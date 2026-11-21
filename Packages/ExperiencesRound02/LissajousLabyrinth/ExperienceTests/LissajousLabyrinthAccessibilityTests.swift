// LissajousLabyrinthAccessibilityTests — feature 316 (R02-G02-06) T-R02G0206-005 (FR-R02G0206-001 … 006;
// SC-R02G0206-001 … 004).
// On the simulator, through the one app's session host, modelled on Aurora Loom's feature-306 tests. Recorded feedback:
// the presenter's route is an `ExperienceFeedback` with a `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock
// moved by hand (1 s before every action, beyond the haptic planner's 0.05 s and the announcement planner's 0.5 s) and
// VoiceOver reported running; an action, undo, redo, a refused non-coprime frequency, a fresh play (level), the
// certified win and a spent allowance record exactly `LissajousLabyrinthFeedbackPlan.after(old:new:)` and
// `refused(code:)` in the sinks and in the presenter's feedback log (the action and win texts are also written out).
// Level 1 is won with the steppers' operation (`stepPending`, the shorter way round) and `applyPending` alone, every
// step announced as "<Title> <value> pending. Apply to change." and the win announced (a burst inside Apply follows
// the shared planners: the newest announcement is posted by `flush()`, haptics after the first are dropped). A gesture
// turn in progress is not announced; its release is announced once. Sound: the presenter makes its own
// `LissajousLabyrinthSound` with the real `AmbientLoopPlayer`, so the state table, offers and a failing `play()` use a
// `LissajousLabyrinthSound` with a fake player; the presenter's sound is only driven with the sound off or off screen
// (no audio starts): the recipe offered at level and mode openings and play ends, not on ordinary actions, no player
// made. Reduce Flashing: the drawn lights are sampled through off-screen stills at frame times 1/60 s apart (the
// presenter eases its lights by the frame time it is drawn at; live frames use the wall clock) over a certified win and
// over undo/redo toggled every 2 frames. Reduce Motion: two stills at different times are byte-identical, and differ
// without it. Labels: SwiftUI's accessibility tree is not inspectable from a unit test, so the label and value strings
// built by code outside the view body (dial titles, stepper titles, level titles, the goal line), the controls'
// action coverage and the panel's layout at the largest accessibility text size (320 and 1024 points wide) are
// checked; the `.accessibilityLabel`/`.accessibilityValue` modifiers in the view body are not. Synthetic data, explicit
// types, plain loops, no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class LissajousLabyrinthAccessClock {
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class LissajousLabyrinthFakeLoop: LissajousLabyrinthLoopPlaying {
    var isEnabled: Bool = false
    private(set) var isPlaying: Bool = false
    private(set) var plays: Int = 0
    private(set) var stops: Int = 0
    let succeeds: Bool

    init(succeeds: Bool) {
        self.succeeds = succeeds
    }

    @discardableResult
    func play() -> Bool {
        plays += 1
        guard isEnabled, succeeds else { return false }
        isPlaying = true
        return true
    }

    func stop() {
        stops += 1
        isPlaying = false
    }
}

/// Makes fake loops and keeps them.
@MainActor
final class LissajousLabyrinthFakeLoopFactory {
    var succeeds: Bool = true
    private(set) var made: [LissajousLabyrinthFakeLoop] = []

    func make() -> LissajousLabyrinthFakeLoop {
        let loop: LissajousLabyrinthFakeLoop = LissajousLabyrinthFakeLoop(succeeds: succeeds)
        made.append(loop)
        return loop
    }

