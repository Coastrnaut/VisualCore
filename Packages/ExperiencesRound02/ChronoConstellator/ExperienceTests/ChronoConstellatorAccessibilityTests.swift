// ChronoConstellatorAccessibilityTests — feature 356 (R02-G06-06) T-R02G0606-006 (FR-R02G0606-001 … 006;
// SC-R02G0606-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Colorfall Canyons' feature-346 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; a phase change, its
// undo, a hold, a step, a rewind, an undo of the rewind and a refusal (a locked level) record exactly
// `ChronoConstellatorFeedbackPlan.after(old:new:)` and `refused(code:)` in the sinks and in the presenter's feedback
// log (several texts are also written out from clarification Q1); a second description of the same state routes
// nothing. Level 1 is won with the panel's operations alone: the star picker (`pickStar(±1)`), Phase − / + (each a
// `star.phase [star, (phase ± 1) mod L]` from the mirror, as the controls send it) and Run (`time.step` of the ticks
// left, at most 1,200), following `ChronoConstellatorExperienceCore.certifiedActions(1)`; every pick and step is
// announced and the winning step routes only the outcome, with a success haptic. A star drag in progress (the
// candidate cell) announces nothing; its released phase change is announced once. Sound: the presenter makes its own
// `ChronoConstellatorSound` with the real `AmbientLoopPlayer`, so the state table, the offers and a failing `play()`
// use a `ChronoConstellatorSound` with an injected recording player; the presenter's sound is only driven with the
// sound off or off screen or inactive (no audio starts). Labels: `progressValue` and the summary element's words
// (`summaryText(core:)`, also written out). Reduce Flashing: a target ring whose star reaches or leaves its target
// eases over 0.45 s in drawn off-screen stills 1/60 s apart (strictly between start and target at 0.1 s and 0.4 s).
// Reduce Motion: two stills of the same state at different frame times are byte-identical and the drawn snapshot
// keeps time 0. Synthetic data, explicit types, plain loops, no nested closure literals, no sleep, no wall-clock
// assertion; few frames, each test short.
#if os(iOS)
import ChronoConstellatorCore
import CoreGraphics
import Foundation
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class ChronoConstellatorA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class ChronoConstellatorA11yLoop: ChronoConstellatorLoopPlaying {
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
final class ChronoConstellatorA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [ChronoConstellatorA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> ChronoConstellatorA11yLoop {
        let loop: ChronoConstellatorA11yLoop = ChronoConstellatorA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> ChronoConstellatorSound {
        ChronoConstellatorSound(recipe: recipe, makePlayer: { next in self.make(next) })
    }
}

/// A change that moves one target ring: the control and values to send and the star whose ring changes.
struct ChronoConstellatorA11yRingChange {
    let control: String
    let values: [Double]
    let star: Int
}

/// Helpers of the accessibility tests.
@MainActor
enum ChronoConstellatorA11y {
    typealias Shell = ExperienceShell<ChronoConstellatorPresenter>
    typealias Plan = ChronoConstellatorFeedbackPlan
    typealias Core = ChronoConstellatorExperienceCore

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: ChronoConstellatorA11yClock
    }

    /// The still size of the Reduce Flashing and Reduce Motion tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64
    /// The frame rate of the sampled stills.
    static let frameRate: Double = 60
    /// The most ticks one `time.step` runs (the panel's Run cap).
    static let maxStep: Int = 1_200

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await ChronoConstellatorTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                                 reduceFlashing: reduceFlashing,
                                                                 size: CGSize(width: 360, height: 240))
        let opening: Core = try ChronoConstellatorTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: ChronoConstellatorA11yClock = ChronoConstellatorA11yClock()
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
    static func core(_ shell: Shell) throws -> Core {
        try ChronoConstellatorTest.core(shell)
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
    static func log(_ presenter: ChronoConstellatorPresenter, after count: Int) -> [Plan] {
        Array(presenter.feedbackLog.dropFirst(count))
    }

    /// "1 edit left" or "n edits left", written out here.
    static func leftText(_ count: Int) -> String { count == 1 ? "1 edit left" : "\(count) edits left" }

    /// "1 tick" or "n ticks", written out here.
    static func ticksText(_ count: Int) -> String { count == 1 ? "1 tick" : "\(count) ticks" }

    /// "row r, column c" of `cell` (1-based), written out here.
    static func cellText(_ cell: Int, columns: Int) -> String {
        "row \(cell / max(columns, 1) + 1), column \(cell % max(columns, 1) + 1)"
    }

    /// "Star k (shape)" of the 0-based `star`, written out here.
    static func starText(_ star: Int) -> String {
        "Star \(star + 1) (\(ChronoConstellatorLevel.shape(of: star).name))"
    }

    /// The summary element's words of `core`, written out from clarification Q5 (from the snapshot at time 0).
    static func summaryText(_ core: Core) -> String {
        let snapshot: ChronoConstellatorSceneSnapshot = core.snapshot(time: 0)
        var parts: [String] = []
        for star in snapshot.stars.indices {
            var holds: [String] = []
            for hold in snapshot.holds where hold.star == star {
                holds.append("holds from tick \(hold.start) for \(ticksText(hold.length))")
            }
            let holdWords: String = holds.isEmpty ? "no holds" : holds.joined(separator: " and ")
            let side: String = snapshot.stars[star].onTarget ? "on" : "off"
            parts.append(starText(star) + ": " + cellText(snapshot.stars[star].cell, columns: snapshot.columns)
                + ", start phase \(snapshot.phases[star]), " + holdWords + ", " + side + " its target.")
        }
        return "Tick \(snapshot.tick) of \(snapshot.tickLimit). \(leftText(snapshot.remaining)). "
            + parts.joined(separator: " ")
    }

    /// The panel's progress value of `core`, written out: "Level n, tick t of T, e edits left".
    static func progressText(_ core: Core) -> String {
        let snapshot: ChronoConstellatorSceneSnapshot = core.snapshot(time: 0)
        return "Level \(core.levelNumber), tick \(snapshot.tick) of \(snapshot.tickLimit), "
            + "\(snapshot.remaining) edits left"
    }

    /// The ticks the panel's Run button sends for `mirror`: the ticks left, at least 1 and at most 1,200.
    static func runTicks(_ mirror: ChronoConstellatorMirror) -> Int {
        max(1, min(maxStep, mirror.tickLimit - mirror.tick))
    }

    /// `core` after applying `control` with `values` itself, and the adapter's answer.
    static func applied(_ core: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = core
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    /// The first star whose on-target flag differs between `a` and `b`; nil when none does.
    static func changedStar(_ a: Core, _ b: Core) -> Int? {
        let before: [Bool] = ChronoConstellatorSoundRecipe.onTarget(a.snapshot(time: 0))
        let after: [Bool] = ChronoConstellatorSoundRecipe.onTarget(b.snapshot(time: 0))
        guard before.count == after.count else { return nil }
        for index in before.indices where before[index] != after[index] { return index }
        return nil
    }

    /// An accepted action from `core` that changes some star's on-target flag (so its ring's target changes): first a
    /// step of 1 … 60 ticks, else a start phase change at tick 0. Nil when none is found.
    static func ringChange(_ core: Core) -> ChronoConstellatorA11yRingChange? {
        let limit: Int = core.play.level.tickLimit
        var ticks: Int = 1
        while ticks <= min(limit, 60) {
            let values: [Double] = [Double(ticks)]
            let next = applied(core, "time.step", values)
            if next.result == .accepted, let star = changedStar(core, next.core) {
                return ChronoConstellatorA11yRingChange(control: "time.step", values: values, star: star)
            }
            ticks += 1
        }
        let stars: [ChronoConstellatorStar] = core.play.level.stars
        for star in stars.indices {
            for phase in 0..<stars[star].length {
                let values: [Double] = [Double(star), Double(phase)]
                let next = applied(core, "star.phase", values)
                if next.result == .accepted, let moved = changedStar(core, next.core) {
                    return ChronoConstellatorA11yRingChange(control: "star.phase", values: values, star: moved)
                }
            }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct ChronoConstellatorAccessibilityTests {
    typealias Access = ChronoConstellatorA11y
    typealias Script = ChronoConstellatorGestureScript
    typealias Plan = ChronoConstellatorFeedbackPlan
    typealias Presenter = ChronoConstellatorPresenter
    typealias Core = ChronoConstellatorExperienceCore

    // MARK: Recorded feedback (FR-R02G0606-002, 003; SC-R02G0606-002)

    /// A phase change, its undo, a hold, a step, a rewind, an undo of the rewind and a refusal: the sinks receive
    /// exactly the plans of `ChronoConstellatorFeedbackPlan`, in order, and the feedback log holds the same plans;
    /// several texts written out; a second description of the same state routes nothing; the panel shows the
    /// refusal's words.
    @Test func recordedFeedbackThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        var expected: [Plan] = []
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        let level: ChronoConstellatorLevel = opening.play.level
        let columns: Int = level.columns
        try #require(level.budget >= 1, "level 1 allows an edit")
        let length: Int = level.stars[0].length
        try #require(length >= 2, "star 1 has another loop cell")
        var previous: Core = opening

        // A phase change of star 1, one cell later round its loop.
        let phase: Int = (opening.snapshot(time: 0).phases[0] + 1) % length
        recorder.clock.advance()
        let phased: ActionResult = presenter.send("star.phase", [0, Double(phase)], port: shell.port)
        #expect(phased == .accepted, "\(phased.code)")
        #expect(presenter.mirror.message == nil)
        var now: Core = try Access.core(shell)
        let phasePlan: Plan = Plan.after(old: previous, new: now)
        let phaseText: String = "\(Access.starText(0)) starts at "
            + "\(Access.cellText(level.stars[0].loop[phase], columns: columns)). "
            + "\(Access.leftText(now.play.remaining))."
        #expect(phasePlan.text == phaseText, "\(phasePlan.text ?? "nil")")
        #expect(phasePlan.kind == .state)
        #expect(phasePlan.haptic == .selection)
        expected.append(phasePlan)
        var count: Int = presenter.feedbackLog.count
        _ = presenter.describe(now)
        #expect(presenter.feedbackLog.count == count, "describing the same state again routes nothing")
        previous = now

        // Undo the phase change (frees the edit for the hold).
        recorder.clock.advance()
        let undone: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        now = try Access.core(shell)
        let undoPlan: Plan = Plan.after(old: previous, new: now)
        let undoText: String = "Undone. Tick 0 of \(level.tickLimit). \(Access.leftText(now.play.remaining))."
        #expect(undoPlan.text == undoText, "\(undoPlan.text ?? "nil")")
        #expect(undoPlan.kind == .state)
        #expect(undoPlan.haptic == .selection)
        expected.append(undoPlan)
        count = presenter.feedbackLog.count
        _ = presenter.describe(now)
        #expect(presenter.feedbackLog.count == count)
        previous = now

        // A hold of star 1 from tick 1 for 2 ticks.
        recorder.clock.advance()
        let held: ActionResult = presenter.send("star.hold", ChronoConstellatorTest.holdValues, port: shell.port)
        #expect(held == .accepted, "\(held.code)")
        now = try Access.core(shell)
        let holdPlan: Plan = Plan.after(old: previous, new: now)
        let holdText: String = "Star 1 holds from tick 1 for 2 ticks. \(Access.leftText(now.play.remaining))."
        #expect(holdPlan.text == holdText, "\(holdPlan.text ?? "nil")")
        #expect(holdPlan.kind == .state)
        #expect(holdPlan.haptic == .selection)
        expected.append(holdPlan)
        count = presenter.feedbackLog.count
        _ = presenter.describe(now)
        #expect(presenter.feedbackLog.count == count)
        previous = now

        // A step of one tick.
        recorder.clock.advance()
        let stepped: ActionResult = presenter.send("time.step", [1], port: shell.port)
        #expect(stepped == .accepted, "\(stepped.code)")
        now = try Access.core(shell)
        let stepPlan: Plan = Plan.after(old: previous, new: now)
        #expect(stepPlan != Plan.none, "a step is announced")
        if now.play.stage == .playing {
            #expect(stepPlan.text?.hasPrefix("Tick 1 of \(level.tickLimit). ") == true, "\(stepPlan.text ?? "nil")")
            #expect(stepPlan.kind == .state)
            #expect(stepPlan.haptic == .selection)
        }
        expected.append(stepPlan)
        count = presenter.feedbackLog.count
        _ = presenter.describe(now)
        #expect(presenter.feedbackLog.count == count)
        previous = now

        // A rewind, then its undo.
        recorder.clock.advance()
        let rewound: ActionResult = presenter.send("time.rewind", [], port: shell.port)
        #expect(rewound == .accepted, "\(rewound.code)")
        now = try Access.core(shell)
        let rewindPlan: Plan = Plan.after(old: previous, new: now)
        #expect(rewindPlan.text == "Rewound to tick 0.", "\(rewindPlan.text ?? "nil")")
        #expect(rewindPlan.kind == .state)
        #expect(rewindPlan.haptic == .selection)
        expected.append(rewindPlan)
        count = presenter.feedbackLog.count
        _ = presenter.describe(now)
        #expect(presenter.feedbackLog.count == count)
        previous = now

        recorder.clock.advance()
        let unrewound: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(unrewound == .accepted, "\(unrewound.code)")
        now = try Access.core(shell)
        let unrewindPlan: Plan = Plan.after(old: previous, new: now)
        let unrewindText: String = "Undone. Tick \(now.play.tick) of \(level.tickLimit). "
            + "\(Access.leftText(now.play.remaining))."
        #expect(unrewindPlan != Plan.none, "the undo is announced")
        if now.play.stage == .playing {
            #expect(unrewindPlan.text == unrewindText, "\(unrewindPlan.text ?? "nil")")
            #expect(unrewindPlan.haptic == .selection)
        }
        expected.append(unrewindPlan)
        count = presenter.feedbackLog.count
        _ = presenter.describe(now)
        #expect(presenter.feedbackLog.count == count)

        // A refusal: a locked level.
        let digest: String = try ChronoConstellatorTest.digest(shell)
        recorder.clock.advance()
        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(!locked.isAccepted)
        #expect(locked.code.contains(ChronoConstellatorExperienceRule.locked), "\(locked.code)")
        let lockedPlan: Plan = Plan.refused(code: locked.code)
        #expect(lockedPlan.text == "That level is not open yet.", "\(lockedPlan.text ?? "nil")")
        #expect(lockedPlan.kind == .rejection)
        #expect(lockedPlan.haptic == .error)
        #expect(presenter.mirror.message == "That level is not open yet.", "the panel shows the same words")
        let after: String = try ChronoConstellatorTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing")
        expected.append(lockedPlan)
        count = presenter.feedbackLog.count
        _ = presenter.describe(try Access.core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing")

        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected))
        #expect(recorder.announcements.announced.count == expected.count, "every plan here is announced")
    }

    // MARK: The panel alone (SC-R02G0606-001)

    /// Level 1 (seed 0) is won with the panel's operations alone, following the certified actions: the star picker,
    /// Phase − / + (the shorter way round the loop) and Run; every pick and step announced; the winning step routes
    /// only the outcome, with a success haptic.
    @Test func levelOneWonWithThePanelOperations() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        let actions: [ChronoConstellatorAction] = Core.certifiedActions(1)
        try #require(!actions.isEmpty, "level 1 has certified actions")
        var routed: Int = 0
        var winStepRouted: Int = -1

        for (index, action) in actions.enumerated() {
            let stage: ChronoConstellatorStage = try Access.core(shell).play.stage
            guard stage == .playing else { break }
            switch action {
            case .phase(let star, let target):
                let starCount: Int = presenter.mirror.starNames.count
                var presses: Int = 0
                while presenter.mirror.pickedStar != star && presses < starCount {
                    recorder.clock.advance()
                    let before: Int = presenter.feedbackLog.count
                    presenter.pickStar(1)
                    presses += 1
                    routed += 1
                    #expect(presenter.feedbackLog.count == before + 1, "a pick is announced")
                    let pickedText: String = "\(Access.starText(presenter.mirror.pickedStar)) picked."
                    #expect(presenter.feedbackLog.last == Plan.picked(star: presenter.mirror.pickedStar))
                    #expect(recorder.announcements.announced.last == pickedText,
                            "\(recorder.announcements.announced.last ?? "nil")")
                }
                #expect(presenter.mirror.pickedStar == star, "action \(index): the picker reached star \(star)")
                let length: Int = presenter.mirror.loopLengths[star]
                let current: Int = presenter.mirror.phases[star]
                let forward: Int = ((target - current) % length + length) % length
                let delta: Int = forward <= length - forward ? 1 : -1
                let steps: Int = min(forward, length - forward)
                for press in 0..<steps {
                    let next: Int = try #require(presenter.mirror.phase(after: delta))
                    let old: Core = try Access.core(shell)
                    recorder.clock.advance()
                    let result: ActionResult = presenter.send("star.phase", [Double(star), Double(next)],
                                                              port: shell.port)
                    #expect(result == .accepted, "action \(index) press \(press): \(result.code)")
                    let new: Core = try Access.core(shell)
                    let plan: Plan = Plan.after(old: old, new: new)
                    #expect(plan.text != nil, "action \(index) press \(press) is announced")
                    #expect(presenter.feedbackLog.last == plan)
                    #expect(recorder.announcements.announced.last == plan.text)
                    routed += 1
                }
                #expect(presenter.mirror.phases[star] == target, "action \(index): star \(star) at phase \(target)")
            case .step:
                let ticks: Int = Access.runTicks(presenter.mirror)
                let old: Core = try Access.core(shell)
                let before: Int = presenter.feedbackLog.count
                recorder.clock.advance()
                let result: ActionResult = presenter.send("time.step", [Double(ticks)], port: shell.port)
                #expect(result == .accepted, "action \(index): \(result.code)")
                let new: Core = try Access.core(shell)
                let plan: Plan = Plan.after(old: old, new: new)
                #expect(plan.text != nil, "action \(index) is announced")
                #expect(presenter.feedbackLog.last == plan)
                if new.play.stage == .won { winStepRouted = presenter.feedbackLog.count - before }
                routed += 1
            case .hold, .release, .rewind:
                Issue.record("action \(index): the certified actions are phase changes and a step")
            }
        }

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(winStepRouted == 1, "the winning step routes only the outcome")
        let stars: Int = ChronoConstellatorProgress.stars(edits: won.play.spent, smallest: won.certifiedSmallest)
        let spentText: String = won.play.spent == 1 ? "1 edit" : "\(won.play.spent) edits"
        let winText: String = "Every star is on its target. Level won with \(spentText), \(stars) of 3 stars."
        let plans: [Plan] = Access.log(presenter, after: logBase)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced.last == winText)
        #expect(plans.count == routed, "every pick and step announced")
        #expect(recorder.announcements.announced.count == routed)
        #expect(recorder.announcements.announced == Access.texts(plans))
        #expect(recorder.haptics.played == Access.haptics(plans), "\(recorder.haptics.played)")
        #expect(recorder.haptics.played.last == .success)
        #expect(presenter.mirror.status == "Won")
    }

    // MARK: Drag preview (edge case)

    /// A star drag in progress (finger down and moved, not released; the candidate cell outlined) adds no
    /// announcement, plan or haptic; the release announces its phase change once.
    @Test func aDragPreviewIsNotAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let presenter: Presenter = shell.presenter
        let before: Core = try Access.core(shell)
        _ = presenter.describe(before)
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let target: ChronoConstellatorDragTarget =
            try #require(try Script.dragTarget(shell), "a star and another loop cell visible at the authored orbit")
        let digest: String = try ChronoConstellatorTest.digest(shell)
        var time: Double = 0

        recorder.clock.advance()
        Script.dragWithoutRelease(shell, from: target.start, to: target.end, time: &time)
        #expect(presenter.gestures.state == .starDrag)
        #expect(presenter.gestures.candidateCell == target.cell, "the drag outlines the candidate cell")
        let text: String = presenter.describe(try Access.core(shell))
        #expect(text.contains("would start at"), "\(text)")
        try ChronoConstellatorTest.draw(session)
        #expect(recorder.announcements.announced.isEmpty, "the preview is not announced")
        #expect(presenter.feedbackLog.count == logBase, "the preview plans nothing")
        #expect(recorder.haptics.played.isEmpty, "the preview plays no haptic")
        let during: String = try ChronoConstellatorTest.digest(shell)
        #expect(during == digest, "nothing is sent before the release")

        recorder.clock.advance()
        Script.touch(shell, id: 1, .ended, at: target.end, time: &time)
        let after: Core = try Access.core(shell)
        #expect(after.snapshot(time: 0).phases[target.star] == target.index, "exactly the dragged phase")
        let plan: Plan = Plan.after(old: before, new: after)
        let columns: Int = before.play.level.columns
        let expectedText: String = "\(Access.starText(target.star)) starts at "
            + "\(Access.cellText(target.cell, columns: columns)). \(Access.leftText(after.play.remaining))."
        #expect(plan.text == expectedText, "\(plan.text ?? "nil")")
        #expect(plan.haptic == .selection)
        let expected: [Plan] = [plan]
        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected), "the release is announced once")
        #expect(recorder.haptics.played == Access.haptics(expected))
    }

    // MARK: Sound (FR-R02G0606-006; SC-R02G0606-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; a `play()` that fails changes nothing else; the recipe is rebuilt only for a new recipe or the toggle
    /// turning on, never for the same recipe offered again.
    @Test func soundStateTable() throws {
        let none: AmbientLoopRecipe = ChronoConstellatorSoundRecipe.recipe(onTarget: [false, false], stage: .playing)
        let one: AmbientLoopRecipe = ChronoConstellatorSoundRecipe.recipe(onTarget: [true, false], stage: .playing)
        let won: AmbientLoopRecipe = ChronoConstellatorSoundRecipe.recipe(onTarget: [true, true], stage: .won)
        try #require(none != one, "another star on target sounds different")
        try #require(one != won, "a won play sounds different")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: ChronoConstellatorA11yLoopFactory = ChronoConstellatorA11yLoopFactory()
            let sound: ChronoConstellatorSound = factory.sound(none)
            sound.setOnScreen(onScreen)
            sound.setActive(active)
            sound.setWanted(wanted)
            let expected: Bool = wanted && onScreen && active
            #expect(sound.shouldPlay == expected, "combination \(combination)")
            #expect(sound.started == expected, "combination \(combination)")
            #expect(sound.playersMade == (expected ? 1 : 0), "combination \(combination)")
            let playing: Bool = factory.made.last?.isPlaying ?? false
            #expect(playing == expected, "combination \(combination)")
            if !wanted {
                #expect(factory.made.isEmpty, "sound off makes no player (combination \(combination))")
                #expect(sound.player == nil)
            }
        }

        // Each input turning off stops a playing loop; turning back on plays again.
        let toggles: ChronoConstellatorA11yLoopFactory = ChronoConstellatorA11yLoopFactory()
        let live: ChronoConstellatorSound = toggles.sound(none)
        live.setOnScreen(true)
        live.setWanted(true)
        #expect(live.started)
        live.setActive(false)
        #expect(!live.started, "an inactive scene stops the loop")
        #expect(toggles.made.first?.isPlaying == false)
        live.setActive(true)
        #expect(live.started)
        live.setOnScreen(false)
        #expect(!live.started, "controls off screen stop the loop")
        #expect(toggles.made.first?.isPlaying == false)
        live.setOnScreen(true)
        #expect(live.started)
        #expect(live.playersMade == 1, "the same recipe keeps its player")

        // A failing play: the choice stays on, nothing else moves.
        let failing: ChronoConstellatorA11yLoopFactory = ChronoConstellatorA11yLoopFactory()
        failing.succeeds = false
        let broken: ChronoConstellatorSound = failing.sound(none)
        broken.setOnScreen(true)
        broken.setWanted(true)
        #expect(broken.playersMade == 1)
        #expect(!broken.started)
        #expect(broken.wanted)
        #expect(broken.onScreen)
        #expect(broken.active)
        #expect(broken.shouldPlay)
        #expect(broken.recipe == none)
        #expect(failing.made.first?.plays == 1)
        #expect(failing.made.first?.isPlaying == false)
        #expect(failing.made.first?.stops == 0)

        // The sound off: offers make no player but are kept.
        let silent: ChronoConstellatorA11yLoopFactory = ChronoConstellatorA11yLoopFactory()
        let off: ChronoConstellatorSound = silent.sound(none)
        off.setOnScreen(true)
        off.offer(one)
        off.offer(won)
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)
        #expect(off.recipe == won, "kept for the next start")

        // Rebuilds only at the named moments.
        let factory: ChronoConstellatorA11yLoopFactory = ChronoConstellatorA11yLoopFactory()
        let sound: ChronoConstellatorSound = factory.sound(none)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(none) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(one)
        #expect(sound.playersMade == 2, "a change of the stars on target makes a new player")
        #expect(factory.made.count == 2)
        if factory.made.count == 2 {
            #expect(!factory.made[0].isPlaying, "the old player stopped")
            #expect(factory.made[1].isPlaying)
        }
        sound.offer(won)
        #expect(sound.playersMade == 3, "a change of the stage makes a new player")
        #expect(sound.playerRecipe == won)
        sound.setWanted(false)
        #expect(!sound.started)
        sound.offer(none)
        #expect(sound.playersMade == 3, "an offer while off makes no player")
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "the toggle turning on plays the latest recipe")
        #expect(sound.playerRecipe == none)
        #expect(factory.recipes == [none, one, won, none])
        sound.setWanted(false)
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "toggling with the same recipe keeps the player")
        #expect(sound.started)
    }

    /// The presenter's own sound (real `AmbientLoopPlayer`; never started here): off by default; its recipe follows
    /// the described core; drawn frames leave it; `setSound`, `controlsAppeared`/`Disappeared` and `sceneActive` set
    /// the policy's inputs, and with any one of them off no player is made.
    @Test func presenterSoundFollowsTheCore() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        presenter.controlsDisappeared()
        #expect(!presenter.sound.onScreen)
        #expect(!presenter.sound.wanted)
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        let opening: Core = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")

        try ChronoConstellatorTest.draw(session, frames: 3)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "drawn frames leave the recipe")
        #expect(presenter.sound.playersMade == 0)

        // Off, on screen and active: still no player.
        presenter.controlsAppeared()
        #expect(presenter.sound.onScreen)
        #expect(!presenter.sound.shouldPlay, "the sound is off")
        #expect(presenter.sound.playersMade == 0)
        presenter.controlsDisappeared()
        #expect(!presenter.sound.onScreen)

        // A change of the stars on target or the stage offers the new recipe.
        let change: ChronoConstellatorA11yRingChange? = Access.ringChange(opening)
        if let change {
            let result: ActionResult = presenter.send(change.control, change.values, port: shell.port)
            #expect(result == .accepted, "\(result.code)")
            let moved: Core = try Access.core(shell)
            #expect(presenter.sound.recipe == Presenter.recipe(moved), "the recipe follows the stars on target")
        }

        // On while off screen: the choice is kept, nothing plays.
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        #expect(!presenter.sound.started)
        #expect(presenter.sound.playersMade == 0, "no player is made off screen")

        // On and inactive, then on screen: still nothing plays.
        presenter.sceneActive(false)
        #expect(!presenter.sound.active)
        presenter.controlsAppeared()
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the loop silent")
        #expect(presenter.sound.playersMade == 0)

        // Off again, then back to the defaults without ever playing.
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        presenter.sceneActive(true)
        #expect(presenter.sound.active)
        #expect(!presenter.sound.shouldPlay)
        presenter.controlsDisappeared()
        #expect(presenter.sound.playersMade == 0, "the sound off makes no player")
    }

    // MARK: Labels and values (FR-R02G0606-001, 005)

    /// The panel's progress value, the picked star's labels and the summary element's words, written out: at the
    /// opening and after a step.
    @Test func labelsAndValues() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        let opening: Core = try Access.core(shell)
        let mirror: ChronoConstellatorMirror = presenter.mirror
        #expect(ChronoConstellatorControls.progressValue(mirror) == Access.progressText(opening),
                "\(ChronoConstellatorControls.progressValue(mirror))")
        #expect(mirror.summary == Plan.summaryText(core: opening))
        #expect(mirror.summary == Access.summaryText(opening), "\(mirror.summary)")
        #expect(mirror.summary.hasPrefix("Tick 0 of \(opening.play.level.tickLimit). "))
        let shape: String = ChronoConstellatorLevel.shape(of: 0).name
        #expect(mirror.starNames.first == "star 1 (\(shape))")
        #expect(mirror.pickedStar == 0)
        #expect(mirror.pickedStarLabel == "Star 1 (\(shape))")
        let snapshot: ChronoConstellatorSceneSnapshot = opening.snapshot(time: 0)
        #expect(mirror.pickedPhaseLabel == "phase \(snapshot.phases[0]) of \(snapshot.stars[0].loop.count)")
        #expect(mirror.pickedHoldsLabel == "no holds")

        let held: ActionResult = presenter.send("star.hold", ChronoConstellatorTest.holdValues, port: shell.port)
        #expect(held == .accepted, "\(held.code)")
        #expect(mirror.pickedHoldsLabel == "hold from tick 1 for 2 ticks")
        let stepped: ActionResult = presenter.send("time.step", [3], port: shell.port)
        #expect(stepped == .accepted, "\(stepped.code)")
        let moved: Core = try Access.core(shell)
        #expect(ChronoConstellatorControls.progressValue(mirror) == Access.progressText(moved),
                "\(ChronoConstellatorControls.progressValue(mirror))")
        #expect(mirror.summary == Plan.summaryText(core: moved))
        #expect(mirror.summary == Access.summaryText(moved), "\(mirror.summary)")
        #expect(mirror.summary.hasPrefix("Tick \(moved.play.tick) of "))
        #expect(mirror.summary.contains("holds from tick 1 for 2 ticks"))
    }

    // MARK: Reduce Flashing (FR-R02G0606-004; SC-R02G0606-003)

    /// Under Reduce Flashing a target ring whose star reaches or leaves its target eases in drawn frames 1/60 s apart:
    /// strictly between its start and its target at 0.1 s and at 0.4 s (not instantly), at its target after 0.6 s;
    /// the scene draws the eased lights.
    @Test func ringsFadeUnderReduceFlashing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceFlashing: true)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        #expect(presenter.lights.reducedFlash)
        let opening: Core = try Access.core(shell)
        let change: ChronoConstellatorA11yRingChange =
            try #require(Access.ringChange(opening), "a step or phase change moves a star onto or off its target")

        let base: Double = 100
        _ = try ChronoConstellatorTest.still(session, width: Access.stillWidth, height: Access.stillHeight,
                                             time: base)
        #expect(presenter.lights.isSettled, "the opening lights rest")
        try #require(presenter.lights.rings.indices.contains(change.star))
        let start: Double = presenter.lights.rings[change.star]

        let result: ActionResult = presenter.send(change.control, change.values, port: shell.port)
        #expect(result == .accepted, "\(result.code)")
        let moved: Core = try Access.core(shell)
        let onTarget: Bool = moved.snapshot(time: 0).stars[change.star].onTarget
        let target: Double = onTarget ? ChronoConstellatorLights.ringLit : ChronoConstellatorLights.ringUnlit
        try #require(Swift.abs(target - start) > 0.1, "the ring's target changes")

        var levels: [Double] = []
        for frame in 1...36 {
            _ = try ChronoConstellatorTest.still(session, width: Access.stillWidth, height: Access.stillHeight,
                                                 time: base + Double(frame) / Access.frameRate)
            levels.append(presenter.lights.rings[change.star])
            #expect(presenter.scene.lights == presenter.lights, "frame \(frame): the scene draws the eased lights")
        }
        let low: Double = Swift.min(start, target)
        let high: Double = Swift.max(start, target)
        let tenth: Double = levels[5]
        let fortieth: Double = levels[23]
        #expect(tenth > low && tenth < high, "after 0.1 s the ring is at \(tenth), from \(start) to \(target)")
        #expect(fortieth > low && fortieth < high, "after 0.4 s the ring is at \(fortieth), from \(start) to \(target)")
        var monotone: Bool = true
        var previous: Double = start
        for level in levels {
            if Swift.abs(level - target) > Swift.abs(previous - target) + 1e-9 { monotone = false }
            previous = level
        }
        #expect(monotone, "the ring heads steadily for its target: \(levels)")
        let last: Double = levels[levels.count - 1]
        #expect(Swift.abs(last - target) < 1e-6, "after 0.6 s the ring rests at its target (\(last))")
        #expect(presenter.lights.isSettled, "a fade lasts 0.45 s")
    }

    // MARK: Reduce Motion (FR-R02G0606-004)

    /// Under Reduce Motion two stills of the same advanced state at different frame times are byte-identical and the
    /// drawn snapshot keeps time 0.
    @Test func reduceMotionStillsIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceMotion: true)
        Access.quiet(shell)
        let accepted: Int = ChronoConstellatorTest.advance(shell)
        #expect(accepted >= 1)
        // A first still lets any light fade finish (the next frame is 0.25 s later, beyond 0.15 s).
        _ = try ChronoConstellatorTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0)
        let first: [UInt8] = try ChronoConstellatorTest.still(session, width: Access.stillWidth,
                                                              height: Access.stillHeight, time: 0.25)
        let firstDrawn: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let second: [UInt8] = try ChronoConstellatorTest.still(session, width: Access.stillWidth,
                                                               height: Access.stillHeight, time: 1.3)
        let secondDrawn: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(ChronoConstellatorTest.nonFieldPixels(first) > 0, "the still shows the scene")
        #expect(first == second, "Reduce Motion: stills at 0.25 s and 1.3 s are identical")
        #expect(firstDrawn.time == 0)
        #expect(secondDrawn.time == 0)
        let core: Core = try Access.core(shell)
        #expect(secondDrawn == core.snapshot(time: 0))
    }
}
#endif
