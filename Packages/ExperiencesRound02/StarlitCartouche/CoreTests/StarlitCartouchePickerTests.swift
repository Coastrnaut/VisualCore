// StarlitCartouchePickerTests — feature 454 (R02-G16-04) T-R02G1604-002 (FR-R02G1604-002, 005; SC-R02G1604-001, 004;
// clarifications Q1, Q3). The analytic picker against an independent rule written here: 500 seeded points (a third
// near a star, a third near the wait pips, a third anywhere) over certified levels (manifest numbers through
// `StarlitCartoucheExperienceCore.level(number:)`), 3 view sizes, 3 orbits and waits 0, 4 and 8; the independent rule
// projects each star's launch centre and the point 0.098 above it along the view's up axis (same depth) to get the
// ring radius in view points, takes the hit nearest the eye (the higher index on equal distance), names the ship's
// star the ship, and builds the slider box from the pips' projected corners; the slider's wait is checked the same
// way. The 8-point allowance at 7 and 9 points; the front-most of two overlapping stars; the ship; unusable input.
// Explicit types, plain loops; each test well under 10 s; no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import StarlitCartoucheCore

struct StarlitCartouchePickerTests {
    typealias G = StarlitCartoucheSceneGeometry
    typealias P = StarlitCartouchePicker
    typealias Snapshot = StarlitCartoucheSceneSnapshot

    /// The view sizes checked (phone portrait, tablet landscape, phone landscape), in points.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1024, 768), SIMD2(844, 390)]
    /// The orbits checked: authored and two opposite corners.
    static let orbits: [StarlitCartoucheOrbit] = [
        .authored,
        StarlitCartoucheOrbit(yaw: StarlitCartoucheOrbit.yawLimit, pitch: StarlitCartoucheOrbit.pitchRange.upperBound),
        StarlitCartoucheOrbit(yaw: -StarlitCartoucheOrbit.yawLimit, pitch: StarlitCartoucheOrbit.pitchRange.lowerBound),
    ]
    /// The waits checked.
    static let waits: [Int] = [0, 4, 8]
    /// The certified manifest numbers sampled.
    static let numbers: [Int] = [1, 17, 34, 51, 68, 85, 100]

    /// A deterministic generator (SplitMix64).
    struct Mix {
        var state: UInt64

        mutating func next() -> UInt64 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z: UInt64 = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        /// A double in 0 ..< 1.
        mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }

