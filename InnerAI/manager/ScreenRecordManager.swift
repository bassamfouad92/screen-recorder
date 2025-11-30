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

struct RecordingConfiguration {
    let audioDeviceId: UInt32
    let recordMic: Bool
    let audioDeviceTransportType: AudioDeviceTransportType
    let mode: RecordMode
    let videoFormat: VideoFormat
}

enum RecordingEvent {
    case started
    case stopped(URL)
    case error(RecordingError)
}

class ScreenRecordManager: NSObject {
    
    deinit {
        print("ScreenRecordManager deinit")
    }
    
    // MARK: - Publishers
    let actionInput = PassthroughSubject<RecordAction, Never>()
    private let eventSubject = PassthroughSubject<RecordingEvent, Never>()
    var events: AnyPublisher<RecordingEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Properties
    private var pipeline: (any ScreenRecordingPipeline)?
    private var writer: (any RecordingFileWriter)?
    private var cancellables = Set<AnyCancellable>()
    private let bufferAdjuster = BufferAdjuster()
    
    private(set) var startTime: Date?
    private(set) var filePath: String?
    private(set) var fileURL: URL?
    
    private let configuration: RecordingConfiguration
    
    // MARK: - Init
    init(configuration: RecordingConfiguration) {
        self.configuration = configuration
        super.init()
        bindActions()
    }
    
    // MARK: - Private Methods
    
    private func bindActions() {
        actionInput
            .sink { [weak self] action in
                self?.handleAction(action)
            }
            .store(in: &cancellables)
    }
    
    private func handleAction(_ action: RecordAction) {
        Task {
            switch action {
            case .start:
                break
            case .pause:
                handlePause()
            case .resume:
                handleResume()
            case .stop:
                await handleStop()
            case .restart:
                await handleRestart()
            case .delete:
                await handleDelete()
            }
        }
    }
    
    private func handlePause() {
        DebugLogger.log(.action, "⏸️ PAUSE requested")
        pipeline?.actionInput.send(.pause)
        bufferAdjuster.pause()
    }
    
    private func handleResume() {
        DebugLogger.log(.action, "▶️ RESUME requested")
        pipeline?.actionInput.send(.resume)
        bufferAdjuster.resume()
    }
    
    private func handleStop() async {
        do {
            DebugLogger.log(.action, "⏹️ STOP requested")
            pipeline?.actionInput.send(.stop)
            let url = try await writer?.finish()
            if let url = url {
                eventSubject.send(.stopped(url))
            }
        } catch {
            pipeline?.actionInput.send(.stop)
            eventSubject.send(.error(.custom(error.localizedDescription)))
        }
    }
    
    private func handleRestart() async {
        await handleStop()
    }
    
    private func handleDelete() async {
        if let filePath = filePath {
            RecordFileManager.shared.deleteFile(atPath: filePath)
        }
        await handleStop()
    }
    
    // MARK: - Public Methods
    
    func record(
        displayID: CGDirectDisplayID,
        selectedWindow: WindowReference?,
        cameraWindow: WindowReference?,
        excludedWindows: [WindowReference]? = []
    ) async throws {
        DebugLogger.log(.info, "🎬 Initializing recording...")
        
        // Convert WindowReference to SCWindow
        let scSelectedWindow = selectedWindow?.asSCWindow
        let scCameraWindow = cameraWindow?.asSCWindow
        let scExcludedWindows = excludedWindows?.compactMap { $0.asSCWindow } ?? []
        
        // 1. Prepare File URL
        let fileExtension = configuration.videoFormat == .mp4 ? "mp4" : "mov"
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
            mode: configuration.mode,
            videoFormat: configuration.videoFormat,
            recordMic: configuration.recordMic
        )
        
        // 3. Initialize Writer
        let writer = try SCKRecordingFileWriter(config: writerConfig)
        self.writer = writer
        DebugLogger.log(.info, "💾 Writer initialized")
        
        // 4. Initialize Pipeline
        let pipeline = SCKScreenRecordingPipeline(
            selectedWindow: scSelectedWindow,
            cameraWindow: scCameraWindow,
            excludedWindows: scExcludedWindows,
            displayID: displayID,
            mode: configuration.mode,
            audioDeviceId: configuration.audioDeviceId,
            isBluetooth: configuration.audioDeviceTransportType == .bluetooth
        )
        self.pipeline = pipeline
        DebugLogger.log(.info, "⚡️ Pipeline initialized")
        
        pipeline.processedBuffers
            .compactMap { [weak self] buffer in
                self?.bufferAdjuster.adjust(buffer)
            }
            .sink { [weak writer] adjusted in
                writer?.write(adjusted)
            }
            .store(in: &cancellables)
        
        DebugLogger.log(.info, "🔗 Pipeline connected to Writer")
            
        pipeline.errorPublisher
            .sink { [weak self] error in
                DebugLogger.log(.error, "Pipeline error: \(error)")
                self?.eventSubject.send(.error(error))
            }
            .store(in: &cancellables)
        
        DebugLogger.log(.info, "✅ Recording setup complete")
    }
    
    func start() async throws {
        DebugLogger.log(.action, "▶️ START requested")
        startTime = Date()
        pipeline?.actionInput.send(.start)
        eventSubject.send(.started)
    }
    
    private func stopRecording() async throws {
        DebugLogger.log(.action, "⏹️ STOP requested")
        pipeline?.actionInput.send(.stop)
        
        if let url = try await writer?.finish() {
            eventSubject.send(.stopped(url))
        }
        
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
