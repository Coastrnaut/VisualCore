// AudioFeatureKind — feature 049 (A06-P03) T-A06-302; gap G-AUDIOMAP (FR-A06-301, FR-A06-302; SC-A06-301; research D2;
// data-model "AudioFeatureKind"; contract specs/049-ml-p03-scenes-mapping/contracts/api.md). The seven features a
// mapping can follow and their normalisation to 0…1: level and peak by dBFS over −60…0, each frequency region by the dB
// of the summed energy of its four bands over −80…0, beat energy as is.
import Foundation

/// A feature of ``AudioFeatures`` that an ``AudioMapping`` can follow.
///
/// The case order is the action index 0…6 (`level`, `peak`, `beat`, `low`, `lowMid`, `highMid`, `high`); the raw
/// value is the persisted string.
public enum AudioFeatureKind: String, Codable, Sendable, CaseIterable {
    /// The RMS level of the window (``AudioFeatures/rmsDB``).
    case level
    /// The peak sample of the window (``AudioFeatures/peakDB``).
    case peak
    /// The smoothed onset pulse (``AudioFeatures/beatEnergy``).
    case beat
    /// The summed energy of bands 0–3.
    case low
    /// The summed energy of bands 4–7.
    case lowMid
    /// The summed energy of bands 8–11.
    case highMid
    /// The summed energy of bands 12–15.
    case high

    /// The dBFS window over which ``level`` and ``peak`` are normalised: −60 dBFS reads 0, 0 dBFS reads 1.
    public static let levelWindowDB: ClosedRange<Float> = -60...0
    /// The dB window over which a frequency region is normalised: −80 dB reads 0, 0 dB reads 1.
    public static let regionWindowDB: ClosedRange<Float> = -80...0
    /// Number of bands summed per frequency region.
    public static let bandsPerRegion = 4

    /// The kind at action index `index` (0…6), or `nil` outside that range.
    public static func from(index: Int) -> AudioFeatureKind? {
        let all = allCases
        guard index >= 0, index < all.count else { return nil }
        return all[index]
    }

    /// The action index of this kind (0…6, the case order).
    public var index: Int {
        switch self {
        case .level: return 0
        case .peak: return 1
        case .beat: return 2
        case .low: return 3
        case .lowMid: return 4
        case .highMid: return 5
        case .high: return 6
        }
    }

    /// The feature normalised to 0…1.
    ///
    /// Level and peak are mapped linearly from ``levelWindowDB``; a region sums the linear energies of its four bands
    /// (bands beyond `features.bandEnergies.count` read 0), takes 10·log10 floored at ``LevelMeter/floorDB`` and maps
    /// it linearly from ``regionWindowDB``; beat energy is clamped to 0…1. Values below a window read 0, above read 1,
    /// and non-finite results read 0.
    public func normalized(_ features: AudioFeatures) -> Float {
        let result: Float
        switch self {
        case .level:
            result = Self.window(features.rmsDB, Self.levelWindowDB)
        case .peak:
            result = Self.window(features.peakDB, Self.levelWindowDB)
        case .beat:
            result = features.beatEnergy
        case .low, .lowMid, .highMid, .high:
            result = Self.window(Self.regionDB(features, first: (index - 3) * Self.bandsPerRegion), Self.regionWindowDB)
        }
        guard result.isFinite else { return 0 }
        return min(max(result, 0), 1)
    }

    /// 10·log10 of the summed linear energy of bands `first ..< first + bandsPerRegion`, floored at the meter floor.
    private static func regionDB(_ features: AudioFeatures, first: Int) -> Float {
        var sum: Float = 0
        let energies = features.bandEnergies
        for band in first..<(first + bandsPerRegion) where band < energies.count {
            let energy = energies[band]
            if energy.isFinite, energy > 0 { sum += energy }
        }
        guard sum > 0, sum.isFinite else { return LevelMeter.floorDB }
        return max(LevelMeter.floorDB, 10 * log10(sum))
    }

    /// `value` mapped linearly from `window` to 0…1 (unclamped; the caller clamps).
    private static func window(_ value: Float, _ window: ClosedRange<Float>) -> Float {
        (value - window.lowerBound) / (window.upperBound - window.lowerBound)
    }
}
