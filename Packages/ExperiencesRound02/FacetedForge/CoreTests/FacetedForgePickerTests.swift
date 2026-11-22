// FacetedForgePickerTests — feature 374 (R02-G08-04) T-R02G0804-002 (FR-R02G0804-001, 002, 003, 005;
// SC-R02G0804-001; clarifications Q1–Q3). The analytic picker, the rim tilt and the depth steps against an independent
// computation written here: its own camera ray and projector (built from the drawn camera's eye, view axes and field of
// view, not `ScreenProjection`), its own rim distance, its own fan-triangle test for the preview and the piece faces,
// its own centre fallback, its own direction snap, the kernel preview centre from the kernel's own cross-section and
// its own projected normal. 500 seeded cases (seed 2_374) over the certified levels 1, 21, 41, 61 and 81 after their
// first certified cut, three view sizes and three orbits; the minimum target of the rim and of the piece centres; the
// ties to the lower index and the smaller depth; a zero tilt keeps the choice; the depth steps' sign and rounding; and
// non-finite input. Plain loops and explicit types (CI type-check rule); well under 10 s.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import FacetedForgeCore

@Suite struct FacetedForgePickerTests {
    typealias Geometry = FacetedForgeSceneGeometry
    typealias Snapshot = FacetedForgeSceneSnapshot
    typealias Picker = FacetedForgePicker
    typealias Orbit = FacetedForgeOrbit
    typealias Choice = FacetedForgePreviewChoice

    /// The view sizes in points: phone portrait, tablet landscape and a tiny view where the piece centres matter.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1_180, 820), SIMD2(120, 90)]

    /// The authored orbit and two orbits inside the bounds.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.5, pitch: 0.3), Orbit(yaw: -0.6, pitch: 1.0)]

    /// A certified play after its first certified cut and its snapshot with the initial preview choice at time 1 s.
    struct Case {
        let number: Int
        let play: FacetedForgePlay
        let snapshot: Snapshot
    }

    /// The certified levels 1, 21, 41, 61 and 81 after their first certified cut.
    static func cases() throws -> [Case] {
        var result: [Case] = []
        for number in [1, 21, 41, 61, 81] {
            let core: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: number)
            var play: FacetedForgePlay = core.play
            let first: FacetedForgeAction = try #require(FacetedForgeExperienceCore.certifiedActions(number).first)
            try play.apply(first, expecting: play.fingerprint)
            let snapshot: Snapshot = Snapshot(play: play, levelNumber: number, choice: Choice.initial(play), time: 1)
            result.append(Case(number: number, play: play, snapshot: snapshot))
        }
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
            let camera: FacetedForgeCamera = Geometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
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

    // MARK: Independent pick

    /// The distance from `p` to segment a…b.
    static func segment(_ p: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let ab: SIMD2<Double> = b - a
        let l2: Double = (ab * ab).sum()
        var t: Double = 0
        if l2 > 0 { t = ((p - a) * ab).sum() / l2 }
        if t < 0 { t = 0 }
        if t > 1 { t = 1 }
        let d: SIMD2<Double> = a + ab * t - p
        return (d * d).sum().squareRoot()
    }

    /// The ray parameter where the ray from `eye` along `direction` meets the polygon (fan triangles, Möller–Trumbore)
    /// and the smallest barycentric margin of that hit (negative: outside); nil when no fan triangle is met ahead.
    static func fanHit(eye: SIMD3<Double>, direction: SIMD3<Double>,
                       polygon: [SIMD3<Double>]) -> (t: Double, margin: Double)? {
        guard polygon.count >= 3 else { return nil }
        var best: (t: Double, margin: Double)?
        for k in 1..<(polygon.count - 1) {
            let a: SIMD3<Double> = polygon[0]
            let e1: SIMD3<Double> = polygon[k] - a
            let e2: SIMD3<Double> = polygon[k + 1] - a
            let p: SIMD3<Double> = Geometry.cross(direction, e2)
            let det: Double = (e1 * p).sum()
            if abs(det) < 1e-18 { continue }
            let s: SIMD3<Double> = eye - a
            let u: Double = (s * p).sum() / det
            let q: SIMD3<Double> = Geometry.cross(s, e1)
            let v: Double = (direction * q).sum() / det
            let t: Double = (e2 * q).sum() / det
            let margin: Double = min(u, v, 1 - u - v)
            if t > 0 && margin >= -1e-7 {
                if margin > (best?.margin ?? -Double.infinity) { best = (t, margin) }
            }
        }
        return best
    }

