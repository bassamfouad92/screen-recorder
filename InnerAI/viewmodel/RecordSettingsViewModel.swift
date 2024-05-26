//
//  RecordSettingsViewModel.swift
//  InnerAI
//
//  Created by Bassam Fouad on 01/05/2024.
//

import Foundation
import AVFoundation

final class RecordSettingsViewModel: ObservableObject {
    
    let deviceManager: AVCaptureDeviceManager
    
    var videoOptions: [any SelectableOption] = [
        VideoOption(rightIcon: .check, videoWindowType: .fullScreen, isSelected: true),
        VideoOption(rightIcon: .check, videoWindowType: .specific),
        VideoOption(rightIcon: .check, videoWindowType: .camera)
    ]
    
    var cameraOptions: [any SelectableOption] = [
        CameraOption(title: "No Camera", rightIcon: .check).onCamera(false),
    ]
    
    var voiceOptions: [any SelectableOption] = [
        VoiceOption(title: "No Microphone", rightIcon: .check).onMicrophone(false),
    ]
    
    @Published var selectedVideoOption: VideoOption {
        didSet {
            for (index, var option) in videoOptions.enumerated() {
                option.isSelected = (option.title == selectedVideoOption.title)
                videoOptions[index] = option
            }
        }
    }
    
    @Published private var _recordConfig: RecordConfiguration = RecordConfiguration(videoWindowType: .fullScreen, windowInfo: nil)
    
    // Computed property to access and modify _recordConfig
    var recordConfig: RecordConfiguration {
        get {
            return _recordConfig
        }
        set {
            _recordConfig = newValue
        }
    }
    
    var defaultCamera: AVCaptureDevice?
    
    var micDeviceId: UInt32? {
        didSet {
            guard let id = micDeviceId else { return }
            recordConfig = recordConfig.withAudioDeviceId(id)
        }
    }
    
    var selectedCamera: String? {
        didSet {
            guard let name = selectedCamera else { return }
            defaultCamera = deviceManager.getDevice(withName: name)
            recordConfig = recordConfig.withCameraDevice(defaultCamera!)
        }
    }
    
    var allowCamera: Bool? {
        didSet {
            guard let state = allowCamera else { return }
            recordConfig = recordConfig.withCamera(state)
        }
    }
    
    var allowMicrophone: Bool? {
        didSet {
            guard let state = allowMicrophone else { return }
            recordConfig = recordConfig.withAudio(state)
        }
    }

    init() {
        self.selectedVideoOption = videoOptions[0] as! VideoOption
        self.deviceManager = AVCaptureDeviceManager.shared
        appendAvailableCamerasAndMicrophone()
    }
    
    func setSelectedVideo(with option: VideoOption) {
        selectedVideoOption = option
    }
    
    func setSelectedCamera(with cameraOption: CameraOption) {
        for (index, var option) in cameraOptions.enumerated() {
            option.isSelected = (option.title == cameraOption.title)
            cameraOptions[index] = option
        }
    }
    
    func setDefaultCamera() {
        self.selectedCamera = deviceManager.getDefaultCamera()?.localizedName
    }
    
    func setSelectedMicrophone(with micOption: VoiceOption) {
        micDeviceId = micOption.deviceId
        for (index, var option) in voiceOptions.enumerated() {
            option.isSelected = (option.title == micOption.title)
            voiceOptions[index] = option
        }
    }
    
    func configureRecordConfig(videoWindowType: VideoWindowType, windowInfo: OpenedWindowInfo? = nil) {
        recordConfig = RecordConfiguration(videoWindowType: videoWindowType, windowInfo: windowInfo, selectedCamera: defaultCamera)
    }
    
    private func appendAvailableCamerasAndMicrophone() {
        cameraOptions.append(contentsOf: (deviceManager.getListOfCamerasAsString().map {
            return CameraOption(title: $0, rightIcon: .check)
        }))
        voiceOptions.append(contentsOf: (deviceManager.getAudioDevices().map {
            return VoiceOption(title: $0.deviceName, rightIcon: .check).withDeviceId($0.deviceId)
        }))
    }
    
    func configureCameraAndMic() {
        if cameraOptions.count > 1 {
            let defaultCamera = deviceManager.getDefaultCamera()?.localizedName ?? ""
            if let defaultCameraOption = cameraOptions.first(where: { $0.title == defaultCamera }) {
                setDefaultCamera()
                setSelectedCamera(with: defaultCameraOption as! CameraOption)
            }
        }
        if voiceOptions.count > 1 {
            let defaultMic = deviceManager.getDefaultMicrophone()?.localizedName ?? ""
            
            if let defaultVoiceOption = voiceOptions.first(where: { $0.title == defaultMic }) {
                setSelectedMicrophone(with: defaultVoiceOption as! VoiceOption)
            }
        }
    }
}

// MARK: Session
extension RecordSettingsViewModel {
    func logout() {
        UserSessionManager.logout()
    }
}
