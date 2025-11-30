//
//  CameraView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 04/05/2024.
//

import SwiftUI

enum CameraViewPresentationStyle {
    case full
    case partial
}

struct CameraView: View {
        
    let presentationStyle: CameraViewPresentationStyle
    let service: any CameraCaptureProvider

    init(presentationStyle: CameraViewPresentationStyle, service: any CameraCaptureProvider = CameraCaptureService()) {
        self.presentationStyle = presentationStyle
        self.service = service
    }
    
    var body: some View {
        applyCustomModifiers(to: PlayerContainerView(captureSession: service.captureSession))
    }
    
    @ViewBuilder
    private func applyCustomModifiers(to view: PlayerContainerView) -> some View {
        switch presentationStyle {
        case .partial:
            view
                .frame(width: 190, height: 190)
                .clipShape(Circle())
        case .full:
            view
                .background(Color.clear)
        }
    }
}
