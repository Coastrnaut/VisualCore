// VoxelOrigamiPicker — feature 444 (R02-G15-04) T-R02G1504-002 (FR-R02G1504-001, 003; SC-R02G1504-001; clarifications
// Q1, Q2). Analytic, deterministic picking of a touch in the drawn Voxel Origami scene and the predicted on-screen
// motion of a hinge's quarter turn. Everything is projected through the drawn camera
// (`VoxelOrigamiSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect width / height) into view points (origin
// top left, x right, y down; the size is the view's size in points), so the allowance is the same number of points at
// every orbit:
//   - a cube's outline is the convex hull of its eight corners — a cube of side 0.9 s (``VoxelOrigamiSceneGeometry/
//     cubeSide`` · s) about w(cells[i]), each corner offset turned by the cube's orientation exactly as the mesh turns
//     it — projected into view points, counter-clockwise as seen on the screen;
//   - a touch hits a cube when it lies inside that outline or within ``VoxelOrigamiPicker/cubeAllowance`` (8) points
//     of it; of several hits the front-most wins: the cube the painter's order
//     (`VoxelOrigamiSceneGeometry.paintOrder(_:camera:)`) draws last (the nearest centre to the eye, then the higher
//     index). The target wireframe, hinge marks, gauges and backdrop are never targets; a touch on cube 0 (the root)
//     picks the root. Unusable input (a non-finite point, a size that is not finite and positive) picks nothing;
//   - the turn prediction of hinge h: the world centre of the tracked cube — of the cubes hinge h swings
//     (`VoxelOrigamiLattice.swinging` at the snapshot's turns), the one farthest from the hinge line, the lowest index
//     on ties (``VoxelOrigamiPicker/trackedCube(_:cubes:pose:moving:)``; a centroid would stay put for a subtree
//     symmetric about the line) — at the current turns, after `+1` and after `−1`
//     (`VoxelOrigamiLattice.turned`, ignoring collisions), each pose from `VoxelOrigamiLattice.pose(_:turns:)` mapped
//     with the drawn snapshot's world mapping (the same centre m and scale s; the box is never recomputed from the
//     turned pose), projected; `plus` and `minus` are the projected centre after the turn minus before. A finger's
//     travel d picks the step whose motion has the larger projection d · û (û its unit direction), once that
//     projection reaches the threshold.
// Presentation only: the picker reads the drawn snapshot and the orbit and never changes the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Voxel Origami scene.
public enum VoxelOrigamiPick: Sendable, Equatable {
    /// Cube `index` (0 is the root, which has no hinge): the front-most cube whose projected outline, grown by
    /// ``VoxelOrigamiPicker/cubeAllowance`` points, holds the touch.
    case cube(Int)
    /// Nothing: unusable input or no cube within reach.
    case empty
}

/// The predicted on-screen motion of a quarter turn of one hinge: where its tracked cube (the swinging cube farthest
/// from the hinge line) moves, in view points, for a `+1` and a `−1` quarter turn.
public struct VoxelOrigamiTurnPrediction: Sendable, Equatable {
    /// The hinge (1 … cubes − 1).
    public let hinge: Int
    /// The motion in view points (x right, y down) of the tracked cube's projected centre for a `+1` quarter turn.
    public let plus: SIMD2<Double>
    /// The motion in view points (x right, y down) of the tracked cube's projected centre for a `−1` quarter turn.
    public let minus: SIMD2<Double>

    /// A prediction of the given values.
    public init(hinge: Int, plus: SIMD2<Double>, minus: SIMD2<Double>) {
        self.hinge = hinge
        self.plus = plus
        self.minus = minus
    }

    /// The step (+1 or −1) a finger's `travel` (view points since touch-down) asks for: the sign whose motion has the
    /// larger projection travel · û (û that motion's unit direction; a tie goes to +1), once that projection reaches
    /// `threshold`. Nil when neither projection reaches it, when either motion is zero or not finite, or when the
    /// travel or the threshold is not finite.
    public func step(for travel: SIMD2<Double>, threshold: Double) -> Int? {
        guard travel.x.isFinite, travel.y.isFinite, threshold.isFinite else { return nil }
        let plusLength: Double = (plus.x * plus.x + plus.y * plus.y).squareRoot()
        let minusLength: Double = (minus.x * minus.x + minus.y * minus.y).squareRoot()
        guard plusLength.isFinite, minusLength.isFinite, plusLength > 0, minusLength > 0 else { return nil }
        let alongPlus: Double = (travel.x * plus.x + travel.y * plus.y) / plusLength
        let alongMinus: Double = (travel.x * minus.x + travel.y * minus.y) / minusLength
        if alongPlus >= alongMinus {
            return alongPlus >= threshold ? 1 : nil
        }
        return alongMinus >= threshold ? -1 : nil
    }
}

