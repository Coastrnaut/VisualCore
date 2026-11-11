// FractalMath.swift — the escape-time iteration z ← z² + c in Double, the CPU reference for the Phase 02 shaders
// (feature 026 T-A03-102; gap G-FRACTAL; FR-A03-102, FR-A03-103; clarification 1). Fractal-specific content stays in
// the app (constitution A03); the plane viewport is VisualCoreMath.PlaneViewport.
import Foundation
import VisualCoreMath

/// The result of iterating one point.
public struct EscapeResult: Sendable, Equatable {
    /// The step n (1…cap) after which |zₙ|² > R², or `cap` for interior points, or 0 for invalid input.
    public let count: Int
    /// The smooth escape value n + 1 − log₂(log|zₙ|) for escaping points; 0 otherwise.
    public let smooth: Double
    /// True when the point stayed bounded for the whole cap.
    public let interior: Bool
}

/// Escape-time iteration for the Mandelbrot and Julia sets.
public enum FractalMath {
    /// Allowed iteration caps (values outside are clamped).
    public static let capRange = 1...10_000
    /// The smallest escape radius (smaller values are raised to it).
    public static let minimumRadius = 2.0

    /// Iterates z ← z² + c from `z0`. Escapes when |z|² > R² after step n (count n). A non-finite `z0` or `c` escapes at
    /// step 0 with smooth value 0, so no NaN is ever produced.
    public static func escape(z0: Vec2, c: Vec2, cap: Int, radius: Double) -> EscapeResult {
        let cap = min(max(cap, capRange.lowerBound), capRange.upperBound)
        let r = radius.isFinite ? max(radius, minimumRadius) : minimumRadius
        guard z0.isFinite, c.isFinite else { return EscapeResult(count: 0, smooth: 0, interior: false) }
        let r2 = r * r
        var x = z0.x, y = z0.y
        for n in 1...cap {
            let nx = x * x - y * y + c.x
            y = 2 * x * y + c.y
            x = nx
            let m2 = x * x + y * y
            if m2 > r2 {
                let logModulus = 0.5 * log(m2)
                let smooth = Double(n) + 1 - log2(logModulus)
                return EscapeResult(count: n, smooth: smooth.isFinite ? smooth : Double(n), interior: false)
            }
        }
        return EscapeResult(count: cap, smooth: 0, interior: true)
    }

    /// The Mandelbrot iteration for the point `c` (z₀ = 0).
    public static func mandelbrot(_ c: Vec2, cap: Int, radius: Double) -> EscapeResult {
        escape(z0: .zero, c: c, cap: cap, radius: radius)
    }

    /// The Julia iteration for the point `z` with seed `seed` (c = seed).
    public static func julia(_ z: Vec2, seed: Vec2, cap: Int, radius: Double) -> EscapeResult {
        escape(z0: z, c: seed, cap: cap, radius: radius)
    }
}
