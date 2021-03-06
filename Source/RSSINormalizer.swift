//
//  RSSINormalizer.swift
//  SwiftySensors
//
//  https://github.com/kinetic-fit/sensors-swift
//
//  Copyright © 2016 Kinetic. All rights reserved.
//
//  Derived from Android's RSSI signal level calculator
//  - https://github.com/android/platform_frameworks_base/blob/master/wifi/java/android/net/wifi/WifiManager.java#L1495
//

import Foundation

open class RSSINormalizer {
    
    // RSSI ranges are between 0 (max strength) and -100 (min strength)
    open static func calculateSignalLevel(_ rssi: Int, numLevels: Int, rssiMin: Int = -100, rssiMax: Int = -65) -> Int {
        if rssi <= rssiMin {
            return 0
        } else if rssi >= rssiMax {
            return numLevels - 1
        }
        let inputRange = Float(rssiMax - rssiMin)
        let outputRange = Float(numLevels - 1)
        return Int(Float(rssi - rssiMin) * outputRange / inputRange)
    }
    
}
