// BinaryGardensSceneGeometryTests — feature 503 (R02-G21-03) T-R02G2103-004 (FR-R02G2103-001, 002, 003, 004, 006,
// 007, 010; SC-R02G2103-001, 003; clarifications Q1–Q4, Q6; research R1–R4, R7–R11). The system geometry: the fit rule
// and the CPU reference places; finite and bounded meshes for the extreme settings (1 and 5 worlds, 2 and 8 rings,
// radii 1 and 60 units, tilt 0 and 6, a star and a world at the same point, a world held still, retrograde worlds, flux
// 0 and 128 000 milliflux, budgets 1 and 24) at every tier; every body exactly on a vertex of its drawn orbit; every
// element inside the view with a margin at 7 aspects over the catalog's levels (two per difficulty band; the authored
// box holds every vertex and the camera holds the box); the same positions at every tier; the cube-sphere's vertices on
// the unit sphere and its face counts per tier, its quads emitted far-first; the painter's order (bodies back to front,
// worlds before stars on a tie); cell heights, window brackets (wrapping and empty), required ticks and bloom markers
// from the kernel's values only; trail ticks cyclic; a won level in place; the glow mesh empty at level-2 and its shell
// counts per tier; each failure kind marked on a failed play only (never for a predicted failure); the streams of
// `BinaryGardensShaders` (encoded codes, quad-local normals at ±1.25, world normals and shares, the backdrop's plane
// offsets and height); the backdrop filling the view and its gradient coordinate; the fallback colours. Explicit
// types, plain loops.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import BinaryGardensCore

@Suite struct BinaryGardensSceneGeometryTests {
    typealias G = BinaryGardensSceneGeometry
    typealias Snapshot = BinaryGardensSceneSnapshot
    typealias Material = BinaryGardensMaterial

    /// The sampled catalog levels (numbers 1 … 100): two per difficulty band.
    static let sampleNumbers: [Int] = [1, 2, 21, 22, 41, 42, 61, 62, 81, 82]

    /// The sampled certified levels, certified once per process.
    static let levels: [BinaryGardensLevel] = {
        var result: [BinaryGardensLevel] = []
        for number in sampleNumbers {
            do {
                result.append(try BinaryGardensExperienceCore.level(number: number))
            } catch {
                fatalError("level \(number) does not certify: \(error)")
            }
        }
        return result
    }()

