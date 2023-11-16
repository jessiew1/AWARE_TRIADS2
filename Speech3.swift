import Foundation
import AVFoundation
import UserNotifications

class DecibelMeter {
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private let notificationCenter = UNUserNotificationCenter.current()
    private var surveyCount = 0
    private let maxSurveysPerDay = 3
    private let minIntervalBetweenSurveys: TimeInterval = 1800 // 30 minutes in seconds
    private var lastSurveyDate: Date?
    private var isMeteringEnabled = false

    init() {
        setupAudioRecorder()
        requestNotificationAuthorization()
    }
    
    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            let url = URL(fileURLWithPath: "/dev/null")  // No need to save recorded audio
            let settings = [
                AVFormatIDKey: Int(kAudioFormatAppleLossless),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ] as [String : Any]
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
        } catch {
            print("AudioRecorder setup failed with error: \(error)")
        }
    }
    
    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func startMetering() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.audioRecorder?.record()
            self?.isMeteringEnabled = true
            self?.levelTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self!, selector: #selector(self?.updateMeters), userInfo: nil, repeats: true)
        }
    }
    
    @objc private func updateMeters() {
        guard isMeteringEnabled else { return }
        
        audioRecorder?.updateMeters()
        if let averagePower = audioRecorder?.averagePower(forChannel: 0) {
            let linearLevel = pow(10, averagePower / 20)
            let levelInDecibels = 20 * log10(linearLevel)
            let absoluteLevelInDecibels = abs(levelInDecibels)
            print("Current input level: \(absoluteLevelInDecibels) dB")
            
            let now = Date()
            if absoluteLevelInDecibels < 20 {
                if surveyCount < maxSurveysPerDay,
                   lastSurveyDate == nil || now.timeIntervalSince(lastSurveyDate!) >= minIntervalBetweenSurveys {
                    lastSurveyDate = now
                    surveyCount += 1
                    scheduleNotification(title: "Conversation Detected", body: "Please take a moment to fill out a survey.", timeInterval: 1, repeats: false, surveyNumber: surveyCount)
                }
            }
            if let lastDate = lastSurveyDate, now.timeIntervalSince(lastDate) >= 86400 {
                surveyCount = 0
            }
        }
    }
    
    private func scheduleNotification(title: String, body: String, timeInterval: TimeInterval, repeats: Bool, surveyNumber: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // Set the 'userInfo' for deep linking
        content.userInfo = ["surveyNumber": surveyNumber, "url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]
        // Set the category identifier for managing the notification
        content.categoryIdentifier = "SURVEY_INVITATION"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func stopMetering() {
        audioRecorder?.stop()
        levelTimer?.invalidate()
        isMeteringEnabled = false
    }
}

// Usage
let decibelMeter = DecibelMeter()

// To stop metering later on:
// decibelMeter.stopMetering()
