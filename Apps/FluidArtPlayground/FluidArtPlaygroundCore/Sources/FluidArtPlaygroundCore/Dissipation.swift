// Dissipation.swift — how dye and velocity fade (feature 019 T-A02-109; FR-A02-102, FR-A02-104; research R1, R2).
// The CPU reference for the GPU dissipation pass: every step multiplies by 1 / (1 + d·Δt) and then rounds to the
// storage precision, exactly as the GPU stores its result.
import VisualCoreSimulation

/// The dissipation rule and its CPU reference.
public enum Dissipation {
    /// The per-step multiplier `1 / (1 + d·dt)` for dissipation `d` (per second) and step `dt` (seconds).
    public static func factor(d: Double, dt: Double) -> Float { Float(1 / (1 + d * dt)) }

    /// One step on `grid`: each value in `channels` (default: all) is multiplied by `factor(d:dt:)` and rounded to
    /// `precision`. With `encoding`, values are stored encoded (RGBA8 velocity): they are decoded, scaled and
    /// re-encoded, so zero stays at zero.
    public static func step(_ grid: inout FieldGrid, d: Double, dt: Double, precision: StoragePrecision,
                            encoding: SignedRangeEncoding? = nil, channels: Range<Int>? = nil) {
        let f = factor(d: d, dt: dt)
        let selected = channels ?? 0..<grid.channels
        for i in grid.values.indices where selected.contains(i % grid.channels) {
            let v = grid.values[i]
            let next = encoding.map { $0.encode($0.decode(v) * f) } ?? v * f
            grid.values[i] = precision.round(next)
        }
    }
}
