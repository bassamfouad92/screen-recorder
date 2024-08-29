//
//  MyRecorder.swift
//  InnerAI
//
//  Created by Bassam Fouad on 03/05/2024.
//

import Foundation
import ScreenCaptureKit
import AVFAudio
import AVFoundation

// Thanks to https://github.com/Mnpn/Azayaka

class ScreenRecordManager: NSObject, SCStreamDelegate, SCStreamOutput {
    
    deinit {
        print("ScreenRecordManager deinit")
    }
    
    var audioWriter: AVAssetWriter?
    var videoWriter: AVAssetWriter!
    var vwInput, awInput, micInput: AVAssetWriterInput!
    let audioEngine = AVAudioEngine()
    var startTime: Date?
    var stream: SCStream!
    var filePath: String!
    var audioFile: AVAudioFile?
    var audioSettings: [String : Any]!
    var availableContent: SCShareableContent?
    var filter: SCContentFilter?
    var updateTimer: Timer?
    var recordMic = true // enable/disable mic
    var audioOutputURL: URL!
    var autioStartTime: Date?
    var streamType: StreamType?
    var audioDeviceId: UInt32 = 0
    var audioDeviceTransportType: AudioDeviceTransportType = .builtIn
    var isPause: Bool = false {
        didSet {
            if isPause {
                pauseStreaming()
            } else {
                resumeStreaming()
            }
        }
    } // to pause a video & audio writing buffer
    var pausedDuration: CMTime = .zero
    var pauseStartTime: Float64?

    private var frameRate: Int = 60
    private var videoQuality: Double = 1.0
    private var videoFormat: VideoFormat = .mp4
    private var encoder: Encoder = .h264
    
    private var sessionTime: CMTime = .zero
        
    var sampleBufferBeforeTime: CMTime = CMTime.zero
    var sampleBufferAfterTime: CMTime = CMTime.zero
    var adjustedBufferTime: CMTime = .zero
    var fileURL: URL?

    let excludedWindows = ["", "com.apple.dock", "com.apple.controlcenter", "com.apple.notificationcenterui", "com.apple.systemuiserver", "com.apple.WindowManager", "dev.mnpn.Azayaka", "com.gaosun.eul", "com.pointum.hazeover", "net.matthewpalmer.Vanilla", "com.dwarvesv.minimalbar", "com.bjango.istatmenus.status"]
    
    var onStopStream: (_ stream: SCStream) -> Void = { stream in }
    var isStreamStopped = false
    var mode: RecordMode = .h264_sRGB
    var lastSampleBuffer: CMSampleBuffer?
    var sessionStarted = false
    var firstSampleTime: CMTime = .zero

    func record(displayID: CGDirectDisplayID, selectedWindow: SCWindow?, cameraWindow: SCWindow?, excludedWindows: [SCWindow]? = []) async throws {
        let conf = SCStreamConfiguration()
        conf.width = 2
        conf.height = 2
        
        let displaySize = CGDisplayBounds(displayID).size
        
        // The number of physical pixels that represent a logic point on screen, currently 2 for MacBook Pro retina displays
        let displayScaleFactor: Int
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            displayScaleFactor = mode.pixelWidth / mode.width
        } else {
            displayScaleFactor = 1
        }
        
        conf.width = Int(displaySize.width) * displayScaleFactor
        conf.height = Int(displaySize.height) * displayScaleFactor
        
        
        var channelLayout = AudioChannelLayout()
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_1_D
        
        audioSettings = [
            AVNumberOfChannelsKey: 6,
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVSampleRateKey : 44100,
            AVChannelLayoutKey : NSData(bytes: &channelLayout, length: MemoryLayout.size(ofValue: channelLayout))
        ] as [String : Any]
        
        conf.queueDepth = 6
        //conf.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        conf.showsCursor = true
        conf.pixelFormat = kCVPixelFormatType_32BGRA // 'BGRA'
        conf.colorSpaceName = CGColorSpace.sRGB
        conf.capturesAudio = true
        conf.sampleRate = audioSettings["AVSampleRateKey"] as! Int
        conf.channelCount = audioSettings["AVNumberOfChannelsKey"] as! Int
        
        
        if let cropRect = selectedWindow?.frame {
            // ScreenCaptureKit uses top-left of screen as origin
            if displayID != CGMainDisplayID() {
                conf.sourceRect = CGRect(x: cropRect.origin.x - CGDisplayBounds(displayID).origin.x, y: cropRect.origin.y, width: cropRect.width, height: cropRect.height)
            } else {
                conf.sourceRect = cropRect
            }
            conf.width = Int(cropRect.width) * displayScaleFactor
            conf.height = Int(cropRect.height) * displayScaleFactor
        } else {
            conf.width = Int(displaySize.width) * displayScaleFactor
            conf.height = Int(displaySize.height) * displayScaleFactor
        }
        let sharableContent = try await SCShareableContent.current
        
