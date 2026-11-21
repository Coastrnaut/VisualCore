// ColorfallCanyonsSceneGeometryTests — feature 343 (R02-G05-03) T-R02G0503-004 (FR-R02G0503-001, 006; SC-R02G0503-001,
// 003; clarifications Q1–Q3). Snapshots of real plays (fixture channel levels, seeded random levels and extreme levels:
// all heights 15 and 0, all rock, 4 × 4 and 12 × 10 grids, springs running for hundreds of ticks, a three-colour mix):
// terrain, fluid and feature meshes are finite, inside the bounding box of the tallest element and the bounding sphere,
// follow the vertex contract (terrain unit normals, unlit meshes the colour in the normal slot); every cell top, emitter
// top and basin centre (and every vertex) projects inside the view with a 5 % margin at 7 aspects 0.4 … 2.5; places are
// the same at every tier and only triangle counts change; carving lowers the block top by 0.06·u; fluid colour,
// brightness and thickness follow the palette rules; empty cells have no sheet; bands and waterfalls follow the tier and
// the drop; emitters dim; target arcs show only required colours; the camera is never singular. Plain loops and explicit
// types (CI type-check rule).
import Foundation
import Testing
@testable import ColorfallCanyonsCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct ColorfallCanyonsSceneGeometryTests {
    typealias Geometry = ColorfallCanyonsSceneGeometry
    typealias Snapshot = ColorfallCanyonsSceneSnapshot

    /// The aspects the framing is checked for.
    static let aspects: [Double] = [0.4, 0.6, 1, 1.333, 1.5, 2, 2.5]

    /// A play of `level` begun (tutorial dismissed) with `actions` applied in order; refused actions are skipped.
    static func play(_ level: ColorfallCanyonsLevel, _ actions: [ColorfallCanyonsAction]) throws -> ColorfallCanyonsPlay {
        var play: ColorfallCanyonsPlay = ColorfallCanyonsPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions where play.stage == .playing {
            try? play.apply(action, expecting: play.fingerprint)
        }
        return play
    }

    /// A snapshot of `level` after `actions`.
    static func snapshot(_ level: ColorfallCanyonsLevel, _ actions: [ColorfallCanyonsAction]) throws -> Snapshot {
        Snapshot(play: try play(level, actions), levelNumber: 1, time: 0)
    }

    /// The actions that open every closed valve of `level`, then step `ticks`.
    static func opening(_ level: ColorfallCanyonsLevel, ticks: Int) -> [ColorfallCanyonsAction] {
        var actions: [ColorfallCanyonsAction] = []
        for (index, spring) in level.springs.enumerated() where !spring.open { actions.append(.valve(index)) }
        var left: Int = ticks
        while left > 0 {
            actions.append(.step(min(left, 600)))
            left -= 600
        }
        return actions
    }

    /// An extreme level: `columns` × `rows`, every height `height`, every cell rock (`rock`) or open, three open springs
    /// (cyan, coral, yellow; release 4, supply 999) at cells 0 … 2, a basin at cell 3 and a drain at the last cell.
    static func extremeLevel(columns: Int, rows: Int, height: Int, rock: Bool) throws -> ColorfallCanyonsLevel {
        let count: Int = columns * rows
        var grounds: [ColorfallCanyonsGround] = Array(repeating: rock ? .rock : .open, count: count)
        for cell in 0..<4 { grounds[cell] = .open }
        grounds[count - 1] = .drain
        var springs: [ColorfallCanyonsSpring] = []
        for c in 0..<3 {
            springs.append(ColorfallCanyonsSpring(cell: c, color: ColorfallCanyonsColor(rawValue: c)!, release: 4,
                                                  supply: 999, open: true))
        }
        let basin: ColorfallCanyonsBasin = ColorfallCanyonsBasin(cell: 3, capacity: 999, fill: 999, shares: [400, 300, 300],
                                                                 tolerance: 100, isProtected: false, toleratedWrong: 0)
        return try ColorfallCanyonsLevel(id: "extreme-\(columns)x\(rows)-\(height)-\(rock ? "rock" : "open")", seed: 2_343,
                                         difficulty: 1, columns: columns, rows: rows,
                                         heights: Array(repeating: height, count: count), grounds: grounds,
                                         springs: springs, basins: [basin], flowRate: 8, budget: 30, tickLimit: 3_600)
    }

    /// A 4 × 4 level whose three springs (heights 15) meet in cell 5 and fall into the basin at cell 9 (height 0):
    /// cyan 0 → 4 → 5, coral 1 → 5, yellow 2 → 6 → 5, then 5 → 9; drops of 6 and 8 steps carry waterfalls.
    static func mixLevel() throws -> ColorfallCanyonsLevel {
        let heights: [Int] = [15, 15, 15, 15,
                              9, 8, 9, 12,
                              12, 0, 12, 12,
                              12, 12, 12, 0]
        var grounds: [ColorfallCanyonsGround] = Array(repeating: .open, count: 16)
        grounds[15] = .drain
        var springs: [ColorfallCanyonsSpring] = []
        for c in 0..<3 {
            springs.append(ColorfallCanyonsSpring(cell: c, color: ColorfallCanyonsColor(rawValue: c)!, release: 2,
                                                  supply: 400, open: c != 1))
        }
        let basin: ColorfallCanyonsBasin = ColorfallCanyonsBasin(cell: 9, capacity: 999, fill: 900, shares: [400, 0, 600],
                                                                 tolerance: 50, isProtected: false, toleratedWrong: 0)
        return try ColorfallCanyonsLevel(id: "mix", seed: 2_343, difficulty: 2, columns: 4, rows: 4, heights: heights,
                                         grounds: grounds, springs: springs, basins: [basin], flowRate: 3, budget: 10,
                                         tickLimit: 3_600)
    }

    /// Extreme snapshots: 4 × 4 and 12 × 10 grids at heights 15 and 0, open and all-rock, springs run 0 and 250 ticks
    /// (masses up to 1,000 per spring cell); the mix level after 40 ticks with coral opened.
    static func extremeSnapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        let sizes: [(Int, Int)] = [(4, 4), (12, 10)]
        for (columns, rows) in sizes {
            for height in [15, 0] {
                for rock in [false, true] {
                    let level: ColorfallCanyonsLevel = try extremeLevel(columns: columns, rows: rows, height: height,
                                                                        rock: rock)
                    result.append(try snapshot(level, []))
                    result.append(try snapshot(level, [.step(250)]))
                }
            }
        }
        let mix: ColorfallCanyonsLevel = try mixLevel()
        result.append(try snapshot(mix, [.valve(1), .step(40)]))
        return result
    }

    /// Snapshots of fixture channel levels 0 … 5 (valve opened, 12 ticks) and random levels 0 … 5 (valves opened,
    /// 30 ticks).
    static func playedSnapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for i in 0..<6 {
            let level: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.fixture(i).level
            result.append(try snapshot(level, opening(level, ticks: 12)))
            let random: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(i)
            result.append(try snapshot(random, opening(random, ticks: 30)))
        }
        return result
    }

    /// Every test snapshot.
    static func allSnapshots() throws -> [Snapshot] { try extremeSnapshots() + playedSnapshots() }

    /// The three coloured parts of `snapshot` at `tier`, lit first: terrain, fluid, features.
    static func parts(_ snapshot: Snapshot,
                      tier: ColorfallCanyonsTier) throws -> [(lit: Bool, part: ColorfallCanyonsColouredMesh)] {
        [(true, try Geometry.terrainPart(snapshot, tier: tier)), (false, try Geometry.fluidPart(snapshot, tier: tier)),
         (false, try Geometry.featurePart(snapshot, tier: tier))]
    }

    /// `v` as SIMD.
    static func simd(_ v: Vec3) -> SIMD3<Double> { SIMD3(v.x, v.y, v.z) }

    /// Whether `a` and `b` agree within `tolerance` per component.
    static func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ tolerance: Double = 1e-12) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
    }

    /// Whether `p` lies inside `cell`'s footprint shrunk by `inset` on every side.
    static func inside(_ p: SIMD3<Double>, cell: Int, inset: Double, _ snapshot: Snapshot) -> Bool {
        let c: SIMD3<Double> = Geometry.cellCentre(cell, snapshot)
        let h: Double = Geometry.cellSize(snapshot) / 2 - inset
        return abs(p.x - c.x) < h && abs(p.z - c.z) < h
    }

    /// The finite entries of `m`.
    static func isFinite(_ m: Mat4) -> Bool {
        var values: [Double] = []
        for c in [m.c0, m.c1, m.c2, m.c3] { values += [c.x, c.y, c.z, c.w] }
        return values.allSatisfy { $0.isFinite }
    }

    @Test func meshesAreFiniteBoundedAndFollowTheVertexContract() throws {
        for snapshot in try Self.allSnapshots() {
            let u: Double = Geometry.cellSize(snapshot)
            let halfWidth: Double = Double(snapshot.columns) * u / 2
            let halfDepth: Double = Double(snapshot.rows) * u / 2
            let tallest: Double = Geometry.tallest(snapshot)
            let radius: Double = Geometry.boundingRadius(snapshot)
            #expect(radius.isFinite && radius > 0.1 && radius < 3)
            for tier in ColorfallCanyonsTier.all {
                for (lit, part) in try Self.parts(snapshot, tier: tier) {
                    let mesh: Mesh = part.mesh
                    #expect(part.colours.count == mesh.positions.count)
                    #expect(mesh.normals.count == mesh.positions.count && mesh.uvs.count == mesh.positions.count)
                    #expect(mesh.indices.count % 3 == 0)
                    for i in 0..<mesh.positions.count {
                        let p: SIMD3<Double> = Self.simd(mesh.positions[i])
                        let n: SIMD3<Double> = Self.simd(mesh.normals[i])
                        let uv: Vec2 = mesh.uvs[i]
                        let c: Vec4 = part.colours[i]
                        let rgb: SIMD3<Double> = SIMD3(c.x, c.y, c.z)
                        #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
                        #expect(abs(p.x) <= halfWidth + 1e-12 && abs(p.z) <= halfDepth + 1e-12)
                        #expect(p.y >= -1e-12 && p.y <= tallest + 1e-12)
                        #expect(Geometry.length(p) <= radius - Geometry.boundingPad + 1e-9)
                        #expect(n.x.isFinite && n.y.isFinite && n.z.isFinite && uv.x.isFinite && uv.y.isFinite)
                        for value in [c.x, c.y, c.z, c.w] { #expect(value >= 0 && value <= 1) }
                        if lit {
                            // Terrain program: unit normal, material code 0 … 3, shade 1; colour the material's.
                            #expect(abs(Geometry.length(n) - 1) < 1e-9)
                            let material: ColorfallCanyonsShaders.TerrainMaterial? =
                                ColorfallCanyonsShaders.TerrainMaterial(rawValue: Int(uv.x))
                            #expect(material != nil && uv.x == Double(Int(uv.x)) && uv.y == 1)
                            if let material {
                                let base: SIMD3<Double> = material.colour
                                #expect(Self.near(rgb, base) || Self.near(rgb, base * 0.85) || Self.near(rgb, base * 0.65))
                            }
                        } else {
                            // Fluid program: weights ≥ 0 summing to 1, brightness 0.3 … 1, flow code 0 … 8.
                            #expect(n.x >= 0 && n.y >= 0 && n.z >= 0 && abs(n.x + n.y + n.z - 1) < 1e-12)
                            #expect(uv.x >= 0.3 - 1e-12 && uv.x <= 1)
                            #expect(uv.y >= 0 && uv.y <= 8 && uv.y == Double(Int(uv.y)))
                            #expect(Self.near(rgb, ColorfallCanyonsShaders.fluidColour(weights: n) * uv.x, 1e-12))
                        }
                    }
                    for t in 0..<(mesh.indices.count / 3) {
                        let a: Int = Int(mesh.indices[3 * t]), b: Int = Int(mesh.indices[3 * t + 1])
                        let c: Int = Int(mesh.indices[3 * t + 2])
                        #expect(a < mesh.positions.count && b < mesh.positions.count && c < mesh.positions.count)
                        let pa: SIMD3<Double> = Self.simd(mesh.positions[a])
                        let area: Double = Geometry.length(Geometry.cross(Self.simd(mesh.positions[b]) - pa,
                                                                          Self.simd(mesh.positions[c]) - pa))
                        #expect(area > 1e-14)
                    }
                }
            }
        }
    }

    @Test func everyPlaceProjectsInsideTheViewWithMargin() throws {
        let snapshots: [Snapshot] = try Self.allSnapshots()
        for snapshot in snapshots {
            var points: [SIMD3<Double>] = []
            for cell in 0..<snapshot.cellCount { points.append(Geometry.cellTop(cell, snapshot)) }
            for s in snapshot.springs.indices { points.append(Geometry.emitterTop(s, snapshot)) }
            for b in snapshot.basins.indices { points.append(Geometry.basinCentre(b, snapshot)) }
            for aspect in Self.aspects {
                let camera: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: aspect)
                for point in points {
                    let v: SIMD2<Double>? = Geometry.project(point, camera: camera)
                    #expect(v != nil)
                    guard let v else { continue }
                    #expect(v.x >= 0.05 && v.x <= 0.95 && v.y >= 0.05 && v.y <= 0.95)
                }
            }
        }
        // Every vertex of the richest tier, for the extreme snapshots.
        for snapshot in try Self.extremeSnapshots() {
            let level0: ColorfallCanyonsTier = ColorfallCanyonsTier.of(0)
            var points: [SIMD3<Double>] = []
            for (_, part) in try Self.parts(snapshot, tier: level0) {
                for p in part.mesh.positions { points.append(Self.simd(p)) }
            }
            for aspect in [0.4, 1, 2.5] {
                let camera: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: aspect)
                for point in points {
                    guard let v = Geometry.project(point, camera: camera) else {
                        Issue.record("vertex behind the camera")
                        continue
                    }
                    #expect(v.x >= 0.05 && v.x <= 0.95 && v.y >= 0.05 && v.y <= 0.95)
                }
            }
        }
    }

    @Test func placesAreTheSameAtEveryTierAndOnlyTriangleCountsChange() throws {
        for snapshot in try Self.allSnapshots() {
            let tiers: [ColorfallCanyonsTier] = ColorfallCanyonsTier.all
            var terrain: [Mesh] = []
            var fluid: [Mesh] = []
            var features: [Mesh] = []
            for tier in tiers {
                terrain.append(try Geometry.terrainMesh(snapshot, tier: tier))
                fluid.append(try Geometry.fluidMesh(snapshot, tier: tier))
                features.append(try Geometry.featureMesh(snapshot, tier: tier))
            }
            #expect(features[0] == features[1] && features[1] == features[2])
            #expect(fluid[0] == fluid[1] && fluid[1] == fluid[2])
            #expect(terrain[0].bounds == terrain[1].bounds && terrain[1].bounds == terrain[2].bounds)
            #expect(terrain[0].triangleCount > terrain[1].triangleCount)
            #expect(terrain[1].triangleCount > terrain[2].triangleCount)
            for k in 1..<3 {
                let finer: Set<Vec3> = Set(terrain[k - 1].positions)
                for p in terrain[k].positions { #expect(finer.contains(p)) }
            }
        }
    }

    @Test func carvingLowersTheBlockTopByOneStep() throws {
        for i in 0..<5 {
            let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(i)
            let level: ColorfallCanyonsLevel = fixture.level
            let valve: [ColorfallCanyonsAction] = level.springs[0].open ? [] : [.valve(0)]
            let before: Snapshot = try Self.snapshot(level, valve)
            let after: Snapshot = try Self.snapshot(level, valve + [.carve(fixture.dam)])
            #expect(after.heights[fixture.dam] == before.heights[fixture.dam] - 1)
            let u: Double = Geometry.cellSize(before)
            let a: SIMD3<Double> = Geometry.cellTop(fixture.dam, before)
            let b: SIMD3<Double> = Geometry.cellTop(fixture.dam, after)
            #expect(abs(a.y - b.y - 0.06 * u) < 1e-12)
            #expect(a.x == b.x && a.z == b.z)
            for tier in ColorfallCanyonsTier.all {
                let highest: [Double] = try [before, after].map { snapshot in
                    let mesh: Mesh = try Geometry.terrainMesh(snapshot, tier: tier)
                    var y: Double = -1
                    for p in mesh.positions where Self.inside(Self.simd(p), cell: fixture.dam, inset: 0.01 * u, snapshot) {
                        y = max(y, p.y)
                    }
                    return y
                }
                #expect(abs(highest[0] - highest[1] - 0.06 * u) < 1e-12)
                #expect(abs(highest[1] - b.y) < 1e-12)
            }
            for cell in 0..<before.cellCount where cell != fixture.dam {
                #expect(Geometry.cellTop(cell, before) == Geometry.cellTop(cell, after))
            }
        }
    }

    @Test func blockTopsFollowHeightsGroundsAndTheGridLayout() throws {
        let level: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(7)
        let snapshot: Snapshot = try Self.snapshot(level, [])
        let u: Double = Geometry.cellSize(snapshot)
        #expect(abs(u - 2 / Double(max(level.columns, level.rows))) < 1e-15)
        for cell in 0..<snapshot.cellCount {
            let c: Double = Double(cell % level.columns), r: Double = Double(cell / level.columns)
            let top: SIMD3<Double> = Geometry.cellTop(cell, snapshot)
            #expect(abs(top.x - (c - Double(level.columns - 1) / 2) * u) < 1e-12)
            #expect(abs(top.z - (r - Double(level.rows - 1) / 2) * u) < 1e-12)
            let h: Double = Double(snapshot.heights[cell])
            switch snapshot.grounds[cell] {
            case .open: #expect(abs(top.y - 0.06 * h * u) < 1e-12)
            case .rock: #expect(abs(top.y - (0.06 * h + 0.5) * u) < 1e-12)
            case .drain: #expect(top.y == 0)
            }
        }
        for s in snapshot.springs.indices {
            let e: SIMD3<Double> = Geometry.emitterTop(s, snapshot)
            #expect(Self.near(e, Geometry.cellTop(snapshot.springs[s].cell, snapshot) + SIMD3(0, 0.6 * u, 0)))
        }
        for b in snapshot.basins.indices {
            #expect(Geometry.basinCentre(b, snapshot) == Geometry.cellTop(snapshot.basins[b].cell, snapshot))
        }
        #expect(Geometry.cellTop(-1, snapshot) == .zero && Geometry.cellTop(snapshot.cellCount, snapshot) == .zero)
        #expect(Geometry.emitterTop(9, snapshot) == .zero && Geometry.basinCentre(9, snapshot) == .zero)
    }

    @Test func fluidStreamsColourBrightnessAndThicknessFollowThePalette() throws {
        var checked: Int = 0
        for snapshot in try Self.allSnapshots() {
            let u: Double = Geometry.cellSize(snapshot)
            let part: ColorfallCanyonsColouredMesh = try Geometry.fluidPart(snapshot, tier: ColorfallCanyonsTier.of(2))
            for cell in 0..<snapshot.cellCount where snapshot.volume(cell) > 0 {
                let volume: Int = snapshot.volume(cell)
                let masses: [Int] = snapshot.masses[cell]
                var mix: SIMD3<Double> = SIMD3(0, 0, 0)
                var weights: SIMD3<Double> = SIMD3(0, 0, 0)
                for color in ColorfallCanyonsColor.allCases {
                    let share: Double = Double(masses[color.rawValue]) / Double(volume)
                    mix += ColorfallCanyonsPalette.colour(color) * share
                    weights[color.rawValue] = share
                }
                let brightness: Double = 0.35 + 0.65 * Double(min(volume, 24)) / 24
                let expected: SIMD3<Double> = mix * brightness
                #expect(Self.near(Geometry.fluidColour(cell, snapshot), expected, 1e-12))
                let thickness: Double = (0.02 + 0.04 * Double(min(volume, 24)) / 24) * u
                let top: Double = Geometry.cellTop(cell, snapshot).y
                let sheetTop: Double = Geometry.sheetTop(cell, snapshot)
                #expect(abs(sheetTop - (top + 0.01 * u + thickness)) < 1e-12)
                var found: Int = 0
                for i in 0..<part.mesh.positions.count {
                    let p: SIMD3<Double> = Self.simd(part.mesh.positions[i])
                    guard Self.inside(p, cell: cell, inset: 0, snapshot), abs(p.y - sheetTop) < 1e-12 else { continue }
                    #expect(Self.near(Self.simd(part.mesh.normals[i]), weights, 1e-12))
                    #expect(abs(part.mesh.uvs[i].x - brightness) < 1e-12)
                    #expect(part.mesh.uvs[i].y == Geometry.flowCode(cell, snapshot))
                    let c: Vec4 = part.colours[i]
                    #expect(Self.near(SIMD3(c.x, c.y, c.z), expected, 1e-12))
                    found += 1
                }
                #expect(found >= 4)
                checked += 1
            }
        }
        #expect(checked > 20)
        #expect(ColorfallCanyonsPalette.fluid([5, 0, 0]) == ColorfallCanyonsPalette.cyan)
        #expect(ColorfallCanyonsPalette.fluid([0, 0, 0]) == ColorfallCanyonsPalette.night)
        #expect(ColorfallCanyonsPalette.brightness(volume: 24) == 1 && ColorfallCanyonsPalette.brightness(volume: 999) == 1)
    }

    @Test func emptyCellsHaveNoSheet() throws {
        var empty: Int = 0
        for snapshot in try Self.allSnapshots() {
            let u: Double = Geometry.cellSize(snapshot)
            for tier in ColorfallCanyonsTier.all {
                let mesh: Mesh = try Geometry.fluidMesh(snapshot, tier: tier)
                for cell in 0..<snapshot.cellCount where snapshot.volume(cell) == 0 {
                    for p in mesh.positions {
                        #expect(!Self.inside(Self.simd(p), cell: cell, inset: 0.02 * u, snapshot))
                    }
                    empty += 1
                }
            }
            let level: ColorfallCanyonsLevel = try Self.extremeLevel(columns: 4, rows: 4, height: 15, rock: false)
            let dry: Snapshot = try Self.snapshot(level, [])
            #expect(try Geometry.fluidMesh(dry, tier: ColorfallCanyonsTier.of(0)).positions.isEmpty)
        }
        #expect(empty > 100)
    }

    @Test func flowCodesFollowTheDownhillDirectionAndWaterfallsTheDrop() throws {
        var waterfalls: Int = 0
        var flowing: Int = 0
        for snapshot in try Self.allSnapshots() {
            let u: Double = Geometry.cellSize(snapshot)
            let mesh: Mesh = try Geometry.fluidMesh(snapshot, tier: ColorfallCanyonsTier.of(0))
            var falls: Int = 0
            for cell in 0..<snapshot.cellCount {
                let code: Double = Geometry.flowCode(cell, snapshot)
                let decoded: (direction: SIMD2<Double>, waterfall: Bool) = ColorfallCanyonsShaders.flowDirection(code: code)
                guard let next = snapshot.downhill[cell] else {
                    #expect(code == 0)
                    continue
                }
                let step: SIMD3<Double> = (Geometry.cellCentre(next, snapshot) - Geometry.cellCentre(cell, snapshot)) / u
                #expect(abs(decoded.direction.x - step.x) < 1e-9 && abs(decoded.direction.y - step.z) < 1e-9)
                let isFall: Bool = Geometry.drop(cell, snapshot) >= 2 - 1e-9
                #expect(decoded.waterfall == isFall && Geometry.isWaterfall(cell, snapshot) == isFall)
                if snapshot.volume(cell) > 0 {
                    flowing += 1
                    if isFall { falls += 1 }
                }
            }
            // Waterfall vertices are the only fluid vertices outside every sheet's footprint: 4 per waterfall.
            var outside: Int = 0
            for p in mesh.positions {
                var inSheet: Bool = false
                for cell in 0..<snapshot.cellCount
                where Self.inside(Self.simd(p), cell: cell, inset: (0.5 - Geometry.sheetHalf) * u - 1e-12, snapshot) {
                    inSheet = true
                }
                if !inSheet { outside += 1 }
            }
            #expect(outside == 4 * falls)
            waterfalls += falls
        }
        #expect(waterfalls > 0 && flowing > 0)
        let mix: Snapshot = try Self.snapshot(try Self.mixLevel(), [.valve(1), .step(40)])
        #expect(mix.downhill[5] == 9 && Geometry.drop(5, mix) == 8)
        #expect(Geometry.flowCode(5, mix) == 7)
        #expect(mix.masses[5].allSatisfy { $0 > 0 })
    }

    @Test func emittersDimWhenNotFlowingRimsArePearlAndArcsShowOnlyRequiredColours() throws {
        let level: ColorfallCanyonsLevel = try Self.mixLevel()
        let snapshot: Snapshot = try Self.snapshot(level, [.step(5)])
        let features: ColorfallCanyonsColouredMesh = try Geometry.featurePart(snapshot, tier: ColorfallCanyonsTier.of(1))
        let mesh: Mesh = features.mesh
        let u: Double = Geometry.cellSize(snapshot)
        for s in snapshot.springs.indices {
            let spring: Snapshot.Spring = snapshot.springs[s]
            let brightness: Double = spring.flowing ? 1 : 0.3
            #expect(spring.flowing == (s != 1))
            #expect(Geometry.emitterBrightness(s, snapshot) == brightness)
            #expect(Self.near(Geometry.emitterColour(s, snapshot), ColorfallCanyonsPalette.colour(spring.color) * brightness))
            var top: Bool = false
            for i in 0..<mesh.positions.count where Self.near(Self.simd(mesh.positions[i]), Geometry.emitterTop(s, snapshot)) {
                #expect(Self.simd(mesh.normals[i]) == Geometry.oneHot(spring.color))
                #expect(mesh.uvs[i] == Vec2(brightness, 0))
                top = true
            }
            #expect(top)
        }
        let basin: ColorfallCanyonsBasin = snapshot.basins[0]
        let arcY: Double = Geometry.basinCentre(0, snapshot).y + 0.085 * u
        var seen: Set<Int> = []
        for i in 0..<mesh.positions.count where abs(mesh.positions[i].y - arcY) < 1e-12 {
            #expect(Self.inside(Self.simd(mesh.positions[i]), cell: basin.cell, inset: 0, snapshot))
            #expect(mesh.uvs[i] == Vec2(1, 0))
            for color in ColorfallCanyonsColor.allCases where Self.simd(mesh.normals[i]) == Geometry.oneHot(color) {
                seen.insert(color.rawValue)
            }
        }
        #expect(seen == [0, 2])
        let terrain: Mesh = try Geometry.terrainMesh(snapshot, tier: ColorfallCanyonsTier.of(1))
        var rim: Int = 0
        for i in 0..<terrain.positions.count where terrain.uvs[i].x == 2 {
            #expect(abs(terrain.positions[i].y - (Geometry.basinCentre(0, snapshot).y + 0.08 * u)) < 1e-12)
            #expect(Self.inside(Self.simd(terrain.positions[i]), cell: basin.cell, inset: 0, snapshot))
            rim += 1
        }
        #expect(rim == 2 * Geometry.rimSegments)
        for cell in 0..<snapshot.cellCount {
            let expected: ColorfallCanyonsShaders.TerrainMaterial =
                snapshot.grounds[cell] == .drain ? .pit : (snapshot.grounds[cell] == .rock ? .rock : .sandstone)
            #expect(Geometry.material(cell, snapshot) == expected)
        }
    }

    @Test func cameraIsNeverSingular() throws {
        let odd: [Double] = [0, -1, .nan, .infinity, -.infinity, 1e-9, 1e9, 0.4, 2.5]
        for snapshot in try Self.extremeSnapshots() {
            for aspect in odd {
                let camera: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: aspect)
                #expect(camera.eye.x.isFinite && camera.eye.y.isFinite && camera.eye.z.isFinite)
                #expect(camera.aspect.isFinite && camera.aspect >= 0.1 && camera.aspect <= 10)
                #expect(camera.near > 0 && camera.far > camera.near && camera.far.isFinite)
                #expect(Self.isFinite(camera.view) && Self.isFinite(camera.projection))
                #expect(Self.isFinite(camera.viewProjection))
                #expect(camera.eye.z > 0 && camera.eye.y > 0 && abs(camera.eye.x) < 1e-12)
                let pitch: Double = atan2(camera.eye.y, camera.eye.z)
                #expect(abs(pitch - 50 * Double.pi / 180) < 1e-12)
                #expect(Geometry.length(camera.eye) - camera.radius > camera.near)
                let centre: SIMD2<Double>? = Geometry.project(.zero, camera: camera)
                #expect(centre != nil)
                if let centre { #expect(abs(centre.x - 0.5) < 1e-9 && abs(centre.y - 0.5) < 1e-9) }
            }
            let one: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: 1)
            #expect(Geometry.camera(snapshot, aspect: .nan) == one && Geometry.camera(snapshot, aspect: 0) == one)
            #expect(Geometry.project(SIMD3(.nan, 0, 0), camera: one) == nil)
            #expect(Geometry.project(one.eye * 2, camera: one) == nil)
        }
    }
}
