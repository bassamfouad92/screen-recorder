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

    func adjusted(with time: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        return sampleBuffer.retimed(with: timing)
    }
}
