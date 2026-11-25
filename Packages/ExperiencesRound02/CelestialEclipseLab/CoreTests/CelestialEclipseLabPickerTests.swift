// CelestialEclipseLabPickerTests — feature 464 (R02-G17-04) T-R02G1704-002 (FR-R02G1704-003, 005; SC-R02G1704-001, 004;
// clarifications Q1, Q3, Q4). The analytic picker against an independent rule written here: 500 seeded touches (seed
// 2_464) over certified levels (the certified candidates of eight manifest numbers), three view sizes and three orbits,
// each picked by its own pinhole projection of the drawn camera — the front-most body (the nearest to the eye, ties to
// the higher index) whose projected disc radius r · s grown by 8 points holds the touch, else the dial (the box of the
// projected strip ends and bracket ends grown by 8 points), else empty — and its dial tick (the nearest projected tick
// on the strip) and ring offset (the nearest projected orbit position, ties to the lower phase); the 8-point allowance
// at 7 points (hit) and 9 points (miss); the front-most of two overlapping bodies whichever index is nearer; unusable
// input (non-finite points, sizes not finite and positive). Explicit types, plain loops; each test well under 10 s; no
// wall-clock asserts.
import Foundation
import Testing
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

struct CelestialEclipseLabPickerTests {
    typealias P = CelestialEclipseLabPicker
    typealias G = CelestialEclipseLabSceneGeometry
    typealias Snapshot = CelestialEclipseLabSceneSnapshot
    typealias Level = CelestialEclipseLabLevel
    typealias Orbit = CelestialEclipseLabOrbit
    typealias V = CelestialEclipseLabVector
    typealias Body = CelestialEclipseLabBody

    /// The feature's test seed.
    static let seed: UInt64 = 2_464

    /// The three view sizes in points: a phone upright, a phone on its side, a tablet.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(844, 390), SIMD2(1024, 768)]

    /// The three orbits: the authored one and two within bounds.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.6, pitch: 0.3), Orbit(yaw: -0.9, pitch: -0.3)]

    /// The manifest numbers whose certified levels are used.
    static let numbers: [Int] = [1, 7, 20, 42, 48, 64, 94, 100]

    /// The certified levels of ``numbers``: each the generator's certified candidate (no solver run).
    static let levels: [Level] = {
        var result: [Level] = []
        for number in numbers {
            let entry: CelestialEclipseLabManifestEntry = CelestialEclipseLabManifest.entries[number - 1]
            let index: Int = CelestialEclipseLabExperienceCore.certifiedCandidates[number - 1]
            if let level = CelestialEclipseLabGenerator.candidate(entry, index: index) { result.append(level) }
        }
        return result
    }()

