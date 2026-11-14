// AudioMapper — feature 049 (A06-P03) T-A06-302; gap G-AUDIOMAP (FR-A06-301, FR-A06-302; SC-A06-301; research D1, D2;
// data-model "AudioMapper"; contract specs/049-ml-p03-scenes-mapping/contracts/api.md). Applies one ``AudioMapping`` to
// successive feature sets: normalise, scale and clamp, smooth with a ``FeatureSmoother``, map into a parameter range.
// A plain value that allocates nothing per update.
import Foundation

/// Turns successive ``AudioFeatures`` into values of one parameter according to an ``AudioMapping``.
///
/// Each ``value(for:range:elapsed:)`` computes n = feature.normalized, x = clamp(gain · n, clampLow, clampHigh),
/// s = smoother(attack, release) over x with the elapsed time, and returns `range.lowerBound + s · (upper − lower)`.
/// The rest value (silence, s = 0) is the range minimum.
public struct AudioMapper: Sendable {
    /// The mapping applied.
    public private(set) var mapping: AudioMapping
    private var smoother: FeatureSmoother

    /// Creates a mapper at rest (``smoothed`` = 0).
    public init(mapping: AudioMapping) {
        self.mapping = mapping
        self.smoother = FeatureSmoother(attack: mapping.attack, release: mapping.release)
    }

    /// The current smoothed, clamped feature value (0…1).
    public var smoothed: Double { Double(smoother.value) }

    /// Advances the smoothing by `elapsed` seconds towards the mapped `features` and returns the parameter value.
    ///
    /// - Parameters:
    ///   - features: the newest feature set.
    ///   - range: the parameter's range; the result always lies within it.
    ///   - elapsed: seconds since the previous call; negative or non-finite values leave the smoothing unchanged.
    /// - Returns: `range.lowerBound + smoothed · (range.upperBound − range.lowerBound)`, clamped to `range`.
    public mutating func value(for features: AudioFeatures, range: ClosedRange<Double>, elapsed: Double) -> Double {
        let n = Double(mapping.feature.normalized(features))
        let x = min(max(mapping.gain * n, mapping.clampLow), mapping.clampHigh)
        let s = Double(smoother.update(target: Float(x), elapsed: elapsed))
        let value = range.lowerBound + s * (range.upperBound - range.lowerBound)
        guard value.isFinite else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// Returns the smoothing to rest (``smoothed`` = 0).
    public mutating func reset() {
        smoother.reset()
    }

    /// Replaces the mapping and keeps the current ``smoothed`` value, so a change of gain or feature glides.
    public mutating func setMapping(_ mapping: AudioMapping) {
        let held = smoother.value
        self.mapping = mapping
        var next = FeatureSmoother(attack: mapping.attack, release: mapping.release)
        // From 0 a step to `held` with an elapsed time far beyond any time constant lands exactly on `held`.
        if held > 0 { next.update(target: held, elapsed: 1e9) }
        smoother = next
    }
}
