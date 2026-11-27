// MushroomWeatherViewOrbit — feature 494 (R02-G20-04) T-R02G2004-002 (FR-R02G2004-008; SC-R02G2004-004; clarification
// Q4). The player's view of the forest: a yaw about the world's vertical axis (+z, towards the sky) through the centre
// of the box the camera holds and a pitch about the authored view's right axis (+x) through the authored look-at point,
// both in radians; yaw ±60°, pitch −20° … +35°, authored (0, 0). The camera of an orbit is
// `MushroomWeatherSceneGeometry.camera(aspect:orbit:)`. Presentation only: never saved (the snapshot schema stays 1),
// never read by the rules, never part of the digest. Modelled on feature 484's `MicroscopicAuroraViewOrbit`.
import Foundation

/// The player's view of the forest (see the file header). Presentation only.
public struct MushroomWeatherViewOrbit: Sendable, Equatable {
    /// The yaw in radians about +z (counter-clockwise seen from above): positive carries the eye from the front (−y)
    /// towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians about the authored view's right axis (+x): positive raises the eye (the forest seen more
    /// from above), negative lowers it; allowed ``pitchRange`` (−20° … +35°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 0, the fixed camera of R02-G20-03.
    public static let authored: MushroomWeatherViewOrbit = MushroomWeatherViewOrbit(yaw: 0, pitch: 0)
    /// The largest yaw either way, 60° in radians.
    public static let yawLimit: Double = 60.0 * Double.pi / 180
    /// The allowed yaws, −60° … +60° in radians.
    public static let yawRange: ClosedRange<Double> = (-yawLimit)...yawLimit
    /// The allowed pitches, −20° … +35° in radians.
    public static let pitchRange: ClosedRange<Double> = (-20.0 * Double.pi / 180)...(35.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −60° … 60° and pitch to −20° … 35°; a non-finite angle becomes 0.
    public func clamped() -> MushroomWeatherViewOrbit {
        let y: Double = yaw.isFinite ? yaw : 0
        let p: Double = pitch.isFinite ? pitch : 0
        return MushroomWeatherViewOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                        pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// Whether this orbit lies within the bounds (finite, yaw within ±``yawLimit``, pitch within ``pitchRange``).
    public var isWithinBounds: Bool {
        yaw.isFinite && pitch.isFinite && abs(yaw) <= Self.yawLimit && Self.pitchRange.contains(pitch)
    }

    /// The four corners of the bounds (yaw ±60° × pitch −20° and +35°), for tests and checks.
    public static let corners: [MushroomWeatherViewOrbit] = [
        MushroomWeatherViewOrbit(yaw: -yawLimit, pitch: pitchRange.lowerBound),
        MushroomWeatherViewOrbit(yaw: yawLimit, pitch: pitchRange.lowerBound),
        MushroomWeatherViewOrbit(yaw: -yawLimit, pitch: pitchRange.upperBound),
        MushroomWeatherViewOrbit(yaw: yawLimit, pitch: pitchRange.upperBound),
    ]
}
