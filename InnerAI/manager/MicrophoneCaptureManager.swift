import AVFAudio
import AVFoundation
import Combine
import CoreMedia

final class MicrophoneCaptureManager {
    private let engine = AVAudioEngine()
    private let micBufferSubject = PassthroughSubject<CMSampleBuffer, Never>()
    var micBuffers: AnyPublisher<CMSampleBuffer, Never> {
        micBufferSubject.eraseToAnyPublisher()
    }
    
    private var audioDeviceId: UInt32 = 0
    private var isBluetooth: Bool = false
    
    func configureMic(audioDeviceId: UInt32, isBluetooth: Bool) {
        self.audioDeviceId = audioDeviceId
        self.isBluetooth = isBluetooth
        
        installRouting()
        installTap()
    }
    
    func start() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }
    
    func stop() {
        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
    }
    
    private func installRouting() {
        if audioDeviceId != 0 {
            if isBluetooth {
                setupMicInputToSystem()
            } else {
                setupMicInputToAudioUnit()
            }
        }
    }
    
    private func installTap() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        
        // Remove existing tap if any to avoid crash
        input.removeTap(onBus: 0)
        
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
            guard let self = self else { return }
            
            if let sampleBuffer = buffer.asSampleBuffer {
                self.micBufferSubject.send(sampleBuffer)
            }
        }
    }
    
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
        guard let inputUnit: AudioUnit = engine.inputNode.audioUnit else { return }
        var inputDeviceID: AudioDeviceID = audioDeviceId
        AudioUnitSetProperty(inputUnit, kAudioOutputUnitProperty_CurrentDevice,
                                     kAudioUnitScope_Global, 0, &inputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
    }
}
