//
//  VideoView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 02/05/2024.
//

import SwiftUI
import ScreenCaptureKit

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
    
    @StateObject var viewModel: RecordingScreenViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    
    var onStateChanged: (RecordingState) -> Void

    var body: some View {
        ZStack {
            windowContentLayer()
            cameraLayer()
        }.onAppear {
            viewDidAppear()
        }.onChange(of: viewModel.recordingState) { newState in
            switch newState {
            case .inProgress:
                onStateChanged(.inProgress)
                print("Recording started ⏺️")
            case .stopped(let file):
                onStateChanged(.stopped(file))
                print("Recording stopped ✅", file.name)
            case .deleted:
                onStateChanged(.deleted)
                print("Recording deleted 🗑️")
            }
        }
        .frame(width: screenSize.width, height: screenSize.height, alignment: .bottomLeading)
            .edgesIgnoringSafeArea(.all)
            .background(.clear)
            .overlay(
                controlPanelLayer(),
                alignment: .bottomLeading
            )

    }
    
    // MARK: Screen capture kit handler
    private func getSpecificWindow() {
        Task {
            let sharableContent = try await SCShareableContent.current
            if let windowID = recordConfig.windowInfo?.windowID {
                viewModel.selectedWindow = sharableContent.windows.first(where: { $0.windowID == windowID })
                viewModel.cameraWindow = sharableContent.windows.first(where: { $0.title == "CameraWindow" })
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    startRecording()
                }
            }
        }
    }
    
    private func getCameraOnlyWindows() {
        
        SCShareableContent.getWithCompletionHandler { shareableContent, error in
            if let error = error {
                print("Error retrieving windows: \(error.localizedDescription)")
                return
            }
            
            guard let shareableContent = shareableContent else {
                print("Error: Shareable content is nil")
                return
            }
            
            DispatchQueue.main.async {
                if let cameraWindow = shareableContent.windows.first(where: { $0.title == "CameraWindow" }) {
                    viewModel.selectedWindow = cameraWindow
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        startRecording()
                    }
                }
            }
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
                            viewModel: viewModel.contentViewModel,
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
                    isPopupDisplayed: $viewModel.displayingActionPopup,
                    onClicked: { action in
                        viewModel.actionSubject.send(action)
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
        viewModel.appDelegate = appDelegate
        viewModel.recordConfig = recordConfig
        viewModel.displayingActionPopup = false
        
        moveWindowToExternalIfNeeded()
        viewModel.contentViewModel.selectedCamera = recordConfig.selectedCamera
        viewModel.contentViewModel.checkAuthorization()
        setupRecording()
    }
    
    private func setupRecording() {
        if recordConfig.videoWindowType == .specific {
            getSpecificWindow()
        } else if recordConfig.videoWindowType == .camera {
            if let _ = recordConfig.selectedCamera, recordConfig.settings.displayCamera {
                appDelegate.showCameraWindow(viewModel: viewModel.contentViewModel, presentationStyle: .full, offset: CGSize.zero, screenSize: screenSize, displayId: recordConfig.screenInfo?.displayID ?? CGMainDisplayID())
                appDelegate.makeDefaultOverlayWindowsOnTop()
            }
            moveCameraWindowToExternalIfNeeded()
            getCameraOnlyWindows()
        } else {
            if recordConfig.settings.displayCamera {
                appDelegate.showCameraWindow(viewModel: viewModel.contentViewModel, presentationStyle: .partial, offset: .zero, screenSize: screenSize, displayId: recordConfig.screenInfo?.displayID ?? CGMainDisplayID())
                moveCameraWindowToExternalIfNeeded()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                startRecording()
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
    
    private func viewDidDisappear() {
        appDelegate.hideCameraWindow()
    }
}

// MARK: Screen capture kit recordering functions
//
extension RecordingScreenView {
    private func startRecording() {
        appDelegate.hidePopOver()
        onStateChanged(.inProgress)
        Task {
            await viewModel.startRecording()
        }
    }
}
