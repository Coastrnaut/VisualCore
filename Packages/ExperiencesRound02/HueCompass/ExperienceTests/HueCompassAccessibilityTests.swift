// HueCompassAccessibilityTests — feature 336 (R02-G04-06) T-R02G0406-006 (FR-R02G0406-001 … 006;
// SC-R02G0406-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on Wave
// Knot Keeper's feature-326 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; refusals (undo with
// nothing to undo, a value that is not whole, a locked level), turns, undo, redo, a probe, a band pick, a win, a fresh
// play and a failure record exactly `HueCompassFeedbackPlan.after(old:new:)`, `picked(band:)` and `refused(code:)` in
// the sinks and in the presenter's feedback log (the texts are also written out from clarification Q1), and the panel
// shows the refusal's words. Level 1 is won with what the panel's buttons send alone: the turn buttons (`compass.turn`
// of ±1 and ±4), Probe (`compass.probe`), the band stepper (`pickBand`) and Select (`compass.select` of the mirror's
// bearing and picked band); every step is announced and the win is an outcome with a success haptic. A swipe in
// progress (finger down and moved, not released) announces nothing; its released turn is announced once. Sound: the
// presenter makes its own `HueCompassSound` with the real `AmbientLoopPlayer`, so the state table, the offers and a
// failing `play()` use a `HueCompassSound` with a fake player; the presenter's sound is only driven with the sound off
// or off screen (no audio starts): its recipe follows level openings, new clues and play ends, and a turn leaves it as
// it was. Reduce Flashing: the drawn lights (every probe mark, the selection mark, the target ring and the win glow)
// are sampled through off-screen stills at frame times 1/60 s apart over a probe and retry flicker, a turn and undo
// flicker and a win; no element crosses half its range more than 3 times per second and every complete one-way fade of
// more than half the range takes at least 0.4 s; the glow-shell gain rises after the win while the gain limit stays
// 0.5. Reduce Motion: two stills at different times are byte-identical and the drawn snapshot keeps time 0. Labels:
// SwiftUI's accessibility tree is not inspectable from a unit test, so the label and value strings built outside the
// view body (turn titles and spoken names, the progress value, the goal line, mode names, level titles, the summary
// element's words), the mirror values the modifiers read, the controls' action coverage and the panel's layout at the
// largest accessibility text size (320 and 1024 points wide) are checked. Synthetic data, explicit types, plain loops,
// no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import CoreGraphics
import Foundation
import HueCompassCore
import SwiftUI
import Testing
import UIKit
@testable import HueCompassExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class HueCompassAccessClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class HueCompassFakeLoop: HueCompassLoopPlaying {
    /// Whether `play()` may play.
    var isEnabled: Bool = false
    /// Whether the loop plays.
    private(set) var isPlaying: Bool = false
    /// How many times `play()` was called.
    private(set) var plays: Int = 0
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0
    /// Whether `play()` succeeds.
    let succeeds: Bool

    /// A fake loop whose `play()` succeeds when `succeeds` is true.
    init(succeeds: Bool) {
        self.succeeds = succeeds
    }

    /// Starts the loop when enabled and `succeeds`; false otherwise.
    @discardableResult
    func play() -> Bool {
        plays += 1
        guard isEnabled, succeeds else { return false }
        isPlaying = true
        return true
    }

    /// Stops the loop.
    func stop() {
        stops += 1
        isPlaying = false
    }
}

/// Makes fake loops and keeps them.
@MainActor
final class HueCompassFakeLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [HueCompassFakeLoop] = []

    /// Makes and keeps one fake loop.
    func make() -> HueCompassFakeLoop {
        let loop: HueCompassFakeLoop = HueCompassFakeLoop(succeeds: succeeds)
        made.append(loop)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> HueCompassSound {
        HueCompassSound(recipe: recipe, makePlayer: { _ in self.make() })
    }
}

/// One drawn frame's light levels: every probe mark by bearing, the selection mark, the target ring and the win glow.
struct HueCompassLightSample {
    /// The probe-mark levels by bearing (a bearing missing here is at 0).
    let probes: [Int: Double]
    /// The selection mark's level (0 when absent).
    let selection: Double
    /// The target ring's level (0 when absent).
    let ring: Double
    /// The win glow.
    let glow: Double
}

