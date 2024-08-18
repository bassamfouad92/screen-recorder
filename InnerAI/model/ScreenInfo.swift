//
//  ScreenInfo.swift
//  InnerAI
//
//  Created by Bassam Fouad on 14/08/2024.
//

import Cocoa
import CoreGraphics

struct DisplaySize: Hashable {
    let width: Double
    let height: Double
}

struct ScreenInfo: Hashable {
    let displayID: CGDirectDisplayID
    let displaySize: DisplaySize
    let title: String
    let image: NSImage
    var isSelected: Bool = false
    var isHovered: Bool = false
}

