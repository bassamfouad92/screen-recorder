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
        let options = CGWindowListOption(arrayLiteral: CGWindowListOption.excludeDesktopElements, CGWindowListOption.optionOnScreenBelowWindow, CGWindowListOption.optionOnScreenAboveWindow)
        let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        guard let infoList = windowListInfo as NSArray? as? [[String: AnyObject]] else { return }
        print("SpecificWindowCropView : \(infoList)")
        minimizeWindow(withName: "YouTube")
        if let window = infoList.first(where: { ($0["kCGWindowName"] as? String) == windowOwnerName}), let pid = window["kCGWindowOwnerPID"] as? Int32, (window["kCGWindowName"] as? String ?? "").isEmpty == false {
            let app = NSRunningApplication(processIdentifier: pid)
            app?.activate(options: .activateIgnoringOtherApps)
        }
    }
    
    func minimizeWindow(withName windowName: String) {
        if let window = NSApplication.shared.windows.first(where: { $0.title == windowName }) {
            window.miniaturize(nil)
        } else {
            print("Not found!!!!")
        }
    }
    
    func bringSafariWindowToFront(windowTitle: String, withAppName appName: String) {
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
    
    func bringApplicationToFront(byName windowName: String, inAppName appName: String) {
        guard let appElement = getAXUIElement(forAppName: appName) else {
                print("Failed to create AXUIElement for \(appName).")
                return
            }

            // Get all windows of the application
            var windowElements: AnyObject?
            let result = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &windowElements)
            
            if result == .success, let windows = windowElements as? [AXUIElement] {
                // Find the window with the specified name
                if let targetWindow = windows.first(where: { window in
                    var windowTitle: AnyObject?
                    let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowTitle)
                    return titleResult == .success && (windowTitle as? String) == windowName
                }) {
                    // Bring the window to the front
                    let frontmostResult = AXUIElementSetAttributeValue(targetWindow, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
                    if frontmostResult == .success {
                        print("Successfully brought window '\(windowName)' of \(appName) to the front.")
                    } else {
                        print("Failed to bring window '\(windowName)' of \(appName) to the front. Error: \(frontmostResult.rawValue)")
                    }
                } else {
                    print("Window with name '\(windowName)' not found in \(appName).")
                }
            } else {
                print("Failed to retrieve windows for \(appName). Error: \(result.rawValue)")
            }
    }
    
    func getAXUIElement(forAppName appName: String) -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.localizedName == appName }) else {
            print("Application '\(appName)' not found.")
            return nil
        }
        let pid = app.processIdentifier
        return AXUIElementCreateApplication(pid)
    }
    
    func printRunningApplications() {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            print("Application: \(app.localizedName ?? "Unknown") PID: \(app.processIdentifier)")
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
                if let window = shareableContent.windows.first(where: { $0.title ?? "" == title }) {
                    //switchToApp(named: runningApplicationName)
                    bringSafariWindowToFront(windowTitle: title, withAppName: window.owningApplication?.applicationName ?? title)
                    print("Window size: \(window.frame)")
                    print("Window top left: \(window.frame.origin.x), \(window.frame.origin.y)")
                    onWindowFront(window.frame.bottomLeft)
                    self.window = window
                }
           }
    })
  }
}

