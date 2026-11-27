// BinaryGardensPickerTests — feature 504 (R02-G21-04) T-R02G2104-002 (FR-R02G2104-004, 007, 009, 010, 012;
// SC-R02G2104-001, 004; clarifications Q1, Q3, Q4; research R1–R3, R7, R11). The analytic picker against an independent
// pick written here (`BinaryGardensIndependentPick`: its own projection through the camera's matrices, its own cast
// onto the base plane by inverting the plane's homography, its own pip, ring and dial positions from the kernel's
// table points and its own back-to-front order) on 500 seeded points — half aimed near a target, half anywhere in the
// view — over certified levels and edge snapshots (1 and 5 worlds, 2 and 8 rings, tilt 0 and 6, a single luminosity
// level) at 3 sizes and 3 orbits; the allowances at their edges; overlapping targets (a star on a world, a pip row over
// a ring); unusable input; the ring, grid-phase, pip, dial and tick targets, the tangent rule with the locks, and the
// travel steps (halves away from zero). Seed 2_504; explicit types, plain loops.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import BinaryGardensCore

/// An independent pick of the Binary Gardens system (feature 504 tests): the picking rules of the specification
/// written again without the picker's helpers.
struct BinaryGardensIndependentPick {
    typealias G = BinaryGardensSceneGeometry

    /// The view's size in points.
    let size: SIMD2<Double>
    /// The drawn camera.
    let camera: BinaryGardensCamera

    /// The pick context of a view of `size` from `orbit`.
    init(size: SIMD2<Double>, orbit: BinaryGardensViewOrbit) {
        self.size = size
        camera = G.camera(aspect: size.x / size.y, orbit: orbit)
    }

    /// `m` times (x, y, z, w), column-major.
    static func times(_ m: Mat4, _ x: Double, _ y: Double, _ z: Double, _ w: Double) -> SIMD4<Double> {
        SIMD4(m.c0.x * x + m.c1.x * y + m.c2.x * z + m.c3.x * w, m.c0.y * x + m.c1.y * y + m.c2.y * z + m.c3.y * w,
              m.c0.z * x + m.c1.z * y + m.c2.z * z + m.c3.z * w, m.c0.w * x + m.c1.w * y + m.c2.w * z + m.c3.w * w)
    }

    /// `p` in view points through the view-projection matrix (nil behind the eye).
    func project(_ p: SIMD3<Double>) -> SIMD2<Double>? {
        let c: SIMD4<Double> = Self.times(camera.viewProjection, p.x, p.y, p.z, 1)
        guard c.w > 1e-9 else { return nil }
        return SIMD2((c.x / c.w + 1) / 2 * size.x, (1 - c.y / c.w) / 2 * size.y)
    }

    /// The point of the base plane under view point `v`: the plane's homography (columns 0, 1 and 3 of the
    /// view-projection) inverted; nil when the point casts behind the eye or the homography is singular.
    func cast(_ v: SIMD2<Double>) -> SIMD2<Double>? {
        let m: Mat4 = camera.viewProjection
        let nx: Double = 2 * v.x / size.x - 1
        let ny: Double = 1 - 2 * v.y / size.y
        // Rows: x_ndc · w − x_clip = 0 and y_ndc · w − y_clip = 0 in the unknowns (X, Y), with clip = M · (X, Y, 0, 1).
        let a11: Double = nx * m.c0.w - m.c0.x
        let a12: Double = nx * m.c1.w - m.c1.x
        let b1: Double = m.c3.x - nx * m.c3.w
        let a21: Double = ny * m.c0.w - m.c0.y
        let a22: Double = ny * m.c1.w - m.c1.y
        let b2: Double = m.c3.y - ny * m.c3.w
        let det: Double = a11 * a22 - a12 * a21
        guard abs(det) > 1e-15 else { return nil }
        let x: Double = (b1 * a22 - a12 * b2) / det
        let y: Double = (a11 * b2 - b1 * a21) / det
        let w: Double = m.c0.w * x + m.c1.w * y + m.c3.w
        guard w > 1e-9, x.isFinite, y.isFinite else { return nil }
        return SIMD2(x, y)
    }

