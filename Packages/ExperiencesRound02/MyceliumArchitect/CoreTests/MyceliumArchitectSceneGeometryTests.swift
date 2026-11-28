// MyceliumArchitectSceneGeometryTests — feature 513 (R02-G22-03) T-R02G2203-003 (FR-R02G2203-001, 003, 006;
// SC-R02G2203-003; clarifications Q1–Q5; research R1, R3–R6, R9). The cave floor geometry: the fit rule and the CPU
// reference points; every vertex, normal and uv finite and every board vertex but the backdrop's inside the fitted box
// for the extreme snapshots (4 × 4 and 32 × 32 boards, a network of 2 048 nodes and of the root alone, 1 and 6
// terminals, 0 and 12 sites, budgets 1 and 24, seeds pointing off the board, weight 4 094) at every tier, with the
// streams the shaders decode (material codes, quad-local flats, unit solid normals, the backdrop's height, the glow's
// factor and radial share); the painter's order of the elements and of the emitted triangles; the reference points
// equal to the cell centres and inside the view; the camera holding the box with a margin of at least 5 % for aspects
// 0.4 … 2.5 and a zero-size view handled; tiers differing only in tessellation, fuzz, spores and glow; the shown pulse
// changing only the pulse-dependent parts; each failure kind marked on a failed play only. Explicit types, plain loops.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import MyceliumArchitectCore

@Suite struct MyceliumArchitectSceneGeometryTests {
    typealias G = MyceliumArchitectSceneGeometry
    typealias Snapshot = MyceliumArchitectSceneSnapshot
    typealias Material = MyceliumArchitectMaterial
    typealias Cell = MyceliumArchitectCell

