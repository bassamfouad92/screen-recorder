//
//  WindowReference.swift
//  InnerAI
//
//  Created by Bassam Fouad on 30/11/2025.
//

import Foundation
import ScreenCaptureKit

/// A type-erased wrapper for window references
/// This allows ViewModel to hold window references without importing ScreenCaptureKit
struct WindowReference {
    let underlying: Any
    
    init(_ window: SCWindow) {
        self.underlying = window
    }
    
    var asSCWindow: SCWindow? {
        underlying as? SCWindow
    }
}
