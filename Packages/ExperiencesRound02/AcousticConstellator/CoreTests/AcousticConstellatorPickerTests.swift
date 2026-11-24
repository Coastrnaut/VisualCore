// AcousticConstellatorPickerTests — feature 424 (R02-G13-04) T-R02G1304-002 (FR-R02G1304-004, 005; SC-R02G1304-001,
// 004; clarifications Q1, Q4). The analytic picker of Acoustic Constellator against an independent pick written here
// (its own camera basis and projection from the camera's eye, target, field of view and aspect; its own star centres,
// coherence bars, hold pips, link splines and segment distance from the grid formulas): 500 seeded points (LCG seed
// 2_424) per view size and orbit over certified levels 1, 50 and 100 (each with its witness's links made), at 3 view
// sizes and 3 orbits; the 22-point target of a coherence bar, a hold pip, a star and a link at 21 and 23 points; gauges
// beat stars and stars beat links; ties go to the lower star index; the drag target and the finger's world point;
// unusable input picks nothing. Explicit types, plain loops; well under 10 s each.
import Foundation
import Testing
import VisualCoreMath
@testable import AcousticConstellatorCore

@Suite struct AcousticConstellatorPickerTests {
    typealias Geometry = AcousticConstellatorSceneGeometry
    typealias Snapshot = AcousticConstellatorSceneSnapshot
    typealias Picker = AcousticConstellatorPicker
    typealias Orbit = AcousticConstellatorOrbit
    typealias Link = AcousticConstellatorLink

    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1024, 768), SIMD2(2000, 800)]

    static let orbits: [Orbit] = [Orbit.authored, Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound),
                                  Orbit(yaw: -0.3, pitch: Orbit.pitchRange.lowerBound)]

    /// A 64-bit linear congruential generator (Knuth's MMIX constants).
    struct LCG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / 9_007_199_254_740_992
        }
        mutating func int(_ upper: Int) -> Int { min(Int(next() * Double(upper)), upper - 1) }
    }

    /// Certified levels 1, 50 and 100, each with its witness's links made (so links can be picked).
    static func certified() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for number in [1, 50, 100] {
            let generated: AcousticConstellatorGenerated = try AcousticConstellatorExperienceCore.generated(number: number)
            var play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: generated.level)
            for action in generated.actions {
                guard case .link = action, play.stage == .playing else { continue }
                try play.apply(action, expecting: play.fingerprint)
            }
            result.append(Snapshot(play: play, levelNumber: number, time: 0))
        }
        return result
    }

    /// A begun play (tutorial dismissed) of a hand-made level of three stars at grid points `stars`, symbol 0–1 and
    /// 0–2, hold 2, with `links` made.
    static func handMade(_ stars: [(Int, Int, Int)], links: [Link]) throws -> Snapshot {
        var list: [AcousticConstellatorStar] = []
        for s in stars { list.append(AcousticConstellatorStar(x: s.0, y: s.1, z: s.2, rate: 1, phase: 0)) }
        let level = try AcousticConstellatorLevel(id: "picker-hand-made", seed: 5, difficulty: 1, stars: list,
                                                  fixedLinks: [], symbol: [Link(a: 0, b: 1), Link(a: 0, b: 2)],
                                                  coupling: 2, degreeLimit: 2, linkLimit: 3, snapLimit: 2,
                                                  threshold: 9, hold: 2, window: 4, budget: 10)
        var play = AcousticConstellatorPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for link in links { try play.apply(.link(link.a, link.b), expecting: play.fingerprint) }
        return Snapshot(play: play, levelNumber: 1, time: 0)
    }

    /// Stars 0 and 1 at the far row's ends, star 2 at the left middle, link 0–1 along the far row: every target alone.
    static func farRow() throws -> Snapshot {
        try handMade([(0, 0, 5), (11, 0, 5), (0, 5, 5)], links: [Link(a: 0, b: 1)])
    }

    // MARK: The independent pick

    /// The camera basis (right, up, forward) from the eye towards the target with +y up.
    static func basis(_ camera: AcousticConstellatorCamera) -> (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) {
        let f0: SIMD3<Double> = camera.target - camera.eye
        let f: SIMD3<Double> = f0 / (f0 * f0).sum().squareRoot()
        let r0: SIMD3<Double> = SIMD3(-f.z, 0, f.x)
        let r: SIMD3<Double> = r0 / (r0 * r0).sum().squareRoot()
        let u: SIMD3<Double> = SIMD3(r.y * f.z - r.z * f.y, r.z * f.x - r.x * f.z, r.x * f.y - r.y * f.x)
        return (r, u, f)
    }

    /// World `p` in view points of `size`, or nil behind the eye.
    static func project(_ p: SIMD3<Double>, _ camera: AcousticConstellatorCamera,
                        _ size: SIMD2<Double>) -> SIMD2<Double>? {
        let (r, u, f): (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) = basis(camera)
        let d: SIMD3<Double> = p - camera.eye
        let depth: Double = (d * f).sum()
        guard depth > 0 else { return nil }
        let t: Double = tan(camera.fovY / 2)
        let nx: Double = (d * r).sum() / (depth * t * camera.aspect)
        let ny: Double = (d * u).sum() / (depth * t)
        return SIMD2((nx + 1) / 2 * size.x, (1 - ny) / 2 * size.y)
    }

    /// The centre of star `index`: ((gx − 5.5)·0.14, 0.15 + (gz − 5.5)·0.02, (gy − 5.5)·0.11).
    static func star(_ index: Int, _ s: Snapshot) -> SIMD3<Double> {
        let star: AcousticConstellatorStar = s.stars[index]
        return SIMD3((Double(star.x) - 5.5) * 0.14, 0.15 + (Double(star.z) - 5.5) * 0.02, (Double(star.y) - 5.5) * 0.11)
    }

    /// The centre of coherence bar `index`: (−0.6 + (index + 0.5)·0.1, 0, 0.85).
    static func bar(_ index: Int) -> SIMD3<Double> { SIMD3(-0.6 + (Double(index) + 0.5) * 0.1, 0, 0.85) }

    /// The centre of hold pip `index`: (−0.4 + (index + 0.5)·0.8 / hold, 0, 1.0).
    static func pip(_ index: Int, _ s: Snapshot) -> SIMD3<Double> {
        SIMD3(-0.4 + (Double(index) + 0.5) * 0.8 / Double(s.hold), 0, 1.0)
    }

    /// The point at `u` on link `index`'s spline: the chord point lifted 0.12 · u · (1 − u).
    static func spline(_ index: Int, _ u: Double, _ s: Snapshot) -> SIMD3<Double> {
        let a: SIMD3<Double> = star(s.links[index].a, s)
        let b: SIMD3<Double> = star(s.links[index].b, s)
        return a + (b - a) * u + SIMD3(0, 0.12 * u * (1 - u), 0)
    }

    /// The distance from `q` to the segment a–b, by the closest point (the end itself beyond either end).
    static func toSegment(_ q: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let ab: SIMD2<Double> = b - a
        let len2: Double = (ab * ab).sum()
        let t: Double = len2 > 0 ? ((q - a) * ab).sum() / len2 : 0
        let c: SIMD2<Double> = t <= 0 ? a : (t >= 1 ? b : a + ab * t)
        return ((q - c) * (q - c)).sum().squareRoot()
    }

    /// The distance between view points.
    static func length(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { ((a - b) * (a - b)).sum().squareRoot() }

    /// The shortest distance from `q` to link `index`'s projected spline (16 segments).
    static func toLink(_ q: SIMD2<Double>, _ index: Int, _ s: Snapshot, _ camera: AcousticConstellatorCamera,
                       _ size: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        var previous: SIMD2<Double>? = nil
        for k in 0...16 {
            let p: SIMD2<Double>? = project(spline(index, Double(k) / 16, s), camera, size)
            if let a = previous, let b = p { best = min(best, toSegment(q, a, b)) }
            previous = p
        }
        return best
    }

    /// The nearest of `distances` within 22 points, taken in order and replaced only by one nearer by more than 1e-6
    /// points (so ties go to the earlier candidate); `ambiguous` when a distance lies within 1e-7 of 22 or a
    /// difference lies within 1e-9 of the 1e-6 tie band, where rounding may decide.
    static func nearest(_ distances: [Double]) -> (index: Int?, ambiguous: Bool) {
        var best: Int? = nil
        var ambiguous: Bool = false
        for (index, d) in distances.enumerated() {
            if abs(d - 22) < 1e-7 { ambiguous = true }
            guard d <= 22 else { continue }
            if let b = best {
                let gain: Double = distances[b] - d
                if abs(gain - 1e-6) < 1e-9 { ambiguous = true }
                if gain > 1e-6 { best = index }
            } else {
                best = index
            }
        }
        return (best, ambiguous)
    }

    /// The independent pick, or nil near a decision boundary.
    static func expected(_ q: SIMD2<Double>, _ s: Snapshot, _ size: SIMD2<Double>,
                         _ orbit: Orbit) -> AcousticConstellatorPick? {
        let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
        var gauges: [Double] = []
        for index in 0..<12 {
            gauges.append(project(bar(index), camera, size).map { length($0, q) } ?? .infinity)
        }
        for index in 0..<s.hold {
            gauges.append(project(pip(index, s), camera, size).map { length($0, q) } ?? .infinity)
        }
        let gauge = nearest(gauges)
        if gauge.ambiguous { return nil }
        if let index = gauge.index { return index < 12 ? .coherence(index) : .hold(index - 12) }
        var stars: [Double] = []
        for index in s.stars.indices {
            stars.append(project(star(index, s), camera, size).map { length($0, q) } ?? .infinity)
        }
        let starPick = nearest(stars)
        if starPick.ambiguous { return nil }
        if let index = starPick.index { return .star(index) }
        var links: [Double] = []
        for index in s.links.indices { links.append(toLink(q, index, s, camera, size)) }
        let linkPick = nearest(links)
        if linkPick.ambiguous { return nil }
        if let index = linkPick.index { return .link(index) }
        return .empty
    }

    // MARK: Tests

    @Test func fiveHundredSeededPointsAgreeWithAnIndependentPick() throws {
        let snapshots: [Snapshot] = try Self.certified()
        for s in snapshots { #expect(!s.links.isEmpty, "level \(s.levelNumber) has links to pick") }
        var random: LCG = LCG(state: 2_424)
        var bars: Int = 0
        var pips: Int = 0
        var stars: Int = 0
        var links: Int = 0
        var empties: Int = 0
        var skipped: Int = 0
        for size in Self.sizes {
            for orbit in Self.orbits {
                for index in 0..<500 {
                    let s: Snapshot = snapshots[index % snapshots.count]
                    var q: SIMD2<Double> = SIMD2(random.next() * size.x, random.next() * size.y)
                    // Three of every four points near a target (a bar, a pip, a star or a link's middle), so every
                    // target and the order between them are exercised.
                    if index % 4 != 0 {
                        let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: size.x / size.y,
                                                                                 orbit: orbit)
                        let kind: Int = random.int(4)
                        var world: SIMD3<Double> = Self.bar(random.int(12))
                        if kind == 1 {
                            world = Self.pip(random.int(s.hold), s)
                        } else if kind == 2 {
                            world = Self.star(random.int(s.stars.count), s)
                        } else if kind == 3, !s.links.isEmpty {
                            world = Self.spline(random.int(s.links.count), 0.5, s)
                        }
                        if let p = Self.project(world, camera, size) {
                            q = p + SIMD2(random.next() * 60 - 30, random.next() * 60 - 30)
                        }
                    }
                    let picked: AcousticConstellatorPick = Picker.pick(q, size: size, snapshot: s, orbit: orbit)
                    guard let want = Self.expected(q, s, size, orbit) else { skipped += 1; continue }
                    #expect(picked == want, "\(q) in \(size) at \(orbit), level \(s.levelNumber)")
                    switch want {
                    case .coherence: bars += 1
                    case .hold: pips += 1
                    case .star: stars += 1
                    case .link: links += 1
                    case .empty: empties += 1
                    }
                }
            }
        }
        #expect(skipped <= 5)
        #expect(bars > 300 && pips > 200 && stars > 300 && links > 100 && empties > 300,
                "\(bars) \(pips) \(stars) \(links) \(empties)")
    }

    @Test func viewPointMatchesTheIndependentProjection() throws {
        let s: Snapshot = try Self.farRow()
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                var points: [SIMD3<Double>] = [Self.bar(0), Self.bar(11), Self.pip(1, s), Self.spline(0, 0.5, s)]
                for index in s.stars.indices { points.append(Self.star(index, s)) }
                for index in 0..<8 { points.append(Geometry.corner(index)) }
                for p in points {
                    guard let a = Picker.viewPoint(p, size: size, camera: camera),
                          let b = Self.project(p, camera, size) else {
                        Issue.record("\(p) behind the eye at \(orbit)")
                        continue
                    }
                    #expect(Self.length(a, b) < 1e-6, "\(a) vs \(b)")
                }
                // Behind the eye: nil.
                let behind: SIMD3<Double> = camera.eye * 2 - camera.target
                #expect(Picker.viewPoint(behind, size: size, camera: camera) == nil)
            }
        }
    }

    @Test func theTargetIsTwentyTwoPoints() throws {
        let s: Snapshot = try Self.farRow()
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                guard let b0 = Self.project(Self.bar(0), camera, size), let b1 = Self.project(Self.bar(1), camera, size),
                      let p1 = Self.project(Self.pip(1, s), camera, size),
                      let front = Self.project(Self.pip(1, s) + SIMD3(0, 0, 0.1), camera, size),
                      let s0 = Self.project(Self.star(0, s), camera, size),
                      let s1 = Self.project(Self.star(1, s), camera, size),
                      let mid = Self.project(Self.spline(0, 0.5, s), camera, size),
                      let before = Self.project(Self.spline(0, 0.49, s), camera, size),
                      let after = Self.project(Self.spline(0, 0.51, s), camera, size) else {
                    Issue.record("targets behind the eye")
                    continue
                }
                // Coherence bar 0, away from bar 1 along the gauge: 21 points the bar, 23 points nothing.
                let left: SIMD2<Double> = (b0 - b1) / Self.length(b0, b1)
                #expect(Picker.pick(b0 + left * 21, size: size, snapshot: s, orbit: orbit) == .coherence(0))
                #expect(Picker.pick(b0 + left * 23, size: size, snapshot: s, orbit: orbit) == .empty)
                // Hold pip 1, towards the viewer (away from the coherence gauge, over the moves gauge, which is no
                // target): 21 points the pip, 23 points nothing.
                let near: SIMD2<Double> = (front - p1) / Self.length(front, p1)
                #expect(Picker.pick(p1 + near * 21, size: size, snapshot: s, orbit: orbit) == .hold(1))
                #expect(Picker.pick(p1 + near * 23, size: size, snapshot: s, orbit: orbit) == .empty)
                // Star 0, along the link beyond its end: 21 points the star, 23 points nothing.
                let out: SIMD2<Double> = (s0 - s1) / Self.length(s0, s1)
                #expect(Picker.pick(s0 + out * 21, size: size, snapshot: s, orbit: orbit) == .star(0))
                #expect(Picker.pick(s0 + out * 23, size: size, snapshot: s, orbit: orbit) == .empty)
                // The link, square to its projected spline at its middle: 21 points the link, 23 nothing.
                let along: SIMD2<Double> = (after - before) / Self.length(after, before)
                let side: SIMD2<Double> = SIMD2(-along.y, along.x)
                for sign in [1.0, -1.0] {
                    #expect(Picker.pick(mid + side * (21 * sign), size: size, snapshot: s, orbit: orbit) == .link(0))
                    #expect(Picker.pick(mid + side * (23 * sign), size: size, snapshot: s, orbit: orbit) == .empty)
                }
            }
        }
    }

    @Test func gaugesBeatStarsAndStarsBeatLinks() throws {
        // Star 0 at the front centre, just behind the coherence gauge; link 0–1 to the far left corner.
        let s: Snapshot = try Self.handMade([(6, 11, 0), (0, 0, 5), (11, 0, 5)], links: [Link(a: 0, b: 1)])
        let small: SIMD2<Double> = SIMD2(160, 160)
        var checked: Int = 0
        for orbit in Self.orbits {
            let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: 1, orbit: orbit)
            guard let c = Self.project(Self.star(0, s), camera, small),
                  let bar = Self.project(Self.bar(6), camera, small) else {
                Issue.record("targets behind the eye")
                continue
            }
            let between: SIMD2<Double> = (c + bar) / 2
            if Self.length(between, c) <= 21 && Self.length(between, bar) <= 21 {
                checked += 1
                let picked: AcousticConstellatorPick = Picker.pick(between, size: small, snapshot: s, orbit: orbit)
                switch picked {
                case .coherence, .hold: #expect(picked == Self.expected(between, s, small, orbit))
                default: Issue.record("a gauge must win at \(orbit), got \(picked)")
                }
            }
            // On the star's centre (also the link's end): the star, in a view large enough to keep the gauges away.
            let large: SIMD2<Double> = SIMD2(2000, 800)
            let wide: AcousticConstellatorCamera = Geometry.camera(s, aspect: large.x / large.y, orbit: orbit)
            if let centre = Self.project(Self.star(0, s), wide, large) {
                #expect(Self.toLink(centre, 0, s, wide, large) < 1e-6)
                #expect(Picker.pick(centre, size: large, snapshot: s, orbit: orbit) == .star(0))
            }
        }
        #expect(checked == Self.orbits.count, "a point within reach of both the star and a bar at every orbit")
    }

    @Test func tiesGoToTheLowerStarIndexAndTheNearerStarWins() throws {
        // Star 0 just right of the middle of the far row, star 1 just left of it: mirrored at the authored orbit.
        let s: Snapshot = try Self.handMade([(6, 0, 5), (5, 0, 5), (0, 5, 5)], links: [])
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: .authored)
        guard let a = Self.project(Self.star(0, s), camera, size),
              let b = Self.project(Self.star(1, s), camera, size) else {
            Issue.record("stars behind the eye")
            return
        }
        #expect(a.x > size.x / 2 && b.x < size.x / 2 && abs((a.x - size.x / 2) + (b.x - size.x / 2)) < 1e-9)
        #expect(abs(a.y - b.y) < 1e-9 && (a.x - b.x) / 2 < 21)
        let middle: SIMD2<Double> = SIMD2(size.x / 2, a.y)
        #expect(Picker.pick(middle, size: size, snapshot: s, orbit: .authored) == .star(0))
        #expect(Picker.pick(middle + SIMD2(1, 0), size: size, snapshot: s, orbit: .authored) == .star(0))
        #expect(Picker.pick(middle - SIMD2(1, 0), size: size, snapshot: s, orbit: .authored) == .star(1))
        // The drag target: the same rule, the dragged star excluded.
        #expect(Picker.starAt(middle, size: size, snapshot: s, orbit: .authored, excluding: nil) == 0)
        #expect(Picker.starAt(middle, size: size, snapshot: s, orbit: .authored, excluding: 0) == 1)
        #expect(Picker.starAt(middle + SIMD2(1, 0), size: size, snapshot: s, orbit: .authored, excluding: 1) == 0)
        #expect(Picker.starAt(middle - SIMD2(1, 0), size: size, snapshot: s, orbit: .authored, excluding: nil) == 1)
        #expect(Picker.starAt(SIMD2(5, 5), size: size, snapshot: s, orbit: .authored, excluding: nil) == nil)
        // The segment distance: perpendicular inside, to the nearer end outside, to the point for no length.
        let p: SIMD2<Double> = SIMD2(0, 0)
        let q: SIMD2<Double> = SIMD2(10, 0)
        #expect(Picker.segmentDistance(SIMD2(5, 3), p, q) == 3)
        #expect(Picker.segmentDistance(SIMD2(-3, 4), p, q) == 5)
        #expect(Picker.segmentDistance(SIMD2(13, -4), p, q) == 5)
        #expect(Picker.segmentDistance(SIMD2(3, 4), p, p) == 5)
    }

    @Test func theDragTargetAgreesWithTheIndependentNearestStar() throws {
        let snapshots: [Snapshot] = try Self.certified()
        var random: LCG = LCG(state: 2_424)
        var hits: Int = 0
        for size in Self.sizes {
            for orbit in Self.orbits {
                for index in 0..<60 {
                    let s: Snapshot = snapshots[index % snapshots.count]
                    let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                    let excluded: Int = random.int(s.stars.count)
                    let aim: Int = random.int(s.stars.count)
                    guard let p = Self.project(Self.star(aim, s), camera, size) else { continue }
                    let q: SIMD2<Double> = p + SIMD2(random.next() * 50 - 25, random.next() * 50 - 25)
                    var distances: [Double] = []
                    for star in s.stars.indices {
                        let d: Double = Self.project(Self.star(star, s), camera, size).map { Self.length($0, q) }
                            ?? .infinity
                        distances.append(star == excluded ? .infinity : d)
                    }
                    let want = Self.nearest(distances)
                    if want.ambiguous { continue }
                    let got: Int? = Picker.starAt(q, size: size, snapshot: s, orbit: orbit, excluding: excluded)
                    #expect(got == want.index, "\(q) in \(size) at \(orbit)")
                    if got != nil { hits += 1 }
                }
            }
        }
        #expect(hits > 100, "\(hits)")
    }

    @Test func theFingerPointLiesUnderTheFinger() throws {
        let snapshots: [Snapshot] = try Self.certified()
        for s in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                    for index in s.stars.indices {
                        let world: SIMD3<Double> = Self.star(index, s)
                        guard let p = Picker.viewPoint(world, size: size, camera: camera),
                              let back = Picker.fingerPoint(p, size: size, camera: camera, height: world.y) else {
                            Issue.record("star \(index) has no finger point at \(orbit)")
                            continue
                        }
                        #expect(abs(back.x - world.x) < 1e-9 && back.y == world.y && abs(back.z - world.z) < 1e-9,
                                "\(back) vs \(world)")
                        // Off the star, the point stays on the plane and projects back under the finger.
                        let q: SIMD2<Double> = p + SIMD2(37, -23)
                        if let off = Picker.fingerPoint(q, size: size, camera: camera, height: world.y),
                           let seen = Picker.viewPoint(off, size: size, camera: camera) {
                            #expect(off.y == world.y && Self.length(seen, q) < 1e-6)
                        } else {
                            Issue.record("no finger point beside star \(index)")
                        }
                    }
                    // A plane above the eye is missed (the ray points down); unusable input gives nothing.
                    let centre: SIMD2<Double> = size / 2
                    #expect(Picker.fingerPoint(centre, size: size, camera: camera, height: camera.eye.y + 1) == nil)
                    #expect(Picker.fingerPoint(SIMD2(.nan, 1), size: size, camera: camera, height: 0.15) == nil)
                    #expect(Picker.fingerPoint(centre, size: SIMD2(0, 1), camera: camera, height: 0.15) == nil)
                    #expect(Picker.fingerPoint(centre, size: size, camera: camera, height: .infinity) == nil)
                }
            }
        }
    }

    @Test func unusableInputPicksNothing() throws {
        let s: Snapshot = try Self.farRow()
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: AcousticConstellatorCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: .authored)
        guard let p = Self.project(Self.star(1, s), camera, size) else {
            Issue.record("star behind the eye")
            return
        }
        #expect(Picker.pick(p, size: size, snapshot: s, orbit: .authored) == .star(1))
        let badPoints: [SIMD2<Double>] = [SIMD2(.nan, p.y), SIMD2(p.x, .infinity), SIMD2(-.infinity, p.y)]
        let badSizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, 0), SIMD2(-390, 844), SIMD2(390, -1),
                                         SIMD2(.nan, 844), SIMD2(390, .infinity)]
        for point in badPoints {
            #expect(Picker.pick(point, size: size, snapshot: s, orbit: .authored) == .empty)
            #expect(Picker.starAt(point, size: size, snapshot: s, orbit: .authored, excluding: nil) == nil)
        }
        for bad in badSizes {
            #expect(Picker.pick(p, size: bad, snapshot: s, orbit: .authored) == .empty)
            #expect(Picker.starAt(p, size: bad, snapshot: s, orbit: .authored, excluding: nil) == nil)
            #expect(Picker.viewPoint(Self.star(1, s), size: bad, camera: camera) == nil)
        }
        let nonFinite: SIMD3<Double> = SIMD3(.nan, 0, 0)
        #expect(Picker.viewPoint(nonFinite, size: size, camera: camera) == nil)
        // A non-finite orbit is the authored one.
        let odd: Orbit = Orbit(yaw: .nan, pitch: .infinity)
        #expect(Picker.pick(p, size: size, snapshot: s, orbit: odd) == .star(1))
        // The moves gauge and the guides are never targets.
        let three: Snapshot = try Self.handMade([(0, 0, 5), (11, 0, 5), (0, 5, 5)], links: [])
        #expect(!three.unlinkedSymbolPairs.isEmpty)
        let large: SIMD2<Double> = SIMD2(2000, 800)
        let wide: AcousticConstellatorCamera = Geometry.camera(three, aspect: large.x / large.y, orbit: .authored)
        if let moves = Self.project(Geometry.movesBar(0, three), wide, large),
           let guide = Self.project((Self.star(0, three) + Self.star(1, three)) / 2, wide, large) {
            #expect(Picker.pick(moves, size: large, snapshot: three, orbit: .authored) == .empty)
            #expect(Picker.pick(guide, size: large, snapshot: three, orbit: .authored) == .empty)
        }
    }
}
