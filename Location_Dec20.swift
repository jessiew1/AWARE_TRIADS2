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
    private var lastNotificationTime: Date? // Track the last notification time

    override init() {
        super.init()
        setupLocationManager()

        if let fileURL = Bundle.main.url(forResource: "Neighborhoods-4", withExtension: "geojson") {
            self.neighborhoods = loadNeighborhoods(from: fileURL) ?? [:]
        } else {
            print("Failed to locate the 'Neighborhoods-4.geojson' file.")
        }
        countAndPrintNeighborhoodsInFile()
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
            handleLocationUpdate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

    private func getCurrentLocation() -> CLLocationCoordinate2D? {
        return lastKnownLocation
    }

    private func countAndPrintNeighborhoodsInFile() {
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

    func handleLocationUpdate(latitude: Double, longitude: Double) {
        let locationPoint = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        notificationSent = false
        var foundNeighborhood: String?

        for (polygon, name) in neighborhoods {
            if isPoint(locationPoint, insidePolygon: polygon) {
                foundNeighborhood = name
                if currentNeighborhood != name {
                    currentNeighborhood = name
                    lastKnownLocation = locationPoint
                    stopTimer()
                    startTimer(neighborhood: name)
                }
                break
            }
        }

        if foundNeighborhood == nil && currentNeighborhood != nil {
            stopTimer()
        }
    }

    private func isPoint(_ point: CLLocationCoordinate2D, insidePolygon polygon: MKPolygon) -> Bool {
        let polygonRenderer = MKPolygonRenderer(polygon: polygon)
        let mapPoint = MKMapPoint(point)
        let polygonViewPoint = polygonRenderer.point(for: mapPoint)

        return polygonRenderer.path.contains(polygonViewPoint)
    }

    private func startTimer(neighborhood: String) {
        currentNeighborhood = neighborhood
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            guard let strongSelf = self else { return }
            let timeSpent = Int(Date().timeIntervalSince(strongSelf.startTime ?? Date()))
            if timeSpent >= 300 {
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

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationContent, trigger: nil)

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
            //sendNotificationWithTitle("Time Spent", body: notificationText)
        }
        startTime = nil
        currentNeighborhood = nil
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
