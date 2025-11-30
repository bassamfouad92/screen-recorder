//
//  AppDelegate+CustomPopup.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation
import AppKit
import SwiftUI
import AVFoundation

extension AppDelegate {
    
    func configureCustomWindowPopup() {
        popupWindow = createWindow(rootView: EmptyView())
        hideCustomPopup()
    }
    
    func showCustomPopup(title: String, message: String, buttonTitle: String = "Cancel", completion: @escaping(_ isTakeMeBack: Bool) -> Void) {
        self.popupWindow?.contentView = NSHostingView(rootView: CustomPopupView(title: title, buttonTile: buttonTitle, message: message, onClick: { action in
            switch action {
            case .action:
                completion(false)
                self.hideCustomPopup()
            case .takeMeBack:
                completion(true)
            case .dismiss:
                self.hideCustomPopup()
            }
        }).environmentObject(self))
        popupWindow?.makeKeyAndOrderFront(nil)
        popupWindow?.contentView?.isHidden = false
    }
    
    func hideCustomPopup() {
        popupWindow?.contentView?.isHidden = true
    }
    
    func configureCameraWindow() {
        cameraWindow = createWindow(rootView: EmptyView(), title: "CameraWindow")
        hideCameraWindow()
    }
    
    func showCameraWindow(service: any CameraCaptureProvider, presentationStyle: CameraViewPresentationStyle, offset: CGSize, screenSize: CGRect, displayId: CGDirectDisplayID = CGMainDisplayID()) {
        self.cameraWindow?.contentView = NSHostingView(rootView: CameraPreviewOverlayView(presentationStyle: presentationStyle, offset: offset, service: service, screenSize: screenSize).environmentObject(self))
        if presentationStyle == .full {
            cameraWindow?.level = .normal
        } else {
            cameraWindow?.level = .mainMenu
        }
        // Move camera window to external display
        WindowUtil.moveWindowsToExternalDisplay(windowsInfo: [
            WindowInfo(windowTitle: "CameraWindow", appName: "Screen Recoder by Inner AI")
        ], toDisplay: displayId)
        
        self.cameraWindow?.setFrame(screenSize, display: true)
        self.cameraWindow?.toggleFullScreen(nil)
        
        cameraWindow?.makeKeyAndOrderFront(nil)
        cameraWindow?.contentView?.isHidden = false
    }
    
    func hideCameraWindow() {
        cameraWindow?.contentView?.isHidden = true
    }
}
