//
//  AudioRouteObserver.swift
//  InnerAI
//
//  Created by Bassam Fouad on 14/08/2024.
//
import CoreAudio
import AVFoundation
import SwiftUI
import Combine

class DeviceObserver: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    var onDeviceStatusChanged: (() -> Void)?

    init() {
        setupVideoDeviceListener()
    }
    
    deinit {}
    
    private func setupVideoDeviceListener() {
        NotificationCenter.default.publisher(for: .AVCaptureDeviceWasConnected)
            .sink { _ in
                self.updateDeviceStatus()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVCaptureDeviceWasDisconnected)
            .sink { _ in
                self.updateDeviceStatus()
            }
            .store(in: &cancellables)
    }
    
    private func updateDeviceStatus() {
        DispatchQueue.main.async {
            self.onDeviceStatusChanged?()
        }
    }
}
