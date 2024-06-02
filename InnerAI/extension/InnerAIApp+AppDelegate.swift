//
//  InnerAIApp+AppDelegate.swift
//  InnerAI
//
//  Created by Bassam Fouad on 02/05/2024.
//

import SwiftUI

extension AppDelegate {
    func createWindow<Content: View>(rootView: Content, title: String = "InnerAIRecordWindow") -> NSWindow {
            let screenFrame = NSScreen.main?.frame
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: screenFrame?.width ?? 900, height: screenFrame?.height ?? 400),
                styleMask: [],
                backing: .buffered, defer: false)
            window.level = .modalPanel
            window.contentView = NSHostingView(rootView: rootView)
            window.backgroundColor = NSColor.clear
            window.titlebarAppearsTransparent = true
            window.styleMask = .fullSizeContentView
            window.isReleasedWhenClosed = false
            window.title = title
            return window
        }
}
