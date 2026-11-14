// CameraBounds.swift — feature 041 (A05-P02) T-A05-202 (FR-A05-221; G-ORBITBOUNDS).
// Bounds for the 2D camera (zoom range, square centre extent) and the orbit camera (pitch limit, distance range),
// with bounded pan, zoom and orbit steps. Every step returns a camera inside the bounds, so state built only from
// these steps never holds an out-of-bounds camera. Reset is assigning the preset's default camera.
import Foundation

/// Bounds for a ``Camera2D``: a zoom range and a square of allowed view centres (−extent…extent on both axes).
public struct ViewBounds2D: Sendable, Equatable, Codable {
    /// Allowed zoom magnifications; intersected with ``Camera2D/zoomRange`` when applied
    /// (an empty or non-finite intersection falls back to ``Camera2D/zoomRange``).
    public var zoomRange: ClosedRange<Double>
    /// Half-size of the allowed centre square; a negative or non-finite extent acts as 0.
    public var extent: Double

    /// Creates bounds from a zoom range and the half-size of the allowed centre square.
    public init(zoomRange: ClosedRange<Double>, extent: Double) {
        self.zoomRange = zoomRange
        self.extent = extent
    }

    /// The zoom range actually applied: `zoomRange` ∩ ``Camera2D/zoomRange``.
    var effectiveZoomRange: ClosedRange<Double> {
        let lower = max(zoomRange.lowerBound, Camera2D.zoomRange.lowerBound)
        let upper = min(zoomRange.upperBound, Camera2D.zoomRange.upperBound)
        guard lower.isFinite, upper.isFinite, lower <= upper else { return Camera2D.zoomRange }
        return lower...upper
    }

    /// The centre extent actually applied (finite, ≥ 0).
    var effectiveExtent: Double { extent.isFinite && extent > 0 ? extent : 0 }

    /// Returns `camera` with its zoom clamped into the bounds' zoom range and each centre component clamped into
    /// −extent…extent. A NaN centre component becomes 0 and an infinite one saturates at the bound; a non-finite
    /// rotation becomes 0. Idempotent.
    public func clamp(_ camera: Camera2D) -> Camera2D {
        let range = effectiveZoomRange
        let e = effectiveExtent
        func c(_ v: Double) -> Double { v.isNaN ? min(max(0, -e), e) : min(max(v, -e), e) }
        let z = min(max(camera.zoom, range.lowerBound), range.upperBound)
        return Camera2D(center: Vec2(c(camera.center.x), c(camera.center.y)), zoom: z,
                        rotation: camera.rotation.isFinite ? camera.rotation : 0)
    }
}

extension Camera2D {
    /// Pans by a camera-space `delta` exactly like ``pan(by:)`` (the content follows the finger) and clamps the
    /// result into `bounds`. A non-finite delta returns `self` unchanged.
    public func panned(by delta: Vec2, within bounds: ViewBounds2D) -> Camera2D {
        guard delta.x.isFinite, delta.y.isFinite else { return self }
        var next = self
        next.pan(by: delta)
        return bounds.clamp(next)
    }

    /// Multiplies the zoom by `factor` about the view centre (the centre stays put) and clamps the result into
    /// `bounds`; an overflowing product saturates at the upper zoom bound. A non-finite or non-positive factor
    /// returns `self` unchanged.
    public func zoomed(by factor: Double, within bounds: ViewBounds2D) -> Camera2D {
        guard factor.isFinite, factor > 0 else { return self }
        let range = bounds.effectiveZoomRange
        let product = zoom * factor
        let z = product.isFinite ? product : range.upperBound
        return bounds.clamp(Camera2D(center: center, zoom: min(max(z, range.lowerBound), range.upperBound),
                                     rotation: rotation))
    }
}

/// Bounds for an ``OrbitCamera``: a symmetric pitch limit and a distance range; yaw is free and kept in −π…π.
public struct OrbitBounds: Sendable, Equatable, Codable {
    /// Maximum absolute pitch in radians; the applied limit is `min(|pitchLimit|, OrbitCamera.pitchLimit)`
    /// (non-finite falls back to ``OrbitCamera/pitchLimit``).
    public var pitchLimit: Double
    /// Allowed eye-to-target distances; intersected with ``OrbitCamera/distanceRange`` when applied
    /// (an empty or non-finite intersection falls back to ``OrbitCamera/distanceRange``).
    public var distanceRange: ClosedRange<Double>

    /// Creates bounds from a pitch limit (radians) and a distance range.
    public init(pitchLimit: Double, distanceRange: ClosedRange<Double>) {
        self.pitchLimit = pitchLimit
        self.distanceRange = distanceRange
    }

    /// The pitch limit actually applied (finite, 0…``OrbitCamera/pitchLimit``).
    var effectivePitchLimit: Double {
        pitchLimit.isFinite ? min(abs(pitchLimit), OrbitCamera.pitchLimit) : OrbitCamera.pitchLimit
    }

    /// The distance range actually applied: `distanceRange` ∩ ``OrbitCamera/distanceRange``.
    var effectiveDistanceRange: ClosedRange<Double> {
        let lower = max(distanceRange.lowerBound, OrbitCamera.distanceRange.lowerBound)
        let upper = min(distanceRange.upperBound, OrbitCamera.distanceRange.upperBound)
        guard lower.isFinite, upper.isFinite, lower <= upper else { return OrbitCamera.distanceRange }
        return lower...upper
    }

    /// Wraps an angle into −π…π (non-finite becomes 0); deterministic and idempotent.
    static func wrapYaw(_ yaw: Double) -> Double { yaw.isFinite ? remainder(yaw, 2 * .pi) : 0 }

    /// Returns `camera` with its pitch clamped into ±limit, its distance clamped into the distance range and its
    /// yaw wrapped into −π…π. Target, field of view and clip planes are kept. Idempotent.
    public func clamp(_ camera: OrbitCamera) -> OrbitCamera {
        let limit = effectivePitchLimit
        let range = effectiveDistanceRange
        var out = camera
        out.yaw = Self.wrapYaw(camera.yaw)
        out.pitch = min(max(camera.pitch, -limit), limit)
        out.distance = min(max(camera.distance, range.lowerBound), range.upperBound)
        return out
    }
}

extension OrbitCamera {
    /// Adds the yaw and pitch deltas (radians) and clamps the result into `bounds`. A non-finite delta returns
    /// `self` unchanged.
    public func orbited(yaw: Double, pitch: Double, within bounds: OrbitBounds) -> OrbitCamera {
        guard yaw.isFinite, pitch.isFinite else { return self }
        let limit = bounds.effectivePitchLimit
        var next = self
        next.yaw = OrbitBounds.wrapYaw(self.yaw) + OrbitBounds.wrapYaw(yaw)
        let raw = self.pitch + pitch
        next.pitch = min(max(raw.isFinite ? raw : 0, -limit), limit)
        return bounds.clamp(next)
    }

    /// Divides the distance by `factor` (a zoom-in pinch, factor > 1, moves closer) and clamps the result into
    /// `bounds`; an overflowing quotient saturates at the far bound. A non-finite or non-positive factor returns
    /// `self` unchanged.
    public func zoomed(by factor: Double, within bounds: OrbitBounds) -> OrbitCamera {
        guard factor.isFinite, factor > 0 else { return self }
        let range = bounds.effectiveDistanceRange
        let quotient = distance / factor
        var next = self
        next.distance = min(max(quotient.isFinite ? quotient : range.upperBound, range.lowerBound), range.upperBound)
        return bounds.clamp(next)
    }
}
