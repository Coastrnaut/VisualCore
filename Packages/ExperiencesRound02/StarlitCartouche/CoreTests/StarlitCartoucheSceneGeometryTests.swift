// StarlitCartoucheSceneGeometryTests — feature 453 (R02-G16-03) T-R02G1603-004 (FR-R02G1603-001, 002, 003, 004, 006;
// SC-R02G1603-001; clarifications Q1, Q2, Q3, Q4). The star chart from snapshots: finite and bounded for extreme
// settings (4 and 12 stars, orbit coordinates ±8, 24 corridors, 8 hazards, budgets 1 and 24, deadline 64); every star
// at every beat 0 … 64, the cartouche, bars, track and pips inside the view with a 5 % margin at 7 aspects over a
// sample of 20 catalog levels; the same positions at every tier; the stars exactly at w(position(at: beat)); the
// trails at the legs' departure and arrival positions; gauges at 0, half and the budget; a won level brighter and in
// place; the glow empty at level-2 with its shell counts per tier; only sphere detail, ghosts and glow differ between
// tiers; the paint order sorted with the tie rule; each failure kind (departure, hazard, arrival, deadline, stroke,
// budget) marked; the vertex streams follow `StarlitCartoucheShaders.Material/localCoordinate` and the fallback
// colours equal the shader's material colours. Explicit types, plain loops; each test well under 10 s; no wall-clock
// asserts.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import StarlitCartoucheCore

struct StarlitCartoucheSceneGeometryTests {
    typealias G = StarlitCartoucheSceneGeometry
    typealias Snapshot = StarlitCartoucheSceneSnapshot
    typealias Material = StarlitCartoucheShaders.Material
    typealias V = StarlitCartoucheVector

