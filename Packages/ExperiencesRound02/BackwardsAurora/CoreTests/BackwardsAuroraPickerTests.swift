// BackwardsAuroraPickerTests — feature 394 (R02-G10-04) T-R02G1004-003 (FR-R02G1004-001, 004; SC-R02G1004-001;
// clarification Q1). The analytic picker and the sample column against an independent computation written here: its
// own camera ray and projector (built from the drawn camera's eye, view axes and field of view, not
// `ScreenProjection`), its own sample points, band and columns from the clarified formulas. 500 seeded points (seed
// 2_394) over certified levels 1, 25, 50, 75 and 100 (generated from the manifest and played to their witness) with
// sections in the middle and at both ends, three view sizes and three orbits; the 22-point minimum target of the ends;
// the ends winning over the band and the samples; non-finite and unusable input. Plain loops and explicit types (CI
// type-check rule); well under 10 s.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import BackwardsAuroraCore

@Suite struct BackwardsAuroraPickerTests {
    typealias Geometry = BackwardsAuroraSceneGeometry
    typealias Snapshot = BackwardsAuroraSceneSnapshot
    typealias Picker = BackwardsAuroraPicker
    typealias Orbit = BackwardsAuroraOrbit

    /// The view sizes in points: phone portrait, tablet landscape and a small view where the targets overlap.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1_180, 820), SIMD2(200, 150)]

    /// The authored orbit and two orbits inside the bounds.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.5, pitch: 0.3), Orbit(yaw: -0.55, pitch: -0.2)]

    /// One certified level's snapshot with a chosen section.
    struct Case {
        /// The catalog level number.
        let number: Int
        /// The snapshot drawn.
        let snapshot: Snapshot
    }

    /// Catalog levels 1, 25, 50, 75 and 100 played to their witness, each with the section across the middle, at the
    /// left end and at the right end.
    static func cases() throws -> [Case] {
        var result: [Case] = []
        for number in [1, 25, 50, 75, 100] {
            let generated: BackwardsAuroraGenerated = try BackwardsAuroraGenerator.generate(
                BackwardsAuroraManifest.entries[number - 1])
            var play: BackwardsAuroraPlay = BackwardsAuroraPlay(level: generated.level)
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in generated.solution.actions { try play.apply(action, expecting: play.fingerprint) }
            let n: Int = play.wave.count
            let sections: [(Int, Int)] = [(2, n - 3), (0, 3), (n - 4, n - 1)]
            for section in sections {
                result.append(Case(number: number, snapshot: Snapshot(play: play, levelNumber: number,
                                                                      sectionStart: section.0,
                                                                      sectionEnd: section.1, time: 1)))
            }
        }
        return result
    }

    // MARK: Independent camera

    /// The drawn camera's frame, read from its view matrix rows (right, up, −forward) and its field of view.
    struct Frame {
        /// The eye.
        let eye: SIMD3<Double>
        /// The view's right axis.
        let right: SIMD3<Double>
        /// The view's up axis.
        let up: SIMD3<Double>
        /// The view direction.
        let forward: SIMD3<Double>
        /// tan of half the vertical field of view.
        let tanY: Double
        /// tan of half the horizontal field of view.
        let tanX: Double
        /// The view size in points.
        let size: SIMD2<Double>

        /// The frame of the drawn camera for `snapshot` in a view of `size` points at `orbit`.
        init(_ snapshot: Snapshot, size: SIMD2<Double>, orbit: Orbit) {
            let camera: BackwardsAuroraCamera = Geometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
            let r0: Vec4 = camera.view.row(0)
            let r1: Vec4 = camera.view.row(1)
            let r2: Vec4 = camera.view.row(2)
            eye = camera.eye
            right = SIMD3(r0.x, r0.y, r0.z)
            up = SIMD3(r1.x, r1.y, r1.z)
            forward = SIMD3(-r2.x, -r2.y, -r2.z)
            tanY = tan(camera.fovY / 2)
            tanX = tanY * camera.aspect
            self.size = size
        }

        /// The unit ray direction from the eye through `point` (view points, y down).
        func ray(_ point: SIMD2<Double>) -> SIMD3<Double> {
            let x: Double = 2 * point.x / size.x - 1
            let y: Double = 1 - 2 * point.y / size.y
            let d: SIMD3<Double> = forward + right * (x * tanX) + up * (y * tanY)
            return d / (d * d).sum().squareRoot()
        }