    /// The independent pick and whether it lies within a rounding distance of a decision boundary.
    static func expected(_ point: SIMD2<Double>, frame: Frame, snapshot: Snapshot,
                         reduceMotion: Bool) -> (pick: FacetedForgePick, ambiguous: Bool, byCentre: Bool) {
        var ambiguous: Bool = false
        let direction: SIMD3<Double> = frame.ray(point)
        let shift: SIMD3<Double> = Geometry.offset(piece: snapshot.choice.piece, snapshot, reduceMotion: reduceMotion)
        var preview: [SIMD3<Double>] = []
        for corner in snapshot.preview { preview.append(corner + shift) }
        if preview.count >= 3 {
            var outline: [SIMD2<Double>] = []
            for corner in preview { if let p = frame.project(corner) { outline.append(p) } }
            var rim: Double = .infinity
            for k in 0..<outline.count {
                rim = min(rim, segment(point, outline[k], outline[(k + 1) % outline.count]))
            }
            if abs(rim - Picker.minimumTarget) < 1e-6 { ambiguous = true }
            if rim <= Picker.minimumTarget { return (.rim, ambiguous, false) }
            if let hit = fanHit(eye: frame.eye, direction: direction, polygon: preview) {
                if hit.margin < 1e-7 { ambiguous = true }
                return (.plane, ambiguous, false)
            }
        }
        var nearest: Double = .infinity
        var owner: Int = -1
        for (index, piece) in snapshot.pieces.enumerated() {
            let offset: SIMD3<Double> = Geometry.offset(piece: index, snapshot, reduceMotion: reduceMotion)
            for face in piece.faces {
                var polygon: [SIMD3<Double>] = []
                for i in face { polygon.append(piece.corners[i] + offset) }
                guard let hit = fanHit(eye: frame.eye, direction: direction, polygon: polygon) else { continue }
                if hit.margin < 1e-7 { ambiguous = true }
                if owner != index && abs(hit.t - nearest) < 1e-9 { ambiguous = true }
                if hit.t < nearest {
                    nearest = hit.t
                    owner = index
                }
            }
        }
        if owner >= 0 { return (.piece(owner), ambiguous, false) }
        var best: Double = .infinity
        var chosen: Int = -1
        for index in snapshot.pieces.indices {
            let centre: SIMD3<Double> = snapshot.pieces[index].centroid
                + Geometry.offset(piece: index, snapshot, reduceMotion: reduceMotion)
            guard let p = frame.project(centre) else { continue }
            let d: Double = ((p - point) * (p - point)).sum().squareRoot()
            if abs(d - Picker.minimumTarget) < 1e-6 || abs(d - best) < 1e-9 { ambiguous = true }
            if d <= Picker.minimumTarget && d < best {
                best = d
                chosen = index
            }
        }
        if chosen >= 0 { return (.piece(chosen), ambiguous, true) }
        return (.empty, ambiguous, false)
    }

    /// A seeded point of class `kind`: anywhere, near the preview centre, near a preview corner, near a piece centre.
    static func point(_ random: inout SeededRandom, kind: Int, frame: Frame, snapshot: Snapshot) -> SIMD2<Double> {
        var anchor: SIMD2<Double>? = nil
        let spread: Double = 0.12 * min(frame.size.x, frame.size.y)
        if kind == 1, let c = Geometry.previewCentre(snapshot) { anchor = frame.project(c) }
        if kind == 2, !snapshot.preview.isEmpty {
            let corner: SIMD3<Double> = snapshot.preview[random.int(0...(snapshot.preview.count - 1))]
            anchor = frame.project(corner + Geometry.offset(piece: snapshot.choice.piece, snapshot))
        }
        if kind == 3 {
            anchor = frame.project(Geometry.pieceCentre(random.int(0...(snapshot.pieces.count - 1)), snapshot))
        }
        var p: SIMD2<Double> = SIMD2(random.range(1...(frame.size.x - 1)), random.range(1...(frame.size.y - 1)))
        if let anchor {
            p = anchor + SIMD2(random.range(-spread...spread), random.range(-spread...spread))
        }
        return SIMD2(min(max(p.x, 1), frame.size.x - 1), min(max(p.y, 1), frame.size.y - 1))
    }

