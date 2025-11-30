//
//  VideoView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 02/05/2024.
//

import SwiftUI
import ScreenCaptureKit
import Combine

enum RecordingControlAction {
    case stop
    case pause
    case resume
    case restart
    case delete
    case start
}

enum RecordingState: Equatable {
    case inProgress
    case stopped(any FileProtocol)
    case deleted
    
    static func ==(lhs: RecordingState, rhs: RecordingState) -> Bool {
            switch (lhs, rhs) {
            case (.inProgress, .inProgress):
                return true
            case let (.stopped(info1), .stopped(info2)):
                return info1.name == info2.name
            case (.deleted, .deleted):
                return true
            default:
                return false
            }
        }
}

struct RecordingScreenView: View {
    
    let screenSize: NSRect
    let recordConfig: RecordConfiguration
    
    @State private var offset = CGSize.zero
    @State private var cancellables = Set<AnyCancellable>()
    
    @StateObject var viewModel: RecordingScreenViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    var onStateChanged: (RecordingState) -> Void

    var body: some View {
        ZStack {
            windowContentLayer()
            cameraLayer()
        }
        .onAppear {
            viewDidAppear()
            setupViewEventHandling()
        }
        .onChange(of: viewModel.recordingState) { newState in
            handleStateChange(newState)
        }
        .onChange(of: viewModel.isReadyToStart) { ready in
            if ready {
                startRecording()
                viewModel.isReadyToStart = false // Reset
            }
        }
        .frame(width: screenSize.width, height: screenSize.height, alignment: .bottomLeading)
        .edgesIgnoringSafeArea(.all)
        .background(.clear)
        .overlay(
            controlPanelLayer(),
            alignment: .bottomLeading
        )
        .confirmationDialog(
            confirmationTitle(),
            isPresented: $viewModel.showConfirmationDialog,
            titleVisibility: .visible
        ) {
            Button(confirmationButtonTitle(), role: .destructive) {
                viewModel.confirmAction()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelAction()
            }
        } message: {
            Text(confirmationMessage())
        }
    }
    
    // MARK: - View Event Handling
    
    private func setupViewEventHandling() {
        viewModel.viewEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak appDelegate] event in
                handleViewEvent(event, appDelegate: appDelegate)
            }
            .store(in: &cancellables)
    }
    
    private func handleViewEvent(_ event: ViewEvent, appDelegate: AppDelegate?) {
        switch event {
        case .hidePopover:
            appDelegate?.hidePopOver()
        case .showControlPanel:
            break
        case .hideControlPanel:
            break
        case .hideWindow:
            appDelegate?.hideWindow()
        case .hideCameraWindow:
            appDelegate?.hideCameraWindow()
        }
    }
    
    private func handleStateChange(_ newState: RecordingState) {
        switch newState {
        case .inProgress:
            onStateChanged(.inProgress)
            DebugLogger.log(.info, "Recording started ⏺️")
        case .stopped(let file):
            onStateChanged(.stopped(file))
            DebugLogger.log(.info, "Recording stopped ✅ \(file.name)")
        case .deleted:
            onStateChanged(.deleted)
            DebugLogger.log(.info, "Recording deleted 🗑️")
        }
    }
    
    // MARK: - Confirmation Dialog
    
    private func confirmationTitle() -> String {
        guard let action = viewModel.confirmationAction else { return "" }
        switch action {
        case .restart:
            return "Restart your recording?"
        case .delete:
            return "Delete your Recording?"
        }
    }
    
    private func confirmationMessage() -> String {
        "The progress on your current video will be lost."
    }
    
    private func confirmationButtonTitle() -> String {
        guard let action = viewModel.confirmationAction else { return "" }
        switch action {
        case .restart:
            return "Restart"
        case .delete:
            return "Delete"
        }
    }
}

// MARK: - Layered View Components
extension RecordingScreenView {
    
    private func windowContentLayer() -> some View {
        if recordConfig.videoWindowType == .specific, let windowInfo = recordConfig.windowInfo {
            return AnyView(
                SpecificWindowCropView(title: windowInfo.title, onWindowFront: { bottomLeftPos, _ in
                    if recordConfig.settings.displayCamera, let _ = recordConfig.selectedCamera {
                        appDelegate.showCameraWindow(
                            service: viewModel.cameraService,
                            presentationStyle: .partial,
                            offset: CGSize(width: bottomLeftPos.x + 20, height: bottomLeftPos.y - 200),
                            screenSize: screenSize,
                            displayId: recordConfig.screenInfo?.displayID ?? CGMainDisplayID()
                        )
                    }
                })
            )
        }
        return AnyView(EmptyView())
    }
    
