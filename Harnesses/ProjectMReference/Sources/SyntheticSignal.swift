// SyntheticSignal.swift — deterministic stereo test audio for the engine (feature 008 T-F703; research R4).
// 44.1 kHz; a 220 Hz tone whose pitch sweeps slowly, plus 2 Hz beat pulses, as a pure function of the frame
// index. No capture (FR-F708): the reference keeps all real audio paths.
import Foundation

struct SyntheticSignal: Sendable, Equatable {
    static let sampleRate = 44_100.0
    /// Audio frames already produced.
    private(set) var frame = 0

    /// Interleaved stereo Float32 samples for the next `frames` frames.
    mutating func next(frames: Int) -> [Float] {
        guard frames > 0 else { return [] }
        var out = [Float](repeating: 0, count: frames * 2)
        for i in 0..<frames {
            let t = Double(frame + i) / Self.sampleRate
            let pitch = 220 * (1 + 0.5 * sin(2 * .pi * 0.1 * t))
            let beat = exp(-12 * (t * 2).truncatingRemainder(dividingBy: 1))
            let tone = sin(2 * .pi * pitch * t) * (0.25 + 0.6 * beat)
            out[2 * i] = Float(tone)
            out[2 * i + 1] = Float(tone * 0.9)
        }
        frame += frames
        return out
    }

    /// Splits one video frame's worth of audio (1/60 s) into engine-sized chunks (edge case: per-call maximum).
    mutating func chunksForVideoFrame(maxFramesPerCall: Int, videoRate: Double = 60) -> [[Float]] {
        let total = Int((Self.sampleRate / videoRate).rounded())
        let limit = max(1, maxFramesPerCall)
        var chunks: [[Float]] = []
        var remaining = total
        while remaining > 0 {
            let n = min(limit, remaining)
            chunks.append(next(frames: n))
            remaining -= n
        }
        return chunks
    }
}
