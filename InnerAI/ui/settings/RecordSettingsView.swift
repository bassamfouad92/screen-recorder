//
//  RecordSettingsView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 30/04/2024.
//

import SwiftUI
import AVFoundation
import ScreenCaptureKit
import ApplicationServices

enum SettingsViewType {
    case video, camera, microphone, quit, none
}

struct RecordSettingsView: View {
    
    @State private var viewModel = RecordSettingsViewModel()
    @State private var settingsViewType: SettingsViewType = .none
    @State private var showRecordSettings = true

    @State private var videoSettingOption: any SelectableOption = Option(title: "", icon: "monitor", rightIcon: .settings)
    @State private var cameraSettingOption: any SelectableOption = Option(title: "Default - Camera", icon: "video", rightIcon: .settings)
    @State private var micSettingOption: any SelectableOption = Option(title: "Default - MacBook", icon: "microphone-icon", rightIcon: .settings)
    @State private var showAlert = false
    @State private var showErrorMessage = ""
    @State private var isRecordButtonHovered = false

    @EnvironmentObject var appDelegate: AppDelegate
    
    var isCameraAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            var isAuthorized = status == .authorized
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            return isAuthorized
        }
    }
    
    var isMicrophoneAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            var isAuthorized = status == .authorized
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
            }
            return isAuthorized
        }
    }


    var body: some View {
        
        VStack(spacing: 5) {
            
            HStack {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(0.4)
                    .padding(.leading, 30)
                if showRecordSettings {
                    Button(action: {
                        if settingsViewType == .quit {
                                settingsViewType = .none
                        } else {
                            settingsViewType = .quit
                        }
                    }) {
                        Image("menu_icon") // Example system image for menu button
                            .resizable()
                            .frame(width: 30, height: 30)
                            .aspectRatio(contentMode: .fill)
                            .background(.clear)
                    }.buttonStyle(PlainButtonStyle())
                }
            }.padding()
            
            
            if showRecordSettings {
                
                Text("Record settings")
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .padding(.bottom, 10)
                
                VStack(spacing: 10) {
                   SettingOptionView(model: $videoSettingOption, OnSelected: {}, onTap: {
                       if settingsViewType == .video {
                               settingsViewType = .none
                       } else {
                           settingsViewType = .video
                       }
                   })
                   SettingOptionView(model: $cameraSettingOption, OnSelected: {}, onTap: {
                       if settingsViewType == .camera {
                               settingsViewType = .none
                       } else {
                           settingsViewType = .camera
                       }
                   })
                   SettingOptionView(model: $micSettingOption, OnSelected: {}, onTap: {
                       if settingsViewType == .microphone {
                           settingsViewType = .none
                       } else {
                           settingsViewType = .microphone
                       }
                   })
               }.onAppear {
                   viewModel.configureCameraAndMic()
                   viewModel.checkForUpdates()
                   
                   if let videoOption = viewModel.videoOptions.first {
                       videoSettingOption = videoOption.withRightIcon(.settings).withSelected(false)
                       viewModel.setSelectedVideo(with: videoOption as! VideoOption)
                   }
                   if let camera = viewModel.cameraOptions.first(where: { $0.isSelected }) {
                       cameraSettingOption = camera.withRightIcon(.settings).withSelected(false)
                   }
                   if let mic = viewModel.voiceOptions.first(where: { $0.isSelected }) {
                       micSettingOption = mic.withRightIcon(.settings).withSelected(false)
                   }
                   //delete all saved files
                   RecordFileManager.shared.deleteAllMP4Files()
               }
                
                Button(action: {
                    validateAndDisplayRecordView()
                }) {
                    Image("start-recording-button")
                        .resizable()
                        .frame(width: 260, height: 50) // Adjust size as needed
                        .aspectRatio(contentMode: .fit)
                }.buttonStyle(BorderlessButtonStyle()).padding([.top, .bottom], 20)
                    .shadow(color: .appPurple.opacity(isRecordButtonHovered ? 0.8 : 0), radius: 12, x: 0, y: 10)
                    .onHover { hovering in
                        withAnimation {
                            isRecordButtonHovered = hovering
                        }
                    }
                
                if !showErrorMessage.isEmpty {
                    Text(showErrorMessage).foregroundColor(.red).fixedSize(horizontal: true, vertical: false)
                }
                
            } else {
                ActivityIndicatorWithText(text: "Recording in progress")
            }
            
            
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .backGradientOne,
                            .backGradientTwo,
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                ).padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
        )
        .frame(maxWidth: 280)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            Task {
                await setUpCameraCapture()
                await setUpAudioCapture()
                setUpScreenCapture()
            }
            
            //observing popover show and hide
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "popover"), object: nil, queue: .main) { notification in
                // Extract userInfo dictionary from the notification object
                if let payload = notification.object as? [String: Bool], let popoverShowing = payload["is_show"] {
                    if !popoverShowing {
                        settingsViewType = .none
                        videoSettingOption.isSelected = false
                        micSettingOption.isSelected = false
                        cameraSettingOption.isSelected = false
                    }
                }
            }
        }
        .onTapGesture {
            settingsViewType = .none
            setAllInUnselectedState()
        }
        .onChange(of: settingsViewType, perform: { view in
            if view == .none {
                setAllInUnselectedState()
            }
        })
        .popover(isPresented: .constant(settingsViewType != .none), attachmentAnchor: popoverArrowAlignment(), arrowEdge: .leading) {
            VStack {
                // View based on currentView
                switch settingsViewType {
                case .video:
                    VideoRecordOptionListView(options: viewModel.videoOptions, didSelectVideoOption: { option in
                        
                        hideOptionsPopOver()
                        
                       switch option.videoWindowType {
                          case .fullScreen, .camera:
                            videoSettingOption = option.withRightIcon(.settings).withSelected(false)
                            viewModel.setSelectedVideo(with: option)
                            viewModel.configureRecordConfig(videoWindowType: option.videoWindowType)
                          case .specific:
                            routeToWindowSelectionIfNeeded(option: option)
                        }
                        
                    })
                case .camera:
                    CameraOptionListView(options: viewModel.cameraOptions, didSelectCameraOption: {
                        option in
                        hideOptionsPopOver()
                        if option.allowCamera {
                            viewModel.selectedCamera = option.title
                        } else {
                            appDelegate.hideWindow()
                        }
                        viewModel.setSelectedCamera(with: option)
                        viewModel.allowCamera = option.allowCamera
                        cameraSettingOption = option.withRightIcon(.settings).withSelected(false)
                    })
                case .microphone:
                    VoiceOptionListView(options: viewModel.voiceOptions, didSelectVoiceOption: {
                        option in
                        hideOptionsPopOver()
                        viewModel.setSelectedMicrophone(with: option)
                        viewModel.allowMicrophone = option.allowMicrophone
                        micSettingOption = option.withRightIcon(.settings).withSelected(false)
                    })
                case .quit:
                    QuitAndLogoutView(onLogout: {
                        viewModel.logout()
                        appDelegate.hideWindow()
                        appDelegate.displayLoginView()
                    })
                default:
                    EmptyView()
                }
            }
        }.alert("Please allow screen capture permission to continue", isPresented: $showAlert) {
            Button("Open settings", role: .cancel) {
                appDelegate.hideWindow()
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
        }
    }
    
    private var customRect: CGRect {
        CGRect(x: 280 - 50.0, y: 0, width: 100, height: 100)
    }
    
    func popoverArrowAlignment() -> PopoverAttachmentAnchor {
        switch settingsViewType {
        case .quit:
            return .rect(.rect(customRect))
        case .video:
            return .rect(.rect(CGRect(x: 0, y: 50, width: 100, height: 200)))
        case .microphone:
            return .rect(.rect(CGRect(x: 0, y: 120, width: 100, height: 600)))
        default:
            return .rect(.rect(CGRect(x: 0, y: 20, width: 100, height: 600)))
        }
    }
    
    func hideOptionsPopOver() {
        settingsViewType = .none
        showErrorMessage = ""
    }
    
    func setAllInUnselectedState() {
        videoSettingOption = videoSettingOption.withSelected(false)
        micSettingOption = micSettingOption.withSelected(false)
        cameraSettingOption = cameraSettingOption.withSelected(false)
    }
    
    func validateIfCameraOnly() -> Bool {
        if viewModel.recordConfig.videoWindowType == .camera {
            return viewModel.recordConfig.settings.displayCamera
        }
        return true
    }
    
    private func validateIfSpecificWindowAvailable() {
        
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
                let windowID = viewModel.recordConfig.windowInfo?.windowID
                guard shareableContent.windows.first(where: { $0.windowID == windowID }) != nil else {
                    showErrorMessage = "\(videoSettingOption.title) not found, or closed."
                    return
                }
                routeToVideoRecordView()
            }
        }
    }
    
    func validateAndDisplayRecordView() {
        if !isCameraMicPermission() {
            return
        }
        
        guard CGPreflightScreenCaptureAccess() else {
            showAlert = true
            return
        }
        
        if !validateIfCameraOnly() {
            showErrorMessage = "Please select a camera before proceed"
            return
        }
        
        if viewModel.recordConfig.videoWindowType == .specific {
            validateIfSpecificWindowAvailable()
        } else {
            routeToVideoRecordView()
        }
    }
}

