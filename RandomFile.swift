import Foundation
import AWAREFramework
import MySQLNIO
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    let device_id = AWAREStudy.shared().getDeviceId()
    let device_name = AWAREStudy.shared().getDeviceName()
    private var notificationCount = 0

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
        scheduleImmediateNotification(for: datesForNotification)
    }

    func scheduleImmediateNotification(for dates: [Date]) {
        let content = UNMutableNotificationContent()
        content.title = "Random Survey Schedule"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let dateString = dates.map { dateFormatter.string(from: $0) }.joined(separator: ", ")
        content.body = "Notifications scheduled for: \(dateString)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        //let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        //UNUserNotificationCenter.current().add(request) { error in
           // if let error = error {
            //    print("Error scheduling immediate notification: \(error)")
           // }
       // }
    }

    func scheduleAndStoreNotification(for date: Date, content: UNMutableNotificationContent, device_id: String, device_name: String) {
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                //self.storeNotificationDetailsInDatabase(message_id: request.identifier, date: date, message_text: content.body, device_id: device_id, device_name: device_name)
            }
        }
    }

 func storeNotificationDetailsInDatabase(message_id: String, date: Date, message_text: String, device_id: String, device_name: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: date)

        let sql = "INSERT INTO Notifications (message_id, date, message_text, device_id, device_name) VALUES (?, ?, ?, ?, ?)"

        let values: [MySQLData] = [
            MySQLData(string: message_id),
            MySQLData(string: dateString),
            MySQLData(string: message_text),
            MySQLData(string: device_id),
            MySQLData(string: device_name)
        ]

        MySQLConnectionHandler.shared.pool?.withConnection { connection in
            connection.query(sql, values).map { rows in
                print("Notification stored successfully.")
            }.flatMapError { error in
                print("Failed to store notification: \(error)")
                return connection.eventLoop.makeFailedFuture(error)
            }
        }
    }

    private func scheduleNotification(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Random Survey"
        content.body = "Tap to participate!"
        content.sound = .default
        content.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling random notification: \(error)")
            } else {
                self.notificationCount += 1
                print(self.notificationCount)
                if self.notificationCount > 21 {
                    //self.storeNotificationDetailsInDatabase(message_id: request.identifier, date: date, message_text: content.body, device_id: self.device_id, device_name: self.device_name)
                }
            }
        }
    }

    func scheduleTwoStartupNotifications() {
        let firstNotificationDate = Date().addingTimeInterval(60) // 1 minute after app start
        let secondNotificationDate = Date().addingTimeInterval(120) // 2 minutes after app start

        scheduleNotification(for: firstNotificationDate)
        scheduleNotification(for: secondNotificationDate)
    }
}