    /// The distance between view points.
    static func gap(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The distance from `p` to the segment a → b.
    static func toSegment(_ p: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = b - a
        let l: Double = d.x * d.x + d.y * d.y
        if l == 0 { return gap(p, a) }
        let t: Double = max(0, min(1, ((p.x - a.x) * d.x + (p.y - a.y) * d.y) / l))
        return gap(p, a + d * t)
    }

    /// A world extent at `centre` in view points: extent / (depth · tan(fovY / 2)) · height / 2, depth along the axis
    /// from the eye to the target.
    func extent(_ e: Double, at centre: SIMD3<Double>) -> Double {
        let f: SIMD3<Double> = camera.target - camera.eye
        let fl: Double = (f * f).sum().squareRoot()
        let depth: Double = ((centre - camera.eye) * f).sum() / fl
        return e / (depth * tan(camera.fovY / 2)) * size.y / 2
    }

    /// Star `star`'s pip centres facing the drawn eye.
    func pips(_ star: Int, _ s: BinaryGardensSceneSnapshot) -> [SIMD3<Double>] {
        let c: SIMD3<Double> = G.starCentre(star, s)
        let toEye: SIMD3<Double> = camera.eye - c
        let w: SIMD3<Double> = toEye / (toEye * toEye).sum().squareRoot()
        var right: SIMD3<Double> = SIMD3(-w.y, w.x, 0)
        let rl: Double = (right * right).sum().squareRoot()
        right = rl > 1e-9 ? right / rl : SIMD3(1, 0, 0)
        let up: SIMD3<Double> = SIMD3(w.y * right.z - w.z * right.y, w.z * right.x - w.x * right.z,
                                      w.x * right.y - w.y * right.x)
        let lum: Int = s.arrangement.luminosities[star]
        let r: Double = 0.05 + 0.012 * Double(min(max(lum, 0), 3))
        let n: Int = s.luminosityLevels.count
        var result: [SIMD3<Double>] = []
        for k in 0..<n { result.append(c - up * (r + 0.03) + right * ((Double(k) - Double(n - 1) / 2) * 0.022)) }
        return result
    }

    /// Ring `ring`'s 48 vertices at the snapshot's tilt, from the kernel's table.
    static func ringPoints(_ ring: Int, _ s: BinaryGardensSceneSnapshot, tilt: Int? = nil) -> [SIMD3<Double>] {
        var points: [SIMD3<Double>] = []
        for step in 0..<48 {
            let p: BinaryGardensPoint = BinaryGardensSky.starPosition(radius: s.ringRadii[ring], phase: step,
                                                                      tilt: tilt ?? s.arrangement.tilt)
            points.append(SIMD3(Double(p.x), Double(p.y), Double(p.z)) * (s.fitScale / 1_048_576))
        }
        return points
    }

    /// The pick of `v` in `s` (no preview), in the specification's order.
    func pick(_ v: SIMD2<Double>, _ s: BinaryGardensSceneSnapshot) -> BinaryGardensPick {
        let c: SIMD2<Double>? = cast(v)
        if let p = c {
            let barY: Double = -1.2 - 0.1 * Double(s.worlds.count) - 0.03
            if s.budget > 0 && abs(p.y - barY) <= 0.0175 {
                let slot: Double = 1.8 / Double(s.budget)
                for k in 0..<s.budget where abs(p.x - (-0.9 + (Double(k) + 0.5) * slot)) <= 0.4 * slot {
                    return .empty
                }
            }
            for j in s.worlds.indices.reversed() where abs(p.y - (-1.2 - 0.1 * Double(j))) <= 0.045 {
                if p.x >= -0.95 && p.x <= 1.22 { return .gauge(j) }
            }
        }
        // Bodies front to back: nearest first; ties: stars before worlds, then the higher index.
        var bodies: [(star: Bool, index: Int, distance: Double)] = []
        for j in s.worlds.indices {
            let d: SIMD3<Double> = G.worldCentre(j, s) - camera.eye
            bodies.append((false, j, (d * d).sum().squareRoot()))
        }
        for i in 0..<2 {
            let d: SIMD3<Double> = G.starCentre(i, s) - camera.eye
            bodies.append((true, i, (d * d).sum().squareRoot()))
        }
        bodies.sort { a, b in
            if abs(a.distance - b.distance) > 1e-12 { return a.distance < b.distance }
            if a.star != b.star { return a.star }
            return a.index > b.index
        }
        for body in bodies {
            if body.star {
                let row: [SIMD3<Double>] = pips(body.index, s)
                if let first = row.first, let last = row.last, let a = project(first), let b = project(last),
                   Self.toSegment(v, a, b) <= 12 {
                    return .pips(body.index)
                }
                let centre: SIMD3<Double> = G.starCentre(body.index, s)
                let r: Double = 0.05 + 0.012 * Double(min(max(s.arrangement.luminosities[body.index], 0), 3))
                if let p = project(centre), Self.gap(v, p) <= extent(r, at: centre) + 12 { return .star(body.index) }
            } else {
                let centre: SIMD3<Double> = G.worldCentre(body.index, s)
                if let p = project(centre), Self.gap(v, p) <= extent(0.07, at: centre) + 12 {
                    return .world(body.index)
                }
            }
        }
        for ring in s.ringRadii.indices.reversed() {
            let points: [SIMD3<Double>] = Self.ringPoints(ring, s)
            for k in 0..<48 {
                if let a = project(points[k]), let b = project(points[(k + 1) % 48]), Self.toSegment(v, a, b) <= 12 {
                    return .ring(ring)
                }
            }
        }
        if s.maxTilt > 0, let a = project(SIMD3(-1.15, 1.08, 0)),
           let b = project(SIMD3(-1.15 + 0.05 * Double(s.maxTilt), 1.08, 0)), Self.toSegment(v, a, b) <= 12 {
            return .dial
        }
        if let p = c, (p * p).sum().squareRoot() <= 0.95 { return .disc }
        return .empty
    }

    /// The view points worth aiming at in `s`: every body, pip row, ring vertex, dial pip and gauge cell.
    func aims(_ s: BinaryGardensSceneSnapshot) -> [SIMD2<Double>] {
        var points: [SIMD3<Double>] = []
        for i in 0..<2 {
            points.append(G.starCentre(i, s))
            points += pips(i, s)
        }
        for j in s.worlds.indices {
            points.append(G.worldCentre(j, s))
            points.append(SIMD3(Double(j % 3) * 0.6 - 0.6, -1.2 - 0.1 * Double(j), 0))
            points.append(SIMD3(1.1, -1.2 - 0.1 * Double(j), 0))
        }
        for ring in s.ringRadii.indices {
            let ringPoints: [SIMD3<Double>] = Self.ringPoints(ring, s)
            points.append(ringPoints[(ring * 7) % 48])
            points.append(ringPoints[(ring * 7 + 24) % 48])
        }
        if s.maxTilt > 0 { points.append(SIMD3(-1.15 + 0.025 * Double(s.maxTilt), 1.08, 0)) }
        points.append(SIMD3(0, -1.2 - 0.1 * Double(s.worlds.count) - 0.03, 0))
        var result: [SIMD2<Double>] = []
        for p in points { if let v = project(p) { result.append(v) } }
        return result
    }
}

@Suite struct BinaryGardensPickerTests {
    typealias G = BinaryGardensSceneGeometry
    typealias P = BinaryGardensPicker
    typealias Snapshot = BinaryGardensSceneSnapshot
    typealias Independent = BinaryGardensIndependentPick

