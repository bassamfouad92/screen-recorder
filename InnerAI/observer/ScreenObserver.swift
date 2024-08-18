//
//  ScreenObserver.swift
//  InnerAI
//
//  Created by Bassam Fouad on 16/08/2024.
//
import SwiftUI
import Combine
import ScreenCaptureKit

class ScreenObserver: ObservableObject {
    @Published var screenCount: Int = NSScreen.screens.count
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.screenCount = NSScreen.screens.count
                self?.getScreensList()
                self?.onScreenChange()
            }
            .store(in: &cancellables)
    }
    
    func onScreenChange() {
        print("ScreenObserver: \(self.screenCount)")
    }
    
    ///To check if mac is connected to external screens
    func getScreensList() {
        SCShareableContent.getWithCompletionHandler({ shareableContent, error in
            if let error = error {
                print("Error retrieving windows: \(error.localizedDescription)")
                return
            }
            
            guard let shareableContent = shareableContent else {
                print("Error: Shareable content is nil")
                return
            }
            
            DispatchQueue.main.async {
                self.screenCount = shareableContent.displays.count
            }
        })
    }
}

