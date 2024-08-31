//
//  RecordSettingsViewModel.swift
//  InnerAI
//
//  Created by Bassam Fouad on 01/05/2024.
//

import Foundation
import AVFoundation
import Combine
import AppKit
    
final class RecordSettingsViewModel: ObservableObject {
    
    let deviceManager: AVCaptureDeviceManager

    var videoOptions: [any SelectableOption] = [
        VideoOption(rightIcon: .check, videoWindowType: .fullScreen, isSelected: true),
        //temp removal
        VideoOption(rightIcon: .check, videoWindowType: .specific),
        VideoOption(rightIcon: .check, videoWindowType: .camera)
    ]
    
    private var noCameraOption: CameraOption {
        CameraOption(title: "No Camera", rightIcon: .check).onCamera(false)
    }
    
    var cameraOptions: [any SelectableOption] = []
    
    var voiceOptions: [any SelectableOption] = [
        VoiceOption(title: "No Microphone", rightIcon: .check).onMicrophone(false),
    ]
    
    //MARK:- Observers
    @Published private var screenObserver = ScreenObserver()
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
            let audioDeviceId: AudioDeviceID = id
            let transportType = deviceManager.getAudioDeviceTransportType(deviceID: audioDeviceId)
            recordConfig = recordConfig.withAudioDeviceId(id, transportType)
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
            recordConfig = recordConfig.withCamera(allowCamera ?? false)
        }
    }
    
    var allowMicrophone: Bool? {
        didSet {
            recordConfig = recordConfig.withAudio(allowMicrophone ?? false)
        }
    }
    
    var isExternelScreenConnected: Bool = false

    private var cancellables = Set<AnyCancellable>()
    
    func subscribeToScreenObserver() {
        screenObserver.getScreensList()
        isExternelScreenConnected = screenObserver.screenCount > 1
    }

    func checkForUpdates() {
        guard let url = URL(string: "https://cdn-client.innerplay.io/v2-screenrec/versions.json") else { return }

        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: [AppVersion].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] versions in
                self?.handleVersionCheck(versions: versions)
            })
            .store(in: &cancellables)
    }

    private func handleVersionCheck(versions: [AppVersion]) {
        guard let latestVersion = versions.max(by: { $0.version < $1.version }) else { return }
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        if latestVersion.version > currentVersion {
            // Show update popup
            let alert = NSAlert()
            alert.messageText = "Update Available"
            alert.informativeText = "A new version (\(latestVersion.version)) is available. Would you like to update?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Update")
            
            if latestVersion.required {
                alert.addButton(withTitle: "Quit")
            } else {
                alert.addButton(withTitle: "Cancel")
            }
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open latestVersion.download_link in browser
                if let url = URL(string: latestVersion.download_link) {
                    NSWorkspace.shared.open(url)
                    NSApplication.shared.terminate(nil)
                }
            } else if latestVersion.required && response == .alertSecondButtonReturn {
                // Quit the application
                NSApplication.shared.terminate(nil)
            }
        }
    }

    init() {
        self.selectedVideoOption = videoOptions[0] as! VideoOption
        self.deviceManager = AVCaptureDeviceManager.shared
        self.cameraOptions.append(noCameraOption)
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
    
    func configureRecordConfig(videoWindowType: VideoWindowType, windowInfo: OpenedWindowInfo? = nil, screeninfo: ScreenInfo? = nil) {
        recordConfig = RecordConfiguration(videoWindowType: videoWindowType, windowInfo: windowInfo, selectedCamera: defaultCamera)
        if let screen = screeninfo {
            recordConfig = recordConfig.withScreenInfo(screen)
        }
        recordConfig = recordConfig.withExternalDisplay(isExternelScreenConnected)
    }
    
    func appendAvailableCamerasAndMicrophone() {
        //remove all before setting new devices
        cameraOptions.removeAll()
        cameraOptions.append(noCameraOption)
        voiceOptions = voiceOptions.filter { $0.title == "No Microphone" }
        
        cameraOptions.append(contentsOf: (deviceManager.getListOfCamerasAsString().map {
            return CameraOption(title: $0, rightIcon: .check)
        }))
        voiceOptions.append(contentsOf: (deviceManager.getAudioDevices().map {
            return VoiceOption(title: $0.deviceName, rightIcon: .check).withDeviceId($0.deviceId)
        }))
    }
    
    func removeNoCameraOption() {
        cameraOptions = cameraOptions.filter { $0.title != "No Camera" }
    }
    
    func configureCameraOption(isDefault: Bool = true) {
        if isDefault,
           let defaultCameraName = deviceManager.getDefaultCamera()?.localizedName,
           let defaultCameraOption = cameraOptions.first(where: { $0.title == defaultCameraName }) as? CameraOption {
            setDefaultCamera()
            setSelectedCamera(with: defaultCameraOption)
        } else if let firstCameraOption = cameraOptions.first as? CameraOption {
            setSelectedCamera(with: firstCameraOption)
        }
    }
    
    func configureMicrophoneOption() {
        guard cameraOptions.count > 1 else { return }
        let defaultMic = deviceManager.getDefaultMicrophone()?.localizedName ?? ""
        if let defaultVoiceOption = voiceOptions.first(where: { $0.title == defaultMic }) {
            setSelectedMicrophone(with: defaultVoiceOption as! VoiceOption)
        }
    }
    
    func configureCameraAndMic() {
        guard cameraOptions.count > 1 else { return }
        configureCameraOption()
        configureMicrophoneOption()
    }
}

// MARK: Session
extension RecordSettingsViewModel {
    func logout() {
        UserSessionManager.logout()
    }
}

struct AppVersion: Decodable {
    let version: String
    let download_link: String
    let required: Bool
}
