//
//  ScreenRecordManager.swift
//  InnerAI
//
//  Created by Bassam Fouad on 03/05/2024.
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine

class ScreenRecordManager: NSObject, ObservableObject {
    
    deinit {
        print("ScreenRecordManager deinit")
    }
    
    // MARK: - Properties
    var pipeline: SCKScreenRecordingPipeline?
    var writer: SCKRecordingFileWriter?
    private var cancellables = Set<AnyCancellable>()
    
    var startTime: Date?
    var filePath: String!
    var fileURL: URL?
    
    var recordMic = true
    var audioDeviceId: UInt32 = 0
    var audioDeviceTransportType: AudioDeviceTransportType = .builtIn
    
    var isPause: Bool = false {
        didSet {
            DebugLogger.log(.action, isPause ? "⏸️ PAUSE requested" : "▶️ RESUME requested")
            if isPause {
                pipeline?.actionInput.send(.pause)
                Task { await writer?.pause() }
            } else {
                pipeline?.actionInput.send(.resume)
                Task { await writer?.resume() }
            }
        }
    }
    
    var onStopStream: (_ stream: SCStream?) -> Void = { _ in }
    
    // Configuration
    private var mode: RecordMode = .h264_sRGB
    private var videoFormat: VideoFormat = .mp4
    
    // MARK: - Methods
    
    func record(displayID: CGDirectDisplayID, selectedWindow: SCWindow?, cameraWindow: SCWindow?, excludedWindows: [SCWindow]? = []) async throws {
        DebugLogger.log(.info, "🎬 Initializing recording...")
        
        // 1. Prepare File URL
        let fileExtension = videoFormat == .mp4 ? "mp4" : "mov"
        let url = try RecordFileManager.shared.makeVideoFileURL(extension: fileExtension)
        self.fileURL = url
        self.filePath = url.path
        DebugLogger.log(.info, "📁 Output file: \(url.lastPathComponent)")
        
        // 2. Prepare Settings
        let displaySize = CGDisplayBounds(displayID).size
        let displayScaleFactor = getDisplayScaleFactor(for: displayID)
        
        let writerConfig = try WriterConfig.create(
            url: url,
            displaySize: displaySize,
            scaleFactor: displayScaleFactor,
            mode: mode,
            videoFormat: videoFormat,
            recordMic: recordMic
        )
        
        // 3. Initialize Writer
        let writer = try SCKRecordingFileWriter(config: writerConfig)
        self.writer = writer
        DebugLogger.log(.info, "💾 Writer initialized")
        
        // 4. Initialize Pipeline
        let pipeline = SCKScreenRecordingPipeline(
            selectedWindow: selectedWindow,
            cameraWindow: cameraWindow,
            excludedWindows: excludedWindows ?? [],
            displayID: displayID,
            mode: mode,
            audioDeviceId: audioDeviceId,
            isBluetooth: audioDeviceTransportType == .bluetooth
        )
        self.pipeline = pipeline
        DebugLogger.log(.info, "⚡️ Pipeline initialized")
        
        // 5. Connect Pipeline to Writer
        pipeline.processedBuffers
            .sink { [weak writer] buffer in
                writer?.write(buffer)
            }
            .store(in: &cancellables)
        DebugLogger.log(.info, "🔗 Pipeline connected to Writer")
            
        pipeline.errorPublisher
            .sink { [weak self] error in
                DebugLogger.log(.error, "Pipeline error: \(error)")
                self?.onStopStream(nil)
            }
            .store(in: &cancellables)
        
        DebugLogger.log(.info, "✅ Recording setup complete")
    }
    
    func start() async throws {
        DebugLogger.log(.action, "▶️ START requested")
        startTime = Date()
        pipeline?.actionInput.send(.start)
    }
    
    func stopRecording() async throws {
        DebugLogger.log(.action, "⏹️ STOP requested")
        pipeline?.actionInput.send(.stop)
        _ = try await writer?.finish()
        pipeline = nil
        writer = nil
        cancellables.removeAll()
        DebugLogger.log(.info, "✅ Recording stopped and cleaned up")
    }
    
    // MARK: - Helpers
    
    private func getDisplayScaleFactor(for displayID: CGDirectDisplayID) -> Int {
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            return mode.pixelWidth / mode.width
        }
        return 1
    }
    

    
    // Legacy helpers if needed by UI
    func getRecordingLength() -> String {
        guard let startTime = startTime else { return "00:00" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: Date.now.timeIntervalSince(startTime)) ?? "00:00"
    }
    
    func getRecordingSize() -> String {
        guard let filePath = filePath else { return "Unknown" }
        do {
            let fileAttr = try FileManager.default.attributesOfItem(atPath: filePath)
            let byteFormat = ByteCountFormatter()
            byteFormat.allowedUnits = [.useMB]
            byteFormat.countStyle = .file
            return byteFormat.string(fromByteCount: fileAttr[FileAttributeKey.size] as! Int64)
        } catch {
            return "Unknown"
        }
    }
}
