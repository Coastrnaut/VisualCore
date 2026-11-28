// MyceliumArchitectViewOrbit — feature 514 (R02-G22-04) T-R02G2204-002 (FR-R02G2204-008, 014; SC-R02G2204-003, 004;
// clarification Q5; research R6, R7). The player's view of the cave floor: a yaw about the vertical axis (+z, out of
// the board plane) through the authored look-at point (0, −0.3, 0) and a pitch about the authored view's right axis
// (+x) through the look-at point, both in radians; yaw ±60°, pitch −20° … +35° (feature 504's bounds), authored (0, 0).
// The camera of an orbit is `MyceliumArchitectSceneGeometry.camera(aspect:orbit:)` (``camera(aspect:)``): the authored
// frame turned rigidly by the orbit, the authored field of view for the aspect and the eye moved back along the turned
// view axis until every corner of the authored box (board, gauges, pips and actions bars) lies inside the view with
// `MyceliumArchitectSceneGeometry.refitMargin` (6 %) per side, so the board and gauges keep a margin of at least 5 % at
// every orbit within bounds and every aspect 0.4 … 2.5. Presentation only: never saved (the snapshot schema stays 1),
// never read by the rules, never part of the digest. Modelled on `BinaryGardensViewOrbit` (feature 504).
import Foundation

/// The player's view of the cave floor (see the file header). Presentation only.
public struct MyceliumArchitectViewOrbit: Sendable, Equatable {
    /// The yaw in radians about +z (counter-clockwise seen from above): positive carries the eye from the front (−y)
    /// towards +x; allowed ``yawRange`` (−60° … +60°).
    public let yaw: Double
    /// The pitch in radians about the authored view's right axis (+x): positive raises the eye (the board seen more
    /// from above), negative lowers it; allowed ``pitchRange`` (−20° … +35°).
    public let pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 0, the fixed camera of R02-G22-03.
    public static let authored: MyceliumArchitectViewOrbit = MyceliumArchitectViewOrbit(yaw: 0, pitch: 0)
    /// The largest yaw either way, 60° in radians.
    public static let yawLimit: Double = 60.0 * Double.pi / 180
    /// The allowed yaws, −60° … +60° in radians.
    public static let yawRange: ClosedRange<Double> = (-yawLimit)...yawLimit
    /// The allowed pitches, −20° … +35° in radians.
    public static let pitchRange: ClosedRange<Double> = (-20.0 * Double.pi / 180)...(35.0 * Double.pi / 180)

    /// This orbit with the yaw clamped to ``yawRange`` and the pitch to ``pitchRange``; a non-finite angle becomes 0.
    public func clamped() -> MyceliumArchitectViewOrbit {
        let y: Double = yaw.isFinite ? yaw : 0
        let p: Double = pitch.isFinite ? pitch : 0
        return MyceliumArchitectViewOrbit(yaw: min(max(y, Self.yawRange.lowerBound), Self.yawRange.upperBound),
                                          pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// Whether this orbit lies within the bounds (finite, yaw within ``yawRange``, pitch within ``pitchRange``).
    public var isWithinBounds: Bool {
        yaw.isFinite && pitch.isFinite && Self.yawRange.contains(yaw) && Self.pitchRange.contains(pitch)
    }

    /// Whether this is the authored view (yaw and pitch both 0 after clamping).
    public var isAuthored: Bool {
        let c: MyceliumArchitectViewOrbit = clamped()
        return c.yaw == 0 && c.pitch == 0
    }

    /// The four corners of the bounds (yaw ±60° × pitch −20° and +35°), for tests and checks.
    public static let corners: [MyceliumArchitectViewOrbit] = [
        MyceliumArchitectViewOrbit(yaw: -yawLimit, pitch: pitchRange.lowerBound),
        MyceliumArchitectViewOrbit(yaw: yawLimit, pitch: pitchRange.lowerBound),
        MyceliumArchitectViewOrbit(yaw: -yawLimit, pitch: pitchRange.upperBound),
        MyceliumArchitectViewOrbit(yaw: yawLimit, pitch: pitchRange.upperBound),
    ]

    /// The camera of this orbit (clamped) for `aspect` (width / height; a non-finite or non-positive aspect uses 1):
    /// ``MyceliumArchitectSceneGeometry/camera(aspect:orbit:)``. At the authored orbit it is the fixed camera of
    /// R02-G22-03 (`MyceliumArchitectSceneGeometry.camera(aspect:)`), bit for bit.
    public func camera(aspect: Double) -> MyceliumArchitectCamera {
        MyceliumArchitectSceneGeometry.camera(aspect: aspect, orbit: self)
    }
}