    /// A playing snapshot of `level` with tick `tick` shown (default choice).
    static func playing(_ level: Level, tick: Int) throws -> Snapshot {
        let play: CelestialEclipseLabPlay = try CelestialEclipseLabExperienceCore.freshPlay(of: level)
        return Snapshot(play: play, chosenBody: -1, shownTick: tick, levelNumber: 1, time: 0)
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

    /// The lens of the camera drawn for `snapshot` in a view of `size` from `orbit`.
    static func lens(_ snapshot: Snapshot, size: SIMD2<Double>, orbit: Orbit) -> Lens {
        let camera: CelestialEclipseLabCamera = G.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
        let forward: SIMD3<Double> = unit(camera.target - camera.eye)
        let side: SIMD3<Double> = SIMD3(-forward.z, 0, forward.x)
        let right: SIMD3<Double> = unit(side)
        let ux: Double = right.y * forward.z - right.z * forward.y
        let uy: Double = right.z * forward.x - right.x * forward.z
        let uz: Double = right.x * forward.y - right.y * forward.x
        let up: SIMD3<Double> = SIMD3(ux, uy, uz)
        return Lens(eye: camera.eye, forward: forward, right: right, up: up, tanHalf: tan(camera.fovY / 2),
                    aspect: camera.aspect, size: size)
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

    /// The radius in view points of world radius `radius` at `p` through `lens`.
    static func radius(_ radius: Double, at p: SIMD3<Double>, _ lens: Lens) -> Double {
        radius / (dot(p - lens.eye, lens.forward) * lens.tanHalf) * lens.size.y / 2
    }

    /// The independent pick (see the header).
    static func expectedPick(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> CelestialEclipseLabPick {
        var best: Int? = nil
        var bestDistance: Double = Double.infinity
        for body in snapshot.bodies.indices {
            let centre: SIMD3<Double> = G.bodyCentre(body, snapshot)
            guard let c = screen(centre, lens) else { continue }
            let reach: Double = radius(G.bodyRadius(body, snapshot), at: centre, lens) + 8
            guard distance(point, c) <= reach else { continue }
            let fromEye: Double = dot(centre - lens.eye, centre - lens.eye).squareRoot()
            if fromEye < bestDistance || (fromEye == bestDistance && body > (best ?? -1)) {
                best = body
                bestDistance = fromEye
            }
        }
        if let body = best { return .body(body) }
        if let box = expectedDialBox(snapshot, lens), point.x >= box.low.x - 8, point.x <= box.high.x + 8,
           point.y >= box.low.y - 8, point.y <= box.high.y + 8 {
            return .dial
        }
        return .empty
    }

    /// The x of tick `tick` on the strip: −0.9 + 1.8 · tick / (horizon − 1).
    static func tickX(_ tick: Int, _ snapshot: Snapshot) -> Double {
        -0.9 + 1.8 * Double(tick) / Double(max(snapshot.horizon - 1, 1))
    }

    /// The box of the projected strip ends (y −1.15) and bracket ends (y −1.05, the window's ticks ∓ 0.012).
    static func expectedDialBox(_ snapshot: Snapshot, _ lens: Lens) -> (low: SIMD2<Double>, high: SIMD2<Double>)? {
        var points: [SIMD3<Double>] = [SIMD3(-0.9, -1.15, 0), SIMD3(0.9, -1.15, 0)]
        for target in snapshot.target {
            points.append(SIMD3(tickX(target.open, snapshot) - 0.012, -1.05, 0))
            points.append(SIMD3(tickX(target.close, snapshot) + 0.012, -1.05, 0))
        }
        var low: SIMD2<Double> = SIMD2(Double.infinity, Double.infinity)
        var high: SIMD2<Double> = SIMD2(-Double.infinity, -Double.infinity)
        for p in points {
            guard let q = screen(p, lens) else { return nil }
            low = SIMD2(min(low.x, q.x), min(low.y, q.y))
            high = SIMD2(max(high.x, q.x), max(high.y, q.y))
        }
        return (low, high)
    }

    /// The independent dial tick: the tick whose projected place on the strip (x = −0.9 + 1.8 · tick / (horizon − 1),
    /// y = −1.15) is nearest to the point, the lower tick on ties.
    static func expectedTick(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> Int {
        let last: Int = max(snapshot.horizon - 1, 1)
        var best: Int = 0
        var bestDistance: Double = Double.infinity
        for tick in 0...last {
            let x: Double = -0.9 + 1.8 * Double(tick) / Double(last)
            guard let q = screen(SIMD3(x, -1.15, 0), lens) else { continue }
            let e: Double = distance(point, q)
            if e < bestDistance {
                best = tick
                bestDistance = e
            }
        }
        return best
    }

    /// The independent ring offset: the phase whose orbit position at the shown tick projects nearest (lower on ties).
    static func expectedOffset(_ point: SIMD2<Double>, body: Int, _ snapshot: Snapshot, _ lens: Lens) -> Int {
        let b: Body = snapshot.bodies[body]
        var best: Int = 0
        var bestDistance: Double = Double.infinity
        for p in 0..<b.period {
            let v: V = b.orbit[(snapshot.shownTick + p) % b.period]
            guard let q = screen(G.world(v, snapshot), lens) else { continue }
            let e: Double = distance(point, q)
            if e < bestDistance {
                best = p
                bestDistance = e
            }
        }
        return best
    }

    // MARK: Tests

    @Test func fiveHundredSeededTouchesMatchTheIndependentRule() throws {
        #expect(Self.levels.count == Self.numbers.count)
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var bodies: Int = 0
        var dials: Int = 0
        var empties: Int = 0
        for k in 0..<500 {
            let level: Level = Self.levels[k % Self.levels.count]
            let size: SIMD2<Double> = Self.sizes[(k / Self.levels.count) % Self.sizes.count]
            let orbit: Orbit = Self.orbits[(k / (Self.levels.count * Self.sizes.count)) % Self.orbits.count]
            let snap: Snapshot = try Self.playing(level, tick: random.int(0...(level.horizon - 1)))
            let lens: Lens = Self.lens(snap, size: size, orbit: orbit)
            var point: SIMD2<Double> = SIMD2(random.range(0...size.x), random.range(0...size.y))
            let kind: Int = k % 3
            if kind == 0 {
                // Near a body: within its projected radius plus 14 points.
                let body: Int = random.int(0...(level.bodies.count - 1))
                let centre: SIMD3<Double> = G.bodyCentre(body, snap)
                let c: SIMD2<Double> = try #require(Self.screen(centre, lens))
                let reach: Double = Self.radius(G.bodyRadius(body, snap), at: centre, lens) + 14
                let angle: Double = random.range(0...(2 * Double.pi))
                point = c + SIMD2(cos(angle), sin(angle)) * random.range(0...reach)
            } else if kind == 1 {
                // Near the dial: the strip's box grown by 20 points.
                let box: (low: SIMD2<Double>, high: SIMD2<Double>) = try #require(Self.expectedDialBox(snap, lens))
                point = SIMD2(random.range((box.low.x - 20)...(box.high.x + 20)),
                              random.range((box.low.y - 20)...(box.high.y + 20)))
            }
            let expected: CelestialEclipseLabPick = Self.expectedPick(point, snap, lens)
            let picked: CelestialEclipseLabPick = P.pick(point, size: size, snapshot: snap, orbit: orbit)
            #expect(picked == expected, "touch \(k) \(level.id) \(size) \(orbit)")
            switch expected {
            case .body: bodies += 1
            case .dial: dials += 1
            case .empty: empties += 1
            }
            #expect(P.dialTick(point, size: size, snapshot: snap, orbit: orbit) == Self.expectedTick(point, snap, lens),
                    "tick \(k)")
            let body: Int = random.int(0...(level.bodies.count - 1))
            #expect(P.ringOffset(point, body: body, size: size, snapshot: snap, orbit: orbit)
                    == Self.expectedOffset(point, body: body, snap, lens), "ring \(k)")
        }
        #expect(bodies >= 80 && dials >= 40 && empties >= 50, "\(bodies) \(dials) \(empties)")
    }

    @Test func eightPointAllowanceHitsAtSevenAndMissesAtNine() throws {
        var hits: Int = 0
        var misses: Int = 0
        for level in Self.levels.prefix(4) {
            let snap: Snapshot = try Self.playing(level, tick: 0)
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let lens: Lens = Self.lens(snap, size: size, orbit: orbit)
                    for body in level.bodies.indices {
                        let centre: SIMD3<Double> = G.bodyCentre(body, snap)
                        let c: SIMD2<Double> = try #require(Self.screen(centre, lens))
                        let r: Double = Self.radius(G.bodyRadius(body, snap), at: centre, lens)
                        for step in 0..<8 {
                            let angle: Double = Double(step) * Double.pi / 4 + 0.1
                            let direction: SIMD2<Double> = SIMD2(cos(angle), sin(angle))
                            let inner: SIMD2<Double> = c + direction * (r + 7)
                            let outer: SIMD2<Double> = c + direction * (r + 9)
                            let near: CelestialEclipseLabPick = P.pick(inner, size: size, snapshot: snap, orbit: orbit)
                            let far: CelestialEclipseLabPick = P.pick(outer, size: size, snapshot: snap, orbit: orbit)
                            #expect(near == Self.expectedPick(inner, snap, lens))
                            #expect(far == Self.expectedPick(outer, snap, lens))
                            // Where no other body reaches either touch, the 7-point touch is this body and the
                            // 9-point touch is empty (or the dial).
                            var others: Bool = false
                            for other in level.bodies.indices where other != body {
                                let oc: SIMD3<Double> = G.bodyCentre(other, snap)
                                guard let q = Self.screen(oc, lens) else { continue }
                                let reach: Double = Self.radius(G.bodyRadius(other, snap), at: oc, lens) + 8
                                if Self.distance(inner, q) <= reach || Self.distance(outer, q) <= reach {
                                    others = true
                                }
                            }
                            if !others {
                                #expect(near == .body(body))
                                hits += 1
                                if far != .dial {
                                    #expect(far == .empty)
                                    misses += 1
                                }
                            }
                        }
                    }
                }
            }
        }
        #expect(hits >= 100 && misses >= 100, "\(hits) \(misses)")
        #expect(P.bodyAllowance == 8)
    }

