//
//  VideoView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 02/05/2024.
//

import SwiftUI
import ScreenCaptureKit

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
    
    @State private var selectedWindow: SCWindow?
    @State private var cameraWindow: SCWindow?
    @State private var screenRecorder: ScreenRecorder?
    @State private var url: URL?
    @State private var screenRecordManager: ScreenRecordManager?
    @State private var restartPerformed: Bool = false
    @State private var displayingActionPopup: Bool = false

    @ObservedObject var viewModel = ContentViewModel()
    @EnvironmentObject var appDelegate: AppDelegate

    var onStateChanged: (RecordingState) -> Void
    @State private var offset = CGSize.zero
    @State private var shouldStartControlPannel = true

    var body: some View {
        ZStack {
            if recordConfig.videoWindowType == .specific && recordConfig.windowInfo != nil {
                SpecificWindowCropView(title: recordConfig.windowInfo?.title ?? "", onWindowFront: { bottomLeftPos,_ in
                    if let _ = recordConfig.selectedCamera, recordConfig.settings.displayCamera {
                        appDelegate.showCameraWindow(viewModel: viewModel, presentationStyle: .partial, offset: CGSize(width:  bottomLeftPos.x + 20, height: bottomLeftPos.y - 200), screenSize: screenSize, displayId: recordConfig.screenInfo?.displayID ?? CGMainDisplayID())
                    }
                })
            }
            if recordConfig.settings.displayCamera {
                if recordConfig.videoWindowType == .fullScreen {
                    /*DraggableView(content: {
                        CameraView(presentationStyle: .partial, viewModel: viewModel)
                    }, callback: { _ in
                        
                    }, contentSize: CGSize(width: 190, height: 130), screenSize: screenSize).offset(y: -60)*/
                }
            }
        }.onAppear {
            viewDidAppear()
        }.frame(width: screenSize.width, height: screenSize.height, alignment: .bottomLeading)
            .edgesIgnoringSafeArea(.all)
            .background(.clear)
            .overlay(
                        HStack {
                            if !shouldStartControlPannel {
                                ControlPanelView(restartRecording: $restartPerformed, isPopupDisplayed: $displayingActionPopup, onClicked: { action in
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
                                        onStateChanged(.inProgress)
                                        break
                                    }
                                }).offset(x: offset.width, y: offset.height)
                            }
                            if !shouldStartControlPannel {
                                DraggableView(content: {
                                    Image("record_menu")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                }, callback: { offset in
                                    self.offset = offset
                                }, contentSize: CGSize(width: 220, height: 60), screenSize: screenSize).offset(x: -44)
                            }
                        }.offset(x: offset == .zero ? 250 : 0, y: -60)
                            .transition(.move(edge: .bottom)), // Optional: Add a transition animation
                alignment: .bottomLeading
            )
    }
    
    // MARK: Screen capture kit handler
    private func getSpecificWindow() {
        Task {
            let sharableContent = try await SCShareableContent.current
            if let windowID = recordConfig.windowInfo?.windowID {
                selectedWindow = sharableContent.windows.first(where: { $0.windowID == windowID })
                cameraWindow = sharableContent.windows.first(where: { $0.title == "CameraWindow" })
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
                    selectedWindow = cameraWindow
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        startRecording()
                    }
                }
            }
        }
    }
}
// MARK: Lifecycle functions
extension RecordingScreenView {
    private func viewDidAppear() {
        moveWindowToExternalIfNeeded()
        viewModel.selectedCamera = recordConfig.selectedCamera
        viewModel.checkAuthorization()
        setupRecording()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            shouldStartControlPannel = false
        }
    }
    
    private func setupRecording() {
        if recordConfig.videoWindowType == .specific {
            getSpecificWindow()
        } else if recordConfig.videoWindowType == .camera {
            if let _ = recordConfig.selectedCamera, recordConfig.settings.displayCamera {
                appDelegate.showCameraWindow(viewModel: viewModel, presentationStyle: .full, offset: CGSize.zero, screenSize: screenSize, displayId: recordConfig.screenInfo?.displayID ?? CGMainDisplayID())
                appDelegate.makeDefaultOverlayWindowsOnTop()
            }
            moveCameraWindowToExternalIfNeeded()
            getCameraOnlyWindows()
        } else {
            if recordConfig.settings.displayCamera {
                appDelegate.showCameraWindow(viewModel: viewModel, presentationStyle: .partial, offset: .zero, screenSize: screenSize, displayId: recordConfig.screenInfo?.displayID ?? CGMainDisplayID())
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
    private func initRecorder() async {
        do {
            url = URL(filePath: FileManager.default.currentDirectoryPath).appending(path: "recording-bsm \(Date()).mov")
            screenRecordManager = ScreenRecordManager()
            screenRecordManager?.audioDeviceId = recordConfig.audioDeviceId ?? 0
            screenRecordManager?.recordMic = recordConfig.settings.enableAudio
            screenRecordManager?.audioDeviceTransportType = recordConfig.audioDeviceTransportType ?? .builtIn
            screenRecordManager?.onStopStream = { stream in
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
            // exclude record controls from recorded video output result
            var excludedWindows: [SCWindow] = []
            if let controlsWindow = (try await SCShareableContent.current.windows.first(where: { $0.title == "InnerAIRecordWindow"})) {
                excludedWindows.append(controlsWindow)
            }
            try await screenRecordManager?.record(displayID: recordConfig.screenInfo?.displayID ?? CGMainDisplayID(), selectedWindow: selectedWindow, cameraWindow: cameraWindow, excludedWindows: excludedWindows)
        } catch {
            print("Error during recording:", error)
        }
    }
    
    private func startRecording() {
        appDelegate.hidePopOver()
        onStateChanged(.inProgress)
        
        Task {
           await initRecorder()
           try await screenRecordManager?.start()
        }
    }

    private func stopRecordingSession(stopCameraCapturing: Bool = true, isRestart: Bool = false) {
        Task {
            do {
                if stopCameraCapturing {
                    viewModel.stopSession()
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

// MARK: Record operations function
//
extension RecordingScreenView {
    private func deleteRecording() {
        displayingActionPopup = true
        screenRecordManager?.isPause = true
        appDelegate.showCustomPopup(title: "Delete your Recording?", message: "The progress on your current video will be lost.", buttonTitle: "Delete", completion: { isTakeMeBackClicked in
            
            if isTakeMeBackClicked {
                displayingActionPopup = false
                appDelegate.hideCustomPopup()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.screenRecordManager?.isPause = false
                }
                return
            }
            
            if let filePath = screenRecordManager?.filePath {
                stopRecordingSession()
                RecordFileManager.shared.deleteFile(atPath: filePath)
                onStateChanged(.deleted)
                appDelegate.hideWindow()
            }
        })
    }
    
    private func restartRecording() {
        displayingActionPopup = true
        screenRecordManager?.isPause = true
        appDelegate.showCustomPopup(title: "Restart your recording?", message: "The progress on your current video will be lost.", buttonTitle: "Restart", completion: { isTakeMeBackClicked in
            
            if isTakeMeBackClicked {
                displayingActionPopup = false
                appDelegate.hideCustomPopup()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.screenRecordManager?.isPause = false
                }
                return
            }
            //delete file
            if let filePath = screenRecordManager?.filePath {
                RecordFileManager.shared.deleteFile(atPath: filePath)
            }
            stopRecordingSession(stopCameraCapturing: false, isRestart: true)
            startRecording()
            restartPerformed = true
        })
    }
    
    private func stopRecording() {
        
        guard let fileURL = screenRecordManager?.fileURL, let fileInfo =  RecordFileManager.shared.fetchFileInfo(fromPath: fileURL) else {
            stopRecordingSession()
            appDelegate.hideWindow()
            return
        }
        
        onStateChanged(.stopped(FileInfo(url: fileInfo.fileURL, name: fileInfo.fileName, size: fileInfo.fileSize, type: "video/\(fileInfo.fileType)")))

        stopRecordingSession()
        viewDidDisappear()
        appDelegate.hideWindow()
    }
}
