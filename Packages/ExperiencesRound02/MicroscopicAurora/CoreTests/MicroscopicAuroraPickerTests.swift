// MicroscopicAuroraPickerTests — feature 484 (R02-G19-04) T-R02G1904-002 (FR-R02G1904-001 … 003, 006; SC-R02G1904-001,
// 004). The analytic picker against an independent rule written here: 500 seeded touches (seed 2_484) over certified
// levels (`MicroscopicAuroraGenerator.generate` of four manifest entries, two wells placed on their sites), three view
// sizes and three view orbits, each judged by its own pinhole projection of the drawn camera — a well within its
// projected spiral radius (0.45 cell) grown by 12 points (later slots first), else a site within its projected ring
// radius (0.35 cell) grown by 12 points (higher index first), else the scrubber within 14 points of its projected
// track, else the field when the finger casts inside the enclosure, else empty — with its dish point (the ray cast onto
// z = 0 in dish units), drop target (the nearest site within 24 points, lower index on ties; nil on a well's site;
// removal outside the enclosure) and scrub tick (round(fraction × ticks swum) of the cast point along the track); the
// allowances at their edges (half a point inside and outside); overlapping targets (the one drawn last wins); round
// trips (a site's projected centre casts back onto its cell centre; the scrubber mark reads the shown tick); unusable
// input (non-finite points, sizes not finite and positive). Explicit types, plain loops; each test well under 10 s; no
// wall-clock asserts.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

struct MicroscopicAuroraPickerTests {
    typealias P = MicroscopicAuroraPicker
    typealias G = MicroscopicAuroraSceneGeometry
    typealias Snapshot = MicroscopicAuroraSceneSnapshot
    typealias Level = MicroscopicAuroraLevel
    typealias ViewOrbit = MicroscopicAuroraViewOrbit
    typealias Play = MicroscopicAuroraPlay
    typealias Cell = MicroscopicAuroraCell
    typealias Well = MicroscopicAuroraWell
    typealias Pick = MicroscopicAuroraPick
    typealias Target = MicroscopicAuroraPreviewTarget

    /// The feature's test seed.
    static let seed: UInt64 = 2_484

    /// The three view sizes in points: a phone upright, a phone on its side, a tablet.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(844, 390), SIMD2(1024, 768)]

    /// The three view orbits: the authored one and two within bounds.
    static let orbits: [ViewOrbit] = [.authored, ViewOrbit(yaw: 0.7, pitch: 0.4), ViewOrbit(yaw: -0.9, pitch: -0.3)]

    /// The manifest numbers whose certified levels are used.
    static let numbers: [Int] = [1, 21, 41, 81]

    /// The certified levels of ``numbers``: `MicroscopicAuroraGenerator.generate` of each entry (no neighbour).
    static let levels: [Level] = {
        var result: [Level] = []
        for number in numbers {
            let entry: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifest.entries[number - 1]
            if let generated = try? MicroscopicAuroraGenerator.generate(entry, previous: nil) {
                result.append(generated.level)
            }
        }
        return result
    }()

    /// The snapshot of a play of `level` with a strength-2 counterclockwise well on site 0 in slot 0 and a strength-4
    /// clockwise well on site 2 in slot 2 (site 1 and later sites empty), tick `tick` shown.
    static func snapshot(_ level: Level, tick: Int) throws -> Snapshot {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        let sites: [Cell] = level.sites ?? []
        if sites.count >= 3 {
            try play.apply(.place(slot: 0, well: Well(cell: sites[0], strength: 2, sense: .counterclockwise)),
                           expecting: play.fingerprint)
            try play.apply(.place(slot: 2, well: Well(cell: sites[2], strength: 4, sense: .clockwise)),
                           expecting: play.fingerprint)
        }
        return Snapshot(play: play, shownTick: tick, levelNumber: 1, time: 0)
    }

    // MARK: The independent rule

