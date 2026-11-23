// EchoCartographerSceneGeometryTests — feature 403 (R02-G11-03) T-R02G1103-004 (FR-R02G1103-001, 003, 006;
// clarifications Q1, Q2, Q4). The chamber geometry of Echo Cartographer built from real plays (fixture levels and
// hand-made chambers, pulses, marks and claims applied through `EchoCartographerPlay`): every mesh is finite and bounded
// with one colour per vertex for 5 × 5 and 16 × 16 chambers with every cell known, none known but the entry, every wall
// known, 4 pillars, 8 markers, budgets 1 and 60, with and without a last pulse; every cell centre, wall top, pillar top
// and gauge bar projects inside the view with a 5 % margin at seven aspects 0.4 … 2.5; every position but the ring
// field's is the same at every tier; no vertex lies inside an unknown cell's footprint (the ground, the ring field and
// the player's own markers excepted); the gauge lights 0, half and all bars; the ring field is present exactly at tiers
// with rings; the material codes are exactly those of `EchoCartographerShaders`, each with its local coordinate layout;
// wall edge strips carry the struck distance. Painter's order (coordinator design change, depth testing off, culling
// on): flat layers, then solids back to front (ascending Z, outside in), each complete, then the gauge; every triangle
// winds to face up (flat) or outward (solids). Plain loops; well under 10 s each.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import EchoCartographerCore

