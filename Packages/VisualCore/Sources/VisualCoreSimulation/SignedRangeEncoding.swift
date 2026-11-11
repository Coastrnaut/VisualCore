// SignedRangeEncoding.swift — storing signed values in normalized (0…1) storage (feature 019 T-A02-102; G-CPUFIELD).
// Used when a signed field (velocity, displacement) must fall back to RGBA8 render targets.

/// Maps −range…range to 0…1 (zero at 0.5) and back.
public struct SignedRangeEncoding: Sendable, Equatable {
    /// The largest magnitude that can be stored; larger values are clamped.
    public let range: Float

    /// Nil unless `range` is finite and greater than zero.
    public init?(range: Float) {
        guard range.isFinite, range > 0 else { return nil }
        self.range = range
    }

    /// `clamp(v / range · 0.5 + 0.5, 0, 1)`.
    public func encode(_ v: Float) -> Float { min(max(v / range * 0.5 + 0.5, 0), 1) }

    /// `(u − 0.5) · 2 · range`.
    public func decode(_ u: Float) -> Float { (u - 0.5) * 2 * range }
}
