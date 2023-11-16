import CoreLocation
import UserNotifications

struct GeoFenceManager {
    static let locationManager = CLLocationManager()
    static var lastProcessedLocation: CLLocation?
    static var lastShownAddress: String?
    static var surveyCount = 0
    static var lastResetDate: Date?
    static var geofenceRegions: [CLCircularRegion] = []
    static var lastThreeSurveyTimestamps: [Date] = []
 
    static func setupLocationManager() {
        locationManager.delegate = locationDelegate
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation() // Start receiving location updates
        
       
    }

    static func startMonitoringGeofences() {
        let locations = [
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
            ("Colony West", CLLocationCoordinate2D(latitude: 34.787459, longitude: -92.260556), 100.0),
            ("Southwest City", CLLocationCoordinate2D(latitude: 38.472862, longitude: -90.318372), 100.0),
            ("The Hamptons", CLLocationCoordinate2D(latitude: 38.611335, longitude: -90.256369), 100.0),
            ("The Hill-Dogtown", CLLocationCoordinate2D(latitude: 38.606173, longitude: -90.243923), 100.0),
            ("Garden District", CLLocationCoordinate2D(latitude: 38.611673, longitude: -90.217584), 100.0),
            ("Tower Grove", CLLocationCoordinate2D(latitude: 38.623926, longitude: -90.242932), 100.0),
            ("Bevo / Morgan Ford", CLLocationCoordinate2D(latitude: 38.590948, longitude: -90.203861), 100.0),
            ("Greater Dutchtown", CLLocationCoordinate2D(latitude: 38.592052, longitude: -90.229491), 100.0),
            ("Cherokee Area", CLLocationCoordinate2D(latitude: 38.603759, longitude: -90.217867), 100.0),
            ("Carondelet", CLLocationCoordinate2D(latitude: 38.521467, longitude: -90.198677), 100.0),
            ("Soulard / Benton Park", CLLocationCoordinate2D(latitude: 38.588157, longitude: -90.202904), 100.0),
            ("McKinley-Fox", CLLocationCoordinate2D(latitude: 38.611827, longitude: -90.263316), 100.0),
            ("Midtown", CLLocationCoordinate2D(latitude: 38.607459, longitude: -90.218887), 100.0),
            ("Lafayette Square / Near South Side", CLLocationCoordinate2D(latitude: 38.613586, longitude: -90.225195), 100.0),
            ("Downtown", CLLocationCoordinate2D(latitude: 38.627273, longitude: -90.201901), 100.0),
            ("Upper West End", CLLocationCoordinate2D(latitude: 38.644326, longitude: -90.210615), 100.0),
            ("West End / Forest Park", CLLocationCoordinate2D(latitude: 38.636519, longitude: -90.251599), 100.0),
            ("Central West End / Grove", CLLocationCoordinate2D(latitude: 38.631651, longitude: -90.217256), 100.0),
            ("Greater Ville", CLLocationCoordinate2D(latitude: 38.628684, longitude: -90.231062), 100.0),
            ("Near North Side", CLLocationCoordinate2D(latitude: 38.640019, longitude: -90.225195), 100.0),
            ("Fairgrounds / O'Fallon", CLLocationCoordinate2D(latitude: 38.641044, longitude: -90.208477), 100.0),
            ("Old North / Hyde Park", CLLocationCoordinate2D(latitude: 38.663722, longitude: -90.216283), 100.0),
            ("North Kingshighway / Penrose", CLLocationCoordinate2D(latitude: 38.670546, longitude: -90.204293), 100.0),
            ("Wells-Goodfellow", CLLocationCoordinate2D(latitude: 38.677104, longitude: -90.224541), 100.0),
            ("Walnut Park / Cemeteries", CLLocationCoordinate2D(latitude: 38.664553, longitude: -90.251599), 100.0),
            ("Baden / North Riverfront", CLLocationCoordinate2D(latitude: 38.660274, longitude: -90.201901), 100.0),
            ("Wydown Skinker/Wash University- St. Louis", CLLocationCoordinate2D(latitude: 38.659618, longitude: -90.207198), 100.0)
            ]
    
        for (identifier, coordinate, radius) in locations {
            let geofenceRegion = CLCircularRegion(center: coordinate, radius: radius, identifier: identifier)
            geofenceRegion.notifyOnEntry = true
            geofenceRegion.notifyOnExit = true
            locationManager.startMonitoring(for: geofenceRegion)
            geofenceRegions.append(geofenceRegion)
        }
        
        sendTrackingNotification()
    }

    static func sendTrackingNotification() {
        guard let currentLocation = locationManager.location else {
            print("Current location is not available.")
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(currentLocation) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error)")
                return
            }
            
            let address = placemarks?.first?.formattedAddress ?? "Unknown location"
            let content = UNMutableNotificationContent()
            content.title = "Location Tracking"
            content.body = "Location tracking is now on. We will notify you when you enter or exit a geofenced area. Your current location is: \(address)"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }
    
    static func sendSurveyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "New Survey Available"
        content.body = "You have a new survey available. Tap to complete it."
        content.sound = .default
        content.userInfo = ["link": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        
        lastThreeSurveyTimestamps.append(Date())
        if lastThreeSurveyTimestamps.count > 3 {
            lastThreeSurveyTimestamps.removeFirst()
        }
    }
}

extension CLPlacemark {
    var formattedAddress: String {
        return [subThoroughfare, thoroughfare, locality, administrativeArea, country].compactMap { $0 }.joined(separator: ", ")
    }
}

let locationDelegate: CLLocationManagerDelegate = {
    class Delegate: NSObject, CLLocationManagerDelegate {
        func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
            if region is CLCircularRegion {
                // Check if the user has received 3 surveys in the last 24 hours
                let now = Date()
                GeoFenceManager.lastThreeSurveyTimestamps = GeoFenceManager.lastThreeSurveyTimestamps.filter { now.timeIntervalSince($0) < 24 * 60 * 60 }
                
                if GeoFenceManager.lastThreeSurveyTimestamps.count < 3 {
                    GeoFenceManager.sendSurveyNotification()
                }
            }
        }

   
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let currentLocation = locations.last else { return }
            if let lastLocation = GeoFenceManager.lastProcessedLocation, currentLocation.isEqual(lastLocation) {
                 // The current location is the same as the last processed location
                 print("Locations are the same, no need to process again.")
                 return
             }
             // Save the current location as the last processed location for future comparisons
             GeoFenceManager.lastProcessedLocation = currentLocation
             // Call your notification function here
              sendCurrentLocationNotification(location: currentLocation)
        }
        
        func sendCurrentLocationNotification(location: CLLocation) {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                if let error = error {
                    print("Geocoding error: \(error)")
                    return
                }
                
                if let placemark = placemarks?.first {
                                let address = placemark.formattedAddress
                                
                                if address != GeoFenceManager.lastShownAddress {
                                        // Update the last shown address
                                        GeoFenceManager.lastShownAddress = address
                                    let content = UNMutableNotificationContent()
                                    content.title = "Current Address"
                                    content.body = "Your current address is: \(address)"
                                    content.sound = .default
                                    
                                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                                } else {
                                    print("Address has not changed. No need to send a notification.")
                                }
                }
            }
        }
    }

    return Delegate()
}()
