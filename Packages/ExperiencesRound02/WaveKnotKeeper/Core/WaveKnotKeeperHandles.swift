// WaveKnotKeeperHandles — feature 324 (R02-G03-04) T-R02G0304-002 (FR-R02G0304-001, 002; SC-R02G0304-001;
// clarifications Q1, Q3). Every control point of the rope is a pickable handle at its world position (kernel × 1/8).
// A touch picks the handles whose projected centre lies within max(22 points, the handle sphere's projected radius) of
// it; among those the nearest to the eye wins, then the nearest on screen, then the lower index. A drag from a handle
// becomes a move by projecting one lattice step (1/8 world unit) of each of the six directions from the handle with the
// drawn camera: the candidate is the direction whose unit projected step has the largest dot product with the drag
// (ties to the lower index in `WaveKnotKeeperDirection.allCases`), and only when the drag's component along it reaches
// max(6 points, half that projected step); otherwise there is no candidate. Doubles are used for presentation only;
// the kernel checks every move.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// Handle picking and drag-to-direction mapping for Wave Knot Keeper's control points, in screen points of a viewport
/// of `size` (width, height; origin top left, y down) seen through a ``WaveKnotKeeperCamera``.
public enum WaveKnotKeeperHandles {
    /// The minimum touch radius of every handle in screen points, 22 (half the 44-point minimum target; the R02-F22
    /// `HandlePicker.minimumTouchRadius`).
    public static let touchRadius: Double = HandlePicker.minimumTouchRadius
    /// The smallest drag component, in screen points, that can make a candidate, 6.
    public static let minimumSnap: Double = 6
    /// The world length of one lattice step, 1/8 (one kernel unit).
    public static let stepLength: Double = WaveKnotKeeperSceneGeometry.unitsPerKernel

