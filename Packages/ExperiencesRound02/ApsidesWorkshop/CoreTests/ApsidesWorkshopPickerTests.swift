// ApsidesWorkshopPickerTests — feature 474 (R02-G18-04) T-R02G1804-002 (FR-R02G1804-001 … 003, 005; SC-R02G1804-001,
// 004; clarifications Q1, Q3, Q4). The analytic picker against an independent rule written here: 500 seeded touches
// (seed 2_474) over certified levels (`ApsidesWorkshopGenerator.generate` of four manifest entries), three view sizes
// and three view orbits, each judged by its own pinhole projection of the drawn camera — the orbiter within its
// projected radius 0.03 grown by 8 points, else the apoapsis square (half-size 0.015) and then the periapsis diamond
// (half-size 0.0175) grown by 12 points, else the loop within 10 points of its projected chords, else empty — with its
// sky point (the ray cast onto z = 0 in lattice units), knob steps (d = round(angle / 15°) mod 24, k = round(20 −
// 20 r / a) clamped 0 … 15), size step (a = round(20 R / (20 + k)) clamped 8 … 48) and crank tick (the nearest
// projected kernel position, lower on ties); the allowances at their edges (one point inside, one outside); the
// handles' round trip (a finger on the knob or the handle reads the current orbit); overlapping handles (the one drawn
// last wins); a point at the star keeps the direction; unusable input (non-finite points, sizes not finite and
// positive). Explicit types, plain loops; each test well under 10 s; no wall-clock asserts.
import Foundation
import Testing
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

struct ApsidesWorkshopPickerTests {
    typealias P = ApsidesWorkshopPicker
    typealias G = ApsidesWorkshopSceneGeometry
    typealias Snapshot = ApsidesWorkshopSceneSnapshot
    typealias Level = ApsidesWorkshopLevel
    typealias Orbit = ApsidesWorkshopOrbit
    typealias ViewOrbit = ApsidesWorkshopViewOrbit
    typealias Play = ApsidesWorkshopPlay

    /// The feature's test seed.
    static let seed: UInt64 = 2_474

    /// The three view sizes in points: a phone upright, a phone on its side, a tablet.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(844, 390), SIMD2(1024, 768)]

    /// The three view orbits: the authored one and two within bounds.
    static let orbits: [ViewOrbit] = [.authored, ViewOrbit(yaw: 0.7, pitch: 0.4), ViewOrbit(yaw: -0.9, pitch: -0.3)]

    /// The manifest numbers whose certified levels are used.
    static let numbers: [Int] = [1, 21, 41, 81]

    /// The certified levels of ``numbers``: `ApsidesWorkshopGenerator.generate` of each entry (no neighbour).
    static let levels: [Level] = {
        var result: [Level] = []
        for number in numbers {
            let entry: ApsidesWorkshopManifestEntry = ApsidesWorkshopManifest.entries[number - 1]
            if let generated = try? ApsidesWorkshopGenerator.generate(entry, previous: nil) {
                result.append(generated.level)
            }
        }
        return result
    }()

    /// The snapshot of a fresh play of `level` with tick `tick` shown.
    static func snapshot(_ level: Level, tick: Int) -> Snapshot {
        Snapshot(play: Play(level: level), shownTick: tick, levelNumber: 1, time: 0)
    }

    /// A level on `orbit` (period `period`, one full sweep target, budget 4), without the "already won" rule.
    static func handLevel(_ orbit: Orbit, period: Int = 16) throws -> Level {
        try Level(id: "picker", seed: seed, difficulty: 1, period: period, planets: [],
                  targets: [ApsidesWorkshopTarget.sweep(sector: 0, low: 0, high: 1000)], orbit: orbit, budget: 4,
                  tutorial: false, refusingAWin: false)
    }

    // MARK: The independent rule

