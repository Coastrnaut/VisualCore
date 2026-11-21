// AuroraLoomAccessibilityTests — feature 306 (R02-G01-06) T-R02G0106-006 (FR-R02G0106-001 … 006; SC-R02G0106-001 …
// 004; clarifications Q1–Q5). On the simulator, through the one app's session host: the presenter's feedback route with
// a `RecordingHapticSink`, a `RecordingAnnouncementSink`, a controllable clock (advanced 1 s before every action, far
// beyond the haptic planner's 0.05 s and the announcement planner's 0.5 s, so nothing is rate-limited) and VoiceOver
// reported running. Scripted sequences (a wave move through `adjust`, undo, redo, a refused level pick, a fresh pick and
// the certified win) record exactly the plans of `AuroraLoomFeedbackPlan.after(old:new:)` and `refused(code:)`, in order,
// in the sinks and in the presenter's feedback log. Level 1 is won through `adjust(ribbon:control:by:port:)` alone by
// following the level-3 hint, every move announced (SC-R02G0106-001). Labels and values: SwiftUI's accessibility tree is
// not inspectable from a unit test, so the mirror-driven values the steppers show (`mirror.steps`) are checked against
// the core, the native controls cover every action and `adjust` wraps 15 + 1 → 0 and 0 − 1 → 15. The panel is laid out
// in a window at the largest accessibility text size at 320 and 1024 points wide: the fitting width stays within the
// window and the hosted scroll view's content stays within the width and the 520-point readable width on iPad, and
// grows taller than at the default size; feature 309 adds the same layout with a step pending (Apply and Clear).
// The sound policy's state table uses a fake loop player (8 combinations, a
// recipe change while playing, a failing `play()`); the presenter's own sound (the real `AmbientLoopPlayer`) is only
// checked with the sound choice off, so no audio starts in the simulator: no player is made, an ordinary move keeps the
// offered recipe and a level change offers the new one. Reduce Flashing: the presenter's lights fade over 0.45 s; the
// drawn levels cannot be sampled at a controlled frame time through the host, so an `AuroraLoomLights` copy is stepped at
// 60 Hz with the snapshots of a scripted win and of a flickering target — no half-range change faster than 0.4 s and at
// most 3 half-range crossings per second. Reduce Motion: the drawn snapshot stays at time 0 over several frames.
// Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// A clock the tests move by hand.
@MainActor
final class AuroraLoomTestClock {
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class AuroraLoomFakeLoop: AuroraLoomLoopPlaying {
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
final class AuroraLoomFakeLoopFactory {
    var succeeds: Bool = true
    private(set) var made: [AuroraLoomFakeLoop] = []

    func make() -> AuroraLoomFakeLoop {
        let loop: AuroraLoomFakeLoop = AuroraLoomFakeLoop(succeeds: succeeds)
        made.append(loop)
        return loop
    }

    /// A sound policy starting from `recipe`'s steps and stage that makes its players here.
    func sound(steps: AuroraLoomSteps, stage: AuroraLoomStage) -> AuroraLoomSound {
        AuroraLoomSound(recipe: AuroraLoomSoundRecipe.recipe(steps: steps, stage: stage),
                        makePlayer: { _ in self.make() })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum AuroraLoomAccess {
    typealias Shell = ExperienceShell<AuroraLoomPresenter>

    /// A recording route on `presenter`.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: AuroraLoomTestClock
    }

    /// Opens Aurora Loom with `seed` (seed 0 is level 1).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        try await AuroraLoomTest.open(session, seed: seed, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing,
                                      size: CGSize(width: 360, height: 240))
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: AuroraLoomTestClock = AuroraLoomTestClock()
        shell.presenter.feedback = ExperienceFeedback(hapticSink: haptics, announcementSink: announcements,
                                                      clock: { clock.now }, voiceOverRunning: { true })
        return Recorder(haptics: haptics, announcements: announcements, clock: clock)
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> AuroraLoomExperienceCore {
        try #require(shell.engine.core)
    }

    /// The log entry of `plan`.
    static func entry(_ plan: AuroraLoomFeedbackPlan) -> AuroraLoomFeedbackEntry {
        AuroraLoomFeedbackEntry(text: plan.text, kind: plan.kind, haptic: plan.haptic)
    }

    /// The texts of `entries` that are announced, in order.
    static func texts(_ entries: [AuroraLoomFeedbackEntry]) -> [String] {
        var result: [String] = []
        for entry in entries {
            if let text = entry.text, entry.kind != nil { result.append(text) }
        }
        return result
    }

    /// The haptics of `entries`, in order.
    static func haptics(_ entries: [AuroraLoomFeedbackEntry]) -> [HapticKind] {
        var result: [HapticKind] = []
        for entry in entries {
            if let haptic = entry.haptic { result.append(haptic) }
        }
        return result
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
@Suite(.serialized) struct AuroraLoomAccessibilityTests {
    typealias Access = AuroraLoomAccess

    // MARK: Recorded feedback (FR-R02G0106-002, 003; SC-R02G0106-002)

    /// A wave move through `adjust`, undo, redo, a refused pick, a fresh pick and the certified win: the sinks receive
    /// exactly the plans of `AuroraLoomFeedbackPlan`, in order, and the feedback log holds the same entries.
    @Test func recordedFeedbackThroughThePort() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let recorder: AuroraLoomAccess.Recorder = Access.record(shell)
        var expected: [AuroraLoomFeedbackEntry] = []
        let opening: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)

        // A wave move through the steppers' operation.
        recorder.clock.advance()
        let moved: ActionResult? = presenter.adjust(ribbon: 0, control: 0, by: 1, port: shell.port)
        #expect(moved == .accepted, "\(moved?.code ?? "nil")")
        let afterMove: AuroraLoomExperienceCore = try Access.core(shell)
        try #require(afterMove.play.stage == .playing, "level 1 is not won by one wave step")
        let movePlan: AuroraLoomFeedbackPlan = AuroraLoomFeedbackPlan.after(old: opening, new: afterMove)
        #expect(movePlan.kind == .state)
        #expect(movePlan.haptic == .selection)
        let wave: Int = (opening.play.steps.wave[0] + 1) % 16
        #expect(movePlan.text?.hasPrefix("Ribbon 1 wave \(wave). ") == true, "\(movePlan.text ?? "nil")")
        expected.append(Access.entry(movePlan))

        // Undo.
        recorder.clock.advance()
        let undone: ActionResult = presenter.send("play.undo", port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(afterUndo.play.steps == opening.play.steps)
        let undoPlan: AuroraLoomFeedbackPlan = AuroraLoomFeedbackPlan.after(old: afterMove, new: afterUndo)
        #expect(undoPlan.kind == .state)
        #expect(undoPlan.haptic == .selection)
        let restored: Int = opening.play.steps.wave[0]
        #expect(undoPlan.text?.hasPrefix("Undone: Ribbon 1 wave \(restored). ") == true, "\(undoPlan.text ?? "nil")")
        expected.append(Access.entry(undoPlan))

        // Redo.
        recorder.clock.advance()
        let redone: ActionResult = presenter.send("play.redo", port: shell.port)
        #expect(redone == .accepted, "\(redone.code)")
        let afterRedo: AuroraLoomExperienceCore = try Access.core(shell)
        let redoPlan: AuroraLoomFeedbackPlan = AuroraLoomFeedbackPlan.after(old: afterUndo, new: afterRedo)
        #expect(redoPlan.kind == .state)
        #expect(redoPlan.haptic == .selection)
        #expect(redoPlan.text?.hasPrefix("Redone: Ribbon 1 wave \(wave). ") == true, "\(redoPlan.text ?? "nil")")
        expected.append(Access.entry(redoPlan))

        // A refused pick of a closed level.
        recorder.clock.advance()
        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(!locked.isAccepted)
        let refusedPlan: AuroraLoomFeedbackPlan = AuroraLoomFeedbackPlan.refused(code: locked.code)
        #expect(refusedPlan.text == "That level is not open yet.")
        #expect(refusedPlan.kind == .rejection)
        #expect(refusedPlan.haptic == .error)
        expected.append(Access.entry(refusedPlan))

        // A fresh play of level 1: a level announcement, no haptic.
        recorder.clock.advance()
        let picked: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(picked == .accepted, "\(picked.code)")
        let fresh: AuroraLoomExperienceCore = try Access.core(shell)
        let levelPlan: AuroraLoomFeedbackPlan = AuroraLoomFeedbackPlan.after(old: afterRedo, new: fresh)
        #expect(levelPlan.kind == .level)
        #expect(levelPlan.haptic == nil)
        #expect(levelPlan.text?.hasPrefix("Level 1, band 1, Campaign.") == true, "\(levelPlan.text ?? "nil")")
        expected.append(Access.entry(levelPlan))

        // The certified win: selections, then the outcome with a success haptic.
        let certified: AuroraLoomGenerated = try AuroraLoomExperienceCore.generated(number: 1)
        var previous: AuroraLoomExperienceCore = fresh
        for move in certified.solution.moves {
            recorder.clock.advance()
            let control: Double = move.control == .wave ? 0 : 1
            let result: ActionResult = presenter.send("ribbon.move", [Double(move.ribbon), control, Double(move.step)],
                                                      port: shell.port)
            #expect(result == .accepted, "\(result.code)")
            let next: AuroraLoomExperienceCore = try Access.core(shell)
            expected.append(Access.entry(AuroraLoomFeedbackPlan.after(old: previous, new: next)))
            previous = next
        }
        #expect(previous.play.stage == .won)
        let last: AuroraLoomFeedbackEntry = try #require(expected.last)
        #expect(last.kind == .outcome)
        #expect(last.haptic == .success)
        let spent: Int = previous.play.spent
        #expect(last.text == "Harmony. Level won in \(spent) moves, 3 of 3 stars.", "\(last.text ?? "nil")")

        #expect(presenter.feedbackLog == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected))
        #expect(recorder.announcements.announced.count == expected.count, "every plan here is announced")
    }

    /// Two actions in the same instant: the second haptic is dropped by the planner, the second announcement is held
    /// and posted by `flush()` once the interval has passed; the feedback log keeps both plans.
    @Test func burstsFollowTheSharedPlanners() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let recorder: AuroraLoomAccess.Recorder = Access.record(shell)
        recorder.clock.advance()
        let first: ActionResult? = presenter.adjust(ribbon: 1, control: 1, by: 1, port: shell.port)
        #expect(first == .accepted, "\(first?.code ?? "nil")")
        let second: ActionResult? = presenter.adjust(ribbon: 1, control: 1, by: 1, port: shell.port)
        #expect(second == .accepted, "\(second?.code ?? "nil")")
        #expect(presenter.feedbackLog.count == 2)
        #expect(recorder.haptics.played.count == 1, "the second selection within 0.05 s is dropped")
        #expect(recorder.announcements.announced.count == 1, "the second announcement is held")
        recorder.clock.advance()
        presenter.feedback.flush()
        #expect(recorder.announcements.announced.count == 2)
        let held: String = try #require(presenter.feedbackLog.last?.text)
        #expect(recorder.announcements.announced.last == held)
    }

    // MARK: Adjust alone (SC-R02G0106-001)

    /// Level 1 is won using only `adjust`, following the level-3 hint each time; every move is announced and felt.
    @Test func levelOneWonThroughAdjustAlone() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let recorder: AuroraLoomAccess.Recorder = Access.record(shell)
        var moves: Int = 0
        var core: AuroraLoomExperienceCore = try Access.core(shell)
        while core.play.stage == .playing && moves < 64 {
            let hint: AuroraLoomHint = try #require(core.hint(level: 3))
            let control: AuroraLoomControl = try #require(hint.control)
            let step: Int = try #require(hint.step)
            let index: Int = control == .wave ? 0 : 1
            let current: Int = control == .wave ? core.play.steps.wave[hint.ribbon] : core.play.steps.phase[hint.ribbon]
            recorder.clock.advance()
            let result: ActionResult? = presenter.adjust(ribbon: hint.ribbon, control: index, by: step - current,
                                                         port: shell.port)
            #expect(result == .accepted, "\(result?.code ?? "nil")")
            moves += 1
            core = try Access.core(shell)
            let reached: Int = control == .wave ? core.play.steps.wave[hint.ribbon] : core.play.steps.phase[hint.ribbon]
            #expect(reached == step)
        }
        #expect(core.play.stage == .won)
        #expect(core.play.spent == moves)
        #expect(presenter.feedbackLog.count == moves)
        #expect(recorder.announcements.announced.count == moves, "every move announced")
        #expect(recorder.haptics.played.count == moves, "every move felt")
        #expect(presenter.feedbackLog.last?.kind == .outcome)
        #expect(recorder.haptics.played.last == .success)
    }

    // MARK: Labels, values and wrapping (FR-R02G0106-001)

    /// The steppers' values come from the mirror, which matches the core; the native controls send every action, every
    /// gesture action among them; `adjust` wraps 15 + 1 → 0 and 0 − 1 → 15.
    @Test func controlValuesAndWrapping() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let recorder: AuroraLoomAccess.Recorder = Access.record(shell)
        let allActions: Set<String> = Set(AuroraLoomExperienceCore.actionIDs)
        #expect(presenter.nativeActions == allActions)
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions))
        let opening: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(presenter.mirror.steps == opening.play.steps)
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")

        // Practice raises the allowance so the wrap moves cannot run out.
        recorder.clock.advance()
        let practice: ActionResult = presenter.send("mode.practice", port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        recorder.clock.advance()
        let top: ActionResult = presenter.send("ribbon.move", [2, 0, 15], port: shell.port)
        #expect(top == .accepted, "\(top.code)")
        try #require(try Access.core(shell).play.stage == .playing)
        #expect(presenter.mirror.steps?.wave[2] == 15)

        recorder.clock.advance()
        let up: ActionResult? = presenter.adjust(ribbon: 2, control: 0, by: 1, port: shell.port)
        #expect(up == .accepted, "\(up?.code ?? "nil")")
        #expect(try Access.core(shell).play.steps.wave[2] == 0, "15 + 1 wraps to 0")
        #expect(presenter.mirror.steps?.wave[2] == 0)
        #expect(presenter.mirror.selectedRibbon == 2, "adjust selects its ribbon")
        try #require(try Access.core(shell).play.stage == .playing)

        recorder.clock.advance()
        let down: ActionResult? = presenter.adjust(ribbon: 2, control: 0, by: -1, port: shell.port)
        #expect(down == .accepted, "\(down?.code ?? "nil")")
        #expect(try Access.core(shell).play.steps.wave[2] == 15, "0 − 1 wraps to 15")
        #expect(presenter.mirror.steps?.wave[2] == 15)

        #expect(presenter.adjust(ribbon: 3, control: 0, by: 1, port: shell.port) == nil, "no fourth ribbon")
        let core: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(presenter.mirror.steps == core.play.steps)
        #expect(shell.accessibilitySummary.contains("Ribbon 3: wave 15, phase \(core.play.steps.phase[2])."))
    }

    // MARK: Larger Text (FR-R02G0106-005)

    /// The panel at the largest accessibility text size in a window 320 points wide (iPhone SE) and 1024 points wide
    /// (iPad): the fitting width stays within the window; the hosted scroll view's content stays within the window and
    /// the 520-point readable width, and is taller than at the default text size on the iPhone width.
    @Test func panelAtTheLargestTextSize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
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
                #expect(controller.view.bounds.size == screen, "\(what): bounds")
                let scroll: UIScrollView = try #require(Access.scrollView(in: controller.view), "\(what): scroll view")
                let content: CGSize = scroll.contentSize
                let limit: CGFloat = min(screen.width, AuroraLoomControls.maximumWidth) + 0.5
                #expect(content.width <= limit, "\(what): content width \(content.width)")
                #expect(content.height > 0, "\(what): content height")
                heights.append(content.height)
                window.isHidden = true
            }
            if screen.width < 400 && heights.count == 2 {
                #expect(heights[1] > heights[0], "the text grows: \(heights)")
            }
        }
        // Feature 309 (T-R02G0109-013): the same layout with a step pending, so the Apply and Clear row is shown.
        shell.presenter.stepPending(ribbon: 0, control: 0, by: 1)
        #expect(shell.presenter.mirror.pending != nil)
        for screen in screens {
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
                let what: String = "\(Int(screen.width)) pt at \(size) with a step pending"
                let fitting: CGSize = controller.sizeThatFits(in: CGSize(width: screen.width,
                                                                         height: .greatestFiniteMagnitude))
                #expect(fitting.width <= screen.width + 0.5, "\(what): fitting width \(fitting.width)")
                let scroll: UIScrollView = try #require(Access.scrollView(in: controller.view), "\(what): scroll view")
                let limit: CGFloat = min(screen.width, AuroraLoomControls.maximumWidth) + 0.5
                #expect(scroll.contentSize.width <= limit, "\(what): content width \(scroll.contentSize.width)")
                window.isHidden = true
            }
        }
        shell.presenter.clearPending()
    }

    // MARK: Sound (FR-R02G0106-006; SC-R02G0106-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations.
    @Test func soundStateTable() throws {
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [0, 0, 0], phase: [0, 0, 0])
        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: AuroraLoomFakeLoopFactory = AuroraLoomFakeLoopFactory()
            let sound: AuroraLoomSound = factory.sound(steps: steps, stage: .playing)
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

        // From playing, each input turned off stops the loop and turned on again plays it with the same player.
        let factory: AuroraLoomFakeLoopFactory = AuroraLoomFakeLoopFactory()
        let sound: AuroraLoomSound = factory.sound(steps: steps, stage: .playing)
        sound.setOnScreen(true)
        sound.setWanted(true)
        let loop: AuroraLoomFakeLoop = try #require(factory.made.first)
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

    /// Offers: a different recipe while playing makes a new player (the old one stops); the same recipe does not;
    /// any offer while the sound is off makes none.
    @Test func soundOffersRebuildOnlyOnANewRecipe() {
        let opening: AuroraLoomSteps = AuroraLoomSteps(wave: [0, 0, 0], phase: [0, 0, 0])
        let moved: AuroraLoomSteps = AuroraLoomSteps(wave: [1, 0, 0], phase: [0, 0, 0])
        let silent: AuroraLoomFakeLoopFactory = AuroraLoomFakeLoopFactory()
        let off: AuroraLoomSound = silent.sound(steps: opening, stage: .playing)
        off.setOnScreen(true)
        off.offer(AuroraLoomSoundRecipe.recipe(steps: moved, stage: .playing))
        off.offer(AuroraLoomSoundRecipe.recipe(steps: moved, stage: .won))
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)

        let factory: AuroraLoomFakeLoopFactory = AuroraLoomFakeLoopFactory()
        let sound: AuroraLoomSound = factory.sound(steps: opening, stage: .playing)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1)
        sound.offer(AuroraLoomSoundRecipe.recipe(steps: opening, stage: .playing))
        #expect(sound.playersMade == 1, "the same recipe keeps the player")
        sound.offer(AuroraLoomSoundRecipe.recipe(steps: moved, stage: .won))
        #expect(sound.playersMade == 2, "a new recipe makes a new player")
        #expect(factory.made.count == 2)
        if factory.made.count == 2 {
            #expect(!factory.made[0].isPlaying, "the old player stopped")
            #expect(factory.made[1].isPlaying)
        }
        sound.offer(AuroraLoomSoundRecipe.recipe(steps: moved, stage: .won))
        #expect(sound.playersMade == 2)
    }

    /// A `play()` that fails leaves `started` false and the choice on, and makes nothing else happen.
    @Test func failingPlayLeavesTheChoiceOn() {
        let factory: AuroraLoomFakeLoopFactory = AuroraLoomFakeLoopFactory()
        factory.succeeds = false
        let sound: AuroraLoomSound = factory.sound(steps: AuroraLoomSteps(wave: [2, 4, 6], phase: [0, 0, 0]),
                                                   stage: .playing)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1)
        #expect(!sound.started)
        #expect(sound.wanted)
        #expect(sound.shouldPlay)
        #expect(factory.made.first?.plays == 1)
        #expect(factory.made.first?.isPlaying == false)
    }

    /// The presenter's own sound with the choice off (the real `AmbientLoopPlayer` is never started in the simulator
    /// here): no player is made; an ordinary move keeps the offered recipe, a level change offers the new level's one.
    @Test func presenterSoundOffersAtLevelChangesOnly() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        _ = Access.record(shell)
        presenter.controlsAppeared()
        #expect(!presenter.sound.wanted)
        let opening: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(presenter.sound.recipe == AuroraLoomSoundRecipe.recipe(steps: opening.play.steps,
                                                                        stage: opening.play.stage))
        let moved: ActionResult? = presenter.adjust(ribbon: 0, control: 0, by: 1, port: shell.port)
        #expect(moved == .accepted, "\(moved?.code ?? "nil")")
        #expect(presenter.sound.recipe == AuroraLoomSoundRecipe.recipe(steps: opening.play.steps,
                                                                        stage: opening.play.stage),
                "an ordinary move does not offer a recipe")
        // A fresh play of level 1 (a level opening offers the opening recipe again).
        let fresh: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(fresh == .accepted, "\(fresh.code)")

        // The certified win: the moves offer nothing, the end of the play offers the won recipe.
        let certified: AuroraLoomGenerated = try AuroraLoomExperienceCore.generated(number: 1)
        for move in certified.solution.moves {
            let control: Double = move.control == .wave ? 0 : 1
            let result: ActionResult = presenter.send("ribbon.move", [Double(move.ribbon), control, Double(move.step)],
                                                      port: shell.port)
            #expect(result == .accepted, "\(result.code)")
            let now: AuroraLoomExperienceCore = try Access.core(shell)
            if now.play.stage == .playing {
                #expect(presenter.sound.recipe == AuroraLoomSoundRecipe.recipe(steps: opening.play.steps,
                                                                                stage: opening.play.stage),
                        "a move of the play does not offer a recipe")
            }
        }
        let won: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(presenter.sound.recipe == AuroraLoomSoundRecipe.recipe(steps: won.play.steps, stage: .won),
                "the end of the play offers the won recipe")

        // A mode change opens the level afresh and offers its recipe.
        let practice: ActionResult = presenter.send("mode.practice", port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        let changed: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(changed.play.stage == .playing)
        #expect(presenter.sound.recipe == AuroraLoomSoundRecipe.recipe(steps: changed.play.steps,
                                                                        stage: changed.play.stage),
                "a level or mode change offers the fresh play's recipe")
        #expect(presenter.sound.playersMade == 0, "sound off makes no player")
        presenter.controlsDisappeared()
        presenter.sceneActive(false)
        #expect(presenter.sound.playersMade == 0)
        #expect(!presenter.sound.shouldPlay)
    }

    // MARK: Reduce Flashing and Reduce Motion (FR-R02G0106-004; SC-R02G0106-003)

    /// Under Reduce Flashing the presenter fades over 0.45 s; lights stepped at 60 Hz through a scripted win and a
    /// flickering target change by more than half their range no faster than 0.4 s and cross half their range at most
    /// 3 times per second. Without it the same win fades faster (the measure sees the fades).
    @Test func reduceFlashingFadesSlowly() async throws {
        let reduced: AuroraLoomPresenter = AuroraLoomPresenter(reduceMotion: false, reduceFlashing: true)
        #expect(reduced.lights.reducedFlash)
        #expect(reduced.lights.duration == AuroraLoomLights.reducedFlashDuration)
        #expect(AuroraLoomLights.reducedFlashDuration == 0.45)
        let normal: AuroraLoomPresenter = AuroraLoomPresenter(reduceMotion: false, reduceFlashing: false)
        #expect(normal.lights.duration == AuroraLoomLights.normalDuration)

        // The snapshots of a certified win of level 1, taken through the port.
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        var snapshots: [AuroraLoomSceneSnapshot] = [try Access.core(shell).snapshot(time: 0)]
        let certified: AuroraLoomGenerated = try AuroraLoomExperienceCore.generated(number: 1)
        for move in certified.solution.moves {
            let control: Double = move.control == .wave ? 0 : 1
            let result: ActionResult = shell.port.send("ribbon.move", [Double(move.ribbon), control, Double(move.step)])
            #expect(result == .accepted, "\(result.code)")
            snapshots.append(try Access.core(shell).snapshot(time: 0))
        }
        let won: AuroraLoomSceneSnapshot = try #require(snapshots.last)
        #expect(won.stage == .won)

        let frameRate: Double = 60
        let frame: Double = 1 / frameRate
        for reducedFlash in [true, false] {
            // A move every 0.1 s, then a second of the won loom.
            var lights: AuroraLoomLights = AuroraLoomLights(reducedFlash: reducedFlash)
            lights.settle(to: snapshots[0])
            var samples: [[Double]] = [lights.levels]
            for index in 1..<snapshots.count {
                for _ in 0..<6 {
                    lights.step(toward: snapshots[index], elapsed: frame)
                    samples.append(lights.levels)
                }
            }
            for _ in 0..<60 {
                lights.step(toward: won, elapsed: frame)
                samples.append(lights.levels)
            }
            #expect(lights.glow == 1, "the glow reaches full")
            let shortest: Double = AuroraLoomLights.shortestHalfRangeChange(samples, frameRate: frameRate)
            #expect(shortest.isFinite, "the win makes a change of more than half the range")
            if reducedFlash {
                #expect(shortest >= 0.4, "Reduce Flashing: shortest half-range change \(shortest) s")
                let crossings: Double = AuroraLoomLights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
                #expect(crossings <= 3, "Reduce Flashing: \(crossings) crossings per second")
            } else {
                #expect(shortest < 0.4, "normal fades are quicker: \(shortest) s")
            }
        }

        // A target flickering between the opening and the won loom every 2 frames for 2 seconds.
        var flicker: AuroraLoomLights = AuroraLoomLights(reducedFlash: true)
        flicker.settle(to: snapshots[0])
        var samples: [[Double]] = [flicker.levels]
        for index in 0..<120 {
            let target: AuroraLoomSceneSnapshot = (index / 2) % 2 == 0 ? won : snapshots[0]
            flicker.step(toward: target, elapsed: frame)
            samples.append(flicker.levels)
        }
        for _ in 0..<60 {
            flicker.step(toward: won, elapsed: frame)
            samples.append(flicker.levels)
        }
        let crossings: Double = AuroraLoomLights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
        #expect(crossings <= 3, "flickering target: \(crossings) crossings per second")
        let shortest: Double = AuroraLoomLights.shortestHalfRangeChange(samples, frameRate: frameRate)
        #expect(shortest >= 0.4, "flickering target: shortest half-range change \(shortest) s")
    }

    /// Under Reduce Motion the drawn snapshot stays at time 0 and equal over several frames.
    @Test func reduceMotionFramesIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceMotion: true)
        let first: AuroraLoomSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        try AuroraLoomTest.draw(session, frames: 4)
        let second: AuroraLoomSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(first.time == 0)
        #expect(second == first)
        let core: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(second == core.snapshot(time: 0))
    }
}
#endif