@Suite struct EchoCartographerSceneGeometryTests {
    typealias Geometry = EchoCartographerSceneGeometry
    typealias Snapshot = EchoCartographerSceneSnapshot
    typealias Cell = EchoCartographerCell

    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]

    /// A play of `level` begun (tutorial dismissed), with `actions` applied while the play accepts them.
    static func play(_ level: EchoCartographerLevel, _ actions: [EchoCartographerAction]) throws -> EchoCartographerPlay {
        var play = EchoCartographerPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions where play.stage == .playing {
            try play.apply(action, expecting: play.fingerprint)
        }
        return play
    }

    /// A level of a `width` × `height` chamber with walls `walls` (cell indices).
    static func level(_ id: String, width: Int, height: Int, walls: Set<Int>, entry: Cell, beacons: [Cell],
                      energy: Int) throws -> EchoCartographerLevel {
        let chamber = try EchoCartographerChamber(width: width, height: height, walls: walls)
        return try EchoCartographerLevel(id: id, seed: 3, difficulty: 1, chamber: chamber, entry: entry,
                                         beacons: beacons, tolerance: 0, energy: energy, missCost: 1)
    }

    /// An open 16 × 16 chamber (budget 60): 16 pulses from column 0 reveal every cell, 8 markers, then the 4 beacons
    /// claimed (won; 4 pillars; 44 energy left).
    static func open16() throws -> Snapshot {
        let beacons: [Cell] = [Cell(x: 5, y: 5), Cell(x: 10, y: 3), Cell(x: 15, y: 15), Cell(x: 2, y: 12)]
        let lvl = try level("geometry-open-16", width: 16, height: 16, walls: [], entry: Cell(x: 0, y: 0),
                            beacons: beacons, energy: 60)
        var actions: [EchoCartographerAction] = []
        for y in 0..<16 { actions.append(.pulse(0, y)) }
        for k in 0..<8 { actions.append(.mark(k * 2, 15 - k)) }
        for b in beacons { actions.append(.claim(b.x, b.y)) }
        return Snapshot(play: try play(lvl, actions), levelNumber: 100, time: 0.4)
    }

    /// A 16 × 16 chamber walled on its border (the four corners open and unreachable), budget 60: pulses along row 1 and
    /// column 1 reveal every interior cell and every wall; the last pulse from (14, 1).
    static func bordered16() throws -> Snapshot {
        var walls: Set<Int> = []
        for i in 1..<15 {
            walls.insert(i)
            walls.insert(15 * 16 + i)
            walls.insert(i * 16)
            walls.insert(i * 16 + 15)
        }
        let lvl = try level("geometry-border-16", width: 16, height: 16, walls: walls, entry: Cell(x: 1, y: 1),
                            beacons: [Cell(x: 8, y: 8)], energy: 60)
        var actions: [EchoCartographerAction] = []
        for y in 1..<15 { actions.append(.pulse(1, y)) }
        for x in 2..<15 { actions.append(.pulse(x, 1)) }
        return Snapshot(play: try play(lvl, actions), levelNumber: 50, time: 2)
    }

    /// A 5 × 5 chamber (wall at the centre), budget 1; `pulsed`: one pulse from the entry (energy 0, failed).
    static func tiny5(pulsed: Bool) throws -> Snapshot {
        let lvl = try level("geometry-tiny-5", width: 5, height: 5, walls: [12], entry: Cell(x: 0, y: 2),
                            beacons: [Cell(x: 4, y: 4)], energy: 1)
        let actions: [EchoCartographerAction] = pulsed ? [.pulse(0, 2)] : []
        return Snapshot(play: try play(lvl, actions), levelNumber: 1, time: 0)
    }

    /// An open `width` × `height` chamber, budget `budget`, `pulses` pulses from the entry (0, 0).
    static func open(_ width: Int, _ height: Int, budget: Int, pulses: Int) throws -> Snapshot {
        let lvl = try level("geometry-open", width: width, height: height, walls: [], entry: Cell(x: 0, y: 0),
                            beacons: [Cell(x: width - 1, y: height - 1)], energy: budget)
        var actions: [EchoCartographerAction] = []
        for _ in 0..<pulses { actions.append(.pulse(0, 0)) }
        return Snapshot(play: try play(lvl, actions), levelNumber: 7, time: 1)
    }

    /// Fixture levels played through their known pulses and claims.
    static func fixtures() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for fixture in EchoCartographerFixtures.fixtures(6) {
            var actions: [EchoCartographerAction] = []
            for p in fixture.pulses { actions.append(.pulse(p.x, p.y)) }
            for c in fixture.claims { actions.append(.claim(c.x, c.y)) }
            result.append(Snapshot(play: try play(fixture.level, actions), levelNumber: 3, time: 0.25))
        }
        return result
    }

    static func snapshots() throws -> [Snapshot] {
        var all: [Snapshot] = [try open16(), try bordered16(), try tiny5(pulsed: false), try tiny5(pulsed: true),
                               try open(16, 5, budget: 60, pulses: 30), try open(5, 16, budget: 1, pulses: 0)]
        all.append(contentsOf: try fixtures())
        return all
    }

    static func code(_ m: Mesh, _ k: Int) -> Int { Int(m.uvs[k].x.rounded()) }

    static func point(_ v: Vec3) -> SIMD3<Double> { SIMD3(v.x, v.y, v.z) }

    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    /// The cell whose footprint holds world (x, z), or nil outside the chamber.
    static func cell(at p: SIMD3<Double>, _ s: Snapshot) -> Cell? {
        let size: Double = Geometry.cellSize(s)
        let fx: Double = p.x / size + Double(s.width) / 2
        let fz: Double = p.z / size + Double(s.height) / 2
        let x: Int = Int(fx.rounded(.down))
        let y: Int = Int(fz.rounded(.down))
        guard x >= 0, x < s.width, y >= 0, y < s.height else { return nil }
        return Cell(x: x, y: y)
    }

    /// Whether `p` lies strictly inside the footprint of `c` (1e-7 inside its border).
    static func strictlyInside(_ p: SIMD3<Double>, _ c: Cell, _ s: Snapshot) -> Bool {
        let centre: SIMD3<Double> = Geometry.cellCentre(c, s)
        let half: Double = Geometry.cellSize(s) / 2 - 1e-7
        return abs(p.x - centre.x) < half && abs(p.z - centre.z) < half
    }

    // MARK: Snapshots

    @Test func handMadeSnapshotsHaveTheirExtremes() throws {
        let o: Snapshot = try Self.open16()
        #expect(o.openCells.count == 256 && o.located.count == 4 && o.markers.count == 8 && o.stage == .won)
        #expect(o.energy == 44 && o.budget == 60 && o.lastEcho != nil)
        let b: Snapshot = try Self.bordered16()
        #expect(b.wallCells.count == 56 && b.openCells.count == 196 && b.energy == 33)
        let none: Snapshot = try Self.tiny5(pulsed: false)
        #expect(none.openCells == [Cell(x: 0, y: 2)] && none.wallCells.isEmpty && none.lastEcho == nil)
        let spent: Snapshot = try Self.tiny5(pulsed: true)
        #expect(spent.energy == 0 && spent.stage == .failed && spent.budget == 1 && spent.lastEcho != nil)
    }

    // MARK: Finite and bounded

    @Test func finiteAndBoundedForExtremeSnapshots() throws {
        for s in try Self.snapshots() {
            for tier in EchoCartographerTier.all {
                let parts: [EchoCartographerColouredMesh] = [try Geometry.chamberPart(s, tier: tier),
                                                             try Geometry.glowPart(s, tier: tier)]
                let meshes: [Mesh] = [try Geometry.chamberMesh(s, tier: tier, reduceMotion: false),
                                      try Geometry.chamberMesh(s, tier: tier, reduceMotion: true),
                                      try Geometry.glowMesh(s, tier: tier)]
                #expect(meshes[0] == meshes[1])
                #expect(meshes[2] == parts[1].mesh)
                for (index, part) in parts.enumerated() {
                    #expect(part.colours.count == part.mesh.positions.count)
                    #expect(part.mesh.indices.isEmpty == (index == 1 && (tier.glowShells == 0
                                                                        || (s.wallCells.isEmpty && s.located.isEmpty))))
                    for c in part.colours {
                        #expect(c.x >= 0 && c.x <= 1 && c.y >= 0 && c.y <= 1 && c.z >= 0 && c.z <= 1 && c.w == 1)
                    }
                }
                for m in meshes {
                    #expect(m.normals.count == m.positions.count && m.uvs.count == m.positions.count)
                    #expect(m.indices.count % 3 == 0)
                    #expect(m.indices.count / 3 < 60_000)
                    for i in m.indices { #expect(Int(i) < m.positions.count) }
                    var bad: Int = 0
                    for k in m.positions.indices {
                        let p: Vec3 = m.positions[k]
                        let n: Vec3 = m.normals[k]
                        let uv: Vec2 = m.uvs[k]
                        let finite: Bool = p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite
                            && n.y.isFinite && n.z.isFinite && uv.x.isFinite && uv.y.isFinite
                        let bounded: Bool = abs(p.x) <= 1.0 + 1e-9 && abs(p.z) <= 1.03 + 1e-9 && p.y >= -0.01 - 1e-12
                            && p.y <= 0.8
                        if !(finite && bounded) { bad += 1 }
                    }
                    #expect(bad == 0, "vertices not finite or out of bounds: \(bad), \(s.width)x\(s.height)")
                }
            }
        }
    }

    // MARK: Projection

    @Test func everyReferencePointProjectsInsideTheViewAtSevenAspects() throws {
        var snapshots: [Snapshot] = [try Self.tiny5(pulsed: true), try Self.open16(), try Self.bordered16()]
        snapshots.append(try Self.open(16, 5, budget: 60, pulses: 0))
        snapshots.append(try Self.open(5, 16, budget: 1, pulses: 0))
        for s in snapshots {
            var points: [SIMD3<Double>] = []
            for y in 0..<s.height {
                for x in 0..<s.width {
                    let c: Cell = Cell(x: x, y: y)
                    points.append(Geometry.cellCentre(c, s))
                    points.append(Geometry.wallTop(c, s))
                    points.append(Geometry.pillarTop(c, s))
                }
            }
            for bar in 0..<s.budget { points.append(Geometry.gaugeBar(bar, s)) }
            for index in 0..<8 { points.append(Geometry.corner(index)) }
            let refs: EchoCartographerReferencePoints = Geometry.referencePoints(s)
            points.append(refs.entry)
            points.append(refs.firstGaugeBar)
            points.append(contentsOf: refs.markers)
            for aspect in Self.aspects {
                let camera: EchoCartographerCamera = Geometry.camera(s, aspect: aspect)
                #expect(camera.eye == SIMD3(0, 2.4, 1.9) && camera.target == SIMD3(0, 0, 0.05))
                var outside: Int = 0
                for p in points {
                    guard let v = Geometry.project(p, camera: camera) else { outside += 1; continue }
                    if v.x < 0.05 || v.x > 0.95 || v.y < 0.05 || v.y > 0.95 { outside += 1 }
                }
                #expect(outside == 0, "points outside the 5 % margin: \(outside) at aspect \(aspect)")
            }
        }
    }

    @Test func referencePointsFollowClarificationQ1() throws {
        let s: Snapshot = try Self.bordered16()
        let size: Double = Geometry.cellSize(s)
        #expect(abs(size - 1.8 / 16) < 1e-15)
        let c: SIMD3<Double> = Geometry.cellCentre(Cell(x: 0, y: 15), s)
        #expect(abs(c.x - (0.5 - 8) * size) < 1e-12 && c.y == 0 && abs(c.z - (15.5 - 8) * size) < 1e-12)
        #expect(abs(Geometry.wallTop(Cell(x: 3, y: 0), s).y - 0.5 * size) < 1e-15)
        let refs: EchoCartographerReferencePoints = Geometry.referencePoints(s)
        #expect(refs.floors.count == s.openCells.count && refs.walls.count == s.wallCells.count)
        #expect(refs.entry.y == 0.005 && abs(refs.entry.x - (1.5 - 8) * size) < 1e-12)
        let first: SIMD3<Double> = refs.firstGaugeBar
        #expect(abs(first.x - (-0.9 + 0.015)) < 1e-12 && first.y == 0 && first.z == 1.0)
        let o: Snapshot = try Self.open16()
        let markers: [SIMD3<Double>] = Geometry.referencePoints(o).markers
        #expect(markers.count == 8)
        for m in markers { #expect(m.y == 0.01) }
    }

    // MARK: Tiers

    @Test func positionsAreTheSameAtEveryTierButTheRingField() throws {
        for s in try Self.snapshots() {
            var reference: [Vec3]? = nil
            for tier in EchoCartographerTier.all {
                let m: Mesh = try Geometry.chamberMesh(s, tier: tier, reduceMotion: false)
                var positions: [Vec3] = []
                var rings: Int = 0
                for k in m.positions.indices {
                    if Self.code(m, k) == Geometry.Material.ring.rawValue { rings += 1 } else {
                        positions.append(m.positions[k])
                    }
                }
                #expect(rings == (tier.rings ? 4 : 0), "ring field vertices \(rings) at \(tier.name)")
                if let r = reference { #expect(r == positions) } else { reference = positions }
                let part: Mesh = try Geometry.chamberPart(s, tier: tier).mesh
                #expect(part.positions == positions)
            }
        }
    }

    // MARK: Hidden cells

    @Test func noVertexInsideAnUnknownCell() throws {
        for s in try Self.snapshots() {
            for tier in EchoCartographerTier.all {
                let meshes: [(Mesh, Bool)] = [(try Geometry.chamberMesh(s, tier: tier, reduceMotion: false), true),
                                              (try Geometry.glowMesh(s, tier: tier), false)]
                for (m, chamber) in meshes {
                    var hits: Int = 0
                    for k in m.positions.indices {
                        if chamber {
                            let code: Int = Self.code(m, k)
                            if code == Geometry.Material.ground.rawValue || code == Geometry.Material.ring.rawValue {
                                continue
                            }
                        }
                        let p: SIMD3<Double> = Self.point(m.positions[k])
                        guard let c = Self.cell(at: p, s), s.known(c) == .unknown,
                              Self.strictlyInside(p, c, s) else { continue }
                        if chamber && Self.code(m, k) == Geometry.Material.marker.rawValue && s.markers.contains(c) {
                            continue
                        }
                        hits += 1
                    }
                    #expect(hits == 0, "vertices on unknown cells: \(hits) at \(tier.name)")
                }
            }
        }
    }

    @Test func snapshotsHoldNoUnlocatedBeaconPillar() throws {
        for s in try Self.snapshots() {
            let m: Mesh = try Geometry.chamberMesh(s, tier: EchoCartographerTier.of(0), reduceMotion: false)
            var pillarCells: Set<Cell> = []
            for k in m.positions.indices where Self.code(m, k) == Geometry.Material.pillar.rawValue {
                if let c = Self.cell(at: Self.point(m.positions[k]), s) { pillarCells.insert(c) }
            }
            #expect(pillarCells == Set(s.located))
        }
    }

    // MARK: Gauge

    @Test func gaugeLightsTheEnergyLeft() throws {
        let cases: [(Snapshot, Int, Int)] = [(try Self.open(16, 16, budget: 60, pulses: 0), 60, 0),
                                              (try Self.open(16, 16, budget: 60, pulses: 30), 30, 30),
                                              (try Self.open(16, 16, budget: 60, pulses: 60), 0, 60),
                                              (try Self.tiny5(pulsed: false), 1, 0),
                                              (try Self.tiny5(pulsed: true), 0, 1)]
        for (s, lit, unlit) in cases {
            #expect(Geometry.litBars(s) == lit)
            let m: Mesh = try Geometry.chamberMesh(s, tier: EchoCartographerTier.of(2), reduceMotion: false)
            var litCentres: Int = 0
            var unlitCentres: Int = 0
            for k in m.positions.indices where m.uvs[k].y == 0 {
                let code: Int = Self.code(m, k)
                if code == Geometry.Material.gaugeLit.rawValue { litCentres += 1 }
                if code == Geometry.Material.gaugeUnlit.rawValue { unlitCentres += 1 }
            }
            #expect(litCentres == lit && unlitCentres == unlit, "lit \(litCentres) unlit \(unlitCentres)")
            // The first bars are lit; bar k's centre is its fan centre.
            for k in m.positions.indices where m.uvs[k].y == 0 {
                let code: Int = Self.code(m, k)
                guard code == Geometry.Material.gaugeLit.rawValue || code == Geometry.Material.gaugeUnlit.rawValue
                else { continue }
                let p: Vec3 = m.positions[k]
                let index: Int = Int(((p.x + 0.9) / Geometry.gaugeSlot(s) - 0.5).rounded())
                let expected: SIMD3<Double> = Geometry.gaugeBar(index, s)
                #expect(abs(p.x - expected.x) < 1e-12 && p.y == 0 && p.z == 1.0)
                #expect((index < lit) == (code == Geometry.Material.gaugeLit.rawValue))
            }
        }
    }

    @Test func gaugeBarsFillFourFifthsOfTheirSlot() throws {
        for budget in [1, 60] {
            let s: Snapshot = try Self.open(5, 5, budget: budget, pulses: 0)
            let m: Mesh = try Geometry.chamberMesh(s, tier: EchoCartographerTier.of(0), reduceMotion: false)
            var low: Double = Double.infinity
            var high: Double = -Double.infinity
            var zLow: Double = Double.infinity
            var zHigh: Double = -Double.infinity
            for k in m.positions.indices where Self.code(m, k) == Geometry.Material.gaugeLit.rawValue {
                low = min(low, m.positions[k].x)
                high = max(high, m.positions[k].x)
                zLow = min(zLow, m.positions[k].z)
                zHigh = max(zHigh, m.positions[k].z)
            }
            let slot: Double = 1.8 / Double(budget)
            #expect(abs(low - (-0.9 + 0.1 * slot)) < 1e-12 && abs(high - (0.9 - 0.1 * slot)) < 1e-12)
            #expect(abs(zLow - 0.97) < 1e-12 && abs(zHigh - 1.03) < 1e-12)
        }
    }

    // MARK: Materials

    @Test func materialCodesAreExactlyTheShadersAndFollowTheirLocalLayout() throws {
        let s: Snapshot = try Self.open(16, 16, budget: 60, pulses: 30)
        // A snapshot with every material: walls (bordered), pillars and markers (open16) are checked together.
        let rich: [Snapshot] = [try Self.bordered16(), try Self.open16(), s]
        var used: Set<Int> = []
        for snapshot in rich {
            let m: Mesh = try Geometry.chamberMesh(snapshot, tier: EchoCartographerTier.of(0), reduceMotion: false)
            for k in m.positions.indices {
                let code: Int = Self.code(m, k)
                used.insert(code)
                #expect(m.uvs[k].x == Double(code))
                guard let material = Geometry.Material(rawValue: code) else {
                    Issue.record("unknown material code \(code)")
                    continue
                }
                let d: Double = m.uvs[k].y
                switch material.localCoordinate {
                case .none: #expect(d == 0)
                case .fan: #expect(d == 0 || d == 1)
                case .strip: #expect(d == -1 || d == 1 || (material == .wallEdge && d == 0))
                }
                if material != .wallEdge {
                    let n: Vec3 = m.normals[k]
                    #expect(abs(n.x * n.x + n.y * n.y + n.z * n.z - 1) < 1e-12)
                }
            }
        }
        var shaders: Set<Int> = []
        for material in EchoCartographerShaders.ChamberMaterial.allCases { shaders.insert(material.rawValue) }
        #expect(used == shaders)
        #expect(EchoCartographerShaders.wallEdgeMaterial == Geometry.Material.wallEdge.rawValue)
    }

    @Test func glowShellsCarryTheGlowColourAndFactor() throws {
        let s: Snapshot = try Self.open16()
        let b: Snapshot = try Self.bordered16()
        for snapshot in [s, b] {
            for tier in EchoCartographerTier.all {
                let part: EchoCartographerColouredMesh = try Geometry.glowPart(snapshot, tier: tier)
                var factors: Set<Double> = []
                for k in part.mesh.positions.indices {
                    let n: Vec3 = part.mesh.normals[k]
                    let g: SIMD3<Double> = EchoCartographerPalette.glow
                    #expect(n.x == g.x && n.y == g.y && n.z == g.z && part.mesh.uvs[k].y == 0)
                    factors.insert(part.mesh.uvs[k].x)
                }
                var expected: Set<Double> = []
                if tier.glowShells > 0 {
                    for k in 1...tier.glowShells { expected.insert(pow(0.5, Double(k))) }
                }
                #expect(factors == expected)
            }
        }
    }

    // MARK: Flares

    @Test func wallEdgeStripsCarryTheStruckDistance() throws {
        let lvl: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        // Pulse 1 from (0, 0): the east ray strikes (3, 0) at distance 3.
        let one: Snapshot = Snapshot(play: try Self.play(lvl, [.pulse(0, 0)]), levelNumber: 1, time: 0)
        try expectStrikes(one, [Cell(x: 3, y: 0): 3])
        // Pulse 2 from (2, 0): (3, 0) at 1, (2, 3) at 3.
        let two: Snapshot = Snapshot(play: try Self.play(lvl, [.pulse(0, 0), .pulse(2, 0)]), levelNumber: 1, time: 0)
        try expectStrikes(two, [Cell(x: 3, y: 0): 1, Cell(x: 2, y: 3): 3])
        // Pulse 3 from (0, 2): only (1, 2) at 1; the earlier walls rest at 0.
        let three: Snapshot = Snapshot(play: try Self.play(lvl, [.pulse(0, 0), .pulse(2, 0), .pulse(0, 2)]),
                                       levelNumber: 1, time: 0)
        try expectStrikes(three, [Cell(x: 3, y: 0): 0, Cell(x: 2, y: 3): 0, Cell(x: 1, y: 2): 1])
    }

    /// Every edge-strip vertex of each wall in `expected` carries (distance, 0, 0) in its normal, and every known wall
    /// has 12 edges (24 folded halves, 48 triangles).
    func expectStrikes(_ s: Snapshot, _ expected: [Cell: Int]) throws {
        #expect(Set(s.wallCells) == Set(expected.keys))
        let m: Mesh = try Geometry.chamberMesh(s, tier: EchoCartographerTier.of(0), reduceMotion: false)
        var seen: [Cell: Int] = [:]
        for k in m.positions.indices where Self.code(m, k) == Geometry.Material.wallEdge.rawValue {
            guard let c = Self.cell(at: Self.point(m.positions[k]), s), let distance = expected[c] else {
                Issue.record("edge vertex outside a known wall")
                continue
            }
            let n: Vec3 = m.normals[k]
            #expect(n.x == Double(distance) && n.y == 0 && n.z == 0, "struck distance \(n.x) for \(c.x), \(c.y)")
            seen[c, default: 0] += 1
        }
        #expect(Set(seen.keys) == Set(expected.keys))
        var triangles: [Cell: Int] = [:]
        var t: Int = 0
        while t + 2 < m.indices.count {
            let a: Int = Int(m.indices[t])
            if Self.code(m, a) == Geometry.Material.wallEdge.rawValue {
                var centroid: SIMD3<Double> = SIMD3(0, 0, 0)
                for j in 0..<3 { centroid += Self.point(m.positions[Int(m.indices[t + j])]) }
                if let c = Self.cell(at: centroid / 3, s) { triangles[c, default: 0] += 1 }
            }
            t += 3
        }
        for c in expected.keys { #expect(triangles[c] == 48, "edge triangles \(triangles[c] ?? 0)") }
        let rays: Int = s.lastEcho?.rays.count ?? 0
        var rayVertices: Int = 0
        for k in m.positions.indices where Self.code(m, k) == Geometry.Material.ray.rawValue { rayVertices += 1 }
        #expect(rayVertices == 4 * rays)
    }

    @Test func raysEndAtTheStruckFaceOrTheEdge() throws {
        let lvl: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        let s: Snapshot = Snapshot(play: try Self.play(lvl, [.pulse(0, 0)]), levelNumber: 1, time: 0)
        guard let echo = s.lastEcho else { Issue.record("no echo"); return }
        let size: Double = Geometry.cellSize(s)
        for ray in echo.rays {
            let end: SIMD3<Double> = Geometry.rayEnd(ray, from: echo.emitter, s)
            let start: SIMD3<Double> = Geometry.cellCentre(echo.emitter, s)
            let length: Double = abs(end.x - start.x) + abs(end.z - start.z)
            #expect(abs(length - (Double(ray.distance) - 0.5) * size) < 1e-12)
            if ray.wall == nil {
                let half: SIMD2<Double> = Geometry.halfExtent(s)
                #expect(abs(abs(end.x) - half.x) < 1e-12 || abs(abs(end.z) - half.y) < 1e-12)
            }
        }
    }

    // MARK: Painter's order and winding

    @Test func meshIsInPaintersOrder() throws {
        var snapshots: [Snapshot] = [try Self.open16(), try Self.bordered16()]
        snapshots.append(contentsOf: try Self.fixtures())
        for s in snapshots {
            let m: Mesh = try Geometry.chamberMesh(s, tier: EchoCartographerTier.of(0), reduceMotion: false)
            var phase: Int = 0
            var phaseErrors: Int = 0
            var solids: [Cell] = []
            var finished: Set<Cell> = []
            var edgesStarted: Bool = false
            var orderErrors: Int = 0
            var t: Int = 0
            while t + 2 < m.indices.count {
                let code: Int = Self.code(m, Int(m.indices[t]))
                let here: Int = code <= 5 ? 0 : (code <= 8 ? 1 : 2)
                if here < phase { phaseErrors += 1 }
                phase = max(phase, here)
                if here == 1 {
                    var centroid: SIMD3<Double> = SIMD3(0, 0, 0)
                    for j in 0..<3 { centroid += Self.point(m.positions[Int(m.indices[t + j])]) }
                    guard let c = Self.cell(at: centroid / 3, s) else { orderErrors += 1; t += 3; continue }
                    if solids.last != c {
                        if finished.contains(c) { orderErrors += 1 }
                        if let previous = solids.last {
                            finished.insert(previous)
                            if !Self.drawnBefore(previous, c, s) { orderErrors += 1 }
                        }
                        solids.append(c)
                        edgesStarted = false
                    }
                    if code == Geometry.Material.wallEdge.rawValue { edgesStarted = true }
                    if code == Geometry.Material.wallFace.rawValue && edgesStarted { orderErrors += 1 }
                }
                t += 3
            }
            #expect(phaseErrors == 0, "flat, solid, gauge phases out of order: \(phaseErrors)")
            #expect(orderErrors == 0, "solids out of painter's order: \(orderErrors)")
            #expect(solids.count == s.wallCells.count + s.located.count)
            var order: [Cell] = []
            for solid in Geometry.solidOrder(s) { order.append(solid.cell) }
            #expect(order == solids)
        }
    }

    /// Whether `a` is drawn before `b`: ascending row (Z), then descending |X|, then ascending X.
    static func drawnBefore(_ a: Cell, _ b: Cell, _ s: Snapshot) -> Bool {
        if a.y != b.y { return a.y < b.y }
        let da: Double = abs(Geometry.cellCentre(a, s).x)
        let db: Double = abs(Geometry.cellCentre(b, s).x)
        if abs(da - db) > 1e-12 { return da > db }
        return a.x < b.x
    }

    @Test func everyTriangleFacesUpOrOutward() throws {
        let snapshots: [Snapshot] = [try Self.open16(), try Self.bordered16(), try Self.tiny5(pulsed: true)]
        for s in snapshots {
            for tier in EchoCartographerTier.all {
                let meshes: [(Mesh, Bool)] = [(try Geometry.chamberMesh(s, tier: tier, reduceMotion: false), true),
                                              (try Geometry.glowMesh(s, tier: tier), false)]
                for (m, chamber) in meshes {
                    var wrong: Int = 0
                    var t: Int = 0
                    while t + 2 < m.indices.count {
                        let ia: Int = Int(m.indices[t])
                        let a: SIMD3<Double> = Self.point(m.positions[ia])
                        let b: SIMD3<Double> = Self.point(m.positions[Int(m.indices[t + 1])])
                        let c: SIMD3<Double> = Self.point(m.positions[Int(m.indices[t + 2])])
                        let n: SIMD3<Double> = Self.cross(b - a, c - a)
                        let code: Int = Self.code(m, ia)
                        let flat: Bool = chamber && (code <= 5 || code >= 9)
                        if flat {
                            if !(n.y > 0) { wrong += 1 }
                        } else {
                            let centroid: SIMD3<Double> = (a + b + c) / 3
                            guard let cell = Self.cell(at: centroid, s) else { wrong += 1; t += 3; continue }
                            let centre: SIMD3<Double> = Geometry.cellCentre(cell, s)
                            // Outward along the normal's dominant axis: up, or away from the cell's centre.
                            if !Self.outward(n, centroid - centre) { wrong += 1 }
                            if chamber && code != Geometry.Material.wallEdge.rawValue {
                                let normal: SIMD3<Double> = Self.point(m.normals[ia])
                                if !(Self.dot(n, normal) > 0) { wrong += 1 }
                            }
                        }
                        t += 3
                    }
                    #expect(wrong == 0, "triangles facing the wrong way: \(wrong) at \(tier.name)")
                }
            }
        }
    }

    /// Whether the triangle normal `n` faces outward for a triangle at offset `r` from its cell's centre: along its
    /// dominant axis it points up (y) or the same way as `r` (x, z).
    static func outward(_ n: SIMD3<Double>, _ r: SIMD3<Double>) -> Bool {
        let ax: Double = abs(n.x)
        let ay: Double = abs(n.y)
        let az: Double = abs(n.z)
        if ay >= ax && ay >= az { return n.y > 0 }
        if ax >= az { return n.x * r.x > 0 }
        return n.z * r.z > 0
    }

    // MARK: Fallback

    @Test func fallbackPartsUseUnlitPaletteColoursWithoutFlare() throws {
        let s: Snapshot = try Self.open16()
        let b: Snapshot = try Self.bordered16()
        for snapshot in [s, b] {
            let part: EchoCartographerColouredMesh = try Geometry.chamberPart(snapshot, tier: EchoCartographerTier.of(2))
            #expect(!part.mesh.indices.isEmpty)
            for k in part.mesh.positions.indices {
                let code: Int = Self.code(part.mesh, k)
                #expect(code != Geometry.Material.ring.rawValue)
                guard let material = Geometry.Material(rawValue: code) else { continue }
                let c: Vec4 = part.colours[k]
                let expected: SIMD3<Double> = material.colour
                #expect(abs(c.x - expected.x) < 1e-12 && abs(c.y - expected.y) < 1e-12
                        && abs(c.z - expected.z) < 1e-12 && c.w == 1)
            }
            let glow: EchoCartographerColouredMesh = try Geometry.glowPart(snapshot, tier: EchoCartographerTier.of(0))
            #expect(!glow.mesh.indices.isEmpty)
            for k in glow.mesh.positions.indices {
                let f: Double = glow.mesh.uvs[k].x
                let c: Vec4 = glow.colours[k]
                #expect(abs(c.x - EchoCartographerPalette.glow.x * f) < 1e-12 && c.w == 1)
            }
        }
    }

    @Test func cameraIsFixedAndSanitisesAspects() throws {
        let s: Snapshot = try Self.tiny5(pulsed: false)
        let o: Snapshot = try Self.open16()
        for aspect in Self.aspects {
            #expect(Geometry.camera(s, aspect: aspect) == Geometry.camera(o, aspect: aspect))
            let camera: EchoCartographerCamera = Geometry.camera(s, aspect: aspect)
            #expect(camera.fovY > 0 && camera.fovY < Double.pi && camera.near > 0 && camera.far > camera.near)
        }
        #expect(Geometry.camera(s, aspect: .nan).aspect == 1)
        #expect(Geometry.camera(s, aspect: -2).aspect == 1)
        #expect(Geometry.camera(s, aspect: 100).aspect == 10)
        #expect(Geometry.project(SIMD3(.nan, 0, 0), camera: Geometry.camera(s, aspect: 1)) == nil)
        #expect(Geometry.project(SIMD3(0, 5, 5), camera: Geometry.camera(s, aspect: 1)) == nil)
    }

    /// Feature 403 convergence (T-R02G1103-014): on a won level every wall edge vertex carries the won flag 1 in the
    /// normal slot's y, and 0 before the win; positions are unchanged.
    @Test func aWonLevelFlagsEveryWallEdge() throws {
        let generated: EchoCartographerGenerated = try EchoCartographerExperienceCore.generated(number: 1)
        var play: EchoCartographerPlay = EchoCartographerPlay(level: generated.level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        let actions: [EchoCartographerAction] = generated.actions
        for action in actions.dropLast() { try play.apply(action, expecting: play.fingerprint) }
        let before: EchoCartographerSceneSnapshot = EchoCartographerSceneSnapshot(play: play, levelNumber: 1, time: 0)
        if let last = actions.last { try play.apply(last, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        let after: EchoCartographerSceneSnapshot = EchoCartographerSceneSnapshot(play: play, levelNumber: 1, time: 0)
        #expect(EchoCartographerSceneGeometry.wonFlag(before) == 0)
        #expect(EchoCartographerSceneGeometry.wonFlag(after) == 1)
        let tier: EchoCartographerTier = EchoCartographerTier.of(0)
        let meshBefore = try EchoCartographerSceneGeometry.chamberMesh(before, tier: tier, reduceMotion: false)
        let meshAfter = try EchoCartographerSceneGeometry.chamberMesh(after, tier: tier, reduceMotion: false)
        let edge: Double = Double(EchoCartographerShaders.wallEdgeMaterial)
        var edgesBefore: Int = 0
        var edgesAfter: Int = 0
        for index in 0..<meshBefore.positions.count where abs(meshBefore.uvs[index].x - edge) < 0.01 {
            edgesBefore += 1
            #expect(meshBefore.normals[index].y == 0)
        }
        for index in 0..<meshAfter.positions.count where abs(meshAfter.uvs[index].x - edge) < 0.01 {
            edgesAfter += 1
            #expect(meshAfter.normals[index].y == 1)
        }
        #expect(edgesBefore > 0 && edgesAfter >= edgesBefore)
    }

    // MARK: Orbit (feature 404, R02-G11-04, T-R02G1104-002)

    /// Nine orbits: the authored one, the four clamp corners, the pitch extremes at yaw 0, the yaw extreme at pitch 0 and
    /// a middle one.
    static func orbits() -> [EchoCartographerOrbit] {
        let y: Double = EchoCartographerOrbit.yawLimit
        let lo: Double = EchoCartographerOrbit.pitchRange.lowerBound
        let hi: Double = EchoCartographerOrbit.pitchRange.upperBound
        return [EchoCartographerOrbit.authored, EchoCartographerOrbit(yaw: y, pitch: hi),
                EchoCartographerOrbit(yaw: -y, pitch: hi), EchoCartographerOrbit(yaw: y, pitch: lo),
                EchoCartographerOrbit(yaw: -y, pitch: lo), EchoCartographerOrbit(yaw: 0, pitch: lo),
                EchoCartographerOrbit(yaw: 0, pitch: hi), EchoCartographerOrbit(yaw: y, pitch: 0),
                EchoCartographerOrbit(yaw: -0.3, pitch: 0.1)]
    }

    /// NDC (x, y) of `p` through `camera`, or nil behind the eye.
    static func ndc(_ p: SIMD3<Double>, _ camera: EchoCartographerCamera) -> SIMD2<Double>? {
        let clip: Vec4 = camera.viewProjection * Vec4(Vec3(p.x, p.y, p.z), 1)
        guard clip.w > 0 else { return nil }
        return SIMD2(clip.x / clip.w, clip.y / clip.w)
    }

    @Test func everyOrbitKeepsTheAuthoredBoxInsideTheMargin() throws {
        let s: Snapshot = try Self.tiny5(pulsed: false)
        let bound: Double = 1 - 2 * Geometry.fitMargin
        #expect(bound <= 0.9)
        for orbit in Self.orbits() {
            for aspect in Self.aspects {
                let camera: EchoCartographerCamera = Geometry.camera(s, aspect: aspect, orbit: orbit)
                var largest: Double = 0
                for index in 0..<8 {
                    guard let v = Self.ndc(Geometry.corner(index), camera) else {
                        Issue.record("corner \(index) behind the eye at \(orbit), aspect \(aspect)")
                        continue
                    }
                    #expect(abs(v.x) <= bound + 1e-9 && abs(v.y) <= bound + 1e-9,
                            "corner \(index) at \(v) outside the margin at \(orbit), aspect \(aspect)")
                    largest = max(largest, abs(v.x), abs(v.y))
                }
                // The field of view is the smallest that fits: some corner touches the margin.
                #expect(abs(largest - bound) < 1e-9, "fit not tight: \(largest) at \(orbit), aspect \(aspect)")
                #expect(camera.target == Geometry.lookAt)
                let offset: SIMD3<Double> = camera.eye - Geometry.lookAt
                let authored: SIMD3<Double> = Geometry.eye - Geometry.lookAt
                let lengths: Double = Self.dot(offset, offset).squareRoot() - Self.dot(authored, authored).squareRoot()
                #expect(abs(lengths) < 1e-12)
            }
        }
    }

    @Test func positivePitchRaisesTheEyeAndPositiveYawMovesItTowardsPlusX() throws {
        let s: Snapshot = try Self.tiny5(pulsed: false)
        let base: EchoCartographerCamera = Geometry.camera(s, aspect: 1)
        let up: EchoCartographerCamera = Geometry.camera(s, aspect: 1, orbit: EchoCartographerOrbit(yaw: 0, pitch: 0.2))
        let down: EchoCartographerCamera = Geometry.camera(s, aspect: 1,
                                                           orbit: EchoCartographerOrbit(yaw: 0, pitch: -0.2))
        let side: EchoCartographerCamera = Geometry.camera(s, aspect: 1, orbit: EchoCartographerOrbit(yaw: 0.3, pitch: 0))
        #expect(up.eye.y > base.eye.y && up.eye.z < base.eye.z && up.eye.x == 0)
        #expect(down.eye.y < base.eye.y && down.eye.z > base.eye.z)
        #expect(side.eye.x > 0 && side.eye.y == base.eye.y)
    }

    @Test func theAuthoredOrbitIsTheFixedCameraBitForBit() throws {
        let s: Snapshot = try Self.tiny5(pulsed: false)
        var aspects: [Double] = Self.aspects
        aspects.append(contentsOf: [0.05, 20, 0, -1, .nan, .infinity])
        for aspect in aspects {
            let fixed: EchoCartographerCamera = Geometry.camera(s, aspect: aspect)
            let orbit: EchoCartographerCamera = Geometry.camera(s, aspect: aspect, orbit: .authored)
            #expect(fixed == orbit)
            #expect(fixed.fovY.bitPattern == orbit.fovY.bitPattern && fixed.near.bitPattern == orbit.near.bitPattern
                    && fixed.far.bitPattern == orbit.far.bitPattern)
            #expect(fixed.eye.x.bitPattern == orbit.eye.x.bitPattern && fixed.eye.y.bitPattern == orbit.eye.y.bitPattern
                    && fixed.eye.z.bitPattern == orbit.eye.z.bitPattern)
            #expect(fixed.eye == Geometry.eye)
            // A non-finite orbit is the authored one.
            let odd: EchoCartographerCamera = Geometry.camera(s, aspect: aspect,
                                                              orbit: EchoCartographerOrbit(yaw: .nan, pitch: .infinity))
            #expect(odd == fixed)
        }
    }

    @Test func clampedBoundsTheOrbit() {
        let y: Double = EchoCartographerOrbit.yawLimit
        let lo: Double = EchoCartographerOrbit.pitchRange.lowerBound
        let hi: Double = EchoCartographerOrbit.pitchRange.upperBound
        #expect(abs(y - 35.0 * Double.pi / 180) < 1e-15)
        #expect(abs(lo + 15.0 * Double.pi / 180) < 1e-15 && abs(hi - 20.0 * Double.pi / 180) < 1e-15)
        #expect(EchoCartographerOrbit.authored == EchoCartographerOrbit(yaw: 0, pitch: 0))
        #expect(EchoCartographerOrbit(yaw: 5, pitch: 5).clamped() == EchoCartographerOrbit(yaw: y, pitch: hi))
        #expect(EchoCartographerOrbit(yaw: -5, pitch: -5).clamped() == EchoCartographerOrbit(yaw: -y, pitch: lo))
        #expect(EchoCartographerOrbit(yaw: 0.2, pitch: -0.1).clamped() == EchoCartographerOrbit(yaw: 0.2, pitch: -0.1))
        #expect(EchoCartographerOrbit(yaw: .nan, pitch: .infinity).clamped() == EchoCartographerOrbit.authored)
        #expect(EchoCartographerOrbit(yaw: -.infinity, pitch: .nan).clamped() == EchoCartographerOrbit.authored)
        let s: SIMD3<Double> = Geometry.orbitEye(EchoCartographerOrbit(yaw: 9, pitch: -9))
        #expect(s == Geometry.orbitEye(EchoCartographerOrbit(yaw: y, pitch: lo)))
    }
}
