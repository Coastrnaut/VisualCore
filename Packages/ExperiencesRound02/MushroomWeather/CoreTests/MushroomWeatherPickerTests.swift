// MushroomWeatherPickerTests — feature 494 (R02-G20-04) T-R02G2004-002 (FR-R02G2004-001 … 005, 007; SC-R02G2004-001,
// 004; clarifications Q1, Q3, Q4). The analytic picker against an independent rule written here: 500 seeded touches
// (seed 2_494) over certified levels (`MushroomWeatherGenerator.generate` of five manifest entries, the plan's pods
// placed on their sites), three view sizes and three view orbits, each judged by its own pinhole projection of the
// drawn camera (its eye, the view matrix's axes, its lens) — a vent within the larger half-diagonal of its projected frame
// grown by 12 points (higher index first), else a pod within its projected radius grown by 12 points (later slots
// first), else a site within its projected ring radius grown by 12 points (higher index first), else the moon within
// its projected radius grown by 12 points, else the scrubber within 14 points of its projected track, else the floor
// when the finger casts inside the floor rectangle, else empty — with its floor point (the ray cast onto z = 0), drop
// target (the nearest site within 24 points, lower index on ties; nil on a pod's site; removal outside the floor
// rectangle), moon level (clamp(start + round(−dy / 40), 0, 3)) and scrub cycle (round(fraction × cycles run) of the
// cast point along the track); the allowances at their edges (half a point inside and outside); overlapping targets
// (the one drawn last wins); round trips; unusable input (non-finite points, sizes not finite and positive). Explicit
// types, plain loops; each test well under 10 s; no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherPickerTests {
    typealias P = MushroomWeatherPicker
    typealias G = MushroomWeatherSceneGeometry
    typealias Snapshot = MushroomWeatherSceneSnapshot
    typealias Level = MushroomWeatherLevel
    typealias ViewOrbit = MushroomWeatherViewOrbit
    typealias Play = MushroomWeatherPlay
    typealias Cell = MushroomWeatherCell
    typealias Pick = MushroomWeatherPick
    typealias Kind = MushroomWeatherPreviewKind

    /// The feature's test seed.
    static let seed: UInt64 = 2_494

    /// The three view sizes in points: a phone upright, a phone on its side, a tablet.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(844, 390), SIMD2(1024, 768)]

    /// The three view orbits: the authored one and two within bounds.
    static let orbits: [ViewOrbit] = [.authored, ViewOrbit(yaw: 0.7, pitch: 0.4), ViewOrbit(yaw: -0.9, pitch: -0.3)]

    /// The manifest numbers whose certified levels are used.
    static let numbers: [Int] = [1, 21, 41, 61, 81]

    /// The certified levels of ``numbers`` with their plans: `MushroomWeatherGenerator.generate` of each entry.
    static let generated: [MushroomWeatherGenerated] = {
        var result: [MushroomWeatherGenerated] = []
        for number in numbers {
            let entry: MushroomWeatherManifestEntry = MushroomWeatherManifest.entries[number - 1]
            if let level = try? MushroomWeatherGenerator.generate(entry, previous: nil) { result.append(level) }
        }
        return result
    }()

    /// A play of `generated` in stage `playing` with the plan's placements applied (its pods on their sites).
    static func play(_ generated: MushroomWeatherGenerated) throws -> Play {
        var play: Play = Play(level: generated.level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in generated.plan.actions {
            if case .place = action { try play.apply(action, expecting: play.fingerprint) }
        }
        return play
    }

    /// `base` with the given pods, sites and vents (the unchecked initialiser; one field and nothing grown).
    static func variant(_ base: Snapshot, pods: [Cell?], sites: [Cell], vents: [Cell]) -> Snapshot {
        var grown: [Int?] = []
        var open: [Bool] = []
        for _ in pods { grown.append(nil) }
        for _ in vents { open.append(false) }
        return Snapshot(rows: base.rows, columns: base.columns, blocked: base.blocked, fields: [base.fields[0]],
                        cyclesRun: 0, shownCycle: 0, moldBound: base.moldBound, colonies: base.colonies,
                        requiredCycles: base.requiredCycles, pods: pods, grownAt: grown, sites: sites, vents: vents,
                        ventsOpen: open, moonlight: base.moonlight, failure: nil, stage: .playing,
                        actionsLeft: base.actionsLeft, budget: base.budget, levelNumber: base.levelNumber, time: 0)
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

    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// The lens of the camera drawn in a view of `size` from `orbit`: the eye, the axes of its view matrix (rows 0 … 2
    /// are right, up and backward) and its lens.
    static func lens(size: SIMD2<Double>, orbit: ViewOrbit) -> Lens {
        let camera: MushroomWeatherCamera = G.camera(aspect: size.x / size.y, orbit: orbit)
        let v: Mat4 = camera.view
        let r0: Vec4 = v.row(0)
        let r1: Vec4 = v.row(1)
        let r2: Vec4 = v.row(2)
        return Lens(eye: camera.eye, forward: SIMD3(-r2.x, -r2.y, -r2.z), right: SIMD3(r0.x, r0.y, r0.z),
                    up: SIMD3(r1.x, r1.y, r1.z), tanHalf: tan(camera.fovY / 2), aspect: camera.aspect, size: size)
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

    /// The cell scale s = min(1.8 / C, 1.6 / R) of `snapshot`.
    static func scale(_ snapshot: Snapshot) -> Double {
        min(1.8 / Double(snapshot.columns), 1.6 / Double(snapshot.rows))
    }

    /// The world point of `cell`'s centre at `height` (world units).
    static func world(_ cell: Cell, _ snapshot: Snapshot, height: Double) -> SIMD3<Double> {
        let s: Double = scale(snapshot)
        return SIMD3((Double(cell.column) - Double(snapshot.columns - 1) / 2) * s,
                     (Double(snapshot.rows - 1) / 2 - Double(cell.row)) * s, height)
    }

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

    /// Whether `point` casts inside the floor rectangle of `snapshot`.
    static func expectedInside(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> Bool {
        guard let hit = cast(point, lens) else { return false }
        let s: Double = scale(snapshot)
        return abs(hit.x) <= Double(snapshot.columns) * s / 2 && abs(hit.y) <= Double(snapshot.rows) * s / 2
    }

    /// The vent's projected centre and reach (the larger half-diagonal of its projected frame plus 12 points).
    static func ventTarget(_ index: Int, _ snapshot: Snapshot,
                           _ lens: Lens) -> (centre: SIMD2<Double>, reach: Double)? {
        let s: Double = scale(snapshot)
        let c: SIMD3<Double> = world(snapshot.vents[index], snapshot, height: 0.9 * s)
        let h: Double = 0.45 * s
        guard let centre = screen(c, lens), let a = screen(c + SIMD3(-h, -h, 0), lens),
              let b = screen(c + SIMD3(h, -h, 0), lens), let e = screen(c + SIMD3(h, h, 0), lens),
              let f = screen(c + SIMD3(-h, h, 0), lens) else { return nil }
        return (centre: centre, reach: max(distance(a, e), distance(b, f)) / 2 + 12)
    }

    /// The pod's projected centre and reach (its radius, 0.26 s grown by the shown cycle else 0.18 s, plus 12).
    static func podTarget(_ slot: Int, _ snapshot: Snapshot,
                          _ lens: Lens) -> (centre: SIMD2<Double>, reach: Double)? {
        guard let cell = snapshot.pods[slot] else { return nil }
        let s: Double = scale(snapshot)
        let c: SIMD3<Double> = world(cell, snapshot, height: 0.1 * s)
        var grown: Bool = false
        if let cycle = snapshot.grownAt[slot] { grown = snapshot.shownCycle >= cycle }
        guard let centre = screen(c, lens) else { return nil }
        return (centre: centre, reach: extent((grown ? 0.26 : 0.18) * s, at: c, lens) + 12)
    }

    /// The site's projected centre and reach (its ring radius 0.32 s plus 12).
    static func siteTarget(_ index: Int, _ snapshot: Snapshot,
                           _ lens: Lens) -> (centre: SIMD2<Double>, reach: Double)? {
        let c: SIMD3<Double> = world(snapshot.sites[index], snapshot, height: 0.01)
        guard let centre = screen(c, lens) else { return nil }
        return (centre: centre, reach: extent(0.32 * scale(snapshot), at: c, lens) + 12)
    }

    /// The moon's projected centre and reach (radius 0.12 plus 12).
    static func moonTarget(_ lens: Lens) -> (centre: SIMD2<Double>, reach: Double)? {
        let c: SIMD3<Double> = SIMD3(1.15, 1.05, -0.5)
        guard let centre = screen(c, lens) else { return nil }
        return (centre: centre, reach: extent(0.12, at: c, lens) + 12)
    }

    /// The independent pick (see the header).
    static func expectedPick(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> Pick {
        var vent: Int = snapshot.vents.count - 1
        while vent >= 0 {
            if let t = ventTarget(vent, snapshot, lens), distance(point, t.centre) <= t.reach { return .vent(vent) }
            vent -= 1
        }
        var slot: Int = snapshot.pods.count - 1
        while slot >= 0 {
            if let t = podTarget(slot, snapshot, lens), distance(point, t.centre) <= t.reach { return .pod(slot) }
            slot -= 1
        }
        var index: Int = snapshot.sites.count - 1
        while index >= 0 {
            if let t = siteTarget(index, snapshot, lens), distance(point, t.centre) <= t.reach { return .site(index) }
            index -= 1
        }
        if let t = moonTarget(lens), distance(point, t.centre) <= t.reach { return .moon }
        if let a = screen(SIMD3(-0.9, -0.9, 0), lens), let b = screen(SIMD3(0.9, -0.9, 0), lens),
           segment(point, a, b) <= 14 {
            return .scrubber
        }
        if expectedInside(point, snapshot, lens) { return .floor }
        return .empty
    }

    /// The independent drop target of slot `slot`'s pod.
    static func expectedDrop(_ point: SIMD2<Double>, slot: Int, _ snapshot: Snapshot, _ lens: Lens) -> Kind? {
        guard snapshot.pods[slot] != nil else { return nil }
        var best: Int = -1
        var bestDistance: Double = Double.infinity
        for index in snapshot.sites.indices {
            guard let c = screen(world(snapshot.sites[index], snapshot, height: 0.01), lens) else { continue }
            let d: Double = distance(point, c)
            if d <= 24 && d < bestDistance {
                best = index
                bestDistance = d
            }
        }
        if best >= 0 {
            let site: Cell = snapshot.sites[best]
            for pod in snapshot.pods where pod == site { return nil }
            return .pod(slot: slot, target: site)
        }
        return expectedInside(point, snapshot, lens) ? nil : .pod(slot: slot, target: nil)
    }

    /// The independent scrub cycle.
    static func expectedCycle(_ point: SIMD2<Double>, _ snapshot: Snapshot, _ lens: Lens) -> Int {
        guard let hit = cast(point, lens) else { return snapshot.shownCycle }
        let fraction: Double = max(0, min(1, (hit.x + 0.9) / 1.8))
        return Int((fraction * Double(snapshot.cyclesRun)).rounded(.toNearestOrAwayFromZero))
    }

    /// The independent moon level.
    static func expectedMoon(start: Int, travel: Double) -> Int {
        let steps: Double = (-travel / 40).rounded(.toNearestOrAwayFromZero)
        if steps >= 4 { return 3 }
        if steps <= -4 { return 0 }
        return max(0, min(3, start + Int(steps)))
    }

    // MARK: Tests

    @Test func fiveHundredSeededTouchesMatchTheIndependentRule() throws {
        #expect(Self.generated.count == Self.numbers.count)
        var plays: [Play] = []
        for level in Self.generated { plays.append(try Self.play(level)) }
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var counts: [String: Int] = [:]
        var drops: [String: Int] = [:]
        for k in 0..<500 {
            let play: Play = plays[k % plays.count]
            let size: SIMD2<Double> = Self.sizes[(k / plays.count) % Self.sizes.count]
            let orbit: ViewOrbit = Self.orbits[(k / (plays.count * Self.sizes.count)) % Self.orbits.count]
            let probe: Snapshot = Snapshot(play: play, shownCycle: 0, levelNumber: 1, time: 0)
            let snap: Snapshot = Snapshot(play: play, shownCycle: random.int(0...probe.cyclesRun), levelNumber: 1,
                                          time: 0)
            let lens: Lens = Self.lens(size: size, orbit: orbit)
            var point: SIMD2<Double> = SIMD2(random.range(0...size.x), random.range(0...size.y))
            let kind: Int = k % 7
            var target: (centre: SIMD2<Double>, reach: Double)? = nil
            if kind == 0 {
                var slots: [Int] = []
                for slot in snap.pods.indices where snap.pods[slot] != nil { slots.append(slot) }
                if !slots.isEmpty { target = Self.podTarget(slots[random.int(0...(slots.count - 1))], snap, lens) }
            } else if kind == 1 {
                target = Self.siteTarget(random.int(0...(snap.sites.count - 1)), snap, lens)
            } else if kind == 2 && !snap.vents.isEmpty {
                target = Self.ventTarget(random.int(0...(snap.vents.count - 1)), snap, lens)
            } else if kind == 3 {
                target = Self.moonTarget(lens)
            } else if kind == 4 {
                if let a = Self.screen(SIMD3(-0.9, -0.9, 0), lens), let b = Self.screen(SIMD3(0.9, -0.9, 0), lens) {
                    let f: Double = random.double()
                    point = SIMD2(a.x + (b.x - a.x) * f + random.range(-20...20),
                                  a.y + (b.y - a.y) * f + random.range(-20...20))
                }
            } else if kind == 5 {
                let s: Double = Self.scale(snap)
                let x: Double = Double(snap.columns) * s / 2 * random.range(-1.2...1.2)
                let y: Double = Double(snap.rows) * s / 2 * random.range(-1.2...1.2)
                if let c = Self.screen(SIMD3(x, y, 0), lens) { point = c }
            }
            if let t = target {
                let angle: Double = random.range(0...(2 * Double.pi))
                let r: Double = random.range(0...(t.reach * 1.5))
                point = SIMD2(t.centre.x + r * cos(angle), t.centre.y + r * sin(angle))
            }
            let picked: Pick = P.pick(point, size: size, snapshot: snap, orbit: orbit)
            let expected: Pick = Self.expectedPick(point, snap, lens)
            #expect(picked == expected, "touch \(k) \(size) \(orbit): \(picked) vs \(expected)")
            switch picked {
            case .pod: counts["pod", default: 0] += 1
            case .site: counts["site", default: 0] += 1
            case .vent: counts["vent", default: 0] += 1
            default: counts["\(picked)", default: 0] += 1
            }
            let slot: Int = k % snap.pods.count
            let drop: Kind? = P.dropTarget(point, slot: slot, size: size, snapshot: snap, orbit: orbit)
            #expect(drop == Self.expectedDrop(point, slot: slot, snap, lens), "touch \(k)")
            switch drop {
            case .pod(_, let cell?): drops["site", default: 0] += 1
                #expect(snap.sites.contains(cell))
            case .pod(_, nil): drops["removal", default: 0] += 1
            case .moonlight: Issue.record("a drop is never a moonlight change")
            case nil: drops["none", default: 0] += 1
            }
            let read: Int = P.scrubCycle(point, size: size, snapshot: snap, orbit: orbit)
            #expect(read == Self.expectedCycle(point, snap, lens), "touch \(k)")
            #expect(read >= 0 && read <= snap.cyclesRun)
            let floor: SIMD2<Double>? = P.floorPoint(point, size: size, snapshot: snap, orbit: orbit)
            let cast: SIMD3<Double>? = Self.cast(point, lens)
            #expect((floor == nil) == (cast == nil), "touch \(k)")
            if let f = floor, let c = cast { #expect(Self.distance(f, SIMD2(c.x, c.y)) <= 1e-9, "touch \(k)") }
            let start: Int = random.int(0...3)
            let travel: Double = random.range(-170...170)
            #expect(P.moonLevel(start: start, travel: travel) == Self.expectedMoon(start: start, travel: travel))
        }
        // Every kind of pick and of drop occurs.
        for name in ["vent", "pod", "site", "moon", "scrubber", "floor", "empty"] {
            #expect((counts[name] ?? 0) > 0, "\(name): \(counts)")
        }
        for name in ["site", "removal", "none"] {
            #expect((drops[name] ?? 0) > 0, "\(name): \(drops)")
        }
    }

    @Test func moonLevelsAndConstants() {
        #expect(P.markerAllowance == 12 && P.scrubberBand == 14 && P.siteReach == 24 && P.moonStep == 40)
        let travels: [Double] = [0, -19.9, -20, -20.1, 19.9, 20, 20.1, -59.9, -60, -60.1, -400, 400, 1e300, -1e300]
        for start in -1...4 {
            for travel in travels {
                let clampedStart: Int = max(0, min(3, start))
                #expect(P.moonLevel(start: start, travel: travel) == Self.expectedMoon(start: clampedStart,
                                                                                      travel: travel),
                        "\(start) \(travel)")
            }
            #expect(P.moonLevel(start: start, travel: .nan) == max(0, min(3, start)))
        }
        #expect(P.moonLevel(start: 1, travel: -40) == 2)
        #expect(P.moonLevel(start: 1, travel: 40) == 0)
        #expect(P.moonLevel(start: 2, travel: -19) == 2)
        #expect(P.moonLevel(start: 0, travel: -1000) == 3)
    }

    @Test func allowancesAtTheirEdges() throws {
        let play: Play = try Self.play(Self.generated[2])
        let base: Snapshot = Snapshot(play: play, shownCycle: 0, levelNumber: 1, time: 0)
        let sites: [Cell] = base.sites
        try #require(sites.count >= 3)
        // No vents: slot 0 holds a pod on site 0, slot 1 is empty; `lone` lists site 2 alone (so no neighbour
        // interferes with its edges), `snap` lists every site.
        var pods: [Cell?] = []
        var none: [Cell?] = []
        for slot in base.pods.indices {
            pods.append(slot == 0 ? sites[0] : nil)
            none.append(nil)
        }
        let snap: Snapshot = Self.variant(base, pods: pods, sites: sites, vents: [])
        let lone: Snapshot = Self.variant(base, pods: none, sites: [sites[2]], vents: [])
        let loneDrop: Snapshot = Self.variant(base, pods: pods, sites: [sites[2]], vents: [])
        let ventOnly: Snapshot = Self.variant(base, pods: [nil], sites: [], vents: [sites[2]])
        let bare: Snapshot = Self.variant(base, pods: [nil], sites: [], vents: [])
        for size in Self.sizes {
            for orbit in Self.orbits {
                let lens: Lens = Self.lens(size: size, orbit: orbit)
                let pod: (centre: SIMD2<Double>, reach: Double) = try #require(Self.podTarget(0, snap, lens))
                #expect(P.pick(pod.centre + SIMD2(pod.reach - 0.5, 0), size: size, snapshot: snap, orbit: orbit)
                        == .pod(0))
                #expect(P.pick(pod.centre + SIMD2(pod.reach + 0.5, 0), size: size, snapshot: snap, orbit: orbit)
                        != .pod(0))
                let site: (centre: SIMD2<Double>, reach: Double) = try #require(Self.siteTarget(0, lone, lens))
                #expect(P.pick(site.centre + SIMD2(0, site.reach - 0.5), size: size, snapshot: lone, orbit: orbit)
                        == .site(0))
                #expect(P.pick(site.centre + SIMD2(0, site.reach + 0.5), size: size, snapshot: lone, orbit: orbit)
                        != .site(0))
                let vent: (centre: SIMD2<Double>, reach: Double) = try #require(Self.ventTarget(0, ventOnly, lens))
                #expect(P.pick(vent.centre + SIMD2(-(vent.reach - 0.5), 0), size: size, snapshot: ventOnly,
                               orbit: orbit) == .vent(0))
                #expect(P.pick(vent.centre + SIMD2(-(vent.reach + 0.5), 0), size: size, snapshot: ventOnly,
                               orbit: orbit) != .vent(0))
                let moon: (centre: SIMD2<Double>, reach: Double) = try #require(Self.moonTarget(lens))
                #expect(P.pick(moon.centre + SIMD2(0, -(moon.reach - 0.5)), size: size, snapshot: bare, orbit: orbit)
                        == .moon)
                #expect(P.pick(moon.centre + SIMD2(0, -(moon.reach + 0.5)), size: size, snapshot: bare, orbit: orbit)
                        != .moon)
                // A dragged pod snaps to the free site within 24 points.
                let near: Kind? = P.dropTarget(site.centre + SIMD2(23.5, 0), slot: 0, size: size,
                                               snapshot: loneDrop, orbit: orbit)
                #expect(near == .pod(slot: 0, target: sites[2]), "\(size) \(orbit)")
                let far: Kind? = P.dropTarget(site.centre + SIMD2(24.5, 0), slot: 0, size: size, snapshot: loneDrop,
                                              orbit: orbit)
                #expect(far != .pod(slot: 0, target: sites[2]), "\(size) \(orbit)")
                // On its own site: no change; an empty slot never drops.
                #expect(P.dropTarget(pod.centre, slot: 0, size: size, snapshot: snap, orbit: orbit) == nil)
                #expect(P.dropTarget(site.centre, slot: 1, size: size, snapshot: loneDrop, orbit: orbit) == nil)
                // The scrubber band at the track's middle, perpendicular to the projected track.
                let a: SIMD2<Double> = try #require(Self.screen(SIMD3(-0.9, -0.9, 0), lens))
                let b: SIMD2<Double> = try #require(Self.screen(SIMD3(0.9, -0.9, 0), lens))
                let mid: SIMD2<Double> = (a + b) / 2
                let along: SIMD2<Double> = (b - a) / Self.distance(a, b)
                let normal: SIMD2<Double> = SIMD2(-along.y, along.x)
                #expect(P.pick(mid + normal * 13.5, size: size, snapshot: bare, orbit: orbit) == .scrubber)
                #expect(P.pick(mid - normal * 13.5, size: size, snapshot: bare, orbit: orbit) == .scrubber)
                #expect(P.pick(mid + normal * 14.5, size: size, snapshot: bare, orbit: orbit) != .scrubber)
                #expect(P.pick(mid - normal * 14.5, size: size, snapshot: bare, orbit: orbit) != .scrubber)
                // Off the floor in a view corner: removal; at the floor centre (no site near): floor, no change.
                #expect(P.dropTarget(SIMD2(1, size.y - 1), slot: 0, size: size, snapshot: snap, orbit: orbit)
                        == .pod(slot: 0, target: nil))
                let centre: SIMD2<Double> = try #require(Self.screen(SIMD3(0, 0, 0), lens))
                if P.pick(centre, size: size, snapshot: bare, orbit: orbit) == .floor {
                    let bareDrop: Snapshot = Self.variant(base, pods: [sites[0]], sites: [], vents: [])
                    #expect(P.dropTarget(centre, slot: 0, size: size, snapshot: bareDrop, orbit: orbit) == nil)
                }
            }
        }
    }

    @Test func overlappingTargetsPickTheOneDrawnLast() throws {
        let play: Play = try Self.play(Self.generated[0])
        let base: Snapshot = Snapshot(play: play, shownCycle: 0, levelNumber: 1, time: 0)
        let a: Cell = Cell(row: 2, column: 2)
        let b: Cell = Cell(row: 2, column: 3)
        let size: SIMD2<Double> = SIMD2(200, 200)
        let lens: Lens = Self.lens(size: size, orbit: .authored)
        // Two pods on neighbouring sites (slots 0 and 1): between them the later slot wins, and a pod wins over its
        // site.
        let pods: Snapshot = Self.variant(base, pods: [a, b], sites: [a, b], vents: [])
        let ca: SIMD2<Double> = try #require(Self.screen(Self.world(a, pods, height: 0.01), lens))
        let cb: SIMD2<Double> = try #require(Self.screen(Self.world(b, pods, height: 0.01), lens))
        let between: SIMD2<Double> = (ca + cb) / 2
        #expect(P.pick(between, size: size, snapshot: pods, orbit: .authored) == .pod(1))
        #expect(P.pick(ca, size: size, snapshot: pods, orbit: .authored) == .pod(1))
        // A vent over a pod's cell wins over the pod.
        let vented: Snapshot = Self.variant(base, pods: [a, nil], sites: [a, b], vents: [a])
        let pa: (centre: SIMD2<Double>, reach: Double) = try #require(Self.podTarget(0, vented, lens))
        #expect(P.pick(pa.centre, size: size, snapshot: vented, orbit: .authored) == .vent(0))
        // Without pods, the sites overlap and the higher index wins; the nearer site wins a drop (lower on ties).
        let bare: Snapshot = Self.variant(base, pods: [a, nil], sites: [b, Cell(row: 2, column: 4)], vents: [])
        let c4: SIMD2<Double> = try #require(Self.screen(Self.world(Cell(row: 2, column: 4), bare, height: 0.01),
                                                         lens))
        let gap: SIMD2<Double> = (cb + c4) / 2
        #expect(P.pick(gap, size: size, snapshot: bare, orbit: .authored) == .site(1))
        #expect(P.dropTarget(cb, slot: 0, size: size, snapshot: bare, orbit: .authored) == .pod(slot: 0, target: b))
        #expect(P.dropTarget(c4, slot: 0, size: size, snapshot: bare, orbit: .authored)
                == .pod(slot: 0, target: Cell(row: 2, column: 4)))
        let d1: Double = Self.distance(gap, cb)
        let d2: Double = Self.distance(gap, c4)
        if d1 == d2 && d1 <= 24 {
            #expect(P.dropTarget(gap, slot: 0, size: size, snapshot: bare, orbit: .authored)
                    == .pod(slot: 0, target: b))
        }
        // A drop on another pod's site is no change.
        #expect(P.dropTarget(cb, slot: 1, size: size, snapshot: pods, orbit: .authored) == nil)
        #expect(P.dropTarget(ca, slot: 1, size: size, snapshot: pods, orbit: .authored) == nil)
        // In a large view the targets separate and the gap between the two sites is the floor.
        let large: SIMD2<Double> = SIMD2(4000, 4000)
        let big: Lens = Self.lens(size: large, orbit: .authored)
        let lb: SIMD2<Double> = try #require(Self.screen(Self.world(b, bare, height: 0.01), big))
        let l4: SIMD2<Double> = try #require(Self.screen(Self.world(Cell(row: 2, column: 4), bare, height: 0.01),
                                                         big))
        #expect(P.pick((lb + l4) / 2, size: large, snapshot: bare, orbit: .authored) == .floor)
    }

    @Test func roundTripsAndProjection() throws {
        let play: Play = try Self.play(Self.generated[3])
        let snap: Snapshot = Snapshot(play: play, shownCycle: 0, levelNumber: 1, time: 0)
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: MushroomWeatherCamera = try #require(P.camera(size: size, orbit: orbit))
                #expect(camera == G.camera(aspect: size.x / size.y, orbit: orbit))
                let lens: Lens = Self.lens(size: size, orbit: orbit)
                // A cell's projected centre casts back onto it; the picker's projection is the lens's.
                for site in snap.sites {
                    let w: SIMD3<Double> = G.cellCentre(site, snap, height: 0)
                    let v: SIMD2<Double> = try #require(P.viewPoint(w, size: size, camera: camera))
                    let e: SIMD2<Double> = try #require(Self.screen(w, lens))
                    #expect(Self.distance(v, e) < 1e-6)
                    let f: SIMD2<Double> = try #require(P.floorPoint(v, size: size, snapshot: snap, orbit: orbit))
                    #expect(abs(f.x - w.x) < 1e-6 && abs(f.y - w.y) < 1e-6)
                }
                // The scrubber at every tenth of the run reads its cycle.
                for step in 0...10 {
                    let cycle: Int = snap.cyclesRun * step / 10
                    let fraction: Double = Double(cycle) / Double(max(snap.cyclesRun, 1))
                    let v: SIMD2<Double> = try #require(P.viewPoint(G.scrubberPoint(fraction), size: size,
                                                                    camera: camera))
                    #expect(P.scrubCycle(v, size: size, snapshot: snap, orbit: orbit) == cycle, "\(cycle)")
                }
                // Beyond the ends the cycle clamps.
                let left: SIMD2<Double> = try #require(P.viewPoint(SIMD3(-0.98, -0.9, 0), size: size, camera: camera))
                let right: SIMD2<Double> = try #require(P.viewPoint(SIMD3(0.98, -0.9, 0), size: size, camera: camera))
                #expect(P.scrubCycle(left, size: size, snapshot: snap, orbit: orbit) == 0)
                #expect(P.scrubCycle(right, size: size, snapshot: snap, orbit: orbit) == snap.cyclesRun)
                // Behind the eye nothing projects; the extent of a world unit shrinks with depth.
                #expect(P.viewPoint(camera.eye + (camera.eye - camera.target), size: size, camera: camera) == nil)
                let near: Double = try #require(P.projectedExtent(0.1, at: SIMD3(0, -1.0, 0), size: size,
                                                                  camera: camera))
                let far: Double = try #require(P.projectedExtent(0.1, at: SIMD3(0, 1.0, -0.5), size: size,
                                                                 camera: camera))
                #expect(near > far && far > 0)
            }
        }
    }

    @Test func unusableInputPicksNothing() throws {
        let play: Play = try Self.play(Self.generated[4])
        let snap: Snapshot = Snapshot(play: play, shownCycle: 5, levelNumber: 1, time: 0)
        let good: SIMD2<Double> = SIMD2(390, 844)
        let points: [SIMD2<Double>] = [SIMD2(.nan, 10), SIMD2(10, .infinity), SIMD2(-.infinity, .nan)]
        for point in points {
            #expect(P.pick(point, size: good, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.floorPoint(point, size: good, snapshot: snap, orbit: .authored) == nil)
            #expect(P.dropTarget(point, slot: 0, size: good, snapshot: snap, orbit: .authored) == nil)
            #expect(P.scrubCycle(point, size: good, snapshot: snap, orbit: .authored) == 5)
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 100), SIMD2(100, -1), SIMD2(.nan, 100), SIMD2(100, .infinity)]
        for size in sizes {
            #expect(P.pick(SIMD2(50, 50), size: size, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.camera(size: size, orbit: .authored) == nil)
            #expect(P.floorPoint(SIMD2(50, 50), size: size, snapshot: snap, orbit: .authored) == nil)
            #expect(P.dropTarget(SIMD2(50, 50), slot: 0, size: size, snapshot: snap, orbit: .authored) == nil)
            #expect(P.scrubCycle(SIMD2(50, 50), size: size, snapshot: snap, orbit: .authored) == 5)
            #expect(P.viewPoint(SIMD3(0, 0, 0), size: size, camera: G.camera(aspect: 1)) == nil)
            #expect(P.projectedExtent(0.1, at: SIMD3(0, 0, 0), size: size, camera: G.camera(aspect: 1)) == nil)
        }
        // Slots out of range never drop; a non-finite orbit counts as the authored one.
        #expect(P.dropTarget(SIMD2(1, 1), slot: -1, size: good, snapshot: snap, orbit: .authored) == nil)
        #expect(P.dropTarget(SIMD2(1, 1), slot: 99, size: good, snapshot: snap, orbit: .authored) == nil)
        let wild: ViewOrbit = ViewOrbit(yaw: .nan, pitch: .infinity)
        #expect(wild.clamped() == .authored)
        #expect(G.camera(aspect: 1, orbit: wild) == G.camera(aspect: 1))
        let centre: SIMD2<Double> = SIMD2(195, 422)
        #expect(P.pick(centre, size: good, snapshot: snap, orbit: wild)
                == P.pick(centre, size: good, snapshot: snap, orbit: .authored))
    }
}
