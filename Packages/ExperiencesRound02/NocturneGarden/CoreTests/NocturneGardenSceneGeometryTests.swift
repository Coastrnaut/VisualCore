// NocturneGardenSceneGeometryTests — feature 383 (R02-G09-03) T-R02G0903-004 (FR-R02G0903-001, 002, 004, 006;
// SC-R02G0903-001; clarifications Q1–Q4). The garden geometry of Nocturne Garden built from real plays: every mesh is
// finite and bounded with one colour per vertex for the empty bed of a 16 × 12 level, a 32 × 24 bed of 12 size-3 blooms
// on the top row ending in a leak failure, and catalog levels 1 and 81 played to their witness; every cell centre, the
// lantern, every gauge bar and every bloom box corner projects inside the view with a 5 % margin at seven aspects 0.4 …
// 2.5; positions are the same at every tier, time and Reduce Motion; the shadow quads equal the kernel's mask; every
// bloom vertex lies in its bloom box; the gauge has 0, half and all bars spent; level-2 has no glow; the head
// triangulation covers each outline exactly. Hand-made levels and two catalog levels, plain loops; well under 2 s each.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import NocturneGardenCore

@Suite struct NocturneGardenSceneGeometryTests {
    typealias Geometry = NocturneGardenSceneGeometry
    typealias Snapshot = NocturneGardenSceneSnapshot

    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]

    /// A play of `level` begun (tutorial dismissed), with `actions` applied.
    static func play(_ level: NocturneGardenLevel,
                     _ actions: [NocturneGardenAction] = []) throws -> NocturneGardenPlay {
        var play = NocturneGardenPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The empty bed of a 16 × 12 level (target a 3 × 2 block, two forbidden cells, budget 6).
    static func emptyBed() throws -> Snapshot {
        let level = try NocturneGardenLevel(id: "geometry-empty", seed: 1, difficulty: 1, width: 16, height: 12,
                                            target: [17, 18, 19, 33, 34, 35], forbidden: [20, 36],
                                            supply: [.tulip: 2], sizes: [1, 2], elevations: [2, 3], sun: 2,
                                            budget: 6, required: .whole, leakAllowance: 0)
        return Snapshot(play: try play(level), levelNumber: 1, time: 1)
    }

    /// A 32 × 24 bed with 12 size-3 blooms anchored on the top row (columns 1, 3, … 23, kinds cycling) under the high
    /// sun; the forbidden cell (column 24, row 23) is darkened only by the twelfth plant: a leak failure.
    static func crowdedLeak() throws -> Snapshot {
        let width: Int = 32
        let row: Int = 23
        let forbiddenCell: Int = row * width + 24
        var supply: [NocturneGardenKind: Int] = [:]
        var actions: [NocturneGardenAction] = []
        let kinds: [NocturneGardenKind] = NocturneGardenKind.allCases
        for k in 0..<12 {
            let kind: NocturneGardenKind = kinds[k % kinds.count]
            supply[kind, default: 0] += 1
            actions.append(.plant(kind, 1 + 2 * k, row, 3))
        }
        let level = try NocturneGardenLevel(id: "geometry-crowded", seed: 2, difficulty: 5, width: width, height: 24,
                                            target: [0], forbidden: [forbiddenCell], supply: supply, sizes: [3],
                                            elevations: [1], sun: 1, budget: 20, required: .whole, leakAllowance: 0)
        return Snapshot(play: try play(level, actions), levelNumber: 100, time: 2.5)
    }

    /// Catalog level `number` played to its witness's last action, at time 0.
    static func catalog(_ number: Int) throws -> Snapshot {
        let generated: NocturneGardenGenerated = try NocturneGardenGenerator.generate(
            NocturneGardenManifest.entries[number - 1])
        return Snapshot(play: try play(generated.level, generated.solution.actions), levelNumber: number, time: 0)
    }

    static func snapshots() throws -> [Snapshot] {
        [try emptyBed(), try crowdedLeak(), try catalog(1), try catalog(81)]
    }

    static func code(_ m: Mesh, _ vertex: UInt32) -> Int { Int(m.uvs[Int(vertex)].x.rounded()) }

    @Test func crowdedBedEndsInALeakWithTwelveBlooms() throws {
        let s: Snapshot = try Self.crowdedLeak()
        #expect(s.blooms.count == 12 && s.leakFailure && s.stage == .failed)
        #expect(s.leaking == [23 * 32 + 24])
        #expect(s.blooms.allSatisfy { $0.size == 3 && $0.row == 23 })
        let e: Snapshot = try Self.emptyBed()
        #expect(e.blooms.isEmpty && e.shadow.isEmpty && !e.leakFailure)
    }

    @Test func finiteAndBoundedForExtremeSnapshots() throws {
        for s in try Self.snapshots() {
            let u: Double = Geometry.cellSize(s)
            let maxY: Double = max(Geometry.lantern(s).y + Geometry.lanternRadius, Double(s.height) * u + 18 * u)
            for tier in NocturneGardenTier.all {
                let parts: [NocturneGardenColouredMesh] = [try Geometry.gardenPart(s, tier: tier),
                                                          try Geometry.glowPart(s, tier: tier)]
                for (index, part) in parts.enumerated() {
                    let m: Mesh = part.mesh
                    #expect(part.colours.count == m.positions.count)
                    #expect(m.normals.count == m.positions.count && m.uvs.count == m.positions.count)
                    #expect(m.indices.count % 3 == 0)
                    #expect(m.indices.isEmpty == (index == 1 && tier.glowShells == 0))
                    #expect(m.indices.count / 3 < 20_000)
                    for i in m.indices { #expect(Int(i) < m.positions.count) }
                    for k in m.positions.indices {
                        let p: Vec3 = m.positions[k]
                        let n: Vec3 = m.normals[k]
                        let ok: Bool = p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite && n.y.isFinite
                            && n.z.isFinite && m.uvs[k].x.isFinite && m.uvs[k].y.isFinite
                        #expect(ok)
                        #expect(abs(p.x) <= Geometry.groundHalfWidth + 1e-9)
                        // A glow shell grows a head by at most 0.08 · 2 of its 6·s·u height about its centre.
                        let slack: Double = index == 1 ? 2 * Geometry.glowGrowth * 18 * u : 0
                        #expect(p.y >= Geometry.groundY - slack - 1e-9 && p.y <= maxY + slack + 1e-9)
                        #expect(p.z >= Geometry.groundBack - 1e-9 && p.z <= Geometry.groundFront + 1e-9)
                        if index == 0 {
                            let length: Double = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
                            #expect(abs(length - 1) < 1e-9)
                            let c: Int = Int(m.uvs[k].x.rounded())
                            #expect(c >= 0 && c <= 11)
                            #expect(m.uvs[k].y >= 0 && m.uvs[k].y <= 1)
                        } else {
                            #expect(m.uvs[k].x > 0 && m.uvs[k].x <= 0.5 && m.uvs[k].y == 0)
                        }
                        let c: Vec4 = part.colours[k]
                        #expect(c.x >= 0 && c.x <= 1 && c.y >= 0 && c.y <= 1 && c.z >= 0 && c.z <= 1 && c.w == 1)
                    }
                }
            }
            for aspect in [0.0, -1, .nan, .infinity, 1e-9, 1e9] {
                let cam: NocturneGardenCamera = Geometry.camera(s, aspect: aspect)
                #expect(cam.aspect.isFinite && cam.aspect > 0 && cam.near > 0 && cam.far > cam.near)
                #expect(cam.eye.x.isFinite && cam.eye.y.isFinite && cam.eye.z.isFinite && cam.radius.isFinite)
                #expect(Geometry.project(Geometry.bedCentre(s), camera: cam) != nil)
            }
        }
    }

    @Test func everyPlaceIsInsideTheViewWithMarginAtSevenAspects() throws {
        let margin: Double = 0.05
        for s in try Self.snapshots() {
            var points: [SIMD3<Double>] = []
            for cell in 0..<(s.width * s.height) { points.append(Geometry.cellCentre(cell, s)) }
            points.append(Geometry.lantern(s))
            for bar in 0..<s.budget { points.append(Geometry.gaugeBar(bar, s)) }
            for tier in NocturneGardenTier.all {
                for bloom in s.blooms.indices {
                    let box = Geometry.bloomBox(bloom, s, tier: tier)
                    for corner in 0..<8 {
                        points.append(SIMD3(corner & 1 == 0 ? box.min.x : box.max.x,
                                            corner & 2 == 0 ? box.min.y : box.max.y,
                                            corner & 4 == 0 ? box.min.z : box.max.z))
                    }
                }
            }
            for aspect in Self.aspects {
                let cam: NocturneGardenCamera = Geometry.camera(s, aspect: aspect)
                var inside: Bool = true
                for p in points {
                    guard let v = Geometry.project(p, camera: cam) else {
                        inside = false
                        continue
                    }
                    if v.x < margin || v.x > 1 - margin || v.y < margin || v.y > 1 - margin { inside = false }
                }
                #expect(inside, "level \(s.levelNumber) aspect \(aspect)")
            }
        }
    }

    @Test func placesFollowTheClarifiedFormulas() throws {
        let s: Snapshot = try Self.crowdedLeak()
        let u: Double = 2.0 / 32
        #expect(Geometry.cellSize(s) == u)
        let c: SIMD3<Double> = Geometry.cellCentre(23 * 32 + 5, s)
        #expect(abs(c.x - (-1 + 5.5 * u)) < 1e-12 && abs(c.y - 23.5 * u) < 1e-12 && c.z == 0)
        let l: SIMD3<Double> = Geometry.lantern(s)
        #expect(l.x == 1.25 && abs(l.y - 1.15 * 24 * u) < 1e-12 && l.z == 0.3)
        let first: SIMD3<Double> = Geometry.gaugeBar(0, s)
        let last: SIMD3<Double> = Geometry.gaugeBar(s.budget - 1, s)
        #expect(first.y == -0.1 && first.z == 0.05 && abs(first.x + last.x) < 1e-12)
        #expect(first.x > -0.9 && last.x < 0.9)
        let box = Geometry.bloomBox(0, s, tier: NocturneGardenTier.all[0])
        let foot: Double = -1 + Double(s.blooms[0].column) * u
        #expect(abs(box.min.x - (foot - 3 * u)) < 1e-12 && abs(box.max.x - (foot + 6 * u)) < 1e-12)
        #expect(box.min.y == -0.2 && abs(box.max.y - (23 * u + 18 * u)) < 1e-12)
        #expect(box.min.z == 0.35 && abs(box.max.z - 0.39) < 1e-12)
    }

    @Test func positionsAreTheSameAtEveryTierTimeAndReduceMotion() throws {
        for s in try Self.snapshots() {
            let tiers: [NocturneGardenTier] = NocturneGardenTier.all
            for tier in tiers {
                for bloom in s.blooms.indices {
                    let a = Geometry.bloomBox(bloom, s, tier: tier)
                    let b = Geometry.bloomBox(bloom, s, tier: tiers[0])
                    #expect(a.min == b.min && a.max == b.max)
                }
            }
            // Heads, cells, rims, hatch, crosses, lantern and gauge: every vertex of those materials, per tier.
            let fixed: Set<Int> = [1, 3, 4, 5, 6, 8, 9, 10, 11]
            var reference: [Int: Set<[Double]>] = [:]
            for (t, tier) in tiers.enumerated() {
                let m: Mesh = try Geometry.gardenMesh(s, tier: tier)
                var found: [Int: Set<[Double]>] = [:]
                for k in m.positions.indices {
                    let code: Int = Int(m.uvs[k].x.rounded())
                    guard fixed.contains(code) else { continue }
                    found[code, default: []].insert([m.positions[k].x, m.positions[k].y, m.positions[k].z])
                }
                if t == 0 { reference = found } else { #expect(found == reference) }
            }
            let still: Mesh = try Geometry.gardenMesh(s, tier: tiers[0], reduceMotion: true)
            let moving: Mesh = try Geometry.gardenMesh(s, tier: tiers[0], reduceMotion: false)
            #expect(still == moving)
            for aspect in Self.aspects {
                #expect(Geometry.camera(s, aspect: aspect) == Geometry.camera(s, aspect: aspect))
            }
        }
    }

    /// A 20 × 14 level with one rose of size 2 to plant (the presentation-time check).
    static func timeLevel() throws -> NocturneGardenLevel {
        try NocturneGardenLevel(id: "geometry-time", seed: 3, difficulty: 1, width: 20, height: 14, target: [3],
                                forbidden: [], supply: [.rose: 1], sizes: [2], elevations: [2], sun: 2, budget: 3,
                                required: .whole, leakAllowance: 0)
    }

    @Test func geometryIgnoresThePresentationTime() throws {
        let level: NocturneGardenLevel = try Self.timeLevel()
        let p: NocturneGardenPlay = try Self.play(level, [.plant(.rose, 4, 2, 2)])
        let early = Snapshot(play: p, levelNumber: 7, time: 0)
        let late = Snapshot(play: p, levelNumber: 7, time: 123.5)
        for tier in NocturneGardenTier.all {
            #expect(try Geometry.gardenMesh(early, tier: tier) == Geometry.gardenMesh(late, tier: tier))
            #expect(try Geometry.glowMesh(early, tier: tier) == Geometry.glowMesh(late, tier: tier))
        }
        #expect(Geometry.camera(early, aspect: 1.5) == Geometry.camera(late, aspect: 1.5))
    }

    @Test func shadowQuadsEqualTheMask() throws {
        let shadow: Int = Int(NocturneGardenShaders.shadowMaterial)
        for s in try Self.snapshots() {
            for tier in NocturneGardenTier.all {
                let m: Mesh = try Geometry.gardenMesh(s, tier: tier)
                var full: Int = 0
                var feather: Int = 0
                var t: Int = 0
                while t + 2 < m.indices.count {
                    let ids: [UInt32] = [m.indices[t], m.indices[t + 1], m.indices[t + 2]]
                    t += 3
                    guard Self.code(m, ids[0]) == shadow else { continue }
                    var cover: Bool = true
                    for id in ids where m.uvs[Int(id)].y != 1 { cover = false }
                    if cover { full += 1 } else { feather += 1 }
                }
                #expect(full == 2 * s.shadow.count, "level \(s.levelNumber) \(tier.name)")
                if tier.feather == 0 || s.shadow.isEmpty { #expect(feather == 0) }
                if tier.feather > 0 && !s.shadow.isEmpty && s.shadow.count < s.width * s.height {
                    #expect(feather > 0)
                }
            }
        }
    }

    @Test func everyBloomVertexLiesInItsBox() throws {
        let body: Set<Int> = [Int(NocturneGardenShaders.bloomBodyMaterial), Int(NocturneGardenShaders.leafStemMaterial),
                              Int(NocturneGardenShaders.headRimMaterial)]
        for s in [try Self.crowdedLeak(), try Self.catalog(81)] {
            for tier in NocturneGardenTier.all {
                var boxes: [(min: SIMD3<Double>, max: SIMD3<Double>)] = []
                for bloom in s.blooms.indices { boxes.append(Geometry.bloomBox(bloom, s, tier: tier)) }
                let m: Mesh = try Geometry.gardenMesh(s, tier: tier)
                var outside: Int = 0
                for k in m.positions.indices where body.contains(Int(m.uvs[k].x.rounded())) {
                    let p: Vec3 = m.positions[k]
                    var inAny: Bool = false
                    for box in boxes where p.x >= box.min.x - 1e-9 && p.x <= box.max.x + 1e-9
                        && p.y >= box.min.y - 1e-9 && p.y <= box.max.y + 1e-9 && p.z >= box.min.z - 1e-9
                        && p.z <= box.max.z + 1e-9 {
                        inAny = true
                    }
                    if !inAny { outside += 1 }
                }
                #expect(outside == 0, "level \(s.levelNumber) \(tier.name)")
            }
        }
    }

    /// A 16 × 12 level of budget 4 with `spent` sun actions applied (the sun alternating 2 → 3 → 2 …).
    static func gauge(spent: Int) throws -> Snapshot {
        let level = try NocturneGardenLevel(id: "geometry-gauge", seed: 4, difficulty: 1, width: 16, height: 12,
                                            target: [40], forbidden: [], supply: [.bell: 1], sizes: [1],
                                            elevations: [2, 3], sun: 2, budget: 4, required: .whole,
                                            leakAllowance: 0)
        var actions: [NocturneGardenAction] = []
        for k in 0..<spent { actions.append(.sun(k % 2 == 0 ? 3 : 2)) }
        return Snapshot(play: try play(level, actions), levelNumber: 2, time: 0)
    }

    @Test func gaugeShowsNoneHalfAndAllBarsSpent() throws {
        let spentCode: Int = Int(NocturneGardenShaders.spentBarMaterial)
        let unspentCode: Int = Int(NocturneGardenShaders.unspentBarMaterial)
        for spent in [0, 2, 4] {
            let s: Snapshot = try Self.gauge(spent: spent)
            #expect(s.moves == spent && Geometry.spentBars(s) == spent)
            let m: Mesh = try Geometry.gardenMesh(s, tier: NocturneGardenTier.all[2])
            var spentTriangles: Int = 0
            var unspentTriangles: Int = 0
            var t: Int = 0
            while t + 2 < m.indices.count {
                let c: Int = Self.code(m, m.indices[t])
                if c == spentCode { spentTriangles += 1 }
                if c == unspentCode { unspentTriangles += 1 }
                t += 3
            }
            #expect(spentTriangles == 2 * spent && unspentTriangles == 2 * (4 - spent))
            var xs: [Double] = []
            for bar in 0..<4 { xs.append(Geometry.gaugeBar(bar, s).x) }
            #expect(xs == xs.sorted() && abs(xs[0] + xs[3]) < 1e-12)
        }
    }

    @Test func glowIsEmptyAtLevelTwoAndShellsElsewhere() throws {
        let s: Snapshot = try Self.crowdedLeak()
        for tier in NocturneGardenTier.all {
            let m: Mesh = try Geometry.glowMesh(s, tier: tier)
            if tier.glowShells == 0 {
                #expect(m.positions.isEmpty && m.indices.isEmpty)
            } else {
                var weights: Set<Double> = []
                for uv in m.uvs { weights.insert(uv.x) }
                #expect(weights.count == tier.glowShells)
                #expect(m.indices.count > 0)
            }
        }
        #expect(try Geometry.glowMesh(try Self.emptyBed(), tier: NocturneGardenTier.all[2]).indices.isEmpty)
        #expect(try !Geometry.glowMesh(try Self.emptyBed(), tier: NocturneGardenTier.all[0]).indices.isEmpty)
    }

    @Test func headTriangulationCoversEachOutline() {
        for kind in NocturneGardenKind.allCases {
            let p: [NocturneGardenLattice] = kind.outline
            let triangles: [Int] = Geometry.earClip(kind)
            #expect(triangles.count == 3 * (p.count - 2))
            var outlineArea: Int = 0
            for i in p.indices {
                let a: NocturneGardenLattice = p[i]
                let b: NocturneGardenLattice = p[(i + 1) % p.count]
                outlineArea += a.x * b.y - b.x * a.y
            }
            var sum: Int = 0
            var t: Int = 0
            while t + 2 < triangles.count {
                let a: NocturneGardenLattice = p[triangles[t]]
                let b: NocturneGardenLattice = p[triangles[t + 1]]
                let c: NocturneGardenLattice = p[triangles[t + 2]]
                let area: Int = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
                #expect(area > 0, "\(kind.name)")
                sum += area
                t += 3
            }
            #expect(sum == outlineArea && outlineArea > 0, "\(kind.name)")
            #expect(Geometry.earClip(kind) == triangles)
        }
    }

    @Test func leakCrossesAppearOnlyAfterALeakFailure() throws {
        let cross: Int = Int(NocturneGardenShaders.leakCrossMaterial)
        let s: Snapshot = try Self.crowdedLeak()
        let m: Mesh = try Geometry.gardenMesh(s, tier: NocturneGardenTier.all[1])
        var count: Int = 0
        var t: Int = 0
        while t + 2 < m.indices.count {
            if Self.code(m, m.indices[t]) == cross { count += 1 }
            t += 3
        }
        #expect(count == 4 * s.leaking.count && count > 0)
        let quiet: Mesh = try Geometry.gardenMesh(try Self.catalog(1), tier: NocturneGardenTier.all[1])
        #expect(quiet.uvs.allSatisfy { Int($0.x.rounded()) != cross })
    }
}
