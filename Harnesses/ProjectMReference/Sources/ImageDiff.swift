// ImageDiff.swift — pairwise RGBA8 image comparison for the A/B baseline (feature 008 T-F703; FR-F705, SC-F702).
enum ImageDiff {
    struct Result: Equatable, CustomStringConvertible {
        /// Mean absolute difference over R, G and B (0…255).
        var meanAbs: Double
        /// Fraction of pixels whose R, G and B each differ by at most 8.
        var within8: Double
        /// Strict absolute form (mean ≤ 2 and ≥ 99% within 8) — used where no engine noise is involved.
        var passes: Bool { meanAbs <= 2 && within8 >= 0.99 }
        /// SC-F702 (amended 2026-11-10): mean ≤ 2 and within-8 no worse than the engine's own noise floor − 1 pp, ≥ 95%.
        func passes(noiseFloorWithin8 floor: Double) -> Bool { meanAbs <= 2 && within8 >= max(0.95, floor - 0.01) }
        var description: String { String(format: "meanAbs=%.3f within8=%.4f", meanAbs, within8) }
    }

    /// Compares two equally sized RGBA8 buffers; nil when sizes differ or are empty.
    static func compare(_ a: [UInt8], _ b: [UInt8]) -> Result? {
        guard a.count == b.count, !a.isEmpty, a.count % 4 == 0 else { return nil }
        var sum = 0, close = 0
        let pixels = a.count / 4
        for p in 0..<pixels {
            let i = p * 4
            let dr = abs(Int(a[i]) - Int(b[i])), dg = abs(Int(a[i + 1]) - Int(b[i + 1])), db = abs(Int(a[i + 2]) - Int(b[i + 2]))
            sum += dr + dg + db
            if dr <= 8 && dg <= 8 && db <= 8 { close += 1 }
        }
        return Result(meanAbs: Double(sum) / Double(pixels * 3), within8: Double(close) / Double(pixels))
    }

    /// Fraction of pixels with any channel above `threshold` (non-black content).
    static func litFraction(_ p: [UInt8], threshold: UInt8 = 8) -> Double {
        guard !p.isEmpty else { return 0 }
        var lit = 0
        for i in stride(from: 0, to: p.count, by: 4) where p[i] > threshold || p[i + 1] > threshold || p[i + 2] > threshold { lit += 1 }
        return Double(lit) / Double(p.count / 4)
    }
}
