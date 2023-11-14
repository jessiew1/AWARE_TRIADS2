import AVFoundation
import UserNotifications

class ConversationDetector: NSObject, AVAudioRecorderDelegate {
    
    var audioRecorder: AVAudioRecorder!
    var notificationCounter = 0
    let notificationLimit = 3
    
    override init() {
        super.init()
        requestMicrophonePermission()
        requestNotificationAuthorization()
        setupAudioRecorder()
    }
    
    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                print("Microphone permission granted.")
            }
        }
    }
    
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                print("Notification permission granted.")
            }
        }
    }
    
    func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true)
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
            audioRecorder.delegate = self
            audioRecorder.isMeteringEnabled = true
            audioRecorder.prepareToRecord()
        } catch {
            print("Audio recorder setup failed: \(error)")
        }
    }
    
    func startMonitoring() {
        guard let recorder = audioRecorder else {
            print("Audio Recorder not initialized")
            return
        }
        
        recorder.record()
        DispatchQueue.global(qos: .background).async {
            while recorder.isRecording {
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                print("power level:", power)
                if power > -40 { // -40 dB is a rough threshold for conversation-level sound
                    DispatchQueue.main.async {
                        self.sendNotificationIfNeeded()
                    }
                    Thread.sleep(forTimeInterval: 600) // Wait for 10 minutes before listening again
                }
                // Reduce the sleep interval here for more frequent sampling, e.g., 0.05 for 20 times per second.
                Thread.sleep(forTimeInterval: 0.05) // Sample every 0.05 seconds
            }
        }
    }

    func sendNotificationIfNeeded() {
        guard notificationCounter < notificationLimit else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Conversation Detected"
        content.body = "Tap to participate in our latest survey."
        content.sound = .default
        content.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                self.notificationCounter += 1
            }
        }
    }
    
    // Reset the notification counter at midnight
    func resetNotificationCounter() {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: midnight)!
        
        let timer = Timer(fireAt: nextMidnight, interval: 0, target: self, selector: #selector(resetCounter), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @objc func resetCounter() {
        notificationCounter = 0
    }
    
    func stopMonitoring() {
        audioRecorder?.stop()  // Use optional chaining to safely attempt to call stop()
        audioRecorder = nil    // Then, if necessary, explicitly set audioRecorder to nil
    }

}
