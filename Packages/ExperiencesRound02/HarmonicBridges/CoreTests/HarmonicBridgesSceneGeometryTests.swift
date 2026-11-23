// HarmonicBridgesSceneGeometryTests — feature 413 (R02-G12-03) T-R02G1203-004 (FR-R02G1203-001, 002, 004, 006;
// clarifications Q1 … Q4; SC-R02G1203-003). The bridge geometry of Harmonic Bridges built from real plays (hand-made
// levels and the seeded fixtures, actions applied through `HarmonicBridgesPlay`): every mesh is finite and bounded with
// one colour per vertex for 2 and 8 islands, 1 and 12 strings, every string a bridge and none, budgets 1 and 60, 1 and
// 4 steps, broken and won plays; every island top, string and membrane midpoint, gauge bar and step pip projects inside
// the view with a 5 % margin at seven aspects 0.4 … 2.5; every position but the wave shells' is the same at every tier
// and under Reduce Motion; marks are filled exactly where the kernel's swing reaches the threshold; the gauge lights 0,
// half and all bars; the largest scene stays under 4,000 triangles plus its shells; a won level's membranes, glow rings
// and glow shells are brighter and nothing moves; a broken test frames and crosses its step's pip and outlines its
// string. Painter's order (depth testing off, culling on): ground, flat rings, membranes, shells, strings and marks,
// islands back to front (each complete), pips, gauge; every triangle winds to face up (flat) or outward (prisms).
// Plain loops; well under 10 s each.
//
// Feature 414 (R02-G12-04) T-R02G1204-002 (FR-R02G1204-005; SC-R02G1204-004): at the authored orbit, the four clamp
// corners and the centre of the range, at seven aspects 0.4 … 2.5, every island top, string end, pip and gauge bar
// projects inside the view with a 5 % margin and the fit is tight; pitch raises, yaw turns about the box centre; the
// orbit is clamped; the authored orbit is the fixed camera bit for bit.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import HarmonicBridgesCore