// MARK: Routing
//
extension RecordSettingsView {
    
    func routeToWindowSelectionIfNeeded(option: VideoOption) {
        guard CGPreflightScreenCaptureAccess() else {
            showAlert = true
            return
        }
        
        AccessibilityHelper.askForAccessibilityIfNeeded(appDelegate: appDelegate) { accessibilityEnabled in
            DispatchQueue.main.async {
                if accessibilityEnabled {
                    self.appDelegate.diplaySelectRecordWindowView(completion: { selectedWindow in
                        self.videoSettingOption = option.withRightIcon(.settings).withSelected(false)
                        self.videoSettingOption.title = selectedWindow.title
                        self.viewModel.setSelectedVideo(with: option)
                        self.viewModel.configureRecordConfig(videoWindowType: .specific, windowInfo: selectedWindow)
                        self.routeToCropView()
                    })
                } else {
                    // The user either cancelled or needs to grant permission in System Preferences
                    // We don't proceed with window selection
                    print("Accessibility permission not granted")
                    self.appDelegate.hidePopOver()
                }
            }
        }
    }
    
    func routeToVideoRecordView() {
        hideOptionsPopOver()
        appDelegate.diplayVideoWindowView(withRecord: viewModel.recordConfig, callback: { state in
            switch state {
            case .inProgress:
                showRecordSettings = false
            case .stopped(let fileInfo):
                showRecordSettings = true
                routeToUploadView(fileInfo: fileInfo as! FileInfo)
            default:
                // reset to default state i.e full screen
                viewModel.recordConfig = RecordConfiguration(videoWindowType: .fullScreen, windowInfo: nil)
                showRecordSettings = true
            }
        })
    }
    
