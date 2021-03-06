//
//  CyclingSpeedCadenceService.swift
//  SwiftySensors
//
//  https://github.com/kinetic-fit/sensors-swift
//
//  Copyright © 2016 Kinetic. All rights reserved.
//

import CoreBluetooth
import Signals

//
// https://developer.bluetooth.org/gatt/services/Pages/ServiceViewer.aspx?u=org.bluetooth.service.cycling_speed_and_cadence.xml
//
open class CyclingSpeedCadenceService: Service, ServiceProtocol {
    open static var uuid: String { return "1816" }    
    open override var characteristicTypes: Dictionary<String, Characteristic.Type> {
        return [
            Measurement.uuid:       Measurement.self,
            Feature.uuid:           Feature.self,
            SensorLocation.uuid:    SensorLocation.self,
        ]
    }
    
    open var measurement: Measurement?
    open var feature: Feature?
    open var sensorLocation: SensorLocation?
    
    
    //
    // https://developer.bluetooth.org/gatt/characteristics/Pages/CharacteristicViewer.aspx?u=org.bluetooth.characteristic.csc_measurement.xml
    //
    open class Measurement: Characteristic {
        open static let uuid: String = "2A5B"
        
        open fileprivate(set) var speedKPH: Double?
        open fileprivate(set) var crankRPM: Double?
        
        open var wheelCircumferenceCM: Double = 213.3
        
        open fileprivate(set) var measurementData: CyclingSpeedCadenceSerializer.MeasurementData? {
            didSet {
                guard let previous = oldValue else { return }
                guard let current = measurementData else { return }
                
                if let kph = CyclingSerializer.calculateWheelKPH(current, previous: previous, wheelCircumferenceCM: wheelCircumferenceCM, wheelTimeResolution: 1024) {
                    speedKPH = kph
                }
                if let rpm = CyclingSerializer.calculateCrankRPM(current, previous: previous) {
                    crankRPM = rpm
                }
            }
        }
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            (service as? CyclingSpeedCadenceService)?.measurement = self
            
            cbCharacteristic.notify(true)
        }
        
        override open func valueUpdated() {
            if let value = cbCharacteristic.value {
                
                // Certain sensors (*cough* Mio Velo *cough*) will send updates in bursts
                // so we're going to do a little filtering here to get a more stable reading
                
                let now = Date.timeIntervalSinceReferenceDate
                // calculate the expected interval of wheel events based on current speed
                // This results in a small "bump" of speed typically at the end. need to fix that...
                var reqInterval = 0.8
                if let speedKPH = speedKPH {
                    let speedCMS = speedKPH * 27.77777777777778
                    // A slower speed of around 5 kph would expect a wheel event every 1.5 seconds.
                    // These values could probably use some tweaking ...
                    reqInterval = max(0.5, min((wheelCircumferenceCM / speedCMS) * 0.9, 1.5))
                }
                if measurementData == nil || now - measurementData!.timestamp > reqInterval {
                    measurementData = CyclingSpeedCadenceSerializer.readMeasurement(value)
                }
            }
            super.valueUpdated()
        }
        
    }
    
    
    //
    // https://developer.bluetooth.org/gatt/characteristics/Pages/CharacteristicViewer.aspx?u=org.bluetooth.characteristic.cycling_power_feature.xml
    //
    open class Feature: Characteristic {
        open static let uuid: String = "2A5C"
        
        open fileprivate(set) var features: CyclingSpeedCadenceSerializer.Features?
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            (service as? CyclingSpeedCadenceService)?.feature = self
            
            cbCharacteristic.read()
        }
        
        override open func valueUpdated() {
            if let value = cbCharacteristic.value {
                features = CyclingSpeedCadenceSerializer.readFeatures(value)
            }
            
            super.valueUpdated()
            
            if let service = service {
                service.sensor.onServiceFeaturesIdentified => (service.sensor, service)
            }
        }
    }
    
    
    //
    // https://developer.bluetooth.org/gatt/characteristics/Pages/CharacteristicViewer.aspx?u=org.bluetooth.characteristic.sensor_location.xml
    //
    open class SensorLocation: Characteristic {
        open static let uuid: String = "2A5D"
        
        required public init(service: Service, cbc: CBCharacteristic) {
            super.init(service: service, cbc: cbc)
            (service as? CyclingSpeedCadenceService)?.sensorLocation = self
            
            cbCharacteristic.read()
        }
        
        open fileprivate(set) var location: CyclingSerializer.SensorLocation?
        
        override open func valueUpdated() {
            if let value = cbCharacteristic.value {
                location = CyclingSerializer.readSensorLocation(value)
            }
            super.valueUpdated()
        }
    }
    
    
}


