// ChronoConstellatorSceneGeometryTests — feature 353 (R02-G06-03) T-R02G0603-004 (FR-R02G0603-001, 002, 006;
// SC-R02G0603-001; clarifications Q1–Q3). The sky geometry of Chrono Constellator built from real plays: every mesh is
// finite and inside the grid box for the extreme grids (5 × 5, 12 × 10, 5 × 10, 12 × 5); every star, target and loop cell
// and every vertex projects inside the view with a 5 % margin at seven aspects 0.4 … 2.5; the field and star meshes and
// the camera are identical at every tier; ribbon ages rise 0.04·u per tick and alpha decays as 1 − age / R; ribbon
// vertex and triangle counts scale with the tier exactly; holds, lit targets and the collision cross are drawn; the held
// cell agrees with the kernel. A handful of hand-made levels, explicit types, plain loops; well under 10 s.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorSceneGeometryTests {
    typealias Geometry = ChronoConstellatorSceneGeometry
    typealias Snapshot = ChronoConstellatorSceneSnapshot

    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]

    /// A level of `columns` × `rows` with `count` stars on rectangle loops in vertical strips (no shared cells), all with
    /// phase 0 and loops of 6 cells, targets at loop index 3 (even stars) and 1 (odd stars): never all on target at once
    /// without an edit, so plain steps run on until the tick limit.
    static func level(columns: Int, rows: Int, count: Int, tickLimit: Int = 600) throws -> ChronoConstellatorLevel {
        let strip: Int = columns / count
        var stars: [ChronoConstellatorStar] = []
        for star in 0..<count {
            let width: Int = max(2, min(strip, 3))
            let loop: [Int] = ChronoConstellatorFixtures.rectangle(column: star * strip, row: star % 2 == 0 ? 0 : rows - 3,
                                                                    width: width, height: 3, columns: columns)
            stars.append(ChronoConstellatorStar(loop: loop, phase: 0, target: loop[star % 2 == 0 ? 3 : 1]))
        }
        return try ChronoConstellatorLevel(id: "geometry-\(columns)x\(rows)", seed: 1, difficulty: 1, columns: columns,
                                           rows: rows, stars: stars, budget: 5, tickLimit: tickLimit)
    }

    /// A play of `level` begun, with a hold on star 0 from tick 2 for 3 ticks, stepped `ticks` ticks.
    static func play(_ level: ChronoConstellatorLevel, ticks: Int, hold: Bool = true) throws -> ChronoConstellatorPlay {
        var play = ChronoConstellatorPlay(level: level)
        try play.handle(.begin)
        if hold { try play.apply(.hold(0, 2, 3), expecting: play.fingerprint) }
        if ticks > 0 { try play.apply(.step(ticks), expecting: play.fingerprint) }
        return play
    }

    /// Snapshots of the four extreme grids at ticks 0, 3 and 30 (with a hold), plus a non-finite time.
    static func snapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        let grids: [(Int, Int, Int)] = [(5, 5, 2), (12, 10, 5), (5, 10, 2), (12, 5, 4)]
        for (columns, rows, count) in grids {
            let lvl: ChronoConstellatorLevel = try level(columns: columns, rows: rows, count: count)
            for ticks in [0, 3, 30] {
                let p: ChronoConstellatorPlay = try play(lvl, ticks: ticks)
                result.append(Snapshot(play: p, levelNumber: 1, time: ticks == 30 ? .infinity : Double(ticks)))
            }
        }
        return result
    }

    /// A 5 × 5 play that collides on cell 1 at tick 1.
    static func collision() throws -> Snapshot {
        let a: [Int] = ChronoConstellatorFixtures.rectangle(column: 0, row: 0, width: 2, height: 2, columns: 5)
        let b: [Int] = ChronoConstellatorFixtures.rectangle(column: 1, row: 0, width: 2, height: 2, columns: 5)
        let lvl = try ChronoConstellatorLevel(id: "collide", seed: 2, difficulty: 1, columns: 5, rows: 5,
                                              stars: [ChronoConstellatorStar(loop: a, phase: 0, target: a[3]),
                                                      ChronoConstellatorStar(loop: b, phase: 3, target: b[1])],
                                              budget: 2, tickLimit: 50)
        var p = ChronoConstellatorPlay(level: lvl)
        try p.handle(.begin)
        try p.apply(.step(5), expecting: p.fingerprint)
        return Snapshot(play: p, levelNumber: 2, time: 0)
    }

    static func meshes(_ s: Snapshot, _ tier: ChronoConstellatorTier) throws -> [ChronoConstellatorColouredMesh] {
        [try Geometry.fieldPart(s, tier: tier), try Geometry.starPart(s, tier: tier),
         try Geometry.ribbonPart(s, tier: tier), try Geometry.glowPart(s, tier: tier)]
    }

    @Test func finiteAndBoundedForExtremeSettings() throws {
        var all: [Snapshot] = try Self.snapshots()
        all.append(try Self.collision())
        for s in all {
            let u: Double = Geometry.cellSize(s)
            #expect(abs(u - 2 / Double(max(s.columns, s.rows))) < 1e-12)
            #expect(s.time.isFinite)
            let halfWidth: Double = Double(s.columns) * u / 2 + 1e-9
            let halfDepth: Double = Double(s.rows) * u / 2 + 1e-9
            for tier in ChronoConstellatorTier.all {
                for part in try Self.meshes(s, tier) {
                    let m: Mesh = part.mesh
                    #expect(part.colours.count == m.positions.count)
                    #expect(m.normals.count == m.positions.count && m.uvs.count == m.positions.count)
                    #expect(m.indices.count % 3 == 0)
                    for i in m.indices { #expect(Int(i) < m.positions.count) }
                    for k in m.positions.indices {
                        let p: Vec3 = m.positions[k]
                        let ok: Bool = p.x.isFinite && p.y.isFinite && p.z.isFinite && m.normals[k].x.isFinite
                            && m.normals[k].y.isFinite && m.normals[k].z.isFinite && m.uvs[k].x.isFinite
                            && m.uvs[k].y.isFinite
                        #expect(ok)
                        #expect(abs(p.x) <= halfWidth && abs(p.z) <= halfDepth)
                        #expect(p.y >= -0.01 * u && p.y <= Geometry.tallest(s) + 1e-9)
                        let c: Vec4 = part.colours[k]
                        #expect(c.x >= 0 && c.x <= 1 && c.y >= 0 && c.y <= 1 && c.z >= 0 && c.z <= 1)
                    }
                }
            }
            for aspect in [0.0, -1, .nan, .infinity, 1e-9, 1e9] {
                let cam: ChronoConstellatorCamera = Geometry.camera(s, aspect: aspect)
                #expect(cam.eye.x.isFinite && cam.eye.y.isFinite && cam.eye.z.isFinite && cam.near > 0)
                #expect(Geometry.project(SIMD3(0, 0, 0), camera: cam) != nil)
            }
            #expect(Geometry.camera(s, aspect: .nan) == Geometry.camera(s, aspect: 1))
            #expect(Geometry.project(SIMD3(.nan, 0, 0), camera: Geometry.camera(s, aspect: 1)) == nil)
        }
    }

    @Test func everyElementInsideTheViewAtSevenAspects() throws {
        var all: [Snapshot] = try Self.snapshots()
        all.append(try Self.collision())
        let tier: ChronoConstellatorTier = .of(0)
        for s in all {
            var points: [SIMD3<Double>] = []
            for i in s.stars.indices {
                points.append(Geometry.starCentre(i, s))
                points.append(Geometry.targetCentre(i, s))
                for cell in s.stars[i].loop {
                    points.append(Geometry.cellCentre(cell, s) + SIMD3(0, Geometry.trackLift * Geometry.cellSize(s), 0))
                }
            }
            for part in try Self.meshes(s, tier) {
                for p in part.mesh.positions { points.append(SIMD3(p.x, p.y, p.z)) }
            }
            for aspect in Self.aspects {
                let cam: ChronoConstellatorCamera = Geometry.camera(s, aspect: aspect)
                for p in points {
                    let v: SIMD2<Double>? = Geometry.project(p, camera: cam)
                    #expect(v != nil)
                    if let v {
                        #expect(v.x >= 0.05 && v.x <= 0.95 && v.y >= 0.05 && v.y <= 0.95,
                                "\(s.columns)x\(s.rows) aspect \(aspect): \(v)")
                    }
                }
            }
        }
    }

    @Test func samePositionsAtEveryTier() throws {
        var all: [Snapshot] = try Self.snapshots()
        all.append(try Self.collision())
        for s in all {
            let field: Mesh = try Geometry.fieldMesh(s, tier: .of(0))
            let stars: Mesh = try Geometry.starMesh(s, tier: .of(0))
            for tier in ChronoConstellatorTier.all {
                #expect(try Geometry.fieldMesh(s, tier: tier) == field)
                #expect(try Geometry.starMesh(s, tier: tier) == stars)
            }
            for aspect in Self.aspects {
                #expect(Geometry.camera(s, aspect: aspect).radius == Geometry.boundingRadius(s))
            }
        }
    }

    @Test func ribbonAlphaDecaysAsStated() throws {
        for tier in ChronoConstellatorTier.all {
            let r: Double = Double(tier.ribbonTicks)
            #expect(Geometry.ribbonAlpha(age: 0, tier: tier) == 1)
            #expect(Geometry.ribbonAlpha(age: r, tier: tier) == 0)
            #expect(abs(Geometry.ribbonAlpha(age: r / 2, tier: tier) - 0.5) < 1e-12)
            #expect(Geometry.ribbonAlpha(age: 2 * r, tier: tier) == 0)
            #expect(Geometry.ribbonAlpha(age: -1, tier: tier) == 1)
            #expect(Geometry.ribbonAlpha(age: .nan, tier: tier) == 0)
        }
        let lvl: ChronoConstellatorLevel = try Self.level(columns: 12, rows: 10, count: 5)
        let s = Snapshot(play: try Self.play(lvl, ticks: 30, hold: false), levelNumber: 1, time: 0)
        #expect(s.tick == 30)
        let u: Double = Geometry.cellSize(s)
        for tier in ChronoConstellatorTier.all {
            let part: ChronoConstellatorColouredMesh = try Geometry.ribbonPart(s, tier: tier)
            var maxAge: Double = 0
            for k in part.mesh.positions.indices where part.mesh.uvs[k].y == 1 {
                // Core vertices: the age follows from the height, and the fallback colour from the alpha.
                let age: Double = part.mesh.uvs[k].x
                let height: Double = (Geometry.nodeHeight + Geometry.ribbonRise * age) * u
                #expect(abs(part.mesh.positions[k].y - height) < 1e-9)
                let alpha: Double = 1 - age / Double(tier.ribbonTicks)
                #expect(abs(Geometry.ribbonAlpha(age: age, tier: tier) - alpha) < 1e-12)
                #expect(abs(part.colours[k].x - ChronoConstellatorPalette.rose.x * alpha) < 1e-9)
                maxAge = max(maxAge, age)
            }
            #expect(maxAge == Double(tier.ribbonTicks))
        }
        // At tick 0 there is no history to draw.
        let start = Snapshot(play: try Self.play(lvl, ticks: 0, hold: false), levelNumber: 1, time: 0)
        #expect(try Geometry.ribbonMesh(start, tier: .of(0)).positions.isEmpty)
    }

    @Test func vertexCountsScaleWithTier() throws {
        let lvl: ChronoConstellatorLevel = try Self.level(columns: 12, rows: 10, count: 5)
        let s = Snapshot(play: try Self.play(lvl, ticks: 30), levelNumber: 1, time: 0)
        var vertices: [Int] = []
        for tier in ChronoConstellatorTier.all {
            let m: Mesh = try Geometry.ribbonMesh(s, tier: tier)
            let expected: Int = s.stars.count * tier.ribbonTicks * tier.segments * 2 * (tier.glowShells + 1)
            #expect(m.triangleCount == expected)
            vertices.append(m.positions.count)
            let total: Int = try Geometry.fieldMesh(s, tier: tier).triangleCount
                + Geometry.starMesh(s, tier: tier).triangleCount + m.triangleCount
            #expect(total <= 6_000, "tier \(tier.name): \(total) triangles")
            let glow: Mesh = try Geometry.glowMesh(s, tier: tier)
            #expect(glow.triangleCount == m.triangleCount + (try Geometry.starMesh(s, tier: tier).triangleCount))
        }
        #expect(vertices[0] > vertices[1] && vertices[1] > vertices[2] && vertices[2] > 0)
    }

    @Test func marksHoldsTargetsAndCollision() throws {
        let lvl: ChronoConstellatorLevel = try Self.level(columns: 5, rows: 5, count: 2)
        let p: ChronoConstellatorPlay = try Self.play(lvl, ticks: 3)
        let s = Snapshot(play: p, levelNumber: 1, time: 0)
        #expect(s.tick == 3 && s.stage == .playing)
        let u: Double = Geometry.cellSize(s)
        // The held cell is the kernel's position at the hold's first tick.
        for hold in s.holds {
            #expect(Geometry.heldCell(hold, s) == p.timeline.position(star: hold.star, at: hold.start, level: lvl))
            #expect(Geometry.isActive(hold, s))
        }
        let field: ChronoConstellatorColouredMesh = try Geometry.fieldPart(s, tier: .of(0))
        let bars: Int = field.mesh.positions.indices.filter {
            abs(field.mesh.positions[$0].y - Geometry.holdHeight * u) < 1e-12 && field.mesh.uvs[$0].x == Geometry.trackCode
        }.count
        #expect(bars == 4)
        #expect(!field.mesh.uvs.contains { $0.x == Geometry.amberCode })
        // A star on its target lights the ring: shade 1 in the field and a glow copy in the star mesh.
        let lit = Snapshot(play: try Self.play(lvl, ticks: 1, hold: false), levelNumber: 1, time: 0)
        #expect(lit.stars[1].onTarget)
        let litField: Mesh = try Geometry.fieldMesh(lit, tier: .of(2))
        #expect(litField.uvs.contains { $0.x == Geometry.roseCode && $0.y == 1 })
        #expect(litField.uvs.contains { $0.x == Geometry.roseCode && $0.y == Geometry.unlit } == !lit.stars[0].onTarget)
        let glow: Mesh = try Geometry.starMesh(lit, tier: .of(2))
        let rose: Vec3 = Vec3(ChronoConstellatorPalette.rose.x, ChronoConstellatorPalette.rose.y,
                              ChronoConstellatorPalette.rose.z)
        #expect(glow.normals.contains(rose))
        #expect(!(try Geometry.starMesh(s, tier: .of(2))).normals.contains(rose) || s.stars.contains { $0.onTarget })
        // A collision draws the amber cross on its cell.
        let c: Snapshot = try Self.collision()
        guard case .collision(_, _, let cell) = c.failure else {
            Issue.record("expected a collision, got \(String(describing: c.failure))")
            return
        }
        let crossed: Mesh = try Geometry.fieldMesh(c, tier: .of(0))
        let centre: SIMD3<Double> = Geometry.cellCentre(cell, c)
        let amber: [Int] = crossed.positions.indices.filter { crossed.uvs[$0].x == Geometry.amberCode }
        #expect(amber.count >= 8)
        for k in amber {
            let q: Vec3 = crossed.positions[k]
            #expect(abs(q.x - centre.x) < 0.5 * Geometry.cellSize(c) && abs(q.z - centre.z) < 0.5 * Geometry.cellSize(c))
        }
    }

    @Test func shapesFollowTheStarIndex() {
        let shapes: [ChronoConstellatorShape] = [.ring, .cross, .diamond, .triangle, .square]
        for (i, shape) in shapes.enumerated() { #expect(Geometry.shape(i) == shape) }
        #expect(Geometry.shape(-3) == .ring && Geometry.shape(9) == .square)
    }
}
