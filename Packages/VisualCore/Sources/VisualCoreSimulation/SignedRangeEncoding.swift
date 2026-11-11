// SignedRangeEncoding.swift — storing signed values in normalized (0…1) storage (feature 019 T-A02-102; G-CPUFIELD).
// Used when a signed field (velocity, displacement) must fall back to RGBA8 render targets. Feature 020: zero must be
// exactly storable, otherwise a field at rest decodes to a small non-zero value and drifts, so `unorm8(range:)` puts
// zero at 128/255.

/// Maps −range…range to 0…1 with zero at `center`, and back.
public struct SignedRangeEncoding: Sendable, Equatable {
    /// The largest magnitude that can be stored; larger values are clamped.
    public let range: Float
    /// The stored value that means zero (0.5 by default).
    public let center: Float

    /// Nil unless `range` is finite and greater than zero and `center` lies strictly between 0 and 1.
    public init?(range: Float, center: Float = 0.5) {
        guard range.isFinite, range > 0, center.isFinite, center > 0, center < 1 else { return nil }
        self.range = range
        self.center = center
    }

    /// An encoding for 8-bit normalized storage: zero at 128/255, which unorm8 stores exactly.
    public static func unorm8(range: Float) -> SignedRangeEncoding? { SignedRangeEncoding(range: range, center: 128.0 / 255) }

    /// `clamp(v / range · 0.5 + center, 0, 1)`.
    public func encode(_ v: Float) -> Float { min(max(v / range * 0.5 + center, 0), 1) }

    /// `(u − center) · 2 · range`.
    public func decode(_ u: Float) -> Float { (u - center) * 2 * range }
}
