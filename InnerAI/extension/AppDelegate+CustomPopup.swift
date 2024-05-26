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
    
    func showCameraWindow(viewModel: ContentViewModel, presentationStyle: CameraViewPresentationStyle) {
        self.cameraWindow?.contentView = NSHostingView(rootView: CameraPreviewOverlayView(presentationStyle: presentationStyle, viewModel: viewModel).environmentObject(self))
        cameraWindow?.makeKeyAndOrderFront(nil)
        cameraWindow?.contentView?.isHidden = false
    }
    
    func hideCameraWindow() {
        cameraWindow?.contentView?.isHidden = true
    }
}
