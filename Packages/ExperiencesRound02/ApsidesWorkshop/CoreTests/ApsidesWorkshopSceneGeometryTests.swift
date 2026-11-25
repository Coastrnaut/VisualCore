// ApsidesWorkshopSceneGeometryTests — feature 473 (R02-G18-03) T-R02G1803-004 (FR-R02G1803-001, 002, 003, 004, 006;
// SC-R02G1803-001; clarifications Q1–Q4). The compass from snapshots: finite and bounded for extreme settings (sizes 8
// and 48, eccentricity steps 0 and 15, periods 16 and 96, 0 and 6 planets of radius 8 at the corners ±64, budgets 1
// and 24); every vertex of the compass and glow meshes and every reference point inside the view with a 5 % margin at
// 7 aspects over catalog levels 1, 21, 41, 61, 81 (their first valid candidates) and seeded fixtures; the authored
// camera; the same positions at every tier (bodies aside, which change only their detail, and the orbit ribbon, which
// changes only its refinement); the orbit ribbon through every kernel position exactly; gauges at 0, half and the full
// scale and actions bars at 0, half and the full budget; a won level in place; the glow empty at level-2 with its shell
// counts per tier; the paint order by kind; each failure kind (contact, order, share, apsis-sector, apsis-distance)
// marked. Seed 2_473; explicit types, plain loops; each test well under 10 s; no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import ApsidesWorkshopCore

struct ApsidesWorkshopSceneGeometryTests {
    typealias G = ApsidesWorkshopSceneGeometry
    typealias Snapshot = ApsidesWorkshopSceneSnapshot
    typealias Level = ApsidesWorkshopLevel
    typealias Orbit = ApsidesWorkshopOrbit
    typealias Target = ApsidesWorkshopTarget
    typealias Planet = ApsidesWorkshopPlanet
    typealias Play = ApsidesWorkshopPlay
    typealias Tier = ApsidesWorkshopTier
    typealias M = ApsidesWorkshopMaterial

    /// The feature's test seed.
    static let seed: UInt64 = 2_473

