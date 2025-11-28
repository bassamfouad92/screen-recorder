//
//  RecordingFileWriter.swift
//  InnerAI
//
//  Created by Bassam Fouad on 23/11/2025.
//

import Foundation
import AVFoundation

protocol RecordingFileWriter {
    func write(_ buffer: RecordingBuffer)
    func finish() async throws -> URL
    func pause() async
    func resume() async
}

actor WriterExecutor {
    func run(_ operation: () -> Void) {
        operation()
    }

    func runAsync(_ operation: () async -> Void) async {
        await operation()
    }
}


final class SCKRecordingFileWriter: RecordingFileWriter {

    // MARK: - Writer Components
    private let videoWriter: AVAssetWriter
    private let audioWriter: AVAssetWriter?

    private let videoInput: AVAssetWriterInput
    private let appAudioInput: AVAssetWriterInput?
    private let micAudioInput: AVAssetWriterInput?

    // MARK: - State
    private let queue = DispatchQueue(label: "RecordingFileWriter.queue")

    private var isSessionStarted = false
    private var sessionStartTime: CMTime?
    private var lastPTS: CMTime = .zero
    private var lastSampleBuffer: CMSampleBuffer?

    private var pauseStart: CMTime?
    private var accumulatedPause: CMTime = .zero
    private let outputURL: URL
    private let executor = WriterExecutor()


    // MARK: - INIT
    init(config: WriterConfig) throws {
        self.outputURL = config.url

        // Writer
        videoWriter = try AVAssetWriter(url: config.url, fileType: config.fileType)

        // Video
        videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: config.videoSettings
        )
        videoInput.expectsMediaDataInRealTime = true
        guard videoWriter.canAdd(videoInput) else { throw NSError() }
        videoWriter.add(videoInput)

        // App Audio
        if let appAudio = config.appAudioSettings {
            let aw = AVAssetWriterInput(mediaType: .audio, outputSettings: appAudio)
            aw.expectsMediaDataInRealTime = true

            audioWriter = try AVAssetWriter(url: config.url, fileType: config.fileType)
            guard audioWriter!.canAdd(aw) else { throw NSError() }
            audioWriter!.add(aw)

            self.appAudioInput = aw
        } else {
            self.audioWriter = nil
            self.appAudioInput = nil
        }

        // Mic Audio
        if let micAudio = config.micAudioSettings {
            let mic = AVAssetWriterInput(mediaType: .audio, outputSettings: micAudio)
            mic.expectsMediaDataInRealTime = true

            self.micAudioInput = mic
            videoWriter.add(mic)  // or separate writer depending on architecture
        } else {
            self.micAudioInput = nil
        }
    }

    // MARK: - Start
    private func startIfNeeded(using buffer: CMSampleBuffer) {
        guard !isSessionStarted else { return }

        let ts = CMSampleBufferGetPresentationTimeStamp(buffer)
        sessionStartTime = ts

        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: ts)

        audioWriter?.startWriting()
        audioWriter?.startSession(atSourceTime: ts)

        isSessionStarted = true
        DebugLogger.log(.writer, "✅ Writer session started at \(ts.seconds)s")
    }

    // MARK: - Pause / Resume
    func pause() async {
        await executor.run {
            pauseStart = lastPTS
            DebugLogger.log(.writer, "⏸️ Writer PAUSED at \(lastPTS.seconds)s")
        }
    }

    func resume() async {
        await executor.run {
            if let pauseStart = pauseStart {
                let now = lastPTS
                let pauseDurationSeconds = CMTimeGetSeconds(now) - CMTimeGetSeconds(pauseStart)
                guard pauseDurationSeconds > 0 else {
                    self.pauseStart = nil
                    return
                }
                
                let pauseDuration = CMTime(seconds: pauseDurationSeconds,
                                          preferredTimescale: now.timescale)
                self.accumulatedPause = self.accumulatedPause + pauseDuration
                self.pauseStart = nil
                
                DebugLogger.log(.writer, "▶️ Writer RESUMED (paused for \(pauseDurationSeconds)s, total pause: \(self.accumulatedPause.seconds)s)")
            }
        }
    }


    // MARK: - Write
    func write(_ buffer: RecordingBuffer) {
        Task {
            await executor.run {
                self._write(buffer)
            }
        }
    }
    
    private func _write(_ buffer: RecordingBuffer) {
        guard isSessionStarted else {
            self.startIfNeeded(using: buffer.sampleBuffer)
            return
        }

        let pts = CMSampleBufferGetPresentationTimeStamp(buffer.sampleBuffer)
        lastPTS = pts

        if pauseStart != nil { return }

        let adjusted = CMTimeSubtract(pts, accumulatedPause)
        guard let sampleBuffer = buffer.adjusted(with: adjusted) else { return }

        // Log every 120th buffer to avoid spam
        var writeCount = 0
        writeCount += 1
        
        switch buffer.kind {
        case .video:
            if videoInput.isReadyForMoreMediaData {
                  lastSampleBuffer = sampleBuffer
                _ = videoInput.append(sampleBuffer)
                
                if writeCount % 120 == 0 {
                    DebugLogger.log(.writer, "💾 Writing buffers... (\(writeCount) total, current: \(adjusted.seconds)s)")
                }
            }

        case .appAudio:
            if let ai = appAudioInput, ai.isReadyForMoreMediaData {
                lastSampleBuffer = sampleBuffer
                _ = ai.append(sampleBuffer)
            }

        case .microphone:
            if let mi = micAudioInput, mi.isReadyForMoreMediaData {
                _ = mi.append(sampleBuffer)
            }
        }
    }
    
    private func finishWriter(_ writer: AVAssetWriter) async throws {
        try await withCheckedThrowingContinuation{ (continuation: CheckedContinuation<Void, Error>) in
            if let error = writer.error {
                continuation.resume(throwing: error)
            } else {
                writer.finishWriting {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Finish
    func finish() async throws -> URL {
        DebugLogger.log(.writer, "Finishing writer...")
        
        await executor.runAsync {
            videoInput.markAsFinished()
            appAudioInput?.markAsFinished()
            micAudioInput?.markAsFinished()
        }
        
        videoWriter.endSession(atSourceTime: lastSampleBuffer?.presentationTimeStamp ?? .zero)
        try await finishWriter(videoWriter)
        
        if let aw = audioWriter {
            try await finishWriter(aw)
        }
        
        DebugLogger.log(.writer, "✅ Writer finished successfully. File: \(outputURL.lastPathComponent)")
        return outputURL
    }
}