    /// The seed of feature 504's tests.
    static let seed: UInt64 = 2_504

    /// The view sizes checked: a tall phone, a tablet, a wide phone.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1024, 768), SIMD2(844, 390)]

    /// The orbits checked: the authored one and two turned ones.
    static let orbits: [BinaryGardensViewOrbit] = [.authored, BinaryGardensViewOrbit(yaw: 0.6, pitch: 0.4),
                                                    BinaryGardensViewOrbit(yaw: -1.0, pitch: -0.3)]

    /// Sampled certified levels.
    static let levels: [BinaryGardensLevel] = {
        var result: [BinaryGardensLevel] = []
        for number in [1, 22, 43, 64, 85] {
            do {
                result.append(try BinaryGardensExperienceCore.level(number: number))
            } catch {
                fatalError("level \(number) does not certify: \(error)")
            }
        }
        return result
    }()

    /// A snapshot of `level` playing at shown tick `tick`.
    static func snapshot(_ level: BinaryGardensLevel, tick: Int) throws -> Snapshot {
        Snapshot(play: try BinaryGardensExperienceCore.freshPlay(of: level), shownTick: tick, levelNumber: 1, time: 0)
    }

    /// An unchecked snapshot from the kernel's positions: `rings` radii spread over 1 … 40, `worlds` worlds of radius
    /// `worldRadius`, both stars on ring `starRing` at phases 0 and 24 with luminosity indices `lums`, tilt `tilt`,
    /// luminosity levels `levels`, T_max `maxTilt`, budget 6, tick `tick` shown, the given freedoms.
    static func edge(rings: Int, worlds count: Int, worldRadius: Int, tilt: Int, maxTilt: Int = 6,
                     levels: [Int] = [1, 20, 40, 64], lums: [Int] = [0, 3], starRing: Int? = nil, tick: Int = 48,
                     speed: Int = 1, phaseStep: Int = 1,
                     freedoms: [BinaryGardensStarFreedom] = [.free, .free]) -> Snapshot {
        var ringRadii: [Int] = []
        for k in 0..<rings { ringRadii.append(1 + k * 39 / max(rings - 1, 1)) }
        let ring: Int = starRing ?? rings - 1
        var worlds: [BinaryGardensSceneWorld] = []
        for j in 0..<count {
            var positions: [BinaryGardensPoint] = []
            for t in 1...48 {
                let phase: Int = BinaryGardensSky.phase(9 * j, speed: 1, tick: t)
                positions.append(BinaryGardensSky.worldPosition(radius: worldRadius, phase: phase))
            }
            let flux: [Int] = Array(repeating: 30, count: 48)
            let shares: [[Int]] = Array(repeating: [15, 15], count: 48)
            let bands: [BinaryGardensBand] = Array(repeating: .comfortable, count: 48)
            worlds.append(BinaryGardensSceneWorld(radius: worldRadius, phase: 9 * j, speed: 1, lethalLow: 10,
                                                  comfortLow: 20, comfortHigh: 40, lethalHigh: 60, window: 10,
                                                  bloomLow: 100, bloomHigh: 2_000, positions: positions, flux: flux,
                                                  shares: shares, bands: bands, longestLethalRun: 0,
                                                  longestWindow: 48, windowStart: 1, integral: 1_440,
                                                  bloom: .inside))
        }
        let arrangement: BinaryGardensArrangement = BinaryGardensArrangement(rings: [ring, ring], phases: [0, 24],
                                                                            luminosities: lums, tilt: tilt)
        var stars: [[BinaryGardensPoint]] = []
        for t in 1...48 {
            var both: [BinaryGardensPoint] = []
            for star in 0..<2 {
                let step: Int = BinaryGardensSky.phase(arrangement.phases[star], speed: speed, tick: t)
                both.append(BinaryGardensSky.starPosition(radius: ringRadii[ring], phase: step, tilt: tilt))
            }
            stars.append(both)
        }
        return Snapshot(ringRadii: ringRadii, luminosityLevels: levels, maxTilt: maxTilt, phaseStep: phaseStep,
                        lethalTolerance: 2, worlds: worlds, arrangement: arrangement, starPositions: stars,
                        shownTick: tick, failure: nil, stage: .playing, actionsLeft: 3, budget: 6, levelNumber: 1,
                        time: 0, starSpeed: speed, freedoms: freedoms)
    }