        /// An integer in 0 ..< n.
        mutating func below(_ n: Int) -> Int { Int(next() % UInt64(max(n, 1))) }
    }

    /// A playing snapshot of certified level `number` with wait `wait` (default destination).
    static func snapshot(_ number: Int, wait: Int) throws -> Snapshot {
        let level: StarlitCartoucheLevel = try StarlitCartoucheExperienceCore.level(number: number)
        var play: StarlitCartouchePlay = StarlitCartouchePlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return Snapshot(play: play, chosenStar: -1, chosenWait: wait, levelNumber: number, time: 0)
    }

    /// The independent view point: the projection to 0 … 1 scaled by the size.
    static func view(_ p: SIMD3<Double>, _ size: SIMD2<Double>, _ camera: StarlitCartoucheCamera) -> SIMD2<Double>? {
        guard let q = G.project(p, camera: camera) else { return nil }
        return SIMD2(q.x * size.x, q.y * size.y)
    }

    /// The distance between view points.
    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// One star target of the independent rule: index, view centre, reach (ring radius + 8) and eye distance.
    struct Target {
        let index: Int
        let centre: SIMD2<Double>
        let reach: Double
        let depth: Double
    }

    /// The independent star targets: launch centre w(position(at: beat + wait)), radius from the point 0.098 above it.
    static func targets(_ snap: Snapshot, _ size: SIMD2<Double>, _ camera: StarlitCartoucheCamera) -> [Target] {
        let forward: SIMD3<Double> = G.unit(camera.target - camera.eye)
        let right: SIMD3<Double> = G.unit(G.cross(forward, SIMD3(0, 1, 0)))
        let up: SIMD3<Double> = G.cross(right, forward)
        var list: [Target] = []
        for index in snap.stars.indices {
            let world: SIMD3<Double> = G.world(snap.stars[index].position(at: snap.beat + snap.chosenWait), snap)
            guard let c = view(world, size, camera), let top = view(world + up * 0.098, size, camera) else { continue }
            let d: SIMD3<Double> = world - camera.eye
            list.append(Target(index: index, centre: c, reach: distance(c, top) + 8,
                               depth: (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()))
        }
        return list
    }

    /// The independent slider box: the projected corners of the nine pips (side 0.04 on the view's right and up).
    static func box(_ size: SIMD2<Double>, _ camera: StarlitCartoucheCamera) -> (SIMD2<Double>, SIMD2<Double>) {
        let forward: SIMD3<Double> = G.unit(camera.target - camera.eye)
        let right: SIMD3<Double> = G.unit(G.cross(forward, SIMD3(0, 1, 0)))
        let up: SIMD3<Double> = G.cross(right, forward)
        var low: SIMD2<Double> = SIMD2(1e30, 1e30)
        var high: SIMD2<Double> = SIMD2(-1e30, -1e30)
        for j in 0..<9 {
            let c: SIMD3<Double> = SIMD3(0.05 + 0.1 * Double(j), -1.35, 0)
            for corner in [right + up, right - up, up - right, right * -1 - up] {
                if let p = view(c + corner * 0.02, size, camera) {
                    low = SIMD2(min(low.x, p.x), min(low.y, p.y))
                    high = SIMD2(max(high.x, p.x), max(high.y, p.y))
                }
            }
        }
        return (low, high)
    }

    /// The independent pick and how close the point is to any boundary of the rule (to skip ambiguous points).
    static func expected(_ point: SIMD2<Double>, _ snap: Snapshot, _ size: SIMD2<Double>,
                         _ camera: StarlitCartoucheCamera) -> (pick: StarlitCartouchePick, margin: Double) {
        var margin: Double = Double.infinity
        var best: Target? = nil
        for target in targets(snap, size, camera) {
            let gap: Double = distance(point, target.centre) - target.reach
            margin = min(margin, abs(gap))
            guard gap <= 0 else { continue }
            if let b = best {
                if target.depth < b.depth || (target.depth == b.depth && target.index > b.index) { best = target }
            } else {
                best = target
            }
        }
        if let b = best {
            return (b.index == snap.star ? .ship : .star(b.index), margin)
        }
        let (low, high): (SIMD2<Double>, SIMD2<Double>) = box(size, camera)
        let edges: [Double] = [point.x - (low.x - 8), (high.x + 8) - point.x, point.y - (low.y - 8),
                               (high.y + 8) - point.y]
        var inside: Bool = true
        for e in edges {
            if e < 0 { inside = false }
        }
        for e in edges { margin = min(margin, abs(e)) }
        return (inside ? .slider : .empty, margin)
    }

    /// The independent slider wait: the pip nearest to the point's foot on the line through pips 0 and 8.
    static func expectedWait(_ point: SIMD2<Double>, _ size: SIMD2<Double>,
                             _ camera: StarlitCartoucheCamera) -> (wait: Int, margin: Double) {
        var centres: [SIMD2<Double>] = []
        for j in 0..<9 {
            if let p = view(SIMD3(0.05 + 0.1 * Double(j), -1.35, 0), size, camera) { centres.append(p) }
        }
        guard centres.count == 9 else { return (-1, 0) }
        let a: SIMD2<Double> = centres[0]
        let d: SIMD2<Double> = centres[8] - a
        let t: Double = ((point.x - a.x) * d.x + (point.y - a.y) * d.y) / (d.x * d.x + d.y * d.y)
        let foot: SIMD2<Double> = a + d * t
        var distances: [Double] = []
        for c in centres { distances.append(distance(foot, c)) }
        var best: Int = 0
        for j in 1..<9 where distances[j] < distances[best] { best = j }
        var second: Double = Double.infinity
        for j in 0..<9 where j != best { second = min(second, distances[j]) }
        return (best, second - distances[best])
    }

    // MARK: Tests

    @Test func pickAgreesWithTheIndependentRuleOn500SeededPoints() throws {
        var snaps: [Snapshot] = []
        for number in Self.numbers {
            for wait in Self.waits { snaps.append(try Self.snapshot(number, wait: wait)) }
        }
        var random: Mix = Mix(state: 2_454)
        var counts: [String: Int] = [:]
        var checked: Int = 0
        var waitsChecked: Int = 0
        for k in 0..<500 {
            let snap: Snapshot = snaps[random.below(snaps.count)]
            let size: SIMD2<Double> = Self.sizes[k % 3]
            let orbit: StarlitCartoucheOrbit = Self.orbits[(k / 3) % 3]
            let camera: StarlitCartoucheCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
            var point: SIMD2<Double> = SIMD2(random.unit() * size.x, random.unit() * size.y)
            if k % 3 == 0 {
                let targets: [Target] = Self.targets(snap, size, camera)
                let target: Target = targets[random.below(targets.count)]
                let angle: Double = random.unit() * 2 * Double.pi
                let r: Double = random.unit() * (target.reach + 12)
                point = target.centre + SIMD2(cos(angle), sin(angle)) * r
            } else if k % 3 == 1 {
                let (low, high): (SIMD2<Double>, SIMD2<Double>) = Self.box(size, camera)
                point = SIMD2(low.x - 12 + random.unit() * (high.x - low.x + 24),
                              low.y - 12 + random.unit() * (high.y - low.y + 24))
            }
            let rule: (pick: StarlitCartouchePick, margin: Double) = Self.expected(point, snap, size, camera)
            guard rule.margin > 1e-6 else { continue }
            let picked: StarlitCartouchePick = P.pick(point, size: size, snapshot: snap, orbit: orbit)
            #expect(picked == rule.pick, "point \(point) size \(size) orbit \(orbit) wait \(snap.chosenWait)")
            checked += 1
            counts[String(describing: rule.pick).prefix(4).description, default: 0] += 1
            if rule.pick == .slider {
                let w: (wait: Int, margin: Double) = Self.expectedWait(point, size, camera)
                if w.margin > 1e-6 {
                    #expect(P.sliderWait(point, size: size, snapshot: snap, orbit: orbit) == w.wait)
                    waitsChecked += 1
                }
            }
        }
        #expect(checked >= 495)
        #expect((counts["star"] ?? 0) > 20 && (counts["ship"] ?? 0) > 3 && (counts["slid"] ?? 0) > 50)
        #expect((counts["empt"] ?? 0) > 50)
        #expect(waitsChecked > 50)
    }

    @Test func sliderWaitAtEveryPipAndBeyondTheEnds() throws {
        let snap: Snapshot = try Self.snapshot(1, wait: 3)
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: StarlitCartoucheCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                var centres: [SIMD2<Double>] = []
                for j in 0..<9 {
                    let c: SIMD2<Double> = try #require(P.viewPoint(G.waitPip(j), size: size, camera: camera))
                    centres.append(c)
                    #expect(P.sliderWait(c, size: size, snapshot: snap, orbit: orbit) == j)
                    // A pip's centre is the slider unless a star in front reaches it.
                    let rule: StarlitCartouchePick = Self.expected(c, snap, size, camera).pick
                    #expect(rule != .empty)
                    #expect(P.pick(c, size: size, snapshot: snap, orbit: orbit) == rule)
                }
                let d: SIMD2<Double> = centres[8] - centres[0]
                #expect(P.sliderWait(centres[0] - d, size: size, snapshot: snap, orbit: orbit) == 0)
                #expect(P.sliderWait(centres[8] + d, size: size, snapshot: snap, orbit: orbit) == 8)
                // Off the line (across it) the foot decides.
                let across: SIMD2<Double> = SIMD2(-d.y, d.x) / (d.x * d.x + d.y * d.y).squareRoot() * 30
                #expect(P.sliderWait(centres[5] + across, size: size, snapshot: snap, orbit: orbit) == 5)
            }
        }
    }

    @Test func allowanceIsEightPoints() throws {
        var verified: Int = 0
        for number in Self.numbers {
            let snap: Snapshot = try Self.snapshot(number, wait: 0)
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: StarlitCartoucheCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                    let targets: [Target] = Self.targets(snap, size, camera)
                    for target in targets {
                        for step in 0..<8 {
                            let angle: Double = Double(step) * Double.pi / 4
                            let u: SIMD2<Double> = SIMD2(cos(angle), sin(angle))
                            let ring: Double = target.reach - 8
                            let near: SIMD2<Double> = target.centre + u * (ring + 7)
                            let far: SIMD2<Double> = target.centre + u * (ring + 9)
                            // Only where no other star and not the slider reach the far point.
                            let rule: (pick: StarlitCartouchePick, margin: Double) =
                                Self.expected(far, snap, size, camera)
                            guard rule.pick == .empty, rule.margin > 0.5 else { continue }
                            let nearRule: (pick: StarlitCartouchePick, margin: Double) =
                                Self.expected(near, snap, size, camera)
                            let own: StarlitCartouchePick = target.index == snap.star ? .ship : .star(target.index)
                            guard nearRule.pick == own else { continue }
                            #expect(P.pick(near, size: size, snapshot: snap, orbit: orbit) == own)
                            #expect(P.pick(far, size: size, snapshot: snap, orbit: orbit) == .empty)
                            verified += 1
                            break
                        }
                    }
                }
            }
        }
        #expect(verified > 100)
        #expect(P.starAllowance == 8)
    }

    @Test func frontMostStarWinsWhereStarsOverlap() throws {
        var overlaps: Int = 0
        for number in Self.numbers {
            for wait in Self.waits {
                let snap: Snapshot = try Self.snapshot(number, wait: wait)
                for size in Self.sizes {
                    for orbit in Self.orbits {
                        let camera: StarlitCartoucheCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                        let targets: [Target] = Self.targets(snap, size, camera)
                        for a in targets {
                            for b in targets where b.index > a.index {
                                let gap: Double = Self.distance(a.centre, b.centre)
                                guard gap > 1e-6, gap < min(a.reach, b.reach) else { continue }
                                // The midpoint is within reach of both.
                                let mid: SIMD2<Double> = (a.centre + b.centre) / 2
                                let front: Target = a.depth < b.depth || (a.depth == b.depth && a.index > b.index)
                                    ? a : b
                                let own: StarlitCartouchePick = front.index == snap.star ? .ship : .star(front.index)
                                let rule: (pick: StarlitCartouchePick, margin: Double) =
                                    Self.expected(mid, snap, size, camera)
                                guard rule.pick == own else { continue }
                                #expect(P.pick(mid, size: size, snapshot: snap, orbit: orbit) == own)
                                overlaps += 1
                            }
                        }
                    }
                }
            }
        }
        // A constructed overlap: two stars on the line of sight, the nearer one in front.
        let level: StarlitCartoucheLevel = try Self.lineOfSightLevel()
        var play: StarlitCartouchePlay = StarlitCartouchePlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        let snap: Snapshot = Snapshot(play: play, chosenStar: -1, chosenWait: 0, levelNumber: 1, time: 0)
        let size: SIMD2<Double> = SIMD2(800, 800)
        let camera: StarlitCartoucheCamera = G.camera(snap, aspect: 1)
        let c1: SIMD2<Double> = try #require(P.viewPoint(G.launchCentre(1, snap), size: size, camera: camera))
        let c2: SIMD2<Double> = try #require(P.viewPoint(G.launchCentre(2, snap), size: size, camera: camera))
        #expect(Self.distance(c1, c2) < 10)
        let near1: Double = Self.length(G.launchCentre(1, snap) - camera.eye)
        let near2: Double = Self.length(G.launchCentre(2, snap) - camera.eye)
        let front: Int = near1 < near2 ? 1 : 2
        #expect(P.pick((c1 + c2) / 2, size: size, snapshot: snap, orbit: .authored) == .star(front))
        overlaps += 1
        #expect(overlaps > 1)
    }

    /// The length of `v`.
    static func length(_ v: SIMD3<Double>) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }

    /// A level whose stars 1 and 2 lie almost on one line of sight of the authored eye (the box −8 … 8 puts star 2
    /// at w ≈ (0, −0.18, 0), next to the look-at point, and star 1 one step (3, 3, 7) ∝ (1.2, 1.2, 2.8) towards the
    /// eye); stars 0 and 3 at opposite corners, star 0 the start.
    static func lineOfSightLevel() throws -> StarlitCartoucheLevel {
        typealias V = StarlitCartoucheVector
        let orbits: [[V]] = [[V(-8, -8, -8)], [V(3, 1, 7)], [V(0, -2, 0)], [V(8, 8, 8)]]
        var stars: [StarlitCartoucheStar] = []
        for i in orbits.indices {
            stars.append(StarlitCartoucheStar(orbit: orbits[i], glyph: StarlitCartoucheGlyphPoint(i, 0), open: 0,
                                              close: 64))
        }
        let corridors: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(0, 1, travel: 1),
                                                     StarlitCartoucheCorridor(1, 2, travel: 1),
                                                     StarlitCartoucheCorridor(0, 3, travel: 1)]
        return try StarlitCartoucheLevel(id: "line-of-sight", seed: 3, difficulty: 1, stars: stars, range: 12,
                                         corridors: corridors, hazards: [], start: 0, beacon: 2, deadline: 20,
                                         symbol: [0, 1], budget: 4)
    }

    @Test func theShipsStarIsTheShip() throws {
        var ships: Int = 0
        for number in Self.numbers {
            for wait in Self.waits {
                let snap: Snapshot = try Self.snapshot(number, wait: wait)
                for size in Self.sizes {
                    for orbit in Self.orbits {
                        let camera: StarlitCartoucheCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                        let centre: SIMD2<Double> =
                            try #require(P.viewPoint(G.launchCentre(snap.star, snap), size: size, camera: camera))
                        let rule: (pick: StarlitCartouchePick, margin: Double) =
                            Self.expected(centre, snap, size, camera)
                        #expect(P.pick(centre, size: size, snapshot: snap, orbit: orbit) == rule.pick)
                        if rule.pick == .ship {
                            ships += 1
                            continue
                        }
                        // Another star in front covers the ship's star: never the ship's own index as a star.
                        #expect(rule.pick != .star(snap.star))
                    }
                }
            }
        }
        // The ship's own centre picks the ship in most views (189 checked).
        #expect(ships > 150, "\(ships)")
        // Every other star's centre is never the ship.
        let snap: Snapshot = try Self.snapshot(1, wait: 0)
        let size: SIMD2<Double> = SIMD2(600, 600)
        let camera: StarlitCartoucheCamera = G.camera(snap, aspect: 1)
        for index in snap.stars.indices where index != snap.star {
            let c: SIMD2<Double> = try #require(P.viewPoint(G.launchCentre(index, snap), size: size, camera: camera))
            let picked: StarlitCartouchePick = P.pick(c, size: size, snapshot: snap, orbit: .authored)
            #expect(picked == Self.expected(c, snap, size, camera).pick)
            #expect(picked != .star(snap.star))
        }
    }

    @Test func unusableInputPicksNothing() throws {
        let snap: Snapshot = try Self.snapshot(1, wait: 4)
        let good: SIMD2<Double> = SIMD2(100, 100)
        let size: SIMD2<Double> = SIMD2(390, 844)
        let points: [SIMD2<Double>] = [SIMD2(.nan, 1), SIMD2(1, .nan), SIMD2(.infinity, 1), SIMD2(1, -.infinity)]
        for point in points {
            #expect(P.pick(point, size: size, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.sliderWait(point, size: size, snapshot: snap, orbit: .authored) == 4)
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 100), SIMD2(100, 0), SIMD2(-10, 100), SIMD2(.nan, 100),
                                      SIMD2(100, .infinity)]
        for bad in sizes {
            #expect(P.pick(good, size: bad, snapshot: snap, orbit: .authored) == .empty)
            #expect(P.sliderWait(good, size: bad, snapshot: snap, orbit: .authored) == 4)
            #expect(P.viewPoint(SIMD3(0, 0, 0), size: bad, camera: G.camera(snap, aspect: 1)) == nil)
            #expect(P.sliderBox(size: bad, camera: G.camera(snap, aspect: 1)) == nil)
        }
        // Behind the eye and non-finite world points have no view point.
        let camera: StarlitCartoucheCamera = G.camera(snap, aspect: size.x / size.y)
        #expect(P.viewPoint(camera.eye + (camera.eye - camera.target), size: size, camera: camera) == nil)
        #expect(P.viewPoint(SIMD3(.nan, 0, 0), size: size, camera: camera) == nil)
        // The view point is the projection scaled by the size, origin top left.
        let target: SIMD2<Double> = try #require(P.viewPoint(camera.target, size: size, camera: camera))
        #expect(abs(target.x - size.x / 2) < 1e-9 && abs(target.y - size.y / 2) < 1e-9)
        // A non-finite orbit is the authored one.
        let nanOrbit: StarlitCartoucheOrbit = StarlitCartoucheOrbit(yaw: .nan, pitch: .infinity)
        let corner: SIMD2<Double> = SIMD2(2, 2)
        #expect(P.pick(corner, size: size, snapshot: snap, orbit: nanOrbit)
                == P.pick(corner, size: size, snapshot: snap, orbit: .authored))
        // Far outside the view: empty.
        #expect(P.pick(SIMD2(-5000, -5000), size: size, snapshot: snap, orbit: .authored) == .empty)
    }
}
