//
//  SCK.swift
//  InnerAI
//
//  Created by Bassam Fouad on 19/11/2025.
//

import Combine
import ScreenCaptureKit
import CoreMedia

final class SCKScreenRecordingPipeline: NSObject, ScreenRecordingPipeline {
   
    typealias WindowType = SCWindow

    let actionInput = PassthroughSubject<RecordAction, Never>()
    private let errorSubject = PassthroughSubject<RecordingError, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    private let processedBuffersSubject = PassthroughSubject<RecordingBuffer, Never>()
    var processedBuffers: AnyPublisher<RecordingBuffer, Never> {
        processedBuffersSubject.eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<RecordingError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    private var conf = SCStreamConfiguration()
    private var selectedWindow: SCWindow?
    private var cameraWindow: SCWindow?
    private var excludedWindows: [SCWindow] = []
    private var displayID: CGDirectDisplayID = 0
    private var mode: RecordMode = .h264_sRGB
    private var stream: SCStream?

    private let audioManager = MicrophoneCaptureManager()
    private var audioDeviceId: UInt32 = 0
    private var isBluetooth: Bool = false
    var videoFrameCount = 0
    var micBufferCount = 0
    var appAudioCount = 0
        
    init(
        selectedWindow: SCWindow? = nil,
        cameraWindow: SCWindow? = nil,
        excludedWindows: [SCWindow] = [],
        displayID: CGDirectDisplayID,
        mode: RecordMode,
        audioDeviceId: UInt32 = 0,
        isBluetooth: Bool = false
    ) {
        self.selectedWindow = selectedWindow
        self.cameraWindow = cameraWindow
        self.excludedWindows = excludedWindows
        self.displayID = displayID
        self.mode = mode
        self.audioDeviceId = audioDeviceId
        self.isBluetooth = isBluetooth
        
        super.init()
        
        buildConfiguration()
        bindActions()
        bindBufferLogger()
        
        audioManager.configureMic(audioDeviceId: audioDeviceId, isBluetooth: isBluetooth)
        bindMic()
    }

    private func buildConfiguration() {
        let displayBounds = CGDisplayBounds(displayID).size
        let scale = calculateScaleFactor(for: displayID, displayBounds: displayBounds)

        let configuration = SCStreamConfiguration()
        configureVideo(on: configuration, displayBounds: displayBounds, scale: scale)
        configureWindowCropping(on: configuration, scale: scale)
        configureAudio(on: configuration)
        configureAdvancedOptions(on: configuration)

        self.conf = configuration
    }

    
    private func calculateScaleFactor(
        for displayID: CGDirectDisplayID,
        displayBounds: CGSize
    ) -> Int {
        let pixelWidth = CGDisplayCopyDisplayMode(displayID)?.pixelWidth
        return (pixelWidth ?? Int(displayBounds.width)) / Int(displayBounds.width)
    }

    private func configureVideo(
        on config: SCStreamConfiguration,
        displayBounds: CGSize,
        scale: Int
    ) {
        config.width = Int(displayBounds.width) * scale
        config.height = Int(displayBounds.height) * scale
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
    }

    private func configureWindowCropping(
        on config: SCStreamConfiguration,
        scale: Int
    ) {
        guard let windowFrame = selectedWindow?.frame else { return }
        
        config.sourceRect = windowFrame
        config.width = Int(windowFrame.width) * scale
        config.height = Int(windowFrame.height) * scale
    }
    
    private func configureAudio(on config: SCStreamConfiguration) {
        let audioFormat = kAudioFormatMPEG4AAC
        let sampleRate: Int = 44_100
        let channelCount = 2

        config.capturesAudio = true
        config.sampleRate = sampleRate
        config.channelCount = channelCount
    }

    private func configureAdvancedOptions(on config: SCStreamConfiguration) {
        config.queueDepth = 6
        // config.minimumFrameInterval = CMTime(value: 1, timescale: frameRate)
    }
    
    private func bindActions() {
        actionInput
            .sink { [weak self] action in
                self?.handleAction(action)
            }
            .store(in: &cancellables)
    }
    
    private func bindMic() {
        audioManager.micBuffers
            .sink { [weak self] buffer in
                guard let self = self else { return }
                self.processedBuffersSubject.send(RecordingBuffer(sampleBuffer: buffer, kind: .microphone))
            }
            .store(in: &cancellables)
    }
    
    private func bindBufferLogger() {
        processedBuffersSubject
            .sink { [weak self] buffer in
                guard let self = self else { return }
                switch buffer.kind {
                case .video:
                    self.videoFrameCount += 1
                    if self.videoFrameCount % 60 == 0 {
                        DebugLogger.log(.pipeline, "📹 Video frames flowing... (\(self.videoFrameCount) total)")
                    }
                case .microphone:
                    self.micBufferCount += 1
                    if self.micBufferCount % 60 == 0 {
                        DebugLogger.log(.mic, "🎤 Mic buffers flowing... (\(self.micBufferCount) total)")
                    }
                case .appAudio:
                    self.appAudioCount += 1
                    if self.appAudioCount % 60 == 0 {
                        DebugLogger.log(.pipeline, "🔊 App audio flowing... (\(appAudioCount) total)")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAction(_ action: RecordAction) {
        DebugLogger.log(.action, "Received action: \(action)")
        
        switch action {

        case .start:
            Task { await start() }

        case .pause:
            DebugLogger.log(.pipeline, "Pipeline PAUSED")

        case .resume:
            DebugLogger.log(.pipeline, "Pipeline RESUMED")

        case .stop:
            Task { await stop() }

        case .restart:
            Task {
                await stop()
                await start()
            }

        case .delete:
            Task {
                await stop()
            }
        }
    }

    
    private func prepareStream() async {
        do {
            let sharable = try await SCShareableContent.current
            guard let display = sharable.displays.first(where: { $0.displayID == displayID }) else {
                errorSubject.send(.displayNotFound(id: displayID))
                return
            }
            
            let filter: SCContentFilter
            
            if let selected = selectedWindow {
                var include = [selected]
                if let cam = cameraWindow { include.append(cam) }
                filter = SCContentFilter(display: display, including: include)
            } else {
                filter = SCContentFilter(display: display,
                                         excludingApplications: [],
                                         exceptingWindows: excludedWindows)
            }
            
            let stream = SCStream(filter: filter, configuration: conf, delegate: self)
            self.stream = stream
            
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            
        } catch {
            errorSubject.send(.captureStopFailed(""))
        }
    }

    private func start() async {
        DebugLogger.log(.pipeline, "Starting pipeline...")
        await prepareStream()

        guard let stream else { 
            DebugLogger.log(.error, "Stream not initialized")
            return 
        }

        do {
            try await stream.startCapture()
            DebugLogger.log(.pipeline, "Screen capture started")
            
            try audioManager.start()
            DebugLogger.log(.mic, "Microphone capture started")
            
            DebugLogger.log(.pipeline, "✅ Pipeline started successfully")
        } catch {
            DebugLogger.log(.error, "Failed to start capture: \(error)")
            errorSubject.send(.captureStartFailed)
        }
    }

    private func stop() async {
        DebugLogger.log(.pipeline, "Stopping pipeline...")
        
        audioManager.stop()
        DebugLogger.log(.mic, "Microphone capture stopped")
        
        do {
            try await stream?.stopCapture()
            DebugLogger.log(.pipeline, "Screen capture stopped")
        } catch {
            DebugLogger.log(.error, "Failed to stop capture: \(error)")
            errorSubject.send(.captureStopFailed(""))
        }

        stream = nil
        DebugLogger.log(.pipeline, "✅ Pipeline stopped")
    }
}

extension SCKScreenRecordingPipeline: SCStreamDelegate, SCStreamOutput {
    
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        let kind: RecordingBuffer.BufferKind = outputType == .screen ? .video : .appAudio
        processedBuffersSubject.send(RecordingBuffer(sampleBuffer: sampleBuffer, kind: kind))
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) { // stream error
        DebugLogger.log(.error, "Stream stopped with error: \(error.localizedDescription)")
        errorSubject.send(.captureStopFailed(error.localizedDescription))
    }
}