/// The analytic picker of the Voxel Origami scene: cubes by their projected outlines, front-most first, and the turn
/// prediction of a hinge, each projected through the drawn camera into view points.
public enum VoxelOrigamiPicker {
    /// How many view points a cube's target reaches beyond its projected outline, 8.
    public static let cubeAllowance: Double = 8

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``VoxelOrigamiSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not finite
    /// or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: VoxelOrigamiCamera) -> SIMD2<Double>? {
        guard usable(size), let v = VoxelOrigamiSceneGeometry.project(point, camera: camera) else { return nil }
        let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The world corners of cube `cube` of `snapshot`: the cube of side ``VoxelOrigamiSceneGeometry/cubeSide`` · s
    /// about w(cells[cube]), each corner offset turned by the cube's orientation as the mesh turns it. Empty for an
    /// index outside the snapshot.
    static func corners(_ cube: Int, snapshot: VoxelOrigamiSceneSnapshot) -> [SIMD3<Double>] {
        typealias G = VoxelOrigamiSceneGeometry
        guard cube >= 0, cube < snapshot.cells.count, cube < snapshot.orientations.count else { return [] }
        let centre: SIMD3<Double> = G.cubeCentre(cube, snapshot)
        let half: Double = G.cubeSide * G.scale(snapshot) / 2
        var result: [SIMD3<Double>] = []
        for index in 0..<8 {
            result.append(centre + G.rotate(snapshot.orientations[cube], G.Parts.cornerOffset(index, half)))
        }
        return result
    }

    /// The outline of cube `cube` in view points (origin top left, y down) of a view of `size` points seen through
    /// `camera`: the convex hull of its eight projected corners (side 0.9 s, turned by its orientation),
    /// counter-clockwise as seen on the screen (a negative shoelace area in the y-down view points), without repeated
    /// or collinear points. Empty for a cube index outside the snapshot, a size that is not finite and positive, or a
    /// corner behind the eye.
    public static func outline(_ cube: Int, size: SIMD2<Double>, snapshot: VoxelOrigamiSceneSnapshot,
                               camera: VoxelOrigamiCamera) -> [SIMD2<Double>] {
        guard usable(size) else { return [] }
        var points: [SIMD2<Double>] = []
        for corner in corners(cube, snapshot: snapshot) {
            guard let p = viewPoint(corner, size: size, camera: camera) else { return [] }
            points.append(p)
        }
        return hull(points)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``VoxelOrigamiPick/cube(_:)`` for the front-most
    /// cube (drawn last in ``VoxelOrigamiSceneGeometry/paintOrder(_:camera:)``) whose projected outline holds the
    /// touch or lies within ``cubeAllowance`` points of it; else ``VoxelOrigamiPick/empty`` (also for a non-finite
    /// point or a size that is not finite and positive). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: VoxelOrigamiSceneSnapshot,
                            orbit: VoxelOrigamiOrbit) -> VoxelOrigamiPick {
        guard point.x.isFinite, point.y.isFinite, usable(size) else { return .empty }
        typealias G = VoxelOrigamiSceneGeometry
        let camera: VoxelOrigamiCamera = G.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
        let order: [VoxelOrigamiElement] = G.paintOrder(snapshot, camera: camera)
        for element in order.reversed() where element.kind == .cube {
            let polygon: [SIMD2<Double>] = outline(element.index, size: size, snapshot: snapshot, camera: camera)
            guard polygon.count >= 3 else { continue }
            if inside(point, polygon) || boundaryDistance(point, polygon) <= cubeAllowance {
                return .cube(element.index)
            }
        }
        return .empty
    }

    /// The turn prediction of hinge `hinge` in a view of `size` points showing `snapshot` from the camera of `orbit`
    /// (clamped) with aspect width / height: the projected world centre of the hinge's tracked cube
    /// (``trackedCube(_:cubes:pose:moving:)``) at the snapshot's turns,
    /// after a `+1` and after a `−1` quarter turn minus before (poses from
    /// `VoxelOrigamiLattice.pose(_:turns:)`, mapped with the snapshot's centre m and scale s; collisions ignored). Nil
    /// for a hinge outside 1 … cubes − 1, a hinge that swings nothing, a size that is not finite and positive, or a
    /// centre behind the eye.
    public static func prediction(_ hinge: Int, size: SIMD2<Double>, snapshot: VoxelOrigamiSceneSnapshot,
                                  orbit: VoxelOrigamiOrbit) -> VoxelOrigamiTurnPrediction? {
        let cubes: [VoxelOrigamiCube] = snapshot.cubes
        guard hinge >= 1, hinge < cubes.count, snapshot.turns.count == cubes.count, usable(size) else { return nil }
        let current: VoxelOrigamiPose = VoxelOrigamiLattice.pose(cubes, turns: snapshot.turns)
        let moving: [Int] = VoxelOrigamiLattice.swinging(cubes, pose: current, hinge: hinge)
        guard !moving.isEmpty else { return nil }
        let middle: SIMD3<Double> = VoxelOrigamiSceneGeometry.middle(snapshot)
        let s: Double = VoxelOrigamiSceneGeometry.scale(snapshot)
        let camera: VoxelOrigamiCamera = VoxelOrigamiSceneGeometry.camera(snapshot, aspect: size.x / size.y,
                                                                          orbit: orbit)
        let tracked: Int = trackedCube(hinge, cubes: cubes, pose: current, moving: moving)
        func centre(_ pose: VoxelOrigamiPose) -> SIMD2<Double>? {
            let c: VoxelOrigamiVector = pose.cells[tracked]
            return viewPoint((SIMD3(Double(c.x), Double(c.y), Double(c.z)) - middle) * s, size: size, camera: camera)
        }
        let plusTurns: [Int] = VoxelOrigamiLattice.turned(snapshot.turns, hinge: hinge, step: 1)
        let minusTurns: [Int] = VoxelOrigamiLattice.turned(snapshot.turns, hinge: hinge, step: -1)
        guard let before = centre(current),
              let afterPlus = centre(VoxelOrigamiLattice.pose(cubes, turns: plusTurns)),
              let afterMinus = centre(VoxelOrigamiLattice.pose(cubes, turns: minusTurns)) else { return nil }
        return VoxelOrigamiTurnPrediction(hinge: hinge, plus: afterPlus - before, minus: afterMinus - before)
    }