    @Test func frontMostBodyWinsWhicheverIndexIsNearer() throws {
        // Two concentric bodies: one radius 3 at depth 10 (nearer the eye), one radius 5 at depth 0.
        for nearIndex in [0, 1] {
            let near: Body = Body(orbit: Array(repeating: V(0, 0, 10), count: 4), radius: 3)
            let far: Body = Body(orbit: Array(repeating: V(1, 0, 0), count: 4), radius: 5)
            let bodies: [Body] = nearIndex == 0 ? [near, far] : [far, near]
            let target: [CelestialEclipseLabTarget] = [
                CelestialEclipseLabTarget(front: nearIndex, back: 1 - nearIndex, open: 0, close: 7),
            ]
            let level: Level = try Level.probe(bodies: bodies, horizon: 8, target: target, phases: [0, 0])
            let snap: Snapshot = Snapshot(play: CelestialEclipseLabPlay(level: level), chosenBody: -1, shownTick: 0,
                                          levelNumber: 1, time: 0)
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                    let nearPoint: SIMD2<Double> = try #require(P.viewPoint(G.bodyCentre(nearIndex, snap), size: size,
                                                                           camera: camera))
                    #expect(P.pick(nearPoint, size: size, snapshot: snap, orbit: orbit) == .body(nearIndex))
                    // The far body still wins outside the near body's reach but inside its own.
                    let farCentre: SIMD3<Double> = G.bodyCentre(1 - nearIndex, snap)
                    let farPoint: SIMD2<Double> = try #require(P.viewPoint(farCentre, size: size, camera: camera))
                    let farRadius: Double = try #require(P.projectedRadius(G.bodyRadius(1 - nearIndex, snap),
                                                                           at: farCentre, size: size, camera: camera))
                    let apart: Double = Self.distance(farPoint, nearPoint)
                    var direction: SIMD2<Double> = SIMD2(1, 0)
                    if apart > 0 { direction = (farPoint - nearPoint) / apart }
                    let edge: SIMD2<Double> = farPoint + direction * farRadius
                    let lens: Lens = Self.lens(snap, size: size, orbit: orbit)
                    let picked: CelestialEclipseLabPick = P.pick(edge, size: size, snapshot: snap, orbit: orbit)
                    #expect(picked == Self.expectedPick(edge, snap, lens))
                }
            }
        }
    }

    @Test func dialTicksAndRingOffsetsAtTheirOwnPoints() throws {
        for level in Self.levels.prefix(4) {
            let snap: Snapshot = try Self.playing(level, tick: 2)
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                    for tick in 0..<level.horizon {
                        let q: SIMD2<Double> = try #require(P.viewPoint(G.tickPosition(tick, snap), size: size,
                                                                        camera: camera))
                        #expect(P.dialTick(q, size: size, snapshot: snap, orbit: orbit) == tick)
                        #expect(P.pick(q, size: size, snapshot: snap, orbit: orbit) != .empty)
                    }
                    let start: SIMD2<Double> = try #require(P.viewPoint(G.tickPosition(0, snap), size: size,
                                                                        camera: camera))
                    let end: SIMD2<Double> = try #require(P.viewPoint(G.tickPosition(level.horizon - 1, snap),
                                                                      size: size, camera: camera))
                    #expect(P.dialTick(start + (start - end), size: size, snapshot: snap, orbit: orbit) == 0)
                    #expect(P.dialTick(end + (end - start), size: size, snapshot: snap, orbit: orbit)
                            == level.horizon - 1)
                    for body in level.bodies.indices {
                        let b: Body = level.bodies[body]
                        for p in 0..<b.period {
                            let q: SIMD2<Double> = try #require(P.viewPoint(G.ringPosition(body, offset: p, snap),
                                                                            size: size, camera: camera))
                            let offset: Int = P.ringOffset(q, body: body, size: size, snapshot: snap, orbit: orbit)
                            // The same orbit position (the lowest phase on a repeated position).
                            #expect(offset <= p)
                            #expect(b.position(at: 2, phase: offset) == b.position(at: 2, phase: p))
                        }
                    }
                }
            }
        }
    }

    @Test func unusableInputIsEmpty() throws {
        let level: Level = Self.levels[0]
        let snap: Snapshot = try Self.playing(level, tick: 3)
        let body: Int = Snapshot.defaultChoice(level)
        let good: SIMD2<Double> = SIMD2(390, 844)
        let points: [SIMD2<Double>] = [SIMD2(.nan, 10), SIMD2(10, .infinity), SIMD2(-.infinity, .nan)]
        for point in points {
            #expect(P.pick(point, size: good, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.dialTick(point, size: good, snapshot: snap, orbit: .authored) == 3)
            #expect(P.ringOffset(point, body: body, size: good, snapshot: snap, orbit: .authored) == snap.phases[body])
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 100), SIMD2(100, 0), SIMD2(-5, 100), SIMD2(.nan, 100),
                                      SIMD2(100, .infinity)]
        for size in sizes {
            #expect(P.pick(SIMD2(10, 10), size: size, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.dialTick(SIMD2(10, 10), size: size, snapshot: snap, orbit: .authored) == 3)
            #expect(P.ringOffset(SIMD2(10, 10), body: body, size: size, snapshot: snap, orbit: .authored)
                    == snap.phases[body])
            #expect(P.viewPoint(SIMD3(0, 0, 0), size: size, camera: G.camera(snap, aspect: 1)) == nil)
            #expect(P.camera(size: size, snapshot: snap, orbit: .authored) == nil)
        }
        #expect(P.ringOffset(SIMD2(10, 10), body: -1, size: good, snapshot: snap, orbit: .authored) == 0)
        #expect(P.ringOffset(SIMD2(10, 10), body: 99, size: good, snapshot: snap, orbit: .authored) == 0)
        // Behind the eye: no view point. Far outside the view: empty.
        let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: good.x / good.y)
        #expect(P.viewPoint(camera.eye + (camera.eye - camera.target), size: good, camera: camera) == nil)
        #expect(P.pick(SIMD2(-5_000, -5_000), size: good, snapshot: snap, orbit: .authored) == .empty)
        // An orbit beyond the bounds picks as the clamped orbit.
        let wild: Orbit = Orbit(yaw: 9, pitch: -9)
        let point: SIMD2<Double> = SIMD2(200, 400)
        #expect(P.pick(point, size: good, snapshot: snap, orbit: wild)
                == P.pick(point, size: good, snapshot: snap, orbit: wild.clamped()))
    }
}
