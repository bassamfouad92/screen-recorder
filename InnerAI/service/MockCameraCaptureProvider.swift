//
//  MockCameraCaptureProvider.swift
//  InnerAI
//
//  Created by Bassam Fouad on 30/11/2025.
//

import Foundation
import AVFoundation
import Combine

#if DEBUG
final class MockCameraCaptureProvider: CameraCaptureProvider {
    
    @Published var isGranted: Bool = false
    var captureSession: AVCaptureSession!
    var selectedCamera: AVCaptureDevice?
    
    var checkAuthorizationCalled = false
    var startSessionCalled = false
    var stopSessionCalled = false
    
    init() {
        captureSession = AVCaptureSession()
    }
    
    func checkAuthorization() {
        checkAuthorizationCalled = true
        // Simulate granted permission
        isGranted = true
    }
    
    func startSession() {
        startSessionCalled = true
    }
    
    func stopSession() {
        stopSessionCalled = true
    }
}
#endif