    /// The swinging cube a drag on hinge `hinge` follows: of `moving` (the cubes the hinge swings at `pose`), the one
    /// farthest from the hinge line through the parent's and cube `hinge`'s cells, the lowest index on ties. It is
    /// never on the line, so a quarter turn always moves it (the centroid of a subtree symmetric about the line would
    /// not).
    public static func trackedCube(_ hinge: Int, cubes: [VoxelOrigamiCube], pose: VoxelOrigamiPose,
                                   moving: [Int]) -> Int {
        let origin: VoxelOrigamiVector = pose.cells[hinge]
        let d: VoxelOrigamiVector = origin - pose.cells[cubes[hinge].parent ?? 0]
        var best: Int = moving.first ?? hinge
        var bestDistance: Int = -1
        for index in moving {
            let v: VoxelOrigamiVector = pose.cells[index] - origin
            let along: Int = v.x * d.x + v.y * d.y + v.z * d.z
            let squared: Int = v.x * v.x + v.y * v.y + v.z * v.z - along * along
            if squared > bestDistance {
                bestDistance = squared
                best = index
            }
        }
        return best
    }

    // MARK: Internals

    /// The convex hull of `points` (Andrew's monotone chain), counter-clockwise as seen on the y-down screen (negative
    /// shoelace area), without repeated or collinear points; the points themselves when fewer than three are distinct.
    static func hull(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
        let sorted: [SIMD2<Double>] = points.sorted { a, b in a.x != b.x ? a.x < b.x : a.y < b.y }
        guard sorted.count >= 3 else { return sorted }
        func turn(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        // Each chain keeps strict right turns in (x, y): a negative area, counter-clockwise on the y-down screen.
        var lower: [SIMD2<Double>] = []
        for p in sorted {
            while lower.count >= 2, turn(lower[lower.count - 2], lower[lower.count - 1], p) >= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [SIMD2<Double>] = []
        for p in sorted.reversed() {
            while upper.count >= 2, turn(upper[upper.count - 2], upper[upper.count - 1], p) >= 0 { upper.removeLast() }
            upper.append(p)
        }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    /// Whether `point` lies inside or on the convex polygon `polygon` (either winding).
    static func inside(_ point: SIMD2<Double>, _ polygon: [SIMD2<Double>]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var positive: Bool = false
        var negative: Bool = false
        for i in polygon.indices {
            let a: SIMD2<Double> = polygon[i]
            let b: SIMD2<Double> = polygon[(i + 1) % polygon.count]
            let side: Double = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if side > 0 { positive = true }
            if side < 0 { negative = true }
        }
        return !(positive && negative)
    }

    /// The shortest distance from `point` to the edges of the closed polygon `polygon` (infinity when it is empty).
    static func boundaryDistance(_ point: SIMD2<Double>, _ polygon: [SIMD2<Double>]) -> Double {
        var best: Double = Double.infinity
        for i in polygon.indices {
            best = min(best, segmentDistance(point, polygon[i], polygon[(i + 1) % polygon.count]))
        }
        return best
    }

    /// The shortest distance from `point` to the segment from `a` to `b` (to `a` when it has no length).
    static func segmentDistance(_ point: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = b - a
        let lengthSquared: Double = d.x * d.x + d.y * d.y
        guard lengthSquared > 0 else { return distance(point, a) }
        let w: SIMD2<Double> = point - a
        let t: Double = min(max((w.x * d.x + w.y * d.y) / lengthSquared, 0), 1)
        return distance(point, a + d * t)
    }

    /// Whether `size` is finite and positive in both components.
    static func usable(_ size: SIMD2<Double>) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }

    /// The distance between view points `a` and `b`.
    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }
}