    /// A pinhole lens of the drawn camera in a view of `size` points.
    struct Lens {
        let eye: SIMD3<Double>
        let forward: SIMD3<Double>
        let right: SIMD3<Double>
        let up: SIMD3<Double>
        let tanHalf: Double
        let aspect: Double
        let size: SIMD2<Double>
    }

    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    static func unit(_ v: SIMD3<Double>) -> SIMD3<Double> { v / dot(v, v).squareRoot() }

    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// The lens of the camera drawn in a view of `size` from `orbit`.
    static func lens(size: SIMD2<Double>, orbit: ViewOrbit) -> Lens {
        let camera: MicroscopicAuroraCamera = G.camera(aspect: size.x / size.y, orbit: orbit)
        let forward: SIMD3<Double> = unit(camera.target - camera.eye)
        let right: SIMD3<Double> = unit(SIMD3(-forward.z, 0, forward.x))
        let ux: Double = right.y * forward.z - right.z * forward.y
        let uy: Double = right.z * forward.x - right.x * forward.z
        let uz: Double = right.x * forward.y - right.y * forward.x
        return Lens(eye: camera.eye, forward: forward, right: right, up: SIMD3(ux, uy, uz),
                    tanHalf: tan(camera.fovY / 2), aspect: camera.aspect, size: size)
    }

    /// `p` in view points (origin top left, y down) through `lens`; nil behind the eye.
    static func screen(_ p: SIMD3<Double>, _ lens: Lens) -> SIMD2<Double>? {
        let d: SIMD3<Double> = p - lens.eye
        let depth: Double = dot(d, lens.forward)
        guard depth > 0 else { return nil }
        let x: Double = dot(d, lens.right) / (depth * lens.tanHalf * lens.aspect)
        let y: Double = dot(d, lens.up) / (depth * lens.tanHalf)
        return SIMD2((x + 1) / 2 * lens.size.x, (1 - y) / 2 * lens.size.y)
    }

    /// World extent `extent` at `p` in view points through `lens`.
    static func extent(_ extent: Double, at p: SIMD3<Double>, _ lens: Lens) -> Double {
        extent / (dot(p - lens.eye, lens.forward) * lens.tanHalf) * lens.size.y / 2
    }

    /// The world point of cell `cell`'s centre: ((256 c + 128 − 3072), (3072 − 256 r − 128)) · 0.9 / 2816, z = 0.
    static func world(_ cell: Cell) -> SIMD3<Double> {
        let x: Double = Double(cell.column * 256 + 128 - 3072)
        let y: Double = Double(3072 - cell.row * 256 - 128)
        return SIMD3(x * 0.9 / 2816, y * 0.9 / 2816, 0)
    }

    /// One cell's side in world units.
    static let cell: Double = 256 * 0.9 / 2816

    /// The distance from `q` to the segment `a` → `b`.
    static func segment(_ q: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = b - a
        let l2: Double = d.x * d.x + d.y * d.y
        if l2 == 0 { return distance(q, a) }
        let t: Double = max(0, min(1, ((q.x - a.x) * d.x + (q.y - a.y) * d.y) / l2))
        return distance(q, SIMD2(a.x + d.x * t, a.y + d.y * t))
    }

    /// The independent cast of `point` onto z = 0 in world units; nil when the ray misses the plane.
    static func cast(_ point: SIMD2<Double>, _ lens: Lens) -> SIMD3<Double>? {
        let x: Double = (2 * point.x / lens.size.x - 1) * lens.tanHalf * lens.aspect
        let y: Double = (1 - 2 * point.y / lens.size.y) * lens.tanHalf
        let ray: SIMD3<Double> = lens.forward + lens.right * x + lens.up * y
        guard ray.z < 0 else { return nil }
        let t: Double = -lens.eye.z / ray.z
        return lens.eye + ray * t
    }