        /// The projection of `world` in view points (y down); nil behind the eye.
        func project(_ world: SIMD3<Double>) -> SIMD2<Double>? {
            let rel: SIMD3<Double> = world - eye
            let z: Double = (rel * forward).sum()
            guard z > 1e-9 else { return nil }
            let x: Double = (rel * right).sum() / (z * tanX)
            let y: Double = (rel * up).sum() / (z * tanY)
            return SIMD2((x + 1) / 2 * size.x, (1 - y) / 2 * size.y)
        }

        /// The point where the ray through `point` meets z = 0 ahead of the eye; nil otherwise.
        func plane(_ point: SIMD2<Double>) -> SIMD2<Double>? {
            let d: SIMD3<Double> = ray(point)
            guard abs(d.z) > 1e-12 else { return nil }
            let t: Double = -eye.z / d.z
            guard t > 0 else { return nil }
            let p: SIMD3<Double> = eye + d * t
            return SIMD2(p.x, p.y)
        }
    }

    // MARK: Independent places (the clarified formulas)

    /// u = 2 / N.
    static func spacing(_ s: Snapshot) -> Double { 2.0 / Double(s.samples.count) }

    /// Sample k's point: (−1 + (k + 0.5)·u, 0.6·s(k) / 64, 0).
    static func sample(_ s: Snapshot, _ k: Int) -> SIMD3<Double> {
        SIMD3(-1 + (Double(k) + 0.5) * spacing(s), 0.6 * Double(s.samples[k]) / 64, 0)
    }

    /// The distance between view points.
    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { ((a - b) * (a - b)).sum().squareRoot() }

    /// The independent column of x: floor((x + 1) / u), and whether x lies within a rounding distance of a column line.
    static func column(_ x: Double, _ s: Snapshot) -> (k: Int, ambiguous: Bool) {
        let f: Double = (x + 1) / spacing(s)
        return (Int(min(max(f.rounded(.down), -1e6), 1e6)), abs(f - f.rounded()) < 1e-7)
    }

    /// The independent pick, whether it lies within a rounding distance of a decision boundary, and how it was made.
    static func expected(_ point: SIMD2<Double>, frame: Frame, snapshot s: Snapshot)
        -> (pick: BackwardsAuroraPick, ambiguous: Bool, how: String) {
        var ambiguous: Bool = false
        var ds: Double = .infinity
        var de: Double = .infinity
        if let p = frame.project(sample(s, s.sectionStart)) { ds = distance(p, point) }
        if let p = frame.project(sample(s, s.sectionEnd)) { de = distance(p, point) }
        if abs(ds - 22) < 1e-6 || abs(de - 22) < 1e-6 { ambiguous = true }
        if ds <= 22 || de <= 22 {
            if abs(ds - de) < 1e-9 { ambiguous = true }
            return ds <= de ? (.start, ambiguous, "start") : (.end, ambiguous, "end")
        }
        guard let hit = frame.plane(point) else { return (.empty, ambiguous, "empty") }
        let n: Int = s.samples.count
        let u: Double = spacing(s)
        let low: Double = -1 + Double(s.sectionStart) * u
        let high: Double = -1 + Double(s.sectionEnd + 1) * u
        let c: (k: Int, ambiguous: Bool) = column(hit.x, s)
        if abs(hit.x - low) < 1e-9 || abs(hit.x - high) < 1e-9 || abs(abs(hit.y) - 0.7) < 1e-9 { ambiguous = true }
        if hit.x >= low && hit.x <= high && abs(hit.y) <= 0.7 {
            if c.ambiguous { ambiguous = true }
            return (.band(min(max(c.k, s.sectionStart), s.sectionEnd)), ambiguous, "band")
        }
        if abs(abs(hit.x) - 1) < 1e-9 || abs(abs(hit.y) - 0.75) < 1e-9 { ambiguous = true }
        if abs(hit.x) <= 1 && abs(hit.y) <= 0.75 {
            if c.ambiguous { ambiguous = true }
            return (.sample(min(max(c.k, 0), n - 1)), ambiguous, "sample")
        }
        return (.empty, ambiguous, "empty")
    }