    func routeToUploadView(fileInfo: FileInfo) {
        appDelegate.displayUploadViewPopOver(fileInfo: fileInfo)
    }
    
    func routeToCropView() {
        appDelegate.diplayCropWindowView(showWith: viewModel.recordConfig.windowInfo?.runningApplicationName ?? "")
    }
}

// MARK: Permissions
//
extension RecordSettingsView {
    
    func setUpCameraCapture() async {
        guard await isCameraAuthorized else {
            return
        }
        print("Auhtorized camera")
    }
    
    func setUpAudioCapture() async {
        guard await isMicrophoneAuthorized else {
            return
        }
        print("Auhtorized microphone")
    }

    func setUpScreenCapture() {
        let hasScreenAccess = CGPreflightScreenCaptureAccess()
        if !hasScreenAccess {
            CGRequestScreenCaptureAccess()
        }
        print("Screen capture access requested")
    }
    
    func isCameraMicPermission() -> Bool {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            appDelegate.showCustomPopup(title: "Permission", message: "Please allow camera permission in setting to proceed", buttonTitle: "Settings", completion: { isTakeMeBack in
                if isTakeMeBack {
                    appDelegate.hideCustomPopup()
                    return
                }
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
            })
            return false
        }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            appDelegate.showCustomPopup(title: "Permission", message: "Please allow microphon permission in setting to proceed", buttonTitle: "Settings", completion: { isTakeMeBack in
                if isTakeMeBack {
                    appDelegate.hideCustomPopup()
                    return
                }
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)

            })
            return false
        }
        return true
    }
}