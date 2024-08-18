//
//  WindowUtil.swift
//  InnerAI
//
//  Created by Bassam Fouad on 15/08/2024.
//

import Foundation
import AppKit

struct WindowInfo {
    let windowTitle: String
    let appName: String
}

struct WindowUtil {
    
    static func bringWindowToFront(windowTitle: String, withAppName appName: String) -> AXUIElement? {
          let runningApps = NSWorkspace.shared.runningApplications
        
          guard let app = runningApps.first(where: { $0.localizedName == appName }) else {
            return nil
           }
        
           let appPID = app.processIdentifier
           let appElement = AXUIElementCreateApplication(appPID)

          NSRunningApplication(processIdentifier: appPID)?.activate(options: .activateIgnoringOtherApps)

           var value: CFTypeRef?
           let result = AXUIElementCopyAttributeValue(appElement,
                                                      kAXChildrenAttribute as CFString, &value)
           
           if result != .success {
               return nil
           }
           
           guard let windowList = value as? [AXUIElement], !windowList.isEmpty else {
               return nil
           }
        
           for window in windowList {
               var titleValue: CFTypeRef?
               let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)

               if titleResult == .success, let title = titleValue as? String, title.contains(windowTitle) {
                   let raiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                   if raiseResult == .success {
                       print("Window with title '\(windowTitle)' and \(appName) brought to the front.")
                       return window
                   } else {
                       print("Failed to bring window to the front with error code \(raiseResult).")
                   }
                   return nil
               }
           }
        return nil
    }
    
    static func getWindow(windowTitle: String, withAppName appName: String) -> AXUIElement? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) else { return nil }
        
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &value) == .success,
              let windowList = value as? [AXUIElement] else {
            return nil
        }
        
        return windowList.first { window in
            var titleValue: CFTypeRef?
            return AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success &&
            (titleValue as? String)?.contains(windowTitle) == true
        }
    }
    
    static func getDisplayId(from window: AXUIElement) -> CGDirectDisplayID? {
        // Get the window's position
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        
        // Get the window's size
        var sizeValue: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
        
        guard positionResult == .success,
              sizeResult == .success,
              let positionAXValue = positionValue,
              let sizeAXValue = sizeValue else {
            return nil
        }
        
        var windowPosition = CGPoint.zero
        AXValueGetValue(positionAXValue as! AXValue, .cgPoint, &windowPosition)
        
        var windowSize = CGSize.zero
        AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &windowSize)
        
        // Calculate the center of the window
        let windowCenter = CGPoint(x: windowPosition.x + windowSize.width / 2, y: windowPosition.y + windowSize.height / 2)
        
        // Get the list of displays
        var displays = [CGDirectDisplayID](repeating: 0, count: 32)
        var displayCount: UInt32 = 0
        let error = CGGetActiveDisplayList(UInt32(displays.count), &displays, &displayCount)
        
        if error != .success {
            return nil
        }
        
        displays = Array(displays.prefix(Int(displayCount)))
        
        // Check which display contains the window center
        for displayID in displays {
            let displayBounds = CGDisplayBounds(displayID)
            if displayBounds.contains(windowCenter) {
                return displayID
            }
        }
        return nil
    }
    
    static func moveWindowsToExternalDisplay(windowsInfo: [WindowInfo], toDisplay displayID: CGDirectDisplayID) {
        let runningApps = NSWorkspace.shared.runningApplications
        
        for windowInfo in windowsInfo {
            guard let app = runningApps.first(where: { $0.localizedName == windowInfo.appName }) else {
                print("VideoView Application '\(windowInfo.appName)' not found.")
                continue
            }
            
            let appPID = app.processIdentifier
            let appElement = AXUIElementCreateApplication(appPID)
            
            if appElement == nil {
                print("VideoView Failed to create AXUIElement for application '\(windowInfo.appName)'.")
                continue
            }

            NSRunningApplication(processIdentifier: appPID)?.activate(options: .activateIgnoringOtherApps)
            
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
            
            if result != .success {
                print("VideoView Failed to get windows attribute with error code \(result).")
                continue
            }
            
            guard let windowList = value as? [AXUIElement], !windowList.isEmpty else {
                print("VideoView No windows found for application '\(windowInfo.appName)'.")
                continue
            }

            for window in windowList {
                var titleValue: CFTypeRef?
                let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
                
                if titleResult == .success, let title = titleValue as? String, title.contains(windowInfo.windowTitle) {
                    moveWindow(window, toDisplay: displayID)
                    print("VideoView Window with title '\(windowInfo.windowTitle)' from application '\(windowInfo.appName)' moved to external display.")
                } else if titleResult != .success {
                    print("VideoView Failed to get window title with error code \(titleResult).")
                }
            }
        }
    }

    // Helper function to move the window to the external display
    private static func moveWindow(_ window: AXUIElement, toDisplay displayID: CGDirectDisplayID) {
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        
        if positionResult != .success || positionValue == nil {
            print("VideoView Failed to get window position with error code \(positionResult).")
            return
        }
        
        // Calculate the new position based on the external display's bounds
        let displayBounds = CGDisplayBounds(displayID)
        var newPosition = CGPoint(x: displayBounds.origin.x, y: displayBounds.origin.y)

        let positionAXValue = AXValueCreate(.cgPoint, &newPosition)!
        
        let setPositionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionAXValue)
        
        if setPositionResult != .success {
            print("VideoView Failed to move window to external display with error code \(setPositionResult).")
        }
    }
}