    /// The snapshots of the seeded pick check.
    static func pickSnapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for (k, level) in levels.enumerated() { result.append(try snapshot(level, tick: 1 + k * 11)) }
        result.append(edge(rings: 2, worlds: 1, worldRadius: 30, tilt: 0, maxTilt: 0, levels: [12], lums: [0, 0]))
        result.append(edge(rings: 8, worlds: 5, worldRadius: 40, tilt: 6, tick: 17))
        result.append(edge(rings: 8, worlds: 5, worldRadius: 60, tilt: 3, starRing: 4, tick: 33, speed: 3))
        return result
    }

    @Test func fiveHundredSeededPointsEqualTheIndependentPick() throws {
        let snaps: [Snapshot] = try Self.pickSnapshots()
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var seen: Set<String> = []
        var count: Int = 0
        while count < 500 {
            let snap: Snapshot = snaps[count % snaps.count]
            let size: SIMD2<Double> = Self.sizes[(count / snaps.count) % Self.sizes.count]
            let orbit: BinaryGardensViewOrbit = Self.orbits[(count / (snaps.count * Self.sizes.count)) % 3]
            let independent: Independent = Independent(size: size, orbit: orbit)
            var point: SIMD2<Double> = SIMD2(random.range(0...size.x), random.range(0...size.y))
            if count % 2 == 0 {
                let aims: [SIMD2<Double>] = independent.aims(snap)
                if !aims.isEmpty {
                    let aim: SIMD2<Double> = aims[random.int(0...(aims.count - 1))]
                    point = aim + SIMD2(random.range(-20...20), random.range(-20...20))
                }
            }
            let expected: BinaryGardensPick = independent.pick(point, snap)
            let picked: BinaryGardensPick = P.pick(point, size: size, snapshot: snap, orbit: orbit)
            #expect(picked == expected, "point \(point) size \(size) orbit \(orbit) snapshot \(count % snaps.count)")
            switch expected {
            case .gauge: seen.insert("gauge")
            case .pips: seen.insert("pips")
            case .star: seen.insert("star")
            case .world: seen.insert("world")
            case .ring: seen.insert("ring")
            case .dial: seen.insert("dial")
            case .disc: seen.insert("disc")
            case .empty: seen.insert("empty")
            }
            count += 1
        }
        #expect(seen.count == 8, "kinds seen: \(seen.sorted())")
    }

