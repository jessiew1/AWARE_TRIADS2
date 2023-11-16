//As of Version 2.1 Build 5, this is the driving file for the location tests
//The major thing here is the definition of targetAddress (line 18)
//which is the center of Danforth Campus at WashU
//around this address, we start a 25 mile radius and grab any sublocalities when the
//gps location is updated
import CoreLocation
import UserNotifications
import MapKit

private var entryTimes: [String: Date] = [:]

struct SurveyLocation {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let radius: CLLocationDistance
}

class GeofenceManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var surveyLocations: [SurveyLocation] = []
    private let targetAddress = "6475 Forsyth Blvd, St. Louis, MO 63105"
    private let targetRadius: CLLocationDistance = 40233.6 // 25 miles in meters

    override init() {
        super.init()
        locationManager.delegate = self
        configureUserNotifications()
        configureLocationManager()
        setupInitialGeofence()
    }

    private func configureUserNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted.")
            } else if let error = error {
                print("Notification permissions not granted with error: \(error.localizedDescription)")
            }
        }
    }

    private func configureLocationManager() {
        locationManager.requestAlwaysAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
    }

    private func setupInitialGeofence() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(targetAddress) { [weak self] (placemarks, error) in
            guard let strongSelf = self, let placemark = placemarks?.first, let location = placemark.location else {
                print("Geocoding failed: \(error?.localizedDescription ?? "No error description")")
                return
            }

            let surveyLocation = SurveyLocation(name: "Target Area", coordinate: location.coordinate, radius: strongSelf.targetRadius)
            strongSelf.setupGeofences(surveyLocations: [surveyLocation])
        }
    }

    func setupGeofences(surveyLocations: [SurveyLocation]) {
        self.surveyLocations = surveyLocations
        for location in surveyLocations {
            let geofenceRegion = CLCircularRegion(center: location.coordinate, radius: location.radius, identifier: location.name)
            geofenceRegion.notifyOnEntry = true
            geofenceRegion.notifyOnExit = true

            guard CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways else {
                print("Location permissions are not adequate to start geofence monitoring.")
                return
            }

            if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
                locationManager.startMonitoring(for: geofenceRegion)
            } else {
                print("Geofencing is not supported on this device.")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.first else { return }
        determineNeighborhood(from: currentLocation)
    }

    private func determineNeighborhood(from location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let strongSelf = self, let placemark = placemarks?.first, error == nil else {
                print("Reverse geocoding failed: \(error?.localizedDescription ?? "No error description")")
                return
            }

            if let neighborhood = placemark.subLocality {
                let newSurveyLocation = SurveyLocation(name: neighborhood, coordinate: location.coordinate, radius: 1000) // radius can be set as needed
                strongSelf.surveyLocations.append(newSurveyLocation)
                strongSelf.setupGeofences(surveyLocations: [newSurveyLocation])
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let geoRegion = region as? CLCircularRegion {
            entryTimes[geoRegion.identifier] = Date()
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let geoRegion = region as? CLCircularRegion, let entryTime = entryTimes[geoRegion.identifier] {
            let timeSpent = Date().timeIntervalSince(entryTime)
            if timeSpent >= 300 { // 300 seconds = 5 minutes
                sendNotification(for: geoRegion.identifier, event: "exited")
            }
            entryTimes.removeValue(forKey: geoRegion.identifier)
        }
    }


    private func sendNotification(for neighborhood: String, event: String) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Geofence Alert"
        notificationContent.body = "You spent at least 5 minutes in \(neighborhood)."
        notificationContent.sound = .default
        notificationContent.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let uniqueIdentifier = "\(neighborhood)_\(event)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: uniqueIdentifier, content: notificationContent, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
