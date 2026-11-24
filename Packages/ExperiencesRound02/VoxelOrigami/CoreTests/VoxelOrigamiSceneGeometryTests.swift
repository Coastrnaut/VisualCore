// VoxelOrigamiSceneGeometryTests — feature 443 (R02-G15-03) T-R02G1503-004 (FR-R02G1503-001, 002, 004, 006;
// SC-R02G1503-001; clarifications Q1, Q2, Q3). The voxel scene from snapshots: finite and bounded for extreme settings
// (4 and 12 cubes, straight and folded chains, budgets 1 and 40); every cube, hinge, pip and bar inside the view with
// margin at 7 aspects over ten catalog levels (built from their recorded candidates); the same positions at every tier;
// the cubes exactly at w(kernel cell); the target at the covered count's alignment; gauges at 0, half and the budget; a
// won level brighter and in place; the glow empty at level-2 with its shell counts per tier; only bevels, edge widths
// and glow differ between tiers; the paint order sorted with the tie rule; back-face culling: every cube triangle
// facing away from the eye projects clockwise and every one facing it counter-clockwise, every flat item
// counter-clockwise.
// Feature 444 (R02-G15-04) T-R02G1504-002 (FR-R02G1504-004; SC-R02G1504-004; clarification Q4) adds the orbit: every
// element and box corner inside the view with margin at the four orbit corners (yaw ±60°, pitch −20° and +35°) and 7
// aspects; the authored-orbit camera and the camera-taking meshes bit-identical to the authored ones, clamping; the eye
// outside the box at every corner; the winding of the meshes built for an orbited camera suits back-face culling.
// Explicit types, plain loops; each test well under 2 s.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import VoxelOrigamiCore

struct VoxelOrigamiSceneGeometryTests {
    typealias G = VoxelOrigamiSceneGeometry
    typealias Snapshot = VoxelOrigamiSceneSnapshot
    typealias Material = VoxelOrigamiShaders.Material

    /// (manifest entry index, recorded candidate index) of ten catalog levels, read from
    /// docs/games/voxel-origami/levels/NNN.witness.json (`skipped`) on 2026-11-24.
    static let catalogTable: [(entry: Int, skipped: Int)] = [(0, 3), (4, 0), (9, 0), (19, 1), (29, 1), (44, 3), (59, 0),
                                                              (74, 0), (89, 7), (99, 3)]