    /// A seeded point of class `kind`: anywhere, near an end, inside the band, near a sample, near the timeline's
    /// left or right edge.
    static func point(_ random: inout SeededRandom, kind: Int, frame: Frame, snapshot s: Snapshot) -> SIMD2<Double> {
        var anchor: SIMD2<Double>? = nil
        var spread: Double = 0.08 * min(frame.size.x, frame.size.y)
        let n: Int = s.samples.count
        if kind == 1 {
            anchor = frame.project(sample(s, random.int(0...1) == 0 ? s.sectionStart : s.sectionEnd))
            spread = 30
        }
        if kind == 2 {
            let x: Double = random.range((-1 + Double(s.sectionStart) * spacing(s))...(-1 + Double(s.sectionEnd + 1)
                                                                                         * spacing(s)))
            anchor = frame.project(SIMD3(x, random.range(-0.7...0.7), 0))
            spread = 4
        }
        if kind == 3 {
            anchor = frame.project(sample(s, random.int(0...(n - 1))))
        }
        if kind == 4 {
            let x: Double = random.int(0...1) == 0 ? -1 : 1
            anchor = frame.project(SIMD3(x, random.range(-0.8...0.8), 0))
        }
        var p: SIMD2<Double> = SIMD2(random.range(1...(frame.size.x - 1)), random.range(1...(frame.size.y - 1)))
        if let anchor {
            p = anchor + SIMD2(random.range(-spread...spread), random.range(-spread...spread))
        }
        return SIMD2(min(max(p.x, 1), frame.size.x - 1), min(max(p.y, 1), frame.size.y - 1))
    }

    // MARK: Picks

    @Test func fiveHundredSeededPicksMatchTheIndependentPick() throws {
        let cases: [Case] = try Self.cases()
        var random: SeededRandom = SeededRandom(seed: 2_394)
        var counts: [String: Int] = [:]
        var ambiguous: Int = 0
        for k in 0..<500 {
            let c: Case = cases[k % cases.count]
            let size: SIMD2<Double> = Self.sizes[(k / cases.count) % Self.sizes.count]
            let orbit: Orbit = Self.orbits[(k / 3) % Self.orbits.count]
            let frame: Frame = Frame(c.snapshot, size: size, orbit: orbit)
            let p: SIMD2<Double> = Self.point(&random, kind: random.int(0...4), frame: frame, snapshot: c.snapshot)
            let expected: (pick: BackwardsAuroraPick, ambiguous: Bool, how: String) =
                Self.expected(p, frame: frame, snapshot: c.snapshot)
            if expected.ambiguous {
                ambiguous += 1
                continue
            }
            let pick: BackwardsAuroraPick = Picker.pick(p, size: size, snapshot: c.snapshot, orbit: orbit)
            #expect(pick == expected.pick, "level \(c.number) size \(size) orbit \(orbit) point \(p)")
            counts[expected.how, default: 0] += 1
            // The sample column under the point, clamped to the wave.
            guard let hit = frame.plane(p) else {
                #expect(Picker.column(p, size: size, snapshot: c.snapshot, orbit: orbit) == nil)
                continue
            }
            let column: (k: Int, ambiguous: Bool) = Self.column(hit.x, c.snapshot)
            guard !column.ambiguous else { continue }
            let want: Int = min(max(column.k, 0), c.snapshot.count - 1)
            #expect(Picker.column(p, size: size, snapshot: c.snapshot, orbit: orbit) == want)
        }
        #expect(ambiguous <= 5)
        for key in ["start", "end", "band", "sample", "empty"] {
            #expect((counts[key] ?? 0) > 0, "no \(key) pick among \(counts)")
        }
    }

