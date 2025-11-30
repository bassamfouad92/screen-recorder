//
//  RecordingScreenViewModel.swift
//  InnerAI
//
//  Created by Bassam Fouad on 16/11/2025.
//

import Combine
import CoreGraphics
import Foundation

enum ControlPanelVisibility {
    case show
    case hide
}

enum ConfirmationAction {
    case restart
    case delete
}

enum ViewEvent {
    case hidePopover
    case showControlPanel
    case hideControlPanel
    case hideWindow
    case hideCameraWindow
}

class RecordingScreenViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var controlPanelVisibility: ControlPanelVisibility = .hide
    @Published var recordingState: RecordingState = .inProgress
    @Published var selectedWindow: WindowReference?
    @Published var cameraWindow: WindowReference?
    
    // Confirmation dialog
    @Published var showConfirmationDialog = false
    @Published var confirmationAction: ConfirmationAction?
    
    // Control panel state
    @Published var restartPerformed = false
    @Published var showingConfirmation = false
    @Published var isReadyToStart = false
    
    // MARK: - Publishers
    private let viewEventSubject = PassthroughSubject<ViewEvent, Never>()
    var viewEvents: AnyPublisher<ViewEvent, Never> {
        viewEventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    private let screenRecordManager: ScreenRecordManager
    let cameraService: any CameraCaptureProvider
    private let windowContentProvider: WindowContentProvider
    
    // MARK: - Configuration
    var recordConfig: RecordConfiguration!
    var screenSize = CGSize.zero
    
    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    init(
        cameraService: any CameraCaptureProvider,
        recordConfig: RecordConfiguration,
        windowContentProvider: WindowContentProvider = SCKWindowContentService()
    ) {
        self.cameraService = cameraService
        self.recordConfig = recordConfig
        self.windowContentProvider = windowContentProvider
        
        // Create configuration
        let config = RecordingConfiguration(
            audioDeviceId: recordConfig.audioDeviceId ?? 0,
            recordMic: recordConfig.settings.enableAudio,
            audioDeviceTransportType: recordConfig.audioDeviceTransportType ?? .builtIn,
            mode: .h264_sRGB,
            videoFormat: .mp4
        )
        
        // Initialize manager
        self.screenRecordManager = ScreenRecordManager(configuration: config)
        
        setupBindings()
    }
    
    private func setupBindings() {
        screenRecordManager.events
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.handleRecordingEvent(event)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Recording Operations
    
    @MainActor
    func startRecording() async {
        do {
            viewEventSubject.send(.hidePopover)
            controlPanelVisibility = .hide
            
            // Exclude control window
            let excluded = try await windowContentProvider.getExcludedWindows(
                withTitles: ["InnerAIRecordWindow"]
            )
            
            // Setup recording
            try await screenRecordManager.record(
                displayID: recordConfig.screenInfo?.displayID ?? CGMainDisplayID(),
                selectedWindow: selectedWindow,
                cameraWindow: cameraWindow,
                excludedWindows: excluded
            )
            
            // Start
            try await screenRecordManager.start()
            controlPanelVisibility = .show
            
        } catch {
            DebugLogger.log(.error, "Recording failed: \(error)")
        }
    }
    
    @MainActor
    private func handleRecordingEvent(_ event: RecordingEvent) {
        switch event {
        case .started:
            recordingState = .inProgress
            
        case .stopped(let url):
            if let fileInfo = RecordFileManager.shared.fetchFileInfo(fromPath: url) {
                let info = FileInfo(
                    url: fileInfo.fileURL,
                    name: fileInfo.fileName,
                    size: fileInfo.fileSize,
                    type: "video/\(fileInfo.fileType)"
                )
                recordingState = .stopped(info)
            }
            
            cleanup()
            
        case .error:
            cleanup()
        }
    }
    
    func sendAction(_ action: RecordAction) {
        switch action {
        case .pause, .resume, .start:
            screenRecordManager.actionInput.send(action)
            
        case .stop:
            screenRecordManager.actionInput.send(.stop)
            
        case .restart:
            confirmationAction = .restart
            showConfirmationDialog = true
            showingConfirmation = true
            screenRecordManager.actionInput.send(.pause)
            
        case .delete:
            confirmationAction = .delete
            showConfirmationDialog = true
            showingConfirmation = true
            screenRecordManager.actionInput.send(.pause)
        }
    }
    
    @MainActor func confirmAction() {
        guard let action = confirmationAction else { return }
        
        switch action {
        case .restart:
            executeRestart()
        case .delete:
            executeDelete()
        }
        
        showConfirmationDialog = false
        showingConfirmation = false
        confirmationAction = nil
    }
    
    func cancelAction() {
        showConfirmationDialog = false
        showingConfirmation = false
        confirmationAction = nil
        
        // Resume recording
        screenRecordManager.actionInput.send(.resume)
    }
    
    private func executeRestart() {
        // Delete current file
        if let filePath = screenRecordManager.filePath {
            RecordFileManager.shared.deleteFile(atPath: filePath)
        }
        
        // Stop and restart
        Task {
            screenRecordManager.actionInput.send(.stop)
            cameraService.stopSession()
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            await MainActor.run {
                restartPerformed = true
            }
            
            await startRecording()
        }
    }
    
    @MainActor private func executeDelete() {
        // Delete file
        if let filePath = screenRecordManager.filePath {
            RecordFileManager.shared.deleteFile(atPath: filePath)
        }
        
        // Stop recording
        screenRecordManager.actionInput.send(.delete)
        recordingState = .deleted
        cleanup()
    }
    
    @MainActor
    private func cleanup() {
        cameraService.stopSession()
        viewEventSubject.send(.hideCameraWindow)
        viewEventSubject.send(.hideWindow)
    }
    
    // MARK: - Window Setup
    
    func setupWindowsForSpecificWindow(windowID: CGWindowID) async {
        do {
            selectedWindow = try await windowContentProvider.getWindow(withID: windowID)
            cameraWindow = try await windowContentProvider.getWindow(withTitle: "CameraWindow")
            
            // Delay then signal ready
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
            await MainActor.run {
                isReadyToStart = true
            }
        } catch {
            DebugLogger.log(.error, "Failed to get specific window: \(error)")
        }
    }
    
    func setupWindowsForCameraOnly() async {
        do {
            selectedWindow = try await windowContentProvider.getWindow(withTitle: "CameraWindow")
            
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                isReadyToStart = true
            }
        } catch {
            DebugLogger.log(.error, "Failed to get camera window: \(error)")
        }
    }
    
    func setupWindowsForFullScreen() async {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await MainActor.run {
            isReadyToStart = true
        }
    }
}
