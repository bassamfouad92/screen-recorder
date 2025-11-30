//
//  CameraCaptureProvider.swift
//  InnerAI
//
//  Created by Bassam Fouad on 30/11/2025.
//

import Foundation
import AVFoundation
import Combine

protocol CameraCaptureProvider: ObservableObject {
    var isGranted: Bool { get set }
    var captureSession: AVCaptureSession! { get }
    var selectedCamera: AVCaptureDevice? { get set }
    
    func checkAuthorization()
    func startSession()
    func stopSession()
}
