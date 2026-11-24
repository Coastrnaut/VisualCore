// AcousticConstellatorSceneGeometryTests — feature 423 (R02-G13-03) T-R02G1303-004 (FR-R02G1303-001, 002, 004, 006;
// clarifications Q1 … Q4; SC-R02G1303-003). The constellation geometry of Acoustic Constellator built from real plays
// (hand-made levels and the seeded fixtures of seed 2_423, actions applied through `AcousticConstellatorPlay`): every
// mesh is finite and bounded with one colour per vertex for 3 and 8 stars, 0 and 16 links, every link snapped and none,
// budgets 1 and 40, holds 2 and 12, won and failed plays; every star centre, link check point, gauge bar, threshold mark
// and hold pip projects inside the view with a 5 % margin at seven aspects 0.4 … 2.5; the constellation mesh is the same
// at every tier; links are teal exactly where the kernel's gap at the shown tick is at most 1 and broken exactly where
// the kernel's report snaps them; the moves gauge lights 0, half and all bars; a won level's symbol links and their glow
// are brighter and nothing moves; the glow mesh is empty at level-2 and has 2 wave shells and 2 glow shells at level-0
// and 1 glow shell at level-1; failures outline the missing guide or the snapped link; painter's order holds. Plain
// loops; well under 10 s each.
//
// Feature 424 (R02-G13-04) T-R02G1304-002 (FR-R02G1304-005; SC-R02G1304-004; clarifications Q1, Q4): at the authored
// orbit, the four clamp corners and the centre of the range, at seven aspects 0.4 … 2.5, every star centre, link check
// point, gauge bar, threshold mark and hold pip projects inside the view with a 5 % margin and the fit is tight; pitch
// raises, yaw turns about the box centre; the orbit is clamped; the authored orbit is the fixed camera bit for bit; the
// stars are painted back to front for every orbit (the authored orbit keeps the authored order) and nothing moves; the
// drag filament is finite, teal, 0.01 wide and in place between the star's centre and the world point.
//
// Feature 426 (R02-G13-06) T-R02G1306-005: the won level `won` of `constellationPart` and `glowPart` scales the won
// links' and the won glow's fallback lift monotonically (0: teal links and plain glow; 1 and nil: today's output);
// positions, indices and streams never change.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import AcousticConstellatorCore