    /// The seven aspects checked.
    static let aspects: [Double] = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]

    /// Catalog levels 1, 21, 41, 61 and 81: the first valid candidate of each entry (the catalog's content rules
    /// without the solver's certification, so the sample stays cheap).
    static let catalogLevels: [Level] = {
        let numbers: [Int] = [1, 21, 41, 61, 81]
        var levels: [Level] = []
        for entry in ApsidesWorkshopManifest.entries where numbers.contains(entry.number) {
            for index in 0..<ApsidesWorkshopGenerator.maxCandidates {
                if let level = ApsidesWorkshopGenerator.candidate(entry, index: index) {
                    levels.append(level)
                    break
                }
            }
        }
        return levels
    }()

    /// Seeded fixtures (levels with known winning actions).
    static let fixtures: [ApsidesWorkshopFixture] = ApsidesWorkshopFixture.all(count: 8, seed: seed)

    /// A level of the given values without the "already won" rule (every other rule checked).
    static func level(_ id: String, period: Int, planets: [Planet], targets: [Target], orbit: Orbit,
                      budget: Int) throws -> Level {
        try Level(id: id, seed: seed, difficulty: 1, period: period, planets: planets, targets: targets, orbit: orbit,
                  budget: budget, tutorial: false, refusingAWin: false)
    }

    /// The extreme orbits: sizes 8 and 48 at eccentricity step 0, and step 15 at the smallest and largest valid sizes
    /// (12 and 36; sizes 8 and 48 are invalid at step 15).
    static let extremeOrbits: [Orbit] = [
        Orbit(size: 8, eccentricity: 0, direction: 0), Orbit(size: 48, eccentricity: 0, direction: 5),
        Orbit(size: 12, eccentricity: 15, direction: 7), Orbit(size: 36, eccentricity: 15, direction: 23),
    ]

    /// Six planets of radius 8 at the corners ±64 and the top and bottom middles.
    static let cornerPlanets: [Planet] = [
        Planet(x: -64, y: -64, radius: 8), Planet(x: 64, y: -64, radius: 8), Planet(x: 64, y: 64, radius: 8),
        Planet(x: -64, y: 64, radius: 8), Planet(x: 0, y: 64, radius: 8), Planet(x: 0, y: -64, radius: 8),
    ]

    /// Six targets: four sweeps and both apsis targets, with full bands.
    static let sixTargets: [Target] = [
        Target.sweep(sector: 0, low: 0, high: 1000), Target.sweep(sector: 2, low: 0, high: 1000),
        Target.sweep(sector: 4, low: 0, high: 1000), Target.sweep(sector: 6, low: 0, high: 1000),
        Target(kind: .periapsis, sector: 0, low: 0, high: 1280), Target(kind: .apoapsis, sector: 4, low: 0, high: 1280),
    ]

    /// The extreme levels: 4 orbits × periods 16 and 96 × (no planets with budget 1, six corner planets with budget
    /// 24).
    static func extremeLevels() throws -> [Level] {
        var levels: [Level] = []
        for (o, orbit) in extremeOrbits.enumerated() {
            for period in [16, 96] {
                for crowded in [false, true] {
                    levels.append(try level("extreme-\(o)-\(period)-\(crowded ? 6 : 0)", period: period,
                                            planets: crowded ? cornerPlanets : [], targets: sixTargets, orbit: orbit,
                                            budget: crowded ? 24 : 1))
                }
            }
        }
        return levels
    }

    /// The hand orbit: a circle of 20 lattice units, periapsis direction 0 (P(0) on +x, sector 0), period 16.
    static let handOrbit: Orbit = Orbit(size: 20, eccentricity: 0, direction: 0)

    /// A hand level on the hand orbit with `targets` and `planets` (budget 4).
    static func handLevel(_ id: String, targets: [Target], planets: [Planet] = []) throws -> Level {
        try level(id, period: 16, planets: planets, targets: targets, orbit: handOrbit, budget: 4)
    }

    /// One hand level per failure kind, with the code expected.
    static func failureLevels() throws -> [(code: String, level: Level)] {
        let full: Target = Target.sweep(sector: 0, low: 0, high: 1000)
        return [
            (code: "contact", level: try handLevel("contact", targets: [full],
                                                    planets: [Planet(x: 0, y: 20, radius: 1)])),
            (code: "order", level: try handLevel("order", targets: [
                Target.sweep(sector: 2, low: 0, high: 1000), Target(kind: .periapsis, sector: 0, low: 0, high: 1280),
            ])),
            (code: "share", level: try handLevel("share", targets: [Target.sweep(sector: 0, low: 1000, high: 1000)])),
            (code: "apsis-sector", level: try handLevel("apsis-sector", targets: [
                Target(kind: .periapsis, sector: 3, low: 0, high: 1280),
            ])),
            (code: "apsis-distance", level: try handLevel("apsis-distance", targets: [
                Target(kind: .periapsis, sector: 0, low: 0, high: 0),
            ])),
        ]
    }

    /// The snapshot of a fresh play of `level` at `tick`.
    static func snapshot(_ level: Level, tick: Int = 0) -> Snapshot {
        Snapshot(play: Play(level: level), shownTick: tick, levelNumber: 1, time: 0)
    }

    /// The snapshot of `play` at `tick`.
    static func snapshot(_ play: Play, tick: Int = 0) -> Snapshot {
        Snapshot(play: play, shownTick: tick, levelNumber: 1, time: 0)
    }

    /// A play of `level` started (stage playing).
    static func started(_ level: Level) throws -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The position of vertex `index` of `mesh`.
    static func point(_ mesh: Mesh, _ index: Int) -> SIMD3<Double> {
        SIMD3(mesh.positions[index].x, mesh.positions[index].y, mesh.positions[index].z)
    }

    /// The a_uv.x of `material`.
    static func code(_ material: M) -> Double { Double(material.rawValue) }

    /// The vertex indices of `mesh` with material `material`.
    static func vertices(_ mesh: Mesh, _ material: M) -> [Int] {
        var found: [Int] = []
        for index in mesh.uvs.indices where mesh.uvs[index].x == code(material) { found.append(index) }
        return found
    }

    /// The triangle count of `mesh` whose first vertex has material `material`.
    static func triangles(_ mesh: Mesh, _ material: M) -> Int {
        var count: Int = 0
        let wanted: Double = code(material)
        for t in stride(from: 0, to: mesh.indices.count, by: 3) where mesh.uvs[Int(mesh.indices[t])].x == wanted {
            count += 1
        }
        return count
    }

    /// The positions of every vertex of `mesh` whose material is not in `excluded`, in order.
    static func positions(_ mesh: Mesh, except excluded: [M]) -> [SIMD3<Double>] {
        var codes: [Double] = []
        for material in excluded { codes.append(code(material)) }
        var list: [SIMD3<Double>] = []
        for index in mesh.positions.indices where !codes.contains(mesh.uvs[index].x) {
            list.append(point(mesh, index))
        }
        return list
    }

    /// The length of `v`.
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

    // MARK: Tests

    @Test func finiteAndBoundedForExtremeSettings() throws {
        let levels: [Level] = try Self.extremeLevels()
        #expect(levels.count == 16)
        for level in levels {
            for tick in [0, level.period / 2] {
                let snap: Snapshot = Self.snapshot(level, tick: tick)
                #expect(snap.gauges.count == 6)
                for tier in Tier.all {
                    let mesh: Mesh = try G.compassMesh(snap, tier: tier)
                    #expect(mesh.triangleCount > 0 && mesh.triangleCount < 40_000, "\(mesh.triangleCount)")
                    var bad: Int = 0
                    var outside: Int = 0
                    for index in mesh.positions.indices {
                        let p: SIMD3<Double> = Self.point(mesh, index)
                        let n: Vec3 = mesh.normals[index]
                        let uv: Vec2 = mesh.uvs[index]
                        if !(p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite && n.y.isFinite
                             && n.z.isFinite && uv.x.isFinite && uv.y.isFinite) { bad += 1 }
                        if uv.x != Self.code(.backdrop)
                            && !(abs(p.x) <= 1.05 && p.y >= -1.65 && p.y <= 1.05 && abs(p.z) <= 0.15) {
                            outside += 1
                        }
                    }
                    let glow: Mesh = try G.glowMesh(snap, tier: tier)
                    for index in glow.positions.indices {
                        let p: SIMD3<Double> = Self.point(glow, index)
                        if !(p.x.isFinite && p.y.isFinite && p.z.isFinite) { bad += 1 }
                        if !(abs(p.x) <= 1.05 && p.y >= -1.65 && p.y <= 1.05 && abs(p.z) <= 0.15) { outside += 1 }
                    }
                    #expect(bad == 0 && outside == 0, "\(level.id) tick \(tick) \(tier.name): \(bad) \(outside)")
                }
            }
        }
    }

    @Test func everyElementInsideTheViewAtSevenAspects() throws {
        var levels: [Level] = Self.catalogLevels
        #expect(levels.count == 5)
        for fixture in Self.fixtures { levels.append(fixture.level) }
        for level in levels {
            for tick in [0, level.period / 2] {
                let snap: Snapshot = Self.snapshot(level, tick: tick)
                let mesh: Mesh = try G.compassMesh(snap, tier: .of(0))
                let glow: Mesh = try G.glowMesh(snap, tier: .of(0))
                var points: [SIMD3<Double>] = Self.positions(mesh, except: [.backdrop])
                for index in glow.positions.indices { points.append(Self.point(glow, index)) }
                for element in G.paintOrder(snap) where element.part != .backdrop { points.append(element.centre) }
                for element in G.referencePoints(snap) { points.append(element.centre) }
                for aspect in Self.aspects {
                    let camera: ApsidesWorkshopCamera = G.camera(aspect: aspect)
                    var outside: Int = 0
                    for p in points where !Self.inside(G.project(p, camera: camera)) { outside += 1 }
                    #expect(outside == 0, "\(level.id) tick \(tick) aspect \(aspect)")
                }
            }
        }
    }

    @Test func backdropFillsTheView() throws {
        let half: SIMD2<Double> = G.backdropHalf()
        for aspect in Self.aspects {
            let camera: ApsidesWorkshopCamera = G.camera(aspect: aspect)
            let corners: [SIMD3<Double>] = [
                SIMD3(G.lookAt.x - half.x, G.lookAt.y - half.y, G.backdropDepth),
                SIMD3(G.lookAt.x + half.x, G.lookAt.y + half.y, G.backdropDepth),
            ]
            let low: SIMD2<Double>? = G.project(corners[0], camera: camera)
            let high: SIMD2<Double>? = G.project(corners[1], camera: camera)
            #expect(low != nil && high != nil)
            if let l = low, let h = high {
                #expect(l.x < 0 && l.y > 1 && h.x > 1 && h.y < 0, "aspect \(aspect)")
            }
            let top: Double = G.backdropHeight(view: SIMD2(0.5, 0), camera: camera)
            let bottom: Double = G.backdropHeight(view: SIMD2(0.5, 1), camera: camera)
            #expect(top > bottom && top < 1 && bottom > 0, "aspect \(aspect)")
        }
    }

    @Test func cameraIsTheAuthoredOneAndProjectRefusesBehind() throws {
        let camera: ApsidesWorkshopCamera = G.camera(aspect: 1.5)
        #expect(camera.eye == SIMD3(0, -0.3, 3.6) && camera.target == SIMD3(0, -0.3, 0))
        #expect(camera.fovY > 0 && camera.fovY < Double.pi && camera.aspect == 1.5)
        #expect(G.camera(aspect: .nan).aspect == 1 && G.camera(aspect: 100).aspect == 10)
        let centre: SIMD2<Double>? = G.project(camera.target, camera: camera)
        #expect(centre != nil && abs(centre!.x - 0.5) < 1e-9 && abs(centre!.y - 0.5) < 1e-9)
        let up: SIMD2<Double>? = G.project(SIMD3(0, 0.5, 0), camera: camera)
        let right: SIMD2<Double>? = G.project(SIMD3(0.5, -0.3, 0), camera: camera)
        #expect(up != nil && up!.y < 0.5 && right != nil && right!.x > 0.5)
        #expect(G.project(SIMD3(0, -0.3, 6), camera: camera) == nil)
        #expect(G.project(SIMD3(.nan, 0, 0), camera: camera) == nil)
        // The box's corners keep the 6 % fitting margin at the extreme aspects.
        for aspect in [0.4, 2.5] {
            let fitted: ApsidesWorkshopCamera = G.camera(aspect: aspect)
            for index in 0..<8 {
                let q: SIMD2<Double>? = G.project(G.corner(index), camera: fitted)
                #expect(q != nil && q!.x >= 0.06 - 1e-9 && q!.x <= 0.94 + 1e-9 && q!.y >= 0.06 - 1e-9
                        && q!.y <= 0.94 + 1e-9, "aspect \(aspect) corner \(index)")
            }
        }
    }

    @Test func worldScaleAndReferencePoints() throws {
        #expect(G.scale == 0.9 / 16_384)
        #expect(G.world(ApsidesWorkshopPoint(x: 16_384, y: -16_384), depth: -0.04) == SIMD3(0.9, -0.9, -0.04))
        #expect(abs(G.starRadius - 2 * 256 * 0.9 / 16_384) < 1e-15)
        let level: Level = try Self.handLevel("reference", targets: [Target.sweep(sector: 0, low: 0, high: 1000)],
                                              planets: [Planet(x: 30, y: -10, radius: 3)])
        let snap: Snapshot = Self.snapshot(level, tick: 8)
        #expect(G.starCentre() == SIMD3(0, 0, 0))
        #expect(G.orbiterCentre(snap) == G.world(snap.positions[8], depth: 0))
        #expect(G.planetCentre(0, snap) == G.world(ApsidesWorkshopPoint(x: 30 * 256, y: -10 * 256), depth: 0))
        #expect(G.planetRadius(0, snap) == 3 * 256 * G.scale)
        #expect(G.gaugeCentre(0) == SIMD3(0, -1.08, 0))
        #expect(abs(G.gaugeCentre(5).y - (-1.08 - 0.35)) < 1e-12)
        #expect(abs(G.actionsBar(0, snap).x - (-0.9 + 0.5 * 1.8 / 4)) < 1e-12 && G.actionsBar(0, snap).y == -1.55)
        var parts: [ApsidesWorkshopElement.Part] = []
        for element in G.referencePoints(snap) { parts.append(element.part) }
        #expect(parts == [.planet, .star, .orbiter, .track, .bar])
        // The apoapsis tick T/2 keeps the orbiter at least 8 lattice units (plus both radii) from the star.
        #expect(Self.length(G.orbiterCentre(snap)) >= 8 * 256 * G.scale)
    }

    @Test func samePositionsAtEveryTier() throws {
        var levels: [Level] = []
        for fixture in Self.fixtures.prefix(6) { levels.append(fixture.level) }
        for entry in try Self.failureLevels() { levels.append(entry.level) }
        let detail: [M] = [.planet, .star, .orbiter, .orbit]
        for level in levels {
            let snap: Snapshot = Self.snapshot(level, tick: 1)
            let reference: [SIMD3<Double>] = Self.positions(try G.compassMesh(snap, tier: .of(0)), except: detail)
            let order: [ApsidesWorkshopElement] = G.paintOrder(snap)
            for tier in Tier.all {
                let mesh: Mesh = try G.compassMesh(snap, tier: tier)
                #expect(Self.positions(mesh, except: detail) == reference, "\(level.id) \(tier.name)")
                #expect(G.paintOrder(snap) == order)
                var bodies: [(SIMD3<Double>, Double, M)] = []
                for p in level.planets.indices {
                    bodies.append((G.planetCentre(p, snap), G.planetRadius(p, snap), .planet))
                }
                bodies.append((G.starCentre(), G.starRadius, .star))
                bodies.append((G.orbiterCentre(snap), G.orbiterRadius, .orbiter))
                for (centre, radius, material) in bodies {
                    var found: Int = 0
                    for index in Self.vertices(mesh, material) {
                        let p: SIMD3<Double> = Self.point(mesh, index)
                        if tier.flatSpheres {
                            if mesh.uvs[index].y == 0 && p == centre { found += 1 }
                        } else if mesh.normals[index] == Vec3(0, 1, 0)
                                    && Self.length(p - (centre + SIMD3(0, radius, 0))) < 1e-12 {
                            found += 1   // the north pole of the body's sphere
                        }
                    }
                    #expect(found == 1, "\(level.id) \(tier.name) \(material)")
                }
                let expected: Int = tier.flatSpheres ? Tier.discSides : 2 * tier.longitudes * (tier.latitudes - 1)
                #expect(Self.triangles(mesh, .star) == expected, "\(tier.name)")
            }
        }
    }

    @Test func orbitRibbonThroughEveryKernelPosition() throws {
        var levels: [Level] = Self.catalogLevels
        for fixture in Self.fixtures { levels.append(fixture.level) }
        levels.append(contentsOf: try Self.extremeLevels().prefix(8))
        for (number, level) in levels.enumerated() {
            let snap: Snapshot = Self.snapshot(level, tick: level.period - 1)
            let kernel: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(level.orbit, period: level.period).points
            #expect(snap.positions == kernel)
            #expect(G.orbiterCentre(snap) == G.world(kernel[level.period - 1], depth: 0))
            let orbit: Orbit = level.orbit
            let near: Double = Double(orbit.periapsisDistance) / 20 * 256 * G.scale
            let far: Double = Double(orbit.apoapsisDistance) / 20 * 256 * G.scale
            for tier in Tier.all {
                let step: Int = tier.refinement + 1
                let ribbon: [SIMD3<Double>] = G.refinement(snap, tier: tier)
                #expect(ribbon.count == level.period * step)
                var off: Int = 0
                var offEllipse: Int = 0
                for t in 0..<level.period where ribbon[t * step] != G.world(kernel[t], depth: 0) { off += 1 }
                for (index, p) in ribbon.enumerated() where index % step != 0 {
                    let r: Double = Self.length(p)
                    if r < near - 1e-9 || r > far + 1e-9 || p.z != 0 { offEllipse += 1 }
                }
                #expect(off == 0 && offEllipse == 0, "\(level.id) \(tier.name)")
                // The drawn ribbon's strips are centred on the ribbon points: the two corners of both strips at each
                // kernel point (checked on a sample of levels to keep the test short).
                guard number % 3 == 0 else { continue }
                let mesh: Mesh = try G.compassMesh(snap, tier: tier)
                let ribbonVertices: [Int] = Self.vertices(mesh, .orbit)
                var missing: Int = 0
                for t in 0..<level.period {
                    let p: SIMD3<Double> = G.world(kernel[t], depth: 0)
                    var corners: Int = 0
                    for index in ribbonVertices
                    where abs(Self.length(Self.point(mesh, index) - p) - G.orbitWidth / 2) < 1e-12 {
                        corners += 1
                    }
                    if corners < 4 { missing += 1 }
                }
                #expect(missing == 0, "\(level.id) \(tier.name)")
            }
        }
    }

    @Test func gaugesAtZeroHalfAndFull() throws {
        #expect(G.gaugeX(0, top: 1000) == -0.9 && abs(G.gaugeX(500, top: 1000)) < 1e-12)
        #expect(G.gaugeX(1000, top: 1000) == 0.9 && G.gaugeX(1280, top: 1280) == 0.9)
        #expect(abs(G.gaugeX(640, top: 1280)) < 1e-12 && G.gaugeX(-5, top: 1000) == -0.9)
        #expect(G.gaugeX(2000, top: 1280) == 0.9)
        let level: Level = try Self.handLevel("gauges", targets: [Target.sweep(sector: 0, low: 0, high: 1000),
                                                                  Target(kind: .periapsis, sector: 0, low: 0,
                                                                         high: 1280)])
        var play: Play = try Self.started(level)
        var seen: [Int] = []
        for spent in 0...4 {
            if spent > 0 { try play.apply(.size(spent % 2 == 1 ? 21 : 22), expecting: play.fingerprint) }
            guard spent % 2 == 0 else { continue }
            let snap: Snapshot = Self.snapshot(play)
            let left: Int = 4 - spent
            #expect(snap.actionsLeft == left && G.litActions(snap) == left)
            let mesh: Mesh = try G.compassMesh(snap, tier: .of(1))
            #expect(Self.triangles(mesh, .barLit) == 4 * left && Self.triangles(mesh, .barUnlit) == 4 * (4 - left))
            for b in 0..<4 {
                let c: SIMD3<Double> = G.actionsBar(b, snap)
                let material: M = b < left ? .barLit : .barUnlit
                #expect(Self.near(mesh, material, c, 0) == 1, "bar \(b) left \(left)")
                #expect(Self.near(mesh, material, c, 0.4 * 1.8 / 4 * 1.2) == 5, "bar \(b) left \(left)")
            }
            // The share gauge's mark at its reading, the distance gauge's at 400 of 1280.
            #expect(G.markCentre(0, snap).x == G.gaugeX(snap.shares[0], top: 1000))
            #expect(G.markCentre(1, snap).x == G.gaugeX(snap.orbit.periapsisDistance, top: 1280))
            #expect(G.markCentre(1, snap).y == G.gaugeCentre(1).y)
            seen.append(left)
        }
        #expect(seen == [4, 2, 0])
        // Budgets 1 and 24: each bar 1.8 / budget wide with a fifth as gap.
        for budget in [1, 24] {
            let wide: Level = try Self.level("budget-\(budget)", period: 16, planets: [],
                                             targets: [Target.sweep(sector: 0, low: 0, high: 1000)],
                                             orbit: Self.handOrbit, budget: budget)
            let snap: Snapshot = Self.snapshot(wide)
            let slot: Double = 1.8 / Double(budget)
            #expect(abs(G.actionsSlot(snap) - slot) < 1e-12)
            #expect(abs(G.actionsBar(budget - 1, snap).x - (0.9 - slot / 2)) < 1e-12)
            let mesh: Mesh = try G.compassMesh(snap, tier: .of(2))
            var lowest: Double = 1
            var highest: Double = -1
            for index in Self.vertices(mesh, .barLit) {
                lowest = min(lowest, Self.point(mesh, index).x)
                highest = max(highest, Self.point(mesh, index).x)
            }
            #expect(abs(lowest - (-0.9 + 0.1 * slot)) < 1e-12 && abs(highest - (0.9 - 0.1 * slot)) < 1e-12)
        }
    }

    @Test func wonLevelInPlace() throws {
        var checked: Int = 0
        for fixture in Self.fixtures {
            var play: Play = try Self.started(fixture.level)
            var actions: [ApsidesWorkshopAction] = fixture.actions
            if actions.last == .play { actions.removeLast() }
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
            let before: Snapshot = Self.snapshot(play, tick: 2)
            try play.apply(.play, expecting: play.fingerprint)
            let won: Snapshot = Self.snapshot(play, tick: 2)
            #expect(won.isWon && won.failure == nil)
            for tier in Tier.all {
                let lit: ApsidesWorkshopColouredMesh = try G.compassPart(won, tier: tier)
                let unlit: ApsidesWorkshopColouredMesh = try G.compassPart(won, tier: tier, wonLevel: false)
                #expect(lit.mesh.positions == unlit.mesh.positions && lit.mesh.indices == unlit.mesh.indices)
                #expect(lit.mesh.positions == (try G.compassMesh(before, tier: tier)).positions)
                #expect(Self.vertices(lit.mesh, .markUnmet).isEmpty && Self.vertices(lit.mesh, .broken).isEmpty)
                #expect(Self.vertices(lit.mesh, .markMet).count == 4 * won.gauges.count)
                let met: Vec4 = Vec4(ApsidesWorkshopPalette.met.x, ApsidesWorkshopPalette.met.y,
                                     ApsidesWorkshopPalette.met.z, 1)
                var wrong: Int = 0
                for index in Self.vertices(lit.mesh, .markMet) where lit.colours[index] != met { wrong += 1 }
                #expect(wrong == 0 && lit.colours.count == lit.mesh.positions.count)
            }
            checked += 1
        }
        #expect(checked == Self.fixtures.count)
        // The override lights a level that is not won without moving anything.
        let snap: Snapshot = Self.snapshot(try Self.handLevel("unwon", targets: [
            Target.sweep(sector: 0, low: 1000, high: 1000),
        ]))
        let plain: ApsidesWorkshopColouredMesh = try G.compassPart(snap, tier: .of(0))
        let lit: ApsidesWorkshopColouredMesh = try G.compassPart(snap, tier: .of(0), wonLevel: true)
        #expect(plain.mesh.positions == lit.mesh.positions)
        #expect(Self.vertices(plain.mesh, .markUnmet).count == 4 && Self.vertices(lit.mesh, .markMet).count == 4)
    }

    @Test func glowEmptyAtLevelTwoAndShellsPerTier() throws {
        var levels: [Level] = []
        for fixture in Self.fixtures.prefix(4) { levels.append(fixture.level) }
        levels.append(Self.catalogLevels[0])
        for level in levels {
            let snap: Snapshot = Self.snapshot(level, tick: 3)
            #expect((try G.glowMesh(snap, tier: .of(2))).triangleCount == 0)
            #expect((try G.glowPart(snap, tier: .of(2))).colours.isEmpty)
            for tier in Tier.all where tier.glowShells > 0 {
                let glow: Mesh = try G.glowMesh(snap, tier: tier)
                let segments: Int = level.period * (tier.refinement + 1)
                let perShell: Int = 2 * G.glowSides + 4 * segments + 2 * G.glowSides
                #expect(glow.triangleCount == tier.glowShells * perShell, "\(level.id) \(tier.name)")
                var kinds: [Int: Int] = [:]
                var factors: Set<Double> = []
                for index in glow.uvs.indices {
                    let decoded: (kind: ApsidesWorkshopShaders.GlowKind, factor: Double) =
                        ApsidesWorkshopShaders.GlowKind.decode(glow.uvs[index].x)
                    kinds[decoded.kind.rawValue, default: 0] += 1
                    factors.insert(decoded.factor)
                    #expect(glow.uvs[index].y == 0 || glow.uvs[index].y == 1)
                }
                #expect(kinds.count == 3 && factors.count == tier.glowShells, "\(tier.name)")
            }
        }
    }

    @Test func paintOrderByKind() throws {
        let snap: Snapshot = Self.snapshot(try Self.failureLevels()[0].level, tick: 4)
        let order: [ApsidesWorkshopElement] = G.paintOrder(snap)
        var sorted: Int = 0
        for k in 1..<order.count where !ApsidesWorkshopElement.paintsBefore(order[k], order[k - 1]) { sorted += 1 }
        #expect(sorted == order.count - 1)
        #expect(order.first?.part == .backdrop && order.last?.part == .bar)
        var wedges: Int = 0
        for element in order where element.kind == .wedge { wedges += 1 }
        #expect(wedges == snap.period)
        // In the mesh, the first appearance of each material follows the kinds' order.
        let mesh: Mesh = try G.compassMesh(snap, tier: .of(0))
        let sequence: [M] = [.backdrop, .wedge, .spoke, .ghost, .orbit, .periapsis, .apoapsis, .planet, .star,
                             .orbiter, .gaugeTrack, .barLit]
        var firsts: [Int] = []
        for material in sequence {
            var first: Int = -1
            for t in stride(from: 0, to: mesh.indices.count, by: 3)
            where mesh.uvs[Int(mesh.indices[t])].x == Self.code(material) {
                first = t
                break
            }
            firsts.append(first)
        }
        #expect(!firsts.contains(-1) && firsts == firsts.sorted(), "\(firsts)")
        // Wedges of tick t are tinted when a sweep target names the sector of P(t).
        let mixed: Snapshot = Self.snapshot(try Self.handLevel("tinted", targets: [
            Target.sweep(sector: 2, low: 0, high: 1000),
        ]))
        let tinted: Mesh = try G.compassMesh(mixed, tier: .of(2))
        var named: Int = 0
        for p in mixed.positions where ApsidesWorkshopSky.sector(of: p) == 2 { named += 1 }
        #expect(named > 0 && Self.triangles(tinted, .targetWedge) == named)
        #expect(Self.triangles(tinted, .wedge) == mixed.period - named)
        // The compass: 8 spokes, 1 + 2 + … + 8 notches, one sweep bracket (arc and two legs).
        #expect(Self.triangles(tinted, .spoke) == 16 && Self.triangles(tinted, .notch) == 72)
        #expect(Self.triangles(tinted, .rim) == 2 * G.rimSegments)
        #expect(Self.triangles(tinted, .bracket) == 2 * G.arcSegments + 4)
    }

    @Test func eachFailureKindMarked() throws {
        var kinds: [String] = []
        for entry in try Self.failureLevels() {
            let snap: Snapshot = Self.snapshot(entry.level)
            #expect(snap.failure?.code == entry.code, "\(entry.code): \(String(describing: snap.failure))")
            kinds.append(snap.failure?.code ?? "none")
            let mesh: Mesh = try G.compassMesh(snap, tier: .of(1))
            let broken: [Int] = Self.vertices(mesh, .broken)
            #expect(!broken.isEmpty, "\(entry.code)")
            if let hit = G.contact(snap) {
                let c: SIMD3<Double> = G.planetCentre(hit.planet, snap)
                let r: Double = G.planetRadius(hit.planet, snap)
                let ring: Int = Self.near(mesh, .broken, c, r + G.hazardWidth + 1e-9)
                #expect(ring >= 2 * G.ringSegments, "contact ring \(ring)")
                #expect(Self.vertices(mesh, .hazard).isEmpty)
                let a: SIMD3<Double> = G.world(snap.positions[hit.tick], depth: 0)
                let b: SIMD3<Double> = G.world(snap.positions[(hit.tick + 1) % snap.period], depth: 0)
                #expect(Self.near(mesh, .broken, a, G.brokenSegmentWidth / 2 + 1e-9) >= 2)
                #expect(Self.near(mesh, .broken, b, G.brokenSegmentWidth / 2 + 1e-9) >= 2)
                #expect(G.failingGauge(snap) == nil)
                #expect(Self.triangles(mesh, .gaugeTrack) == 2 * snap.gauges.count)
            } else {
                let target: Int? = G.failingGauge(snap)
                #expect(target != nil, "\(entry.code)")
                let i: Int = target ?? 0
                let y: Double = G.gaugeCentre(i).y
                var onTrack: Int = 0
                for index in broken where abs(Self.point(mesh, index).y - y) <= G.trackHeight / 2 + 1e-9 {
                    onTrack += 1
                }
                #expect(onTrack == broken.count && broken.count == 4, "\(entry.code)")
                #expect(Self.triangles(mesh, .gaugeTrack) == 2 * (snap.gauges.count - 1))
            }
        }
        #expect(kinds == ["contact", "order", "share", "apsis-sector", "apsis-distance"])
        // A winning fixture's start shows no broken colour once won.
        let fixture: ApsidesWorkshopFixture = Self.fixtures[0]
        let won: Snapshot = Self.snapshot(try Self.level("winning", period: fixture.level.period,
                                                         planets: fixture.level.planets,
                                                         targets: fixture.level.targets, orbit: fixture.winning,
                                                         budget: fixture.level.budget))
        #expect(won.failure == nil)
        #expect(Self.vertices(try G.compassMesh(won, tier: .of(0)), .broken).isEmpty)
    }
}