    /// The seven aspects checked.
    static let aspects: [Double] = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]

    /// A snapshot of `level` in stage `playing` at shown tick `tick`.
    static func snapshot(_ level: BinaryGardensLevel, tick: Int = 24, number: Int = 1,
                         time: Double = 0) throws -> Snapshot {
        var play: BinaryGardensPlay = BinaryGardensPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return Snapshot(play: play, shownTick: tick, levelNumber: number, time: time)
    }

    /// `base` with the given values replaced (the unchecked initialiser).
    static func variant(_ base: Snapshot, worlds: [BinaryGardensSceneWorld]? = nil,
                        failure: BinaryGardensFailure?? = nil, stage: BinaryGardensStage? = nil,
                        shownTick: Int? = nil, actionsLeft: Int? = nil) -> Snapshot {
        Snapshot(ringRadii: base.ringRadii, luminosityLevels: base.luminosityLevels, maxTilt: base.maxTilt,
                 phaseStep: base.phaseStep, lethalTolerance: base.lethalTolerance, worlds: worlds ?? base.worlds,
                 arrangement: base.arrangement, starPositions: base.starPositions,
                 shownTick: shownTick ?? base.shownTick, failure: failure ?? base.failure, stage: stage ?? base.stage,
                 actionsLeft: actionsLeft ?? base.actionsLeft, budget: base.budget, levelNumber: base.levelNumber,
                 time: base.time)
    }

    /// `world` with its light replaced (flux, bands, window, start, integral).
    static func relit(_ world: BinaryGardensSceneWorld, flux: [Int]? = nil, bands: [BinaryGardensBand]? = nil,
                      longestWindow: Int? = nil, windowStart: Int? = nil, integral: Int? = nil,
                      window: Int? = nil) -> BinaryGardensSceneWorld {
        BinaryGardensSceneWorld(radius: world.radius, phase: world.phase, speed: world.speed,
                                lethalLow: world.lethalLow, comfortLow: world.comfortLow,
                                comfortHigh: world.comfortHigh, lethalHigh: world.lethalHigh,
                                window: window ?? world.window, bloomLow: world.bloomLow, bloomHigh: world.bloomHigh,
                                positions: world.positions, flux: flux ?? world.flux, shares: world.shares,
                                bands: bands ?? world.bands, longestLethalRun: world.longestLethalRun,
                                longestWindow: longestWindow ?? world.longestWindow,
                                windowStart: windowStart ?? world.windowStart, integral: integral ?? world.integral,
                                bloom: world.bloom)
    }

    /// An extreme snapshot built from the kernel's own positions: `rings` ring radii (1 … 40 spread), `worlds`
    /// worlds of radius `worldRadius` (speeds 0, −4, 4, … : a world held still and retrograde ones), both stars on
    /// the largest ring at tilt `tilt` with star 1 at world 0's start phase when the radii match (the same point),
    /// fluxes alternating 0 and 128 000 milliflux with every band, budget `budget`, tick 48 shown (where star 1 and
    /// world 0 meet when their radii match).
    static func extreme(rings: Int, worlds count: Int, worldRadius: Int, tilt: Int, budget: Int,
                        failure: BinaryGardensFailure? = nil, stage: BinaryGardensStage = .playing,
                        time: Double = 0) -> Snapshot {
        var ringRadii: [Int] = []
        for k in 0..<rings { ringRadii.append(rings == 1 ? 1 : 1 + k * 39 / max(rings - 1, 1)) }
        let speeds: [Int] = [0, -4, 4, -1, 2]
        let bands: [BinaryGardensBand] = BinaryGardensBand.allCases
        var worlds: [BinaryGardensSceneWorld] = []
        for j in 0..<count {
            var positions: [BinaryGardensPoint] = []
            var flux: [Int] = []
            var shares: [[Int]] = []
            var tickBands: [BinaryGardensBand] = []
            for tick in 1...48 {
                let phase: Int = BinaryGardensSky.phase(5 * j, speed: speeds[j % speeds.count], tick: tick)
                positions.append(BinaryGardensSky.worldPosition(radius: worldRadius, phase: phase))
                let f: Int = tick % 2 == 0 ? 0 : 128_000
                flux.append(f)
                shares.append([f / 2, f / 2])
                tickBands.append(bands[(tick + j) % bands.count])
            }
            worlds.append(BinaryGardensSceneWorld(radius: worldRadius, phase: 5 * j, speed: speeds[j % speeds.count],
                                                  lethalLow: 10, comfortLow: 20, comfortHigh: 30, lethalHigh: 40,
                                                  window: 48, bloomLow: 100, bloomHigh: 6_144_000,
                                                  positions: positions, flux: flux, shares: shares, bands: tickBands,
                                                  longestLethalRun: 1, longestWindow: j == 0 ? 0 : 40,
                                                  windowStart: j == 0 ? 0 : 30, integral: 3_072_000 * j,
                                                  bloom: .inside))
        }
        var stars: [[BinaryGardensPoint]] = []
        let top: Int = ringRadii[ringRadii.count - 1]
        for tick in 1...48 {
            let one: BinaryGardensPoint = BinaryGardensSky.starPosition(radius: top, phase: tick % 48, tilt: tilt)
            let two: BinaryGardensPoint = BinaryGardensSky.starPosition(radius: top, phase: (tick + 24) % 48,
                                                                        tilt: tilt)
            stars.append([one, two])
        }
        let arrangement = BinaryGardensArrangement(rings: [rings - 1, rings - 1], phases: [0, 24],
                                                   luminosities: [0, 3], tilt: tilt)
        return Snapshot(ringRadii: ringRadii, luminosityLevels: [1, 20, 40, 64], maxTilt: 6, phaseStep: 1,
                        lethalTolerance: 12, worlds: worlds, arrangement: arrangement, starPositions: stars,
                        shownTick: 48, failure: failure, stage: stage, actionsLeft: budget / 2, budget: budget,
                        levelNumber: 1, time: time)
    }

    /// The extreme snapshots of the task.
    static func extremes() -> [Snapshot] {
        [extreme(rings: 2, worlds: 1, worldRadius: 1, tilt: 0, budget: 1),
         extreme(rings: 8, worlds: 5, worldRadius: 60, tilt: 6, budget: 24),
         extreme(rings: 8, worlds: 5, worldRadius: 40, tilt: 6, budget: 24),
         extreme(rings: 2, worlds: 5, worldRadius: 1, tilt: 3, budget: 1,
                 failure: .scorched(world: 4, tick: 60), stage: .failed, time: 123.4),
         extreme(rings: 8, worlds: 1, worldRadius: 60, tilt: 0, budget: 24,
                 failure: .unstable(world: 0, window: 0, required: 48), stage: .failed)]
    }

    /// The decoded a_uv.x of vertex `k` of a system mesh.
    static func decoded(_ mesh: Mesh, _ k: Int) -> (material: Material, value: Double, broken: Bool) {
        BinaryGardensShaders.decode(mesh.uvs[k].x)
    }

    /// The positions of `mesh`'s vertices whose material is in `materials` (and whose broken mark is `broken`, when
    /// given).
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

    /// The materials marked broken in `mesh`.
    static func brokenMaterials(_ mesh: Mesh) -> Set<Material> {
        var result: Set<Material> = []
        for k in mesh.positions.indices where decoded(mesh, k).broken { result.insert(decoded(mesh, k).material) }
        return result
    }

    /// The positions of `points` as a sorted list of rounded strings (order-free comparison).
    static func key(_ points: [SIMD3<Double>]) -> [String] {
        var keys: [String] = []
        for p in points { keys.append(String(format: "%.9f %.9f %.9f", p.x, p.y, p.z)) }
        return Set(keys).sorted()
    }

    /// Whether `point` lies in the authored box.
    static func inBox(_ point: SIMD3<Double>) -> Bool {
        let tolerance: Double = 1e-9
        return point.x >= G.boxLow.x - tolerance && point.x <= G.boxHigh.x + tolerance
            && point.y >= G.boxLow.y - tolerance && point.y <= G.boxHigh.y + tolerance
            && point.z >= G.boxLow.z - tolerance && point.z <= G.boxHigh.z + tolerance
    }

    /// Whether `point` projects inside the view with a margin of at least 5 % on each side.
    static func inView(_ point: SIMD3<Double>, _ camera: BinaryGardensCamera) -> Bool {
        guard let p = G.project(point, camera: camera) else { return false }
        return p.x >= 0.05 && p.x <= 0.95 && p.y >= 0.05 && p.y <= 0.95
    }

    /// The distance between `a` and `b`.
    static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d: SIMD3<Double> = a - b
        return (d * d).sum().squareRoot()
    }

    /// Checks that a system mesh is finite, well indexed, bounded (every vertex but the backdrop's in the box; a mote
    /// on every point of its loop) and follows the streams of `BinaryGardensShaders`.
    static func checkSystem(_ mesh: Mesh) {
        checkIndices(mesh)
        let e: Double = BinaryGardensShaders.quadExtent
        for k in mesh.positions.indices {
            let p: Vec3 = mesh.positions[k]
            let n: Vec3 = mesh.normals[k]
            let uv: Vec2 = mesh.uvs[k]
            var finite: Bool = true
            for v in [p.x, p.y, p.z, n.x, n.y, n.z, uv.x, uv.y] where !v.isFinite { finite = false }
            #expect(finite)
            let d = decoded(mesh, k)
            #expect(abs(uv.x - BinaryGardensShaders.encode(d.material, value: d.value, broken: d.broken)) < 1e-9)
            let length: Double = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
            if d.material == .backdrop {
                #expect(n.z == 0 && uv.y >= 0 && uv.y <= 1)
                continue
            }
            if d.material.isWorld {
                #expect(abs(length - 1) < 1e-9 && uv.y >= 0 && uv.y <= 1, "\(d.material)")
            } else if d.material == .gaugePlate {
                #expect(abs(abs(n.x) - 1) < 1e-12 && abs(abs(n.y) - e) < 1e-12 && n.z == 0 && uv.y == 0)
            } else {
                #expect(abs(abs(n.x) - e) < 1e-12 && abs(abs(n.y) - e) < 1e-12 && uv.y == 0, "\(d.material)")
                switch d.material {
                case .ringShared: #expect(n.z == 0 || n.z == 1)
                case .corona: #expect(n.z == 0 || n.z == 1)
                case .mote: #expect(n.z == BinaryGardensShaders.moteLoopRadius)
                default: #expect(n.z == 0, "\(d.material)")
                }
            }
            let point: SIMD3<Double> = SIMD3(p.x, p.y, p.z)
            if d.material == .mote {
                let r: Double = n.z
                #expect(inBox(point) && inBox(point + SIMD3(-2 * r, 0, 0)) && inBox(point + SIMD3(-r, r, 0))
                        && inBox(point + SIMD3(-r, -r, 0)))
            } else {
                #expect(inBox(point), "\(d.material) vertex at \(p.x), \(p.y), \(p.z)")
            }
        }
    }

    /// Checks that a glow mesh is finite, well indexed, bounded and follows the glow stream (a_normal a colour or
    /// zero, kind and factor in a_uv.x, a_uv.y 0 or 1).
    static func checkGlow(_ mesh: Mesh) {
        checkIndices(mesh)
        for k in mesh.positions.indices {
            let n: Vec3 = mesh.normals[k]
            let uv: Vec2 = mesh.uvs[k]
            #expect(n.x >= 0 && n.x <= 1 && n.y >= 0 && n.y <= 1 && n.z >= 0 && n.z <= 1)
            #expect(uv.x >= 0 && uv.x <= 3 && (uv.y == 0 || uv.y == 1))
            let p: Vec3 = mesh.positions[k]
            #expect(inBox(SIMD3(p.x, p.y, p.z)))
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

    // MARK: Places

    @Test func fitRuleAndReferencePlaces() throws {
        let snapshot: Snapshot = try Self.snapshot(Self.levels[0])
        // Level 1: rings 5, 6, 8, one world of radius 24: k = 0.95 / 24.
        #expect(abs(snapshot.fitScale - 0.95 / 24) < 1e-15)
        #expect(G.fitScale(ringRadii: [5, 6, 8], worldRadii: [24]) == snapshot.fitScale)
        #expect(G.position(BinaryGardensPoint(x: 1 << 20, y: -(1 << 21), z: 0), scale: 0.5) == SIMD3(0.5, -1, 0))
        let points: [BinaryGardensReferencePoint] = G.referencePoints(snapshot)
        #expect(points.count == 1 + snapshot.worlds.count + 2 + 2)
        #expect(points[0].kind == .barycentre && points[0].centre == SIMD3(0, 0, 0))
        #expect(points[1].kind == .world && points[1].centre == G.worldCentre(0, snapshot))
        #expect(points[2].kind == .star && points[3].kind == .star && points[3].index == 1)
        #expect(points[4].kind == .gaugeMargin && points[4].centre == SIMD3(-0.925, -1.2, 0))
        #expect(points[5].kind == .actionsBar && points[5].centre == G.actionsBar(0, snapshot))
        #expect(G.gaugeY(0) == -1.2 && abs(G.gaugeY(4) + 1.6) < 1e-12)
        #expect(abs(G.actionsY(snapshot) - (-1.2 - 0.1 * Double(snapshot.worlds.count) - 0.03)) < 1e-12)
        #expect(G.starRadius(luminosityIndex: 0) == 0.05 && abs(G.starRadius(luminosityIndex: 3) - 0.086) < 1e-12)
        #expect(G.tiltPipCentre(0) == SIMD3(-1.15, 1.08, 0) && abs(G.tiltPipCentre(6).x + 0.85) < 1e-12)
        #expect(abs(G.cellX(1) - (-0.9 + 0.5 * 1.8 / 48)) < 1e-12 && abs(G.cellX(48) - (0.9 - 0.5 * 1.8 / 48)) < 1e-12)
        #expect(G.cellHeight(flux: 0, lethalHigh: 100) == 0.01)
        #expect(abs(G.cellHeight(flux: 500, lethalHigh: 100) - 0.07) < 1e-12)
        #expect(abs(G.cellHeight(flux: 50, lethalHigh: 100) - 0.04) < 1e-12)
        #expect(G.bloomX(0, bloomHigh: 100) == 0.97 && abs(G.bloomX(200, bloomHigh: 100) - 1.2) < 1e-12)
        #expect(abs(G.bloomX(900, bloomHigh: 100) - 1.2) < 1e-12 && G.bloomTop(0) == 1)
        #expect(G.failureColumn(1) == 1 && G.failureColumn(48) == 48 && G.failureColumn(60) == 12)
        #expect(G.trailTicks(shownTick: 3, count: 4) == [2, 1, 48, 47])
        #expect(G.trailTicks(shownTick: 48, count: 8) == [47, 46, 45, 44, 43, 42, 41, 40])
        #expect(G.trailTicks(shownTick: 10, count: 0).isEmpty)
        // The star uniforms are the stars' centres at the shown tick.
        let uniforms: (SIMD3<Double>, SIMD3<Double>) = G.starUniforms(snapshot)
        #expect(uniforms.0 == G.starCentre(0, snapshot) && uniforms.1 == G.starCentre(1, snapshot))
    }

    @Test func everyBodyStandsOnAVertexOfItsDrawnOrbit() throws {
        for level in Self.levels {
            for tick in [1, 13, 24, 48] {
                let snapshot: Snapshot = try Self.snapshot(level, tick: tick)
                let k: Double = snapshot.fitScale
                for star in 0..<2 {
                    let ring: Int = snapshot.ringRadii[snapshot.arrangement.rings[star]]
                    var nearest: Double = Double.infinity
                    for step in 0..<48 {
                        let vertex: SIMD3<Double> = G.ringVertex(radius: ring, step: step,
                                                                 tilt: snapshot.arrangement.tilt, scale: k)
                        nearest = min(nearest, Self.distance(vertex, G.starCentre(star, snapshot)))
                    }
                    #expect(nearest == 0, "star \(star) is exactly a vertex of its ring")
                }
                for world in snapshot.worlds.indices {
                    var nearest: Double = Double.infinity
                    for step in 0..<48 {
                        let vertex: SIMD3<Double> = G.orbitVertex(radius: snapshot.worlds[world].radius, step: step,
                                                                  scale: k)
                        nearest = min(nearest, Self.distance(vertex, G.worldCentre(world, snapshot)))
                    }
                    #expect(nearest == 0, "world \(world) is exactly a vertex of its orbit")
                    // Within the fit disc (the integer table points lie within 2e-4 of the unit circle).
                    #expect(Self.distance(G.worldCentre(world, snapshot), SIMD3(0, 0, 0)) <= 0.95 * 1.0002)
                }
            }
        }
        // The 48-gons use the kernel's table points: vertex 12 of a ring at tilt 0 is (0, ρ, 0) · k.
        #expect(G.ringVertex(radius: 8, step: 12, tilt: 0, scale: 0.1) == SIMD3(0, 0.8, 0))
        #expect(G.orbitVertex(radius: 10, step: 24, scale: 0.1) == SIMD3(-1, 0, 0))
        let tilted: SIMD3<Double> = G.ringVertex(radius: 8, step: 12, tilt: 6, scale: 0.1)
        #expect(abs(tilted.y - 0.8 * 724 / 1024) < 1e-12 && abs(tilted.z - 0.8 * 724 / 1024) < 1e-12)
    }

    @Test func paintOrderSortsTheBodiesBackToFront() throws {
        for level in Self.levels {
            let snapshot: Snapshot = try Self.snapshot(level)
            let order: [BinaryGardensElement] = G.paintOrder(snapshot)
            #expect(order.first?.kind == .backdrop)
            var lastRank: Int = -1
            var lastBody: Double = Double.infinity
            var bodies: Int = 0
            for element in order {
                let rank: Int = element.kind == .star ? BinaryGardensElement.Kind.world.rawValue : element.kind.rawValue
                #expect(rank >= lastRank, "kinds in order")
                lastRank = rank
                if element.kind.isBody {
                    let d: Double = Self.distance(element.centre, G.eye)
                    #expect(d <= lastBody + 1e-12, "bodies back to front")
                    lastBody = d
                    bodies += 1
                }
            }
            #expect(bodies == snapshot.worlds.count + 2)
            #expect((snapshot.maxTilt > 0) == order.contains { $0.kind == .tiltDial })
            #expect(order.filter { $0.kind == .ring }.count == snapshot.ringRadii.count)
            #expect(order.filter { $0.kind == .actions }.count == snapshot.budget)
            #expect(order.last?.kind == .glow)
        }
        // A tie: a world before a star; then by index.
        let star = BinaryGardensElement(kind: .star, index: 0, item: 0, centre: SIMD3(0, 0, 0))
        let world = BinaryGardensElement(kind: .world, index: 3, item: 3, centre: SIMD3(0, 0, 0))
        let far = BinaryGardensElement(kind: .star, index: 1, item: 1, centre: SIMD3(0, 5, 0))
        #expect(BinaryGardensElement.drawsBefore(world, star, eye: G.eye))
        #expect(!BinaryGardensElement.drawsBefore(star, world, eye: G.eye))
        #expect(BinaryGardensElement.drawsBefore(far, world, eye: G.eye), "the farther body first")
    }

    // MARK: Cube-sphere

    @Test func cubeSphereVerticesLieOnTheUnitSphere() {
        for tier in BinaryGardensTier.all {
            let n: Int = tier.faceQuads
            let sphere = G.cubeSphere(faceQuads: n)
            #expect(sphere.positions.count == 6 * (n + 1) * (n + 1))
            #expect(sphere.triangles.count == 6 * 2 * n * n)
            #expect(sphere.normals == sphere.positions)
            for p in sphere.positions { #expect(abs((p * p).sum().squareRoot() - 1) < 1e-12) }
            for t in sphere.triangles {
                let a: SIMD3<Double> = sphere.positions[t.x]
                let b: SIMD3<Double> = sphere.positions[t.y]
                let c: SIMD3<Double> = sphere.positions[t.z]
                let normal: SIMD3<Double> = G.cross(b - a, c - a)
                #expect(G.dot(normal, a + b + c) > 0, "wound counter-clockwise seen from outside")
            }
        }
        #expect(G.cubeSphere(faceQuads: 0).triangles.count == 12)
    }

    @Test func aWorldEmitsItsQuadsFarFirst() throws {
        let snapshot: Snapshot = try Self.snapshot(Self.levels[0])
        let mesh: Mesh = try G.systemMesh(snapshot, tier: BinaryGardensTier.of(0))
        let centre: SIMD3<Double> = G.worldCentre(0, snapshot)
        var previous: Double = Double.infinity
        var triangles: Int = 0
        var t: Int = 0
        while t + 2 < mesh.indices.count {
            let a: Int = Int(mesh.indices[t])
            if Self.decoded(mesh, a).material.isWorld {
                var mid: SIMD3<Double> = SIMD3(0, 0, 0)
                for j in 0..<3 {
                    let p: Vec3 = mesh.positions[Int(mesh.indices[t + j])]
                    mid += SIMD3(p.x, p.y, p.z) / 3
                }
                let d: Double = Self.distance(mid, G.eye)
                // Quads come far-first; a triangle may sit up to a quad's span nearer than the quad's centre.
                #expect(d <= previous + 0.03)
                previous = min(previous, d)
                #expect(abs(Self.distance(mid, centre)) <= G.worldRadius + 1e-9)
                triangles += 1
            }
            t += 3
        }
        #expect(triangles == 6 * 2 * 64)
    }

    // MARK: Meshes

    @Test func extremeSettingsAreFiniteBoundedAndFollowTheStreams() throws {
        for snapshot in Self.extremes() {
            for tier in BinaryGardensTier.all {
                let part: BinaryGardensColouredMesh = try G.systemPart(snapshot, tier: tier)
                #expect(part.colours.count == part.mesh.positions.count)
                Self.checkSystem(part.mesh)
                Self.checkGlow(try G.glowMesh(snapshot, tier: tier))
                for colour in part.colours {
                    #expect(colour.x >= 0 && colour.x <= 1 && colour.y >= 0 && colour.y <= 1 && colour.w == 1)
                }
                #expect(part.mesh.indices.count / 3 < 40_000)
            }
        }
    }

    @Test func cameraHoldsTheBoxAtSevenAspects() {
        for aspect in Self.aspects {
            let camera: BinaryGardensCamera = G.camera(aspect: aspect)
            #expect(camera.eye == SIMD3(0, -2.0, 3.2) && camera.target == SIMD3(0, -0.35, 0))
            for index in 0..<8 { #expect(Self.inView(G.corner(index), camera), "corner \(index) at \(aspect)") }
            #expect(camera.fovY > 0 && camera.fovY < Double.pi)
        }
        #expect(G.camera(aspect: .nan).aspect == 1 && G.camera(aspect: 0).aspect == 1)
        #expect(G.camera(aspect: 100).aspect == 10)
    }

    @Test func everyElementInsideTheViewOverCatalogLevels() throws {
        for level in Self.levels {
            let snapshot: Snapshot = try Self.snapshot(level)
            let mesh: Mesh = try G.systemMesh(snapshot, tier: BinaryGardensTier.of(0))
            Self.checkSystem(mesh)
            Self.checkGlow(try G.glowMesh(snapshot, tier: BinaryGardensTier.of(0)))
            for aspect in Self.aspects {
                let camera: BinaryGardensCamera = G.camera(aspect: aspect)
                for point in G.referencePoints(snapshot) {
                    #expect(Self.inView(point.centre, camera), "\(point.kind) at \(aspect)")
                }
            }
        }
    }

    @Test func samePositionsAtEveryTier() throws {
        let fixed: Set<Material> = [.tiltPipLit, .tiltPipUnlit, .ringIdle, .ringStarOne, .ringStarTwo, .ringShared,
                                    .orbit, .worldPip, .starOne, .starTwo, .luminosityPipLit, .luminosityPipUnlit,
                                    .gaugePlate, .cellLethalLow, .cellDim, .cellComfortable, .cellBright,
                                    .cellLethalHigh, .guide, .windowBracket, .windowBracketShort, .requiredTick,
                                    .tickMarker, .bloomTrack, .bloomBracket, .bloomMarker, .actionsLit,
                                    .actionsUnlit, .backdrop]
        for level in [Self.levels[0], Self.levels[5], Self.levels[9]] {
            let snapshot: Snapshot = try Self.snapshot(level)
            var keys: [[String]] = []
            var references: [[BinaryGardensReferencePoint]] = []
            var trails: [Int] = []
            var rays: [Int] = []
            for tier in BinaryGardensTier.all {
                let mesh: Mesh = try G.systemMesh(snapshot, tier: tier)
                keys.append(Self.key(Self.positions(mesh, fixed)))
                references.append(G.referencePoints(snapshot))
                trails.append(Self.positions(mesh, [.trail]).count)
                rays.append(Self.positions(mesh, [.corona]).count)
            }
            #expect(keys[0] == keys[1] && keys[1] == keys[2], "the shared content is the same at every tier")
            #expect(references[0] == references[1] && references[1] == references[2])
            #expect(trails[0] > trails[1] && trails[1] > 0 && trails[2] == 0)
            #expect(rays[0] > rays[1] && rays[1] > 0 && rays[2] == 0)
            // The tier only tessellates the worlds more or less finely; their centres stay.
            let dots: [(centre: SIMD3<Double>, freshness: Double)] = G.trailDots(snapshot, tier: .of(0))
            #expect(dots.count == 8 * (2 + snapshot.worlds.count))
            #expect(dots[0].freshness > dots[dots.count - 1].freshness)
        }
    }

    @Test func ringsAreDashedIdleSolidForAStarAndSharedForBoth() throws {
        // Level 1: both stars on ring 0 (shared), rings 1 and 2 idle.
        let snapshot: Snapshot = try Self.snapshot(Self.levels[0])
        #expect(snapshot.arrangement.rings == [0, 0])
        #expect(G.ringMaterial(0, snapshot).material == .ringShared && !G.ringMaterial(0, snapshot).dashed)
        #expect(G.ringMaterial(1, snapshot).material == .ringIdle && G.ringMaterial(1, snapshot).dashed)
        let mesh: Mesh = try G.systemMesh(snapshot, tier: .of(2))
        var shared: Int = 0
        var parities: Set<Double> = []
        for k in mesh.positions.indices where Self.decoded(mesh, k).material == .ringShared {
            shared += 1
            parities.insert(mesh.normals[k].z)
        }
        #expect(shared > 0 && parities == [0, 1], "a shared ring alternates both colours")
        let idle: Int = Self.positions(mesh, [.ringIdle]).count
        let orbits: Int = Self.positions(mesh, [.orbit]).count
        #expect(idle > 0 && orbits > 0)
        // One star moved: its own ring solid in its colour.
        let moved: Snapshot = Snapshot(ringRadii: snapshot.ringRadii, luminosityLevels: snapshot.luminosityLevels,
                                       maxTilt: 0, phaseStep: 8, lethalTolerance: 7, worlds: snapshot.worlds,
                                       arrangement: BinaryGardensArrangement(rings: [0, 2], phases: [32, 16],
                                                                             luminosities: [1, 1], tilt: 0),
                                       starPositions: snapshot.starPositions, shownTick: 24, failure: nil,
                                       stage: .playing, actionsLeft: 8, budget: 9, levelNumber: 1, time: 0)
        #expect(G.ringMaterial(0, moved).material == .ringStarOne && G.ringMaterial(2, moved).material == .ringStarTwo)
        #expect(G.ringMaterial(1, moved).dashed)
    }

    @Test func gaugesComeFromTheKernelValuesOnly() throws {
        let base: Snapshot = try Self.snapshot(Self.levels[2])
        let world: BinaryGardensSceneWorld = base.worlds[0]
        let mesh: Mesh = try G.systemMesh(base, tier: .of(2))
        // 48 cells per world, each as tall as 0.01 + 0.06 · min(1, F/λ_hi) and in its band's material.
        var cellVertices: Int = 0
        let cells: Set<Material> = [.cellLethalLow, .cellDim, .cellComfortable, .cellBright, .cellLethalHigh]
        for k in mesh.positions.indices where cells.contains(Self.decoded(mesh, k).material) { cellVertices += 1 }
        #expect(cellVertices == 4 * 48 * base.worlds.count)
        for tick in [1, 17, 48] {
            let height: Double = G.cellHeight(flux: world.flux[tick - 1], lethalHigh: world.lethalHigh)
            let material: Material = Material.cell(world.bands[tick - 1])
            let e: Double = BinaryGardensShaders.quadExtent
            var found: Bool = false
            for k in mesh.positions.indices where Self.decoded(mesh, k).material == material {
                let p: Vec3 = mesh.positions[k]
                if abs(p.x - (G.cellX(tick) + e * 0.8 * G.cellPitch / 2)) < 1e-9
                    && abs(p.y - (G.baseline(0) + height / 2 + e * height / 2)) < 1e-9 {
                    found = true
                }
            }
            #expect(found, "cell \(tick) stands at its kernel height")
        }
        // Window brackets: one piece, two pieces when the window wraps, none without a comfortable tick.
        let one: BinaryGardensSceneWorld = Self.relit(world, longestWindow: 10, windowStart: 5, window: 8)
        #expect(G.windowPieces(one).count == 1 && G.windowPieces(one)[0].first == 5 && G.windowPieces(one)[0].last == 14)
        let wrap: BinaryGardensSceneWorld = Self.relit(world, longestWindow: 10, windowStart: 44, window: 8)
        #expect(G.windowPieces(wrap).count == 2 && G.windowPieces(wrap)[1].last == 5)
        let whole: BinaryGardensSceneWorld = Self.relit(world, longestWindow: 48, windowStart: 1, window: 48)
        #expect(G.windowPieces(whole).count == 1 && G.windowPieces(whole)[0].last == 48)
        let empty: BinaryGardensSceneWorld = Self.relit(world, longestWindow: 0, windowStart: 0, window: 8)
        #expect(G.windowPieces(empty).isEmpty)
        // The required tick: W cells after the window's start (cyclic), or after tick 0 when there is no window.
        #expect(abs(G.requiredX(one) - (-0.9 + 12 * G.cellPitch)) < 1e-12)
        #expect(abs(G.requiredX(wrap) - (-0.9 + 3 * G.cellPitch)) < 1e-12)
        #expect(abs(G.requiredX(empty) - (-0.9 + 8 * G.cellPitch)) < 1e-12)
        // Solid when the window reaches W, dashed otherwise.
        let solidMesh: Mesh = try G.systemMesh(Self.variant(base, worlds: [one] + Array(base.worlds.dropFirst())),
                                               tier: .of(2))
        let shortWorld: BinaryGardensSceneWorld = Self.relit(world, longestWindow: 10, windowStart: 5, window: 12)
        let shortMesh: Mesh = try G.systemMesh(Self.variant(base, worlds: [shortWorld] + Array(base.worlds.dropFirst())),
                                               tier: .of(2))
        #expect(Self.positions(solidMesh, [.windowBracket]).count >= 4)
        #expect(Self.positions(shortMesh, [.windowBracketShort]).count >= 4)
        // The bloom marker at min(I, 2 · B_hi); the tick marker above the shown tick's column.
        let marker: Int = min(world.integral, 2 * world.bloomHigh)
        let mx: Double = G.bloomX(marker, bloomHigh: world.bloomHigh)
        let e: Double = BinaryGardensShaders.quadExtent
        var bloomFound: Bool = false
        var tickFound: Bool = false
        for k in mesh.positions.indices {
            let p: Vec3 = mesh.positions[k]
            let d = Self.decoded(mesh, k)
            if d.material == .bloomMarker && abs(p.x - (mx + e * G.bloomMarkerRadius)) < 1e-9 { bloomFound = true }
            if d.material == .tickMarker && abs(p.x - (G.cellX(24) + e * G.markerRadius)) < 1e-9 { tickFound = true }
        }
        #expect(bloomFound && tickFound)
    }

    @Test func aWonLevelStaysInPlaceAndBlooms() throws {
        let base: Snapshot = try Self.snapshot(Self.levels[4])
        let won: Snapshot = Self.variant(base, failure: .some(nil), stage: .won)
        #expect(won.isWon && !base.isWon)
        let tier: BinaryGardensTier = .of(0)
        let fixed: Set<Material> = [.starOne, .starTwo, .worldPip, .gaugePlate, .actionsLit, .actionsUnlit, .orbit]
        let a: Mesh = try G.systemMesh(base, tier: tier)
        let b: Mesh = try G.systemMesh(won, tier: tier)
        #expect(Self.key(Self.positions(a, fixed)) == Self.key(Self.positions(b, fixed)), "nothing moves")
        #expect(G.referencePoints(base) == G.referencePoints(won))
        // Every world gets its motes on a won level.
        var motes: Int = 0
        for world in won.worlds.indices { motes += G.motes(world, won, tier: tier, won: true).count }
        #expect(motes == 8 * won.worlds.count)
        #expect(Self.positions(b, [.mote]).count == 4 * motes)
        // The glow mesh is unchanged; its fallback colours raise every world.
        #expect(try G.glowMesh(base, tier: tier) == G.glowMesh(won, tier: tier))
        let plain: BinaryGardensColouredMesh = try G.glowPart(base, tier: tier, wonLevel: false)
        let lit: BinaryGardensColouredMesh = try G.glowPart(base, tier: tier, wonLevel: true)
        #expect(plain.mesh == lit.mesh && plain.colours.count == lit.colours.count)
    }

    @Test func glowShellsPerTier() throws {
        let snapshot: Snapshot = try Self.snapshot(Self.levels[6])
        let bodies: Int = 2 + snapshot.worlds.count
        let quadsPerShell: Int = G.glowSides
        for tier in BinaryGardensTier.all {
            let mesh: Mesh = try G.glowMesh(snapshot, tier: tier)
            #expect(mesh.indices.count == tier.glowShells * bodies * quadsPerShell * 6, "\(tier.name)")
            Self.checkGlow(mesh)
        }
        #expect(try G.glowMesh(snapshot, tier: .of(2)).positions.isEmpty)
        // A star shell carries its colour; a world shell zero and the factor of its band at the shown tick.
        let mesh: Mesh = try G.glowMesh(snapshot, tier: .of(1))
        var starColours: Set<String> = []
        for k in mesh.positions.indices {
            let kind = BinaryGardensShaders.GlowKind.decode(mesh.uvs[k].x)
            let n: Vec3 = mesh.normals[k]
            if kind.kind == .star {
                starColours.insert(String(format: "%.3f %.3f %.3f", n.x, n.y, n.z))
                #expect(kind.factor == 1)
            } else {
                #expect(n.x == 0 && n.y == 0 && n.z == 0)
                #expect(kind.factor == 0 || kind.factor == 1)
            }
        }
        #expect(starColours.count == 2)
    }

    @Test func eachFailureKindIsMarkedOnAFailedPlayOnly() throws {
        let base: Snapshot = try Self.snapshot(Self.levels[2])
        let tier: BinaryGardensTier = .of(2)
        // A predicted failure while playing marks nothing.
        let predicted: Snapshot = Self.variant(base, failure: .some(.frozen(world: 0, tick: 7)), stage: .playing)
        #expect(Self.brokenMaterials(try G.systemMesh(predicted, tier: tier)).isEmpty)
        // Frozen at walk tick 55: the broken ring around world 0 and its cell at column 7.
        let frozen: Snapshot = Self.variant(base, failure: .some(.frozen(world: 0, tick: 55)), stage: .failed)
        let frozenMesh: Mesh = try G.systemMesh(frozen, tier: tier)
        let marks: Set<Material> = Self.brokenMaterials(frozenMesh)
        #expect(marks.contains(.brokenRing) && marks.count == 2)
        #expect(G.lethalMark(frozen)?.column == 7)
        var cellX: Double = 0
        for k in frozenMesh.positions.indices where Self.decoded(frozenMesh, k).broken
            && Self.decoded(frozenMesh, k).material != .brokenRing {
            cellX += Double(frozenMesh.positions[k].x) / 4
        }
        #expect(abs(cellX - G.cellX(7)) < 1e-9)
        let ring: [SIMD3<Double>] = Self.positions(frozenMesh, [.brokenRing])
        var ringCentre: SIMD3<Double> = SIMD3(0, 0, 0)
        for p in ring { ringCentre += p / Double(ring.count) }
        #expect(Self.distance(ringCentre, G.worldCentre(0, frozen)) < 1e-9)
        // Scorched on the result screen after a failed run marks the same way.
        let scorched: Snapshot = Self.variant(base, failure: .some(.scorched(world: 1, tick: 3)), stage: .result)
        #expect(Self.brokenMaterials(try G.systemMesh(scorched, tier: tier)).contains(.brokenRing))
        // Unstable: the window bracket, or the required tick alone when there is no window.
        let windowed: BinaryGardensSceneWorld = Self.relit(base.worlds[0], longestWindow: 6, windowStart: 40, window: 9)
        let unstable: Snapshot = Self.variant(base, worlds: [windowed] + Array(base.worlds.dropFirst()),
                                              failure: .some(.unstable(world: 0, window: 6, required: 9)),
                                              stage: .failed)
        #expect(Self.brokenMaterials(try G.systemMesh(unstable, tier: tier)) == [.windowBracketShort])
        let none: BinaryGardensSceneWorld = Self.relit(base.worlds[0], longestWindow: 0, windowStart: 0, window: 9)
        let bare: Snapshot = Self.variant(base, worlds: [none] + Array(base.worlds.dropFirst()),
                                          failure: .some(.unstable(world: 0, window: 0, required: 9)), stage: .failed)
        #expect(Self.brokenMaterials(try G.systemMesh(bare, tier: tier)) == [.requiredTick])
        // Wilted and bleached: the bloom marker.
        let wilted: Snapshot = Self.variant(base, failure: .some(.wilted(world: 1, integral: 5, low: 10, high: 20)),
                                            stage: .failed)
        #expect(Self.brokenMaterials(try G.systemMesh(wilted, tier: tier)) == [.bloomMarker])
        let bleached: Snapshot = Self.variant(base, failure: .some(.bleached(world: 0, integral: 50, low: 10,
                                                                             high: 20)), stage: .failed)
        #expect(Self.brokenMaterials(try G.systemMesh(bleached, tier: tier)) == [.bloomMarker])
    }

    @Test func worldStreamsCarryTheBandAndBothShares() throws {
        let snapshot: Snapshot = try Self.snapshot(Self.levels[4], tick: 17)
        let mesh: Mesh = try G.systemMesh(snapshot, tier: .of(1))
        for world in snapshot.worlds.indices {
            let centre: SIMD3<Double> = G.worldCentre(world, snapshot)
            let expected: Material = Material.world(snapshot.band(world))
            let one: Double = BinaryGardensShaders.shareValue(snapshot.share(world, star: 0))
            let two: Double = BinaryGardensShaders.shareValue(snapshot.share(world, star: 1))
            var count: Int = 0
            for k in mesh.positions.indices where Self.decoded(mesh, k).material.isWorld {
                let p: Vec3 = mesh.positions[k]
                guard Self.distance(SIMD3(p.x, p.y, p.z), centre) < G.worldRadius + 1e-9 else { continue }
                let n: Vec3 = mesh.normals[k]
                #expect(abs(Self.distance(SIMD3(p.x, p.y, p.z), centre) - G.worldRadius) < 1e-9)
                #expect(Self.distance(SIMD3(p.x, p.y, p.z), centre + SIMD3(n.x, n.y, n.z) * G.worldRadius) < 1e-9)
                #expect(Self.decoded(mesh, k).material == expected)
                #expect(abs(Self.decoded(mesh, k).value - one) < 1e-9 && abs(mesh.uvs[k].y - two) < 1e-12)
                count += 1
            }
            #expect(count > 0)
            #expect(G.worldPips(world, snapshot).count == world + 1)
        }
        for star in 0..<2 {
            let pips = G.luminosityPips(star, snapshot)
            #expect(pips.count == snapshot.luminosityLevels.count)
            var lit: Int = 0
            for pip in pips where pip.lit { lit += 1 }
            #expect(lit == snapshot.arrangement.luminosities[star] + 1)
        }
    }

    @Test func backdropFillsTheViewAndCarriesItsGradient() throws {
        let snapshot: Snapshot = try Self.snapshot(Self.levels[0])
        let mesh: Mesh = try G.systemMesh(snapshot, tier: .of(2))
        let corners: [SIMD3<Double>] = Self.positions(mesh, [.backdrop])
        #expect(corners.count == 4)
        for aspect in [0.25, 0.4, 1, 2.5, 4] {
            let camera: BinaryGardensCamera = G.camera(aspect: aspect)
            var xs: [Double] = []
            var ys: [Double] = []
            for corner in corners {
                let p: SIMD2<Double> = try #require(G.project(corner, camera: camera))
                xs.append(p.x)
                ys.append(p.y)
            }
            #expect((xs.min() ?? 1) < 0 && (xs.max() ?? 0) > 1 && (ys.min() ?? 1) < 0 && (ys.max() ?? 0) > 1)
        }
        let camera: BinaryGardensCamera = G.camera(aspect: 1.5)
        let bottom: Double = G.backdropHeight(view: SIMD2(0.5, 1), camera: camera)
        let top: Double = G.backdropHeight(view: SIMD2(0.5, 0), camera: camera)
        #expect(bottom > 0 && bottom < 0.5 && top > 0.5 && top < 1)
        for k in mesh.positions.indices where Self.decoded(mesh, k).material == .backdrop {
            #expect(mesh.uvs[k].y == 0 || mesh.uvs[k].y == 1)
            #expect(abs(abs(mesh.normals[k].x) - G.backdropHalf().x) < 1e-9)
        }
    }

    @Test func fallbackColoursFollowTheShaderBaseColours() throws {
        let snapshot: Snapshot = try Self.snapshot(Self.levels[0])
        let part: BinaryGardensColouredMesh = try G.systemPart(snapshot, tier: .of(1))
        for k in part.mesh.positions.indices {
            let d = Self.decoded(part.mesh, k)
            let c: Vec4 = part.colours[k]
            switch d.material {
            case .backdrop, .ringShared, .corona:
                continue
            default:
                let expected: SIMD3<Double> = G.colour(of: part.mesh.uvs[k].x, won: 0)
                #expect(abs(c.x - expected.x) < 1e-9 && abs(c.y - expected.y) < 1e-9 && abs(c.z - expected.z) < 1e-9)
            }
        }
        #expect(G.colour(of: BinaryGardensShaders.encode(.actionsLit)) == BinaryGardensPalette.actionsLit)
        #expect(G.colour(of: BinaryGardensShaders.encode(.cellDim, broken: true)) == BinaryGardensPalette.broken)
        #expect(G.colour(of: BinaryGardensShaders.encode(.worldComfortable)) == BinaryGardensPalette.world)
        let frosty: SIMD3<Double> = G.colour(of: BinaryGardensShaders.encode(.worldLethalLow))
        #expect(frosty.z > BinaryGardensPalette.world.z)
        #expect(G.colour(of: BinaryGardensShaders.encode(.worldLethalLow), won: 1) == BinaryGardensPalette.world)
        // The first actions bar is lit (red above blue, the frame check's vermilion).
        #expect(BinaryGardensPalette.actionsLit.x - BinaryGardensPalette.actionsLit.z >= 0.08)
        #expect(G.litActions(snapshot) == snapshot.actionsLeft)
    }
}
