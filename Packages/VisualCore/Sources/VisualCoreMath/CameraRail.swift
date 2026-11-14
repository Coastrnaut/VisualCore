// CameraRail — feature 054 (A07-P01) T-A07-102 (FR-A07-101, FR-A07-104; gap G-CAMERARAIL; research D1, D2, D6).
// A closed centripetal Catmull–Rom rail parameterised by arc length, with a level (horizon-locked) frame.
import Foundation

/// The camera pose on a rail at one travelled distance: position and a right-handed, level orientation frame.
public struct RailPose: Sendable, Equatable {
    /// World position on the rail.
    public let position: Vec3
    /// Unit travel direction (the look direction).
    public let direction: Vec3
    /// Unit right vector, `normalize(direction × (0, 1, 0))`; always horizontal (y = 0).
    public let right: Vec3
    /// Unit up vector, `right × direction`; always has a positive y component.
    public let up: Vec3

    /// Creates a pose from its position and frame vectors (no normalization is applied).
    public init(position: Vec3, direction: Vec3, right: Vec3, up: Vec3) {
        self.position = position
        self.direction = direction
        self.right = right
        self.up = up
    }
}

/// A closed camera rail through control points: a centripetal Catmull–Rom loop (alpha 0.5, no cusps or
/// self-intersections within a span) sampled into an arc-length table, so equal distances are equal lengths.
///
/// The frame is level: right is horizontal and up leans toward world +y, so the horizon never rolls. Tangents within
/// 30° of vertical are refused at construction because the level frame is undefined there.
public struct CameraRail: Sendable, Equatable {
    /// Smallest allowed angle between a sampled tangent and the vertical axis, in radians (30°).
    public static let minimumAngleFromVertical = 30.0 * .pi / 180

    /// The control points the loop passes through, in order (the last joins the first).
    public let controlPoints: [Vec3]
    /// Table samples per span between consecutive control points.
    public let samplesPerSpan: Int
    /// Sampled positions along the loop (`controlPoints.count · samplesPerSpan`, the closing sample omitted).
    private let samples: [Vec3]
    /// Unit tangents at the samples (central differences).
    private let tangents: [Vec3]
    /// Cumulative arc length at each sample; one more entry than `samples`, the last being `length`.
    private let cumulative: [Double]

    /// Builds the rail, or returns nil for fewer than 4 points, a non-finite coordinate, consecutive duplicate points
    /// (the last and first count as consecutive), `samplesPerSpan < 1`, or a sampled tangent within 30° of vertical.
    ///
    /// - Parameters:
    ///   - controlPoints: The points the closed loop passes through.
    ///   - samplesPerSpan: Arc-length table samples per span (default 64).
    public init?(controlPoints: [Vec3], samplesPerSpan: Int = 64) {
        let n = controlPoints.count
        guard n >= 4, samplesPerSpan >= 1, controlPoints.allSatisfy(\.isFinite) else { return nil }
        for i in 0..<n where (controlPoints[(i + 1) % n] - controlPoints[i]).length == 0 { return nil }

        var samples: [Vec3] = []
        samples.reserveCapacity(n * samplesPerSpan)
        for i in 0..<n {
            let p0 = controlPoints[(i + n - 1) % n], p1 = controlPoints[i]
            let p2 = controlPoints[(i + 1) % n], p3 = controlPoints[(i + 2) % n]
            for k in 0..<samplesPerSpan {
                samples.append(Self.centripetal(p0, p1, p2, p3, u: Double(k) / Double(samplesPerSpan)))
            }
        }
        guard samples.allSatisfy(\.isFinite) else { return nil }

        let count = samples.count
        var cumulative = [0.0]
        cumulative.reserveCapacity(count + 1)
        for i in 0..<count {
            let step = (samples[(i + 1) % count] - samples[i]).length
            guard step > 0 else { return nil }
            cumulative.append(cumulative[i] + step)
        }

        let verticalLimit = cos(Self.minimumAngleFromVertical)
        var tangents: [Vec3] = []
        tangents.reserveCapacity(count)
        for i in 0..<count {
            let t = (samples[(i + 1) % count] - samples[(i + count - 1) % count]).normalized
            guard t.length > 0, abs(t.y) < verticalLimit else { return nil }
            tangents.append(t)
        }

        self.controlPoints = controlPoints
        self.samplesPerSpan = samplesPerSpan
        self.samples = samples
        self.tangents = tangents
        self.cumulative = cumulative
    }

