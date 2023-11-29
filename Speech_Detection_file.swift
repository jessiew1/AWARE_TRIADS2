{\rtf1\ansi\ansicpg1252\cocoartf2759
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 import Foundation\
import AWAREFramework\
\
class ConversationAwareSensor: AWARESensor \{\
\
    var conversationDetector: ConversationDetector?\
\
    override init() \{\
        super.init()\
        self.conversationDetector = ConversationDetector()\
    \}\
\
    override func startSensor() \{\
        conversationDetector?.startMonitoring()\
    \}\
\
    override func stopSensor() \{\
        conversationDetector?.stopMonitoring()\
    \}\
\
    // Handle other sensor lifecycle methods and data handling as needed\
\}\
\
// Usage with AWARE framework\
let core = AWARECore.shared()\
core.requestPermissionForBackgroundSensing \{ status in\
    core.startBaseLocationSensor()\
    \
    let conversationSensor = ConversationAwareSensor(awareStudy: AWAREStudy.shared())\
    conversationSensor.startSensor()\
    \
    conversationSensor.setSensorEventHandler \{ sensor, data in\
        print(data)\
    \}\
    conversationSensor.setDebug(true)\
\
    let manager = AWARESensorManager.shared()\
    manager.add(conversationSensor)\
    manager.startAllSensors()\
\}\
}