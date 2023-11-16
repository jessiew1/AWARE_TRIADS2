//
//  Locs2.swift
//  aware-client-ios-v2
//
//  Created by JessieW on 11/10/23.
//  Copyright © 2023 Yuuki Nishiyama. All rights reserved.
//
// With respect to the other files, "Locs2.swift just test location detection - no connection with any specific location"
import CoreLocation
import UserNotifications
import MapKit
import GoogleMaps
import GooglePlaces


struct SurveyLocation {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let radius: CLLocationDistance
}

class GeofenceManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var surveyLocations: [SurveyLocation] = []
    var specialNeighborhoods: [String] = [] // Names of special neighborhoods

    override init() {
        super.init()
        locationManager.delegate = self
        checkLocationAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Less precise, more battery-efficient
    }

    private func checkLocationAuthorization() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization() // or requestAlwaysAuthorization()
        default:
            // Handle cases where permission is denied or restricted
            print("Location permissions are not granted.")
        }
    }

    func setupGeofences(surveyLocations: [SurveyLocation]) {
        // Consider dynamically managing geofences to stay within system limits
        self.surveyLocations = surveyLocations
        for location in surveyLocations {
            let geofenceRegion = CLCircularRegion(center: location.coordinate, radius: location.radius, identifier: location.name)
            geofenceRegion.notifyOnEntry = true
            geofenceRegion.notifyOnExit = true
            locationManager.startMonitoring(for: geofenceRegion)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let geoRegion = region as? CLCircularRegion {
            reverseGeocodeLocation(geoRegion.center) { [weak self] neighborhood in
                let isSpecial = self?.isSpecialNeighborhood(neighborhood) ?? false
                self?.sendNotification(for: geoRegion, event: "entered", isSpecial: isSpecial)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let geoRegion = region as? CLCircularRegion {
            reverseGeocodeLocation(geoRegion.center) { [weak self] neighborhood in
                let isSpecial = self?.isSpecialNeighborhood(neighborhood) ?? false
                self?.sendNotification(for: geoRegion, event: "exited", isSpecial: isSpecial)
            }
        }
    }

    private func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            completion(placemarks?.first?.subLocality)
        }
    }

    private func isSpecialNeighborhood(_ neighborhood: String?) -> Bool {
        guard let neighborhood = neighborhood else { return false }
        return specialNeighborhoods.contains(neighborhood)
    }

    private func sendNotification(for region: CLCircularRegion, event: String, isSpecial: Bool) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = isSpecial ? "Special Geofence Alert" : "Geofence Alert"
        notificationContent.body = "You have \(event) the geofence for \(region.identifier)."
        notificationContent.sound = .default

        let request = UNNotificationRequest(identifier: "\(region.identifier)_\(event)", content: notificationContent, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
