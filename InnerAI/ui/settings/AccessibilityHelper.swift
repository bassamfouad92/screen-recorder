//
//  AccessibilityHelper.swift
//  InnerAI
//
//  Created by Bassam Fouad on 20/07/2024.
//

import AppKit

struct AccessibilityHelper {
    static func askForAccessibilityIfNeeded(appDelegate: AppDelegate, completion: @escaping (Bool) -> Void) {
        // Hide the app immediately
        DispatchQueue.main.async {
            appDelegate.hideWindow()
            
            // Check if we already have accessibility access
            let trusted = AXIsProcessTrusted()
            if trusted {
                // If we're already trusted, call the completion handler immediately
                completion(true)
                appDelegate.showWindow()
                return
            }
            
            // If we're not trusted, we need to request access
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
                completion(accessibilityEnabled)
                appDelegate.showWindow()
            }
        }
    }
}