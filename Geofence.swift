import UIKit
import SafariServices
import CoreData
import AWAREFramework
import Foundation
import UserNotifications
import CoreLocation

public func FindLocations(viewController: UIViewController) {
    let core = AWARECore.shared()
    let study = AWAREStudy.shared()
    let manager = AWARESensorManager.shared()
    let locationManager = CLLocationManager()
    var surveyCount = 0
    var lastResetDate: Date?
    
    locationManager.delegate = viewController as? CLLocationManagerDelegate
    locationManager.requestAlwaysAuthorization()
    
    // Request permission for push notifications
    core.requestPermissionForPushNotification { (notifGranted, error) in
        if notifGranted {
            // Manually check location services authorization status
            let locStatus = CLLocationManager.authorizationStatus()
            switch locStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                // Initialize the sensor
                let fusedLocation = FusedLocations(awareStudy: study)
                
                // Configure the location sensor for continuous updates
                fusedLocation.distanceFilter = Int32(kCLDistanceFilterNone)
                
                manager.add(fusedLocation)
                
                // Set the event handler for location updates
                fusedLocation.setSensorEventHandler { (sensor, data) in
                    if let data = data,
                       let latitude = data["double_latitude"] as? Double,
                       let longitude = data["double_longitude"] as? Double {
                        
                        let location = CLLocation(latitude: latitude, longitude: longitude)
                        let geocoder = CLGeocoder()
                        
                        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                            if let placemark = placemarks?.first {
                                var addressString = ""
                                
                                if let subThoroughfare = placemark.subThoroughfare {
                                    addressString += subThoroughfare + " "
                                }
                                if let thoroughfare = placemark.thoroughfare {
                                    addressString += thoroughfare + ", "
                                }
                                if let locality = placemark.locality {
                                    addressString += locality + ", "
                                }
                                if let administrativeArea = placemark.administrativeArea {
                                    addressString += administrativeArea + ", "
                                }
                                if let postalCode = placemark.postalCode {
                                    addressString += postalCode + ", "
                                }
                                if let country = placemark.country {
                                    addressString += country
                                }
                                
                                // Show a local notification with the current location
                                let content = UNMutableNotificationContent()
                                content.title = "Location Update"
                                content.body = "Your current location is: \(addressString)"
                                content.sound = UNNotificationSound.default
                                
                                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                                let request = UNNotificationRequest(identifier: "locationUpdate", content: content, trigger: trigger)
                                
                                UNUserNotificationCenter.current().add(request) { (error) in
                                    if let error = error {
                                        print("Error: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Set up and start monitoring the geofences for the provided locations
                let locations = [
                    // ... (previous locations)
                    ("Capitol View/Stifft's Station", CLLocationCoordinate2D(latitude: 34.711358, longitude: -92.284333), 100.0),
                    ("Chenal Valley", CLLocationCoordinate2D(latitude: 34.749435, longitude: -92.338972), 100.0),
                    ("East Little Rock", CLLocationCoordinate2D(latitude: 34.737459, longitude: -92.198972), 100.0),
                    ("Governor's Mansion District", CLLocationCoordinate2D(latitude: 34.741833, longitude: -92.287056), 100.0),
                    ("The Heights and Hillcrest", CLLocationCoordinate2D(latitude: 34.736667, longitude: -92.27875), 100.0),
                    ("Mabelvale", CLLocationCoordinate2D(latitude: 34.674167, longitude: -92.233333), 100.0),
                    ("MacArthur Park District", CLLocationCoordinate2D(latitude: 34.741833, longitude: -92.270556), 100.0),
                    ("Quapaw Quarter", CLLocationCoordinate2D(latitude: 34.737459, longitude: -92.260556), 100.0),
                    ("South Main Residential Historic District (SoMa)", CLLocationCoordinate2D(latitude: 34.731833, longitude: -92.260556), 100.0),
                    ("Alpine", CLLocationCoordinate2D(latitude: 34.537459, longitude: -92.260556), 100.0),
                    ("Andover Square", CLLocationCoordinate2D(latitude: 34.787459, longitude: -92.260556), 100.0),
                    ("Apple Gate", CLLocationCoordinate2D(latitude: 34.711358, longitude: -92.260556), 100.0),
                    ("Big Rock", CLLocationCoordinate2D(latitude: 34.637459, longitude: -92.260556), 100.0),
                    ("Birchwood", CLLocationCoordinate2D(latitude: 34.761358, longitude: -92.260556), 100.0),
                    ("Breckenridge", CLLocationCoordinate2D(latitude: 34.837459, longitude: -92.260556), 100.0),
                    ("Broadmoor", CLLocationCoordinate2D(latitude: 34.791358, longitude: -92.260556), 100.0),
                    ("Brodie Creek", CLLocationCoordinate2D(latitude: 34.741358, longitude: -92.260556), 100.0),
                    ("Briarwood", CLLocationCoordinate2D(latitude: 34.701358, longitude: -92.260556), 100.0),
                    ("Cammack Village", CLLocationCoordinate2D(latitude: 34.661358, longitude: -92.260556), 100.0),
                    ("Candlewood", CLLocationCoordinate2D(latitude: 34.621358, longitude: -92.260556), 100.0),
                    ("Capitol Hill", CLLocationCoordinate2D(latitude: 34.587459, longitude: -92.260556), 100.0),
                    ("Carmel", CLLocationCoordinate2D(latitude: 34.957459, longitude: -92.260556), 100.0),
                    ("Central High School Neighborhood Historic District", CLLocationCoordinate2D(latitude: 34.741833, longitude: -92.270556), 100.0),
                    ("Cherry Creek", CLLocationCoordinate2D(latitude: 34.861358, longitude: -92.260556), 100.0),
                    ("Chenal Ridge", CLLocationCoordinate2D(latitude: 34.749435, longitude: -92.338972), 100.0),
                    ("Cloverdale", CLLocationCoordinate2D(latitude: 34.611358, longitude: -92.260556), 100.0),
                    ("College Station", CLLocationCoordinate2D(latitude: 34.571358, longitude: -92.260556), 100.0),
                    ("Colony West", CLLocationCoordinate2D(latitude: 34.787459, longitude: -92.260556), 100.0)
                ]

                
                for (name, coordinate, radius) in locations {
                    let geofenceRegion = CLCircularRegion(center: coordinate, radius: radius, identifier: name)
                    geofenceRegion.notifyOnEntry = true
                    geofenceRegion.notifyOnExit = true
                    locationManager.startMonitoring(for: geofenceRegion)
                }
                
            case .denied, .restricted:
                print("Location services are denied or restricted.")
            case .notDetermined:
                print("Location services authorization not determined.")
            @unknown default:
                print("Unknown location services authorization status.")
            }
        } else {
            print("Push notification permission denied.")
        }
    }
    
    // Activate the AWARE status monitor
    AWAREStatusMonitor.shared().activate(withCheckInterval: 60)
}

extension UIViewController: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            handleEvent(for: region, eventType: "Entered")
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLCircularRegion {
            handleEvent(for: region, eventType: "Exited")
        }
    }
    
    private func handleEvent(for region: CLRegion, eventType: String) {
        // Your event handling logic here
        // You can trigger surveys or show notifications based on the event
    }
}

