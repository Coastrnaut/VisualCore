// CelestialEclipseLabOrbit — feature 464 (R02-G17-04) T-R02G1704-002 (FR-R02G1704-006; SC-R02G1704-004;
// clarification Q4). The player's view of the sky: a yaw about the vertical axis through the authored box centre
// (0, −0.25, 0), positive moving the eye from the front (+z) towards +x, within ±60°; and a pitch about the authored
// view's right axis, positive raising the eye, within −20° … +35°; authored (0, 0), the fixed camera of R02-G17-03.
// `CelestialEclipseLabSceneGeometry.camera(_:aspect:orbit:)` builds the camera of an orbit. Presentation only: never
// saved (the snapshot schema stays 1), never read by the rules, never part of the digest. Modelled on feature 454's
// `StarlitCartoucheOrbit`.
import Foundation

/// The player's view of the sky: a yaw about the vertical axis through the authored box centre and a pitch about the
/// authored view's right axis, both in radians (feature 464, R02-G17-04). Presentation only: never saved, never read by
/// the rules.
public struct CelestialEclipseLabOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians about the authored view's right axis: positive raises the eye (the sky seen more from
    /// above), negative lowers it; allowed ``pitchRange`` (−20° … +35°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 0, the fixed camera of R02-G17-03.
    public static let authored = CelestialEclipseLabOrbit(yaw: 0, pitch: 0)
    /// The largest yaw either way, 60° in radians.
    public static let yawLimit: Double = 60.0 * Double.pi / 180
    /// The allowed pitches, −20° … +35° in radians.
    public static let pitchRange: ClosedRange<Double> = (-20.0 * Double.pi / 180)...(35.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −60° … 60° and pitch to −20° … 35°; a non-finite angle becomes 0.
    public func clamped() -> CelestialEclipseLabOrbit {
        let y: Double = yaw.isFinite ? yaw : 0
        let p: Double = pitch.isFinite ? pitch : 0
        return CelestialEclipseLabOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                        pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// Whether this orbit lies within the bounds (finite, yaw within ±``yawLimit``, pitch within ``pitchRange``).
    public var isWithinBounds: Bool {
        yaw.isFinite && pitch.isFinite && abs(yaw) <= Self.yawLimit && Self.pitchRange.contains(pitch)
    }
}
