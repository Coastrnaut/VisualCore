// ChronoConstellatorSceneGeometryTests — feature 353 (R02-G06-03) T-R02G0603-004 (FR-R02G0603-001, 002, 006;
// SC-R02G0603-001; clarifications Q1–Q3). The sky geometry of Chrono Constellator built from real plays: every mesh is
// finite and inside the grid box for the extreme grids (5 × 5, 12 × 10, 5 × 10, 12 × 5); every star, target and loop cell
// and every vertex projects inside the view with a 5 % margin at seven aspects 0.4 … 2.5; the field and star meshes and
// the camera are identical at every tier; ribbon ages rise 0.04·u per tick and alpha decays as 1 − age / R; ribbon
// vertex and triangle counts scale with the tier exactly; holds, lit targets and the collision cross are drawn; the held
// cell agrees with the kernel. A handful of hand-made levels, explicit types, plain loops; well under 10 s.
// Feature 354 (R02-G06-04) T-R02G0604-002 (FR-R02G0604-005; SC-R02G0604-004): at the authored orbit, both yaw limits,
// both pitch limits and the four bound corners every element projects inside the view with a 5 % margin for aspects
// 0.4 … 2.5; the authored camera is the authored orbit's camera bit for bit; `ChronoConstellatorOrbit.clamped()` keeps
// the bounds; the candidate ring has the stated geometry and streams.
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

    /// The 5 × 5 level of ``collision()``.
    static func collisionLevel() throws -> ChronoConstellatorLevel {
        let a: [Int] = ChronoConstellatorFixtures.rectangle(column: 0, row: 0, width: 2, height: 2, columns: 5)
        let b: [Int] = ChronoConstellatorFixtures.rectangle(column: 1, row: 0, width: 2, height: 2, columns: 5)
        return try ChronoConstellatorLevel(id: "collide", seed: 2, difficulty: 1, columns: 5, rows: 5,
                                           stars: [ChronoConstellatorStar(loop: a, phase: 0, target: a[3]),
                                                   ChronoConstellatorStar(loop: b, phase: 3, target: b[1])],
                                           budget: 2, tickLimit: 50)
    }

    /// A 5 × 5 play that collides on cell 1 at tick 1.
    static func collision() throws -> Snapshot {
        let lvl: ChronoConstellatorLevel = try collisionLevel()
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

    /// The current-tick mark (converge T-R02G0603-014): absent at tick 0, half the grid's width at half the tick limit,
    /// the whole width at the limit; a silver bar of the field program near the field's near edge, clear of the target
    /// rings; the same at every tier.
    @Test func theCurrentTickMarkFollowsTheTick() throws {
        let lvl: ChronoConstellatorLevel = try Self.level(columns: 6, rows: 5, count: 2, tickLimit: 40)
        let width: Double = 6 * Geometry.cellSize(Snapshot(play: try Self.play(lvl, ticks: 0), levelNumber: 1, time: 0))
        let expected: [(ticks: Int, length: Double)] = [(0, 0), (20, width / 2), (40, width)]
        var counts: [Int] = []
        for entry in expected {
            let s: Snapshot = Snapshot(play: try Self.play(lvl, ticks: entry.ticks, hold: false), levelNumber: 1, time: 0)
            #expect(s.tick == entry.ticks)
            let length: Double = Geometry.tickBarLength(s)
            #expect(length.isFinite && abs(length - entry.length) < 1e-9, "tick \(entry.ticks): \(length)")
            let u: Double = Geometry.cellSize(s)
            let nearEdge: Double = Double(s.rows) * u / 2
            let field: ChronoConstellatorColouredMesh = try Geometry.fieldPart(s, tier: .of(0))
            counts.append(field.mesh.positions.count)
            var barXs: [Double] = []
            for (k, q) in field.mesh.positions.enumerated() {
                let inBand: Bool = abs(Double(q.z) - (nearEdge - Geometry.tickBarInset * u)) <= Geometry.tickBarWidth * u / 2
                    + 1e-9
                let onTrackHeight: Bool = abs(Double(q.y) - Geometry.trackLift * u) < 1e-9
                if inBand && onTrackHeight && field.mesh.uvs[k].x == Geometry.trackCode {
                    barXs.append(Double(q.x))
                }
            }
            if entry.ticks == 0 {
                #expect(barXs.isEmpty)
            } else {
                let minX: Double = barXs.min() ?? .nan
                let maxX: Double = barXs.max() ?? .nan
                #expect(abs(minX + 3 * u) < 1e-6 && abs(maxX - minX - entry.length) < 1e-6, "\(minX) \(maxX)")
            }
            #expect(Geometry.tickBarInset + Geometry.tickBarWidth / 2 < 0.5 - Geometry.targetOuter)
            for index in 1..<ChronoConstellatorTier.all.count {
                #expect(try Geometry.fieldPart(s, tier: .of(index)) == field)
            }
        }
        #expect(counts[1] == counts[0] + 4 && counts[2] == counts[1])
    }

    /// Feature 356 (T-R02G0606-004): with lights the ring shades, the node colours and the collision mark follow the eased
    /// levels; settled lights give the snapshot's own ring shades, and the mark fades out at its remembered cell after a
    /// rewind; without lights the meshes are unchanged.
    @Test func theLightsDriveRingsNodesAndTheCollisionMark() throws {
        let c: Snapshot = try Self.collision()
        var lights: ChronoConstellatorLights = ChronoConstellatorLights(reducedFlash: true)
        lights.settle(to: c)
        let plain: ChronoConstellatorColouredMesh = try Geometry.fieldPart(c, tier: .of(0))
        let lit: ChronoConstellatorColouredMesh = try Geometry.fieldPart(c, tier: .of(0), lights: lights)
        #expect(plain == lit)
        #expect(lights.collisionCell != nil && lights.collision == 1)
        let plainStars: ChronoConstellatorColouredMesh = try Geometry.starPart(c, tier: .of(0))
        let litStars: ChronoConstellatorColouredMesh = try Geometry.starPart(c, tier: .of(0), lights: lights)
        #expect(plainStars.mesh.positions == litStars.mesh.positions)
        var dimmer: Bool = false
        for (k, colour) in litStars.colours.enumerated() where colour.x < plainStars.colours[k].x - 1e-9 {
            dimmer = true
        }
        #expect(dimmer == lights.nodes.contains { $0 < 1 })
        // Rewind: the failure is gone, the mark fades at its remembered cell.
        let lvl: ChronoConstellatorLevel = try Self.collisionLevel()
        var p = ChronoConstellatorPlay(level: lvl)
        try p.handle(.begin)
        let rewound: Snapshot = Snapshot(play: p, levelNumber: 2, time: 0)
        lights.step(toward: rewound, elapsed: 0.1)
        #expect(lights.collision > 0 && lights.collision < 1 && lights.collisionCell != nil)
        let fading: ChronoConstellatorColouredMesh = try Geometry.fieldPart(rewound, tier: .of(0), lights: lights)
        var amber: Int = 0
        for uv in fading.mesh.uvs where uv.x == Geometry.amberCode {
            amber += 1
            #expect(abs(uv.y - lights.collision) < 1e-12)
        }
        #expect(amber > 0)
        lights.step(toward: rewound, elapsed: 1)
        #expect(lights.collision == 0 && lights.collisionCell == nil)
        let dark: ChronoConstellatorColouredMesh = try Geometry.fieldPart(rewound, tier: .of(0), lights: lights)
        var after: Int = 0
        for uv in dark.mesh.uvs where uv.x == Geometry.amberCode { after += 1 }
        #expect(after == 0)
        // Ring shades are the eased levels.
        let shaded: ChronoConstellatorColouredMesh = try Geometry.fieldPart(rewound, tier: .of(0), lights: lights)
        var roseShades: Set<Double> = []
        for uv in shaded.mesh.uvs where uv.x == Geometry.roseCode { roseShades.insert(uv.y) }
        #expect(roseShades.isSubset(of: Set(lights.rings)))
    }

    @Test func shapesFollowTheStarIndex() {
        let shapes: [ChronoConstellatorShape] = [.ring, .cross, .diamond, .triangle, .square]
        for (i, shape) in shapes.enumerated() { #expect(Geometry.shape(i) == shape) }
        #expect(Geometry.shape(-3) == .ring && Geometry.shape(9) == .square)
    }

    // MARK: Orbit (feature 354)

    typealias Orbit = ChronoConstellatorOrbit

    /// The authored orbit, both yaw limits, both pitch limits and the four corners of the orbit bounds.
    static let orbits: [Orbit] = [
        .authored,
        Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.authored.pitch),
        Orbit(yaw: Orbit.yawLimit, pitch: Orbit.authored.pitch),
        Orbit(yaw: 0, pitch: Orbit.pitchRange.lowerBound),
        Orbit(yaw: 0, pitch: Orbit.pitchRange.upperBound),
        Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound),
        Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound),
        Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound),
        Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound),
    ]

    @Test func everyElementInsideTheViewAtEveryOrbitBound() throws {
        var all: [Snapshot] = try Self.snapshots()
        all.append(try Self.collision())
        let tier: ChronoConstellatorTier = .of(0)
        for s in all {
            var points: [SIMD3<Double>] = []
            for part in try Self.meshes(s, tier) {
                for p in part.mesh.positions { points.append(SIMD3(p.x, p.y, p.z)) }
            }
            for cell in 0..<(s.columns * s.rows) {
                for p in try Geometry.candidatePart(cell, s).mesh.positions { points.append(SIMD3(p.x, p.y, p.z)) }
            }
            for orbit in Self.orbits {
                for aspect in Self.aspects {
                    let cam: ChronoConstellatorCamera = Geometry.camera(s, aspect: aspect, orbit: orbit)
                    #expect(Geometry.length(cam.eye) - cam.radius > cam.near)
                    var outside: Int = 0
                    for p in points {
                        guard let v = Geometry.project(p, camera: cam) else {
                            outside += 1
                            continue
                        }
                        if !(v.x >= 0.05 && v.x <= 0.95 && v.y >= 0.05 && v.y <= 0.95) { outside += 1 }
                    }
                    #expect(outside == 0, "\(s.columns)x\(s.rows) orbit \(orbit) aspect \(aspect)")
                }
            }
        }
    }

    @Test func theOrbitCameraLooksFromTheOrbitDirection() throws {
        for s in try Self.snapshots() {
            for orbit in Self.orbits {
                let cam: ChronoConstellatorCamera = Geometry.camera(s, aspect: 1, orbit: orbit)
                let eye: SIMD3<Double> = cam.eye
                let horizontal: Double = (eye.x * eye.x + eye.z * eye.z).squareRoot()
                #expect(abs(atan2(eye.y, horizontal) - orbit.pitch) < 1e-12)
                #expect(abs(atan2(eye.x, eye.z) - orbit.yaw) < 1e-12)
                #expect(abs(Geometry.length(eye) - Geometry.length(Geometry.camera(s, aspect: 1).eye)) < 1e-12)
                #expect(cam.radius == Geometry.boundingRadius(s))
                let centre: SIMD2<Double>? = Geometry.project(.zero, camera: cam)
                #expect(centre != nil)
                if let centre { #expect(abs(centre.x - 0.5) < 1e-9 && abs(centre.y - 0.5) < 1e-9) }
            }
        }
    }

    @Test func theAuthoredCameraIsTheAuthoredOrbit() throws {
        #expect(Orbit.authored.yaw == 0)
        #expect(Orbit.authored.pitch == Geometry.pitch)
        #expect(Orbit.authored.eyeDirection == Geometry.eyeDirection)
        let aspects: [Double] = [0.4, 0.6, 1, 1.333, 1.5, 2, 2.5, 0, .nan, 20]
        var all: [Snapshot] = try Self.snapshots()
        all.append(try Self.collision())
        for s in all {
            for aspect in aspects {
                #expect(Geometry.camera(s, aspect: aspect) == Geometry.camera(s, aspect: aspect, orbit: .authored))
            }
        }
    }

    @Test func clampedKeepsTheOrbitBounds() throws {
        let degree: Double = Double.pi / 180
        #expect(abs(Orbit.yawLimit - 40 * degree) < 1e-15)
        #expect(abs(Orbit.pitchRange.lowerBound - 30 * degree) < 1e-15)
        #expect(abs(Orbit.pitchRange.upperBound - 75 * degree) < 1e-15)
        #expect(abs(Orbit.authored.pitch - 55 * degree) < 1e-15)
        #expect(Orbit.authored.clamped() == .authored)
        let inside: Orbit = Orbit(yaw: 10 * degree, pitch: 35 * degree)
        #expect(inside.clamped() == inside)
        let low: Orbit = Orbit(yaw: -3, pitch: -1).clamped()
        #expect(low.yaw == -Orbit.yawLimit && low.pitch == Orbit.pitchRange.lowerBound)
        let high: Orbit = Orbit(yaw: 3, pitch: 2).clamped()
        #expect(high.yaw == Orbit.yawLimit && high.pitch == Orbit.pitchRange.upperBound)
        let odd: [Double] = [.nan, .infinity, -.infinity]
        for value in odd {
            #expect(Orbit(yaw: value, pitch: value).clamped() == .authored)
            let yawOnly: Orbit = Orbit(yaw: value, pitch: 35 * degree).clamped()
            #expect(yawOnly.yaw == 0 && yawOnly.pitch == 35 * degree)
        }
        for orbit in Self.orbits {
            let e: SIMD3<Double> = orbit.eyeDirection
            #expect(abs(Geometry.length(e) - 1) < 1e-12)
        }
        // The camera of an out-of-bounds orbit is the camera of its clamped orbit.
        let s: Snapshot = try Self.snapshots()[0]
        let wild: Orbit = Orbit(yaw: 2, pitch: 1.5)
        #expect(Geometry.camera(s, aspect: 1, orbit: wild) == Geometry.camera(s, aspect: 1, orbit: wild.clamped()))
    }

    @Test func candidateRingOutlinesItsCell() throws {
        var all: [Snapshot] = try Self.snapshots()
        all.append(try Self.collision())
        let up: Vec3 = Vec3(0, 1, 0)
        for s in all {
            let u: Double = Geometry.cellSize(s)
            let outer: Double = 0.42 * u
            let inner: Double = 0.36 * u
            for cell in [0, s.columns - 1, s.columns * s.rows / 2, s.columns * s.rows - 1] {
                let part: ChronoConstellatorColouredMesh = try Geometry.candidatePart(cell, s)
                let m: Mesh = part.mesh
                let centre: SIMD3<Double> = Geometry.cellCentre(cell, s)
                #expect(m.triangleCount == 8)
                #expect(part.colours.count == m.positions.count && m.normals.count == m.positions.count)
                var area: Double = 0
                var k: Int = 0
                while k + 2 < m.indices.count {
                    let a: Vec3 = m.positions[Int(m.indices[k])]
                    let b: Vec3 = m.positions[Int(m.indices[k + 1])]
                    let c: Vec3 = m.positions[Int(m.indices[k + 2])]
                    let n: SIMD3<Double> = Geometry.cross(SIMD3(b.x - a.x, b.y - a.y, b.z - a.z),
                                                          SIMD3(c.x - a.x, c.y - a.y, c.z - a.z))
                    #expect(n.y > 0)
                    area += Geometry.length(n) / 2
                    k += 3
                }
                let expectedArea: Double = 4 * (outer * outer - inner * inner)
                #expect(abs(area - expectedArea) < 1e-12, "area \(area) vs \(expectedArea)")
                var maxRing: Double = 0
                var minRing: Double = .infinity
                for i in m.positions.indices {
                    let p: Vec3 = m.positions[i]
                    #expect(abs(p.y - 0.01 * u) < 1e-12)
                    let ring: Double = max(abs(p.x - centre.x), abs(p.z - centre.z))
                    maxRing = max(maxRing, ring)
                    minRing = min(minRing, ring)
                    #expect(ring >= inner - 1e-12 && ring <= outer + 1e-12)
                    #expect(m.normals[i] == up)
                    #expect(m.uvs[i] == Vec2(Geometry.trackCode, 1))
                    let c: Vec4 = part.colours[i]
                    let silver: SIMD3<Double> = ChronoConstellatorPalette.silver
                    #expect(c == Vec4(silver.x, silver.y, silver.z, 1))
                }
                #expect(abs(maxRing - outer) < 1e-12 && abs(minRing - inner) < 1e-12)
                #expect(try Geometry.candidatePart(cell, s) == part)
            }
            for bad in [-1, s.columns * s.rows, Int.max, Int.min] {
                let empty: ChronoConstellatorColouredMesh = try Geometry.candidatePart(bad, s)
                #expect(empty.mesh.positions.isEmpty && empty.mesh.indices.isEmpty && empty.colours.isEmpty)
            }
        }
    }
}
