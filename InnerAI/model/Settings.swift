//
//  Settings.swift
//  InnerAI
//
//  Created by Bassam Fouad on 30/04/2024.
//

import Foundation
import AVFoundation

enum RigthIconType {
    case check
    case settings
    
    func getIconName() -> String {
        switch self {
        case .check:
            return "check_icon"
        case .settings:
            return "settings_icon"
        }
    }
    
    func getIconSize() -> Double {
        switch self {
        case .check:
            return 20.0
        case .settings:
            return 30.0
        }
    }
}

enum VideoWindowType {
    case fullScreen
    case specific
    case camera
    
    var string: String {
        switch self {
        case .fullScreen:
            return "Full Screen"
        case .specific:
            return "Specific Window"
        case .camera:
            return "Camera Only"
        }
    }
    
    var icon: String {
        switch self {
        case .fullScreen:
            return "monitor"
        case .specific:
            return "specific_window_icon"
        case .camera:
            return "profile_icon"
        }
    }
}

struct RecordSettings {
    var displayCamera: Bool
    var enableAudio: Bool
}

protocol SelectableOption: Hashable {
    var title: String { get set }
    var icon: String { get }
    var rightIcon: RigthIconType { get set }
    var isSelected: Bool { get set }
}

extension SelectableOption {
    func withSelected(_ selected: Bool) -> Self {
        var copy = self
        copy.isSelected = selected
        return copy
    }
    func withRightIcon(_ newRightIcon: RigthIconType) -> Self {
        var copy = self
        copy.rightIcon = newRightIcon
        return copy
    }
}

struct Option: SelectableOption, Hashable {
    var title: String
    var icon: String
    var rightIcon: RigthIconType
    var isSelected: Bool = false

    func withRightIcon(_ newRightIcon: RigthIconType) -> Option {
        return Option(title: title, icon: icon, rightIcon: newRightIcon, isSelected: isSelected)
    }
}

struct VideoOption: SelectableOption, Hashable {
    
    var title: String
    var icon: String
    var rightIcon: RigthIconType
    var videoWindowType: VideoWindowType = .fullScreen
    var isSelected: Bool
    
    init(rightIcon: RigthIconType, videoWindowType: VideoWindowType, isSelected: Bool = false) {
        title = videoWindowType.string
        icon = videoWindowType.icon
        self.rightIcon = rightIcon
        self.videoWindowType = videoWindowType
        self.isSelected = isSelected
    }
}

struct CameraOption: SelectableOption, Hashable {
    
    var title: String
    var icon: String = "video"
    var rightIcon: RigthIconType
    var isSelected: Bool
    var allowCamera: Bool = false
    
    init(title: String, rightIcon: RigthIconType, isSelected: Bool = false, allowCamera: Bool = true) {
        self.title = title
        self.rightIcon = rightIcon
        self.isSelected = isSelected
        self.allowCamera = allowCamera
    }
    
    func onCamera(_ state: Bool) -> Self {
        var copy = self
        copy.allowCamera = state
        copy.icon = state ? "video" : "no_camera"
        return copy
    }
}

struct VoiceOption: SelectableOption, Hashable {
    
    var title: String
    var icon: String = "microphone-icon"
    var rightIcon: RigthIconType
    var isSelected: Bool
    var allowMicrophone: Bool
    var deviceId: UInt32 = 0
    
    init(title: String, rightIcon: RigthIconType, isSelected: Bool = false, allowMicrophone: Bool = true) {
        self.title = title
        self.rightIcon = rightIcon
        self.isSelected = isSelected
        self.allowMicrophone = allowMicrophone
    }
    
    func onMicrophone(_ state: Bool) -> Self {
        var copy = self
        copy.allowMicrophone = state
        copy.icon = state ? "microphone-icon" : "no_mic"
        return copy
    }
    
    func withDeviceId(_ id: UInt32) -> Self {
        var copy = self
        copy.deviceId = id
        return copy
    }
}

struct RecordConfiguration {
    let videoWindowType: VideoWindowType
    var settings: RecordSettings = RecordSettings(displayCamera: true, enableAudio: true)
    let windowInfo: OpenedWindowInfo?
    var audioDeviceId: UInt32?
    var audioDeviceTransportType: AudioDeviceTransportType?
    var selectedCamera: AVCaptureDevice?
    var screenInfo: ScreenInfo?
    var isExternalDisplayConnected: Bool = false
    
    func withCamera(_ state: Bool) -> Self {
        var copy = self
        copy.settings.displayCamera = state
        return copy
    }
    
    func withAudio(_ state: Bool) -> Self {
        var copy = self
        copy.settings.enableAudio = state
        return copy
    }
    
    func withCameraDevice(_ camera: AVCaptureDevice) -> Self {
        var copy = self
        copy.selectedCamera = camera
        return copy
    }
    
    func withAudioDeviceId(_ id: UInt32, _ type: AudioDeviceTransportType) -> Self {
        var copy = self
        copy.audioDeviceId = id
        copy.audioDeviceTransportType = type
        return copy
    }
    
    func withScreenInfo(_ info: ScreenInfo) -> Self {
        var copy = self
        copy.screenInfo = info
        return copy
    }
    
    func withExternalDisplay(_ isConnected: Bool) -> Self {
        var copy = self
        copy.isExternalDisplayConnected = isConnected
        return copy
    }
    
}
