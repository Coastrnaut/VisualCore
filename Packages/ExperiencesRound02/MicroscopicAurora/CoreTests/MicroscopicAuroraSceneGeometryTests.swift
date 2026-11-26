// MicroscopicAuroraSceneGeometryTests — feature 483 (R02-G19-03) T-R02G1903-004 (FR-R02G1903-001, 002, 003, 004, 006;
// SC-R02G1903-001; clarifications Q1–Q4). The dish from snapshots: finite and bounded for extreme settings (radius 6
// and 11, 4 and 16 swimmers, swims of 120 and 480 ticks, swimmers at the rim and at the centre, budgets 1 and 24, all
// 576 cells lit); every vertex of the dish and glow meshes, every element and every reference point inside the view
// with a 5 % margin at 7 aspects over catalog levels 1, 21, 41, 61, 81 and seeded fixtures; the authored camera; the
// same positions at every tier (fronds, ribbons and capsules aside); ribbons through kernel positions only; gauges at
// 0, half and full; a won level in place; the glow empty at level-2 with its shells per tier; the paint order by kind;
// the well spirals turning like the kernel; each failure kind (exit, coherence, coverage, connectedness) marked.
// Feature 484 (R02-G19-04) T-R02G1904-002 adds the view orbit, the scrubber and the preview (see the extension below).
// Seed 2_483; explicit types, plain loops; no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import MicroscopicAuroraCore

struct MicroscopicAuroraSceneGeometryTests {
    typealias G = MicroscopicAuroraSceneGeometry
    typealias Snapshot = MicroscopicAuroraSceneSnapshot
    typealias Level = MicroscopicAuroraLevel
    typealias Play = MicroscopicAuroraPlay
    typealias Tier = MicroscopicAuroraTier
    typealias Cell = MicroscopicAuroraCell
    typealias Point = MicroscopicAuroraPoint
    typealias M = MicroscopicAuroraMaterial

    /// The feature's test seed.
    static let seed: UInt64 = 2_483

