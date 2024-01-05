import Foundation
import CoreLocation
import UserNotifications
import MapKit
import AWAREFramework

class LocationHandler: NSObject, CLLocationManagerDelegate {
    private var notificationSent = false
    private var geocoder = CLGeocoder()
    private var neighborhoods: [MKPolygon: String] = [:]
    private var currentNeighborhood: String?
    private var timer: Timer?
    private var startTime: Date?
    private var lastLocationCheckTime: Date?
    private var lastKnownLocation: CLLocationCoordinate2D?
    private var locationManager: CLLocationManager?
    private var lastNotificationTime: Date? //  Track the last notification time

    

    override init() {
        super.init()
        setupLocationManager()

        if let fileURL = Bundle.main.url(forResource: "Neighborhoods-4", withExtension: "geojson") {
            self.neighborhoods = loadNeighborhoods(from: fileURL) ?? [:]
        } else {
            print("Failed to locate the 'Neighborhoods-4.geojson' file.")
        }
        countAndPrintNeighborhoodsInFile()
        
        // Manually call handleLocationUpdate with hardcoded coordinates if needed
        // handleLocationUpdate(latitude: -30, longitude: 90)
    }

    

    
    func countAndPrintNeighborhoodsInFile() {
        if let fileURL = Bundle.main.url(forResource: "Neighborhoods-4", withExtension: "geojson") {
            do {
                let data = try Data(contentsOf: fileURL)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                guard let featureCollection = json as? [String: Any],
                      let features = featureCollection["features"] as? [[String: Any]] else {
                    print("Unable to parse the GeoJSON file.")
                    return
                }

                var neighborhoodCounts: [String: Int] = [:]

                for feature in features {
                    if let properties = feature["properties"] as? [String: Any],
                       let neighborhoodName = properties["NAMELSAD"] as? String {
                        neighborhoodCounts[neighborhoodName, default: 0] += 1
                    }
                }

                for (neighborhoodName, count) in neighborhoodCounts {
                    print("\(neighborhoodName): \(count)")
                }
            } catch {
                print("Error reading or parsing GeoJSON file: \(error)")
            }
        } else {
            print("Failed to locate the 'Neighborhoods-4.geojson' file.")
        }
    }

    
    
