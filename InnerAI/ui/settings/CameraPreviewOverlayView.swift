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
    @State var offset: CGSize = CGSize.zero
    @ObservedObject var viewModel: ContentViewModel
    let screenSize: CGRect
    
    var body: some View {
        ZStack {
            if presentationStyle == .partial {
                if offset != .zero {
                    DraggableView(content: {
                        CameraView(presentationStyle: presentationStyle, viewModel: viewModel)
                    }, callback: { _ in
                    }, contentSize: CGSize(width: 190, height: 130), specificWindowSize: offset, screenSize: screenSize).offset(x: offset.width, y: offset.height)
                } else {
                    DraggableView(content: {
                        CameraView(presentationStyle: .partial, viewModel: viewModel)
                    }, callback: { _ in
                        
                    }, contentSize: CGSize(width: 190, height: 130), screenSize: screenSize).offset(y: -60)
                }
            } else {
                CameraView(presentationStyle: presentationStyle, viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.checkAuthorization()
        }
        .frame(width: screenSize.width, height: screenSize.height, alignment: offset != .zero ? .topLeading : .bottomLeading)
        .background(.clear)
    }
}

