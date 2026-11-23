// BackwardsAuroraSceneGeometryTests — feature 393 (R02-G10-03) T-R02G1003-004 (FR-R02G1003-001, 006; clarification
// Q1). The aurora geometry of Backwards Aurora built from real plays: every mesh is finite and bounded with one colour
// per vertex for catalog levels 1, 50 and 100 played to their witness and hand-made levels of 12 and 32 samples at ±64
// (every interior bend a kink), one torn by a reversal, with the section at each end and budgets 1 and 40; every sample
// point, ring centre and gauge bar projects inside the view with a 5 % margin at seven aspects 0.4 … 2.5; the ribbon,
// ghost and marker positions are the same at every tier; the ribbon passes through the exact sample points; the gauge
// has 0, half and all bars spent; the fallback parts are non-empty. Plain loops; well under 10 s each.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import BackwardsAuroraCore

@Suite struct BackwardsAuroraSceneGeometryTests {
    typealias Geometry = BackwardsAuroraSceneGeometry
    typealias Snapshot = BackwardsAuroraSceneSnapshot

    static let aspects: [Double] = [0.4, 0.6, 0.75, 1, 1.5, 2, 2.5]

    /// A play of `level` begun (tutorial dismissed), with `actions` applied.
    static func play(_ level: BackwardsAuroraLevel,
                     _ actions: [BackwardsAuroraAction] = []) throws -> BackwardsAuroraPlay {
        var play = BackwardsAuroraPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// A level of `count` samples alternating +64, −64 (every interior bend ±256: all kinks at L = 1), the target the
    /// sorted samples, checkpoints at both ends.
    static func zigzag(_ count: Int, budget: Int, breaking: Int) throws -> BackwardsAuroraLevel {
        var samples: [Int] = []
        for k in 0..<count { samples.append(k % 2 == 0 ? 64 : -64) }
        let opening = try BackwardsAuroraWave(samples)
        let target = try BackwardsAuroraWave(samples.sorted())
        return try BackwardsAuroraLevel(id: "geometry-zigzag-\(count)", seed: UInt64(count), difficulty: 5,
                                        opening: opening, target: target, checkpoints: [0, count - 1], bendLimit: 1,
                                        breakingLimit: breaking, shortest: 2, longest: count, budget: budget)
    }

    /// A 12-sample zigzag (budget 1, breaking 64) torn by reversing [0, 1]; section at the left end.
    static func torn12() throws -> Snapshot {
        let p: BackwardsAuroraPlay = try play(try zigzag(12, budget: 1, breaking: 64), [.reverse(0, 1)])
        return Snapshot(play: p, levelNumber: 1, sectionStart: 0, sectionEnd: 1, time: 0)
    }

    /// A 32-sample zigzag (budget 40), untouched; section at the right end.
    static func zigzag32() throws -> Snapshot {
        Snapshot(play: try play(try zigzag(32, budget: 40, breaking: 128)), levelNumber: 100, sectionStart: 30,
                 sectionEnd: 31, time: 3.5)
    }

    /// A 32-sample zigzag (budget 1); the section asked far outside the wave (clamped).
    static func zigzag32Clamped() throws -> Snapshot {
        Snapshot(play: try play(try zigzag(32, budget: 1, breaking: 128)), levelNumber: 2, sectionStart: 99,
                 sectionEnd: 200, time: .nan)
    }

    /// Catalog level `number` played to its witness's last action, the section across the middle.
    static func catalog(_ number: Int) throws -> Snapshot {
        let generated: BackwardsAuroraGenerated = try BackwardsAuroraGenerator.generate(
            BackwardsAuroraManifest.entries[number - 1])
        let p: BackwardsAuroraPlay = try play(generated.level, generated.solution.actions)
        return Snapshot(play: p, levelNumber: number, sectionStart: 2, sectionEnd: p.wave.count - 3, time: 1)
    }

    static func snapshots() throws -> [Snapshot] {
        [try torn12(), try zigzag32(), try zigzag32Clamped(), try catalog(1), try catalog(50), try catalog(100)]
    }

    static func code(_ m: Mesh, _ k: Int) -> Int { Int(m.uvs[k].x.rounded()) }

    /// A play of a mild 12-sample level (values 0 / 8, breaking 128: never tears) with `spent` reversals applied, each
    /// the first legal one that neither wins nor is a no-op.
    static func spending(_ spent: Int, budget: Int) throws -> Snapshot {
        var samples: [Int] = []
        for k in 0..<12 { samples.append(k % 3 == 0 ? 8 : 0) }
        let level = try BackwardsAuroraLevel(id: "geometry-gauge-\(budget)", seed: 7, difficulty: 1,
                                             opening: try BackwardsAuroraWave(samples),
                                             target: try BackwardsAuroraWave(samples.sorted()),
                                             checkpoints: [0, 11], bendLimit: 1, breakingLimit: 128, shortest: 2,
                                             longest: 12, budget: budget)
        var p: BackwardsAuroraPlay = try play(level)
        for _ in 0..<spent {
            var applied: Bool = false
            for start in 0..<11 where !applied {
                for end in (start + 1)..<12 where !applied {
                    guard !p.wave.isPalindrome(start: start, end: end) else { continue }
                    if level.wins(p.wave.reversed(start: start, end: end)) { continue }
                    try p.apply(.reverse(start, end), expecting: p.fingerprint)
                    applied = true
                }
            }
        }
        return Snapshot(play: p, levelNumber: 3, sectionStart: 0, sectionEnd: 1, time: 0)
    }

    @Test func handMadeLevelsHaveEveryKinkAndATear() throws {
        let t: Snapshot = try Self.torn12()
        #expect(t.stage == .failed && t.tear != nil && t.budget == 1)
        let z: Snapshot = try Self.zigzag32()
        #expect(z.kinks == Array(1...30) && z.tear == nil && z.budget == 40)
        let c: Snapshot = try Self.zigzag32Clamped()
        #expect(c.sectionStart == 30 && c.sectionEnd == 31)
    }

    @Test func finiteAndBoundedForExtremeSnapshots() throws {
        for s in try Self.snapshots() {
            for tier in BackwardsAuroraTier.all {
                let parts: [BackwardsAuroraColouredMesh] = [try Geometry.auroraPart(s, tier: tier),
                                                            try Geometry.glowPart(s, tier: tier)]
                for (index, part) in parts.enumerated() {
                    let m: Mesh = part.mesh
                    #expect(part.colours.count == m.positions.count)
                    #expect(m.normals.count == m.positions.count && m.uvs.count == m.positions.count)
                    #expect(m.indices.count % 3 == 0)
                    #expect(m.indices.isEmpty == (index == 1 && tier.glowShells == 0))
                    #expect(m.indices.count / 3 < 20_000)
                    for i in m.indices { #expect(Int(i) < m.positions.count) }
                    var t: Int = 0
                    while t + 2 < m.indices.count {
                        let a: Vec3 = m.positions[Int(m.indices[t])]
                        let b: Vec3 = m.positions[Int(m.indices[t + 1])]
                        let c: Vec3 = m.positions[Int(m.indices[t + 2])]
                        #expect((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) > 0)
                        t += 3
                    }
                    for k in m.positions.indices {
                        let p: Vec3 = m.positions[k]
                        let n: Vec3 = m.normals[k]
                        let uv: Vec2 = m.uvs[k]
                        let ok: Bool = p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite && n.y.isFinite
                            && n.z.isFinite && uv.x.isFinite && uv.y.isFinite
                        #expect(ok)
                        #expect(abs(p.x) <= Geometry.groundHalfSize && abs(p.y) <= Geometry.groundHalfSize)
                        #expect(p.z >= Geometry.groundZ - 1e-12 && p.z <= max(Geometry.crossZ, Geometry.gaugeZ) + 1e-12)
                        #expect(abs(uv.y) <= 1)
                        if index == 0 {
                            #expect(n.x == 0 && n.y == 0 && n.z == 1)
                            let c: Int = Self.code(m, k)
                            #expect(c >= 0 && c <= 12)
                            // A ring at an end sample of 32 reaches u/2 − 0.051 past the timeline (x −1.02).
                            let reach: Double = 1 + Geometry.ringRadius + Geometry.ringLine / 2 + 1e-12
                            if p.z > Geometry.groundZ { #expect(abs(p.x) <= reach && p.y >= -0.95 && p.y <= 0.75) }
                        } else {
                            #expect(uv.x > 0 && uv.x <= 0.5)
                            #expect(abs(p.x) <= 1 && abs(p.y) <= 0.75)
                        }
                        let c: Vec4 = part.colours[k]
                        #expect(c.x >= 0 && c.x <= 1 && c.y >= 0 && c.y <= 1 && c.z >= 0 && c.z <= 1 && c.w == 1)
                    }
                }
            }
            for aspect in [0.0, -1, .nan, .infinity, 1e-9, 1e9] {
                let cam: BackwardsAuroraCamera = Geometry.camera(s, aspect: aspect)
                #expect(cam.aspect.isFinite && cam.aspect > 0 && cam.near > 0 && cam.far > cam.near)
                #expect(cam.eye.x.isFinite && cam.eye.y.isFinite && cam.eye.z.isFinite)
                #expect(Geometry.project(Geometry.samplePoint(0, s), camera: cam) != nil)
                #expect(cam.viewProjection.floats.count == 16)
            }
        }
    }

    @Test func everyPlaceIsInsideTheViewWithMarginAtSevenAspects() throws {
        let margin: Double = 0.05
        for s in try Self.snapshots() {
            var points: [SIMD3<Double>] = []
            for k in 0..<s.count {
                points.append(Geometry.samplePoint(k, s))
                points.append(Geometry.targetPoint(k, s))
            }
            for index in s.checkpoints.indices { points.append(Geometry.ringCentre(index, s)) }
            for bar in 0..<s.budget { points.append(Geometry.gaugeBar(bar, s)) }
            for aspect in Self.aspects {
                let cam: BackwardsAuroraCamera = Geometry.camera(s, aspect: aspect)
                for p in points {
                    guard let v = Geometry.project(p, camera: cam) else {
                        Issue.record("point \(p) not projected at aspect \(aspect)")
                        continue
                    }
                    #expect(v.x >= margin && v.x <= 1 - margin && v.y >= margin && v.y <= 1 - margin)
                }
                // The whole authored box also fits.
                for corner in 0..<8 {
                    let p: SIMD3<Double> = SIMD3(corner & 1 == 0 ? -1 : 1, corner & 2 == 0 ? -0.95 : 0.75,
                                                 corner & 4 == 0 ? -0.2 : 0.05)
                    let v: SIMD2<Double>? = Geometry.project(p, camera: cam)
                    #expect(v != nil)
                    if let v { #expect(v.x >= margin && v.x <= 1 - margin && v.y >= margin && v.y <= 1 - margin) }
                }
                // Up is up: a higher point projects higher (smaller y).
                if let low = Geometry.project(SIMD3(0, -0.5, 0), camera: cam),
                   let high = Geometry.project(SIMD3(0, 0.5, 0), camera: cam) {
                    #expect(high.y < low.y)
                }
            }
        }
    }

    @Test func markerPositionsAreTheSameAtEveryTier() throws {
        for s in try Self.snapshots() {
            var reference: [String]?
            for tier in BackwardsAuroraTier.all {
                let m: Mesh = try Geometry.auroraMesh(s, tier: tier, reduceMotion: tier.index == 1)
                var keys: [String] = []
                for k in m.positions.indices {
                    let c: Int = Self.code(m, k)
                    guard c >= 3 && c <= 11 else { continue }
                    let p: Vec3 = m.positions[k]
                    keys.append("\(c) \(p.x) \(p.y) \(p.z) \(m.uvs[k].y)")
                }
                keys.sort()
                #expect(!keys.isEmpty)
                if let reference { #expect(keys == reference) } else { reference = keys }
                // Trailing layers: tier.trailingLayers − 1 copies.
                var codes: Set<Int> = []
                for k in m.positions.indices { codes.insert(Self.code(m, k)) }
                #expect(codes.contains(2) == (tier.trailingLayers >= 2))
                #expect(codes.contains(12) == (tier.trailingLayers >= 3))
            }
        }
    }

    @Test func ribbonPassesThroughTheExactSamplePoints() throws {
        for s in try Self.snapshots() {
            let m: Mesh = try Geometry.auroraMesh(s, tier: BackwardsAuroraTier.of(0))
            var ribbon: [Vec3] = []
            var signs: [Double] = []
            for k in m.positions.indices where Self.code(m, k) == 5 {
                ribbon.append(m.positions[k])
                signs.append(m.uvs[k].y)
            }
            for k in 0..<s.count {
                let p: SIMD3<Double> = Geometry.samplePoint(k, s)
                #expect(abs(p.x - (-1 + (Double(k) + 0.5) * 2 / Double(s.count))) < 1e-12)
                #expect(p.y == 0.6 * Double(s.samples[k]) / 64 && p.z == 0)
                var found: Bool = false
                for (i, q) in ribbon.enumerated() where q.x == p.x && q.y == p.y && q.z == p.z {
                    found = true
                    let inside: Bool = k >= s.sectionStart && k <= s.sectionEnd
                    #expect((signs[i] < 0) == inside)
                    #expect(abs(abs(signs[i]) - (p.x + 1) / 2) < 1e-12)
                }
                #expect(found)
            }
            // Every ribbon vertex lies within ±0.03 of the polyline between its neighbouring samples.
            let u: Double = 2 / Double(s.count)
            for q in ribbon {
                let f: Double = (q.x + 1) / u - 0.5
                let k: Int = min(max(Int(f.rounded(.down)), 0), s.count - 2)
                let a: SIMD3<Double> = Geometry.samplePoint(k, s)
                let b: SIMD3<Double> = Geometry.samplePoint(k + 1, s)
                let y: Double = a.y + (b.y - a.y) * (q.x - a.x) / (b.x - a.x)
                #expect(abs(q.y - y) <= Geometry.ribbonHalfHeight + 1e-12)
            }
            // Ghost vertices at the exact target points.
            for k in 0..<s.count {
                let p: SIMD3<Double> = Geometry.targetPoint(k, s)
                var found: Bool = false
                for i in m.positions.indices where Self.code(m, i) == 3 {
                    let q: Vec3 = m.positions[i]
                    if q.x == p.x && q.y == p.y && q.z == p.z { found = true }
                }
                #expect(found)
            }
        }
    }

    @Test func gaugeShowsNoneHalfAndAllSpent() throws {
        for budget in [4, 40] {
            for spent in [0, budget / 2, budget] {
                let s: Snapshot = try Self.spending(spent, budget: budget)
                #expect(s.spent == spent && s.budget == budget)
                #expect(Geometry.spentBars(s) == spent)
                let m: Mesh = try Geometry.auroraMesh(s, tier: BackwardsAuroraTier.of(2))
                var spentCorners: Int = 0
                var unspentCorners: Int = 0
                for k in m.positions.indices {
                    let c: Int = Self.code(m, k)
                    if c == 10 { spentCorners += 1 }
                    if c == 11 { unspentCorners += 1 }
                }
                #expect(spentCorners == 4 * spent && unspentCorners == 4 * (budget - spent))
                let first: SIMD3<Double> = Geometry.gaugeBar(0, s)
                let last: SIMD3<Double> = Geometry.gaugeBar(budget - 1, s)
                #expect(first.x > -0.9 && last.x < 0.9 && first.y == -0.85)
                #expect(abs((first.x + last.x)) < 1e-12)
            }
        }
        let one: Snapshot = try Self.torn12()
        #expect(abs(Geometry.gaugeBar(0, one).x) < 1e-12)
    }

    @Test func fallbackPartsAreNonEmptyWithOneColourPerVertex() throws {
        for s in try Self.snapshots() {
            for tier in BackwardsAuroraTier.all {
                let a: BackwardsAuroraColouredMesh = try Geometry.auroraPart(s, tier: tier)
                #expect(!a.mesh.indices.isEmpty && a.colours.count == a.mesh.positions.count)
                #expect(a.mesh == (try Geometry.auroraMesh(s, tier: tier)))
                let g: BackwardsAuroraColouredMesh = try Geometry.glowPart(s, tier: tier)
                #expect(g.colours.count == g.mesh.positions.count)
                #expect(g.mesh.indices.isEmpty == (tier.glowShells == 0))
                #expect(g.mesh == (try Geometry.glowMesh(s, tier: tier)))
                // The first vertex is the ground, in the midnight colour.
                let c: Vec4 = a.colours[0]
                let ground: SIMD3<Double> = BackwardsAuroraPalette.ground
                #expect(abs(c.x - ground.x) < 1e-12 && abs(c.y - ground.y) < 1e-12 && abs(c.z - ground.z) < 1e-12)
            }
            // Kinks and the tear are drawn with their codes.
            let m: Mesh = try Geometry.auroraMesh(s, tier: BackwardsAuroraTier.of(2))
            var codes: Set<Int> = []
            for k in m.positions.indices { codes.insert(Self.code(m, k)) }
            #expect(codes.contains(8) == !s.kinks.isEmpty)
            #expect(codes.contains(9) == (s.tear != nil))
            #expect(codes.contains(7) == s.matched.contains(true))
            #expect(codes.contains(6) == s.matched.contains(false))
        }
    }
}
