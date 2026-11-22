// AmethystEscapeAccessibilityTests — feature 366 (R02-G07-06) T-R02G0706-005 (FR-R02G0706-001 … 006;
// SC-R02G0706-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Chrono Constellator's feature-356 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running. On level 67 (seed
// 2_366, no tutorial; the scripted sequence of the feature's plan tests) turns both ways, undo, redo, advances, a wedge
// failure, two refusals (`r02-g07.stage` on the failed play, `r02-g07.stuck` at a wall) and the undo of the failure
// record exactly `AmethystEscapeFeedbackPlan.after(old:new:)` and `refused(code:)` in the sinks and in the presenter's
// feedback log (the texts are also written out from clarification Q1); a second description of the same state routes
// nothing; the panel shows the refusal's words. Level 1 (seed 0) is won with the panel's accessibility operations
// alone: the adjustable shell picker (`pickShell(±1)`, announced "<Shell> picked."), Turn − / + (`shell.rotate
// [picked, ∓1]`, as the controls send it) and Advance (`pearl.advance`), following
// `AmethystEscapeExperienceCore.certifiedActions(1)`; every pick and step is announced and the winning advance routes
// only the outcome, with a success haptic. A two-sector shell drag in progress announces nothing; its release is
// announced once (`drag(old:new:shell:sectors:)`, one selection haptic). Sound: the presenter makes its own
// `AmethystEscapeSound` with the real `AmbientLoopPlayer`, so the state table (wanted × on screen × active), the
// offers and a failing `play()` use an `AmethystEscapeSound` with an injected recording player; the presenter's
// sound is only driven with the sound off or off screen or inactive (no audio starts). Labels: the shell picker
// "Shell to turn" with the value "<Shell>, turned t of N", the turn buttons named with the picked
// shell, the progress value and the summary element's words (`summaryText(core:)`, also written out). Reduce Motion:
// two stills of the same state at different frame times are byte-identical and the drawn snapshot keeps time 0.
// Synthetic data, explicit types, plain loops, no nested closure literals, no sleep, no wall-clock assertion; few
// frames, each test short.
#if os(iOS)
import AmethystEscapeCore
import CoreGraphics
import Foundation
import Testing
@testable import AmethystEscapeExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class AmethystEscapeA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class AmethystEscapeA11yLoop: AmethystEscapeLoopPlaying {
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
final class AmethystEscapeA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [AmethystEscapeA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> AmethystEscapeA11yLoop {
        let loop: AmethystEscapeA11yLoop = AmethystEscapeA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> AmethystEscapeSound {
        AmethystEscapeSound(recipe: recipe, makePlayer: { next in self.make(next) })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum AmethystEscapeA11y {
    typealias Shell = ExperienceShell<AmethystEscapePresenter>
    typealias Plan = AmethystEscapeFeedbackPlan
    typealias Core = AmethystEscapeExperienceCore

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: AmethystEscapeA11yClock
    }

    /// The seed of level 67 (band 4, no tutorial; 8 sectors, 4 shells, budget 17), the level of the plan tests.
    static let scriptedSeed: UInt64 = 2_366
    /// The still size of the Reduce Motion test (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64
    /// The shared advice that ends every failure explanation (feature 365).
    static let advice: String = "Undo the last move or retry the level."

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await AmethystEscapeTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                             reduceFlashing: reduceFlashing,
                                                             size: CGSize(width: 360, height: 240))
        let opening: Core = try AmethystEscapeTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: AmethystEscapeA11yClock = AmethystEscapeA11yClock()
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
        try AmethystEscapeTest.core(shell)
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
    static func log(_ presenter: AmethystEscapePresenter, after count: Int) -> [Plan] {
        Array(presenter.feedbackLog.dropFirst(count))
    }

    /// `text` with its first character upper-cased, written out here ("Shell 1 (inner)").
    static func sentence(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// "1 move left" or "n moves left", written out here.
    static func leftText(_ count: Int) -> String { count == 1 ? "1 move left" : "\(count) moves left" }

    /// The shell picker's value of `core` with shell `picked`, written out from clarification Q5: "<Shell>, turned t
    /// of N".
    static func pickerText(_ core: Core, picked: Int) -> String {
        let level: AmethystEscapeLevel = core.play.level
        return sentence(level.shellName(picked)) + ", turned \(core.play.crystal.offsets[picked]) of \(level.sectors)"
    }

    /// The panel's progress value of `core`, written out: "Level n, m moves left".
    static func progressText(_ core: Core) -> String {
        "Level \(core.levelNumber), \(leftText(core.play.remaining))"
    }

    /// Sends the accepted `control` with `values` through the presenter as the panel does, one clock second later;
    /// expects the feedback log to grow by exactly the plan of the change (none for an unchanged core) and a second
    /// description of the same state to route nothing. Returns the plan.
    static func accepted(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double] = [],
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: AmethystEscapePresenter = shell.presenter
        let old: Core = try core(shell)
        let before: Int = presenter.feedbackLog.count
        recorder.clock.advance()
        let result: ActionResult = presenter.send(control, values, port: shell.port)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        let new: Core = try core(shell)
        let plan: Plan = Plan.after(old: old, new: new)
        #expect(plan != Plan.none, "\(control) \(values) is announced", sourceLocation: sourceLocation)
        #expect(presenter.feedbackLog.count == before + 1, "\(control) routes one plan", sourceLocation: sourceLocation)
        #expect(presenter.feedbackLog.last == plan, "\(control) routes its plan", sourceLocation: sourceLocation)
        #expect(presenter.mirror.message == nil, sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(new)
        #expect(presenter.feedbackLog.count == count, "describing the same state again routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// Sends the refused `control` with `values` through the presenter, one clock second later; expects a code that
    /// contains `code`, an unchanged digest, the refusal plan routed and its words in the panel. Returns the plan.
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double], code: String,
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: AmethystEscapePresenter = shell.presenter
        let digest: String = try AmethystEscapeTest.digest(shell)
        recorder.clock.advance()
        let result: ActionResult = presenter.send(control, values, port: shell.port)
        #expect(!result.isAccepted, "\(control) \(values) is refused", sourceLocation: sourceLocation)
        #expect(result.code.contains(code), "\(result.code)", sourceLocation: sourceLocation)
        let plan: Plan = Plan.refused(code: result.code)
        #expect(plan.kind == .rejection, sourceLocation: sourceLocation)
        #expect(plan.haptic == .error, sourceLocation: sourceLocation)
        #expect(presenter.feedbackLog.last == plan, sourceLocation: sourceLocation)
        #expect(presenter.mirror.message == plan.text, "the panel shows the same words", sourceLocation: sourceLocation)
        let after: String = try AmethystEscapeTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// Moves the panel's shell picker to `target` the shorter way round with `pickShell(±1)`, one clock second per
    /// press; every press announces "<Shell> picked." (no haptic). Returns the presses made.
    static func pick(_ shell: Shell, _ recorder: Recorder, to target: Int,
                     sourceLocation: SourceLocation = #_sourceLocation) throws -> Int {
        let presenter: AmethystEscapePresenter = shell.presenter
        let count: Int = presenter.mirror.shellNames.count
        guard count > 0 else { return 0 }
        let forward: Int = ((target - presenter.mirror.pickedShell) % count + count) % count
        let delta: Int = forward <= count - forward ? 1 : -1
        let presses: Int = Swift.min(forward, count - forward)
        for _ in 0..<presses {
            recorder.clock.advance()
            let before: Int = presenter.feedbackLog.count
            presenter.pickShell(delta)
            let now: Core = try core(shell)
            let plan: Plan = Plan.picked(shell: presenter.mirror.pickedShell, core: now)
            #expect(presenter.feedbackLog.count == before + 1, "a pick is announced", sourceLocation: sourceLocation)
            #expect(presenter.feedbackLog.last == plan, sourceLocation: sourceLocation)
            let text: String = sentence(now.play.level.shellName(presenter.mirror.pickedShell)) + " picked."
            #expect(plan.text == text, "\(plan.text ?? "nil")", sourceLocation: sourceLocation)
            #expect(plan.haptic == nil, "a pick plays no haptic", sourceLocation: sourceLocation)
            #expect(recorder.announcements.announced.last == text, sourceLocation: sourceLocation)
        }
        #expect(presenter.mirror.pickedShell == target, "the picker reached shell \(target)",
                sourceLocation: sourceLocation)
        return presses
    }
}

@MainActor
@Suite(.serialized) struct AmethystEscapeAccessibilityTests {
    typealias Access = AmethystEscapeA11y
    typealias Script = AmethystEscapeGestureScript
    typealias Plan = AmethystEscapeFeedbackPlan
    typealias Presenter = AmethystEscapePresenter
    typealias Core = AmethystEscapeExperienceCore
    typealias Controls = AmethystEscapeControls

    // MARK: Recorded feedback (FR-R02G0706-002, 003; SC-R02G0706-002)

    /// Turns both ways, undo, redo, advances, a wedge failure, a refusal on the failed play, its undo, a turn, an
    /// advance and a refusal at a wall (level 67): the sinks receive exactly the plans of `AmethystEscapeFeedbackPlan`,
    /// in order, and the feedback log holds the same plans; the texts written out; the failure routes only the outcome
    /// with a warning haptic; the panel shows each refusal's words.
    @Test func recordedFeedbackThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: Access.scriptedSeed)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 67)
        #expect(opening.tutorial == .done)
        #expect(opening.play.stage == .playing)
        #expect(opening.play.level.budget == 17)
        var expected: [Plan] = []

        func state(_ plan: Plan, _ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(plan.text == text, "\(plan.text ?? "nil")", sourceLocation: sourceLocation)
            #expect(plan.kind == .state, sourceLocation: sourceLocation)
            #expect(plan.haptic == .selection, sourceLocation: sourceLocation)
            expected.append(plan)
        }

        state(try Access.accepted(shell, recorder, "shell.rotate", [0, 1]),
              "Shell 1 (inner) turned one sector clockwise. 16 moves left.")
        state(try Access.accepted(shell, recorder, "shell.rotate", [1, -1]),
              "Shell 2 turned one sector anticlockwise. 15 moves left.")
        state(try Access.accepted(shell, recorder, "play.undo"),
              "Undone. The pearl is in shell 1 (inner), sector 8 of 8. 16 moves left.")
        state(try Access.accepted(shell, recorder, "play.redo"),
              "Redone. The pearl is in shell 1 (inner), sector 8 of 8. 15 moves left.")
        state(try Access.accepted(shell, recorder, "play.undo"),
              "Undone. The pearl is in shell 1 (inner), sector 8 of 8. 16 moves left.")
        state(try Access.accepted(shell, recorder, "play.undo"),
              "Undone. The pearl is in shell 1 (inner), sector 7 of 8. 17 moves left.")
        state(try Access.accepted(shell, recorder, "pearl.advance"),
              "The pearl rolled to shell 2, sector 7 of 8. 16 moves left.")
        state(try Access.accepted(shell, recorder, "pearl.advance"),
              "The pearl rolled to shell 2, sector 8 of 8. 15 moves left.")
        state(try Access.accepted(shell, recorder, "pearl.advance"),
              "The pearl rolled to shell 2, sector 1 of 8. 14 moves left.")

        // The fourth advance falls into the blocked wedge of shell 3: only the outcome, with a warning haptic.
        let fall: Plan = try Access.accepted(shell, recorder, "pearl.advance")
        let failed: Core = try Access.core(shell)
        #expect(failed.play.stage == .failed)
        let explanation: AmethystEscapeFailureExplanation = try #require(failed.failureExplanation)
        #expect(fall.text == explanation.text, "\(fall.text ?? "nil")")
        #expect(fall.text?.hasPrefix("The pearl fell into the blocked wedge of shell 3, sector 1 of 8") == true,
                "\(fall.text ?? "nil")")
        #expect(fall.text?.hasSuffix(Access.advice) == true, "\(fall.text ?? "nil")")
        #expect(fall.kind == .outcome)
        #expect(fall.haptic == .warning)
        expected.append(fall)

        // A refusal on the failed play.
        let ended: Plan = try Access.refused(shell, recorder, "shell.rotate", [0, 1], code: "r02-g07.stage")
        #expect(ended.text == "The level has ended.", "\(ended.text ?? "nil")")
        expected.append(ended)

        // The undo returns to playing; a turn of shell 3 back and an advance reach a wall; the next advance is refused.
        state(try Access.accepted(shell, recorder, "play.undo"),
              "Undone. The pearl is in shell 2, sector 1 of 8. 14 moves left.")
        #expect(try Access.core(shell).play.stage == .playing)
        state(try Access.accepted(shell, recorder, "shell.rotate", [2, -1]),
              "Shell 3 turned one sector anticlockwise. 13 moves left.")
        state(try Access.accepted(shell, recorder, "pearl.advance"),
              "The pearl rolled to shell 3, sector 1 of 8. 12 moves left.")
        let stuck: Plan = try Access.refused(shell, recorder, "pearl.advance", [], code: "r02-g07.stuck")
        #expect(stuck.text == "A wall stops the pearl: turn a shell first.", "\(stuck.text ?? "nil")")
        expected.append(stuck)

        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
        #expect(recorder.announcements.announced.count == expected.count, "every plan here is announced")
        #expect(presenter.mirror.summary == Plan.summaryText(core: try Access.core(shell)))
    }

    // MARK: The panel alone (SC-R02G0706-001)

    /// Level 1 (seed 0) is won with the panel's accessibility operations alone: the shell picker (incremented and
    /// decremented once, then moved to each certified turn's shell), Turn − / + and Advance, following the certified
    /// actions; every pick and step announced; the winning advance routes only the outcome, with a success haptic.
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
        let shells: Int = opening.play.level.shells.count
        try #require(shells >= 2, "level 1 has two shells")
        let actions: [AmethystEscapeAction] = Core.certifiedActions(1)
        try #require(!actions.isEmpty, "level 1 has certified actions")
        var routed: Int = 0
        var winRouted: Int = -1

        // The adjustable picker: increment then decrement, each announced.
        #expect(presenter.mirror.pickedShell == 0)
        routed += try Access.pick(shell, recorder, to: 1)
        routed += try Access.pick(shell, recorder, to: 0)
        #expect(routed == 2)

        for (index, action) in actions.enumerated() {
            let stage: AmethystEscapeStage = try Access.core(shell).play.stage
            guard stage == .playing else { break }
            var control: String = "pearl.advance"
            var values: [Double] = []
            if case .rotate(let target, let step) = action {
                routed += try Access.pick(shell, recorder, to: target)
                // "Turn −" or "Turn +" sends a turn of the picked shell.
                control = "shell.rotate"
                values = [Double(presenter.mirror.pickedShell), Double(step)]
            }
            let old: Core = try Access.core(shell)
            let before: Int = presenter.feedbackLog.count
            recorder.clock.advance()
            let result: ActionResult = presenter.send(control, values, port: shell.port)
            #expect(result == .accepted, "action \(index) \(control): \(result.code)")
            let new: Core = try Access.core(shell)
            let plan: Plan = Plan.after(old: old, new: new)
            #expect(plan.text != nil, "action \(index) is announced")
            #expect(presenter.feedbackLog.count == before + 1, "action \(index) routes one plan")
            #expect(presenter.feedbackLog.last == plan)
            #expect(recorder.announcements.announced.last == plan.text)
            if new.play.stage == .won {
                winRouted = presenter.feedbackLog.count - before
            }
            routed += 1
        }

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(winRouted == 1, "the winning advance routes only the outcome")
        let stars: Int = AmethystEscapeProgress.stars(moves: won.play.moves, smallest: won.certifiedSmallest)
        let movesText: String = won.play.moves == 1 ? "1 move" : "\(won.play.moves) moves"
        let winText: String = "The pearl escaped. Level won in \(movesText), \(stars) of 3 stars."
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

    // MARK: The adjustable picker (FR-R02G0706-001, 005)

    /// The shell picker increments and decrements one shell at a time, wrapping at both ends; its value follows the
    /// pick ("<Shell>, turned t of N") and every change is announced without a haptic.
    @Test func theAdjustablePickerIncrementsAndDecrements() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: Access.scriptedSeed)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let core: Core = try Access.core(shell)
        let count: Int = core.play.level.shells.count
        #expect(count == 4)
        #expect(Controls.shellPickerLabel == "Shell to turn")
        #expect(presenter.mirror.pickedShell == 0)
        #expect(Controls.shellPickerValue(presenter.mirror) == "Shell 1 (inner), turned 0 of 8")

        var wanted: [String] = []
        for press in 1...count {
            recorder.clock.advance()
            presenter.pickShell(1)
            let picked: Int = press % count
            #expect(presenter.mirror.pickedShell == picked, "increment \(press)")
            #expect(Controls.shellPickerValue(presenter.mirror) == Access.pickerText(core, picked: picked))
            wanted.append(Access.sentence(core.play.level.shellName(picked)) + " picked.")
        }
        #expect(presenter.mirror.pickedShell == 0, "four increments wrap round")
        recorder.clock.advance()
        presenter.pickShell(-1)
        #expect(presenter.mirror.pickedShell == count - 1, "a decrement from the first shell wraps to the outer one")
        #expect(Controls.shellPickerValue(presenter.mirror) == "Shell 4 (outer), turned 0 of 8")
        wanted.append("Shell 4 (outer) picked.")
        recorder.clock.advance()
        presenter.pickShell(-1)
        #expect(presenter.mirror.pickedShell == count - 2)
        #expect(Controls.shellPickerValue(presenter.mirror) == "Shell 3, turned 0 of 8")
        wanted.append("Shell 3 picked.")

        let plans: [Plan] = Access.log(presenter, after: logBase)
        #expect(plans.count == count + 2, "every pick announced")
        #expect(Access.texts(plans) == wanted)
        #expect(recorder.announcements.announced == wanted)
        #expect(recorder.haptics.played.isEmpty, "picks play no haptic")
        #expect(try Access.core(shell) == core, "a pick changes no state")
    }

    // MARK: Labels and values (FR-R02G0706-001, 005)

    /// The shell picker's label and value, the turn buttons' labels, the progress value, the Sound toggle and the
    /// summary element's words, written out: at the opening of level 67 and after three moves.
    @Test func labelsAndValues() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: Access.scriptedSeed)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        let opening: Core = try Access.core(shell)
        let mirror: AmethystEscapeMirror = presenter.mirror
        #expect(mirror.pickedShell == 0)
        #expect(mirror.pickedShellLabel == "Shell 1 (inner)")
        #expect(Controls.shellPickerLabel == "Shell to turn")
        #expect(Controls.shellPickerValue(mirror) == Access.pickerText(opening, picked: 0))
        #expect(Controls.turnLabel(mirror, step: -1) == "Turn shell 1 (inner) one sector anticlockwise",
                "\(Controls.turnLabel(mirror, step: -1))")
        #expect(Controls.turnLabel(mirror, step: 1) == "Turn shell 1 (inner) one sector clockwise",
                "\(Controls.turnLabel(mirror, step: 1))")
        #expect(Controls.progressValue(mirror) == Access.progressText(opening), "\(Controls.progressValue(mirror))")
        #expect(mirror.summary == Plan.summaryText(core: opening))
        #expect(mirror.summary.hasPrefix("17 moves left. The pearl is in shell 1 (inner), sector 7 of 8. "),
                "\(mirror.summary)")
        #expect(mirror.soundOn == false, "the sound is off by default")

        // Two advances and the outer shell forward: the crystal of the plan tests' summary.
        let controls: [String] = ["pearl.advance", "pearl.advance", "shell.rotate"]
        let values: [[Double]] = [[], [], [3, 1]]
        for index in controls.indices {
            let result: ActionResult = presenter.send(controls[index], values[index], port: shell.port)
            #expect(result == .accepted, "\(controls[index]): \(result.code)")
        }
        let moved: Core = try Access.core(shell)
        let summary: String = "14 moves left. The pearl is in shell 2, sector 8 of 8. "
            + "The exit gap is at sector 5 of 8. "
            + "Shell 1 (inner): openings at sectors 3, 7; walls after sectors 3, 4; blocked sectors 2, turned 0. "
            + "Shell 2: openings at sectors 1, 3; walls after sectors 4; blocked sectors 2, 4, 5, turned 0. "
            + "Shell 3: openings at sectors 5, 7; walls after sectors 1, 2, 4; blocked sectors 1, 6, turned 0. "
            + "Shell 4 (outer): exit gap at sector 4; walls after sectors 6; blocked sectors 8, turned 1."
        #expect(mirror.summary == Plan.summaryText(core: moved))
        #expect(mirror.summary == summary, "\(mirror.summary)")
        #expect(Controls.progressValue(mirror) == Access.progressText(moved), "\(Controls.progressValue(mirror))")
        #expect(Controls.shellPickerValue(mirror) == "Shell 1 (inner), turned 0 of 8")

        // The picker on the outer shell names it in the turn buttons.
        presenter.pickShell(-1)
        #expect(mirror.pickedShell == 3)
        #expect(Controls.shellPickerValue(mirror) == "Shell 4 (outer), turned 1 of 8")
        #expect(Controls.turnLabel(mirror, step: 1) == "Turn shell 4 (outer) one sector clockwise")

        // The Sound toggle (kept off screen, so nothing plays).
        presenter.controlsDisappeared()
        presenter.setSound(on: true)
        #expect(mirror.soundOn)
        presenter.setSound(on: false)
        #expect(!mirror.soundOn)
    }

    // MARK: Drag (edge case; clarification Q1)

    /// A two-sector shell drag in progress (finger down and moved, not released) adds no announcement, plan or
    /// haptic; the release, two turns, is announced once ("<Shell> turned 2 sectors …") with one selection haptic.
    @Test func aMultiSectorDragIsAnnouncedOnce() async throws {
        let seed: UInt64 = try #require(try Script.seed { $0.play.level.budget >= 3 }, "a level with budget ≥ 3")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: seed)
        let presenter: Presenter = shell.presenter
        let before: Core = try Access.core(shell)
        _ = presenter.describe(before)
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let target: AmethystEscapeDragTarget =
            try #require(try Script.dragTarget(shell), "a shell ring visible at the authored orbit")
        let digest: String = try AmethystEscapeTest.digest(shell)
        var time: Double = 0

        recorder.clock.advance()
        Script.dragWithoutRelease(shell, along: target.path, time: &time)
        #expect(presenter.gestures.state == .shellDrag)
        #expect(presenter.gestures.candidateSectors == target.sectors)
        let text: String = presenter.describe(try Access.core(shell))
        #expect(text.contains("would turn 2 sectors"), "\(text)")
        try AmethystEscapeTest.draw(session)
        #expect(recorder.announcements.announced.isEmpty, "the preview is not announced")
        #expect(presenter.feedbackLog.count == logBase, "the preview plans nothing")
        #expect(recorder.haptics.played.isEmpty, "the preview plays no haptic")
        #expect(try AmethystEscapeTest.digest(shell) == digest, "nothing is sent before the release")

        recorder.clock.advance()
        let last: Vec2 = try #require(target.path.last)
        Script.touch(shell, id: 1, .ended, at: last, time: &time)
        let after: Core = try Access.core(shell)
        #expect(after.play.moves == before.play.moves + 2, "the drag is two turns")
        let plan: Plan = Plan.drag(old: before, new: after, shell: target.shell, sectors: abs(target.sectors))
        let direction: String = target.sectors > 0 ? "clockwise" : "anticlockwise"
        let expectedText: String = Access.sentence(before.play.level.shellName(target.shell))
            + " turned 2 sectors \(direction). \(Access.leftText(after.play.remaining))."
        #expect(plan.text == expectedText, "\(plan.text ?? "nil")")
        #expect(plan.kind == .state)
        #expect(plan.haptic == .selection)
        let expected: [Plan] = [plan]
        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected), "the release is announced once")
        #expect(recorder.haptics.played == Access.haptics(expected), "one selection haptic")
    }

    // MARK: Sound (FR-R02G0706-006; SC-R02G0706-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; each input turning off stops a playing loop; a `play()` that fails changes nothing else; the recipe is
    /// rebuilt only for a new recipe or the toggle turning on, never for the same recipe offered again.
    @Test func soundStateTable() throws {
        let inner: AmbientLoopRecipe = AmethystEscapeSoundRecipe.recipe(pearlShell: 0, shells: 3, stage: .playing)
        let middle: AmbientLoopRecipe = AmethystEscapeSoundRecipe.recipe(pearlShell: 1, shells: 3, stage: .playing)
        let won: AmbientLoopRecipe = AmethystEscapeSoundRecipe.recipe(pearlShell: 2, shells: 3, stage: .won)
        try #require(inner != middle, "a pearl in another shell sounds different")
        try #require(middle != won, "a won play sounds different")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: AmethystEscapeA11yLoopFactory = AmethystEscapeA11yLoopFactory()
            let sound: AmethystEscapeSound = factory.sound(inner)
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
        let toggles: AmethystEscapeA11yLoopFactory = AmethystEscapeA11yLoopFactory()
        let live: AmethystEscapeSound = toggles.sound(inner)
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
        let failing: AmethystEscapeA11yLoopFactory = AmethystEscapeA11yLoopFactory()
        failing.succeeds = false
        let broken: AmethystEscapeSound = failing.sound(inner)
        broken.setOnScreen(true)
        broken.setWanted(true)
        #expect(broken.playersMade == 1)
        #expect(!broken.started)
        #expect(broken.wanted)
        #expect(broken.onScreen)
        #expect(broken.active)
        #expect(broken.shouldPlay)
        #expect(broken.recipe == inner)
        #expect(failing.made.first?.plays == 1)
        #expect(failing.made.first?.isPlaying == false)
        #expect(failing.made.first?.stops == 0)

        // The sound off: offers make no player but are kept.
        let silent: AmethystEscapeA11yLoopFactory = AmethystEscapeA11yLoopFactory()
        let off: AmethystEscapeSound = silent.sound(inner)
        off.setOnScreen(true)
        off.offer(middle)
        off.offer(won)
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)
        #expect(off.recipe == won, "kept for the next start")

        // Rebuilds only at the named moments.
        let factory: AmethystEscapeA11yLoopFactory = AmethystEscapeA11yLoopFactory()
        let sound: AmethystEscapeSound = factory.sound(inner)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(inner) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(middle)
        #expect(sound.playersMade == 2, "a change of the pearl's shell makes a new player")
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
        sound.offer(inner)
        #expect(sound.playersMade == 3, "an offer while off makes no player")
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "the toggle turning on plays the latest recipe")
        #expect(sound.playerRecipe == inner)
        #expect(factory.recipes == [inner, middle, won, inner])
        sound.setWanted(false)
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "toggling with the same recipe keeps the player")
        #expect(sound.started)
    }

    /// The presenter's own sound (real `AmbientLoopPlayer`; never started here): off by default; its recipe follows
    /// the described core (an advance into another shell offers a new one, a turn does not change it); drawn frames
    /// leave it; `setSound`, `controlsAppeared`/`Disappeared` and `sceneActive` set the policy's inputs, and with any
    /// one of them off no player is made.
    @Test func presenterSoundFollowsTheCore() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: Access.scriptedSeed)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        presenter.controlsDisappeared()
        #expect(!presenter.sound.onScreen)
        #expect(!presenter.sound.wanted)
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        let opening: Core = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")

        try AmethystEscapeTest.draw(session, frames: 3)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "drawn frames leave the recipe")
        #expect(presenter.sound.playersMade == 0)

        // A turn keeps the pearl's shell and the recipe; an advance into shell 2 offers the new recipe.
        let turned: ActionResult = presenter.send("shell.rotate", [0, 1], port: shell.port)
        #expect(turned == .accepted, "\(turned.code)")
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "a turn keeps the recipe")
        let undone: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let advanced: ActionResult = presenter.send("pearl.advance", [], port: shell.port)
        #expect(advanced == .accepted, "\(advanced.code)")
        let moved: Core = try Access.core(shell)
        #expect(moved.play.crystal.pearl.shell == 1, "the pearl rolled into shell 2")
        #expect(presenter.sound.recipe == Presenter.recipe(moved), "the recipe follows the pearl's shell")
        #expect(Presenter.recipe(moved) != Presenter.recipe(opening))

        // Off, on screen and active: still no player.
        presenter.controlsAppeared()
        #expect(presenter.sound.onScreen)
        #expect(!presenter.sound.shouldPlay, "the sound is off")
        #expect(presenter.sound.playersMade == 0)
        presenter.controlsDisappeared()
        #expect(!presenter.sound.onScreen)

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

    // MARK: Reduce Motion (FR-R02G0706-004)

    /// Under Reduce Motion two stills of the same advanced state at different frame times are byte-identical and the
    /// drawn snapshot keeps time 0.
    @Test func reduceMotionStillsIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceMotion: true)
        Access.quiet(shell)
        let accepted: Int = AmethystEscapeTest.advance(shell)
        #expect(accepted >= 1)
        // A first still lets any light fade finish (the next frame is 0.25 s later, beyond 0.15 s).
        _ = try AmethystEscapeTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0)
        let first: [UInt8] = try AmethystEscapeTest.still(session, width: Access.stillWidth,
                                                          height: Access.stillHeight, time: 0.25)
        let firstDrawn: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let second: [UInt8] = try AmethystEscapeTest.still(session, width: Access.stillWidth,
                                                           height: Access.stillHeight, time: 1.3)
        let secondDrawn: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(AmethystEscapeTest.nonBackdropPixels(first) > 0, "the still shows the crystal")
        #expect(first == second, "Reduce Motion: stills at 0.25 s and 1.3 s are identical")
        #expect(firstDrawn.time == 0)
        #expect(secondDrawn.time == 0)
        let core: Core = try Access.core(shell)
        #expect(secondDrawn == core.snapshot(time: 0))
    }
}
#endif
