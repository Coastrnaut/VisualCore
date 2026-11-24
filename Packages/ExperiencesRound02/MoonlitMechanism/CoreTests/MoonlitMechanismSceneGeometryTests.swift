// MoonlitMechanismSceneGeometryTests — feature 433 (R02-G14-03) T-R02G1403-004 (FR-R02G1403-001, 002, 003, 004, 006;
// clarifications Q1 … Q4; SC-R02G1403-001). The clockwork geometry of Moonlit Mechanism built from real plays
// (hand-made levels whose key-frame targets are their own casts, and the 100 catalog levels of R02-G14-02): every mesh
// is finite and bounded with one colour per vertex for 2 and 5 gears, 6 and 20 teeth, walls 8 × 6 and 24 × 16, every
// lamp height, budgets 1 and 40 and 2 and 6 key frames; every cast cell, gear (centre, rim check point and tooth-tip
// extremes), card, pip, moves bar and the lamp projects inside the view with a 5 % margin at seven aspects 0.4 … 2.5
// for every catalog level; positions are the same at every tier and only the gears' outline segments, the feathers
// and the glow differ; the ink squares are exactly the kernel's cast cells of the shown key frame; tooth zero turns with the
// phase and in the gear's direction; the moves gauge lights all, half and none of 40 bars; a won level is brighter
// (fallback paper and a wall glow shell) and nothing moves; the glow is empty at level-2 with 2 and 1 lamp shells at
// level-0 and level-1; failures outline the jammed pair or the failing card; the vertex streams follow the shader
// conventions. Plain loops and explicit types (CI type-check rule); well under 10 s each.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import MoonlitMechanismCore

/// The catalog levels of this test process, generated once.
private let catalogLevels: Result<[MoonlitMechanismLevel], any Error> = Result {
    var levels: [MoonlitMechanismLevel] = []
    for entry in MoonlitMechanismManifest.entries { levels.append(try MoonlitMechanismGenerator.generate(entry).level) }
    return levels
}

