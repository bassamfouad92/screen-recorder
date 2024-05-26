//
//  PlayerView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 04/05/2024.
//

import SwiftUI
import AppKit
import AVFoundation

class PlayerView: NSView {
    
    var previewLayer: AVCaptureVideoPreviewLayer?

    init(captureSession: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        super.init(frame: .zero)

        setupLayer()
    }

    func setupLayer() {

        previewLayer?.frame = self.frame
        previewLayer?.contentsGravity = .resizeAspectFill
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