    @Test func theEndsHaveAMinimumTargetOfTwentyTwoPoints() throws {
        #expect(Picker.minimumTarget == 22)
        var inside: Int = 0
        var outside: Int = 0
        for c in try Self.cases() {
            let s: Snapshot = c.snapshot
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let frame: Frame = Frame(s, size: size, orbit: orbit)
                    guard let start = frame.project(Self.sample(s, s.sectionStart)),
                          let end = frame.project(Self.sample(s, s.sectionEnd)) else {
                        Issue.record("an end is not projected")
                        continue
                    }
                    for centre in [start, end] {
                        for k in 0..<16 {
                            let angle: Double = 2 * Double.pi * Double(k) / 16
                            for radius in [21.0, 23.0] {
                                let p: SIMD2<Double> = centre + SIMD2(cos(angle), sin(angle)) * radius
                                guard p.x > 0, p.y > 0, p.x < size.x, p.y < size.y else { continue }
                                let pick: BackwardsAuroraPick = Picker.pick(p, size: size, snapshot: s, orbit: orbit)
                                let ds: Double = Self.distance(p, start)
                                let de: Double = Self.distance(p, end)
                                if radius < 22 {
                                    #expect(pick == .start || pick == .end)
                                    if abs(ds - de) > 1e-6 { #expect(pick == (ds < de ? .start : .end)) }
                                    inside += 1
                                } else if ds > 22 + 1e-6 && de > 22 + 1e-6 {
                                    #expect(pick != .start && pick != .end)
                                    outside += 1
                                }
                            }
                        }
                    }
                }
            }
        }
        #expect(inside > 500 && outside > 300)
    }

    @Test func theEndsWinOverTheBandAndTheSamples() throws {
        var checked: Int = 0
        for c in try Self.cases() {
            let s: Snapshot = c.snapshot
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let frame: Frame = Frame(s, size: size, orbit: orbit)
                    for (index, k) in [s.sectionStart, s.sectionEnd].enumerated() {
                        guard let p = frame.project(Self.sample(s, k)) else { continue }
                        // A touch 10 points off the end's projected point, sideways into the band.
                        let q: SIMD2<Double> = p + SIMD2(index == 0 ? 10 : -10, 0)
                        guard q.x > 0, q.y > 0, q.x < size.x, q.y < size.y,
                              let hit = frame.plane(q) else { continue }
                        let other: SIMD2<Double>? = frame.project(Self.sample(s, index == 0 ? s.sectionEnd
                                                                                : s.sectionStart))
                        let own: Double = Self.distance(q, p)
                        let rival: Double = other.map { Self.distance(q, $0) } ?? .infinity
                        // Only touches whose point on z = 0 lies on the band or a sample column count: the end still wins.
                        guard abs(own - rival) > 1e-6, abs(hit.x) <= 1, abs(hit.y) <= 0.75 else { continue }
                        let ownPick: BackwardsAuroraPick = index == 0 ? .start : .end
                        let rivalPick: BackwardsAuroraPick = index == 0 ? .end : .start
                        let want: BackwardsAuroraPick = own < rival ? ownPick : rivalPick
                        #expect(Picker.pick(q, size: size, snapshot: s, orbit: orbit) == want)
                        checked += 1
                    }
                }
            }
        }
        #expect(checked > 100)
    }

    @Test func unusableInputPicksNothing() throws {
        let s: Snapshot = try Self.cases()[0].snapshot
        let size: SIMD2<Double> = SIMD2(390, 844)
        let bad: [SIMD2<Double>] = [SIMD2(.nan, 10), SIMD2(10, .infinity), SIMD2(-50, 10), SIMD2(10, 900)]
        for p in bad {
            #expect(Picker.pick(p, size: size, snapshot: s, orbit: .authored) == .empty)
            #expect(Picker.column(p, size: size, snapshot: s, orbit: .authored) == nil)
        }
        for z in [SIMD2<Double>(0, 844), SIMD2(390, -1), SIMD2(.nan, 844)] {
            #expect(Picker.pick(SIMD2(10, 10), size: z, snapshot: s, orbit: .authored) == .empty)
            #expect(Picker.column(SIMD2(10, 10), size: z, snapshot: s, orbit: .authored) == nil)
        }
        // A wild orbit is clamped: the same pick as at the bound.
        let wild: Orbit = Orbit(yaw: 9, pitch: -9)
        let bound: Orbit = Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound)
        #expect(wild.clamped() == bound)
        let p: SIMD2<Double> = SIMD2(195, 422)
        #expect(Picker.pick(p, size: size, snapshot: s, orbit: wild) == Picker.pick(p, size: size, snapshot: s,
                                                                                     orbit: bound))
    }
}
