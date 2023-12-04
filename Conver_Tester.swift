import Foundation
import UIKit
import AWAREFramework
import CoreData
import AWAREFramework.Conversation
import AWAREFramework.AWARESensor
import StudentLifeAudio
import UserNotifications

// Global variables to track survey count and last survey time
var surveyCount = 0
var lastSurveyDate: Date?
var turnOffTimer: Timer?
var turnOnTimer: Timer?

func startAwareSensors() {
    let core = AWARECore.shared()
    core.requestPermissionForBackgroundSensing { (status) in
        core.startBaseLocationSensor()
        let conversation = Conversation(awareStudy: AWAREStudy.shared())
        conversation.startSensor()
        conversation.setSensorEventHandler { (sensor, data) in
            print(data)
        }
        conversation.setDebug(true)
        let manager = AWARESensorManager.shared()
        manager.add(conversation)
        manager.startAllSensors()
    }
    startFetchingSensorData()
}

var sensorDataTimer: Timer?

func startFetchingSensorData() {
    sensorDataTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
        fetchSensorData()
    }
}

func fetchSensorData() {
    if let con = manager.getLatestSensorData(SENSOR_PLUGIN_STUDENTLIFE_AUDIO) as? [String: Any] {
              if let inference = con["inference"] {
                  print("Inference:", inference)
              }
              if let datatype = con["datatype"] {
                  print("Datatype:", datatype)
              }
          } else {
              // Handle the case where 'con' is nil or not a dictionary
          }
    
    // Check if the survey count has exceeded the limit or if 24 hours have not passed since the last survey
    if surveyCount >= 3, let lastDate = lastSurveyDate, Date().timeIntervalSince(lastDate) < 86400 {
        return
    }

    if let con = manager.getLatestSensorData(SENSOR_PLUGIN_STUDENTLIFE_AUDIO) as? [String: Any], let inference = con["inference"] as? Int, inference == 2 {
        sendNotification()
        pauseFetchingSensorData(for: 900) // Pause for 15 minutes
        surveyCount += 1
        lastSurveyDate = Date()
    }
    
    if let con = manager.getLatestSensorData(SENSOR_PLUGIN_STUDENTLIFE_AUDIO) as? [String: Any], let datatype = con["datatype"] as? Int, datatype == 2 {
        sendNotification2()
        pauseFetchingSensorData(for: 900) // Pause for 15 minutes
        surveyCount += 1
        lastSurveyDate = Date()
    }
    
    
}


func sendNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Conversation Detected - Inference"
    content.body = "Tap to participate in our latest survey."
    content.sound = .default
    content.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error scheduling notification: \(error)")
        }
    }
}

func sendNotification2() {
    let content = UNMutableNotificationContent()
    content.title = "Conversation Detected - Datatype"
    content.body = "Tap to participate in our latest survey."
    content.sound = .default
    content.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error scheduling notification: \(error)")
        }
    }
}

func pauseFetchingSensorData(for interval: TimeInterval) {
    sensorDataTimer?.invalidate()
    sensorDataTimer = nil
    DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
        startFetchingSensorData()
    }
}

func stopFetchingSensorData() {
    sensorDataTimer?.invalidate()
    sensorDataTimer = nil
}

func requestNotificationPermission() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            print("Error requesting notifications permission: \(error)")
        }
    }
}



