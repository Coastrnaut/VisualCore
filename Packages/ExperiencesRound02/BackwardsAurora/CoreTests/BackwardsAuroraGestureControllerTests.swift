// BackwardsAuroraGestureControllerTests — feature 394 (R02-G10-04) T-R02G1004-004 (FR-R02G1004-001 … 005, 007;
// SC-R02G1004-001 … 003; clarifications Q1 … Q4). 500 seeded (seed 2_394) scripted gestures — taps on sample columns and
// on the band, end drags, swipes, held presses (frozen by `tick` or by a late move), band drags that are not sideways,
// touches of 10 … 16 points, random touches, second fingers, double taps on empty space and cancelled touches — on
// certified levels 1, 21, 41, 61 and 81 (one reversal before their certified win, still playing; won; showing the
// result) with a seeded chosen section, at three view sizes and three orbits reached by two-finger drags, send exactly
// the actions an independent expectation written here predicts: the pick at touch-down and the sample column under the
// finger come from `BackwardsAuroraPicker` (the geometry oracle, tested on its own), while the arbitration (tap, drag,
// swipe, freeze or nothing by travel, direction and event timestamps; the tap rule of clarification Q2; the clamped end
// drag; no reversal on a finished play; the orbit arithmetic) is computed here on its own. Every freeze preview equals
// the kernel's reversal of the chosen section (samples, kinks, tear and matched checkpoints, the tear checked against
// the play itself where the kernel accepts the reversal); second fingers, `.cancelled` phases, `cancel()` and finished
// plays send no reversal; 10 … 16 points of travel send nothing; a double tap on empty space resets the view; previews
// and the orbit never change the adapter's digest. Plain loops and explicit types (CI type-check rule); each test well
// under 10 s once the levels are certified.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import BackwardsAuroraCore

