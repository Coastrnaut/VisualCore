// NocturneGardenPickerTests — feature 384 (R02-G09-04) T-R02G0904-003 (FR-R02G0904-001, 003, 004; SC-R02G0904-001;
// clarifications Q1–Q3). The analytic picker, the bed cell, the sun steps and the pinch size against an independent
// computation written here: its own camera ray and projector (built from the drawn camera's eye, view axes and field of
// view, not `ScreenProjection`), its own lantern, head outlines, head boxes, feet and bed cell from the clarified
// formulas, its own rounding of drags and its own nearest allowed value. 500 seeded points (seed 2_384) over the
// certified levels 1, 21, 41, 61 and 81 played to their certified solution (and the opening bed of level 1), three view
// sizes and three orbits; the minimum target of the lantern and of the blooms' feet; the ties to the lower; and
// non-finite input. Plain loops and explicit types (CI type-check rule); well under 10 s.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import NocturneGardenCore

@Suite struct NocturneGardenPickerTests {
    typealias Geometry = NocturneGardenSceneGeometry
    typealias Snapshot = NocturneGardenSceneSnapshot
    typealias Picker = NocturneGardenPicker
    typealias Orbit = NocturneGardenOrbit

    /// The view sizes in points: phone portrait, tablet landscape and a small view where the targets overlap.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1_180, 820), SIMD2(200, 150)]

    /// The authored orbit and two orbits inside the bounds.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.5, pitch: 0.4), Orbit(yaw: -0.6, pitch: 0.05)]

    /// A certified level's play and its snapshot at time 1 s.
    struct Case {
        let number: Int
        let play: NocturneGardenPlay
        let snapshot: Snapshot
    }

