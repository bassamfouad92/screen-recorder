//
//  ScreenRecordService.swift
//  InnerAI
//
//  Created by Bassam Fouad on 19/11/2025.
//

import Combine
import CoreGraphics
import Foundation

protocol ScreenRecordingPipeline: AnyObject {
    // MARK: - Streams (abstracted)
    var actionInput: PassthroughSubject<RecordAction, Never> { get }

    // MARK: - Outputs
    var processedBuffers: AnyPublisher<RecordingBuffer, Never> { get }
    var errorPublisher: AnyPublisher<RecordingError, Never> { get }
}
