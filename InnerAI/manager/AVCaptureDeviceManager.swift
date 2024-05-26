//
//  AVCaptureDeviceManager.swift
//  InnerAI
//
//  Created by Bassam Fouad on 04/05/2024.
//

import AVFoundation
import CoreAudio
import AudioToolbox

struct AudioDevice: Identifiable {
    let id: AudioDeviceID
    let name: String
    let inputChannels: Int
    let outputChannels: Int
}


class AVCaptureDeviceManager {
    
    static let shared = AVCaptureDeviceManager()
    
    private init() {}
    
    func getAudioDevices() -> [MicInfo] {
        
        var devices = [MicInfo]()
        
        var propertySize: UInt32 = 0
        var status: OSStatus = noErr
        
        // Get the number of devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        if status != noErr {
            print("Error: Unable to get the number of audio devices.")
            return devices
        }
        
        // Get the device IDs
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        if status != noErr {
            print("Error: Unable to get the audio device IDs.")
            return devices
        }
        
        // Get device info for each device
        for deviceID in deviceIDs {
            var deviceName: String = ""
            var inputChannels: Int = 0
            var isAggregateDevice = false
            // Get device name
            propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
            propertySize = UInt32(MemoryLayout<CFString>.size)
            var name: CFString? = nil
            status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &name
            )
            if status == noErr, let deviceNameCF = name as String? {
                deviceName = deviceNameCF
            }
            
            propertyAddress.mSelector = kAudioDevicePropertyTransportType
                    propertySize = UInt32(MemoryLayout<UInt32>.size)
                    var transportType: UInt32 = 0
                    status = AudioObjectGetPropertyData(
                        deviceID,
                        &propertyAddress,
                        0,
                        nil,
                        &propertySize,
                        &transportType
                    )
                    if status == noErr {
                        // kAudioDeviceTransportTypeAggregate is not directly available, so we use its raw value
                        if transportType == kAudioDeviceTransportTypeAggregate {
                            isAggregateDevice = true
                        }
                    }

            if !isAggregateDevice {
                // Get input channels
                propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration
                propertyAddress.mScope = kAudioDevicePropertyScopeInput
                status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &propertySize)
                if status == noErr {
                    let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
                    defer { bufferListPointer.deallocate() }
                    status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, bufferListPointer)
                    if status == noErr {
                        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
                        for buffer in bufferList {
                            inputChannels += Int(buffer.mNumberChannels)
                        }
                    }
                }
            }
            
            // MIC = 1, Speaker and headphone = 0
            if inputChannels == 1 {
                devices.append(MicInfo(deviceId: deviceID, deviceName: deviceName))
            }
        }
        
        return devices
        
    }
   
    /// Returns all cameras on the device.
    func getListOfCameras() -> [AVCaptureDevice] {
        if #available(macOS 14.0, *) {
            let session = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .external,
                    .builtInWideAngleCamera,
                    .continuityCamera,
                ],
                mediaType: .video,
                position: .unspecified)
            return session.devices
        }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: .unspecified)
        return session.devices
    }
    
    /// Returns all microphones on the device.
    func getListOfMicrophones() -> [AVCaptureDevice] {
        if #available(macOS 14.0, *) {
            let session = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .microphone,
                    .builtInMicrophone,
                    .external
                ],
                mediaType: .audio,
                position: .unspecified)
            return session.devices
        }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInMicrophone,
            ],
            mediaType: .audio,
            position: .unspecified)
        return session.devices
    }
    
    /// Converts giving AVCaptureDevice list to the String
    private func convertDeviceListToString(_ devices: [AVCaptureDevice]) -> [String] {
        let uniqueNames = Set(devices.map { $0.localizedName })
        return Array(uniqueNames)
    }
    
    func getListOfCamerasAsString() -> [String] {
        let devices = getListOfCameras()
        return convertDeviceListToString(devices)
    }
    
    func getListOfMicrophonesAsString() -> [String] {
        let devices = getListOfMicrophones()
        return convertDeviceListToString(devices)
    }
    
    func getDefaultCamera() -> AVCaptureDevice? {
        return AVCaptureDevice.default(for: .video)
    }
    
    func getDefaultMicrophone() -> AVCaptureDevice? {
        return AVCaptureDevice.default(for: .audio)
    }
    
    func getDevice(withName name: String) -> AVCaptureDevice? {
        return getListOfCameras().first(where: { $0.localizedName == name})
    }
}

