//
//  RecordingScreenViewModel.swift
//  InnerAI
//
//  Created by Bassam Fouad on 16/11/2025.
//

import Combine
import ScreenCaptureKit

enum ControlPanelVisibility {
    case show
    case hide
}

class RecordingScreenViewModel: ObservableObject {
    
    @Published var screenRecordManager: ScreenRecordManager?
    @Published var controlPanelVisibility: ControlPanelVisibility = .hide
    @Published var recordingResult: FileInfo? = nil
    @Published var displayingActionPopup: Bool = false
    @Published var restartPerformed: Bool = false
    @Published var contentViewModel: ContentViewModel
    @Published var selectedWindow: SCWindow?
    @Published var cameraWindow: SCWindow?
    @Published var recordingState: RecordingState = .inProgress

    /// View sends actions into this subject
    let actionSubject = PassthroughSubject<RecordingAction, Never>()
    private var cancellables = Set<AnyCancellable>()

    /// External state from parent
    var recordConfig: RecordConfiguration!
    var appDelegate: AppDelegate!
    var screenSize = CGSize.zero
    
    init(contentViewModel: ContentViewModel) {
        self.contentViewModel = contentViewModel
        bindActions()
    }


    private func bindActions() {
        actionSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                guard let self = self else { return }
                Task { @MainActor in
                    self.handle(action: action)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func handle(action: RecordingAction) {
        switch action {
        case .stop:
            stopRecording()
        case .pause:
            screenRecordManager?.isPause = true

        case .resume:
            screenRecordManager?.isPause = false

        case .restart:
            restartRecording()

        case .delete:
            deleteRecording()

        default:
            recordingState = .inProgress
            break
        }
    }

    // MARK: - Recording Ops
    @MainActor
    func startRecording() async {
        do {
            appDelegate.hidePopOver()
            controlPanelVisibility = .hide
            
            screenRecordManager = ScreenRecordManager()
            screenRecordManager?.audioDeviceId = recordConfig.audioDeviceId ?? 0
            screenRecordManager?.recordMic = recordConfig.settings.enableAudio
            screenRecordManager?.audioDeviceTransportType = recordConfig.audioDeviceTransportType ?? .builtIn
            
            screenRecordManager?.onStopStream = { [weak self] _ in
                Task { @MainActor in
                    self?.stopRecording()
                }
            }
            
            // Exclude control window
            var excluded: [SCWindow] = []
            if let controls = try await SCShareableContent
                .current
                .windows
                .first(where: { $0.title == "InnerAIRecordWindow" })
            {
                excluded.append(controls)
            }
            
            try await screenRecordManager?.record(
                displayID: recordConfig.screenInfo?.displayID ?? CGMainDisplayID(),
                selectedWindow: selectedWindow,
                cameraWindow: cameraWindow,
                excludedWindows: excluded
            )
            
            try await screenRecordManager?.start()
            controlPanelVisibility = .show
            
        } catch {
            print("Recording failed: \(error)")
        }
    }

    @MainActor
    func stopRecording() {
        guard let fileURL = screenRecordManager?.fileURL,
              let fileInfo = RecordFileManager.shared.fetchFileInfo(fromPath: fileURL)
        else {
            stopRecordingSession()
            appDelegate.hideWindow()
            return
        }
        
        let info = FileInfo(
                url: fileInfo.fileURL,
                name: fileInfo.fileName,
                size: fileInfo.fileSize,
                type: "video/\(fileInfo.fileType)"
            )
            
        recordingState = .stopped(info)
        
        stopRecordingSession()
        appDelegate.hideCameraWindow()
        appDelegate.hideWindow()
    }
    
    func restartRecording() {
        displayingActionPopup = true
        screenRecordManager?.isPause = true
        
        appDelegate.showCustomPopup(
            title: "Restart your recording?",
            message: "The progress on your current video will be lost.",
            buttonTitle: "Restart"
        ) { [weak self] cancelled in
            
            guard let self else { return }
            
            if cancelled {
                displayingActionPopup = false
                appDelegate.hideCustomPopup()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.screenRecordManager?.isPause = false
                }
                return
            }
            
            if let filePath = self.screenRecordManager?.filePath {
                RecordFileManager.shared.deleteFile(atPath: filePath)
            }
            
            Task {
                try? await self.screenRecordManager?.stopRecording()
            }

            stopRecordingSession(stopCameraCapturing: false, isRestart: true)
            self.startRecordingAgain()
        }
    }

    private func startRecordingAgain() {
        Task {
            await startRecording()
        }
    }
    
    func deleteRecording() {
        displayingActionPopup = true
        screenRecordManager?.isPause = true

        appDelegate.showCustomPopup(
            title: "Delete your Recording?",
            message: "The progress on your current video will be lost.",
            buttonTitle: "Delete"
        ) { [weak self] cancelled in
            
            guard let self else { return }

            if cancelled {
                displayingActionPopup = false
                appDelegate.hideCustomPopup()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.screenRecordManager?.isPause = false
                }
                return
            }

            if let filePath = self.screenRecordManager?.filePath {
                RecordFileManager.shared.deleteFile(atPath: filePath)
            }
            stopRecordingSession()
            recordingState = .deleted
            appDelegate.hideWindow()
            screenRecordManager = nil
        }
    }

    private func stopRecordingSession(stopCameraCapturing: Bool = true, isRestart: Bool = false) {
        Task {
            do {
                if stopCameraCapturing {
                    contentViewModel.stopSession()
                }
                try await screenRecordManager?.stopRecording()
                if !isRestart {
                    screenRecordManager = nil
                }
             } catch {
                print("Error during recording:", error)
            }
        }
    }

}