    /// The seven aspects checked.
    static let aspects: [Double] = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]

    /// The materials drawn as solids (a unit normal in a_normal).
    static let solids: Set<Material> = [.rock, .vein, .sprout, .root, .terminalClosed, .terminalOpen]

    /// The materials whose geometry or presence depends on the tier.
    static let tiered: Set<Material> = [.vein, .sprout, .root, .terminalClosed, .terminalOpen, .fuzz, .spore]

    /// The materials whose geometry or presence depends on the shown pulse.
    static let pulsed: Set<Material> = [.vein, .bloom, .fuzz, .nutrient, .nutrientConsumed, .terminalClosed,
                                        .terminalOpen, .pipFilled, .pipHollow]

    /// A checked level of the given shape (the "already won" rule off: a test level).
    static func level(width: Int, height: Int, root: Cell, terminals: [Cell], rocks: [Cell] = [], toxins: [Cell] = [],
                      fixed: [Cell] = [], sites: [Cell]? = nil, budget: Int, nutrientBudget: Int = 4094,
                      weightLimit: Int = 2000) throws -> MyceliumArchitectLevel {
        try MyceliumArchitectLevel(id: "geometry-test", seed: 1, difficulty: 1, width: width, height: height,
                                   root: root, terminals: terminals, rocks: rocks, toxins: toxins,
                                   fixedNutrients: fixed, strength: 4, reach: 4, curvature: 1, obstacle: 1,
                                   maxNutrients: 6, maxBlockers: 6, maxSeeds: 4, startSeeds: [], pulses: 128,
                                   nutrientBudget: nutrientBudget, weightLimit: weightLimit, budget: budget,
                                   tutorial: false, refusingAWin: false, sites: sites)
    }

    /// The direction from `a` to the neighbouring `b` (east when they are not neighbours).
    static func direction(_ a: Cell, _ b: Cell) -> MyceliumArchitectDirection {
        for d in MyceliumArchitectDirection.allCases where a.moved(d) == b { return d }
        return .east
    }

    /// The boustrophedon path over a W × H board from (0, 0), row by row, `count` cells long (walking back along it
    /// once the board is covered, so a path may revisit cells up to 2 · W · H nodes).
    static func path(width: Int, height: Int, count: Int) -> [Cell] {
        var forward: [Cell] = []
        for row in 0..<height {
            for k in 0..<width { forward.append(Cell(column: row % 2 == 0 ? k : width - 1 - k, row: row)) }
        }
        var cells: [Cell] = []
        var index: Int = 0
        var step: Int = 1
        while cells.count < count {
            cells.append(forward[index])
            if index + step >= forward.count || index + step < 0 { step = -step }
            index += step
        }
        return cells
    }

    /// A report growing `cells` as one chain (cell i at pulse i, its parent i − 1, step weights 2 and 3 alternating,
    /// every fifth step consuming), with the given terminal pulses and total weight.
    static func report(_ cells: [Cell], terminalPulses: [Int?], totalWeight: Int,
                       failure: MyceliumArchitectFailure? = nil) -> MyceliumArchitectReport {
        var steps: [MyceliumArchitectStep] = []
        var pulses: [Int] = []
        var parents: [Int?] = []
        for index in cells.indices {
            pulses.append(index)
            parents.append(index == 0 ? nil : index - 1)
            if index > 0 {
                let from: Cell = cells[index - 1]
                steps.append(MyceliumArchitectStep(pulse: index, tip: 0, from: from,
                                                   direction: direction(from, cells[index]), to: cells[index],
                                                   score: 1, weight: index % 2 == 0 ? 2 : 3,
                                                   consumed: index % 5 == 0, newTip: nil))
            }
        }
        var paths: [Int?] = []
        for _ in terminalPulses { paths.append(nil) }
        return MyceliumArchitectReport(field: [], steps: steps, grown: cells, grownPulses: pulses, parents: parents,
                                       totalWeight: totalWeight, pulsesRun: max(cells.count - 1, 0),
                                       terminalPulses: terminalPulses, terminalPathWeights: paths, failure: failure)
    }

    /// A snapshot of the given parts (the unchecked initialiser).
    static func snapshot(_ level: MyceliumArchitectLevel, _ arrangement: MyceliumArchitectArrangement,
                         _ report: MyceliumArchitectReport, failure: MyceliumArchitectFailure? = nil,
                         stage: MyceliumArchitectStage = .playing, actionsLeft: Int = 0,
                         shownPulse: Int = 4_096) -> Snapshot {
        Snapshot(level: level, arrangement: arrangement, report: report, failure: failure, stage: stage,
                 actionsLeft: actionsLeft, shownPulse: shownPulse, levelNumber: 1, time: 0)
    }

    /// The 4 × 4 extreme: one terminal, no sites, budget 1, every cell grown, seeds pointing off the board.
    static func small(failure: MyceliumArchitectFailure? = nil, stage: MyceliumArchitectStage = .playing,
                      shownPulse: Int = 4_096) throws -> Snapshot {
        let terminal: Cell = Cell(column: 0, row: 3)
        let level: MyceliumArchitectLevel = try level(width: 4, height: 4, root: Cell(column: 0, row: 0),
                                                      terminals: [terminal], toxins: [Cell(column: 3, row: 3)],
                                                      budget: 1, nutrientBudget: 4, weightLimit: 2)
        let cells: [Cell] = path(width: 4, height: 4, count: 16)
        let arrangement = MyceliumArchitectArrangement(nutrients: [Cell(column: 2, row: 0)], blockers: [],
                                                       seeds: [.north, .west, .northWest, .east])
        let reached: Int = cells.firstIndex(of: terminal) ?? 0
        return snapshot(level, arrangement, report(cells, terminalPulses: [reached], totalWeight: 4094),
                        failure: failure, stage: stage, actionsLeft: 1, shownPulse: shownPulse)
    }

    /// The 32 × 32 extreme: six terminals (four reached), twelve sites, budget 24, a network of 2 048 nodes.
    static func large(failure: MyceliumArchitectFailure? = nil, stage: MyceliumArchitectStage = .playing,
                      shownPulse: Int = 4_096) throws -> Snapshot {
        let terminals: [Cell] = [Cell(column: 31, row: 0), Cell(column: 0, row: 31), Cell(column: 31, row: 31),
                                 Cell(column: 16, row: 16), Cell(column: 5, row: 9), Cell(column: 30, row: 2)]
        var sites: [Cell] = []
        for k in 0..<12 { sites.append(Cell(column: 2 + 2 * k, row: 20)) }
        let toxins: [Cell] = [Cell(column: 10, row: 10), Cell(column: 0, row: 30)]
        let rocks: [Cell] = [Cell(column: 31, row: 15), Cell(column: 0, row: 15), Cell(column: 12, row: 0)]
        let level: MyceliumArchitectLevel = try level(width: 32, height: 32, root: Cell(column: 0, row: 0),
                                                      terminals: terminals, rocks: rocks, toxins: toxins,
                                                      fixed: [Cell(column: 3, row: 3), Cell(column: 31, row: 30)],
                                                      sites: sites, budget: 24, nutrientBudget: 4094,
                                                      weightLimit: 3000)
        let cells: [Cell] = path(width: 32, height: 32, count: 2_048)
        var pulses: [Int?] = []
        for (index, terminal) in terminals.enumerated() { pulses.append(index < 4 ? cells.firstIndex(of: terminal) : nil) }
        let arrangement = MyceliumArchitectArrangement(nutrients: [Cell(column: 4, row: 4), Cell(column: 20, row: 25)],
                                                       blockers: [Cell(column: 7, row: 7), Cell(column: 31, row: 29)],
                                                       seeds: [.east, .south, .southEast, .north])
        return snapshot(level, arrangement, report(cells, terminalPulses: pulses, totalWeight: 4094),
                        failure: failure, stage: stage, actionsLeft: 7, shownPulse: shownPulse)
    }

    /// The 32 × 32 board with the root alone (one terminal, never reached), budget 1, no sites.
    static func lonely() throws -> Snapshot {
        let level: MyceliumArchitectLevel = try level(width: 32, height: 32, root: Cell(column: 31, row: 31),
                                                      terminals: [Cell(column: 0, row: 0)], budget: 1)
        let arrangement = MyceliumArchitectArrangement(nutrients: [], blockers: [], seeds: [.southEast])
        return snapshot(level, arrangement, report([Cell(column: 31, row: 31)], terminalPulses: [nil], totalWeight: 0))
    }

    /// A 4 × 8 board with six terminals and two sites, budget 24, a short branching network with a bloom.
    static func branching() throws -> Snapshot {
        let terminals: [Cell] = [Cell(column: 1, row: 2), Cell(column: 3, row: 7), Cell(column: 0, row: 7),
                                 Cell(column: 3, row: 0), Cell(column: 2, row: 5), Cell(column: 0, row: 4)]
        let level: MyceliumArchitectLevel = try level(width: 4, height: 8, root: Cell(column: 1, row: 1),
                                                      terminals: terminals,
                                                      sites: [Cell(column: 3, row: 3), Cell(column: 2, row: 7)],
                                                      budget: 24)
        let cells: [Cell] = [Cell(column: 1, row: 1), Cell(column: 1, row: 2), Cell(column: 0, row: 2),
                             Cell(column: 2, row: 2), Cell(column: 2, row: 3), Cell(column: 2, row: 4)]
        let parents: [Int?] = [nil, 0, 1, 1, 3, 4]
        var steps: [MyceliumArchitectStep] = []
        for index in 1..<cells.count {
            let from: Cell = cells[parents[index] ?? 0]
            steps.append(MyceliumArchitectStep(pulse: index, tip: 0, from: from, direction: direction(from, cells[index]),
                                               to: cells[index], score: 1, weight: 2, consumed: index == 1,
                                               newTip: nil))
        }
        let report = MyceliumArchitectReport(field: [], steps: steps, grown: cells, grownPulses: [0, 1, 2, 2, 3, 4],
                                             parents: parents, totalWeight: 10, pulsesRun: 4,
                                             terminalPulses: [1, nil, nil, nil, nil, nil],
                                             terminalPathWeights: [2, nil, nil, nil, nil, nil], failure: nil)
        let arrangement = MyceliumArchitectArrangement(nutrients: [Cell(column: 1, row: 2)], blockers: [],
                                                       seeds: [.south])
        return snapshot(level, arrangement, report, actionsLeft: 24)
    }

    /// The extreme snapshots of the task.
    static func extremes() throws -> [Snapshot] {
        [try small(), try large(), try lonely(), try branching(),
         try large(failure: .overweight(weight: 4094, limit: 3000), stage: .failed),
         try small(failure: .starved(pulse: 3, tip: 0, cell: Cell(column: 3, row: 0), weight: 4, budget: 2),
                   stage: .result)]
    }

    /// The decoded a_uv.x of vertex `k` of a board mesh.
    static func decoded(_ mesh: Mesh, _ k: Int) -> (material: Material, value: Double, broken: Bool) {
        Material.decode(mesh.uvs[k].x)
    }

    /// The vertex positions of `mesh` whose material is in `materials` (and whose broken mark is `broken`, when given).
    static func positions(_ mesh: Mesh, _ materials: Set<Material>, broken: Bool? = nil) -> [SIMD3<Double>] {
        var result: [SIMD3<Double>] = []
        for k in mesh.positions.indices {
            let d = decoded(mesh, k)
            guard materials.contains(d.material) else { continue }
            if let broken, d.broken != broken { continue }
            let p: Vec3 = mesh.positions[k]
            result.append(SIMD3(p.x, p.y, p.z))
        }
        return result
    }

    /// The vertices of `mesh` whose material is not in `excluded`, as a sorted list of rounded strings (position, normal
    /// and uv; order-free comparison).
    static func key(_ mesh: Mesh, excluding excluded: Set<Material>) -> [String] {
        var keys: [String] = []
        for k in mesh.positions.indices where !excluded.contains(decoded(mesh, k).material) {
            let p: Vec3 = mesh.positions[k]
            let n: Vec3 = mesh.normals[k]
            let uv: Vec2 = mesh.uvs[k]
            keys.append(String(format: "%.9f %.9f %.9f %.6f %.6f %.6f %.9f %.9f", p.x, p.y, p.z, n.x, n.y, n.z,
                               uv.x, uv.y))
        }
        return Set(keys).sorted()
    }

    /// Whether `point` lies in the fitted box.
    static func inBox(_ point: SIMD3<Double>) -> Bool {
        let tolerance: Double = 1e-9
        return point.x >= G.boxLow.x - tolerance && point.x <= G.boxHigh.x + tolerance
            && point.y >= G.boxLow.y - tolerance && point.y <= G.boxHigh.y + tolerance
            && point.z >= G.boxLow.z - tolerance && point.z <= G.boxHigh.z + tolerance
    }

    /// Whether `point` projects inside the view with a margin of at least 5 % on each side.
    static func inView(_ point: SIMD3<Double>, _ camera: MyceliumArchitectCamera) -> Bool {
        guard let p = G.project(point, camera: camera) else { return false }
        return p.x >= 0.05 && p.x <= 0.95 && p.y >= 0.05 && p.y <= 0.95
    }

    /// Whether `a` and `b` are within 1e-12 of each other.
    static func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Bool {
        let d: SIMD3<Double> = a - b
        return (d * d).sum().squareRoot() < 1e-12
    }

    /// Checks that a board mesh is finite, well indexed, bounded (every vertex but the backdrop's in the box) and follows
    /// the streams the shaders decode.
    static func checkBoard(_ mesh: Mesh) {
        checkIndices(mesh)
        var bad: Int = 0
        for k in mesh.positions.indices {
            let p: Vec3 = mesh.positions[k]
            let n: Vec3 = mesh.normals[k]
            let uv: Vec2 = mesh.uvs[k]
            var finite: Bool = true
            for v in [p.x, p.y, p.z, n.x, n.y, n.z, uv.x, uv.y] where !v.isFinite { finite = false }
            let d = decoded(mesh, k)
            var ok: Bool = finite && abs(uv.x - Material.encode(d.material, value: d.value, broken: d.broken)) < 1e-9
            let length: Double = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
            if d.material == .backdrop {
                ok = ok && n.z == 0 && uv.y >= 0 && uv.y <= 1
            } else if solids.contains(d.material) {
                ok = ok && abs(length - 1) < 1e-9 && uv.y >= 0 && uv.y <= 1
                ok = ok && inBox(SIMD3(p.x, p.y, p.z))
            } else {
                ok = ok && abs(abs(n.x) - 1) < 1e-12 && abs(abs(n.y) - 1) < 1e-12 && n.z == 0 && uv.y == 0
                ok = ok && inBox(SIMD3(p.x, p.y, p.z))
            }
            if !ok { bad += 1 }
        }
        #expect(bad == 0, "\(bad) vertices off the streams or outside the box")
    }

    /// Checks that a glow mesh is finite, well indexed, bounded and follows the glow stream (a_normal a colour, factor
    /// 0 … 1 in a_uv.x, radial share 0 … 1 in a_uv.y).
    static func checkGlow(_ mesh: Mesh) {
        checkIndices(mesh)
        var bad: Int = 0
        for k in mesh.positions.indices {
            let n: Vec3 = mesh.normals[k]
            let uv: Vec2 = mesh.uvs[k]
            let p: Vec3 = mesh.positions[k]
            let ok: Bool = n.x >= 0 && n.x <= 1 && n.y >= 0 && n.y <= 1 && n.z >= 0 && n.z <= 1
                && uv.x > 0 && uv.x <= 1 && uv.y >= 0 && uv.y <= 1 && inBox(SIMD3(p.x, p.y, p.z))
            if !ok { bad += 1 }
        }
        #expect(bad == 0)
    }

    /// Checks the index list of `mesh`.
    static func checkIndices(_ mesh: Mesh) {
        #expect(mesh.indices.count % 3 == 0)
        #expect(mesh.normals.count == mesh.positions.count && mesh.uvs.count == mesh.positions.count)
        var bad: Int = 0
        for index in mesh.indices where Int(index) >= mesh.positions.count { bad += 1 }
        #expect(bad == 0)
    }

    // MARK: Streams and places

    @Test func materialCodesAreTheSharedTableAndRoundTrip() {
        let names: [Material] = [.backdrop, .floor, .grid, .site, .toxin, .rock, .blocker, .nutrient,
                                 .nutrientConsumed, .vein, .bloom, .sprout, .root, .terminalClosed, .terminalOpen,
                                 .gaugePlate, .weightFill, .limitTick, .pipFilled, .pipHollow, .actionsLit,
                                 .actionsUnlit, .fuzz, .spore]
        #expect(Material.allCases == names)
        for (code, material) in names.enumerated() {
            #expect(material.rawValue == code)
            for value in [0.0, 0.3, 1.0] {
                for broken in [false, true] {
                    let x: Double = Material.encode(material, value: value, broken: broken)
                    let d = Material.decode(x)
                    #expect(d.material == material && d.broken == broken)
                    #expect(abs(d.value - (material.isValued ? value : 0)) < 1e-9)
                    // As the shader reads it: floor(x + 0.001), broken from a remainder of 0.375.
                    #expect(Int((x + 0.001).rounded(.down)) == code)
                    #expect((x - Double(code) >= 0.375) == broken)
                }
            }
        }
        let valued: Set<Material> = [.toxin, .nutrient, .vein, .weightFill, .fuzz, .spore]
        for material in names { #expect(material.isValued == valued.contains(material)) }
    }

    @Test func fitRuleAndReferencePoints() throws {
        #expect(G.fitScale(width: 4, height: 4) == 1.9 / 4 && G.fitScale(width: 8, height: 32) == 1.9 / 32)
        let s: Double = G.fitScale(width: 4, height: 8)
        let c: SIMD3<Double> = G.centre(Cell(column: 1, row: 2), width: 4, height: 8, scale: s)
        #expect(Self.near(c, SIMD3((1 + 0.5 - 2) * s, 0.05 + (4 - 2 - 0.5) * s, 0)))
        let top: SIMD3<Double> = G.centre(Cell(column: 0, row: 0), width: 32, height: 32, scale: 1.9 / 32)
        #expect(abs(top.x - (-0.95 + 0.95 / 32)) < 1e-12 && abs(top.y - (1.0 - 0.95 / 32)) < 1e-12)
        for snapshot in try Self.extremes() + [try MyceliumArchitectExperienceCore.opening(number: 1).snapshotForRendering] {
            let points: [MyceliumArchitectReferencePoint] = G.referencePoints(snapshot)
            #expect(points.count == 4 + snapshot.level.terminals.count)
            #expect(points[0].kind == .boardCentre && Self.near(points[0].centre, SIMD3(0, 0.05, 0)))
            #expect(points[1].kind == .root && Self.near(points[1].centre, G.centre(snapshot.level.root, snapshot)))
            for (t, cell) in snapshot.level.terminals.enumerated() {
                let point: MyceliumArchitectReferencePoint = points[2 + t]
                #expect(point.kind == .terminal && point.index == t && Self.near(point.centre, G.centre(cell, snapshot)))
            }
            let order: [MyceliumArchitectElement] = G.paintOrder(snapshot)
            for point in points {
                switch point.kind {
                case .root:
                    #expect(order.contains { $0.kind == .root && Self.near($0.centre, point.centre) })
                case .terminal:
                    #expect(order.contains { $0.kind == .terminal && $0.item == point.index && Self.near($0.centre, point.centre) })
                case .gaugeMargin:
                    #expect(Self.near(point.centre, SIMD3(-0.925, -1.12, 0)))
                case .actionsBar:
                    #expect(order.contains { $0.kind == .actions && $0.item == 0 && Self.near($0.centre, point.centre) })
                    #expect(Self.near(point.centre, SIMD3(-0.95 + 0.5 * 1.9 / Double(snapshot.budget), -1.34, 0)))
                case .boardCentre:
                    break
                }
                for aspect in Self.aspects {
                    let camera: MyceliumArchitectCamera = G.camera(aspect: aspect)
                    #expect(Self.inView(point.centre, camera), "\(point.kind) at \(aspect)")
                    // The projection is the camera's view-projection, as the renderer draws it.
                    let clip: Vec4 = camera.viewProjection * Vec4(point.centre.x, point.centre.y, point.centre.z, 1)
                    let projected: SIMD2<Double> = try #require(G.project(point.centre, camera: camera))
                    #expect(abs(projected.x - (clip.x / clip.w + 1) / 2) < 1e-9)
                    #expect(abs(projected.y - (1 - clip.y / clip.w) / 2) < 1e-9)
                }
            }
        }
    }

    @Test func extremeSnapshotsAreFiniteAndInsideTheBoxAtEveryTier() throws {
        for snapshot in try Self.extremes() {
            for tier in MyceliumArchitectTier.all {
                let part: MyceliumArchitectColouredMesh = G.boardPart(snapshot, tier: tier)
                #expect(part.colours.count == part.mesh.positions.count && !part.mesh.indices.isEmpty)
                #expect(part.mesh == G.board(snapshot, tier: tier))
                Self.checkBoard(part.mesh)
                for colour in part.colours {
                    #expect(colour.x >= 0 && colour.x <= 1 && colour.y >= 0 && colour.y <= 1 && colour.w == 1)
                }
                let glow: Mesh = G.glow(snapshot, tier: tier)
                Self.checkGlow(glow)
                #expect(glow.positions.isEmpty == (tier.glowShells == 0))
                #expect(part.mesh.indices.count / 3 < 200_000)
            }
        }
    }

    @Test func cameraHoldsTheBoxWithAFivePercentMarginAndHandlesAZeroSizeView() {
        for aspect in Self.aspects {
            let camera: MyceliumArchitectCamera = G.camera(aspect: aspect)
            #expect(camera.eye == SIMD3(0, -1.9, 2.8) && camera.target == SIMD3(0, -0.3, 0))
            for index in 0..<8 { #expect(Self.inView(G.corner(index), camera), "corner \(index) at \(aspect)") }
            #expect(camera.fovY > 0 && camera.fovY < Double.pi && camera.near > 0 && camera.far > camera.near)
        }
        #expect(G.boxLow == SIMD3(-1.05, -1.45, 0) && G.boxHigh == SIMD3(1.05, 1.05, 0.25))
        #expect(G.aspectRange == 0.4...2.5)
        for aspect in [0.0, -1.0, Double.nan, Double.infinity] {
            let camera: MyceliumArchitectCamera = G.camera(aspect: aspect)
            #expect(camera.aspect == 1 && camera.fovY.isFinite)
            var finite: Bool = true
            for column in [camera.viewProjection.c0, camera.viewProjection.c1, camera.viewProjection.c2,
                           camera.viewProjection.c3] {
                for v in [column.x, column.y, column.z, column.w] where !v.isFinite { finite = false }
            }
            #expect(finite)
            #expect(G.project(SIMD3(0, 0.05, 0), camera: camera) != nil)
        }
        #expect(G.camera(aspect: 100).aspect == 10)
        #expect(G.project(SIMD3(.nan, 0, 0), camera: G.camera(aspect: 1)) == nil)
    }

    @Test func backdropFillsTheViewAndCarriesItsGradient() throws {
        let snapshot: Snapshot = try Self.small()
        let mesh: Mesh = G.board(snapshot, tier: MyceliumArchitectTier.of(0))
        var heights: [Double] = []
        for k in mesh.positions.indices where Self.decoded(mesh, k).material == .backdrop { heights.append(mesh.uvs[k].y) }
        #expect(heights.count == 4 && heights.contains(0) && heights.contains(1))
        for aspect in [0.25, 1.0, 4.0] {
            let camera: MyceliumArchitectCamera = G.camera(aspect: aspect)
            let corners: [SIMD3<Double>] = Self.positions(mesh, [.backdrop])
            var low: SIMD2<Double> = SIMD2(1, 1)
            var high: SIMD2<Double> = SIMD2(0, 0)
            for corner in corners {
                let p: SIMD2<Double> = try #require(G.project(corner, camera: camera))
                low = SIMD2(min(low.x, p.x), min(low.y, p.y))
                high = SIMD2(max(high.x, p.x), max(high.y, p.y))
            }
            #expect(low.x <= 0 && low.y <= 0 && high.x >= 1 && high.y >= 1, "aspect \(aspect)")
            let h: Double = G.backdropHeight(view: SIMD2(0.5, 0.95), camera: camera)
            #expect(h > 0 && h < 0.5)
        }
        let bottom: Vec4 = G.backdropColour(height: 0)
        #expect(bottom == MyceliumArchitectPalette.cave && G.backdropColour(height: 1) == MyceliumArchitectPalette.caveTop)
    }

    // MARK: Order

    @Test func elementsAndTrianglesFollowThePaintersOrder() throws {
        let rank: [Material: Int] = [.backdrop: 0, .floor: 1, .grid: 1, .site: 2, .toxin: 3, .rock: 4, .blocker: 5,
                                     .nutrient: 6, .nutrientConsumed: 6, .vein: 7, .bloom: 8, .fuzz: 9, .sprout: 10,
                                     .root: 11, .terminalClosed: 12, .terminalOpen: 12, .spore: 13, .gaugePlate: 14,
                                     .weightFill: 14, .limitTick: 14, .actionsLit: 16, .actionsUnlit: 16]
        for snapshot in try Self.extremes() {
            let order: [MyceliumArchitectElement] = G.paintOrder(snapshot)
            #expect(order.first?.kind == .backdrop && order.last?.kind == .glow)
            for k in 1..<order.count {
                let a: MyceliumArchitectElement = order[k - 1]
                let b: MyceliumArchitectElement = order[k]
                #expect(a.kind.rawValue < b.kind.rawValue || (a.kind == b.kind && a.index + 1 == b.index))
            }
            // Veins in growth order, one per shown grown cell but the root.
            var veins: [Int] = []
            for element in order where element.kind == .vein { veins.append(element.item) }
            var expected: [Int] = []
            for index in snapshot.grown.indices where index > 0 && snapshot.isShown(index) { expected.append(index) }
            #expect(veins == expected)
            let mesh: Mesh = G.board(snapshot, tier: MyceliumArchitectTier.of(0))
            var last: Int = 0
            var backwards: Int = 0
            var t: Int = 0
            while t < mesh.indices.count {
                let material: Material = Self.decoded(mesh, Int(mesh.indices[t])).material
                if let r = rank[material] {
                    if r < last { backwards += 1 }
                    last = max(last, r)
                }
                t += 3
            }
            #expect(backwards == 0)
        }
    }

    @Test func aSolidEmitsItsFarSideFirst() throws {
        let snapshot: Snapshot = try Self.lonely()
        let mesh: Mesh = G.board(snapshot, tier: MyceliumArchitectTier.of(0))
        var sawFront: Bool = false
        var backAfterFront: Int = 0
        var t: Int = 0
        while t < mesh.indices.count {
            let ids: [Int] = [Int(mesh.indices[t]), Int(mesh.indices[t + 1]), Int(mesh.indices[t + 2])]
            t += 3
            guard Self.decoded(mesh, ids[0]).material == .root else { continue }
            var normal: SIMD3<Double> = SIMD3(0, 0, 0)
            var middle: SIMD3<Double> = SIMD3(0, 0, 0)
            for id in ids {
                let n: Vec3 = mesh.normals[id]
                let p: Vec3 = mesh.positions[id]
                normal += SIMD3(n.x, n.y, n.z)
                middle += SIMD3(p.x, p.y, p.z) / 3
            }
            let front: Bool = G.dot(normal, G.eye - middle) > 0
            if front { sawFront = true } else if sawFront { backAfterFront += 1 }
        }
        #expect(sawFront && backAfterFront == 0)
    }

    // MARK: Tiers and the shown pulse

    @Test func tiersDifferOnlyInTessellationFuzzSporesAndGlow() throws {
        for snapshot in [try Self.small(), try Self.branching(), try Self.large()] {
            let order: [MyceliumArchitectElement] = G.paintOrder(snapshot)
            var meshes: [Mesh] = []
            for tier in MyceliumArchitectTier.all {
                meshes.append(G.board(snapshot, tier: tier))
                #expect(G.paintOrder(snapshot) == order)
            }
            let base: [String] = Self.key(meshes[0], excluding: Self.tiered)
            for mesh in meshes { #expect(Self.key(mesh, excluding: Self.tiered) == base) }
            for (index, tier) in MyceliumArchitectTier.all.enumerated() {
                #expect(Self.positions(meshes[index], [.spore]).count == 4 * tier.spores)
                if tier.fuzzStrands == 0 { #expect(Self.positions(meshes[index], [.fuzz]).isEmpty) }
                // A cap's rim has the tier's segments; a tube's ring the tier's sides.
                let root: [SIMD3<Double>] = Self.positions(meshes[index], [.root])
                #expect(root.count == tier.capSegments * G.capRings + 1)
            }
        }
        // Fuzz at the branch point and under the open cap, by tier.
        let branching: Snapshot = try Self.branching()
        #expect(G.branchPoints(branching) == [1])
        for tier in MyceliumArchitectTier.all {
            #expect(G.fuzzStrands(branching, tier: tier).count == 2 * tier.fuzzStrands)
        }
    }

    @Test func veinsTaperByPathWeight() throws {
        let snapshot: Snapshot = try Self.small()
        let s: Double = snapshot.fitScale
        let largest: Int = snapshot.largestPathWeight
        #expect(largest > 0)
        #expect(abs(G.veinRadius(weight: 0, largest: largest, scale: s) - 0.16 * s) < 1e-12)
        #expect(abs(G.veinRadius(weight: largest, largest: largest, scale: s) - 0.06 * s) < 1e-12)
        #expect(abs(G.veinRadius(weight: 5, largest: 0, scale: s) - 0.16 * s) < 1e-12)
        let mesh: Mesh = G.board(snapshot, tier: MyceliumArchitectTier.of(2))
        var top: Double = 0
        var shares: Set<Int> = []
        for k in mesh.positions.indices where Self.decoded(mesh, k).material == .vein {
            top = max(top, mesh.positions[k].z)
            shares.insert(Int((Self.decoded(mesh, k).value * 1000).rounded()))
            #expect(mesh.positions[k].z >= -1e-12)
        }
        #expect(abs(top - 0.32 * s) < 1e-9 && shares.contains(0) && shares.contains(1000))
        // Tier 2: 4 sides, 2 rings of 4 vertices per vein.
        #expect(Self.positions(mesh, [.vein]).count <= 8 * (snapshot.grown.count - 1))
    }

    @Test func theShownPulseChangesOnlyWhichVeinsAreDrawn() throws {
        let full: Snapshot = try Self.small()
        let excluded: Set<Material> = Self.pulsed
        for pulse in [0, 3, 8, 15] {
            let shown: Snapshot = try Self.small(shownPulse: pulse)
            var veins: Int = 0
            for element in G.paintOrder(shown) where element.kind == .vein { veins += 1 }
            #expect(veins == pulse)
            for tier in MyceliumArchitectTier.all {
                let a: Mesh = G.board(full, tier: tier)
                let b: Mesh = G.board(shown, tier: tier)
                #expect(Self.key(a, excluding: excluded) == Self.key(b, excluding: excluded))
            }
            // Every drawn vein ends on shown cells only.
            var cells: [SIMD3<Double>] = []
            for index in shown.grown.indices where shown.isShown(index) { cells.append(G.centre(shown.grown[index], shown)) }
            for element in G.paintOrder(shown) where element.kind == .vein {
                let child: SIMD3<Double> = G.centre(shown.grown[element.item], shown)
                #expect(cells.contains { Self.near($0, child) })
            }
            // The terminal opens exactly when the kernel's terminal pulse is shown.
            let open: Int = Self.positions(G.board(shown, tier: MyceliumArchitectTier.of(0)), [.terminalOpen]).count
            #expect((open > 0) == shown.isReached(0))
        }
    }

    // MARK: Failures

    @Test func eachFailureKindIsMarkedOnAFailedPlayOnly() throws {
        let tier: MyceliumArchitectTier = MyceliumArchitectTier.of(1)
        let toxin: Cell = Cell(column: 3, row: 3)
        let toxic: MyceliumArchitectFailure = .toxic(pulse: 2, tip: 0, cell: toxin)
        let starvedCell: Cell = Cell(column: 3, row: 0)
        let starved: MyceliumArchitectFailure = .starved(pulse: 3, tip: 0, cell: starvedCell, weight: 4, budget: 2)
        let unreached: MyceliumArchitectFailure = .unreached(terminal: 0)
        let overweight: MyceliumArchitectFailure = .overweight(weight: 4094, limit: 2)
        for failure in [toxic, starved, unreached, overweight] {
            let playing: Mesh = G.board(try Self.small(failure: failure, stage: .playing), tier: tier)
            #expect(Self.positions(playing, Set(Material.allCases), broken: true).isEmpty, "\(failure) while playing")
            for stage in [MyceliumArchitectStage.failed, .result] {
                let snapshot: Snapshot = try Self.small(failure: failure, stage: stage)
                let mesh: Mesh = G.board(snapshot, tier: tier)
                var broken: Set<Material> = []
                for k in mesh.positions.indices where Self.decoded(mesh, k).broken {
                    broken.insert(Self.decoded(mesh, k).material)
                }
                let s: Double = snapshot.fitScale
                switch failure {
                case .toxic:
                    #expect(broken == [.pipHollow])
                    let ring: [SIMD3<Double>] = Self.positions(mesh, [.pipHollow], broken: true)
                    var mid: SIMD3<Double> = SIMD3(0, 0, 0)
                    for p in ring { mid += p / Double(ring.count) }
                    #expect(ring.count == 4 && Self.near(mid, G.centre(toxin, snapshot)))
                    #expect(abs(abs(ring[0].x - mid.x) - 0.5 * s) < 1e-12)
                case .starved:
                    #expect(broken == [.site, .limitTick])
                    let outline: [SIMD3<Double>] = Self.positions(mesh, [.site], broken: true)
                    var mid: SIMD3<Double> = SIMD3(0, 0, 0)
                    for p in outline { mid += p / Double(outline.count) }
                    #expect(outline.count == 4 && Self.near(mid, G.centre(starvedCell, snapshot)))
                    let tick: [SIMD3<Double>] = Self.positions(mesh, [.limitTick], broken: true)
                    #expect(tick.count == 4 && abs((tick[0].x + tick[2].x) / 2 - 0.9) < 1e-12)
                case .unreached:
                    #expect(broken == [.pipHollow])
                    let ring: [SIMD3<Double>] = Self.positions(mesh, [.pipHollow], broken: true)
                    var mid: SIMD3<Double> = SIMD3(0, 0, 0)
                    for p in ring { mid += p / Double(ring.count) }
                    #expect(ring.count == 4 && Self.near(mid, G.centre(snapshot.level.terminals[0], snapshot)))
                case .overweight:
                    #expect(broken == [.weightFill])
                    let past: [SIMD3<Double>] = Self.positions(mesh, [.weightFill], broken: true)
                    var left: Double = 1
                    for p in past { left = min(left, p.x) }
                    #expect(abs(left - G.weightX(snapshot.weightLimit, budget: snapshot.nutrientBudget)) < 1e-12)
                }
                let colours: [Vec4] = G.boardPart(snapshot, tier: tier).colours
                var brokenColour: Bool = false
                for k in mesh.positions.indices where Self.decoded(mesh, k).broken {
                    brokenColour = brokenColour || colours[k] == MyceliumArchitectPalette.broken
                }
                #expect(brokenColour)
            }
        }
    }

    // MARK: Fallback and glow

    @Test func theFallbackIsTheLevel2BoardInPaletteColours() throws {
        let snapshot: Snapshot = try Self.branching()
        let fallback: MyceliumArchitectColouredMesh = G.fallback(snapshot)
        #expect(fallback.mesh == G.board(snapshot, tier: MyceliumArchitectTier.of(2)))
        for k in fallback.mesh.positions.indices {
            let d = Self.decoded(fallback.mesh, k)
            if d.material == .backdrop {
                let h: Double = Double(fallback.mesh.uvs[k].y)
                #expect(fallback.colours[k] == G.backdropColour(height: h))
            } else {
                #expect(fallback.colours[k] == d.material.colour)
            }
        }
        #expect(Material.vein.colour == MyceliumArchitectPalette.emerald)
        #expect(Material.terminalOpen.colour == MyceliumArchitectPalette.capOpen)
        #expect(Material.terminalClosed.colour == MyceliumArchitectPalette.capClosed)
        #expect(Material.actionsLit.colour == MyceliumArchitectPalette.actionsLit)
    }

    @Test func glowShellsPerTierAroundTheRootOpenCapsAndBlooms() throws {
        let snapshot: Snapshot = try Self.branching()
        // The root, one open terminal and one bloom; per shell an annulus of 24 sides (48 welded vertices).
        for tier in MyceliumArchitectTier.all {
            let glow: Mesh = G.glow(snapshot, tier: tier)
            #expect(glow.positions.count == 3 * tier.glowShells * G.glowSides * 2)
            var factors: Set<Int> = []
            var emerald: Int = 0
            for k in glow.positions.indices {
                factors.insert(Int((glow.uvs[k].x * 100).rounded()))
                let n: Vec3 = glow.normals[k]
                if n.x == 0 && n.y == 0 && n.z == 0 { emerald += 1 }
            }
            if tier.glowShells == 2 { #expect(factors == [100, 50]) }
            if tier.glowShells == 1 { #expect(factors == [100]) }
            #expect(emerald == tier.glowShells * G.glowSides * 2)
        }
        #expect(G.glow(snapshot, tier: MyceliumArchitectTier.of(2)).positions.isEmpty)
        var glowItems: [Int] = []
        for element in G.paintOrder(snapshot) where element.kind == .glow { glowItems.append(element.item) }
        #expect(glowItems == [0, 1, 1 + 6])
    }
}
