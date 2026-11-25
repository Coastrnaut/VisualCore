// CelestialEclipseLabSceneGeometryTests — feature 463 (R02-G17-03) T-R02G1703-004 (FR-R02G1703-001, 002, 004, 006;
// SC-R02G1703-001, 003; clarifications Q1, Q2). The sky from snapshots: finite and bounded for extreme settings (2 and
// 6 bodies, coordinates ±32, radius 8, horizons 8 and 96, budgets 1 and 24); every disc at every orbit position (so at
// every tick for every phase), the elements and the gauges inside the view with a 5 % margin at 7 aspects over a sample
// of catalog candidates (levels 1, 21, 41, 61, 81 and the first two entries of every band); the same positions at every
// tier; the bodies exactly at w of the kernel's positions for the shown tick; a crescent shadow lens for exactly the
// kernel's eclipses under way, inside both circles with the analytic overlap area; halos only for total and annular
// eclipses; gauges at 0, half and the full budget; a won level lit and in place; the glow empty at level-2 with its
// shell counts per tier; the paint order sorted with the tie rule; each failure kind (unwanted, window, horizon)
// marked. Seed 2_463; explicit types, plain loops; each test well under 10 s; no wall-clock asserts.
// Feature 464 (R02-G17-04) T-R02G1704-002 (FR-R02G1704-001, 004, 006; SC-R02G1704-004): the orbit's bounds and
// clamping; `camera(_:aspect:)` equal to `camera(_:aspect:orbit: .authored)` bit for bit; the eye outside the box and
// the box within the fitted margin at the orbit corners; every element, every disc at every orbit position and a ghost
// at every orbit position inside the view at the orbit corners and 7 aspects; the ghost (material 17 at the disc
// radius, right after the bodies) and the preview timeline equal to the kernel's; without a preview (and with the
// authored camera) the same meshes as before.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import CelestialEclipseLabCore

struct CelestialEclipseLabSceneGeometryTests {
    typealias G = CelestialEclipseLabSceneGeometry
    typealias Snapshot = CelestialEclipseLabSceneSnapshot
    typealias Level = CelestialEclipseLabLevel
    typealias V = CelestialEclipseLabVector
    typealias Body = CelestialEclipseLabBody
    typealias Target = CelestialEclipseLabTarget

    /// The feature's test seed.
    static let seed: UInt64 = 2_463

