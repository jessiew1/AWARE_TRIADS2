import UIKit
import CoreLocation

// Define structures for GeoJSON data
struct GeoJSON: Codable {
    var type: String
    var features: [Feature]
}

struct Feature: Codable {
    var type: String
    var properties: [String: String]
    var geometry: Geometry
}

struct Geometry: Codable {
    var type: String
    var coordinates: [[[Double]]] // Assuming polygons
}

class NeighborhoodLocator: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first?.coordinate {
            currentLocation = location
            checkCurrentNeighborhood()
        }
    }

    // Function to parse GeoJSON file
    func parseGeoJSON() -> GeoJSON? {
        guard let url = Bundle.main.url(forResource: "Neighborhoods", withExtension: "geojson"),
              let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        return try? decoder.decode(GeoJSON.self, from: data)
    }

    // Function to check if a point is within a polygon
    func isPoint(_ point: CLLocationCoordinate2D, inPolygon polygon: [CLLocationCoordinate2D]) -> Bool {
        var isInside = false
        for i in 0..<polygon.count {
            let j = (i + 1) % polygon.count
            if ((polygon[i].latitude > point.latitude) != (polygon[j].latitude > point.latitude)) &&
                (point.longitude < (polygon[j].longitude - polygon[i].longitude) * (point.latitude - polygon[i].latitude) / (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude) {
                isInside = !isInside
            }
        }
        return isInside
    }

    // Determine if the user's location is within a neighborhood
    func checkUserLocationInNeighborhood(userLocation: CLLocationCoordinate2D) -> String? {
        guard let neighborhoods = parseGeoJSON() else { return nil }

        for feature in neighborhoods.features {
            let coordinates = feature.geometry.coordinates[0].map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
            if isPoint(userLocation, inPolygon: coordinates) {
                return feature.properties["name"] // Assuming there's a name property
            }
        }

        return nil
    }

    func checkCurrentNeighborhood() {
        guard let userLocation = currentLocation else { return }
        if let neighborhoodName = checkUserLocationInNeighborhood(userLocation: userLocation) {
            print("User is currently in \(neighborhoodName)")
        } else {
            print("User is not in a known neighborhood")
        }
    }
}

