import Foundation
import AWAREFramework

class ConversationAwareSensor: AWARESensor {

    var conversationDetector: ConversationDetector?

    override init() {
        super.init()
        self.conversationDetector = ConversationDetector()
    }

    override func startSensor() {
        conversationDetector?.startMonitoring()
    }

    override func stopSensor() {
        conversationDetector?.stopMonitoring()
    }

    // Handle other sensor lifecycle methods and data handling as needed
}

// Usage with AWARE framework
let core = AWARECore.shared()
core.requestPermissionForBackgroundSensing { status in
    core.startBaseLocationSensor()
    
    let conversationSensor = ConversationAwareSensor(awareStudy: AWAREStudy.shared())
    conversationSensor.startSensor()
    
    conversationSensor.setSensorEventHandler { sensor, data in
        print(data)
    }
    conversationSensor.setDebug(true)

    let manager = AWARESensorManager.shared()
    manager.add(conversationSensor)
    manager.startAllSensors()
}
