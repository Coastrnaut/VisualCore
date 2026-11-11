// ImageComparison.swift — RGBA8 image comparison and statistics for pixel tests (feature 012 T-A01-103; FR-A01-108).
// Test-only (rule R5). Compares RGB channels; alpha is ignored because window and target alpha policies differ.

/// The per-channel difference between two RGBA8 images.
public struct ImageDifference: Sendable, Equatable {
    /// Mean absolute RGB channel difference (0…255); infinite when the images cannot be compared.
    public let meanAbsolute: Double
    /// Largest absolute RGB channel difference (0…255).
    public let maxAbsolute: Int
    let histogram: [Int]
    let channels: Int

    /// Fraction (0…1) of RGB channels whose difference is at most `tolerance`; 0 when the images cannot be compared.
    public func fractionWithin(_ tolerance: Int) -> Double {
        guard channels > 0 else { return 0 }
        return Double(histogram.prefix(max(0, min(tolerance, 255)) + 1).reduce(0, +)) / Double(channels)
    }
}

/// Compares RGBA8 pixel buffers.
public enum ImageComparison {
    /// Differences of `a` and `b` (same length, a multiple of 4). Mismatched or empty buffers give an infinite mean.
    public static func compare(_ a: [UInt8], _ b: [UInt8]) -> ImageDifference {
        guard a.count == b.count, !a.isEmpty, a.count % 4 == 0 else {
            return ImageDifference(meanAbsolute: .infinity, maxAbsolute: 255, histogram: [], channels: 0)
        }
        var histogram = [Int](repeating: 0, count: 256)
        var total = 0, maxDiff = 0
        var i = 0
        while i < a.count {
            for c in 0..<3 {
                let d = abs(Int(a[i + c]) - Int(b[i + c]))
                histogram[d] += 1
                total += d
                maxDiff = max(maxDiff, d)
            }
            i += 4
        }
        let channels = a.count / 4 * 3
        return ImageDifference(meanAbsolute: Double(total) / Double(channels), maxAbsolute: maxDiff, histogram: histogram, channels: channels)
    }
}

/// Simple statistics of an RGBA8 image.
public enum ImageStatistics {
    /// Mean Rec. 709 luma of the sRGB-encoded values, 0…1 (0 for an empty buffer).
    public static func meanLuminance(_ rgba: [UInt8]) -> Double {
        guard rgba.count >= 4 else { return 0 }
        var sum = 0.0
        var i = 0
        while i + 3 < rgba.count {
            sum += 0.2126 * Double(rgba[i]) + 0.7152 * Double(rgba[i + 1]) + 0.0722 * Double(rgba[i + 2])
            i += 4
        }
        return sum / Double(rgba.count / 4) / 255
    }

    /// Number of distinct colors after quantizing each RGB channel to 5 bits.
    public static func distinctColors(_ rgba: [UInt8]) -> Int {
        var seen = Set<Int>()
        var i = 0
        while i + 3 < rgba.count {
            seen.insert(Int(rgba[i] >> 3) << 10 | Int(rgba[i + 1] >> 3) << 5 | Int(rgba[i + 2] >> 3))
            i += 4
        }
        return seen.count
    }
}
