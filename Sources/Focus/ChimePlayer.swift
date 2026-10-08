import AVFoundation

/// End-of-phase chime: a soft bell arpeggio played twice (~3.5 s), noticeable without being
/// an alarm. Descending when a pomodoro ends (time to relax), ascending when a break ends
/// (back to work). Synthesized, so there are no audio files.
enum ChimePlayer {
    /// The engine playing the current chime; kept alive until it finishes.
    private static var engine: AVAudioEngine?

    static func play(_ finished: Phase) {
        // C6, E6, G6.
        let notes: [Double] = [1046.5, 1318.5, 1568.0]
        guard let buffer = render(notes: finished == .focus ? notes.reversed() : notes) else { return }

        // A fresh engine per chime always plays on the current output device.
        engine?.stop()
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        guard (try? engine.start()) != nil else { return }
        self.engine = engine
        player.scheduleBuffer(buffer) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.engine === engine {
                    engine.stop()
                    self.engine = nil
                }
            }
        }
        player.play()
    }

    static func render(notes: [Double], sampleRate: Double = 48_000) -> AVAudioPCMBuffer? {
        let noteGap = 0.22      // seconds between notes of the arpeggio
        let repeatGap = 1.35    // seconds between the two arpeggios
        let ring = 1.8          // how long each note rings
        let starts = (0..<2).flatMap { r in
            notes.indices.map { Double(r) * repeatGap + Double($0) * noteGap }
        }
        let duration = (starts.last ?? 0) + ring
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let left = buffer.floatChannelData?[0],
              let right = buffer.floatChannelData?[1] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { left[i] = 0 }

        for (n, start) in starts.enumerated() {
            let freq = notes[n % notes.count]
            // The second round is a bit softer, so it reads as an echo, not a second alarm.
            let level: Float = n < notes.count ? 0.16 : 0.11
            let first = Int(start * sampleRate)
            let count = min(Int(ring * sampleRate), Int(frames) - first)
            for k in 0..<count {
                let t = Double(k) / sampleRate
                let attack = min(1, t / 0.006)
                let decay = exp(-t / 0.45)
                // Bell-like partials: fundamental plus soft, slightly inharmonic overtones.
                let tone = sin(2 * .pi * freq * t)
                    + 0.35 * sin(2 * .pi * freq * 2.01 * t) * exp(-t / 0.25)
                    + 0.12 * sin(2 * .pi * freq * 3.02 * t) * exp(-t / 0.15)
                left[first + k] += level * Float(attack * decay * tone)
            }
        }
        for i in 0..<Int(frames) { right[i] = left[i] }
        return buffer
    }
}