        guard let display = sharableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw RecordingError("Can't find display with ID \(displayID) in sharable content")
        }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows ?? [])
        //stream = SCStream(filter: SCContentFilter(desktopIndependentWindow:             sharableContent.windows.first(where: {$0.windowID == 60})!), configuration: conf, delegate: self)
        if let choosed = selectedWindow {
           var includings: [SCWindow] = [choosed]
            if let cameraWindow = cameraWindow {
                includings.append(cameraWindow)
                stream = SCStream(filter: SCContentFilter(display: display, including: includings), configuration: conf, delegate: self)
            } else {
                stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: choosed), configuration: conf, delegate: self)
            }
        } else {
            stream = SCStream(filter: filter, configuration: conf, delegate: self)
        }
        
        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            initVideo(conf: conf, displayScaleFactor: displayScaleFactor, displaySize: displaySize)
        } catch {
            assertionFailure("capture failed")
            return
        }
    }
    
    func start() async throws {
        try await stream.startCapture()
    }
    
    private func getFilePath() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
        let fileName = "inner_ai_recording_new"
        let fileNameWithDates = fileName.replacingOccurrences(of: "%t", with: dateFormatter.string(from: Date())).prefix(Int(NAME_MAX) - 5)
        return String(fileName)
    }
    
    func getRecordingLength() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: Date.now.timeIntervalSince(startTime ?? Date.now)) ?? "Unknown"
    }
    
    func getRecordingSize() -> String {
        do {
            if let filePath = filePath {
                let fileAttr = try FileManager.default.attributesOfItem(atPath: filePath)
                let byteFormat = ByteCountFormatter()
                byteFormat.allowedUnits = [.useMB]
                byteFormat.countStyle = .file
                return byteFormat.string(fromByteCount: fileAttr[FileAttributeKey.size] as! Int64)
            }
        } catch {
            print(String(format: "failed to fetch file for size indicator: %@", error.localizedDescription))
        }
        return "Unknown"
    }
}

extension ScreenRecordManager {

    private func initVideo(conf: SCStreamConfiguration, displayScaleFactor: Int, displaySize: CGSize) {
        
        startTime = nil
        let fileEnding = videoFormat
        var fileType: AVFileType?
        
        switch fileEnding {
            case VideoFormat.mov: fileType = AVFileType.mov
            case VideoFormat.mp4: fileType = AVFileType.mp4
        }

        filePath = "\(getFilePath())\(Date()).\(fileEnding)"
        // Ensure directory exists
        FileUtils.createDirectoryInDocuments(withName: "inneraivideos")

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let newDirectoryURL = documentsURL.appendingPathComponent("inneraivideos")
        
        fileURL = newDirectoryURL.appendingPathComponent(filePath)

        guard fileURL?.startAccessingSecurityScopedResource() ?? false else {
            print("Failed to access the file.")
             return
        }
        
        defer {
            fileURL?.stopAccessingSecurityScopedResource()
        }
        
        videoWriter = try? AVAssetWriter(url: fileURL!, fileType: fileType!)
        // AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
        // Downsize to fit a larger display back into in 4K
        let videoSize = downsizedVideoSize(source: displaySize, scaleFactor: displayScaleFactor, mode: mode)

        // Use the preset as large as possible, size will be reduced to screen size by computed videoSize
        guard let assistant = AVOutputSettingsAssistant(preset: mode.preset) else {
            return
        }
        
        do {
            assistant.sourceVideoFormat = try CMVideoFormatDescription(videoCodecType: mode.videoCodecType, width: videoSize.width, height: videoSize.height)
        } catch {
            print("Assistant error")
        }

        guard var outputSettings = assistant.videoSettings else {
            return
        }
        outputSettings[AVVideoWidthKey] = videoSize.width
        outputSettings[AVVideoHeightKey] = videoSize.height

        // Configure video color properties and compression properties based on RecordMode
        // See AVVideoSettings.h and VTCompressionProperties.h
        outputSettings[AVVideoColorPropertiesKey] = mode.videoColorProperties

        if let videoProfileLevel = mode.videoProfileLevel {
            var compressionProperties: [String: Any] = outputSettings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
            compressionProperties[AVVideoProfileLevelKey] = videoProfileLevel
            outputSettings[AVVideoCompressionPropertiesKey] = compressionProperties as NSDictionary
        }
        
        vwInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        //awInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        micInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        vwInput.expectsMediaDataInRealTime = true
       // awInput.expectsMediaDataInRealTime = true
        micInput.expectsMediaDataInRealTime = true
        
        /*self.audioOutputURL = URL(filePath: FileManager.default.currentDirectoryPath).appending(path: "fouad-recording \(Date()).\(fileEnding)")
        
        do {
            try audioWriter = AVAssetWriter(outputURL: self.audioOutputURL, fileType: .mp4)
        } catch let writerError as NSError {
            print("Error opening video file \(writerError)")
        }*/

        if videoWriter.canAdd(vwInput) {
            videoWriter.add(vwInput)
        }

        /*if ((audioWriter?.canAdd(awInput)) != nil) {
            audioWriter?.add(awInput)
        }*/
        if recordMic {
            if videoWriter.canAdd(micInput) {
                videoWriter.add(micInput)
            }

            let input = audioEngine.inputNode
            
            if audioDeviceId != 0 {
                /// When you try to set the kAudioOutputUnitProperty_CurrentDevice property on the AudioUnit of the AVAudioEngine's input node, it might not work as expected for Bluetooth devices like AirPods. This is because AVAudioEngine is designed to work with the system's default audio route, and changing the input/output devices programmatically might conflict with how AVAudioEngine manages audio routes. So we need to set mac's input device to working with bluetooth
                if audioDeviceTransportType == .bluetooth {
                    setupMicInputToSystem()
                } else {
                    setupMicInputToAudioUnit()
                }
            }
            
            input.installTap(onBus: 0, bufferSize: 1024, format: input.inputFormat(forBus: 0)) { [self] (buffer, time) in
            
                if micInput.isReadyForMoreMediaData && startTime != nil && !isPause {
                    if !micInput.append(buffer.asSampleBuffer!) {
                        print("Mic buffered not added")
                    }
                    //_cacheAudioBuffer(sampleBuffer: buffer.asSampleBuffer!, isMuted: isPause)
                }
            }
            do {
                try audioEngine.start()
            } catch {
                print("Unable to start audio engine")
            }
        }
        videoWriter.startWriting()
        //audioWriter?.startWriting()
    }
    
