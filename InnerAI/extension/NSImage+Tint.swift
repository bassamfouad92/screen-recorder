//
//  NSImage+Tint.swift
//  InnerAI
//
//  Created by Bassam Fouad on 04/05/2024.
//

import Cocoa

extension NSImage {
    func tintedImage(tint: NSColor) -> NSImage {
        guard let tinted = self.copy() as? NSImage else { return self }
        tinted.lockFocus()
        tint.set()
        
        let imageRect = NSRect(origin: .zero, size: self.size)
        imageRect.fill(using: .sourceAtop)
        
        tinted.unlockFocus()
        return tinted
    }
}
