//
//  RecordingBuffer.swift
//  InnerAI
//
//  Created by Bassam Fouad on 23/11/2025.
//

import CoreMedia

struct RecordingBuffer {
    let sampleBuffer: CMSampleBuffer
    let kind: BufferKind

    enum BufferKind {
        case video
        case appAudio
        case microphone
    }

    func adjusted(with time: CMTime) -> RecordingBuffer? {
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        guard let newSample = sampleBuffer.retimed(with: timing) else { return nil }
        return RecordingBuffer(sampleBuffer: newSample, kind: kind)
    }
}