    //write empty audio buffers when in paused or muted state
    private func _cacheAudioBuffer(sampleBuffer: CMSampleBuffer, isMuted: Bool) {
        if isMuted, let ref = CMSampleBufferGetDataBuffer(sampleBuffer) {
            CMBlockBufferFillDataBytes(
                with: 0,
                blockBuffer: ref,
                offsetIntoDestination: 0,
                dataLength: CMBlockBufferGetDataLength(ref))
            
            if !micInput.append(sampleBuffer) {
                print("Mic buffered not added")
            }
        } else {
            if !micInput.append(sampleBuffer) {
                print("Mic buffered not added")
            }
        }
    }
    

    func stopRecording() async throws {
        
        do {
            if !isStreamStopped {
                try await stream.stopCapture()
            }
            await stopWriting()
        } catch {
            print("Unable to stop session")
        }
        
    }
    
    private func stopWriting() async {
        //vwInput.markAsFinished()
        //awInput.markAsFinished()
        if recordMic {
            micInput.markAsFinished()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        videoWriter.endSession(atSourceTime: lastSampleBuffer?.presentationTimeStamp ?? .zero)
        vwInput.markAsFinished()
        await videoWriter.finishWriting()
        /*audioWriter?.endSession(atSourceTime: sessionTime)
        audioWriter?.finishWriting {
            print("Audio write done")
        }*/
    }
    
    func createAdjustedSampleBuffer(_ sampleBuffer: CMSampleBuffer, with adjustedPresentationTime: CMTime) -> CMSampleBuffer? {
        var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: adjustedPresentationTime, decodeTimeStamp: .invalid)
        var adjustedSampleBuffer: CMSampleBuffer?
        
        let status = CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleBufferOut: &adjustedSampleBuffer)
        
        guard status == noErr, let adjustedBuffer = adjustedSampleBuffer else {
            return nil
        }
        
