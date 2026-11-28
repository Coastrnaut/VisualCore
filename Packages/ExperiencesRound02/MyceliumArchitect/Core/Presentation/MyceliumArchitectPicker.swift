// MyceliumArchitectPicker — feature 514 (R02-G22-04) T-R02G2204-003 (FR-R02G2204-003, 004, 007, 010; SC-R02G2204-001;
// clarifications Q1, Q2, Q4; research R1, R2, R5, R6). Analytic, deterministic picking of a touch on the drawn Mycelium
// Architect cave floor. Everything is projected through the drawn camera (`MyceliumArchitectViewOrbit.camera(aspect:)`,
// orbit included, with the view's aspect width / height) into view points (origin top left, x right, y down; the size
// is the view's size in points). A world extent e at a centre c becomes e / (depth · tan(fovY / 2)) · height / 2 view
// points, depth c's distance from the eye along the view axis. Of several hits the target drawn last wins, in the
// reverse of the scene's painter's order (clarification Q1, research R1):
//   1. the actions bars and the terminal pip row are empty space: the finger cast onto the plane z = 0 inside an actions
//      bar's drawn rectangle (bar i centred at `MyceliumArchitectSceneGeometry.actionsBar(i, _)`, 0.8 · 1.9 / budget
//      wide, 0.035 tall) or inside a gauge-row pip's square (half 0.018 at y −1.24);
//   2. the weight gauge: the finger cast onto z = 0 inside the plate rectangle x −0.95 … 0.95, y −1.12 ± 0.045;
//   3. a sprout (later directions first): outside the root's projected cap radius 0.36·s and within
//      ``MyceliumArchitectPicker/allowance`` (12) points of the projected segment from the root's centre to its tip
//      (0.4·s from the root towards the seeded direction, on z = 0) — inside the cap the root wins, so a seed drag
//      starts from the root on a seeded level too (implementation correction of clarification Q1, 2026-11-27);
//   4. the root: within the projected cap radius 0.36·s grown by 12 points of the projected root centre;
//   5. a cell: the finger cast onto z = 0 lies inside the board |x| ≤ W·s / 2, |y − 0.05| ≤ H·s / 2, giving
//      (column, row) = (⌊x / s + W / 2⌋, ⌊H / 2 − (y − 0.05) / s⌋) (the far edges clamped onto the last column or row);
//   6. anything else, and unusable input (a non-finite point, a size that is not finite and positive), is empty space.
// A seed drag's direction is chosen on the board plane (research R5): of the eight directions the one whose board
// vector (dc, −dr) makes the smallest angle with the cast travel (largest cosine; ties to the lower direction number;
// a zero travel gives north). The gauge maps a cast x to the shown pulse clamp(round((x + 0.9) / 1.8 · pulses run), 0,
// pulses run), halves away from zero. The allowance is feature 504's. Presentation only: the picker reads the snapshot
// and the view orbit and never changes the kernel. Modelled on `BinaryGardensPicker` (feature 504).
import Foundation
import VisualCoreMath

/// What a touch picked on the Mycelium Architect cave floor (feature 514, clarification Q1).
public enum MyceliumArchitectPickTarget: Sendable, Hashable {
    /// Nothing: unusable input, the actions bars, the terminal pip row, or outside every target.
    case empty
    /// The weight gauge: the finger cast onto the board plane inside its plate.
    case gauge
    /// The sprout of a seeded direction: within ``MyceliumArchitectPicker/allowance`` of its projected segment.
    case sprout(MyceliumArchitectDirection)
    /// The root cap: its projected radius grown by ``MyceliumArchitectPicker/allowance``.
    case root
    /// A board cell: the finger cast onto the board plane inside the board.
    case cell(MyceliumArchitectCell)
}

/// The analytic picker of the Mycelium Architect cave floor (see the file header).
public enum MyceliumArchitectPicker {
    /// How many view points a target reaches beyond its projected size or segment, 12 (feature 504's).
    public static let allowance: Double = 12

