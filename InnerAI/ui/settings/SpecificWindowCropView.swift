//
//  SpecificWindowCropView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 26/05/2024.
//

import SwiftUI
import ScreenCaptureKit

struct RectangleMaskShape: Shape {
    var inset: CGFloat
    var width: CGFloat
    var height: CGFloat
    var positionX: CGFloat
    var positionY: CGFloat

    func path(in rect: CGRect) -> Path {
        var shape = Rectangle().path(in: rect)
        let insetRect = CGRect(x: positionX, y: positionY, width: width, height: height)
        let insetPath = Rectangle().path(in: insetRect.insetBy(dx: inset, dy: inset))
        shape.addPath(insetPath)
        return shape
    }
}


struct SpecificWindowCropView: View {
    
    @State var window: SCWindow?
    @State var adjustedFrame: CGRect = .zero
    
    var title: String = ""
    let maskPositionX: CGFloat = 0
    let maskPositionY: CGFloat = 0
    var onWindowFront: (_ windowBottomPos: CGPoint, _ displayId: CGDirectDisplayID) -> Void

    var body: some View {
        GeometryReader { geometry in
                if let window = window {
                    Color.black.opacity(0.6)
                        .mask(
                            RectangleMaskShape(
                                inset: 0,
                                width: window.frame.width,
                                height: window.frame.height,
                                positionX: window.frame.origin.x - adjustedFrame.origin.x,
                                positionY: window.frame.origin.y
                            )
                            .fill(style: FillStyle(eoFill: true))
                        )
                } else {
                    Color.clear
                }
        }
        .allowsHitTesting(false)
        .onAppear {
            getOpenedWindowsList()
        }
    }
    
    private func getOpenedWindowsList() {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true, completionHandler: { shareableContent, error in
            if let error = error {
                print("Error retrieving windows: \(error.localizedDescription)")
                return
            }
            
            guard let shareableContent = shareableContent else {
                print("Error: Shareable content is nil")
                return
            }
            DispatchQueue.main.async {
                if let window = shareableContent.windows.first(where: { $0.title == title }) {
                    if let windowOnFront = WindowUtil.bringWindowToFront(windowTitle: title, withAppName: window.owningApplication?.applicationName ?? title),
                       let displayId = WindowUtil.getDisplayId(from: windowOnFront) {
                        
                        adjustedFrame = CGDisplayBounds(displayId)
                        
                        let adjustedWindowFrame = CGRect(
                            x: window.frame.origin.x - adjustedFrame.origin.x,
                            y: window.frame.origin.y,
                            width: window.frame.width,
                            height: window.frame.height
                        )
                        
                        onWindowFront(adjustedWindowFrame.bottomLeft, displayId)
                    } else {
                        onWindowFront(window.frame.bottomLeft, CGMainDisplayID())
                    }
                    self.window = window
                }
            }
    })
  }
}

