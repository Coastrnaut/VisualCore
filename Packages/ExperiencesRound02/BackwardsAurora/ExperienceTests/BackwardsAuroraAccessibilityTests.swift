// BackwardsAuroraAccessibilityTests — feature 396 (R02-G10-06) T-R02G1006-005 (FR-R02G1006-001 … 006;
// SC-R02G1006-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Nocturne Garden's feature-386 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running (the route's init).
// Values: every value the panel reads (`BackwardsAuroraControls.values(_:)`) is non-empty words after level 1 is
// described; the start and end name the sample and its height ("sample k, height h"); the Reset view and mode values,
// the mode names and the 520-point readable width. Level 1 (seed 0) is won with the panel's accessibility operations
// alone: the adjustable start and end steppers (`stepStart`, `stepEnd`, then `refreshSummary()`, as the panel's
// increment and decrement do; never announced, no haptic) line up each reversal of the certified solution
// (`BackwardsAuroraExperienceCore.generated(number: 1).solution.actions`) and Reverse sends `wave.reverse` with the
// mirror's ends through `presenter.send`; every reversal routes exactly `BackwardsAuroraFeedbackPlan.after(old:new:)` and
// the winning one only the outcome ("Every checkpoint matches … Level won with m reversals made, 3 of 3 stars."), with a
// success haptic. Scripted sequence on the first level of `BackwardsAuroraTest.tearFailure()`: a certified reversal,
// undo, redo, a redo with nothing to redo (`r02-g10.action`, "That section cannot be reversed here."), the next level
// while locked (`r02-g10.locked`, "That level is not open yet."), undo, and the tearing reversal (an `outcome` with a
// warning haptic): the sinks and the feedback log hold exactly the plans, the panel shows each refusal's words and
// `refusalLog` keeps the codes. A revealed hint is announced after the detached search (bounded poll ≤ 5 s): `state`,
// its words, no haptic. The summary element's words equal `summaryText(core:sectionStart:sectionEnd:)` and follow a
// stepped end. Reduce Motion: two stills of the same state at different frame times are byte-identical and the drawn
// snapshot keeps time 0. Reduce Flashing: after a tear the presenter's tear light reaches 1 only after ≥ 0.4 s of frame
// time (0.45 s fade) and after undo `fadingTear` stays on the torn seam until the light reaches 0. Sound: the state
// table (wanted × on screen × active) and the offers use a `BackwardsAuroraSound` with an injected recording player;
// the presenter's own sound is only driven off screen (no player made). Synthetic data, explicit types, plain loops, no
// nested closure literals, no wall-clock assertion; few frames, each test short.
#if os(iOS)
import CoreGraphics
import Foundation
import BackwardsAuroraCore
import Testing
@testable import BackwardsAuroraExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class BackwardsAuroraA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class BackwardsAuroraA11yLoop: BackwardsAuroraLoopPlaying {
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
final class BackwardsAuroraA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [BackwardsAuroraA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> BackwardsAuroraA11yLoop {
        let loop: BackwardsAuroraA11yLoop = BackwardsAuroraA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> BackwardsAuroraSound {
        BackwardsAuroraSound(recipe: recipe, makePlayer: { next in self.make(next) })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum BackwardsAuroraA11y {
    typealias Shell = ExperienceShell<BackwardsAuroraPresenter>
    typealias Plan = BackwardsAuroraFeedbackPlan
    typealias Core = BackwardsAuroraExperienceCore

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: BackwardsAuroraA11yClock
    }

    /// The still size of the Reduce Motion and Reduce Flashing tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64
    /// The longest wait for a hint search, in polls of ``pollNanoseconds`` (5 s).
    static let pollLimit: Int = 500
    static let pollNanoseconds: UInt64 = 10_000_000

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await BackwardsAuroraTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                              reduceFlashing: reduceFlashing,
                                                              size: CGSize(width: 360, height: 240))
        let opening: Core = try BackwardsAuroraTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: BackwardsAuroraA11yClock = BackwardsAuroraA11yClock()
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
        try BackwardsAuroraTest.core(shell)
    }

    /// The summary element's words for `core` with the mirror's section.
    static func summary(_ core: Core, _ mirror: BackwardsAuroraMirror) -> String {
        Plan.summaryText(core: core, sectionStart: mirror.start, sectionEnd: mirror.end)
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
    static func log(_ presenter: BackwardsAuroraPresenter, after count: Int) -> [Plan] {
        Array(presenter.feedbackLog.dropFirst(count))
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: BackwardsAuroraPresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(nanoseconds: pollNanoseconds)
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint one clock second later and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: BackwardsAuroraPresenter, _ recorder: Recorder,
                          sourceLocation: SourceLocation = #_sourceLocation) async throws {
        recorder.clock.advance()
        presenter.showHint()
        let finished: Bool = try await awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s", sourceLocation: sourceLocation)
    }

    /// Sends the accepted `control` with `values` through the presenter as the panel does, one clock second later;
    /// expects the feedback log to grow by exactly the plan of the change (nothing for `.none`), the panel to show no
    /// refusal, the summary element to read `summaryText(core:sectionStart:sectionEnd:)` and a second description of
    /// the same state to route nothing. Returns the plan.
    @discardableResult
    static func accepted(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double] = [],
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: BackwardsAuroraPresenter = shell.presenter
        let old: Core = try core(shell)
        let before: Int = presenter.feedbackLog.count
        recorder.clock.advance()
        let result: ActionResult = presenter.send(control, values, port: shell.port)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        let new: Core = try core(shell)
        let plan: Plan = Plan.after(old: old, new: new)
        let routed: Int = plan == Plan.none ? 0 : 1
        #expect(presenter.feedbackLog.count == before + routed, "\(control) routes its plan",
                sourceLocation: sourceLocation)
        if routed == 1 {
            #expect(presenter.feedbackLog.last == plan, "\(control) routes its plan", sourceLocation: sourceLocation)
        }
        #expect(presenter.mirror.message == nil, sourceLocation: sourceLocation)
        #expect(presenter.mirror.summary == summary(new, presenter.mirror), "\(presenter.mirror.summary)",
                sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(new)
        #expect(presenter.feedbackLog.count == count, "describing the same state again routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// Sends the refused `control` with `values` through the presenter, one clock second later; expects a code that
    /// contains `code`, an unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), its words in
    /// the panel and the code in `refusalLog`. Returns the plan.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double], code: String,
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: BackwardsAuroraPresenter = shell.presenter
        let digest: String = try BackwardsAuroraTest.digest(shell)
        let playedBefore: Int = recorder.haptics.played.count
        recorder.clock.advance()
        let result: ActionResult = presenter.send(control, values, port: shell.port)
        #expect(!result.isAccepted, "\(control) \(values) is refused", sourceLocation: sourceLocation)
        #expect(result.code.contains(code), "\(result.code)", sourceLocation: sourceLocation)
        let plan: Plan = Plan.refused(code: result.code)
        #expect(plan.kind == .rejection, sourceLocation: sourceLocation)
        #expect(plan.haptic == .error, sourceLocation: sourceLocation)
        #expect(presenter.feedbackLog.last == plan, sourceLocation: sourceLocation)
        #expect(presenter.mirror.message == Plan.refusalText(code: result.code), "the panel shows the same words",
                sourceLocation: sourceLocation)
        #expect(presenter.mirror.message == plan.text, sourceLocation: sourceLocation)
        #expect(presenter.refusalLog.last == result.code, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        let after: String = try BackwardsAuroraTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// Moves the panel's section to `start` … `end` with the adjustable steppers' operations only (`stepStart(±1)`,
    /// `stepEnd(±1)`, each followed by `refreshSummary()` as the panel's increment and decrement do): first the end up,
    /// then the start, then the end down, so neither end pushes the other. Returns the presses made.
    static func lineUp(_ presenter: BackwardsAuroraPresenter, start: Int, end: Int) -> Int {
        let mirror: BackwardsAuroraMirror = presenter.mirror
        var presses: Int = 0
        for _ in 0..<128 {
            if mirror.end < end {
                mirror.stepEnd(1)
            } else if mirror.start > start {
                mirror.stepStart(-1)
            } else if mirror.start < start {
                mirror.stepStart(1)
            } else if mirror.end > end {
                mirror.stepEnd(-1)
            } else {
                break
            }
            presenter.refreshSummary()
            presses += 1
        }
        return presses
    }
}

