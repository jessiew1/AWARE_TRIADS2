import UIKit
import CoreLocation

struct LocationManagerWrapper {
    static var locationManager: CLLocationManager?
    static var currentViewController: UIViewController?
}

struct GeofenceLocation {
    var coordinate: CLLocationCoordinate2D
    var identifier: String
}

func setupLocationManager() {
    print ("---GeoFence Called! ----")
    LocationManagerWrapper.locationManager = CLLocationManager()
    LocationManagerWrapper.locationManager?.delegate = locationDelegateInstance
    LocationManagerWrapper.locationManager?.requestWhenInUseAuthorization()
}

let locationDelegateInstance: CLLocationManagerDelegate = {
    let delegate = LocationDelegate()
    return delegate
}()

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            switch manager.authorizationStatus {
            case .notDetermined:
                print("User has not yet made a choice regarding whether the app can use location services.")
            case .restricted:
                print("The app is not authorized to use location services.")
            case .denied:
                print("The user explicitly denied the use of location services for this app or location services are currently disabled in Settings.")
            case .authorizedAlways, .authorizedWhenInUse:
                setupGeofencing()
            @unknown default:
                print("A new authorization status was added that is not handled")
            }
        } else {
            // Handle older iOS versions
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined, .authorizedWhenInUse:
                print("User has not yet made a choice or has granted authorization to use their location only when the app is in use.")
            case .restricted, .denied:
                print("The app is not authorized to use location services.")
            case .authorizedAlways:
                setupGeofencing()
            @unknown default:
                print("A new authorization status was added that is not handled")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion else {
            return
        }
        showAlert(message: "User entered \(region.identifier)")
        showSurvey2()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion else {
            return
        }
        showAlert(message: "User left \(region.identifier)")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let region = region {
            print("Failed to monitor region with identifier: \(region.identifier), error: \(error)")
        } else {
            print("Failed to monitor region, error: \(error)")
        }
    }
}

func showSurvey2() {
    if surveysTaken < maxSurveysPerDay {
        if let surveyURL = URL(string: "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk") {
            DispatchQueue.main.async {
                UIApplication.shared.open(surveyURL, options: [:]) { success in
                    if success {
                        surveysTaken += 1
                        showSurveyTriggeredNotification()
                    } else {
                        print("Failed to open survey URL.")
                    }
                }
            }
        }
    } else {
        print("You've reached the maximum surveys for today.")
    }
}


@available(iOS 14.0, *)
func setupGeofencing() {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
        showAlert(message: "Geofencing is not supported on this device")
        return
    }
    guard LocationManagerWrapper.locationManager?.authorizationStatus == .authorizedAlways else {
        showAlert(message: "App does not have the correct location authorization")
        return
    }
    
    let locations = [
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 8.653765, longitude: -90.329635), identifier: "Greg Tests"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.711358, longitude: -92.284333), identifier: "Capitol View/Stifft's Station"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.749435, longitude: -92.338972), identifier: "Chenal Valley"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.737459, longitude: -92.198972), identifier: "East Little Rock"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.736667, longitude: -92.27875), identifier: "The Heights and Hillcrest"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.674167, longitude: -92.233333), identifier: "Mabelvale"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.741833, longitude: -92.270556), identifier: "MacArthur Park District"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.737459, longitude: -92.260556), identifier: "Quapaw Quarter"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.731833, longitude: -92.260556), identifier: "South Main Residential Historic District (SoMa)"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.537459, longitude: -92.260556), identifier: "Alpine"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.787459, longitude: -92.260556), identifier: "Andover Square"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.711358, longitude: -92.260556), identifier: "Apple Gate"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.637459, longitude: -92.260556), identifier: "Big Rock"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.761358, longitude: -92.260556), identifier: "Birchwood"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.837459, longitude: -92.260556), identifier: "Breckenridge"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.791358, longitude: -92.260556), identifier: "Broadmoor"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.741358, longitude: -92.260556), identifier: "Brodie Creek"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.701358, longitude: -92.260556), identifier: "Briarwood"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.661358, longitude: -92.260556), identifier: "Cammack Village"),
        GeofenceLocation(coordinate: CLLocationCoordinate2D(latitude: 34.621358, longitude: -92.260556), identifier: "Candlewood")
    ]


    
    startMonitoring(locations: locations)
}

func startMonitoring(locations: [GeofenceLocation]) {
    for location in locations {
        let geofenceRegion = CLCircularRegion(center: location.coordinate, radius: 100, identifier: location.identifier)
        geofenceRegion.notifyOnEntry = true
        geofenceRegion.notifyOnExit = true
        LocationManagerWrapper.locationManager?.startMonitoring(for: geofenceRegion)
    }
}

func showAlert(message: String) {
    guard let currentViewController = LocationManagerWrapper.currentViewController else {
        print("Current view controller is not set")
        return
    }
    let alertController = UIAlertController(title: "Information", message: message, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
    currentViewController.present(alertController, animated: true, completion: nil)
}

func viewDidLoad() {
    setupLocationManager()
}
