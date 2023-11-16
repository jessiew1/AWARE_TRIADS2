//  Speech2.swift
//  aware-client-ios-v2
//
//  Created by JessieW on 11/2/23.
//  Copyright © 2023 Yuuki Nishiyama. All rights reserved.

import Foundation
import UIKit
import AWAREFramework
import Speech
import UserNotifications

let noiseSensor = AmbientNoise()
let manager = AWARESensorManager.shared()
let core = AWARECore.shared()

func scheduleNotification2(title: String, body: String, timeInterval: TimeInterval, repeats: Bool, surveyNumber: Int) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    
    // Adding user info with survey number and URL
    content.userInfo = ["surveyNumber": surveyNumber, "url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error scheduling notification: \(error.localizedDescription)")
        }
    }
}

func setupNoiseSensor() {
    print(":NoiseSensor:")
    noiseSensor.setSensorEventHandler { sensor, data in
        if let d = data {
            print(d["double_decibels"])
            print(d["double_silent_threshold"])
            
            if let decibels = d["double_decibels"] as? Double, decibels >= 0.51 {
                let currentDate = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let currentDateString = dateFormatter.string(from: currentDate)
                
                let storedDate = UserDefaults.standard.string(forKey: "lastSurveyDate")
                var surveyCount = UserDefaults.standard.integer(forKey: "surveyCount")
                
                if storedDate == currentDateString {
                    if surveyCount < 3 {
                        scheduleNotification2(title: "Survey Reminder", body: "Please complete the deep survey", timeInterval: 5, repeats: false, surveyNumber: surveyCount + 1)
                        UserDefaults.standard.set(surveyCount + 1, forKey: "surveyCount")
                    }
                } else {
                    UserDefaults.standard.set(currentDateString, forKey: "lastSurveyDate")
                    UserDefaults.standard.set(1, forKey: "surveyCount")
                    scheduleNotification2(title: "Survey Reminder", body: "Please complete the deep survey", timeInterval: 5, repeats: false, surveyNumber: 1)
                }
            }
        }
    }
    
    noiseSensor.setAudioFileGenerationHandler { url in
        if let url = url {
            print(url)
        }
    }
}

func startSensors() {
    manager.add(noiseSensor)
    manager.startAllSensors()
}

func startConversationSensor() {
    core.requestPermissionForBackgroundSensing { status in
        core.startBaseLocationSensor()
        let conversation = Conversation(awareStudy: AWAREStudy.shared())
        conversation.startSensor()
        conversation.setSensorEventHandler { sensor, data in
            print("ConversationData:", data)
        }
        conversation.setDebug(true)
        manager.add(conversation)
        manager.startAllSensors()
    }
}

func requestBackgroundSensingPermission() {
    core.requestPermissionForBackgroundSensing { state in
        print(state)
        core.activate()
    }
}

func configureApplication() {
    setupNoiseSensor()
    startSensors()
    requestBackgroundSensingPermission()
    startConversationSensor()
}
