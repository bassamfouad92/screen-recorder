//
//  PlayerContainerView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 04/05/2024.
//
import AVFoundation
import SwiftUI

struct PlayerContainerView: NSViewRepresentable {
    
    typealias NSViewType = PlayerView

    let captureSession: AVCaptureSession

    init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
    }

    func makeNSView(context: Context) -> PlayerView {
        return PlayerView(captureSession: captureSession)
    }

    func updateNSView(_ nsView: PlayerView, context: Context) { }
}
