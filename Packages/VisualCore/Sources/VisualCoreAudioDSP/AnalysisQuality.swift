// AnalysisQuality — feature 051 (A06-P05) T-A06-502; gap G-AUDIOBUDGET (FR-A06-501; SC-A06-501, SC-A06-502; contract
// specs/051-ml-p05-performance-accessibility/contracts/api.md). Maps the host's quality tier (clarification 1) to an
// analysis configuration: level 0 → 1,024 samples / 16 bands, level 1 → 512 / 16, level 2 → 256 / 8; levels outside
// 0…2 clamp to the nearest level.
import Foundation

/// Analysis quality levels: each level selects a window size and band count for a ``FeatureExtractor``.
///
/// Level 0 is the most detailed (and most costly); higher levels analyse shorter windows with fewer bands.
public enum AnalysisQuality {
    /// The valid quality levels (0…2); other levels clamp to the nearest bound.
    public static let levels: ClosedRange<Int> = 0...2

    /// The analysis configuration for `level`, clamped to ``levels``.
    /// - Parameter level: the quality level; −1 reads as 0 and 5 reads as 2.
    /// - Returns: the window size in samples and the band count: (1,024, 16), (512, 16) or (256, 8).
    public static func configuration(level: Int) -> (size: Int, bandCount: Int) {
        switch min(max(level, levels.lowerBound), levels.upperBound) {
        case 0: return (size: 1_024, bandCount: 16)
        case 1: return (size: 512, bandCount: 16)
        default: return (size: 256, bandCount: 8)
        }
    }

    /// Creates a feature extractor for the configuration of `level` (clamped) at `sampleRate`, or `nil` when the
    /// sample rate is invalid (see ``FeatureExtractor/init(size:sampleRate:bandCount:)``).
    public static func makeExtractor(level: Int, sampleRate: Double) -> FeatureExtractor? {
        let config = configuration(level: level)
        return FeatureExtractor(size: config.size, sampleRate: sampleRate, bandCount: config.bandCount)
    }
}
