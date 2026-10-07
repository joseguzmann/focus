import AVFoundation

enum NoiseType: String, Codable, CaseIterable, Identifiable {
    case white, pink, brown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: "White noise"
        case .pink: "Pink noise"
        case .brown: "Brown noise"
        }
    }
}

/// Generates background noise in real time (no audio files, no loops).
/// Fades in and out to avoid clicks, and stops the engine when silent.
final class NoisePlayer {
    private let engine = AVAudioEngine()
    private let generator = NoiseGenerator()
    private var stopWork: DispatchWorkItem?

    init() {
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate > 0 ? sampleRate : 48_000, channels: 1)!
        let generator = generator
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            for frame in 0..<Int(frameCount) {
                let sample = generator.next()
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
    }

    func play(_ type: NoiseType, volume: Double) {
        stopWork?.cancel()
        generator.type = type
        generator.targetGain = Float(volume)
        if !engine.isRunning { try? engine.start() }
    }

    func stop() {
        generator.targetGain = 0
        guard engine.isRunning, stopWork == nil || stopWork!.isCancelled else { return }
        // Let the fade-out finish before releasing the audio device.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generator.targetGain == 0 else { return }
            self.engine.pause()
        }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}

/// State shared with the audio render thread. Races on these scalars are harmless
/// (worst case a sample uses the previous value).
private final class NoiseGenerator: @unchecked Sendable {
    var type: NoiseType = .brown
    var targetGain: Float = 0
    private var gain: Float = 0
    private var seed: UInt32 = 0x9E37_79B9
    private var brown: Float = 0
    private var pink = [Float](repeating: 0, count: 7)

    func next() -> Float {
        // ~0.1 s fade at 48 kHz.
        gain += (targetGain - gain) * 0.0002
        let white = random()
        let sample: Float
        switch type {
        case .white:
            sample = white * 0.25
        case .pink:
            // Paul Kellet's pink noise filter.
            pink[0] = 0.99886 * pink[0] + white * 0.0555179
            pink[1] = 0.99332 * pink[1] + white * 0.0750759
            pink[2] = 0.96900 * pink[2] + white * 0.1538520
            pink[3] = 0.86650 * pink[3] + white * 0.3104856
            pink[4] = 0.55000 * pink[4] + white * 0.5329522
            pink[5] = -0.7616 * pink[5] - white * 0.0168980
            let value = pink[0] + pink[1] + pink[2] + pink[3] + pink[4] + pink[5] + pink[6] + white * 0.5362
            pink[6] = white * 0.115926
            sample = value * 0.09
        case .brown:
            // Leaky integrator of white noise.
            brown = (brown + 0.02 * white) / 1.02
            sample = brown * 3.0
        }
        return sample * gain
    }

    /// xorshift32 mapped to [-1, 1]: cheap enough for the render thread.
    private func random() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }
}