    @Test func allowancesHoldAtTheirEdges() throws {
        // One far world (radius 60) and small rings (1 … 2 units): the world stands alone at tick 24.
        let snap: Snapshot = Self.edge(rings: 2, worlds: 1, worldRadius: 60, tilt: 0, maxTilt: 0, tick: 24)
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: BinaryGardensCamera = try #require(P.camera(size: size, orbit: orbit))
                let centre: SIMD3<Double> = G.worldCentre(0, snap)
                let c: SIMD2<Double> = try #require(P.viewPoint(centre, size: size, camera: camera))
                let r: Double = try #require(P.projectedExtent(G.worldRadius, at: centre, size: size, camera: camera))
                let inside: SIMD2<Double> = c - SIMD2(r + P.markerAllowance - 0.01, 0)
                let outside: SIMD2<Double> = c - SIMD2(r + P.markerAllowance + 0.01, 0)
                #expect(P.pick(inside, size: size, snapshot: snap, orbit: orbit) == .world(0))
                #expect(P.pick(outside, size: size, snapshot: snap, orbit: orbit) != .world(0))
                let independent: Independent = Independent(size: size, orbit: orbit)
                #expect(abs(independent.extent(G.worldRadius, at: centre) - r) < 1e-9)
                // The dial of a level with T_max 6 (another snapshot): 12 points off its segment's middle, up and down.
                let dialSnap: Snapshot = Self.edge(rings: 2, worlds: 1, worldRadius: 60, tilt: 0, maxTilt: 6, tick: 24)
                let a: SIMD2<Double> = try #require(P.viewPoint(G.tiltPipCentre(0), size: size, camera: camera))
                let b: SIMD2<Double> = try #require(P.viewPoint(G.tiltPipCentre(6), size: size, camera: camera))
                let mid: SIMD2<Double> = (a + b) / 2
                let along: SIMD2<Double> = (b - a) / Independent.gap(a, b)
                let normal: SIMD2<Double> = SIMD2(-along.y, along.x)
                #expect(P.pick(mid + normal * 11.99, size: size, snapshot: dialSnap, orbit: orbit) == .dial)
                #expect(P.pick(mid + normal * 12.01, size: size, snapshot: dialSnap, orbit: orbit) != .dial)
                #expect(P.pick(mid, size: size, snapshot: snap, orbit: orbit) != .dial, "no dial at T_max 0")
            }
        }
        // The gauge plate's edges on the base plane: inside y_j ± 0.045, the gap between rows empty (cast points
        // projected back).
        let rows: Snapshot = Self.edge(rings: 2, worlds: 5, worldRadius: 60, tilt: 0, tick: 24)
        let size: SIMD2<Double> = SIMD2(800, 800)
        let camera: BinaryGardensCamera = try #require(P.camera(size: size, orbit: .authored))
        for j in 0..<5 {
            let y: Double = G.gaugeY(j)
            let inside: SIMD2<Double> = try #require(P.viewPoint(SIMD3(0.3, y + 0.0449, 0), size: size, camera: camera))
            #expect(P.pick(inside, size: size, snapshot: rows, orbit: .authored) == .gauge(j))
            if j > 0 {
                let between: SIMD2<Double> = try #require(P.viewPoint(SIMD3(0.3, y + 0.05, 0), size: size,
                                                                      camera: camera))
                #expect(P.pick(between, size: size, snapshot: rows, orbit: .authored) == .empty)
            }
            let edge: SIMD2<Double> = try #require(P.viewPoint(SIMD3(1.2199, y, 0), size: size, camera: camera))
            #expect(P.pick(edge, size: size, snapshot: rows, orbit: .authored) == .gauge(j))
            let beyond: SIMD2<Double> = try #require(P.viewPoint(SIMD3(1.2201, y, 0), size: size, camera: camera))
            #expect(P.pick(beyond, size: size, snapshot: rows, orbit: .authored) != .gauge(j))
        }
        // An actions bar is empty space.
        let bar: SIMD2<Double> = try #require(P.viewPoint(G.actionsBar(2, rows), size: size, camera: camera))
        #expect(P.pick(bar, size: size, snapshot: rows, orbit: .authored) == .empty)
    }

    @Test func overlappingTargetsGoToTheOneDrawnLast() throws {
        // Star 1 and world 0 on the same point: the star (drawn after a world at the same distance) wins.
        let rings: Int = 3
        // The largest ring is 40 units, star 1 at phase 0 at tick 48 and world 0 at phase 0 at tick 48: one point.
        let snap: Snapshot = Self.edge(rings: rings, worlds: 1, worldRadius: 40, tilt: 0, tick: 48)
        #expect(G.starCentre(0, snap) == G.worldCentre(0, snap))
        var over: Int = 0
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: BinaryGardensCamera = try #require(P.camera(size: size, orbit: orbit))
                let c: SIMD2<Double> = try #require(P.viewPoint(G.starCentre(0, snap), size: size, camera: camera))
                let picked: BinaryGardensPick = P.pick(c, size: size, snapshot: snap, orbit: orbit)
                #expect(picked == .star(0) || picked == .pips(0), "\(picked)")
                #expect(picked == Independent(size: size, orbit: orbit).pick(c, snap))
                // A pip row over a ring: points of star 2's pip row within a ring's allowance pick the pips.
                let row: [(centre: SIMD3<Double>, lit: Bool)] = G.luminosityPips(1, snap, eye: camera.eye)
                for k in 0...10 {
                    let t: Double = Double(k) / 10
                    let point: SIMD3<Double> = row[0].centre + (row[row.count - 1].centre - row[0].centre) * t
                    let m: SIMD2<Double> = try #require(P.viewPoint(point, size: size, camera: camera))
                    let ringGap: Double = try #require(P.ringDistance(m, ring: rings - 1, size: size,
                                                                      snapshot: snap, camera: camera))
                    if ringGap <= P.markerAllowance {
                        over += 1
                        #expect(P.pick(m, size: size, snapshot: snap, orbit: orbit) == .pips(1))
                    }
                }
            }
        }
        #expect(over > 0, "some pip row point lies over a ring")
        // The order of the bodies is the scene's back-to-front order reversed.
        let level: Snapshot = try Self.snapshot(Self.levels[3], tick: 9)
        let eye: SIMD3<Double> = G.camera(aspect: 1, orbit: Self.orbits[1]).eye
        let order: [BinaryGardensElement] = G.paintOrder(level, eye: eye)
        var bodies: [Double] = []
        for element in order where element.kind.isBody {
            let d: SIMD3<Double> = element.centre - eye
            bodies.append((d * d).sum().squareRoot())
        }
        for k in 1..<bodies.count { #expect(bodies[k - 1] >= bodies[k] - 1e-12) }
    }

    @Test func unusableInputIsEmptySpace() throws {
        let snap: Snapshot = try Self.snapshot(Self.levels[0], tick: 5)
        let good: SIMD2<Double> = SIMD2(390, 844)
        let points: [SIMD2<Double>] = [SIMD2(.nan, 10), SIMD2(10, .infinity), SIMD2(-.infinity, .nan)]
        for point in points { #expect(P.pick(point, size: good, snapshot: snap, orbit: .authored) == .empty) }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 100), SIMD2(100, -1), SIMD2(.nan, 100), SIMD2(100, .infinity)]
        for size in sizes {
            #expect(P.pick(SIMD2(50, 50), size: size, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.camera(size: size, orbit: .authored) == nil)
            #expect(P.planePoint(SIMD2(50, 50), size: size, orbit: .authored) == nil)
            #expect(P.gaugeTick(SIMD2(50, 50), size: size, orbit: .authored) == nil)
            #expect(P.tangent(star: 0, size: size, snapshot: snap, orbit: .authored) == nil)
            #expect(P.ringTarget(SIMD2(50, 50), star: 0, size: size, snapshot: snap, orbit: .authored)
                    == snap.arrangement.rings[0])
            #expect(P.phaseTarget(SIMD2(50, 50), star: 1, size: size, snapshot: snap, orbit: .authored)
                    == snap.arrangement.phases[1])
        }
        // Every projected value stays finite at the extreme aspects and orbits.
        for size in [SIMD2<Double>(160, 400), SIMD2<Double>(1000, 400)] {
            for orbit in BinaryGardensViewOrbit.corners {
                let camera: BinaryGardensCamera = try #require(P.camera(size: size, orbit: orbit))
                for star in 0..<2 {
                    let v: SIMD2<Double> = try #require(P.viewPoint(G.starCentre(star, snap), size: size,
                                                                    camera: camera))
                    #expect(v.x.isFinite && v.y.isFinite)
                    let u: SIMD2<Double> = try #require(P.tangent(star: star, size: size, snapshot: snap,
                                                                  orbit: orbit))
                    #expect(u.x.isFinite && u.y.isFinite)
                }
            }
        }
    }

    @Test func dragTargetsSnapToRingsGridPhasesPipsAndTicks() throws {
        let snaps: [Snapshot] = [try Self.snapshot(Self.levels[1], tick: 12),
                                 Self.edge(rings: 8, worlds: 2, worldRadius: 50, tilt: 4, starRing: 3, tick: 20,
                                           speed: 2, phaseStep: 6)]
        for snap in snaps {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let independent: Independent = Independent(size: size, orbit: orbit)
                    for star in 0..<2 {
                        // At each ring's point under the star, the ring target is that ring.
                        let step: Int = snap.starStep(star, tick: snap.shownTick)
                        for ring in snap.ringRadii.indices {
                            let point: SIMD3<Double> = Independent.ringPoints(ring, snap)[step]
                            let v: SIMD2<Double> = try #require(independent.project(point))
                            let target: Int = P.ringTarget(v, star: star, size: size, snapshot: snap, orbit: orbit)
                            if ring > 0 {
                                let inner: SIMD3<Double> = Independent.ringPoints(ring - 1, snap)[step]
                                if let w = independent.project(inner), Independent.gap(v, w) < 1e-6 { continue }
                            }
                            #expect(target == ring, "ring \(ring) star \(star)")
                        }
                        // At each grid phase's drawn position, the phase target is that phase.
                        let ring: Int = snap.arrangement.rings[star]
                        let points: [SIMD3<Double>] = Independent.ringPoints(ring, snap)
                        var p: Int = 0
                        while p < 48 {
                            let drawn: Int = (p + snap.starSpeed * snap.shownTick) % 48
                            let v: SIMD2<Double> = try #require(independent.project(points[drawn]))
                            #expect(P.phaseTarget(v, star: star, size: size, snapshot: snap, orbit: orbit) == p)
                            p += snap.phaseStep
                        }
                        // A pip tap takes the nearest pip.
                        let pips: [SIMD3<Double>] = independent.pips(star, snap)
                        for (k, pip) in pips.enumerated() {
                            let v: SIMD2<Double> = try #require(independent.project(pip))
                            #expect(P.nearestPip(v, star: star, size: size, snapshot: snap, orbit: orbit) == k)
                        }
                    }
                    for step in 0...snap.maxTilt {
                        let v: SIMD2<Double> = try #require(independent.project(G.tiltPipCentre(step)))
                        #expect(P.nearestTiltPip(v, size: size, snapshot: snap, orbit: orbit) == step)
                    }
                    // The tick under the finger: each cell's centre, the plate's margins.
                    for tick in [1, 2, 24, 47, 48] {
                        let v: SIMD2<Double> = try #require(independent.project(G.cellCentre(0, tick: tick)))
                        #expect(P.gaugeTick(v, size: size, orbit: orbit) == tick)
                        let cast: SIMD2<Double> = try #require(independent.cast(v))
                        #expect(abs(cast.x - G.cellX(tick)) < 1e-6)
                        #expect(abs(try #require(P.gaugeX(v, size: size, orbit: orbit)) - G.cellX(tick)) < 1e-6)
                    }
                    let margin: SIMD2<Double> = try #require(independent.project(SIMD3(-0.93, -1.2, 0)))
                    #expect(P.gaugeTick(margin, size: size, orbit: orbit) == 1)
                    let bloom: SIMD2<Double> = try #require(independent.project(SIMD3(1.1, -1.2, 0)))
                    #expect(P.gaugeTick(bloom, size: size, orbit: orbit) == 48)
                }
            }
        }
    }

    @Test func dragModeFollowsTheTangentAndTheLocks() throws {
        let free: Snapshot = Self.edge(rings: 4, worlds: 1, worldRadius: 50, tilt: 2, tick: 10)
        for size in Self.sizes {
            for orbit in Self.orbits {
                for star in 0..<2 {
                    let u: SIMD2<Double> = try #require(P.tangent(star: star, size: size, snapshot: free,
                                                                  orbit: orbit))
                    // Independent tangent: the kernel's table points either side of the drawn step.
                    let independent: Independent = Independent(size: size, orbit: orbit)
                    let step: Int = free.starStep(star, tick: free.shownTick)
                    let points: [SIMD3<Double>] = Independent.ringPoints(free.arrangement.rings[star], free)
                    let ahead: SIMD2<Double> = try #require(independent.project(points[(step + 1) % 48]))
                    let behind: SIMD2<Double> = try #require(independent.project(points[(step + 47) % 48]))
                    #expect(Independent.gap(u, ahead - behind) < 1e-6)
                    let length: Double = (u.x * u.x + u.y * u.y).squareRoot()
                    try #require(length >= P.tangentFloor)
                    let t: SIMD2<Double> = u / length
                    let n: SIMD2<Double> = SIMD2(-t.y, t.x)
                    #expect(P.dragMode(travel: t * 20 + n * 5, star: star, size: size, snapshot: free,
                                       orbit: orbit) == .phase)
                    #expect(P.dragMode(travel: -t * 20 + n * 3, star: star, size: size, snapshot: free,
                                       orbit: orbit) == .phase)
                    #expect(P.dragMode(travel: n * 20 + t * 5, star: star, size: size, snapshot: free,
                                       orbit: orbit) == .ring)
                    #expect(P.dragMode(travel: t * 10 + n * 10.001, star: star, size: size, snapshot: free,
                                       orbit: orbit) == .ring, "across at least along: ring")
                }
            }
        }
        // The locks override the direction.
        let size: SIMD2<Double> = SIMD2(390, 844)
        let ringOnly: Snapshot = Self.edge(rings: 4, worlds: 1, worldRadius: 50, tilt: 2, tick: 10,
                                           freedoms: [BinaryGardensStarFreedom(ring: true, phase: false,
                                                                               luminosity: true), .free])
        let phaseOnly: Snapshot = Self.edge(rings: 4, worlds: 1, worldRadius: 50, tilt: 2, tick: 10,
                                            freedoms: [BinaryGardensStarFreedom(ring: false, phase: true,
                                                                                luminosity: false), .free])
        let fixed: Snapshot = Self.edge(rings: 4, worlds: 1, worldRadius: 50, tilt: 2, tick: 10,
                                        freedoms: [BinaryGardensStarFreedom(ring: false, phase: false,
                                                                            luminosity: true), .free])
        let u: SIMD2<Double> = try #require(P.tangent(star: 0, size: size, snapshot: free, orbit: .authored))
        let n: SIMD2<Double> = SIMD2(-u.y, u.x)
        #expect(P.dragMode(travel: u * 30, star: 0, size: size, snapshot: ringOnly, orbit: .authored) == .ring)
        #expect(P.dragMode(travel: n * 30, star: 0, size: size, snapshot: phaseOnly, orbit: .authored) == .phase)
        #expect(P.dragMode(travel: u * 30, star: 0, size: size, snapshot: fixed, orbit: .authored) == nil)
        #expect(P.dragMode(travel: u * 30, star: 1, size: size, snapshot: fixed, orbit: .authored) == .phase)
        #expect(P.dragMode(travel: SIMD2(.nan, 1), star: 0, size: size, snapshot: free, orbit: .authored) == .ring)
        // A tangent shorter than the floor (a ring of radius 1 at a tiny view) decides a ring drag.
        let tiny: Snapshot = Self.edge(rings: 2, worlds: 1, worldRadius: 60, tilt: 0, starRing: 0, tick: 10)
        let small: SIMD2<Double> = SIMD2(4, 4)
        let tangent: SIMD2<Double> = try #require(P.tangent(star: 0, size: small, snapshot: tiny, orbit: .authored))
        #expect((tangent.x * tangent.x + tangent.y * tangent.y).squareRoot() < P.tangentFloor)
        #expect(P.dragMode(travel: tangent * 1000, star: 0, size: small, snapshot: tiny, orbit: .authored) == .ring)
    }

    @Test func travelStepsRoundHalvesAwayFromZero() {
        #expect(P.markerAllowance == 12 && P.stepTravel == 32 && P.tangentFloor == 0.5)
        #expect(P.stepValue(start: 1, travel: 0, upper: 3) == 1)
        #expect(P.stepValue(start: 1, travel: 15.9, upper: 3) == 1)
        #expect(P.stepValue(start: 1, travel: 16, upper: 3) == 2)
        #expect(P.stepValue(start: 1, travel: -16, upper: 3) == 0)
        #expect(P.stepValue(start: 1, travel: 47.9, upper: 3) == 2)
        #expect(P.stepValue(start: 1, travel: 48, upper: 3) == 3)
        #expect(P.stepValue(start: 1, travel: 1_000, upper: 3) == 3)
        #expect(P.stepValue(start: 1, travel: -1_000, upper: 3) == 0)
        #expect(P.stepValue(start: 2, travel: .nan, upper: 3) == 2)
        #expect(P.stepValue(start: 9, travel: 0, upper: 6) == 6)
        #expect(P.stepValue(start: 0, travel: 500, upper: 0) == 0)
        for travel in stride(from: -200.0, through: 200.0, by: 7.5) {
            let expected: Int = min(max(3 + Int((travel / 32).rounded(.toNearestOrAwayFromZero)), 0), 6)
            #expect(P.stepValue(start: 3, travel: travel, upper: 6) == expected)
        }
    }
}
