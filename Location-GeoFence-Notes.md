# LocationHandler Class Documentation

The `LocationHandler` class is designed to manage location updates, send notifications, and integrate with the AWARE Framework for data collection. This class utilizes several key iOS frameworks, including `CoreLocation`, `UserNotifications`, and `MapKit`, along with external frameworks like `AWAREFramework` and `MySQLNIO`.

## Key Properties

- **notificationSent**: A boolean flag to track if a notification has been sent.
- **geocoder**: An instance of `CLGeocoder` used for reverse geocoding.
- **neighborhoods**: A dictionary mapping `MKPolygon` objects to neighborhood names.
- **currentNeighborhood**: An optional string to store the current neighborhood name.
- **timer**: An optional `Timer` instance for scheduling location checks.
- **startTime**: An optional `Date` instance marking the start time of tracking.
- **lastLocationCheckTime**: An optional `Date` for the last location check.
- **lastKnownLocation**: An optional `CLLocationCoordinate2D` for the last known location.
- **locationManager**: An optional `CLLocationManager` for managing location updates.
- **lastNotificationTime**: An optional `Date` to track the last notification time.
- **eventLoopGroup** and **mysqlConnection**: Properties for managing MySQL database connections.

## Initialization

The `LocationHandler` class is initialized using the `shared` singleton instance. During initialization:

1. **Location Manager Setup**: The `setupLocationManager()` method is called to configure the `CLLocationManager`.
2. **Neighborhoods Loading**: It attempts to load neighborhood data from a `geojson` file.
3. **Notification Center Delegate**: Sets the `UNUserNotificationCenter` delegate to self.

## Methods

### `setupLocationManager()`

Configures the `CLLocationManager` for location updates, including permissions and accuracy settings.

### `handleLocationUpdate(latitude:longitude:)`

Handles location updates by determining the current neighborhood based on latitude and longitude, and triggers notifications or database updates if necessary.

### `scheduleNotification(content:identifier:delay:)`

Schedules a local notification with specified content, identifier, and delay.

### `storeNotificationDetailsInDatabase(message:)`

Stores notification details in a MySQL database using the provided message.

### `sendTestNotificationOnAppStart()`

Sends a test notification when the app starts, useful for debugging and verification.

### `countAndPrintNeighborhoodsInFile()`

Counts and prints the number of neighborhoods in the `geojson` file.

### `createNeighborhoodStayAlertContent(neighborhood:)`

Creates the content for a notification alerting the user that they have stayed in a neighborhood for an extended period.

## Utility Methods

- **`loadNeighborhoods(from:)`**: Loads neighborhood data from a `geojson` file.
- **`coordinates(for:)`**: Extracts coordinates from an `MKPolygon`.
- **`isPoint(_:in:)`**: Determines if a point is within a given polygon.

## When Users Receive Notifications and Reminders

Users will receive notifications and reminders based on the following conditions:

1. **Entering a New Neighborhood**: When the user enters a new neighborhood, a notification is triggered to inform them about their new location.
2. **Staying in a Neighborhood**: If the user stays within the same neighborhood for an extended period, a reminder notification is sent. This duration is configurable but typically set to alert the user after a significant amount of time has passed.
3. **Custom Reminders**: The system can also send reminders based on custom criteria, such as specific times of day or user-defined events.

### Example Notification Workflow

1. **Location Update**: The `handleLocationUpdate(latitude:longitude:)` method receives a new location update.
2. **Neighborhood Check**: The method checks if the user has entered a new neighborhood using the `isPoint(_:in:)` method.
3. **Send Notification**: If a new neighborhood is detected, the `createNeighborhoodStayAlertContent(neighborhood:)` method creates the notification content, and `scheduleNotification(content:identifier:delay:)` schedules the notification.
4. **Store in Database**: The `storeNotificationDetailsInDatabase(message:)` method stores the notification details in the MySQL database.

## AWARE Framework Integration

The `initializeAWAREFrameworkComponents()` function integrates the `LocationHandler` with the AWARE Framework:

1. **Permission Requests**: Requests permissions for push notifications and background sensing.
2. **Fused Location Sensor**: Adds and configures a fused location sensor to the AWARE sensor manager.
3. **Event Handling**: Sets up an event handler to process location data and invoke `handleLocationUpdate(latitude:longitude:)`.
4. **Status Monitoring**: Activates status monitoring with a specified check interval.

## Example Usage

To use the `LocationHandler` class, ensure it is properly initialized and integrated with the AWARE Framework:

```swift
func initializeAWAREFrameworkComponents() {
    let locationHandler = LocationHandler.shared
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
```

This setup ensures that location updates are handled and processed efficiently, integrating seamlessly with both the local notification system and the AWARE Framework.

---
