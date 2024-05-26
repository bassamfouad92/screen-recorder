//
//  CameraPreviewOverlayView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 07/05/2024.
//

import SwiftUI
import AVFoundation

struct CameraPreviewOverlayView: View {
    
    var presentationStyle: CameraViewPresentationStyle = .partial
    @ObservedObject var viewModel: ContentViewModel
    let screenSize = NSScreen.main?.frame.size ?? .zero
    
    var body: some View {
        ZStack {
            if presentationStyle == .partial {
                DraggableView(content: {
                    CameraView(presentationStyle: presentationStyle, viewModel: viewModel)
                }, callback: { _ in
                    
                }, contentSize: CGSize(width: 190, height: 130)).offset(y: -60)
            } else {
                CameraView(presentationStyle: presentationStyle, viewModel: viewModel)
            }
        }
        .allowsHitTesting(presentationStyle == .partial)
        .onAppear {
            viewModel.checkAuthorization()
        }
        .frame(maxWidth: screenSize.width, maxHeight: screenSize.height, alignment: .bottomLeading)
            .padding()
            .background(.clear)
    }
}