        return adjustedBuffer
    }
    
    func pauseStreaming() {
        pauseStartTime = CMTimeGetSeconds(sampleBufferBeforeTime)
    }

    // ****** Note on resume subtract before pause time to (during pause time) to adjust frames *********
    func resumeStreaming() {
        let pauseEndTime = CMTimeGetSeconds(sampleBufferAfterTime)
        pausedDuration = CMTime(seconds: pauseEndTime - pauseStartTime!, preferredTimescale: 1000)
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        
        // Return early if session hasn't started yet
        //guard sessionStarted else { return }

        guard sampleBuffer.isValid, !isPause else {
            // ****** Note save buffer time during pause *********
            sampleBufferAfterTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            return
        }
        
        // Retrieve the array of metadata attachments from the sample buffer
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first
        else { return }

        // Validate the status of the frame. If it isn't `.complete`, return
        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete
        else { return }
        
        
        switch outputType {
        case .screen:
            
            if videoWriter != nil && videoWriter?.status == .writing, startTime == nil {
                startTime = Date.now
                sessionTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoWriter.startSession(atSourceTime: sessionTime)
                sessionStarted = true
                //videoWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            }
            
            guard sessionStarted else { return }
            
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if pauseStartTime != nil {
                
                let adjustedPresentationTime = CMTimeSubtract(presentationTime, pausedDuration)
                
                // Create a new CMSampleBuffer with adjusted timing
                guard let adjustedSampleBuffer = createAdjustedSampleBuffer(sampleBuffer, with: adjustedPresentationTime) else {
                    print("Failed to adjust sample buffer timing")
                    return
                }
                
                // ****** Note update buffer time with new adjustedSampleBuffer after first resume, now this time would be use for rest of the pause/resumes *********
                sampleBufferBeforeTime = CMSampleBufferGetPresentationTimeStamp(adjustedSampleBuffer)
                
                if vwInput.isReadyForMoreMediaData {
                    lastSampleBuffer = sampleBuffer
                    if !vwInput.append(adjustedSampleBuffer) {
                        print("Failed to append adjusted sample buffer to video writer input")
                    }
                }
            } else {
                
                // ****** Note buffer time with sampleBuffer for first time *********
                
                sampleBufferBeforeTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                if vwInput.isReadyForMoreMediaData {
                    
                    lastSampleBuffer = sampleBuffer

                    if !vwInput.append(sampleBuffer) {
                        print("Failed to append sample buffer to video writer input")
                    }
                }
            }
            
            break
        case .audio:
            break
            /*guard let audioWriter = audioWriter else { break }
             if audioWriter.status == .unknown {
             if audioWriter.startWriting() {
             print("audio writing started")
             audioWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
             }
             } else if audioWriter.status == .writing {
             
             if self.autioStartTime == nil {
             autioStartTime = .now
             audioWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
             }
             
             if let isReadyForMoreMediaData = awInput?.isReadyForMoreMediaData,
             isReadyForMoreMediaData {
             if let appendInput = awInput?.append(sampleBuffer),
             !appendInput {
             print("couldn't write app audio buffer")
             }
             }
             }*/
        @unknown default:
            assertionFailure("unknown stream type")
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) { // stream error
        print("closing stream with error:\n", error,
              "\nthis might be due to the window closing or the user stopping from the sonoma ui")
        isStreamStopped = true
        sessionTime = CMSampleBufferGetPresentationTimeStamp(lastSampleBuffer!)
        onStopStream(stream)
    }
}

// https://developer.apple.com/documentation/screencapturekit/capturing_screen_content_in_macos
// For Sonoma updated to https://developer.apple.com/forums/thread/727709
extension CMSampleBuffer {
    var asPCMBuffer: AVAudioPCMBuffer? {
        try? self.withAudioBufferList { audioBufferList, _ -> AVAudioPCMBuffer? in
            guard let absd = self.formatDescription?.audioStreamBasicDescription else { return nil }
            guard let format = AVAudioFormat(standardFormatWithSampleRate: absd.mSampleRate, channels: absd.mChannelsPerFrame) else { return nil }
            return AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer)
        }
    }
}

// Based on https://gist.github.com/aibo-cora/c57d1a4125e145e586ecb61ebecff47c
extension AVAudioPCMBuffer {
    var asSampleBuffer: CMSampleBuffer? {
        let asbd = self.format.streamDescription
        var sampleBuffer: CMSampleBuffer? = nil
        var format: CMFormatDescription? = nil

        guard CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &format
        ) == noErr else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(asbd.pointee.mSampleRate)),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )

        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: CMItemCount(self.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        ) == noErr else { return nil }

        guard CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer!,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: self.mutableAudioBufferList
        ) == noErr else { return nil }

        return sampleBuffer
    }
}

extension ScreenRecordManager {
    private func setupMicInputToSystem() {
        var inputDeviceID: AudioDeviceID = audioDeviceId
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)

        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address,
                                                0,
                                                nil,
                                                UInt32(MemoryLayout<AudioDeviceID>.size),
                                                &inputDeviceID)
        if status != noErr {
            print("Failed to set default input device with error: \(status)")
        }
    }
    
    private func setupMicInputToAudioUnit() {
        guard let inputUnit: AudioUnit = audioEngine.inputNode.audioUnit else { return }
        var inputDeviceID: AudioDeviceID = audioDeviceId
        AudioUnitSetProperty(inputUnit, kAudioOutputUnitProperty_CurrentDevice,
                                     kAudioUnitScope_Global, 0, &inputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
    }
}
