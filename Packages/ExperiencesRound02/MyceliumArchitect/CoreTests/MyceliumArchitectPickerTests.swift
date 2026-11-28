// MyceliumArchitectPickerTests — feature 514 (R02-G22-04) T-R02G2204-003 (FR-R02G2204-003, 004, 007, 010;
// SC-R02G2204-001; clarifications Q1, Q2, Q4; research R1, R2, R5, R6). The analytic picker against an independent
// pinhole projection written here (the camera's eye, target, field of view and aspect, with the up direction derived
// from the authored frame turned by the orbit in this file, never the picker's or the geometry's projection code) on
// 500 seeded cases over certified levels with and without seeds, seven view sizes (aspects 0.4 … 2.5) and orbits
// within bounds; the reverse painter's priorities (actions bars and pip row empty, gauge, sprouts later first, root,
// cells); the cast onto the board plane; the seed direction by board angle; the gauge's pulse formula; non-finite
// input and unusable sizes as empty space. Host-run (`swift test`); explicit types, plain loops (CI type-check rule).
import Foundation
@testable import MyceliumArchitectCore
import Testing
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

/// An independent pinhole projection of a camera (see the file header).
private struct IndependentView {
    /// The eye.
    let eye: SIMD3<Double>
    /// The unit view axis.
    let forward: SIMD3<Double>
    /// The unit right direction.
    let right: SIMD3<Double>
    /// The unit up direction.
    let up: SIMD3<Double>
    /// tan(fovY / 2).
    let tanHalf: Double
    /// Width / height.
    let aspect: Double
    /// The view size in points.
    let size: Vec2

    /// The authored eye and look-at point of R02-G22-03, written here.
    static let authoredEye: SIMD3<Double> = SIMD3(0, -1.9, 2.8)
    /// The authored look-at point, written here.
    static let authoredTarget: SIMD3<Double> = SIMD3(0, -0.3, 0)

    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }
    static func normal(_ v: SIMD3<Double>) -> SIMD3<Double> { v / dot(v, v).squareRoot() }

    /// The view of `camera` (orbit `orbit`, clamped) in a view of `size` points.
    init(camera: MyceliumArchitectCamera, orbit: MyceliumArchitectViewOrbit, size: Vec2) {
        let o: MyceliumArchitectViewOrbit = orbit.clamped()
        let f0: SIMD3<Double> = Self.normal(Self.authoredTarget - Self.authoredEye)
        let r0: SIMD3<Double> = Self.normal(Self.cross(f0, SIMD3(0, 1, 0)))
        let u0: SIMD3<Double> = Self.cross(r0, f0)
        // Turn the authored up by −pitch about +x, then by the yaw about +z.
        let cp: Double = cos(-o.pitch)
        let sp: Double = sin(-o.pitch)
        let u1: SIMD3<Double> = SIMD3(u0.x, u0.y * cp - u0.z * sp, u0.y * sp + u0.z * cp)
        let cy: Double = cos(o.yaw)
        let sy: Double = sin(o.yaw)
        let u2: SIMD3<Double> = SIMD3(u1.x * cy - u1.y * sy, u1.x * sy + u1.y * cy, u1.z)
        eye = camera.eye
        forward = Self.normal(camera.target - camera.eye)
        right = Self.normal(Self.cross(forward, u2))
        up = Self.cross(right, forward)
        tanHalf = tan(camera.fovY / 2)
        aspect = size.x / size.y
        self.size = size
    }

    /// `p` in view points, or nil behind the eye.
    func project(_ p: SIMD3<Double>) -> Vec2? {
        let d: SIMD3<Double> = p - eye
        let depth: Double = Self.dot(d, forward)
        guard depth > 0 else { return nil }
        let x: Double = Self.dot(d, right) / (depth * tanHalf * aspect)
        let y: Double = Self.dot(d, up) / (depth * tanHalf)
        return Vec2((x + 1) / 2 * size.x, (1 - y) / 2 * size.y)
    }

    /// The board-plane point under view point `v`, or nil.
    func cast(_ v: Vec2) -> Vec2? {
        let x: Double = (2 * v.x / size.x - 1) * tanHalf * aspect
        let y: Double = (1 - 2 * v.y / size.y) * tanHalf
        let ray: SIMD3<Double> = forward + right * x + up * y
        guard ray.z < 0 else { return nil }
        let t: Double = -eye.z / ray.z
        return Vec2(eye.x + ray.x * t, eye.y + ray.y * t)
    }

    /// A world extent `e` at `c` in view points.
    func extent(_ e: Double, at c: SIMD3<Double>) -> Double {
        e / (Self.dot(c - eye, forward) * tanHalf) * size.y / 2
    }
}

