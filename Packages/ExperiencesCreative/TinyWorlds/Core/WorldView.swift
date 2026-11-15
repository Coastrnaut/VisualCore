// WorldView — feature 089 (A12-P01) T-A12-103 (FR-A12-120, FR-A12-121; clarification 4; research D4; data-model
// "WorldView"). The orbit view around the world centre: yaw (radians, wrapped into −π…π), pitch (radians, clamped to
// 10°…75°, so the eye never goes below the ground plane) and distance (metres, clamped to 10…30, so the eye stays
// outside the 12 m world, whose half-diagonal is 8.49 m, and at the lowest pitch 1.74 m above the centre plane, above
// every preset's highest point of 1.6 m).
//
// `orbit(yawDegrees:pitchDegrees:)` turns by each step (each −180…180 degrees), wrapping yaw and clamping pitch;
// `zoom(_:)` divides the distance by a factor in 0.5…2 (2 moves in, 0.5 moves out) and clamps it; `reset()` restores
// the default view (yaw 45°, pitch 35°, distance 18 m). A non-finite or out-of-range step or factor is refused: the
// call returns false and nothing changes. Decoding refuses a yaw outside −π…π or a pitch or distance outside its range
// (and anything non-finite), so a decoded view is always valid.
//
// Feature 092 (A12-P04) T-A12-402 (FR-A12-403; clarification Q3; research D2; data-model "WorldPack"): camera limits
// per preset. `CameraLimits` holds a pitch range and a distance range inside the global ones above
// (`CameraLimits.global` is exactly 10°…75° and 10…30 m); `clamped(to:)` clamps a view's pitch and distance into
// them (yaw unchanged), and `orbit(yawDegrees:pitchDegrees:limits:)` and `zoom(_:limits:)` step within them. Each
// preset's limits are its pack's (`CameraPolicy.limits(for:)`); restored views are clamped to them by the camera
// policy, never refused for them.
import Foundation

/// A pitch range and a distance range for the orbit view, always inside ``WorldView``'s global limits.
public struct CameraLimits: Equatable, Sendable {
    /// The global limits: pitch 10°…75°, distance 10…30 m (``WorldView/pitchRange``, ``WorldView/distanceRange``).
    public static let global = CameraLimits(pitchDegrees: 10...75, distance: 10...30)

    /// The allowed pitch in radians.
    public let pitch: ClosedRange<Double>
    /// The allowed distance in metres.
    public let distance: ClosedRange<Double>

    /// Limits of `pitchDegrees` (converted as degrees × ``WorldView/radiansPerDegree``) and `distance` (metres), each
    /// bound clamped into the global range; a non-finite bound takes the global bound.
    public init(pitchDegrees: ClosedRange<Double>, distance: ClosedRange<Double>) {
        func bounded(_ value: Double, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            value.isFinite ? WorldView.clamp(value, range) : fallback
        }
        let low = bounded(pitchDegrees.lowerBound * WorldView.radiansPerDegree, WorldView.pitchRange.lowerBound,
                          WorldView.pitchRange)
        let high = bounded(pitchDegrees.upperBound * WorldView.radiansPerDegree, WorldView.pitchRange.upperBound,
                           WorldView.pitchRange)
        pitch = low...max(low, high)
        let near = bounded(distance.lowerBound, WorldView.distanceRange.lowerBound, WorldView.distanceRange)
        let far = bounded(distance.upperBound, WorldView.distanceRange.upperBound, WorldView.distanceRange)
        self.distance = near...max(near, far)
    }

    /// The pitch range in degrees.
    public var pitchDegrees: ClosedRange<Double> {
        (pitch.lowerBound / WorldView.radiansPerDegree)...(pitch.upperBound / WorldView.radiansPerDegree)
    }

    /// True when these limits lie inside the global ones.
    public var isInsideGlobal: Bool {
        Self.global.pitch.lowerBound <= pitch.lowerBound && pitch.upperBound <= Self.global.pitch.upperBound
            && Self.global.distance.lowerBound <= distance.lowerBound
            && distance.upperBound <= Self.global.distance.upperBound
    }

    /// True when `view` is valid and its pitch and distance lie within these limits.
    public func contains(_ view: WorldView) -> Bool {
        view.isValid && pitch.contains(view.pitch) && distance.contains(view.distance)
    }
}

/// The orbit view of a world (yaw, pitch, distance), always within its limits.
public struct WorldView: Codable, Equatable, Sendable {
    /// Radians per degree.
    public static let radiansPerDegree = Double.pi / 180
    /// The allowed pitch in radians (10°…75°).
    public static let pitchRange: ClosedRange<Double> = (10 * radiansPerDegree)...(75 * radiansPerDegree)
    /// The allowed distance from the world centre in metres.
    public static let distanceRange: ClosedRange<Double> = 10...30
    /// The allowed orbit step in degrees, for yaw and for pitch.
    public static let orbitStepRange: ClosedRange<Double> = -180...180
    /// The allowed zoom factor.
    public static let zoomRange: ClosedRange<Double> = 0.5...2
    /// The default view: yaw 45°, pitch 35°, distance 18 m.
    public static let `default` = WorldView(yaw: 45 * radiansPerDegree, pitch: 35 * radiansPerDegree, distance: 18)