    /// A sound policy starting from the recipe of `dials` and `stage` that makes its players here.
    func sound(dials: LissajousLabyrinthDials, stage: LissajousLabyrinthStage) -> LissajousLabyrinthSound {
        LissajousLabyrinthSound(recipe: LissajousLabyrinthSoundRecipe.recipe(dials: dials, stage: stage),
                                makePlayer: { _ in self.make() })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum LissajousLabyrinthAccess {
    typealias Shell = ExperienceShell<LissajousLabyrinthPresenter>
    typealias Teaching = LissajousLabyrinthTeaching
    typealias Plan = LissajousLabyrinthFeedbackPlan

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: LissajousLabyrinthAccessClock
    }

    /// The still size of the Reduce Flashing and Reduce Motion tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64
    /// The frame rate of the sampled stills.
    static let frameRate: Double = 60

    /// Opens level `seed % 100 + 1`.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        try await LissajousLabyrinthTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                              reduceFlashing: reduceFlashing, size: CGSize(width: 360, height: 240))
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: LissajousLabyrinthAccessClock = LissajousLabyrinthAccessClock()
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
    static func core(_ shell: Shell) throws -> LissajousLabyrinthExperienceCore {
        try #require(shell.engine.core)
    }

    /// The texts of `plans` that are announced, in order.
    static func texts(_ plans: [Plan]) -> [String] {
        var result: [String] = []
        for plan in plans {
            if let text = plan.text, plan.kind != nil { result.append(text) }
        }
        return result
    }

    /// The haptics of `plans`, in order.
    static func haptics(_ plans: [Plan]) -> [HapticKind] {
        var result: [HapticKind] = []
        for plan in plans {
            if let haptic = plan.haptic { result.append(haptic) }
        }
        return result
    }

    /// The feedback log entries after the first `count`.
    static func log(_ presenter: LissajousLabyrinthPresenter, after count: Int) -> [Plan] {
        Array(presenter.feedbackLog.dropFirst(count))
    }

    /// "1 action" or "n actions", written out here.
    static func actions(_ count: Int) -> String { count == 1 ? "1 action" : "\(count) actions" }

    /// The `dial.set` values of `action`.
    static func values(_ action: LissajousLabyrinthAction) -> [Double] {
        let index: Int = LissajousLabyrinthDial.allCases.firstIndex(of: action.dial) ?? 0
        return [Double(index), Double(action.value)]
    }

    /// `value + delta` wrapped into `dial`'s range (the stepper's wrap), computed independently of the presenter.
    static func wrapped(_ dial: LissajousLabyrinthDial, _ value: Int, by delta: Int) -> Int {
        let lower: Int = dial.range.lowerBound
        let width: Int = dial.range.count
        return lower + (((value - lower + delta) % width) + width) % width
    }

    /// The greatest common divisor of two positive integers.
    static func gcd(_ a: Int, _ b: Int) -> Int {
        var x: Int = a
        var y: Int = b
        while y != 0 {
            let r: Int = x % y
            x = y
            y = r
        }
        return x
    }

    /// A frequency action of `dials` whose new frequencies share a factor (refused as not coprime); nil when none.
    static func nonCoprime(_ dials: LissajousLabyrinthDials) -> LissajousLabyrinthAction? {
        let pairs: [(LissajousLabyrinthDial, LissajousLabyrinthDial)] = [(.frequencyA, .frequencyB),
                                                                         (.frequencyB, .frequencyA)]
        for pair in pairs {
            for target in 1...9 where target != dials[pair.0] && gcd(target, dials[pair.1]) != 1 {
                return LissajousLabyrinthAction(dial: pair.0, value: target)
            }
        }
        // With both frequencies at 1 every value is coprime; setting a dial to its current value is refused with the
        // same code (`r02-g02.move`: "a dial must change").
        return LissajousLabyrinthAction(dial: .phaseA, value: dials.phaseA)
    }

    /// The flattened light targets of `snapshot` (checkpoints, obstacles, glow), in the order of `levels`.
    static func targets(_ snapshot: LissajousLabyrinthSceneSnapshot) -> [Double] {
        let wanted = LissajousLabyrinthLights.targets(snapshot)
        return wanted.checkpoints + wanted.obstacles + [wanted.glow]
    }

    /// Draws an off-screen still of `session` at frame time `time` and returns the presenter's drawn light levels.
    static func sample(_ session: ExperienceSession, _ presenter: LissajousLabyrinthPresenter,
                       time: Double) throws -> [Double] {
        _ = try LissajousLabyrinthTest.still(session, width: stillWidth, height: stillHeight, time: time)
        return presenter.lights.levels
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
@Suite(.serialized) struct LissajousLabyrinthAccessibilityTests {
    typealias Access = LissajousLabyrinthAccess
    typealias Teaching = LissajousLabyrinthTeaching
    typealias Script = LissajousLabyrinthGestureScript
    typealias Plan = LissajousLabyrinthFeedbackPlan

    // MARK: Recorded feedback (FR-R02G0206-002, 003; SC-R02G0206-002)

    /// An action, undo, redo, a refused non-coprime frequency, a fresh play, the certified win, another fresh play and
    /// a spent allowance: the sinks receive exactly the plans of `LissajousLabyrinthFeedbackPlan`, in order, and the
    /// feedback log holds the same plans.
    @Test func recordedFeedbackThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let announcedBase: Int = presenter.announcements.count
        var expected: [Plan] = []
        let opening: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)

        // An accepted action: a state announcement and a selection haptic, text written out.
        let action: LissajousLabyrinthAction = try #require(Teaching.nonWinningAction(opening), "a non-winning action")
        recorder.clock.advance()
        let moved: ActionResult = presenter.send(action, port: shell.port)
        #expect(moved == .accepted, "\(moved.code)")
        let afterAction: LissajousLabyrinthExperienceCore = try Access.core(shell)
        try #require(afterAction.play.stage == .playing)
        let actionPlan: Plan = Plan.after(old: opening, new: afterAction)
        let snapshot: LissajousLabyrinthSceneSnapshot = afterAction.snapshot(time: 0)
        var want: String = "\(Teaching.title(action.dial)) \(action.value). "
            + "\(snapshot.visits.count) of \(snapshot.level.checkpoints.count) checkpoints in order. "
            + "Actions 1 of \(afterAction.play.level.allowance)."
        if let obstacle = snapshot.contactObstacle { want += " The path touches obstacle \(obstacle + 1)." }
        #expect(actionPlan.text == want, "\(actionPlan.text ?? "nil")")
        #expect(actionPlan.kind == .state)
        #expect(actionPlan.haptic == .selection)
        expected.append(actionPlan)

        // Undo names the dial with its restored value.
        recorder.clock.advance()
        let undone: ActionResult = presenter.send("play.undo", port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(afterUndo.play.dials == opening.play.dials)
        let undoPlan: Plan = Plan.after(old: afterAction, new: afterUndo)
        let restored: Int = opening.play.dials[action.dial]
        #expect(undoPlan.text?.hasPrefix("Undone: \(Teaching.title(action.dial)) \(restored). ") == true,
                "\(undoPlan.text ?? "nil")")
        #expect(undoPlan.kind == .state)
        #expect(undoPlan.haptic == .selection)
        expected.append(undoPlan)

        // Redo.
        recorder.clock.advance()
        let redone: ActionResult = presenter.send("play.redo", port: shell.port)
        #expect(redone == .accepted, "\(redone.code)")
        let afterRedo: LissajousLabyrinthExperienceCore = try Access.core(shell)
        let redoPlan: Plan = Plan.after(old: afterUndo, new: afterRedo)
        #expect(redoPlan.text?.hasPrefix("Redone: \(Teaching.title(action.dial)) \(action.value). ") == true,
                "\(redoPlan.text ?? "nil")")
        #expect(redoPlan.kind == .state)
        #expect(redoPlan.haptic == .selection)
        expected.append(redoPlan)

        // A refused action: a frequency that shares a factor with the other one, or a dial set to its current value.
        let bad: LissajousLabyrinthAction = try #require(Access.nonCoprime(afterRedo.play.dials), "a non-coprime value")
        recorder.clock.advance()
        let refused: ActionResult = presenter.send(bad, port: shell.port)
        #expect(!refused.isAccepted)
        #expect(refused.code.contains("r02-g02.move"), "\(refused.code)")
        let refusedPlan: Plan = Plan.refused(code: refused.code)
        #expect(refusedPlan.text
                == "That change is not allowed: the frequencies must share no factor, and a dial must change.")
        #expect(refusedPlan.kind == .rejection)
        #expect(refusedPlan.haptic == .error)
        #expect(presenter.mirror.message == refusedPlan.text)
        expected.append(refusedPlan)

