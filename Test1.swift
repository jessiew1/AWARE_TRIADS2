//  Test2.swift
//  aware-client-ios-v2
//
//  Created by JessieW on 11/2/23.
//  Copyright © 2023 Jessie. All rights reserved.
//


import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // Add this method to the NotificationManager class
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification."
        content.sound = UNNotificationSound.default
        content.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]

        // Configure the trigger for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create the request
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        // Schedule the request with the system.
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling test notification: \(error)")
            } else {
                print("Test notification scheduled.")
            }
        }
    }

    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if granted {
                print("Notification permission granted.")
                self?.scheduleNotificationsStartingAt1230()
            } else if let error = error {
                print("Notification permission denied because: \(error.localizedDescription).")
            }
        }
    }
    
    func scheduleNotificationsStartingAt1230() {
        let startHour = 12
        let startMinute = 30
        let endHour = 16
        let endMinute = 15
        
        var currentDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        currentDateComponents.hour = startHour
        currentDateComponents.minute = startMinute
        
        guard let startTime = Calendar.current.date(from: currentDateComponents) else { return }
        let endTime = Calendar.current.date(bySettingHour: endHour, minute: endMinute, second: 0, of: startTime)!
        
        var currentTime = startTime
        while currentTime <= endTime {
            scheduleNotification(for: currentTime)
            currentTime = Calendar.current.date(byAdding: .minute, value: 15, to: currentTime)!
        }
    }
    
    private func scheduleNotification(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Survey Notification"
        content.body = "Tap to open the survey."
        content.sound = UNNotificationSound.default
        content.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification for \(date): \(error)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate Methods
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLinkURLString = userInfo["deep_link_url"] as? String,
           let deepLinkURL = URL(string: deepLinkURLString) {
            // Open the deep link URL in a web browser
            DispatchQueue.main.async {
                UIApplication.shared.open(deepLinkURL, options: [:], completionHandler: nil)
            }
        }
        completionHandler()
    }
}
