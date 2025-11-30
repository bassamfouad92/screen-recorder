//
//  WriterConfig.swift
//  InnerAI
//
//  Created by Bassam Fouad on 23/11/2025.
//

import Foundation
import AVFoundation

struct WriterConfig {
    let url: URL
    let fileType: AVFileType
    
    let videoSettings: [String: Any]
    let appAudioSettings: [String: Any]?
    let micAudioSettings: [String: Any]?
    
    static func create(
        url: URL,
        displaySize: CGSize,
        scaleFactor: Int,
        mode: RecordMode,
        videoFormat: VideoFormat,
        recordMic: Bool
    ) throws -> WriterConfig {
        
        let videoSize = downsizedVideoSize(source: displaySize, scaleFactor: scaleFactor, mode: mode)
        
        guard let assistant = AVOutputSettingsAssistant(preset: mode.preset) else {
            throw RecordingError.custom("Can't create AVOutputSettingsAssistant")
        }
        
        assistant.sourceVideoFormat = try CMVideoFormatDescription(videoCodecType: mode.videoCodecType, width: videoSize.width, height: videoSize.height)
        
        guard var outputSettings = assistant.videoSettings else {
            throw RecordingError.custom("AVOutputSettingsAssistant has no videoSettings")
        }
        
        outputSettings[AVVideoWidthKey] = videoSize.width
        outputSettings[AVVideoHeightKey] = videoSize.height
        outputSettings[AVVideoColorPropertiesKey] = mode.videoColorProperties
        
        if let videoProfileLevel = mode.videoProfileLevel {
            var compressionProperties = outputSettings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
            compressionProperties[AVVideoProfileLevelKey] = videoProfileLevel
            outputSettings[AVVideoCompressionPropertiesKey] = compressionProperties
        }
        
        // Audio Settings
        let audioSettings: [String: Any] = [
            AVNumberOfChannelsKey: 2,
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100
        ]
        
        let fileType: AVFileType = videoFormat == .mp4 ? .mp4 : .mov
        
        return WriterConfig(
            url: url,
            fileType: fileType,
            videoSettings: outputSettings,
            appAudioSettings: audioSettings,
            micAudioSettings: recordMic ? audioSettings : nil
        )
    }
}