@MainActor
@Suite(.serialized) struct BackwardsAuroraAccessibilityTests {
    typealias Access = BackwardsAuroraA11y
    typealias Plan = BackwardsAuroraFeedbackPlan
    typealias Presenter = BackwardsAuroraPresenter
    typealias Core = BackwardsAuroraExperienceCore

    // MARK: Values (FR-R02G1006-001, 005; clarification Q5)

    /// After level 1 is described every value the panel reads is non-empty words: start and end name the sample and
    /// its height, Undo and Redo the reversals spent, Next level, Retry and Play level; the Reset view and mode values,
    /// the mode names and the readable width.
    @Test func everyControlHasAValueInWords() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: BackwardsAuroraMirror = presenter.mirror
        let values: BackwardsAuroraControls.Values = BackwardsAuroraControls.values(mirror)
        let all: [String] = [values.start, values.end, values.reversals, values.nextLevel, values.retry,
                             values.playLevel, mirror.startLabel, mirror.endLabel, mirror.sectionLabel, mirror.summary,
                             mirror.status, mirror.measureLabel, mirror.targetLabel, mirror.goalLabel]
        for (index, value) in all.enumerated() {
            #expect(!value.isEmpty, "value \(index) is empty")
        }
        let samples: [Int] = core.play.wave.samples
        try #require(samples.count >= 2)
        #expect(mirror.start == 0)
        #expect(mirror.end == 1)
        #expect(values.start == "sample 0, height \(samples[0])", "\(values.start)")
        #expect(values.end == "sample 1, height \(samples[1])", "\(values.end)")
        #expect(values.reversals == "0 of \(core.play.level.budget) reversals spent", "\(values.reversals)")
        #expect(values.nextLevel == "no further level open", "\(values.nextLevel)")
        #expect(values.retry == "level 1, campaign", "\(values.retry)")
        #expect(values.playLevel == "level 1", "\(values.playLevel)")
        #expect(mirror.sectionLabel == "section 0 to 1, 2 samples")

