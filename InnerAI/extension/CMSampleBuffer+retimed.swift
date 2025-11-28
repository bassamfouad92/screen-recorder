//
//  CMSampleBuffer+retimed.swift
//  InnerAI
//
//  Created by Bassam Fouad on 23/11/2025.
//

import CoreMedia

extension CMSampleBuffer {
    func retimed(with timing: CMSampleTimingInfo) -> CMSampleBuffer? {
        var info = timing
        var timingArray = [info]

        var new: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingArray,
            sampleBufferOut: &new
        )
        return new
    }
}
