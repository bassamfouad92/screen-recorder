import CoreMedia

extension CMSampleBuffer {
    func retimed(with timing: CMSampleTimingInfo) -> CMSampleBuffer? {
        var timingInfo = timing
        var sampleBuffer: CMSampleBuffer?
        
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        return status == noErr ? sampleBuffer : nil
    }
}