    /// Whether `size` is usable: both components finite and positive.
    static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }

    /// The drawn camera of a view of `viewSize` points from `orbit` (clamped): aspect width / height. Nil for a size
    /// that is not finite and positive.
    public static func camera(viewSize: Vec2, orbit: MyceliumArchitectViewOrbit) -> MyceliumArchitectCamera? {
        guard usable(viewSize) else { return nil }
        return orbit.camera(aspect: viewSize.x / viewSize.y)
    }

    /// World `point` in view points (origin top left, x right, y down) of a view of `viewSize` points seen through
    /// `camera`: ``MyceliumArchitectSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not
    /// finite or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, viewSize: Vec2, camera: MyceliumArchitectCamera) -> Vec2? {
        guard usable(viewSize), let v = MyceliumArchitectSceneGeometry.project(point, camera: camera) else { return nil }
        let p: Vec2 = Vec2(v.x * viewSize.x, v.y * viewSize.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The length in view points of a world extent `extent` at `centre` seen through `camera` in a view of `viewSize`
    /// points: extent / (depth · tan(fovY / 2)) · height / 2, depth the centre's distance along the view axis. Nil when
    /// the centre is not in front of the eye or the size is unusable.
    public static func projectedExtent(_ extent: Double, at centre: SIMD3<Double>, viewSize: Vec2,
                                       camera: MyceliumArchitectCamera) -> Double? {
        typealias G = MyceliumArchitectSceneGeometry
        guard usable(viewSize) else { return nil }
        let forward: SIMD3<Double> = G.viewBasis(camera).forward
        let depth: Double = G.dot(centre - camera.eye, forward)
        let tanHalf: Double = tan(camera.fovY / 2)
        guard depth.isFinite, depth > 0, tanHalf.isFinite, tanHalf > 0 else { return nil }
        let r: Double = extent / (depth * tanHalf) * viewSize.y / 2
        return r.isFinite ? r : nil
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `viewSize` points showing `snapshot`
    /// from the camera of `orbit` (clamped), in the order of the file header: the actions bars and the pip row
    /// (empty), the gauge, the sprouts (later directions first), the root, a cell, else
    /// ``MyceliumArchitectPickTarget/empty`` (also for a non-finite point or a size that is not finite and positive).
    /// Deterministic.
    public static func pick(_ point: Vec2, viewSize: Vec2, snapshot: MyceliumArchitectSceneSnapshot,
                            orbit: MyceliumArchitectViewOrbit) -> MyceliumArchitectPickTarget {
        guard point.x.isFinite, point.y.isFinite, let view = camera(viewSize: viewSize, orbit: orbit) else {
            return .empty
        }
        let plane: Vec2? = cast(point, viewSize: viewSize, orbit: orbit)
        if let c = plane {
            if onEmptyRow(c, snapshot) { return .empty }
            if onGauge(c) { return .gauge }
        }
        let seeds: [MyceliumArchitectDirection] = snapshot.arrangement.seeds
        var index: Int = insideRootCap(point, viewSize: viewSize, snapshot: snapshot, camera: view) ? -1 : seeds.count - 1
        while index >= 0 {
            let direction: MyceliumArchitectDirection = seeds[index]
            index -= 1
            if let gap = sproutDistance(point, direction: direction, viewSize: viewSize, snapshot: snapshot,
                                        camera: view), gap <= allowance {
                return .sprout(direction)
            }
        }
        if hitsRoot(point, viewSize: viewSize, snapshot: snapshot, camera: view) { return .root }
        if let c = plane, let cell = cell(atPlane: c, snapshot: snapshot) { return .cell(cell) }
        return .empty
    }

    /// The point of the plane z = 0 under view point `point` (origin top left, y down) of a view of `viewSize` points
    /// seen from the camera of `orbit` (clamped), in world units (x, y): the ray from the eye through the point cast
    /// onto the plane. Nil for a non-finite point, an unusable size, or a ray that does not meet the plane in front of
    /// the eye.
    public static func cast(_ point: Vec2, viewSize: Vec2, orbit: MyceliumArchitectViewOrbit) -> Vec2? {
        typealias G = MyceliumArchitectSceneGeometry
        guard point.x.isFinite, point.y.isFinite, let view = camera(viewSize: viewSize, orbit: orbit) else { return nil }
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = G.viewBasis(view)
        let tanHalf: Double = tan(view.fovY / 2)
        let x: Double = (2 * point.x / viewSize.x - 1) * tanHalf * view.aspect
        let y: Double = (1 - 2 * point.y / viewSize.y) * tanHalf
        let ray: SIMD3<Double> = basis.forward + basis.right * x + basis.up * y
        guard ray.z.isFinite, ray.z < 0 else { return nil }
        let t: Double = -view.eye.z / ray.z
        guard t.isFinite, t > 0 else { return nil }
        let hit: SIMD3<Double> = view.eye + ray * t
        guard hit.x.isFinite, hit.y.isFinite else { return nil }
        return Vec2(hit.x, hit.y)
    }

    /// The direction of a seed drag from plane point `from` to plane point `to` (research R5): of the eight
    /// directions the one whose board vector (dc, −dr), normalised, has the largest cosine with the travel; ties go to
    /// the lower direction number; a zero or non-finite travel gives north.
    public static func direction(from: Vec2, to: Vec2) -> MyceliumArchitectDirection {
        let dx: Double = to.x - from.x
        let dy: Double = to.y - from.y
        let size: Double = (dx * dx + dy * dy).squareRoot()
        guard size.isFinite, size > 0 else { return .north }
        var best: MyceliumArchitectDirection = .north
        var bestCosine: Double = -Double.infinity
        for direction in MyceliumArchitectDirection.allCases {
            let v: SIMD3<Double> = MyceliumArchitectSceneGeometry.planeDirection(direction)
            let cosine: Double = (v.x * dx + v.y * dy) / size
            if cosine > bestCosine {
                bestCosine = cosine
                best = direction
            }
        }
        return best
    }

    /// The pulse the gauge shows at plane x `x` (clarification Q2): clamp(round((x + 0.9) / 1.8 · pulsesRun), 0,
    /// pulsesRun), halves away from zero; 0 for a non-finite x or pulses run below 1.
    public static func pulse(atPlaneX x: Double, pulsesRun: Int) -> Int {
        guard x.isFinite, pulsesRun > 0 else { return 0 }
        let raw: Double = ((x + 0.9) / 1.8 * Double(pulsesRun)).rounded(.toNearestOrAwayFromZero)
        guard raw.isFinite else { return 0 }
        if raw <= 0 { return 0 }
        if raw >= Double(pulsesRun) { return pulsesRun }
        return Int(raw)
    }

    /// The board cell under plane point `c` of `snapshot`'s level: (⌊x / s + W / 2⌋, ⌊H / 2 − (y − 0.05) / s⌋) when
    /// |x| ≤ W·s / 2 and |y − 0.05| ≤ H·s / 2 (the far edges clamped onto the last column or row); nil outside the
    /// board or for a non-finite point.
    public static func cell(atPlane c: Vec2, snapshot: MyceliumArchitectSceneSnapshot) -> MyceliumArchitectCell? {
        let s: Double = snapshot.fitScale
        let w: Int = snapshot.level.width
        let h: Int = snapshot.level.height
        guard c.x.isFinite, c.y.isFinite, s > 0, w > 0, h > 0 else { return nil }
        let y: Double = c.y - MyceliumArchitectSceneGeometry.boardCentreY
        guard abs(c.x) <= Double(w) * s / 2, abs(y) <= Double(h) * s / 2 else { return nil }
        let column: Int = min(max(Int((c.x / s + Double(w) / 2).rounded(.down)), 0), w - 1)
        let row: Int = min(max(Int((Double(h) / 2 - y / s).rounded(.down)), 0), h - 1)
        return MyceliumArchitectCell(column: column, row: row)
    }

    /// Whether plane point `c` lies inside the weight gauge's plate: x −0.95 … 0.95, y −1.12 ± 0.045.
    public static func onGauge(_ c: Vec2) -> Bool {
        typealias G = MyceliumArchitectSceneGeometry
        return c.x >= G.plateLeft && c.x <= G.plateRight && abs(c.y - G.gaugeY) <= G.plateHalf
    }

    /// Whether plane point `c` lies on an actions bar's drawn rectangle or a gauge-row pip's square of `snapshot` (empty
    /// space, clarification Q1).
    static func onEmptyRow(_ c: Vec2, _ snapshot: MyceliumArchitectSceneSnapshot) -> Bool {
        typealias G = MyceliumArchitectSceneGeometry
        let halfWidth: Double = G.barFill * G.actionsSlot(snapshot) / 2
        let halfHeight: Double = G.actionsHeight / 2
        for bar in 0..<max(snapshot.budget, 0) {
            let centre: SIMD3<Double> = G.actionsBar(bar, snapshot)
            if abs(c.x - centre.x) <= halfWidth && abs(c.y - centre.y) <= halfHeight { return true }
        }
        let count: Int = snapshot.level.terminals.count
        for terminal in 0..<count {
            let centre: SIMD3<Double> = G.rowPip(terminal, count: count)
            if abs(c.x - centre.x) <= G.pipHalf && abs(c.y - centre.y) <= G.pipHalf { return true }
        }
        return false
    }

    /// The tip of `direction`'s sprout in `snapshot`: the root's centre + 0.4·s along the direction's board vector.
    public static func sproutTip(_ direction: MyceliumArchitectDirection,
                                 snapshot: MyceliumArchitectSceneSnapshot) -> SIMD3<Double> {
        typealias G = MyceliumArchitectSceneGeometry
        let length: Double = G.sproutLength * snapshot.fitScale
        return G.centre(snapshot.level.root, snapshot) + G.planeDirection(direction) * length
    }

    /// The distance in view points from `point` to `direction`'s projected sprout segment (root centre to tip) seen
    /// through `camera`; nil when an end is behind the eye or the size is unusable.
    static func sproutDistance(_ point: Vec2, direction: MyceliumArchitectDirection, viewSize: Vec2,
                               snapshot: MyceliumArchitectSceneSnapshot, camera: MyceliumArchitectCamera) -> Double? {
        let root: SIMD3<Double> = MyceliumArchitectSceneGeometry.centre(snapshot.level.root, snapshot)
        guard let a = viewPoint(root, viewSize: viewSize, camera: camera),
              let b = viewPoint(sproutTip(direction, snapshot: snapshot), viewSize: viewSize, camera: camera) else {
            return nil
        }
        return segmentDistance(point, a, b)
    }

    /// Whether `point` lies within the root's projected cap radius 0.36·s (no allowance) of its projected centre, seen
    /// through `camera` in a view of `viewSize` points: there the root outranks every sprout.
    static func insideRootCap(_ point: Vec2, viewSize: Vec2, snapshot: MyceliumArchitectSceneSnapshot,
                              camera: MyceliumArchitectCamera) -> Bool {
        typealias G = MyceliumArchitectSceneGeometry
        let centre: SIMD3<Double> = G.centre(snapshot.level.root, snapshot)
        guard let p = viewPoint(centre, viewSize: viewSize, camera: camera),
              let r = projectedExtent(G.rootCapRadius * snapshot.fitScale, at: centre, viewSize: viewSize,
                                      camera: camera) else { return false }
        let dx: Double = point.x - p.x
        let dy: Double = point.y - p.y
        return (dx * dx + dy * dy).squareRoot() < r
    }

    /// Whether `point` lies within the root's projected cap radius 0.36·s grown by ``allowance`` of its projected
    /// centre, seen through `camera` in a view of `viewSize` points (the root's pick disc).
    public static func hitsRoot(_ point: Vec2, viewSize: Vec2, snapshot: MyceliumArchitectSceneSnapshot,
                                camera: MyceliumArchitectCamera) -> Bool {
        typealias G = MyceliumArchitectSceneGeometry
        guard point.x.isFinite, point.y.isFinite else { return false }
        let centre: SIMD3<Double> = G.centre(snapshot.level.root, snapshot)
        guard let p = viewPoint(centre, viewSize: viewSize, camera: camera),
              let r = projectedExtent(G.rootCapRadius * snapshot.fitScale, at: centre, viewSize: viewSize,
                                      camera: camera) else { return false }
        let dx: Double = point.x - p.x
        let dy: Double = point.y - p.y
        return (dx * dx + dy * dy).squareRoot() <= r + allowance
    }

    /// Whether `point` lies in the root's pick disc (``hitsRoot(_:viewSize:snapshot:camera:)``) of a view of
    /// `viewSize` points from `orbit`; false for unusable input.
    public static func hitsRoot(_ point: Vec2, viewSize: Vec2, snapshot: MyceliumArchitectSceneSnapshot,
                                orbit: MyceliumArchitectViewOrbit) -> Bool {
        guard let view = camera(viewSize: viewSize, orbit: orbit) else { return false }
        return hitsRoot(point, viewSize: viewSize, snapshot: snapshot, camera: view)
    }

    /// The distance from `p` to the segment `a` … `b` (to `a` for a segment of length 0).
    static func segmentDistance(_ p: Vec2, _ a: Vec2, _ b: Vec2) -> Double {
        let abx: Double = b.x - a.x
        let aby: Double = b.y - a.y
        let apx: Double = p.x - a.x
        let apy: Double = p.y - a.y
        let size: Double = abx * abx + aby * aby
        var t: Double = 0
        if size > 0 { t = min(max((apx * abx + apy * aby) / size, 0), 1) }
        let dx: Double = apx - abx * t
        let dy: Double = apy - aby * t
        return (dx * dx + dy * dy).squareRoot()
    }
}