@Suite struct BackwardsAuroraGestureControllerTests {
    typealias Controller = BackwardsAuroraGestureController
    typealias Snapshot = BackwardsAuroraSceneSnapshot
    typealias Action = BackwardsAuroraGestureAction
    typealias Geometry = BackwardsAuroraSceneGeometry
    typealias Picker = BackwardsAuroraPicker
    typealias Orbit = BackwardsAuroraOrbit
    typealias Core = BackwardsAuroraExperienceCore
    typealias Play = BackwardsAuroraPlay
    typealias Preview = BackwardsAuroraFreezePreview

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_394
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.3, pitch: 0.2), Orbit(yaw: -0.45, pitch: -0.15)]
    /// The certified levels used.
    static let levels: [Int] = [1, 21, 41, 61, 81]

    // MARK: Cases

    /// A core (for the digest and the adapter), the play the controller sees and the level number.
    struct Case {
        let core: Core
        let play: Play
        let number: Int
    }

    /// The adapter action of a kernel action.
    func adapterAction(_ a: BackwardsAuroraAction) -> ExperienceAction {
        switch a {
        case let .reverse(start, end):
            return ExperienceAction(control: "wave.reverse", values: [Double(start), Double(end)], step: 0)
        }
    }

    /// The digest of `core` as the engine computes it.
    func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// Certified level `number` one reversal before its certified win (playing), after it (won) and showing the
    /// result.
    func cases(_ number: Int) throws -> [Case] {
        let actions: [BackwardsAuroraAction] = try Core.generated(number: number).solution.actions
        try #require(!actions.isEmpty)
        var core: Core = try Core.opening(number: number)
        var index: Int = 0
        while index < actions.count - 1 {
            #expect(core.apply(adapterAction(actions[index])) == .accepted)
            index += 1
        }
        #expect(core.play.stage == .playing)
        let playing: Case = Case(core: core, play: core.play, number: number)
        #expect(core.apply(adapterAction(actions[actions.count - 1])) == .accepted)
        #expect(core.play.stage == .won)
        let won: Case = Case(core: core, play: core.play, number: number)
        var shown: Play = core.play
        try shown.handle(.showResult)
        #expect(shown.stage == .result)
        return [playing, won, Case(core: core, play: shown, number: number)]
    }

    /// Every case of ``levels``.
    func allCases() throws -> [Case] {
        var all: [Case] = []
        for number in Self.levels { all += try cases(number) }
        return all
    }

    /// Level 1 failed by its budget: a neutral pair (not a palindrome, no checkpoint) reversed until the budget runs out.
    func failedCase() throws -> Case {
        var core: Core = try Core.opening(number: 1)
        let wave: BackwardsAuroraWave = core.play.wave
        let checkpoints: [Int] = core.play.level.checkpoints
        var pair: Int?
        var k: Int = 0
        while k + 1 < wave.count && pair == nil {
            if wave.samples[k] != wave.samples[k + 1] && !checkpoints.contains(k) && !checkpoints.contains(k + 1)
                && core.play.level.sectionLengths.contains(2) {
                pair = k
            }
            k += 1
        }
        let first: Int = try #require(pair)
        var spent: Int = 0
        while core.play.stage == .playing && spent <= core.play.level.budget {
            #expect(core.apply(adapterAction(.reverse(first, first + 1))) == .accepted)
            spent += 1
        }
        #expect(core.play.stage == .failed)
        return Case(core: core, play: core.play, number: 1)
    }

    /// The snapshot of `c` at time 1 s with the chosen section [`start`, `end`].
    func snapshot(_ c: Case, _ start: Int, _ end: Int) -> Snapshot {
        Snapshot(play: c.play, levelNumber: c.number, sectionStart: start, sectionEnd: end, time: 1)
    }

    /// A seeded section of `c`'s level: a length among its section lengths, a start that fits.
    func section(_ c: Case, _ random: inout SeededRandom) -> (start: Int, end: Int) {
        let count: Int = c.play.wave.count
        let low: Int = max(c.play.level.shortest, 2)
        let high: Int = max(min(c.play.level.longest, count), low)
        let length: Int = low + below(high - low + 1, &random)
        let start: Int = below(count - length + 1, &random)
        return (start, start + length - 1)
    }

    // MARK: Projection and targets

    /// The view point of `world` for `snapshot` in `view` at `orbit`, or nil behind the eye.
    func screen(_ world: SIMD3<Double>, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let camera: BackwardsAuroraCamera = Geometry.camera(snapshot, aspect: view.x / view.y, orbit: orbit)
        guard let p = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(p.x * view.x, p.y * view.y)
    }

    /// The pick of `point` (the oracle).
    func pick(_ point: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> BackwardsAuroraPick {
        Picker.pick(SIMD2(point.x, point.y), size: SIMD2(view.x, view.y), snapshot: snapshot, orbit: orbit)
    }

    /// The sample column under `point` (the oracle).
    func column(_ point: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Int? {
        Picker.column(SIMD2(point.x, point.y), size: SIMD2(view.x, view.y), snapshot: snapshot, orbit: orbit)
    }

    /// The x of column `k`.
    func columnX(_ k: Double, _ snapshot: Snapshot) -> Double {
        -1 + (k + 0.5) * Geometry.spacing(snapshot)
    }

    /// A point on the timeline plane at fractional column `k` and height `y`, projected and kept inside the view.
    func planePoint(_ k: Double, _ y: Double, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        guard let p = screen(SIMD3(columnX(k, snapshot), y, 0), snapshot: snapshot, view: view, orbit: orbit) else {
            return nil
        }
        return inside(p, view)
    }

    /// A seeded point over the band of `snapshot` (column inside the section, |y| ≤ 0.65).
    func bandPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout SeededRandom) -> Vec2? {
        let span: Double = Double(snapshot.sectionEnd - snapshot.sectionStart + 1)
        let k: Double = Double(snapshot.sectionStart) - 0.45 + unit(&random) * (span - 0.1)
        return planePoint(k, unit(&random) * 1.3 - 0.65, snapshot: snapshot, view: view, orbit: orbit)
    }

    /// The projected sample point of the section's start (`start` true) or end.
    func endPoint(_ start: Bool, _ snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let k: Int = start ? snapshot.sectionStart : snapshot.sectionEnd
        guard let p = screen(Geometry.samplePoint(k, snapshot), snapshot: snapshot, view: view, orbit: orbit) else {
            return nil
        }
        return inside(p, view)
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    func emptyPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where pick(c, snapshot: snapshot, view: view, orbit: orbit) == .empty {
            return c
        }
        return nil
    }

    // MARK: Scripting

    /// One step of a one-finger script: a pointer event of finger 1, or a `tick` at a time.
    enum Step {
        case event(PointerPhase, Vec2, Double)
        case tick(Double)
    }

    /// A pointer event.
    func event(_ id: Int, _ phase: PointerPhase, _ point: Vec2, _ time: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: point, timestamp: time)
    }

    /// A unit random number 0 ..< 1.
    func unit(_ random: inout SeededRandom) -> Double {
        Double(random.next() >> 11) / 9_007_199_254_740_992
    }

    /// A random whole number 0 ..< `count`.
    func below(_ count: Int, _ random: inout SeededRandom) -> Int {
        min(Int(unit(&random) * Double(count)), count - 1)
    }

    /// `p` kept one point inside `view`.
    func inside(_ p: Vec2, _ view: Vec2) -> Vec2 {
        Vec2(min(max(p.x, 1), view.x - 1), min(max(p.y, 1), view.y - 1))
    }

    /// A straight path of `steps` + 1 events from `a` to `b` (each kept inside the view) at 0.05 s intervals from
    /// `time`, the end repeated 0.02 s later (the last move and the release at the same place).
    func path(_ a: Vec2, _ b: Vec2, steps: Int, view: Vec2, time: Double) -> [Step] {
        var result: [Step] = []
        var i: Int = 0
        var last: Vec2 = a
        var lastTime: Double = time
        while i <= steps {
            let t: Double = Double(i) / Double(steps)
            last = inside(a + (b - a) * t, view)
            lastTime = time + 0.05 * Double(i)
            result.append(.event(i == 0 ? .began : .moved, last, lastTime))
            i += 1
        }
        result.append(.event(.ended, last, lastTime + 0.02))
        return result
    }

    /// A tap at `p` from `time` lasting `held` seconds.
    func tapSteps(_ p: Vec2, time: Double, held: Double) -> [Step] {
        [.event(.began, p, time), .event(.ended, p, time + held)]
    }

    /// What a script produced: the actions, the state after touch-down, the preview just before the last step and the
    /// state just before it.
    struct Outcome {
        var actions: [Action]
        var state: Controller.State
        var preview: Preview?
        var before: Controller.State
    }

    /// Feeds `steps` (finger 1) to `controller` for `snapshot` of `c` in `view`.
    func run(_ controller: inout Controller, _ steps: [Step], view: Vec2, snapshot: Snapshot, c: Case) -> Outcome {
        var outcome: Outcome = Outcome(actions: [], state: .idle, preview: nil, before: .idle)
        var index: Int = 0
        while index < steps.count {
            if index == steps.count - 1 {
                outcome.preview = controller.preview
                outcome.before = controller.state
            }
            switch steps[index] {
            case let .event(phase, point, time):
                outcome.actions += controller.handle(event(1, phase, point, time), viewSize: view, snapshot: snapshot,
                                                     play: c.play)
            case let .tick(time):
                controller.tick(at: time, snapshot: snapshot, play: c.play)
            }
            if index == 0 { outcome.state = controller.state }
            index += 1
        }
        return outcome
    }

    /// Two fingers (7 and 8) going down at `a` and `b`, moving their midpoint by `move` and lifting; returns the
    /// actions sent.
    func twoFingers(_ controller: inout Controller, a: Vec2, b: Vec2, by move: Vec2, view: Vec2, snapshot: Snapshot,
                    c: Case, time: Double) -> [Action] {
        let frame: Double = 1.0 / 60
        let evs: [PointerEvent] = [event(7, .began, a, time), event(8, .began, b, time + frame),
                                   event(7, .moved, a + move, time + 2 * frame),
                                   event(8, .moved, b + move, time + 3 * frame),
                                   event(7, .ended, a + move, time + 4 * frame),
                                   event(8, .ended, b + move, time + 5 * frame)]
        var actions: [Action] = []
        for e in evs {
            actions += controller.handle(e, viewSize: view, snapshot: snapshot, play: c.play)
        }
        return actions
    }

    /// Whether two orbits agree within 1e-9 radians.
    func near(_ a: Orbit, _ b: Orbit) -> Bool {
        abs(a.yaw - b.yaw) < 1e-9 && abs(a.pitch - b.pitch) < 1e-9
    }

    /// `orbit` turned by a midpoint movement of `delta` in `view` (90° per width, 60° per height, pitch up for an
    /// upward movement), clamped — computed here on its own.
    func turned(_ orbit: Orbit, by delta: Vec2, view: Vec2) -> Orbit {
        Orbit(yaw: orbit.yaw + delta.x / view.x * (Double.pi / 2),
              pitch: orbit.pitch - delta.y / view.y * (Double.pi / 3)).clamped()
    }

    /// A controller turned to `orbit` by a two-finger drag starting on empty space in `view`.
    func controller(at orbit: Orbit, view: Vec2, snapshot: Snapshot, c: Case) throws -> Controller {
        var controller: Controller = Controller()
        let a: Vec2 = try #require(emptyPoint(snapshot, view: view, orbit: .authored))
        let b: Vec2 = Vec2(view.x / 2, view.y / 2)
        let move: Vec2 = Vec2(orbit.yaw / (Double.pi / 2) * view.x, -orbit.pitch / (Double.pi / 3) * view.y)
        let actions: [Action] = twoFingers(&controller, a: a, b: b, by: move, view: view, snapshot: snapshot, c: c,
                                           time: 0)
        #expect(actions.isEmpty)
        #expect(near(controller.orbit, orbit))
        #expect(controller.state == .idle && controller.preview == nil)
        return controller
    }

    // MARK: Independent expectation

    /// What a one-finger script must send and show.
    struct Expectation {
        var actions: [Action]
        var state: Controller.State
        /// Whether the freeze preview shows just before the last step.
        var preview: Bool
        /// Whether the press froze.
        var frozen: Bool
    }

    /// The section change of a tap on column `k` (clarification Q2), written on its own.
    func tapRule(_ k: Int, start: Int, end: Int) -> [Action] {
        if k < start { return [.setStart(k)] }
        if k > end { return [.setEnd(k)] }
        if k == start || k == end { return [] }
        if k - start <= end - k { return [.setStart(k)] }
        return [.setEnd(k)]
    }

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended`) on case `c` with `snapshot`
    /// in `view` at `orbit`, written on its own.
    func expected(_ steps: [Step], c: Case, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Expectation {
        guard case let .event(_, origin, startTime) = steps[0] else {
            return Expectation(actions: [], state: .idle, preview: false, frozen: false)
        }
        let picked: BackwardsAuroraPick = pick(origin, snapshot: snapshot, view: view, orbit: orbit)
        let start: Int = snapshot.sectionStart
        let end: Int = snapshot.sectionEnd
        let playing: Bool = c.play.stage == .playing
        var state: Controller.State = .idle
        var band: Bool = false
        var position: Int = 0
        switch picked {
        case .start:
            state = .endDrag
            position = start
        case .end:
            state = .endDrag
            position = end
        case .band:
            state = .bandPress
            band = true
        case .sample:
            state = .samplePress
        case .empty:
            state = .idle
        }
        var result: Expectation = Expectation(actions: [], state: state, preview: false, frozen: false)
        var travel: Double = 0
        var swiping: Bool?
        var frozen: Bool = false
        var index: Int = 1
        while index < steps.count {
            if index == steps.count - 1 { result.preview = band && (frozen || swiping == true) }
            switch steps[index] {
            case let .tick(time):
                if band && !frozen && swiping == nil && travel < 10 && time - startTime >= 0.5 { frozen = true }
            case let .event(phase, point, time):
                if phase == .moved && band && !frozen && swiping == nil && travel < 10 && time - startTime >= 0.5 {
                    frozen = true
                }
                travel = max(travel, (point - origin).length)
                if travel >= 16 {
                    switch picked {
                    case .start, .end:
                        if let k = column(point, snapshot: snapshot, view: view, orbit: orbit) {
                            let clamped: Int = picked == .start ? min(max(k, 0), end - 1)
                                : min(max(k, start + 1), snapshot.count - 1)
                            if clamped != position {
                                position = clamped
                                result.actions.append(picked == .start ? .setStart(clamped) : .setEnd(clamped))
                            }
                        }
                    case .band:
                        if !frozen && swiping == nil {
                            let d: Vec2 = point - origin
                            swiping = abs(d.x) >= 2 * abs(d.y)
                        }
                    case .sample, .empty:
                        break
                    }
                }
                if phase == .ended {
                    if frozen {
                        // A frozen press sends nothing.
                    } else if travel >= 16 {
                        if band && swiping == true && playing { result.actions.append(.reverse(start, end)) }
                    } else if travel < 10 && time - startTime <= 0.5 {
                        switch picked {
                        case .band(let k), .sample(let k):
                            result.actions += tapRule(k, start: start, end: end)
                        case .start, .end, .empty:
                            break
                        }
                    }
                }
            }
            index += 1
        }
        result.frozen = frozen
        return result
    }

    /// Checks `preview` against the kernel for `play`: the samples are the wave's reversal of the section, the kinks
    /// the would-be bends above L, the tear the rules' seam (and the play's own tear where the kernel accepts the
    /// reversal), the matched checkpoints the level's count, and the text names them.
    func checkPreview(_ preview: Preview, play: Play) {
        let level: BackwardsAuroraLevel = play.level
        let after: BackwardsAuroraWave = play.wave.reversed(start: preview.start, end: preview.end)
        #expect(preview.samples == after.samples)
        var kinks: [Int] = []
        var worst: Int = 0
        var k: Int = 1
        while k + 1 < after.count {
            let b: Int = after.samples[k - 1] - 2 * after.samples[k] + after.samples[k + 1]
            if abs(b) > level.bendLimit { kinks.append(k) }
            worst = max(worst, abs(b))
            k += 1
        }
        #expect(preview.kinks == kinks)
        #expect(preview.worstBend == worst)
        let rules: BackwardsAuroraRules = BackwardsAuroraRules(level: level)
        #expect(preview.tear == rules.tearSeam(after, start: preview.start, end: preview.end))
        var matched: Int = 0
        for p in level.checkpoints where after.samples[p] == level.target.samples[p] { matched += 1 }
        #expect(preview.matched == matched)
        let accepted: Bool = play.stage == .playing && level.sectionLengths.contains(preview.end - preview.start + 1)
            && !play.wave.isPalindrome(start: preview.start, end: preview.end)
        if accepted {
            var copy: Play = play
            do {
                try copy.apply(.reverse(preview.start, preview.end), expecting: copy.fingerprint)
                #expect(copy.wave.samples == preview.samples)
                if case let .tear(_, seam)? = copy.failure {
                    #expect(preview.tear == seam)
                } else {
                    #expect(preview.tear == nil)
                }
            } catch {
                Issue.record("the kernel refused \(preview.start) … \(preview.end): \(error)")
            }
        }
        if let tear = preview.tear {
            #expect(preview.text == "would tear at seam \(tear)")
        } else {
            #expect(preview.text == "would match \(matched) of \(level.checkpoints.count) checkpoints, worst bend "
                    + "\(worst) of \(level.bendLimit)")
        }
    }

    /// One seeded one-finger script of `kind` (0 … 7) on `snapshot` in `view` at `orbit`, or nil without a target.
    func script(_ kind: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout SeededRandom) -> [Step]? {
        let count: Int = snapshot.count
        switch kind {
        case 0:   // a tap on a sample column
            let k: Double = Double(below(count, &random)) + unit(&random) * 0.8 - 0.4
            guard let p = planePoint(k, unit(&random) * 1.48 - 0.74, snapshot: snapshot, view: view,
                                     orbit: orbit) else { return nil }
            let q: Vec2 = inside(p + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3), view)
            return [.event(.began, p, 1), .event(.ended, q, 1.05 + 0.4 * unit(&random))]
        case 1:   // a tap on the band
            guard let p = bandPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            return tapSteps(p, time: 1, held: 0.05 + 0.4 * unit(&random))
        case 2:   // an end drag to a seeded column
            let fromStart: Bool = unit(&random) < 0.5
            guard let p = endPoint(fromStart, snapshot, view: view, orbit: orbit),
                  let q = planePoint(Double(below(count, &random)), unit(&random) * 1.2 - 0.6, snapshot: snapshot,
                                     view: view, orbit: orbit) else { return nil }
            return path(p, q, steps: 4, view: view, time: 1)
        case 3:   // a swipe along the band
            guard let p = bandPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            let dx: Double = (40 + 180 * unit(&random)) * (unit(&random) < 0.5 ? -1 : 1)
            let dy: Double = (unit(&random) * 0.8 - 0.4) * abs(dx)
            return path(p, p + Vec2(dx, dy), steps: 4, view: view, time: 1)
        case 4:   // a held press on the band: frozen by a tick or by a late small move, then perhaps a sideways move
            guard let p = bandPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            let hold: Double = 0.3 + 0.5 * unit(&random)
            var steps: [Step] = [.event(.began, p, 1)]
            if unit(&random) < 0.6 {
                steps.append(.tick(1 + hold))
            } else {
                steps.append(.event(.moved, inside(p + Vec2(3, 2), view), 1 + hold))
            }
            let q: Vec2 = unit(&random) < 0.5 ? p : inside(p + Vec2(120 * (unit(&random) < 0.5 ? -1 : 1), 4), view)
            steps.append(.event(.moved, q, 1 + hold + 0.1))
            steps.append(.event(.ended, q, 1 + hold + 0.15))
            return steps
        case 5:   // a band drag that is not sideways
            guard let p = bandPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            let dy: Double = (40 + 160 * unit(&random)) * (unit(&random) < 0.5 ? -1 : 1)
            let dx: Double = (unit(&random) * 0.8 - 0.4) * abs(dy)
            return path(p, p + Vec2(dx, dy), steps: 3, view: view, time: 1)
        case 6:   // a short touch of 10 … 16 points from a sample, the band or an end
            var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let choice: Int = below(3, &random)
            if choice == 0, let b = bandPoint(snapshot, view: view, orbit: orbit, random: &random) { p = b }
            if choice == 1, let e = endPoint(unit(&random) < 0.5, snapshot, view: view, orbit: orbit) { p = e }
            let angle: Double = unit(&random) * 2 * Double.pi
            let length: Double = 10.5 + 5 * unit(&random)
            let q: Vec2 = p + Vec2(cos(angle) * length, sin(angle) * length)
            guard q.x > 1, q.y > 1, q.x < view.x - 1, q.y < view.y - 1 else { return nil }
            return path(p, q, steps: 2, view: view, time: 1)
        default:  // a random touch, sometimes slow
            let p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let q: Vec2 = p + Vec2(unit(&random) * 60 - 30, unit(&random) * 60 - 30)
            let slow: Double = unit(&random) < 0.3 ? 0.6 : 0
            var steps: [Step] = []
            for s in path(p, q, steps: 2, view: view, time: 1) {
                if case let .event(phase, point, time) = s {
                    steps.append(.event(phase, point, phase == .began ? time : time + slow))
                }
            }
            return steps
        }
    }

    /// A seeded one-finger script of `kind` (0 … 7) checked against its expectation; returns the actions sent and
    /// whether a preview was checked against the kernel (and froze), or nil when the script has no target here.
    func oneFinger(_ kind: Int, _ controller: inout Controller, c: Case, snapshot: Snapshot, view: Vec2, orbit: Orbit,
                   run: Int, random: inout SeededRandom) -> (actions: [Action], previewed: Bool, frozen: Bool)? {
        guard let s = script(kind, snapshot: snapshot, view: view, orbit: orbit, random: &random) else { return nil }
        let want: Expectation = expected(s, c: c, snapshot: snapshot, view: view, orbit: orbit)
        let got: Outcome = self.run(&controller, s, view: view, snapshot: snapshot, c: c)
        #expect(got.actions == want.actions, "run \(run) kind \(kind)")
        #expect(got.state == want.state, "run \(run) kind \(kind)")
        #expect(controller.state == .idle && controller.preview == nil)
        #expect(near(controller.orbit, orbit))
        if want.frozen { #expect(got.before == .freeze, "run \(run) kind \(kind)") }
        var previewed: Bool = false
        if want.preview {
            let expectedPreview: Preview? = Preview.make(play: c.play, start: snapshot.sectionStart,
                                                         end: snapshot.sectionEnd)
            #expect(got.preview == expectedPreview, "preview run \(run) kind \(kind)")
            if let p = got.preview {
                checkPreview(p, play: c.play)
                #expect(snapshot.withPreview(p.samples).preview == p.samples)
                previewed = true
            }
        } else {
            #expect(got.preview == nil, "no preview run \(run) kind \(kind)")
        }
        return (got.actions, previewed, want.frozen)
    }

    /// A seeded second-finger script: the first finger on the band (perhaps swiping first), a second finger cancels
    /// and orbits; nothing is sent and the orbit turns by half the second finger's movement.
    func secondFingerScript(_ controller: inout Controller, c: Case, snapshot: Snapshot, view: Vec2, orbit: Orbit,
                            run: Int, random: inout SeededRandom) -> [Action]? {
        guard let p = bandPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
        var actions: [Action] = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: snapshot,
                                                  play: c.play)
        var first: Vec2 = p
        let onBand: Bool = pick(p, snapshot: snapshot, view: view, orbit: orbit) != .start
            && pick(p, snapshot: snapshot, view: view, orbit: orbit) != .end
        if unit(&random) < 0.5 && onBand {
            first = inside(p + Vec2(80, 0), view)
            actions += controller.handle(event(1, .moved, first, 1.05), viewSize: view, snapshot: snapshot,
                                         play: c.play)
        }
        let q: Vec2 = Vec2(view.x / 2, view.y / 2)
        actions += controller.handle(event(2, .began, q, 1.1), viewSize: view, snapshot: snapshot, play: c.play)
        #expect(controller.state == .orbiting && controller.preview == nil, "second finger run \(run)")
        let move: Vec2 = Vec2((unit(&random) - 0.5) * view.x * 0.6, (unit(&random) - 0.5) * view.y * 0.6)
        actions += controller.handle(event(2, .moved, q + move, 1.15), viewSize: view, snapshot: snapshot,
                                     play: c.play)
        actions += controller.handle(event(1, .ended, first, 1.2), viewSize: view, snapshot: snapshot, play: c.play)
        #expect(controller.state == .cancelled)
        actions += controller.handle(event(2, .ended, q + move, 1.25), viewSize: view, snapshot: snapshot,
                                     play: c.play)
        #expect(controller.state == .idle && controller.preview == nil)
        #expect(actions.isEmpty, "second finger run \(run)")
        #expect(near(controller.orbit, turned(orbit, by: move * 0.5, view: view)), "second finger run \(run)")
        return actions
    }

    /// A seeded double tap on empty space: `.resetView` and the authored orbit; nil without an empty corner.
    func doubleTapScript(_ controller: inout Controller, c: Case, snapshot: Snapshot, view: Vec2, orbit: Orbit,
                         run: Int, random: inout SeededRandom) -> [Action]? {
        guard let e = emptyPoint(snapshot, view: view, orbit: orbit) else { return nil }
        let shift: Vec2 = Vec2(unit(&random) * 10, unit(&random) * 10)
        var actions: [Action] = self.run(&controller, tapSteps(e, time: 1, held: 0.05), view: view,
                                         snapshot: snapshot, c: c).actions
        #expect(actions.isEmpty)
        actions += self.run(&controller, tapSteps(inside(e + shift, view), time: 1.2, held: 0.05), view: view,
                       snapshot: snapshot, c: c).actions
        #expect(actions == [.resetView], "double tap run \(run)")
        #expect(controller.orbit == .authored)
        return actions
    }

    /// A seeded cancelled band gesture: a swipe or a press ended by a `.cancelled` phase sends nothing.
    func cancelledScript(_ controller: inout Controller, c: Case, snapshot: Snapshot, view: Vec2, orbit: Orbit,
                         run: Int, random: inout SeededRandom) -> [Action]? {
        guard let p = bandPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
        let picked: BackwardsAuroraPick = pick(p, snapshot: snapshot, view: view, orbit: orbit)
        let endPicked: Bool = picked == .start || picked == .end
        let q: Vec2 = unit(&random) < 0.5 || endPicked ? p : inside(p + Vec2(100, 0), view)
        var actions: [Action] = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: snapshot,
                                                  play: c.play)
        actions += controller.handle(event(1, .moved, q, 1.05), viewSize: view, snapshot: snapshot, play: c.play)
        actions += controller.handle(event(1, .cancelled, q, 1.1), viewSize: view, snapshot: snapshot, play: c.play)
        #expect(actions.isEmpty, "cancelled run \(run)")
        #expect(controller.state == .idle && controller.preview == nil)
        return actions
    }

    // MARK: Tests

    @Test func fiveHundredSeededScriptsMatchTheIndependentExpectation() throws {
        let all: [Case] = try allCases()
        var digests: [String] = []
        for c in all { digests.append(try digest(c.core)) }
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var run: Int = 0
        var attempts: Int = 0
        var counts: [Int] = Array(repeating: 0, count: 11)
        var sent: [String: Int] = [:]
        var previews: Int = 0
        var freezes: Int = 0
        var accepted: Int = 0
        while run < 500 && attempts < 5_000 {
            attempts += 1
            let c: Case = all[below(all.count, &random)]
            let view: Vec2 = Self.views[below(Self.views.count, &random)]
            let nominal: Orbit = Self.orbits[below(Self.orbits.count, &random)]
            let chosen: (start: Int, end: Int) = section(c, &random)
            let drawn: Snapshot = snapshot(c, chosen.start, chosen.end)
            var controller: Controller = try self.controller(at: nominal, view: view, snapshot: drawn, c: c)
            // The expectation uses the orbit the controller reached (equal to the nominal one within 1e-9 radians).
            let orbit: Orbit = controller.orbit
            let kind: Int = below(11, &random)
            var actions: [Action] = []
            if kind == 8 {
                guard let got = secondFingerScript(&controller, c: c, snapshot: drawn, view: view, orbit: orbit,
                                                   run: run, random: &random) else { continue }
                actions = got
            } else if kind == 9 {
                guard let got = doubleTapScript(&controller, c: c, snapshot: drawn, view: view, orbit: orbit, run: run,
                                                random: &random) else { continue }
                actions = got
            } else if kind == 10 {
                guard let got = cancelledScript(&controller, c: c, snapshot: drawn, view: view, orbit: orbit, run: run,
                                                random: &random) else { continue }
                actions = got
            } else {
                guard let got = oneFinger(kind, &controller, c: c, snapshot: drawn, view: view, orbit: orbit, run: run,
                                          random: &random) else { continue }
                actions = got.actions
                if got.previewed { previews += 1 }
                if got.frozen { freezes += 1 }
            }
            // Every reversal sent is of the chosen section, on a playing case, and the adapter accepts it or refuses
            // it with a kernel reason code.
            for a in actions {
                guard case let .reverse(start, end) = a else { continue }
                #expect(start == drawn.sectionStart && end == drawn.sectionEnd)
                #expect(c.play.stage == .playing, "a reversal on a finished play, run \(run)")
                var copy: Core = c.core
                let result: ActionResult = copy.apply(adapterAction(.reverse(start, end)))
                if result == .accepted {
                    accepted += 1
                } else if case .rejected(.rule) = result {
                    // A palindrome or a length the level does not allow: refused with its reason code.
                } else {
                    Issue.record("unexpected adapter result \(result), run \(run)")
                }
            }
            for a in actions { sent[String(describing: a).prefix(while: { $0 != "(" }).description, default: 0] += 1 }
            counts[kind] += 1
            run += 1
        }
        #expect(run == 500)
        for k in 0..<11 { #expect(counts[k] > 0, "script kind \(k) never ran") }
        for name in ["setStart", "setEnd", "reverse", "resetView"] {
            #expect((sent[name] ?? 0) > 0, "\(name) never sent")
        }
        #expect(previews > 20)
        #expect(freezes > 5)
        #expect(accepted > 5)
        var index: Int = 0
        while index < all.count {
            #expect(try digest(all[index].core) == digests[index])
            index += 1
        }
    }

    @Test func everyFreezePreviewEqualsTheKernelsReversal() throws {
        var all: [Case] = try allCases()
        all.append(try failedCase())
        for c in all {
            let play: Play = c.play
            let count: Int = play.wave.count
            #expect(Preview.make(play: play, start: -1, end: 2) == nil)
            #expect(Preview.make(play: play, start: 3, end: 3) == nil)
            #expect(Preview.make(play: play, start: 5, end: 4) == nil)
            #expect(Preview.make(play: play, start: 0, end: count) == nil)
            var start: Int = 0
            while start < count - 1 {
                var end: Int = start + 1
                while end < count {
                    let p: Preview = try #require(Preview.make(play: play, start: start, end: end))
                    #expect(p.start == start && p.end == end)
                    #expect(p.checkpointCount == play.level.checkpoints.count && p.bendLimit == play.level.bendLimit)
                    checkPreview(p, play: play)
                    end += 1
                }
                start += 1
            }
        }
    }

    @Test func tenToSixteenPointsSendNothing() throws {
        let c: Case = try cases(Self.levels[0])[0]
        let drawn: Snapshot = snapshot(c, 3, 9)
        for view in Self.views {
            var starts: [Vec2] = []
            if let e = endPoint(false, drawn, view: view, orbit: .authored) { starts.append(e) }
            if let b = planePoint(6, 0.1, snapshot: drawn, view: view, orbit: .authored) { starts.append(b) }
            if let s = planePoint(Double(drawn.count - 1), -0.2, snapshot: drawn, view: view, orbit: .authored) {
                starts.append(s)
            }
            #expect(starts.count == 3)
            for start in starts {
                for length in [10.0, 12.5, 15.9] {
                    for direction in [Vec2(1, 0), Vec2(0, 1), Vec2(-0.6, -0.8)] {
                        var controller: Controller = Controller()
                        let s: [Step] = path(start, start + direction * length, steps: 3, view: view, time: 1)
                        let got: Outcome = run(&controller, s, view: view, snapshot: drawn, c: c)
                        #expect(got.actions.isEmpty)
                        #expect(got.preview == nil)
                        #expect(controller.orbit == .authored)
                    }
                }
            }
        }
    }

    @Test func secondFingersCancelsAndFinishedPlaysSendNoReversal() throws {
        let level: [Case] = try cases(Self.levels[1])
        let playing: Case = level[0]
        let view: Vec2 = Self.views[1]
        let drawn: Snapshot = snapshot(playing, 2, 8)
        let band: Vec2 = try #require(planePoint(5, 0.0, snapshot: drawn, view: view, orbit: .authored))
        #expect(pick(band, snapshot: drawn, view: view, orbit: .authored) == .band(5))
        let side: Vec2 = band + Vec2(150, 0)
        func send(_ c: inout Controller, _ e: PointerEvent, _ k: Case, _ s: Snapshot) -> [Action] {
            c.handle(e, viewSize: view, snapshot: s, play: k.play)
        }
        // A swipe with its preview, then a second finger: preview dropped, an orbit, nothing sent.
        var controller: Controller = Controller()
        var actions: [Action] = send(&controller, event(1, .began, band, 1), playing, drawn)
        #expect(controller.state == .bandPress)
        actions += send(&controller, event(1, .moved, side, 1.1), playing, drawn)
        #expect(controller.state == .swipe && controller.preview != nil)
        actions += send(&controller, event(2, .began, Vec2(20, 20), 1.2), playing, drawn)
        #expect(controller.state == .orbiting && controller.preview == nil)
        actions += send(&controller, event(2, .cancelled, Vec2(20, 20), 1.3), playing, drawn)
        #expect(controller.state == .cancelled)
        actions += send(&controller, event(1, .ended, side, 1.4), playing, drawn)
        #expect(actions.isEmpty && controller.state == .idle)
        // A frozen press, then a second finger: nothing sent.
        controller = Controller()
        actions = send(&controller, event(1, .began, band, 2), playing, drawn)
        controller.tick(at: 2.6, snapshot: drawn, play: playing.play)
        #expect(controller.state == .freeze && controller.preview != nil)
        actions += send(&controller, event(2, .began, Vec2(20, 20), 2.7), playing, drawn)
        #expect(controller.state == .orbiting && controller.preview == nil)
        actions += send(&controller, event(1, .ended, band, 2.8), playing, drawn)
        actions += send(&controller, event(2, .ended, Vec2(20, 20), 2.9), playing, drawn)
        #expect(actions.isEmpty && controller.state == .idle)
        // An end drag that already moved the end, then a second finger: nothing more is sent.
        let endDown: Vec2 = try #require(endPoint(false, drawn, view: view, orbit: .authored))
        #expect(pick(endDown, snapshot: drawn, view: view, orbit: .authored) == .end)
        let farRight: Vec2 = try #require(planePoint(Double(drawn.count - 1), 0, snapshot: drawn, view: view,
                                                     orbit: .authored))
        controller = Controller()
        actions = send(&controller, event(1, .began, endDown, 3), playing, drawn)
        #expect(controller.state == .endDrag)
        actions += send(&controller, event(1, .moved, farRight, 3.1), playing, drawn)
        #expect(actions == [.setEnd(drawn.count - 1)])
        actions += send(&controller, event(2, .began, Vec2(20, 20), 3.2), playing, drawn)
        actions += send(&controller, event(1, .moved, endDown, 3.3), playing, drawn)
        actions += send(&controller, event(1, .ended, endDown, 3.4), playing, drawn)
        actions += send(&controller, event(2, .ended, Vec2(20, 20), 3.5), playing, drawn)
        #expect(actions == [.setEnd(drawn.count - 1)] && controller.state == .idle)
        // A cancelled swipe and a system cancel send nothing.
        controller = Controller()
        actions = send(&controller, event(1, .began, band, 4), playing, drawn)
        actions += send(&controller, event(1, .moved, side, 4.1), playing, drawn)
        actions += send(&controller, event(1, .cancelled, side, 4.2), playing, drawn)
        #expect(actions.isEmpty && controller.preview == nil && controller.state == .idle)
        actions = send(&controller, event(1, .began, band, 5), playing, drawn)
        actions += send(&controller, event(1, .moved, side, 5.1), playing, drawn)
        #expect(controller.preview != nil)
        controller.cancel()
        #expect(controller.state == .idle && controller.preview == nil)
        actions += send(&controller, event(1, .ended, side, 5.2), playing, drawn)
        #expect(actions.isEmpty)
        // The same swipe on the playing case sends one reversal of the section.
        controller = Controller()
        actions = send(&controller, event(1, .began, band, 6), playing, drawn)
        actions += send(&controller, event(1, .moved, side, 6.1), playing, drawn)
        actions += send(&controller, event(1, .ended, side, 6.2), playing, drawn)
        #expect(actions == [.reverse(2, 8)])
        // Finished plays (won, result, failed): no reversal; taps, end drags and previews still work.
        let finished: [Case] = [level[1], level[2], try failedCase()]
        for c in finished {
            #expect(c.play.stage != .playing)
            let s: Snapshot = snapshot(c, 2, 8)
            let b: Vec2 = try #require(planePoint(5, 0.0, snapshot: s, view: view, orbit: .authored))
            controller = Controller()
            actions = send(&controller, event(1, .began, b, 7), c, s)
            actions += send(&controller, event(1, .moved, b + Vec2(150, 0), 7.1), c, s)
            let preview: Preview = try #require(controller.preview)
            checkPreview(preview, play: c.play)
            actions += send(&controller, event(1, .ended, b + Vec2(150, 0), 7.2), c, s)
            #expect(actions.isEmpty, "a swipe on \(c.play.stage)")
            controller = Controller()
            actions = send(&controller, event(1, .began, b, 8), c, s)
            controller.tick(at: 8.5, snapshot: s, play: c.play)
            #expect(controller.preview == Preview.make(play: c.play, start: 2, end: 8))
            actions += send(&controller, event(1, .ended, b, 8.6), c, s)
            #expect(actions.isEmpty)
            controller = Controller()
            actions = send(&controller, event(1, .began, b, 9), c, s)
            actions += send(&controller, event(1, .ended, b, 9.05), c, s)
            #expect(actions == [.setStart(5)])
            let e: Vec2 = try #require(endPoint(false, s, view: view, orbit: .authored))
            let r: Vec2 = try #require(planePoint(Double(s.count - 1), 0, snapshot: s, view: view, orbit: .authored))
            controller = Controller()
            actions = send(&controller, event(1, .began, e, 10), c, s)
            actions += send(&controller, event(1, .moved, r, 10.1), c, s)
            actions += send(&controller, event(1, .ended, r, 10.2), c, s)
            #expect(actions == [.setEnd(s.count - 1)])
        }
    }

    @Test func theTapRuleMovesTheNearerEnd() throws {
        let c: Case = try cases(Self.levels[0])[0]
        let drawn: Snapshot = snapshot(c, 4, 10)
        let view: Vec2 = Self.views[1]
        // Expected per column: left of the start, inside (nearer end, ties to the start), on an end, right of the end.
        let columns: [Int] = [1, 5, 7, 8, 9, 12]
        let wanted: [[Action]] = [[.setStart(1)], [.setStart(5)], [.setStart(7)], [.setEnd(8)], [.setEnd(9)],
                                  [.setEnd(12)]]
        var index: Int = 0
        while index < columns.count {
            // A height on the column that picks it (not an end within the minimum target).
            var found: Vec2?
            for y in [0.6, -0.6, 0.3, -0.3, 0.0] where found == nil {
                if let q = planePoint(Double(columns[index]), y, snapshot: drawn, view: view, orbit: .authored) {
                    let picked: BackwardsAuroraPick = pick(q, snapshot: drawn, view: view, orbit: .authored)
                    if picked == .band(columns[index]) || picked == .sample(columns[index]) { found = q }
                }
            }
            let p: Vec2 = try #require(found, "column \(columns[index])")
            var controller: Controller = Controller()
            let got: Outcome = run(&controller, tapSteps(p, time: 1, held: 0.1), view: view, snapshot: drawn, c: c)
            #expect(got.actions == wanted[index], "column \(columns[index])")
            index += 1
        }
        #expect(Controller.tap(4, start: 4, end: 10).isEmpty)
        #expect(Controller.tap(10, start: 4, end: 10).isEmpty)
        // A tap held longer than 0.5 s sends nothing.
        let p: Vec2 = try #require(planePoint(1, 0.3, snapshot: drawn, view: view, orbit: .authored))
        var controller: Controller = Controller()
        #expect(run(&controller, tapSteps(p, time: 1, held: 0.6), view: view, snapshot: drawn, c: c).actions.isEmpty)
    }

    @Test func endDragsFollowTheColumnAndNeverCross() throws {
        let c: Case = try cases(Self.levels[0])[0]
        let drawn: Snapshot = snapshot(c, 3, 9)
        let count: Int = drawn.count
        for view in [Self.views[1], Self.views[2]] {
            let startDown: Vec2 = try #require(endPoint(true, drawn, view: view, orbit: .authored))
            let endDown: Vec2 = try #require(endPoint(false, drawn, view: view, orbit: .authored))
            #expect(pick(startDown, snapshot: drawn, view: view, orbit: .authored) == .start)
            #expect(pick(endDown, snapshot: drawn, view: view, orbit: .authored) == .end)
            let right: Vec2 = try #require(planePoint(Double(count - 1), 0, snapshot: drawn, view: view,
                                                      orbit: .authored))
            let left: Vec2 = try #require(planePoint(0, 0, snapshot: drawn, view: view, orbit: .authored))
            var controller: Controller = Controller()
            var got: Outcome = run(&controller, path(startDown, right, steps: 8, view: view, time: 1), view: view,
                                   snapshot: drawn, c: c)
            #expect(got.actions.last == .setStart(8))
            for a in got.actions {
                if case let .setStart(k) = a { #expect(k > 3 && k <= 8) } else { Issue.record("not a start: \(a)") }
            }
            controller = Controller()
            got = run(&controller, path(endDown, left, steps: 8, view: view, time: 1), view: view, snapshot: drawn,
                      c: c)
            #expect(got.actions.last == .setEnd(4))
            controller = Controller()
            got = run(&controller, path(startDown, left, steps: 4, view: view, time: 1), view: view, snapshot: drawn,
                      c: c)
            #expect(got.actions.last == .setStart(0))
            controller = Controller()
            got = run(&controller, path(endDown, right, steps: 4, view: view, time: 1), view: view, snapshot: drawn,
                      c: c)
            #expect(got.actions.last == .setEnd(count - 1))
            // A tap on an end changes nothing.
            controller = Controller()
            #expect(run(&controller, tapSteps(endDown, time: 1, held: 0.1), view: view, snapshot: drawn,
                        c: c).actions.isEmpty)
        }
    }

    @Test func aHeldPressFreezesByEventTimeAndNeverSwipes() throws {
        let c: Case = try cases(Self.levels[2])[0]
        let drawn: Snapshot = snapshot(c, 2, 7)
        let view: Vec2 = Self.views[1]
        let band: Vec2 = try #require(planePoint(4, 0.1, snapshot: drawn, view: view, orbit: .authored))
        let sample: Vec2 = try #require(planePoint(Double(drawn.count - 1), 0.1, snapshot: drawn, view: view,
                                                   orbit: .authored))
        let wanted: Preview? = Preview.make(play: c.play, start: 2, end: 7)
        func send(_ ctl: inout Controller, _ e: PointerEvent) -> [Action] {
            ctl.handle(e, viewSize: view, snapshot: drawn, play: c.play)
        }
        // Before 0.5 s nothing; at 0.5 s a freeze; moving sideways keeps it; lifting sends nothing.
        var controller: Controller = Controller()
        var actions: [Action] = send(&controller, event(1, .began, band, 1))
        controller.tick(at: 1.49, snapshot: drawn, play: c.play)
        #expect(controller.state == .bandPress && controller.preview == nil)
        controller.tick(at: .nan, snapshot: drawn, play: c.play)
        #expect(controller.state == .bandPress)
        controller.tick(at: 1.5, snapshot: drawn, play: c.play)
        #expect(controller.state == .freeze && controller.preview == wanted)
        actions += send(&controller, event(1, .moved, band + Vec2(200, 0), 1.6))
        #expect(controller.state == .freeze && controller.preview == wanted)
        actions += send(&controller, event(1, .ended, band + Vec2(200, 0), 1.7))
        #expect(actions.isEmpty && controller.state == .idle && controller.preview == nil)
        // A press that moved 12 points never freezes.
        controller = Controller()
        actions = send(&controller, event(1, .began, band, 2))
        actions += send(&controller, event(1, .moved, band + Vec2(0, 12), 2.1))
        controller.tick(at: 2.8, snapshot: drawn, play: c.play)
        #expect(controller.state == .bandPress && controller.preview == nil)
        actions += send(&controller, event(1, .ended, band + Vec2(0, 12), 2.9))
        #expect(actions.isEmpty)
        // A sample press never freezes.
        controller = Controller()
        actions = send(&controller, event(1, .began, sample, 3))
        #expect(controller.state == .samplePress)
        controller.tick(at: 4, snapshot: drawn, play: c.play)
        #expect(controller.state == .samplePress && controller.preview == nil)
        actions += send(&controller, event(1, .ended, sample, 4.1))
        #expect(actions.isEmpty)
        // Without ticks, a late small move freezes by its timestamp; a later swipe-like move sends nothing.
        controller = Controller()
        actions = send(&controller, event(1, .began, band, 5))
        actions += send(&controller, event(1, .moved, band + Vec2(2, 1), 5.6))
        #expect(controller.state == .freeze && controller.preview == wanted)
        actions += send(&controller, event(1, .moved, band + Vec2(-180, 0), 5.7))
        actions += send(&controller, event(1, .ended, band + Vec2(-180, 0), 5.8))
        #expect(actions.isEmpty)
        // A held press lifted late without any tick or move sends nothing; a quick swipe after a short wait reverses.
        controller = Controller()
        actions = send(&controller, event(1, .began, band, 6))
        actions += send(&controller, event(1, .ended, band, 6.7))
        #expect(actions.isEmpty)
        controller = Controller()
        actions = send(&controller, event(1, .began, band, 7))
        controller.tick(at: 7.3, snapshot: drawn, play: c.play)
        actions += send(&controller, event(1, .moved, band + Vec2(120, 10), 7.4))
        #expect(controller.state == .swipe && controller.preview == wanted)
        controller.tick(at: 8, snapshot: drawn, play: c.play)
        #expect(controller.state == .swipe)
        actions += send(&controller, event(1, .ended, band + Vec2(120, 10), 8.1))
        #expect(actions == [.reverse(2, 7)])
    }

    @Test func aDoubleTapOnEmptySpaceResetsTheView() throws {
        let c: Case = try cases(Self.levels[0])[0]
        let drawn: Snapshot = snapshot(c, 2, 6)
        for view in Self.views {
            let turnedOrbit: Orbit = Self.orbits[1]
            var controller: Controller = try self.controller(at: turnedOrbit, view: view, snapshot: drawn, c: c)
            let e: Vec2 = try #require(emptyPoint(drawn, view: view, orbit: turnedOrbit))
            let inward: Vec2 = Vec2(e.x < view.x / 2 ? 1 : -1, e.y < view.y / 2 ? 1 : -1)
            func tapAt(_ ctl: inout Controller, _ p: Vec2, _ t: Double) -> [Action] {
                run(&ctl, tapSteps(p, time: t, held: 0.05), view: view, snapshot: drawn, c: c).actions
            }
            #expect(tapAt(&controller, e, 1).isEmpty)
            #expect(tapAt(&controller, e + Vec2(30 * inward.x, 0), 1.2).isEmpty)          // too far: a new first tap
            #expect(tapAt(&controller, e + Vec2(30 * inward.x, 0), 1.8).isEmpty)          // too late: a new first tap
            #expect(near(controller.orbit, turnedOrbit))
            #expect(tapAt(&controller, e + Vec2(30 * inward.x, 5 * inward.y), 2.0) == [.resetView])
            #expect(controller.orbit == .authored)
            #expect(tapAt(&controller, e + Vec2(30 * inward.x, 5 * inward.y), 2.2).isEmpty)  // a third tap starts anew
            let back: Controller = controller
            controller = try self.controller(at: turnedOrbit, view: view, snapshot: drawn, c: c)
            controller.resetView()
            #expect(controller.orbit == back.orbit)
            #expect(controller.camera(viewSize: view, snapshot: drawn)
                    == Geometry.camera(drawn, aspect: view.x / view.y))
            #expect(controller.camera(viewSize: Vec2(0, 10), snapshot: drawn) == nil)
        }
    }

    @Test func orbitFollowsClampsAndRebases() throws {
        let c: Case = try cases(Self.levels[0])[0]
        let drawn: Snapshot = snapshot(c, 2, 6)
        let view: Vec2 = Self.views[1]
        let a: Vec2 = try #require(emptyPoint(drawn, view: view, orbit: .authored))
        let b: Vec2 = Vec2(view.x / 2, view.y / 2)
        var controller: Controller = Controller()
        #expect(twoFingers(&controller, a: a, b: b, by: Vec2(view.x / 8, 0), view: view, snapshot: drawn, c: c,
                           time: 0).isEmpty)
        #expect(abs(controller.orbit.yaw - Double.pi / 16) < 1e-12)
        #expect(abs(controller.orbit.pitch) < 1e-12)
        #expect(twoFingers(&controller, a: a, b: b, by: Vec2(2 * view.x, -view.y), view: view, snapshot: drawn, c: c,
                           time: 1).isEmpty)
        #expect(controller.orbit == Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound))
        #expect(twoFingers(&controller, a: a, b: b, by: Vec2(-4 * view.x, 2 * view.y), view: view, snapshot: drawn,
                           c: c, time: 2).isEmpty)
        #expect(controller.orbit == Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound))
        // A third finger re-bases the midpoint: its touch-down turns nothing, its move by dx turns by dx / 3.
        controller = Controller()
        func send(_ e: PointerEvent) -> [Action] {
            controller.handle(e, viewSize: view, snapshot: drawn, play: c.play)
        }
        var actions: [Action] = send(event(1, .began, a, 0))
        actions += send(event(2, .began, b, 0.01))
        #expect(controller.state == .orbiting)
        actions += send(event(3, .began, Vec2(view.x - 10, 10), 0.02))
        #expect(controller.orbit == .authored)
        actions += send(event(3, .moved, Vec2(view.x - 10 - 90, 10), 0.03))
        #expect(abs(controller.orbit.yaw - (-30 / view.x * Double.pi / 2)) < 1e-12)
        actions += send(event(3, .ended, Vec2(view.x - 100, 10), 0.04))
        #expect(controller.state == .cancelled)
        actions += send(event(1, .moved, a + Vec2(200, 0), 0.05))
        #expect(abs(controller.orbit.yaw - (-30 / view.x * Double.pi / 2)) < 1e-12)
        actions += send(event(1, .ended, a, 0.06))
        actions += send(event(2, .ended, b, 0.07))
        #expect(actions.isEmpty && controller.state == .idle)
    }

    @Test func previewsAndOrbitNeverChangeTheDigest() throws {
        let level: [Case] = try cases(Self.levels[3])
        for c in level {
            let before: String = try digest(c.core)
            let drawn: Snapshot = snapshot(c, 1, 6)
            for view in Self.views {
                for orbit in Self.orbits {
                    var controller: Controller = try self.controller(at: orbit, view: view, snapshot: drawn, c: c)
                    var k: Double = 1
                    while k <= 6 {
                        if let p = planePoint(k, 0, snapshot: drawn, view: view, orbit: orbit) {
                            _ = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: drawn,
                                                  play: c.play)
                            controller.tick(at: 1.6, snapshot: drawn, play: c.play)
                            if let preview = controller.preview {
                                checkPreview(preview, play: c.play)
                                let shown: Snapshot = drawn.withPreview(preview.samples)
                                #expect(shown.preview == preview.samples && shown.samples == drawn.samples)
                            }
                            controller.cancel()
                        }
                        k += 1
                    }
                    #expect(try digest(c.core) == before)
                    #expect(near(controller.orbit, orbit))
                }
            }
        }
    }
}