@Suite struct AcousticConstellatorSceneGeometryTests {
    typealias Geometry = AcousticConstellatorSceneGeometry
    typealias Snapshot = AcousticConstellatorSceneSnapshot
    typealias Material = AcousticConstellatorMaterial
    typealias Link = AcousticConstellatorLink

    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]
    static let seed: UInt64 = 2_423

    // MARK: Levels and plays

    /// A begun play of `level` (tutorial dismissed) with `actions` applied while the play accepts them.
    static func play(_ level: AcousticConstellatorLevel,
                     _ actions: [AcousticConstellatorAction]) throws -> AcousticConstellatorPlay {
        var play = AcousticConstellatorPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions where play.stage == .playing {
            try play.apply(action, expecting: play.fingerprint)
        }
        return play
    }

    /// Three stars at grid extremes, no fixed links, symbol 0–1 and 1–2, all rate 1 at phase 0: budget `budget`,
    /// hold 2.
    static func threeStars(budget: Int) throws -> AcousticConstellatorLevel {
        let stars: [AcousticConstellatorStar] = [AcousticConstellatorStar(x: 0, y: 0, z: 0, rate: 1, phase: 0),
                                                 AcousticConstellatorStar(x: 11, y: 11, z: 11, rate: 1, phase: 0),
                                                 AcousticConstellatorStar(x: 0, y: 11, z: 5, rate: 1, phase: 0)]
        return try AcousticConstellatorLevel(id: "geometry-three", seed: 1, difficulty: 1, stars: stars, fixedLinks: [],
                                             symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)], coupling: 2,
                                             degreeLimit: 2, linkLimit: 2, snapLimit: 2, threshold: 9, hold: 2,
                                             window: 4, budget: budget)
    }

    /// The 16 pairs of K4,4 between stars 0 … 3 and 4 … 7.
    static let bipartite: [Link] = {
        var pairs: [Link] = []
        for a in 0..<4 { for b in 4..<8 { pairs.append(Link(a: a, b: b)) } }
        return pairs
    }()

    /// The six fixed links of the large levels.
    static let fixedSix: [Link] = [Link(a: 0, b: 4), Link(a: 0, b: 5), Link(a: 0, b: 6), Link(a: 0, b: 7),
                                   Link(a: 1, b: 4), Link(a: 1, b: 5)]

    /// Eight stars at the grid's corners, the six fixed links, a symbol of 7 pairs over all stars, degree limit 4 and
    /// link limit 16 (so K4,4 fits), phases 0; stars 4 … 7 have rate `rateB` (0: nothing snaps and every tick is
    /// coherent; 6: every link snaps on tick 1), the others rate 0; budget 40, hold `hold`.
    static func eightStars(rateB: Int, hold: Int, threshold: Int) throws -> AcousticConstellatorLevel {
        let corners: [(Int, Int, Int)] = [(0, 0, 0), (11, 0, 11), (0, 11, 11), (11, 11, 0), (0, 0, 11), (11, 0, 0),
                                          (0, 11, 0), (11, 11, 11)]
        var stars: [AcousticConstellatorStar] = []
        for (index, c) in corners.enumerated() {
            stars.append(AcousticConstellatorStar(x: c.0, y: c.1, z: c.2, rate: index >= 4 ? rateB : 0, phase: 0))
        }
        let symbol: [Link] = [Link(a: 0, b: 4), Link(a: 1, b: 4), Link(a: 2, b: 4), Link(a: 3, b: 4), Link(a: 0, b: 5),
                              Link(a: 0, b: 6), Link(a: 0, b: 7)]
        return try AcousticConstellatorLevel(id: "geometry-eight-\(rateB)", seed: 2, difficulty: 1, stars: stars,
                                             fixedLinks: fixedSix, symbol: symbol, coupling: 1, degreeLimit: 4,
                                             linkLimit: 16, snapLimit: 2, threshold: threshold, hold: hold,
                                             window: 48, budget: 40)
    }

    /// The actions that place the ten K4,4 pairs that are not fixed.
    static var placeTen: [AcousticConstellatorAction] {
        var actions: [AcousticConstellatorAction] = []
        for pair in bipartite where !fixedSix.contains(pair) { actions.append(.link(pair.a, pair.b)) }
        return actions
    }

    /// 8 stars, 16 links, nothing snaps, hold 12 (the report wins on tick 12); listened (won) when `listen`.
    static func sixteenCalm(listen: Bool, time: Double) throws -> Snapshot {
        let level = try eightStars(rateB: 0, hold: 12, threshold: 64)
        return Snapshot(play: try play(level, placeTen + (listen ? [.listen] : [])), levelNumber: 100, time: time)
    }

    /// 8 stars, 16 links, every link snaps on tick 1, hold 2; listened (failed `disconnected`) when `listen`.
    static func sixteenSnapped(listen: Bool, time: Double) throws -> Snapshot {
        let level = try eightStars(rateB: 6, hold: 2, threshold: 1)
        return Snapshot(play: try play(level, placeTen + (listen ? [.listen] : [])), levelNumber: 99, time: time)
    }

    /// 3 stars, no links, budget 1, nothing played.
    static func threeIdle() throws -> Snapshot {
        Snapshot(play: try play(try threeStars(budget: 1), []), levelNumber: 1, time: 0)
    }

    /// 3 stars, no links, budget 1, listened at once: failed `missing` 0–1.
    static func threeMissing() throws -> Snapshot {
        Snapshot(play: try play(try threeStars(budget: 1), [.listen]), levelNumber: 1, time: 2)
    }

    /// The fixture's known actions as play actions.
    static func actions(_ fixture: AcousticConstellatorFixture) -> [AcousticConstellatorAction] {
        var result: [AcousticConstellatorAction] = []
        for action in fixture.winningActions {
            switch action.kind {
            case "link": result.append(.link(action.a, action.b))
            case "nudge": result.append(.nudge(action.a, action.b))
            default: result.append(.listen)
            }
        }
        return result
    }

    /// The fixtures of seed 2_423: played to a win, played up to their listen, and listened at once (failed).
    static func fixtures() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for (offset, fixture) in AcousticConstellatorFixtures.fixtures(4, from: seed).enumerated() {
            let known: [AcousticConstellatorAction] = actions(fixture)
            let time: Double = 0.3 + 0.55 * Double(offset)
            result.append(Snapshot(play: try play(fixture.level, known), levelNumber: 7, time: time))
            result.append(Snapshot(play: try play(fixture.level, Array(known.dropLast())), levelNumber: 7, time: time))
            result.append(Snapshot(play: try play(fixture.level, [.listen]), levelNumber: 7, time: time))
        }
        return result
    }

    static func snapshots() throws -> [Snapshot] {
        var all: [Snapshot] = [try threeIdle(), try threeMissing()]
        for time in [0, 0.85, 3.3] {
            all.append(try sixteenCalm(listen: false, time: time))
            all.append(try sixteenCalm(listen: true, time: time))
        }
        for time in [0, 0.3] {
            all.append(try sixteenSnapped(listen: false, time: time))
            all.append(try sixteenSnapped(listen: true, time: time))
        }
        all.append(contentsOf: try fixtures())
        return all
    }

    // MARK: Helpers

    static func code(_ m: Mesh, _ k: Int) -> Int { Int(m.uvs[k].x.rounded()) }

    static func luminance(_ c: Vec4) -> Double { 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z }

    static func isLink(_ code: Int) -> Bool {
        code == Material.silverLink.rawValue || code == Material.tealLink.rawValue || code == Material.wonLink.rawValue
    }

    /// The triangles whose first vertex has code `material`.
    static func triangles(_ m: Mesh, _ material: Material) -> Int {
        var count: Int = 0
        var t: Int = 0
        while t < m.indices.count {
            if code(m, Int(m.indices[t])) == material.rawValue { count += 1 }
            t += 3
        }
        return count
    }

    /// The vertices of link `index`'s strip (link materials with item `index`).
    static func linkVertices(_ m: Mesh, _ index: Int) -> [Int] {
        var result: [Int] = []
        for k in m.positions.indices where isLink(code(m, k)) && Int(m.normals[k].y.rounded()) == index {
            result.append(k)
        }
        return result
    }

    /// Whether link `index` snaps on or before `tick`, read directly from the kernel's report.
    static func kernelSnapped(_ s: Snapshot, _ index: Int, _ tick: Int) -> Bool {
        for step in s.report.snapped.indices where step <= tick && s.report.snapped[step].contains(index) { return true }
        return false
    }

    /// The size of link `index`'s gap at `tick`, read directly from the kernel's report.
    static func kernelGap(_ s: Snapshot, _ index: Int, _ tick: Int) -> Int {
        let phases: [Int] = s.report.phases[min(tick, s.report.phases.count - 1)]
        let link: Link = s.links[index]
        return abs(AcousticConstellatorClock.gap(phases[link.a], phases[link.b]))
    }

    /// The glow kind of a glow-mesh vertex: ⌊uv.x / 2⌋ (factor 0 … 1 added to 2 · kind).
    static func kind(_ m: Mesh, _ k: Int) -> Int { min(Int(m.uvs[k].x / 2), 2) }

    /// The triangles of the glow mesh whose first vertex has glow kind `kind`.
    static func glowTriangles(_ m: Mesh, _ kind: AcousticConstellatorGlowKind) -> Int {
        var count: Int = 0
        var t: Int = 0
        while t < m.indices.count {
            if Self.kind(m, Int(m.indices[t])) == kind.rawValue { count += 1 }
            t += 3
        }
        return count
    }

    /// The positions rounded to 1e-7, as a set of keys.
    static func keys(_ m: Mesh) -> Set<String> {
        var keys: Set<String> = []
        for p in m.positions { keys.insert("\((p.x * 1e7).rounded()),\((p.y * 1e7).rounded()),\((p.z * 1e7).rounded())") }
        return keys
    }

    static func finite(_ v: Vec3) -> Bool { v.x.isFinite && v.y.isFinite && v.z.isFinite }

    // MARK: Snapshots

    @Test func handMadeSnapshotsHaveTheirExtremes() throws {
        let idle: Snapshot = try Self.threeIdle()
        #expect(idle.stars.count == 3 && idle.links.isEmpty && idle.budget == 1 && idle.hold == 2)
        let calm: Snapshot = try Self.sixteenCalm(listen: false, time: 0)
        #expect(calm.stars.count == 8 && calm.links.count == 16 && calm.budget == 40 && calm.hold == 12)
        #expect(calm.report.snappedCount == 0 && calm.report.won && calm.ticks == 13)
        let won: Snapshot = try Self.sixteenCalm(listen: true, time: 0)
        #expect(won.stage == .won)
        let snapped: Snapshot = try Self.sixteenSnapped(listen: false, time: 0.3)
        #expect(snapped.shownTick == 1 && snapped.report.snapped[1].count == 16)
        let disconnected: Snapshot = try Self.sixteenSnapped(listen: true, time: 0)
        #expect(disconnected.failure == .disconnected(tick: 1, link: Link(a: 0, b: 4)))
        #expect(try Self.threeMissing().failure == .missing(Link(a: 0, b: 1)))
        let fixtures: [Snapshot] = try Self.fixtures()
        for index in stride(from: 0, to: fixtures.count, by: 3) {
            #expect(fixtures[index].stage == .won && fixtures[index + 1].stage == .playing)
            #expect(fixtures[index + 2].stage == .failed)
        }
    }

    // MARK: Finite and bounded

    @Test func finiteAndBoundedForExtremeSettings() throws {
        for s in try Self.snapshots() {
            for tier in AcousticConstellatorTier.all {
                for reduceMotion in [false, true] {
                    let parts: [AcousticConstellatorColouredMesh] = [
                        try Geometry.constellationPart(s, tier: tier, reduceMotion: reduceMotion),
                        try Geometry.glowPart(s, tier: tier, reduceMotion: reduceMotion),
                    ]
                    let meshes: [Mesh] = [try Geometry.constellationMesh(s, tier: tier, reduceMotion: reduceMotion),
                                          try Geometry.glowMesh(s, tier: tier, reduceMotion: reduceMotion)]
                    #expect(meshes[0] == parts[0].mesh && meshes[1] == parts[1].mesh)
                    #expect(meshes[0].indices.count / 3 < 3_000)
                    // The sky is the lowest constellation layer (y = −0.01); a glow shell around a star on the lowest
                    // layer (bottom at 0.04 − 0.035 − 2 · 0.012) may reach y = −0.019, drawn additively over the sky.
                    for part in parts {
                        let m: Mesh = part.mesh
                        #expect(part.colours.count == m.positions.count)
                        #expect(m.normals.count == m.positions.count && m.uvs.count == m.positions.count)
                        #expect(m.indices.count % 3 == 0)
                        for index in m.indices { #expect(Int(index) < m.positions.count) }
                        for k in m.positions.indices {
                            let p: Vec3 = m.positions[k]
                            #expect(Self.finite(p) && Self.finite(m.normals[k]))
                            #expect(m.uvs[k].x.isFinite && m.uvs[k].y.isFinite)
                            #expect(p.x >= -1.1 && p.x <= 1.1 && p.y >= -0.025 && p.y <= 0.34 && p.z >= -0.9
                                        && p.z <= 1.3)
                            let c: Vec4 = part.colours[k]
                            #expect(c.x >= 0 && c.x <= 1 && c.y >= 0 && c.y <= 1 && c.z >= 0 && c.z <= 1 && c.w == 1)
                        }
                    }
                }
            }
        }
    }

    // MARK: Inside the view

    @Test func everyPlaceIsInsideTheViewAtSevenAspects() throws {
        for s in try Self.snapshots() {
            var points: [SIMD3<Double>] = []
            for index in s.stars.indices { points.append(Geometry.starCentre(index, s)) }
            for index in s.links.indices { points.append(Geometry.linkCheckPoint(index, s)) }
            for index in 0..<Geometry.coherenceCount { points.append(Geometry.coherenceBar(index, s)) }
            points.append(Geometry.thresholdMark(s))
            for index in 0..<s.hold { points.append(Geometry.holdPip(index, s)) }
            for index in 0..<s.budget { points.append(Geometry.movesBar(index, s)) }
            for aspect in Self.aspects {
                let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: aspect)
                for point in points {
                    let p: SIMD2<Double>? = Geometry.project(point, camera: camera)
                    #expect(p != nil)
                    if let p { #expect(p.x >= 0.05 && p.x <= 0.95 && p.y >= 0.05 && p.y <= 0.95) }
                }
            }
        }
    }

    @Test func checkPointsLieBesideTheirStrips() throws {
        let s: Snapshot = try Self.sixteenCalm(listen: false, time: 0)
        for index in s.links.indices {
            let on: SIMD3<Double> = Geometry.linkPoint(index, u: 0.25, s)
            let check: SIMD3<Double> = Geometry.linkCheckPoint(index, s)
            let d: SIMD3<Double> = check - on
            #expect(abs((d * d).sum().squareRoot() - 0.015) < 1e-12 && abs(d.y) < 1e-12)
        }
        let a: SIMD3<Double> = Geometry.starCentre(0, s)
        #expect(a == SIMD3(-5.5 * 0.14, 0.15 - 5.5 * 0.02, -5.5 * 0.11))
        let m: Mesh = try Geometry.constellationMesh(s, tier: AcousticConstellatorTier.of(0), reduceMotion: false)
        for k in m.positions.indices where Self.code(m, k) == Material.star.rawValue {
            let star: Int = Int(m.uvs[k].y.rounded())
            let n: Vec3 = m.normals[k]
            let c: SIMD3<Double> = Geometry.starCentre(star, s)
            #expect(abs(n.x * n.x + n.y * n.y + n.z * n.z - 1) < 1e-9)
            #expect(abs(m.positions[k].x - (c.x + 0.045 * n.x)) < 1e-9 && abs(m.positions[k].y - (c.y + 0.035 * n.y)) < 1e-9
                        && abs(m.positions[k].z - (c.z + 0.045 * n.z)) < 1e-9)
        }
    }

    // MARK: Tiers

    @Test func constellationIsTheSameAtEveryTier() throws {
        for s in try Self.snapshots() {
            for reduceMotion in [false, true] {
                let first: AcousticConstellatorColouredMesh = try Geometry.constellationPart(
                    s, tier: AcousticConstellatorTier.of(0), reduceMotion: reduceMotion)
                for tier in AcousticConstellatorTier.all.dropFirst() {
                    let other: AcousticConstellatorColouredMesh = try Geometry.constellationPart(
                        s, tier: tier, reduceMotion: reduceMotion)
                    #expect(other == first)
                }
            }
        }
    }

    @Test func glowMeshShellsPerTier() throws {
        // Shown tick 3 is coherent; 0.1 s into it the shells' ages are 0.1 and 0.6.
        let s: Snapshot = try Self.sixteenCalm(listen: false, time: 0.85)
        #expect(s.shownTick == 3 && s.isCoherent(at: 3))
        let ring: Int = Geometry.shellSegments * 2
        var expectations: [(tier: Int, waves: Int, glows: Set<Double>)] = []
        expectations.append((tier: 0, waves: 2, glows: [0.5, 0.25]))
        expectations.append((tier: 1, waves: 0, glows: [0.5]))
        expectations.append((tier: 2, waves: 0, glows: []))
        for e in expectations {
            let m: Mesh = try Geometry.glowMesh(s, tier: AcousticConstellatorTier.of(e.tier))
            #expect(Self.glowTriangles(m, .waveShell) == s.stars.count * e.waves * ring)
            var factors: Set<Double> = []
            var ages: Set<Double> = []
            for k in m.positions.indices {
                if Self.kind(m, k) == AcousticConstellatorGlowKind.glow.rawValue {
                    factors.insert(m.uvs[k].x)
                    #expect(m.uvs[k].y == 0)
                } else if Self.kind(m, k) == AcousticConstellatorGlowKind.waveShell.rawValue {
                    ages.insert((m.uvs[k].y * 1e9).rounded() / 1e9)
                    #expect(abs(m.uvs[k].x - (4 + 1 - m.uvs[k].y)) < 1e-12)
                }
            }
            #expect(factors == e.glows)
            #expect(ages == (e.waves == 2 ? [0.1, 0.6] : []))
        }
        let still: Mesh = try Geometry.glowMesh(s, tier: AcousticConstellatorTier.of(0), reduceMotion: true)
        #expect(Self.glowTriangles(still, .waveShell) == 0 && Self.glowTriangles(still, .glow) > 0)
        let idle: Mesh = try Geometry.glowMesh(try Self.sixteenCalm(listen: false, time: 0),
                                               tier: AcousticConstellatorTier.of(0))
        #expect(Self.glowTriangles(idle, .waveShell) == 0)
        for snapshot in try Self.snapshots() {
            for reduceMotion in [false, true] {
                let empty: Mesh = try Geometry.glowMesh(snapshot, tier: AcousticConstellatorTier.of(2),
                                                        reduceMotion: reduceMotion)
                #expect(empty.positions.isEmpty && empty.indices.isEmpty)
            }
        }
    }

    // MARK: Kernel exactness

    @Test func tealExactlyWhereTheKernelGapIsAtMostOne() throws {
        var teal: Int = 0
        var silver: Int = 0
        for s in try Self.snapshots() {
            for reduceMotion in [false, true] {
                let tick: Int = reduceMotion ? 0 : s.shownTick
                let m: Mesh = try Geometry.constellationMesh(s, tier: AcousticConstellatorTier.of(0),
                                                             reduceMotion: reduceMotion)
                let won: Bool = s.stage == .won
                for index in s.links.indices {
                    let vertices: [Int] = Self.linkVertices(m, index)
                    #expect(!vertices.isEmpty)
                    let expected: Material
                    if won && s.symbol.contains(s.links[index]) {
                        expected = .wonLink
                    } else if Self.kernelGap(s, index, tick) <= 1 {
                        expected = .tealLink
                        teal += 1
                    } else {
                        expected = .silverLink
                        silver += 1
                    }
                    for k in vertices { #expect(Self.code(m, k) == expected.rawValue) }
                }
            }
        }
        #expect(teal > 0 && silver > 0)
    }

    @Test func snappedExactlyWhereTheKernelReportSnaps() throws {
        var snappedSeen: Int = 0
        var wholeSeen: Int = 0
        for s in try Self.snapshots() {
            let tick: Int = s.shownTick
            let m: Mesh = try Geometry.constellationMesh(s, tier: AcousticConstellatorTier.of(1), reduceMotion: false)
            for index in s.links.indices {
                var middle: Bool = false
                for k in Self.linkVertices(m, index) where m.normals[k].x > 0.35 + 1e-9 && m.normals[k].x < 0.65 - 1e-9 {
                    middle = true
                }
                let snapped: Bool = Self.kernelSnapped(s, index, tick)
                #expect(middle == !snapped)
                if snapped { snappedSeen += 1 } else { wholeSeen += 1 }
            }
        }
        #expect(snappedSeen >= 16 && wholeSeen > 0)
        let all: Snapshot = try Self.sixteenSnapped(listen: false, time: 0.3)
        for index in all.links.indices { #expect(Self.kernelSnapped(all, index, all.shownTick)) }
        let none: Snapshot = try Self.sixteenCalm(listen: false, time: 3.3)
        for index in none.links.indices { #expect(!Self.kernelSnapped(none, index, none.shownTick)) }
    }

    // MARK: Gauges

    @Test func gaugesLightZeroHalfAndTheBudget() throws {
        let level = try Self.threeStars(budget: 4)
        let cases: [(nudges: Int, lit: Int)] = [(nudges: 0, lit: 4), (nudges: 2, lit: 2), (nudges: 4, lit: 0)]
        for c in cases {
            let actions: [AcousticConstellatorAction] = Array(repeating: .nudge(0, 1), count: c.nudges)
            let s = Snapshot(play: try Self.play(level, actions), levelNumber: 3, time: 0)
            #expect(Geometry.litMoves(s) == c.lit)
            let m: Mesh = try Geometry.constellationMesh(s, tier: AcousticConstellatorTier.of(0), reduceMotion: false)
            #expect(Self.triangles(m, .movesLit) == 4 * c.lit)
            #expect(Self.triangles(m, .movesUnlit) == 4 * (4 - c.lit))
        }
        let failed = Snapshot(play: try Self.play(level, Array(repeating: .nudge(0, 1), count: 4)), levelNumber: 3,
                              time: 0)
        #expect(failed.failure == .budget(3))
        for s in try Self.snapshots() {
            let tick: Int = s.shownTick
            let m: Mesh = try Geometry.constellationMesh(s, tier: AcousticConstellatorTier.of(0), reduceMotion: false)
            #expect(Self.triangles(m, .coherenceLit) == 4 * s.coherenceBars(at: tick))
            #expect(Self.triangles(m, .coherenceLit) + Self.triangles(m, .coherenceUnlit) == 4 * 12)
            #expect(Self.triangles(m, .thresholdMark) == 4)
            #expect(Self.triangles(m, .holdLit) == 4 * s.run(at: tick))
            #expect(Self.triangles(m, .holdUnlit) == 8 * (s.hold - s.run(at: tick)))
            #expect(Self.triangles(m, .movesLit) + Self.triangles(m, .movesUnlit) == 4 * s.budget)
        }
        let calm: Snapshot = try Self.sixteenCalm(listen: false, time: 3.3)
        #expect(calm.shownTick == 12 && calm.run(at: 12) == 12 && calm.coherenceBars(at: 12) == 12)
    }

    // MARK: Won and failed

    @Test func wonLevelLinksAreBrighterAndInPlace() throws {
        let before: Snapshot = try Self.sixteenCalm(listen: false, time: 0)
        let won: Snapshot = try Self.sixteenCalm(listen: true, time: 0)
        #expect(Geometry.wonFlag(won) == 1 && Geometry.wonFlag(before) == 0)
        let tier = AcousticConstellatorTier.of(0)
        let a: AcousticConstellatorColouredMesh = try Geometry.constellationPart(before, tier: tier)
        let b: AcousticConstellatorColouredMesh = try Geometry.constellationPart(won, tier: tier)
        #expect(a.mesh.positions == b.mesh.positions && a.mesh.indices == b.mesh.indices)
        for index in won.links.indices where won.symbol.contains(won.links[index]) {
            for k in Self.linkVertices(b.mesh, index) {
                #expect(Self.code(b.mesh, k) == Material.wonLink.rawValue)
                #expect(Self.luminance(b.colours[k]) > Self.luminance(a.colours[k]) + 0.05)
            }
        }
        let glowBefore: AcousticConstellatorColouredMesh = try Geometry.glowPart(before, tier: tier)
        let glowWon: AcousticConstellatorColouredMesh = try Geometry.glowPart(won, tier: tier)
        // The same places (welding may merge strip ends of one glow kind, so compare rounded sets).
        #expect(Self.keys(glowBefore.mesh) == Self.keys(glowWon.mesh))
        var sumBefore: Double = 0
        var sumWon: Double = 0
        for c in glowBefore.colours { sumBefore += Self.luminance(c) }
        for c in glowWon.colours { sumWon += Self.luminance(c) }
        #expect(sumWon > sumBefore)
        #expect(Self.glowTriangles(glowBefore.mesh, .wonGlow) == 0)
        #expect(Self.glowTriangles(glowWon.mesh, .wonGlow) == 2 * won.symbol.count * Geometry.linkSegments * 2)
    }

    /// Feature 426 (R02-G13-06) T-R02G1306-005: the won level scales the fallback lift of won links and won glow.
    @Test func theWonLevelScalesTheFallbackLiftOfWonLinksAndWonGlow() throws {
        let won: Snapshot = try Self.sixteenCalm(listen: true, time: 0)
        let before: Snapshot = try Self.sixteenCalm(listen: false, time: 0)
        #expect(Geometry.wonFlag(won) == 1)
        let tier = AcousticConstellatorTier.of(0)
        let full: AcousticConstellatorColouredMesh = try Geometry.constellationPart(won, tier: tier)
        let glowFull: AcousticConstellatorColouredMesh = try Geometry.glowPart(won, tier: tier)
        // nil is today's output; 1 equals it.
        #expect(full == (try Geometry.constellationPart(won, tier: tier, won: nil)))
        #expect(full == (try Geometry.constellationPart(won, tier: tier, won: 1)))
        #expect(glowFull == (try Geometry.glowPart(won, tier: tier, won: nil)))
        #expect(glowFull == (try Geometry.glowPart(won, tier: tier, won: 1)))
        var wonVertices: [Int] = []
        for k in full.mesh.positions.indices where Self.code(full.mesh, k) == Material.wonLink.rawValue {
            wonVertices.append(k)
        }
        #expect(!wonVertices.isEmpty)
        var previous: Double = -1
        var previousGlow: Double = -1
        for tenth in 0...10 {
            let level: Double = Double(tenth) / 10
            let part: AcousticConstellatorColouredMesh = try Geometry.constellationPart(won, tier: tier, won: level)
            #expect(part.mesh == full.mesh, "positions and streams never change")
            var brightness: Double = 0
            for k in part.colours.indices {
                if Self.code(part.mesh, k) == Material.wonLink.rawValue {
                    brightness += Self.luminance(part.colours[k])
                } else {
                    #expect(part.colours[k] == full.colours[k], "only won links change")
                }
            }
            #expect(brightness >= previous - 1e-9, "the won link's lift grows with the level")
            previous = brightness
            let glow: AcousticConstellatorColouredMesh = try Geometry.glowPart(won, tier: tier, won: level)
            #expect(glow.mesh == glowFull.mesh, "the glow's positions and streams never change")
            var glowBrightness: Double = 0
            for k in glow.colours.indices {
                if Self.kind(glow.mesh, k) == AcousticConstellatorGlowKind.wonGlow.rawValue {
                    glowBrightness += Self.luminance(glow.colours[k])
                } else {
                    #expect(glow.colours[k] == glowFull.colours[k], "only won glow changes")
                }
            }
            #expect(glowBrightness >= previousGlow - 1e-9, "the won glow's lift grows with the level")
            previousGlow = glowBrightness
        }
        // At 0 a won link has the teal link's colour and a won glow the plain glow's colour.
        let none: AcousticConstellatorColouredMesh = try Geometry.constellationPart(won, tier: tier, won: 0)
        let teal: SIMD3<Double> = AcousticConstellatorPalette.teal
        for k in wonVertices {
            let c: Vec4 = none.colours[k]
            #expect(abs(c.x - teal.x) < 1e-12 && abs(c.y - teal.y) < 1e-12 && abs(c.z - teal.z) < 1e-12)
            #expect(Self.luminance(full.colours[k]) > Self.luminance(c) + 0.05)
        }
        let glowNone: AcousticConstellatorColouredMesh = try Geometry.glowPart(won, tier: tier, won: 0)
        let glow: SIMD3<Double> = AcousticConstellatorPalette.glow
        for k in glowNone.colours.indices where Self.kind(glowNone.mesh, k) == AcousticConstellatorGlowKind.wonGlow.rawValue {
            let factor: Double = AcousticConstellatorGlowKind.decode(glowNone.mesh.uvs[k].x).factor
            let c: Vec4 = glowNone.colours[k]
            #expect(abs(c.x - glow.x * factor) < 1e-9 && abs(c.y - glow.y * factor) < 1e-9
                    && abs(c.z - glow.z * factor) < 1e-9)
        }
        // Out-of-range levels are clamped; a non-finite level counts as 1; a level never affects an unwon play.
        #expect(none == (try Geometry.constellationPart(won, tier: tier, won: -3)))
        #expect(full == (try Geometry.constellationPart(won, tier: tier, won: 7)))
        #expect(full == (try Geometry.constellationPart(won, tier: tier, won: .nan)))
        #expect(glowFull == (try Geometry.glowPart(won, tier: tier, won: .infinity)))
        #expect((try Geometry.constellationPart(before, tier: tier)) ==
                (try Geometry.constellationPart(before, tier: tier, won: 0)))
        #expect((try Geometry.glowPart(before, tier: tier)) == (try Geometry.glowPart(before, tier: tier, won: 0)))
    }

    @Test func failuresOutlineTheMissingGuideOrTheSnappedLink() throws {
        let missing: Snapshot = try Self.threeMissing()
        let m: Mesh = try Geometry.constellationMesh(missing, tier: AcousticConstellatorTier.of(0), reduceMotion: false)
        #expect(Self.triangles(m, .broken) > 0 && Self.triangles(m, .guide) == 2 * 8 * 2)
        for k in m.positions.indices where Self.code(m, k) == Material.broken.rawValue {
            #expect(Int(m.normals[k].y.rounded()) == 0)
        }
        let disconnected: Snapshot = try Self.sixteenSnapped(listen: true, time: 0)
        #expect(Geometry.brokenLinkIndex(disconnected) == 0)
        let d: Mesh = try Geometry.constellationMesh(disconnected, tier: AcousticConstellatorTier.of(0),
                                                     reduceMotion: false)
        #expect(Self.triangles(d, .broken) == 2 * Geometry.linkSegments * 2)
        let calm: Mesh = try Geometry.constellationMesh(try Self.sixteenCalm(listen: false, time: 0),
                                                        tier: AcousticConstellatorTier.of(0), reduceMotion: false)
        #expect(Self.triangles(calm, .broken) == 0)
    }

    // MARK: Painter's order

    @Test func painterOrderSkyGaugesGuidesLinksHandsStars() throws {
        func rank(_ code: Int) -> Int {
            switch Material(rawValue: code) {
            case .sky?: 0
            case .coherenceLit?, .coherenceUnlit?, .thresholdMark?, .holdLit?, .holdUnlit?, .movesLit?, .movesUnlit?: 1
            case .guide?: 2
            case .silverLink?, .tealLink?, .wonLink?: 3
            case .hand?: 4
            case .star?: 5
            default: -1
            }
        }
        for s in try Self.snapshots() {
            let m: Mesh = try Geometry.constellationMesh(s, tier: AcousticConstellatorTier.of(0), reduceMotion: false)
            var last: Int = 0
            var lastStar: Int = -1
            let order: [Int] = Geometry.starOrder(s)
            var t: Int = 0
            while t < m.indices.count {
                let k: Int = Int(m.indices[t])
                let c: Int = Self.code(m, k)
                if c != Material.broken.rawValue {
                    let r: Int = rank(c)
                    #expect(r >= last)
                    last = r
                }
                if c == Material.star.rawValue {
                    let star: Int = Int(m.uvs[k].y.rounded())
                    let position: Int = order.firstIndex(of: star) ?? -1
                    #expect(position >= lastStar)
                    lastStar = position
                }
                t += 3
            }
            #expect(last == 5)
            for i in 1..<order.count {
                #expect(Geometry.starCentre(order[i - 1], s).z <= Geometry.starCentre(order[i], s).z)
            }
        }
    }

    // MARK: Orbit (feature 424, R02-G13-04, T-R02G1304-002)

    /// Six orbits: the authored one, the four clamp corners and the centre of the allowed range.
    static func orbits() -> [AcousticConstellatorOrbit] {
        let y: Double = AcousticConstellatorOrbit.yawLimit
        let lo: Double = AcousticConstellatorOrbit.pitchRange.lowerBound
        let hi: Double = AcousticConstellatorOrbit.pitchRange.upperBound
        return [AcousticConstellatorOrbit.authored, AcousticConstellatorOrbit(yaw: y, pitch: hi),
                AcousticConstellatorOrbit(yaw: -y, pitch: hi), AcousticConstellatorOrbit(yaw: y, pitch: lo),
                AcousticConstellatorOrbit(yaw: -y, pitch: lo), AcousticConstellatorOrbit(yaw: 0, pitch: (lo + hi) / 2)]
    }

    /// NDC (x, y) of `p` through `camera`, or nil behind the eye.
    static func ndc(_ p: SIMD3<Double>, _ camera: AcousticConstellatorCamera) -> SIMD2<Double>? {
        let clip: Vec4 = camera.viewProjection * Vec4(Vec3(p.x, p.y, p.z), 1)
        guard clip.w > 0 else { return nil }
        return SIMD2(clip.x / clip.w, clip.y / clip.w)
    }

    /// The distance between `a` and `b`.
    static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d: SIMD3<Double> = a - b
        return (d * d).sum().squareRoot()
    }

    @Test func everyOrbitKeepsTheSceneInsideTheMarginAtSevenAspects() throws {
        let snapshots: [Snapshot] = [try Self.threeIdle(), try Self.sixteenCalm(listen: false, time: 0),
                                     try Self.sixteenSnapped(listen: true, time: 0.3)]
        let bound: Double = 1 - 2 * Geometry.fitMargin
        for s in snapshots {
            var points: [SIMD3<Double>] = []
            for index in s.stars.indices { points.append(Geometry.starCentre(index, s)) }
            for index in s.links.indices {
                points.append(Geometry.linkCheckPoint(index, s))
                points.append(Geometry.linkPoint(index, u: 0.5, s))
            }
            for index in 0..<Geometry.coherenceCount { points.append(Geometry.coherenceBar(index, s)) }
            points.append(Geometry.thresholdMark(s))
            for index in 0..<s.hold { points.append(Geometry.holdPip(index, s)) }
            for index in 0..<s.budget { points.append(Geometry.movesBar(index, s)) }
            for orbit in Self.orbits() {
                for aspect in Self.aspects {
                    let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: aspect, orbit: orbit)
                    var outside: Int = 0
                    for p in points {
                        guard let v = Geometry.project(p, camera: camera) else { outside += 1; continue }
                        if v.x < 0.05 || v.x > 0.95 || v.y < 0.05 || v.y > 0.95 { outside += 1 }
                    }
                    #expect(outside == 0, "points outside the 5 % margin: \(outside) at \(orbit), aspect \(aspect)")
                    // The field of view is the smallest that holds the box: some corner touches the margin.
                    var largest: Double = 0
                    for index in 0..<8 {
                        guard let v = Self.ndc(Geometry.corner(index), camera) else {
                            Issue.record("corner \(index) behind the eye at \(orbit), aspect \(aspect)")
                            continue
                        }
                        largest = max(largest, abs(v.x), abs(v.y))
                    }
                    #expect(abs(largest - bound) < 1e-9, "fit not tight: \(largest) at \(orbit), aspect \(aspect)")
                }
            }
        }
    }

    @Test func positivePitchRaisesTheEyeAndPositiveYawMovesItTowardsPlusX() throws {
        let s: Snapshot = try Self.threeIdle()
        let base: AcousticConstellatorCamera = Geometry.camera(s, aspect: 1)
        let up: AcousticConstellatorCamera = Geometry.camera(s, aspect: 1,
                                                             orbit: AcousticConstellatorOrbit(yaw: 0, pitch: 0.2))
        let down: AcousticConstellatorCamera = Geometry.camera(s, aspect: 1,
                                                               orbit: AcousticConstellatorOrbit(yaw: 0, pitch: -0.2))
        let side: AcousticConstellatorCamera = Geometry.camera(s, aspect: 1,
                                                               orbit: AcousticConstellatorOrbit(yaw: 0.3, pitch: 0))
        #expect(up.eye.y > base.eye.y && up.eye.z < base.eye.z && up.eye.x == 0 && up.target == Geometry.lookAt)
        #expect(down.eye.y < base.eye.y && down.eye.z > base.eye.z)
        #expect(side.eye.x > 0 && side.eye.y == base.eye.y)
        // Yaw turns the eye and the look-at point about the vertical axis through the box centre (0, ·, 0.275).
        let centre: SIMD3<Double> = (Geometry.boxLow + Geometry.boxHigh) / 2
        #expect(abs(centre.x) < 1e-15 && abs(centre.z - 0.275) < 1e-12)
        for p in [(base.eye, side.eye), (base.target, side.target)] {
            let a: SIMD2<Double> = SIMD2(p.0.x - centre.x, p.0.z - centre.z)
            let b: SIMD2<Double> = SIMD2(p.1.x - centre.x, p.1.z - centre.z)
            #expect(abs((a * a).sum() - (b * b).sum()) < 1e-12)
        }
        let offset: SIMD3<Double> = up.eye - up.target
        let authored: SIMD3<Double> = Geometry.eye - Geometry.lookAt
        #expect(abs((offset * offset).sum() - (authored * authored).sum()) < 1e-12)
    }

    @Test func theAuthoredOrbitIsTheFixedCameraBitForBit() throws {
        let s: Snapshot = try Self.threeIdle()
        var aspects: [Double] = Self.aspects
        aspects.append(contentsOf: [0.05, 20, 0, -1, .nan, .infinity])
        for aspect in aspects {
            let fixed: AcousticConstellatorCamera = Geometry.camera(s, aspect: aspect)
            let orbit: AcousticConstellatorCamera = Geometry.camera(s, aspect: aspect, orbit: .authored)
            #expect(fixed == orbit)
            #expect(fixed.fovY.bitPattern == orbit.fovY.bitPattern && fixed.near.bitPattern == orbit.near.bitPattern
                    && fixed.far.bitPattern == orbit.far.bitPattern)
            #expect(fixed.eye == SIMD3(0, 2.0, 1.7) && fixed.target == SIMD3(0, 0, 0.2))
            let odd: AcousticConstellatorCamera = Geometry.camera(s, aspect: aspect,
                                                                  orbit: AcousticConstellatorOrbit(yaw: .nan,
                                                                                                   pitch: .infinity))
            #expect(odd == fixed)
        }
        // The meshes drawn at the authored orbit are the meshes of R02-G13-03.
        for s in [try Self.sixteenCalm(listen: true, time: 0.85), try Self.threeMissing()] {
            let tier: AcousticConstellatorTier = AcousticConstellatorTier.of(0)
            #expect(try Geometry.constellationMesh(s, tier: tier, reduceMotion: false, orbit: .authored)
                    == Geometry.constellationMesh(s, tier: tier, reduceMotion: false))
            #expect(try Geometry.glowMesh(s, tier: tier, orbit: .authored) == Geometry.glowMesh(s, tier: tier))
        }
    }

    @Test func clampedBoundsTheOrbit() throws {
        let y: Double = AcousticConstellatorOrbit.yawLimit
        let lo: Double = AcousticConstellatorOrbit.pitchRange.lowerBound
        let hi: Double = AcousticConstellatorOrbit.pitchRange.upperBound
        #expect(abs(y - 35.0 * Double.pi / 180) < 1e-15)
        #expect(abs(lo + 15.0 * Double.pi / 180) < 1e-15 && abs(hi - 20.0 * Double.pi / 180) < 1e-15)
        #expect(AcousticConstellatorOrbit.authored == AcousticConstellatorOrbit(yaw: 0, pitch: 0))
        #expect(AcousticConstellatorOrbit(yaw: 5, pitch: 5).clamped() == AcousticConstellatorOrbit(yaw: y, pitch: hi))
        #expect(AcousticConstellatorOrbit(yaw: -5, pitch: -5).clamped() == AcousticConstellatorOrbit(yaw: -y, pitch: lo))
        #expect(AcousticConstellatorOrbit(yaw: 0.2, pitch: -0.1).clamped()
                == AcousticConstellatorOrbit(yaw: 0.2, pitch: -0.1))
        #expect(AcousticConstellatorOrbit(yaw: .nan, pitch: .infinity).clamped() == AcousticConstellatorOrbit.authored)
        #expect(AcousticConstellatorOrbit(yaw: -.infinity, pitch: .nan).clamped() == AcousticConstellatorOrbit.authored)
        let s: Snapshot = try Self.threeIdle()
        let beyond: AcousticConstellatorCamera = Geometry.camera(s, aspect: 1,
                                                                 orbit: AcousticConstellatorOrbit(yaw: 9, pitch: -9))
        #expect(beyond == Geometry.camera(s, aspect: 1, orbit: AcousticConstellatorOrbit(yaw: y, pitch: lo)))
    }

    @Test func starsArePaintedBackToFrontForEveryOrbit() throws {
        let tier: AcousticConstellatorTier = AcousticConstellatorTier.of(0)
        for s in try Self.snapshots() {
            #expect(Geometry.starOrder(s, orbit: .authored) == Geometry.starOrder(s))
            let authored: Mesh = try Geometry.constellationMesh(s, tier: tier, reduceMotion: false)
            let authoredKeys: Set<String> = Self.keys(authored)
            for orbit in Self.orbits() where orbit != .authored {
                let eye: SIMD3<Double> = Geometry.orbitView(orbit).eye
                let order: [Int] = Geometry.starOrder(s, orbit: orbit)
                #expect(order.sorted() == Array(s.stars.indices), "a permutation of the stars")
                var previous: Double = Double.infinity
                for index in order {
                    let d: Double = Self.distance(Geometry.starCentre(index, s), eye)
                    #expect(d <= previous + 1e-12, "star \(index) at orbit \(orbit) is not nearer than the one before")
                    previous = d
                }
                // The turned mesh draws its stars in that order and holds the same positions.
                let turned: Mesh = try Geometry.constellationMesh(s, tier: tier, reduceMotion: false, orbit: orbit)
                #expect(Self.keys(turned) == authoredKeys)
                #expect(turned.positions.count == authored.positions.count)
                var drawn: [Int] = []
                var t: Int = 0
                while t < turned.indices.count {
                    let k: Int = Int(turned.indices[t])
                    if Self.code(turned, k) == Material.star.rawValue {
                        let star: Int = Int(turned.uvs[k].y.rounded())
                        if drawn.last != star { drawn.append(star) }
                    }
                    t += 3
                }
                #expect(drawn == order, "stars drawn in painter's order at \(orbit)")
                let glow: Mesh = try Geometry.glowMesh(s, tier: tier, orbit: orbit)
                #expect(Self.keys(glow) == Self.keys(try Geometry.glowMesh(s, tier: tier)))
            }
        }
    }

    @Test func theFilamentIsFiniteTealAndInPlace() throws {
        let s: Snapshot = try Self.sixteenCalm(listen: false, time: 0)
        let half: Double = Geometry.linkWidth / 2
        for star in s.stars.indices {
            let a: SIMD3<Double> = Geometry.starCentre(star, s)
            let targets: [SIMD3<Double>] = [Geometry.starCentre((star + 3) % s.stars.count, s),
                                            SIMD3(0.4, a.y, -0.3), SIMD3(-0.85, a.y, 1.2), a + SIMD3(0.001, 0, 0)]
            for b in targets {
                let m: Mesh = try Geometry.filamentMesh(from: star, to: b, s)
                #expect(m.positions.count == 4 && m.indices.count == 6, "one strip segment")
                let chord: SIMD3<Double> = b - a
                let lengthSquared: Double = (chord * chord).sum()
                for (k, v) in m.positions.enumerated() {
                    #expect(Self.finite(v))
                    #expect(Self.code(m, k) == Material.tealLink.rawValue)
                    #expect(abs(abs(m.uvs[k].y) - 1) < 1e-12, "d is −1 or +1 on the long sides")
                    #expect(m.normals[k].y == Double(star), "the normal slot carries the star")
                    // In place: on the chord (u in 0 … 1) at the half width sideways.
                    let p: SIMD3<Double> = SIMD3(v.x, v.y, v.z)
                    let u: Double = ((p - a) * chord).sum() / lengthSquared
                    #expect(u > -1e-9 && u < 1 + 1e-9)
                    let off: Double = Self.distance(p, a + chord * min(max(u, 0), 1))
                    #expect(abs(off - half) < 1e-9, "\(off)")
                }
                // Wound to face the eye (from above).
                var t: Int = 0
                while t < m.indices.count {
                    let p0: Vec3 = m.positions[Int(m.indices[t])]
                    let p1: Vec3 = m.positions[Int(m.indices[t + 1])]
                    let p2: Vec3 = m.positions[Int(m.indices[t + 2])]
                    let e1: SIMD3<Double> = SIMD3(p1.x - p0.x, p1.y - p0.y, p1.z - p0.z)
                    let e2: SIMD3<Double> = SIMD3(p2.x - p0.x, p2.y - p0.y, p2.z - p0.z)
                    let n: SIMD3<Double> = SIMD3(e1.y * e2.z - e1.z * e2.y, e1.z * e2.x - e1.x * e2.z,
                                                 e1.x * e2.y - e1.y * e2.x)
                    let toEye: SIMD3<Double> = Geometry.eye - SIMD3(p0.x, p0.y, p0.z)
                    #expect((n * toEye).sum() > 0)
                    t += 3
                }
            }
        }
        // Unusable input: no strip.
        let a: SIMD3<Double> = Geometry.starCentre(0, s)
        #expect(try Geometry.filamentMesh(from: -1, to: a, s).positions.isEmpty)
        #expect(try Geometry.filamentMesh(from: s.stars.count, to: SIMD3(0, 0.15, 0), s).positions.isEmpty)
        #expect(try Geometry.filamentMesh(from: 0, to: SIMD3(.nan, 0, 0), s).positions.isEmpty)
        #expect(try Geometry.filamentMesh(from: 0, to: SIMD3(0, .infinity, 0), s).positions.isEmpty)
        #expect(try Geometry.filamentMesh(from: 0, to: a, s).positions.isEmpty)
    }
}