    /// The seven aspects checked.
    static let aspects: [Double] = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]

    /// Every fifth catalog entry generated once (20 certified levels with their minimal plans).
    static let catalog: [StarlitCartoucheGenerated] = {
        var generated: [StarlitCartoucheGenerated] = []
        for index in stride(from: 0, to: StarlitCartoucheManifest.entries.count, by: 5) {
            if let level = try? StarlitCartoucheGenerator.generate(StarlitCartoucheManifest.entries[index]) {
                generated.append(level)
            }
        }
        return generated
    }()

    /// The sampled catalog levels.
    static func catalogLevels() -> [StarlitCartoucheLevel] {
        var levels: [StarlitCartoucheLevel] = []
        for generated in catalog { levels.append(generated.level) }
        return levels
    }

    /// An orbit of four positions with coordinates −8 … 8 for star `i`.
    static func wideOrbit(_ i: Int) -> [V] {
        [V(-8 + (i * 3) % 17, 8, -8), V(8, -8 + (i * 5) % 17, 8), V(-8, -8, -8 + (i * 7) % 17), V(8, 8, 8)]
    }

    /// An extreme level of `count` stars (wide orbits), the first `corridors` star pairs, `hazards` hazards on the
    /// first corridors, budget `budget` and deadline 64.
    static func extremeLevel(stars count: Int, corridors limit: Int, hazards hazardCount: Int,
                             budget: Int) throws -> StarlitCartoucheLevel {
        var stars: [StarlitCartoucheStar] = []
        for i in 0..<count {
            stars.append(StarlitCartoucheStar(orbit: wideOrbit(i), glyph: StarlitCartoucheGlyphPoint(i % 5, i / 5),
                                              open: 0, close: 64))
        }
        var corridors: [StarlitCartoucheCorridor] = []
        for a in 0..<count {
            for b in (a + 1)..<count where corridors.count < limit {
                corridors.append(StarlitCartoucheCorridor(a, b, travel: 1 + (a + b) % 3))
            }
        }
        var hazards: [StarlitCartoucheHazard] = []
        for h in 0..<hazardCount {
            hazards.append(StarlitCartoucheHazard(corridor: h % corridors.count, from: 2 * h, to: 2 * h + 3))
        }
        var symbol: [Int] = []
        for index in 0..<min(12, corridors.count) { symbol.append(index) }
        return try StarlitCartoucheLevel(id: "extreme-\(count)-\(budget)", seed: 1, difficulty: 5, stars: stars,
                                         range: 12, corridors: corridors, hazards: hazards, start: 0, beacon: 1,
                                         deadline: 64, symbol: symbol, budget: budget)
    }

    /// The extreme levels: 4 stars (6 corridors) and 12 stars (24 corridors), 8 hazards, budgets 1 and 24.
    static func extremeLevels() throws -> [StarlitCartoucheLevel] {
        var levels: [StarlitCartoucheLevel] = []
        for budget in [1, 24] {
            levels.append(try extremeLevel(stars: 4, corridors: 6, hazards: 8, budget: budget))
            levels.append(try extremeLevel(stars: 12, corridors: 24, hazards: 8, budget: budget))
        }
        return levels
    }

    /// The failure level: star 0 at the origin with window [0, 2]; corridors 0 (0–1) and 1 (1–2) are the symbol,
    /// corridor 2 (0–2) carries hazard [0, 3], corridor 3 (0–3) leads to star 3 whose window is [5, 10], corridor 4
    /// (0–4) is off the symbol; deadline 2, beacon 2. `.leg(1, 3)` breaks the departure, `.leg(2, 0)` meets the hazard,
    /// `.leg(3, 0)` misses the arrival, `.leg(4, 2)` the deadline, `.leg(4, 0)` draws a stray stroke and `.leg(1, 0)`
    /// spends a budget of 1; `.leg(1, 0)` then `.leg(2, 0)` wins with a budget of 2.
    static func failureLevel(budget: Int) throws -> StarlitCartoucheLevel {
        let orbits: [[V]] = [[V(0, 0, 0)], [V(2, 0, 0), V(2, 1, 0)], [V(2, 2, 0)], [V(-2, 0, 1)],
                             [V(0, -2, -1), V(1, -2, -1)]]
        let windows: [(Int, Int)] = [(0, 2), (0, 64), (0, 64), (5, 10), (0, 64)]
        var stars: [StarlitCartoucheStar] = []
        for i in orbits.indices {
            stars.append(StarlitCartoucheStar(orbit: orbits[i], glyph: StarlitCartoucheGlyphPoint(i, 4 - i),
                                              open: windows[i].0, close: windows[i].1))
        }
        let corridors: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(0, 1, travel: 1),
                                                     StarlitCartoucheCorridor(1, 2, travel: 1),
                                                     StarlitCartoucheCorridor(0, 2, travel: 1),
                                                     StarlitCartoucheCorridor(0, 3, travel: 1),
                                                     StarlitCartoucheCorridor(0, 4, travel: 1)]
        return try StarlitCartoucheLevel(id: "failure-\(budget)", seed: 2, difficulty: 1, stars: stars, range: 12,
                                         corridors: corridors,
                                         hazards: [StarlitCartoucheHazard(corridor: 2, from: 0, to: 3)], start: 0,
                                         beacon: 2, deadline: 2, symbol: [0, 1], budget: budget)
    }

    /// A play of `level` started (stage playing).
    static func started(_ level: StarlitCartoucheLevel) throws -> StarlitCartouchePlay {
        var play: StarlitCartouchePlay = StarlitCartouchePlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// `play` after `actions` (stopping when it leaves the playing stage).
    static func flown(_ play: StarlitCartouchePlay,
                      _ actions: [StarlitCartoucheAction]) throws -> StarlitCartouchePlay {
        var p: StarlitCartouchePlay = play
        for action in actions where p.stage == .playing { try p.apply(action, expecting: p.fingerprint) }
        return p
    }

    /// The snapshot of `play` (default choice, wait `wait`).
    static func snapshot(_ play: StarlitCartouchePlay, wait: Int = 0) -> Snapshot {
        Snapshot(play: play, chosenStar: -1, chosenWait: wait, levelNumber: 1, time: 0)
    }

    /// The snapshot of a fresh play of `level`.
    static func snapshot(_ level: StarlitCartoucheLevel) -> Snapshot {
        snapshot(StarlitCartouchePlay(level: level))
    }

    /// Plays with flown legs: each sampled catalog level after all but the last leg of its plan, and fixtures after all
    /// but their last action.
    static func playsWithLegs() throws -> [StarlitCartouchePlay] {
        var plays: [StarlitCartouchePlay] = []
        for generated in catalog.prefix(8) {
            let legs: [StarlitCartoucheAction] = Array(generated.plan.legs.dropLast())
            plays.append(try flown(try started(generated.level), legs))
        }
        for fixture in StarlitCartoucheFixture.all(count: 8) {
            plays.append(try flown(try started(fixture.level), Array(fixture.actions.dropLast())))
        }
        return plays
    }

    /// The position of vertex `index` of `mesh`.
    static func point(_ mesh: Mesh, _ index: Int) -> SIMD3<Double> {
        SIMD3(mesh.positions[index].x, mesh.positions[index].y, mesh.positions[index].z)
    }

    /// The vertex indices of `mesh` of `material` whose local coordinate is `local` (any when nil).
    static func vertices(_ mesh: Mesh, _ material: Material, local: Double? = nil) -> [Int] {
        var found: [Int] = []
        for index in mesh.uvs.indices where mesh.uvs[index].x == Double(material.code) {
            if let l = local, mesh.uvs[index].y != l { continue }
            found.append(index)
        }
        return found
    }

    /// The triangle count of `mesh` whose first vertex has `material`.
    static func triangles(_ mesh: Mesh, _ material: Material) -> Int {
        var count: Int = 0
        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            if mesh.uvs[Int(mesh.indices[t])].x == Double(material.code) { count += 1 }
        }
        return count
    }

    /// The length of `v`.
    static func length(_ v: SIMD3<Double>) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }

    /// The Rec. 709 luminance of `c`.
    static func luminance(_ c: Vec4) -> Double { 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z }

    /// Whether `q` lies inside the view with a 5 % margin.
    static func inside(_ q: SIMD2<Double>?) -> Bool {
        guard let p = q else { return false }
        return p.x >= 0.05 && p.x <= 0.95 && p.y >= 0.05 && p.y <= 0.95
    }

    // MARK: Tests

    @Test func finiteAndBoundedForExtremeSettings() throws {
        let levels: [StarlitCartoucheLevel] = try Self.extremeLevels()
        #expect(levels.count == 4)
        #expect(levels[3].corridors.count == 24 && levels[3].hazards.count == 8 && levels[3].stars.count == 12)
        for level in levels {
            let snap: Snapshot = Self.snapshot(level)
            let s: Double = G.scale(snap)
            #expect(s.isFinite && s > 0 && s <= 0.75)
            #expect(abs(s - 1.5 / 17) < 1e-12)
            for tier in StarlitCartoucheTier.all {
                for glide in [0.0, 0.5, 1.0, Double.nan] {
                    let mesh: Mesh = try G.chartMesh(snap, tier: tier, glide: glide)
                    #expect(mesh.triangleCount > 0 && mesh.triangleCount < 20_000, "\(mesh.triangleCount)")
                    for index in mesh.positions.indices {
                        let p: SIMD3<Double> = Self.point(mesh, index)
                        #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
                        #expect(mesh.uvs[index].x.isFinite && mesh.uvs[index].y.isFinite)
                        if mesh.uvs[index].x != Double(Material.firmament.code) {
                            #expect(abs(p.x) <= 1.0 && p.y >= -1.5 && p.y <= 1.0 && abs(p.z) <= 1.0, "\(p)")
                        }
                    }
                }
                let glow: Mesh = try G.glowMesh(snap, tier: tier)
                for index in glow.positions.indices {
                    let p: SIMD3<Double> = Self.point(glow, index)
                    #expect(abs(p.x) <= 1.0 && abs(p.y) <= 1.0 && abs(p.z) <= 1.0, "\(p)")
                }
            }
        }
    }

    @Test func everythingInsideTheViewAtSevenAspects() throws {
        var levels: [StarlitCartoucheLevel] = Self.catalogLevels()
        #expect(levels.count == 20)
        levels.append(contentsOf: try Self.extremeLevels())
        for level in levels {
            let snap: Snapshot = Self.snapshot(level)
            for aspect in Self.aspects {
                let camera: StarlitCartoucheCamera = G.camera(snap, aspect: aspect)
                let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = G.viewBasis(camera)
                var outside: Int = 0
                for star in level.stars {
                    for beat in 0...64 {
                        let c: SIMD3<Double> = G.world(star.position(at: beat), snap)
                        for corner in [SIMD3<Double>(0, 0, 0), basis.right, basis.up * -1, basis.right * -1] {
                            if !Self.inside(G.project(c + corner * G.markRadius, camera: camera)) { outside += 1 }
                        }
                    }
                }
                for element in G.paintOrder(snap, camera: camera) {
                    if !Self.inside(G.project(element.centre, camera: camera)) { outside += 1 }
                }
                // Gauge extents: the cartouche's corners, the bars' and the track's ends, the outer pips' corners.
                let c: SIMD3<Double> = G.cartoucheCentre()
                var gauge: [SIMD3<Double>] = []
                for sx in [-1.0, 1.0] {
                    for sy in [-1.0, 1.0] {
                        gauge.append(c + basis.right * (0.25 * sx) + basis.up * (0.25 * sy))
                        gauge.append(G.beatTrackCentre() + basis.right * (0.45 * sx) + basis.up * (0.015 * sy))
                        gauge.append(G.waitPip(sx < 0 ? 0 : 8) + basis.right * (0.02 * sx) + basis.up * (0.02 * sy))
                        gauge.append(SIMD3(sx < 0 ? 0 : 0.9, -1.05, 0) + basis.up * (0.02 * sy))
                    }
                }
                for p in gauge where !Self.inside(G.project(p, camera: camera)) { outside += 1 }
                #expect(outside == 0, "\(level.id) aspect \(aspect)")
            }
        }
    }

    @Test func cameraIsTheAuthoredOneAndProjectRefusesBehind() {
        let snap: Snapshot = Self.snapshot(Self.catalogLevels()[0])
        let camera: StarlitCartoucheCamera = G.camera(snap, aspect: 1.5)
        #expect(camera.eye == SIMD3(1.2, 1.0, 2.8))
        #expect(camera.target == SIMD3(0, -0.2, 0))
        #expect(camera.aspect == 1.5)
        #expect(G.camera(snap, aspect: .nan).aspect == 1)
        #expect(G.camera(snap, aspect: 40).aspect == 10)
        let centre: SIMD2<Double>? = G.project(camera.target, camera: camera)
        #expect(centre != nil)
        if let c = centre { #expect(abs(c.x - 0.5) < 1e-9 && abs(c.y - 0.5) < 1e-9) }
        let behind: SIMD3<Double> = camera.eye + (camera.eye - camera.target)
        #expect(G.project(behind, camera: camera) == nil)
        #expect(G.project(SIMD3(.infinity, 0, 0), camera: camera) == nil)
        // The box corners sit at the fitted margin or inside it.
        for aspect in Self.aspects {
            let fitted: StarlitCartoucheCamera = G.camera(snap, aspect: aspect)
            for index in 0..<8 {
                guard let q = G.project(G.corner(index), camera: fitted) else {
                    Issue.record("corner \(index) behind")
                    continue
                }
                #expect(q.x >= 0.06 - 1e-9 && q.x <= 0.94 + 1e-9 && q.y >= 0.06 - 1e-9 && q.y <= 0.94 + 1e-9)
            }
        }
    }

    @Test func starsSitExactlyAtTheKernelPositions() throws {
        for play in try Self.playsWithLegs() {
            let snap: Snapshot = Self.snapshot(play)
            var low: SIMD3<Double> = SIMD3(repeating: Double.infinity)
            var high: SIMD3<Double> = SIMD3(repeating: -Double.infinity)
            for star in play.level.stars {
                for v in star.orbit {
                    let p: SIMD3<Double> = SIMD3(Double(v.x), Double(v.y), Double(v.z))
                    low = SIMD3(min(low.x, p.x), min(low.y, p.y), min(low.z, p.z))
                    high = SIMD3(max(high.x, p.x), max(high.y, p.y), max(high.z, p.z))
                }
            }
            let m: SIMD3<Double> = (low + high) / 2
            let s: Double = 1.5 / (max(high.x - low.x, high.y - low.y, high.z - low.z) + 1)
            #expect(G.scale(snap) == s)
            var centres: [SIMD3<Double>] = []
            for index in play.level.stars.indices {
                let v: V = play.level.stars[index].position(at: play.beat)
                #expect(snap.positions[index] == v)
                let expected: SIMD3<Double> = (SIMD3(Double(v.x), Double(v.y), Double(v.z)) - m) * s
                #expect(Self.length(G.starCentre(index, snap) - expected) < 1e-12)
                centres.append(expected)
            }
            // Level-2: one disc centre per star at its centre; level-0: every sphere vertex 0.07 from its centre.
            let flat: Mesh = try G.chartMesh(snap, tier: .of(2), glide: 1)
            let discCentres: [Int] = Self.vertices(flat, .starCore, local: 0)
            // Stars sharing a position at this beat weld into one disc centre.
            var distinct: [SIMD3<Double>] = []
            for c in centres {
                var seen: Bool = false
                for d in distinct where Self.length(c - d) < 1e-9 { seen = true }
                if !seen { distinct.append(c) }
            }
            #expect(discCentres.count == distinct.count)
            #expect(Self.triangles(flat, .starCore) == StarlitCartoucheTier.discSides * centres.count)
            for vertex in discCentres {
                var near: Bool = false
                for c in centres where Self.length(Self.point(flat, vertex) - c) < 1e-9 { near = true }
                #expect(near)
            }
            let round: Mesh = try G.chartMesh(snap, tier: .of(0), glide: 1)
            for vertex in Self.vertices(round, .starCore) {
                var near: Bool = false
                for c in centres where abs(Self.length(Self.point(round, vertex) - c) - G.starRadius) < 1e-9 {
                    near = true
                }
                #expect(near)
            }
        }
    }

    @Test func trailsRunFromTheDepartureToTheArrivalPositions() throws {
        var flownLegs: Int = 0
        for play in try Self.playsWithLegs() {
            let snap: Snapshot = Self.snapshot(play)
            let mesh: Mesh = try G.chartMesh(snap, tier: .of(1), glide: 1)
            let trailVertices: [Int] = Self.vertices(mesh, .trail)
            for (k, leg) in play.legs.enumerated() {
                flownLegs += 1
                let start: SIMD3<Double> = G.world(play.level.stars[leg.from].position(at: leg.depart), snap)
                let end: SIMD3<Double> = G.world(play.level.stars[leg.to].position(at: leg.arrive), snap)
                let ends: (start: SIMD3<Double>, end: SIMD3<Double>) = G.trailEnds(k, snap)
                #expect(Self.length(ends.start - start) < 1e-12 && Self.length(ends.end - end) < 1e-12)
                #expect(Self.length(G.trailMidpoint(k, snap) - (start + end) / 2) < 1e-12)
                guard Self.length(end - start) > 0 else { continue }
                var atStart: Int = 0
                var atEnd: Int = 0
                for vertex in trailVertices {
                    let p: SIMD3<Double> = Self.point(mesh, vertex)
                    if abs(Self.length(p - start) - G.trailWidth / 2) < 1e-9 { atStart += 1 }
                    if abs(Self.length(p - end) - G.trailWidth / 2) < 1e-9 { atEnd += 1 }
                }
                #expect(atStart >= 2 && atEnd >= 2, "leg \(k)")
            }
            // The ship rests at its star and glides along its last trail.
            #expect(Self.length(G.shipCentre(snap) - G.starCentre(play.star, snap)) < 1e-12)
            if !play.legs.isEmpty {
                let last: (start: SIMD3<Double>, end: SIMD3<Double>) = G.trailEnds(play.legs.count - 1, snap)
                #expect(Self.length(G.shipPlace(snap, glide: 0) - last.start) < 1e-12)
                #expect(Self.length(G.shipPlace(snap, glide: 0.5) - (last.start + last.end) / 2) < 1e-12)
                let still: Mesh = try G.chartMesh(snap, tier: .of(1), glide: 0)
                var others: [Vec3] = []
                var othersStill: [Vec3] = []
                for index in mesh.positions.indices where mesh.uvs[index].x != Double(Material.ship.code) {
                    others.append(mesh.positions[index])
                }
                for index in still.positions.indices where still.uvs[index].x != Double(Material.ship.code) {
                    othersStill.append(still.positions[index])
                }
                #expect(others.count == othersStill.count && Set(others) == Set(othersStill))
            } else {
                #expect(G.shipHeading(snap) == SIMD3(1, 0, 0))
            }
        }
        #expect(flownLegs > 10)
    }

    @Test func gaugesAtZeroHalfAndBudget() throws {
        var stars: [StarlitCartoucheStar] = []
        for i in 0..<4 {
            stars.append(StarlitCartoucheStar(orbit: [V(i, i % 2, 0)], glyph: StarlitCartoucheGlyphPoint(i, 0), open: 0,
                                              close: 64))
        }
        let budget: Int = 6
        let level: StarlitCartoucheLevel = try StarlitCartoucheLevel(
            id: "gauges", seed: 3, difficulty: 1, stars: stars, range: 12,
            corridors: [StarlitCartoucheCorridor(0, 1, travel: 1), StarlitCartoucheCorridor(1, 2, travel: 1),
                        StarlitCartoucheCorridor(2, 3, travel: 1)],
            hazards: [], start: 0, beacon: 2, deadline: 12, symbol: [0], budget: budget)
        var play: StarlitCartouchePlay = try Self.started(level)
        var checked: [Int] = []
        for spent in 0...budget {
            if spent > 0 {
                try play.apply(.leg(play.star == 0 ? 1 : 0, 0), expecting: play.fingerprint)
            }
            guard spent == 0 || spent == budget / 2 || spent == budget else { continue }
            let wait: Int = spent == 0 ? 0 : (spent == budget ? 8 : 4)
            let snap: Snapshot = Self.snapshot(play, wait: wait)
            #expect(snap.actionsLeft == budget - spent)
            #expect(G.litActions(snap) == budget - spent)
            #expect(G.litPips(snap) == wait + 1)
            #expect(abs(G.trackFill(snap) - Double(spent) / 12) < 1e-12)
            let mesh: Mesh = try G.chartMesh(snap, tier: .of(1), glide: 1)
            #expect(Self.vertices(mesh, .actionsLit, local: 0).count == budget - spent)
            #expect(Self.vertices(mesh, .waitLit, local: 0).count == wait + 1)
            #expect(Self.vertices(mesh, .waitUnlit, local: 0).count == 8 - wait)
            #expect(Self.vertices(mesh, .beatTrack, local: 0).count == (spent > 0 ? 1 : 0))
            #expect(Self.vertices(mesh, .beatTrackRest, local: 0).count == 1)
            for index in 0..<budget {
                let bar: SIMD3<Double> = G.actionsBar(index, snap)
                #expect(abs(bar.x - (Double(index) + 0.5) * 0.9 / Double(budget)) < 1e-12 && bar.y == -1.05)
            }
            for index in 0..<9 {
                let pip: SIMD3<Double> = G.waitPip(index)
                #expect(abs(pip.x - (Double(index) + 0.5) * 0.1) < 1e-12 && pip.y == -1.35)
            }
            // The track's fill reaches beat / deadline of the 0.9 track, measured along the view's right axis.
            let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) =
                G.viewBasis(G.camera(snap, aspect: 1))
            let left: SIMD3<Double> = G.beatTrackCentre() - basis.right * 0.45
            var reach: Double = 0
            for vertex in Self.vertices(mesh, .beatTrack) {
                reach = max(reach, G.dot(Self.point(mesh, vertex) - left, basis.right))
            }
            #expect(abs(reach - 0.9 * Double(spent) / 12) < 1e-9)
            if spent == budget {
                #expect(play.failure == .budget(budget))
                #expect(Self.vertices(mesh, .actionsUnlit, local: 0).count == spent)
                #expect(Self.triangles(mesh, .broken) == 8 * budget)
            } else {
                #expect(Self.vertices(mesh, .actionsUnlit, local: 0).count == spent)
                #expect(Self.triangles(mesh, .broken) == 0)
            }
            checked.append(spent)
        }
        #expect(checked == [0, 3, 6])
        #expect(play.stage == .failed)
    }

    @Test func wonLevelIsBrighterAndInPlace() throws {
        var wins: Int = 0
        for generated in Self.catalog.prefix(6) {
            let play: StarlitCartouchePlay = try Self.flown(try Self.started(generated.level), generated.plan.legs)
            #expect(play.stage == .won)
            guard play.stage == .won else { continue }
            wins += 1
            let snap: Snapshot = Self.snapshot(play)
            #expect(G.wonFlag(snap) == 1)
            let tier: StarlitCartoucheTier = .of(0)
            let lit: StarlitCartoucheColouredMesh = try G.chartPart(snap, tier: tier)
            let plain: StarlitCartoucheColouredMesh = try G.chartPart(snap, tier: tier, wonLevel: 0)
            #expect(lit.mesh == plain.mesh)
            #expect(lit.colours.count == lit.mesh.positions.count)
            var brighter: [Int] = Self.vertices(lit.mesh, .trail)
            brighter.append(contentsOf: Self.vertices(lit.mesh, .starCore))
            brighter.append(contentsOf: Self.vertices(lit.mesh, .strokeDrawn))
            #expect(!brighter.isEmpty)
            for vertex in brighter {
                #expect(Self.luminance(lit.colours[vertex]) > Self.luminance(plain.colours[vertex]))
            }
            // Every symbol stroke is drawn: no dashes are left.
            #expect(Self.vertices(lit.mesh, .strokeUndrawn).isEmpty && Self.vertices(lit.mesh, .symbolDash).isEmpty)
            for index in play.level.stars.indices {
                #expect(G.starCentre(index, snap) == G.world(play.level.stars[index].position(at: play.beat), snap))
            }
            for (k, leg) in play.legs.enumerated() {
                #expect(G.trailEnds(k, snap).end == G.world(play.level.stars[leg.to].position(at: leg.arrive), snap))
            }
        }
        #expect(wins == 6)
    }

    @Test func glowShellsPerTier() throws {
        var plays: [StarlitCartouchePlay] = try Self.playsWithLegs()
        plays.append(StarlitCartouchePlay(level: try Self.extremeLevels()[3]))
        for play in plays {
            let snap: Snapshot = Self.snapshot(play)
            let perShell: Int = 2 * G.glowSides * (snap.stars.count + 1)
            var trailTriangles: Int = 0
            for k in snap.legs.indices {
                let ends: (start: SIMD3<Double>, end: SIMD3<Double>) = G.trailEnds(k, snap)
                if Self.length(ends.end - ends.start) > 0 { trailTriangles += 4 }
            }
            for tier in StarlitCartoucheTier.all {
                let part: StarlitCartoucheColouredMesh = try G.glowPart(snap, tier: tier)
                #expect(part.mesh.triangleCount == tier.glowShells * (perShell + trailTriangles), "\(tier.name)")
                #expect(part.colours.count == part.mesh.positions.count)
                for index in part.mesh.uvs.indices {
                    let decoded: (kind: StarlitCartoucheShaders.GlowKind, factor: Double) =
                        StarlitCartoucheShaders.GlowKind.decode(part.mesh.uvs[index].x)
                    #expect(decoded.factor == 0.5 || decoded.factor == 0.25)
                    let n: Vec3 = part.mesh.normals[index]
                    let base: SIMD3<Double> = decoded.kind == .star ? StarlitCartouchePalette.glow
                        : (decoded.kind == .ship ? StarlitCartouchePalette.shipGlow : StarlitCartouchePalette.trailGlow)
                    #expect(SIMD3(n.x, n.y, n.z) == base)
                    let c: Vec4 = part.colours[index]
                    #expect(Self.length(SIMD3(c.x, c.y, c.z) - base * decoded.factor) < 1e-12)
                    #expect(part.mesh.uvs[index].y == 0 || part.mesh.uvs[index].y == 1)
                }
            }
            #expect(try G.glowMesh(snap, tier: .of(2)).triangleCount == 0)
        }
        #expect(StarlitCartoucheTier.all.map(\.glowShells) == [2, 1, 0])
    }

    @Test func onlySphereDetailGhostsAndGlowDifferBetweenTiers() throws {
        var plays: [StarlitCartouchePlay] = try Self.playsWithLegs()
        for level in try Self.extremeLevels() { plays.append(StarlitCartouchePlay(level: level)) }
        for play in plays {
            let snap: Snapshot = Self.snapshot(play, wait: 3)
            var reference: [Vec3]? = nil
            var lengths: [Double] = []
            for k in snap.legs.indices {
                let ends: (start: SIMD3<Double>, end: SIMD3<Double>) = G.trailEnds(k, snap)
                lengths.append(Self.length(ends.end - ends.start))
            }
            for tier in StarlitCartoucheTier.all {
                // Ghost g is drawn when it starts inside its trail (0.05 g before a trail end of length > 0.05 g).
                var ghosts: Int = 0
                for length in lengths where tier.ghosts > 0 {
                    for g in 1...tier.ghosts where G.ghostSpacing * Double(g) < length { ghosts += 1 }
                }
                let mesh: Mesh = try G.chartMesh(snap, tier: tier, glide: 1)
                var kept: [Vec3] = []
                let varying: Set<Double> = [Double(Material.starCore.code), Double(Material.trailGhost.code)]
                for index in mesh.positions.indices where !varying.contains(mesh.uvs[index].x) {
                    kept.append(mesh.positions[index])
                }
                if let r = reference {
                    #expect(kept == r, "\(play.level.id) \(tier.name)")
                } else {
                    reference = kept
                }
                #expect(Self.triangles(mesh, .trailGhost) == 2 * ghosts, "\(tier.name)")
                let perStar: Int = tier.flatStars ? StarlitCartoucheTier.discSides
                    : 2 * tier.longitudes * (tier.latitudes - 1)
                #expect(Self.triangles(mesh, .starCore) == perStar * snap.stars.count, "\(tier.name)")
            }
        }
        #expect(StarlitCartoucheTier.all.map(\.ghosts) == [3, 1, 0])
    }

    @Test func paintOrderIsSortedWithTheTieRule() throws {
        var snaps: [Snapshot] = []
        for play in try Self.playsWithLegs() { snaps.append(Self.snapshot(play)) }
        for level in try Self.extremeLevels() { snaps.append(Self.snapshot(level)) }
        for snap in snaps {
            let camera: StarlitCartoucheCamera = G.camera(snap, aspect: 1)
            let order: [StarlitCartoucheElement] = G.paintOrder(snap, camera: camera)
            let failed: Int = snap.failedLeg == nil ? 0 : 1
            #expect(order.count == snap.corridors.count + snap.hazards.count + snap.legs.count + failed
                    + snap.stars.count + 3 + 1 + snap.budget + 1 + 9)
            for k in 1..<order.count {
                let a: StarlitCartoucheElement = order[k - 1]
                let b: StarlitCartoucheElement = order[k]
                #expect(a.distance >= b.distance)
                if a.distance == b.distance {
                    #expect(a.kind.rawValue < b.kind.rawValue || (a.kind == b.kind && a.index < b.index))
                }
                #expect(abs(a.distance - Self.length(a.centre - camera.eye)) < 1e-12)
            }
            let reference: [StarlitCartoucheElement] = G.referencePoints(snap, camera: camera)
            #expect(reference.count == snap.stars.count + 1 + snap.legs.count + 1 + 1)
            for k in 1..<reference.count {
                #expect(!StarlitCartoucheElement.paintsBefore(reference[k], reference[k - 1]))
            }
            let mesh: Mesh = try G.chartMesh(snap, tier: .of(1), glide: 1)
            #expect(mesh.uvs[Int(mesh.indices[0])].x == Double(Material.firmament.code))
        }
        // The tie rule on equal distances.
        let p: SIMD3<Double> = SIMD3(0, 0, 0)
        let star3: StarlitCartoucheElement = StarlitCartoucheElement(kind: .star, index: 3, centre: p, distance: 2)
        let star1: StarlitCartoucheElement = StarlitCartoucheElement(kind: .star, index: 1, centre: p, distance: 2)
        let corridor: StarlitCartoucheElement = StarlitCartoucheElement(kind: .corridor, index: 9, centre: p,
                                                                        distance: 2)
        let ship: StarlitCartoucheElement = StarlitCartoucheElement(kind: .ship, index: 0, centre: p, distance: 2)
        let pip: StarlitCartoucheElement = StarlitCartoucheElement(kind: .waitPip, index: 0, centre: p, distance: 2)
        let far: StarlitCartoucheElement = StarlitCartoucheElement(kind: .waitPip, index: 5, centre: p, distance: 3)
        var list: [StarlitCartoucheElement] = [pip, star3, ship, corridor, star1, far]
        list.sort(by: StarlitCartoucheElement.paintsBefore)
        #expect(list == [far, corridor, star1, star3, ship, pip])
    }

    @Test func eachFailureKindIsMarked() throws {
        let level: StarlitCartoucheLevel = try Self.failureLevel(budget: 1)
        let healthy: Mesh = try G.chartMesh(Self.snapshot(try Self.started(level)), tier: .of(1), glide: 1)
        #expect(Self.triangles(healthy, .broken) == 0)
        let ring: Int = 2 * G.ringSegments
        let cases: [(action: StarlitCartoucheAction, code: String, broken: Int)] = [
            (.leg(1, 3), "window", ring + 2), (.leg(2, 0), "hazard", 2 + 2), (.leg(3, 0), "window", ring + 2),
            (.leg(4, 2), "deadline", 8 + 2), (.leg(4, 0), "stroke", 2 + 2), (.leg(1, 0), "budget", 8),
        ]
        var kinds: [String] = []
        for row in cases {
            let play: StarlitCartouchePlay = try Self.flown(try Self.started(level), [row.action])
            #expect(play.stage == .failed)
            guard let failure = play.failure else {
                Issue.record("no failure for \(row.action)")
                continue
            }
            #expect(failure.code == row.code)
            let snap: Snapshot = Self.snapshot(play)
            let mesh: Mesh = try G.chartMesh(snap, tier: .of(1), glide: 1)
            #expect(Self.triangles(mesh, .broken) == row.broken, "\(failure)")
            let brokenPoints: [SIMD3<Double>] = Self.vertices(mesh, .broken).map { Self.point(mesh, $0) }
            switch failure {
            case .departure(let star, _, _), .arrival(let star, _, _, _):
                kinds.append(star == 0 ? "departure" : "arrival")
                #expect(G.markedStar(snap) == star)
                var onRing: Int = 0
                for p in brokenPoints {
                    let r: Double = Self.length(p - G.starCentre(star, snap))
                    if abs(r - G.markRadius) <= G.markWidth / 2 + 1e-9 { onRing += 1 }
                }
                #expect(onRing >= 2 * G.ringSegments)
            case .hazard(_, let hazard, _, _):
                kinds.append("hazard")
                #expect(G.markedHazard(snap) == hazard)
                #expect(Self.vertices(mesh, .hazardActive).isEmpty && Self.vertices(mesh, .hazardIdle).isEmpty)
            case .deadline:
                kinds.append("deadline")
                #expect(G.marksBeatTrack(snap))
                var nearTrack: Int = 0
                for p in brokenPoints where abs(p.y - G.trackY) < 0.05 && p.x > -0.05 && p.x < 0.95 { nearTrack += 1 }
                #expect(nearTrack == 8)
            case .stroke(let corridor):
                kinds.append("stroke")
                #expect(G.markedStroke(snap) == corridor)
                var inCartouche: Int = 0
                for p in brokenPoints where Self.length(p - G.cartoucheCentre()) < 0.4 { inCartouche += 1 }
                #expect(inCartouche == 4)
            case .budget:
                kinds.append("budget")
                #expect(G.marksActionsBars(snap))
                #expect(snap.failedLeg == nil)
            }
            // A leg failure draws the failed leg from the departure to the arrival position; the ship stays.
            if let leg = snap.failedLeg {
                let ends: (start: SIMD3<Double>, end: SIMD3<Double>)? = G.failedLegEnds(snap)
                #expect(ends?.start == G.world(level.stars[leg.from].position(at: leg.depart), snap))
                #expect(ends?.end == G.world(level.stars[leg.to].position(at: leg.arrive), snap))
                #expect(snap.star == level.start && snap.legs.isEmpty)
            }
        }
        #expect(kinds == ["departure", "hazard", "arrival", "deadline", "stroke", "budget"])
        // The same level with a budget of 2 is won by legs to stars 1 and 2.
        let won: StarlitCartouchePlay = try Self.flown(try Self.started(try Self.failureLevel(budget: 2)),
                                                       [.leg(1, 0), .leg(2, 0)])
        #expect(won.stage == .won)
        #expect(Self.triangles(try G.chartMesh(Self.snapshot(won), tier: .of(0), glide: 1), .broken) == 0)
    }

    @Test func vertexStreamsFollowTheShaderContract() throws {
        typealias S = StarlitCartoucheShaders
        var plays: [StarlitCartouchePlay] = try Self.playsWithLegs()
        plays.append(StarlitCartouchePlay(level: try Self.extremeLevels()[3]))
        plays.append(try Self.flown(try Self.started(try Self.failureLevel(budget: 1)), [.leg(2, 0)]))
        var seen: Set<Int> = []
        for play in plays {
            let snap: Snapshot = Self.snapshot(play, wait: 2)
            for tier in StarlitCartoucheTier.all {
                let part: StarlitCartoucheColouredMesh = try G.chartPart(snap, tier: tier, glide: 1)
                let mesh: Mesh = part.mesh
                var notchCounts: Set<Int> = []
                var notchSeam: Bool = false
                var chosenSeam: Bool = false
                var shipVertices: [Int] = []
                for index in mesh.positions.indices {
                    let code: Double = mesh.uvs[index].x
                    let local: Double = mesh.uvs[index].y
                    let n: SIMD3<Double> = SIMD3(mesh.normals[index].x, mesh.normals[index].y, mesh.normals[index].z)
                    guard code == code.rounded(), let material = Material(rawValue: Int(code)) else {
                        Issue.record("code \(code)")
                        continue
                    }
                    seen.insert(material.rawValue)
                    // The fallback colour is the shader's material colour (no won level here, the firmament's ends).
                    let c: Vec4 = part.colours[index]
                    if material != .firmament && G.wonFlag(snap) == 0 {
                        #expect(Self.length(SIMD3(c.x, c.y, c.z) - material.colour) < 1e-12, "\(material)")
                    }
                    switch material.localCoordinate {
                    case .firmament:
                        #expect((local == 0 || local == 1) && abs(n.x) == 1 && n.y == 0 && n.z == 0)
                    case .strip:
                        #expect(abs(local) == 1 && n == SIMD3(0, 0, 0), "\(material)")
                    case .stripAlong:
                        #expect(abs(local) == 1 && n.x >= 0 && n.x <= 2 && n.y == 0 && n.z == 0, "\(material)")
                    case .trail:
                        #expect(abs(local) == 1 && (n.x == 0 || n.x == 1) && n.y == 0 && n.z == 0)
                    case .ghost:
                        var fades: [Double] = []
                        for g in 0..<tier.ghosts { fades.append(S.ghostFade(index: g, count: tier.ghosts)) }
                        #expect(abs(local) == 1 && (n.x == 0 || n.x == 1) && fades.contains(n.y) && n.z == 0)
                    case .sphere:
                        if tier.flatStars {
                            #expect(n == S.viewDirection && local >= 0 && local <= 1)
                        } else {
                            #expect(abs(Self.length(n) - 1) < 1e-12 && local == 0)
                        }
                    case .ring:
                        #expect(abs(local) == 1 && n.x >= 0 && n.x <= 1 && n.z == 0)
                        if material == .starNotches {
                            notchCounts.insert(Int(n.y))
                            if n.x == 1 { notchSeam = true }
                        } else {
                            #expect(n.y == 0)
                            if n.x == 1 { chosenSeam = true }
                        }
                    case .arrow:
                        #expect(local == 0 && abs(n.x) == S.arrowQuadExtent && abs(n.y) == S.arrowQuadExtent)
                        shipVertices.append(index)
                    case .fan:
                        #expect((local == 0 || local == 1) && n == SIMD3(0, 0, 0), "\(material)")
                    }
                }
                var expectedCounts: Set<Int> = []
                for index in snap.stars.indices { expectedCounts.insert(index % 6 + 1) }
                #expect(notchCounts == expectedCounts && notchSeam && chosenSeam)
                // The ship's quad: u = +extent lies extent · 0.07 ahead of the ship along its heading.
                #expect(shipVertices.count == 4)
                let centre: SIMD3<Double> = G.shipCentre(snap)
                let heading: SIMD3<Double> = G.shipHeading(snap)
                for vertex in shipVertices {
                    let ahead: Double = G.dot(Self.point(mesh, vertex) - centre, heading)
                    #expect(abs(ahead - mesh.normals[vertex].x * G.shipLength / 2) < 1e-9)
                }
            }
        }
        // Dashes and stripes carry the distance along: an undrawn symbol corridor's far end is its length.
        let snap: Snapshot = Self.snapshot(try Self.started(try Self.failureLevel(budget: 1)))
        let mesh: Mesh = try G.chartMesh(snap, tier: .of(2), glide: 1)
        var farthest: Double = 0
        for vertex in Self.vertices(mesh, .symbolDash) { farthest = max(farthest, mesh.normals[vertex].x) }
        let corridor0: Double = Self.length(G.starCentre(1, snap) - G.starCentre(0, snap))
        #expect(abs(farthest - max(corridor0, Self.length(G.starCentre(2, snap) - G.starCentre(1, snap)))) < 1e-12)
        var expected: Set<Int> = Set(0...21)
        expected.subtract([Material.strokeDrawn.rawValue, Material.waitUnlit.rawValue])
        #expect(seen.isSuperset(of: expected), "\(expected.subtracting(seen).sorted())")
    }
}
