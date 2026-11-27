// MushroomWeatherSceneGeometryTests — feature 493 (R02-G20-03) T-R02G2003-004 (FR-R02G2003-001, 002, 003, 004, 006,
// 007; SC-R02G2003-001, 003; clarifications Q1–Q4). The forest geometry: the fitting rule and the CPU reference places;
// finite and bounded meshes for extreme settings (6 × 6 and 12 × 14 floors, 1 and 6 colonies, 0 and 6 vents, 6 pods,
// humidity 0 and above M, budgets 1 and 24) at every tier; every element inside the view with a margin at 7 aspects
// over a sample of the catalog's levels (two per difficulty band, as the generator tests sample them; the authored box
// holds every vertex and the camera holds the box); the same positions at every tier; mist sizes from the kernel's
// values only; gauges at 0, the band edges and M; a won level in place; the glow mesh empty at level-2 and its shell
// counts per tier; each failure kind marked on a failed play only (never for a predicted failure); the streams of
// `MushroomWeatherShaders` (encoded codes, quad-local normals at ±1.25, strips, lathed and flat solids); the fronds'
// reach, the droplets and motes per tier and independent of time; the backdrop filling the view and its gradient
// coordinate; the fallback colours. Explicit types, plain loops.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherSceneGeometryTests {
    typealias G = MushroomWeatherSceneGeometry
    typealias Cell = MushroomWeatherCell
    typealias Snapshot = MushroomWeatherSceneSnapshot

    /// The sampled catalog levels (numbers 1 … 100): two per difficulty band.
    static let sampleNumbers: [Int] = [1, 2, 21, 22, 41, 42, 61, 62, 81, 82]

    /// The sampled certified levels, generated once.
    static let levels: [MushroomWeatherLevel] = {
        var result: [MushroomWeatherLevel] = []
        for number in sampleNumbers {
            do {
                let generated: MushroomWeatherGenerated =
                    try MushroomWeatherGenerator.generate(MushroomWeatherManifest.entries[number - 1], previous: nil)
                result.append(generated.level)
            } catch {
                fatalError("level \(number) does not generate: \(error)")
            }
        }
        return result
    }()

    /// The seven aspects checked.
    static let aspects: [Double] = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]

    /// A snapshot of `level` in stage `playing` at the middle of its predicted run.
    static func snapshot(_ level: MushroomWeatherLevel, number: Int = 1, time: Double = 0) throws -> Snapshot {
        var play: MushroomWeatherPlay = MushroomWeatherPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        let probe: Snapshot = Snapshot(play: play, shownCycle: 0, levelNumber: number, time: time)
        return Snapshot(play: play, shownCycle: probe.cyclesRun / 2, levelNumber: number, time: time)
    }

    /// `base` with the given values replaced (the unchecked initialiser).
    static func variant(_ base: Snapshot, fields: [[Int]]? = nil, shownCycle: Int? = nil,
                        colonies: [MushroomWeatherSceneColony]? = nil, failure: MushroomWeatherFailure?? = nil,
                        stage: MushroomWeatherStage? = nil) -> Snapshot {
        let newFields: [[Int]] = fields ?? base.fields
        return Snapshot(rows: base.rows, columns: base.columns, blocked: base.blocked, fields: newFields,
                        cyclesRun: newFields.count - 1, shownCycle: shownCycle ?? base.shownCycle,
                        moldBound: base.moldBound, colonies: colonies ?? base.colonies,
                        requiredCycles: base.requiredCycles, pods: base.pods, grownAt: base.grownAt,
                        sites: base.sites, vents: base.vents, ventsOpen: base.ventsOpen, moonlight: base.moonlight,
                        failure: failure ?? base.failure, stage: stage ?? base.stage, actionsLeft: base.actionsLeft,
                        budget: base.budget, levelNumber: base.levelNumber, time: base.time)
    }

    /// An extreme snapshot: a `rows` × `columns` floor (blocked cells on a diagonal), `colonies` colonies, `vents`
    /// vents (alternately open), six pods (every other one grown), every humidity `humidity`, budget `budget`.
    static func extreme(rows: Int, columns: Int, colonies count: Int, vents ventCount: Int, humidity: Int,
                        budget: Int, required: Int, failure: MushroomWeatherFailure? = nil,
                        stage: MushroomWeatherStage = .playing, time: Double = 0) -> Snapshot {
        var blocked: [Cell] = []
        for k in 0..<min(rows, columns) where k % 3 == 1 { blocked.append(Cell(row: k, column: k)) }
        let blockedSet: Set<Cell> = Set(blocked)
        var free: [Cell] = []
        for r in 0..<rows {
            for c in 0..<columns {
                let cell: Cell = Cell(row: r, column: c)
                if !blockedSet.contains(cell) { free.append(cell) }
            }
        }
        var colonies: [MushroomWeatherSceneColony] = []
        for k in 0..<count {
            colonies.append(MushroomWeatherSceneColony(cell: free[k], low: 100, high: 900, survivalFloor: nil,
                                                       finalRun: k, longestRun: k, inBand: k % 2 == 0))
        }
        var pods: [Cell?] = []
        var grownAt: [Int?] = []
        for k in 0..<6 {
            pods.append(free[free.count - 1 - k])
            grownAt.append(k % 2 == 0 ? 0 : nil)
        }
        var vents: [Cell] = []
        var ventsOpen: [Bool] = []
        for k in 0..<ventCount {
            vents.append(free[count + k])
            ventsOpen.append(k % 2 == 0)
        }
        let sites: [Cell] = Array(free[(free.count - 6)...])
        let field: [Int] = Array(repeating: humidity, count: rows * columns)
        return Snapshot(rows: rows, columns: columns, blocked: blocked, fields: [field, field, field], cyclesRun: 2,
                        shownCycle: 1, moldBound: 1000, colonies: colonies, requiredCycles: required, pods: pods,
                        grownAt: grownAt, sites: sites, vents: vents, ventsOpen: ventsOpen, moonlight: 3,
                        failure: failure, stage: stage, actionsLeft: budget / 2, budget: budget, levelNumber: 1,
                        time: time)
    }

    /// The extreme snapshots of the task.
    static func extremes() -> [Snapshot] {
        [extreme(rows: 6, columns: 6, colonies: 1, vents: 0, humidity: 0, budget: 1, required: 5),
         extreme(rows: 12, columns: 14, colonies: 6, vents: 6, humidity: 5000, budget: 24, required: 15),
         extreme(rows: 6, columns: 6, colonies: 6, vents: 6, humidity: 1000, budget: 24, required: 40),
         extreme(rows: 12, columns: 14, colonies: 1, vents: 0, humidity: 0, budget: 1, required: 5,
                 failure: .dried(colony: 0, cycle: 1), stage: .failed, time: 123.4)]
    }

    /// The decoded a_uv.x of vertex `k` of a forest mesh.
    static func decoded(_ mesh: Mesh, _ k: Int) -> (material: MushroomWeatherMaterial, value: Double, broken: Bool) {
        MushroomWeatherShaders.decode(mesh.uvs[k].x)
    }

    /// The positions of `mesh`'s vertices whose material is in `materials` (and whose broken mark is `broken`, when
    /// given).
    static func positions(_ mesh: Mesh, _ materials: Set<MushroomWeatherMaterial>,
                          broken: Bool? = nil) -> [SIMD3<Double>] {
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

    /// The positions of `mesh`'s vertices with the broken mark.
    static func brokenPositions(_ mesh: Mesh) -> [SIMD3<Double>] {
        positions(mesh, Set(MushroomWeatherMaterial.allCases), broken: true)
    }

    /// The positions of `points` as a sorted list of rounded strings (order-free comparison).
    static func key(_ points: [SIMD3<Double>]) -> [String] {
        var keys: [String] = []
        for p in points { keys.append(String(format: "%.9f %.9f %.9f", p.x, p.y, p.z)) }
        return Set(keys).sorted()
    }

    /// Whether `point` lies in the authored box (z from −0.02 for the parts cut at the floor).
    static func inBox(_ point: SIMD3<Double>) -> Bool {
        let tolerance: Double = 1e-9
        return point.x >= G.boxLow.x - tolerance && point.x <= G.boxHigh.x + tolerance
            && point.y >= G.boxLow.y - tolerance && point.y <= G.boxHigh.y + tolerance
            && point.z >= -0.02 && point.z <= G.boxHigh.z + tolerance
    }

    /// Whether `point` projects inside the view with a margin of at least 5 % on each side.
    static func inView(_ point: SIMD3<Double>, _ camera: MushroomWeatherCamera) -> Bool {
        guard let p = G.project(point, camera: camera) else { return false }
        return p.x >= 0.05 && p.x <= 0.95 && p.y >= 0.05 && p.y <= 0.95
    }

    /// The materials drawn as quads (a_normal the quad-local coordinate).
    static let quadMaterials: Set<MushroomWeatherMaterial> = [.moon, .phaseTickLit, .phaseTickUnlit, .floor, .mist,
                                                              .siteRing, .bandRingSolid, .bandRingDashed, .podRing,
                                                              .droplet, .mote, .ventSlat, .bandBracket, .marker,
                                                              .runLit, .runUnlit, .barLit, .barUnlit, .moldPatch]

    /// The materials drawn as strips (a_normal zero, a_uv.y across).
    static let stripMaterials: Set<MushroomWeatherMaterial> = [.frond, .ventFrame, .gaugeTrack]

    /// The solid materials (a_normal the world normal when lathed, zero when flat).
    static let solidMaterials: Set<MushroomWeatherMaterial> = [.log, .stone, .stalk, .cap, .capOut, .pod]

    /// Checks that a forest mesh is finite, well indexed, bounded (every point it can reach in the box except the
    /// backdrop and the moon) and follows the streams of `MushroomWeatherShaders` at `tier`.
    static func checkForest(_ mesh: Mesh, tier: MushroomWeatherTier) {
        checkIndices(mesh)
        let e: Double = MushroomWeatherShaders.quadExtent
        for k in mesh.positions.indices {
            let p: Vec3 = mesh.positions[k]
            let n: Vec3 = mesh.normals[k]
            let uv: Vec2 = mesh.uvs[k]
            var finite: Bool = true
            for v in [p.x, p.y, p.z, n.x, n.y, n.z, uv.x, uv.y] where !v.isFinite { finite = false }
            #expect(finite)
            let d = decoded(mesh, k)
            #expect(abs(uv.x - MushroomWeatherShaders.encode(d.material, value: d.value, broken: d.broken)) < 1e-9)
            #expect(uv.y >= -1 - 1e-9 && uv.y <= 1 + 1e-9)
            let length: Double = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
            if quadMaterials.contains(d.material) {
                #expect(abs(abs(n.x) - e) < 1e-12 && abs(abs(n.y) - e) < 1e-12 && uv.y == 0, "\(d.material)")
                if d.material != .droplet && d.material != .mote { #expect(n.z == 0) }
            } else if stripMaterials.contains(d.material) || d.material == .backdrop {
                #expect(length == 0, "\(d.material)")
            } else if solidMaterials.contains(d.material) {
                let flat: Bool = tier.flatCaps && [.stalk, .cap, .capOut, .pod].contains(d.material)
                if flat {
                    #expect(length == 0 && (uv.y == 0 || uv.y == 1), "\(d.material)")
                } else {
                    #expect(abs(length - 1) < 1e-9 && uv.y == 0, "\(d.material)")
                }
            }
            let point: SIMD3<Double> = SIMD3(p.x, p.y, p.z)
            switch d.material {
            case .backdrop, .moon, .phaseTickLit, .phaseTickUnlit:
                continue
            case .droplet:
                #expect(inBox(point) && inBox(point + SIMD3(0, 0, n.z)))
            case .mote:
                #expect(inBox(point) && inBox(point + SIMD3(-2 * n.z, 0, 0)) && inBox(point + SIMD3(-n.z, n.z, 0))
                        && inBox(point + SIMD3(-n.z, -n.z, 0)))
            default:
                #expect(inBox(point), "\(d.material) vertex at \(p.x), \(p.y), \(p.z)")
            }
        }
    }

    /// Checks that a glow mesh is finite, well indexed and follows the glow stream (a_normal zero, kind and factor in
    /// a_uv.x, a_uv.y 0 or 1).
    static func checkGlow(_ mesh: Mesh) {
        checkIndices(mesh)
        for k in mesh.positions.indices {
            let n: Vec3 = mesh.normals[k]
            let uv: Vec2 = mesh.uvs[k]
            #expect(n.x == 0 && n.y == 0 && n.z == 0)
            #expect(uv.x >= 0 && uv.x <= 3 && (uv.y == 0 || uv.y == 1))
            let p: Vec3 = mesh.positions[k]
            #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
        }
    }

    /// Checks the index list of `mesh`.
    static func checkIndices(_ mesh: Mesh) {
        #expect(mesh.indices.count % 3 == 0)
        #expect(mesh.normals.count == mesh.positions.count && mesh.uvs.count == mesh.positions.count)
        var bad: Int = 0
        for index in mesh.indices where Int(index) >= mesh.positions.count { bad += 1 }
        #expect(bad == 0)
    }

    /// The placed pods of `snapshot`.
    static func podCount(_ snapshot: Snapshot) -> Int {
        var count: Int = 0
        for pod in snapshot.pods where pod != nil { count += 1 }
        return count
    }

    // MARK: Places

    @Test func fittingRuleAndReferencePlaces() throws {
        #expect(abs(G.scale(rows: 6, columns: 6) - 1.6 / 6) < 1e-12)
        #expect(abs(G.scale(rows: 6, columns: 9) - 0.2) < 1e-12)
        #expect(abs(G.scale(rows: 12, columns: 14) - 1.8 / 14) < 1e-12)
        let level: MushroomWeatherLevel = Self.levels[0]
        let snap: Snapshot = try Self.snapshot(level)
        let s: Double = G.scale(rows: level.rows, columns: level.columns)
        let corner: SIMD3<Double> = G.cellCentre(Cell(row: 0, column: 0), snap, height: 0)
        #expect(abs(corner.x - (-Double(level.columns - 1) / 2 * s)) < 1e-12)
        #expect(abs(corner.y - Double(level.rows - 1) / 2 * s) < 1e-12)
        let raised: SIMD3<Double> = G.cellCentre(Cell(row: 1, column: 2), snap, height: 0.9)
        #expect(abs(raised.z - 0.9 * s) < 1e-12)
        #expect(G.floorCentre() == SIMD3(0, 0, 0))
        #expect(G.moonCentre() == SIMD3(1.15, 1.05, -0.5))
        #expect(G.gaugeTrackCentre(0) == SIMD3(0, -1.0, 0))
        #expect(abs(G.gaugeTrackCentre(3).y - (-1.21)) < 1e-12)
        let bar: SIMD3<Double> = G.actionsBar(0, snap)
        #expect(abs(bar.x - (-0.9 + 0.9 / Double(snap.budget))) < 1e-12)
        #expect(abs(bar.y - (-1.0 - 0.07 * Double(snap.colonies.count) - 0.05)) < 1e-12)
        for k in snap.colonies.indices {
            let c: SIMD3<Double> = G.capCentre(k, snap)
            let cell: SIMD3<Double> = G.cellCentre(snap.colonies[k].cell, snap, height: 0)
            #expect(c.x == cell.x && c.y == cell.y && abs(c.z - 0.45 * s) < 1e-12)
        }
        let points: [MushroomWeatherReferencePoint] = G.referencePoints(snap)
        #expect(points.count == snap.colonies.count + 4)
        #expect(points[0].kind == .floorCentre)
        #expect(points[points.count - 1].kind == .actionsBar)
        #expect(points[points.count - 2].kind == .gaugeTrack)
        #expect(points[points.count - 3].kind == .moon)
        var caps: Int = 0
        for point in points where point.kind == .cap { caps += 1 }
        #expect(caps == snap.colonies.count)
    }

    @Test func paintOrderIsByKindThenIndex() throws {
        let snap: Snapshot = try Self.snapshot(Self.levels[1])
        let order: [MushroomWeatherElement] = G.paintOrder(snap)
        for k in 1..<order.count {
            #expect(!MushroomWeatherElement.drawsBefore(order[k], order[k - 1]))
        }
        #expect(order[0].kind == .backdrop)
        #expect(order[order.count - 1].kind == .bar)
        #expect(MushroomWeatherElement.Kind.cap.isSolid && MushroomWeatherElement.Kind.vent.isSolid)
        #expect(!MushroomWeatherElement.Kind.mist.isSolid && !MushroomWeatherElement.Kind.gauge.isSolid)
    }

    // MARK: Bounds and streams

    @Test func extremeSettingsAreFiniteBoundedAndFollowTheStreams() throws {
        for snap in Self.extremes() {
            for tier in MushroomWeatherTier.all {
                let forest: Mesh = try G.forestMesh(snap, tier: tier)
                Self.checkForest(forest, tier: tier)
                #expect(forest.indices.count > 0)
                let glow: Mesh = try G.glowMesh(snap, tier: tier)
                Self.checkGlow(glow)
                for aspect in Self.aspects {
                    let camera: MushroomWeatherCamera = G.camera(aspect: aspect)
                    for p in Self.positions(forest, [.moon, .phaseTickLit, .phaseTickUnlit]) {
                        #expect(Self.inView(p, camera))
                    }
                    var outside: Int = 0
                    for v in glow.positions where !Self.inView(SIMD3(v.x, v.y, v.z), camera) { outside += 1 }
                    #expect(outside == 0)
                }
            }
        }
    }

    @Test func cameraHoldsTheBoxAtSevenAspects() {
        for aspect in Self.aspects {
            let camera: MushroomWeatherCamera = G.camera(aspect: aspect)
            #expect(camera.aspect == aspect)
            for index in 0..<8 { #expect(Self.inView(G.corner(index), camera), "corner \(index) at \(aspect)") }
            guard let centre = G.project(G.lookAt, camera: camera) else {
                Issue.record("target not projected")
                continue
            }
            #expect(abs(centre.x - 0.5) < 1e-9 && abs(centre.y - 0.5) < 1e-9)
        }
        #expect(G.camera(aspect: .nan).aspect == 1)
        #expect(G.camera(aspect: -2).aspect == 1)
        #expect(G.camera(aspect: 50).aspect == 10)
        #expect(G.project(SIMD3(.infinity, 0, 0), camera: G.camera(aspect: 1)) == nil)
    }

    @Test func everyElementInsideTheViewOverCatalogLevels() throws {
        for (n, level) in Self.levels.enumerated() {
            let snap: Snapshot = try Self.snapshot(level, number: Self.sampleNumbers[n], time: 7.5)
            let tier: MushroomWeatherTier = MushroomWeatherTier.all[0]
            let forest: Mesh = try G.forestMesh(snap, tier: tier)
            Self.checkForest(forest, tier: tier)
            let glow: Mesh = try G.glowMesh(snap, tier: tier)
            let moon: [SIMD3<Double>] = Self.positions(forest, [.moon, .phaseTickLit, .phaseTickUnlit])
            for aspect in Self.aspects {
                let camera: MushroomWeatherCamera = G.camera(aspect: aspect)
                for point in G.referencePoints(snap) { #expect(Self.inView(point.centre, camera)) }
                for p in moon { #expect(Self.inView(p, camera)) }
                var outside: Int = 0
                for v in glow.positions where !Self.inView(SIMD3(v.x, v.y, v.z), camera) { outside += 1 }
                #expect(outside == 0, "level \(Self.sampleNumbers[n]) aspect \(aspect)")
            }
        }
    }

    // MARK: Tiers

    @Test func samePositionsAtEveryTier() throws {
        let shared: Set<MushroomWeatherMaterial> = [.backdrop, .moon, .phaseTickLit, .phaseTickUnlit, .floor, .log,
                                                    .stone, .mist, .siteRing, .bandRingSolid, .bandRingDashed,
                                                    .podRing, .ventFrame, .ventSlat, .gaugeTrack, .bandBracket,
                                                    .marker, .runLit, .runUnlit, .barLit, .barUnlit]
        for level in Self.levels {
            let snap: Snapshot = try Self.snapshot(level, time: 3)
            let first: Mesh = try G.forestMesh(snap, tier: MushroomWeatherTier.of(0))
            let reference: [String] = Self.key(Self.positions(first, shared))
            for index in 1...2 {
                let other: Mesh = try G.forestMesh(snap, tier: MushroomWeatherTier.of(index))
                #expect(Self.key(Self.positions(other, shared)) == reference, "tier \(index)")
            }
        }
    }

    @Test func frondsDropletsAndMotesPerTierAndIndependentOfTime() throws {
        let snap: Snapshot = Self.extreme(rows: 6, columns: 6, colonies: 2, vents: 1, humidity: 400, budget: 4,
                                          required: 5, time: 2.25)
        let later: Snapshot = Self.extreme(rows: 6, columns: 6, colonies: 2, vents: 1, humidity: 400, budget: 4,
                                           required: 5, time: 300.0)
        let s: Double = G.scale(rows: 6, columns: 6)
        let roots: [(root: SIMD3<Double>, lean: Double)] = G.frondRoots(snap)
        let stems: [(from: SIMD3<Double>, to: SIMD3<Double>, generation: Int)] = G.frondStems(snap)
        #expect(stems.count == roots.count * 7)
        for (k, stem) in stems.enumerated() {
            let root: SIMD3<Double> = roots[k / 7].root
            let d: SIMD3<Double> = stem.to - root
            #expect((d.x * d.x + d.y * d.y + d.z * d.z).squareRoot() <= 0.3 * s + 1e-12)
            #expect(stem.to.z >= root.z)
        }
        for tier in MushroomWeatherTier.all {
            let mesh: Mesh = try G.forestMesh(snap, tier: tier)
            #expect(Self.positions(mesh, [.frond]).isEmpty == !tier.fronds)
            #expect(Self.positions(mesh, [.droplet]).count == 4 * 6 * tier.droplets)
            #expect(Self.positions(mesh, [.mote]).count == 4 * tier.motes)
            let droplets: [(centre: SIMD3<Double>, phase: Double)] = G.droplets(0, snap, tier: tier)
            #expect(droplets.count == tier.droplets)
            for (k, droplet) in droplets.enumerated() {
                #expect(droplet.phase == Double(k) / Double(max(tier.droplets, 1)))
            }
            #expect(G.motes(tier: tier).count == tier.motes)
            let laterMesh: Mesh = try G.forestMesh(later, tier: tier)
            #expect(mesh == laterMesh)
            for k in mesh.positions.indices {
                let d = Self.decoded(mesh, k)
                if d.material == .droplet {
                    #expect(abs(mesh.normals[k].z - MushroomWeatherShaders.dropletRise(scale: s)) < 1e-12)
                }
                if d.material == .mote { #expect(mesh.normals[k].z == MushroomWeatherShaders.moteLoopRadius) }
            }
        }
        for point in G.referencePoints(snap) {
            for mote in G.motes(tier: MushroomWeatherTier.of(0)) { #expect(point.centre != mote.centre) }
        }
    }

    // MARK: Values

    @Test func mistSizesComeFromTheKernelValuesOnly() throws {
        let s: Double = 0.25
        #expect(abs(G.mistSide(0, moldBound: 1000, scale: s) - 0.2 * s) < 1e-12)
        #expect(abs(G.mistSide(500, moldBound: 1000, scale: s) - 0.55 * s) < 1e-12)
        #expect(abs(G.mistSide(1000, moldBound: 1000, scale: s) - 0.9 * s) < 1e-12)
        #expect(abs(G.mistSide(4000, moldBound: 1000, scale: s) - 0.9 * s) < 1e-12)
        #expect(abs(G.mistSide(-7, moldBound: 1000, scale: s) - 0.2 * s) < 1e-12)
        let level: MushroomWeatherLevel = Self.levels[2]
        let base: Snapshot = try Self.snapshot(level)
        let scale: Double = G.scale(rows: level.rows, columns: level.columns)
        for cycle in [0, base.cyclesRun / 2, base.cyclesRun] {
            let snap: Snapshot = Self.variant(base, shownCycle: cycle)
            let squares = G.mistSquares(snap)
            #expect(squares.count == level.rows * level.columns - level.blocked.count)
            let mesh: Mesh = try G.forestMesh(snap, tier: MushroomWeatherTier.of(1))
            let mist: Set<String> = Set(Self.key(Self.positions(mesh, [.mist])))
            var values: Set<String> = []
            for k in mesh.positions.indices where Self.decoded(mesh, k).material == .mist {
                values.insert(String(format: "%.6f", Self.decoded(mesh, k).value))
            }
            var expected: Set<String> = []
            for square in squares {
                let h: Int = snap.fields[cycle][square.cell.row * level.columns + square.cell.column]
                #expect(square.side == G.mistSide(h, moldBound: level.moldBound, scale: scale))
                #expect(square.share == MushroomWeatherShaders.moisture(humidity: h, moldBound: level.moldBound))
                #expect(square.centre.z == G.mistZ)
                expected.insert(String(format: "%.6f", square.share))
                let half: Double = square.side / 2 * MushroomWeatherShaders.quadExtent
                let corner: SIMD3<Double> = square.centre + SIMD3(half, half, 0)
                #expect(mist.contains(Self.key([corner])[0]))
            }
            #expect(values == expected)
        }
    }

    @Test func gaugesAtZeroBandEdgesAndTheBound() throws {
        let base: Snapshot = try Self.snapshot(Self.levels[3])
        let m: Int = base.moldBound
        let e: Double = MushroomWeatherShaders.quadExtent
        #expect(G.gaugeX(0, top: m) == -0.9)
        #expect(G.gaugeX(m, top: m) == 0.9)
        #expect(G.gaugeX(m * 3, top: m) == 0.9)
        #expect(G.gaugeX(-5, top: m) == -0.9)
        let colony: MushroomWeatherSceneColony = base.colonies[0]
        let index: Int = colony.cell.row * base.columns + colony.cell.column
        for value in [0, colony.low, colony.high, m] {
            var field: [Int] = base.fields[0]
            field[index] = value
            let snap: Snapshot = Self.variant(base, fields: [field], shownCycle: 0)
            let marker: SIMD3<Double> = G.markerCentre(0, snap)
            #expect(abs(marker.x - (-0.9 + 1.8 * Double(value) / Double(m))) < 1e-12)
            #expect(marker.y == -1.0)
            let mesh: Mesh = try G.forestMesh(snap, tier: MushroomWeatherTier.of(2))
            var xs: [Double] = []
            for p in Self.positions(mesh, [.marker]) where abs(p.y - marker.y) <= e * G.markerHalf + 1e-12 {
                xs.append(p.x)
            }
            #expect(xs.count == 4)
            #expect(abs(((xs.min() ?? 0) + (xs.max() ?? 0)) / 2 - marker.x) < 1e-12)
            #expect(abs((xs.max() ?? 0) - (xs.min() ?? 0) - 2 * e * G.markerHalf) < 1e-12)
        }
        let mesh: Mesh = try G.forestMesh(base, tier: MushroomWeatherTier.of(0))
        var xs: [Double] = []
        var ys: [Double] = []
        for p in Self.positions(mesh, [.bandBracket]) where p.y > -1.0 - 0.02 && p.y < -0.95 {
            xs.append(p.x)
            ys.append(p.y)
        }
        #expect(xs.count == 4)
        let mid: Double = ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2
        let shapeHalf: Double = ((xs.max() ?? 0) - (xs.min() ?? 0)) / 2 / e
        #expect(abs(mid - shapeHalf - G.gaugeX(colony.low, top: m)) < 1e-9)
        #expect(abs(mid + shapeHalf - G.gaugeX(colony.high, top: m)) < 1e-9)
        let midY: Double = ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2
        let halfY: Double = ((ys.max() ?? 0) - (ys.min() ?? 0)) / 2 / e
        #expect(abs(midY - halfY - (-1.0)) < 1e-9)
        #expect(abs(midY + halfY - (-1.0 + G.bracketOffset + G.bracketHeight / 2)) < 1e-9)
    }

    @Test func wonLevelStaysInPlace() throws {
        let level: MushroomWeatherLevel = Self.levels[4]
        let playing: Snapshot = try Self.snapshot(level)
        var colonies: [MushroomWeatherSceneColony] = []
        for colony in playing.colonies {
            colonies.append(MushroomWeatherSceneColony(cell: colony.cell, low: colony.low, high: colony.high,
                                                       survivalFloor: colony.survivalFloor, finalRun: colony.finalRun,
                                                       longestRun: colony.longestRun, inBand: false))
        }
        let out: Snapshot = Self.variant(playing, colonies: colonies, failure: .some(nil), stage: .playing)
        let won: Snapshot = Self.variant(out, stage: .won)
        #expect(G.referencePoints(won) == G.referencePoints(out))
        #expect(G.paintOrder(won) == G.paintOrder(out))
        for tier in MushroomWeatherTier.all {
            let before: MushroomWeatherColouredMesh = try G.forestPart(out, tier: tier)
            let after: MushroomWeatherColouredMesh = try G.forestPart(won, tier: tier)
            #expect(before.mesh == after.mesh)
            #expect(Self.positions(after.mesh, [.cap]).isEmpty)
            var lit: Int = 0
            for k in after.mesh.positions.indices where Self.decoded(after.mesh, k).material == .capOut {
                let c: Vec4 = after.colours[k]
                let colour: SIMD3<Double> = SIMD3(c.x, c.y, c.z)
                #expect(colour == MushroomWeatherPalette.cap)
                lit += 1
            }
            #expect(lit > 0)
            let beforeGlow: Mesh = try G.glowMesh(out, tier: tier)
            let afterGlow: Mesh = try G.glowMesh(won, tier: tier)
            #expect(beforeGlow == afterGlow)
            #expect(afterGlow.indices.count == tier.glowShells * (won.colonies.count + Self.podCount(won)) * 24 * 6)
        }
    }

    @Test func glowShellsPerTier() throws {
        for snap in Self.extremes() {
            let pods: Int = Self.podCount(snap)
            for tier in MushroomWeatherTier.all {
                let glow: MushroomWeatherColouredMesh = try G.glowPart(snap, tier: tier)
                #expect(glow.mesh.indices.count == tier.glowShells * (snap.colonies.count + pods) * G.glowSides * 6)
                #expect(glow.colours.count == glow.mesh.positions.count)
                if tier.index == 2 { #expect(glow.mesh.positions.isEmpty && glow.mesh.indices.isEmpty) }
                for uv in glow.mesh.uvs {
                    let d = MushroomWeatherShaders.GlowKind.decode(uv.x)
                    if d.kind == .cap {
                        #expect(d.factor == 1 || d.factor == MushroomWeatherShaders.capOutGlowFactor)
                    } else {
                        #expect(d.factor == 1)
                    }
                }
            }
        }
        #expect(MushroomWeatherTier.all.map(\.glowShells) == [2, 1, 0])
    }

    // MARK: Failures

    @Test func eachFailureKindIsMarkedOnAFailedPlayOnly() throws {
        let base: Snapshot = Self.extreme(rows: 8, columns: 9, colonies: 3, vents: 2, humidity: 500, budget: 6,
                                          required: 8)
        let s: Double = G.scale(rows: 8, columns: 9)
        let e: Double = MushroomWeatherShaders.quadExtent
        let failures: [MushroomWeatherFailure] = [.dried(colony: 1, cycle: 1),
                                                  .mold(cell: Cell(row: 0, column: 0), cycle: 1),
                                                  .unstable(colony: 2, run: 1)]
        for tier in MushroomWeatherTier.all {
            let clean: Mesh = try G.forestMesh(base, tier: tier)
            #expect(Self.brokenPositions(clean).isEmpty && Self.positions(clean, [.moldPatch]).isEmpty)
            for failure in failures {
                let predicted: Snapshot = Self.variant(base, failure: .some(failure), stage: .playing)
                let predictedMesh: Mesh = try G.forestMesh(predicted, tier: tier)
                #expect(predictedMesh == clean)
            }

            let dried: Snapshot = Self.variant(base, failure: .some(failures[0]), stage: .failed)
            let driedMesh: Mesh = try G.forestMesh(dried, tier: tier)
            let cap: SIMD3<Double> = G.capCentre(1, dried)
            let capBroken: [SIMD3<Double>] = Self.positions(driedMesh, [.cap, .capOut], broken: true)
            #expect(!capBroken.isEmpty)
            for p in capBroken {
                let r: Double = ((p.x - cap.x) * (p.x - cap.x) + (p.y - cap.y) * (p.y - cap.y)).squareRoot()
                #expect(r <= G.capRadius * s + 1e-9)
            }
            let ring: [SIMD3<Double>] = Self.positions(driedMesh, [.bandRingSolid, .bandRingDashed], broken: true)
            #expect(ring.count == 4)
            for p in ring { #expect(abs(abs(p.x - cap.x) - e * G.bandRadius * s) < 1e-9 && p.z == G.bandZ) }
            #expect(Self.brokenPositions(driedMesh).count == capBroken.count + 4)

            let mold: Snapshot = Self.variant(base, failure: .some(failures[1]), stage: .failed)
            let moldMesh: Mesh = try G.forestMesh(mold, tier: tier)
            let centre: SIMD3<Double> = G.cellCentre(Cell(row: 0, column: 0), mold, height: 0)
            let patch: [SIMD3<Double>] = Self.positions(moldMesh, [.moldPatch])
            #expect(patch.count == 4)
            for p in patch {
                #expect(abs(abs(p.x - centre.x) - e * G.markSide * s / 2) < 1e-9 && p.z == G.markZ)
            }
            #expect(Self.brokenPositions(moldMesh).isEmpty)

            let unstable: Snapshot = Self.variant(base, failure: .some(failures[2]), stage: .failed)
            let unstableMesh: Mesh = try G.forestMesh(unstable, tier: tier)
            let row: Double = G.gaugeY(2)
            let markers: [SIMD3<Double>] = Self.positions(unstableMesh, [.marker], broken: true)
            let runs: [SIMD3<Double>] = Self.positions(unstableMesh, [.runLit, .runUnlit], broken: true)
            #expect(markers.count == 4 && runs.count == 4 * unstable.requiredCycles)
            for p in markers + runs { #expect(abs(p.y - row) <= 0.03) }
            #expect(Self.brokenPositions(unstableMesh).count == markers.count + runs.count)
        }
    }

    // MARK: Backdrop and fallback

    @Test func backdropFillsTheViewAndCarriesItsGradient() throws {
        let snap: Snapshot = try Self.snapshot(Self.levels[0])
        let mesh: Mesh = try G.forestMesh(snap, tier: MushroomWeatherTier.of(2))
        let corners: [SIMD3<Double>] = Self.positions(mesh, [.backdrop])
        #expect(corners.count == 4)
        for aspect in [0.25, 0.4, 1.0, 2.5, 4.0] {
            let camera: MushroomWeatherCamera = G.camera(aspect: aspect)
            var xs: [Double] = []
            var ys: [Double] = []
            for corner in corners {
                guard let p = G.project(corner, camera: camera) else {
                    Issue.record("backdrop corner behind the eye")
                    continue
                }
                xs.append(p.x)
                ys.append(p.y)
            }
            #expect((xs.min() ?? 0) < 0 && (xs.max() ?? 0) > 1 && (ys.min() ?? 0) < 0 && (ys.max() ?? 0) > 1)
            let bottom: Double = G.backdropHeight(view: SIMD2(0.05, 0.95), camera: camera)
            let top: Double = G.backdropHeight(view: SIMD2(0.05, 0.05), camera: camera)
            #expect(bottom > 0 && bottom < top && top < 1)
            #expect(abs(G.backdropHeight(view: SIMD2(0.5, 0.5), camera: camera) - 0.5) < 1e-12)
        }
    }

    @Test func fallbackColoursFollowTheShaderBaseColours() throws {
        let snap: Snapshot = try Self.snapshot(Self.levels[5])
        for tier in MushroomWeatherTier.all {
            let part: MushroomWeatherColouredMesh = try G.forestPart(snap, tier: tier, wonLevel: false)
            #expect(part.colours.count == part.mesh.positions.count)
            let plain: Mesh = try G.forestMesh(snap, tier: tier)
            #expect(part.mesh == plain)
            for k in part.mesh.positions.indices {
                let d = Self.decoded(part.mesh, k)
                let c: Vec4 = part.colours[k]
                let colour: SIMD3<Double> = SIMD3(c.x, c.y, c.z)
                if d.material == .backdrop {
                    let h: Double = part.mesh.uvs[k].y
                    #expect(colour == MushroomWeatherShaders.backdropColour(height: h))
                } else {
                    let expected: SIMD3<Double> = MushroomWeatherShaders.baseColour(of: d.material, value: d.value,
                                                                                     broken: d.broken, won: 0)
                    let diff: SIMD3<Double> = colour - expected
                    #expect(abs(diff.x) + abs(diff.y) + abs(diff.z) < 1e-9, "\(d.material)")
                }
            }
        }
        #expect(G.colour(of: MushroomWeatherShaders.encode(.cap, value: 0.3)) == MushroomWeatherPalette.cap)
        #expect(G.colour(of: MushroomWeatherShaders.encode(.floor, broken: true)) == MushroomWeatherPalette.broken)
        #expect(G.colour(of: MushroomWeatherShaders.encode(.capOut), won: 1) == MushroomWeatherPalette.cap)
        #expect(G.moonBrightness(0) == 4.0 / 7 && G.moonBrightness(3) == 1 && G.filledTicks(2) == 3)
    }
}
