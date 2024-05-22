// ViewController.swift
// aware-client-ios-v2
//
// Created by Yuuki Nishiyama on 2019/02/27.
// Updated by Jessie Walker on 2024/05/17.
// © 2019 Yuuki Nishiyama. All rights reserved.

import UIKit
import AWAREFramework
import MapKit
import SafariServices
import CoreLocation
import MySQLKit
import NIO
import MySQLNIO
import UserNotifications

/**
 This ViewController is responsible for managing notifications within the AWARE framework. It captures and logs various interactions with notifications, such as when a notification is delivered, clicked, dismissed, or ignored. These interactions are then stored in a MySQL database for further analysis. Key elements include:
 
 - Setting up the notification center delegate and requesting authorization for notifications.
 - Scheduling notifications and capturing delivered notifications both periodically and manually.
 - Handling interactions with notifications, including clicks and dismissals, and logging these interactions in the database.
 - Checking for ignored notifications, defined as notifications that have been delivered but not interacted with within a certain timeframe (e.g., 5 minutes).
 */

class ViewController: UIViewController, UNUserNotificationCenterDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    let sensorManager = AWARESensorManager.shared()
    
    var refreshTimer: Timer?
    var refreshInterval = 0.5
    
    var googleLoginRequestObserver: NSObjectProtocol?
    var contactUpdateRequestObserver: NSObjectProtocol?
    
    var selectedRowContent: TableRowContent?
    
    @IBOutlet weak var uploadButton: UIBarButtonItem!
    
    var geofenceManager: GeofenceManager?
    var mapView: MKMapView!
    
    var sensingStatus = true
    let core = AWARECore.shared()
    
    var eventLoopGroup: EventLoopGroup!
    var mysqlConnection: MySQLConnection!
    let device_name = AWAREStudy.shared().getDeviceName()
    let device_id = AWAREStudy.shared().getDeviceId()
    
    var captureTimer: Timer?
    var deliveredNotifications: [String: Date] = [:] // To track delivered notifications

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        Sensors()
        // Start the process
        initializeAWAREFrameworkComponents()
        NotificationManager.shared.scheduleRandomNotificationsForMultipleDays(numberOfDays: 7)
        NotificationManager.shared.scheduleTwoStartupNotifications()
        testNotificationHandling()
        scheduleTestNotification()
        checkDeliveredReminders()
        // Connect to the database
        connectToDatabase()
        
        // Set UNUserNotificationCenter delegate and request authorization
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification authorization granted")
                self.captureNotifications()
                self.scheduleStartupNotifications()  // Call the function to schedule notifications
            } else if let error = error {
                print("Notification authorization error: \(error)")
            }
        }

        // Start the periodic capture timer
        startCaptureTimer()
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    // Custom error type for handling timeout
    struct TimeoutError: Error {
        let message: String
    }

    // Establish a connection to the MySQL database
    func connectToDatabase() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        

        
        do {
            let socketAddress = try SocketAddress.makeAddressResolvingHost(hostname, port: port)
            let connectFuture = MySQLConnection.connect(
                to: socketAddress,
                username: username,
                database: database,
                password: password,
                tlsConfiguration: nil,
                on: eventLoopGroup.next()
            )
            
            connectFuture.flatMap { connection in
                self.mysqlConnection = connection
                print("MySQL connection established")
                return self.eventLoopGroup.next().makeSucceededFuture(())
            }.whenComplete { result in
                switch result {
                case .failure(let error):
                    print("MySQL connection failed: \(error.localizedDescription)")
                    try? self.eventLoopGroup.syncShutdownGracefully()
                case .success:
                    print("MySQL connection successful")
                }
            }
        } catch {
            print("Failed to resolve socket address: \(error.localizedDescription)")
            try? eventLoopGroup.syncShutdownGracefully()
        }
    }

    // Insert notification into the database
    func insertNotificationIntoDatabase(identifier: String, title: String, body: String, schedule: String?, year: Int?, month: Int?, day: Int?, hour: Int?, minute: Int?, isReminder: Bool) {
        guard let mysqlConnection = mysqlConnection else {
            print("MySQL connection is not established")
            return
        }
        let device_name = AWAREStudy.shared().getDeviceName()
        let device_id = AWAREStudy.shared().getDeviceId()
        let query = """
        INSERT INTO Notifications2 (message_id, title, schedule, body, Year, Month, Day, Hour, Minute, device_name, device_id, is_reminder)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        let parameters: [MySQLData] = [
            MySQLData(string: identifier),
            MySQLData(string: title),
            MySQLData(string: schedule ?? ""),
            MySQLData(string: body),
            MySQLData(int: year ?? 0),
            MySQLData(int: month ?? 0),
            MySQLData(int: day ?? 0),
            MySQLData(int: hour ?? 0),
            MySQLData(int: minute ?? 0),
            MySQLData(string: device_name),
            MySQLData(string: device_id),
            MySQLData(int: isReminder ? 1 : 0) // 1 if reminder, 0 if not
        ]

        mysqlConnection.query(query, parameters).whenComplete { result in
            switch result {
            case .success:
                print("Notification inserted into the database")
            case .failure(let error):
                print("Failed to insert notification into the database: \(error.localizedDescription)")
            }
        }
    }

    // Insert notification interaction into the database
    func insertNotificationInteractionIntoDatabase(identifier: String, interactionType: String, timestamp: String) {
        guard let mysqlConnection = mysqlConnection else {
            print("MySQL connection is not established")
            return
        }
        let device_name = AWAREStudy.shared().getDeviceName()
        let device_id = AWAREStudy.shared().getDeviceId()
        let query = """
        INSERT INTO notification_inter (message_id, interaction_type, timestamp, device_name, device_id)
        VALUES (?, ?, ?, ?, ?)
        """

        let parameters: [MySQLData] = [
            MySQLData(string: identifier),
            MySQLData(string: interactionType),
            MySQLData(string: timestamp),
            MySQLData(string: device_name),
            MySQLData(string: device_id)
        ]

        mysqlConnection.query(query, parameters).whenComplete { result in
            switch result {
            case .success:
                print("Notification interaction inserted into the database")
            case .failure(let error):
                print("Failed to insert notification interaction into the database: \(error.localizedDescription)")
            }
        }
    }

    // Capture Delivered Notifications
    func captureNotifications() {
        let notificationCenter = UNUserNotificationCenter.current()
        
        notificationCenter.getDeliveredNotifications { notifications in
            print("Delivered Notifications at \(Date()): \(notifications.count)")
            for notification in notifications {
                self.handleNotification(notification)
                self.deliveredNotifications[notification.request.identifier] = Date() // Track delivered notifications
            }
        }
    }

    // Capture Delivered Notifications Manually
    @objc func captureDeliveredNotificationsManually() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getDeliveredNotifications { notifications in
            print("Manually Capturing Delivered Notifications at \(Date()): \(notifications.count)")
            for notification in notifications {
                self.handleNotification(notification)
                self.deliveredNotifications[notification.request.identifier] = Date() // Track delivered notifications
            }
        }
    }

    // Check for delivered reminder notifications
    func checkDeliveredReminders() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getDeliveredNotifications { notifications in
            let reminderNotifications = notifications.filter { $0.request.identifier.contains("-reminder") }
            print("Delivered Reminder Notifications at \(Date()): \(reminderNotifications.count)")
            for notification in reminderNotifications {
                print("Reminder Notification - Identifier: \(notification.request.identifier), Title: \(notification.request.content.title), Body: \(notification.request.content.body)")
            }
        }
    }

    // Handle notification delivery
    func handleNotification(_ notification: UNNotification) {
        let identifier = notification.request.identifier
        let content = notification.request.content
        let title = content.title
        let body = content.body
        let trigger = notification.request.trigger
        
        var year: Int? = nil
        var month: Int? = nil
        var day: Int? = nil
        var hour: Int? = nil
        var minute: Int? = nil
        var schedule: String? = nil
        var isReminder: Bool = false

        if identifier.contains("-reminder") {
            isReminder = true
        }

        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            let dateComponents = calendarTrigger.dateComponents
            year = dateComponents.year
            month = dateComponents.month
            day = dateComponents.day
            hour = dateComponents.hour
            minute = dateComponents.minute
            
            if let y = year, let m = month, let d = day, let h = hour, let min = minute {
                schedule = String(format: "%04d-%02d-%02d %02d:%02d:00", y, m, d, h, min)
            }
        } else if let timeIntervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            // If using time interval trigger, we set schedule to the current date and time
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            schedule = dateFormatter.string(from: Date())
        }

        insertNotificationIntoDatabase(identifier: identifier, title: title, body: body, schedule: schedule, year: year, month: month, day: day, hour: hour, minute: minute, isReminder: isReminder)
    }

    // UNUserNotificationCenterDelegate method for handling notifications while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handleNotification(notification)
        completionHandler([.alert, .sound, .badge])
    }

    // UNUserNotificationCenterDelegate method for handling notification responses
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        handleNotification(response.notification)
        
        // Log the interaction
        let identifier = response.notification.request.identifier
        let interactionType: String

        // Determine the type of interaction
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            interactionType = "Clicked Notification"
        case UNNotificationDismissActionIdentifier:
            interactionType = "Dismissed Notification"
        default:
            interactionType = response.actionIdentifier // Custom action
        }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        
        insertNotificationInteractionIntoDatabase(identifier: identifier, interactionType: interactionType, timestamp: timestamp)
        
        // Remove from deliveredNotifications
        deliveredNotifications.removeValue(forKey: identifier)
        
        completionHandler()
    }

    // Start a timer to periodically capture delivered notifications
    func startCaptureTimer() {
        captureTimer = Timer.scheduledTimer(timeInterval: 60.0, // Set the desired interval in seconds
                                            target: self,
                                            selector: #selector(captureDeliveredNotificationsManually),
                                            userInfo: nil,
                                            repeats: true)
        Timer.scheduledTimer(timeInterval: 600.0, // Check for ignored notifications every 10 minutes
                             target: self,
                             selector: #selector(checkForIgnoredNotifications),
                             userInfo: nil,
                             repeats: true)
    }

    // Capture notifications when the app enters the foreground
    @objc func appWillEnterForeground() {
        captureDeliveredNotificationsManually()
        checkDeliveredReminders()
    }

    // Check for ignored notifications
    @objc func checkForIgnoredNotifications() {
        let now = Date()
        for (identifier, deliveryDate) in deliveredNotifications {
            if now.timeIntervalSince(deliveryDate) > 300 { // 5 minutes threshold
                let interactionType = "Ignored Notification"
                let timestamp = DateFormatter.localizedString(from: now, dateStyle: .medium, timeStyle: .medium)
                insertNotificationInteractionIntoDatabase(identifier: identifier, interactionType: interactionType, timestamp: timestamp)
                deliveredNotifications.removeValue(forKey: identifier)
            }
        }
    }

    deinit {
        captureTimer?.invalidate()
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        closeConnection()
    }

    // Ensure the connection is properly closed before deinit
    func closeConnection() {
        if let mysqlConnection = mysqlConnection {
            mysqlConnection.close().whenComplete { result in
                switch result {
                case .success:
                    print("MySQL connection closed successfully")
                case .failure(let error):
                    print("Failed to close MySQL connection: \(error.localizedDescription)")
                }
                self.shutdownEventLoopGroup()
            }
        } else {
            shutdownEventLoopGroup()
        }
    }

    // Shut down the event loop group
    func shutdownEventLoopGroup() {
        do {
            try eventLoopGroup.syncShutdownGracefully()
        } catch {
            print("Failed to shut down event loop group: \(error.localizedDescription)")
        }
    }

    // Schedule notifications every 3 minutes for 2 times
    func scheduleStartupNotifications() {
        let interval: TimeInterval = 3 * 60 // 3 minutes in seconds
        let totalNotifications = 2
        var currentDate = Date()

        for _ in 1...totalNotifications {
            currentDate = currentDate.addingTimeInterval(interval)
            
            // Create content for the notification
            let content = UNMutableNotificationContent()
            content.title = "Scheduled Notification"
            content.body = "This is a TEST notification scheduled for \(currentDate)"
            content.sound = UNNotificationSound.default
            
            // Schedule the notification
            let identifier = UUID().uuidString
            scheduleNotification(for: currentDate, content: content, identifier: identifier)
        }
    }

    // Function to schedule a notification for a specific date
    func scheduleNotification(for date: Date, content: UNMutableNotificationContent, identifier: String) {
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error adding notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for \(date) with identifier: \(identifier)")
            }
        }
    }

    func scheduleTestNotification() {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Test Notification"
        notificationContent.body = "This is a test notification."
        notificationContent.sound = UNNotificationSound.default
        let notificationIdentifier = UUID().uuidString

        // Schedule the initial notification to be triggered after 5 seconds
        let initialDate = Date().addingTimeInterval(5)
        scheduleNotification(for: initialDate, content: notificationContent, identifier: notificationIdentifier)

        // Create and schedule the reminder notification to be triggered after an additional 10 seconds (15 seconds total)
        let reminderContent = UNMutableNotificationContent()
        reminderContent.title = "Reminder"
        reminderContent.body = "This is a reminder for the test notification."
        reminderContent.sound = UNNotificationSound.default
        let reminderIdentifier = "\(notificationIdentifier)-reminder"
        let reminderDate = Date().addingTimeInterval(15)
        scheduleNotification(for: reminderDate, content: reminderContent, identifier: reminderIdentifier)
    }

    func Sensors() {
        core.requestPermissionForBackgroundSensing { (status) in
            self.core.requestPermissionForPushNotification(completion: nil)
            self.core.activate()
            
            // init sensors
            let activity = IOSActivityRecognition()
            let fusedLocation = FusedLocations()
            let location = Locations()
            self.sensorManager.add([activity, fusedLocation, location])
            self.sensorManager.startAllSensors()
        }
    }

    // Function to test notification handling
    func testNotificationHandling() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification."
        content.sound = .default
        content.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling test notification: \(error)")
            } else {
                print("Test notification scheduled")
            }
        }
    }

    @IBAction func openSurvey(_ sender: Any) {
        let urlString = NSURL(string: "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk")
        let svc = SFSafariViewController(url: urlString! as URL)
        self.present(svc, animated: true, completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        AWARECore.shared().checkCompliance(with: self, showDetail: true)
        
        settings = getSettings()
        sensors.sort { (val1, val2) -> Bool in
            if Language().isJapanese() {
                return val1.identifier.localizedStandardCompare(val2.identifier) == .orderedAscending
            } else {
                return val1.title.localizedStandardCompare(val2.title) == .orderedAscending
            }
        }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true, block: { (timer) in
            self.tableView.reloadData()
        })
        
        googleLoginRequestObserver = NotificationCenter.default.addObserver(forName: Notification.Name(ACTION_AWARE_GOOGLE_LOGIN_REQUEST),
                                               object: nil, queue: .main) { (notification) in
                                                self.login()
        }
        self.login()
        
        contactUpdateRequestObserver = NotificationCenter.default.addObserver(forName: Notification.Name(ACTION_AWARE_CONTACT_REQUEST),
                                               object: nil, queue: .main) { (notification) in
                                                
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForegroundNotification(notification:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundNotification(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        self.checkESMSchedules()
        
        if AWAREStudy.shared().getURL() != "" {
            uploadButton.tintColor = UIColor.systemBlue
        } else {
            uploadButton.tintColor = UIColor(white: 0, alpha: 0)
        }
        
        self.hideContextViewIfNeeded()
        _ = LocationPermissionManager().isAuthorizedAlways(with: self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
        NotificationCenter.default.removeObserver(googleLoginRequestObserver as Any)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc func willEnterForegroundNotification(notification: NSNotification) {
        DispatchQueue.main.async {
            self.settings = self.getSettings()
        }
        print("Notification TEST1")
        self.checkESMSchedules()
        if refreshTimer == nil {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true, block: { (timer) in
                self.tableView.reloadData()
            })
        }
        _ = LocationPermissionManager().isAuthorizedAlways(with: self)
    }
    
    @objc func didEnterBackgroundNotification(notification: NSNotification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func checkESMSchedules() {
        let esmManager = ESMScheduleManager.shared()
        let schedules = esmManager.getValidSchedules()
        if schedules.count > 0 {
            if !IOSESM.hasESMAppearedInThisSession() {
                self.tabBarController?.selectedIndex = 0
            }
        }
    }
    
    func login() {
        let glogin = AWARESensorManager.shared().getSensor(SENSOR_PLUGIN_GOOGLE_LOGIN)
        // Uncomment and update the code to use Google login if needed
        // if let login = glogin as? GoogleLogin {
        //     if login.isNeedLogin() {
        //         let loginViewController = AWAREGoogleLoginViewController()
        //         loginViewController.googleLogin = login
        //         self.present(loginViewController, animated: true, completion: {
        //         })
        //     }
        // }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let next = segue.destination as? SensorSettingViewController,
           let content = self.selectedRowContent {
            next.selectedContent = content
        }
    }

    @IBAction func didPushUploadButton(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: NSLocalizedString("setting_view_manual_upload_title", comment: ""),
                                    message: NSLocalizedString("setting_view_manual_upload_msg", comment: ""),
                                    preferredStyle: .alert)
        let execute = UIAlertAction(title: NSLocalizedString("Execute", comment: ""), style: .default) { (action) in
            self.startManualUpload()
        }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (action) in
            
        }
        alert.addAction(execute)
        alert.addAction(cancel)
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func didPushRefreshButton(_ sender: UIBarButtonItem) {
        let study = AWAREStudy.shared()
        let manager = AWARESensorManager.shared()
        
        manager.stopAndRemoveAllSensors()
        if study.getURL() == "" {
            manager.addSensors(with: study)
            manager.add(AWAREEventLogger.shared())
            manager.add(AWAREStatusMonitor.shared())
            manager.createDBTablesOnAwareServer()
            manager.startAllSensors()
            let alert = UIAlertController(title: NSLocalizedString("setting_view_config_refresh_title", comment: ""),
                                          message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in
                
            }))
            self.present(alert, animated: true, completion: nil)
        } else {
            if let studyURL = study.getURL() {
                study.join(withURL: studyURL) { (settings, status, error) in
                    DispatchQueue.main.async {
                        manager.addSensors(with: study)
                        manager.add(AWAREEventLogger.shared())
                        manager.add(AWAREStatusMonitor.shared())
                        manager.createDBTablesOnAwareServer()
                        manager.startAllSensors()
                        self.showReloadCompletionAlert()
                    }
                }
            }
        }
        
        for sensor in self.sensors {
            sensor.syncProgress = 0
            sensor.syncStatus = .unknown
        }
    }

    let sections = ["Study", "Sensors"]
    
    var settings = Array<TableRowContent>()
    
    func getSettings() -> [TableRowContent] {
         return [TableRowContent(type: .setting,
                         title: "Study URL",
                         details: AWAREStudy.shared().getURL() ?? "",
                         identifier: TableRowIdentifier.studyId.rawValue),
         TableRowContent(type: .setting,
                         title: NSLocalizedString("device_id", comment: ""),
                         details: AWAREStudy.shared().getDeviceId(),
                         identifier: TableRowIdentifier.deviceId.rawValue),
         TableRowContent(type: .setting,
                         title: NSLocalizedString("device_name", comment: ""),
                         details: AWAREStudy.shared().getDeviceName(),
                         identifier: TableRowIdentifier.deviceName.rawValue),
         TableRowContent(type: .setting,
                         title: NSLocalizedString("advanced_settings", comment: ""),
                         details: "",
                         identifier: TableRowIdentifier.advancedSettings.rawValue)]
    }
    
    lazy var sensors: [TableRowContent] = {
         let bundleUrl = Bundle.main.url(forResource: "AWAREFramework", withExtension: "bundle")
         if let url = bundleUrl {
             let bundle = Bundle(url: url)
             var contents = [
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Accelerometer", comment: ""),
                                 details: NSLocalizedString("accelerometer_detail", comment:""),
                                 identifier: SENSOR_ACCELEROMETER,
                                 icon: UIImage(named: "ic_action_accelerometer", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Gyroscope", comment:""),
                                 details: NSLocalizedString("gyro_detail", comment: ""),
                                 identifier: SENSOR_GYROSCOPE,
                                 icon: UIImage(named: "ic_action_gyroscope", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Magnetometer", comment: ""),
                                 details: NSLocalizedString("mag_detail", comment: ""),
                                 identifier: SENSOR_MAGNETOMETER,
                                 icon: UIImage(named: "ic_action_magnetometer", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Rotation", comment: ""),
                                 details: NSLocalizedString("rotation_detail", comment: ""),
                                 identifier: SENSOR_ROTATION,
                                 icon: UIImage(named: "ic_action_rotation", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Linear Accelerometer", comment:""),
                                 details: NSLocalizedString("l_accelerometer_detail", comment: ""),
                                 identifier: SENSOR_LINEAR_ACCELEROMETER,
                                 icon: UIImage(named: "ic_action_linear_acceleration", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Activity Recognition", comment:""),
                                 details: NSLocalizedString("activity_recognition_detail", comment: ""),
                                 identifier: SENSOR_IOS_ACTIVITY_RECOGNITION,
                                 icon: UIImage(named: "ic_action_running", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Pedometer", comment: ""),
                                 details: NSLocalizedString("pedometer_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_PEDOMETER,
                                 icon: UIImage(named: "ic_action_steps", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Location", comment: ""),
                                 details: NSLocalizedString("location_detail", comment: ""),
                                 identifier: SENSOR_LOCATIONS,
                                 icon: UIImage(named: "ic_action_locations", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Barometer", comment: ""),
                                 details: NSLocalizedString("barometer_detail", comment: ""),
                                 identifier: SENSOR_BAROMETER,
                                 icon: UIImage(named: "ic_action_barometer", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Battery", comment: ""),
                                 details: NSLocalizedString("battery_detail", comment: ""),
                                 identifier: SENSOR_BATTERY,
                                 icon: UIImage(named: "ic_action_battery", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Network", comment: ""),
                                 details: NSLocalizedString("network_detail", comment: ""),
                                 identifier: SENSOR_NETWORK,
                                 icon: UIImage(named: "ic_action_network", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Communication", comment: ""),
                                 details: NSLocalizedString("communication_detail", comment: ""),
                                 identifier: SENSOR_CALLS,
                                 icon: UIImage(named: "ic_action_communication", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Bluetooth", comment: ""),
                                 details: NSLocalizedString("bluetooth_detail", comment: ""),
                                 identifier: SENSOR_BLUETOOTH,
                                 icon: UIImage(named: "ic_action_bluetooth", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Processor", comment: ""),
                                 details: NSLocalizedString("processor_detail", comment: ""),
                                 identifier: SENSOR_PROCESSOR,
                                 icon: UIImage(named: "ic_action_processor", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Timezone", comment: ""),
                                 details: NSLocalizedString("timezone_detail", comment: ""),
                                 identifier: SENSOR_TIMEZONE,
                                 icon: UIImage(named: "ic_action_timezone", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("WiFi", comment: ""),
                                 details: NSLocalizedString("wifi_detail", comment: ""),
                                 identifier: SENSOR_WIFI,
                                 icon: UIImage(named: "ic_action_wifi", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Screen", comment: ""),
                                 details: NSLocalizedString("screen_detail", comment: ""),
                                 identifier: SENSOR_SCREEN,
                                 icon: UIImage(named: "ic_action_screen", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Ambient Noise", comment:""),
                                 details: NSLocalizedString("ambient_noise_detail", comment: ""),
                                 identifier: SENSOR_AMBIENT_NOISE,
                                 icon: UIImage(named: "ic_action_ambient_noise", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Heart Rate", comment: ""),
                                 details: NSLocalizedString("heartrate_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_BLE_HR,
                                 icon: UIImage(named: "ic_action_heartrate", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Calendar", comment: ""),
                                 details: NSLocalizedString("calendar_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_CALENDAR,
                                 icon: UIImage(named: "ic_action_google_cal", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Contacts", comment: ""),
                                 details: NSLocalizedString("contacts_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_CONTACTS,
                                 icon: UIImage(named: "ic_action_contacts", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Fitbit", comment: ""),
                                 details: NSLocalizedString("fitbit_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_FITBIT,
                                 icon: UIImage(named: "ic_action_fitbit", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Google Login", comment:""),
                                 details: NSLocalizedString("google_login_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_GOOGLE_LOGIN,
                                 icon: UIImage(named: "google_logo", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("NTP", comment:""),
                                 details: NSLocalizedString("ntp_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_NTPTIME,
                                 icon: UIImage(named: "ic_action_ntptime", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Weather", comment:""),
                                 details: NSLocalizedString("weather_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_OPEN_WEATHER,
                                 icon: UIImage(named: "ic_action_openweather", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Conversation",comment:""),
                                 details: NSLocalizedString("conversation_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_STUDENTLIFE_AUDIO,
                                 icon: UIImage(named: "ic_action_conversation", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Fused Location", comment:""),
                                 details: NSLocalizedString("fused_location_detail", comment: ""),
                                 identifier: SENSOR_GOOGLE_FUSED_LOCATION,
                                 icon: UIImage(named: "ic_action_google_fused_location", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("HealthKit", comment: ""),
                                 details: NSLocalizedString("healthkit_detail", comment: ""),
                                 identifier: SENSOR_HEALTH_KIT,
                                 icon: UIImage(named: "ic_action_health_kit", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Device Usage", comment: ""),
                                 details: NSLocalizedString("device_usage_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_DEVICE_USAGE,
                                 icon: UIImage(named: "ic_action_device_usage", in:bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("iOS ESM", comment: ""),
                                 details: NSLocalizedString("ios_esm_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_IOS_ESM,
                                 icon: UIImage(named: "ic_action_web_esm", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Google Calendar ESM", comment: ""),
                                 details: NSLocalizedString("google_calendar_esm_detail", comment: ""),
                                 identifier: SENSOR_PLUGIN_CALENDAR_ESM_SCHEDULER,
                                 icon: UIImage(named: "ic_action_google_cal", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Significant Motion",comment:""),
                                 details: NSLocalizedString("significant_motion_detail", comment: ""),
                                 identifier: SENSOR_SIGNIFICANT_MOTION,
                                 icon: UIImage(named: "ic_action_significant", in: bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title:  NSLocalizedString("Push Notification", comment:""),
                                 details: NSLocalizedString("push_notification_detail", comment: ""),
                                 identifier: SENSOR_PUSH_NOTIFICATION,
                                 icon: UIImage(named: "ic_action_push_notification", in:bundle, compatibleWith: nil)),
                 TableRowContent(type: .sensor,
                                 title: NSLocalizedString("Headphone Motion", comment:""),
                                 details: NSLocalizedString("headphone_motion_detail", comment:""),
                                 identifier: SENSOR_PLUGIN_HEADPHONE_MOTION,
                                 icon: UIImage(named: "ic_action_airpods", in:bundle, compatibleWith: nil))
             ]
             return contents
         }
         return Array<TableRowContent>()
     }()
 }

extension ViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            switch AWAREStudy.shared().getUIMode(){
            case AwareUIModeNormal:
                return self.settings.count
            case AwareUIModeHideSettings:
                return self.settings.count - 1
            case AwareUIModeHideAll:
                break
            case AwareUIModeHideSensors:
                return self.settings.count
            default:
                break
            }
        } else if section == 1 {
            switch AWAREStudy.shared().getUIMode(){
            case AwareUIModeNormal:
                return self.sensors.count
            case AwareUIModeHideSettings:
                break
            case AwareUIModeHideAll:
                break
            case AwareUIModeHideSensors:
                break
            default:
                break
            }
        }
        return 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AwareTableViewCell.cellName) as! AwareTableViewCell

        if indexPath.section == 0 {
            let setting = settings[indexPath.row]
            cell.title.text  = setting.title
            cell.detail.text = setting.details
            cell.icon.isHidden = true
            cell.progress.isHidden = true
            cell.hideIcon()
            cell.hideSyncProgress()
            
        } else if indexPath.section == 1 {
            let sensor =  sensors[indexPath.row]
            cell.title.text  = sensor.title
            cell.showIcon()
            cell.showSyncProgress()
            cell.icon.image  = sensor.icon?.withRenderingMode(.alwaysTemplate)

            if (sensorManager.isExist(sensor.identifier)){
                cell.icon.tintColor = .systemBlue
                let latestData = sensorManager.getLatestSensorValue(sensor.identifier)
                if let data = latestData {
                    cell.detail.text = data
                }
                cell.progress.progress = sensor.syncProgress

            } else {
                cell.icon.tintColor = .dynamicColor(light: .black, dark: .white)
                cell.detail.text = sensor.details
                cell.hideSyncProgress()
            }
            
            cell.setSyncStatus(sensor.syncStatus)
        }
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // return sections.count
        switch AWAREStudy.shared().getUIMode(){
        case AwareUIModeNormal:
            return sections.count
        case AwareUIModeHideSettings:
            return 1
        case AwareUIModeHideAll:
            return 0
        case AwareUIModeHideSensors:
            return 1
        default:
            return sections.count
        }
    }

}

extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let setting = settings[indexPath.row]
            switch setting.identifier {
            case TableRowIdentifier.studyId.rawValue:
                showAlertForSettingStudyId()
                break
            case TableRowIdentifier.deviceId.rawValue:
                let deviceId = AWAREStudy.shared().getDeviceId()
                let activityVC = UIActivityViewController(activityItems: [deviceId], applicationActivities: nil)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    activityVC.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)?.contentView
                    activityVC.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.down
                }
                self.present(activityVC, animated: true, completion: nil)
                break
            case TableRowIdentifier.deviceName.rawValue:
                showAlertForSettingDeviceName()
                break
            case TableRowIdentifier.advancedSettings.rawValue:
                self.performSegue(withIdentifier: "toAdvancedSettings", sender: self)
                break
            default:
                break
            }
        } else if indexPath.section == 1 {
            self.selectedRowContent = sensors[indexPath.row]
            self.performSegue(withIdentifier: "toSensorSetting", sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
}

extension ViewController {
    func showReloadCompletionAlert() {
        let study = AWAREStudy.shared()
        let alert = UIAlertController(title: "Completed reloading the study configuration from AWARE server.",
                                      message: study.getURL(),
                                      preferredStyle: .alert)
        let close = UIAlertAction(title: NSLocalizedString("Close", comment: ""),
                                   style: .default,
                                   handler: { (action) in
                                    for sensor in self.sensors {
                                        sensor.syncProgress = 0
                                        sensor.syncStatus = .unknown
                                    }
        })
        alert.addAction(close)
        self.present(alert, animated: true, completion: nil)
    }
    
    func startManualUpload() {
        let manager = AWARESensorManager.shared()
        
        let callback = { (sensorName: String?, syncState: AwareStorageSyncProgress, progress: Double, error: Error?) -> Void in
            DispatchQueue.main.async {
                var flag = false
                
                for sensor in self.sensors {
                    let name = sensor.identifier
                    if name == sensorName! {
                        flag = true
                    } else if name == "location_gps" || name == "google_fused_location" {
                        if sensorName! == "locations" {
                            flag = true
                        }
                    } else if name == "health_kit" {
                        if sensorName! == "\(SENSOR_HEALTH_KIT)_heartrate" {
                            flag = true
                            print(sensorName!)
                        }
                    }
                    
                    if flag {
                        sensor.syncProgress = Float(progress)
                        if syncState == .complete {
                            sensor.syncStatus = .done
                        } else if syncState == .error {
                            sensor.syncStatus = .error
                        } else if (syncState == .locked || syncState == .unknown) {
                            sensor.syncStatus = .unknown
                        } else {
                            sensor.syncStatus = .syncing
                        }
                        
                        if let _ = error {
                            sensor.syncStatus = .error
                        }
                        if name == "location_gps" || name == "google_fused_location" {
                            flag = false
                            continue
                        } else if name == "\(SENSOR_HEALTH_KIT)_heartrate" {
                            flag = false
                            continue
                        } else {
                            break
                        }
                    }
                }
                
                // completion check
                var complete = true
                for sensor in self.sensors {
                    if manager.isExist(sensor.identifier) {
                        if sensor.syncProgress < 1 {
                            complete = false
                            break
                        }
                    }
                }
                
                if complete {
                    let alert = UIAlertController(title: NSLocalizedString("setting_view_upload_comp_title", comment: ""),
                                                  message: nil,
                                                  preferredStyle: .alert)
                    let close = UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .default, handler: { (action) in
                        for sensor in self.sensors {
                            sensor.syncProgress = 0
                            sensor.syncStatus = .unknown
                        }
                    })
                    alert.addAction(close)
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
        // set callback into each sensor storage
        for sensor in manager.getAllSensors() {
            if let storage = sensor.storage {
                storage.syncProcessCallback = callback
            }
        }
        
        for sensor in self.sensors {
            sensor.syncProgress = 0
            sensor.syncStatus = .syncing
        }
        manager.syncAllSensorsForcefully()
    }
}

extension UIViewController {
    func showAlertForSettingStudyId() {
        let alert = UIAlertController(title: "Study URL", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "https://url.for.aware.server"
            textField.clearButtonMode = .whileEditing
            textField.text = AWAREStudy.shared().getURL()
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Update", comment: ""), style: .default) { (action) in
            if let textFields = alert.textFields {
                if textFields.count > 0 {
                    if let textField = textFields.first {
                        if let text = textField.text {
                            let study = AWAREStudy.shared()
                            study.setStudyURL(text)
                            study.join(withURL: text, completion: { (settings, study, error) in
                                let sensorManager = AWARESensorManager.shared()
                                sensorManager.addSensors(with: AWAREStudy.shared())
                                sensorManager.createDBTablesOnAwareServer()
                                sensorManager.startAllSensors()
                            })
                        }
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: {})
    }
    
    func showAlertForSettingDeviceName() {
        let alert = UIAlertController(title: NSLocalizedString("device_name", comment: ""),
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addTextField { textField in
            textField.clearButtonMode = .whileEditing
            textField.text = AWAREStudy.shared().getDeviceName()
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Update", comment: ""), style: .default) { (action) in
            if let textFields = alert.textFields {
                if textFields.count > 0 {
                    if let textField = textFields.first {
                        if let text = textField.text {
                            let study = AWAREStudy.shared()
                            study.setDeviceName(text)
                            study.refreshStudySettings()
                        }
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: {})
    }
}

class TableRowContent {
    let identifier: String
    var height: CGFloat = 60
    let icon: UIImage?
    var title: String
    var details: String
    let type: TableRowType
    var syncProgress: Float = 0
    var syncStatus: SyncStatus = .unknown
    
    init(type: TableRowType,
         title: String = "",
         details: String = "",
         identifier: String = "",
         icon: UIImage? = nil) {
        self.type = type
        self.title = title
        self.details = details
        self.identifier = identifier
        self.icon = icon
    }
}

enum TableRowType {
    case sensor
    case setting
}

enum TableRowIdentifier: String {
    case studyId = "STUDY_URL"
    case deviceId = "DEVICE_ID"
    case deviceName = "DEVICE_NAME"
    case advancedSettings = "ADVANCED_SETTINGS"
}

extension UIColor {
    public class func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13, *) {
            return UIColor { (traitCollection) -> UIColor in
                if traitCollection.userInterfaceStyle == .dark {
                    return dark
                } else {
                    return light
                }
            }
        }
        return light
    }
}

public class Language {
    
    fileprivate func get() -> String {
        let languages = NSLocale.preferredLanguages
        if let type = languages.first {
            return type
        }
        return ""
    }
    
    func isJapanese() -> Bool {
        return self.get().contains("ja")
    }
    
    func isEnglish() -> Bool {
        return self.get().contains("en")
    }
}