    private func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Breakpoint 1 (Section 3)
        if let location = locations.last {
            lastKnownLocation = location.coordinate
        }
    }
    
    
    
    func showCurrentLocationOnMap() {
        guard let currentLocation = getCurrentLocation() else { return }
        let mapViewController = MapViewController()
        mapViewController.centerMapOnLocation(location: CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude))
        
        // Presenting the map view controller
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            topController.present(mapViewController, animated: true, completion: nil)
        }
    }
    
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager?.distanceFilter = 10 // meters
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
    }



    private func getCurrentLocation() -> CLLocationCoordinate2D? {
        return lastKnownLocation
    }

    func startPeriodicLocationChecks() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkLocationChange()
        }
    }

    private func checkLocationChange() {
        guard let lastCheckTime = lastLocationCheckTime, let currentLocation = getCurrentLocation() else {
            lastLocationCheckTime = Date()
            return
        }

        if Date().timeIntervalSince(lastCheckTime) >= 10 {
            if hasLocationChanged(currentLocation) {
                handleLocationUpdate(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            }
            lastLocationCheckTime = Date()
        }
    }


    private func hasLocationChanged(_ newLocation: CLLocationCoordinate2D) -> Bool {
        guard let lastLocation = lastKnownLocation else {
            return true
        }

        let distance = CLLocation(latitude: newLocation.latitude, longitude: newLocation.longitude)
                     .distance(from: CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude))

        return distance > 10 // meters, adjust this threshold as needed
    }

    func handleLocationUpdate(latitude: Double, longitude: Double) {
        // Breakpoint 2 (Section 3)
        let locationPoint = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        notificationSent = false
        var foundNeighborhood: String?

        if !notificationSent {
            
        }

        for (polygon, name) in neighborhoods {
            //print("Checking if point is inside the neighborhood: \(name)")
            if isPoint(locationPoint, insidePolygon: polygon) {
                print("Found point inside the neighborhood: \(name)")
                foundNeighborhood = name
                if currentNeighborhood != name {
                    print("Current neighborhood (\(String(describing: currentNeighborhood))) is different from found neighborhood (\(name)). Updating neighborhood and restarting timer.")
                    stopTimer()
                    startTimer(neighborhood: name)
                } else {
                    print("Current neighborhood (\(String(describing: currentNeighborhood))) is the same as found neighborhood (\(name)). No need to update.")
                }
                notificationSent = true
                break
            } else {
                //print("Point is not in the neighborhood: \(name)")
            }
        }

        if foundNeighborhood == nil && currentNeighborhood != nil {
            stopTimer()
        }

        if !notificationSent {
           
        }
    }


    // New method to check if a point is inside a polygon using MKPolygonRenderer
    private func isPoint(_ point: CLLocationCoordinate2D, insidePolygon polygon: MKPolygon) -> Bool {
        let polygonRenderer = MKPolygonRenderer(polygon: polygon)
        let mapPoint = MKMapPoint(point)
        let polygonViewPoint = polygonRenderer.point(for: mapPoint)

        let isInside = polygonRenderer.path.contains(polygonViewPoint)
        print("Point \(point) is \(isInside ? "inside" : "outside") the polygon.")
        return isInside
    }

    private func startTimer(neighborhood: String) {
        currentNeighborhood = neighborhood
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            guard let strongSelf = self else { return }
            let timeSpent = Int(Date().timeIntervalSince(strongSelf.startTime ?? Date()))
            print("Time spent in \(neighborhood): \(timeSpent) seconds")

            if timeSpent >= 300 { // 5 minutes = 300 seconds
                strongSelf.timer?.invalidate()
                strongSelf.timer = nil
                strongSelf.handleFiveMinutesStay(neighborhood: neighborhood)
            }
        }
    }


    private func handleFiveMinutesStay(neighborhood: String) {
        let notificationContent = createNotificationContent(neighborhood: neighborhood)
        let notificationIdentifier = UUID().uuidString

        // Schedule the initial notification
        scheduleNotification(content: notificationContent, identifier: notificationIdentifier, delay: 0)

        // Schedule the reminder notification, to be sent after 5 minutes
        let reminderContent = createNotificationContent(neighborhood: neighborhood, isReminder: true)
        scheduleNotification(content: reminderContent, identifier: "\(notificationIdentifier)-reminder", delay: 300)
    }

    private func createNotificationContent(neighborhood: String, isReminder: Bool = false) -> UNMutableNotificationContent {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = isReminder ? "Reminder: Geofence Alert" : "Geofence Alert"
        notificationContent.body = "You spent 5 minutes in \(neighborhood)." + (isReminder ? " Please check it out." : "")
        notificationContent.sound = UNNotificationSound.default
        notificationContent.userInfo = ["notification_id": neighborhood, "is_reminder": isReminder]
        return notificationContent
    }

    private func scheduleNotification(content: UNMutableNotificationContent, identifier: String, delay: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let isReminder = userInfo["is_reminder"] as? Bool, !isReminder,
           let notificationId = userInfo["notification_id"] as? String {
            // Cancel the reminder notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["\(notificationId)-reminder"])
        }
        completionHandler()
    }

    
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        if let startTime = startTime, let neighborhood = currentNeighborhood {
            let timeSpent = Int(Date().timeIntervalSince(startTime))
            let notificationText = "Total time spent in \(neighborhood): \(timeSpent) seconds"
            //sendNotificationWithTitle("Time Spent", body: notificationText)
        }
        startTime = nil
        currentNeighborhood = nil
    }

    private func sendNotificationWithTitle(_ title: String, body: String) {
        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        notificationCenter.add(request)
    }


    
  
    // New method to check if it's okay to send a notification
       private func canSendNotification() -> Bool {
           guard let lastNotificationTime = lastNotificationTime else {
               return true // No notification has been sent yet
           }
           // Only send a new notification if at least 60 seconds have passed
           return Date().timeIntervalSince(lastNotificationTime) > 60
       }

    
    
    private func loadNeighborhoods(from fileURL: URL) -> [MKPolygon: String]? {
        do {
            let data = try Data(contentsOf: fileURL)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard let featureCollection = json as? [String: Any],
                  let features = featureCollection["features"] as? [[String: Any]] else {
                return nil
            }
            
            var neighborhoods = [MKPolygon: String]()
            
            for feature in features {
                    if let properties = feature["properties"] as? [String: Any],
                      let neighborhoodName = properties["NAMELSAD"] as? String,
                      let geometry = feature["geometry"] as? [String: Any],
                      let type = geometry["type"] as? String,
                      type == "MultiPolygon",
                      let coordinatesArray = geometry["coordinates"] as? [[[[Double]]]] {
                      let polygon = coordinatesArray[0][0].map {
                        CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                        }
                      let mkPolygon = MKPolygon(coordinates: polygon, count: polygon.count)
                      neighborhoods[mkPolygon] = neighborhoodName
                    }
                  }
            return neighborhoods
        } catch {
            print("Error reading or parsing GeoJSON file: \(error)")
            return nil
        }
    }

    private func pointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        let x = point.longitude
        let y = point.latitude
        var isInside = false
        var i = 0
        var j = polygon.count - 1

        while i < polygon.count {
            let xi = polygon[i].longitude, yi = polygon[i].latitude
            let xj = polygon[j].longitude, yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            if intersect {
                isInside = !isInside
            }
            print (intersect)
            j = i
            i += 1
        }
        return isInside
    }

    private func coordinates(for polygon: MKPolygon) -> [CLLocationCoordinate2D] {
        let points = polygon.points()
        let pointCount = polygon.pointCount

        var coordinates = [CLLocationCoordinate2D]()
        for i in 0..<pointCount {
            let mapPoint = points[i]
            let coordinate = mapPoint.coordinate
            coordinates.append(coordinate)
        }
        print ("Coordinates", coordinates )
        return coordinates
    }
}

// Initialize AWARE Framework components
func initializeAWAREFrameworkComponents() {
    let locationHandler = LocationHandler()
    let core = AWARECore.shared()
    let study = AWAREStudy.shared()
    let manager = AWARESensorManager.shared()

    core.requestPermissionForPushNotification { (notifState, error) in
        core.requestPermissionForBackgroundSensing { (locState) in
            let fusedLocation = FusedLocations(awareStudy: study)
            manager.add(fusedLocation)
            fusedLocation.setSensorEventHandler { (sensor, data) in
                if let longitude = data?["double_longitude"] as? Double,
                   let latitude = data?["double_latitude"] as? Double {
                    locationHandler.handleLocationUpdate(latitude: latitude, longitude: longitude)
                }
            }
            fusedLocation.saveAll = true
            fusedLocation.startSensor()
        }
    }
    AWAREStatusMonitor.shared().activate(withCheckInterval: 10)
}