    @Test func fiveHundredSeededPicksMatchTheIndependentPick() throws {
        let cases: [Case] = try Self.cases()
        var random: SeededRandom = SeededRandom(seed: 2_374)
        var counts: [String: Int] = [:]
        var ambiguous: Int = 0
        for k in 0..<500 {
            let c: Case = cases[k % cases.count]
            let size: SIMD2<Double> = Self.sizes[(k / cases.count) % Self.sizes.count]
            let orbit: Orbit = Self.orbits[(k / (cases.count * Self.sizes.count)) % Self.orbits.count]
            let frame: Frame = Frame(c.snapshot, size: size, orbit: orbit)
            let reduceMotion: Bool = k % 2 == 1
            let p: SIMD2<Double> = Self.point(&random, kind: random.int(0...3), frame: frame, snapshot: c.snapshot)
            let expected: (pick: FacetedForgePick, ambiguous: Bool, byCentre: Bool) =
                Self.expected(p, frame: frame, snapshot: c.snapshot, reduceMotion: reduceMotion)
            if expected.ambiguous {
                ambiguous += 1
                continue
            }
            let pick: FacetedForgePick = Picker.pick(p, size: size, snapshot: c.snapshot, orbit: orbit,
                                                     reduceMotion: reduceMotion)
            #expect(pick == expected.pick, "level \(c.number) size \(size) orbit \(orbit) point \(p)")
            var key: String = "empty"
            switch expected.pick {
            case .rim: key = "rim"
            case .plane: key = "plane"
            case .piece: key = expected.byCentre ? "centre" : "piece"
            case .empty: key = "empty"
            }
            counts[key, default: 0] += 1
        }
        #expect(ambiguous <= 5)
        #expect((counts["rim"] ?? 0) > 0 && (counts["plane"] ?? 0) > 0)
        #expect((counts["piece"] ?? 0) > 0 && (counts["empty"] ?? 0) > 0)
    }

    // MARK: Tilt

    /// The independent tilt of `snapshot`'s choice by `drag`, and whether a rounding tie made it ambiguous.
    static func expectedTilt(_ c: Case, drag: SIMD2<Double>, frame: Frame,
                             halves: inout Int) -> (choice: Choice, ambiguous: Bool) {
        let choice: Choice = c.snapshot.choice
        let d0: FacetedForgeDirection = FacetedForgeDirection.all[choice.direction]
        var n0: SIMD3<Double> = SIMD3(Double(d0.x), Double(d0.y), Double(d0.z))
        n0 = n0 / (n0 * n0).sum().squareRoot()
        var v: SIMD3<Double> = n0 + (frame.right * drag.x - frame.up * drag.y) * (2 / min(frame.size.x, frame.size.y))
        v = v / (v * v).sum().squareRoot()
        var best: Int = 0
        var bestDot: Double = -1
        var second: Double = -1
        for index in 0..<13 {
            let d: FacetedForgeDirection = FacetedForgeDirection.all[index]
            let u: SIMD3<Double> = SIMD3(Double(d.x), Double(d.y), Double(d.z))
            let value: Double = abs((u * v).sum()) / (u * u).sum().squareRoot()
            if value > bestDot {
                second = bestDot
                bestDot = value
                best = index
            } else if value > second {
                second = value
            }
        }
        var ambiguous: Bool = bestDot - second < 1e-12
        let crossing: [Int] = FacetedForgeSolver.crossingDepths(c.play.pieces[choice.piece], direction: best)
        guard !crossing.isEmpty else {
            return (Choice(piece: choice.piece, direction: best, depth: choice.depth), ambiguous)
        }
        var depth: Int = crossing[crossing.count / 2]
        let section: [SIMD3<Double>] = Snapshot.section(c.play.pieces[choice.piece], direction: choice.direction,
                                                        depth: choice.depth)
        if !section.isEmpty {
            var centre: SIMD3<Double> = .zero
            for p in section { centre += p }
            centre = centre / Double(section.count)
            let d: FacetedForgeDirection = FacetedForgeDirection.all[best]
            let value: Double = Double(d.x) * centre.x + Double(d.y) * centre.y + Double(d.z) * centre.z
            // The kernel centre is rational with small denominators: an exact half is a half on both sides, and
            // rounds away from zero; only a value within a hair of a snapping boundary would be ambiguous.
            let scaled: Double = value * 1e6
            if abs(abs(scaled - scaled.rounded(.down)) - 0.5) < 1e-3 { ambiguous = true }
            let snapped: Double = scaled.rounded() / 1e6
            if snapped - snapped.rounded(.down) == 0.5 { halves += 1 }
            let target: Int = Int(snapped.rounded())
            var bestDistance: Int = Int.max
            for candidate in crossing where abs(candidate - target) < bestDistance {
                bestDistance = abs(candidate - target)
                depth = candidate
            }
        }
        return (Choice(piece: choice.piece, direction: best, depth: depth), ambiguous)
    }

