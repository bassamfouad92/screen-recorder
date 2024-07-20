//
//  AccessibilityHelper.swift
//  InnerAI
//
//  Created by Bassam Fouad on 20/07/2024.
//

import AppKit
import Foundation

struct AccessibilityHelper {
    static func askForAccessibilityIfNeeded() {
        let key: String = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true]
        let enabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if enabled {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Enable Accessibility First"
        alert.informativeText = "Find the popup right behind this one, click \"Open System Preferences\" and enable Screen Recorder by InnerAI. Then launch Screen Recorder by InnerAI again."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
           openAccessibilityPreferences()
           NSApp.terminate(nil)
        }
    }
    
   private static func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