@Suite struct HarmonicBridgesSceneGeometryTests {
    typealias Geometry = HarmonicBridgesSceneGeometry
    typealias Snapshot = HarmonicBridgesSceneSnapshot
    typealias Material = HarmonicBridgesMaterial

    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]

    /// The eight islands of the large levels (corners of the grid included).
    static let eightIslands: [HarmonicBridgesIsland] = [
        HarmonicBridgesIsland(x: 0, y: 0), HarmonicBridgesIsland(x: 15, y: 0), HarmonicBridgesIsland(x: 0, y: 9),
        HarmonicBridgesIsland(x: 15, y: 9), HarmonicBridgesIsland(x: 7, y: 4), HarmonicBridgesIsland(x: 8, y: 5),
        HarmonicBridgesIsland(x: 3, y: 7), HarmonicBridgesIsland(x: 12, y: 2),
    ]

    /// Twelve strings of length 1 at peg 1 on the eight islands.
    static func twelveStrings() -> [HarmonicBridgesString] {
        let pairs: [(Int, Int)] = [(0, 1), (0, 2), (0, 4), (1, 3), (1, 7), (2, 3), (2, 6), (3, 5), (4, 5), (4, 6),
                                   (5, 7), (6, 7)]
        var strings: [HarmonicBridgesString] = []
        for pair in pairs { strings.append(HarmonicBridgesString(a: pair.0, b: pair.1, length: 1, peg: 1)) }
        return strings
    }

    /// A begun play of `level` (tutorial dismissed) with `actions` applied while the play accepts them.
    static func play(_ level: HarmonicBridgesLevel, _ actions: [HarmonicBridgesAction]) throws -> HarmonicBridgesPlay {
        var play = HarmonicBridgesPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions where play.stage == .playing {
            try play.apply(action, expecting: play.fingerprint)
        }
        return play
    }

    /// 8 islands, 12 strings, 4 steps of three tones (modes 1, 2, 3 at strength 3 on every string): every string a
    /// bridge, budget 60.
    static func largeAllBridges() throws -> Snapshot {
        var steps: [[HarmonicBridgesTone]] = []
        for _ in 0..<4 {
            steps.append([HarmonicBridgesTone(frequency: 1, strength: 3), HarmonicBridgesTone(frequency: 2, strength: 3),
                          HarmonicBridgesTone(frequency: 3, strength: 3)])
        }
        let level = try HarmonicBridgesLevel(id: "geometry-large-all", seed: 1, difficulty: 1, islands: eightIslands,
                                             strings: twelveStrings(), start: 0, goal: 3, steps: steps, threshold: 12,
                                             budget: 60)
        return Snapshot(play: try play(level, []), levelNumber: 100, time: 0)
    }

    /// 8 islands, 12 strings, 4 steps of a tone no string resonates: no bridge, budget 1.
    static func largeNoBridges() throws -> Snapshot {
        var steps: [[HarmonicBridgesTone]] = []
        for _ in 0..<4 { steps.append([HarmonicBridgesTone(frequency: 7, strength: 1)]) }
        let level = try HarmonicBridgesLevel(id: "geometry-large-none", seed: 2, difficulty: 1, islands: eightIslands,
                                             strings: twelveStrings(), start: 0, goal: 3, steps: steps, threshold: 1,
                                             budget: 1)
        return Snapshot(play: try play(level, []), levelNumber: 50, time: 0.5)
    }

    /// 2 islands at opposite grid corners, 1 string, 1 step of mode 1 at strength 1 against threshold 2 (swing
    /// [1, 3, 4, 3, 1]: marks 2 … 4 filled, no bridge), budget `budget`, `actions` applied.
    static func smallLevel(budget: Int) throws -> HarmonicBridgesLevel {
        try HarmonicBridgesLevel(id: "geometry-small", seed: 3, difficulty: 1,
                                 islands: [HarmonicBridgesIsland(x: 0, y: 0), HarmonicBridgesIsland(x: 15, y: 9)],
                                 strings: [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)], start: 0, goal: 1,
                                 steps: [[HarmonicBridgesTone(frequency: 1, strength: 1)]], threshold: 2, budget: budget)
    }

    /// The small level, budget 1, nothing played.
    static func smallIdle() throws -> Snapshot {
        Snapshot(play: try play(try smallLevel(budget: 1), []), levelNumber: 1, time: 0)
    }

    /// The small level, budget 1, tested at once: broken in step 0 at string 0.
    static func smallBroken() throws -> Snapshot {
        Snapshot(play: try play(try smallLevel(budget: 1), [.test]), levelNumber: 1, time: 3)
    }

    /// 2 islands, 1 string, 4 steps of mode 1 at strength 3 (a bridge in every step), budget 60.
    static func smallAllBridges() throws -> Snapshot {
        var steps: [[HarmonicBridgesTone]] = []
        for _ in 0..<4 { steps.append([HarmonicBridgesTone(frequency: 1, strength: 3)]) }
        let level = try HarmonicBridgesLevel(id: "geometry-small-all", seed: 4, difficulty: 1,
                                             islands: [HarmonicBridgesIsland(x: 15, y: 0), HarmonicBridgesIsland(x: 0, y: 9)],
                                             strings: [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)], start: 1,
                                             goal: 0, steps: steps, threshold: 3, budget: 60)
        return Snapshot(play: try play(level, []), levelNumber: 2, time: 2.5)
    }

    /// The fixtures played to a win (`won`) or tested at once (broken).
    static func fixtures(won: Bool) throws -> [Snapshot] {
        var result: [Snapshot] = []
        for fixture in HarmonicBridgesFixtures.fixtures(6) {
            var actions: [HarmonicBridgesAction] = []
            if won {
                for t in fixture.winningActions { actions.append(.tune(t.string, t.peg)) }
            }
            actions.append(.test)
            result.append(Snapshot(play: try play(fixture.level, actions), levelNumber: 7, time: 1.3))
        }
        return result
    }

    static func snapshots() throws -> [Snapshot] {
        var all: [Snapshot] = [try largeAllBridges(), try largeNoBridges(), try smallIdle(), try smallBroken(),
                               try smallAllBridges()]
        all.append(contentsOf: try fixtures(won: true))
        all.append(contentsOf: try fixtures(won: false))
        return all
    }

    static func code(_ m: Mesh, _ k: Int) -> Int { Int(m.uvs[k].x.rounded()) }

    static func point(_ v: Vec3) -> SIMD3<Double> { SIMD3(v.x, v.y, v.z) }

    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d: SIMD3<Double> = a - b
        return dot(d, d).squareRoot()
    }

    static func luminance(_ c: Vec4) -> Double { 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z }

    /// The positions (rounded to 1e-9) of the vertices whose code is not `excluded`, as a set of keys.
    static func positionKeys(_ m: Mesh, excluding excluded: Material) -> Set<String> {
        var keys: Set<String> = []
        for k in m.positions.indices where code(m, k) != excluded.rawValue {
            let p: Vec3 = m.positions[k]
            keys.insert("\((p.x * 1e9).rounded()),\((p.y * 1e9).rounded()),\((p.z * 1e9).rounded())")
        }
        return keys
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

    // MARK: Snapshots

    @Test func handMadeSnapshotsHaveTheirExtremes() throws {
        let all: Snapshot = try Self.largeAllBridges()
        #expect(all.islands.count == 8 && all.strings.count == 12 && all.steps == 4 && all.budget == 60)
        for step in 0..<4 {
            for s in 0..<12 { #expect(all.isBridge(s, step: step)) }
            for i in 0..<8 { #expect(all.isReached(i, step: step)) }
        }
        let none: Snapshot = try Self.largeNoBridges()
        #expect(none.budget == 1)
        for step in 0..<4 { for s in 0..<12 { #expect(!none.isBridge(s, step: step)) } }
        let broken: Snapshot = try Self.smallBroken()
        #expect(broken.stage == .failed && broken.failure == .broken(step: 0, string: 0) && broken.actionsLeft == 0)
        let small: Snapshot = try Self.smallAllBridges()
        #expect(small.islands.count == 2 && small.strings.count == 1 && small.steps == 4 && small.shownStep == 2)
        for fixture in try Self.fixtures(won: true) { #expect(fixture.stage == .won) }
        for fixture in try Self.fixtures(won: false) { #expect(fixture.stage == .failed) }
    }

    // MARK: Finite and bounded

    @Test func finiteAndBoundedForExtremeSnapshots() throws {
        for s in try Self.snapshots() {
            for tier in HarmonicBridgesTier.all {
                let parts: [HarmonicBridgesColouredMesh] = [try Geometry.bridgePart(s, tier: tier),
                                                            try Geometry.glowPart(s, tier: tier)]
                let meshes: [Mesh] = [try Geometry.bridgeMesh(s, tier: tier, reduceMotion: false),
                                      try Geometry.bridgeMesh(s, tier: tier, reduceMotion: true),
                                      try Geometry.glowMesh(s, tier: tier)]
                #expect(meshes[2] == parts[1].mesh)
                for part in parts {
                    #expect(part.colours.count == part.mesh.positions.count)
                    for c in part.colours {
                        #expect(c.x >= 0 && c.x <= 1 && c.y >= 0 && c.y <= 1 && c.z >= 0 && c.z <= 1 && c.w == 1)
                    }
                }
                #expect(parts[1].mesh.indices.isEmpty == (tier.glowShells == 0))
                for m in meshes {
                    #expect(m.normals.count == m.positions.count && m.uvs.count == m.positions.count)
                    #expect(m.indices.count % 3 == 0)
                    for i in m.indices { #expect(Int(i) < m.positions.count) }
                    var bad: Int = 0
                    for k in m.positions.indices {
                        let p: Vec3 = m.positions[k]
                        let n: Vec3 = m.normals[k]
                        let uv: Vec2 = m.uvs[k]
                        let finite: Bool = p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite
                            && n.y.isFinite && n.z.isFinite && uv.x.isFinite && uv.y.isFinite
                        let bounded: Bool = abs(p.x) <= 1.1 + 1e-9 && p.z >= -0.8 - 1e-9 && p.z <= 1.1 + 1e-9
                            && p.y >= -0.01 - 1e-12 && p.y <= 0.125 && abs(n.x) <= 1.1 && abs(n.z) <= Double.pi + 1e-12
                            && n.y >= -1 && n.y <= 13_824 && uv.x >= 0 && uv.x <= 15 && abs(uv.y) <= 1
                        if !(finite && bounded) { bad += 1 }
                    }
                    #expect(bad == 0, "vertices not finite or out of bounds: \(bad), \(s.islands.count) islands")
                }
            }
        }
    }

    @Test func largestSceneStaysUnderFourThousandTrianglesPlusShells() throws {
        let s: Snapshot = try Self.largeAllBridges()
        let m: Mesh = try Geometry.bridgeMesh(s, tier: .of(0), reduceMotion: false)
        let shells: Int = Self.triangles(m, .waveShell)
        #expect(shells == 12 * 2 * Geometry.shellSegments * 2)
        #expect(m.indices.count / 3 - shells < 4_000, "triangles: \(m.indices.count / 3 - shells)")
        let budget: Snapshot = Snapshot(play: try Self.play(try Self.smallLevel(budget: 60), []), levelNumber: 1, time: 0)
        let gauge: Mesh = try Geometry.bridgeMesh(budget, tier: .of(0), reduceMotion: false)
        #expect(Self.triangles(gauge, .gaugeLit) == 60 * 4)
    }

    // MARK: Projection

    @Test func everyReferencePointProjectsInsideTheViewAtSevenAspects() throws {
        var snapshots: [Snapshot] = [try Self.largeAllBridges(), try Self.largeNoBridges(), try Self.smallIdle(),
                                     try Self.smallAllBridges()]
        snapshots.append(Snapshot(play: try Self.play(try Self.smallLevel(budget: 60), []), levelNumber: 1, time: 0))
        for s in snapshots {
            var points: [SIMD3<Double>] = []
            for i in s.islands.indices { points.append(Geometry.islandTop(i, s)) }
            for i in s.strings.indices {
                points.append(Geometry.stringMidpoint(i, s))
                points.append(Geometry.membraneMidpoint(i, s))
            }
            for bar in 0..<s.budget { points.append(Geometry.gaugeBar(bar, s)) }
            for pip in 0..<s.steps { points.append(Geometry.stepPip(pip, s)) }
            for index in 0..<8 { points.append(Geometry.corner(index)) }
            for aspect in Self.aspects {
                let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: aspect)
                #expect(camera.eye == SIMD3(0, 1.9, 1.6) && camera.target == SIMD3(0, 0, 0.1))
                var outside: Int = 0
                for p in points {
                    guard let v = Geometry.project(p, camera: camera) else { outside += 1; continue }
                    if v.x < 0.05 || v.x > 0.95 || v.y < 0.05 || v.y > 0.95 { outside += 1 }
                }
                #expect(outside == 0, "points outside the 5 % margin: \(outside) at aspect \(aspect)")
            }
        }
    }

    @Test func placesFollowClarificationQ1() throws {
        let s: Snapshot = try Self.largeAllBridges()
        let corner: SIMD3<Double> = Geometry.islandTop(0, s)
        #expect(abs(corner.x - (-7.5 * 0.12)) < 1e-12 && corner.y == 0.1 && abs(corner.z - (-4.5 * 0.12)) < 1e-12)
        let far: SIMD3<Double> = Geometry.islandTop(3, s)
        #expect(abs(far.x - 7.5 * 0.12) < 1e-12 && abs(far.z - 4.5 * 0.12) < 1e-12)
        let mid: SIMD3<Double> = Geometry.stringMidpoint(0, s)
        #expect(abs(mid.x) < 1e-12 && mid.y == 0.1 && abs(mid.z - corner.z) < 1e-12)
        let membrane: SIMD3<Double> = Geometry.membraneMidpoint(0, s)
        // The membrane's frame-check point: u = 0.25 along the string, 0.018 to the side, at the membrane's height.
        let quarter: SIMD3<Double> = Geometry.stringPoint(0, u: 0.25, y: 0.095, s)
        #expect(abs(quarter.x - (corner.x + 0.25 * (Geometry.islandTop(1, s).x - corner.x))) < 1e-12)
        #expect(membrane.y == 0.095 && abs(Self.distance(membrane, quarter) - 0.018) < 1e-12)
        #expect(abs(Self.dot(membrane - quarter, Geometry.stringEnds(0, s).b - Geometry.stringEnds(0, s).a)) < 1e-12)
        // Clear of the string (half width 0.006) and of every mark (half width 0.01, at u = k / 6).
        for k in 1...5 {
            #expect(Self.distance(membrane, Geometry.markCentre(0, sample: k, s) - SIMD3(0, 0.015, 0)) > 0.0141)
        }
        let firstBar: SIMD3<Double> = Geometry.gaugeBar(0, s)
        #expect(abs(firstBar.x - (-0.9 + 0.015)) < 1e-12 && firstBar.y == 0 && firstBar.z == 0.95)
        #expect(abs(Geometry.stepPip(0, s).x - (-0.3 + 0.075)) < 1e-12 && Geometry.stepPip(3, s).z == 0.8)
        let one: Snapshot = try Self.smallIdle()
        #expect(Geometry.stepPip(0, one) == SIMD3(0, 0, 0.8))
        #expect(abs(Geometry.gaugeBar(0, one).x) < 1e-12)
    }

    // MARK: Tiers

    @Test func everyPositionButTheShellsIsTheSameAtEveryTier() throws {
        for s in try Self.snapshots() {
            let reference: Set<String> = Self.positionKeys(try Geometry.bridgeMesh(s, tier: .of(2), reduceMotion: false),
                                                           excluding: .waveShell)
            for tier in HarmonicBridgesTier.all {
                for reduce in [false, true] {
                    let m: Mesh = try Geometry.bridgeMesh(s, tier: tier, reduceMotion: reduce)
                    if reduce && s.shownStep != s.restingStep { continue }
                    #expect(Self.positionKeys(m, excluding: .waveShell) == reference)
                    let shells: Int = Self.triangles(m, .waveShell)
                    if tier.waveShells == 0 || reduce { #expect(shells == 0) }
                }
                #expect(try Geometry.bridgePart(s, tier: tier).mesh
                        == (try Geometry.bridgeMesh(s, tier: .of(2), reduceMotion: false)))
                let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: 1.5)
                #expect(camera == Geometry.camera(s, aspect: 1.5))
            }
        }
    }

    @Test func stringsCarryTheirPackedModesOnlyWithMotion() throws {
        let s: Snapshot = try Self.largeAllBridges()
        // Modes 1, 2, 3 at strength 3: (4·1 + 3) + 24·(4·2 + 3) + 576·(4·3 + 3) = 8911.
        #expect(Geometry.packModes(0, step: 0, s) == 8_911)
        #expect(Geometry.packModes(0, step: 0, try Self.largeNoBridges()) == 0)
        let cases: [(HarmonicBridgesTier, Bool, Double)] = [(.of(0), false, 8_911), (.of(1), false, 8_911),
                                                            (.of(2), false, 0), (.of(0), true, 0)]
        for (tier, reduce, packed) in cases {
            let m: Mesh = try Geometry.bridgeMesh(s, tier: tier, reduceMotion: reduce)
            var strings: Int = 0
            var wrong: Int = 0
            for k in m.positions.indices where Self.code(m, k) == Material.string.rawValue {
                strings += 1
                if m.normals[k].y != packed || m.normals[k].x < 0 || m.normals[k].x > 1 { wrong += 1 }
            }
            #expect(strings == 12 * (Geometry.stringSegments + 1) * 2)
            #expect(wrong == 0)
        }
    }

    @Test func glowShellsFollowTheTier() throws {
        let s: Snapshot = try Self.largeAllBridges()
        for tier in HarmonicBridgesTier.all {
            let m: Mesh = try Geometry.glowMesh(s, tier: tier)
            var factors: Set<Double> = []
            for k in m.positions.indices {
                factors.insert(m.uvs[k].x)
                #expect(Self.point(m.normals[k]) == HarmonicBridgesPalette.glow)
            }
            let expected: Set<Double> = tier.glowShells == 2 ? [0.5, 0.25] : (tier.glowShells == 1 ? [0.5] : [])
            #expect(factors == expected)
        }
        let none: Mesh = try Geometry.glowMesh(try Self.largeNoBridges(), tier: .of(0))
        // No bridge: only the start island is reached, so only its two prism shells glow.
        #expect(none.indices.count / 3 == 2 * 18)
    }

    // MARK: Marks, gauge, pips

    @Test func marksAreFilledExactlyWhereTheSwingReachesTheThreshold() throws {
        for s in try Self.snapshots() {
            for reduce in [false, true] {
                let step: Int = Geometry.drawnStep(s, reduceMotion: reduce)
                let m: Mesh = try Geometry.bridgeMesh(s, tier: .of(0), reduceMotion: reduce)
                var expectedFilled: Int = 0
                var expectedHollow: Int = 0
                for index in s.strings.indices {
                    for k in 1...5 {
                        let filled: Bool = s.report.swings[step][index][k - 1] >= s.threshold
                        #expect(Geometry.isFilled(index, sample: k, step: step, s) == filled)
                        let centre: SIMD3<Double> = Geometry.markCentre(index, sample: k, s)
                        var found: Bool = false
                        for v in m.positions.indices where abs(m.normals[v].x - Double(k) / 6) < 1e-12 {
                            let near: Double = Self.distance(Self.point(m.positions[v]), centre)
                            if filled && Self.code(m, v) == Material.markFilled.rawValue && m.uvs[v].y == 0
                                && near < 1e-12 { found = true }
                            if !filled && Self.code(m, v) == Material.markHollow.rawValue && near < 0.0101 { found = true }
                        }
                        #expect(found, "mark \(k) of string \(index) (filled: \(filled)) not drawn")
                        if filled { expectedFilled += 1 } else { expectedHollow += 1 }
                    }
                }
                var centres: Int = 0
                var hollow: Int = 0
                for v in m.positions.indices {
                    if Self.code(m, v) == Material.markFilled.rawValue && m.uvs[v].y == 0 { centres += 1 }
                    if Self.code(m, v) == Material.markHollow.rawValue { hollow += 1 }
                }
                #expect(centres == expectedFilled)
                #expect(hollow == expectedHollow * 2 * Geometry.markSegments)
            }
        }
        // The small level's swing [1, 3, 4, 3, 1] against threshold 2: samples 2, 3, 4 filled.
        let small: Snapshot = try Self.smallIdle()
        var filled: [Bool] = []
        for k in 1...5 { filled.append(Geometry.isFilled(0, sample: k, step: 0, small)) }
        #expect(filled == [false, true, true, true, false])
    }

    @Test func gaugeLightsZeroHalfAndAllBars() throws {
        let level: HarmonicBridgesLevel = try Self.smallLevel(budget: 10)
        let cases: [(actions: Int, lit: Int)] = [(actions: 0, lit: 10), (actions: 5, lit: 5), (actions: 10, lit: 0)]
        for index in cases.indices {
            var actions: [HarmonicBridgesAction] = []
            for a in 0..<cases[index].actions { actions.append(.tune(0, a % 2 == 0 ? 2 : 1)) }
            let s: Snapshot = Snapshot(play: try Self.play(level, actions), levelNumber: 1, time: 0)
            #expect(s.actionsLeft == cases[index].lit && Geometry.litBars(s) == cases[index].lit)
            let m: Mesh = try Geometry.bridgeMesh(s, tier: .of(1), reduceMotion: false)
            var lit: Int = 0
            var unlit: Int = 0
            for v in m.positions.indices where m.uvs[v].y == 0 {
                if Self.code(m, v) == Material.gaugeLit.rawValue {
                    lit += 1
                    #expect(Self.point(m.positions[v]) == Geometry.gaugeBar(lit - 1, s))
                }
                if Self.code(m, v) == Material.gaugeUnlit.rawValue { unlit += 1 }
            }
            #expect(lit == cases[index].lit && unlit == 10 - cases[index].lit)
        }
    }

    @Test func pipsShowTheShownStepAndABrokenStepIsCrossed() throws {
        let s: Snapshot = try Self.smallAllBridges()
        let m: Mesh = try Geometry.bridgeMesh(s, tier: .of(0), reduceMotion: false)
        var filledAt: [SIMD3<Double>] = []
        var outlined: Int = 0
        for v in m.positions.indices {
            if Self.code(m, v) == Material.pip.rawValue && m.uvs[v].y == 0 { filledAt.append(Self.point(m.positions[v])) }
            if Self.code(m, v) == Material.pipUnlit.rawValue { outlined += 1 }
        }
        #expect(filledAt == [Geometry.stepPip(2, s)])
        #expect(outlined == 3 * 8)
        let resting: Mesh = try Geometry.bridgeMesh(s, tier: .of(0), reduceMotion: true)
        var restingAt: [SIMD3<Double>] = []
        for v in resting.positions.indices where Self.code(resting, v) == Material.pip.rawValue && resting.uvs[v].y == 0 {
            restingAt.append(Self.point(resting.positions[v]))
        }
        #expect(restingAt == [Geometry.stepPip(0, s)])

        for broken in [try Self.smallBroken()] + (try Self.fixtures(won: false)) {
            guard case let .broken(step, string)? = broken.failure else { continue }
            #expect(broken.shownStep == step && broken.restingStep == step)
            let b: Mesh = try Geometry.bridgeMesh(broken, tier: .of(2), reduceMotion: false)
            let pip: SIMD3<Double> = Geometry.stepPip(step, broken)
            var nearPip: Int = 0
            var onString: Int = 0
            for v in b.positions.indices where Self.code(b, v) == Material.brokenOutline.rawValue {
                let p: SIMD3<Double> = Self.point(b.positions[v])
                if p.y == 0 && abs(p.x - pip.x) <= 0.04 + 1e-12 && abs(p.z - pip.z) <= 0.04 + 1e-12 { nearPip += 1 }
                if p.y == Geometry.stringY { onString += 1 }
            }
            #expect(nearPip == 8 + 8)
            #expect(onString == (string == nil ? 0 : 2 * (Geometry.stringSegments + 1) * 2))
        }
        let quiet: Mesh = try Geometry.bridgeMesh(try Self.largeAllBridges(), tier: .of(0), reduceMotion: false)
        #expect(Self.triangles(quiet, .brokenOutline) == 0)
    }

    // MARK: Won

    @Test func aWonLevelIsBrighterAndInPlace() throws {
        for fixture in HarmonicBridgesFixtures.fixtures(4) {
            var tunings: [HarmonicBridgesAction] = []
            for t in fixture.winningActions { tunings.append(.tune(t.string, t.peg)) }
            let before: Snapshot = Snapshot(play: try Self.play(fixture.level, tunings), levelNumber: 1, time: 0)
            let after: Snapshot = Snapshot(play: try Self.play(fixture.level, tunings + [.test]), levelNumber: 1, time: 0)
            #expect(before.stage == .playing && after.stage == .won)
            #expect(Geometry.wonFlag(before) == 0 && Geometry.wonFlag(after) == 1)
            for tier in HarmonicBridgesTier.all {
                let a: Mesh = try Geometry.bridgeMesh(before, tier: tier, reduceMotion: false)
                let b: Mesh = try Geometry.bridgeMesh(after, tier: tier, reduceMotion: false)
                // The test spends one action, so one gauge bar goes dark; everything else keeps its code.
                #expect(a.positions == b.positions && a.indices == b.indices && a.uvs.count == b.uvs.count)
                var changed: Int = 0
                for v in a.uvs.indices where a.uvs[v] != b.uvs[v] {
                    changed += 1
                    #expect(Self.code(a, v) == Material.gaugeLit.rawValue && Self.code(b, v) == Material.gaugeUnlit.rawValue)
                }
                #expect(changed == 5)
                let ga: Mesh = try Geometry.glowMesh(before, tier: tier)
                let gb: Mesh = try Geometry.glowMesh(after, tier: tier)
                #expect(ga.positions == gb.positions)
                for v in gb.uvs.indices { #expect(gb.uvs[v].y == 1 && ga.uvs[v].y == 0) }
            }
            let pa: HarmonicBridgesColouredMesh = try Geometry.bridgePart(before, tier: .of(0))
            let pb: HarmonicBridgesColouredMesh = try Geometry.bridgePart(after, tier: .of(0))
            var brighter: Int = 0
            var lifted: Int = 0
            for v in pb.mesh.positions.indices {
                let c: Int = Self.code(pb.mesh, v)
                if c == Material.membrane.rawValue || c == Material.glowRing.rawValue {
                    lifted += 1
                    #expect(pb.mesh.normals[v].z == 1 && pa.mesh.normals[v].z == 0)
                    if Self.luminance(pb.colours[v]) > Self.luminance(pa.colours[v]) + 0.03 { brighter += 1 }
                } else if c != Material.gaugeUnlit.rawValue {
                    #expect(pb.colours[v] == pa.colours[v])
                }
            }
            #expect(lifted > 0 && brighter == lifted)
            let wa: HarmonicBridgesColouredMesh = try Geometry.glowPart(before, tier: .of(0))
            let wb: HarmonicBridgesColouredMesh = try Geometry.glowPart(after, tier: .of(0))
            for v in wb.colours.indices { #expect(Self.luminance(wb.colours[v]) > Self.luminance(wa.colours[v])) }
        }
    }

    // MARK: Painter's order and winding

    /// The painter's layer of a triangle: 0 ground, 1 flat rings, 2 membranes, 3 shells, 4 strings and marks,
    /// 5 islands, 6 pips, 7 gauge.
    static func layer(_ code: Int, y: Double) -> Int {
        switch code {
        case Material.ground.rawValue: return 0
        case Material.glowRing.rawValue, Material.startRing.rawValue, Material.goalStar.rawValue: return 1
        case Material.membrane.rawValue: return 2
        case Material.waveShell.rawValue: return 3
        case Material.string.rawValue, Material.markFilled.rawValue, Material.markHollow.rawValue: return 4
        case Material.brokenOutline.rawValue: return y > 0.05 ? 4 : 6
        case Material.islandFace.rawValue, Material.islandEdge.rawValue: return 5
        case Material.pip.rawValue, Material.pipUnlit.rawValue: return 6
        default: return 7
        }
    }

    @Test func meshIsInPaintersOrderAndWindsOutward() throws {
        for s in try Self.snapshots() {
            let m: Mesh = try Geometry.bridgeMesh(s, tier: .of(0), reduceMotion: false)
            let order: [Int] = Geometry.islandOrder(s)
            var last: Int = 0
            var islandsSeen: [Int] = []
            var badOrder: Int = 0
            var badWinding: Int = 0
            var t: Int = 0
            while t < m.indices.count {
                let a: SIMD3<Double> = Self.point(m.positions[Int(m.indices[t])])
                let b: SIMD3<Double> = Self.point(m.positions[Int(m.indices[t + 1])])
                let c: SIMD3<Double> = Self.point(m.positions[Int(m.indices[t + 2])])
                let centroid: SIMD3<Double> = (a + b + c) / 3
                let n: SIMD3<Double> = Self.cross(b - a, c - a)
                let layer: Int = Self.layer(Self.code(m, Int(m.indices[t])), y: centroid.y)
                if layer < last { badOrder += 1 }
                last = layer
                if layer == 5 {
                    var nearest: Int = 0
                    var best: Double = Double.infinity
                    for i in s.islands.indices {
                        let centre: SIMD3<Double> = Geometry.islandCentre(i, s)
                        let d: Double = Self.distance(SIMD3(centroid.x, 0, centroid.z), centre)
                        if d < best { best = d; nearest = i }
                    }
                    if islandsSeen.last != nearest { islandsSeen.append(nearest) }
                    let axis: SIMD3<Double> = Geometry.islandCentre(nearest, s) + SIMD3(0, Geometry.islandHeight / 2, 0)
                    if Self.dot(n, centroid - axis) <= 0 { badWinding += 1 }
                } else if n.y <= 0 {
                    badWinding += 1
                }
                t += 3
            }
            #expect(badOrder == 0)
            #expect(badWinding == 0)
            #expect(islandsSeen == order, "islands drawn \(islandsSeen), expected \(order)")
            for k in 1..<max(order.count, 1) {
                let p: HarmonicBridgesIsland = s.islands[order[k - 1]]
                let q: HarmonicBridgesIsland = s.islands[order[k]]
                #expect(p.y < q.y || (p.y == q.y && abs(2 * p.x - 15) >= abs(2 * q.x - 15)))
            }
        }
    }

    // MARK: Orbit (feature 414, R02-G12-04, T-R02G1204-002)

    /// Six orbits: the authored one, the four clamp corners and the centre of the allowed range.
    static func orbits() -> [HarmonicBridgesOrbit] {
        let y: Double = HarmonicBridgesOrbit.yawLimit
        let lo: Double = HarmonicBridgesOrbit.pitchRange.lowerBound
        let hi: Double = HarmonicBridgesOrbit.pitchRange.upperBound
        return [HarmonicBridgesOrbit.authored, HarmonicBridgesOrbit(yaw: y, pitch: hi),
                HarmonicBridgesOrbit(yaw: -y, pitch: hi), HarmonicBridgesOrbit(yaw: y, pitch: lo),
                HarmonicBridgesOrbit(yaw: -y, pitch: lo), HarmonicBridgesOrbit(yaw: 0, pitch: (lo + hi) / 2)]
    }

    /// NDC (x, y) of `p` through `camera`, or nil behind the eye.
    static func ndc(_ p: SIMD3<Double>, _ camera: HarmonicBridgesCamera) -> SIMD2<Double>? {
        let clip: Vec4 = camera.viewProjection * Vec4(Vec3(p.x, p.y, p.z), 1)
        guard clip.w > 0 else { return nil }
        return SIMD2(clip.x / clip.w, clip.y / clip.w)
    }

    @Test func everyOrbitKeepsTheSceneInsideTheMarginAtSevenAspects() throws {
        var snapshots: [Snapshot] = [try Self.largeAllBridges(), try Self.largeNoBridges(), try Self.smallIdle(),
                                     try Self.smallAllBridges()]
        snapshots.append(Snapshot(play: try Self.play(try Self.smallLevel(budget: 60), []), levelNumber: 1, time: 0))
        let bound: Double = 1 - 2 * Geometry.fitMargin
        for s in snapshots {
            var points: [SIMD3<Double>] = []
            for i in s.islands.indices { points.append(Geometry.islandTop(i, s)) }
            for i in s.strings.indices {
                let ends = Geometry.stringEnds(i, s)
                points.append(ends.a)
                points.append(ends.b)
            }
            for bar in 0..<s.budget { points.append(Geometry.gaugeBar(bar, s)) }
            for pip in 0..<s.steps { points.append(Geometry.stepPip(pip, s)) }
            for orbit in Self.orbits() {
                for aspect in Self.aspects {
                    let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: aspect, orbit: orbit)
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
        let s: Snapshot = try Self.smallIdle()
        let base: HarmonicBridgesCamera = Geometry.camera(s, aspect: 1)
        let up: HarmonicBridgesCamera = Geometry.camera(s, aspect: 1, orbit: HarmonicBridgesOrbit(yaw: 0, pitch: 0.2))
        let down: HarmonicBridgesCamera = Geometry.camera(s, aspect: 1, orbit: HarmonicBridgesOrbit(yaw: 0, pitch: -0.2))
        let side: HarmonicBridgesCamera = Geometry.camera(s, aspect: 1, orbit: HarmonicBridgesOrbit(yaw: 0.3, pitch: 0))
        #expect(up.eye.y > base.eye.y && up.eye.z < base.eye.z && up.eye.x == 0 && up.target == Geometry.lookAt)
        #expect(down.eye.y < base.eye.y && down.eye.z > base.eye.z)
        #expect(side.eye.x > 0 && side.eye.y == base.eye.y)
        // Yaw turns the eye and the look-at point about the vertical axis through the box centre (0, ·, 0.15).
        let centre: SIMD3<Double> = (Geometry.boxLow + Geometry.boxHigh) / 2
        for p in [(base.eye, side.eye), (base.target, side.target)] {
            let a: SIMD2<Double> = SIMD2(p.0.x - centre.x, p.0.z - centre.z)
            let b: SIMD2<Double> = SIMD2(p.1.x - centre.x, p.1.z - centre.z)
            #expect(abs((a * a).sum() - (b * b).sum()) < 1e-12)
        }
        let offset: SIMD3<Double> = up.eye - up.target
        let authored: SIMD3<Double> = Geometry.eye - Geometry.lookAt
        #expect(abs(Self.dot(offset, offset) - Self.dot(authored, authored)) < 1e-12)
    }

    @Test func theAuthoredOrbitIsTheFixedCameraBitForBit() throws {
        let s: Snapshot = try Self.smallIdle()
        var aspects: [Double] = Self.aspects
        aspects.append(contentsOf: [0.05, 20, 0, -1, .nan, .infinity])
        for aspect in aspects {
            let fixed: HarmonicBridgesCamera = Geometry.camera(s, aspect: aspect)
            let orbit: HarmonicBridgesCamera = Geometry.camera(s, aspect: aspect, orbit: .authored)
            #expect(fixed == orbit)
            #expect(fixed.fovY.bitPattern == orbit.fovY.bitPattern && fixed.near.bitPattern == orbit.near.bitPattern
                    && fixed.far.bitPattern == orbit.far.bitPattern)
            #expect(fixed.eye == SIMD3(0, 1.9, 1.6) && fixed.target == SIMD3(0, 0, 0.1))
            let odd: HarmonicBridgesCamera = Geometry.camera(s, aspect: aspect,
                                                             orbit: HarmonicBridgesOrbit(yaw: .nan, pitch: .infinity))
            #expect(odd == fixed)
        }
    }

    @Test func clampedBoundsTheOrbit() throws {
        let y: Double = HarmonicBridgesOrbit.yawLimit
        let lo: Double = HarmonicBridgesOrbit.pitchRange.lowerBound
        let hi: Double = HarmonicBridgesOrbit.pitchRange.upperBound
        #expect(abs(y - 35.0 * Double.pi / 180) < 1e-15)
        #expect(abs(lo + 15.0 * Double.pi / 180) < 1e-15 && abs(hi - 20.0 * Double.pi / 180) < 1e-15)
        #expect(HarmonicBridgesOrbit.authored == HarmonicBridgesOrbit(yaw: 0, pitch: 0))
        #expect(HarmonicBridgesOrbit(yaw: 5, pitch: 5).clamped() == HarmonicBridgesOrbit(yaw: y, pitch: hi))
        #expect(HarmonicBridgesOrbit(yaw: -5, pitch: -5).clamped() == HarmonicBridgesOrbit(yaw: -y, pitch: lo))
        #expect(HarmonicBridgesOrbit(yaw: 0.2, pitch: -0.1).clamped() == HarmonicBridgesOrbit(yaw: 0.2, pitch: -0.1))
        #expect(HarmonicBridgesOrbit(yaw: .nan, pitch: .infinity).clamped() == HarmonicBridgesOrbit.authored)
        #expect(HarmonicBridgesOrbit(yaw: -.infinity, pitch: .nan).clamped() == HarmonicBridgesOrbit.authored)
        let s: Snapshot = try Self.smallIdle()
        let beyond: HarmonicBridgesCamera = Geometry.camera(s, aspect: 1, orbit: HarmonicBridgesOrbit(yaw: 9, pitch: -9))
        #expect(beyond == Geometry.camera(s, aspect: 1, orbit: HarmonicBridgesOrbit(yaw: y, pitch: lo)))
    }

    /// Feature 414 convergence task T-R02G1204-013: at the orbit's corners and centre every island is drawn after
    /// every island farther from the eye; the authored orbit keeps the authored order; a turned bridge mesh holds the
    /// same positions as the authored one (only the islands' order changes).
    @Test func islandsArePaintedBackToFrontForEveryOrbit() throws {
        for s in try Self.snapshots() {
            #expect(Geometry.islandOrder(s, orbit: .authored) == Geometry.islandOrder(s))
            let authoredKeys: Set<String> = Self.positionKeys(try Geometry.bridgeMesh(s, tier: .of(2),
                                                                                       reduceMotion: false),
                                                              excluding: .waveShell)
            for orbit in Self.orbits() where orbit != .authored {
                let eye: SIMD3<Double> = Geometry.orbitView(orbit).eye
                let order: [Int] = Geometry.islandOrder(s, orbit: orbit)
                #expect(order.sorted() == Array(s.islands.indices), "a permutation of the islands")
                var previous: Double = Double.infinity
                for index in order {
                    let d: Double = Self.distance(Geometry.islandCentre(index, s), eye)
                    #expect(d <= previous + 1e-12, "island \(index) at orbit \(orbit) is not nearer than the one before")
                    previous = d
                }
                let turned: Mesh = try Geometry.bridgeMesh(s, tier: .of(2), reduceMotion: false, orbit: orbit)
                #expect(Self.positionKeys(turned, excluding: .waveShell) == authoredKeys)
            }
        }
    }
}