    /// The seven aspects checked.
    static let aspects: [Double] = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]

    /// A sample of catalog levels: the first valid candidate of entries 1, 21, 41, 61, 81 and of the first two entries
    /// of every band.
    static let catalogLevels: [Level] = {
        var numbers: [Int] = [1, 21, 41, 61, 81]
        for band in 1...5 {
            var taken: Int = 0
            for entry in CelestialEclipseLabManifest.entries where entry.band == band && taken < 2 {
                if !numbers.contains(entry.number) { numbers.append(entry.number) }
                taken += 1
            }
        }
        var levels: [Level] = []
        for entry in CelestialEclipseLabManifest.entries where numbers.contains(entry.number) {
            for index in 0..<64 {
                if let level = CelestialEclipseLabGenerator.candidate(entry, index: index) {
                    levels.append(level)
                    break
                }
            }
        }
        return levels
    }()

    /// Seeded fixtures (levels with known winning phases).
    static let fixtures: [CelestialEclipseLabFixture] = CelestialEclipseLabFixture.all(count: 10, seed: seed)

    /// A level of the given values without the "already won" rule (every other rule checked).
    static func level(_ id: String, bodies: [Body], horizon: Int, target: [Target], phases: [Int],
                      budget: Int) throws -> Level {
        try Level(id: id, seed: seed, difficulty: 1, bodies: bodies, horizon: horizon, target: target, phases: phases,
                  budget: budget, tutorial: false, refusingAWin: false)
    }

    /// An extreme level: `count` bodies of radius 8 on the corners (±32, ±32) (body i starting at corner i mod 4),
    /// body i at depths 30 − 12 i and 28 − 12 i, body 0 fixed; horizon `horizon`, budget `budget`.
    static func extremeLevel(bodies count: Int, horizon: Int, budget: Int) throws -> Level {
        let corners: [(Int, Int)] = [(-32, -32), (32, -32), (32, 32), (-32, 32)]
        var bodies: [Body] = []
        for i in 0..<count {
            var orbit: [V] = []
            for k in 0..<4 {
                let c: (Int, Int) = corners[(i + k) % 4]
                orbit.append(V(c.0, c.1, 30 - 12 * i - 2 * (k % 2)))
            }
            bodies.append(Body(orbit: orbit, radius: 8, fixed: i == 0))
        }
        return try level("extreme-\(count)-\(horizon)-\(budget)", bodies: bodies, horizon: horizon,
                         target: [Target(front: 0, back: 1, open: 0, close: horizon - 1)],
                         phases: Array(repeating: 0, count: count), budget: budget)
    }

    /// The extreme levels: 2 and 6 bodies × horizons 8 and 96 × budgets 1 and 24.
    static func extremeLevels() throws -> [Level] {
        var levels: [Level] = []
        for count in [2, 6] {
            for horizon in [8, 96] {
                for budget in [1, 24] {
                    levels.append(try extremeLevel(bodies: count, horizon: horizon, budget: budget))
                }
            }
        }
        return levels
    }

    /// The hand-made level (horizon 8): body 0 (radius 4, fixed, depth 20) at (−20, −20) for ticks 0 … 2 and (20, 20)
    /// at tick 3; body 1 (radius 1, depth 10) at (0, 0), (2, 0), (4, 0), (20, 20); body 2 (radius 4, depth 0) at the
    /// origin. Phases 0: ticks 0 and 1 annular (1 over 2), tick 2 partial (1 over 2), tick 3 total (0 over 1); the
    /// intervals are (1, 2) at 0, (0, 1) at 3, (1, 2) at 4 and (0, 1) at 7.
    static func handLevel(target: [Target], budget: Int = 4) throws -> Level {
        let bodies: [Body] = [
            Body(orbit: [V(-20, -20, 20), V(-20, -20, 20), V(-20, -20, 20), V(20, 20, 20)], radius: 4, fixed: true),
            Body(orbit: [V(0, 0, 10), V(2, 0, 10), V(4, 0, 10), V(20, 20, 10)], radius: 1),
            Body(orbit: [V(0, 0, 0), V(0, 0, 0), V(0, 0, 0), V(0, 0, 0)], radius: 4),
        ]
        return try level("hand", bodies: bodies, horizon: 8, target: target, phases: [0, 0, 0], budget: budget)
    }

    /// The hand level whose prediction fails `unwanted` (body 1 over 2 at tick 0 before the target 0 over 1).
    static func unwantedLevel() throws -> Level {
        try handLevel(target: [Target(front: 0, back: 1, open: 3, close: 3)])
    }

    /// The hand level whose prediction fails `window` (1 over 2 at tick 0, window 5 … 7).
    static func windowLevel() throws -> Level { try handLevel(target: [Target(front: 1, back: 2, open: 5, close: 7)]) }

    /// The hand level whose prediction fails `horizon` (four events matched, the fifth target never comes).
    static func horizonLevel() throws -> Level {
        try handLevel(target: [Target(front: 1, back: 2, open: 0, close: 0),
                               Target(front: 0, back: 1, open: 3, close: 3),
                               Target(front: 1, back: 2, open: 4, close: 4),
                               Target(front: 0, back: 1, open: 7, close: 7),
                               Target(front: 1, back: 2, open: 7, close: 7)])
    }

    /// The hand level whose starting phases win (1 over 2 at tick 0).
    static func winningLevel() throws -> Level { try handLevel(target: [Target(front: 1, back: 2, open: 0, close: 0)]) }

    /// A play of `level` started (stage playing).
    static func started(_ level: Level) throws -> CelestialEclipseLabPlay {
        var play: CelestialEclipseLabPlay = CelestialEclipseLabPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The snapshot of `play` at `tick` (default choice).
    static func snapshot(_ play: CelestialEclipseLabPlay, tick: Int = 0) -> Snapshot {
        Snapshot(play: play, chosenBody: -1, shownTick: tick, levelNumber: 1, time: 0)
    }

    /// The snapshot of a fresh play of `level` at `tick`.
    static func snapshot(_ level: Level, tick: Int = 0) -> Snapshot {
        snapshot(CelestialEclipseLabPlay(level: level), tick: tick)
    }

    /// The position of vertex `index` of `mesh`.
    static func point(_ mesh: Mesh, _ index: Int) -> SIMD3<Double> {
        SIMD3(mesh.positions[index].x, mesh.positions[index].y, mesh.positions[index].z)
    }

    /// The vertex indices of `mesh` with material `code` (and local coordinate `local` when given).
    static func vertices(_ mesh: Mesh, _ code: Double, local: Double? = nil) -> [Int] {
        var found: [Int] = []
        for index in mesh.uvs.indices where mesh.uvs[index].x == code {
            if let l = local, mesh.uvs[index].y != l { continue }
            found.append(index)
        }
        return found
    }

    /// The triangle count of `mesh` whose first vertex has material `code`.
    static func triangles(_ mesh: Mesh, _ code: Double) -> Int {
        var count: Int = 0
        for t in stride(from: 0, to: mesh.indices.count, by: 3) where mesh.uvs[Int(mesh.indices[t])].x == code {
            count += 1
        }
        return count
    }

    /// The positions of every vertex of `mesh` whose material is not `code`, in order.
    static func positions(_ mesh: Mesh, except code: Double) -> [SIMD3<Double>] {
        var list: [SIMD3<Double>] = []
        for index in mesh.positions.indices where mesh.uvs[index].x != code { list.append(point(mesh, index)) }
        return list
    }

    /// The length of `v`.
    static func length(_ v: SIMD3<Double>) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }

    /// Whether `q` lies inside the view with a 5 % margin.
    static func inside(_ q: SIMD2<Double>?) -> Bool {
        guard let p = q else { return false }
        return p.x >= 0.05 && p.x <= 0.95 && p.y >= 0.05 && p.y <= 0.95
    }

    /// The elements of `snapshot` (aspect 1) that draw `part`.
    static func elements(_ snapshot: Snapshot,
                         _ part: CelestialEclipseLabElement.Part) -> [CelestialEclipseLabElement] {
        var found: [CelestialEclipseLabElement] = []
        for element in G.paintOrder(snapshot, camera: G.camera(snapshot, aspect: 1)) where element.part == part {
            found.append(element)
        }
        return found
    }

    /// The vertices of `mesh` with material `code` within `radius` of `centre`.
    static func near(_ mesh: Mesh, _ code: Double, _ centre: SIMD3<Double>, _ radius: Double) -> Int {
        var count: Int = 0
        for index in vertices(mesh, code) where length(point(mesh, index) - centre) <= radius { count += 1 }
        return count
    }

    // MARK: Tests

    @Test func finiteAndBoundedForExtremeSettings() throws {
        let levels: [Level] = try Self.extremeLevels()
        #expect(levels.count == 8)
        for level in levels {
            for tick in [0, level.horizon / 2, level.horizon - 1] {
                let snap: Snapshot = Self.snapshot(level, tick: tick)
                let s: Double = G.scale(snap)
                #expect(abs(s - 1.5 / 81) < 1e-12)
                for eclipse in snap.eclipses {
                    for q in G.shadowLens(eclipse, snap) { #expect(abs(q.x) <= 0.75 && abs(q.y) <= 0.75) }
                }
                for tier in CelestialEclipseLabTier.all {
                    let mesh: Mesh = try G.skyMesh(snap, tier: tier)
                    #expect(mesh.triangleCount > 0 && mesh.triangleCount < 20_000, "\(mesh.triangleCount)")
                    for index in mesh.positions.indices {
                        let p: SIMD3<Double> = Self.point(mesh, index)
                        let n: Vec3 = mesh.normals[index]
                        #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
                        #expect(n.x.isFinite && n.y.isFinite && n.z.isFinite)
                        #expect(mesh.uvs[index].x.isFinite && mesh.uvs[index].y.isFinite)
                        if mesh.uvs[index].x != G.materialBackdrop {
                            #expect(abs(p.x) <= 1.0 && p.y >= -1.5 && p.y <= 1.0 && abs(p.z) <= 1.0, "\(p)")
                        }
                    }
                    let glow: Mesh = try G.glowMesh(snap, tier: tier)
                    for index in glow.positions.indices {
                        let p: SIMD3<Double> = Self.point(glow, index)
                        #expect(abs(p.x) <= 1.0 && p.y >= -1.5 && p.y <= 1.0 && abs(p.z) <= 1.0, "\(p)")
                    }
                }
            }
        }
    }

    @Test func everyDiscAndGaugeInsideTheViewAtSevenAspects() throws {
        let levels: [Level] = Self.catalogLevels
        #expect(levels.count >= 10)
        for level in levels {
            let snap: Snapshot = Self.snapshot(level)
            let s: Double = G.scale(snap)
            for aspect in Self.aspects {
                let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: aspect)
                let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = G.viewBasis(camera)
                let directions: [SIMD3<Double>] = [basis.right, basis.up, basis.right * -1, basis.up * -1]
                var outside: Int = 0
                for body in level.bodies {
                    // Every orbit position is the body's place at some tick for some phase; the reach covers the disc,
                    // its notches, the chosen ring and a failure outline.
                    let reach: Double = Double(body.radius) * s + G.outlineOffset + G.outlineWidth / 2
                    for v in body.orbit {
                        let c: SIMD3<Double> = G.world(v, snap)
                        if !Self.inside(G.project(c, camera: camera)) { outside += 1 }
                        for d in directions where !Self.inside(G.project(c + d * reach, camera: camera)) {
                            outside += 1
                        }
                    }
                }
                for element in G.paintOrder(snap, camera: camera) {
                    if !Self.inside(G.project(element.centre, camera: camera)) { outside += 1 }
                }
                var gauge: [SIMD3<Double>] = []
                let markReach: Double = G.markFrame + G.outlineWidth
                for sy in [-1.0, 1.0] {
                    gauge.append(G.tickPosition(0, snap) + basis.up * markReach * sy)
                    gauge.append(G.tickPosition(level.horizon - 1, snap) + basis.up * markReach * sy)
                    gauge.append(SIMD3(G.gaugeStart, G.barsY + G.barHeight / 2 * sy, 0))
                    gauge.append(SIMD3(G.gaugeEnd, G.barsY + G.barHeight / 2 * sy, 0))
                }
                gauge.append(G.tickPosition(0, snap) - basis.right * markReach)
                gauge.append(G.tickPosition(level.horizon - 1, snap) + basis.right * markReach)
                for k in level.target.indices { gauge.append(G.bracketCentre(k, snap) + basis.up * 0.04) }
                for p in gauge where !Self.inside(G.project(p, camera: camera)) { outside += 1 }
                #expect(outside == 0, "\(level.id) aspect \(aspect)")
            }
        }
    }

    @Test func cameraIsTheAuthoredOneAndProjectRefusesBehind() throws {
        let snap: Snapshot = Self.snapshot(try Self.unwantedLevel())
        let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: 1.5)
        #expect(camera.eye == SIMD3(0.3, 0.2, 3.4) && camera.target == SIMD3(0, -0.25, 0))
        #expect(camera.fovY > 0 && camera.fovY < Double.pi && camera.aspect == 1.5)
        #expect(G.camera(snap, aspect: .nan).aspect == 1 && G.camera(snap, aspect: 100).aspect == 10)
        let centre: SIMD2<Double>? = G.project(camera.target, camera: camera)
        #expect(centre != nil && abs(centre!.x - 0.5) < 1e-9 && abs(centre!.y - 0.5) < 1e-9)
        #expect(G.project(SIMD3(0.3, 0.2, 6), camera: camera) == nil)
        #expect(G.project(SIMD3(.nan, 0, 0), camera: camera) == nil)
    }

    @Test func samePositionsAtEveryTier() throws {
        var levels: [Level] = []
        for fixture in Self.fixtures.prefix(6) { levels.append(fixture.level) }
        levels.append(try Self.horizonLevel())
        for level in levels {
            let snap: Snapshot = Self.snapshot(level, tick: 1)
            let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: 1)
            let reference: [SIMD3<Double>] = Self.positions(try G.skyMesh(snap, tier: .of(0)), except: G.materialBody)
            let order: [CelestialEclipseLabElement] = G.paintOrder(snap, camera: camera)
            for tier in CelestialEclipseLabTier.all {
                let mesh: Mesh = try G.skyMesh(snap, tier: tier)
                #expect(Self.positions(mesh, except: G.materialBody) == reference, "\(level.id) \(tier.name)")
                #expect(G.paintOrder(snap, camera: camera) == order)
                for b in level.bodies.indices {
                    let c: SIMD3<Double> = G.bodyCentre(b, snap)
                    var found: Int = 0
                    for index in Self.vertices(mesh, G.materialBody) {
                        let p: SIMD3<Double> = Self.point(mesh, index)
                        if tier.flatBodies {
                            if mesh.uvs[index].y == 0 && p == c { found += 1 }
                        } else if mesh.normals[index] == Vec3(0, 1, 0)
                                    && Self.length(p - (c + SIMD3(0, G.bodyRadius(b, snap), 0))) < 1e-12 {
                            found += 1   // the north pole of body b's sphere
                        }
                    }
                    #expect(found == 1, "\(level.id) \(tier.name) body \(b)")
                }
            }
        }
    }

    @Test func bodiesExactlyAtTheKernelPositionsForTheShownTick() throws {
        for fixture in Self.fixtures {
            let level: Level = fixture.level
            for tick in 0..<level.horizon {
                let snap: Snapshot = Self.snapshot(level, tick: tick)
                for b in level.bodies.indices {
                    let kernel: V = level.bodies[b].position(at: tick, phase: level.phases[b])
                    #expect(snap.positions[b] == kernel)
                    #expect(G.bodyCentre(b, snap) == G.world(kernel, snap))
                    #expect(G.bodyRadius(b, snap) == Double(level.bodies[b].radius) * G.scale(snap))
                }
            }
            let snap: Snapshot = Self.snapshot(level, tick: level.horizon - 1)
            let mesh: Mesh = try G.skyMesh(snap, tier: .of(2))
            var centres: [SIMD3<Double>] = []
            for index in Self.vertices(mesh, G.materialBody, local: 0) { centres.append(Self.point(mesh, index)) }
            #expect(centres.count == level.bodies.count)
            for b in level.bodies.indices { #expect(centres.contains(G.bodyCentre(b, snap))) }
        }
    }

    @Test func discsFitTheWidenedBox() throws {
        var levels: [Level] = Self.catalogLevels
        levels.append(contentsOf: try Self.extremeLevels())
        for level in levels {
            let snap: Snapshot = Self.snapshot(level)
            let s: Double = G.scale(snap)
            var largest: Double = 0
            for body in level.bodies {
                let r: Double = Double(body.radius) * s
                for v in body.orbit {
                    let c: SIMD3<Double> = G.world(v, snap)
                    largest = max(largest, abs(c.x) + r, abs(c.y) + r, abs(c.z))
                }
            }
            #expect(largest <= 0.75 + 1e-12, "\(level.id)")
        }
    }

    /// The analytic area of the overlap of circles (a, ra) and (b, rb).
    static func overlapArea(_ a: SIMD2<Double>, _ ra: Double, _ b: SIMD2<Double>, _ rb: Double) -> Double {
        let d: Double = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
        if d >= ra + rb { return 0 }
        if d <= abs(ra - rb) { return Double.pi * min(ra, rb) * min(ra, rb) }
        let ca: Double = (d * d + ra * ra - rb * rb) / (2 * d * ra)
        let cb: Double = (d * d + rb * rb - ra * ra) / (2 * d * rb)
        let k: Double = (-d + ra + rb) * (d + ra - rb) * (d - ra + rb) * (d + ra + rb)
        return ra * ra * acos(ca) + rb * rb * acos(cb) - 0.5 * k.squareRoot()
    }

    /// The area of the polygon `outline` (shoelace, absolute).
    static func polygonArea(_ outline: [SIMD2<Double>]) -> Double {
        var twice: Double = 0
        for k in outline.indices {
            let p: SIMD2<Double> = outline[k]
            let q: SIMD2<Double> = outline[(k + 1) % outline.count]
            twice += p.x * q.y - q.x * p.y
        }
        return abs(twice) / 2
    }

    @Test func shadowLensInsideBothCirclesWithTheAnalyticArea() throws {
        var levels: [Level] = []
        for fixture in Self.fixtures { levels.append(fixture.level) }
        levels.append(try Self.horizonLevel())
        var seen: [CelestialEclipseLabVisibility: Int] = [:]
        for level in levels {
            for tick in 0..<level.horizon {
                let snap: Snapshot = Self.snapshot(level, tick: tick)
                for eclipse in snap.eclipses {
                    let fc: SIMD3<Double> = G.bodyCentre(eclipse.front, snap)
                    let bc: SIMD3<Double> = G.bodyCentre(eclipse.back, snap)
                    let a: SIMD2<Double> = SIMD2(fc.x, fc.y)
                    let b: SIMD2<Double> = SIMD2(bc.x, bc.y)
                    let ra: Double = G.bodyRadius(eclipse.front, snap)
                    let rb: Double = G.bodyRadius(eclipse.back, snap)
                    let lens: [SIMD2<Double>] = G.shadowLens(eclipse, snap)
                    #expect(lens.count == 48, "\(level.id) tick \(tick)")
                    let tolerance: Double = 1e-9 * max(1, ra + rb)
                    var outside: Int = 0
                    for q in lens {
                        let da: Double = ((q.x - a.x) * (q.x - a.x) + (q.y - a.y) * (q.y - a.y)).squareRoot()
                        let db: Double = ((q.x - b.x) * (q.x - b.x) + (q.y - b.y) * (q.y - b.y)).squareRoot()
                        if da > ra + tolerance || db > rb + tolerance { outside += 1 }
                    }
                    #expect(outside == 0, "\(level.id) tick \(tick)")
                    let expected: Double
                    switch eclipse.visibility {
                    case .total: expected = Double.pi * rb * rb
                    case .annular: expected = Double.pi * ra * ra
                    case .partial: expected = Self.overlapArea(a, ra, b, rb)
                    }
                    #expect(expected > 0 && abs(Self.polygonArea(lens) - expected) <= 0.01 * expected,
                            "\(level.id) tick \(tick) \(eclipse.visibility)")
                    seen[eclipse.visibility, default: 0] += 1
                }
            }
        }
        #expect((seen[.partial] ?? 0) > 0 && (seen[.total] ?? 0) > 0 && (seen[.annular] ?? 0) > 0)
    }

    @Test func noShadowForPairsNotUnderWay() throws {
        let level: Level = try Self.horizonLevel()
        for tick in 0..<level.horizon {
            let snap: Snapshot = Self.snapshot(level, tick: tick)
            for front in level.bodies.indices {
                for back in level.bodies.indices where back != front {
                    for visibility in CelestialEclipseLabVisibility.allCases {
                        let e: CelestialEclipseLabEclipse = CelestialEclipseLabEclipse(front: front, back: back,
                                                                                       visibility: visibility)
                        let lens: [SIMD2<Double>] = G.shadowLens(e, snap)
                        #expect(lens.isEmpty == !snap.eclipses.contains(e), "tick \(tick) \(front) \(back)")
                    }
                }
            }
            var shadows: Int = 0
            for element in Self.elements(snap, .shadow) {
                #expect(element.kind == .body && element.centre == G.bodyCentre(snap.eclipses[element.item].back, snap))
                shadows += 1
            }
            #expect(shadows == snap.eclipses.count)
            let mesh: Mesh = try G.skyMesh(snap, tier: .of(1))
            #expect(Self.triangles(mesh, G.materialShadow) == 48 * snap.eclipses.count)
        }
        // Tick 0: body 1 (radius 1, depth 10) annular over body 2 (radius 4, depth 0): the shadow is body 1's disc in
        // the plane just in front of body 2, painted right after body 2 and before body 1.
        let snap: Snapshot = Self.snapshot(level, tick: 0)
        let mesh: Mesh = try G.skyMesh(snap, tier: .of(0))
        let z: Double = G.shadowZ(snap.eclipses[0], snap)
        #expect(z > G.bodyCentre(2, snap).z && z < G.bodyCentre(1, snap).z)
        for index in Self.vertices(mesh, G.materialShadow) { #expect(abs(Self.point(mesh, index).z - z) < 1e-12) }
        var positions: [CelestialEclipseLabElement.Part: Int] = [:]
        var back: Int = -1
        var front: Int = -1
        for (k, element) in G.paintOrder(snap, camera: G.camera(snap, aspect: 1)).enumerated() {
            if element.part == .shadow { positions[.shadow] = k }
            if element.part == .body && element.item == 2 { back = k }
            if element.part == .body && element.item == 1 { front = k }
        }
        #expect(back >= 0 && positions[.shadow] == back + 1 && front > back + 1)
    }

    @Test func halosOnlyForTotalAndAnnular() throws {
        let level: Level = try Self.horizonLevel()
        let expected: [Int?] = [1, 1, nil, 0]   // the halo's front body per tick 0 … 3
        for tick in 0..<4 {
            let snap: Snapshot = Self.snapshot(level, tick: tick)
            let halos: [CelestialEclipseLabElement] = Self.elements(snap, .halo)
            let mesh: Mesh = try G.skyMesh(snap, tier: .of(1))
            if let front = expected[tick] {
                #expect(halos.count == 1)
                #expect(halos.first?.centre == G.bodyCentre(front, snap))
                #expect(Self.triangles(mesh, G.materialHalo) == 2 * G.ringSegments)
            } else {
                #expect(halos.isEmpty && snap.eclipses.count == 1 && snap.eclipses[0].visibility == .partial)
                #expect(Self.triangles(mesh, G.materialHalo) == 0)
            }
        }
        var seen: Int = 0
        for fixture in Self.fixtures {
            for tick in 0..<fixture.level.horizon {
                let snap: Snapshot = Self.snapshot(fixture.level, tick: tick)
                var wanted: Int = 0
                for eclipse in snap.eclipses where eclipse.visibility != .partial { wanted += 1 }
                let halos: [CelestialEclipseLabElement] = Self.elements(snap, .halo)
                #expect(halos.count == wanted)
                for halo in halos { #expect(snap.eclipses[halo.item].visibility != .partial) }
                seen += wanted
            }
        }
        #expect(seen > 0)
    }

    @Test func gaugesAtZeroHalfAndFullBudget() throws {
        let level: Level = try Self.extremeLevel(bodies: 2, horizon: 8, budget: 24)
        var play: CelestialEclipseLabPlay = try Self.started(level)
        for spent in 0...24 {
            if spent == 0 || spent == 12 || spent == 24 {
                let snap: Snapshot = Self.snapshot(play)
                let lit: Int = 24 - spent
                #expect(G.litActions(snap) == lit)
                let mesh: Mesh = try G.skyMesh(snap, tier: .of(0))
                #expect(Self.triangles(mesh, G.materialBar) == 4 * lit)
                #expect(Self.triangles(mesh, G.materialBarUnlit) == 4 * (24 - lit))
                let bars: [CelestialEclipseLabElement] = Self.elements(snap, .bar)
                #expect(bars.count == 24)
                let slot: Double = G.actionsSlot(snap)
                #expect(abs(slot - 0.075) < 1e-12)
                #expect(abs(G.actionsBar(0, snap).x - (-0.9 + slot / 2)) < 1e-12)
                #expect(abs(G.actionsBar(23, snap).x - (0.9 - slot / 2)) < 1e-12 && G.actionsBar(23, snap).y == -1.35)
            }
            if spent < 24 {
                let offset: Int = (play.phases[1] + 1) % level.bodies[1].period
                try play.apply(.phase(1, offset), expecting: play.fingerprint)
            }
        }
        #expect(play.actionsLeft == 0)
        let single: Snapshot = Self.snapshot(try Self.extremeLevel(bodies: 2, horizon: 8, budget: 1))
        #expect(G.actionsBar(0, single) == SIMD3(0, -1.35, 0) && G.litActions(single) == 1)
        // The timeline: ticks 0 … horizon − 1 from x −0.9 to 0.9 at y −1.15; the playhead at the shown tick.
        let snap: Snapshot = Self.snapshot(level, tick: 5)
        #expect(G.tickPosition(0, snap) == SIMD3(-0.9, -1.15, 0))
        #expect(Self.length(G.tickPosition(7, snap) - SIMD3(0.9, -1.15, 0)) < 1e-12)
        #expect(G.timelineCentre() == SIMD3(0, -1.15, 0) && G.playhead(snap) == G.tickPosition(5, snap))
        #expect(G.bracketCentre(0, snap).y == -1.05)
    }

    @Test func wonLevelLitAndInPlace() throws {
        var play: CelestialEclipseLabPlay = try Self.started(try Self.winningLevel())
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.stage == .won)
        let snap: Snapshot = Self.snapshot(play)
        #expect(G.isWon(snap) && snap.failure == nil && snap.matched == 1)
        for tier in CelestialEclipseLabTier.all {
            let won: CelestialEclipseLabColouredMesh = try G.skyPart(snap, tier: tier)
            let plain: CelestialEclipseLabColouredMesh = try G.skyPart(snap, tier: tier, wonLevel: false)
            #expect(won.mesh == plain.mesh)
            let brackets: [Int] = Self.vertices(won.mesh, G.materialBracket)
            #expect(!brackets.isEmpty)
            for index in brackets {
                let lit: Vec4 = won.colours[index]
                let unlit: Vec4 = plain.colours[index]
                let gold: SIMD3<Double> = CelestialEclipseLabPalette.matched
                let window: SIMD3<Double> = CelestialEclipseLabPalette.window
                #expect(abs(lit.x - gold.x) < 1e-12 && abs(lit.y - gold.y) < 1e-12 && abs(lit.z - gold.z) < 1e-12)
                #expect(abs(unlit.x - window.x) < 1e-12 && abs(unlit.z - window.z) < 1e-12)
            }
            #expect(Self.triangles(won.mesh, G.materialDiamond) == 4)
            #expect(Self.vertices(won.mesh, G.materialBroken).isEmpty)
            // The matched eclipse under way at tick 0 (1 over 2, annular) flags its halo.
            let halos: [Int] = Self.vertices(won.mesh, G.materialHalo)
            #expect(!halos.isEmpty)
            for index in halos { #expect(won.mesh.normals[index].x == 1) }
        }
        #expect(G.isMatched(snap.eclipses[0], snap))
        let marks: [CelestialEclipseLabElement] = Self.elements(snap, .mark)
        #expect(marks.count == 4)
        for mark in marks {
            let expected: Double = mark.item == 0 ? G.materialDiamond : G.materialFaint
            #expect(G.markMaterial(mark.item, snap) == expected)
        }
    }

    @Test func glowEmptyAtLevelTwoAndShellCountsPerTier() throws {
        var play: CelestialEclipseLabPlay = try Self.started(try Self.winningLevel())
        try play.apply(.run, expecting: play.fingerprint)
        let snap: Snapshot = Self.snapshot(play)
        #expect(G.glowObjects(snap) == 3)   // the annular halo at tick 0, the chosen ring, the matched mark
        let shells: [Int] = [2, 1, 0]
        for tier in CelestialEclipseLabTier.all {
            #expect(tier.glowShells == shells[tier.index])
            let glow: CelestialEclipseLabColouredMesh = try G.glowPart(snap, tier: tier)
            #expect(glow.mesh.triangleCount == tier.glowShells * G.glowObjects(snap) * G.glowSides * 2)
            #expect(glow.colours.count == glow.mesh.positions.count)
            var codes: Set<Double> = []
            for uv in glow.mesh.uvs { codes.insert(uv.x) }
            var expected: Set<Double> = []
            for k in stride(from: tier.glowShells, through: 1, by: -1) {
                for kind in [G.glowMatchedHalo, G.glowChosen, G.glowMark] {
                    expected.insert(G.glowCode(kind: kind, factor: pow(0.5, Double(k))))
                }
            }
            #expect(codes == expected)
        }
        #expect(try G.glowMesh(snap, tier: .of(2)).positions.isEmpty)
    }

    @Test func paintOrderSortedWithTheTieRule() throws {
        var snapshots: [Snapshot] = []
        for fixture in Self.fixtures.prefix(6) { snapshots.append(Self.snapshot(fixture.level, tick: 2)) }
        snapshots.append(Self.snapshot(try Self.horizonLevel(), tick: 0))
        for snap in snapshots {
            let order: [CelestialEclipseLabElement] = G.paintOrder(snap, camera: G.camera(snap, aspect: 1.3))
            for k in 1..<order.count {
                #expect(!CelestialEclipseLabElement.paintsBefore(order[k], order[k - 1]))
                #expect(order[k].kind.rawValue >= order[k - 1].kind.rawValue)
                let byDistance: Bool = order[k].kind == .body || order[k].kind == .halo
                if byDistance && order[k].kind == order[k - 1].kind {
                    #expect(order[k].distance <= order[k - 1].distance)
                }
            }
            var keys: Set<Int> = []
            for element in order { keys.insert(element.kind.rawValue * 100_000 + element.index) }
            #expect(keys.count == order.count)
        }
        // Ties: same centre, so kind (ring, body, halo, gauge) then index decide.
        let c: SIMD3<Double> = SIMD3(0, 0, 0)
        typealias E = CelestialEclipseLabElement
        let ring: E = E(kind: .ring, index: 3, part: .chosen, item: 1, centre: c, distance: 2)
        let body: E = E(kind: .body, index: 1, part: .body, item: 1, centre: c, distance: 2)
        let halo: E = E(kind: .halo, index: 0, part: .halo, item: 0, centre: c, distance: 2)
        let gauge: E = E(kind: .gauge, index: 0, part: .strip, item: 0, centre: c, distance: 2)
        let low: E = E(kind: .body, index: 0, part: .body, item: 0, centre: c, distance: 2)
        let far: E = E(kind: .gauge, index: 9, part: .bar, item: 0, centre: c, distance: 3)
        #expect(E.paintsBefore(ring, body))
        #expect(E.paintsBefore(body, halo))
        #expect(E.paintsBefore(halo, gauge))
        #expect(E.paintsBefore(low, body) && !E.paintsBefore(body, low))
        // The kind comes first: a farther gauge still paints after a nearer ring; flat gauges go by index alone.
        #expect(E.paintsBefore(ring, far) && !E.paintsBefore(far, ring))
        let nearStrip: E = E(kind: .gauge, index: 0, part: .strip, item: 0, centre: c, distance: 1)
        #expect(E.paintsBefore(nearStrip, far))
        let farBody: E = E(kind: .body, index: 5, part: .body, item: 5, centre: c, distance: 3)
        #expect(E.paintsBefore(farBody, low))
        // In the hand level at tick 0 the chosen ring (body 1), body 1 and its halo share a centre.
        let snap: Snapshot = Self.snapshot(try Self.horizonLevel(), tick: 0)
        let order: [CelestialEclipseLabElement] = G.paintOrder(snap, camera: G.camera(snap, aspect: 1))
        var chosen: Int = -1
        var front: Int = -1
        var halo1: Int = -1
        for (k, element) in order.enumerated() {
            if element.part == .chosen { chosen = k }
            if element.part == .body && element.item == 1 { front = k }
            if element.part == .halo { halo1 = k }
        }
        #expect(snap.chosenBody == 1 && chosen >= 0 && chosen < front && front < halo1)
        // The reference points: bodies, the strip, brackets, the playhead and the first bar, in paint order.
        let points: [CelestialEclipseLabElement] = G.referencePoints(snap, camera: G.camera(snap, aspect: 1))
        #expect(points.count == 3 + 1 + 5 + 1 + 1)
        for k in 1..<points.count { #expect(!CelestialEclipseLabElement.paintsBefore(points[k], points[k - 1])) }
    }

    @Test func unwantedFailureMarked() throws {
        let snap: Snapshot = Self.snapshot(try Self.unwantedLevel())
        #expect(snap.failure == .unwanted(front: 1, back: 2, tick: 0))
        try Self.expectEventFailure(snap, interval: 0)
    }

    @Test func windowFailureMarked() throws {
        let snap: Snapshot = Self.snapshot(try Self.windowLevel())
        #expect(snap.failure == .window(front: 1, back: 2, tick: 0, open: 5, close: 7))
        try Self.expectEventFailure(snap, interval: 0)
    }

    /// Checks an event failure: the failing interval's cross framed in the broken colour, the two bodies outlined, no
    /// end mark.
    static func expectEventFailure(_ snap: Snapshot, interval: Int) throws {
        #expect(G.failingInterval(snap) == interval)
        #expect(G.markMaterial(interval, snap) == G.materialCross)
        #expect(elements(snap, .endMark).isEmpty && G.framedBracket(snap) == nil)
        let mesh: Mesh = try G.skyMesh(snap, tier: .of(0))
        let at: SIMD3<Double> = G.tickPosition(snap.intervals[interval].first, snap)
        #expect(triangles(mesh, G.materialCross) == 4)
        #expect(near(mesh, G.materialCross, at, G.markSize + 0.01) == vertices(mesh, G.materialCross).count)
        #expect(near(mesh, G.materialBroken, at, (G.markFrame + G.outlineWidth) * 1.5) == 8)   // a welded frame
        try expectOutlined(mesh, snap)
    }

    /// Checks that the failure's two bodies are ringed in the broken colour at r · s + 0.075.
    static func expectOutlined(_ mesh: Mesh, _ snap: Snapshot) throws {
        guard let pair = G.failureBodies(snap) else {
            Issue.record("no failure bodies")
            return
        }
        for b in [pair.front, pair.back] {
            let r: Double = G.bodyRadius(b, snap) + G.outlineOffset
            var ring: Int = 0
            for index in vertices(mesh, G.materialBroken) {
                let d: Double = length(point(mesh, index) - G.bodyCentre(b, snap))
                if abs(d - r) <= G.outlineWidth / 2 + 1e-9 { ring += 1 }
            }
            #expect(ring >= 2 * G.ringSegments, "body \(b)")
        }
    }

    @Test func horizonFailureMarked() throws {
        let snap: Snapshot = Self.snapshot(try Self.horizonLevel())
        #expect(snap.failure == .horizon(front: 1, back: 2, open: 7, close: 7) && snap.matched == 4)
        #expect(G.failingInterval(snap) == nil && G.framedBracket(snap) == 4)
        let ends: [CelestialEclipseLabElement] = Self.elements(snap, .endMark)
        #expect(ends.count == 1 && ends.first?.centre == G.tickPosition(7, snap))
        let mesh: Mesh = try G.skyMesh(snap, tier: .of(1))
        #expect(Self.triangles(mesh, G.materialCross) == 0)
        #expect(Self.near(mesh, G.materialBroken, G.tickPosition(7, snap), G.markSize + 0.01) >= 8)
        // The framed bracket: the 8 welded broken frame vertices around target 4's bracket.
        let framed: SIMD3<Double> = G.bracketCentre(4, snap)
        var around: Int = 0
        for index in Self.vertices(mesh, G.materialBroken) {
            let p: SIMD3<Double> = Self.point(mesh, index)
            if abs(p.y - framed.y) < 0.06 && abs(p.x - framed.x) < 0.1 { around += 1 }
        }
        #expect(around == 8)
        try Self.expectOutlined(mesh, snap)
        var marks: [Double] = []
        for mark in Self.elements(snap, .mark).sorted(by: { $0.item < $1.item }) {
            marks.append(G.markMaterial(mark.item, snap))
        }
        #expect(marks == [G.materialDiamond, G.materialDiamond, G.materialDiamond, G.materialDiamond])
    }

    @Test func fallbackColoursFollowTheMaterials() throws {
        let part: CelestialEclipseLabColouredMesh = try G.skyPart(Self.snapshot(try Self.unwantedLevel()), tier: .of(2))
        for index in part.mesh.positions.indices where part.mesh.uvs[index].x != G.materialBackdrop {
            let c: SIMD3<Double> = G.colour(of: part.mesh.uvs[index].x)
            let v: Vec4 = part.colours[index]
            #expect(abs(v.x - c.x) < 1e-12 && abs(v.y - c.y) < 1e-12 && abs(v.z - c.z) < 1e-12 && v.w == 1)
        }
        var codes: Set<Double> = []
        for code in 0..<G.materialCount { codes.insert(Double(code)) }
        for uv in part.mesh.uvs { #expect(codes.contains(uv.x)) }
        #expect(G.colour(of: G.materialBody) == CelestialEclipseLabPalette.disc)
        #expect(G.colour(of: G.materialBar) == CelestialEclipseLabPalette.actionsLit)
    }

    // MARK: Feature 464 (R02-G17-04) T-R02G1704-002

    typealias Orbit = CelestialEclipseLabOrbit

    /// The authored orbit and the four orbit corners.
    static let orbitCorners: [Orbit] = {
        var list: [Orbit] = [.authored]
        for yaw in [-Orbit.yawLimit, Orbit.yawLimit] {
            for pitch in [Orbit.pitchRange.lowerBound, Orbit.pitchRange.upperBound] {
                list.append(Orbit(yaw: yaw, pitch: pitch))
            }
        }
        return list
    }()

    /// A playing snapshot of `level` at `tick` (default choice).
    static func playing(_ level: Level, tick: Int = 0) throws -> Snapshot {
        snapshot(try started(level), tick: tick)
    }

    /// The first movable body of `level`.
    static func movable(_ level: Level) -> Int {
        for (index, body) in level.bodies.enumerated() where !body.fixed { return index }
        return 0
    }

    /// The index in `mesh.indices` / 3 of every triangle whose first vertex has material `code`, in order.
    static func triangleOrder(_ mesh: Mesh, _ code: Double) -> [Int] {
        var found: [Int] = []
        for t in stride(from: 0, to: mesh.indices.count, by: 3) where mesh.uvs[Int(mesh.indices[t])].x == code {
            found.append(t / 3)
        }
        return found
    }

    @Test func orbitBoundsAndTheAuthoredCameraBitForBit() throws {
        #expect(abs(Orbit.yawLimit - Double.pi / 3) < 1e-15)
        #expect(abs(Orbit.pitchRange.lowerBound + Double.pi / 9) < 1e-15)
        #expect(abs(Orbit.pitchRange.upperBound - 35 * Double.pi / 180) < 1e-15)
        #expect(Orbit.authored == Orbit(yaw: 0, pitch: 0) && Orbit.authored.isWithinBounds)
        #expect(Orbit(yaw: 3, pitch: 3).clamped() == Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound))
        #expect(Orbit(yaw: -3, pitch: -3).clamped()
                == Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound))
        #expect(Orbit(yaw: .nan, pitch: .infinity).clamped() == .authored)
        #expect(!Orbit(yaw: 3, pitch: 0).isWithinBounds && !Orbit(yaw: 0, pitch: .nan).isWithinBounds)
        for orbit in Self.orbitCorners { #expect(orbit.isWithinBounds && orbit.clamped() == orbit) }
        let snap: Snapshot = Self.snapshot(try Self.unwantedLevel())
        var aspects: [Double] = Self.aspects
        aspects.append(contentsOf: [Double.nan, 40, -1])
        for aspect in aspects {
            #expect(G.camera(snap, aspect: aspect) == G.camera(snap, aspect: aspect, orbit: .authored))
            let unusable: Orbit = Orbit(yaw: .nan, pitch: .nan)
            #expect(G.camera(snap, aspect: aspect) == G.camera(snap, aspect: aspect, orbit: unusable))
        }
        let authored: CelestialEclipseLabCamera = G.camera(snap, aspect: 1, orbit: .authored)
        #expect(authored.eye == SIMD3(0.3, 0.2, 3.4) && authored.target == SIMD3(0, -0.25, 0))
        #expect(G.camera(snap, aspect: 1, orbit: Orbit(yaw: 3, pitch: 3))
                == G.camera(snap, aspect: 1, orbit: Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound)))
        // An orbit keeps the eye's distance from the look-at point; yaw turns about the box centre's vertical axis.
        let base: Double = Self.length(authored.eye - authored.target)
        for orbit in Self.orbitCorners {
            let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: 1, orbit: orbit)
            #expect(abs(Self.length(camera.eye - camera.target) - base) < 1e-12)
            #expect(abs(camera.target.x) < 1e-12 && abs(camera.target.z) < 1e-12)
            #expect(abs(camera.target.y + 0.25) < 1e-12)
        }
        let yawed: CelestialEclipseLabCamera = G.camera(snap, aspect: 1, orbit: Orbit(yaw: Orbit.yawLimit, pitch: 0))
        #expect(abs(yawed.eye.y - authored.eye.y) < 1e-12 && yawed.eye.x > authored.eye.x)
        let raised: CelestialEclipseLabCamera = G.camera(snap, aspect: 1, orbit: Orbit(yaw: 0, pitch: 0.3))
        #expect(raised.eye.y > authored.eye.y)
        // The eye outside the box and every box corner within the fitted margin at every orbit corner and aspect.
        for orbit in Self.orbitCorners {
            for aspect in Self.aspects {
                let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: aspect, orbit: orbit)
                let e: SIMD3<Double> = camera.eye
                let inBox: Bool = e.x >= G.boxLow.x && e.x <= G.boxHigh.x && e.y >= G.boxLow.y && e.y <= G.boxHigh.y
                    && e.z >= G.boxLow.z && e.z <= G.boxHigh.z
                #expect(!inBox, "\(orbit)")
                #expect(camera.fovY.isFinite && camera.fovY > 0 && camera.fovY < Double.pi)
                for index in 0..<8 {
                    let q: SIMD2<Double> = try #require(G.project(G.corner(index), camera: camera))
                    #expect(q.x >= 0.06 - 1e-9 && q.x <= 0.94 + 1e-9 && q.y >= 0.06 - 1e-9 && q.y <= 0.94 + 1e-9)
                }
            }
        }
    }

    @Test func everyElementAndGhostInsideTheViewAtTheOrbitCorners() throws {
        let levels: [Level] = Array(Self.catalogLevels.prefix(8))
        #expect(levels.count == 8)
        for level in levels {
            let snap: Snapshot = try Self.playing(level)
            let s: Double = G.scale(snap)
            let body: Int = Self.movable(level)
            var ghosts: [SIMD3<Double>] = []
            for offset in 0..<level.bodies[body].period {
                let preview: Snapshot = snap.previewing(body: body, offset: offset)
                ghosts.append(try #require(G.ghostCentre(preview)))
            }
            for orbit in Self.orbitCorners {
                for aspect in Self.aspects {
                    let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: aspect, orbit: orbit)
                    let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = G.viewBasis(camera)
                    let directions: [SIMD3<Double>] = [basis.right, basis.up, basis.right * -1, basis.up * -1]
                    var outside: Int = 0
                    for b in level.bodies {
                        // Every orbit position is the body's place (and its ghost's) at some tick for some phase; the
                        // reach covers the disc, the ghost, its notches, the chosen ring and a failure outline.
                        let reach: Double = Double(b.radius) * s + G.outlineOffset + G.outlineWidth / 2
                        for v in b.orbit {
                            let c: SIMD3<Double> = G.world(v, snap)
                            if !Self.inside(G.project(c, camera: camera)) { outside += 1 }
                            for d in directions where !Self.inside(G.project(c + d * reach, camera: camera)) {
                                outside += 1
                            }
                        }
                    }
                    let ghostReach: Double = G.bodyRadius(body, snap) + G.ghostWidth / 2
                    for c in ghosts {
                        for d in directions where !Self.inside(G.project(c + d * ghostReach, camera: camera)) {
                            outside += 1
                        }
                    }
                    for element in G.paintOrder(snap, camera: camera) {
                        if !Self.inside(G.project(element.centre, camera: camera)) { outside += 1 }
                    }
                    var gauge: [SIMD3<Double>] = []
                    let markReach: Double = G.markFrame + G.outlineWidth
                    for sy in [-1.0, 1.0] {
                        gauge.append(G.tickPosition(0, snap) + basis.up * markReach * sy)
                        gauge.append(G.tickPosition(level.horizon - 1, snap) + basis.up * markReach * sy)
                        gauge.append(SIMD3(G.gaugeStart, G.barsY + G.barHeight / 2 * sy, 0))
                        gauge.append(SIMD3(G.gaugeEnd, G.barsY + G.barHeight / 2 * sy, 0))
                    }
                    gauge.append(G.tickPosition(0, snap) - basis.right * markReach)
                    gauge.append(G.tickPosition(level.horizon - 1, snap) + basis.right * markReach)
                    for k in level.target.indices { gauge.append(G.bracketCentre(k, snap) + basis.up * 0.04) }
                    for p in gauge where !Self.inside(G.project(p, camera: camera)) { outside += 1 }
                    #expect(outside == 0, "\(level.id) orbit \(orbit) aspect \(aspect)")
                }
            }
            // The drawn ghost itself (every vertex of material 17) inside the view at the extreme aspects.
            let next: Int = (snap.phases[body] + 1) % level.bodies[body].period
            let preview: Snapshot = snap.previewing(body: body, offset: next)
            for orbit in Self.orbitCorners {
                for aspect in [0.4, 2.5] {
                    let camera: CelestialEclipseLabCamera = G.camera(preview, aspect: aspect, orbit: orbit)
                    let mesh: Mesh = try G.skyMesh(preview, tier: .of(2), camera: camera)
                    let ghost: [Int] = Self.vertices(mesh, G.materialGhost)
                    #expect(!ghost.isEmpty)
                    var outside: Int = 0
                    for index in ghost where !Self.inside(G.project(Self.point(mesh, index), camera: camera)) {
                        outside += 1
                    }
                    #expect(outside == 0, "\(level.id) ghost orbit \(orbit) aspect \(aspect)")
                }
            }
        }
    }

    @Test func ghostAndPreviewTimelineFollowTheKernel() throws {
        var checked: Int = 0
        for fixture in Self.fixtures.prefix(6) {
            let level: Level = fixture.level
            let snap: Snapshot = try Self.playing(level, tick: 1)
            #expect(!snap.isPreviewing && snap.previewBody == nil && snap.previewOffset == nil)
            #expect(snap.previewIntervals == snap.intervals && snap.previewMatched == snap.matched)
            #expect(snap.previewFailure == snap.failure && snap.withoutPreview() == snap)
            #expect(G.ghostCentre(snap) == nil)
            let plain: Mesh = try G.skyMesh(snap, tier: .of(1))
            #expect(Self.vertices(plain, G.materialGhost).isEmpty)
            for body in level.bodies.indices {
                let period: Int = level.bodies[body].period
                if level.bodies[body].fixed {
                    #expect(snap.previewing(body: body, offset: 1) == snap)
                    continue
                }
                for offset in 0..<period {
                    let preview: Snapshot = snap.previewing(body: body, offset: offset)
                    var phases: [Int] = snap.phases
                    phases[body] = offset
                    let kernel: CelestialEclipseLabTimeline = CelestialEclipseLabSky.timeline(level, phases: phases)
                    #expect(preview.isPreviewing && preview.previewBody == body && preview.previewOffset == offset)
                    #expect(preview.previewIntervals == kernel.intervals && preview.previewMatched == kernel.matched)
                    #expect(preview.previewFailure == kernel.failure)
                    // Presentation only: the game state is unchanged.
                    #expect(preview.phases == snap.phases && preview.positions == snap.positions)
                    #expect(preview.intervals == snap.intervals && preview.matched == snap.matched)
                    #expect(preview.failure == snap.failure && preview.eclipses == snap.eclipses)
                    #expect(preview.withoutPreview() == snap)
                    #expect(snap.previewing(body: body, offset: offset + period) == preview)
                    #expect(snap.previewing(body: body, offset: offset - period) == preview)
                    let centre: SIMD3<Double> = try #require(G.ghostCentre(preview))
                    let expected: SIMD3<Double> = G.world(level.bodies[body].position(at: 1, phase: offset), snap)
                    #expect(centre == expected && G.ringPosition(body, offset: offset, snap) == expected)
                    checked += 1
                }
                #expect(G.ringPosition(body, offset: snap.phases[body], snap) == G.bodyCentre(body, snap))
            }
            #expect(snap.previewing(body: -1, offset: 0) == snap && snap.previewing(body: 9, offset: 0) == snap)
        }
        #expect(checked > 20)
        // The ghost: 48 dashed quads of material 17 at the disc radius around the ghost centre, drawn right after the
        // bodies and their shadows and before the halos and gauges; the marks drawn from the preview's timeline.
        for fixture in Self.fixtures.prefix(6) {
            let level: Level = fixture.level
            let snap: Snapshot = try Self.playing(level)
            var body: Int = Self.movable(level)
            for index in level.bodies.indices where !level.bodies[index].fixed {
                if fixture.winning[index] != snap.phases[index] { body = index }
            }
            let preview: Snapshot = snap.previewing(body: body, offset: fixture.winning[body])
            let mesh: Mesh = try G.skyMesh(preview, tier: .of(0))
            #expect(Self.triangles(mesh, G.materialGhost) == 2 * G.ringSegments)
            let centre: SIMD3<Double> = try #require(G.ghostCentre(preview))
            let r: Double = G.bodyRadius(body, preview)
            for index in Self.vertices(mesh, G.materialGhost) {
                let d: Double = Self.length(Self.point(mesh, index) - centre)
                #expect(d >= r - G.ghostWidth / 2 - 1e-9 && d <= r + G.ghostWidth / 2 + 1e-9)
                let a: Double = mesh.normals[index].x
                #expect(a >= 0 && a <= 1 && abs(mesh.uvs[index].y) == 1)
            }
            let ghost: [Int] = Self.triangleOrder(mesh, G.materialGhost)
            let bodies: [Int] = Self.triangleOrder(mesh, G.materialBody) + Self.triangleOrder(mesh, G.materialShadow)
            let later: [Int] = Self.triangleOrder(mesh, G.materialHalo) + Self.triangleOrder(mesh, G.materialStrip)
            let firstGhost: Int = try #require(ghost.first)
            #expect(firstGhost > (bodies.max() ?? -1))
            #expect((ghost.last ?? 0) < (later.min() ?? Int.max))
            #expect(ghost.count == ghost.last! - firstGhost + 1)
            // The marks follow the preview's timeline: matched diamonds, the failing cross, faint diamonds after.
            var marks: [CelestialEclipseLabElement] = []
            for element in G.paintOrder(preview, camera: G.camera(preview, aspect: 1)) where element.part == .mark {
                marks.append(element)
            }
            #expect(marks.count == preview.previewIntervals.count)
            for mark in marks {
                #expect(mark.centre == G.tickPosition(preview.previewIntervals[mark.item].first, preview))
                let material: Double = G.markMaterial(mark.item, preview)
                let interval: CelestialEclipseLabInterval = preview.previewIntervals[mark.item]
                var failing: Bool = false
                switch preview.previewFailure {
                case .unwanted(let front, let back, let tick), .window(let front, let back, let tick, _, _):
                    failing = interval.front == front && interval.back == back && interval.first == tick
                default:
                    break
                }
                if mark.item < preview.previewMatched {
                    #expect(material == G.materialDiamond)
                } else if failing {
                    #expect(material == G.materialCross)
                } else {
                    #expect(material == G.materialFaint)
                }
            }
            var horizon: Bool = false
            if case .horizon = preview.previewFailure { horizon = true }
            #expect(G.isHorizonFailure(preview) == horizon)
            #expect((G.framedBracket(preview) != nil) == horizon)
            let glow: CelestialEclipseLabColouredMesh = try G.glowPart(preview, tier: .of(0))
            #expect(glow.mesh.triangleCount == 2 * G.glowObjects(preview) * G.glowSides * 2)
        }
        // Previewing the current phase draws R02-G17-03's sky plus the ghost.
        let snap: Snapshot = try Self.playing(Self.fixtures[0].level, tick: 2)
        let body: Int = Self.movable(Self.fixtures[0].level)
        let same: Snapshot = snap.previewing(body: body, offset: snap.phases[body])
        #expect(same.previewIntervals == snap.intervals && same.previewMatched == snap.matched)
        for tier in CelestialEclipseLabTier.all {
            let plain: Mesh = try G.skyMesh(snap, tier: tier)
            let ghosted: Mesh = try G.skyMesh(same, tier: tier)
            #expect(Self.positions(ghosted, except: G.materialGhost) == Self.positions(plain, except: G.materialGhost))
            #expect(ghosted.triangleCount == plain.triangleCount + 2 * G.ringSegments)
            #expect(try G.glowMesh(same, tier: tier) == G.glowMesh(snap, tier: tier))
        }
    }

    @Test func noPreviewAndAuthoredCameraDrawTheSameMeshes() throws {
        var snapshots: [Snapshot] = []
        for fixture in Self.fixtures.prefix(4) { snapshots.append(try Self.playing(fixture.level, tick: 3)) }
        snapshots.append(Self.snapshot(try Self.horizonLevel(), tick: 0))
        snapshots.append(Self.snapshot(try Self.unwantedLevel(), tick: 3))
        for snap in snapshots {
            for tier in CelestialEclipseLabTier.all {
                let sky: CelestialEclipseLabColouredMesh = try G.skyPart(snap, tier: tier)
                let glow: CelestialEclipseLabColouredMesh = try G.glowPart(snap, tier: tier)
                #expect(try G.skyPart(snap.withoutPreview(), tier: tier) == sky)
                for aspect in [0.4, 1.0, 2.5] {
                    let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: aspect)
                    #expect(try G.skyPart(snap, tier: tier, camera: camera) == sky)
                    #expect(try G.glowPart(snap, tier: tier, camera: camera) == glow)
                    #expect(try G.skyMesh(snap, tier: tier, camera: camera) == sky.mesh)
                    #expect(try G.glowMesh(snap, tier: tier, camera: camera) == glow.mesh)
                }
            }
        }
        // Another orbit builds the billboards for its eye: a level-2 disc faces that camera; the bodies stay put.
        let snap: Snapshot = snapshots[0]
        let camera: CelestialEclipseLabCamera = G.camera(snap, aspect: 1.2, orbit: Orbit(yaw: 0.7, pitch: 0.4))
        let towards: SIMD3<Double> = G.viewBasis(camera).forward * -1
        let mesh: Mesh = try G.skyMesh(snap, tier: .of(2), camera: camera)
        let authored: Mesh = try G.skyMesh(snap, tier: .of(2))
        #expect(mesh != authored)
        let discs: [Int] = Self.vertices(mesh, G.materialBody, local: 0)
        #expect(discs.count == snap.bodies.count)
        for index in discs {
            let n: Vec3 = mesh.normals[index]
            #expect(abs(n.x - towards.x) < 1e-12 && abs(n.y - towards.y) < 1e-12 && abs(n.z - towards.z) < 1e-12)
            var near: Bool = false
            for body in snap.bodies.indices {
                if Self.length(Self.point(mesh, index) - G.bodyCentre(body, snap)) < 1e-12 { near = true }
            }
            #expect(near)
        }
        let order: [CelestialEclipseLabElement] = G.paintOrder(snap, camera: camera)
        for element in order { #expect(abs(element.distance - Self.length(element.centre - camera.eye)) < 1e-12) }
    }
}