@Suite struct MyceliumArchitectPickerTests {
    typealias Picker = MyceliumArchitectPicker
    typealias Target = MyceliumArchitectPickTarget
    typealias Orbit = MyceliumArchitectViewOrbit
    typealias Snapshot = MyceliumArchitectSceneSnapshot
    typealias Cell = MyceliumArchitectCell
    typealias Direction = MyceliumArchitectDirection

    /// The seed of the seeded tests.
    static let seed: UInt64 = 25_143

    /// The view sizes checked (aspects 0.4 … 2.5).
    static let sizes: [Vec2] = [Vec2(390, 844), Vec2(844, 390), Vec2(768, 1024), Vec2(1024, 768), Vec2(320, 800),
                                Vec2(1000, 400), Vec2(600, 600)]

    /// The centre of `cell`, written here: ((c + 0.5 − W/2)·s, 0.05 + (H/2 − r − 0.5)·s, 0).
    static func centre(_ cell: Cell, _ snapshot: Snapshot) -> SIMD3<Double> {
        let s: Double = 1.9 / Double(max(snapshot.level.width, snapshot.level.height))
        return SIMD3((Double(cell.column) + 0.5 - Double(snapshot.level.width) / 2) * s,
                     0.05 + (Double(snapshot.level.height) / 2 - Double(cell.row) - 0.5) * s, 0)
    }

    /// The board vector of `direction`, normalised, written here.
    static func vector(_ direction: Direction) -> SIMD2<Double> {
        let o: (column: Int, row: Int) = direction.offset
        let v: SIMD2<Double> = SIMD2(Double(o.column), -Double(o.row))
        return v / (v.x * v.x + v.y * v.y).squareRoot()
    }