    /// A pinhole lens of the drawn camera in a view of `size` points.
    struct Lens {
        let eye: SIMD3<Double>
        let forward: SIMD3<Double>
        let right: SIMD3<Double>
        let up: SIMD3<Double>
        let tanHalf: Double
        let aspect: Double
        let size: SIMD2<Double>
    }

    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    static func unit(_ v: SIMD3<Double>) -> SIMD3<Double> { v / dot(v, v).squareRoot() }

    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// The lens of the camera drawn in a view of `size` from `orbit`.
    static func lens(size: SIMD2<Double>, orbit: ViewOrbit) -> Lens {
        let camera: ApsidesWorkshopCamera = G.camera(aspect: size.x / size.y, orbit: orbit)
        let forward: SIMD3<Double> = unit(camera.target - camera.eye)
        let right: SIMD3<Double> = unit(SIMD3(-forward.z, 0, forward.x))
        let ux: Double = right.y * forward.z - right.z * forward.y
        let uy: Double = right.z * forward.x - right.x * forward.z
        let uz: Double = right.x * forward.y - right.y * forward.x
        return Lens(eye: camera.eye, forward: forward, right: right, up: SIMD3(ux, uy, uz),
                    tanHalf: tan(camera.fovY / 2), aspect: camera.aspect, size: size)
    }

    /// `p` in view points (origin top left, y down) through `lens`; nil behind the eye.
    static func screen(_ p: SIMD3<Double>, _ lens: Lens) -> SIMD2<Double>? {
        let d: SIMD3<Double> = p - lens.eye
        let depth: Double = dot(d, lens.forward)
        guard depth > 0 else { return nil }
        let x: Double = dot(d, lens.right) / (depth * lens.tanHalf * lens.aspect)
        let y: Double = dot(d, lens.up) / (depth * lens.tanHalf)
        return SIMD2((x + 1) / 2 * lens.size.x, (1 - y) / 2 * lens.size.y)
    }

    /// World extent `extent` at `p` in view points through `lens`.
    static func extent(_ extent: Double, at p: SIMD3<Double>, _ lens: Lens) -> Double {
        extent / (dot(p - lens.eye, lens.forward) * lens.tanHalf) * lens.size.y / 2
    }

    /// The world point of sky point `p` (sky units, z = 0): (x, y) · 0.9 / 16 384.
    static func world(_ p: ApsidesWorkshopPoint) -> SIMD3<Double> {
        SIMD3(Double(p.x) * 0.9 / 16_384, Double(p.y) * 0.9 / 16_384, 0)
    }

    /// The handles of `snapshot` as (pick, centre, world extent, allowance), drawn last first.
    static func handles(_ snapshot: Snapshot) -> [(pick: ApsidesWorkshopPick, centre: SIMD3<Double>, extent: Double,
                                                   allowance: Double)] {
        let n: Int = snapshot.positions.count
        return [
            (pick: .orbiter, centre: world(snapshot.orbiter), extent: 0.03, allowance: 8),
            (pick: .sizeHandle, centre: world(snapshot.positions[n / 2]), extent: 0.015, allowance: 12),
            (pick: .knob, centre: world(snapshot.positions[0]), extent: 0.0175, allowance: 12),
        ]
    }

    /// The distance from `q` to the segment `a` → `b`.
    static func segment(_ q: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = b - a
        let l2: Double = d.x * d.x + d.y * d.y
        if l2 == 0 { return distance(q, a) }
        let t: Double = max(0, min(1, ((q.x - a.x) * d.x + (q.y - a.y) * d.y) / l2))
        return distance(q, SIMD2(a.x + d.x * t, a.y + d.y * t))
    }