        // The end stepped: the value follows with the new sample's height.
        mirror.stepEnd(1)
        presenter.refreshSummary()
        let stepped: BackwardsAuroraControls.Values = BackwardsAuroraControls.values(mirror)
        #expect(stepped.end == "sample 2, height \(samples[2])", "\(stepped.end)")
        #expect(stepped.start == values.start)

        #expect(BackwardsAuroraControls.viewValue(true) == "authored view")
        #expect(BackwardsAuroraControls.viewValue(false) == "orbited view")
        #expect(BackwardsAuroraControls.selectedValue(true) == "selected")
        #expect(BackwardsAuroraControls.selectedValue(false) == "not selected")
        #expect(BackwardsAuroraControls.modeName(.campaign) == "campaign")
        #expect(BackwardsAuroraControls.modeName(.practice) == "practice")
        #expect(BackwardsAuroraControls.modeName(.daily(level: 74)) == "daily")
        #expect(BackwardsAuroraControls.readableWidth == 520)
        #expect(presenter.feedbackLog.isEmpty, "describing and stepping plan nothing")
    }

    // MARK: Summary element (clarification Q5)

    /// The summary element's words equal `summaryText(core:sectionStart:sectionEnd:)` at the opening and follow a
    /// stepped end after `refreshSummary()`; stepping routes nothing.
    @Test func summaryFollowsTheSection() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: BackwardsAuroraMirror = presenter.mirror
        #expect(mirror.summary == Plan.summaryText(core: core, sectionStart: 0, sectionEnd: 1))
        #expect(mirror.summary.hasPrefix(BackwardsAuroraLevel.reversalsText(core.play.remaining) + ". "),
                "\(mirror.summary)")
        #expect(mirror.summary.contains(" Section 0 to 1, 2 samples. "), "\(mirror.summary)")
        mirror.stepEnd(1)
        #expect(mirror.summary.contains(" Section 0 to 1, 2 samples. "), "nothing changes before the refresh")
        presenter.refreshSummary()
        #expect(mirror.summary == Plan.summaryText(core: core, sectionStart: 0, sectionEnd: 2))
        #expect(mirror.summary.contains(" Section 0 to 2, 3 samples. "), "\(mirror.summary)")
        mirror.stepStart(1)
        presenter.refreshSummary()
        #expect(mirror.summary == Plan.summaryText(core: core, sectionStart: 1, sectionEnd: 2))
        #expect(presenter.feedbackLog.isEmpty, "the ends are not announced")
    }

    // MARK: The panel alone (SC-R02G1006-001)

    /// Level 1 (seed 0) is won with the panel's accessibility operations alone: the start and end steppers line up each
    /// certified reversal (never announced, no haptic) and Reverse sends the mirror's ends; every reversal routes
    /// exactly `after(old:new:)` with a selection haptic; the winning one routes only the outcome with a success haptic.
    @Test func levelOneWonWithThePanelOperations() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: BackwardsAuroraMirror = presenter.mirror
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        let actions: [BackwardsAuroraAction] = try Core.generated(number: 1).solution.actions
        try #require(!actions.isEmpty, "level 1 has a certified solution")
        var presses: Int = 0
        var sent: Int = 0
        var winRouted: Int = -1

        for (index, action) in actions.enumerated() {
            let stage: BackwardsAuroraStage = try Access.core(shell).play.stage
            guard stage == .playing else { break }
            guard case let .reverse(start, end) = action else { continue }
            let logBefore: Int = presenter.feedbackLog.count
            let announcedBefore: Int = recorder.announcements.announced.count
            let playedBefore: Int = recorder.haptics.played.count
            presses += Access.lineUp(presenter, start: start, end: end)
            #expect(mirror.start == start && mirror.end == end, "the steppers reached \(start) … \(end)")
            #expect(presenter.feedbackLog.count == logBefore, "a stepped end plans nothing")
            #expect(recorder.announcements.announced.count == announcedBefore, "a stepped end is not announced")
            #expect(recorder.haptics.played.count == playedBefore, "a stepped end plays no haptic")
            let current: Core = try Access.core(shell)
            #expect(mirror.summary == Access.summary(current, mirror), "\(mirror.summary)")

            // Reverse: the panel's button sends the mirror's ends.
            let old: Core = current
            recorder.clock.advance()
            let result: ActionResult = presenter.send("wave.reverse", [Double(mirror.start), Double(mirror.end)],
                                                      port: shell.port)
            #expect(result == .accepted, "reversal \(index + 1) \(start) … \(end): \(result.code)")
            sent += 1
            let new: Core = try Access.core(shell)
            let plan: Plan = Plan.after(old: old, new: new)
            #expect(plan.text != nil, "reversal \(index + 1) is announced")
            #expect(presenter.feedbackLog.count == logBefore + 1, "reversal \(index + 1) routes one plan")
            #expect(presenter.feedbackLog.last == plan)
            #expect(recorder.announcements.announced.last == plan.text)
            #expect(presenter.mirror.summary == Access.summary(new, mirror))
            if new.play.stage == .won {
                winRouted = presenter.feedbackLog.count - logBefore
            } else {
                #expect(plan.kind == .state)
                #expect(plan.haptic == .selection)
                #expect(recorder.haptics.played.last == .selection)
                let first: String = "Reversed samples \(start) to \(end). "
                #expect(plan.text?.hasPrefix(first) == true, "\(plan.text ?? "nil")")
                let left: String = BackwardsAuroraLevel.reversalsText(new.play.remaining) + "."
                #expect(plan.text?.hasSuffix(" " + left) == true, "\(plan.text ?? "nil")")
            }
        }
        #expect(sent == actions.count, "every certified reversal was sent")
        #expect(presses > 0, "the steppers were used")

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(winRouted == 1, "the winning reversal routes only the outcome")
        let made: Int = BackwardsAuroraProgress.reversalsMade(won.play)
        #expect(made == actions.count)
        let stars: Int = BackwardsAuroraProgress.stars(reversalsMade: made, smallest: won.certifiedSmallest)
        #expect(stars == 3)
        let winText: String = Plan.wonText + " Level won with " + Plan.reversals(made) + " made, 3 of 3 stars."
        let plans: [Plan] = Access.log(presenter, after: logBase)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced.last == winText)
        #expect(plans.count == actions.count, "every reversal announced, no stepped end")
        #expect(recorder.announcements.announced == Access.texts(plans))
        #expect(recorder.haptics.played == Access.haptics(plans), "\(recorder.haptics.played)")
        #expect(recorder.haptics.played.last == .success)
        #expect(presenter.mirror.status == "Won")
    }

    // MARK: Recorded feedback (FR-R02G1006-002, 003; SC-R02G1006-002)

    /// On the first tearing level: a certified reversal, undo, redo, a redo with nothing to redo, the next level while
    /// locked, undo and the tearing reversal; the sinks receive exactly the plans of `BackwardsAuroraFeedbackPlan`, in
    /// order, and the feedback log holds the same plans; haptics per clarification Q2 (selection, error, warning).
    @Test func recordedFeedbackThroughThePresenter() async throws {
        let found = try #require(try BackwardsAuroraTest.tearFailure(), "a tearing reversal within levels 41 … 100")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: UInt64(found.level - 1))
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == found.level)
        #expect(opening.play.stage == .playing)
        let first = BackwardsAuroraTest.control(try BackwardsAuroraTest.firstAction(found.level))
        var expected: [Plan] = []

        func state(_ plan: Plan, prefix: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let text: String = plan.text ?? ""
            #expect(text.hasPrefix(prefix), "\(text)", sourceLocation: sourceLocation)
            #expect(plan.kind == .state, sourceLocation: sourceLocation)
            #expect(plan.haptic == .selection, sourceLocation: sourceLocation)
            expected.append(plan)
        }

        // A certified reversal, its undo and redo: `state` with the measure and the reversals left.
        let reversed: Plan = try Access.accepted(shell, recorder, first.control, first.values)
        let start: Int = Int(first.values[0])
        let end: Int = Int(first.values[1])
        state(reversed, prefix: "Reversed samples \(start) to \(end). Checkpoints matched ")
        try #require(try Access.core(shell).play.stage == .playing, "the first certified reversal does not end it")
        let left: String = BackwardsAuroraLevel.reversalsText(try Access.core(shell).play.remaining) + "."
        #expect(reversed.text?.hasSuffix(" " + left) == true, "\(reversed.text ?? "nil")")
        state(try Access.accepted(shell, recorder, "play.undo"), prefix: "Undone. Checkpoints matched ")
        state(try Access.accepted(shell, recorder, "play.redo"), prefix: "Redone. Checkpoints matched ")
        #expect(expected.last?.text?.hasSuffix(" " + left) == true, "\(expected.last?.text ?? "nil")")

        // Nothing to redo, and a level that is not open yet.
        let nothing: Plan = try Access.refused(shell, recorder, "play.redo", [], code: "r02-g10.action")
        #expect(nothing.text == "That section cannot be reversed here.", "\(nothing.text ?? "nil")")
        expected.append(nothing)
        if found.level < 100 {
            let locked: Plan = try Access.refused(shell, recorder, "level.select", [Double(found.level + 1)],
                                                  code: "r02-g10.locked")
            #expect(locked.text == "That level is not open yet.", "\(locked.text ?? "nil")")
            #expect(presenter.mirror.message == "That level is not open yet.")
            expected.append(locked)
        }

        // Back to the opening wave, then the tearing reversal: only the outcome, with a warning haptic.
        state(try Access.accepted(shell, recorder, "play.undo"), prefix: "Undone. Checkpoints matched ")
        #expect(try Access.core(shell).play.wave == opening.play.wave, "undo returns to the opening wave")
        let tear = BackwardsAuroraTest.control(found.action)
        let torn: Plan = try Access.accepted(shell, recorder, tear.control, tear.values)
        let failed: Core = try Access.core(shell)
        #expect(failed.play.stage == .failed)
        guard case let .tear(_, seam)? = failed.play.failure else {
            Issue.record("the reversal \(tear.values) tears")
            return
        }
        #expect(seam == found.seam)
        let explanation: BackwardsAuroraFailureExplanation = try #require(BackwardsAuroraFailureExplanation(
            play: failed.play))
        #expect(torn.text == explanation.text, "\(torn.text ?? "nil")")
        #expect(torn.kind == .outcome)
        #expect(torn.haptic == .warning)
        expected.append(torn)

        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.announcements.announced.count == expected.count, "every plan here is announced")
        var haptics: [HapticKind] = [.selection, .selection, .selection, .error]
        if found.level < 100 { haptics.append(.error) }
        haptics.append(.selection)
        haptics.append(.warning)
        #expect(recorder.haptics.played == haptics, "\(recorder.haptics.played)")
        #expect(recorder.haptics.played == Access.haptics(expected))
        #expect(presenter.mirror.message == nil, "the accepted tear cleared the refusal's words")
        #expect(presenter.mirror.summary == Access.summary(failed, presenter.mirror))
    }

    // MARK: Hints (clarification Q1)

    /// A revealed hint is announced after the off-main-actor search finishes: `state`, the hint's words, no haptic;
    /// the next level comes from the cache and is announced too; "Finding a hint…" is never announced.
    @Test func aRevealedHintIsAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        let digest: String = try BackwardsAuroraTest.digest(shell)
        var expected: [Plan] = []
        for level in 1...2 {
            try await Access.pressHint(presenter, recorder)
            let want: BackwardsAuroraHint = try #require(BackwardsAuroraHints.hint(level: level, play: opening.play))
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "\(presenter.mirror.hintText ?? "nil")")
            let plan: Plan = Plan.hint(text: want.text)
            #expect(plan.kind == .state)
            #expect(plan.haptic == nil)
            #expect(presenter.feedbackLog.last == plan, "hint \(level) is routed")
            #expect(recorder.announcements.announced.last == want.text)
            expected.append(plan)
        }
        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(!recorder.announcements.announced.contains(Presenter.searchingText))
        #expect(recorder.haptics.played.isEmpty, "a hint plays no haptic")
        #expect(try BackwardsAuroraTest.digest(shell) == digest, "a hint changes nothing")
    }

    // MARK: Reduce Motion (FR-R02G1006-004)

    /// Under Reduce Motion two stills of the same reversed state at different frame times are byte-identical, the
    /// drawn snapshot keeps time 0 and equals the core's snapshot at time 0, and the lights rest.
    @Test func reduceMotionStillsIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 20, reduceMotion: true)
        Access.quiet(shell)
        #expect(try BackwardsAuroraTest.advance(shell))
        // Two first stills let any light fade finish (0.5 s apart, beyond the 0.15 s fade).
        _ = try BackwardsAuroraTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0)
        _ = try BackwardsAuroraTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0.5)
        let first: [UInt8] = try BackwardsAuroraTest.still(session, width: Access.stillWidth,
                                                           height: Access.stillHeight, time: 0.75)
        let firstDrawn: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let second: [UInt8] = try BackwardsAuroraTest.still(session, width: Access.stillWidth,
                                                            height: Access.stillHeight, time: 1.9)
        let secondDrawn: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(BackwardsAuroraTest.nonGroundPixels(first) > 0, "the still shows the aurora")
        #expect(first == second, "Reduce Motion: stills at 0.75 s and 1.9 s are identical")
        #expect(firstDrawn.time == 0)
        #expect(secondDrawn.time == 0)
        #expect(firstDrawn == secondDrawn)
        #expect(shell.presenter.lights.isSettled, "the lights rest")
        let core: Core = try Access.core(shell)
        let mirror: BackwardsAuroraMirror = shell.presenter.mirror
        #expect(secondDrawn == core.snapshot(sectionStart: mirror.start, sectionEnd: mirror.end, time: 0))
    }

    // MARK: Reduce Flashing (FR-R02G1006-004; SC-R02G1006-003)

    /// Under Reduce Flashing the tear light reaches 1 only after at least 0.4 s of frame time after a tear (the 0.45 s
    /// fade); after undo the tear cross stays on the torn seam (`fadingTear`) until the light reaches 0.
    @Test func reduceFlashingTearLightFades() async throws {
        let found = try #require(try BackwardsAuroraTest.tearFailure(), "a tearing reversal within levels 41 … 100")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: UInt64(found.level - 1), reduceFlashing: true)
        Access.quiet(shell)
        let presenter: Presenter = shell.presenter
        let base: Double = 10
        // A still before the tear: the lights rest at the playing targets with the last frame time at 10 s.
        _ = try BackwardsAuroraTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: base)
        #expect(presenter.lights.tear == 0)
        #expect(presenter.fadingTear == nil)
        let tear = BackwardsAuroraTest.control(found.action)
        let result: ActionResult = presenter.send(tear.control, tear.values, port: shell.port)
        #expect(result == .accepted, "\(result.code)")
        #expect(try Access.core(shell).play.stage == .failed)

        // The tear light rises over 0.45 s: below 1 at 0.1 … 0.4 s, 1 at 0.5 s.
        let rising: [Double] = [0.1, 0.2, 0.3, 0.4]
        var previous: Double = 0
        for offset in rising {
            _ = try BackwardsAuroraTest.still(session, width: Access.stillWidth, height: Access.stillHeight,
                                              time: base + offset)
            let level: Double = presenter.lights.tear
            #expect(level > previous, "the tear light rises at \(offset) s: \(level)")
            #expect(level < 1, "the tear light is below 1 at \(offset) s: \(level)")
            #expect(presenter.lastSnapshot?.tear == found.seam)
            #expect(presenter.fadingTear == found.seam)
            previous = level
        }
        _ = try BackwardsAuroraTest.still(session, width: Access.stillWidth, height: Access.stillHeight,
                                          time: base + 0.5)
        #expect(presenter.lights.tear == 1, "the tear light reaches 1 after 0.45 s")

        // Undo: the snapshot has no tear, and the cross stays on the torn seam while its light fades out.
        let undone: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let falling: [Double] = [0.6, 0.7, 0.8, 0.9]
        previous = 1
        for offset in falling {
            _ = try BackwardsAuroraTest.still(session, width: Access.stillWidth, height: Access.stillHeight,
                                              time: base + offset)
            let level: Double = presenter.lights.tear
            #expect(presenter.lastSnapshot?.tear == nil, "the undone play has no tear")
            #expect(level < previous, "the tear light falls at \(offset) s: \(level)")
            #expect(level > 0, "the tear light is above 0 at \(offset) s: \(level)")
            #expect(presenter.fadingTear == found.seam, "the cross stays on the torn seam at \(offset) s")
            previous = level
        }
        _ = try BackwardsAuroraTest.still(session, width: Access.stillWidth, height: Access.stillHeight,
                                          time: base + 1.0)
        #expect(presenter.lights.tear == 0, "the tear light reaches 0 after 0.45 s")
        #expect(presenter.fadingTear == nil, "the cross is gone once its light is 0")
    }

    // MARK: Sound (FR-R02G1006-006; SC-R02G1006-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; each input turning off stops a playing loop; a `play()` that fails changes nothing else; a new player is
    /// made only for a different recipe or the toggle turning on, never for the same recipe offered again.
    @Test func soundStateTable() throws {
        let calm: AmbientLoopRecipe = BackwardsAuroraSoundRecipe.recipe(rootStep: 0, matched: 0, stage: .playing)
        let one: AmbientLoopRecipe = BackwardsAuroraSoundRecipe.recipe(rootStep: 0, matched: 1, stage: .playing)
        let won: AmbientLoopRecipe = BackwardsAuroraSoundRecipe.recipe(rootStep: 0, matched: 1, stage: .won)
        try #require(calm != one, "another matched count sounds different")
        try #require(one != won, "a won play sounds different")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: BackwardsAuroraA11yLoopFactory = BackwardsAuroraA11yLoopFactory()
            let sound: BackwardsAuroraSound = factory.sound(calm)
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

        // Off by default: on screen and active, nothing is made.
        let idle: BackwardsAuroraA11yLoopFactory = BackwardsAuroraA11yLoopFactory()
        let quiet: BackwardsAuroraSound = idle.sound(calm)
        quiet.setOnScreen(true)
        #expect(!quiet.wanted, "the sound is off by default")
        #expect(quiet.active, "the scene starts active")
        #expect(!quiet.shouldPlay)
        #expect(idle.made.isEmpty)

        // Each input turning off stops a playing loop; turning back on plays again.
        let toggles: BackwardsAuroraA11yLoopFactory = BackwardsAuroraA11yLoopFactory()
        let live: BackwardsAuroraSound = toggles.sound(calm)
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
        live.setWanted(false)
        #expect(!live.started, "the sound off stops the loop")
        #expect(toggles.made.first?.isPlaying == false)
        live.setWanted(true)
        #expect(live.started)
        #expect(live.playersMade == 1, "the same recipe keeps its player")

        // A failing play: the choice stays on, nothing else moves.
        let failing: BackwardsAuroraA11yLoopFactory = BackwardsAuroraA11yLoopFactory()
        failing.succeeds = false
        let broken: BackwardsAuroraSound = failing.sound(calm)
        broken.setOnScreen(true)
        broken.setWanted(true)
        #expect(broken.playersMade == 1)
        #expect(!broken.started)
        #expect(broken.wanted)
        #expect(broken.onScreen)
        #expect(broken.active)
        #expect(broken.shouldPlay)
        #expect(broken.recipe == calm)
        #expect(failing.made.first?.plays == 1)
        #expect(failing.made.first?.isPlaying == false)
        #expect(failing.made.first?.stops == 0)

        // The sound off: offers make no player but are kept.
        let silent: BackwardsAuroraA11yLoopFactory = BackwardsAuroraA11yLoopFactory()
        let off: BackwardsAuroraSound = silent.sound(calm)
        off.setOnScreen(true)
        off.offer(one)
        off.offer(won)
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)
        #expect(off.recipe == won, "kept for the next start")

        // New players only at the named moments.
        let factory: BackwardsAuroraA11yLoopFactory = BackwardsAuroraA11yLoopFactory()
        let sound: BackwardsAuroraSound = factory.sound(calm)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(calm) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(one)
        #expect(sound.playersMade == 2, "a change of the matched count makes a new player")
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
        sound.offer(calm)
        #expect(sound.playersMade == 3, "an offer while off makes no player")
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "the toggle turning on plays the latest recipe")
        #expect(sound.playerRecipe == calm)
        #expect(factory.recipes == [calm, one, won, calm])
        sound.setWanted(false)
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "toggling with the same recipe keeps the player")
        #expect(sound.started)
    }

    /// The presenter's Sound toggle (the controls kept off screen, so nothing plays): off by default, `setSound(on:)`
    /// toggles `mirror.soundOn` and the sound's choice, the opening offered the core's recipe, and no player is made
    /// while the controls are off screen or the scene is inactive.
    @Test func thePresenterSoundToggle() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(core), "the first state offers its recipe")
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        presenter.sceneActive(false)
        #expect(!presenter.sound.active)
        presenter.controlsAppeared()
        #expect(presenter.sound.onScreen)
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the loop silent")
        presenter.controlsDisappeared()
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        presenter.sceneActive(true)
        #expect(!presenter.sound.shouldPlay)
        #expect(presenter.sound.playersMade == 0, "no player was made")
    }
}
#endif