    /// Whether `size` is a usable viewport: finite and positive on both axes.
    static func usable(_ size: SIMD2<Double>) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }

    /// `point` in screen points of a `size` viewport (origin top left, y down); nil behind the camera, outside the
    /// depth range −1 … 1, for non-finite input or an unusable size.
    public static func screen(_ point: SIMD3<Double>, camera: WaveKnotKeeperCamera,
                              size: SIMD2<Double>) -> SIMD2<Double>? {
        guard usable(size), point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let projected = ScreenProjection.project(Vec3(point.x, point.y, point.z),
                                                       viewProjection: camera.viewProjection,
                                                       viewport: Vec2(size.x, size.y)),
              projected.depth >= -1, projected.depth <= 1 else { return nil }
        return SIMD2(projected.point.x, projected.point.y)
    }

    /// The radius in screen points of the handle sphere (``WaveKnotKeeperSceneGeometry/handleRadius``) drawn at world
    /// `point`: handleRadius / (view depth · tan(fovY / 2)) · height / 2; nil when the point is not in front of the
    /// eye, for non-finite input or an unusable size.
    public static func projectedRadius(_ point: SIMD3<Double>, camera: WaveKnotKeeperCamera,
                                       size: SIMD2<Double>) -> Double? {
        guard usable(size), point.x.isFinite, point.y.isFinite, point.z.isFinite else { return nil }
        let axis: SIMD3<Double> = camera.target - camera.eye
        let axisLength: Double = WaveKnotKeeperSceneGeometry.length(axis)
        guard axisLength > 0, axisLength.isFinite else { return nil }
        let depth: Double = WaveKnotKeeperSceneGeometry.dot(point - camera.eye, axis / axisLength)
        guard depth > 1e-9 else { return nil }
        let radius: Double = WaveKnotKeeperSceneGeometry.handleRadius / (depth * tan(camera.fovY / 2)) * size.y / 2
        return radius.isFinite ? radius : nil
    }

    /// The index of the control point a touch at `location` (screen points) picks, or nil on empty space.
    ///
    /// A handle is hit when its projected centre lies within max(``touchRadius``, ``projectedRadius(_:camera:size:)``)
    /// of the touch. Among the hits the handle nearest to the eye (world distance) wins, then the one nearest the touch
    /// on screen, then the lower index. Handles behind the camera or outside the depth range are skipped; a non-finite
    /// location or an unusable size picks nothing.
    public static func pick(_ location: SIMD2<Double>, snapshot: WaveKnotKeeperSceneSnapshot,
                            camera: WaveKnotKeeperCamera, size: SIMD2<Double>) -> Int? {
        guard usable(size), location.x.isFinite, location.y.isFinite else { return nil }
        let points: [SIMD3<Double>] = WaveKnotKeeperSceneGeometry.worldPoints(snapshot)
        var best: (index: Int, eye: Double, screen: Double)? = nil
        for index in points.indices {
            let p: SIMD3<Double> = points[index]
            guard let centre = screen(p, camera: camera, size: size) else { continue }
            let offset: SIMD2<Double> = centre - location
            let screenDistance: Double = (offset.x * offset.x + offset.y * offset.y).squareRoot()
            let reach: Double = max(touchRadius, projectedRadius(p, camera: camera, size: size) ?? 0)
            guard screenDistance <= reach else { continue }
            let eyeDistance: Double = WaveKnotKeeperSceneGeometry.length(p - camera.eye)
            if let current = best {
                let better: Bool = eyeDistance < current.eye
                    || (eyeDistance == current.eye && screenDistance < current.screen)
                guard better else { continue }
            }
            best = (index, eyeDistance, screenDistance)
        }
        return best?.index
    }

    /// The screen vector (points) of one lattice step along `direction` from control point `point`: the projection of
    /// world(point) + offset · 1/8 minus the projection of world(point). Nil for an index outside the rope, when either
    /// end does not project, or for an unusable size.
    public static func projectedStep(point: Int, direction: WaveKnotKeeperDirection,
                                     snapshot: WaveKnotKeeperSceneSnapshot, camera: WaveKnotKeeperCamera,
                                     size: SIMD2<Double>) -> SIMD2<Double>? {
        guard snapshot.points.indices.contains(point) else { return nil }
        let start: SIMD3<Double> = WaveKnotKeeperSceneGeometry.world(snapshot.points[point])
        let o: (x: Int, y: Int, z: Int) = direction.offset
        let end: SIMD3<Double> = start + SIMD3(Double(o.x), Double(o.y), Double(o.z)) * stepLength
        guard let a = screen(start, camera: camera, size: size),
              let b = screen(end, camera: camera, size: size) else { return nil }
        return b - a
    }

    /// The direction a drag of `drag` screen points from control point `point` asks for, or nil.
    ///
    /// For each direction in `WaveKnotKeeperDirection.allCases` with a projected step
    /// (``projectedStep(point:direction:snapshot:camera:size:)``) longer than 10⁻⁹ points, the drag's component along
    /// the step's unit vector is computed; the direction with the largest component wins (ties to the lower index). It
    /// is the candidate only when that component is at least max(``minimumSnap``, half the step's projected length).
    /// A non-finite drag, an invalid point or no projectable step gives nil.
    public static func candidate(point: Int, drag: SIMD2<Double>, snapshot: WaveKnotKeeperSceneSnapshot,
                                 camera: WaveKnotKeeperCamera, size: SIMD2<Double>) -> WaveKnotKeeperDirection? {
        guard drag.x.isFinite, drag.y.isFinite else { return nil }
        var best: (direction: WaveKnotKeeperDirection, component: Double, length: Double)? = nil
        for direction in WaveKnotKeeperDirection.allCases {
            guard let step = projectedStep(point: point, direction: direction, snapshot: snapshot, camera: camera,
                                           size: size) else { continue }
            let length: Double = (step.x * step.x + step.y * step.y).squareRoot()
            guard length > 1e-9, length.isFinite else { continue }
            let component: Double = (step.x * drag.x + step.y * drag.y) / length
            if let current = best, component <= current.component { continue }
            best = (direction, component, length)
        }
        guard let chosen = best, chosen.component >= max(minimumSnap, chosen.length / 2) else { return nil }
        return chosen.direction
    }
}
