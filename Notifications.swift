//
//  Notifcations.swift
//  PPS-Data
//
//  Created by Joshua Ren on 10/28/19.
//  Copyright © 2019 Joshua Ren. All rights reserved.
//

import Foundation
import UserNotifications
import Foundation
import UserNotifications

func registerForPushNotifications() {
    UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else {
                print("Notification permission not granted")
                return
            }
            DispatchQueue.main.async {
                getNotificationSettings()
                createPushNotifications()
            }
    }
}

private func helpCreateNotification(contentTitle: String, contentSubTitle: String, contentBody: String, dateHour: Int, dateMinutes: Int) {
    var date = DateComponents()
    date.hour = dateHour
    date.minute = dateMinutes
    
    let content = UNMutableNotificationContent()
    content.title = contentTitle
    content.subtitle = contentSubTitle
    content.body = contentBody
    content.sound = .default
    
    let uuidString = UUID().uuidString
    let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
    let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error in reminder: \(error.localizedDescription)")
        }
    }
}

func createPushNotifications() -> [String : [[Int: Int]]] {
    let contentTitles = ["Survey 1", "Survey 2", "Survey 3"]
    let contentSubTitles = ["", "", ""]
    let contentBodies = ["Time to take a survey! :)", "Time to take a survey! :)", "Time to take a survey! :)"]
    
    var dateHours = [Int]()
    var dateMinutes = [Int]()
    
    for _ in 0..<3 {
        let randomHour = Int.random(in: 0...23)
        let randomMinute = Int.random(in: 0...59)
        dateHours.append(randomHour)
        dateMinutes.append(randomMinute)
    }
    
    if contentTitles.count != contentSubTitles.count || contentSubTitles.count != contentBodies.count || contentBodies.count != dateHours.count || dateHours.count != dateMinutes.count {
        print("\nERROR: Lengths of arrays do not match\n")
        return [:]
    }
    
    UNUserNotificationCenter.current().getPendingNotificationRequests { notifications in
        if notifications.isEmpty {
            for i in 0..<contentTitles.count {
                helpCreateNotification(contentTitle: contentTitles[i], contentSubTitle: contentSubTitles[i], contentBody: contentBodies[i], dateHour: dateHours[i], dateMinutes: dateMinutes[i])
            }
        } else {
            print("Notifications are already scheduled")
        }
    }
    
    return helpGetHours(titles: contentTitles, dateHours: dateHours, dateMinutes: dateMinutes)
}
private func getNotificationSettings() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        guard settings.authorizationStatus == .authorized else { return }
        print("Notifications are authorized")
    }
}

private func helpGetHours(titles: [String], dateHours: [Int], dateMinutes: [Int]) -> [String : [[Int: Int]]] {
    var nameToTimes = [String : [[Int : Int]]]()
    for i in 0..<dateHours.count {
        let curTitle = titles[i]
        let curHour = dateHours[i]
        let curMin = dateMinutes[i]
        var timeComponents = [Int: Int]()
        timeComponents[curHour] = curMin
        if nameToTimes[curTitle] == nil {
            nameToTimes[curTitle] = [timeComponents]
        } else {
            nameToTimes[curTitle]?.append(timeComponents)
        }
    }
    return nameToTimes
}

func getNotificationTimes() -> [String : [[Int: Int]]] {
    return createPushNotifications()
}

func removeNotifications() {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
}

func listPendingNotifications() {
    UNUserNotificationCenter.current().getPendingNotificationRequests { notifications in
        for notification in notifications {
            print(notification)
        }
        print("Existing notifications count: ", notifications.count, "\n")
    }
}
