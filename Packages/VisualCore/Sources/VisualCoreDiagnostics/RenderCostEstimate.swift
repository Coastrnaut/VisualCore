// RenderCostEstimate.swift — a relative render-cost estimate: pixels × iterations × samples against a reference
// (feature 029 T-A03-401; gap G-COST; FR-A03-401; research R1). Iteration- or sample-bound shaders (escape-time
// fractals, ray marchers, path tracers, benchmarks) show it before the user commits to a heavy setting. It is a ratio,
// never a time: no device timing is implied.
import Foundation

/// The work of a render as pixels × iterations per pixel × samples per pixel. Non-positive or non-finite factors count
/// as 1.
public struct RenderCostEstimate: Sendable, Equatable {
    /// How heavy a ratio is, by thresholds.
    public enum Level: String, Sendable, CaseIterable {
        case light, moderate, heavy
    }

    /// Pixels drawn.
    public let pixels: Double
    /// Iterations (or steps) per pixel; an upper bound for early-exit loops.
    public let iterations: Double
    /// Samples per pixel.
    public let samples: Double

    /// Creates an estimate; invalid factors count as 1.
    public init(pixels: Double, iterations: Double, samples: Double = 1) {
        func valid(_ v: Double) -> Double { v.isFinite && v > 0 ? v : 1 }
        self.pixels = valid(pixels)
        self.iterations = valid(iterations)
        self.samples = valid(samples)
    }

    /// The total work units (pixels × iterations × samples).
    public var work: Double { pixels * iterations * samples }

    /// This estimate's work divided by `reference`'s.
    public func relative(to reference: RenderCostEstimate) -> Double { work / reference.work }

    /// The level of `ratio`: light up to `lightMax`, moderate up to `moderateMax`, heavy above.
    public static func level(ratio: Double, lightMax: Double = 2, moderateMax: Double = 10) -> Level {
        if ratio <= lightMax { return .light }
        return ratio <= moderateMax ? .moderate : .heavy
    }

    /// `ratio` with two significant digits and "×": "1×", "2.5×", "63×", "1.2e3×" (scientific from 1,000).
    public static func text(ratio: Double) -> String {
        guard ratio.isFinite, ratio > 0 else { return "—" }
        if ratio >= 1000 {
            let e = Int(log10(ratio).rounded(.down))
            var m = ratio / pow(10, Double(e)), exponent = e
            if (m * 10).rounded() / 10 >= 10 { m /= 10; exponent += 1 }
            return String(format: "%.1f", m).replacingOccurrences(of: ".0", with: "") + "e\(exponent)×"
        }
        let digits = ratio >= 10 ? 0 : (ratio >= 1 ? 1 : 2)
        var s = String(format: "%.\(digits)f", ratio)
        if s.contains(".") { while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(".") { s.removeLast() } }
        return s + "×"
    }
}
