// HueCompassDial — feature 334 (R02-G04-04) T-R02G0404-002 (FR-R02G0404-001, 002; SC-R02G0404-001; clarifications
// Q1, Q2). The pure screen geometry of the swipe dial: the compass centre projected through the drawn camera, the hub
// disc (0.3 world units about the centre, never smaller than 30 points), the swipe angle about the centre in screen
// terms (atan2(−dy, dx), counter-clockwise on screen is counter-clockwise on the compass; nil inside the 20-point dead
// zone), the accumulation of angle changes across the ±π seam, and the conversion of an angle to whole bearings and its
// wrapping into −47 … 48. View coordinates are points with the origin at the top left and y down. Presentation only:
// nothing here enters the digest, the snapshot or the kernel.
import Foundation

/// The swipe dial of Hue Compass: pure functions of the camera, the view size and touch points.
public enum HueCompassDial {
    /// The dead zone about the projected centre, 20 points: a touch closer than this has no angle.
    public static let deadZone: Double = 20
    /// The tap distance, 10 points: a touch that ends within this distance of where it began is a tap.
    public static let tapDistance: Double = 10
    /// The smallest hub radius, 30 points.
    public static let minimumHubRadius: Double = 30
    /// The hub's radius in world units about the compass centre, 0.3.
    public static let hubWorldRadius: Double = 0.3
    /// The bearings of one turn, 96.
    static let bearings: Int = HueCompassWheel.bearings
    /// The directions in the compass plane at which the hub's rim is sampled, 16.
    static let hubSamples: Int = 16

    /// The compass centre (the world origin) projected through `camera` into a view of `size` points: in points, origin
    /// top left, y down. Nil when `size` is not positive and finite on both axes or the projection fails.
    public static func centre(camera: HueCompassCamera, size: SIMD2<Double>) -> SIMD2<Double>? {
        point(.zero, camera: camera, size: size)
    }

    /// The radius in points of the hub about ``centre(camera:size:)``: the largest distance from the projected centre to
    /// the projected rim of the disc of ``hubWorldRadius`` about the origin in the compass plane, sampled at 16
    /// directions (every 22.5°; within 2 % of the exact largest distance of the projected ellipse), and never less than
    /// ``minimumHubRadius``. ``minimumHubRadius`` when the projection fails.
    public static func hubRadius(camera: HueCompassCamera, size: SIMD2<Double>) -> Double {
        guard let c = centre(camera: camera, size: size) else { return minimumHubRadius }
        var radius: Double = minimumHubRadius
        for k in 0..<hubSamples {
            let a: Double = 2 * Double.pi * Double(k) / Double(hubSamples)
            let rim: SIMD3<Double> = SIMD3(cos(a), sin(a), 0) * hubWorldRadius
            guard let p = point(rim, camera: camera, size: size) else { continue }
            let d: SIMD2<Double> = p - c
            radius = max(radius, (d.x * d.x + d.y * d.y).squareRoot())
        }
        return radius
    }

    /// The angle of `point` about `centre` in radians, −π … π with −π excluded, in screen-up terms: atan2(−dy, dx) with (dx, dy) =
    /// point − centre and screen y down, so a point to the right is 0, one above is +π/2 and counter-clockwise on screen
    /// is positive. Nil when the point is closer than ``deadZone`` to the centre (distance < 20; exactly 20 has an
    /// angle) or either input is not finite.
    public static func angle(of point: SIMD2<Double>, centre: SIMD2<Double>) -> Double? {
        let dx: Double = point.x - centre.x
        let dy: Double = point.y - centre.y
        guard dx.isFinite, dy.isFinite, (dx * dx + dy * dy).squareRoot() >= deadZone else { return nil }
        // 0 − dy, not −dy: a point straight left (dy = 0) gives +π, never −π (atan2(−0.0, x < 0) is −π).
        return atan2(0 - dy, dx)
    }

    /// The shortest signed change from angle `previous` to angle `current` (radians), in −π … π with −π excluded:
    /// (current − previous) reduced by whole turns, so crossing the ±π seam adds a small change, not a whole turn.
    /// Exactly half a turn counts as +π. 0 when either angle is not finite.
    public static func accumulate(previous: Double, current: Double) -> Double {
        let turn: Double = 2 * Double.pi
        var d: Double = current - previous
        guard d.isFinite else { return 0 }
        d = d.truncatingRemainder(dividingBy: turn)
        if d > Double.pi { d -= turn }
        if d <= -Double.pi { d += turn }
        return d
    }

    /// The whole bearings of an accumulated angle `radians`: round(radians · 96 / 2π), where a half-step rounds away
    /// from zero (Swift's `.toNearestOrAwayFromZero`: +0.5 step → 1, −0.5 step → −1, +1.5 → 2). 0 for a non-finite
    /// angle; the result is held within ±2⁵³ steps so it always converts to `Int`.
    public static func steps(forAngle radians: Double) -> Int {
        let s: Double = (radians * Double(bearings) / (2 * Double.pi)).rounded(.toNearestOrAwayFromZero)
        guard s.isFinite else { return 0 }
        let limit: Double = 9_007_199_254_740_992
        return Int(min(max(s, -limit), limit))
    }

    /// `steps` wrapped into −47 … 48: the representative of `steps` modulo 96 in that range (48 stays 48, −48 becomes
    /// 48, 49 becomes −47, 95 becomes −1, 96 becomes 0).
    public static func wrapped(_ steps: Int) -> Int {
        var r: Int = steps % bearings
        if r < 0 { r += bearings }
        return r > bearings / 2 ? r - bearings : r
    }

    /// `world` projected through `camera` into a view of `size` points (origin top left, y down); nil for an unusable
    /// size or a failed projection.
    static func point(_ world: SIMD3<Double>, camera: HueCompassCamera, size: SIMD2<Double>) -> SIMD2<Double>? {
        guard size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0,
              let v = HueCompassSceneGeometry.project(world, camera: camera) else { return nil }
        return SIMD2(v.x * size.x, v.y * size.y)
    }
}
