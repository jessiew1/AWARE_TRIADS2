//
//  Noisesensor.swift
//  aware-client-ios-v2
//
//  Created by JessieW on 10/26/23.
//  Copyright © 2023 Yuuki Nishiyama. All rights reserved.
//

import Foundation
import UIKit
import AWAREFramework
import Speech

class NoiseSensor {

    private var noiseSensor: AmbientNoise?
    private var study: AWAREStudy

    init(study: AWAREStudy) {
        self.study = study
        self.noiseSensor = AmbientNoise(awareStudy: study)
    }

    func startMonitoringNoise() {
        noiseSensor?.setSensorEventHandler { [weak self] (data, error) in
            guard let self = self else { return }
            if let noiseData = data as? AmbientNoiseData {
                let decibels = noiseData.db
                print("Current Noise Level: \(decibels) dB")
                
                if decibels > 50 {
                    self.handleLoudNoise()
                }
            }
        }
        noiseSensor?.startSensor()
    }

    private func handleLoudNoise() {
        print("Loud noise detected!")
        // Add additional handling code here
    }
}