    /// Total arc length of the closed loop (of the sampled polyline).
    public var length: Double { cumulative[cumulative.count - 1] }

    /// The pose at `distance` along the rail; the distance wraps modulo `length` (negative values too, a non-finite
    /// value counts as 0). Position and direction are interpolated linearly in the arc-length table.
    ///
    /// - Parameter distance: Travelled distance in world units.
    public func pose(at distance: Double) -> RailPose {
        let d = (try? NumericHygiene.wrapped(distance, modulus: length)) ?? 0
        // Binary search for the last table entry ≤ d.
        var lo = 0, hi = samples.count
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if cumulative[mid] <= d { lo = mid } else { hi = mid }
        }
        let next = (lo + 1) % samples.count
        let span = cumulative[lo + 1] - cumulative[lo]
        let t = min(max((d - cumulative[lo]) / span, 0), 1)
        let position = samples[lo] + (samples[next] - samples[lo]) * t
        var direction = (tangents[lo] + (tangents[next] - tangents[lo]) * t).normalized
        if direction.length == 0 { direction = tangents[lo] }
        let right = direction.cross(Vec3(0, 1, 0)).normalized
        let up = right.cross(direction).normalized
        return RailPose(position: position, direction: direction, right: right, up: up)
    }

    /// The rail pose as an `OrbitCamera`: eye at the pose position, target one unit ahead along the direction
    /// (distance 1), with yaw and pitch derived from the direction so `eye` and the look direction equal the pose.
    ///
    /// - Parameters:
    ///   - distance: Travelled distance (wraps as in ``pose(at:)``).
    ///   - fovY: Vertical field of view in radians.
    ///   - near: Near clipping plane distance.
    ///   - far: Far clipping plane distance.
    public func orbitCamera(at distance: Double, fovY: Double, near: Double, far: Double) -> OrbitCamera {
        let pose = pose(at: distance)
        let back = -pose.direction   // eye − target, as OrbitCamera.eye writes it
        let pitch = asin(min(1, max(-1, back.y)))
        let yaw = atan2(back.x, back.z)
        return OrbitCamera(target: pose.position + pose.direction, distance: 1, yaw: yaw, pitch: pitch,
                           fovY: fovY, near: near, far: far)
    }

    /// The smallest radius of curvature over the table: 1 ÷ the largest sampled curvature, where curvature is the
    /// angle between the unit tangents of the two neighbours of a sample divided by the arc length between them.
    /// Returns `.infinity` for a rail with no measurable curvature.
    public func minimumTurnRadius() -> Double {
        let count = samples.count
        var maxCurvature = 0.0
        for i in 0..<count {
            let a = tangents[(i + count - 1) % count], b = tangents[(i + 1) % count]
            let angle = acos(min(1, max(-1, a.dot(b))))
            let before = cumulative[i] - cumulative[(i + count - 1) % count]
            let arc = (before > 0 ? before : before + length) + (cumulative[i + 1] - cumulative[i])
            maxCurvature = max(maxCurvature, angle / arc)
        }
        return maxCurvature > 0 ? 1 / maxCurvature : .infinity
    }

    /// Barry–Goldman evaluation of the centripetal Catmull–Rom span p1 → p2 at `u` in [0, 1).
    private static func centripetal(_ p0: Vec3, _ p1: Vec3, _ p2: Vec3, _ p3: Vec3, u: Double) -> Vec3 {
        let t0 = 0.0
        let t1 = t0 + (p1 - p0).length.squareRoot()
        let t2 = t1 + (p2 - p1).length.squareRoot()
        let t3 = t2 + (p3 - p2).length.squareRoot()
        let t = t1 + (t2 - t1) * u
        func lerp(_ a: Vec3, _ b: Vec3, _ ta: Double, _ tb: Double) -> Vec3 {
            a * ((tb - t) / (tb - ta)) + b * ((t - ta) / (tb - ta))
        }
        let a1 = lerp(p0, p1, t0, t1), a2 = lerp(p1, p2, t1, t2), a3 = lerp(p2, p3, t2, t3)
        let b1 = lerp(a1, a2, t0, t2), b2 = lerp(a2, a3, t1, t3)
        return lerp(b1, b2, t1, t2)
    }
}
