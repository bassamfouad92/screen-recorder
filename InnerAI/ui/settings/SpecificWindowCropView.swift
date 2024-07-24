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
    var title: String = ""
    let screenSize = NSScreen.main?.frame.size ?? .zero
    let maskPositionX: CGFloat = 0
    let maskPositionY: CGFloat = 0
    var onWindowFront: (_ windowBottomPos: CGPoint) -> Void

    var body: some View {
        GeometryReader { geometry in
                if let window = window {
                    Color.black.opacity(0.6)
                        .mask(
                            RectangleMaskShape(
                                inset: 0,
                                width: window.frame.width,
                                height: window.frame.height,
                                positionX: window.frame.origin.x,
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
    
    func switchToApp(named windowOwnerName: String) {
        let options = CGWindowListOption(arrayLiteral: CGWindowListOption.excludeDesktopElements, CGWindowListOption.optionOnScreenBelowWindow, CGWindowListOption.optionOnScreenAboveWindow)
        let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        guard let infoList = windowListInfo as NSArray? as? [[String: AnyObject]] else { return }
        if let window = infoList.first(where: { ($0["kCGWindowName"] as? String) == windowOwnerName}), let pid = window["kCGWindowOwnerPID"] as? Int32, (window["kCGWindowName"] as? String ?? "").isEmpty == false {
            let app = NSRunningApplication(processIdentifier: pid)
            app?.activate(options: .activateIgnoringOtherApps)
        }
    }
    
    func bringWindowToFront(windowTitle: String, withAppName appName: String) {
          let runningApps = NSWorkspace.shared.runningApplications
        
          guard let app = runningApps.first(where: { $0.localizedName == appName }) else {
            print("Application '\(appName)' not found.")
            return
           }
        
           let finderPID = app.processIdentifier
           let finderAppElement = AXUIElementCreateApplication(finderPID)
           
           if finderAppElement == nil {
               print("Failed to create AXUIElement for Finder.")
               return
           }

          NSRunningApplication(processIdentifier: finderPID)?.activate(options: .activateIgnoringOtherApps)

           var value: CFTypeRef?
           let result = AXUIElementCopyAttributeValue(finderAppElement,
                                                      kAXChildrenAttribute as CFString, &value)
           
           if result != .success {
               print("Failed to get windows attribute with error code \(result).")
               return
           }
           
           guard let windowList = value as? [AXUIElement], !windowList.isEmpty else {
               print("No windows found.")
               return
           }
        
           for window in windowList {
               var titleValue: CFTypeRef?
               let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)

               if titleResult == .success, let title = titleValue as? String, title.contains(windowTitle) {
                   let raiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                   if raiseResult == .success {
                       print("Window with title '\(windowTitle)' brought to the front.")
                   } else {
                       print("Failed to bring window to the front with error code \(raiseResult).")
                   }
                   return
               }
           }
           
           print("No window found with title containing '\(windowTitle)'.")
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
                if let window = shareableContent.windows.first(where: { $0.title ?? "" == title }) {
                    bringWindowToFront(windowTitle: title, withAppName: window.owningApplication?.applicationName ?? title)
                    onWindowFront(window.frame.bottomLeft)
                    self.window = window
                }
           }
    })
  }
}