    /// The independent pick (see the header).
    static func expectedPick(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> ApsidesWorkshopPick {
        for handle in handles(snapshot) {
            guard let c = screen(handle.centre, lens) else { continue }
            if distance(point, c) <= extent(handle.extent, at: handle.centre, lens) + handle.allowance {
                return handle.pick
            }
        }
        let n: Int = snapshot.positions.count
        for t in 0..<n {
            guard let a = screen(world(snapshot.positions[t]), lens),
                  let b = screen(world(snapshot.positions[(t + 1) % n]), lens) else { continue }
            if segment(point, a, b) <= 10 { return .loop }
        }
        return .empty
    }

    /// The independent sky point: the ray from the eye through `point` cast onto z = 0, in lattice units.
    static func expectedSky(_ point: SIMD2<Double>, _ lens: Lens) -> SIMD2<Double>? {
        let x: Double = (2 * point.x / lens.size.x - 1) * lens.tanHalf * lens.aspect
        let y: Double = (1 - 2 * point.y / lens.size.y) * lens.tanHalf
        let ray: SIMD3<Double> = lens.forward + lens.right * x + lens.up * y
        guard ray.z < 0 else { return nil }
        let t: Double = -lens.eye.z / ray.z
        let lattice: Double = 0.9 / 64
        return SIMD2((lens.eye.x + ray.x * t) / lattice, (lens.eye.y + ray.y * t) / lattice)
    }

    /// The independent knob steps of sky point `sky` from `current`.
    static func expectedKnob(_ sky: SIMD2<Double>, _ current: Orbit) -> Orbit {
        let r: Double = (sky.x * sky.x + sky.y * sky.y).squareRoot()
        var d: Int = current.direction
        if r > 1e-6 {
            var degrees: Double = atan2(sky.y, sky.x) * 180 / Double.pi
            if degrees < 0 { degrees += 360 }
            d = Int((degrees / 15).rounded()) % 24
        }
        let k: Int = max(0, min(15, Int((20 - 20 * r / Double(current.size)).rounded())))
        return Orbit(size: current.size, eccentricity: k, direction: d)
    }

    /// The independent size step of sky point `sky` from `current`.
    static func expectedSize(_ sky: SIMD2<Double>, _ current: Orbit) -> Orbit {
        let r: Double = (sky.x * sky.x + sky.y * sky.y).squareRoot()
        let a: Int = max(8, min(48, Int((20 * r / Double(20 + current.eccentricity)).rounded())))
        return Orbit(size: a, eccentricity: current.eccentricity, direction: current.direction)
    }

    /// The independent crank tick: the nearest projected kernel position, the lower tick on ties.
    static func expectedTick(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> Int {
        var best: Int = snapshot.shownTick
        var bestDistance: Double = Double.infinity
        for (tick, p) in snapshot.positions.enumerated() {
            guard let q = screen(world(p), lens) else { continue }
            let e: Double = distance(point, q)
            if e < bestDistance {
                best = tick
                bestDistance = e
            }
        }
        return best
    }

    // MARK: Tests

    @Test func fiveHundredSeededTouchesMatchTheIndependentRule() throws {
        #expect(Self.levels.count == Self.numbers.count)
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var counts: [String: Int] = [:]
        for k in 0..<500 {
            let level: Level = Self.levels[k % Self.levels.count]
            let size: SIMD2<Double> = Self.sizes[(k / Self.levels.count) % Self.sizes.count]
            let orbit: ViewOrbit = Self.orbits[(k / (Self.levels.count * Self.sizes.count)) % Self.orbits.count]
            let snap: Snapshot = Self.snapshot(level, tick: random.int(0...(level.period - 1)))
            let lens: Lens = Self.lens(size: size, orbit: orbit)
            var point: SIMD2<Double> = SIMD2(random.range(0...size.x), random.range(0...size.y))
            let kind: Int = k % 5
            if kind < 3 {
                let handle = Self.handles(snap)[kind]
                if let c = Self.screen(handle.centre, lens) {
                    let reach: Double = Self.extent(handle.extent, at: handle.centre, lens) + handle.allowance
                    let angle: Double = random.range(0...(2 * Double.pi))
                    let r: Double = random.range(0...(reach * 1.5))
                    point = SIMD2(c.x + r * cos(angle), c.y + r * sin(angle))
                }
            } else if kind == 3 {
                let n: Int = snap.positions.count
                let t: Int = random.int(0...(n - 1))
                if let a = Self.screen(Self.world(snap.positions[t]), lens),
                   let b = Self.screen(Self.world(snap.positions[(t + 1) % n]), lens) {
                    let f: Double = random.double()
                    point = SIMD2(a.x + (b.x - a.x) * f + random.range(-16...16),
                                  a.y + (b.y - a.y) * f + random.range(-16...16))
                }
            }
            let picked: ApsidesWorkshopPick = P.pick(point, size: size, snapshot: snap, orbit: orbit)
            let expected: ApsidesWorkshopPick = Self.expectedPick(point, snap, lens)
            #expect(picked == expected, "touch \(k) \(level.id) \(size) \(orbit): \(picked) vs \(expected)")
            counts["\(picked)", default: 0] += 1
            let tick: Int = P.crankTick(point, size: size, snapshot: snap, orbit: orbit)
            #expect(tick == Self.expectedTick(point, snap, lens), "touch \(k)")
            let sky: SIMD2<Double>? = P.skyPoint(point, size: size, orbit: orbit)
            let expectedSky: SIMD2<Double>? = Self.expectedSky(point, lens)
            #expect((sky == nil) == (expectedSky == nil), "touch \(k)")
            if let s = sky, let e = expectedSky {
                #expect(Self.distance(s, e) <= 1e-6 * max(1, Self.distance(e, SIMD2(0, 0))), "touch \(k)")
                let knob: Orbit? = P.knobSteps(point, size: size, snapshot: snap, orbit: orbit)
                #expect(knob == Self.expectedKnob(e, snap.orbit), "touch \(k)")
                #expect(P.handleSize(point, size: size, snapshot: snap, orbit: orbit)
                        == Self.expectedSize(e, snap.orbit), "touch \(k)")
            }
        }
        // Every kind of pick occurs.
        for name in ["orbiter", "sizeHandle", "knob", "loop", "empty"] {
            #expect((counts[name] ?? 0) > 0, "\(name): \(counts)")
        }
    }

    @Test func allowancesAtTheirEdges() throws {
        #expect(P.orbiterAllowance == 8 && P.markerAllowance == 12 && P.loopBand == 10)
        // A circle of 20 lattice units, period 16: the knob at tick 0 (+x), the handle at tick 8 (−x), the orbiter at
        // tick 4 (+y), each far from the others.
        let level: Level = try Self.handLevel(Orbit(size: 20, eccentricity: 0, direction: 0))
        let snap: Snapshot = Self.snapshot(level, tick: 4)
        for size in Self.sizes {
            for orbit in Self.orbits {
                let lens: Lens = Self.lens(size: size, orbit: orbit)
                let star: SIMD2<Double> = try #require(Self.screen(SIMD3(0, 0, 0), lens))
                for handle in Self.handles(snap) {
                    let c: SIMD2<Double> = try #require(Self.screen(handle.centre, lens))
                    let reach: Double = Self.extent(handle.extent, at: handle.centre, lens) + handle.allowance
                    // Towards the star: inside the loop, away from the chords.
                    let towards: SIMD2<Double> = (star - c) / Self.distance(star, c)
                    let inside: SIMD2<Double> = c + towards * (reach - 1)
                    let outside: SIMD2<Double> = c + towards * (reach + 1)
                    #expect(P.pick(inside, size: size, snapshot: snap, orbit: orbit) == handle.pick,
                            "\(handle.pick) \(size) \(orbit)")
                    let beyond: ApsidesWorkshopPick = P.pick(outside, size: size, snapshot: snap, orbit: orbit)
                    #expect(beyond != handle.pick, "\(handle.pick) \(size) \(orbit)")
                    #expect(beyond == Self.expectedPick(outside, snap, lens))
                }
                // The loop band: 9 points and 11 points from the middle of chord 11 → 12, outwards.
                let a: SIMD2<Double> = try #require(Self.screen(Self.world(snap.positions[11]), lens))
                let b: SIMD2<Double> = try #require(Self.screen(Self.world(snap.positions[12]), lens))
                let middle: SIMD2<Double> = (a + b) / 2
                var normal: SIMD2<Double> = SIMD2(b.y - a.y, a.x - b.x) / Self.distance(a, b)
                if (normal.x * (middle.x - star.x) + normal.y * (middle.y - star.y)) < 0 { normal = normal * -1 }
                #expect(P.pick(middle + normal * 9, size: size, snapshot: snap, orbit: orbit) == .loop)
                #expect(P.pick(middle + normal * 11, size: size, snapshot: snap, orbit: orbit) == .empty)
                #expect(P.pick(middle - normal * 9, size: size, snapshot: snap, orbit: orbit) == .loop)
                // The star and the compass are empty space.
                #expect(P.pick(star, size: size, snapshot: snap, orbit: orbit) == .empty)
            }
        }
    }