        // A fresh play of level 1: a level announcement, no haptic.
        recorder.clock.advance()
        let picked: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(picked == .accepted, "\(picked.code)")
        let fresh: LissajousLabyrinthExperienceCore = try Access.core(shell)
        let levelPlan: Plan = Plan.after(old: afterRedo, new: fresh)
        #expect(levelPlan.text?.hasPrefix("Level 1, band 1, campaign.") == true, "\(levelPlan.text ?? "nil")")
        #expect(levelPlan.kind == .level)
        #expect(levelPlan.haptic == nil)
        expected.append(levelPlan)

        // The certified win: selections, then the outcome with a success haptic and 3 stars.
        let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: 1)
        var previous: LissajousLabyrinthExperienceCore = fresh
        for step in generated.solution.actions {
            recorder.clock.advance()
            let result: ActionResult = presenter.send(step, port: shell.port)
            #expect(result == .accepted, "\(result.code)")
            let next: LissajousLabyrinthExperienceCore = try Access.core(shell)
            expected.append(Plan.after(old: previous, new: next))
            previous = next
        }
        #expect(previous.play.stage == .won)
        let winPlan: Plan = try #require(expected.last)
        let spent: Int = previous.play.spent
        #expect(spent == generated.solution.shortest)
        #expect(winPlan.text == "The path is safe. Level won in \(Access.actions(spent)), 3 of 3 stars.",
                "\(winPlan.text ?? "nil")")
        #expect(winPlan.kind == .outcome)
        #expect(winPlan.haptic == .success)

        // Another fresh play, then the allowance spent without a win: the outcome with a warning haptic.
        recorder.clock.advance()
        let again: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(again == .accepted, "\(again.code)")
        let replay: LissajousLabyrinthExperienceCore = try Access.core(shell)
        expected.append(Plan.after(old: previous, new: replay))
        previous = replay
        let start: Int = replay.play.dials.phaseC
        let losing: Int = try #require(Teaching.losingPhase(from: replay.play), "a losing alternation for phase C")
        for index in 0..<replay.play.level.allowance {
            recorder.clock.advance()
            let value: Int = index % 2 == 0 ? losing : start
            let result: ActionResult = presenter.send(LissajousLabyrinthAction(dial: .phaseC, value: value),
                                                      port: shell.port)
            #expect(result == .accepted, "action \(index): \(result.code)")
            let next: LissajousLabyrinthExperienceCore = try Access.core(shell)
            expected.append(Plan.after(old: previous, new: next))
            previous = next
        }
        #expect(previous.play.stage == .failed)
        let failPlan: Plan = try #require(expected.last)
        #expect(failPlan.kind == .outcome)
        #expect(failPlan.haptic == .warning)
        #expect(failPlan.text == previous.failureExplanation?.text, "\(failPlan.text ?? "nil")")

        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected))
        #expect(Array(presenter.announcements.dropFirst(announcedBase)) == Access.texts(expected))
        #expect(recorder.announcements.announced.count == expected.count, "every plan here is announced")
    }

    // MARK: Steppers and Apply alone (SC-R02G0206-001)

    /// Level 1 is won with the steppers' operation and Apply alone: every step announced as "<Title> <value> pending.
    /// Apply to change.", nothing sent before Apply, the win announced; the burst of Apply follows the shared planners.
    @Test func levelOneWonWithTheSteppersAndApply() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        let digest: String = try LissajousLabyrinthTest.digest(shell)
        let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: 1)
        let final: LissajousLabyrinthDials = Script.finalDials(generated)

        var steps: Int = 0
        for dial in LissajousLabyrinthDial.allCases {
            let current: Int = opening.play.dials[dial]
            let target: Int = final[dial]
            guard target != current else { continue }
            let width: Int = dial.range.count
            let forward: Int = ((target - current) % width + width) % width
            let delta: Int = forward <= width / 2 ? 1 : -1
            let count: Int = delta > 0 ? forward : width - forward
            var value: Int = current
            for _ in 0..<count {
                recorder.clock.advance()
                presenter.stepPending(dial, by: delta)
                value = Access.wrapped(dial, value, by: delta)
                steps += 1
                let announced: String = "\(Teaching.title(dial)) \(value) pending. Apply to change."
                #expect(presenter.announcements.last == announced, "\(presenter.announcements.last ?? "nil")")
                #expect(recorder.announcements.announced.last == announced)
                #expect(presenter.mirror.selectedDial == dial)
            }
            #expect(value == target)
            #expect(presenter.mirror.pending.values[dial] == target)
        }
        #expect(steps > 0)
        #expect(recorder.announcements.announced.count == steps, "every step announced")
        #expect(recorder.haptics.played.isEmpty, "pending steps play no haptic")
        #expect(presenter.feedbackLog.count == logBase, "pending steps are not plans")
        #expect(try LissajousLabyrinthTest.digest(shell) == digest, "pending values send nothing")

        recorder.clock.advance()
        let results: [ActionResult] = presenter.applyPending(port: shell.port)
        #expect(results.count == generated.solution.shortest, "\(results.count) actions")
        for result in results { #expect(result == .accepted, "\(result.code)") }
        let won: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.play.spent == generated.solution.shortest)
        #expect(won.play.dials == final)

        let plans: [Plan] = Access.log(presenter, after: logBase)
        #expect(plans.count == results.count, "each sent action is planned in order")
        let winText: String = "The path is safe. Level won in \(Access.actions(won.play.spent)), 3 of 3 stars."
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(presenter.announcements.last == winText)
        #expect(presenter.mirror.pending.isEmpty)

        // Apply's actions share one instant: the first announcement is posted, the newest is held until `flush()`;
        // the first haptic plays and the rest fall within the haptic planner's interval.
        recorder.clock.advance()
        presenter.feedback.flush()
        #expect(recorder.announcements.announced.last == winText, "the win is heard after the burst")
        let firstHaptic: HapticKind = results.count == 1 ? .success : .selection
        #expect(recorder.haptics.played == [firstHaptic], "\(recorder.haptics.played)")
    }

    // MARK: Gesture preview (edge case)

    /// A one-finger turn in progress is not announced and plans nothing; the release announces the action once.
    @Test func aGesturePreviewIsNotAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let announcedBase: Int = presenter.announcements.count
        let before: LissajousLabyrinthExperienceCore = try Access.core(shell)
        let digest: String = try LissajousLabyrinthTest.digest(shell)
        let dial: LissajousLabyrinthDial = .phaseC
        let offset: Int = try #require(Script.phaseSteps(before.play, dial), "a phase C turn that keeps playing")
        let path: [Int] = Script.values(dial, from: before.play.dials[dial], steps: offset)
        let target: Int = try #require(path.last)
        var time: Double = 0

        recorder.clock.advance()
        try Script.begin(shell, dial, value: path[0], time: &time)
        for index in 1..<path.count {
            try Script.move(shell, dial, value: path[index], time: &time)
        }
        #expect(presenter.mirror.candidate == LissajousLabyrinthAction(dial: dial, value: target))
        #expect(presenter.announcements.count == announcedBase, "the preview is not announced")
        #expect(presenter.feedbackLog.count == logBase, "the preview plans nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        #expect(try LissajousLabyrinthTest.digest(shell) == digest)

        recorder.clock.advance()
        try Script.end(shell, dial, value: target, time: &time)
        let after: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(after.play.dials[dial] == target)
        let plan: Plan = Plan.after(old: before, new: after)
        let text: String = try #require(plan.text)
        #expect(text.hasPrefix("\(Teaching.title(dial)) \(target). "), "\(text)")
        #expect(Access.log(presenter, after: logBase) == [plan])
        #expect(Array(presenter.announcements.dropFirst(announcedBase)) == [text], "the release is announced once")
        #expect(recorder.announcements.announced == [text])
        #expect(recorder.haptics.played == [.selection])
    }

    // MARK: Sound (FR-R02G0206-006; SC-R02G0206-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; each input turned off stops the loop and on again plays it with the same player.
    @Test func soundStateTable() throws {
        let dials: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0)
        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: LissajousLabyrinthFakeLoopFactory = LissajousLabyrinthFakeLoopFactory()
            let sound: LissajousLabyrinthSound = factory.sound(dials: dials, stage: .playing)
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
            }
        }

        let factory: LissajousLabyrinthFakeLoopFactory = LissajousLabyrinthFakeLoopFactory()
        let sound: LissajousLabyrinthSound = factory.sound(dials: dials, stage: .playing)
        sound.setOnScreen(true)
        sound.setWanted(true)
        let loop: LissajousLabyrinthFakeLoop = try #require(factory.made.first)
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

    /// Offers (a level opening or a play end): a different recipe while playing makes a new player and stops the old
    /// one; the same recipe does not; any offer while the sound is off makes none.
    @Test func soundOffersRebuildOnlyOnANewRecipe() {
        let opening: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2,
                                                                       phaseA: 0, phaseC: 0)
        let moved: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 3, frequencyB: 2, phaseA: 0, phaseC: 0)
        let silent: LissajousLabyrinthFakeLoopFactory = LissajousLabyrinthFakeLoopFactory()
        let off: LissajousLabyrinthSound = silent.sound(dials: opening, stage: .playing)
        off.setOnScreen(true)
        off.offer(LissajousLabyrinthSoundRecipe.recipe(dials: moved, stage: .playing))
        off.offer(LissajousLabyrinthSoundRecipe.recipe(dials: moved, stage: .won))
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)
        #expect(off.recipe == LissajousLabyrinthSoundRecipe.recipe(dials: moved, stage: .won), "kept for the start")

        let factory: LissajousLabyrinthFakeLoopFactory = LissajousLabyrinthFakeLoopFactory()
        let sound: LissajousLabyrinthSound = factory.sound(dials: opening, stage: .playing)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1)
        sound.offer(LissajousLabyrinthSoundRecipe.recipe(dials: opening, stage: .playing))
        #expect(sound.playersMade == 1, "the same recipe keeps the player")
        sound.offer(LissajousLabyrinthSoundRecipe.recipe(dials: moved, stage: .won))
        #expect(sound.playersMade == 2, "a new recipe makes a new player")
        #expect(factory.made.count == 2)
        if factory.made.count == 2 {
            #expect(!factory.made[0].isPlaying, "the old player stopped")
            #expect(factory.made[1].isPlaying)
        }
        sound.offer(LissajousLabyrinthSoundRecipe.recipe(dials: moved, stage: .won))
        #expect(sound.playersMade == 2)
    }

    /// A `play()` that fails leaves `started` false and the choice on, and nothing else happens.
    @Test func failingPlayLeavesTheChoiceOn() {
        let factory: LissajousLabyrinthFakeLoopFactory = LissajousLabyrinthFakeLoopFactory()
        factory.succeeds = false
        let dials: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 3, frequencyB: 4, phaseA: 5, phaseC: 6)
        let sound: LissajousLabyrinthSound = factory.sound(dials: dials, stage: .playing)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1)
        #expect(!sound.started)
        #expect(sound.wanted)
        #expect(sound.shouldPlay)
        #expect(factory.made.first?.plays == 1)
        #expect(factory.made.first?.isPlaying == false)
        #expect(factory.made.first?.stops == 0)
    }

    /// The presenter's own sound (real `AmbientLoopPlayer`; never started here: the sound is off, or on while off
    /// screen): ordinary actions offer nothing; a mode change, the end of a play and a fresh play of the same level
    /// (Retry) offer their recipe; turning the sound on offers the current recipe; no player is made.
    @Test func presenterSoundOffersAtOpeningsAndEndsOnly() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        Access.quiet(shell)
        presenter.controlsAppeared()
        #expect(!presenter.sound.wanted)
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")

        // An ordinary action keeps the offered recipe.
        let opening: LissajousLabyrinthExperienceCore = try Access.core(shell)
        let initial = presenter.sound.recipe
        let action: LissajousLabyrinthAction = try #require(Teaching.nonWinningAction(opening))
        #expect(presenter.send(action, port: shell.port) == .accepted)
        #expect(presenter.sound.recipe == initial, "an ordinary action does not offer a recipe")
        #expect(presenter.send("play.undo", port: shell.port) == .accepted)
        #expect(presenter.sound.recipe == initial, "an undo does not offer a recipe")

        // A mode change opens the level afresh and offers its recipe; back to the campaign likewise.
        #expect(presenter.send("mode.practice", port: shell.port) == .accepted)
        let practice: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(presenter.sound.recipe == LissajousLabyrinthSoundRecipe.recipe(dials: practice.play.dials,
                                                                                stage: practice.play.stage))
        #expect(presenter.send("mode.campaign", port: shell.port) == .accepted)
        let campaign: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(campaign.levelNumber == 1)
        let campaignRecipe = LissajousLabyrinthSoundRecipe.recipe(dials: campaign.play.dials,
                                                                   stage: campaign.play.stage)
        #expect(presenter.sound.recipe == campaignRecipe)

        // The certified win: the actions offer nothing until the end of the play offers the won recipe.
        let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: 1)
        for step in generated.solution.actions {
            #expect(presenter.send(step, port: shell.port) == .accepted)
            if try Access.core(shell).play.stage == .playing {
                #expect(presenter.sound.recipe == campaignRecipe, "an action of the play does not offer a recipe")
            }
        }
        let won: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(presenter.sound.recipe == LissajousLabyrinthSoundRecipe.recipe(dials: won.play.dials, stage: .won),
                "the end of the play offers the won recipe")

        // Retry (a fresh play of the same level in the same mode) is a level opening: the playing recipe returns.
        #expect(presenter.retry(port: shell.port, date: DateComponents()) == .accepted)
        let retried: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(retried.play.stage == .playing)
        #expect(presenter.sound.recipe == LissajousLabyrinthSoundRecipe.recipe(dials: retried.play.dials,
                                                                                stage: retried.play.stage),
                "a fresh play of the same level offers its recipe (the won recipe must not keep playing)")

        // Turning the sound on while off screen offers the current recipe and makes no player.
        presenter.controlsDisappeared()
        presenter.sceneActive(false)
        #expect(presenter.send(action, port: shell.port) == .accepted)
        let current: LissajousLabyrinthExperienceCore = try Access.core(shell)
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay)
        #expect(presenter.sound.recipe == LissajousLabyrinthSoundRecipe.recipe(dials: current.play.dials,
                                                                                stage: current.play.stage))
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.playersMade == 0, "no player was made")
        #expect(!presenter.sound.started)
    }

    // MARK: Reduce Flashing (FR-R02G0206-004; SC-R02G0206-003)

    /// The drawn lights over a certified win, sampled through stills 1/60 s apart: under Reduce Flashing no half-range
    /// change is faster than 0.4 s and no element crosses half its range more than 3 times per second; without it the
    /// glow completes its change within 10 frames (0.15 s and float rounding).
    @Test(arguments: [true, false])
    func drawnLightsFadeOverAWin(reduceFlashing: Bool) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceFlashing: reduceFlashing)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        Access.quiet(shell)
        #expect(presenter.lights.reducedFlash == reduceFlashing)
        let duration: Double = reduceFlashing ? LissajousLabyrinthLights.reducedFlashDuration
            : LissajousLabyrinthLights.normalDuration
        #expect(presenter.lights.duration == duration)

        let base: Double = 100
        var samples: [[Double]] = [try Access.sample(session, presenter, time: base)]
        #expect(presenter.lights.glow == 0)
        let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: 1)
        for step in generated.solution.actions {
            let result: ActionResult = shell.port.send("dial.set", Access.values(step))
            #expect(result == .accepted, "\(result.code)")
        }
        let won: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        var reached: Int?
        for frame in 1...90 {
            let levels: [Double] = try Access.sample(session, presenter, time: base + Double(frame) / Access.frameRate)
            samples.append(levels)
            if reached == nil, levels.last == 1 { reached = frame }
        }
        #expect(presenter.lights.levels == Access.targets(won.snapshot(time: 0)), "the lights reach the won targets")
        let glowFrame: Int = try #require(reached, "the glow reaches full")
        let shortest: Double = LissajousLabyrinthLights.shortestHalfRangeChange(samples, frameRate: Access.frameRate)
        #expect(shortest.isFinite, "the win makes a change of more than half the range")
        let crossings: Double = LissajousLabyrinthLights.maxHalfRangeCrossingsPerSecond(samples,
                                                                                         frameRate: Access.frameRate)
        if reduceFlashing {
            #expect(shortest >= 0.4, "Reduce Flashing: shortest half-range change \(shortest) s")
            #expect(crossings <= 3, "Reduce Flashing: \(crossings) crossings per second")
            #expect(glowFrame >= 24, "Reduce Flashing: the glow took \(glowFrame) frames")
        } else {
            #expect(glowFrame <= 10, "normal: the glow took \(glowFrame) frames")
            #expect(shortest < 0.4, "normal fades are quicker: \(shortest) s")
        }
    }

    /// Adversarial flicker in drawn frames under Reduce Flashing: an action that moves the lights (preferably one that
    /// changes which checkpoint is next, 0 to 0.5) is undone and redone every 2 frames for 2 s, then held 1 s;
    /// no element crosses half its range more than 3 times per second and no half-range change is faster than 0.4 s.
    @Test func drawnLightsSurviveUndoRedoFlicker() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceFlashing: true)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        Access.quiet(shell)
        let opening: LissajousLabyrinthExperienceCore = try Access.core(shell)
        let openingSnapshot: LissajousLabyrinthSceneSnapshot = opening.snapshot(time: 0)
        let openingTargets: [Double] = Access.targets(openingSnapshot)

        // The flickering action: still playing afterwards, light targets changed; a change of the visit count first.
        var preferred: LissajousLabyrinthAction?
        var fallback: LissajousLabyrinthAction?
        for dial in LissajousLabyrinthDial.allCases where preferred == nil {
            for value in dial.range where value != opening.play.dials[dial] && preferred == nil {
                let action: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: dial, value: value)
                var trial: LissajousLabyrinthPlay = opening.play
                do {
                    try trial.apply(action, expecting: trial.fingerprint)
                } catch {
                    continue
                }
                guard trial.stage == .playing else { continue }
                let snapshot: LissajousLabyrinthSceneSnapshot = LissajousLabyrinthSceneSnapshot(play: trial, time: 0)
                guard Access.targets(snapshot) != openingTargets else { continue }
                if snapshot.visits.count != openingSnapshot.visits.count {
                    preferred = action
                } else if fallback == nil {
                    fallback = action
                }
            }
        }
        let action: LissajousLabyrinthAction = try #require(preferred ?? fallback, "an action that moves the lights")

        let base: Double = 100
        var samples: [[Double]] = [try Access.sample(session, presenter, time: base)]
        #expect(shell.port.send("dial.set", Access.values(action)) == .accepted)
        var applied: Bool = true
        for frame in 0..<180 {
            if frame > 0 && frame < 120 && frame % 2 == 0 {
                let result: ActionResult = shell.port.send(applied ? "play.undo" : "play.redo")
                #expect(result == .accepted, "frame \(frame): \(result.code)")
                applied.toggle()
            }
            samples.append(try Access.sample(session, presenter, time: base + Double(frame + 1) / Access.frameRate))
        }
        #expect(try Access.core(shell).play.stage == .playing)
        let crossings: Double = LissajousLabyrinthLights.maxHalfRangeCrossingsPerSecond(samples,
                                                                                         frameRate: Access.frameRate)
        #expect(crossings <= 3, "undo/redo flicker of \(action): \(crossings) crossings per second")
        let shortest: Double = LissajousLabyrinthLights.shortestHalfRangeChange(samples, frameRate: Access.frameRate)
        #expect(shortest >= 0.4, "undo/redo flicker of \(action): shortest half-range change \(shortest) s")
    }

    // MARK: Reduce Motion (FR-R02G0206-004; SC-R02G0206-003)

    /// Under Reduce Motion two stills at different times are byte-identical and the drawn snapshot stays at time 0;
    /// without it the same two times give different pictures.
    @Test func reduceMotionStillsIdentical() async throws {
        do {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Access.open(session, reduceMotion: true)
            Access.quiet(shell)
            let first: [UInt8] = try LissajousLabyrinthTest.still(session, width: Access.stillWidth,
                                                                  height: Access.stillHeight, time: 0.25)
            let second: [UInt8] = try LissajousLabyrinthTest.still(session, width: Access.stillWidth,
                                                                   height: Access.stillHeight, time: 1.3)
            #expect(LissajousLabyrinthTest.nonNightPixels(first) > 0, "the still shows the scene")
            #expect(first == second, "Reduce Motion: stills at 0.25 s and 1.3 s are identical")
            try LissajousLabyrinthTest.draw(session, frames: 3)
            let drawn: LissajousLabyrinthSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let core: LissajousLabyrinthExperienceCore = try Access.core(shell)
            #expect(drawn.time == 0)
            #expect(drawn == core.snapshot(time: 0))
        }

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceMotion: false)
        Access.quiet(shell)
        let first: [UInt8] = try LissajousLabyrinthTest.still(session, width: Access.stillWidth,
                                                              height: Access.stillHeight, time: 0.25)
        let second: [UInt8] = try LissajousLabyrinthTest.still(session, width: Access.stillWidth,
                                                               height: Access.stillHeight, time: 1.3)
        #expect(first != second, "without Reduce Motion the tracer head moves")
    }

    // MARK: Labels and values (FR-R02G0206-001, 005)

    /// The label and value strings built outside the view body: the four dial names, the stepper titles with and
    /// without a pending value, the level picker's titles, the goal line; the controls cover every action; the panel
    /// keeps a readable width of 520 points; the sound is off by default.
    @Test func labelsValuesAndActionCoverage() async throws {
        let dials: [LissajousLabyrinthDial] = LissajousLabyrinthDial.allCases
        let names: [String] = ["Frequency A", "Frequency B", "Phase A", "Phase C"]
        #expect(dials.count == 4)
        for index in 0..<dials.count {
            #expect(LissajousLabyrinthPresenter.title(dials[index]) == names[index])
            #expect(Teaching.title(dials[index]) == names[index])
        }
        #expect(LissajousLabyrinthControls.title(.phaseC, shown: 12, current: 12) == "Phase C 12")
        #expect(LissajousLabyrinthControls.title(.phaseC, shown: 3, current: 12) == "Phase C 3 (now 12)")
        #expect(LissajousLabyrinthControls.title(.frequencyA, shown: 5, current: 5) == "Frequency A 5")
        #expect(LissajousLabyrinthControls.levelTitle(7, stars: nil) == "Level 7")
        #expect(LissajousLabyrinthControls.levelTitle(7, stars: 1) == "Level 7 · 1 star")
        #expect(LissajousLabyrinthControls.levelTitle(7, stars: 3) == "Level 7 · 3 stars")
        #expect(LissajousLabyrinthControls.readableWidth == 520)
        #expect(LissajousLabyrinthControls.isDaily(.daily(level: 42)))
        #expect(!LissajousLabyrinthControls.isDaily(.campaign))

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        Access.quiet(shell)
        let core: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(presenter.nativeActions == Set(LissajousLabyrinthExperienceCore.actionIDs))
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions))
        #expect(presenter.mirror.dials == core.play.dials, "the steppers' values come from the mirror")
        #expect(presenter.mirror.soundOn == false)
        let goal: String = LissajousLabyrinthControls.goal(presenter.mirror)
        #expect(goal == "Campaign · goal: \(core.play.level.allowance) actions allowed, best possible "
                + "\(core.certifiedShortest)", "\(goal)")
        #expect(presenter.send("mode.practice", port: shell.port) == .accepted)
        #expect(LissajousLabyrinthControls.goal(presenter.mirror).hasPrefix("Practice · goal: 64 actions allowed"))
        #expect(shell.accessibilitySummary.hasPrefix("Lissajous Labyrinth level 1. "))
    }

    /// The panel at the largest accessibility text size in a window 320 points wide (iPhone SE) and 1024 points wide
    /// (iPad), also with a value pending (Apply and Clear shown): the fitting width stays within the window, the hosted
    /// scroll view's content stays within the window and the readable width plus the panel's padding, and the text
    /// grows taller than at the default size on the iPhone width.
    @Test func panelAtTheLargestTextSize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        Access.quiet(shell)
        let screens: [CGSize] = [CGSize(width: 320, height: 568), CGSize(width: 1024, height: 1366)]
        let sizes: [DynamicTypeSize] = [.large, .accessibility5]
        // `.frame(maxWidth: 520)` is applied inside `.padding()` (16 points a side by default).
        let padded: CGFloat = LissajousLabyrinthControls.readableWidth + 2 * 16
        for pending in [false, true] {
            if pending { shell.presenter.stepPending(.phaseA, by: 1) }
            #expect(shell.presenter.mirror.pending.isEmpty == !pending)
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
                    let what: String = "\(Int(screen.width)) pt at \(size)\(pending ? " with a value pending" : "")"
                    let fitting: CGSize = controller.sizeThatFits(in: CGSize(width: screen.width,
                                                                             height: .greatestFiniteMagnitude))
                    #expect(fitting.width.isFinite && fitting.height.isFinite, "\(what): fitting \(fitting)")
                    #expect(fitting.width <= screen.width + 0.5, "\(what): fitting width \(fitting.width)")
                    let scroll: UIScrollView = try #require(Access.scrollView(in: controller.view),
                                                            "\(what): scroll view")
                    let content: CGSize = scroll.contentSize
                    let limit: CGFloat = min(screen.width, padded) + 0.5
                    #expect(content.width <= limit, "\(what): content width \(content.width)")
                    #expect(content.height > 0, "\(what): content height")
                    heights.append(content.height)
                    window.isHidden = true
                }
                if screen.width < 400 && heights.count == 2 {
                    #expect(heights[1] > heights[0], "the text grows: \(heights)")
                }
            }
        }
        shell.presenter.clearPending()
        #expect(shell.presenter.sound.playersMade == 0, "showing the panel with the sound off makes no player")
    }
}
#endif
