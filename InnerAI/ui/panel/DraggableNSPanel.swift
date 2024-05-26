//
//  DraggableNSPanel.swift
//  InnerAI
//
//  Created by Bassam Fouad on 02/05/2024.
//

import SwiftUI

struct DraggableNSPanel: NSViewRepresentable {
    
    let contentView: AnyView

    func makeNSView(context: Context) -> NSView {
        // Create an NSPanel
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                            styleMask: [.titled, .closable, .fullSizeContentView],
                            backing: .buffered, defer: false)

        // Make it draggable
        panel.isMovableByWindowBackground = true

        // Set background color and rounded corners
        panel.backgroundColor = .black
        panel.isOpaque = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 10

        // Create an NSHostingView to embed SwiftUI content
        let hostingView = NSHostingView(rootView: contentView)

        // Add the hosting view to the panel
        panel.contentView = hostingView

        return panel.contentView!
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        
    }
}