    @Test func overlappingHandlesTheOneDrawnLastWins() throws {
        let level: Level = try Self.handLevel(Orbit(size: 20, eccentricity: 0, direction: 0))
        let size: SIMD2<Double> = Self.sizes[0]
        for orbit in Self.orbits {
            let lens: Lens = Self.lens(size: size, orbit: orbit)
            // The orbiter on the knob (tick 0) or on the handle (tick 8) wins.
            let onKnob: Snapshot = Self.snapshot(level, tick: 0)
            let knob: SIMD2<Double> = try #require(Self.screen(G.knobCentre(onKnob), lens))
            #expect(P.pick(knob, size: size, snapshot: onKnob, orbit: orbit) == .orbiter)
            let onHandle: Snapshot = Self.snapshot(level, tick: 8)
            let handle: SIMD2<Double> = try #require(Self.screen(G.handleCentre(onHandle), lens))
            #expect(P.pick(handle, size: size, snapshot: onHandle, orbit: orbit) == .orbiter)
            let apart: Snapshot = Self.snapshot(level, tick: 4)
            #expect(P.pick(knob, size: size, snapshot: apart, orbit: orbit) == .knob)
            #expect(P.pick(handle, size: size, snapshot: apart, orbit: orbit) == .sizeHandle)
        }
        // A view small enough that the knob's target reaches the handle while the orbiter's (on the knob) does not:
        // the handle (drawn after the knob) wins at its centre.
        let small: Level = try Self.handLevel(Orbit(size: 8, eccentricity: 0, direction: 0))
        let snap: Snapshot = Self.snapshot(small, tick: 0)
        var found: Bool = false
        for side in stride(from: 40, through: 400, by: 2) {
            let view: SIMD2<Double> = SIMD2(Double(side), Double(side))
            let lens: Lens = Self.lens(size: view, orbit: .authored)
            let k: SIMD2<Double> = try #require(Self.screen(G.knobCentre(snap), lens))
            let h: SIMD2<Double> = try #require(Self.screen(G.handleCentre(snap), lens))
            let gap: Double = Self.distance(k, h)
            let knobReach: Double = Self.extent(0.0175, at: G.knobCentre(snap), lens) + 12
            let orbiterReach: Double = Self.extent(0.03, at: G.knobCentre(snap), lens) + 8
            guard gap <= knobReach, gap > orbiterReach else { continue }
            found = true
            #expect(P.pick(h, size: view, snapshot: snap, orbit: .authored) == .sizeHandle, "side \(side)")
            #expect(Self.expectedPick(h, snap, lens) == .sizeHandle)
        }
        #expect(found)
    }

