import AVFoundation
import UserNotifications
import Speech

// Global variables
var audioEngine = AVAudioEngine()
var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
var recognitionTask: SFSpeechRecognitionTask?
let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
var notificationCounter = 0
let notificationLimit = 3

// Function to request speech recognition authorization
func requestSpeechRecognitionAuthorization() {
    SFSpeechRecognizer.requestAuthorization { authStatus in
        switch authStatus {
        case .authorized:
            print("Speech recognition authorization granted.")
        default:
            print("Speech recognition authorization denied.")
        }
    }
}

// Function to request notification authorization
func requestNotificationAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
        if granted {
            print("Notification permission granted.")
        } else {
            print("Notification permission denied.")
        }
    }
}

// Function to send notification if needed
func sendNotificationIfNeeded() {
    guard notificationCounter < notificationLimit else { return }
    
    sendNotification(title: "Conversation Detected", body: "Tap to participate in our latest survey.")
}

// Function to send custom notification
func sendNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error scheduling notification: \(error)")
        } else {
            notificationCounter += 1
        }
    }
}

// Function to reset notification counter
func resetNotificationCounter() {
    notificationCounter = 0
}

// Function to set up speech recognizer
func setupSpeechRecognizer() {
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard recognitionRequest != nil else { fatalError("Unable to create a speech recognition request.") }
    recognitionRequest?.shouldReportPartialResults = true
}

// Function to analyze speech and detect potential speaker changes
func analyzeTranscriptionForSpeakerChanges(_ transcription: SFTranscription) -> Bool {
    let segments = transcription.segments
    var lastEndTime = segments.first?.timestamp ?? 0.0

    for segment in segments {
        if segment.timestamp - lastEndTime > 1.0 {
            return true // Potential speaker change
        }
        lastEndTime = segment.timestamp + segment.duration
    }
    return false
}

// Function to start monitoring
func startMonitoring() {
    print ("Start Monitoring")
    guard !audioEngine.isRunning else { return }

    recognitionTask?.cancel()
    recognitionTask = nil

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a speech recognition request.") }

    let inputNode = audioEngine.inputNode
    recognitionRequest.shouldReportPartialResults = true

    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
        if let result = result, result.isFinal {
            print(result.bestTranscription.formattedString)
            let isMultipleSpeakers = analyzeTranscriptionForSpeakerChanges(result.bestTranscription)
            DispatchQueue.main.async {
                if isMultipleSpeakers {
                    sendNotification(title: "Multiple Speakers Detected", body: "Conversation with multiple participants detected.")
                } else {
                    sendNotificationIfNeeded()
                }
            }
        } else if let error = error {
            print("Speech recognition error: \(error)")
        }
    }

    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
        recognitionRequest.append(buffer)
    }

    audioEngine.prepare()
    do {
        try audioEngine.start()
    } catch {
        print("Audio engine couldn't start because of an error: \(error)")
    }
}

// Function to stop monitoring
func stopMonitoring() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionTask?.cancel()
    recognitionTask = nil
}