    /// The independent dish point: the cast in dish units (x right, y down the dish).
    static func expectedDish(_ point: SIMD2<Double>, _ lens: Lens) -> SIMD2<Double>? {
        guard let hit = cast(point, lens) else { return nil }
        return SIMD2(3072 + hit.x * 2816 / 0.9, 3072 - hit.y * 2816 / 0.9)
    }

    /// Whether `point` casts inside the enclosure of `snapshot`.
    static func expectedInside(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> Bool {
        guard let d = expectedDish(point, lens) else { return false }
        let r: Double = Double(snapshot.radius * 256)
        return (d.x - 3072) * (d.x - 3072) + (d.y - 3072) * (d.y - 3072) <= r * r
    }

    /// The independent pick (see the header).
    static func expectedPick(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> Pick {
        var slot: Int = snapshot.wells.count - 1
        while slot >= 0 {
            if let well = snapshot.wells[slot], let c = screen(world(well.cell), lens),
               distance(point, c) <= extent(0.45 * cell, at: world(well.cell), lens) + 12 {
                return .well(slot)
            }
            slot -= 1
        }
        var index: Int = snapshot.sites.count - 1
        while index >= 0 {
            let w: SIMD3<Double> = world(snapshot.sites[index])
            if let c = screen(w, lens), distance(point, c) <= extent(0.35 * cell, at: w, lens) + 12 {
                return .site(index)
            }
            index -= 1
        }
        if let a = screen(SIMD3(-0.9, -1.31, 0), lens), let b = screen(SIMD3(0.9, -1.31, 0), lens),
           segment(point, a, b) <= 14 {
            return .scrubber
        }
        if expectedInside(point, snapshot, lens) { return .field }
        return .empty
    }

    /// The independent drop target of a well of slot `slot`.
    static func expectedDrop(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> Target? {
        var best: Int = -1
        var bestDistance: Double = Double.infinity
        for (index, site) in snapshot.sites.enumerated() {
            guard let c = screen(world(site), lens) else { continue }
            let d: Double = distance(point, c)
            if d <= 24 && d < bestDistance {
                best = index
                bestDistance = d
            }
        }
        if best >= 0 {
            let site: Cell = snapshot.sites[best]
            for well in snapshot.wells where well?.cell == site { return nil }
            return .site(site)
        }
        return expectedInside(point, snapshot, lens) ? nil : .removal
    }

    /// The independent scrub tick.
    static func expectedTick(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> Int {
        guard let hit = cast(point, lens) else { return snapshot.shownTick }
        let fraction: Double = max(0, min(1, (hit.x + 0.9) / 1.8))
        return Int((fraction * Double(snapshot.ticksSwum)).rounded(.toNearestOrAwayFromZero))
    }

    // MARK: Tests

    @Test func fiveHundredSeededTouchesMatchTheIndependentRule() throws {
        #expect(Self.levels.count == Self.numbers.count)
        var snapshots: [Snapshot] = []
        for level in Self.levels { snapshots.append(try Self.snapshot(level, tick: 0)) }
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var counts: [String: Int] = [:]
        var drops: [String: Int] = [:]
        for k in 0..<500 {
            let base: Snapshot = snapshots[k % snapshots.count]
            let size: SIMD2<Double> = Self.sizes[(k / snapshots.count) % Self.sizes.count]
            let orbit: ViewOrbit = Self.orbits[(k / (snapshots.count * Self.sizes.count)) % Self.orbits.count]
            let tick: Int = random.int(0...base.ticksSwum)
            let snap: Snapshot = Snapshot(radius: base.radius, positions: base.positions, velocities: base.velocities,
                                          ticksSwum: base.ticksSwum, shownTick: tick, density: base.density,
                                          litStencil: base.litStencil, stray: base.stray, stencil: base.stencil,
                                          sites: base.sites, wells: base.wells, coverage: base.coverage,
                                          requiredCoverage: base.requiredCoverage, coherence: base.coherence,
                                          requiredCoherence: base.requiredCoherence, swarm: base.swarm,
                                          coherenceRadius: base.coherenceRadius, failure: base.failure,
                                          stage: base.stage, actionsLeft: base.actionsLeft, budget: base.budget,
                                          levelNumber: base.levelNumber, time: base.time)
            let lens: Lens = Self.lens(size: size, orbit: orbit)
            var point: SIMD2<Double> = SIMD2(random.range(0...size.x), random.range(0...size.y))
            let kind: Int = k % 5
            if kind == 0 || kind == 1 {
                // Around a well (kind 0) or a site (kind 1), up to 1.5 times its reach.
                let cells: [Cell] = kind == 0 ? snap.wells.compactMap { $0?.cell } : snap.sites
                let target: Cell = cells[random.int(0...(cells.count - 1))]
                if let c = Self.screen(Self.world(target), lens) {
                    let share: Double = kind == 0 ? 0.45 : 0.35
                    let reach: Double = Self.extent(share * Self.cell, at: Self.world(target), lens) + 12
                    let angle: Double = random.range(0...(2 * Double.pi))
                    let r: Double = random.range(0...(reach * 1.5))
                    point = SIMD2(c.x + r * cos(angle), c.y + r * sin(angle))
                }
            } else if kind == 2 {
                // Around the scrubber track.
                if let a = Self.screen(SIMD3(-0.9, -1.31, 0), lens), let b = Self.screen(SIMD3(0.9, -1.31, 0), lens) {
                    let f: Double = random.double()
                    point = SIMD2(a.x + (b.x - a.x) * f + random.range(-20...20),
                                  a.y + (b.y - a.y) * f + random.range(-20...20))
                }
            } else if kind == 3 {
                // Inside or just outside the enclosure.
                let r: Double = G.rimRadius(snap) * random.range(0...1.2)
                let angle: Double = random.range(0...(2 * Double.pi))
                if let c = Self.screen(SIMD3(r * cos(angle), r * sin(angle), 0), lens) { point = c }
            }
            let picked: Pick = P.pick(point, size: size, snapshot: snap, orbit: orbit)
            let expected: Pick = Self.expectedPick(point, snap, lens)
            #expect(picked == expected, "touch \(k) \(size) \(orbit): \(picked) vs \(expected)")
            switch picked {
            case .well: counts["well", default: 0] += 1
            case .site: counts["site", default: 0] += 1
            default: counts["\(picked)", default: 0] += 1
            }
            let slot: Int = k % 3
            let drop: Target? = P.dropTarget(point, slot: slot, size: size, snapshot: snap, orbit: orbit)
            #expect(drop == Self.expectedDrop(point, snap, lens), "touch \(k)")
            switch drop {
            case .site: drops["site", default: 0] += 1
            case .removal: drops["removal", default: 0] += 1
            case nil: drops["none", default: 0] += 1
            }
            let read: Int = P.scrubTick(point, size: size, snapshot: snap, orbit: orbit)
            #expect(read == Self.expectedTick(point, snap, lens), "touch \(k)")
            #expect(read >= 0 && read <= snap.ticksSwum)
            let dish: SIMD2<Double>? = P.dishPoint(point, size: size, orbit: orbit)
            let expectedDish: SIMD2<Double>? = Self.expectedDish(point, lens)
            #expect((dish == nil) == (expectedDish == nil), "touch \(k)")
            if let d = dish, let e = expectedDish { #expect(Self.distance(d, e) <= 1e-6, "touch \(k)") }
        }
        // Every kind of pick and of drop occurs.
        for name in ["well", "site", "scrubber", "field", "empty"] {
            #expect((counts[name] ?? 0) > 0, "\(name): \(counts)")
        }
        for name in ["site", "removal", "none"] {
            #expect((drops[name] ?? 0) > 0, "\(name): \(drops)")
        }
    }

    @Test func allowancesAtTheirEdges() throws {
        let snap: Snapshot = try Self.snapshot(Self.levels[1], tick: 0)
        for size in Self.sizes {
            for orbit in Self.orbits {
                let lens: Lens = Self.lens(size: size, orbit: orbit)
                // The well in slot 2: half a point inside its reach, and half a point outside (not that well).
                let well: Cell = try #require(snap.wells[2]?.cell)
                let wc: SIMD2<Double> = try #require(Self.screen(Self.world(well), lens))
                let wellReach: Double = Self.extent(0.45 * Self.cell, at: Self.world(well), lens) + 12
                #expect(P.markerAllowance == 12)
                #expect(P.pick(wc + SIMD2(wellReach - 0.5, 0), size: size, snapshot: snap, orbit: orbit) == .well(2))
                #expect(P.pick(wc + SIMD2(wellReach + 0.5, 0), size: size, snapshot: snap, orbit: orbit) != .well(2))
                // The empty site 1.
                let site: Cell = snap.sites[1]
                let sc: SIMD2<Double> = try #require(Self.screen(Self.world(site), lens))
                let siteReach: Double = Self.extent(0.35 * Self.cell, at: Self.world(site), lens) + 12
                #expect(P.pick(sc + SIMD2(0, siteReach - 0.5), size: size, snapshot: snap, orbit: orbit) == .site(1))
                #expect(P.pick(sc + SIMD2(0, siteReach + 0.5), size: size, snapshot: snap, orbit: orbit) != .site(1))
                // A dragged well snaps to the empty site within 24 points.
                #expect(P.siteReach == 24)
                let near: Target? = P.dropTarget(sc + SIMD2(23.5, 0), slot: 0, size: size, snapshot: snap,
                                                 orbit: orbit)
                #expect(near == .site(site), "\(size) \(orbit)")
                let far: Target? = P.dropTarget(sc + SIMD2(24.5, 0), slot: 0, size: size, snapshot: snap,
                                                orbit: orbit)
                #expect(far != .site(site), "\(size) \(orbit)")
                // On a well's site (its own or another's): no change.
                #expect(P.dropTarget(wc, slot: 2, size: size, snapshot: snap, orbit: orbit) == nil)
                #expect(P.dropTarget(wc, slot: 0, size: size, snapshot: snap, orbit: orbit) == nil)
                // The scrubber band at the track's middle, perpendicular to the projected track.
                let a: SIMD2<Double> = try #require(Self.screen(SIMD3(-0.9, -1.31, 0), lens))
                let b: SIMD2<Double> = try #require(Self.screen(SIMD3(0.9, -1.31, 0), lens))
                let mid: SIMD2<Double> = (a + b) / 2
                let along: SIMD2<Double> = (b - a) / Self.distance(a, b)
                let normal: SIMD2<Double> = SIMD2(-along.y, along.x)
                #expect(P.scrubberBand == 14)
                #expect(P.pick(mid + normal * 13.5, size: size, snapshot: snap, orbit: orbit) == .scrubber)
                #expect(P.pick(mid - normal * 13.5, size: size, snapshot: snap, orbit: orbit) == .scrubber)
                #expect(P.pick(mid + normal * 14.5, size: size, snapshot: snap, orbit: orbit) != .scrubber)
                // Off the dish, well away from the scrubber: removal; on the open field: no change.
                #expect(P.dropTarget(SIMD2(1, 1), slot: 0, size: size, snapshot: snap, orbit: orbit) == .removal)
                let centre: SIMD2<Double> = try #require(Self.screen(SIMD3(0, 0, 0), lens))
                if P.pick(centre, size: size, snapshot: snap, orbit: orbit) == .field {
                    #expect(P.dropTarget(centre, slot: 0, size: size, snapshot: snap, orbit: orbit) == nil)
                }
            }
        }
    }

    @Test func overlappingTargetsPickTheOneDrawnLast() throws {
        let level: Level = Self.levels[0]
        let base: Snapshot = try Self.snapshot(level, tick: 0)
        let a: Cell = Cell(row: 11, column: 11)
        let b: Cell = Cell(row: 11, column: 12)
        // Two wells on neighbouring cells (slots 0 and 1) and two sites on them, seen in a small view where the
        // allowances overlap: between them the later slot wins, and a well always wins over its site.
        let snap: Snapshot = Snapshot(radius: base.radius, positions: base.positions, velocities: base.velocities,
                                      ticksSwum: base.ticksSwum, shownTick: 0, density: base.density,
                                      litStencil: base.litStencil, stray: base.stray, stencil: base.stencil,
                                      sites: [a, b], wells: [Well(cell: a, strength: 1, sense: .clockwise),
                                                             Well(cell: b, strength: 1, sense: .clockwise), nil],
                                      coverage: base.coverage, requiredCoverage: base.requiredCoverage,
                                      coherence: base.coherence, requiredCoherence: base.requiredCoherence,
                                      swarm: base.swarm, coherenceRadius: base.coherenceRadius, failure: nil,
                                      stage: .playing, actionsLeft: 3, budget: 3, levelNumber: 1, time: 0)
        let size: SIMD2<Double> = SIMD2(200, 200)
        let lens: Lens = Self.lens(size: size, orbit: .authored)
        let ca: SIMD2<Double> = try #require(Self.screen(Self.world(a), lens))
        let cb: SIMD2<Double> = try #require(Self.screen(Self.world(b), lens))
        let between: SIMD2<Double> = (ca + cb) / 2
        #expect(P.pick(between, size: size, snapshot: snap, orbit: .authored) == .well(1))
        #expect(P.pick(ca, size: size, snapshot: snap, orbit: .authored) == .well(1))
        // Without the wells, the sites overlap and the higher index wins; a nearer site wins a drop (lower on ties).
        let bare: Snapshot = Snapshot(radius: snap.radius, positions: snap.positions, velocities: snap.velocities,
                                      ticksSwum: snap.ticksSwum, shownTick: 0, density: snap.density,
                                      litStencil: snap.litStencil, stray: snap.stray, stencil: snap.stencil,
                                      sites: [a, b], wells: [nil, nil, nil], coverage: snap.coverage,
                                      requiredCoverage: snap.requiredCoverage, coherence: snap.coherence,
                                      requiredCoherence: snap.requiredCoherence, swarm: snap.swarm,
                                      coherenceRadius: snap.coherenceRadius, failure: nil, stage: .playing,
                                      actionsLeft: 3, budget: 3, levelNumber: 1, time: 0)
        #expect(P.pick(between, size: size, snapshot: bare, orbit: .authored) == .site(1))
        #expect(P.dropTarget(ca, slot: 0, size: size, snapshot: bare, orbit: .authored) == .site(a))
        #expect(P.dropTarget(cb, slot: 0, size: size, snapshot: bare, orbit: .authored) == .site(b))
        #expect(P.dropTarget(between, slot: 0, size: size, snapshot: bare, orbit: .authored) == .site(a))
        // The same in a large view: the targets separate, the gap between them is the field.
        let large: SIMD2<Double> = SIMD2(4000, 4000)
        let big: Lens = Self.lens(size: large, orbit: .authored)
        let la: SIMD2<Double> = try #require(Self.screen(Self.world(a), big))
        let lb: SIMD2<Double> = try #require(Self.screen(Self.world(b), big))
        #expect(P.pick((la + lb) / 2, size: large, snapshot: bare, orbit: .authored) == .field)
    }

    @Test func roundTripsAndProjection() throws {
        let snap: Snapshot = try Self.snapshot(Self.levels[2], tick: 0)
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: MicroscopicAuroraCamera = try #require(P.camera(size: size, orbit: orbit))
                #expect(camera == G.camera(aspect: size.x / size.y, orbit: orbit))
                // A site's projected centre casts back onto its cell centre.
                for site in snap.sites {
                    let v: SIMD2<Double> = try #require(P.viewPoint(G.cellCentre(site), size: size, camera: camera))
                    let d: SIMD2<Double> = try #require(P.dishPoint(v, size: size, orbit: orbit))
                    #expect(abs(d.x - Double(site.centre.x)) < 1e-6 && abs(d.y - Double(site.centre.y)) < 1e-6)
                }
                // The scrubber at every tenth of the swim reads its tick.
                for step in 0...10 {
                    let tick: Int = snap.ticksSwum * step / 10
                    let fraction: Double = Double(tick) / Double(max(snap.ticksSwum, 1))
                    let v: SIMD2<Double> = try #require(P.viewPoint(G.scrubberPoint(fraction), size: size,
                                                                    camera: camera))
                    #expect(P.scrubTick(v, size: size, snapshot: snap, orbit: orbit) == tick, "\(tick)")
                    #expect(P.pick(v, size: size, snapshot: snap, orbit: orbit) == .scrubber)
                }
                // Beyond the ends the tick clamps.
                let left: SIMD2<Double> = try #require(P.viewPoint(SIMD3(-0.98, -1.31, 0), size: size,
                                                                   camera: camera))
                let right: SIMD2<Double> = try #require(P.viewPoint(SIMD3(0.98, -1.31, 0), size: size,
                                                                    camera: camera))
                #expect(P.scrubTick(left, size: size, snapshot: snap, orbit: orbit) == 0)
                #expect(P.scrubTick(right, size: size, snapshot: snap, orbit: orbit) == snap.ticksSwum)
                // Behind the eye nothing projects.
                #expect(P.viewPoint(camera.eye + (camera.eye - camera.target), size: size, camera: camera) == nil)
                // The extent of a world unit shrinks with depth.
                let near: Double = try #require(P.projectedExtent(0.1, at: SIMD3(0, 0, 0.0), size: size,
                                                                  camera: camera))
                let far: Double = try #require(P.projectedExtent(0.1, at: camera.target - (camera.eye
                                                                  - camera.target), size: size, camera: camera))
                #expect(near > far && far > 0)
            }
        }
    }

    @Test func unusableInputPicksNothing() throws {
        let snap: Snapshot = try Self.snapshot(Self.levels[3], tick: 5)
        let good: SIMD2<Double> = SIMD2(390, 844)
        let points: [SIMD2<Double>] = [SIMD2(.nan, 10), SIMD2(10, .infinity), SIMD2(-.infinity, .nan)]
        for point in points {
            #expect(P.pick(point, size: good, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.dishPoint(point, size: good, orbit: .authored) == nil)
            #expect(P.dropTarget(point, slot: 0, size: good, snapshot: snap, orbit: .authored) == nil)
            #expect(P.scrubTick(point, size: good, snapshot: snap, orbit: .authored) == 5)
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 100), SIMD2(100, -1), SIMD2(.nan, 100), SIMD2(100, .infinity)]
        for size in sizes {
            #expect(P.pick(SIMD2(50, 50), size: size, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.camera(size: size, orbit: .authored) == nil)
            #expect(P.dishPoint(SIMD2(50, 50), size: size, orbit: .authored) == nil)
            #expect(P.dropTarget(SIMD2(50, 50), slot: 0, size: size, snapshot: snap, orbit: .authored) == nil)
            #expect(P.scrubTick(SIMD2(50, 50), size: size, snapshot: snap, orbit: .authored) == 5)
            let camera: MicroscopicAuroraCamera = G.camera(aspect: 1)
            #expect(P.viewPoint(SIMD3(0, 0, 0), size: size, camera: camera) == nil)
        }
        // A non-finite orbit counts as the authored one.
        let wild: ViewOrbit = ViewOrbit(yaw: .nan, pitch: .infinity)
        #expect(wild.clamped() == .authored)
        #expect(G.camera(aspect: 1, orbit: wild) == G.camera(aspect: 1))
        let centre: SIMD2<Double> = SIMD2(195, 422)
        #expect(P.pick(centre, size: good, snapshot: snap, orbit: wild)
                == P.pick(centre, size: good, snapshot: snap, orbit: .authored))
    }
}
