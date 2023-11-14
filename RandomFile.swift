import Foundation
import UserNotifications

// Extend the existing NotificationManager class with new functionality
extension NotificationManager {

    // This function schedules random notifications for a specified number of days
    func scheduleRandomNotificationsForMultipleDays(numberOfDays: Int) {
        let timeRanges = [
            (startHour: 9, startMinute: 0, endHour: 13, endMinute: 0),
            (startHour: 13, startMinute: 0, endHour: 17, endMinute: 0),
            (startHour: 17, startMinute: 0, endHour: 21, endMinute: 0)
        ]

        for dayOffset in 0..<numberOfDays {
            for range in timeRanges {
                scheduleRandomNotificationBetween(startHour: range.startHour, startMinute: range.startMinute, endHour: range.endHour, endMinute: range.endMinute, dayOffset: dayOffset)
            }
        }
    }
    
    // This function schedules one random notification between the given start and end times, considering the day offset
    private func scheduleRandomNotificationBetween(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, dayOffset: Int) {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.day! += dayOffset
        
        var startDateComponents = dateComponents
        startDateComponents.hour = startHour
        startDateComponents.minute = startMinute
        
        var endDateComponents = startDateComponents
        endDateComponents.hour = endHour
        endDateComponents.minute = endMinute
        
        guard let startTime = Calendar.current.date(from: startDateComponents),
              let endTime = Calendar.current.date(from: endDateComponents) else { return }
        
        let randomTimeInterval = TimeInterval(arc4random_uniform(UInt32(endTime.timeIntervalSince(startTime))))
        let randomDate = startTime.addingTimeInterval(randomTimeInterval)
        
        scheduleNotification(for: randomDate)
        var datesForNotification = [Date]()
        datesForNotification.append(randomDate)
        // Assuming randomDate is an array of Date objects
        scheduleImmediateNotification(for: datesForNotification)
    }
    
    
    
    func scheduleImmediateNotification(for dates: [Date]) {
        let content = UNMutableNotificationContent()
        content.title = "Random Survey Schedule"

        // Formatting the dates into a string
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let dateString = dates.map { dateFormatter.string(from: $0) }.joined(separator: ", ")
        content.body = "Notifications scheduled for: \(dateString)"
        content.sound = .default

        // Triggering the notification immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling immediate notification: \(error)")
            }
        }
    }

    
    
    
    // This function schedules a notification for a given date
    private func scheduleNotification(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Random Survey Time"
        content.body = "It's time for a random survey! Tap to participate."
        content.sound = .default
        content.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling random notification: \(error)")
            }
        }
    }
}