    /// The distance from `p` to the segment `a` … `b`, written here.
    static func distance(_ p: Vec2, _ a: Vec2, _ b: Vec2) -> Double {
        let ab: SIMD2<Double> = SIMD2(b.x - a.x, b.y - a.y)
        let ap: SIMD2<Double> = SIMD2(p.x - a.x, p.y - a.y)
        let size: Double = ab.x * ab.x + ab.y * ab.y
        let t: Double = size > 0 ? min(max((ap.x * ab.x + ap.y * ab.y) / size, 0), 1) : 0
        let d: SIMD2<Double> = ap - ab * t
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The pick of `point`, computed independently (clarification Q1).
    fileprivate static func expected(_ point: Vec2, _ view: IndependentView, _ snapshot: Snapshot) -> Target {
        let s: Double = 1.9 / Double(max(snapshot.level.width, snapshot.level.height))
        let w: Int = snapshot.level.width
        let h: Int = snapshot.level.height
        let plane: Vec2? = view.cast(point)
        if let c = plane {
            let slot: Double = 1.9 / Double(max(snapshot.budget, 1))
            for bar in 0..<snapshot.budget {
                let x: Double = -0.95 + (Double(bar) + 0.5) * slot
                if abs(c.x - x) <= 0.4 * slot && abs(c.y + 1.34) <= 0.0175 { return .empty }
            }
            let n: Int = snapshot.level.terminals.count
            for t in 0..<n {
                let x: Double = (Double(t) - Double(n - 1) / 2) * 0.06
                if abs(c.x - x) <= 0.018 && abs(c.y + 1.24) <= 0.018 { return .empty }
            }
            if c.x >= -0.95 && c.x <= 0.95 && abs(c.y + 1.12) <= 0.045 { return .gauge }
        }
        let root: SIMD3<Double> = centre(snapshot.level.root, snapshot)
        let seeds: [Direction] = snapshot.arrangement.seeds
        var k: Int = seeds.count - 1
        if let p = view.project(root) {
            let dx: Double = point.x - p.x
            let dy: Double = point.y - p.y
            if (dx * dx + dy * dy).squareRoot() < view.extent(0.36 * s, at: root) { k = -1 }
        }
        while k >= 0 {
            let v: SIMD2<Double> = vector(seeds[k])
            let tip: SIMD3<Double> = root + SIMD3(v.x, v.y, 0) * (0.4 * s)
            if let a = view.project(root), let b = view.project(tip), distance(point, a, b) <= 12 {
                return .sprout(seeds[k])
            }
            k -= 1
        }
        if let p = view.project(root) {
            let dx: Double = point.x - p.x
            let dy: Double = point.y - p.y
            if (dx * dx + dy * dy).squareRoot() <= view.extent(0.36 * s, at: root) + 12 { return .root }
        }
        if let c = plane, abs(c.x) <= Double(w) * s / 2, abs(c.y - 0.05) <= Double(h) * s / 2 {
            let column: Int = min(max(Int(floor(c.x / s + Double(w) / 2)), 0), w - 1)
            let row: Int = min(max(Int(floor(Double(h) / 2 - (c.y - 0.05) / s)), 0), h - 1)
            return .cell(Cell(column: column, row: row))
        }
        return .empty
    }

    /// The snapshots checked: levels 1 … 4 at their openings and with every seed the play accepts (up to the limit).
    static func snapshots() throws -> [Snapshot] {
        var list: [Snapshot] = []
        for number in [1, 2, 3, 4] {
            let opening: MyceliumArchitectExperienceCore = try MyceliumArchitectExperienceCore.opening(number: number)
            list.append(opening.snapshotForRendering)
            var seeded: MyceliumArchitectExperienceCore = opening
            for direction in 0..<8 {
                _ = seeded.apply(ExperienceAction(control: "root.seed", values: [Double(direction)], step: 0))
            }
            list.append(seeded.snapshotForRendering)
        }
        return list
    }

    /// A random orbit within bounds (a corner or the authored view one time in five each).
    static func orbit(_ random: inout SeededRandom) -> Orbit {
        let roll: Int = random.int(0...9)
        if roll == 0 { return .authored }
        if roll == 1 { return Orbit.corners[random.int(0...3)] }
        let yaw: Double = Orbit.yawRange.lowerBound
            + random.double() * (Orbit.yawRange.upperBound - Orbit.yawRange.lowerBound)
        let pitch: Double = Orbit.pitchRange.lowerBound
            + random.double() * (Orbit.pitchRange.upperBound - Orbit.pitchRange.lowerBound)
        return Orbit(yaw: yaw, pitch: pitch)
    }

    /// `p` moved by up to `spread` points either way.
    static func jitter(_ p: Vec2, _ spread: Double, _ random: inout SeededRandom) -> Vec2 {
        Vec2(p.x + (random.double() * 2 - 1) * spread, p.y + (random.double() * 2 - 1) * spread)
    }

    @Test func fiveHundredSeededCasesEqualAnIndependentProjection() throws {
        let snapshots: [Snapshot] = try Self.snapshots()
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var kinds: [String: Int] = [:]
        for case_ in 0..<500 {
            let snapshot: Snapshot = snapshots[random.int(0...(snapshots.count - 1))]
            let size: Vec2 = Self.sizes[random.int(0...(Self.sizes.count - 1))]
            let orbit: Orbit = Self.orbit(&random)
            let camera: MyceliumArchitectCamera = orbit.camera(aspect: size.x / size.y)
            let view: IndependentView = IndependentView(camera: camera, orbit: orbit, size: size)
            let s: Double = snapshot.fitScale
            let root: SIMD3<Double> = Self.centre(snapshot.level.root, snapshot)
            var point: Vec2 = Vec2(random.double() * size.x, random.double() * size.y)
            switch random.int(0...6) {
            case 0:
                let cell: Cell = Cell(column: random.int(0...(snapshot.level.width - 1)),
                                      row: random.int(0...(snapshot.level.height - 1)))
                if let p = view.project(Self.centre(cell, snapshot)) {
                    point = Self.jitter(p, 0.7 * view.extent(s, at: root), &random)
                }
            case 1:
                if let p = view.project(root) { point = Self.jitter(p, view.extent(0.36 * s, at: root) + 16, &random) }
            case 2:
                let seeds: [Direction] = snapshot.arrangement.seeds
                if !seeds.isEmpty {
                    let v: SIMD2<Double> = Self.vector(seeds[random.int(0...(seeds.count - 1))])
                    let mid: SIMD3<Double> = root + SIMD3(v.x, v.y, 0) * (0.3 * s)
                    if let p = view.project(mid) { point = Self.jitter(p, 16, &random) }
                }
            case 3:
                if let p = view.project(SIMD3(-0.95 + random.double() * 1.9, -1.12, 0)) {
                    point = Self.jitter(p, 8, &random)
                }
            case 4:
                let y: Double = random.int(0...1) == 0 ? -1.24 : -1.34
                if let p = view.project(SIMD3(-0.95 + random.double() * 1.9, y, 0)) {
                    point = Self.jitter(p, 4, &random)
                }
            case 5:
                point = Vec2(-0.2 * size.x + random.double() * 1.4 * size.x,
                             -0.2 * size.y + random.double() * 1.4 * size.y)
            default:
                break
            }
            let want: Target = Self.expected(point, view, snapshot)
            let got: Target = Picker.pick(point, viewSize: size, snapshot: snapshot, orbit: orbit)
            #expect(got == want, "case \(case_): \(point) in \(size) at \(orbit)")
            var name: String = "empty"
            switch want {
            case .empty: name = "empty"
            case .gauge: name = "gauge"
            case .sprout: name = "sprout"
            case .root: name = "root"
            case .cell: name = "cell"
            }
            kinds[name, default: 0] += 1
            if let wantCast = view.cast(point), let gotCast = Picker.cast(point, viewSize: size, orbit: orbit) {
                #expect(abs(wantCast.x - gotCast.x) < 1e-9 && abs(wantCast.y - gotCast.y) < 1e-9)
            }
        }
        for name in ["empty", "gauge", "sprout", "root", "cell"] {
            #expect((kinds[name] ?? 0) >= 20, "\(name): \(kinds[name] ?? 0)")
        }
    }

    @Test func thePrioritiesFollowTheReversePaintersOrder() throws {
        let snapshots: [Snapshot] = try Self.snapshots()
        let size: Vec2 = Vec2(600, 900)
        let orbit: Orbit = .authored
        let camera: MyceliumArchitectCamera = orbit.camera(aspect: size.x / size.y)
        let view: IndependentView = IndependentView(camera: camera, orbit: orbit, size: size)
        for snapshot in snapshots {
            let root: SIMD3<Double> = Self.centre(snapshot.level.root, snapshot)
            let rootPoint: Vec2 = try #require(view.project(root))
            let seeds: [Direction] = snapshot.arrangement.seeds
            // Inside the cap the root outranks every sprout, so a seed drag starts there on a seeded level too.
            #expect(Picker.pick(rootPoint, viewSize: size, snapshot: snapshot, orbit: orbit) == .root)
            if let last = seeds.last {
                // Just outside the cap along the latest sprout: that sprout.
                let tip: SIMD3<Double> = MyceliumArchitectPicker.sproutTip(last, snapshot: snapshot)
                let tipPoint: Vec2 = try #require(view.project(tip))
                let r: Double = view.extent(0.36 * snapshot.fitScale, at: root)
                let dx: Double = tipPoint.x - rootPoint.x
                let dy: Double = tipPoint.y - rootPoint.y
                let length: Double = (dx * dx + dy * dy).squareRoot()
                let probe: Vec2 = Vec2(rootPoint.x + dx / length * (r + 2), rootPoint.y + dy / length * (r + 2))
                #expect(Picker.pick(probe, viewSize: size, snapshot: snapshot, orbit: orbit) == .sprout(last))
            }
            let gauge: Vec2 = try #require(view.project(SIMD3(0.3, -1.12, 0)))
            #expect(Picker.pick(gauge, viewSize: size, snapshot: snapshot, orbit: orbit) == .gauge)
            let bar: Vec2 = try #require(view.project(MyceliumArchitectSceneGeometry.actionsBar(0, snapshot)))
            #expect(Picker.pick(bar, viewSize: size, snapshot: snapshot, orbit: orbit) == .empty)
            let n: Int = snapshot.level.terminals.count
            let pip: Vec2 = try #require(view.project(SIMD3(-Double(n - 1) / 2 * 0.06, -1.24, 0)))
            #expect(Picker.pick(pip, viewSize: size, snapshot: snapshot, orbit: orbit) == .empty)
            // A cell far from the root (and its sprouts): the cell; a terminal cell under its cap: the cell.
            var far: Cell = Cell(column: 0, row: 0)
            var best: Int = -1
            for row in 0..<snapshot.level.height {
                for column in 0..<snapshot.level.width {
                    let cell: Cell = Cell(column: column, row: row)
                    let d: Int = cell.distance(to: snapshot.level.root)
                    if d > best {
                        best = d
                        far = cell
                    }
                }
            }
            let farPoint: Vec2 = try #require(view.project(Self.centre(far, snapshot)))
            #expect(Picker.pick(farPoint, viewSize: size, snapshot: snapshot, orbit: orbit) == .cell(far))
            for terminal in snapshot.level.terminals where terminal.distance(to: snapshot.level.root) >= 3 {
                let p: Vec2 = try #require(view.project(Self.centre(terminal, snapshot)))
                #expect(Picker.pick(p, viewSize: size, snapshot: snapshot, orbit: orbit) == .cell(terminal))
            }
            let outside: Vec2 = try #require(view.project(SIMD3(0, 1.2, 0)))
            #expect(Picker.pick(outside, viewSize: size, snapshot: snapshot, orbit: orbit) == .empty)
            #expect(Picker.hitsRoot(rootPoint, viewSize: size, snapshot: snapshot, orbit: orbit))
            #expect(!Picker.hitsRoot(farPoint, viewSize: size, snapshot: snapshot, orbit: orbit))
        }
    }

    @Test func nonFiniteInputAndUnusableSizesAreEmptySpace() throws {
        let snapshot: Snapshot = try Self.snapshots()[1]
        let good: Vec2 = Vec2(300, 400)
        let size: Vec2 = Vec2(600, 900)
        let bad: [Vec2] = [Vec2(Double.nan, 400), Vec2(300, Double.infinity), Vec2(-Double.infinity, Double.nan)]
        for point in bad {
            #expect(Picker.pick(point, viewSize: size, snapshot: snapshot, orbit: .authored) == .empty)
            #expect(Picker.cast(point, viewSize: size, orbit: .authored) == nil)
            #expect(!Picker.hitsRoot(point, viewSize: size, snapshot: snapshot, orbit: .authored))
        }
        let sizes: [Vec2] = [Vec2(0, 900), Vec2(600, 0), Vec2(-600, 900), Vec2(Double.nan, 900),
                             Vec2(600, Double.infinity)]
        for unusable in sizes {
            #expect(Picker.pick(good, viewSize: unusable, snapshot: snapshot, orbit: .authored) == .empty)
            #expect(Picker.cast(good, viewSize: unusable, orbit: .authored) == nil)
            #expect(Picker.camera(viewSize: unusable, orbit: .authored) == nil)
        }
        // A wild orbit is clamped, so picking stays defined.
        let wild: Orbit = Orbit(yaw: Double.nan, pitch: 40)
        _ = Picker.pick(good, viewSize: size, snapshot: snapshot, orbit: wild)
        #expect(Picker.cast(good, viewSize: size, orbit: wild) == Picker.cast(good, viewSize: size,
                                                                              orbit: wild.clamped()))
        #expect(Picker.allowance == 12)
    }

    @Test func theSeedDirectionIsTheNearestBoardAngle() {
        var random: SeededRandom = SeededRandom(seed: Self.seed + 1)
        let origin: Vec2 = Vec2(0.1, -0.2)
        for direction in Direction.allCases {
            let v: SIMD2<Double> = Self.vector(direction)
            #expect(Picker.direction(from: origin, to: Vec2(origin.x + v.x * 0.3, origin.y + v.y * 0.3)) == direction)
        }
        #expect(Picker.direction(from: origin, to: origin) == .north)
        #expect(Picker.direction(from: origin, to: Vec2(Double.nan, 0)) == .north)
        var checked: Int = 0
        for _ in 0..<300 {
            let angle: Double = random.double() * 2 * Double.pi
            let length: Double = 0.01 + random.double()
            let to: Vec2 = Vec2(origin.x + cos(angle) * length, origin.y + sin(angle) * length)
            var best: Direction = .north
            var bestGap: Double = Double.infinity
            var secondGap: Double = Double.infinity
            for direction in Direction.allCases {
                let v: SIMD2<Double> = Self.vector(direction)
                var gap: Double = abs(atan2(v.y, v.x) - angle).truncatingRemainder(dividingBy: 2 * Double.pi)
                if gap > Double.pi { gap = 2 * Double.pi - gap }
                if gap < bestGap {
                    secondGap = bestGap
                    bestGap = gap
                    best = direction
                } else if gap < secondGap {
                    secondGap = gap
                }
            }
            guard secondGap - bestGap > 1e-9 else { continue }
            checked += 1
            #expect(Picker.direction(from: origin, to: to) == best, "angle \(angle)")
        }
        #expect(checked >= 290)
    }

    @Test func theGaugeMapsPlaneXToTheShownPulse() {
        #expect(Picker.pulse(atPlaneX: -0.9, pulsesRun: 40) == 0)
        #expect(Picker.pulse(atPlaneX: 0.9, pulsesRun: 40) == 40)
        #expect(Picker.pulse(atPlaneX: -2, pulsesRun: 40) == 0 && Picker.pulse(atPlaneX: 2, pulsesRun: 40) == 40)
        #expect(Picker.pulse(atPlaneX: 0, pulsesRun: 5) == 3)
        #expect(Picker.pulse(atPlaneX: Double.nan, pulsesRun: 5) == 0)
        #expect(Picker.pulse(atPlaneX: 0.5, pulsesRun: 0) == 0)
        var random: SeededRandom = SeededRandom(seed: Self.seed + 2)
        for _ in 0..<200 {
            let x: Double = -1.1 + random.double() * 2.2
            let run: Int = random.int(1...128)
            let raw: Double = ((x + 0.9) / 1.8 * Double(run)).rounded(.toNearestOrAwayFromZero)
            let want: Int = Int(min(max(raw, 0), Double(run)))
            #expect(Picker.pulse(atPlaneX: x, pulsesRun: run) == want)
        }
    }

    @Test func aDragCastFromTheRootGivesItsDirectionAtEveryOrbit() throws {
        let snapshot: Snapshot = try Self.snapshots()[0]
        let size: Vec2 = Vec2(700, 900)
        let root: SIMD3<Double> = Self.centre(snapshot.level.root, snapshot)
        for orbit in Orbit.corners + [Orbit.authored] {
            let camera: MyceliumArchitectCamera = orbit.camera(aspect: size.x / size.y)
            let view: IndependentView = IndependentView(camera: camera, orbit: orbit, size: size)
            let start: Vec2 = try #require(view.project(root))
            let startPlane: Vec2 = try #require(Picker.cast(start, viewSize: size, orbit: orbit))
            for direction in Direction.allCases {
                let v: SIMD2<Double> = Self.vector(direction)
                let end: Vec2 = try #require(view.project(root + SIMD3(v.x, v.y, 0) * (0.8 * snapshot.fitScale)))
                let endPlane: Vec2 = try #require(Picker.cast(end, viewSize: size, orbit: orbit))
                #expect(Picker.direction(from: startPlane, to: endPlane) == direction, "\(orbit) \(direction)")
            }
        }
    }
}
