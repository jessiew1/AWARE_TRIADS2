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
        if let fileURL = Bundle.main.url(forResource: "Neighborhoods", withExtension: "geojson") {
            self.neighborhoods = loadNeighborhoods(from: fileURL) ?? [:]
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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            lastKnownLocation = location.coordinate
        }
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
        let locationPoint = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        notificationSent = false
        var foundNeighborhood: String?
        if !notificationSent {
             self.reverseGeocodeAndHandleNeighborhood(latitude: latitude, longitude: longitude)
         }

        for (polygon, name) in neighborhoods {
            let coordinates = self.coordinates(for: polygon)
            if self.pointInPolygon(point: locationPoint, polygon: coordinates) {
                foundNeighborhood = name
                if currentNeighborhood != name {
                    stopTimer()
                    startTimer(neighborhood: name)
                }
                notificationSent = true
                break
            }
        }

        if foundNeighborhood == nil && currentNeighborhood != nil {
            stopTimer()
        }

        if !notificationSent {
            self.reverseGeocodeAndHandleNeighborhood(latitude: latitude, longitude: longitude)
          
        }
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
        print("User spent 5 minutes in \(neighborhood)")

        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Geofence Alert"
        notificationContent.body = "You spent 5 minutes in \(neighborhood)."
        notificationContent.sound = UNNotificationSound.default
        notificationContent.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]

        // Create the notification request
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)

        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }

    

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        if let startTime = startTime, let neighborhood = currentNeighborhood {
            let timeSpent = Int(Date().timeIntervalSince(startTime))
            let notificationText = "Total time spent in \(neighborhood): \(timeSpent) seconds"
            sendNotificationWithTitle("Time Spent", body: notificationText)
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

    private func reverseGeocodeAndHandleNeighborhood(latitude: Double, longitude: Double) {
        guard !notificationSent else { return }

        let location = CLLocation(latitude: latitude, longitude: longitude)

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, !self.notificationSent, error == nil, let placemark = placemarks?.first, let neighborhood = placemark.subLocality else {
                print("Error in reverse geocoding or neighborhood not found.")
                return
            }
            self.sendNotificationWithTitle("Entered New Neighborhood", body: "Welcome to \(neighborhood)")
            self.notificationSent = true
        }
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
                   type == "Polygon",
                   let coordinatesArray = geometry["coordinates"] as? [[[Double]]] {
                    
                    let polygon = coordinatesArray[0].map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
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
