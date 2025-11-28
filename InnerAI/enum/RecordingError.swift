//
//  RecordingError.swift
//  InnerAI
//
//  Created by Bassam Fouad on 22/11/2025.
//

import CoreGraphics

enum RecordingError: Error, CustomDebugStringConvertible {
    case displayNotFound(id: CGDirectDisplayID)
    case streamSetupFailed
    case captureStartFailed
    case captureStopFailed(String)
    case invalidSampleBuffer
    case windowUnavailable
    case custom(String)

    var debugDescription: String {
        switch self {
        case .displayNotFound(let id):
            return "Display with ID \(id) was not found."

        case .streamSetupFailed:
            return "Stream setup failed:"

        case .captureStartFailed:
            return "Failed to start capture"

        case .captureStopFailed(let reason):
            return "Failed to stop capture: \(reason)"

        case .invalidSampleBuffer:
            return "Received invalid CMSampleBuffer."

        case .windowUnavailable:
            return "Selected window is no longer available."

        case .custom(let message):
            return message
        }
    }
}