    /// The certified levels 1, 21, 41, 61 and 81 with their certified solution applied, and level 1's opening bed.
    static func cases() throws -> [Case] {
        var result: [Case] = []
        for number in [1, 21, 41, 61, 81] {
            let core: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: number)
            var play: NocturneGardenPlay = core.play
            let actions: [NocturneGardenAction] = try NocturneGardenExperienceCore.generated(number: number)
                .solution.actions
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
            result.append(Case(number: number, play: play, snapshot: Snapshot(play: play, levelNumber: number, time: 1)))
        }
        let opening: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: 1)
        result.append(Case(number: 1, play: opening.play,
                           snapshot: Snapshot(play: opening.play, levelNumber: 1, time: 1)))
        return result
    }

    // MARK: Independent camera

    /// The drawn camera's frame, read from its view matrix rows (right, up, −forward) and its field of view.
    struct Frame {
        let eye: SIMD3<Double>
        let right: SIMD3<Double>
        let up: SIMD3<Double>
        let forward: SIMD3<Double>
        let tanY: Double
        let tanX: Double
        let size: SIMD2<Double>

        init(_ snapshot: Snapshot, size: SIMD2<Double>, orbit: Orbit) {
            let camera: NocturneGardenCamera = Geometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
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
    }

    // MARK: Independent places (the clarified formulas)

    static func cell(_ s: Snapshot) -> Double { 2.0 / Double(s.width) }

    /// The lantern: (1.25, (1.15 − 0.25·(e − 1))·H·u, 0.3).
    static func lantern(_ s: Snapshot) -> SIMD3<Double> {
        SIMD3(1.25, (1.15 - 0.25 * Double(s.sun - 1)) * Double(s.height) * cell(s), 0.3)
    }

    /// Bloom `b`'s foot (the anchor cell's lower-left corner) in the plane.
    static func foot(_ s: Snapshot, _ b: Int) -> SIMD2<Double> {
        let bloom: NocturneGardenBloom = s.blooms[b]
        return SIMD2(-1 + Double(bloom.column) * cell(s), Double(bloom.row) * cell(s))
    }

    /// Bloom `b`'s head box: the bounds of foot + 0.35·size·u·outline.
    static func headBox(_ s: Snapshot, _ b: Int) -> (low: SIMD2<Double>, high: SIMD2<Double>) {
        let bloom: NocturneGardenBloom = s.blooms[b]
        let k: Double = 0.35 * Double(bloom.size) * cell(s)
        let f: SIMD2<Double> = foot(s, b)
        var low: SIMD2<Double> = SIMD2(1e9, 1e9)
        var high: SIMD2<Double> = SIMD2(-1e9, -1e9)
        for p in bloom.kind.outline {
            let q: SIMD2<Double> = f + SIMD2(Double(p.x), Double(p.y)) * k
            low = SIMD2(min(low.x, q.x), min(low.y, q.y))
            high = SIMD2(max(high.x, q.x), max(high.y, q.y))
        }
        return (low, high)
    }

    static func length(_ v: SIMD3<Double>) -> Double { (v * v).sum().squareRoot() }

    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { ((a - b) * (a - b)).sum().squareRoot() }

    /// The independent bed cell of the ray through `point` (nil when z = 0 is not met ahead) and whether the point on
    /// z = 0 lies within a rounding distance of a cell line.
    static func expectedCell(_ point: SIMD2<Double>, frame: Frame,
                             snapshot s: Snapshot) -> (cell: (column: Int, row: Int, inside: Bool)?, ambiguous: Bool) {
        let d: SIMD3<Double> = frame.ray(point)
        guard d.z < -1e-12 else { return (nil, d.z > -1e-6) }
        let t: Double = -frame.eye.z / d.z
        let p: SIMD3<Double> = frame.eye + d * t
        let fx: Double = (p.x + 1) / cell(s)
        let fy: Double = p.y / cell(s)
        let ambiguous: Bool = abs(fx - fx.rounded()) < 1e-7 || abs(fy - fy.rounded()) < 1e-7
        let column: Int = Int(fx.rounded(.down))
        let row: Int = Int(fy.rounded(.down))
        return ((column, row, column >= 0 && column < s.width && row >= 0 && row < s.height), ambiguous)
    }

    /// The independent pick, whether it lies within a rounding distance of a decision boundary, and how it was made.
    static func expected(_ point: SIMD2<Double>, frame: Frame,
                         snapshot s: Snapshot) -> (pick: NocturneGardenPick, ambiguous: Bool, how: String) {
        var ambiguous: Bool = false
        if let l = frame.project(lantern(s)) {
            let d: Double = distance(l, point)
            if abs(d - 22) < 1e-6 { ambiguous = true }
            if d <= 22 { return (.lantern, ambiguous, "lantern") }
        }
        let direction: SIMD3<Double> = frame.ray(point)
        var hit: SIMD2<Double>? = nil
        if abs(direction.z) > 1e-12 {
            let t: Double = (0.37 - frame.eye.z) / direction.z
            if t > 0 {
                let p: SIMD3<Double> = frame.eye + direction * t
                hit = SIMD2(p.x, p.y)
            }
        }
        var boxBest: Int = -1
        var boxDistance: Double = .infinity
        var nearBest: Int = -1
        var nearDistance: Double = .infinity
        for b in s.blooms.indices {
            let box: (low: SIMD2<Double>, high: SIMD2<Double>) = headBox(s, b)
            let centre: SIMD3<Double> = SIMD3((box.low.x + box.high.x) / 2, (box.low.y + box.high.y) / 2, 0.37)
            let eyeDistance: Double = length(centre - frame.eye)
            if let h = hit {
                let margin: Double = min(h.x - box.low.x, box.high.x - h.x, h.y - box.low.y, box.high.y - h.y)
                if abs(margin) < 1e-9 { ambiguous = true }
                if margin >= 0 {
                    if boxBest >= 0 && abs(eyeDistance - boxDistance) < 1e-9 { ambiguous = true }
                    if eyeDistance < boxDistance {
                        boxDistance = eyeDistance
                        boxBest = b
                    }
                }
            }
            let f: SIMD2<Double> = foot(s, b)
            var within: Bool = false
            for anchor in [SIMD3(f.x, f.y, 0.37), centre] {
                guard let p = frame.project(anchor) else { continue }
                let d: Double = distance(p, point)
                if abs(d - 22) < 1e-6 { ambiguous = true }
                if d <= 22 { within = true }
            }
            if within {
                if nearBest >= 0 && abs(eyeDistance - nearDistance) < 1e-9 { ambiguous = true }
                if eyeDistance < nearDistance {
                    nearDistance = eyeDistance
                    nearBest = b
                }
            }
        }
        if boxBest >= 0 { return (.bloom(boxBest), ambiguous, "box") }
        if nearBest >= 0 { return (.bloom(nearBest), ambiguous, "near") }
        let c: (cell: (column: Int, row: Int, inside: Bool)?, ambiguous: Bool) = expectedCell(point, frame: frame,
                                                                                              snapshot: s)
        if c.ambiguous { ambiguous = true }
        guard let found = c.cell else { return (.empty, ambiguous, "empty") }
        if !found.inside { return (.outside, ambiguous, "outside") }
        return (.cell(found.row * s.width + found.column), ambiguous, "cell")
    }

    /// A seeded point of class `kind`: anywhere, near the lantern, near a bloom's foot or head, near a bed cell, near
    /// the bed's border.
    static func point(_ random: inout SeededRandom, kind: Int, frame: Frame, snapshot s: Snapshot) -> SIMD2<Double> {
        var anchor: SIMD2<Double>? = nil
        let spread: Double = 0.08 * min(frame.size.x, frame.size.y)
        if kind == 1 { anchor = frame.project(lantern(s)) }
        if kind == 2 && !s.blooms.isEmpty {
            let b: Int = random.int(0...(s.blooms.count - 1))
            let box: (low: SIMD2<Double>, high: SIMD2<Double>) = headBox(s, b)
            let x: Double = random.range(box.low.x...box.high.x)
            let y: Double = random.range(box.low.y...box.high.y)
            anchor = frame.project(SIMD3(x, y, 0.37))
        }
        if kind == 3 {
            let c: Int = random.int(0...(s.width * s.height - 1))
            anchor = frame.project(SIMD3(-1 + (Double(c % s.width) + 0.5) * cell(s),
                                         (Double(c / s.width) + 0.5) * cell(s), 0))
        }
        if kind == 4 {
            let x: Double = random.int(0...1) == 0 ? -1 : 1
            anchor = frame.project(SIMD3(x, random.range(0...(Double(s.height) * cell(s))), 0))
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
        var random: SeededRandom = SeededRandom(seed: 2_384)
        var counts: [String: Int] = [:]
        var ambiguous: Int = 0
        for k in 0..<500 {
            let c: Case = cases[k % cases.count]
            let size: SIMD2<Double> = Self.sizes[(k / cases.count) % Self.sizes.count]
            let orbit: Orbit = Self.orbits[(k / (cases.count * Self.sizes.count)) % Self.orbits.count]
            let frame: Frame = Frame(c.snapshot, size: size, orbit: orbit)
            let p: SIMD2<Double> = Self.point(&random, kind: random.int(0...4), frame: frame, snapshot: c.snapshot)
            let expected: (pick: NocturneGardenPick, ambiguous: Bool, how: String) =
                Self.expected(p, frame: frame, snapshot: c.snapshot)
            if expected.ambiguous {
                ambiguous += 1
                continue
            }
            let pick: NocturneGardenPick = Picker.pick(p, size: size, snapshot: c.snapshot, orbit: orbit)
            #expect(pick == expected.pick, "level \(c.number) size \(size) orbit \(orbit) point \(p)")
            counts[expected.how, default: 0] += 1
            let cell: (cell: (column: Int, row: Int, inside: Bool)?, ambiguous: Bool) =
                Self.expectedCell(p, frame: frame, snapshot: c.snapshot)
            guard !cell.ambiguous else { continue }
            let got: (column: Int, row: Int, inside: Bool)? = Picker.bedCell(p, size: size, snapshot: c.snapshot,
                                                                             orbit: orbit)
            #expect(got?.column == cell.cell?.column && got?.row == cell.cell?.row
                && got?.inside == cell.cell?.inside, "bed cell level \(c.number) point \(p)")
        }
        #expect(ambiguous <= 5)
        for key in ["lantern", "box", "near", "cell", "outside"] {
            #expect((counts[key] ?? 0) > 0, "no \(key) pick among \(counts)")
        }
    }

    @Test func theLanternHasAMinimumTargetOfTwentyTwoPoints() throws {
        #expect(Picker.minimumTarget == 22 && Picker.pointsPerSunStep == 48)
        var checked: Int = 0
        for c in try Self.cases() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let frame: Frame = Frame(c.snapshot, size: size, orbit: orbit)
                    guard let centre = frame.project(Self.lantern(c.snapshot)) else { continue }
                    for k in 0..<16 {
                        let angle: Double = 2 * Double.pi * Double(k) / 16
                        for distance in [21.0, 23.0] {
                            let p: SIMD2<Double> = centre + SIMD2(cos(angle), sin(angle)) * distance
                            guard p.x > 0, p.y > 0, p.x < size.x, p.y < size.y else { continue }
                            let pick: NocturneGardenPick = Picker.pick(p, size: size, snapshot: c.snapshot,
                                                                       orbit: orbit)
                            if distance < 22 {
                                #expect(pick == .lantern)
                            } else {
                                #expect(pick != .lantern)
                            }
                            checked += 1
                        }
                    }
                }
            }
        }
        #expect(checked > 100)
    }

    @Test func bloomFeetHaveAMinimumTargetOfTwentyTwoPoints() throws {
        var checked: Int = 0
        var outside: Int = 0
        for c in try Self.cases() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let frame: Frame = Frame(c.snapshot, size: size, orbit: orbit)
                    for b in c.snapshot.blooms.indices {
                        let f: SIMD2<Double> = Self.foot(c.snapshot, b)
                        guard let centre = frame.project(SIMD3(f.x, f.y, 0.37)) else { continue }
                        for k in 0..<12 {
                            let angle: Double = 2 * Double.pi * Double(k) / 12
                            for distance in [21.0, 23.0] {
                                let p: SIMD2<Double> = centre + SIMD2(cos(angle), sin(angle)) * distance
                                guard p.x > 0, p.y > 0, p.x < size.x, p.y < size.y else { continue }
                                let expected: (pick: NocturneGardenPick, ambiguous: Bool, how: String) =
                                    Self.expected(p, frame: frame, snapshot: c.snapshot)
                                guard !expected.ambiguous, expected.pick != .lantern else { continue }
                                let pick: NocturneGardenPick = Picker.pick(p, size: size, snapshot: c.snapshot,
                                                                           orbit: orbit)
                                #expect(pick == expected.pick)
                                if distance < 22 {
                                    if case .bloom = pick {} else { Issue.record("foot target missed: \(pick)") }
                                    checked += 1
                                } else if case .bloom = pick {} else {
                                    outside += 1
                                }
                            }
                        }
                    }
                }
            }
        }
        #expect(checked > 50 && outside > 0)
    }

    @Test func overlappingBloomsGoToTheNearestToTheEyeThenTheLowerIndex() throws {
        let level: NocturneGardenLevel = try NocturneGardenLevel(
            id: "picker-overlap", seed: 1, difficulty: 1, width: 16, height: 12, target: [3], forbidden: [],
            supply: [.tulip: 3], sizes: [1, 2], elevations: [2], sun: 2, budget: 6, required: .whole,
            leakAllowance: 0)
        var play: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(of: level)
        try play.apply(.plant(.tulip, 5, 4, 2), expecting: play.fingerprint)
        try play.apply(.plant(.tulip, 5, 4, 1), expecting: play.fingerprint)
        let s: Snapshot = Snapshot(play: play, levelNumber: 1, time: 0)
        let size: SIMD2<Double> = SIMD2(390, 844)
        let frame: Frame = Frame(s, size: size, orbit: .authored)
        // The smaller head's centre lies in both head boxes (they share the foot): the head centre nearest to the eye
        // wins.
        let small: Int = s.blooms[0].size == 1 ? 0 : 1
        let box: (low: SIMD2<Double>, high: SIMD2<Double>) = Self.headBox(s, small)
        let p: SIMD2<Double> = try #require(frame.project(SIMD3((box.low.x + box.high.x) / 2,
                                                                (box.low.y + box.high.y) / 2, 0.37)))
        let expected: (pick: NocturneGardenPick, ambiguous: Bool, how: String) = Self.expected(p, frame: frame,
                                                                                              snapshot: s)
        #expect(!expected.ambiguous && expected.how == "box")
        #expect(Picker.pick(p, size: size, snapshot: s, orbit: .authored) == expected.pick)
        #expect(Picker.nearest([3, 1, 2], to: 1.5) == 1)
        #expect(Picker.nearest([2, 4], to: 3) == 2)
        #expect(Picker.nearest([], to: 3) == nil)
    }

    // MARK: Sun steps and pinch sizes

    /// The independent sun step: steps = sign(drag) · floor(|drag| / 48 + 0.5); the allowed value nearest e + steps,
    /// ties to the lower.
    static func expectedSun(_ e: Int, _ drag: Double, _ allowed: [Int]) -> Int {
        let magnitude: Double = (abs(drag) / 48 + 0.5).rounded(.down)
        let steps: Int = drag < 0 ? -Int(magnitude) : Int(magnitude)
        let target: Int = e + steps
        var best: Int = e
        var bestDistance: Int = Int.max
        for value in 1...4 where allowed.contains(value) {
            let d: Int = abs(value - target)
            if d < bestDistance {
                bestDistance = d
                best = value
            }
        }
        return best
    }

    /// The independent pinch size: the allowed size nearest size·scale, ties to the smaller.
    static func expectedPinch(_ size: Int, _ scale: Double, _ allowed: [Int]) -> Int {
        var best: Int = size
        var bestDistance: Double = .infinity
        for value in 1...3 where allowed.contains(value) {
            let d: Double = abs(Double(value) - Double(size) * scale)
            if d < bestDistance {
                bestDistance = d
                best = value
            }
        }
        return best
    }

    @Test func fiveHundredSeededSunStepsAndPinchSizesMatchTheIndependentOnes() throws {
        let cases: [Case] = try Self.cases()
        var random: SeededRandom = SeededRandom(seed: 2_384)
        var moved: Int = 0
        for k in 0..<500 {
            let c: Case = cases[k % cases.count]
            var elevations: [Int] = Array(c.play.level.elevations).sorted()
            var sizes: [Int] = Array(c.play.level.sizes).sorted()
            if k % 3 == 1 {
                elevations = []
                for value in 1...4 where random.int(0...1) == 0 { elevations.append(value) }
                sizes = []
                for value in 1...3 where random.int(0...1) == 0 { sizes.append(value) }
            }
            // Every fifth drag lies exactly on a half step, the rest anywhere in ±250 points.
            var drag: Double = random.range(-250...250)
            if k % 5 == 0 { drag = (Double(random.int(-5...4)) + 0.5) * 48 }
            let e: Int = random.int(1...4)
            let sun: Int = Picker.sunElevation(from: e, drag: drag, allowed: elevations)
            #expect(sun == Self.expectedSun(e, drag, elevations), "e \(e) drag \(drag) allowed \(elevations)")
            if sun != e { moved += 1 }
            let size: Int = random.int(1...3)
            var scale: Double = random.range(0.2...4)
            if k % 7 == 0 { scale = Double(random.int(1...5)) / Double(2 * size) }
            #expect(Picker.pinchSize(from: size, scale: scale, allowed: sizes)
                == Self.expectedPinch(size, scale, sizes), "size \(size) scale \(scale) allowed \(sizes)")
        }
        #expect(moved > 100)
        // Down is a lower sun (a larger elevation); one step per 48 points; halves away from zero.
        #expect(Picker.sunElevation(from: 2, drag: 47, allowed: [1, 2, 3, 4]) == 3)
        #expect(Picker.sunElevation(from: 2, drag: 23.9, allowed: [1, 2, 3, 4]) == 2)
        #expect(Picker.sunElevation(from: 2, drag: 24, allowed: [1, 2, 3, 4]) == 3)
        #expect(Picker.sunElevation(from: 2, drag: -24, allowed: [1, 2, 3, 4]) == 1)
        #expect(Picker.sunElevation(from: 2, drag: 96, allowed: [1, 2]) == 2)
        #expect(Picker.sunElevation(from: 1, drag: 96, allowed: [2, 4]) == 2)
        #expect(Picker.sunElevation(from: 3, drag: .nan, allowed: [1, 2]) == 3)
        #expect(Picker.sunElevation(from: 3, drag: 1e300, allowed: [1, 2]) == 2)
        #expect(Picker.sunElevation(from: 3, drag: 0, allowed: []) == 3)
        #expect(Picker.pinchSize(from: 2, scale: 1.25, allowed: [1, 2, 3]) == 2)
        #expect(Picker.pinchSize(from: 2, scale: 0.75, allowed: [1, 2, 3]) == 1)
        #expect(Picker.pinchSize(from: 2, scale: 1.5, allowed: [1, 2, 3]) == 3)
        #expect(Picker.pinchSize(from: 1, scale: 2, allowed: [1, 3]) == 1)
        #expect(Picker.pinchSize(from: 2, scale: .infinity, allowed: [1, 3]) == 2)
        #expect(Picker.pinchSize(from: 2, scale: -1, allowed: [1, 3]) == 2)
        #expect(Picker.pinchSize(from: 2, scale: 3, allowed: []) == 2)
    }

    // MARK: Unusable input

    @Test func nonFiniteOrUnusableInputPicksNothing() throws {
        let c: Case = try Self.cases()[0]
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: NocturneGardenCamera = Geometry.camera(c.snapshot, aspect: size.x / size.y, orbit: .authored)
        let centre: SIMD2<Double> = SIMD2(195, 422)
        let bad: [SIMD2<Double>] = [SIMD2(.nan, 422), SIMD2(195, .infinity), SIMD2(-.infinity, .nan),
                                    SIMD2(-5, 422), SIMD2(195, 900)]
        for point in bad {
            #expect(Picker.pick(point, size: size, snapshot: c.snapshot, orbit: .authored) == .empty)
            #expect(Picker.ray(point, size: size, camera: camera) == nil)
            #expect(Picker.bedCell(point, size: size, snapshot: c.snapshot, orbit: .authored) == nil)
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, -1), SIMD2(.nan, 844), SIMD2(390, .infinity)]
        for badSize in sizes {
            #expect(Picker.pick(centre, size: badSize, snapshot: c.snapshot, orbit: .authored) == .empty)
            #expect(Picker.ray(centre, size: badSize, camera: camera) == nil)
            #expect(Picker.bedCell(centre, size: badSize, snapshot: c.snapshot, orbit: .authored) == nil)
        }
        // A non-finite orbit is the authored one.
        let odd: Orbit = Orbit(yaw: .nan, pitch: .infinity)
        #expect(Picker.pick(centre, size: size, snapshot: c.snapshot, orbit: odd)
            == Picker.pick(centre, size: size, snapshot: c.snapshot, orbit: .authored))
        // The ray of the view centre is unit length and passes through the bed's centre.
        if let r = Picker.ray(centre, size: size, camera: camera) {
            #expect(abs(Geometry.length(r.direction) - 1) < 1e-12)
            let target: SIMD3<Double> = Geometry.bedCentre(c.snapshot)
            let t: Double = Geometry.dot(target - r.origin, r.direction)
            #expect(Geometry.length(r.origin + r.direction * t - target) < 1e-9)
        } else {
            Issue.record("no ray through the view centre")
        }
        // A very wide view at the largest yaw: a ray at a side edge runs away from z = 0 (or meets it nearer than the
        // near plane, where nothing is drawn), so nothing is under it.
        let wide: SIMD2<Double> = SIMD2(2_000, 200)
        let turned: Orbit = Orbit(yaw: Orbit.yawLimit, pitch: 0)
        var away: Int = 0
        for x in [1.0, 1_999.0] {
            let p: SIMD2<Double> = SIMD2(x, 100)
            guard Picker.bedCell(p, size: wide, snapshot: c.snapshot, orbit: turned) == nil else { continue }
            away += 1
            #expect(Picker.pick(p, size: wide, snapshot: c.snapshot, orbit: turned) == .empty)
        }
        #expect(away >= 1)
    }
}
