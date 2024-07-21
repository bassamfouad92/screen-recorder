//
//  CGRect+Position.swift
//  InnerAI
//
//  Created by Bassam Fouad on 18/07/2024.
//

import Foundation

extension CGRect {
    var bottomLeft: CGPoint {
        return CGPoint(x: self.origin.x, y: self.origin.y + self.size.height)
    }
}