    /// Yaw in radians, −π…π.
    public private(set) var yaw: Double
    /// Pitch in radians, within ``pitchRange``.
    public private(set) var pitch: Double
    /// Distance from the world centre in metres, within ``distanceRange``.
    public private(set) var distance: Double

    /// A view with yaw wrapped into −π…π, pitch and distance clamped into their ranges; a non-finite component takes
    /// the default view's value.
    public init(yaw: Double, pitch: Double, distance: Double) {
        self.yaw = yaw.isFinite ? Self.wrap(yaw) : 45 * Self.radiansPerDegree
        self.pitch = pitch.isFinite ? Self.clamp(pitch, Self.pitchRange) : 35 * Self.radiansPerDegree
        self.distance = distance.isFinite ? Self.clamp(distance, Self.distanceRange) : 18
    }

    /// Yaw in degrees (−180…180).
    public var yawDegrees: Double { yaw / Self.radiansPerDegree }
    /// Pitch in degrees (10…75).
    public var pitchDegrees: Double { pitch / Self.radiansPerDegree }

    /// True when yaw is in −π…π and pitch and distance are in their ranges.
    public var isValid: Bool {
        yaw.isFinite && yaw >= -Double.pi && yaw <= Double.pi && Self.pitchRange.contains(pitch)
            && Self.distanceRange.contains(distance)
    }

    /// Turns the view by `yawDegrees` and tilts it by `pitchDegrees` (each −180…180); false, with nothing changed,
    /// when a step is non-finite or out of range.
    @discardableResult
    public mutating func orbit(yawDegrees: Double, pitchDegrees: Double) -> Bool {
        guard Self.orbitStepRange.contains(yawDegrees), Self.orbitStepRange.contains(pitchDegrees) else { return false }
        yaw = Self.wrap(yaw + yawDegrees * Self.radiansPerDegree)
        pitch = Self.clamp(pitch + pitchDegrees * Self.radiansPerDegree, Self.pitchRange)
        return true
    }

    /// Divides the distance by `factor` (0.5…2) and clamps it; false, with nothing changed, when the factor is
    /// non-finite or out of range.
    @discardableResult
    public mutating func zoom(_ factor: Double) -> Bool {
        guard Self.zoomRange.contains(factor) else { return false }
        distance = Self.clamp(distance / factor, Self.distanceRange)
        return true
    }

    /// Restores the default view.
    public mutating func reset() { self = .default }

    /// This view with its pitch and distance clamped into `limits` (yaw unchanged).
    public func clamped(to limits: CameraLimits) -> WorldView {
        WorldView(yaw: yaw, pitch: Self.clamp(pitch, limits.pitch), distance: Self.clamp(distance, limits.distance))
    }

    /// ``orbit(yawDegrees:pitchDegrees:)`` with the pitch then clamped into `limits` (the distance too, so the result
    /// lies within them); false, with nothing changed, when a step is refused.
    @discardableResult
    public mutating func orbit(yawDegrees: Double, pitchDegrees: Double, limits: CameraLimits) -> Bool {
        var next = self
        guard next.orbit(yawDegrees: yawDegrees, pitchDegrees: pitchDegrees) else { return false }
        self = next.clamped(to: limits)
        return true
    }

    /// ``zoom(_:)`` with the distance then clamped into `limits` (the pitch too); false, with nothing changed, when
    /// the factor is refused.
    @discardableResult
    public mutating func zoom(_ factor: Double, limits: CameraLimits) -> Bool {
        var next = self
        guard next.zoom(factor) else { return false }
        self = next.clamped(to: limits)
        return true
    }

    /// `angle` wrapped into −π…π (IEEE remainder, exact).
    static func wrap(_ angle: Double) -> Double {
        let wrapped = angle.remainder(dividingBy: 2 * Double.pi)
        return min(max(wrapped, -Double.pi), Double.pi)
    }

    /// `value` clamped into `range`.
    static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private enum CodingKeys: String, CodingKey { case yaw, pitch, distance }

    /// Decodes `{"distance", "pitch", "yaw"}`, refusing a component that is non-finite or outside its range.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        yaw = try c.decode(Double.self, forKey: .yaw)
        pitch = try c.decode(Double.self, forKey: .pitch)
        distance = try c.decode(Double.self, forKey: .distance)
        guard isValid else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                                                    debugDescription: "view outside its limits"))
        }
    }

    /// Encodes `{"distance", "pitch", "yaw"}`.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(distance, forKey: .distance)
        try c.encode(pitch, forKey: .pitch)
        try c.encode(yaw, forKey: .yaw)
    }
}
