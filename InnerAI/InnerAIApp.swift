//
//  InnerAIApp.swift
//  InnerAI
//
//  Created by Bassam Fouad on 26/04/2024.
//

import SwiftUI
import AVFoundation
import RollbarNotifier
import raygun4apple
import Combine

@main
struct InnerAIApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
                .navigationTitle("Settings")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    var window: NSWindow?
    var popupWindow: NSWindow?
    var cameraWindow: NSWindow?
    var popoverShow = true

    var loginView: some View {
        LoginView(viewModel: AppConfigurator.configureLoginViewModel()).environmentObject(self)
    }
    
    var recordSettingView: some View {
        RecordSettingsView().environmentObject(self)
    }
    
    var colorScheme: NSAppearance.Name {
        return NSApp.effectiveAppearance.name
    }
    
    func lightColorSchemes() -> [NSAppearance.Name] {
        return [.aqua, .vibrantLight, .accessibilityHighContrastVibrantLight, .accessibilityHighContrastAqua]
    }

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        configureRayGun()
        configureRollBar()
        configureOverlayWindow()
        configureCustomWindowPopup()
        configureCameraWindow()
        configurePopoverView(rootView: initialView())
        configureStatusItem()
        showPopover()
    }

    func loginWithBrowser() {
        let urlString = AppSettings.shared.environment.platformUrl + "/home.html?source=screenrecorder"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hidePopOver()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        print("App in fourground!!!")
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.hidePopOver()
        }
    }

    
        
    func configureRollBar() {
        let config = RollbarConfig.mutableConfig(withAccessToken: "aa8b8b3e2e7e44148ca6e897ab5293e7")
            config.loggingOptions.logLevel = .error
            config.loggingOptions.crashLevel = .critical
            config.telemetry.captureLog = true
            Rollbar.initWithConfiguration(config)
    }
    
    func configureRayGun() {
        let raygunClient = RaygunClient.sharedInstance(apiKey: "Z4RluGeas5hPY17uTjkfWQ")
        raygunClient.enableCrashReporting()
    }
    
    func initialView() -> any View {
        return UserSessionManager.isUserLoggedIn() ? recordSettingView : loginView
    }
    
    func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let statusButton = statusItem.button {
            let tintedBlackImage = NSImage(named: "status_bar_icon")
            statusButton.image?.isTemplate = true
            statusButton.image = tintedBlackImage
            statusButton.action = #selector(togglePopover)
        }
    }
    
    func configureOverlayWindow() {
        window = createWindow(rootView: EmptyView())
        //hide it initially
        hideWindow()
    }
    
    func makeDefaultOverlayWindowsOnTop() {
        window?.orderFrontRegardless()
    }
    
    func showWindow() {
        self.window?.makeKeyAndOrderFront(nil)
        self.window?.contentView?.isHidden = false
    }
    
    func hideWindow() {
        self.window?.contentView?.isHidden = true
    }
    
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch url.host {
            case "post-login":
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let email = queryItems?.first(where: { $0.name == "email" })?.value
                let apiKey = queryItems?.first(where: { $0.name == "api_key" })?.value
                if let email = email, let apiKey = apiKey {
                    performLogin(email: email, apiKey: apiKey)
                }
            case "open-app":
                if UserSessionManager.isUserLoggedIn() {
                    DispatchQueue.main.async {
                        self.displayRecordSettingsView()
                    }
                }
            default:
                continue
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()  // Add this line

    private func performLogin(email: String, apiKey: String) {
        let loginService = LoginServiceImp(httpClient: AppConfigurator.client)
        loginService.login(email: email, password: apiKey)
            .receive(on: DispatchQueue.main)  // Ensure UI updates are on the main thread
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished:
                    print("Login successful")
                case .failure(let error):
                    print("Login failed: \(error.localizedDescription)")
                    // Optionally handle login failure, e.g., show an error message
                }
            }, receiveValue: { [weak self] loginResponse in
                print("Login response: \(loginResponse)")
                // Save the login details in UserSessionManager
                UserSessionManager.apiKey = apiKey
                UserSessionManager.currentSpace = loginResponse.spaceId
                UserSessionManager.userId = loginResponse.userId
                // Handle successful login, update session, etc.
                self?.displayRecordSettingsView()  // Display the record settings view
            })
            .store(in: &cancellables)
    }

    
}

// MARK: Popover config and routing
extension AppDelegate {
    func configurePopoverView<Content: View>(rootView: Content) {
        self.popover = NSPopover()
        self.popover.appearance = NSAppearance(named: .aqua)
        self.popover.contentSize = NSSize(width: 280, height: 600)
        self.popover.behavior = .transient
        self.popover.animates = false
        self.popover.delegate = self
        let hostingController = NSHostingController(rootView: rootView)
        self.popover.contentViewController = hostingController
        self.popover.contentViewController?.view.window?.makeKey()
    }
    
    func displayLoginView() {
        hidePopOver()
        self.popover.contentViewController = NSHostingController(rootView: loginView)
        showPopover(duration: 0)
    }
    
    func displayRecordSettingsView() {
        hidePopOver()
        self.popover.contentViewController = NSHostingController(rootView: recordSettingView)
        showPopover(duration: 0)
    }
    
    func displayUploadViewPopOver(fileInfo: FileInfo) {
        hidePopOver()
        self.popover.contentViewController = NSHostingController(rootView: UploadVideoView(viewModel: AppConfigurator.configureUploadViewModel(with: fileInfo)).environmentObject(self))
        showPopover(duration: 0)
    }
    
    func showPopover(duration: Double = 0.2) {
        if let button = statusItem.button {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    func hidePopOver() {
        self.popover.performClose(nil)
    }
    
}

// MARK: Overlay views
extension AppDelegate {
    func diplaySelectRecordWindowView(completion: @escaping (_ selectedWindow: OpenedWindowInfo) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.hidePopOver()
        }
        self.window?.contentView = NSHostingView(rootView: SelectRecordWindowView(onSelectedWindow: {
            self.showPopover()
            completion($0)
        }).environmentObject(self))
        showWindow()
    }
    
    func diplayVideoWindowView(withRecord config: RecordConfiguration, callback: @escaping (RecordingState) -> Void) {
        hidePopOver()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.hidePopOver()
        }
        self.window?.contentView = NSHostingView(rootView: VideoView(recordConfig: config, onStateChanged: { state  in
            callback(state)
        }).environmentObject(self))
        showWindow()
    }
    
    func displayCameraPreview() {
        hidePopOver()
        self.window?.contentView = NSHostingView(rootView: CameraPreviewOverlayView(viewModel: ContentViewModel()).environmentObject(self))
        showWindow()
    }
    
    func diplayCropWindowView(showWith runningApplicationName: String) {
        hidePopOver()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.hidePopOver()
        }
        self.window?.contentView = NSHostingView(rootView: SpecificWindowCropView(runningApplicationName: runningApplicationName, onWindowFront: { _ in }).environmentObject(self))
        showWindow()
    }
}

extension AppDelegate: NSPopoverDelegate {
    
    func popoverDidShow(_ notification: Notification) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "popover"), object: ["is_show" : true])
    }
    func popoverDidClose(_ notification: Notification) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "popover"), object: ["is_show" : false])
    }
}
