// CapControl.swift — the iteration-cap control's mapping and the render-cost line (feature 029 T-A03-406; FR-A03-404;
// US1; spec 029 clarification 3). The slider is logarithmic from 50 to 10,000; ÷2 and ×2 buttons step it. The cost
// is VisualCore's relative RenderCostEstimate against cap 200 on the same canvas: a ratio, never a time.
import Foundation
import VisualCoreDiagnostics

/// The iteration-cap control.
public enum CapControl {
    /// The smallest cap the control offers.
    public static let minimum = 50
    /// The largest cap (FractalMath's limit).
    public static let maximum = 10_000
    /// The reference cap for the cost estimate (the default).
    public static let reference = 200

    /// The cap at slider position `p` ∈ [0, 1]: round(50 · 200^p), clamped to 50…10,000.
    public static func cap(position p: Double) -> Int {
        let t = p.isFinite ? min(max(p, 0), 1) : 0
        return clamp(Int((Double(minimum) * pow(200, t)).rounded()))
    }

    /// The slider position of `cap`: log₂₀₀(cap / 50), clamped to [0, 1].
    public static func position(cap: Int) -> Double {
        min(max(log(Double(clamp(cap)) / Double(minimum)) / log(200), 0), 1)
    }

    /// Half the cap (at least 50).
    public static func halved(_ cap: Int) -> Int { clamp(cap / 2) }
    /// Twice the cap (at most 10,000).
    public static func doubled(_ cap: Int) -> Int { clamp(cap * 2) }

    /// `cap` clamped to 50…10,000.
    public static func clamp(_ cap: Int) -> Int { min(max(cap, minimum), maximum) }

    /// The cost of `cap` on a canvas of `pixels` relative to the reference cap on the same canvas.
    public static func costRatio(cap: Int, pixels: Double) -> Double {
        RenderCostEstimate(pixels: pixels, iterations: Double(cap))
            .relative(to: RenderCostEstimate(pixels: pixels, iterations: Double(reference)))
    }

    /// "Render cost: 2.5× the default view (moderate)", with "; may be slow on this device" when heavy.
    public static func costText(cap: Int, pixels: Double) -> String {
        let ratio = costRatio(cap: cap, pixels: pixels)
        let level = RenderCostEstimate.level(ratio: ratio)
        let base = "Render cost: \(RenderCostEstimate.text(ratio: ratio)) the default view (\(level.rawValue))"
        return level == .heavy ? base + "; may be slow on this device" : base
    }
}
