//
//  AudioDeviceTransportType.swift
//  InnerAI
//
//  Created by Bassam Fouad on 14/08/2024.
//

import CoreAudio
import AudioToolbox

enum AudioDeviceTransportType: String {
    case bluetooth = "Bluetooth"
    case usb = "USB"
    case builtIn = "Built-In"
    case pci = "PCI"
    case fireWire = "FireWire"
    case thunderbolt = "Thunderbolt"
    case aggregate = "Aggregate"
    case other = "Other"
    
    init(transportType: UInt32) {
        switch transportType {
        case kAudioDeviceTransportTypeBluetooth:
            self = .bluetooth
        case kAudioDeviceTransportTypeUSB:
            self = .usb
        case kAudioDeviceTransportTypeBuiltIn:
            self = .builtIn
        case kAudioDeviceTransportTypePCI:
            self = .pci
        case kAudioDeviceTransportTypeFireWire:
            self = .fireWire
        case kAudioDeviceTransportTypeThunderbolt:
            self = .thunderbolt
        case kAudioDeviceTransportTypeAggregate:
            self = .aggregate
        default:
            self = .other
        }
    }
}
