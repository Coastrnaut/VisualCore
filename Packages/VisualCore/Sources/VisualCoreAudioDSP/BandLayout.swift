// BandLayout — feature 048 (A06-P02) T-A06-202 (FR-A06-202; research D3): log-spaced frequency bands mapped to
// contiguous, non-empty FFT bin ranges. Contract specs/048-ml-p02-feature-analysis/contracts/api.md.
import Foundation

/// Groups the bins 1…N/2−1 of an N-point spectrum into log-spaced frequency bands.
///
/// Band edges are spaced logarithmically from ``lowestFrequency`` to ``highestFrequency``. Bin k (centre k·fs/N)
/// belongs to the band whose [low, high) holds its centre; a band narrower than one bin is widened to take the next
/// unused bin, so every band holds at least one bin and the ranges stay contiguous and strictly increasing.
public struct BandLayout: Sendable, Equatable {
    /// Largest supported number of bands.
    public static let maximumBandCount = 64

    /// Number of bands (1…64).
    public let bandCount: Int
    /// Sample rate fs in Hz.
    public let sampleRate: Double
    /// Transform size N in samples (a ``SpectrumAnalyzer`` size).
    public let size: Int
    /// Lower edge of the first band in Hz.
    public let lowestFrequency: Double
    /// Effective upper edge of the last band in Hz: the lesser of the requested highest frequency and fs/2.
    public let highestFrequency: Double
    /// Bin ranges, one per band: contiguous, strictly increasing, non-empty and within 1…N/2−1.
    public let bins: [Range<Int>]

    /// Creates a layout, or `nil` when the input is invalid.
    ///
    /// Returns `nil` when `bandCount` is outside 1…64, `sampleRate` is not a positive finite number, `size` is not a
    /// power of two in ``SpectrumAnalyzer/minimumSize``…``SpectrumAnalyzer/maximumSize``, `lowestFrequency` is not
    /// positive or not below the effective highest frequency, or there are fewer usable bins than bands.
    /// - Parameters:
    ///   - bandCount: number of bands (default 16).
    ///   - lowestFrequency: lower edge of the first band in Hz (default 40).
    ///   - highestFrequency: requested upper edge of the last band in Hz (default 16,000), capped at fs/2.
    ///   - sampleRate: sample rate fs in Hz.
    ///   - size: transform size N.
    public init?(bandCount: Int = 16, lowestFrequency: Double = 40, highestFrequency: Double = 16_000,
                 sampleRate: Double, size: Int) {
        guard (1...Self.maximumBandCount).contains(bandCount) else { return nil }
        guard sampleRate.isFinite, sampleRate > 0 else { return nil }
        guard size >= SpectrumAnalyzer.minimumSize, size <= SpectrumAnalyzer.maximumSize, size & (size - 1) == 0
        else { return nil }
        guard lowestFrequency.isFinite, highestFrequency.isFinite, lowestFrequency > 0 else { return nil }
        let highest = min(highestFrequency, sampleRate / 2)
        guard lowestFrequency < highest else { return nil }

        let half = size / 2                       // bins 1..<half are usable
        let binWidth = sampleRate / Double(size)
        // First bin whose centre is at or above `frequency`, clamped to 1...half.
        func firstBin(atOrAbove frequency: Double) -> Int {
            let k = (frequency / binWidth).rounded(.up)
            guard k.isFinite else { return half }
            return min(half, max(1, Int(k)))
        }

        let ratio = highest / lowestFrequency
        var ranges: [Range<Int>] = []
        ranges.reserveCapacity(bandCount)
        var start = firstBin(atOrAbove: lowestFrequency)
        for b in 0..<bandCount {
            let upperEdge = b == bandCount - 1
                ? highest
                : lowestFrequency * pow(ratio, Double(b + 1) / Double(bandCount))
            let end = max(firstBin(atOrAbove: upperEdge), start + 1)
            guard end <= half else { return nil }
            ranges.append(start..<end)
            start = end
        }

        self.bandCount = bandCount
        self.sampleRate = sampleRate
        self.size = size
        self.lowestFrequency = lowestFrequency
        self.highestFrequency = highest
        self.bins = ranges
    }
}