/// Helpers of the accessibility tests.
@MainActor
enum HueCompassAccess {
    typealias Shell = ExperienceShell<HueCompassPresenter>
    typealias Plan = HueCompassFeedbackPlan

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: HueCompassAccessClock
    }

    /// The still size of the Reduce Flashing and Reduce Motion tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64
    /// The frame rate of the sampled stills.
    static let frameRate: Double = 60
    /// The readable width of the panel, padding included (clarification Q5).
    static let readableWidth: CGFloat = 520

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        try await HueCompassTest.open(session, seed: seed, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing,
                                      size: CGSize(width: 360, height: 240))
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: HueCompassAccessClock = HueCompassAccessClock()
        shell.presenter.feedback = ExperienceFeedback(hapticSink: haptics, announcementSink: announcements,
                                                      clock: { clock.now }, voiceOverRunning: { true })
        return Recorder(haptics: haptics, announcements: announcements, clock: clock)
    }

    /// Injects a route that records into throwaway sinks with VoiceOver off (no system haptic or announcement).
    static func quiet(_ shell: Shell) {
        shell.presenter.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(),
                                                      announcementSink: RecordingAnnouncementSink(),
                                                      voiceOverRunning: { false })
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> HueCompassExperienceCore {
        try HueCompassTest.core(shell)
    }

    /// The texts of `plans` that are announced, in order.
    static func texts(_ plans: [Plan]) -> [String] {
        var result: [String] = []
        for plan in plans {
            if let text = plan.text, plan.kind != nil { result.append(text) }
        }
        return result
    }

    /// The feedback log entries after the first `count`.
    static func log(_ presenter: HueCompassPresenter, after count: Int) -> [Plan] {
        Array(presenter.feedbackLog.dropFirst(count))
    }

    /// "1 band" or "g bands", written out here.
    static func bandsText(_ count: Int) -> String { count == 1 ? "1 band" : "\(count) bands" }

    /// "1 unit" or "s units", written out here.
    static func unitsText(_ count: Int) -> String { count == 1 ? "1 unit" : "\(count) units" }

    /// The turn announcement of `core` with `prefix` ("", "Undone: ", "Redone: "), written out from clarification Q1.
    static func turnText(_ core: HueCompassExperienceCore, prefix: String = "") -> String {
        let play: HueCompassPlay = core.play
        let band: Int = play.level.band(of: play.bearing) + 1
        return "\(prefix)Bearing \(play.bearing) of 96, band \(band). Units left \(play.level.allowance - play.spent) of \(play.level.allowance)."
    }

    /// The probe announcement of `core` (its last clue), written out from clarification Q1.
    static func probeText(_ core: HueCompassExperienceCore) throws -> String {
        let play: HueCompassPlay = core.play
        let clue: HueCompassClue = try #require(play.clues.last)
        return "Probe at bearing \(clue.bearing): hue gap \(bandsText(clue.hueGap)), fog depth \(clue.depth). "
            + "Units left \(play.level.allowance - play.spent) of \(play.level.allowance)."
    }

    /// The win announcement of `core` in campaign, written out from clarification Q1.
    static func winText(_ core: HueCompassExperienceCore) -> String {
        let spent: Int = core.play.spent
        let stars: Int = HueCompassProgress.stars(units: spent, smallest: core.certifiedSmallest)
        return "The bearing and band match. Level won with \(unitsText(spent)), \(stars) of 3 stars."
    }

    /// The level announcement of `core`, written out: "Level n, band b, <mode>." and the tutorial instruction.
    static func levelText(_ core: HueCompassExperienceCore, mode: String) -> String {
        var text: String = "Level \(core.levelNumber), band \(core.play.level.band), \(mode)."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return text
    }

    /// The turn-button steps (from ``HueCompassControls/turns``) that take `from` to `to` the shorter way round:
    /// as many ±4 as fit, then ±1.
    static func turnSteps(from: Int, to: Int) -> [Int] {
        let bearings: Int = HueCompassWheel.bearings
        let forward: Int = ((to - from) % bearings + bearings) % bearings
        let sign: Int = forward <= bearings / 2 ? 1 : -1
        var left: Int = sign > 0 ? forward : bearings - forward
        var steps: [Int] = []
        while left >= 4 {
            steps.append(4 * sign)
            left -= 4
        }
        while left > 0 {
            steps.append(sign)
            left -= 1
        }
        return steps
    }

    /// The band the stepper's increment (+1) or decrement (−1) picks from `band`, as `HueCompassControls` computes it.
    static func stepperNext(_ band: Int, delta: Int) -> Int {
        delta > 0 ? (band + 1) % 24 : (band + 23) % 24
    }

    /// The stepper direction (+1 or −1) and the number of presses from `current` to `target`, the shorter way round.
    static func stepperPresses(from current: Int, to target: Int) -> (delta: Int, presses: Int) {
        let forward: Int = ((target - current) % 24 + 24) % 24
        if forward <= 12 { return (1, forward) }
        return (-1, 24 - forward)
    }

    /// Draws an off-screen still of `session` at frame time `time` and returns the presenter's drawn light levels.
    static func sample(_ session: ExperienceSession, _ presenter: HueCompassPresenter,
                       time: Double) throws -> HueCompassLightSample {
        _ = try HueCompassTest.still(session, width: stillWidth, height: stillHeight, time: time)
        let lights: HueCompassLights = presenter.lights
        return HueCompassLightSample(probes: lights.probes, selection: lights.selection?.level ?? 0,
                                     ring: lights.ring?.level ?? 0, glow: lights.glow)
    }

    /// The samples as one vector per frame over every probe bearing seen (sorted; 0 where absent), then the selection,
    /// the ring and the glow.
    static func vectors(_ samples: [HueCompassLightSample]) -> [[Double]] {
        var seen: Set<Int> = []
        for sample in samples {
            for key in sample.probes.keys { seen.insert(key) }
        }
        let keys: [Int] = seen.sorted()
        var result: [[Double]] = []
        for sample in samples {
            var row: [Double] = []
            for key in keys { row.append(sample.probes[key] ?? 0) }
            row.append(sample.selection)
            row.append(sample.ring)
            row.append(sample.glow)
            result.append(row)
        }
        return result
    }

    /// Whether any value of `vectors` lies strictly between 0 and 1 (a light caught mid-fade).
    static func anyMidFade(_ vectors: [[Double]]) -> Bool {
        for row in vectors {
            for value in row where value > 0 && value < 1 { return true }
        }
        return false
    }

    /// The shortest time in seconds of a complete one-way fade of more than half the range of any element (a run of
    /// consecutive frame steps moving the same way; a step without change ends it; a run still moving at the last
    /// sample is skipped); `.infinity` when there is none. Written out here (clarification Q3's measure).
    static func shortestFade(_ vectors: [[Double]], frameRate: Double) -> Double {
        guard vectors.count >= 2 else { return .infinity }
        let width: Int = vectors.map(\.count).min() ?? 0
        var shortest: Double = .infinity
        for element in 0..<width {
            var direction: Int = 0
            var start: Double = vectors[0][element]
            var steps: Int = 0
            for frame in 1..<vectors.count {
                let before: Double = vectors[frame - 1][element]
                let after: Double = vectors[frame][element]
                let sign: Int = after > before ? 1 : (after < before ? -1 : 0)
                if sign != direction {
                    if direction != 0 && Swift.abs(before - start) > 0.5 {
                        shortest = Swift.min(shortest, Double(steps) / frameRate)
                    }
                    direction = sign
                    start = before
                    steps = 0
                }
                if sign != 0 { steps += 1 }
            }
        }
        return shortest
    }

    /// The first `UIScrollView` in `view`'s hierarchy (breadth first), or nil.
    static func scrollView(in view: UIView) -> UIScrollView? {
        var queue: [UIView] = [view]
        var index: Int = 0
        while index < queue.count {
            let current: UIView = queue[index]
            index += 1
            if let scroll = current as? UIScrollView { return scroll }
            for sub in current.subviews { queue.append(sub) }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct HueCompassAccessibilityTests {
    typealias Access = HueCompassAccess
    typealias Script = HueCompassGestureScript
    typealias Plan = HueCompassFeedbackPlan
    typealias Presenter = HueCompassPresenter

    // MARK: Recorded feedback (FR-R02G0406-002, 003; SC-R02G0406-002)

    /// Refusals, two turns, undo, redo, a probe, a band pick, a locked level, a win, a fresh play and a failure:
    /// the sinks receive exactly the plans of `HueCompassFeedbackPlan`, in order, and the feedback log holds the same
    /// plans; texts written out; the panel shows each refusal's words.
    @Test func recordedFeedbackThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let announcedBase: Int = presenter.announcements.count
        var expected: [Plan] = []
        let opening: HueCompassExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        try #require(opening.play.level.allowance >= 2, "a probe leaves level 1 playing")

        // A refusal: undo with nothing to undo.
        var digest: String = try HueCompassTest.digest(shell)
        recorder.clock.advance()
        let noUndo: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(!noUndo.isAccepted)
        #expect(noUndo.code.contains("r02-g04.action"), "\(noUndo.code)")
        let noUndoPlan: Plan = Plan.refused(code: noUndo.code)
        #expect(noUndoPlan.text == "That action is not allowed here.", "\(noUndoPlan.text ?? "nil")")
        #expect(noUndoPlan.kind == .rejection)
        #expect(noUndoPlan.haptic == .error)
        #expect(presenter.mirror.message == "That action is not allowed here.", "the panel shows the same words")
        #expect(try HueCompassTest.digest(shell) == digest, "a refusal changes nothing")
        expected.append(noUndoPlan)

        // A refusal: a value that is not whole.
        recorder.clock.advance()
        let half: ActionResult = presenter.send("compass.turn", [0.5], port: shell.port)
        #expect(!half.isAccepted)
        #expect(half.code.contains(HueCompassExperienceRule.notWhole), "\(half.code)")
        let halfPlan: Plan = Plan.refused(code: half.code)
        #expect(halfPlan.text == "That value must be a whole number.", "\(halfPlan.text ?? "nil")")
        #expect(halfPlan.kind == .rejection)
        #expect(halfPlan.haptic == .error)
        #expect(presenter.mirror.message == halfPlan.text)
        #expect(try HueCompassTest.digest(shell) == digest)
        expected.append(halfPlan)

        // Two accepted turns: state announcements with a selection haptic.
        var previous: HueCompassExperienceCore = opening
        let turns: [Int] = [1, -4]
        for steps in turns {
            recorder.clock.advance()
            let turned: ActionResult = presenter.send("compass.turn", [Double(steps)], port: shell.port)
            #expect(turned == .accepted, "\(turned.code)")
            #expect(presenter.mirror.message == nil, "an accepted action clears the refusal")
            let next: HueCompassExperienceCore = try Access.core(shell)
            let plan: Plan = Plan.after(old: previous, new: next)
            #expect(plan.text == Access.turnText(next), "\(plan.text ?? "nil")")
            #expect(plan.text == Plan.turnText(next))
            #expect(plan.kind == .state)
            #expect(plan.haptic == .selection)
            expected.append(plan)
            previous = next
        }

        // Undo and redo name the bearing after them with their prefix.
        recorder.clock.advance()
        let undone: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: HueCompassExperienceCore = try Access.core(shell)
        let undoPlan: Plan = Plan.after(old: previous, new: afterUndo)
        #expect(undoPlan.text == Access.turnText(afterUndo, prefix: "Undone: "), "\(undoPlan.text ?? "nil")")
        #expect(undoPlan.kind == .state)
        #expect(undoPlan.haptic == .selection)
        expected.append(undoPlan)

        recorder.clock.advance()
        let redone: ActionResult = presenter.send("play.redo", [], port: shell.port)
        #expect(redone == .accepted, "\(redone.code)")
        let afterRedo: HueCompassExperienceCore = try Access.core(shell)
        let redoPlan: Plan = Plan.after(old: afterUndo, new: afterRedo)
        #expect(redoPlan.text == Access.turnText(afterRedo, prefix: "Redone: "), "\(redoPlan.text ?? "nil")")
        #expect(redoPlan.kind == .state)
        #expect(redoPlan.haptic == .selection)
        expected.append(redoPlan)

        // A probe: the clue in words.
        recorder.clock.advance()
        let probed: ActionResult = presenter.send("compass.probe", [], port: shell.port)
        #expect(probed == .accepted, "\(probed.code)")
        let afterProbe: HueCompassExperienceCore = try Access.core(shell)
        try #require(afterProbe.play.stage == .playing)
        let probePlan: Plan = Plan.after(old: afterRedo, new: afterProbe)
        let probeWords: String = try Access.probeText(afterProbe)
        #expect(probePlan.text == probeWords, "\(probePlan.text ?? "nil")")
        #expect(probePlan.kind == .state)
        #expect(probePlan.haptic == .selection)
        expected.append(probePlan)

        // A band pick: "Band h picked.", no haptic, the state unchanged.
        digest = try HueCompassTest.digest(shell)
        recorder.clock.advance()
        presenter.pickBand(5)
        #expect(presenter.mirror.pickedBand == 5)
        let pickPlan: Plan = Plan.picked(band: 5)
        #expect(pickPlan.text == "Band 6 picked.")
        #expect(pickPlan.kind == .state)
        #expect(pickPlan.haptic == nil)
        #expect(try HueCompassTest.digest(shell) == digest, "a band pick is presentation only")
        expected.append(pickPlan)

        // A refusal: a locked level.
        recorder.clock.advance()
        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(!locked.isAccepted)
        #expect(locked.code.contains(HueCompassExperienceRule.locked), "\(locked.code)")
        let lockedPlan: Plan = Plan.refused(code: locked.code)
        #expect(lockedPlan.text == "That level is not open yet.", "\(lockedPlan.text ?? "nil")")
        #expect(lockedPlan.kind == .rejection)
        #expect(lockedPlan.haptic == .error)
        #expect(presenter.mirror.message == "That level is not open yet.")
        #expect(try HueCompassTest.digest(shell) == digest)
        expected.append(lockedPlan)

        // A win: the target's bearing and band selected.
        let level: HueCompassLevel = afterProbe.play.level
        recorder.clock.advance()
        let selected: ActionResult = presenter.send("compass.select", [Double(level.target), Double(level.targetBand)],
                                                    port: shell.port)
        #expect(selected == .accepted, "\(selected.code)")
        let won: HueCompassExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        let winPlan: Plan = Plan.after(old: afterProbe, new: won)
        #expect(winPlan.text == Access.winText(won), "\(winPlan.text ?? "nil")")
        #expect(winPlan.kind == .outcome)
        #expect(winPlan.haptic == .success)
        expected.append(winPlan)

        // A fresh play of level 1: a level announcement, no haptic.
        recorder.clock.advance()
        let fresh: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(fresh == .accepted, "\(fresh.code)")
        let reopened: HueCompassExperienceCore = try Access.core(shell)
        let levelPlan: Plan = Plan.after(old: won, new: reopened)
        #expect(levelPlan.text == Access.levelText(reopened, mode: "Campaign"), "\(levelPlan.text ?? "nil")")
        #expect(levelPlan.kind == .level)
        #expect(levelPlan.haptic == nil)
        expected.append(levelPlan)

        // A failure: a selection half the compass away with the opposite band.
        let missBearing: Int = (level.target + HueCompassWheel.bearings / 2) % HueCompassWheel.bearings
        let missBand: Int = (level.targetBand + HueCompassWheel.bands / 2) % HueCompassWheel.bands
        recorder.clock.advance()
        let missed: ActionResult = presenter.send("compass.select", [Double(missBearing), Double(missBand)],
                                                  port: shell.port)
        #expect(missed == .accepted, "\(missed.code)")
        let failed: HueCompassExperienceCore = try Access.core(shell)
        #expect(failed.play.stage == .failed)
        let failPlan: Plan = Plan.after(old: reopened, new: failed)
        let explanation: String = try #require(failed.failureExplanation?.text)
        #expect(failPlan.text == explanation, "\(failPlan.text ?? "nil")")
        #expect(failPlan.kind == .outcome)
        #expect(failPlan.haptic == .warning)
        expected.append(failPlan)

        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == expected.compactMap { $0.haptic })
        #expect(Array(presenter.announcements.dropFirst(announcedBase)) == Access.texts(expected))
        #expect(recorder.announcements.announced.count == expected.count, "every plan here is announced")
    }

    // MARK: The panel alone (SC-R02G0406-001)

    /// Level 1 (seed 0) is won with what the panel's buttons send alone: the turn buttons to the target bearing, one
    /// probe, the band stepper to the target band and Select; every step announced, the win an outcome with a success
    /// haptic.
    @Test func levelOneWonWithTheAccessibleControls() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: HueCompassExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        let level: HueCompassLevel = opening.play.level
        try #require(level.allowance >= 2, "a probe and a selection fit level 1")
        var announced: Int = 0

        // The turn buttons, from the mirror's bearing to the target, the shorter way round.
        let steps: [Int] = Access.turnSteps(from: presenter.mirror.bearing, to: level.target)
        var previous: HueCompassExperienceCore = opening
        for (index, step) in steps.enumerated() {
            #expect(HueCompassControls.turns.contains(step), "step \(index): \(step) is a turn button")
            recorder.clock.advance()
            let result: ActionResult = presenter.send("compass.turn", [Double(step)], port: shell.port)
            #expect(result == .accepted, "step \(index): \(result.code)")
            let next: HueCompassExperienceCore = try Access.core(shell)
            let text: String = Access.turnText(next)
            announced += 1
            #expect(presenter.announcements.last == text, "\(presenter.announcements.last ?? "nil")")
            #expect(recorder.announcements.announced.last == text)
            previous = next
        }
        #expect(presenter.mirror.bearing == level.target, "the turn buttons reached the target bearing")
        #expect(previous.play.bearing == level.target)

        // Probe.
        recorder.clock.advance()
        let probed: ActionResult = presenter.send("compass.probe", [], port: shell.port)
        #expect(probed == .accepted, "\(probed.code)")
        let afterProbe: HueCompassExperienceCore = try Access.core(shell)
        try #require(afterProbe.play.stage == .playing)
        let probeText: String = try Access.probeText(afterProbe)
        announced += 1
        #expect(presenter.announcements.last == probeText, "\(presenter.announcements.last ?? "nil")")
        #expect(recorder.announcements.announced.last == probeText)

        // The band stepper, from the picked band to the target band.
        let way: (delta: Int, presses: Int) = Access.stepperPresses(from: presenter.mirror.pickedBand,
                                                                    to: level.targetBand)
        for _ in 0..<way.presses {
            let band: Int = Access.stepperNext(presenter.mirror.pickedBand, delta: way.delta)
            recorder.clock.advance()
            presenter.pickBand(band)
            announced += 1
            let text: String = "Band \(band + 1) picked."
            #expect(presenter.mirror.pickedBand == band)
            #expect(presenter.announcements.last == text, "\(presenter.announcements.last ?? "nil")")
            #expect(recorder.announcements.announced.last == text)
        }
        #expect(presenter.mirror.pickedBand == level.targetBand, "the stepper reached the target band")

        // Select: the mirror's bearing with the picked band.
        recorder.clock.advance()
        let selected: ActionResult = presenter.send("compass.select", [Double(presenter.mirror.bearing),
                                                                       Double(presenter.mirror.pickedBand)],
                                                    port: shell.port)
        #expect(selected == .accepted, "\(selected.code)")
        announced += 1
        let won: HueCompassExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        let winText: String = Access.winText(won)
        let plans: [Plan] = Access.log(presenter, after: logBase)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(presenter.announcements.last == winText)
        #expect(recorder.announcements.announced.last == winText)
        #expect(recorder.announcements.announced.count == announced, "every step announced")
        #expect(plans.count == announced)
        #expect(recorder.haptics.played == plans.compactMap { $0.haptic }, "\(recorder.haptics.played)")
        #expect(recorder.haptics.played.last == .success)
        #expect(presenter.mirror.stage == .won)
    }

    // MARK: Gesture preview (edge case)

    /// A swipe in progress (finger down and moved, not released) adds no announcement, plan or haptic; the release
    /// announces its turn once.
    @Test func aSwipePreviewIsNotAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let announcedBase: Int = presenter.announcements.count
        let before: HueCompassExperienceCore = try Access.core(shell)
        let digest: String = try HueCompassTest.digest(shell)
        let k: Int = 7
        var time: Double = 0

        recorder.clock.advance()
        let points: [Vec2] = try Script.swipeWithoutRelease(shell, steps: k, time: &time)
        #expect(presenter.gestures.previewBearing == Script.turned(before.play.bearing, by: k), "the swipe previews")
        #expect(recorder.announcements.announced.isEmpty, "the preview is not announced")
        #expect(presenter.feedbackLog.count == logBase, "the preview plans nothing")
        #expect(presenter.announcements.count == announcedBase)
        #expect(recorder.haptics.played.isEmpty, "the preview plays no haptic")
        #expect(try HueCompassTest.digest(shell) == digest, "nothing is sent before the release")

        recorder.clock.advance()
        Script.touch(shell, id: 1, .ended, at: points[points.count - 1], time: &time)
        let after: HueCompassExperienceCore = try Access.core(shell)
        #expect(after.play.bearing == Script.turned(before.play.bearing, by: k), "exactly one turn of \(k)")
        let plan: Plan = Plan.after(old: before, new: after)
        #expect(plan.text == Access.turnText(after), "\(plan.text ?? "nil")")
        #expect(plan.haptic == .selection)
        let expected: [Plan] = [plan]
        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(Array(presenter.announcements.dropFirst(announcedBase)) == Access.texts(expected),
                "the release is announced once")
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == expected.compactMap { $0.haptic })
    }

    // MARK: Sound (FR-R02G0406-006; SC-R02G0406-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; each input turned off stops the loop and on again plays it with the same player.
    @Test func soundStateTable() throws {
        let quiet: AmbientLoopRecipe = HueCompassSoundRecipe.recipe(clue: nil, stage: .playing)
        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: HueCompassFakeLoopFactory = HueCompassFakeLoopFactory()
            let sound: HueCompassSound = factory.sound(quiet)
            sound.setOnScreen(onScreen)
            sound.setActive(active)
            sound.setWanted(wanted)
            let expected: Bool = wanted && onScreen && active
            #expect(sound.shouldPlay == expected, "combination \(combination)")
            #expect(sound.started == expected, "combination \(combination)")
            #expect(sound.playersMade == (expected ? 1 : 0), "combination \(combination)")
            #expect((factory.made.last?.isPlaying ?? false) == expected, "combination \(combination)")
            if !wanted {
                #expect(factory.made.isEmpty, "sound off makes no player (combination \(combination))")
                #expect(sound.player == nil)
            }
        }

        let factory: HueCompassFakeLoopFactory = HueCompassFakeLoopFactory()
        let sound: HueCompassSound = factory.sound(quiet)
        sound.setOnScreen(true)
        sound.setWanted(true)
        let loop: HueCompassFakeLoop = try #require(factory.made.first)
        #expect(loop.isPlaying)
        for input in 0..<3 {
            switch input {
            case 0: sound.setWanted(false)
            case 1: sound.setOnScreen(false)
            default: sound.setActive(false)
            }
            #expect(!loop.isPlaying, "input \(input) off stops")
            #expect(!sound.started)
            switch input {
            case 0: sound.setWanted(true)
            case 1: sound.setOnScreen(true)
            default: sound.setActive(true)
            }
            #expect(loop.isPlaying, "input \(input) on plays")
            #expect(sound.started)
        }
        #expect(sound.playersMade == 1, "the same recipe keeps its player")
    }

    /// Offers: a different recipe while playing makes a new player and stops the old one; the same recipe does not;
    /// any offer while the sound is off makes none but is kept for the next start. A `play()` that fails leaves
    /// `started` false and the choice on.
    @Test func soundOffersAndAFailingPlay() throws {
        let near: HueCompassClue = HueCompassClue(bearing: 10, hueGap: 3, depth: 10)
        let far: HueCompassClue = HueCompassClue(bearing: 40, hueGap: 9, depth: 60)
        let playing: AmbientLoopRecipe = HueCompassSoundRecipe.recipe(clue: near, stage: .playing)
        let other: AmbientLoopRecipe = HueCompassSoundRecipe.recipe(clue: far, stage: .playing)
        let won: AmbientLoopRecipe = HueCompassSoundRecipe.recipe(clue: near, stage: .won)
        try #require(playing != other, "another clue sounds different")
        try #require(playing != won, "a won play sounds different")

        let silent: HueCompassFakeLoopFactory = HueCompassFakeLoopFactory()
        let off: HueCompassSound = silent.sound(HueCompassSoundRecipe.recipe(clue: nil, stage: .loading))
        off.setOnScreen(true)
        off.offer(playing)
        off.offer(won)
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)
        #expect(off.recipe == won, "kept for the next start")

        let factory: HueCompassFakeLoopFactory = HueCompassFakeLoopFactory()
        let sound: HueCompassSound = factory.sound(playing)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1)
        sound.offer(playing)
        #expect(sound.playersMade == 1, "the same recipe keeps the player")
        sound.offer(other)
        #expect(sound.playersMade == 2, "a new recipe makes a new player")
        #expect(factory.made.count == 2)
        if factory.made.count == 2 {
            #expect(!factory.made[0].isPlaying, "the old player stopped")
            #expect(factory.made[1].isPlaying)
        }
        sound.offer(other)
        #expect(sound.playersMade == 2)
        sound.offer(won)
        #expect(sound.playersMade == 3)
        #expect(sound.playerRecipe == won)

        let failing: HueCompassFakeLoopFactory = HueCompassFakeLoopFactory()
        failing.succeeds = false
        let broken: HueCompassSound = failing.sound(playing)
        broken.setOnScreen(true)
        broken.setWanted(true)
        #expect(broken.playersMade == 1)
        #expect(!broken.started)
        #expect(broken.wanted)
        #expect(broken.shouldPlay)
        #expect(failing.made.first?.plays == 1)
        #expect(failing.made.first?.isPlaying == false)
        #expect(failing.made.first?.stops == 0)
    }

    /// The presenter's own sound (real `AmbientLoopPlayer`; never started here: the sound is off, or on while off
    /// screen): the first state's recipe is offered; a turn leaves it; a probe (a new clue), the end of a play and a
    /// level opening offer their recipe; turning the sound on keeps the choice on, makes no player and leaves the game
    /// unaffected.
    @Test func presenterSoundOffers() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        presenter.controlsAppeared()
        #expect(!presenter.sound.wanted)
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        let opening: HueCompassExperienceCore = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")

        // A turn: the recipe stays.
        let held: AmbientLoopRecipe = presenter.sound.recipe
        #expect(presenter.send("compass.turn", [4], port: shell.port) == .accepted)
        #expect(presenter.sound.recipe == held, "a turn does not change the recipe")

        // A probe offers the recipe of its clue.
        #expect(presenter.send("compass.probe", [], port: shell.port) == .accepted)
        let probed: HueCompassExperienceCore = try Access.core(shell)
        let clue: HueCompassClue = try #require(probed.play.clues.last)
        #expect(presenter.sound.recipe == HueCompassSoundRecipe.recipe(clue: clue, stage: .playing),
                "a new clue offers its recipe")

        // The end of the play offers the won recipe.
        let level: HueCompassLevel = probed.play.level
        #expect(presenter.send("compass.select", [Double(level.target), Double(level.targetBand)],
                               port: shell.port) == .accepted)
        let won: HueCompassExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(presenter.sound.recipe == HueCompassSoundRecipe.recipe(clue: clue, stage: .won),
                "the end of the play offers the won recipe")
        #expect(presenter.sound.recipe != HueCompassSoundRecipe.recipe(clue: clue, stage: .playing))

        // A level opening offers the opening recipe.
        #expect(presenter.send("level.select", [1], port: shell.port) == .accepted)
        let fresh: HueCompassExperienceCore = try Access.core(shell)
        #expect(fresh.play.clues.isEmpty)
        #expect(presenter.sound.recipe == HueCompassSoundRecipe.recipe(clue: nil, stage: .playing))

        // Turning the sound on while off screen: the choice is on, no player is made, the game goes on unaffected.
        presenter.controlsDisappeared()
        presenter.sceneActive(false)
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay)
        #expect(!presenter.sound.started)
        #expect(presenter.sound.recipe == Presenter.recipe(fresh))
        let digest: String = try HueCompassTest.digest(shell)
        #expect(presenter.send("compass.turn", [1], port: shell.port) == .accepted,
                "the game goes on with the sound on")
        #expect(try HueCompassTest.digest(shell) != digest)
        #expect(presenter.mirror.soundOn, "the choice stays on")
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.playersMade == 0, "no player was made")
        #expect(!presenter.sound.started)
        presenter.sceneActive(true)
    }

    // MARK: Reduce Flashing (FR-R02G0406-004; SC-R02G0406-003)

    /// Under Reduce Flashing, drawn frames 1/60 s apart: a probe and a retry alternate every frame for 1 s, the lights
    /// are held 1 s, a turn and its undo alternate every frame for 0.5 s, then the target is selected and the win drawn
    /// for 1 s. No element (probe mark, selection, ring, glow) crosses half its range more than 3 times per second,
    /// every complete fade of more than half the range takes at least 0.4 s, the glow takes at least 24 frames to reach
    /// full, and the glow-shell gain rises after the win while the gain limit stays 0.5.
    @Test func drawnLightsUnderReduceFlashing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceFlashing: true)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        #expect(presenter.lights.reducedFlash)
        #expect(presenter.scene.gainLimit == HueCompassShaders.reducedFlashingGainLimit)
        #expect(presenter.scene.gainLimit == 0.5)
        let opening: HueCompassExperienceCore = try Access.core(shell)
        try #require(opening.play.level.allowance >= 2, "a probe leaves the play going")

        let base: Double = 100
        var frame: Int = 0
        var samples: [HueCompassLightSample] = [try Access.sample(session, presenter, time: base)]
        #expect(presenter.scene.shellGain == HueCompassShaders.standardGain, "no glow before the win")

        // A probe and a retry every frame (1 s), ending on a retry; then held 1 s.
        for index in 1...120 {
            if index <= 60 {
                let result: ActionResult = index % 2 == 1
                    ? shell.port.send("compass.probe", [])
                    : shell.port.send("level.select", [1])
                #expect(result == .accepted, "flicker \(index): \(result.code)")
            }
            frame += 1
            samples.append(try Access.sample(session, presenter, time: base + Double(frame) / Access.frameRate))
            #expect(presenter.scene.lights == presenter.lights, "frame \(frame): the scene draws the eased lights")
        }
        #expect(try Access.core(shell).play.clues.isEmpty)

        // A turn and its undo every frame (0.5 s): the lights do not move.
        for index in 1...30 {
            let result: ActionResult = index % 2 == 1
                ? shell.port.send("compass.turn", [1])
                : shell.port.send("play.undo", [])
            #expect(result == .accepted, "turn flicker \(index): \(result.code)")
            frame += 1
            samples.append(try Access.sample(session, presenter, time: base + Double(frame) / Access.frameRate))
        }

        // The win.
        let level: HueCompassLevel = opening.play.level
        let selected: ActionResult = shell.port.send("compass.select", [Double(level.target), Double(level.targetBand)])
        #expect(selected == .accepted, "\(selected.code)")
        #expect(try Access.core(shell).play.stage == .won)
        var reached: Int?
        for index in 1...60 {
            frame += 1
            let sample: HueCompassLightSample = try Access.sample(session, presenter,
                                                                  time: base + Double(frame) / Access.frameRate)
            samples.append(sample)
            if reached == nil, sample.glow == 1 { reached = index }
        }
        #expect(presenter.lights.glow == 1)
        #expect(presenter.lights.isSettled, "the lights settle once the flicker stops")
        let glowFrame: Int = try #require(reached, "the glow reaches full")
        #expect(glowFrame >= 24, "Reduce Flashing: the glow took \(glowFrame) frames")

        let vectors: [[Double]] = Access.vectors(samples)
        #expect(Access.anyMidFade(vectors), "the lights fade rather than switch")
        let crossings: Double = HueCompassLights.maxHalfRangeCrossingsPerSecond(vectors, frameRate: Access.frameRate)
        #expect(crossings <= 3, "Reduce Flashing: \(crossings) half-range crossings per second")
        let fade: Double = Access.shortestFade(vectors, frameRate: Access.frameRate)
        #expect(fade >= 0.4, "Reduce Flashing: the shortest complete fade took \(fade) s")

        #expect(presenter.scene.shellGain > HueCompassShaders.standardGain, "the win glow raises the shell gain")
        #expect(presenter.scene.shellGain == 2 * HueCompassShaders.standardGain)
        #expect(presenter.scene.gainLimit == 0.5, "the gain limit stays 0.5 under Reduce Flashing")
        #expect(HueCompassShaders.gainLimit(reduceFlashing: true) == 0.5)
    }

    /// Without Reduce Flashing the win glow reaches full within 10 frames (0.15 s and float rounding) and the gain
    /// limit is the standard one.
    @Test func drawnGlowWithoutReduceFlashing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceFlashing: false)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        #expect(!presenter.lights.reducedFlash)
        #expect(presenter.scene.gainLimit == HueCompassShaders.standardGainLimit)
        let base: Double = 100
        _ = try Access.sample(session, presenter, time: base)
        #expect(presenter.lights.glow == 0)
        let level: HueCompassLevel = try Access.core(shell).play.level
        #expect(shell.port.send("compass.select", [Double(level.target), Double(level.targetBand)]) == .accepted)
        var reached: Int?
        for frame in 1...30 {
            let sample: HueCompassLightSample = try Access.sample(session, presenter,
                                                                  time: base + Double(frame) / Access.frameRate)
            if reached == nil, sample.glow == 1 { reached = frame }
        }
        let glowFrame: Int = try #require(reached, "the glow reaches full")
        #expect(glowFrame <= 10, "normal: the glow took \(glowFrame) frames")
        #expect(presenter.lights.isSettled)
        #expect(presenter.scene.shellGain == 2 * HueCompassShaders.standardGain)
    }

    // MARK: Reduce Motion (FR-R02G0406-004; SC-R02G0406-003)

    /// Under Reduce Motion two stills at different times are byte-identical and the drawn snapshot keeps time 0;
    /// without it the drawn snapshots carry their times.
    @Test func reduceMotionStillsIdentical() async throws {
        do {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Access.open(session, reduceMotion: true)
            Access.quiet(shell)
            let first: [UInt8] = try HueCompassTest.still(session, width: Access.stillWidth,
                                                          height: Access.stillHeight, time: 0.25)
            let firstDrawn: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let second: [UInt8] = try HueCompassTest.still(session, width: Access.stillWidth,
                                                           height: Access.stillHeight, time: 1.3)
            let secondDrawn: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(HueCompassTest.nonNightPixels(first) > 0, "the still shows the scene")
            #expect(first == second, "Reduce Motion: stills at 0.25 s and 1.3 s are identical")
            #expect(firstDrawn.time == 0)
            #expect(secondDrawn.time == 0)
            let core: HueCompassExperienceCore = try Access.core(shell)
            #expect(secondDrawn == core.snapshot(time: 0))
        }

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceMotion: false)
        Access.quiet(shell)
        _ = try HueCompassTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0.25)
        let firstDrawn: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        _ = try HueCompassTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 1.3)
        let secondDrawn: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(Swift.abs(firstDrawn.time - 0.25) < 1e-9, "\(firstDrawn.time)")
        #expect(Swift.abs(secondDrawn.time - 1.3) < 1e-9, "\(secondDrawn.time)")
    }

    // MARK: Labels and values (FR-R02G0406-001, 005)

    /// The label and value strings built outside the view body and the mirror values the modifiers read: the four turn
    /// titles and spoken names, the progress value, the goal line, the mode names, the level titles, the summary
    /// element's words and the band stepper's pick; refusals in words; the controls cover every action; the sound is
    /// off by default.
    @Test func labelsValuesAndActionCoverage() async throws {
        #expect(HueCompassControls.turns == [-4, -1, 1, 4])
        #expect(HueCompassControls.turnTitles == ["−4", "−1", "+1", "+4"])
        var spoken: [String] = []
        for steps in HueCompassControls.turns { spoken.append(HueCompassControls.turnLabel(steps)) }
        let wantSpoken: [String] = ["Turn the needle 4 bearings clockwise", "Turn the needle 1 bearing clockwise",
                                    "Turn the needle 1 bearing counter-clockwise",
                                    "Turn the needle 4 bearings counter-clockwise"]
        #expect(spoken == wantSpoken, "\(spoken)")
        #expect(Plan.modeName(.campaign) == "Campaign")
        #expect(Plan.modeName(.practice) == "Practice")
        #expect(Plan.modeName(.daily(level: 1)) == "Daily level")
        #expect(HueCompassControls.levelTitle(7, stars: nil) == "Level 7")
        #expect(HueCompassControls.levelTitle(7, stars: 1) == "Level 7 · 1 star")
        #expect(HueCompassControls.levelTitle(7, stars: 3) == "Level 7 · 3 stars")
        #expect(HueCompassControls.readableWidth == Access.readableWidth)
        #expect(HueCompassControls.isDaily(.daily(level: 42)))
        #expect(!HueCompassControls.isDaily(.campaign))

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        let core: HueCompassExperienceCore = try Access.core(shell)
        #expect(presenter.nativeActions == Set(HueCompassExperienceCore.actionIDs))
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions))
        #expect(presenter.mirror.soundOn == false)
        #expect(!presenter.sound.wanted)

        // The summary element ("Compass") and the play values.
        let mirror: HueCompassMirror = presenter.mirror
        let allowance: Int = core.play.level.allowance
        let band: Int = core.play.level.band(of: core.play.bearing) + 1
        #expect(mirror.bearing == core.play.bearing)
        #expect(mirror.bandUnderNeedle + 1 == band)
        #expect(mirror.summary == Plan.summaryText(core: core))
        #expect(mirror.summary == "Bearing \(core.play.bearing), band \(band). Units left \(allowance) of \(allowance). No clues yet.",
                "\(mirror.summary)")
        #expect(HueCompassControls.progressValue(mirror) == "Level 1, units 0 of \(allowance)")
        #expect(HueCompassControls.goal(mirror)
            == "Campaign · goal: \(allowance) units allowed, fewest probes \(core.certifiedSmallest)")

        // The values follow the mirror: a probe.
        #expect(presenter.send("compass.probe", [], port: shell.port) == .accepted)
        let probed: HueCompassExperienceCore = try Access.core(shell)
        let clue: HueCompassClue = try #require(probed.play.clues.last)
        let probedBand: Int = probed.play.level.band(of: probed.play.bearing) + 1
        let wantSummary: String = "Bearing \(probed.play.bearing), band \(probedBand). Units left \(allowance - 1) of \(allowance). "
            + "Last clue: hue gap \(Access.bandsText(clue.hueGap)), fog depth \(clue.depth)."
        #expect(presenter.mirror.summary == wantSummary, "\(presenter.mirror.summary)")
        #expect(HueCompassControls.progressValue(presenter.mirror) == "Level 1, units 1 of \(allowance)")
        #expect(presenter.mirror.clueCount == 1)

        // The band stepper: a pick is clamped to 0 … 23 and a repeated pick is not announced again.
        presenter.pickBand(23)
        #expect(presenter.mirror.pickedBand == 23)
        let logged: Int = presenter.feedbackLog.count
        presenter.pickBand(30)
        #expect(presenter.mirror.pickedBand == 23, "a pick past the last band is clamped")
        #expect(presenter.feedbackLog.count == logged, "the same band is not announced again")
        presenter.pickBand(-1)
        #expect(presenter.mirror.pickedBand == 0)
        #expect(presenter.feedbackLog.last == Plan.picked(band: 0))

        // A refusal in words.
        #expect(presenter.send("level.select", [2], port: shell.port) != .accepted)
        #expect(presenter.mirror.message == "That level is not open yet.")
        #expect(Plan.refusalText(code: "action.rule.r02-g04.stage") == "The level has ended.")
        #expect(Plan.refusalText(code: "r02-g04.allowance") == "No units are left.")
        #expect(Plan.refusalText(code: "r02-g04.date") == "That date cannot be used.")
        #expect(Plan.refusalText(code: "something.else") == "That change was refused.")

        // Practice.
        #expect(presenter.send("mode.practice", [], port: shell.port) == .accepted)
        #expect(presenter.mirror.message == nil)
        #expect(HueCompassControls.goal(presenter.mirror).hasPrefix("Practice · goal: 24 units allowed"))
        #expect(Plan.modeName(presenter.mirror.mode) == "Practice")
        #expect(shell.accessibilitySummary.hasPrefix("Hue Compass level 1. "))
    }

    /// The panel at the largest accessibility text size in a window 320 points wide (iPhone SE) and 1024 points wide
    /// (iPad): the fitting width stays within the window, the hosted scroll view's content stays within the window and
    /// the readable width (padding included), and the text grows taller than at the default size on the iPhone width.
    @Test func panelAtTheLargestTextSize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        Access.quiet(shell)
        let screens: [CGSize] = [CGSize(width: 320, height: 568), CGSize(width: 1024, height: 1366)]
        let sizes: [DynamicTypeSize] = [.large, .accessibility5]
        for screen in screens {
            var heights: [CGFloat] = []
            for size in sizes {
                let frame: CGRect = CGRect(origin: .zero, size: screen)
                let window: UIWindow = UIWindow(frame: frame)
                let controller: UIHostingController<AnyView> =
                    UIHostingController(rootView: AnyView(shell.controls.environment(\.dynamicTypeSize, size)))
                window.rootViewController = controller
                window.isHidden = false
                controller.view.frame = frame
                window.layoutIfNeeded()
                controller.view.layoutIfNeeded()
                let what: String = "\(Int(screen.width)) pt at \(size)"
                let fitting: CGSize = controller.sizeThatFits(in: CGSize(width: screen.width,
                                                                         height: .greatestFiniteMagnitude))
                #expect(fitting.width.isFinite && fitting.height.isFinite, "\(what): fitting \(fitting)")
                #expect(fitting.width <= screen.width + 0.5, "\(what): fitting width \(fitting.width)")
                let scroll: UIScrollView = try #require(Access.scrollView(in: controller.view), "\(what): scroll view")
                let content: CGSize = scroll.contentSize
                let limit: CGFloat = min(screen.width, Access.readableWidth) + 0.5
                #expect(content.width <= limit, "\(what): content width \(content.width)")
                #expect(content.height > 0, "\(what): content height")
                heights.append(content.height)
                window.isHidden = true
            }
            if screen.width < 400 && heights.count == 2 {
                #expect(heights[1] > heights[0], "the text grows: \(heights)")
            }
        }
        shell.presenter.controlsDisappeared()
        #expect(shell.presenter.sound.playersMade == 0, "showing the panel with the sound off makes no player")
    }
}
#endif