    @Test func fiveHundredSeededTiltsMatchTheIndependentTilt() throws {
        let cases: [Case] = try Self.cases()
        var random: SeededRandom = SeededRandom(seed: 2_374)
        var ambiguous: Int = 0
        var changed: Int = 0
        var halves: Int = 0
        for k in 0..<500 {
            let c: Case = cases[k % cases.count]
            let size: SIMD2<Double> = Self.sizes[(k / cases.count) % Self.sizes.count]
            let orbit: Orbit = Self.orbits[(k / (cases.count * Self.sizes.count)) % Self.orbits.count]
            let frame: Frame = Frame(c.snapshot, size: size, orbit: orbit)
            let reach: Double = 0.6 * min(size.x, size.y)
            let drag: SIMD2<Double> = SIMD2(random.range(-reach...reach), random.range(-reach...reach))
            let expected: (choice: Choice, ambiguous: Bool) =
                Self.expectedTilt(c, drag: drag, frame: frame, halves: &halves)
            if expected.ambiguous {
                ambiguous += 1
                continue
            }
            let tilted: Choice = Picker.tilt(c.snapshot.choice, drag: drag, size: size, snapshot: c.snapshot,
                                             play: c.play, orbit: orbit)
            #expect(tilted == expected.choice, "level \(c.number) size \(size) orbit \(orbit) drag \(drag)")
            if tilted.direction != c.snapshot.choice.direction { changed += 1 }
        }
        #expect(ambiguous <= 5)
        #expect(changed > 100)
        // Exact halves of round(n · c) occur and are decided the same way (away from zero) by both computations.
        #expect(halves > 0)
    }

