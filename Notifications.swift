import Foundation
import UserNotifications

let notificationCenter = UNUserNotificationCenter.current()

func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
    notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            print("Error requesting notification permission: \(error.localizedDescription)")
        }
        completion(granted)
    }
}

func scheduleNotification(title: String, body: String, timeInterval: TimeInterval, repeats: Bool, surveyNumber: Int) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    
    // Adding user info with survey number and URL
    content.userInfo = ["surveyNumber": surveyNumber, "url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
    
    notificationCenter.add(request) { error in
        if let error = error {
            print("Error scheduling notification: \(error.localizedDescription)")
        }
    }
}

func scheduleInitialNotification(withTimes times: [String]) {
    let initialNotificationBody = "Your Surveys Times will be at: \(times.joined(separator: ", "))"
    scheduleNotification(title: "Surveys Times", body: initialNotificationBody, timeInterval: 5, repeats: false, surveyNumber: 0)
    print("Initial notification scheduled.")
}

func createPushNotifications() {
    requestNotificationPermission { granted in
        guard granted else {
            print("Notification permission not granted.")
            return
        }
        
        let times = ["9:15", "9:30", "9:45", "10:00", "10:27", "10:30", "10:45", "11:00", "11:15", "11:30", "11:45", "12:00", "12:15", "12:30", "12:45", "13:00", "13:15", "13:30", "13:45", "14:00", "14:15", "14:30", "14:45"]
        
        for (_, timeString) in times.enumerated() {
            let components = timeString.split(separator: ":")
            guard components.count == 2,
                  let hour = Int(components[0]),
                  let minute = Int(components[1]) else {
                print("Invalid time format for \(timeString)")
                continue
            }
            
            var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            // Check if the time has already passed for today; if so, schedule for the next day
            if let date = Calendar.current.date(from: dateComponents), date < Date() {
                dateComponents.day! += 1
            }
            
            let i = 0 // or whatever your loop index is
            let surveyTitle = "Random Survey \(i + 1)"
            let surveyBody = "Time to take a survey! Number: \(i + 1)"
            let hyperlink = "<a href=\"https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk\" title=\"\(surveyTitle)\">\(surveyBody)</a>"

            
            if let triggerDate = Calendar.current.date(from: dateComponents) {
                let timeInterval = triggerDate.timeIntervalSinceNow
                if timeInterval > 0 { // Schedule only if the time is in the future
                    scheduleNotification(title: surveyTitle, body: surveyBody, timeInterval: timeInterval, repeats: false, surveyNumber: i + 1)
                }
            }
        }
        
        // Schedule the initial notification with the times
        scheduleInitialNotification(withTimes: times)
    }
}