    private func cameraLayer() -> some View {
        if recordConfig.settings.displayCamera && recordConfig.videoWindowType == .fullScreen {
            return AnyView(
                /* DraggableView with CameraView here */
                EmptyView()
            )
        }
        return AnyView(EmptyView())
    }
    
    private func controlPanelLayer() -> some View {
        HStack {
            if viewModel.controlPanelVisibility == .show {
                ControlPanelView(
                    restartRecording: $viewModel.restartPerformed,
                    isPopupDisplayed: $viewModel.showingConfirmation,
                    onClicked: { action in
                        viewModel.sendAction(action)
                    }
                ).offset(x: offset.width, y: offset.height)
                
                DraggableView(content: {
                    Image("record_menu")
                        .resizable()
                        .frame(width: 24, height: 24)
                }, callback: { offset in
                    self.offset = offset
                }, contentSize: CGSize(width: 220, height: 60), screenSize: screenSize)
                .offset(x: -44)
            }
        }.offset(x: offset == .zero ? 250 : 0, y: -60)
         .transition(.move(edge: .bottom))
    }
}


// MARK: Lifecycle functions
extension RecordingScreenView {
    private func viewDidAppear() {
        moveWindowToExternalIfNeeded()
        viewModel.cameraService.selectedCamera = recordConfig.selectedCamera
        viewModel.cameraService.checkAuthorization()
        setupRecording()
    }
    
    private func setupRecording() {
        switch recordConfig.videoWindowType {
        case .specific:
            if let windowID = recordConfig.windowInfo?.windowID {
                Task {
                    await viewModel.setupWindowsForSpecificWindow(windowID: windowID)
                }
            }
            
        case .camera:
            if let _ = recordConfig.selectedCamera, recordConfig.settings.displayCamera {
                appDelegate.showCameraWindow(
                    service: viewModel.cameraService,
                    presentationStyle: .full,
                    offset: CGSize.zero,
                    screenSize: screenSize,
                    displayId: recordConfig.screenInfo?.displayID ?? CGMainDisplayID()
                )
                appDelegate.makeDefaultOverlayWindowsOnTop()
            }
            moveCameraWindowToExternalIfNeeded()
            Task {
                await viewModel.setupWindowsForCameraOnly()
            }
            
        case .fullScreen:
            if recordConfig.settings.displayCamera {
                appDelegate.showCameraWindow(
                    service: viewModel.cameraService,
                    presentationStyle: .partial,
                    offset: .zero,
                    screenSize: screenSize,
                    displayId: recordConfig.screenInfo?.displayID ?? CGMainDisplayID()
                )
                moveCameraWindowToExternalIfNeeded()
            }
            Task {
                await viewModel.setupWindowsForFullScreen()
            }
        }
    }
    
    private func moveWindowToExternalIfNeeded() {
        if recordConfig.isExternalDisplayConnected && (recordConfig.videoWindowType == .fullScreen || recordConfig.videoWindowType == .camera) {
            /// If external screen connected move controls window i.e InnerAIRecordWindow to external display
            let windowsToMove = [
                WindowInfo(windowTitle: "InnerAIRecordWindow", appName: "Screen Recoder by Inner AI"),
            ]
            WindowUtil.moveWindowsToExternalDisplay(windowsInfo: windowsToMove, toDisplay: recordConfig.screenInfo?.displayID ?? CGMainDisplayID())
        }
    }
    
    private func moveCameraWindowToExternalIfNeeded() {
        // Move camera window to external display
        WindowUtil.moveWindowsToExternalDisplay(windowsInfo: [
            WindowInfo(windowTitle: "CameraWindow", appName: "Screen Recoder by Inner AI")
        ], toDisplay: recordConfig.screenInfo?.displayID ?? CGMainDisplayID())
    }
}

// MARK: Screen capture kit recordering functions
//
extension RecordingScreenView {
    private func startRecording() {
        onStateChanged(.inProgress)
        Task {
            await viewModel.startRecording()
        }
    }
}


