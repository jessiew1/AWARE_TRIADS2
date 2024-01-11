//
//  Location.swift
//  aware-client-ios-v2
//
//  Created by Jessie Walker on 12/5/23.
//  Copyright © 2023 Yuuki Nishiyama. All rights reserved.
//

import Foundation
import CoreLocation
import UserNotifications
import MapKit


// A dictionary to keep track of when the user enters a geofence.
private var entryTimes: [String: Date] = [:]

// A structure to define a geofenced location with a name, coordinate, and radius.
struct SurveyLocation {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let radius: CLLocationDistance
}

// Class responsible for managing geofences.
class GeofenceManager: NSObject, CLLocationManagerDelegate {
    // Location manager for handling location services.
    private let locationManager = CLLocationManager()
    // Array to hold the locations we are monitoring.
    private var surveyLocations: [SurveyLocation] = []
    // The address to monitor.
    private let targetAddress = "217 W 15th St. Little Rock, AR 72202"
    // The radius for the geofence (25 miles in meters).
    private let targetRadius: CLLocationDistance = 40233.6

    // Initializer for the class.
    override init() {
        super.init()
        // Set the GeofenceManager as the delegate for the location manager.
        locationManager.delegate = self
        // Setup user notifications for the app.
        configureUserNotifications()
        // Configure the location manager with the necessary settings.
        configureLocationManager()
        // Setup the initial geofence based on the target address.
        setupInitialGeofence()
    }

    // Function to configure user notifications.
    private func configureUserNotifications() {
        // Request permission to show alerts and play sounds for notifications.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted.")
            } else if let error = error {
                print("Notification permissions not granted with error: \(error.localizedDescription)")
            }
        }
    }

    // Function to configure the location manager.
    private func configureLocationManager() {
        // Request permission to always access location.
        locationManager.requestAlwaysAuthorization()
        // Set the desired accuracy for location updates.
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Allow location updates to occur in the background.
        locationManager.allowsBackgroundLocationUpdates = true
        // Start updating the location.
        locationManager.startUpdatingLocation()
    }

    // Function to setup the initial geofence.
    private func setupInitialGeofence() {
        // Create a geocoder to convert an address to coordinates.
        let geocoder = CLGeocoder()
        // Convert the target address to geographic coordinates.
        geocoder.geocodeAddressString(targetAddress) { [weak self] (placemarks, error) in
            // Ensure self exists and we have valid placemark data.
            guard let strongSelf = self, let placemark = placemarks?.first, let location = placemark.location else {
                print("Geocoding failed: \(error?.localizedDescription ?? "No error description")")
                return
            }

            // Create a SurveyLocation for the target area.
            let surveyLocation = SurveyLocation(name: "Target Area", coordinate: location.coordinate, radius: strongSelf.targetRadius)
            // Setup geofences for the survey locations.
            strongSelf.setupGeofences(surveyLocations: [surveyLocation])
        }
    }

    // Function to setup geofences for given survey locations.
    func setupGeofences(surveyLocations: [SurveyLocation]) {
        // Update the class's surveyLocations property.
        self.surveyLocations = surveyLocations
        // Loop through each survey location.
        for location in surveyLocations {
            // Define a circular region for geofencing.
            let geofenceRegion = CLCircularRegion(center: location.coordinate, radius: location.radius, identifier: location.name)
            // Set the region to notify on entry and exit.
            geofenceRegion.notifyOnEntry = true
            geofenceRegion.notifyOnExit = true

            // Check if we have the necessary location permissions.
            guard CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways else {
                print("Location permissions are not adequate to start geofence monitoring.")
                return
            }

            // Start monitoring the geofence region if supported.
            if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
                locationManager.startMonitoring(for: geofenceRegion)
            } else {
                print("Geofencing is not supported on this device.")
            }
        }
    }

    // Called when the location manager receives new location data.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Ensure we have a valid current location.
        guard let currentLocation = locations.first else { return }
        // Determine the neighborhood for the current location.
        determineNeighborhood(from: currentLocation)
    }

    // Function to determine the neighborhood from a given location.
    private func determineNeighborhood(from location: CLLocation) {
        // Create a geocoder for reverse geocoding.
        let geocoder = CLGeocoder()
        // Perform reverse geocoding on the current location.
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            // Ensure self exists and we have valid placemark data.
            guard let strongSelf = self, let placemark = placemarks?.first, error == nil else {
                print("Reverse geocoding failed: \(error?.localizedDescription ?? "No error description")")
                return
            }

            // Check if we have a neighborhood name.
            if let neighborhood = placemark.subLocality {
                // Create a new SurveyLocation for the neighborhood.
                let newSurveyLocation = SurveyLocation(name: neighborhood, coordinate: location.coordinate, radius: 10000) // radius can be set as needed
                // Append the new location and setup its geofence.
                strongSelf.surveyLocations.append(newSurveyLocation)
                strongSelf.setupGeofences(surveyLocations: [newSurveyLocation])
            }
        }
    }

    // Called when the user enters a monitored geofence region.
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Check if the region is one of our geofences and record the entry time.
        if let geoRegion = region as? CLCircularRegion {
            entryTimes[geoRegion.identifier] = Date()
        }
    }

    // Called when the user exits a monitored geofence region.
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // Check if the region is one of our geofences and calculate the time spent inside.
        if let geoRegion = region as? CLCircularRegion, let entryTime = entryTimes[geoRegion.identifier] {
            // Calculate the time spent in the geofence.
            let timeSpent = Date().timeIntervalSince(entryTime)
            // If it's more than 5 minutes, prepare to send a notification.
            if timeSpent >= 30 { // 300 seconds = 5 minutes
                sendNotification(for: geoRegion.identifier, event: "exited")
            }
            // Remove the entry time record for this geofence.
            entryTimes.removeValue(forKey: geoRegion.identifier)
        }
    }

    // Function to send a notification.
    private func sendNotification(for neighborhood: String, event: String) {
        // Create content for the notification.
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Geofence Alert"
        notificationContent.body = "You spent at least 5 minutes in \(neighborhood)."
        notificationContent.sound = .default
        // Additional information for the notification.
        notificationContent.userInfo = ["deep_link_url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"]

        // Define when the notification should be triggered.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Unique identifier for the notification.
        let uniqueIdentifier = "\(neighborhood)_\(event)_\(Date().timeIntervalSince1970)"
        // Create the notification request.
        let request = UNNotificationRequest(identifier: uniqueIdentifier, content: notificationContent, trigger: trigger)
        // Add the notification request to the notification center.
        UNUserNotificationCenter.current().add(request) { error in
            // Check for errors when scheduling the notification.
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