    @Test func aZeroTiltKeepsTheChoice() throws {
        for c in try Self.cases() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let tilted: Choice = Picker.tilt(c.snapshot.choice, drag: .zero, size: size, snapshot: c.snapshot,
                                                     play: c.play, orbit: orbit)
                    #expect(tilted == c.snapshot.choice)
                }
            }
        }
    }

    @Test func aRightDragTiltsTowardsTheCameraRight() throws {
        let c: Case = try Self.cases()[0]
        let size: SIMD2<Double> = SIMD2(390, 844)
        let start: Choice = Choice(piece: c.snapshot.choice.piece, direction: 2, depth: 0).clamped(to: c.play)
        let snapshot: Snapshot = Snapshot(play: c.play, levelNumber: c.number, choice: start, time: 1)
        // At the authored orbit the camera's right is +x: a long right drag of the z-plane snaps it to x.
        let right: Choice = Picker.tilt(start, drag: SIMD2(2_000, 0), size: size, snapshot: snapshot, play: c.play,
                                        orbit: .authored)
        #expect(right.direction == 0)
        // An upward drag (negative y) tilts the z normal towards the camera's up (+y, −z): direction y, or y−z.
        let up: Choice = Picker.tilt(start, drag: SIMD2(0, -2_000), size: size, snapshot: snapshot, play: c.play,
                                     orbit: .authored)
        #expect(up.direction == 1 || up.direction == 8)
    }

    @Test func aTiltWithoutAPreviewTakesTheMiddleCrossingDepth() throws {
        let c: Case = try Self.cases()[1]
        let choice: Choice = Choice(piece: 0, direction: 0, depth: 24)
        let snapshot: Snapshot = Snapshot(play: c.play, levelNumber: c.number, choice: choice, time: 1)
        try #require(snapshot.preview.isEmpty)
        let size: SIMD2<Double> = SIMD2(390, 844)
        let tilted: Choice = Picker.tilt(choice, drag: SIMD2(0, 300), size: size, snapshot: snapshot, play: c.play,
                                         orbit: .authored)
        let crossing: [Int] = FacetedForgeSolver.crossingDepths(c.play.pieces[0], direction: tilted.direction)
        if crossing.isEmpty {
            #expect(tilted.depth == 24)
        } else {
            #expect(tilted.depth == crossing[crossing.count / 2])
        }
        #expect(Picker.depthSteps(drag: SIMD2(100, 100), size: size, snapshot: snapshot, orbit: .authored,
                                  reduceMotion: false) == 0)
        // An unknown piece or a non-finite drag keeps the choice.
        let unknown: Choice = Choice(piece: 99, direction: 3, depth: 1)
        #expect(Picker.tilt(unknown, drag: SIMD2(50, 0), size: size, snapshot: snapshot, play: c.play,
                            orbit: .authored) == unknown)
        #expect(Picker.tilt(choice, drag: SIMD2(.nan, 0), size: size, snapshot: snapshot, play: c.play,
                            orbit: .authored) == choice)
    }

    // MARK: Depth steps

    /// The unit screen direction (points, y down) of +n at the opened preview centre, by the independent projector.
    static func normalOnScreen(_ snapshot: Snapshot, frame: Frame, reduceMotion: Bool) -> SIMD2<Double>? {
        guard !snapshot.preview.isEmpty else { return nil }
        var centre: SIMD3<Double> = .zero
        for p in snapshot.preview { centre += p }
        centre = centre / Double(snapshot.preview.count)
            + Geometry.offset(piece: snapshot.choice.piece, snapshot, reduceMotion: reduceMotion)
        let d: FacetedForgeDirection = FacetedForgeDirection.all[snapshot.choice.direction]
        var n: SIMD3<Double> = SIMD3(Double(d.x), Double(d.y), Double(d.z))
        n = n / (n * n).sum().squareRoot()
        guard let a = frame.project(centre), let b = frame.project(centre + n * 0.1) else { return nil }
        let u: SIMD2<Double> = b - a
        let l: Double = (u * u).sum().squareRoot()
        return l > 1e-9 ? u / l : nil
    }

    @Test func fiveHundredSeededDepthStepsMatchTheIndependentStep() throws {
        let cases: [Case] = try Self.cases()
        var random: SeededRandom = SeededRandom(seed: 2_374)
        var ambiguous: Int = 0
        var nonZero: Int = 0
        for k in 0..<500 {
            let c: Case = cases[k % cases.count]
            let size: SIMD2<Double> = Self.sizes[(k / cases.count) % Self.sizes.count]
            let orbit: Orbit = Self.orbits[(k / (cases.count * Self.sizes.count)) % Self.orbits.count]
            let frame: Frame = Frame(c.snapshot, size: size, orbit: orbit)
            let reduceMotion: Bool = k % 2 == 0
            let drag: SIMD2<Double> = SIMD2(random.range(-200...200), random.range(-200...200))
            let u: SIMD2<Double> = try #require(Self.normalOnScreen(c.snapshot, frame: frame,
                                                                    reduceMotion: reduceMotion))
            let steps: Double = (drag * u).sum() / 24
            if abs(abs(steps - steps.rounded(.down)) - 0.5) < 1e-9 {
                ambiguous += 1
                continue
            }
            let expected: Int = Int(steps.rounded())
            let actual: Int = Picker.depthSteps(drag: drag, size: size, snapshot: c.snapshot, orbit: orbit,
                                                reduceMotion: reduceMotion)
            #expect(actual == expected, "level \(c.number) size \(size) orbit \(orbit) drag \(drag)")
            if actual != 0 { nonZero += 1 }
        }
        #expect(ambiguous <= 5)
        #expect(nonZero > 100)
    }

    @Test func depthStepsHaveTheNormalsSignAndRoundToWholeSteps() throws {
        for c in try Self.cases() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let frame: Frame = Frame(c.snapshot, size: size, orbit: orbit)
                    let u: SIMD2<Double> = try #require(Self.normalOnScreen(c.snapshot, frame: frame,
                                                                            reduceMotion: false))
                    for k in -3...3 {
                        let drag: SIMD2<Double> = u * (24 * Double(k))
                        #expect(Picker.depthSteps(drag: drag, size: size, snapshot: c.snapshot, orbit: orbit,
                                                  reduceMotion: false) == k)
                    }
                    let lists: [(Double, Int)] = [(0.2, 0), (0.4, 0), (0.6, 1), (1.4, 1), (1.6, 2), (-0.6, -1),
                                                  (-1.4, -1), (-1.6, -2)]
                    for (fraction, steps) in lists {
                        #expect(Picker.depthSteps(drag: u * (24 * fraction), size: size, snapshot: c.snapshot,
                                                  orbit: orbit, reduceMotion: false) == steps)
                    }
                    let across: SIMD2<Double> = SIMD2(-u.y, u.x) * 300
                    #expect(Picker.depthSteps(drag: across, size: size, snapshot: c.snapshot, orbit: orbit,
                                              reduceMotion: false) == 0)
                    // Towards +n the depth grows: one step forward is the next larger crossing depth.
                    let next: Choice = c.snapshot.choice.steppingDepth(1, in: c.play)
                    #expect(next.depth >= c.snapshot.choice.depth)
                }
            }
        }
    }

    // MARK: Minimum target, ties, unusable input

    @Test func theRimHasAMinimumTargetOfTwentyTwoPoints() throws {
        #expect(Picker.minimumTarget == 22 && Picker.pointsPerDepthStep == 24)
        var checked: Int = 0
        for c in try Self.cases() {
            for size in Self.sizes {
                let frame: Frame = Frame(c.snapshot, size: size, orbit: .authored)
                var outline: [SIMD2<Double>] = []
                let shift: SIMD3<Double> = Geometry.offset(piece: c.snapshot.choice.piece, c.snapshot)
                for corner in c.snapshot.preview { if let p = frame.project(corner + shift) { outline.append(p) } }
                guard outline.count >= 3 else { continue }
                var mean: SIMD2<Double> = .zero
                for p in outline { mean += p }
                mean = mean / Double(outline.count)
                for k in outline.indices {
                    let a: SIMD2<Double> = outline[k]
                    let b: SIMD2<Double> = outline[(k + 1) % outline.count]
                    let edge: SIMD2<Double> = b - a
                    let length: Double = (edge * edge).sum().squareRoot()
                    guard length > 1 else { continue }
                    var normal: SIMD2<Double> = SIMD2(-edge.y, edge.x) / length
                    let mid: SIMD2<Double> = (a + b) / 2
                    if ((mid - mean) * normal).sum() < 0 { normal = -normal }
                    for (distance, rim) in [(21.0, true), (23.0, false)] {
                        let p: SIMD2<Double> = mid + normal * distance
                        guard p.x > 0, p.y > 0, p.x < size.x, p.y < size.y else { continue }
                        let expected: (pick: FacetedForgePick, ambiguous: Bool, byCentre: Bool) =
                            Self.expected(p, frame: frame, snapshot: c.snapshot, reduceMotion: false)
                        guard !expected.ambiguous else { continue }
                        let pick: FacetedForgePick = Picker.pick(p, size: size, snapshot: c.snapshot,
                                                                 orbit: .authored, reduceMotion: false)
                        #expect(pick == expected.pick)
                        // Outside a convex outline the nearest edge point is this edge's midpoint only if no other
                        // edge is nearer: 21 points out is always within the target, 23 may still be near another.
                        if rim { #expect(pick == .rim) }
                        checked += 1
                    }
                }
            }
        }
        #expect(checked > 20)
    }

    @Test func pieceCentresHaveAMinimumTargetOfTwentyTwoPoints() throws {
        var byCentre: Int = 0
        var missed: Int = 0
        let size: SIMD2<Double> = SIMD2(120, 90)
        for c in try Self.cases() {
            for orbit in Self.orbits {
                let frame: Frame = Frame(c.snapshot, size: size, orbit: orbit)
                for piece in c.snapshot.pieces.indices {
                    guard let centre = frame.project(Geometry.pieceCentre(piece, c.snapshot)) else { continue }
                    for k in 0..<24 {
                        let angle: Double = 2 * Double.pi * Double(k) / 24
                        for distance in [21.0, 23.0] {
                            let p: SIMD2<Double> = centre + SIMD2(cos(angle), sin(angle)) * distance
                            guard p.x > 0, p.y > 0, p.x < size.x, p.y < size.y else { continue }
                            let expected: (pick: FacetedForgePick, ambiguous: Bool, byCentre: Bool) =
                                Self.expected(p, frame: frame, snapshot: c.snapshot, reduceMotion: false)
                            guard !expected.ambiguous else { continue }
                            let pick: FacetedForgePick = Picker.pick(p, size: size, snapshot: c.snapshot,
                                                                     orbit: orbit, reduceMotion: false)
                            #expect(pick == expected.pick)
                            if expected.byCentre { byCentre += 1 }
                            if expected.pick == .empty { missed += 1 }
                        }
                    }
                }
            }
        }
        #expect(byCentre > 0 && missed > 0)
    }

    @Test func tiesGoToTheLowerIndexAndTheSmallerDepth() {
        let points: [SIMD2<Double>?] = [nil, SIMD2(10, 0), SIMD2(-10, 0), SIMD2(0, 10)]
        #expect(Picker.nearestWithin(SIMD2(0, 0), points, limit: 22) == 1)
        #expect(Picker.nearestWithin(SIMD2(0, 0), points, limit: 9) == nil)
        #expect(Picker.nearestWithin(SIMD2(0, 0), [SIMD2(22, 0)], limit: 22) == 0)
        #expect(Picker.nearestDepth([-3, -1, 1, 3], to: 0) == -1)
        #expect(Picker.nearestDepth([3, 1, -1, -3], to: 2) == 1)
        #expect(Picker.nearestDepth([4, 6], to: 5) == 4)
        #expect(Picker.nearestDepth([], to: 5) == nil)
        // The zero vector ties all 13 directions: the lowest index wins; each unit vector snaps to itself, either sign.
        #expect(Picker.nearestDirection(.zero) == 0)
        for index in 0..<13 {
            let d: FacetedForgeDirection = FacetedForgeDirection.all[index]
            let v: SIMD3<Double> = SIMD3(Double(d.x), Double(d.y), Double(d.z))
            #expect(Picker.nearestDirection(v) == index)
            #expect(Picker.nearestDirection(-v * 3) == index)
        }
    }

    @Test func nonFiniteOrUnusableInputPicksNothing() throws {
        let c: Case = try Self.cases()[0]
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: FacetedForgeCamera = Geometry.camera(c.snapshot, aspect: size.x / size.y, orbit: .authored)
        let centre: SIMD2<Double> = SIMD2(195, 422)
        let bad: [SIMD2<Double>] = [SIMD2(.nan, 422), SIMD2(195, .infinity), SIMD2(-.infinity, .nan),
                                    SIMD2(-5, 422), SIMD2(195, 900)]
        for point in bad {
            #expect(Picker.pick(point, size: size, snapshot: c.snapshot, orbit: .authored,
                                reduceMotion: false) == .empty)
            #expect(Picker.ray(point, size: size, camera: camera) == nil)
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, -1), SIMD2(.nan, 844), SIMD2(390, .infinity)]
        for badSize in sizes {
            #expect(Picker.pick(centre, size: badSize, snapshot: c.snapshot, orbit: .authored,
                                reduceMotion: false) == .empty)
            #expect(Picker.ray(centre, size: badSize, camera: camera) == nil)
            #expect(Picker.depthSteps(drag: SIMD2(48, 0), size: badSize, snapshot: c.snapshot, orbit: .authored,
                                      reduceMotion: false) == 0)
            #expect(Picker.tilt(c.snapshot.choice, drag: SIMD2(48, 0), size: badSize, snapshot: c.snapshot,
                                play: c.play, orbit: .authored) == c.snapshot.choice)
        }
        // A non-finite orbit is the authored one.
        let odd: Orbit = Orbit(yaw: .nan, pitch: .infinity)
        #expect(Picker.pick(centre, size: size, snapshot: c.snapshot, orbit: odd, reduceMotion: false)
            == Picker.pick(centre, size: size, snapshot: c.snapshot, orbit: .authored, reduceMotion: false))
        // The ray of the view centre is unit length and passes through the crystal centre.
        if let r = Picker.ray(centre, size: size, camera: camera) {
            #expect(abs(Geometry.length(r.direction) - 1) < 1e-12)
            let t: Double = Geometry.dot(-r.origin, r.direction)
            #expect(Geometry.length(r.origin + r.direction * t) < 1e-9)
        } else {
            Issue.record("no ray through the view centre")
        }
    }
}