    @Test func handlesReadTheCurrentOrbitAndTheStarKeepsTheDirection() throws {
        let orbits: [Orbit] = [Orbit(size: 20, eccentricity: 0, direction: 0), Orbit(size: 12, eccentricity: 15,
                                                                                    direction: 7),
                               Orbit(size: 36, eccentricity: 15, direction: 23), Orbit(size: 30, eccentricity: 6,
                                                                                       direction: 13)]
        var tested: Int = 0
        for orbit in orbits {
            for period in [16, 40, 96] {
                let level: Level = try Self.handLevel(orbit, period: period)
                let snap: Snapshot = Self.snapshot(level, tick: 1)
                for size in Self.sizes {
                    for view in Self.orbits {
                        let camera: ApsidesWorkshopCamera = G.camera(aspect: size.x / size.y, orbit: view)
                        let knob: SIMD2<Double> = try #require(P.viewPoint(G.knobCentre(snap), size: size,
                                                                           camera: camera))
                        #expect(P.knobSteps(knob, size: size, snapshot: snap, orbit: view) == orbit, "\(orbit)")
                        let handle: SIMD2<Double> = try #require(P.viewPoint(G.handleCentre(snap), size: size,
                                                                             camera: camera))
                        #expect(P.handleSize(handle, size: size, snapshot: snap, orbit: view) == orbit, "\(orbit)")
                        // A finger at the star keeps the direction; the eccentricity goes to its largest step.
                        let star: SIMD2<Double> = try #require(P.viewPoint(SIMD3(0, 0, 0), size: size,
                                                                           camera: camera))
                        let sky: SIMD2<Double> = try #require(P.skyPoint(star, size: size, orbit: view))
                        #expect((sky.x * sky.x + sky.y * sky.y).squareRoot() <= P.starTolerance)
                        let atStar: Orbit? = P.knobSteps(star, size: size, snapshot: snap, orbit: view)
                        #expect(atStar == Orbit(size: orbit.size, eccentricity: 15, direction: orbit.direction))
                        tested += 1
                    }
                }
            }
        }
        #expect(tested == 4 * 3 * 3 * 3)
        // The steps are not checked for validity: a far knob point reads eccentricity 0, a near one 15 at size 8
        // (invalid: 8 · 5 < 60); the size clamps to 8 … 48.
        let level: Level = try Self.handLevel(Orbit(size: 8, eccentricity: 0, direction: 0))
        let snap: Snapshot = Self.snapshot(level, tick: 0)
        let size: SIMD2<Double> = Self.sizes[2]
        let camera: ApsidesWorkshopCamera = G.camera(aspect: size.x / size.y, orbit: .authored)
        let near: SIMD2<Double> = try #require(P.viewPoint(SIMD3(0.01, 0, 0), size: size, camera: camera))
        let close: Orbit = try #require(P.knobSteps(near, size: size, snapshot: snap, orbit: .authored))
        #expect(close.eccentricity == 15 && close.direction == 0 && !close.isValid)
        let far: SIMD2<Double> = try #require(P.viewPoint(SIMD3(0, 0.95, 0), size: size, camera: camera))
        let wide: Orbit = try #require(P.knobSteps(far, size: size, snapshot: snap, orbit: .authored))
        #expect(wide.eccentricity == 0 && wide.direction == 6)
        #expect(P.handleSize(far, size: size, snapshot: snap, orbit: .authored)?.size == 48)
        #expect(P.handleSize(near, size: size, snapshot: snap, orbit: .authored)?.size == 8)
    }

    @Test func unusableInputIsEmpty() throws {
        let level: Level = try Self.handLevel(Orbit(size: 20, eccentricity: 0, direction: 0))
        let snap: Snapshot = Self.snapshot(level, tick: 5)
        let good: SIMD2<Double> = SIMD2(390, 844)
        let points: [SIMD2<Double>] = [SIMD2(Double.nan, 10), SIMD2(10, Double.infinity), SIMD2(-Double.infinity, 0)]
        for point in points {
            #expect(P.pick(point, size: good, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.skyPoint(point, size: good, orbit: .authored) == nil)
            #expect(P.knobSteps(point, size: good, snapshot: snap, orbit: .authored) == nil)
            #expect(P.handleSize(point, size: good, snapshot: snap, orbit: .authored) == nil)
            #expect(P.crankTick(point, size: good, snapshot: snap, orbit: .authored) == 5)
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 100), SIMD2(100, -1), SIMD2(Double.nan, 100), SIMD2(100, .infinity)]
        let centre: SIMD2<Double> = SIMD2(50, 50)
        for size in sizes {
            #expect(P.pick(centre, size: size, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.skyPoint(centre, size: size, orbit: .authored) == nil)
            #expect(P.knobSteps(centre, size: size, snapshot: snap, orbit: .authored) == nil)
            #expect(P.handleSize(centre, size: size, snapshot: snap, orbit: .authored) == nil)
            #expect(P.crankTick(centre, size: size, snapshot: snap, orbit: .authored) == 5)
            #expect(P.camera(size: size, orbit: .authored) == nil)
            let camera: ApsidesWorkshopCamera = G.camera(aspect: 1)
            #expect(P.viewPoint(SIMD3(0, 0, 0), size: size, camera: camera) == nil)
        }
        // Behind the eye and non-finite world points have no view point; a ray above the horizon misses the plane.
        let camera: ApsidesWorkshopCamera = G.camera(aspect: good.x / good.y)
        #expect(P.viewPoint(SIMD3(0, 0, 10), size: good, camera: camera) == nil)
        #expect(P.viewPoint(SIMD3(Double.nan, 0, 0), size: good, camera: camera) == nil)
        let tilted: ViewOrbit = ViewOrbit(yaw: 0, pitch: -0.34)
        #expect(P.skyPoint(SIMD2(195, -100_000), size: good, orbit: tilted) == nil)
        // An orbit beyond the bounds is clamped, so it picks as the clamped one.
        let wild: ViewOrbit = ViewOrbit(yaw: 9, pitch: -9)
        let lens: Lens = Self.lens(size: good, orbit: wild.clamped())
        let orbiter: SIMD2<Double> = try #require(Self.screen(G.orbiterCentre(snap), lens))
        #expect(P.pick(orbiter, size: good, snapshot: snap, orbit: wild) == .orbiter)
    }
}