    /// The seven aspects checked.
    static let aspects: [Double] = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]

    /// Catalog levels 1, 21, 41, 61 and 81 as the generator makes them (each about 0.2 s, so cached).
    static let catalogLevels: [Level] = {
        let numbers: [Int] = [1, 21, 41, 61, 81]
        var levels: [Level] = []
        for entry in MicroscopicAuroraManifest.entries where numbers.contains(entry.number) {
            if let generated = try? MicroscopicAuroraGenerator.generate(entry, previous: nil) {
                levels.append(generated.level)
            }
        }
        return levels
    }()

    /// Seeded fixtures (levels with known winning actions).
    static let fixtures: [MicroscopicAuroraFixture] = MicroscopicAuroraFixture.all(count: 4, seed: seed)

    /// Swarm rules with a wide coherence radius.
    static let rules: MicroscopicAuroraSwarmRules = MicroscopicAuroraSwarmRules(
        neighbourRadius: 3, separationRadius: 1, coherenceRadius: 8, separationWeight: 2, alignmentWeight: 4,
        cohesionWeight: 4, maxAcceleration: 8, maxSpeed: 24)

    /// The usable cells of an enclosure of `radius`, row-major, at most `limit`.
    static func usableCells(radius: Int, limit: Int) -> [Cell] {
        var cells: [Cell] = []
        for row in 0..<24 {
            for column in 0..<24 where cells.count < limit {
                let cell: Cell = Cell(row: row, column: column)
                if Level.isUsable(cell, radius: radius) { cells.append(cell) }
            }
        }
        return cells
    }

    /// `count` swimmers bunched at the rim of `radius` (angles within ±0.3 rad of +x) or around the centre.
    static func swimmers(count: Int, radius: Int, atRim: Bool) -> [MicroscopicAuroraSwimmer] {
        var list: [MicroscopicAuroraSwimmer] = []
        let r: Double = Double(radius * 256)
        for k in 0..<count {
            let f: Double = count > 1 ? Double(k) / Double(count - 1) : 0.5
            let p: Point
            if atRim {
                let angle: Double = -0.3 + 0.6 * f
                p = Point(x: 3072 + Int((r * cos(angle)).rounded(.towardZero)),
                          y: 3072 + Int((r * sin(angle)).rounded(.towardZero)))
            } else {
                p = Point(x: 3072 - 300 + Int(600 * f), y: 3072 + (k % 2 == 0 ? -100 : 100))
            }
            list.append(MicroscopicAuroraSwimmer(position: p, velocity: Point(x: 0, y: 4)))
        }
        return list
    }

    /// A level of the given values without the "already won" rule (every other rule checked).
    static func level(_ id: String, radius: Int, length: Int, swimmers: [MicroscopicAuroraSwimmer],
                      stencil: [Cell], wells: [MicroscopicAuroraWell?] = [nil, nil, nil],
                      budget: Int, sites: [Cell]? = nil) throws -> Level {
        try Level(id: id, seed: seed, difficulty: 1, radius: radius, length: length, rules: rules,
                  swimmers: swimmers, stencil: stencil, threshold: 1, coverage: 500, coherence: 2, wells: wells,
                  budget: budget, tutorial: false, sites: sites, refusingAWin: false)
    }

    /// The extreme levels: radius 6 and 11 × 4 and 16 swimmers × 120 and 480 ticks × rim and centre, budget 1 with 4
    /// stencil cells or 24 with up to 120, a strength-4 well and three sites.
    static let extremeLevels: [Level] = {
        var levels: [Level] = []
        for radius in [6, 11] {
            let cells: [Cell] = usableCells(radius: radius, limit: 120)
            let centre: [Cell] = [Cell(row: 11, column: 11), Cell(row: 11, column: 12), Cell(row: 12, column: 11),
                                  Cell(row: 12, column: 12)]
            let sites: [Cell] = [Cell(row: 10, column: 10), Cell(row: 13, column: 13), Cell(row: 10, column: 13)]
            let well: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: sites[0], strength: 4,
                                                                    sense: .counterclockwise)
            for count in [4, 16] {
                for length in [120, 480] {
                    for atRim in [true, false] {
                        let big: Bool = count == 16
                        let id: String = "extreme-\(radius)-\(count)-\(length)-\(atRim ? "rim" : "centre")"
                        if let level = try? level(id, radius: radius, length: length,
                                                  swimmers: swimmers(count: count, radius: radius, atRim: atRim),
                                                  stencil: big ? cells : centre,
                                                  wells: big ? [well, nil, nil] : [nil, nil, nil],
                                                  budget: big ? 24 : 1, sites: big ? sites : nil) {
                            levels.append(level)
                        }
                    }
                }
            }
        }
        return levels
    }()

    /// The snapshot of a fresh play of `level` at `tick`.
    static func snapshot(_ level: Level, tick: Int = 0) -> Snapshot {
        Snapshot(play: Play(level: level), shownTick: tick, levelNumber: 1, time: 0)
    }

    /// A copy of `s` with the given values replaced.
    static func copy(_ s: Snapshot, shownTick: Int? = nil, litStencil: [Cell]? = nil, stray: [Cell]? = nil,
                     coverage: Int? = nil, coherence: Int? = nil, failure: MicroscopicAuroraFailure?? = nil,
                     stage: MicroscopicAuroraStage? = nil, actionsLeft: Int? = nil, budget: Int? = nil) -> Snapshot {
        Snapshot(radius: s.radius, positions: s.positions, velocities: s.velocities, ticksSwum: s.ticksSwum,
                 shownTick: shownTick ?? s.shownTick, density: s.density, litStencil: litStencil ?? s.litStencil,
                 stray: stray ?? s.stray, stencil: s.stencil, sites: s.sites, wells: s.wells,
                 coverage: coverage ?? s.coverage, requiredCoverage: s.requiredCoverage,
                 coherence: coherence ?? s.coherence, requiredCoherence: s.requiredCoherence, swarm: s.swarm,
                 coherenceRadius: s.coherenceRadius, failure: failure ?? s.failure, stage: stage ?? s.stage,
                 actionsLeft: actionsLeft ?? s.actionsLeft, budget: budget ?? s.budget, levelNumber: s.levelNumber,
                 time: s.time)
    }

    /// The position of vertex `index` of `mesh`.
    static func point(_ mesh: Mesh, _ index: Int) -> SIMD3<Double> {
        SIMD3(mesh.positions[index].x, mesh.positions[index].y, mesh.positions[index].z)
    }

    /// The material of vertex `index` of `mesh`, as the shader decodes it.
    static func material(_ mesh: Mesh, _ index: Int) -> M { M.decode(Double(mesh.uvs[index].x)) }

    /// The vertex indices of `mesh` with material `material`.
    static func vertices(_ mesh: Mesh, _ material: M) -> [Int] {
        var found: [Int] = []
        for index in mesh.uvs.indices where Self.material(mesh, index) == material { found.append(index) }
        return found
    }

    /// The triangle count of `mesh` whose first vertex has material `material`.
    static func triangles(_ mesh: Mesh, _ material: M) -> Int {
        var count: Int = 0
        for t in stride(from: 0, to: mesh.indices.count, by: 3) where Self.material(mesh, Int(mesh.indices[t]))
            == material {
            count += 1
        }
        return count
    }

    /// The positions of every vertex of `mesh` whose material is not in `excluded`, in order.
    static func positions(_ mesh: Mesh, except excluded: [M]) -> [SIMD3<Double>] {
        var list: [SIMD3<Double>] = []
        for index in mesh.positions.indices where !excluded.contains(material(mesh, index)) {
            list.append(point(mesh, index))
        }
        return list
    }

    /// The planar length of `v`.
    static func length(_ v: SIMD3<Double>) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }

    /// Whether `q` lies inside the view with a 5 % margin.
    static func inside(_ q: SIMD2<Double>?) -> Bool {
        guard let p = q else { return false }
        return p.x >= 0.05 && p.x <= 0.95 && p.y >= 0.05 && p.y <= 0.95
    }

    /// The vertices of `mesh` with material `material` within `radius` of `centre`.
    static func near(_ mesh: Mesh, _ material: M, _ centre: SIMD3<Double>, _ radius: Double) -> Int {
        var count: Int = 0
        for index in vertices(mesh, material) where length(point(mesh, index) - centre) <= radius { count += 1 }
        return count
    }

    /// The number of vertices of `mesh` that are not finite or lie outside the authored box (backdrop aside).
    static func badVertices(_ mesh: Mesh) -> Int {
        var bad: Int = 0
        for index in mesh.positions.indices {
            let p: SIMD3<Double> = point(mesh, index)
            let n: Vec3 = mesh.normals[index]
            let uv: Vec2 = mesh.uvs[index]
            if !(p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite && n.y.isFinite && n.z.isFinite
                 && uv.x.isFinite && uv.y.isFinite) {
                bad += 1
            } else if material(mesh, index) != .backdrop
                        && !(abs(p.x) <= 1.0 && p.y >= -1.35 && p.y <= 1.0 && abs(p.z) <= 0.02) {
                bad += 1
            }
        }
        return bad
    }

    /// The winning snapshot of `fixture` at `tick` and the one just before the play.
    static func won(_ fixture: MicroscopicAuroraFixture, tick: Int) throws -> (before: Snapshot, won: Snapshot) {
        var play: Play = Play(level: fixture.level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in fixture.actions where action != .play { try play.apply(action, expecting: play.fingerprint) }
        let before: Snapshot = Snapshot(play: play, shownTick: tick, levelNumber: 1, time: 0)
        try play.apply(.play, expecting: play.fingerprint)
        return (before: before, won: Snapshot(play: play, shownTick: tick, levelNumber: 1, time: 0))
    }

    // MARK: Tests

    @Test func finiteAndBoundedForExtremeSettings() throws {
        let levels: [Level] = Self.extremeLevels
        #expect(levels.count == 16)
        var exits: Int = 0
        var full: Int = 0
        for level in levels {
            let base: Snapshot = Self.snapshot(level)
            if case .exit = base.failure { exits += 1 }
            if base.ticksSwum == 480 { full += 1 }
            for tick in [0, base.ticksSwum / 2, base.ticksSwum] {
                let snap: Snapshot = Self.copy(base, shownTick: tick)
                for tier in Tier.all {
                    let mesh: Mesh = try G.dishMesh(snap, tier: tier)
                    #expect(mesh.triangleCount > 0 && mesh.triangleCount < 60_000, "\(mesh.triangleCount)")
                    let glow: Mesh = try G.glowMesh(snap, tier: tier)
                    #expect(Self.badVertices(mesh) == 0 && Self.badVertices(glow) == 0, "\(level.id) \(tier.name)")
                    let reach: Double = G.rimRadius(snap) + G.frondReach
                    var far: Int = 0
                    for index in Self.vertices(mesh, .frond) where Self.length(Self.point(mesh, index)) > reach {
                        far += 1
                    }
                    #expect(far == 0)
                }
            }
        }
        #expect(exits > 0 && full > 0, "\(exits) \(full)")
        // Every one of the 576 cells lit (presentation variant), at both radii.
        for level in [levels[0], levels[levels.count - 1]] {
            var everything: [Cell] = []
            let stencil: Set<Cell> = Set(level.stencil)
            for row in 0..<24 {
                for column in 0..<24 where !stencil.contains(Cell(row: row, column: column)) {
                    everything.append(Cell(row: row, column: column))
                }
            }
            let snap: Snapshot = Self.copy(Self.snapshot(level), litStencil: level.stencil, stray: everything)
            #expect(G.litCells(snap).count == 576)
            let mesh: Mesh = try G.dishMesh(snap, tier: .of(0))
            #expect(Self.badVertices(mesh) == 0)
            #expect(Self.triangles(mesh, .litCell) + Self.triangles(mesh, .strayCell) == 2 * 576)
            #expect(Self.triangles(mesh, .litCell) == 2 * level.stencil.count)
        }
    }

    @Test func everyElementInsideTheViewAtSevenAspects() throws {
        var levels: [Level] = Self.catalogLevels
        #expect(levels.count == 5)
        for fixture in Self.fixtures { levels.append(fixture.level) }
        for level in levels {
            let base: Snapshot = Self.snapshot(level)
            for tick in [0, base.ticksSwum / 2, base.ticksSwum] {
                let snap: Snapshot = Self.copy(base, shownTick: tick)
                let mesh: Mesh = try G.dishMesh(snap, tier: .of(0))
                let glow: Mesh = try G.glowMesh(snap, tier: .of(0))
                var points: [SIMD3<Double>] = Self.positions(mesh, except: [.backdrop])
                for index in glow.positions.indices { points.append(Self.point(glow, index)) }
                for element in G.paintOrder(snap) where element.part != .backdrop { points.append(element.centre) }
                for reference in G.referencePoints(snap) { points.append(reference.centre) }
                for aspect in Self.aspects {
                    let camera: MicroscopicAuroraCamera = G.camera(aspect: aspect)
                    var outside: Int = 0
                    for p in points where !Self.inside(G.project(p, camera: camera)) { outside += 1 }
                    #expect(outside == 0, "\(level.id) tick \(tick) aspect \(aspect)")
                }
            }
        }
    }

    @Test func backdropFillsTheViewAndCameraIsAuthored() throws {
        let half: SIMD2<Double> = G.backdropHalf()
        for aspect in Self.aspects {
            let camera: MicroscopicAuroraCamera = G.camera(aspect: aspect)
            let low: SIMD2<Double>? = G.project(SIMD3(G.lookAt.x - half.x, G.lookAt.y - half.y, G.backdropDepth),
                                                camera: camera)
            let high: SIMD2<Double>? = G.project(SIMD3(G.lookAt.x + half.x, G.lookAt.y + half.y, G.backdropDepth),
                                                 camera: camera)
            #expect(low != nil && high != nil)
            if let l = low, let h = high { #expect(l.x < 0 && l.y > 1 && h.x > 1 && h.y < 0, "aspect \(aspect)") }
            let top: Double = G.backdropHeight(view: SIMD2(0.5, 0), camera: camera)
            let bottom: Double = G.backdropHeight(view: SIMD2(0.5, 1), camera: camera)
            #expect(top > bottom && top < 1 && bottom > 0, "aspect \(aspect)")
        }
        let camera: MicroscopicAuroraCamera = G.camera(aspect: 1.5)
        #expect(camera.eye == SIMD3(0, -0.15, 3.4) && camera.target == SIMD3(0, -0.15, 0))
        #expect(camera.fovY > 0 && camera.fovY < Double.pi && camera.aspect == 1.5)
        #expect(G.camera(aspect: .nan).aspect == 1 && G.camera(aspect: 100).aspect == 10)
        let centre: SIMD2<Double>? = G.project(camera.target, camera: camera)
        #expect(centre != nil && abs(centre!.x - 0.5) < 1e-9 && abs(centre!.y - 0.5) < 1e-9)
        #expect(G.project(SIMD3(0, -0.15, 6), camera: camera) == nil)
        #expect(G.project(SIMD3(.nan, 0, 0), camera: camera) == nil)
        for aspect in [0.4, 2.5] {
            let fitted: MicroscopicAuroraCamera = G.camera(aspect: aspect)
            for index in 0..<8 {
                let q: SIMD2<Double>? = G.project(G.corner(index), camera: fitted)
                #expect(q != nil && q!.x >= 0.06 - 1e-9 && q!.x <= 0.94 + 1e-9 && q!.y >= 0.06 - 1e-9
                        && q!.y <= 0.94 + 1e-9, "aspect \(aspect) corner \(index)")
            }
        }
    }

    @Test func worldScaleAndReferencePoints() throws {
        #expect(G.scale == 0.9 / 2816)
        #expect(G.world(Point(x: 3072 + 2816, y: 3072 - 2816), depth: -1) == SIMD3(0.9, 0.9, -1))
        #expect(G.world(Point(x: 3072, y: 3072), depth: 0) == SIMD3(0, 0, 0))
        let level: Level = Self.extremeLevels[Self.extremeLevels.count - 1]
        let snap: Snapshot = Self.snapshot(level, tick: 7)
        #expect(level.radius == 11 && abs(G.rimRadius(snap) - 0.9) < 1e-12)
        #expect(G.dishCentre() == SIMD3(0, 0, 0) && G.rimPoint(snap) == SIMD3(G.rimRadius(snap), 0, 0))
        #expect(G.swimmerCentre(3, snap) == G.world(snap.positions[3][snap.shownTick], depth: 0))
        #expect(G.siteCentre(0, snap) == G.cellCentre(snap.sites[0]))
        #expect(G.coverageTrackCentre() == SIMD3(0, -1.08, 0) && G.coherenceTrackCentre() == SIMD3(0, -1.15, 0))
        #expect(abs(G.actionsBar(0, snap).x - (-0.9 + 0.5 * 1.8 / 24)) < 1e-12 && G.actionsBar(0, snap).y == -1.25)
        var kinds: [MicroscopicAuroraReferencePoint.Kind] = []
        for reference in G.referencePoints(snap) where reference.kind != .swimmer { kinds.append(reference.kind) }
        #expect(kinds == [.dishCentre, .rimPoint, .site, .coverageTrack, .actionsBar])
        var swimmers: Int = 0
        for reference in G.referencePoints(snap) where reference.kind == .swimmer { swimmers += 1 }
        #expect(swimmers == 16)
        // A still swimmer keeps +x; a moving one points along its velocity with the y flip.
        let still: Snapshot = Snapshot(radius: 11, positions: [[Point(x: 3072, y: 3072)]],
                                       velocities: [[Point(x: 0, y: 0)]], ticksSwum: 0, shownTick: 0, density: [],
                                       litStencil: [], stray: [], stencil: [], sites: [], wells: [nil, nil, nil],
                                       coverage: 0, requiredCoverage: 500, coherence: 1, requiredCoherence: 2,
                                       swarm: 1, coherenceRadius: 2, failure: nil, stage: .playing, actionsLeft: 1,
                                       budget: 1, levelNumber: 1, time: 0)
        #expect(G.swimmerAxis(0, still) == SIMD3(1, 0, 0))
        #expect(G.swimmerAxis(0, Self.snapshot(level)) == SIMD3(0, -1, 0))   // velocity (0, 4): down the dish
    }

    @Test func samePositionsAtEveryTier() throws {
        var levels: [Level] = []
        for fixture in Self.fixtures { levels.append(fixture.level) }
        levels.append(Self.catalogLevels[0])
        levels.append(Self.extremeLevels[Self.extremeLevels.count - 1])
        let detail: [M] = [.frond, .ribbon, .swimmer, .swimmerTail, .broken]
        for level in levels {
            let base: Snapshot = Self.snapshot(level)
            let snap: Snapshot = Self.copy(base, shownTick: base.ticksSwum / 2)
            let reference: [SIMD3<Double>] = Self.positions(try G.dishMesh(snap, tier: .of(0)), except: detail)
            let order: [MicroscopicAuroraElement] = G.paintOrder(snap)
            for tier in Tier.all {
                let mesh: Mesh = try G.dishMesh(snap, tier: tier)
                #expect(Self.positions(mesh, except: detail) == reference, "\(level.id) \(tier.name)")
                #expect(G.paintOrder(snap) == order)
                #expect(Self.vertices(mesh, .frond).isEmpty == !tier.fronds)
                // Body triangles per capsule: flat, two side quads and the head's half disc; otherwise two per quad
                // of the bands after the tail tip, less the degenerate half of the head's pole band.
                let s: Int = tier.capsuleSegments
                let expected: Int = tier.flatCapsules ? 4 + G.flatEndSegments : 2 * s * (s - max(1, s / 5))
                let body: Int = Self.triangles(mesh, .swimmer)
                let swarm: Int = snap.positions.count - G.brokenSwimmers(snap).count
                let poles: Int = tier.flatCapsules ? 0 : s
                #expect(body == swarm * (expected - poles), "\(level.id) \(tier.name) \(body)")
                #expect(Self.triangles(mesh, .swimmerTail) > 0 || swarm == 0)
            }
        }
    }

    @Test func ribbonsThroughKernelPositionsOnly() throws {
        var levels: [Level] = Self.catalogLevels
        levels.append(Self.extremeLevels[Self.extremeLevels.count - 1])
        for level in levels {
            let base: Snapshot = Self.snapshot(level)
            for tick in [0, 10, base.ticksSwum] {
                let snap: Snapshot = Self.copy(base, shownTick: tick)
                for tier in Tier.all {
                    var kernel: [SIMD3<Double>] = []
                    for i in snap.positions.indices {
                        let ribbon: [SIMD3<Double>] = G.ribbon(i, snap, tier: tier)
                        let first: Int = max(0, snap.shownTick - tier.ribbonTicks)
                        #expect(ribbon.count == snap.shownTick - first + 1)
                        var off: Int = 0
                        for (k, p) in ribbon.enumerated() where p != G.world(snap.positions[i][first + k], depth: 0) {
                            off += 1
                        }
                        #expect(off == 0 && ribbon.last == G.swimmerCentre(i, snap), "\(level.id) \(tier.name)")
                        kernel.append(contentsOf: ribbon)
                    }
                    guard tick == base.ticksSwum else { continue }
                    let mesh: Mesh = try G.dishMesh(snap, tier: tier)
                    let ribbonVertices: [Int] = Self.vertices(mesh, .ribbon)
                    var stray: Int = 0
                    var heads: Int = 0
                    for index in ribbonVertices {
                        let p: SIMD3<Double> = Self.point(mesh, index)
                        var onKernel: Bool = false
                        for q in kernel where abs(Self.length(p - q) - G.ribbonWidth / 2) < 1e-12 {
                            onKernel = true
                            break
                        }
                        if !onKernel { stray += 1 }
                        let along: Double = MicroscopicAuroraShaders.ribbonAlong(code: Double(mesh.uvs[index].x))
                        if abs(along - 1) < 1e-6 { heads += 1 }
                        #expect(along >= 0 && along <= 1)
                    }
                    #expect(stray == 0 && (heads > 0 || ribbonVertices.isEmpty), "\(level.id) \(tier.name)")
                }
            }
        }
    }

    @Test func gaugesAtZeroHalfAndFull() throws {
        #expect(G.gaugeX(0, top: 1000) == -0.9 && abs(G.gaugeX(500, top: 1000)) < 1e-12)
        #expect(G.gaugeX(1000, top: 1000) == 0.9 && G.gaugeX(-5, top: 1000) == -0.9 && G.gaugeX(2000, top: 10) == 0.9)
        let base: Snapshot = Self.snapshot(Self.extremeLevels[Self.extremeLevels.count - 1])
        let n: Int = base.swarm
        #expect(n == 16)
        let readings: [(coverage: Int, coherence: Int, x: Double)] = [(0, 0, -0.9), (500, n / 2, 0), (1000, n, 0.9)]
        for reading in readings {
            let snap: Snapshot = Self.copy(base, coverage: reading.coverage, coherence: reading.coherence,
                                           failure: .some(nil))
            #expect(abs(G.coverageMark(snap).x - reading.x) < 1e-12 && G.coverageMark(snap).y == -1.08)
            #expect(abs(G.coherenceMark(snap).x - reading.x) < 1e-12 && G.coherenceMark(snap).y == -1.15)
            let mesh: Mesh = try G.dishMesh(snap, tier: .of(1))
            let coverageMet: Bool = reading.coverage >= snap.requiredCoverage
            let coherenceMet: Bool = reading.coherence >= snap.requiredCoherence
            let met: Int = (coverageMet ? 1 : 0) + (coherenceMet ? 1 : 0)
            #expect(Self.vertices(mesh, .markMet).count == 4 * met)
            #expect(Self.vertices(mesh, .markUnmet).count == 4 * (2 - met))
            #expect(Self.near(mesh, coverageMet ? .markMet : .markUnmet, G.coverageMark(snap),
                              0.025 * 1.5 + 1e-12) == 4)
        }
        // The requirement ticks.
        let mesh: Mesh = try G.dishMesh(base, tier: .of(2))
        #expect(Self.triangles(mesh, .requirementTick) == 4 && Self.triangles(mesh, .gaugeTrack) == 4)
        let tickX: Double = G.gaugeX(base.requiredCoverage, top: 1000)
        #expect(Self.near(mesh, .requirementTick, SIMD3(tickX, -1.08, 0), 0.026) == 4)
        // Actions bars lit for 0, half and all of 24 left.
        for left in [0, 12, 24] {
            let snap: Snapshot = Self.copy(base, actionsLeft: left)
            let bars: Mesh = try G.dishMesh(snap, tier: .of(0))
            #expect(Self.triangles(bars, .barLit) == 4 * left && Self.triangles(bars, .barUnlit) == 4 * (24 - left))
            for b in [0, 11, 12, 23] {
                let material: M = b < left ? .barLit : .barUnlit
                #expect(Self.near(bars, material, G.actionsBar(b, snap), 0) == 1, "bar \(b) left \(left)")
            }
        }
        // Budgets 1 and 24: each bar 1.8 / budget wide with a fifth as gap.
        for budget in [1, 24] {
            let snap: Snapshot = Self.copy(base, actionsLeft: budget, budget: budget)
            let slot: Double = 1.8 / Double(budget)
            #expect(abs(G.actionsSlot(snap) - slot) < 1e-12)
            let bars: Mesh = try G.dishMesh(snap, tier: .of(2))
            var lowest: Double = 1
            var highest: Double = -1
            for index in Self.vertices(bars, .barLit) {
                lowest = min(lowest, Self.point(bars, index).x)
                highest = max(highest, Self.point(bars, index).x)
            }
            #expect(abs(lowest - (-0.9 + 0.1 * slot)) < 1e-12 && abs(highest - (0.9 - 0.1 * slot)) < 1e-12)
        }
    }

    @Test func wonLevelInPlace() throws {
        let lit: Vec4 = Vec4(MicroscopicAuroraPalette.lit.x, MicroscopicAuroraPalette.lit.y,
                             MicroscopicAuroraPalette.lit.z, 1)
        for fixture in Self.fixtures {
            let pair: (before: Snapshot, won: Snapshot) = try Self.won(fixture, tick: 5)
            #expect(pair.won.isWon && pair.won.failure == nil)
            for tier in Tier.all {
                let shown: MicroscopicAuroraColouredMesh = try G.dishPart(pair.won, tier: tier)
                let plain: MicroscopicAuroraColouredMesh = try G.dishPart(pair.won, tier: tier, wonLevel: false)
                let before: Mesh = try G.dishMesh(pair.before, tier: tier)
                #expect(shown.mesh.positions == plain.mesh.positions && shown.mesh.indices == plain.mesh.indices)
                #expect(shown.mesh.positions == before.positions && shown.mesh.uvs.count == before.uvs.count)
                #expect(Self.vertices(shown.mesh, .markUnmet).isEmpty && Self.vertices(shown.mesh, .broken).isEmpty)
                #expect(Self.vertices(shown.mesh, .markMet).count == 8)
                let outlines: [Int] = Self.vertices(shown.mesh, .stencil)
                #expect(!outlines.isEmpty)
                var wrong: Int = 0
                for index in outlines where shown.colours[index] != lit { wrong += 1 }
                for index in Self.vertices(plain.mesh, .stencil) where plain.colours[index] == lit { wrong += 1 }
                #expect(wrong == 0 && shown.colours.count == shown.mesh.positions.count)
            }
        }
    }

    @Test func glowEmptyAtLevelTwoAndShellsPerTier() throws {
        var levels: [Level] = []
        for fixture in Self.fixtures.prefix(2) { levels.append(fixture.level) }
        levels.append(Self.catalogLevels[0])
        for level in levels {
            let base: Snapshot = Self.snapshot(level)
            let snap: Snapshot = Self.copy(base, shownTick: base.ticksSwum)
            #expect((try G.glowMesh(snap, tier: .of(2))).triangleCount == 0)
            #expect((try G.glowPart(snap, tier: .of(2))).colours.isEmpty)
            for tier in Tier.all where tier.glowShells > 0 {
                let glow: Mesh = try G.glowMesh(snap, tier: tier)
                var lifts: Set<Double> = []
                var swimmerTriangles: Int = 0
                for index in glow.positions.indices { lifts.insert(glow.positions[index].z) }
                for t in stride(from: 0, to: glow.indices.count, by: 3) {
                    let decoded: (kind: MicroscopicAuroraShaders.GlowKind, factor: Double) =
                        MicroscopicAuroraShaders.GlowKind.decode(Double(glow.uvs[Int(glow.indices[t])].x))
                    if decoded.kind == .swimmer { swimmerTriangles += 1 }
                }
                #expect(lifts.count == tier.glowShells, "\(level.id) \(tier.name)")
                #expect(swimmerTriangles == tier.glowShells * snap.swarm * 2 * G.glowSides)
                #expect(glow.triangleCount > swimmerTriangles)
                for index in glow.uvs.indices { #expect(glow.uvs[index].y == 0 || glow.uvs[index].y == 1) }
            }
        }
    }

    @Test func paintOrderByKind() throws {
        let level: Level = Self.extremeLevels[Self.extremeLevels.count - 1]
        let base: Snapshot = Self.snapshot(level)
        let snap: Snapshot = Self.copy(base, shownTick: base.ticksSwum / 2)
        let order: [MicroscopicAuroraElement] = G.paintOrder(snap)
        var sorted: Int = 0
        for k in 1..<order.count where !MicroscopicAuroraElement.paintsBefore(order[k], order[k - 1]) { sorted += 1 }
        #expect(sorted == order.count - 1)
        #expect(order.first?.part == .backdrop && order.last?.part == .bar)
        let mesh: Mesh = try G.dishMesh(snap, tier: .of(0))
        var sequence: [M] = [.backdrop, .field, .frond, .rim, .stencil]
        if !G.litCells(snap).isEmpty { sequence.append(.litCell) }
        sequence.append(contentsOf: [.siteRing, .wellSpiral, .wellArrow, .ribbon, .swimmer, .gaugeTrack, .barLit])
        var firsts: [Int] = []
        for material in sequence {
            var first: Int = -1
            for t in stride(from: 0, to: mesh.indices.count, by: 3)
            where Self.material(mesh, Int(mesh.indices[t])) == material {
                first = t
                break
            }
            firsts.append(first)
        }
        #expect(!firsts.contains(-1) && firsts == firsts.sorted(), "\(firsts)")
        #expect(Self.triangles(mesh, .rim) == 2 * G.rimSegments)
        #expect(Self.triangles(mesh, .siteRing) == 2 * G.siteSegments * snap.sites.count)
        #expect(Self.triangles(mesh, .stencil) == 8 * snap.stencil.count)
        #expect(Self.triangles(mesh, .frond) == 2 * G.frondCount * 7)
    }

    @Test func wellSpiralsTurnLikeTheKernel() throws {
        let still: MicroscopicAuroraSwarmRules = MicroscopicAuroraSwarmRules(
            neighbourRadius: 2, separationRadius: 1, coherenceRadius: 2, separationWeight: 0, alignmentWeight: 0,
            cohesionWeight: 0, maxAcceleration: 16, maxSpeed: 48)
        let cell: Cell = Cell(row: 9, column: 14)
        for sense in MicroscopicAuroraSense.allCases {
            for strength in 1...4 {
                let well: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: cell, strength: strength, sense: sense)
                let points: [SIMD3<Double>] = G.spiralPoints(well)
                #expect(points.count == 12 * (strength + 1) + 1)
                let centre: SIMD3<Double> = G.cellCentre(cell)
                let unit: Double = G.cellSide
                #expect(abs(Self.length(points[points.count - 1] - centre) - 0.45 * unit) < 1e-12)
                let arrow = G.arrowhead(well)
                let r: SIMD3<Double> = points[points.count - 1] - centre
                let t: SIMD3<Double> = arrow.tip - points[points.count - 1]
                let turn: Double = r.x * t.y - r.y * t.x
                // The kernel: a resting swimmer one cell to the right of the well turns this way.
                let swimmer: MicroscopicAuroraSwimmer = MicroscopicAuroraSwimmer(
                    position: Point(x: cell.centre.x + 256, y: cell.centre.y), velocity: Point(x: 0, y: 0))
                let moved: [MicroscopicAuroraSwimmer] = MicroscopicAuroraDish.step([swimmer], wells: [well],
                                                                                    rules: still)
                let v: SIMD3<Double> = SIMD3(Double(moved[0].velocity.x), -Double(moved[0].velocity.y), 0)
                let kernelTurn: Double = 1 * v.y - 0 * v.x
                #expect(kernelTurn != 0 && (turn > 0) == (kernelTurn > 0), "\(sense) \(strength)")
                #expect((turn > 0) == (sense == .clockwise))
            }
        }
        let snap: Snapshot = Self.snapshot(Self.extremeLevels[Self.extremeLevels.count - 1])
        let mesh: Mesh = try G.dishMesh(snap, tier: .of(2))
        #expect(Self.triangles(mesh, .wellSpiral) == 2 * 12 * 5 && Self.triangles(mesh, .wellArrow) == 1)
    }

    @Test func eachFailureKindMarked() throws {
        // A real exit from a play: the escaping swimmer and a mark across the rim where it left.
        var exitSnapshot: Snapshot?
        for level in Self.extremeLevels where exitSnapshot == nil {
            let snap: Snapshot = Self.snapshot(level)
            if case .exit = snap.failure { exitSnapshot = Self.copy(snap, shownTick: snap.ticksSwum) }
        }
        let exit: Snapshot = try #require(exitSnapshot)
        guard case .exit(let escaping, _) = exit.failure else { return }
        let exitMesh: Mesh = try G.dishMesh(exit, tier: .of(0))
        let direction: SIMD3<Double> = try #require(G.exitDirection(exit))
        let mark: SIMD3<Double> = direction * G.rimRadius(exit)
        let across: SIMD3<Double> = SIMD3(direction.y, -direction.x, 0) * (G.exitMarkWidth / 2)
        var corners: Int = 0
        for index in Self.vertices(exitMesh, .broken) {
            let p: SIMD3<Double> = Self.point(exitMesh, index)
            for reach in [-G.exitMarkReach, G.exitMarkReach] {
                for side in [-1.0, 1.0] where Self.length(p - (mark + direction * reach + across * side)) < 1e-12 {
                    corners += 1
                }
            }
        }
        #expect(corners == 4)
        #expect(Self.near(exitMesh, .broken, G.swimmerCentre(escaping, exit), G.capsuleLength) > 4)
        #expect(G.brokenSwimmers(exit) == [escaping])
        var kinds: [String] = ["exit"]
        // A coherence failure: three linked swimmers and one far away (κ = 2 cells).
        let positions: [[Point]] = [[Point(x: 3000, y: 3000)], [Point(x: 3200, y: 3000)], [Point(x: 3100, y: 3200)],
                                    [Point(x: 4500, y: 3000)]]
        let velocities: [[Point]] = [[Point(x: 1, y: 0)], [Point(x: 1, y: 0)], [Point(x: 1, y: 0)],
                                     [Point(x: 1, y: 0)]]
        let base: Snapshot = Self.snapshot(Self.extremeLevels[Self.extremeLevels.count - 1])
        let split: Snapshot = Snapshot(radius: 11, positions: positions, velocities: velocities, ticksSwum: 0,
                                       shownTick: 0, density: base.density, litStencil: [], stray: [],
                                       stencil: base.stencil, sites: [], wells: [nil, nil, nil], coverage: 0,
                                       requiredCoverage: 500, coherence: 3, requiredCoherence: 4, swarm: 4,
                                       coherenceRadius: 2, failure: .coherence(tick: 0, group: 3), stage: .failed,
                                       actionsLeft: 1, budget: 1, levelNumber: 1, time: 0)
        #expect(G.largestGroup(split, tick: 0) == [0, 1, 2] && G.brokenSwimmers(split) == [3])
        #expect(MicroscopicAuroraDish.coherence([MicroscopicAuroraSwimmer(position: positions[0][0],
                                                                          velocity: velocities[0][0]),
                                                 MicroscopicAuroraSwimmer(position: positions[1][0],
                                                                          velocity: velocities[1][0]),
                                                 MicroscopicAuroraSwimmer(position: positions[2][0],
                                                                          velocity: velocities[2][0]),
                                                 MicroscopicAuroraSwimmer(position: positions[3][0],
                                                                          velocity: velocities[3][0])],
                                                radius: 2) == 3)
        for tier in Tier.all {
            let mesh: Mesh = try G.dishMesh(split, tier: tier)
            #expect(Self.near(mesh, .broken, G.swimmerCentre(3, split), G.capsuleLength) > 4)
            #expect(Self.near(mesh, .broken, G.swimmerCentre(0, split), G.capsuleLength) == 0)
            #expect(Self.triangles(mesh, .swimmer) > 0)
        }
        kinds.append("coherence")
        // A coverage failure: the unlit stencil outlines broken, the lit ones not.
        let litHalf: [Cell] = Array(base.stencil.prefix(base.stencil.count / 2))
        let coverage: Snapshot = Self.copy(base, litStencil: litHalf, failure: .some(.coverage(lit: litHalf.count,
                                                                                               needed: 100)))
        let coverageMesh: Mesh = try G.dishMesh(coverage, tier: .of(1))
        let unlit: Int = base.stencil.count - litHalf.count
        #expect(G.brokenOutlines(coverage).count == unlit)
        #expect(Self.triangles(coverageMesh, .broken) == 8 * unlit)
        #expect(Self.triangles(coverageMesh, .stencil) == 8 * litHalf.count)
        kinds.append("coverage")
        // A connectedness failure: the named cell's outline broken.
        let named: Cell = base.stencil[base.stencil.count - 1]
        let joined: Snapshot = Self.copy(base, litStencil: base.stencil,
                                         failure: .some(.connectedness(cell: named)))
        let joinedMesh: Mesh = try G.dishMesh(joined, tier: .of(2))
        #expect(Self.triangles(joinedMesh, .broken) == 8)
        let brokenVertices: Int = Self.vertices(joinedMesh, .broken).count
        #expect(brokenVertices >= 12 && Self.near(joinedMesh, .broken, G.cellCentre(named), G.cellSide)
                == brokenVertices)
        #expect(G.namedCell(joined) == named)
        kinds.append("connectedness")
        #expect(kinds == ["exit", "coherence", "coverage", "connectedness"])
        // A won fixture shows no broken colour.
        let pair: (before: Snapshot, won: Snapshot) = try Self.won(Self.fixtures[0], tick: 0)
        #expect(Self.vertices(try G.dishMesh(pair.won, tier: .of(0)), .broken).isEmpty)
    }
}

