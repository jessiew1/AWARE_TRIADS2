//  LocationsTracking.swift
//  aware-client-ios-v2
//
//  Created by JessieW on 11/2/23.
//  Copyright © 2023 Yuuki Nishiyama. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import AWAREFramework
import CoreLocation


// Define these properties at the class or struct level where they can be accessed by your methods
var surveysTaken = 0 // Assuming we start at 0 and increment with each survey taken
let maxSurveysPerDay = 5 // Set this to whatever the maximum number of daily surveys should be

// ...

func initializeAWAREFramework() {
    let core = AWARECore.shared()
    let study = AWAREStudy.shared()
    let manager = AWARESensorManager.shared()
    
   
        setupSensors(study: study, manager: manager)
    
    AWAREStatusMonitor.shared().activate(withCheckInterval: 60)
}



func setupSensors(study: AWAREStudy, manager: AWARESensorManager) {
    let fusedLocation = FusedLocations(awareStudy: study)
    manager.add(fusedLocation)
    fusedLocation.setSensorEventHandler { (sensor, data) in
        if let data = data {
            let currentLongitude = data["double_longitude"] ?? 0.0
            let currentLatitude = data["double_latitude"] ?? 0.0
            let currentLocation = CLLocation(latitude: currentLatitude as! CLLocationDegrees, longitude: currentLongitude as! CLLocationDegrees)
            
            // Print the current latitude, longitude, and location object
            print("Current Latitude: \(currentLatitude)")
            print("Current Longitude: \(currentLongitude)")
            print("Current Location: \(currentLocation)")
            
            let locations = [
                "Greg's Test": CLLocation(latitude: 38.653765, longitude: -90.329635),
                "Capitol View/Stifft's Station": CLLocation(latitude: 34.711358, longitude: -92.284333),
                "Chenal Valley": CLLocation(latitude: 34.749435, longitude: -92.338972),
                "East Little Rock": CLLocation(latitude: 34.737459, longitude: -92.198972),
                "Governor's Mansion District": CLLocation(latitude: 34.741833, longitude: -92.287056),
                "The Heights and Hillcrest": CLLocation(latitude: 34.736667, longitude: -92.27875),
                "Mabelvale": CLLocation(latitude: 34.674167, longitude: -92.233333),
                "MacArthur Park District": CLLocation(latitude: 34.741833, longitude: -92.270556),
                "Quapaw Quarter": CLLocation(latitude: 34.737459, longitude: -92.260556),
                "South Main Residential Historic District (SoMa)": CLLocation(latitude: 34.731833, longitude: -92.260556),
                "Alpine": CLLocation(latitude: 34.537459, longitude: -92.260556),
                "Andover Square": CLLocation(latitude: 34.787459, longitude: -92.260556),
                "Apple Gate": CLLocation(latitude: 34.711358, longitude: -92.260556),
                "Big Rock": CLLocation(latitude: 34.637459, longitude: -92.260556),
                "Birchwood": CLLocation(latitude: 34.761358, longitude: -92.260556),
                "Breckenridge": CLLocation(latitude: 34.837459, longitude: -92.260556),
                "Broadmoor": CLLocation(latitude: 34.791358, longitude: -92.260556),
                "Brodie Creek": CLLocation(latitude: 34.741358, longitude: -92.260556),
                "Briarwood": CLLocation(latitude: 34.701358, longitude: -92.260556),
                "Cammack Village": CLLocation(latitude: 34.661358, longitude: -92.260556),
                "Candlewood": CLLocation(latitude: 34.621358, longitude: -92.260556),
                "Capitol Hill": CLLocation(latitude: 34.587459, longitude: -92.260556),
                "Carmel": CLLocation(latitude: 34.957459, longitude: -92.260556),
                "Central High School Neighborhood Historic District": CLLocation(latitude: 34.741833, longitude: -92.270556),
                "Cherry Creek": CLLocation(latitude: 34.861358, longitude: -92.260556),
                "Chenal Ridge": CLLocation(latitude: 34.749435, longitude: -92.338972),
                "Cloverdale": CLLocation(latitude: 34.611358, longitude: -92.260556),
                "College Station": CLLocation(latitude: 34.571358, longitude: -92.260556),
                "Colony West": CLLocation(latitude: 34.787459, longitude: -92.260556),
                "Southwest City": CLLocation(latitude: 38.472862, longitude: -90.318372),
                "The Hamptons": CLLocation(latitude: 38.611335, longitude: -90.256369),
                "The Hill-Dogtown": CLLocation(latitude: 38.606173, longitude: -90.243923),
                "Garden District": CLLocation(latitude: 38.611673, longitude: -90.217584),
                "Tower Grove": CLLocation(latitude: 38.623926, longitude: -90.242932),
                "Bevo / Morgan Ford": CLLocation(latitude: 38.590948, longitude: -90.203861),
                "Greater Dutchtown": CLLocation(latitude: 38.592052, longitude: -90.229491),
                "Cherokee Area": CLLocation(latitude: 38.603759, longitude: -90.217867),
                "Carondelet": CLLocation(latitude: 38.521467, longitude: -90.198677),
                "Soulard / Benton Park": CLLocation(latitude: 38.588157, longitude: -90.202904),
                "McKinley-Fox": CLLocation(latitude: 38.611827, longitude: -90.263316),
                "Midtown": CLLocation(latitude: 38.607459, longitude: -90.218887),
                "Lafayette Square / Near South Side": CLLocation(latitude: 38.613586, longitude: -90.225195),
                "Downtown": CLLocation(latitude: 38.627273, longitude: -90.201901),
                "Upper West End": CLLocation(latitude: 38.644326, longitude: -90.210615),
                "West End / Forest Park": CLLocation(latitude: 38.636519, longitude: -90.251599),
                "Central West End / Grove": CLLocation(latitude: 38.631651, longitude: -90.217256),
                "Greater Ville": CLLocation(latitude: 38.628684, longitude: -90.231062),
                "Near North Side": CLLocation(latitude: 38.640019, longitude: -90.225195),
                "Fairgrounds / O'Fallon": CLLocation(latitude: 38.641044, longitude: -90.208477),
                "Old North / Hyde Park": CLLocation(latitude: 38.663722, longitude: -90.216283),
                "North Kingshighway / Penrose": CLLocation(latitude: 38.670546, longitude: -90.204293),
                "Wells-Goodfellow": CLLocation(latitude: 38.677104, longitude: -90.224541),
                "Walnut Park / Cemeteries": CLLocation(latitude: 38.664553, longitude: -90.251599),
                "Baden / North Riverfront": CLLocation(latitude: 38.660274, longitude: -90.201901)
            ]

            for (locationName, location) in locations {
                if currentLocation.distance(from: location) < 100 { // distance in meters
                    sendNotification(for: locationName)
                    showSurvey3()
                    break // Remove this if you want to check for multiple locations at once
                }
            }
        }
    }
    fusedLocation.saveAll = true
    fusedLocation.startSensor()
}

func showSurvey3() {
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


// Define the showSurveyTriggeredNotification method
func showSurveyTriggeredNotification() {
    // Implement the logic for showing a notification when a survey is triggered
    // This could be a local notification or an update to the UI
    // For example, using UNUserNotificationCenter to schedule a local notification
    let content = UNMutableNotificationContent()
    content.title = "Survey Triggered"
    content.body = "A new survey is available for you."
    content.sound = .default

    // Create the request
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

    // Add the request to the UNUserNotificationCenter
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error adding notification request: \(error)")
        }
    }
}


func sendNotification(for locationName: String) {
    // Implement the notification logic here
    // For example, using UNUserNotificationCenter to schedule a local notification
    let content = UNMutableNotificationContent()
    content.title = "Location Match"
    content.body = "You are at \(locationName)"
    content.sound = .default
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error scheduling notification: \(error)")
        }
    }
}