@Suite struct MoonlitMechanismSceneGeometryTests {
    typealias Geometry = MoonlitMechanismSceneGeometry
    typealias Snapshot = MoonlitMechanismSceneSnapshot
    typealias Material = MoonlitMechanismShaders.Material

    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]
    static let compass: [(Int, Int)] = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]

    // MARK: Levels and plays

    /// A level of `count` gears in a chain (each meshing with the previous one, alignment 0, phases 0), `teeth` teeth
    /// each, alternate blades solid, depths 1, 2, 3, …, slot k pointing compass direction 8k / T with a ray of 2 cells,
    /// centres spread along a row; key frame k at k turns whose target is exactly its cast at lamp height 0 (so the
    /// start wins at height 0); one forbidden cell no key frame casts.
    static func level(gears count: Int, teeth: Int, width: Int, rows: Int, lampHeights: Int, startingHeight: Int,
                      frames: Int, budget: Int) throws -> MoonlitMechanismLevel {
        var gears: [MoonlitMechanismGear] = []
        let step: Int = max((width - 4) / max(count - 1, 1), 1)
        for index in 0..<count {
            var blades: [Bool] = []
            for bit in 0..<teeth { blades.append(bit % 2 == 0) }
            var slots: [[MoonlitMechanismCell]] = []
            for k in 0..<teeth {
                let d: (Int, Int) = compass[(8 * k) / teeth]
                slots.append([MoonlitMechanismCell(column: d.0, row: d.1),
                              MoonlitMechanismCell(column: 2 * d.0, row: 2 * d.1)])
            }
            let centre: MoonlitMechanismCell = MoonlitMechanismCell(column: min(width - 1, 2 + index * step),
                                                                    row: rows / 2 - 1)
            gears.append(MoonlitMechanismGear(teeth: teeth, phase: 0, blades: blades, depth: 1 + index % 3,
                                              centre: centre, parent: index == 0 ? nil : index - 1, alignment: 0,
                                              slots: slots))
        }
        let zeros: [Int] = Array(repeating: 0, count: count)
        var keyFrames: [MoonlitMechanismKeyFrame] = []
        var cast: Set<Int> = []
        for k in 0..<frames {
            let phases: [Int] = MoonlitMechanismTrain.turned(gears, phases: zeros, by: k)
            let cells: [Int] = MoonlitMechanismTrain.cast(gears, phases: phases, height: 0, width: width, rows: rows)
            keyFrames.append(MoonlitMechanismKeyFrame(turns: k, target: cells, required: true))
            cast.formUnion(cells)
        }
        var forbidden: [Int] = []
        var cell: Int = width * rows - 1
        while forbidden.isEmpty, cell >= 0 {
            if !cast.contains(cell) { forbidden.append(cell) }
            cell -= 1
        }
        return try MoonlitMechanismLevel(id: "geometry-\(count)-\(teeth)-\(width)-\(rows)", seed: 1, difficulty: 1,
                                         gears: gears, width: width, rows: rows, lampHeights: lampHeights,
                                         startingHeight: startingHeight, keyFrames: keyFrames, forbidden: forbidden,
                                         allowance: 0, budget: budget)
    }

    /// A small level: 3 gears of 12 teeth on a 16 × 12 wall, 4 lamp heights, 3 key frames, budget `budget`.
    static func small(budget: Int = 40) throws -> MoonlitMechanismLevel {
        try level(gears: 3, teeth: 12, width: 16, rows: 12, lampHeights: 4, startingHeight: 0, frames: 3,
                  budget: budget)
    }

    /// A begun play of `level` (tutorial dismissed) with `actions` applied while the play accepts them.
    static func play(_ level: MoonlitMechanismLevel,
                     _ actions: [MoonlitMechanismAction]) throws -> MoonlitMechanismPlay {
        var play: MoonlitMechanismPlay = MoonlitMechanismPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions where play.stage == .playing {
            try play.apply(action, expecting: play.fingerprint)
        }
        return play
    }

    /// The snapshot of `level` after `actions` with key frame `frame` shown.
    static func snapshot(_ level: MoonlitMechanismLevel, _ actions: [MoonlitMechanismAction] = [],
                         frame: Int = 0) throws -> Snapshot {
        Snapshot(play: try play(level, actions), shownFrame: frame, levelNumber: 1, time: 0)
    }

    /// The 100 catalog levels.
    static func catalog() throws -> [MoonlitMechanismLevel] { try catalogLevels.get() }

    // MARK: Mesh helpers

    /// Whether every position, normal and uv is finite, positions lie in a generous box, indices are in range and
    /// whole triangles, and there is one colour (components 0 … 1) per vertex.
    static func isSound(_ part: MoonlitMechanismColouredMesh) -> Bool {
        let mesh: Mesh = part.mesh
        guard part.colours.count == mesh.positions.count, mesh.normals.count == mesh.positions.count,
              mesh.uvs.count == mesh.positions.count, mesh.indices.count % 3 == 0 else { return false }
        for p in mesh.positions {
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite, abs(p.x) <= 2.5, p.y >= -1.5, p.y <= 3,
                  p.z >= -0.7, p.z <= 0.5 else { return false }
        }
        for n in mesh.normals where !(n.x.isFinite && n.y.isFinite && n.z.isFinite) { return false }
        for uv in mesh.uvs where !(uv.x.isFinite && uv.y.isFinite) { return false }
        for i in mesh.indices where Int(i) >= mesh.positions.count { return false }
        for c in part.colours {
            for v in [c.x, c.y, c.z, c.w] where !(v >= 0 && v <= 1) { return false }
        }
        return true
    }

    /// The indices of the vertices with material `material`.
    static func vertices(_ mesh: Mesh, _ material: Material) -> [Int] {
        var result: [Int] = []
        for (index, uv) in mesh.uvs.enumerated() where uv.x == Double(material.rawValue) { result.append(index) }
        return result
    }

    /// The fan centres (local 0) of `material`, as positions.
    static func fanCentres(_ mesh: Mesh, _ material: Material) -> [SIMD3<Double>] {
        var result: [SIMD3<Double>] = []
        for index in vertices(mesh, material) where mesh.uvs[index].y == 0 {
            let p: Vec3 = mesh.positions[index]
            result.append(SIMD3(p.x, p.y, p.z))
        }
        return result
    }

    /// Whether `a` and `b` are within 1e-9 on every axis.
    static func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ tolerance: Double = 1e-9) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
    }

    /// The positions (as triples) and uvs of the vertices whose material is not a gear outline (rim, body) or feather,
    /// in mesh order.
    static func tierInvariant(_ mesh: Mesh) -> [Double] {
        let skip: Set<Double> = [Double(Material.gearRim.rawValue), Double(Material.gearBody.rawValue),
                                 Double(Material.inkFeather.rawValue)]
        var result: [Double] = []
        for (index, uv) in mesh.uvs.enumerated() where !skip.contains(uv.x) {
            let p: Vec3 = mesh.positions[index]
            result.append(contentsOf: [p.x, p.y, p.z, uv.x, uv.y])
        }
        return result
    }

    /// The angle `a` reduced to −π … π.
    static func wrapped(_ a: Double) -> Double {
        var x: Double = a.truncatingRemainder(dividingBy: 2 * Double.pi)
        if x > Double.pi { x -= 2 * Double.pi }
        if x < -Double.pi { x += 2 * Double.pi }
        return x
    }

    // MARK: Tests

    @Test func extremesAreFiniteAndBounded() throws {
        var built: Int = 0
        for count in [2, 5] {
            for teeth in [6, 20] {
                for wall in [(8, 6), (24, 16)] {
                    for frames in [2, 6] {
                        for budget in [1, 40] {
                            for height in 0..<5 {
                                let level: MoonlitMechanismLevel = try Self.level(
                                    gears: count, teeth: teeth, width: wall.0, rows: wall.1, lampHeights: 5,
                                    startingHeight: height, frames: frames, budget: budget)
                                let snap: Snapshot = try Self.snapshot(level, frame: frames - 1)
                                for tier in MoonlitMechanismTier.all {
                                    let clockwork: MoonlitMechanismColouredMesh = try Geometry.clockworkPart(snap,
                                                                                                             tier: tier)
                                    let glow: MoonlitMechanismColouredMesh = try Geometry.glowPart(snap, tier: tier)
                                    #expect(Self.isSound(clockwork), "clockwork mesh finite, bounded, coloured")
                                    #expect(Self.isSound(glow), "glow mesh finite, bounded, coloured")
                                    #expect(!clockwork.mesh.indices.isEmpty, "clockwork mesh has triangles")
                                    built += 1
                                }
                                for index in 0..<count {
                                    let p: SIMD3<Double> = Geometry.gearRimCheckPoint(index, snap)
                                    #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite, "rim check point finite")
                                }
                            }
                        }
                    }
                }
            }
        }
        #expect(built == 480, "every extreme combination built at every tier")
    }

    @Test func catalogElementsInsideTheViewAtSevenAspects() throws {
        let levels: [MoonlitMechanismLevel] = try Self.catalog()
        #expect(levels.count == 100, "the catalog has 100 levels")
        var checked: Int = 0
        var outside: Int = 0
        for level in levels {
            for frame in [0, level.keyFrames.count - 1] {
                let snap: Snapshot = try Self.snapshot(level, frame: frame)
                var points: [SIMD3<Double>] = []
                for cell in snap.cast { points.append(Geometry.cellCentre(cell, snap)) }
                let reach: Double = Geometry.rimRadius(snap) + Geometry.toothHeight * Geometry.cellSize(snap)
                for index in snap.gears.indices {
                    let c: SIMD3<Double> = Geometry.gearCentre(index, snap)
                    points.append(c)
                    points.append(Geometry.gearRimCheckPoint(index, snap))
                    points.append(c + SIMD3(reach, 0, 0))
                    points.append(c - SIMD3(reach, 0, 0))
                    points.append(c + SIMD3(0, reach, 0))
                    points.append(c - SIMD3(0, reach, 0))
                }
                for index in snap.keyFrames.indices { points.append(Geometry.card(index, snap)) }
                for index in 0..<Geometry.pipCount(snap) { points.append(Geometry.alignmentPip(index, snap)) }
                for index in 0..<snap.budget { points.append(Geometry.movesBar(index, snap)) }
                points.append(Geometry.lampCentre(snap))
                for aspect in Self.aspects {
                    let camera: MoonlitMechanismCamera = Geometry.camera(snap, aspect: aspect)
                    for point in points {
                        checked += 1
                        guard let p = Geometry.project(point, camera: camera) else {
                            outside += 1
                            continue
                        }
                        if p.x < 0.05 || p.x > 0.95 || p.y < 0.05 || p.y > 0.95 { outside += 1 }
                    }
                }
            }
        }
        #expect(checked > 10_000, "many reference points checked")
        #expect(outside == 0, "every reference point inside the view with a 5 % margin")
    }

    @Test func cameraFitsTheAuthoredBoxTightly() throws {
        let snap: Snapshot = try Self.snapshot(try Self.small())
        for aspect in Self.aspects {
            let camera: MoonlitMechanismCamera = Geometry.camera(snap, aspect: aspect)
            #expect(camera.eye == SIMD3(0, 0.65, 2.4), "authored eye")
            #expect(camera.target == SIMD3(0, 0.55, -0.3), "authored target")
            var lowest: Double = 1
            for index in 0..<8 {
                guard let p = Geometry.project(Geometry.corner(index), camera: camera) else {
                    Issue.record("box corner behind the eye")
                    continue
                }
                lowest = min(lowest, p.x, p.y, 1 - p.x, 1 - p.y)
                #expect(p.x >= 0.05 && p.x <= 0.95 && p.y >= 0.05 && p.y <= 0.95, "box corner inside the margin")
            }
            #expect(abs(lowest - Geometry.fitMargin) < 1e-6, "the fit touches the margin")
        }
        let camera: MoonlitMechanismCamera = Geometry.camera(snap, aspect: 1)
        #expect(Geometry.project(SIMD3(0, 0.65, 3), camera: camera) == nil, "a point behind the eye has no projection")
        let nan: SIMD3<Double> = SIMD3(Double.nan, 0, 0)
        #expect(Geometry.project(nan, camera: camera) == nil, "a non-finite point has no projection")
        #expect(Geometry.camera(snap, aspect: .nan).aspect == 1, "a non-finite aspect becomes 1")
    }

    @Test func wallMappingFollowsClarificationOne() throws {
        let level: MoonlitMechanismLevel = try Self.level(gears: 2, teeth: 6, width: 24, rows: 16, lampHeights: 2,
                                                          startingHeight: 0, frames: 2, budget: 5)
        let snap: Snapshot = try Self.snapshot(level)
        let s: Double = Geometry.cellSize(snap)
        #expect(abs(s - 0.075) < 1e-12, "s is min(1.8 / 24, 1.2 / 16)")
        let first: SIMD3<Double> = Geometry.cellCentre(0, snap)
        #expect(Self.near(first, SIMD3(-11.5 * s, 0.65 + 7.5 * s, -0.6)), "cell 0 at the top left")
        let last: SIMD3<Double> = Geometry.cellCentre(24 * 16 - 1, snap)
        #expect(Self.near(last, SIMD3(11.5 * s, 0.65 - 7.5 * s, -0.6)), "the last cell at the bottom right")
        let gear: MoonlitMechanismGear = snap.gears[1]
        let centre: SIMD3<Double> = Geometry.gearCentre(1, snap)
        let cell: SIMD3<Double> = Geometry.cellCentre(gear.centre.row * 24 + gear.centre.column, snap)
        #expect(Self.near(centre, SIMD3(cell.x, cell.y, -0.6 + 0.12 * Double(gear.depth))), "gear on its centre cell")
        let raised: Snapshot = try Self.snapshot(level, [.lamp(1)])
        #expect(Geometry.gearCentre(1, raised) == centre, "the lamp never moves a gear")
        #expect(Geometry.lampCentre(raised).y > Geometry.lampCentre(snap).y, "the lamp rises with its height")
        #expect(abs(Geometry.lampCentre(raised).y - 1.33) < 1e-12, "lamp at 1.30 + 0.03 · height")
        let mesh: Mesh = try Geometry.clockworkMesh(snap, tier: .of(2), reduceMotion: false)
        let backdrop: [Int] = Self.vertices(mesh, .backdrop)
        #expect(backdrop.count == 4, "one backdrop quad")
        for index in backdrop {
            #expect(mesh.positions[index].z == -0.62, "backdrop at z −0.62")
            #expect(abs(mesh.positions[index].x) == 1.2, "backdrop spans x −1.2 … 1.2")
        }
        let paper: [Int] = Self.vertices(mesh, .paper)
        #expect(paper.count == 4, "one paper quad")
        for index in paper {
            #expect(abs(abs(mesh.positions[index].x) - 0.9) < 1e-12, "paper spans the wall width")
        }
    }

    @Test func positionsAreTheSameAtEveryTier() throws {
        var snaps: [Snapshot] = [try Self.snapshot(try Self.small()), try Self.snapshot(try Self.small(), [.turn(1)])]
        let levels: [MoonlitMechanismLevel] = try Self.catalog()
        for number in [0, 33, 66, 99] { snaps.append(try Self.snapshot(levels[number], frame: 1)) }
        for snap in snaps {
            let meshes: [Mesh] = try MoonlitMechanismTier.all.map { (tier: MoonlitMechanismTier) throws -> Mesh in
                try Geometry.clockworkMesh(snap, tier: tier, reduceMotion: false)
            }
            #expect(Self.tierInvariant(meshes[0]) == Self.tierInvariant(meshes[1]), "level-0 and level-1 agree")
            #expect(Self.tierInvariant(meshes[1]) == Self.tierInvariant(meshes[2]), "level-1 and level-2 agree")
            let rims: [Int] = meshes.map { (mesh: Mesh) -> Int in Self.vertices(mesh, .gearRim).count }
            #expect(rims[0] > rims[1] && rims[1] > rims[2], "rim segments fall with the tier")
            let feathers: [Int] = meshes.map { (mesh: Mesh) -> Int in Self.vertices(mesh, .inkFeather).count }
            #expect(feathers[2] == 0, "no feather at level-2")
            #expect(feathers[0] == feathers[1], "the same feathers at level-0 and level-1")
            #expect(snap.cast.isEmpty || feathers[0] > 0, "feathers at level-0 when shadows are cast")
            let reduced: Mesh = try Geometry.clockworkMesh(snap, tier: .of(0), reduceMotion: true)
            #expect(reduced == meshes[0], "Reduce Motion draws the same set-up phases")
            for index in snap.gears.indices {
                #expect(Geometry.gearRimCheckPoint(index, snap) == Geometry.gearRimCheckPoint(index, snap),
                        "rim check points are deterministic")
            }
        }
    }

    @Test func inkSquaresAreTheKernelsCastCells() throws {
        let levels: [MoonlitMechanismLevel] = try Self.catalog()
        var compared: Int = 0
        for number in stride(from: 0, to: 100, by: 9) {
            let level: MoonlitMechanismLevel = levels[number]
            for frame in level.keyFrames.indices {
                let play: MoonlitMechanismPlay = try Self.play(level, [])
                let snap: Snapshot = Snapshot(play: play, shownFrame: frame, levelNumber: number + 1, time: 0)
                let kernel: [Int] = MoonlitMechanismTrain.cast(level.gears, phases: snap.phases, height: snap.height,
                                                               width: level.width, rows: level.rows)
                #expect(snap.cast == kernel, "the snapshot's cast is the kernel's")
                #expect(snap.cast == play.report.frames[frame].cast, "the snapshot's cast is the report's")
                let mesh: Mesh = try Geometry.clockworkMesh(snap, tier: .of(1), reduceMotion: false)
                let centres: [SIMD3<Double>] = Self.fanCentres(mesh, .ink)
                #expect(centres.count == kernel.count, "one ink square per cast cell")
                for cell in kernel {
                    let c: SIMD3<Double> = Geometry.cellCentre(cell, snap)
                    #expect(centres.contains { (p: SIMD3<Double>) -> Bool in Self.near(p, c) }, "cast cell inked")
                }
                let half: Double = Geometry.inkSide * Geometry.cellSize(snap) / 2
                for index in Self.vertices(mesh, .ink) where mesh.uvs[index].y == 1 {
                    let p: Vec3 = mesh.positions[index]
                    var matched: Bool = false
                    for cell in kernel {
                        let c: SIMD3<Double> = Geometry.cellCentre(cell, snap)
                        if abs(abs(p.x - c.x) - half) < 1e-9 && abs(abs(p.y - c.y) - half) < 1e-9 { matched = true }
                    }
                    #expect(matched, "ink corners 0.46 s from a cast cell's centre")
                }
                let strays: [SIMD3<Double>] = Self.fanCentres(mesh, .strayHatch)
                #expect(strays.count == snap.strayCells.count, "one hatched square per stray cell")
                let missing: Int = Self.vertices(mesh, .missingDotted).count
                #expect(missing == 8 * snap.missingCells.count, "one dotted outline per missing cell")
                compared += 1
            }
        }
        #expect(compared > 20, "many key frames compared")
    }

    @Test func rotationFollowsPhaseAndDirection() throws {
        let level: MoonlitMechanismLevel = try Self.small()
        let before: Snapshot = try Self.snapshot(level)
        let turned: Snapshot = try Self.snapshot(level, [.turn(1)])
        let reseated: Snapshot = try Self.snapshot(level, [.reseat(1, 1)])
        for index in before.gears.indices {
            let step: Double = 2 * Double.pi / Double(before.gears[index].teeth)
            let sense: Int = Geometry.turnSense(index, before)
            #expect(sense == MoonlitMechanismTrain.direction(before.gears, index), "sense is the kernel's direction")
            #expect(sense == (index % 2 == 0 ? 1 : -1), "a chain alternates directions")
            let delta: Double = Self.wrapped(Geometry.toothAngle(index, tooth: 0, turned)
                                             - Geometry.toothAngle(index, tooth: 0, before))
            #expect(abs(delta + Double(sense) * step) < 1e-9, "a turn rotates clockwise for +1, anticlockwise for −1")
            let phaseAngle: Double = Double.pi / 2 - Double(before.phases[index]) * step
            #expect(abs(Self.wrapped(Geometry.toothAngle(index, tooth: 0, before) - phaseAngle)) < 1e-9,
                    "tooth zero at phase · 360° / T from the top")
            let r: Double = Geometry.rimRadius(before) - Geometry.checkInset * Geometry.cellSize(before)
            let check: SIMD3<Double> = Geometry.gearRimCheckPoint(index, before) - Geometry.gearCentre(index, before)
            #expect(abs((check.x * check.x + check.y * check.y).squareRoot() - r) < 1e-9, "check point 0.2 s inside R")
            let checkAngle: Double = atan2(check.y, check.x)
            let expected: Double = Geometry.toothAngle(index, tooth: 0, before) - step / 2
            #expect(abs(Self.wrapped(checkAngle - expected)) < 1e-9, "check point half a tooth past the notch")
            let reseatDelta: Double = Self.wrapped(Geometry.toothAngle(index, tooth: 0, reseated)
                                                   - Geometry.toothAngle(index, tooth: 0, before))
            #expect(abs(reseatDelta - (index == 1 ? -step : 0)) < 1e-9, "a re-seat turns only its gear, one tooth")
        }
        let mesh: Mesh = try Geometry.clockworkMesh(turned, tier: .of(2), reduceMotion: false)
        let notch: [Int] = Self.vertices(mesh, .gearNotch)
        #expect(notch.count == 4 * turned.gears.count, "one notch strip per gear")
        for index in turned.gears.indices {
            let c: SIMD3<Double> = Geometry.gearCentre(index, turned)
            let a: Double = Geometry.toothAngle(index, tooth: 0, turned)
            let tip: SIMD3<Double> = c + SIMD3(cos(a), sin(a), 0)
                * (Geometry.rimRadius(turned) + Geometry.notchReach * Geometry.toothHeight * Geometry.cellSize(turned))
            let half: Double = Geometry.notchWidth * Geometry.cellSize(turned) / 2
            var found: Int = 0
            for v in notch {
                let p: Vec3 = mesh.positions[v]
                let d: Double = ((p.x - tip.x) * (p.x - tip.x) + (p.y - tip.y) * (p.y - tip.y)).squareRoot()
                if abs(d - half) < 1e-9 && abs(p.z - c.z) < 1e-12 { found += 1 }
            }
            #expect(found == 2, "the notch reaches out at tooth zero's angle")
        }
        let spokes: Int = Self.vertices(mesh, .blade).count
        var solid: Int = 0
        for gear in turned.gears { solid += gear.blades.filter { (b: Bool) -> Bool in b }.count }
        #expect(spokes > 0 && spokes <= 4 * solid, "a spoke per solid blade (coinciding spokes weld)")
    }

    @Test func movesGaugeLightsAllHalfAndNone() throws {
        let level: MoonlitMechanismLevel = try Self.small(budget: 40)
        var actions: [MoonlitMechanismAction] = []
        for k in 0..<40 { actions.append(.turn(k % 2 == 0 ? 1 : -1)) }
        for (spent, lit) in [(0, 40), (20, 20), (40, 0)] {
            let snap: Snapshot = try Self.snapshot(level, Array(actions.prefix(spent)))
            #expect(snap.actionsLeft == lit, "actions left as spent")
            #expect(Geometry.litMoves(snap) == lit, "lit moves are the actions left")
            let mesh: Mesh = try Geometry.clockworkMesh(snap, tier: .of(0), reduceMotion: false)
            let on: [SIMD3<Double>] = Self.fanCentres(mesh, .movesLit)
            let off: [SIMD3<Double>] = Self.fanCentres(mesh, .movesUnlit)
            #expect(on.count == lit, "lit bars drawn")
            #expect(off.count == 40 - lit, "unlit bars drawn")
            for index in 0..<40 {
                let c: SIMD3<Double> = Geometry.movesBar(index, snap)
                let pool: [SIMD3<Double>] = index < lit ? on : off
                #expect(pool.contains { (p: SIMD3<Double>) -> Bool in Self.near(p, c) }, "bar in its slot")
            }
        }
        let snap: Snapshot = try Self.snapshot(level)
        #expect(abs(Geometry.movesBar(0, snap).x - (-0.9 + 0.0225)) < 1e-12, "first bar centred in its slot")
        #expect(Geometry.movesBar(0, snap).y == -0.40, "bars at y −0.40")
        let one: Snapshot = try Self.snapshot(try Self.small(budget: 1))
        #expect(abs(Geometry.movesBar(0, one).x) < 1e-12, "a single bar is centred")
        #expect(abs(Geometry.movesSlot(one) - 1.8) < 1e-12, "a single slot spans 1.8")
        let pip: Double = Geometry.pipSide(snap)
        #expect(abs(Geometry.alignmentPip(0, snap).x - (-0.15)) < 1e-12, "first of two pips at −0.15")
        #expect(pip == 0.04, "pip side min(0.04, 0.6 · slot)")
        #expect(abs(Geometry.card(0, snap).y - (-0.16)) < 1e-12, "the shown card is raised")
        #expect(abs(Geometry.card(1, snap).y - (-0.18)) < 1e-12, "other cards at y −0.18")
    }

    @Test func wonLevelIsBrighterAndInPlace() throws {
        let level: MoonlitMechanismLevel = try Self.small()
        let before: Snapshot = try Self.snapshot(level)
        let won: Snapshot = try Self.snapshot(level, [.run])
        #expect(won.isWon, "the level wins at its start")
        #expect(Geometry.wonFlag(won) == 1 && Geometry.wonFlag(before) == 0, "won flag")
        for tier in MoonlitMechanismTier.all {
            let a: MoonlitMechanismColouredMesh = try Geometry.clockworkPart(before, tier: tier)
            let b: MoonlitMechanismColouredMesh = try Geometry.clockworkPart(won, tier: tier)
            #expect(a.mesh.positions == b.mesh.positions, "nothing moves on a win")
            #expect(a.mesh.indices == b.mesh.indices, "the same triangles on a win")
            let paper: [Int] = Self.vertices(b.mesh, .paper)
            for index in paper {
                let x: Vec4 = a.colours[index]
                let y: Vec4 = b.colours[index]
                #expect(y.x + y.y + y.z > x.x + x.y + x.z + 0.1, "the won paper is brighter")
                #expect(b.mesh.uvs[index].y == 0, "paper local coordinate stays 0")
            }
            let glowBefore: Mesh = try Geometry.glowMesh(before, tier: tier)
            let glowWon: Mesh = try Geometry.glowMesh(won, tier: tier)
            var wall: Int = 0
            for uv in glowWon.uvs where uv.x >= 4 { wall += 1 }
            var wallBefore: Int = 0
            for uv in glowBefore.uvs where uv.x >= 4 { wallBefore += 1 }
            #expect(wall == 8 * tier.glowShells, "a wall shell per glow shell when won")
            #expect(wallBefore == 0, "no wall shell before the win")
        }
    }

    @Test func glowShellsFollowTheTier() throws {
        let level: MoonlitMechanismLevel = try Self.small()
        let snap: Snapshot = try Self.snapshot(level)
        var litCards: Int = 0
        for index in snap.keyFrames.indices where Geometry.cardFraction(index, snap) > 0 { litCards += 1 }
        #expect(litCards == 3, "every card of the winning start is lit")
        for tier in MoonlitMechanismTier.all {
            let glow: MoonlitMechanismColouredMesh = try Geometry.glowPart(snap, tier: tier)
            var lamp: Int = 0
            var card: Int = 0
            for (index, uv) in glow.mesh.uvs.enumerated() {
                let n: Vec3 = glow.mesh.normals[index]
                if uv.x < 2 {
                    lamp += 1
                    #expect(abs(n.x - MoonlitMechanismPalette.lampGlow.x) < 1e-12, "lamp shells carry lamp glow")
                } else if uv.x < 4 {
                    card += 1
                    #expect(abs(n.x - MoonlitMechanismPalette.glow.x) < 1e-12, "card shells carry the glow colour")
                }
                #expect(uv.y == 0 || uv.y == 1, "shell radial coordinate 0 inside, 1 outside")
            }
            #expect(lamp == 48 * tier.glowShells, "one lamp ring per shell")
            #expect(card == 8 * tier.glowShells * litCards, "one frame per shell per lit card")
            if tier.glowShells == 0 {
                #expect(glow.mesh.positions.isEmpty && glow.mesh.indices.isEmpty, "level-2 has no glow")
            }
        }
        #expect(MoonlitMechanismTier.of(0).glowShells == 2 && MoonlitMechanismTier.of(1).glowShells == 1,
                "two shells at level-0, one at level-1")
        #expect(Geometry.GlowKind.card.code(factor: 0.5) == 2.5, "glow code is 2 · kind + factor")
    }

    @Test func failuresAreOutlined() throws {
        let level: MoonlitMechanismLevel = try Self.small()
        let jammed: Snapshot = try Self.snapshot(level, [.reseat(1, 1), .run])
        #expect(jammed.failure == .jammed(1), "a re-seat jams the pair")
        let jamMesh: Mesh = try Geometry.clockworkMesh(jammed, tier: .of(0), reduceMotion: false)
        let broken: [Int] = Self.vertices(jamMesh, .broken)
        #expect(broken.count == 2 * 2 * (Geometry.jamSegments + 1), "an arc on each gear of the pair")
        let reach: Double = Geometry.rimRadius(jammed) + Geometry.toothHeight * Geometry.cellSize(jammed)
        for index in broken {
            let p: Vec3 = jamMesh.positions[index]
            var onPair: Bool = false
            for gear in [0, 1] {
                let c: SIMD3<Double> = Geometry.gearCentre(gear, jammed)
                let d: Double = ((p.x - c.x) * (p.x - c.x) + (p.y - c.y) * (p.y - c.y)).squareRoot()
                if d > reach && d < reach + 0.11 * Geometry.cellSize(jammed) + 1e-9 && p.z == c.z { onPair = true }
            }
            #expect(onPair, "the outline hugs the jammed pair's teeth")
        }
        let missed: Snapshot = try Self.snapshot(level, [.turn(1), .run])
        let card: Int? = Geometry.failingCard(missed)
        if case .forbidden(_, let cell)? = missed.failure {
            #expect(Geometry.brokenCell(missed) == cell, "the forbidden cell is outlined")
        } else {
            #expect(card != nil, "a missing or stray failure names a card")
        }
        let missMesh: Mesh = try Geometry.clockworkMesh(missed, tier: .of(0), reduceMotion: false)
        #expect(Self.vertices(missMesh, .broken).count == 8, "one outline frame")
        if let card {
            let c: SIMD3<Double> = Geometry.card(card, missed)
            for index in Self.vertices(missMesh, .broken) {
                let p: Vec3 = missMesh.positions[index]
                #expect(abs(p.y - c.y) < 0.06 && abs(p.x - c.x) < 0.1, "the outline frames the failing card")
            }
        }
        let calm: Snapshot = try Self.snapshot(level)
        let calmMesh: Mesh = try Geometry.clockworkMesh(calm, tier: .of(0), reduceMotion: false)
        #expect(Self.vertices(calmMesh, .broken).isEmpty, "nothing broken without a failure")
    }

    @Test func streamsFollowTheShaderConventions() throws {
        let level: MoonlitMechanismLevel = try Self.small()
        let snap: Snapshot = try Self.snapshot(level, [.turn(1), .reseat(2, 1)])
        let mesh: Mesh = try Geometry.clockworkMesh(snap, tier: .of(0), reduceMotion: false)
        let fans: Set<Material> = [.ink, .strayHatch, .gearBody, .lamp, .cardLit, .cardUnlit, .alignLit, .movesLit,
                                   .movesUnlit]
        let strips: Set<Material> = [.targetOutline, .missingDotted, .forbiddenMark, .gearRim, .gearNotch, .blade,
                                     .ladder, .cardBorder, .alignUnlit, .broken]
        var codes: Set<Double> = []
        for (index, uv) in mesh.uvs.enumerated() {
            #expect(mesh.normals[index] == Vec3(0, 0, 1), "clockwork normal is +z")
            guard let material = Material(rawValue: Float(uv.x)) else {
                Issue.record("unknown material code")
                continue
            }
            codes.insert(uv.x)
            if fans.contains(material) {
                #expect(uv.y == 0 || uv.y == 1, "fan local 0 at the centre, 1 on the outline")
            } else if strips.contains(material) {
                #expect(uv.y == -1 || uv.y == 1, "strip local −1 and +1 on its sides")
            } else if material == .inkFeather {
                #expect(uv.y == 0 || uv.y == 1, "feather local 0 inside, 1 outside")
            } else {
                #expect(uv.y == 0, "backdrop and paper local 0")
            }
        }
        #expect(codes.count >= 15, "most materials appear")
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a: Vec3 = mesh.positions[Int(mesh.indices[i])]
            let b: Vec3 = mesh.positions[Int(mesh.indices[i + 1])]
            let c: Vec3 = mesh.positions[Int(mesh.indices[i + 2])]
            let side: Double = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
            #expect(side > 0, "every triangle winds counter-clockwise from +z")
        }
    }

    // MARK: Orbit (feature 434, R02-G14-04, T-R02G1404-002)

    /// Six orbits: the authored one, the four clamp corners and the centre of the allowed range.
    static func orbits() -> [MoonlitMechanismOrbit] {
        let y: Double = MoonlitMechanismOrbit.yawLimit
        let lo: Double = MoonlitMechanismOrbit.pitchRange.lowerBound
        let hi: Double = MoonlitMechanismOrbit.pitchRange.upperBound
        return [MoonlitMechanismOrbit.authored, MoonlitMechanismOrbit(yaw: y, pitch: hi),
                MoonlitMechanismOrbit(yaw: -y, pitch: hi), MoonlitMechanismOrbit(yaw: y, pitch: lo),
                MoonlitMechanismOrbit(yaw: -y, pitch: lo), MoonlitMechanismOrbit(yaw: 0, pitch: (lo + hi) / 2)]
    }

    @Test func everyOrbitKeepsTheBoxInsideTheMargin() throws {
        let snap: Snapshot = try Self.snapshot(try Self.small())
        for orbit in Self.orbits() {
            for aspect in [0.4, 1, 2.5] {
                let camera: MoonlitMechanismCamera = Geometry.camera(snap, aspect: aspect, orbit: orbit)
                var lowest: Double = 1
                for index in 0..<8 {
                    guard let p = Geometry.project(Geometry.corner(index), camera: camera) else {
                        Issue.record("box corner \(index) behind the eye at \(orbit), aspect \(aspect)")
                        continue
                    }
                    lowest = min(lowest, p.x, p.y, 1 - p.x, 1 - p.y)
                }
                #expect(lowest >= 0.05, "every corner keeps 5 % at \(orbit), aspect \(aspect)")
                #expect(abs(lowest - Geometry.fitMargin) < 1e-6, "the fit is tight at \(orbit), aspect \(aspect)")
                #expect(camera.eye.z > Geometry.boxHigh.z, "the eye stays in front of every plane")
            }
        }
    }

    @Test func catalogElementsInsideTheViewAtEveryOrbitBound() throws {
        // The lamp, the ladder's ends, cards, pips, bars and gear extremes of three catalog levels.
        let levels: [MoonlitMechanismLevel] = try Self.catalog()
        var outside: Int = 0
        for level in [levels[0], levels[49], levels[99]] {
            let snap: Snapshot = try Self.snapshot(level)
            var points: [SIMD3<Double>] = [Geometry.lampCentre(snap)]
            let top: Double = Geometry.lampBaseY + Geometry.lampStep * Double(snap.lampHeights - 1)
            points.append(SIMD3(Geometry.ladderX, Geometry.lampBaseY, Geometry.lampZ))
            points.append(SIMD3(Geometry.ladderX, top, Geometry.lampZ))
            let reach: Double = Geometry.rimRadius(snap) + Geometry.toothHeight * Geometry.cellSize(snap)
            for index in snap.gears.indices {
                let c: SIMD3<Double> = Geometry.gearCentre(index, snap)
                points.append(c + SIMD3(reach, 0, 0))
                points.append(c - SIMD3(reach, 0, 0))
                points.append(c + SIMD3(0, reach, 0))
                points.append(c - SIMD3(0, reach, 0))
            }
            for index in snap.keyFrames.indices { points.append(Geometry.card(index, snap)) }
            for index in 0..<Geometry.pipCount(snap) { points.append(Geometry.alignmentPip(index, snap)) }
            for index in 0..<snap.budget { points.append(Geometry.movesBar(index, snap)) }
            for orbit in Self.orbits() {
                for aspect in [0.4, 1, 2.5] {
                    let camera: MoonlitMechanismCamera = Geometry.camera(snap, aspect: aspect, orbit: orbit)
                    for point in points {
                        guard let p = Geometry.project(point, camera: camera) else {
                            outside += 1
                            continue
                        }
                        if p.x < 0.05 || p.x > 0.95 || p.y < 0.05 || p.y > 0.95 { outside += 1 }
                    }
                }
            }
        }
        #expect(outside == 0, "every reference point inside the view with a 5 % margin at every orbit")
    }

    @Test func orbitIsClampedAndAuthoredIsBitIdentical() throws {
        let y: Double = MoonlitMechanismOrbit.yawLimit
        let range: ClosedRange<Double> = MoonlitMechanismOrbit.pitchRange
        #expect(abs(y - 25 * Double.pi / 180) < 1e-15)
        #expect(abs(range.lowerBound + 10 * Double.pi / 180) < 1e-15)
        #expect(abs(range.upperBound - 15 * Double.pi / 180) < 1e-15)
        #expect(MoonlitMechanismOrbit(yaw: 2, pitch: 2).clamped()
                == MoonlitMechanismOrbit(yaw: y, pitch: range.upperBound))
        #expect(MoonlitMechanismOrbit(yaw: -2, pitch: -2).clamped()
                == MoonlitMechanismOrbit(yaw: -y, pitch: range.lowerBound))
        #expect(MoonlitMechanismOrbit(yaw: .nan, pitch: .infinity).clamped() == MoonlitMechanismOrbit.authored)
        #expect(MoonlitMechanismOrbit(yaw: 0.1, pitch: -0.1).clamped() == MoonlitMechanismOrbit(yaw: 0.1, pitch: -0.1))
        let snap: Snapshot = try Self.snapshot(try Self.small())
        for aspect in Self.aspects {
            let fixed: MoonlitMechanismCamera = Geometry.camera(snap, aspect: aspect)
            let authored: MoonlitMechanismCamera = Geometry.camera(snap, aspect: aspect, orbit: .authored)
            #expect(fixed == authored, "the fixed camera is the authored orbit bit for bit")
            #expect(fixed.eye == Geometry.eye && fixed.target == Geometry.lookAt)
            // Beyond the bounds the camera is the clamped orbit's.
            let wild: MoonlitMechanismCamera = Geometry.camera(snap, aspect: aspect,
                                                               orbit: MoonlitMechanismOrbit(yaw: 9, pitch: -9))
            let edge: MoonlitMechanismCamera = Geometry.camera(snap, aspect: aspect,
                                                               orbit: MoonlitMechanismOrbit(yaw: y,
                                                                                            pitch: range.lowerBound))
            #expect(wild == edge)
        }
    }

    @Test func positivePitchRaisesTheEyeAndPositiveYawMovesItTowardsPlusX() throws {
        let snap: Snapshot = try Self.snapshot(try Self.small())
        let base: MoonlitMechanismCamera = Geometry.camera(snap, aspect: 1)
        let up: MoonlitMechanismCamera = Geometry.camera(snap, aspect: 1,
                                                         orbit: MoonlitMechanismOrbit(yaw: 0, pitch: 0.2))
        let down: MoonlitMechanismCamera = Geometry.camera(snap, aspect: 1,
                                                           orbit: MoonlitMechanismOrbit(yaw: 0, pitch: -0.15))
        let side: MoonlitMechanismCamera = Geometry.camera(snap, aspect: 1,
                                                           orbit: MoonlitMechanismOrbit(yaw: 0.3, pitch: 0))
        #expect(up.eye.y > base.eye.y && up.eye.z < base.eye.z && up.eye.x == 0 && up.target == Geometry.lookAt)
        // The authored offset (0, 0.1, 2.7) already points slightly up, so lowering it also shortens its z a little.
        #expect(down.eye.y < base.eye.y && down.eye.x == 0 && down.target == Geometry.lookAt)
        #expect(side.eye.x > 0 && side.eye.y == base.eye.y && side.target.y == base.target.y)
        // Yaw turns the eye and the look-at point about the vertical axis through the box centre (0, ·, −0.1).
        let centre: SIMD3<Double> = (Geometry.boxLow + Geometry.boxHigh) / 2
        #expect(abs(centre.x) < 1e-15 && abs(centre.z + 0.1) < 1e-12)
        let pairs: [(SIMD3<Double>, SIMD3<Double>)] = [(base.eye, side.eye), (base.target, side.target)]
        for p in pairs {
            let a: SIMD2<Double> = SIMD2(p.0.x - centre.x, p.0.z - centre.z)
            let b: SIMD2<Double> = SIMD2(p.1.x - centre.x, p.1.z - centre.z)
            #expect(abs((a * a).sum() - (b * b).sum()) < 1e-12)
        }
        let offset: SIMD3<Double> = up.eye - up.target
        let authored: SIMD3<Double> = Geometry.eye - Geometry.lookAt
        #expect(abs((offset * offset).sum() - (authored * authored).sum()) < 1e-12)
    }

    // MARK: Fallback won level (feature 436, R02-G14-06)

    /// The fallback paper's lift scales monotonically with the won level, never moves a vertex, and defaults to the
    /// snapshot's won state.
    @Test func theFallbackWonLevelScalesTheLiftOnly() throws {
        let core: MoonlitMechanismExperienceCore = try MoonlitMechanismExperienceCore.opening(number: 1)
        let snapshot: MoonlitMechanismSceneSnapshot = core.snapshot(time: 0)
        let tier: MoonlitMechanismTier = MoonlitMechanismTier.of(2)
        let plain: MoonlitMechanismColouredMesh = try MoonlitMechanismSceneGeometry.clockworkPart(snapshot, tier: tier)
        let zero: MoonlitMechanismColouredMesh = try MoonlitMechanismSceneGeometry.clockworkPart(snapshot, tier: tier,
                                                                                                wonLevel: 0)
        #expect(plain.mesh.positions == zero.mesh.positions && plain.colours == zero.colours)
        var previous: Double = -1
        let levels: [Double] = [0, 0.25, 0.5, 0.75, 1]
        for level in levels {
            let part: MoonlitMechanismColouredMesh = try MoonlitMechanismSceneGeometry.clockworkPart(
                snapshot, tier: tier, wonLevel: level)
            #expect(part.mesh.positions == plain.mesh.positions, "positions never change")
            let paper: SIMD3<Double> = MoonlitMechanismSceneGeometry.paperColour(won: level)
            let brightness: Double = paper.x + paper.y + paper.z
            #expect(brightness > previous)
            previous = brightness
        }
        let nan: MoonlitMechanismColouredMesh = try MoonlitMechanismSceneGeometry.clockworkPart(snapshot, tier: tier,
                                                                                               wonLevel: .nan)
        #expect(nan.colours == zero.colours)
    }
}
