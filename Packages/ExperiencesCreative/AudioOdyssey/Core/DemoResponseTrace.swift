// DemoResponseTrace — feature 057 (A07-P04) T-A07-402 (FR-A07-420; SC-A07-404; clarification 4; research D4;
// data-model "DemoResponseTrace"). The deterministic response trace of one world: precomputed analysis frames (band
// energies, spectral flux, onset flag) are fed at a fixed step through `AudioEnvelope`, the world's `WorldMapping` and
// `WorldResponse`, and the primary and light values after every frame are recorded. The Core cannot import audio, so
// the frames come from the caller (synthetic frames in the Core tests, the real demo source through the feature
// extractor in the experience tests). No wall clock is read.
//
// Rules: frame i uses time `i × step` and elapsed `step`; the run stops at the shortest of the three input arrays.
// `maxRise` is `(max primary − rest) ÷ (upper − rest)` of the world without Reduce Motion (0 for an empty trace).
import Foundation

/// The deterministic audio-response trace of a world for a sequence of analysis frames.
public enum DemoResponseTrace {
    /// The response after one frame.
    public struct TracePoint: Equatable, Sendable {
        /// The primary amount (tunnel breathing, landscape height, star-corridor sparkle).
        public let primary: Double
        /// The light (ambient brightness).
        public let light: Double

        /// A point with the given primary amount and light.
        public init(primary: Double, light: Double) {
            self.primary = primary
            self.light = light
        }
    }

    /// Feeds the frames through a fresh envelope and a resting response of `world` and records the response after
    /// every frame.
    /// - Parameters:
    ///   - bandFrames: The band energies of every frame.
    ///   - flux: The spectral flux of every frame.
    ///   - onsets: The onset flag of every frame.
    ///   - world: The world whose response is traced.
    ///   - mapping: The mapping that turns the envelope into the primary and light targets.
    ///   - step: The fixed time step in seconds (1/60 in the tests).
    ///   - reduceMotion: Whether calm motion or Reduce Motion halves the primary range.
    ///   - reduceFlashing: Whether Reduce Flashing narrows the light range.
    /// - Returns: One point per frame (the shortest input length).
    public static func run(bandFrames: [[Float]], flux: [Float], onsets: [Bool], world: JourneyWorld,
                           mapping: WorldMapping, step: Double, reduceMotion: Bool = false,
                           reduceFlashing: Bool = false) -> [TracePoint] {
        var envelope = AudioEnvelope()
        var response = WorldResponse(world: world, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
        let count = min(bandFrames.count, flux.count, onsets.count)
        var trace: [TracePoint] = []
        trace.reserveCapacity(count)
        for i in 0..<count {
            envelope.update(bandEnergies: bandFrames[i], flux: flux[i], onset: onsets[i], time: Double(i) * step,
                            elapsed: step)
            let targets = mapping.target(from: envelope)
            response.update(primaryTarget: targets.primary, lightTarget: targets.light)
            trace.append(TracePoint(primary: response.primary, light: response.light))
        }
        return trace
    }

    /// The largest rise of the primary amount as a fraction of the world's range above rest (without Reduce Motion):
    /// `(max primary − rest) ÷ (max − rest)`; 0 for an empty trace.
    /// - Parameters:
    ///   - trace: A trace made by `run` for `world`.
    ///   - world: The traced world.
    /// - Returns: The rise in 0…1 (negative only if the primary fell below rest).
    public static func maxRise(_ trace: [TracePoint], world: JourneyWorld) -> Double {
        guard let peak = trace.map(\.primary).max() else { return 0 }
        let rest = WorldResponse.restPrimary(for: world)
        let span = WorldResponse.maxPrimary(for: world) - rest
        return span > 0 ? (peak - rest) / span : 0
    }
}
