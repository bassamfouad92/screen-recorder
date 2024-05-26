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
    @ObservedObject var viewModel: ContentViewModel

    init(presentationStyle: CameraViewPresentationStyle, viewModel: ContentViewModel) {
        self.presentationStyle = presentationStyle
        self.viewModel = viewModel
    }
    
    var body: some View {
        applyCustomModifiers(to: PlayerContainerView(captureSession: viewModel.captureSession))
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
