//
//  DebugLogger.swift
//  InnerAI
//
//  Created by Bassam Fouad on 28/11/2025.
//

import Foundation
import CoreMedia

enum LogCategory: String {
    case action = "🎬 ACTION"
    case pipeline = "⚡️ PIPELINE"
    case writer = "💾 WRITER"
    case mic = "🎤 MIC"
    case error = "❌ ERROR"
    case info = "ℹ️ INFO"
}

struct DebugLogger {
    static var isEnabled = true
    
    static func log(_ category: LogCategory, _ message: String) {
        guard isEnabled else { return }
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("[\(timestamp)] \(category.rawValue): \(message)")
    }
    
    static func logBuffer(_ kind: RecordingBuffer.BufferKind, timestamp: CMTime) {
        guard isEnabled else { return }
        // Throttle buffer logs to avoid flooding (e.g., print every 60th frame or just a dot)
        // For now, let's just print a concise message
        let icon: String
        switch kind {
        case .video: icon = "📹"
        case .appAudio: icon = "🔊"
        case .microphone: icon = "🎤"
        }
        // print("\(icon)", terminator: "") // Inline printing might be messy with other logs
        // Let's print full lines but maybe we can comment this out if it's too much
        // print("[\(Date().formatted(date: .omitted, time: .standard))] 📦 BUFFER: \(icon) at \(timestamp.seconds)s")
    }
}
