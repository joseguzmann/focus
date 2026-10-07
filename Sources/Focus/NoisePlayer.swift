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
/// Each ear gets its own independent noise, which sounds wide instead of "inside the head".
/// Fades in and out to avoid clicks, and stops the engine when silent.
final class NoisePlayer {
    private let engine = AVAudioEngine()
    private let generator: NoiseGenerator
    private var stopWork: DispatchWorkItem?

    init() {
        let outputRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = outputRate > 0 ? outputRate : 48_000
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let generator = NoiseGenerator(sampleRate: Float(sampleRate))
        self.generator = generator
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let left = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let right = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : nil
            generator.render(left: left, right: right ?? left, frames: Int(frameCount))
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
/// (worst case a buffer uses the previous value).
final class NoiseGenerator: @unchecked Sendable {
    var type: NoiseType = .brown
    var targetGain: Float = 0
    private var gain: Float = 0
    private var left = NoiseChannel(seed: 0x9E37_79B9)
    private var right = NoiseChannel(seed: 0x85EB_CA6B)
    private let softTop: Float
    private let brownTop: Float
    private let fade: Float

    init(sampleRate: Float) {
        // One-pole low-pass coefficients: a soft roll-off of the hiss above ~8 kHz,
        // and a darker one for brown noise.
        softTop = 1 - exp(-2 * .pi * 8_000 / sampleRate)
        brownTop = 1 - exp(-2 * .pi * 600 / sampleRate)
        fade = 1 - exp(-1 / (0.15 * sampleRate))
    }

    func render(left out0: UnsafeMutablePointer<Float>, right out1: UnsafeMutablePointer<Float>, frames: Int) {
        let type = type
        let target = targetGain
        let top = type == .brown ? brownTop : softTop
        for i in 0..<frames {
            gain += (target - gain) * fade
            let l = left.next(type, top: top)
            let r = right.next(type, top: top)
            out0[i] = l * gain
            if out1 != out0 { out1[i] = r * gain }
        }
    }

    /// Unfaded samples, for measuring levels.
    func sample(_ type: NoiseType) -> (Float, Float) {
        let top = type == .brown ? brownTop : softTop
        return (left.next(type, top: top), right.next(type, top: top))
    }
}

struct NoiseChannel {
    private var seed: UInt32
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0
    private var b4: Float = 0, b5: Float = 0, b6: Float = 0
    private var brown: Float = 0
    private var smooth: Float = 0

    init(seed: UInt32) { self.seed = seed }

    mutating func next(_ type: NoiseType, top: Float) -> Float {
        let white = random()
        let raw: Float
        let level: Float
        switch type {
        case .white:
            raw = white
            level = 0.30
        case .pink:
            // Paul Kellet's pink noise filter.
            b0 = 0.99886 * b0 + white * 0.0555179
            b1 = 0.99332 * b1 + white * 0.0750759
            b2 = 0.96900 * b2 + white * 0.1538520
            b3 = 0.86650 * b3 + white * 0.3104856
            b4 = 0.55000 * b4 + white * 0.5329522
            b5 = -0.7616 * b5 - white * 0.0168980
            raw = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
            b6 = white * 0.115926
            level = 0.085
        case .brown:
            // Leaky integrator: −6 dB/octave down to ~20 Hz, so it keeps the deep rumble.
            brown = brown * 0.9973 + white * 0.03
            raw = brown
            level = 0.65
        }
        smooth += top * (raw - smooth)
        return smooth * level
    }

    /// xorshift32 mapped to [-1, 1]: cheap enough for the render thread.
    private mutating func random() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }
}