// MARK: Feature 484 (R02-G19-04) T-R02G1904-002

// The view orbit, the scrubber and the preview (FR-R02G1904-002 … 004, 007; SC-R02G1904-003, 004): every element, the
// scrubber and a preview (unfrozen, frozen, a removal) inside the authored box and inside the view with a 5 % margin
// at the four orbit corners and 7 aspects, the box corners within the fitted margin and the eye outside the box at the
// authored orbit and the corners; the previewed swim equal to the kernel's (the play after the
// drop: positions, velocities, report, stray cells); unfrozen the previewed swim drawn with a ghost well, frozen the
// committed swim with the previewed gauge readings; refused drops not previewed; without a preview the dish exactly
// R02-G19-03's drawing (the elements' painter's loop) followed by the scrubber, at the authored camera bit for bit.
extension MicroscopicAuroraSceneGeometryTests {
    typealias ViewOrbit = MicroscopicAuroraViewOrbit
    typealias Well = MicroscopicAuroraWell

    /// The orbits checked: the authored one and the four corners of the bounds.
    static let orbitChecks: [ViewOrbit] = [.authored] + ViewOrbit.corners

    /// A play of `level` begun, with a strength-3 counterclockwise well on site 0 in slot 0 and a strength-2 clockwise
    /// well on site 2 in slot 1 (catalog levels list at least three sites).
    static func playWithWells(_ level: Level) throws -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        let sites: [Cell] = level.sites ?? []
        try play.apply(.place(slot: 0, well: Well(cell: sites[0], strength: 3, sense: .counterclockwise)),
                       expecting: play.fingerprint)
        try play.apply(.place(slot: 1, well: Well(cell: sites[2], strength: 2, sense: .clockwise)),
                       expecting: play.fingerprint)
        return play
    }

    /// The dish of `snapshot` drawn by R02-G19-03's loop: every element in painter's order, nothing else.
    static func elementsOnly(_ snapshot: Snapshot, tier: Tier) throws -> MicroscopicAuroraColouredMesh {
        var parts: G.Parts = G.Parts()
        let broken: Set<Int> = G.brokenSwimmers(snapshot)
        let outlines: Set<Int> = G.brokenOutlines(snapshot)
        for element in G.paintOrder(snapshot) {
            try G.draw(element, into: &parts, snapshot, tier: tier, won: snapshot.isWon, brokenSwimmers: broken,
                       brokenOutlines: outlines)
        }
        return parts.built()
    }

    @Test func viewOrbitBoundsAndCamera() throws {
        #expect(ViewOrbit.authored == ViewOrbit(yaw: 0, pitch: 0))
        #expect(abs(ViewOrbit.yawLimit - Double.pi / 3) < 1e-15)
        #expect(ViewOrbit.yawRange == (-Double.pi / 3)...(Double.pi / 3))
        #expect(abs(ViewOrbit.pitchRange.lowerBound + 20 * Double.pi / 180) < 1e-15)
        #expect(abs(ViewOrbit.pitchRange.upperBound - 35 * Double.pi / 180) < 1e-15)
        #expect(ViewOrbit(yaw: 3, pitch: -3).clamped() == ViewOrbit(yaw: ViewOrbit.yawLimit,
                                                                    pitch: ViewOrbit.pitchRange.lowerBound))
        #expect(ViewOrbit(yaw: .nan, pitch: .infinity).clamped() == .authored)
        #expect(!ViewOrbit(yaw: 2, pitch: 0).isWithinBounds && ViewOrbit(yaw: 0.5, pitch: 0.5).isWithinBounds)
        #expect(ViewOrbit.corners.count == 4)
        for aspect in Self.aspects + [Double.nan, 100] {
            #expect(G.camera(aspect: aspect) == G.camera(aspect: aspect, orbit: .authored), "\(aspect)")
            #expect(G.camera(aspect: aspect, orbit: ViewOrbit(yaw: 0, pitch: 0)) == G.camera(aspect: aspect))
        }
        // Beyond the bounds the camera is the clamped orbit's.
        #expect(G.camera(aspect: 1, orbit: ViewOrbit(yaw: 5, pitch: 5))
                == G.camera(aspect: 1, orbit: ViewOrbit(yaw: ViewOrbit.yawLimit, pitch: ViewOrbit.pitchRange.upperBound)))
        for orbit in Self.orbitChecks {
            for aspect in Self.aspects {
                let camera: MicroscopicAuroraCamera = G.camera(aspect: aspect, orbit: orbit)
                // The eye outside the box, the look-at point in the middle of the view, the eye at the authored
                // distance from it.
                let e: SIMD3<Double> = camera.eye
                #expect(!(abs(e.x) <= 1 && e.y >= -1.35 && e.y <= 1 && abs(e.z) <= 0.02), "\(orbit) \(aspect)")
                #expect(e.z > 1.3, "\(orbit)")
                #expect(abs(Self.length(e - camera.target) - 3.4) < 1e-9)
                let centre: SIMD2<Double> = try #require(G.project(camera.target, camera: camera))
                #expect(abs(centre.x - 0.5) < 1e-9 && abs(centre.y - 0.5) < 1e-9)
                // Every box corner within the fitted margin.
                for index in 0..<8 {
                    let q: SIMD2<Double> = try #require(G.project(G.corner(index), camera: camera))
                    #expect(q.x >= 0.06 - 1e-9 && q.x <= 0.94 + 1e-9 && q.y >= 0.06 - 1e-9 && q.y <= 0.94 + 1e-9,
                            "\(orbit) \(aspect) corner \(index)")
                }
            }
        }
        // Yaw moves the eye towards +x, pitch raises it.
        #expect(G.camera(aspect: 1, orbit: ViewOrbit(yaw: 0.5, pitch: 0)).eye.x > 0)
        #expect(G.camera(aspect: 1, orbit: ViewOrbit(yaw: 0, pitch: 0.5)).eye.y > G.eye.y)
        #expect(G.camera(aspect: 1, orbit: ViewOrbit(yaw: 0, pitch: -0.3)).eye.y < G.eye.y)
    }

    @Test func everyElementScrubberAndPreviewInsideTheViewAtOrbitCorners() throws {
        // Catalog levels 1, 41 and 81 (level-1 meshes: every position but the capsule detail is the same at every
        // tier, and the capsules lie inside the box at every tier).
        let levels: [Level] = [Self.catalogLevels[0], Self.catalogLevels[2], Self.catalogLevels[4]]
        var checked: Int = 0
        for level in levels {
            let play: Play = try Self.playWithWells(level)
            let sites: [Cell] = level.sites ?? []
            let base: Snapshot = Snapshot(play: play, shownTick: 0, levelNumber: 1, time: 0)
            let moved: Snapshot = base.previewing(slot: 0, target: .site(sites[1]), level: level)
            #expect(moved.preview != nil, "\(level.id)")
            let previews: [Snapshot] = [base, moved, moved.freezing(true),
                                        base.previewing(slot: 1, target: .removal, level: level)]
            for snap in previews {
                for tick in [0, snap.ticksSwum] {
                    let shown: Snapshot = Self.copy(snap, shownTick: tick)
                    let view: Snapshot = snap.preview == nil ? shown : shown.previewing(
                        slot: snap.preview!.slot, target: snap.preview!.target, level: level).freezing(snap.frozen)
                    // The authored orbit is checked by everyElementInsideTheViewAtSevenAspects (no preview) and
                    // costs nothing new here; the four corners bound every orbit (the fit holds the box at each).
                    for orbit in ViewOrbit.corners {
                        let drawn: MicroscopicAuroraCamera = G.camera(aspect: 1, orbit: orbit)
                        let mesh: Mesh = try G.dishMesh(view, tier: .of(1), camera: drawn)
                        let glow: Mesh = try G.glowMesh(view, tier: .of(1), camera: drawn)
                        #expect(Self.badVertices(mesh) == 0 && Self.badVertices(glow) == 0)
                        var points: [SIMD3<Double>] = Self.positions(mesh, except: [.backdrop])
                        for index in glow.positions.indices { points.append(Self.point(glow, index)) }
                        for element in G.paintOrder(G.drawnSnapshot(view)) where element.part != .backdrop {
                            points.append(element.centre)
                        }
                        points.append(G.scrubberPoint(0))
                        points.append(G.scrubberPoint(1))
                        points.append(G.scrubberMark(view) + SIMD3(0, G.scrubberMarkReach, 0))
                        points.append(G.scrubberMark(view) - SIMD3(0, G.scrubberMarkReach, 0))
                        #expect(!Self.vertices(mesh, .scrubber).isEmpty)
                        for aspect in Self.aspects {
                            let camera: MicroscopicAuroraCamera = G.camera(aspect: aspect, orbit: orbit)
                            var outside: Int = 0
                            for p in points where !Self.inside(G.project(p, camera: camera)) { outside += 1 }
                            #expect(outside == 0, "\(level.id) tick \(tick) \(orbit) aspect \(aspect)")
                            checked += 1
                        }
                    }
                }
            }
        }
        #expect(checked == 3 * 4 * 2 * 4 * 7)
    }

    @Test func backdropFacesTheOrbitEyeAndFillsTheView() throws {
        let snap: Snapshot = Self.snapshot(Self.catalogLevels[0])
        for orbit in ViewOrbit.corners {
            for aspect in [0.4, 1.0, 2.5] {
                let camera: MicroscopicAuroraCamera = G.camera(aspect: aspect, orbit: orbit)
                let mesh: Mesh = try G.dishMesh(snap, tier: .of(1), camera: camera)
                let corners: [Int] = Self.vertices(mesh, .backdrop)
                #expect(corners.count == 4)
                var low: SIMD2<Double> = SIMD2(Double.infinity, Double.infinity)
                var high: SIMD2<Double> = SIMD2(-Double.infinity, -Double.infinity)
                for index in corners {
                    let q: SIMD2<Double> = try #require(G.project(Self.point(mesh, index), camera: camera))
                    low = SIMD2(min(low.x, q.x), min(low.y, q.y))
                    high = SIMD2(max(high.x, q.x), max(high.y, q.y))
                }
                #expect(low.x < 0 && low.y < 0 && high.x > 1 && high.y > 1, "\(orbit) \(aspect)")
                // Behind the box from that eye.
                let forward: SIMD3<Double> = G.viewBasis(camera).forward
                for index in corners {
                    #expect(G.dot(Self.point(mesh, index) - camera.eye, forward) > 3.4, "\(orbit)")
                }
            }
        }
    }

    @Test func previewedSwimEqualsTheKernelSwim() throws {
        for level in [Self.catalogLevels[1], Self.catalogLevels[3]] {
            let play: Play = try Self.playWithWells(level)
            let sites: [Cell] = level.sites ?? []
            let base: Snapshot = Snapshot(play: play, shownTick: 7, levelNumber: 1, time: 0)
            let fingerprint: String = play.fingerprint
            // A move of slot 0 to site 1 and a removal of slot 1, each against the play after that action.
            let moved: Well = Well(cell: sites[1], strength: 3, sense: .counterclockwise)
            let cases: [(target: MicroscopicAuroraPreviewTarget, slot: Int, action: MicroscopicAuroraAction)] = [
                (target: .site(sites[1]), slot: 0, action: .place(slot: 0, well: moved)),
                (target: .removal, slot: 1, action: .remove(slot: 1)),
            ]
            for entry in cases {
                let previewed: Snapshot = base.previewing(slot: entry.slot, target: entry.target, level: level)
                let preview: MicroscopicAuroraPreview = try #require(previewed.preview)
                var after: Play = play
                try after.apply(entry.action, expecting: after.fingerprint)
                let truth: Snapshot = Snapshot(play: after, shownTick: 7, levelNumber: 1, time: 0)
                #expect(preview.slot == entry.slot && preview.target == entry.target)
                #expect(preview.wells == after.wells)
                #expect(preview.report == after.report)
                #expect(preview.report == MicroscopicAuroraDish.report(level, wells: after.placedWells))
                #expect(preview.positions == truth.positions)
                #expect(preview.velocities == truth.velocities)
                #expect(preview.stray == truth.stray && preview.litStencil == truth.litStencil)
                #expect(preview.coverage == truth.coverage && preview.coherence == truth.coherence)
                #expect(preview.ticksSwum == truth.ticksSwum && preview.density == truth.density)
                // The game state and the committed swim are untouched.
                #expect(play.fingerprint == fingerprint)
                #expect(previewed.positions == base.positions && previewed.wells == base.wells)
                #expect(previewed.coverage == base.coverage && previewed.stage == base.stage)
                #expect(previewed.clearingPreview() == base)
                // Unfrozen, the drawn swim is the previewed one (the truth's, at the same shown tick).
                let drawn: Snapshot = G.drawnSnapshot(previewed)
                #expect(drawn.positions == truth.positions && drawn.shownTick == truth.shownTick)
                #expect(drawn.coverage == truth.coverage && drawn.failure == truth.failure)
                let swim: [M] = [.ribbon, .swimmer, .swimmerTail, .litCell, .strayCell]
                for tier in Tier.all {
                    let mesh: Mesh = try G.dishMesh(previewed, tier: tier)
                    let reference: Mesh = try G.dishMesh(truth, tier: tier)
                    for material in swim {
                        var got: [SIMD3<Double>] = []
                        for index in Self.vertices(mesh, material) { got.append(Self.point(mesh, index)) }
                        var want: [SIMD3<Double>] = []
                        for index in Self.vertices(reference, material) { want.append(Self.point(reference, index)) }
                        #expect(got == want, "\(level.id) \(material) \(tier.name)")
                    }
                    #expect(try G.glowMesh(previewed, tier: tier) == G.glowMesh(truth, tier: tier))
                    // The ghost well at the target site (a move), none for a removal.
                    let ghost: [Int] = Self.vertices(mesh, .ghostWell)
                    switch entry.target {
                    case .site(let cell):
                        #expect(!ghost.isEmpty)
                        let reach: Double = G.wellRadiusShare * G.cellSide + G.arrowLength + G.wellWidth
                        for index in ghost {
                            #expect(Self.length(Self.point(mesh, index) - G.cellCentre(cell)) <= reach)
                        }
                    case .removal:
                        #expect(ghost.isEmpty)
                    }
                    // The committed wells stay drawn.
                    #expect(Self.vertices(mesh, .wellSpiral).count == Self.vertices(try G.dishMesh(base, tier: tier),
                                                                                    .wellSpiral).count)
                }
            }
            // Refused drops are not previewed: the own site, another well's site, an empty slot, a cell that is not a
            // site, a slot out of range.
            let refused: [(slot: Int, target: MicroscopicAuroraPreviewTarget)] = [
                (slot: 0, target: .site(sites[0])), (slot: 0, target: .site(sites[2])),
                (slot: 2, target: .site(sites[1])), (slot: 2, target: .removal),
                (slot: 0, target: .site(Cell(row: 0, column: 0))), (slot: 5, target: .removal),
                (slot: -1, target: .removal),
            ]
            for entry in refused {
                #expect(base.previewing(slot: entry.slot, target: entry.target, level: level).preview == nil,
                        "\(entry.slot) \(entry.target)")
            }
        }
    }

    @Test func frozenDrawsTheCommittedSwimWithPreviewedGauges() throws {
        let level: Level = Self.catalogLevels[2]
        let play: Play = try Self.playWithWells(level)
        let sites: [Cell] = level.sites ?? []
        let base: Snapshot = Snapshot(play: play, shownTick: 11, levelNumber: 1, time: 0)
        #expect(!base.frozen && base.preview == nil && !base.drawsPreviewSwim)
        let frozen: Snapshot = base.previewing(slot: 0, target: .site(sites[1]), level: level).freezing(true)
        let preview: MicroscopicAuroraPreview = try #require(frozen.preview)
        #expect(frozen.frozen && !frozen.drawsPreviewSwim)
        #expect(G.ghostWell(frozen) == nil)
        let drawn: Snapshot = G.drawnSnapshot(frozen)
        #expect(drawn.positions == base.positions && drawn.litStencil == base.litStencil)
        #expect(drawn.failure == base.failure && drawn.shownTick == base.shownTick)
        #expect(drawn.coverage == preview.coverage && drawn.coherence == preview.coherence)
        #expect(G.coverageMark(drawn) == SIMD3(G.gaugeX(preview.coverage, top: 1000), G.coverageY, 0))
        #expect(G.coherenceMark(drawn) == SIMD3(G.gaugeX(preview.coherence, top: G.coherenceTop(base)), G.coherenceY,
                                                0))
        let swim: [M] = [.ribbon, .swimmer, .swimmerTail, .litCell, .strayCell, .wellSpiral, .wellArrow, .stencil]
        for tier in Tier.all {
            let mesh: Mesh = try G.dishMesh(frozen, tier: tier)
            let committed: Mesh = try G.dishMesh(base, tier: tier)
            #expect(Self.positions(mesh, except: [.markMet, .markUnmet]).count
                    == Self.positions(committed, except: [.markMet, .markUnmet]).count)
            for material in swim {
                var got: [SIMD3<Double>] = []
                for index in Self.vertices(mesh, material) { got.append(Self.point(mesh, index)) }
                var want: [SIMD3<Double>] = []
                for index in Self.vertices(committed, material) { want.append(Self.point(committed, index)) }
                #expect(got == want, "\(material) \(tier.name)")
            }
            #expect(Self.vertices(mesh, .ghostWell).isEmpty)
            #expect(try G.glowMesh(frozen, tier: tier) == G.glowMesh(base, tier: tier))
        }
        // Unfreezing draws the preview again; freezing without a preview changes nothing drawn.
        #expect(G.ghostWell(frozen.freezing(false)) != nil)
        #expect(try G.dishPart(base.freezing(true), tier: .of(0)) == G.dishPart(base, tier: .of(0)))
    }

    @Test func noPreviewIsR02G1903GeometryFollowedByTheScrubber() throws {
        var levels: [Level] = []
        for fixture in Self.fixtures { levels.append(fixture.level) }
        levels.append(Self.catalogLevels[0])
        levels.append(Self.extremeLevels[Self.extremeLevels.count - 1])
        for level in levels {
            let base: Snapshot = Self.snapshot(level)
            for tick in [0, base.ticksSwum / 2, base.ticksSwum] {
                let snap: Snapshot = Self.copy(base, shownTick: tick)
                #expect(snap.preview == nil && !snap.frozen)
                #expect(G.drawnSnapshot(snap) == snap)
                for tier in Tier.all {
                    let full: MicroscopicAuroraColouredMesh = try G.dishPart(snap, tier: tier)
                    let legacy: MicroscopicAuroraColouredMesh = try Self.elementsOnly(snap, tier: tier)
                    let n: Int = legacy.mesh.positions.count
                    #expect(Array(full.mesh.positions.prefix(n)) == legacy.mesh.positions)
                    #expect(Array(full.mesh.normals.prefix(n)) == legacy.mesh.normals)
                    #expect(Array(full.mesh.uvs.prefix(n)) == legacy.mesh.uvs)
                    #expect(Array(full.colours.prefix(n)) == legacy.colours)
                    #expect(Array(full.mesh.indices.prefix(legacy.mesh.indices.count)) == legacy.mesh.indices)
                    // What follows is the scrubber: its track and its mark, two quads.
                    #expect(full.mesh.positions.count == n + 8)
                    #expect(full.mesh.indices.count == legacy.mesh.indices.count + 12)
                    for index in n..<full.mesh.positions.count {
                        #expect(Self.material(full.mesh, index) == .scrubber)
                    }
                    // The camera-taking overloads at the authored camera are the same, bit for bit.
                    let authored: MicroscopicAuroraCamera = G.camera(aspect: 1.7)
                    #expect(try G.dishPart(snap, tier: tier, camera: authored) == full)
                    #expect(try G.dishMesh(snap, tier: tier, camera: authored) == full.mesh)
                    #expect(try G.glowPart(snap, tier: tier, camera: authored) == G.glowPart(snap, tier: tier))
                    #expect(try G.glowMesh(snap, tier: tier, camera: authored) == G.glowMesh(snap, tier: tier))
                }
            }
        }
    }

    @Test func scrubberPlacement() throws {
        #expect(G.scrubberY == -1.31)
        #expect(G.scrubberPoint(0) == SIMD3(-0.9, -1.31, 0) && G.scrubberPoint(1) == SIMD3(0.9, -1.31, 0))
        #expect(G.scrubberPoint(0.5).x == 0 && G.scrubberPoint(-3) == G.scrubberPoint(0))
        #expect(G.scrubberPoint(7) == G.scrubberPoint(1) && G.scrubberPoint(.nan) == G.scrubberPoint(0))
        // Below the actions bars and inside the box.
        #expect(G.scrubberY + G.scrubberMarkReach < G.barsY - G.barHeight / 2)
        #expect(G.scrubberY - G.scrubberMarkReach >= G.boxLow.y)
        let base: Snapshot = Self.snapshot(Self.catalogLevels[0])
        for tick in [0, base.ticksSwum / 3, base.ticksSwum] {
            let snap: Snapshot = Self.copy(base, shownTick: tick)
            let x: Double = -0.9 + 1.8 * Double(tick) / Double(base.ticksSwum)
            #expect(abs(G.scrubberMark(snap).x - x) < 1e-12 && G.scrubberMark(snap).y == -1.31)
            let mesh: Mesh = try G.dishMesh(snap, tier: .of(2))
            let marks: Int = Self.near(mesh, .scrubber, G.scrubberMark(snap), G.scrubberMarkReach + 0.01)
            #expect(marks >= 4)
        }
        // A swim of no ticks puts the mark at the start.
        let still: Snapshot = Snapshot(radius: 11, positions: [[Point(x: 3072, y: 3072)]],
                                       velocities: [[Point(x: 0, y: 0)]], ticksSwum: 0, shownTick: 0, density: [],
                                       litStencil: [], stray: [], stencil: [], sites: [], wells: [nil, nil, nil],
                                       coverage: 0, requiredCoverage: 500, coherence: 1, requiredCoherence: 2,
                                       swarm: 1, coherenceRadius: 2, failure: nil, stage: .playing, actionsLeft: 1,
                                       budget: 1, levelNumber: 1, time: 0)
        #expect(G.scrubberMark(still) == G.scrubberPoint(0))
        // The well centres.
        let play: Play = try Self.playWithWells(Self.catalogLevels[0])
        let snap: Snapshot = Snapshot(play: play, shownTick: 0, levelNumber: 1, time: 0)
        #expect(G.wellCentre(0, snap) == G.cellCentre(Self.catalogLevels[0].sites![0]))
        #expect(G.wellCentre(2, snap) == nil && G.wellCentre(3, snap) == nil && G.wellCentre(-1, snap) == nil)
    }
}
