//
//  WindowInfo.swift
//  InnerAI
//
//  Created by Bassam Fouad on 02/05/2024.
//

import Foundation
import ScreenCaptureKit

struct OpenedWindowInfo: Hashable {
    let windowID: CGWindowID
    let title: String
    let image: NSImage
    var isSelected: Bool = false
    var isHovered: Bool = false
}
