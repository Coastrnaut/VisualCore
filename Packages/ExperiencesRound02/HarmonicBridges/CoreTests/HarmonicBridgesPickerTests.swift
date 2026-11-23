// HarmonicBridgesPickerTests — feature 414 (R02-G12-04) T-R02G1204-002 (FR-R02G1204-004; SC-R02G1204-001; research R1).
// The analytic picker of Harmonic Bridges against an independent pick written here (its own camera basis and projection
// from the camera's eye, target, field of view and aspect; its own island tops, pip centres and segment distance from
// the grid formulas): 500 seeded points (LCG seed 2_414) per view size and orbit over certified levels 1, 50 and 100
// (level 100 has overlapping collinear strings: ties go to the lower index), at 3 view sizes and 3 orbits; the 22-point
// target of a pip, the goal and a string at 21 and 23 points; a pip beats the goal and the goal beats a string; the
// nearer of two pips wins; unusable input picks nothing. Explicit types, plain loops; well under 10 s each.
import Foundation
import Testing
import VisualCoreMath
@testable import HarmonicBridgesCore

@Suite struct HarmonicBridgesPickerTests {
    typealias Geometry = HarmonicBridgesSceneGeometry
    typealias Snapshot = HarmonicBridgesSceneSnapshot
    typealias Picker = HarmonicBridgesPicker

    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1024, 768), SIMD2(2000, 800)]

    static let orbits: [HarmonicBridgesOrbit] = [HarmonicBridgesOrbit.authored,
                                                 HarmonicBridgesOrbit(yaw: HarmonicBridgesOrbit.yawLimit,
                                                                      pitch: HarmonicBridgesOrbit.pitchRange.upperBound),
                                                 HarmonicBridgesOrbit(yaw: -0.3,
                                                                      pitch: HarmonicBridgesOrbit.pitchRange.lowerBound)]

    /// A 64-bit linear congruential generator (Knuth's MMIX constants).
    struct LCG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / 9_007_199_254_740_992
        }
        mutating func int(_ upper: Int) -> Int { min(Int(next() * Double(upper)), upper - 1) }
    }

    /// The opening snapshots of certified levels 1, 50 and 100.
    static func certified() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for number in [1, 50, 100] {
            result.append(try HarmonicBridgesExperienceCore.opening(number: number).snapshot(time: 0))
        }
        return result
    }

    /// A begun play (tutorial dismissed) of a hand-made level on `islands` with `strings`, goal `goal` and `steps`
    /// window steps.
    static func handMade(_ islands: [HarmonicBridgesIsland], _ strings: [HarmonicBridgesString], goal: Int,
                         steps: Int) throws -> Snapshot {
        var window: [[HarmonicBridgesTone]] = []
        for _ in 0..<steps { window.append([HarmonicBridgesTone(frequency: 1, strength: 1)]) }
        let level = try HarmonicBridgesLevel(id: "picker-hand-made", seed: 5, difficulty: 1, islands: islands,
                                             strings: strings, start: 0, goal: goal, steps: window, threshold: 12,
                                             budget: 10)
        var play = HarmonicBridgesPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return Snapshot(play: play, levelNumber: 1, time: 0)
    }

    /// Two islands on the far row (gy = 0), the goal the right one, one string between them, one step: the pip sits
    /// alone at the front.
    static func farRow() throws -> Snapshot {
        try handMade([HarmonicBridgesIsland(x: 2, y: 0), HarmonicBridgesIsland(x: 13, y: 0)],
                     [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)], goal: 1, steps: 1)
    }

    // MARK: The independent pick

    /// The camera basis (right, up, forward) from the eye towards the target with +y up.
    static func basis(_ camera: HarmonicBridgesCamera) -> (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) {
        let f0: SIMD3<Double> = camera.target - camera.eye
        let f: SIMD3<Double> = f0 / (f0 * f0).sum().squareRoot()
        let r0: SIMD3<Double> = SIMD3(-f.z, 0, f.x)
        let r: SIMD3<Double> = r0 / (r0 * r0).sum().squareRoot()
        let u: SIMD3<Double> = SIMD3(r.y * f.z - r.z * f.y, r.z * f.x - r.x * f.z, r.x * f.y - r.y * f.x)
        return (r, u, f)
    }

    /// World `p` in view points of `size`, or nil behind the eye.
    static func project(_ p: SIMD3<Double>, _ camera: HarmonicBridgesCamera, _ size: SIMD2<Double>) -> SIMD2<Double>? {
        let (r, u, f): (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) = basis(camera)
        let d: SIMD3<Double> = p - camera.eye
        let depth: Double = (d * f).sum()
        guard depth > 0 else { return nil }
        let t: Double = tan(camera.fovY / 2)
        let nx: Double = (d * r).sum() / (depth * t * camera.aspect)
        let ny: Double = (d * u).sum() / (depth * t)
        return SIMD2((nx + 1) / 2 * size.x, (1 - ny) / 2 * size.y)
    }

    /// The top centre of island `index`: ((gx − 7.5)·0.12, 0.1, (gy − 4.5)·0.12).
    static func top(_ index: Int, _ s: Snapshot) -> SIMD3<Double> {
        let island: HarmonicBridgesIsland = s.islands[index]
        return SIMD3((Double(island.x) - 7.5) * 0.12, 0.1, (Double(island.y) - 4.5) * 0.12)
    }

    /// The centre of step `index`'s pip: (−0.3 + (index + 0.5)·0.6 / steps, 0, 0.8).
    static func pip(_ index: Int, _ s: Snapshot) -> SIMD3<Double> {
        SIMD3(-0.3 + (Double(index) + 0.5) * 0.6 / Double(s.steps), 0, 0.8)
    }

    /// The distance from `q` to the segment a–b, by the closest point (the end itself beyond either end).
    static func toSegment(_ q: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let ab: SIMD2<Double> = b - a
        let len2: Double = (ab * ab).sum()
        let t: Double = len2 > 0 ? ((q - a) * ab).sum() / len2 : 0
        let c: SIMD2<Double> = t <= 0 ? a : (t >= 1 ? b : a + ab * t)
        return ((q - c) * (q - c)).sum().squareRoot()
    }

    /// The nearest of `distances` within 22 points, taken in index order and replaced only by one nearer by more than
    /// 1e-6 points (so ties, such as overlapping collinear strings, go to the lower index); `ambiguous` when a distance
    /// lies within 1e-7 of 22 or a difference lies within 1e-9 of the 1e-6 tie band, where rounding may decide.
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
                         _ orbit: HarmonicBridgesOrbit) -> HarmonicBridgesPick? {
        let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
        var pips: [Double] = []
        for step in 0..<s.steps {
            guard let p = project(pip(step, s), camera, size) else { pips.append(.infinity); continue }
            pips.append(((p - q) * (p - q)).sum().squareRoot())
        }
        let pipPick = nearest(pips)
        if pipPick.ambiguous { return nil }
        if let step = pipPick.index { return .pip(step) }
        if let g = project(top(s.goal, s), camera, size) {
            let d: Double = ((g - q) * (g - q)).sum().squareRoot()
            if abs(d - 22) < 1e-7 { return nil }
            if d <= 22 { return .goal }
        }
        var strings: [Double] = []
        for string in s.strings {
            guard let a = project(top(string.a, s), camera, size),
                  let b = project(top(string.b, s), camera, size) else { strings.append(.infinity); continue }
            strings.append(toSegment(q, a, b))
        }
        let stringPick = nearest(strings)
        if stringPick.ambiguous { return nil }
        if let index = stringPick.index { return .string(index) }
        return .empty
    }

    // MARK: Tests

    @Test func fiveHundredSeededPointsAgreeWithAnIndependentPick() throws {
        let snapshots: [Snapshot] = try Self.certified()
        var random: LCG = LCG(state: 2_414)
        var pips: Int = 0
        var goals: Int = 0
        var strings: Int = 0
        var empties: Int = 0
        var skipped: Int = 0
        for size in Self.sizes {
            for orbit in Self.orbits {
                for index in 0..<500 {
                    let s: Snapshot = snapshots[index % snapshots.count]
                    var q: SIMD2<Double> = SIMD2(random.next() * size.x, random.next() * size.y)
                    // Two of every three points near a target (a pip, the goal or a string's midpoint), so every
                    // target and the order between them are exercised.
                    if index % 3 != 0 {
                        let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                        let kind: Int = random.int(3)
                        var world: SIMD3<Double> = Self.top(s.goal, s)
                        if kind == 0 {
                            world = Self.pip(random.int(s.steps), s)
                        } else if kind == 1 {
                            let string: HarmonicBridgesString = s.strings[random.int(s.strings.count)]
                            world = (Self.top(string.a, s) + Self.top(string.b, s)) / 2
                        }
                        if let p = Self.project(world, camera, size) {
                            q = p + SIMD2(random.next() * 60 - 30, random.next() * 60 - 30)
                        }
                    }
                    let picked: HarmonicBridgesPick = Picker.pick(q, size: size, snapshot: s, orbit: orbit)
                    guard let want = Self.expected(q, s, size, orbit) else { skipped += 1; continue }
                    #expect(picked == want, "\(q) in \(size) at \(orbit), level \(s.levelNumber)")
                    switch want {
                    case .pip: pips += 1
                    case .goal: goals += 1
                    case .string: strings += 1
                    case .empty: empties += 1
                    }
                }
            }
        }
        #expect(skipped <= 5)
        #expect(pips > 200 && goals > 100 && strings > 500 && empties > 300, "\(pips) \(goals) \(strings) \(empties)")
    }

    @Test func viewPointMatchesTheIndependentProjection() throws {
        let s: Snapshot = try Self.farRow()
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                var points: [SIMD3<Double>] = [Self.pip(0, s), Self.top(0, s), Self.top(1, s)]
                for index in 0..<8 { points.append(Geometry.corner(index)) }
                for p in points {
                    guard let a = Picker.viewPoint(p, size: size, camera: camera),
                          let b = Self.project(p, camera, size) else {
                        Issue.record("\(p) behind the eye at \(orbit)")
                        continue
                    }
                    #expect(((a - b) * (a - b)).sum().squareRoot() < 1e-6, "\(a) vs \(b)")
                }
                // Behind the eye: nil.
                let behind: SIMD3<Double> = camera.eye * 2 - camera.target
                #expect(Picker.viewPoint(behind, size: size, camera: camera) == nil)
            }
        }
    }

    @Test func theTargetIsTwentyTwoPoints() throws {
        let s: Snapshot = try Self.farRow()
        let directions: [SIMD2<Double>] = [SIMD2(1, 0), SIMD2(-1, 0), SIMD2(0, 1), SIMD2(0.6, -0.8)]
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                guard let p = Self.project(Self.pip(0, s), camera, size),
                      let g = Self.project(Self.top(1, s), camera, size),
                      let a = Self.project(Self.top(0, s), camera, size) else {
                    Issue.record("targets behind the eye")
                    continue
                }
                // The pip stands alone: 21 points away picks it, 23 points away picks nothing.
                for direction in directions {
                    #expect(Picker.pick(p + direction * 21, size: size, snapshot: s, orbit: orbit) == .pip(0))
                    #expect(Picker.pick(p + direction * 23, size: size, snapshot: s, orbit: orbit) == .empty)
                }
                // The goal, along the string's direction beyond its end: 21 points the goal, 23 points nothing.
                let along: SIMD2<Double> = (g - a) / ((g - a) * (g - a)).sum().squareRoot()
                #expect(Picker.pick(g + along * 21, size: size, snapshot: s, orbit: orbit) == .goal)
                #expect(Picker.pick(g + along * 23, size: size, snapshot: s, orbit: orbit) == .empty)
                // The string, square to its projected segment from its midpoint: 21 points the string, 23 nothing.
                let mid: SIMD2<Double> = (a + g) / 2
                let side: SIMD2<Double> = SIMD2(-along.y, along.x)
                for sign in [1.0, -1.0] {
                    #expect(Picker.pick(mid + side * (21 * sign), size: size, snapshot: s, orbit: orbit) == .string(0))
                    #expect(Picker.pick(mid + side * (23 * sign), size: size, snapshot: s, orbit: orbit) == .empty)
                }
            }
        }
    }

    @Test func aPipBeatsTheGoalAndTheGoalBeatsAString() throws {
        // The goal at the front centre (gy = 9), a string from it to the far corner, one step: in a small view the pip
        // and the goal lie within 22 points of each other.
        let s: Snapshot = try Self.handMade([HarmonicBridgesIsland(x: 0, y: 0), HarmonicBridgesIsland(x: 8, y: 9)],
                                            [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)], goal: 1, steps: 1)
        let size: SIMD2<Double> = SIMD2(120, 120)
        for orbit in Self.orbits {
            let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: 1, orbit: orbit)
            guard let p = Self.project(Self.pip(0, s), camera, size),
                  let g = Self.project(Self.top(1, s), camera, size),
                  let a = Self.project(Self.top(0, s), camera, size) else {
                Issue.record("targets behind the eye")
                continue
            }
            let between: SIMD2<Double> = (p + g) / 2
            let toPip: Double = ((between - p) * (between - p)).sum().squareRoot()
            let toGoal: Double = ((between - g) * (between - g)).sum().squareRoot()
            #expect(toPip <= 22 && toGoal <= 22 && Self.toSegment(between, a, g) <= 22, "\(toPip) \(toGoal)")
            #expect(Picker.pick(between, size: size, snapshot: s, orbit: orbit) == .pip(0))
            // On the goal's top centre (also on the string's end), away from the pip: the goal.
            let away: SIMD2<Double> = g + (g - p) / ((g - p) * (g - p)).sum().squareRoot() * 2
            if ((away - p) * (away - p)).sum().squareRoot() > 22 {
                #expect(Picker.pick(away, size: size, snapshot: s, orbit: orbit) == .goal)
            }
        }
        // In a large view the goal's top centre is far from the pip: the goal, though the string ends there too.
        let large: SIMD2<Double> = SIMD2(1024, 768)
        let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: large.x / large.y, orbit: .authored)
        if let g = Self.project(Self.top(1, s), camera, large) {
            #expect(Picker.pick(g, size: large, snapshot: s, orbit: .authored) == .goal)
        }
    }

    @Test func theNearerPipWinsAndTheSegmentDistanceIsExact() throws {
        let s: Snapshot = try Self.handMade([HarmonicBridgesIsland(x: 0, y: 0), HarmonicBridgesIsland(x: 15, y: 0)],
                                            [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)], goal: 1, steps: 2)
        let size: SIMD2<Double> = SIMD2(200, 200)
        let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: 1, orbit: .authored)
        guard let p0 = Self.project(Self.pip(0, s), camera, size),
              let p1 = Self.project(Self.pip(1, s), camera, size) else {
            Issue.record("pips behind the eye")
            return
        }
        // Mirrored about the view's centre at the authored orbit and within 22 points of each other's midpoint.
        #expect(p0.x < 100 && p1.x > 100 && abs((p0.x - 100) + (p1.x - 100)) < 1e-9)
        let half: Double = (p1.x - p0.x) / 2
        #expect(half < 21)
        #expect(Picker.pick(SIMD2(99, p0.y), size: size, snapshot: s, orbit: .authored) == .pip(0))
        #expect(Picker.pick(SIMD2(101, p0.y), size: size, snapshot: s, orbit: .authored) == .pip(1))
        // The segment distance: perpendicular inside, to the nearer end outside, to the point for no length.
        let a: SIMD2<Double> = SIMD2(0, 0)
        let b: SIMD2<Double> = SIMD2(10, 0)
        #expect(Picker.segmentDistance(SIMD2(5, 3), a, b) == 3)
        #expect(Picker.segmentDistance(SIMD2(-3, 4), a, b) == 5)
        #expect(Picker.segmentDistance(SIMD2(13, -4), a, b) == 5)
        #expect(Picker.segmentDistance(SIMD2(3, 4), a, a) == 5)
    }

    @Test func unusableInputPicksNothing() throws {
        let s: Snapshot = try Self.farRow()
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: HarmonicBridgesCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: .authored)
        guard let p = Self.project(Self.pip(0, s), camera, size) else {
            Issue.record("pip behind the eye")
            return
        }
        #expect(Picker.pick(p, size: size, snapshot: s, orbit: .authored) == .pip(0))
        let badPoints: [SIMD2<Double>] = [SIMD2(.nan, p.y), SIMD2(p.x, .infinity), SIMD2(-.infinity, p.y)]
        let badSizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, 0), SIMD2(-390, 844), SIMD2(390, -1),
                                         SIMD2(.nan, 844), SIMD2(390, .infinity)]
        for point in badPoints {
            #expect(Picker.pick(point, size: size, snapshot: s, orbit: .authored) == .empty)
        }
        for bad in badSizes {
            #expect(Picker.pick(p, size: bad, snapshot: s, orbit: .authored) == .empty)
            #expect(Picker.viewPoint(Self.pip(0, s), size: bad, camera: camera) == nil)
        }
        let nonFinite: SIMD3<Double> = SIMD3(.nan, 0, 0)
        #expect(Picker.viewPoint(nonFinite, size: size, camera: camera) == nil)
        // A non-finite orbit is the authored one.
        let odd: HarmonicBridgesOrbit = HarmonicBridgesOrbit(yaw: .nan, pitch: .infinity)
        #expect(Picker.pick(p, size: size, snapshot: s, orbit: odd) == .pip(0))
    }
}
