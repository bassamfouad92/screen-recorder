//
//  BufferAdjuster.swift
//  InnerAI
//
//  Created by Bassam Fouad on 30/11/2025.
//

import Foundation
import CoreMedia

final class BufferAdjuster {
    private var isPaused = false
    private var pauseStartPTS: CMTime?
    private var totalPauseDuration: CMTime = .zero

    func pause() {
        isPaused = true
        pauseStartPTS = nil
    }
    
    func resume() {
        totalPauseDuration = .zero
        isPaused = false
    }
    
    func adjust(_ buffer: RecordingBuffer) -> RecordingBuffer? {
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer.sampleBuffer)

        if isPaused {
            if pauseStartPTS == nil {
                pauseStartPTS = pts
                DebugLogger.log(.info, "⏸ Pause at PTS: \(pts.seconds)")
            }
            return nil
        }
        
        if let start = pauseStartPTS {
            let pauseDuration = CMTimeSubtract(pts, start)
            totalPauseDuration = CMTimeAdd(totalPauseDuration, pauseDuration)
            pauseStartPTS = nil
            
            DebugLogger.log(.info,
                "▶️ Resume. Pause duration: \(pauseDuration.seconds), total: \(totalPauseDuration.seconds)"
            )
        }
        
        if totalPauseDuration != .zero {
            let adjustedPTS = CMTimeSubtract(pts, totalPauseDuration)
            return buffer.adjusted(with: adjustedPTS)
        }

        return buffer
    }
}