    /// The seven aspects checked.
    static let aspects: [Double] = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]

    /// The ten catalog levels of ``catalogTable``.
    static func catalogLevels() -> [VoxelOrigamiLevel] {
        var levels: [VoxelOrigamiLevel] = []
        for row in catalogTable {
            let entry: VoxelOrigamiManifestEntry = VoxelOrigamiManifest.entries[row.entry]
            if let level = VoxelOrigamiGenerator.candidate(entry, index: row.skipped) {
                levels.append(level)
            }
        }
        return levels
    }

    /// A hand level of the given cubes and target.
    static func level(_ cubes: [VoxelOrigamiCube], target: [VoxelOrigamiVector], budget: Int,
                      orientations: VoxelOrigamiOrientations = .any) throws -> VoxelOrigamiLevel {
        try VoxelOrigamiLevel(id: VoxelOrigamiGenerator.levelID(901), seed: 1, difficulty: 1, cubes: cubes,
                              target: target.sorted(), orientations: orientations, budget: budget)
    }

    /// A chain of `count` cubes: straight along +x, or folded (a staircase of +x and +y).
    static func chain(_ count: Int, folded: Bool) -> [VoxelOrigamiCube] {
        var cubes: [VoxelOrigamiCube] = [.root]
        for index in 1..<count {
            let direction: VoxelOrigamiVector = folded && index % 2 == 0 ? VoxelOrigamiVector(0, 1, 0)
                : VoxelOrigamiVector(1, 0, 0)
            cubes.append(VoxelOrigamiCube(parent: index - 1, direction: direction, startTurn: 0))
        }
        return cubes
    }

    /// The cells of `cubes` at rest.
    static func restCells(_ cubes: [VoxelOrigamiCube]) -> [VoxelOrigamiVector] {
        VoxelOrigamiLattice.pose(cubes, turns: Array(repeating: 0, count: cubes.count)).cells
    }

    /// The L chain of four cubes: (0,0,0), (1,0,0), (1,1,0), (2,1,0); hinge 2 swings cube 3 about +y.
    static let lChain: [VoxelOrigamiCube] = [.root,
                                             VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(1, 0, 0)),
                                             VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(0, 1, 0)),
                                             VoxelOrigamiCube(parent: 2, direction: VoxelOrigamiVector(1, 0, 0))]

    /// The extreme hand levels: 4 and 12 cubes, straight and folded, budgets 1 and 40.
    static func extremeLevels() throws -> [VoxelOrigamiLevel] {
        var levels: [VoxelOrigamiLevel] = []
        var line4: [VoxelOrigamiVector] = []
        for x in 0..<4 { line4.append(VoxelOrigamiVector(x, 0, 0)) }
        for budget in [1, 40] { levels.append(try level(lChain, target: line4, budget: budget)) }
        var line12: [VoxelOrigamiVector] = []
        for x in 0..<12 { line12.append(VoxelOrigamiVector(x, 0, 0)) }
        let folded: [VoxelOrigamiCube] = chain(12, folded: true)
        let straight: [VoxelOrigamiCube] = chain(12, folded: false)
        for budget in [1, 40] {
            levels.append(try level(folded, target: line12, budget: budget))
            levels.append(try level(straight, target: restCells(folded), budget: budget))
        }
        return levels
    }

    /// The snapshot of a fresh play of `level`.
    static func snapshot(_ level: VoxelOrigamiLevel, chosen: Int = 1) -> Snapshot {
        Snapshot(play: VoxelOrigamiPlay(level: level), chosenHinge: chosen, levelNumber: 1, time: 0)
    }

    /// A play of `level` started (stage playing).
    static func started(_ level: VoxelOrigamiLevel) throws -> VoxelOrigamiPlay {
        var play: VoxelOrigamiPlay = VoxelOrigamiPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The position of vertex `index` of `mesh`.
    static func point(_ mesh: Mesh, _ index: Int) -> SIMD3<Double> {
        SIMD3(mesh.positions[index].x, mesh.positions[index].y, mesh.positions[index].z)
    }

    /// The vertex indices of `mesh` whose material code is `material` and whose local coordinate is `local` (any when
    /// nil).
    static func vertices(_ mesh: Mesh, _ material: Material, local: Double? = nil) -> [Int] {
        var found: [Int] = []
        for index in mesh.uvs.indices where mesh.uvs[index].x == Double(material.code) {
            if let l = local, mesh.uvs[index].y != l { continue }
            found.append(index)
        }
        return found
    }

    /// The length of `v`.
    static func length(_ v: SIMD3<Double>) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }

    // MARK: Tests

    @Test func finiteAndBoundedForExtremeSettings() throws {
        let levels: [VoxelOrigamiLevel] = try Self.extremeLevels()
        #expect(levels.count == 6)
        for level in levels {
            let snap: Snapshot = Self.snapshot(level)
            let s: Double = G.scale(snap)
            #expect(s.isFinite && s > 0 && s <= 0.75)
            for tier in VoxelOrigamiTier.all {
                let mesh: Mesh = try G.voxelMesh(snap, tier: tier, reduceMotion: false)
                let glow: Mesh = try G.glowMesh(snap, tier: tier)
                #expect(mesh.triangleCount > 0)
                #expect(mesh.triangleCount < 6_000, "\(mesh.triangleCount) triangles")
                for index in mesh.positions.indices {
                    let p: SIMD3<Double> = Self.point(mesh, index)
                    #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
                    #expect(mesh.uvs[index].x.isFinite && mesh.uvs[index].y.isFinite)
                    if mesh.uvs[index].x != Double(Material.backdrop.code) {
                        #expect(abs(p.x) <= 1.3 && abs(p.y) <= 1.3 && abs(p.z) <= 1.3, "\(p)")
                    }
                }
                for index in glow.positions.indices {
                    let p: SIMD3<Double> = Self.point(glow, index)
                    #expect(abs(p.x) <= 1.3 && abs(p.y) <= 1.3 && abs(p.z) <= 1.3, "\(p)")
                }
            }
        }
    }

    @Test func everyElementInsideTheViewAtSevenAspects() throws {
        let levels: [VoxelOrigamiLevel] = Self.catalogLevels()
        #expect(levels.count == Self.catalogTable.count)
        var all: [VoxelOrigamiLevel] = levels
        all.append(contentsOf: try Self.extremeLevels())
        for level in all {
            let snap: Snapshot = Self.snapshot(level)
            for aspect in Self.aspects {
                let camera: VoxelOrigamiCamera = G.camera(snap, aspect: aspect)
                for element in G.paintOrder(snap, camera: camera) {
                    let p: SIMD2<Double>? = G.project(element.centre, camera: camera)
                    #expect(p != nil)
                    guard let q = p else { continue }
                    #expect(q.x >= 0.05 && q.x <= 0.95 && q.y >= 0.05 && q.y <= 0.95,
                            "\(level.id) aspect \(aspect) \(element.kind) \(element.index) at \(q)")
                }
            }
        }
    }

    @Test func cameraIsTheAuthoredOneAndProjectRefusesBehind() {
        let snap: Snapshot = Self.snapshot(Self.catalogLevels()[0])
        let camera: VoxelOrigamiCamera = G.camera(snap, aspect: 1.5)
        #expect(camera.eye == SIMD3(1.4, 1.1, 2.6))
        #expect(camera.target == SIMD3(0, -0.1, 0))
        #expect(camera.aspect == 1.5)
        #expect(G.camera(snap, aspect: .nan).aspect == 1)
        let centre: SIMD2<Double>? = G.project(camera.target, camera: camera)
        #expect(centre != nil)
        if let c = centre { #expect(abs(c.x - 0.5) < 1e-9 && abs(c.y - 0.5) < 1e-9) }
        let behind: SIMD3<Double> = camera.eye + (camera.eye - camera.target)
        #expect(G.project(behind, camera: camera) == nil)
        #expect(G.project(SIMD3(.infinity, 0, 0), camera: camera) == nil)
    }

    @Test func cubesSitExactlyAtTheKernelCells() throws {
        for level in Self.catalogLevels() {
            let snap: Snapshot = Self.snapshot(level)
            var low: SIMD3<Double> = SIMD3(repeating: Double.infinity)
            var high: SIMD3<Double> = SIMD3(repeating: -Double.infinity)
            var cells: [VoxelOrigamiVector] = snap.cells
            cells.append(contentsOf: snap.target)
            for c in cells {
                let p: SIMD3<Double> = SIMD3(Double(c.x), Double(c.y), Double(c.z))
                low = SIMD3(min(low.x, p.x), min(low.y, p.y), min(low.z, p.z))
                high = SIMD3(max(high.x, p.x), max(high.y, p.y), max(high.z, p.z))
            }
            let m: SIMD3<Double> = (low + high) / 2
            let e: Double = max(high.x - low.x, high.y - low.y, high.z - low.z)
            let s: Double = 1.5 / (e + 1)
            #expect(G.scale(snap) == s)
            #expect(snap.cells == level.pose(turns: level.startTurns).cells)
            var centres: [SIMD3<Double>] = []
            for index in snap.cells.indices {
                let c: VoxelOrigamiVector = snap.cells[index]
                let expected: SIMD3<Double> = (SIMD3(Double(c.x), Double(c.y), Double(c.z)) - m) * s
                #expect(Self.length(G.cubeCentre(index, snap) - expected) < 1e-12)
                centres.append(expected)
            }
            // Each cube's six flat-face centres lie 0.45 s from its centre along an axis.
            let mesh: Mesh = try G.voxelMesh(snap, tier: VoxelOrigamiTier.of(0), reduceMotion: false)
            let faceCentres: [Int] = Self.vertices(mesh, .cubeFace, local: 0)
            #expect(faceCentres.count == 6 * snap.cells.count)
            var perCube: [Int] = Array(repeating: 0, count: centres.count)
            for vertex in faceCentres {
                let p: SIMD3<Double> = Self.point(mesh, vertex)
                for index in centres.indices where abs(Self.length(p - centres[index]) - 0.45 * s) < 1e-9 {
                    let n: SIMD3<Double> = SIMD3(mesh.normals[vertex].x, mesh.normals[vertex].y, mesh.normals[vertex].z)
                    if Self.length(centres[index] + n * (0.45 * s) - p) < 1e-9 { perCube[index] += 1 }
                }
            }
            #expect(perCube == Array(repeating: 6, count: centres.count))
        }
    }

    @Test func targetSitsAtTheCoveredAlignment() throws {
        for level in Self.catalogLevels() {
            let snap: Snapshot = Self.snapshot(level)
            let cells: Set<VoxelOrigamiVector> = Set(snap.cells)
            var shared: Int = 0
            for t in snap.target where cells.contains(t) { shared += 1 }
            #expect(shared == snap.report.covered)
            #expect(snap.target.count == snap.cells.count)
            let camera: VoxelOrigamiCamera = G.camera(snap, aspect: 1)
            var outlines: Int = 0
            for element in G.paintOrder(snap, camera: camera) where element.kind == .targetOutline {
                outlines += 1
                #expect(element.centre == G.world(snap.target[element.index], snap))
            }
            #expect(outlines == snap.target.count)
            // Glyphs: solid exactly for the cubes on target cells.
            let mesh: Mesh = try G.voxelMesh(snap, tier: VoxelOrigamiTier.of(2), reduceMotion: false)
            let solidCentres: Int = Self.vertices(mesh, .glyphSolid, local: 0).count
            #expect(solidCentres == 6 * shared)
        }
    }

    @Test func gaugesAtZeroHalfAndBudget() throws {
        var line4: [VoxelOrigamiVector] = []
        for x in 0..<4 { line4.append(VoxelOrigamiVector(x, 0, 0)) }
        let budget: Int = 6
        let level: VoxelOrigamiLevel = try Self.level(Self.lChain, target: line4, budget: budget)
        var play: VoxelOrigamiPlay = try Self.started(level)
        var checked: [Int] = []
        for spent in 0...budget {
            if spent > 0 { try play.apply(.turn(2, 1), expecting: play.fingerprint) }
            guard spent == 0 || spent == budget / 2 || spent == budget else { continue }
            let snap: Snapshot = Snapshot(play: play, chosenHinge: 2, levelNumber: 1, time: 0)
            #expect(snap.actionsLeft == budget - spent)
            #expect(G.litMoves(snap) == budget - spent)
            let mesh: Mesh = try G.voxelMesh(snap, tier: VoxelOrigamiTier.of(1), reduceMotion: false)
            #expect(Self.vertices(mesh, .movesLit, local: 0).count == budget - spent)
            #expect(Self.vertices(mesh, .movesUnlit, local: 0).count == spent)
            #expect(Self.vertices(mesh, .coveredLit, local: 0).count == snap.report.covered)
            #expect(G.litPips(snap) == snap.report.covered)
            for index in 0..<budget {
                let bar: SIMD3<Double> = G.movesBar(index, snap)
                #expect(abs(bar.x - (-0.9 + (Double(index) + 0.5) * 1.8 / Double(budget))) < 1e-12)
                #expect(bar.y == -1.2)
            }
            let pip: SIMD3<Double> = G.coveredPip(0, snap)
            #expect(abs(pip.x - (-0.8 + 0.5 * 1.6 / 4)) < 1e-12 && pip.y == -1.05)
            checked.append(spent)
        }
        #expect(checked == [0, 3, 6])
        #expect(play.stage == .failed)
    }

    /// A won L-chain play: hinge 2 turned once onto its target.
    static func wonPlay() throws -> VoxelOrigamiPlay {
        let target: [VoxelOrigamiVector] = VoxelOrigamiLattice.pose(lChain, turns: [0, 0, 1, 0]).cells
        let level: VoxelOrigamiLevel = try Self.level(lChain, target: target, budget: 3, orientations: .fixed)
        var play: VoxelOrigamiPlay = try started(level)
        try play.apply(.turn(2, 1), expecting: play.fingerprint)
        return play
    }

    @Test func wonLevelIsBrighterAndInPlace() throws {
        let play: VoxelOrigamiPlay = try Self.wonPlay()
        #expect(play.stage == .won)
        let snap: Snapshot = Snapshot(play: play, chosenHinge: 1, levelNumber: 1, time: 0)
        #expect(G.wonFlag(snap) == 1)
        let tier: VoxelOrigamiTier = VoxelOrigamiTier.of(0)
        let lit: VoxelOrigamiColouredMesh = try G.voxelPart(snap, tier: tier)
        let plain: VoxelOrigamiColouredMesh = try G.voxelPart(snap, tier: tier, wonLevel: 0)
        #expect(lit.mesh == plain.mesh)
        let faces: [Int] = Self.vertices(lit.mesh, .cubeFace)
        #expect(!faces.isEmpty)
        for vertex in faces {
            let a: Vec4 = lit.colours[vertex]
            let b: Vec4 = plain.colours[vertex]
            #expect(0.2126 * a.x + 0.7152 * a.y + 0.0722 * a.z > 0.2126 * b.x + 0.7152 * b.y + 0.0722 * b.z)
        }
        for index in snap.cells.indices {
            #expect(G.cubeCentre(index, snap) == G.world(play.pose.cells[index], snap))
            #expect(G.isLit(index, snap))
        }
        // Every cube glows on a won level.
        let glow: Mesh = try G.glowMesh(snap, tier: tier)
        #expect(glow.triangleCount == 2 * 8 * (snap.target.count + snap.cells.count))
    }

    @Test func glowShellsPerTier() throws {
        for level in Self.catalogLevels() {
            let snap: Snapshot = Self.snapshot(level)
            var lit: Int = 0
            for index in snap.cells.indices where G.isLit(index, snap) { lit += 1 }
            for tier in VoxelOrigamiTier.all {
                let part: VoxelOrigamiColouredMesh = try G.glowPart(snap, tier: tier)
                #expect(part.mesh.triangleCount == tier.glowShells * 8 * (snap.target.count + lit))
                #expect(part.colours.count == part.mesh.positions.count)
                for index in part.mesh.uvs.indices {
                    let decoded: (kind: VoxelOrigamiShaders.GlowKind, factor: Double) =
                        VoxelOrigamiShaders.GlowKind.decode(part.mesh.uvs[index].x)
                    #expect(decoded.factor > 0 && decoded.factor <= 0.5)
                    #expect(part.mesh.uvs[index].y == 0 || part.mesh.uvs[index].y == 1)
                }
            }
            #expect(try G.glowMesh(snap, tier: VoxelOrigamiTier.of(2)).triangleCount == 0)
        }
    }

    @Test func onlyBevelsEdgeWidthsAndGlowDifferBetweenTiers() throws {
        let shared: Set<Float> = [Material.backdrop.code, Material.glyphSolid.code, Material.glyphHollow.code,
                                  Material.dots.code, Material.hinge.code, Material.hingeChosen.code,
                                  Material.coveredLit.code, Material.coveredUnlit.code, Material.movesLit.code,
                                  Material.movesUnlit.code, Material.broken.code]
        var levels: [VoxelOrigamiLevel] = Self.catalogLevels()
        levels.append(contentsOf: try Self.extremeLevels())
        for level in levels {
            let snap: Snapshot = Self.snapshot(level, chosen: 2)
            var reference: [Vec3]? = nil
            var referenceCentres: [Vec3]? = nil
            for tier in VoxelOrigamiTier.all {
                let mesh: Mesh = try G.voxelMesh(snap, tier: tier, reduceMotion: tier.index == 1)
                var kept: [Vec3] = []
                for index in mesh.positions.indices where shared.contains(Float(mesh.uvs[index].x)) {
                    kept.append(mesh.positions[index])
                }
                var centres: [Vec3] = []
                for index in Self.vertices(mesh, .cubeFace, local: 0) { centres.append(mesh.positions[index]) }
                if let r = reference, let rc = referenceCentres {
                    #expect(kept == r, "\(level.id) \(tier.name)")
                    #expect(Set(centres) == Set(rc), "\(level.id) \(tier.name)")
                } else {
                    reference = kept
                    referenceCentres = centres
                }
                // Bevels only where the tier has bevel steps.
                #expect(Self.vertices(mesh, .cubeBevel).isEmpty == (tier.bevelSteps == 0))
            }
            // The target edge width follows the tier.
            let s: Double = G.scale(snap)
            for tier in VoxelOrigamiTier.all {
                let mesh: Mesh = try G.voxelMesh(snap, tier: tier, reduceMotion: false)
                let edges: [Int] = Self.vertices(mesh, .targetEdge)
                #expect(!edges.isEmpty)
                // An edge quad's two sides are tier.edgeWidth · s apart: the first quad's corners 0 and 3.
                var widthFound: Bool = false
                for t in stride(from: 0, to: mesh.indices.count, by: 3)
                where mesh.uvs[Int(mesh.indices[t])].x == Double(Material.targetEdge.code) {
                    var pts: [SIMD3<Double>] = []
                    for k in 0..<3 { pts.append(Self.point(mesh, Int(mesh.indices[t + k]))) }
                    var shortest: Double = Double.infinity
                    for k in 0..<3 { shortest = min(shortest, Self.length(pts[k] - pts[(k + 1) % 3])) }
                    widthFound = abs(shortest - tier.edgeWidth * s) < 1e-9
                    break
                }
                #expect(widthFound, "\(tier.name)")
            }
        }
    }

    @Test func paintOrderIsSortedWithTheTieRule() throws {
        var levels: [VoxelOrigamiLevel] = Self.catalogLevels()
        levels.append(contentsOf: try Self.extremeLevels())
        for level in levels {
            let snap: Snapshot = Self.snapshot(level)
            let camera: VoxelOrigamiCamera = G.camera(snap, aspect: 1)
            let order: [VoxelOrigamiElement] = G.paintOrder(snap, camera: camera)
            #expect(order.count == 2 * snap.cells.count + (snap.cells.count - 1) + snap.cells.count + snap.budget)
            for k in 1..<order.count {
                let a: VoxelOrigamiElement = order[k - 1]
                let b: VoxelOrigamiElement = order[k]
                #expect(a.distance >= b.distance)
                if a.distance == b.distance {
                    #expect(a.kind.rawValue < b.kind.rawValue || (a.kind == b.kind && a.index < b.index))
                }
                #expect(abs(a.distance - Self.length(a.centre - camera.eye)) < 1e-12)
            }
        }
        // The tie rule on equal distances.
        let p: SIMD3<Double> = SIMD3(0, 0, 0)
        let cube3: VoxelOrigamiElement = VoxelOrigamiElement(kind: .cube, index: 3, centre: p, distance: 2)
        let cube1: VoxelOrigamiElement = VoxelOrigamiElement(kind: .cube, index: 1, centre: p, distance: 2)
        let outline: VoxelOrigamiElement = VoxelOrigamiElement(kind: .targetOutline, index: 9, centre: p, distance: 2)
        let bar: VoxelOrigamiElement = VoxelOrigamiElement(kind: .bar, index: 0, centre: p, distance: 2)
        let far: VoxelOrigamiElement = VoxelOrigamiElement(kind: .bar, index: 5, centre: p, distance: 3)
        var list: [VoxelOrigamiElement] = [bar, cube3, outline, cube1, far]
        list.sort(by: VoxelOrigamiElement.paintsBefore)
        #expect(list == [far, outline, cube1, cube3, bar])
    }

    @Test func meshFollowsThePaintOrderAndTheFailureOutlines() throws {
        // U chain with a still cube where hinge 2's turn lands cube 3: collision(hinge 2, moving 3, still 5).
        let cubes: [VoxelOrigamiCube] = [.root,
                                         VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(1, 0, 0)),
                                         VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(0, 1, 0)),
                                         VoxelOrigamiCube(parent: 2, direction: VoxelOrigamiVector(-1, 0, 0)),
                                         VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(0, 0, 1)),
                                         VoxelOrigamiCube(parent: 4, direction: VoxelOrigamiVector(0, 1, 0))]
        var line: [VoxelOrigamiVector] = []
        for x in 0..<6 { line.append(VoxelOrigamiVector(x, 0, 0)) }
        let level: VoxelOrigamiLevel = try Self.level(cubes, target: line, budget: 5)
        var play: VoxelOrigamiPlay = try Self.started(level)
        try play.apply(.turn(2, 1), expecting: play.fingerprint)
        #expect(play.failure == .collision(hinge: 2, moving: 3, still: 5, cell: VoxelOrigamiVector(1, 1, 1)))
        let snap: Snapshot = Snapshot(play: play, chosenHinge: 2, levelNumber: 1, time: 0)
        let mesh: Mesh = try G.voxelMesh(snap, tier: VoxelOrigamiTier.of(1), reduceMotion: false)
        // Two wire cubes of 12 strips (2 triangles each) and a two-strip cross.
        let brokenTriangles: Int = Self.triangles(mesh, .broken).count
        #expect(brokenTriangles == 2 * 12 * 2 + 2 * 2)
        let healthy: Mesh = try G.voxelMesh(Self.snapshot(level, chosen: 2), tier: VoxelOrigamiTier.of(1),
                                            reduceMotion: false)
        #expect(Self.triangles(healthy, .broken).isEmpty)
        // The backdrop is the first triangle; the moves bars and pips follow the paint order of their elements.
        #expect(mesh.uvs[Int(mesh.indices[0])].x == Double(Material.backdrop.code))
        let camera: VoxelOrigamiCamera = G.camera(snap, aspect: 1)
        var barOrder: [Int] = []
        for element in G.paintOrder(snap, camera: camera) where element.kind == .bar { barOrder.append(element.index) }
        var meshBars: [Int] = []
        for vertex in Self.vertices(mesh, .movesLit, local: 0) + Self.vertices(mesh, .movesUnlit, local: 0) {
            let x: Double = mesh.positions[vertex].x
            meshBars.append(Int(((x + 0.9) / G.movesSlot(snap) - 0.5).rounded()))
        }
        var firstUse: [Int] = []
        for t in mesh.indices {
            let i: Int = Int(t)
            let code: Double = mesh.uvs[i].x
            guard code == Double(Material.movesLit.code) || code == Double(Material.movesUnlit.code),
                  mesh.uvs[i].y == 0 else { continue }
            let bar: Int = Int(((mesh.positions[i].x + 0.9) / G.movesSlot(snap) - 0.5).rounded())
            if !firstUse.contains(bar) { firstUse.append(bar) }
        }
        #expect(Set(meshBars) == Set(barOrder))
        #expect(firstUse == barOrder)
    }

    /// The triangles (index triples) of `mesh` whose first vertex has material `material`.
    static func triangles(_ mesh: Mesh, _ material: Material) -> [(Int, Int, Int)] {
        var found: [(Int, Int, Int)] = []
        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a: Int = Int(mesh.indices[t])
            if mesh.uvs[a].x == Double(material.code) {
                found.append((a, Int(mesh.indices[t + 1]), Int(mesh.indices[t + 2])))
            }
        }
        return found
    }

    @Test func windingSuitsBackFaceCulling() throws {
        let solids: Set<Float> = [Material.cubeFace.code, Material.cubeBevel.code, Material.glyphSolid.code,
                                  Material.glyphHollow.code, Material.dots.code]
        var levels: [VoxelOrigamiLevel] = Array(Self.catalogLevels().prefix(4))
        levels.append(try Self.extremeLevels()[2])
        for level in levels {
            let snap: Snapshot = Self.snapshot(level)
            for tier in VoxelOrigamiTier.all {
                let mesh: Mesh = try G.voxelMesh(snap, tier: tier, reduceMotion: false)
                let glow: Mesh = try G.glowMesh(snap, tier: tier)
                for aspect in [0.5, 2.0] {
                    let camera: VoxelOrigamiCamera = G.camera(snap, aspect: aspect)
                    var front: Int = 0
                    var back: Int = 0
                    for (m, isGlow) in [(mesh, false), (glow, true)] {
                        for t in stride(from: 0, to: m.indices.count, by: 3) {
                            let ids: [Int] = [Int(m.indices[t]), Int(m.indices[t + 1]), Int(m.indices[t + 2])]
                            var pts: [SIMD3<Double>] = []
                            var screen: [SIMD2<Double>] = []
                            for id in ids {
                                let p: SIMD3<Double> = Self.point(m, id)
                                pts.append(p)
                                // Backdrop corners may lie outside the view; project them all the same.
                                if let q = G.project(p, camera: camera) { screen.append(q) }
                            }
                            guard screen.count == 3 else { continue }
                            // Signed area with y up (project gives y down): positive is counter-clockwise.
                            let area: Double = (screen[1].x - screen[0].x) * (screen[0].y - screen[2].y)
                                - (screen[0].y - screen[1].y) * (screen[2].x - screen[0].x)
                            let code: Float = Float(m.uvs[ids[0]].x)
                            if !isGlow && solids.contains(code) {
                                let n: SIMD3<Double> = SIMD3(m.normals[ids[0]].x, m.normals[ids[0]].y,
                                                             m.normals[ids[0]].z)
                                let centroid: SIMD3<Double> = (pts[0] + pts[1] + pts[2]) / 3
                                let toEye: SIMD3<Double> = camera.eye - centroid
                                let along: Double = n.x * toEye.x + n.y * toEye.y + n.z * toEye.z
                                let facing: Double = along / Self.length(toEye)
                                if abs(facing) < 1e-6 || abs(area) < 1e-14 { continue }
                                if facing > 0 {
                                    front += 1
                                    #expect(area > 0, "front-facing \(code) projects clockwise")
                                } else {
                                    back += 1
                                    #expect(area < 0, "back-facing \(code) projects counter-clockwise")
                                }
                            } else if abs(area) > 1e-14 {
                                #expect(area > 0, "flat item \(code) (glow \(isGlow)) projects clockwise")
                            }
                        }
                    }
                    #expect(front > 0 && back > 0)
                }
            }
        }
    }

    @Test func normalsAreUnitOnLitMaterials() throws {
        let snap: Snapshot = Self.snapshot(Self.catalogLevels()[5])
        for tier in VoxelOrigamiTier.all {
            let mesh: Mesh = try G.voxelMesh(snap, tier: tier, reduceMotion: false)
            for index in mesh.positions.indices {
                let n: Vec3 = mesh.normals[index]
                #expect(abs((n.x * n.x + n.y * n.y + n.z * n.z).squareRoot() - 1) < 1e-9)
                let local: Double = mesh.uvs[index].y
                #expect(local >= -1 && local <= 1)
            }
        }
    }

    // MARK: Orbit (feature 444, R02-G15-04, T-R02G1504-002)

    /// The four orbit corners: yaw ±60°, pitch −20° and +35°.
    static let orbitCorners: [VoxelOrigamiOrbit] = {
        var corners: [VoxelOrigamiOrbit] = []
        for yaw in [-60.0, 60.0] {
            for pitch in [-20.0, 35.0] {
                corners.append(VoxelOrigamiOrbit(yaw: yaw * Double.pi / 180, pitch: pitch * Double.pi / 180))
            }
        }
        return corners
    }()

    @Test func orbitKeepsEveryElementInsideTheViewAtTheCorners() throws {
        var all: [VoxelOrigamiLevel] = Array(Self.catalogLevels().prefix(5))
        all.append(contentsOf: try Self.extremeLevels())
        for level in all {
            let snap: Snapshot = Self.snapshot(level)
            for orbit in Self.orbitCorners {
                for aspect in Self.aspects {
                    let camera: VoxelOrigamiCamera = G.camera(snap, aspect: aspect, orbit: orbit)
                    for element in G.paintOrder(snap, camera: camera) {
                        let p: SIMD2<Double>? = G.project(element.centre, camera: camera)
                        #expect(p != nil)
                        guard let q = p else { continue }
                        #expect(q.x >= 0.05 && q.x <= 0.95 && q.y >= 0.05 && q.y <= 0.95,
                                "\(level.id) orbit \(orbit) aspect \(aspect) \(element.kind) at \(q)")
                    }
                    // The authored box's corners themselves keep the margin.
                    for index in 0..<8 {
                        guard let q = G.project(G.corner(index), camera: camera) else {
                            Issue.record("box corner \(index) behind the eye")
                            continue
                        }
                        #expect(q.x >= 0.05 - 1e-9 && q.x <= 0.95 + 1e-9 && q.y >= 0.05 - 1e-9 && q.y <= 0.95 + 1e-9)
                    }
                }
            }
        }
    }

    @Test func authoredOrbitCameraIsBitIdentical() throws {
        let snap: Snapshot = Self.snapshot(Self.catalogLevels()[0])
        var aspects: [Double] = Self.aspects
        aspects.append(contentsOf: [Double.nan, 0, -1, 20, 0.05])
        for aspect in aspects {
            let authored: VoxelOrigamiCamera = G.camera(snap, aspect: aspect)
            #expect(G.camera(snap, aspect: aspect, orbit: .authored) == authored)
            #expect(authored.eye == G.eye && authored.target == G.lookAt)
        }
        let camera: VoxelOrigamiCamera = G.camera(snap, aspect: 1)
        for tier in VoxelOrigamiTier.all {
            #expect(try G.voxelMesh(snap, tier: tier, reduceMotion: false, camera: camera)
                == G.voxelMesh(snap, tier: tier, reduceMotion: false))
            #expect(try G.glowMesh(snap, tier: tier, camera: camera) == G.glowMesh(snap, tier: tier))
            #expect(try G.voxelPart(snap, tier: tier, wonLevel: 0.5, camera: camera)
                == G.voxelPart(snap, tier: tier, wonLevel: 0.5))
            #expect(try G.glowPart(snap, tier: tier, camera: camera) == G.glowPart(snap, tier: tier))
        }
        // Clamping: beyond the bounds equals the corner, non-finite equals authored.
        let wild: VoxelOrigamiOrbit = VoxelOrigamiOrbit(yaw: 4, pitch: -3)
        #expect(wild.clamped() == VoxelOrigamiOrbit(yaw: VoxelOrigamiOrbit.yawLimit,
                                                    pitch: VoxelOrigamiOrbit.pitchRange.lowerBound))
        #expect(G.camera(snap, aspect: 1, orbit: wild) == G.camera(snap, aspect: 1, orbit: wild.clamped()))
        #expect(VoxelOrigamiOrbit(yaw: .nan, pitch: .infinity).clamped() == .authored)
        #expect(abs(VoxelOrigamiOrbit.yawLimit - Double.pi / 3) < 1e-15)
        #expect(abs(VoxelOrigamiOrbit.pitchRange.lowerBound + Double.pi / 9) < 1e-15)
        #expect(abs(VoxelOrigamiOrbit.pitchRange.upperBound - 35 * Double.pi / 180) < 1e-15)
        // A small orbit moves the eye: positive yaw towards +x, positive pitch upwards.
        let yawed: VoxelOrigamiCamera = G.camera(snap, aspect: 1, orbit: VoxelOrigamiOrbit(yaw: 0.1, pitch: 0))
        #expect(yawed.eye.x > G.eye.x && yawed.eye.y == G.eye.y)
        let raised: VoxelOrigamiCamera = G.camera(snap, aspect: 1, orbit: VoxelOrigamiOrbit(yaw: 0, pitch: 0.1))
        #expect(raised.eye.y > G.eye.y)
    }

    @Test func eyeStaysOutsideTheBoxAtEveryOrbitCorner() {
        let snap: Snapshot = Self.snapshot(Self.catalogLevels()[0])
        let pivot: SIMD3<Double> = (G.boxLow + G.boxHigh) / 2
        let authoredReach: Double = Self.length(G.eye - G.lookAt)
        for orbit in Self.orbitCorners {
            let camera: VoxelOrigamiCamera = G.camera(snap, aspect: 1, orbit: orbit)
            let e: SIMD3<Double> = camera.eye
            let inside: Bool = e.x >= G.boxLow.x && e.x <= G.boxHigh.x && e.y >= G.boxLow.y && e.y <= G.boxHigh.y
                && e.z >= G.boxLow.z && e.z <= G.boxHigh.z
            #expect(!inside, "orbit \(orbit) eye \(e)")
            #expect(Self.length(e - pivot) > Self.length(G.boxHigh - pivot) + 1)
            #expect(abs(Self.length(e - camera.target) - authoredReach) < 1e-9)
            // The look-at point stays on the yaw axis's height and every box corner in front of the eye.
            #expect(camera.target.y == G.lookAt.y)
            let forward: SIMD3<Double> = (camera.target - e) / Self.length(camera.target - e)
            for index in 0..<8 {
                let r: SIMD3<Double> = G.corner(index) - e
                #expect(r.x * forward.x + r.y * forward.y + r.z * forward.z > camera.near)
            }
        }
    }

    @Test func orbitedWindingSuitsBackFaceCulling() throws {
        let solids: Set<Float> = [Material.cubeFace.code, Material.cubeBevel.code, Material.glyphSolid.code,
                                  Material.glyphHollow.code, Material.dots.code]
        var levels: [VoxelOrigamiLevel] = Array(Self.catalogLevels().prefix(2))
        levels.append(try Self.extremeLevels()[2])
        for level in levels {
            let snap: Snapshot = Self.snapshot(level)
            for orbit in [Self.orbitCorners[0], Self.orbitCorners[3]] {
                let camera: VoxelOrigamiCamera = G.camera(snap, aspect: 1.2, orbit: orbit)
                let tier: VoxelOrigamiTier = VoxelOrigamiTier.all[0]
                let mesh: Mesh = try G.voxelMesh(snap, tier: tier, reduceMotion: false, camera: camera)
                let glow: Mesh = try G.glowMesh(snap, tier: tier, camera: camera)
                #expect(mesh != (try G.voxelMesh(snap, tier: tier, reduceMotion: false)))
                var front: Int = 0
                var back: Int = 0
                var flat: Int = 0
                for (m, isGlow) in [(mesh, false), (glow, true)] {
                    for t in stride(from: 0, to: m.indices.count, by: 3) {
                        let ids: [Int] = [Int(m.indices[t]), Int(m.indices[t + 1]), Int(m.indices[t + 2])]
                        var pts: [SIMD3<Double>] = []
                        var screen: [SIMD2<Double>] = []
                        for id in ids {
                            let p: SIMD3<Double> = Self.point(m, id)
                            pts.append(p)
                            if let q = G.project(p, camera: camera) { screen.append(q) }
                        }
                        guard screen.count == 3 else { continue }
                        let area: Double = (screen[1].x - screen[0].x) * (screen[0].y - screen[2].y)
                            - (screen[0].y - screen[1].y) * (screen[2].x - screen[0].x)
                        let code: Float = Float(m.uvs[ids[0]].x)
                        if !isGlow && solids.contains(code) {
                            let n: SIMD3<Double> = SIMD3(m.normals[ids[0]].x, m.normals[ids[0]].y,
                                                         m.normals[ids[0]].z)
                            let centroid: SIMD3<Double> = (pts[0] + pts[1] + pts[2]) / 3
                            let toEye: SIMD3<Double> = camera.eye - centroid
                            let facing: Double = (n.x * toEye.x + n.y * toEye.y + n.z * toEye.z) / Self.length(toEye)
                            if abs(facing) < 1e-6 || abs(area) < 1e-14 { continue }
                            if facing > 0 {
                                front += 1
                                #expect(area > 0, "orbit \(orbit): front-facing \(code) projects clockwise")
                            } else {
                                back += 1
                                #expect(area < 0, "orbit \(orbit): back-facing \(code) projects counter-clockwise")
                            }
                        } else if abs(area) > 1e-14 {
                            flat += 1
                            #expect(area > 0, "orbit \(orbit): flat item \(code) (glow \(isGlow)) projects clockwise")
                        }
                    }
                }
                #expect(front > 0 && back > 0 && flat > 0)
                // The paint order is for the orbited eye: farthest first.
                let order: [VoxelOrigamiElement] = G.paintOrder(snap, camera: camera)
                for k in 1..<order.count { #expect(order[k - 1].distance >= order[k].distance) }
            }
        }
    }
}
