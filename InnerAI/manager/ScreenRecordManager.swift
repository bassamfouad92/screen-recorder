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

    let excludedWindows = ["", "com.apple.dock", "com.apple.controlcenter", "com.apple.notificationcenterui", "com.apple.systemuiserver", "com.apple.WindowManager", "dev.mnpn.Azayaka", "com.gaosun.eul", "com.pointum.hazeover", "net.matthewpalmer.Vanilla", "com.dwarvesv.minimalbar", "com.bjango.istatmenus.status"]
    
    var onStopStream: (_ stream: SCStream) -> Void = { stream in }
    var isStreamStopped = false
    
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
            AVNumberOfChannelsKey : 6,
            AVFormatIDKey : kAudioFormatMPEG4AAC_HE,
            AVSampleRateKey : 44100,
            AVChannelLayoutKey : NSData(bytes: &channelLayout, length: MemoryLayout.size(ofValue: channelLayout))
        ] as [String : Any]
        
        conf.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        conf.showsCursor = true
        conf.capturesAudio = true
        conf.sampleRate = audioSettings["AVSampleRateKey"] as! Int
        conf.channelCount = audioSettings["AVNumberOfChannelsKey"] as! Int
        
        
        if let cropRect = selectedWindow?.frame {
            // ScreenCaptureKit uses top-left of screen as origin
            conf.sourceRect = cropRect
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
            initVideo(conf: conf)
            try await stream.startCapture()
        } catch {
            assertionFailure("capture failed")
            return
        }
    }
    
    private func getFilePath() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
        let fileName = "inner_ai_recording_new"
        let fileNameWithDates = fileName.replacingOccurrences(of: "%t", with: dateFormatter.string(from: Date())).prefix(Int(NAME_MAX) - 5)
        return String(fileNameWithDates)
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
    private func initVideo(conf: SCStreamConfiguration) {
        
        startTime = nil
        let fileEnding = videoFormat
        var fileType: AVFileType?
        
        switch fileEnding {
            case VideoFormat.mov: fileType = AVFileType.mov
            case VideoFormat.mp4: fileType = AVFileType.mp4
        }

        filePath = "\(getFilePath())\(Date()).\(fileEnding)"
        videoWriter = try? AVAssetWriter.init(outputURL: URL(fileURLWithPath: filePath), fileType: fileType!)
        let encoderIsH265 = self.encoder == .h265
        let fpsMultiplier: Double = Double(frameRate/8)
        let encoderMultiplier: Double = encoderIsH265 ? 0.5 : 0.9
        let targetBitrate = (Double(conf.width) * Double(conf.height) * fpsMultiplier * encoderMultiplier * videoQuality)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: encoderIsH265 ? AVVideoCodecType.hevc : AVVideoCodecType.h264,
            // yes, not ideal if we want more than these encoders in the future, but it's ok for now
            AVVideoWidthKey: conf.width,
            AVVideoHeightKey: conf.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(targetBitrate),
                AVVideoExpectedSourceFrameRateKey: frameRate
            ] as [String : Any]
        ]
        vwInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        awInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        micInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        vwInput.expectsMediaDataInRealTime = true
        awInput.expectsMediaDataInRealTime = true
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
            print("Record Microphone on!!!!")
            if videoWriter.canAdd(micInput) {
                videoWriter.add(micInput)
            }

            let input = audioEngine.inputNode
            
            if audioDeviceId != 0 {
                guard let inputUnit: AudioUnit = input.audioUnit else { return }
                var inputDeviceID: AudioDeviceID = audioDeviceId
                AudioUnitSetProperty(inputUnit, kAudioOutputUnitProperty_CurrentDevice,
                                             kAudioUnitScope_Global, 0, &inputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
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
        vwInput.markAsFinished()
        //awInput.markAsFinished()
        if recordMic {
            micInput.markAsFinished()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        let adjustedSessionTime: CMTime

        if let pauseStartTime = pauseStartTime {
            // Calculate the adjusted session time based on the pause duration
            let time = CMTimeMakeWithSeconds(pauseStartTime, preferredTimescale: 600)
            adjustedSessionTime = CMTimeSubtract(sessionTime, time)
        } else {
            adjustedSessionTime = sessionTime
        }
        
        videoWriter.endSession(atSourceTime: adjustedSessionTime)
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
        
        
        guard sampleBuffer.isValid, !isPause else {
            // ****** Note save buffer time during pause *********
            sampleBufferAfterTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            return
        }
        
        switch outputType {
        case .screen:
            guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let attachments = attachmentsArray.first else { return }
            guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
                  let status = SCFrameStatus(rawValue: statusRawValue),
                  status == .complete else { return }
            
            if videoWriter != nil && videoWriter?.status == .writing, startTime == nil {
                startTime = Date.now
                sessionTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            }
            
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
                    if !vwInput.append(adjustedSampleBuffer) {
                        print("Failed to append adjusted sample buffer to video writer input")
                    }
                }
            } else {
                
                // ****** Note buffer time with sampleBuffer for first time *********
                
                sampleBufferBeforeTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                if vwInput.isReadyForMoreMediaData {
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
