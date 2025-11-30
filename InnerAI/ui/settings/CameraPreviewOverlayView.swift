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
    let service: any CameraCaptureProvider
    let screenSize: CGRect
    
    var body: some View {
        ZStack {
            if presentationStyle == .partial {
                if offset != .zero {
                    DraggableView(content: {
                        CameraView(presentationStyle: presentationStyle, service: service)
                    }, callback: { _ in
                    }, contentSize: CGSize(width: 190, height: 130), specificWindowSize: offset, screenSize: screenSize).offset(x: offset.width, y: offset.height)
                } else {
                    DraggableView(content: {
                        CameraView(presentationStyle: .partial, service: service)
                    }, callback: { _ in
                        
                    }, contentSize: CGSize(width: 190, height: 130), screenSize: screenSize).offset(y: -60)
                }
            } else {
                CameraView(presentationStyle: presentationStyle, service: service)
            }
        }
        .onAppear {
            service.checkAuthorization()
        }
        .frame(width: screenSize.width, height: screenSize.height, alignment: offset != .zero ? .topLeading : .bottomLeading)
        .background(.clear)
    }
}

