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
    var runningApplicationName: String = ""
    let screenSize = NSScreen.main?.frame.size ?? .zero
    let maskPositionX: CGFloat = 0
    let maskPositionY: CGFloat = 0
    var onWindowFront: (_ windowBottomPos: CGPoint) -> Void

    var body: some View {
        GeometryReader { geometry in
            Color.black.opacity(0.6)
                .mask(
                    RectangleMaskShape(
                        inset: 0,
                        width: window?.frame.width ?? 500,
                        height: window?.frame.height ?? 500,
                        positionX: window?.frame.origin.x ?? 0,
                        positionY: window?.frame.origin.y ?? 0
                    )
                    .fill(style: FillStyle(eoFill: true))
                )
        }
        .allowsHitTesting(false)
        .onAppear {
            getOpenedWindowsList()
        }
    }
    
    func switchToApp(named windowOwnerName: String) {
        let options = CGWindowListOption(arrayLiteral: CGWindowListOption.excludeDesktopElements, CGWindowListOption.optionOnScreenOnly)
        let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        guard let infoList = windowListInfo as NSArray? as? [[String: AnyObject]] else { return }

        if let window = infoList.first(where: { ($0["kCGWindowOwnerName"] as? String) == windowOwnerName}), let pid = window["kCGWindowOwnerPID"] as? Int32 {
            let app = NSRunningApplication(processIdentifier: pid)
            app?.activate(options: .activateIgnoringOtherApps)
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
                if let window = shareableContent.windows.first(where: { $0.owningApplication?.applicationName ?? "" == runningApplicationName}) {
                    switchToApp(named: runningApplicationName)
                    print("Window size: \(window.frame)")
                    print("Window top left: \(window.frame.origin.x), \(window.frame.origin.y)")
                    onWindowFront(window.frame.bottomLeft)
                    self.window = window
                }
           }
    })
  }
}

