//
//  location2.swift
//  aware-client-ios-v2
//
//  Created by Jessie Walker on 12/7/23.
//  Copyright © 2023 Yuuki Nishiyama. All rights reserved.
//
import Foundation
import CoreLocation
import UserNotifications
import MapKit
import AWAREFramework

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
    private let targetRadius: CLLocationDistance = 40233.6
    private let geocoder = CLGeocoder() // Declare geocoder here
    
    
    override init() {
        super.init()
        locationManager.delegate = self
        configureUserNotifications()
        configureLocationManager()
        setupPredefinedGeofences()
    }

    private func configureUserNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if !granted, let error = error {
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

    private func setupPredefinedGeofences() {
        let predefinedGeofences = getPredefinedGeofences()
        setupGeofences(surveyLocations: predefinedGeofences)
    }

    private func getPredefinedGeofences() -> [SurveyLocation] {
        // Define your predefined geofences for neighborhoods in Little Rock
        return [
            SurveyLocation(name: "Franz Park", coordinate: CLLocationCoordinate2D(latitude: 38.62183617256886, longitude: -90.30462738898562), radius: 731.0033673732871),
               SurveyLocation(name: "Tiffany", coordinate: CLLocationCoordinate2D(latitude: 38.62173800181611, longitude: -90.24106741333935), radius: 534.493681700327),
               SurveyLocation(name: "Botanical Heights", coordinate: CLLocationCoordinate2D(latitude: 38.62216145052822, longitude: -90.24956937136528), radius: 749.8148166524709),
               SurveyLocation(name: "Kings Oak", coordinate: CLLocationCoordinate2D(latitude: 38.62700213513736, longitude: -90.2705694032149), radius: 477.9374541058416),
               SurveyLocation(name: "Cheltenham", coordinate: CLLocationCoordinate2D(latitude: 38.62677272396369, longitude: -90.28171824847033), radius: 669.8597475943295),
               SurveyLocation(name: "Clayton-Tamm", coordinate: CLLocationCoordinate2D(latitude: 38.62670638325297, longitude: -90.29263304790958), radius: 688.6335864028374),
               SurveyLocation(name: "Forest Park South East", coordinate: CLLocationCoordinate2D(latitude: 38.62624360559153, longitude: -90.25787304918818), radius: 934.573854764096),
               SurveyLocation(name: "Hi-Pointe", coordinate: CLLocationCoordinate2D(latitude: 38.62928219967572, longitude: -90.3028151181257), radius: 613.8298306707416),
               SurveyLocation(name: "Downtown West", coordinate: CLLocationCoordinate2D(latitude: 38.62874754593296, longitude: -90.20713727529956), radius: 1247.3852567616232),
               SurveyLocation(name: "Midtown", coordinate: CLLocationCoordinate2D(latitude: 38.63129324827648, longitude: -90.22883997153177), radius: 1352.757269879806),
               SurveyLocation(name: "Columbus Square", coordinate: CLLocationCoordinate2D(latitude: 38.63726428780851, longitude: -90.19045919373245), radius: 504.55670376958693),
               SurveyLocation(name: "Carr Square", coordinate: CLLocationCoordinate2D(latitude: 38.64015455444882, longitude: -90.20372768397884), radius: 745.914383605155),
               SurveyLocation(name: "Wydown Skinker", coordinate: CLLocationCoordinate2D(latitude: 38.64050235826928, longitude: -90.30381355144492), radius: 404.88438866391385),
               SurveyLocation(name: "Covenant Blu-Grand Center", coordinate: CLLocationCoordinate2D(latitude: 38.64245089328632, longitude: -90.2312153069833), radius: 875.4963178572524),
               SurveyLocation(name: "Central West End", coordinate: CLLocationCoordinate2D(latitude: 38.64164291702656, longitude: -90.25612906088627), radius: 1599.6845357634536),
               SurveyLocation(name: "Old North St. Louis", coordinate: CLLocationCoordinate2D(latitude: 38.64812410724008, longitude: -90.19508658932187), radius: 726.424073937901),
               SurveyLocation(name: "Vandeventer", coordinate: CLLocationCoordinate2D(latitude: 38.64993817788352, longitude: -90.24143416629367), radius: 800.7145780721002),
               SurveyLocation(name: "St. Louis Place", coordinate: CLLocationCoordinate2D(latitude: 38.64953442989835, longitude: -90.20571601835391), radius: 967.9274079772563),
               SurveyLocation(name: "Visitation Park", coordinate: CLLocationCoordinate2D(latitude: 38.656495451250926, longitude: -90.27567858333165), radius: 448.01399552525464),
               SurveyLocation(name: "Lewis Place", coordinate: CLLocationCoordinate2D(latitude: 38.65492124246923, longitude: -90.25214971004785), radius: 671.3685130140407),
               SurveyLocation(name: "Fountain Park", coordinate: CLLocationCoordinate2D(latitude: 38.65674376877091, longitude: -90.25969577284016), radius: 571.5790086060213),
               SurveyLocation(name: "Jeff Vanderlou", coordinate: CLLocationCoordinate2D(latitude: 38.65040997967013, longitude: -90.2201478622062), radius: 1299.9374602138741),
               SurveyLocation(name: "The Ville", coordinate: CLLocationCoordinate2D(latitude: 38.65902707281431, longitude: -90.2397062491055), radius: 749.3062981905315),
               SurveyLocation(name: "Academy", coordinate: CLLocationCoordinate2D(latitude: 38.65808450775611, longitude: -90.26732250993969), radius: 778.5428416801772),
               SurveyLocation(name: "Hyde Park", coordinate: CLLocationCoordinate2D(latitude: 38.66136692304574, longitude: -90.20361831852024), radius: 875.9167058510518),
               SurveyLocation(name: "Fairground Park", coordinate: CLLocationCoordinate2D(latitude: 38.66560352951051, longitude: -90.2215162311658), radius: 538.9571648446927),
               SurveyLocation(name: "West End", coordinate: CLLocationCoordinate2D(latitude: 38.66068048641784, longitude: -90.28735080571956), radius: 1162.4104012933103),
               SurveyLocation(name: "Greater Ville", coordinate: CLLocationCoordinate2D(latitude: 38.66326304058189, longitude: -90.23740063113816), radius: 1134.1992238057226),
               SurveyLocation(name: "Fairground Neighborhood", coordinate: CLLocationCoordinate2D(latitude: 38.66702742888759, longitude: -90.21480160332905), radius: 656.823188098053),
               SurveyLocation(name: "Hamilton Heights", coordinate: CLLocationCoordinate2D(latitude: 38.668233555899675, longitude: -90.27893452578664), radius: 813.6176832787091),
               SurveyLocation(name: "Kingsway East", coordinate: CLLocationCoordinate2D(latitude: 38.66817599023003, longitude: -90.25279174746164), radius: 810.6220221622045),
               SurveyLocation(name: "Kingsway West", coordinate: CLLocationCoordinate2D(latitude: 38.67110991228476, longitude: -90.2598079420942), radius: 753.3538098962664),
               SurveyLocation(name: "Patch", coordinate: CLLocationCoordinate2D(latitude: 38.54310813041989, longitude: -90.26183015718217), radius: 1133.7474004521891),
               SurveyLocation(name: "Carondelet Park", coordinate: CLLocationCoordinate2D(latitude: 38.56219131158208, longitude: -90.26440510661548), radius: 618.8396490917318),
               SurveyLocation(name: "Carondelet", coordinate: CLLocationCoordinate2D(latitude: 38.55835976445464, longitude: -90.25373004535206), radius: 1333.2567599247309),
               SurveyLocation(name: "Holly Hills", coordinate: CLLocationCoordinate2D(latitude: 38.568626177059286, longitude: -90.26081927313955), radius: 736.4275679496677),
               SurveyLocation(name: "Boulevard Heights", coordinate: CLLocationCoordinate2D(latitude: 38.561299346855556, longitude: -90.27927140251738), radius: 1485.2995985065008),
               SurveyLocation(name: "Mount Pleasant", coordinate: CLLocationCoordinate2D(latitude: 38.573230566402344, longitude: -90.23595741615638), radius: 887.6311520530899),
               SurveyLocation(name: "Princeton Heights", coordinate: CLLocationCoordinate2D(latitude: 38.575167216436284, longitude: -90.28721533488613), radius: 1059.89373652111),
               SurveyLocation(name: "St. Louis Hills", coordinate: CLLocationCoordinate2D(latitude: 38.58293174110251, longitude: -90.3018927509709), radius: 1262.995293062565),
               SurveyLocation(name: "Willmore Park", coordinate: CLLocationCoordinate2D(latitude: 38.572865247345696, longitude: -90.30380695573731), radius: 735.8780765985641),
            SurveyLocation(name: "Dutchtown", coordinate: CLLocationCoordinate2D(latitude: 38.58083031183201, longitude: -90.24547880623906), radius: 1430.0601288736013),
              SurveyLocation(name: "Bevo Mill", coordinate: CLLocationCoordinate2D(latitude: 38.5801948174387, longitude: -90.26721420211773), radius: 1359.5628162753278),
              SurveyLocation(name: "Southampton", coordinate: CLLocationCoordinate2D(latitude: 38.5873916648194, longitude: -90.28492497275971), radius: 973.0454701471547),
              SurveyLocation(name: "Marine Villa", coordinate: CLLocationCoordinate2D(latitude: 38.58602949605725, longitude: -90.22064294927867), radius: 938.5008162671309),
              SurveyLocation(name: "Gravois Park", coordinate: CLLocationCoordinate2D(latitude: 38.59047312019155, longitude: -90.23448575734832), radius: 770.8273643545547),
              SurveyLocation(name: "North Hampton", coordinate: CLLocationCoordinate2D(latitude: 38.5979019429337, longitude: -90.28179939749656), radius: 1116.3708944317739),
              SurveyLocation(name: "Benton Park West", coordinate: CLLocationCoordinate2D(latitude: 38.59776334501065, longitude: -90.2306244515402), radius: 740.7958113708664),
              SurveyLocation(name: "Tower Grove South", coordinate: CLLocationCoordinate2D(latitude: 38.59689794674792, longitude: -90.25697500387653), radius: 1414.1523597778669),
              SurveyLocation(name: "Lindenwood Park", coordinate: CLLocationCoordinate2D(latitude: 38.59801283349311, longitude: -90.30542685482538), radius: 1420.6256639101982),
              SurveyLocation(name: "Benton Park", coordinate: CLLocationCoordinate2D(latitude: 38.59962728240591, longitude: -90.21932064626134), radius: 803.2888737449993),
              SurveyLocation(name: "Tower Grove Park", coordinate: CLLocationCoordinate2D(latitude: 38.60629254245263, longitude: -90.25534629712081), radius: 779.5835551066671),
              SurveyLocation(name: "Tower Grove East", coordinate: CLLocationCoordinate2D(latitude: 38.6030097414213, longitude: -90.23717161593655), radius: 835.2014142183054),
              SurveyLocation(name: "McKinley Heights", coordinate: CLLocationCoordinate2D(latitude: 38.60978303941312, longitude: -90.2178537323034), radius: 542.2610985649393),
              SurveyLocation(name: "Soulard", coordinate: CLLocationCoordinate2D(latitude: 38.60366905371726, longitude: -90.20913695058768), radius: 900.6668483325471),
              SurveyLocation(name: "Fox Park", coordinate: CLLocationCoordinate2D(latitude: 38.60859491722343, longitude: -90.2259981125988), radius: 617.1690501738293),
              SurveyLocation(name: "Compton Heights", coordinate: CLLocationCoordinate2D(latitude: 38.61237985520898, longitude: -90.2345954311179), radius: 614.2532805608816),
              SurveyLocation(name: "Kosciusko", coordinate: CLLocationCoordinate2D(latitude: 38.602085292760265, longitude: -90.20035963222374), radius: 1201.2179367441956),
              SurveyLocation(name: "Missouri Botanical Garden", coordinate: CLLocationCoordinate2D(latitude: 38.61258438414857, longitude: -90.25948387761036), radius: 422.99590106422477),
              SurveyLocation(name: "Shaw", coordinate: CLLocationCoordinate2D(latitude: 38.61271574010624, longitude: -90.24867360730937), radius: 898.06718193222),
              SurveyLocation(name: "Southwest Garden", coordinate: CLLocationCoordinate2D(latitude: 38.60938310853191, longitude: -90.27450140090752), radius: 1073.797023635528),
              SurveyLocation(name: "Clifton Heights", coordinate: CLLocationCoordinate2D(latitude: 38.612164665752424, longitude: -90.29425546213145), radius: 811.3072998794298),
              SurveyLocation(name: "LaSalle Park", coordinate: CLLocationCoordinate2D(latitude: 38.61487866676951, longitude: -90.20025348756678), radius: 532.8467102101026),
              SurveyLocation(name: "Peabody Darst Webbe", coordinate: CLLocationCoordinate2D(latitude: 38.61563711921256, longitude: -90.20711675660732), radius: 521.8321291844071),
              SurveyLocation(name: "Lafayette Square", coordinate: CLLocationCoordinate2D(latitude: 38.616932656718866, longitude: -90.21506112592121), radius: 676.576820751214),
              SurveyLocation(name: "Ellendale", coordinate: CLLocationCoordinate2D(latitude: 38.612124938873734, longitude: -90.30552281830482), radius: 1047.750194060157),
              SurveyLocation(name: "The Hill", coordinate: CLLocationCoordinate2D(latitude: 38.618017109207884, longitude: -90.27661051360514), radius: 1143.3683860955307),
              SurveyLocation(name: "The Gate District", coordinate: CLLocationCoordinate2D(latitude: 38.61958889390624, longitude: -90.22925766534006), radius: 939.7446226585889),
                SurveyLocation(name: "College Hill", coordinate: CLLocationCoordinate2D(latitude: 38.672960842635504, longitude: -90.20962557641924), radius: 732.9109986376933),
                SurveyLocation(name: "O'Fallon", coordinate: CLLocationCoordinate2D(latitude: 38.67354855119207, longitude: -90.22604603566444), radius: 893.5418575482662),
                SurveyLocation(name: "O'Fallon Park", coordinate: CLLocationCoordinate2D(latitude: 38.68040998987993, longitude: -90.2189129785528), radius: 563.4101188690917),
                SurveyLocation(name: "Penrose", coordinate: CLLocationCoordinate2D(latitude: 38.67794225015018, longitude: -90.2389500506592), radius: 1025.7112541124425),
                SurveyLocation(name: "Near North Riverfront", coordinate: CLLocationCoordinate2D(latitude: 38.66300298067833, longitude: -90.1928259661809), radius: 1693.514581980027),
                SurveyLocation(name: "Penrose Park", coordinate: CLLocationCoordinate2D(latitude: 38.68432877389094, longitude: -90.24682891165372), radius: 392.7805341396111),
                SurveyLocation(name: "Wells Goodfellow", coordinate: CLLocationCoordinate2D(latitude: 38.67721887116503, longitude: -90.27206597301684), radius: 1285.4792819701167),
                SurveyLocation(name: "Mark Twain", coordinate: CLLocationCoordinate2D(latitude: 38.68903121062677, longitude: -90.24116432043856), radius: 934.1775674605963),
                SurveyLocation(name: "Mark Twain I-70 Industrial", coordinate: CLLocationCoordinate2D(latitude: 38.688071594213376, longitude: -90.26147376224853), radius: 1276.0521572353914),
                SurveyLocation(name: "Walnut Park East", coordinate: CLLocationCoordinate2D(latitude: 38.69762532529184, longitude: -90.25169916538026), radius: 952.3580487077932),
                SurveyLocation(name: "Bellefontaine/Calvary Cemetery", coordinate: CLLocationCoordinate2D(latitude: 38.698432262203404, longitude: -90.23475344019322), radius: 1357.9181029470644),
                SurveyLocation(name: "Walnut Park West", coordinate: CLLocationCoordinate2D(latitude: 38.705532848691355, longitude: -90.25732091878461), radius: 766.7255452947957),
                SurveyLocation(name: "North Pointe", coordinate: CLLocationCoordinate2D(latitude: 38.71538219795283, longitude: -90.24748755515772), radius: 823.6714460656528),
                SurveyLocation(name: "North Riverfront", coordinate: CLLocationCoordinate2D(latitude: 38.70110326502839, longitude: -90.21726835393605), radius: 1819.8544368550945),
                SurveyLocation(name: "Baden", coordinate: CLLocationCoordinate2D(latitude: 38.71619073032002, longitude: -90.23222400740036), radius: 1219.6438851353453),
                SurveyLocation(name: "Riverview", coordinate: CLLocationCoordinate2D(latitude: 38.750930884613034, longitude: -90.19421814883168), radius: 1336.09179735203),
                SurveyLocation(name: "Forest Park", coordinate: CLLocationCoordinate2D(latitude: 38.638234305012624, longitude: -90.28424970356299), radius: 1696.2976970352174),
                SurveyLocation(name: "DeBaliviere Place", coordinate: CLLocationCoordinate2D(latitude: 38.64951112443275, longitude: -90.27943724560383), radius: 661.0000787116631),
                SurveyLocation(name: "Skinker DeBaliviere", coordinate: CLLocationCoordinate2D(latitude: 38.65091651074182, longitude: -90.29377259134584), radius: 834.6810906498591),
                SurveyLocation(name: "Downtown", coordinate: CLLocationCoordinate2D(latitude: 38.6255766391188, longitude: -90.19084625380052), radius: 1182.1005604036595)
            ]

    }

    func setupGeofences(surveyLocations: [SurveyLocation]) {
        self.surveyLocations = surveyLocations
        for location in surveyLocations {
            let geofenceRegion = CLCircularRegion(center: location.coordinate, radius: location.radius, identifier: location.name)
            geofenceRegion.notifyOnEntry = true
            geofenceRegion.notifyOnExit = true

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
         geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
             guard let self = self, error == nil else {
                 print("Reverse geocoding failed: \(error?.localizedDescription ?? "No error description")")
                 return
             }

             if let placemark = placemarks?.first, let neighborhood = placemark.subLocality {
                 // Check if the neighborhood is in the predefined list
                 if let matchingLocation = self.surveyLocations.first(where: { $0.name == neighborhood }) {
                     self.setupGeofences(surveyLocations: [matchingLocation])
                 } else {
                     // Create a new SurveyLocation for the neighborhood not in the list
                     let newLocation = SurveyLocation(name: neighborhood, coordinate: location.coordinate, radius: 1000)
                     self.surveyLocations.append(newLocation)
                     self.setupGeofences(surveyLocations: [newLocation])
                 }
             }
         }
     }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let geoRegion = region as? CLCircularRegion {
            sendNotification2(for: geoRegion.identifier, event: "entered")
            entryTimes[geoRegion.identifier] = Date()
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let geoRegion = region as? CLCircularRegion, let entryTime = entryTimes[geoRegion.identifier] {
            let timeSpent = Date().timeIntervalSince(entryTime)
            if timeSpent >= 30 { // Consider reducing this threshold if needed
                sendNotification(for: geoRegion.identifier, event: "exited")
            }
            entryTimes.removeValue(forKey: geoRegion.identifier)
        }
    }

    private func sendNotification2(for neighborhood: String, event: String) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Geofence Alert"
        notificationContent.body = "You Entered \(neighborhood)."
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
