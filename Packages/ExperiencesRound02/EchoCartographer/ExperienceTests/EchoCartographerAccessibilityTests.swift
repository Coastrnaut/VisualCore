// EchoCartographerAccessibilityTests — feature 406 (R02-G11-06) T-R02G1106-005 (FR-R02G1106-001 … 006;
// SC-R02G1106-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Backwards Aurora's feature-396 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running.
// Values: every value the panel reads (`EchoCartographerControls.values(_:)`, the cursor's cell in words, the summary,
// the status and labels) is non-empty words after level 1 is described; the summary element equals
// `EchoCartographerFeedbackPlan.summaryText(core:cursor:)` and follows a stepped column after `refreshSummary()`.
// Level 1 (seed 0) is won with the panel's accessibility operations alone: the adjustable column and row
// (`stepColumn`, `stepRow`, then `refreshSummary()`; never announced, no haptic) move the cursor to each certified
// action's cell and Pulse / Claim / Mark send the cursor's cell through `presenter.send`; every accepted step routes
// exactly `EchoCartographerFeedbackPlan.after(old:new:)` of the cores captured before and after it, and the last one is
// the win outcome with a success haptic. Refusals (a locked level, a pulse from a cell not known open) show
// `refusalText(code:)` and route a rejection with an error haptic. Reduce Motion: two stills of the same state at
// different frame times are byte-identical. Reduce Flashing: the scene draws the rings and flares at rest, two stills
// right after a pulse at different times are identical, and after a win the won light rises below 1 for 0.4 s of frame
// time and reaches 1 by 0.5 s (the 0.45 s fade). Sound: the state table (wanted × on screen × active) and the rebuilds
// use an `EchoCartographerSound` with an injected recording player; the presenter's own sound is only driven off screen
// (no player made). Synthetic data, explicit types, plain loops, no nested closure literals, no wall-clock assertion.
#if os(iOS)
import CoreGraphics
import EchoCartographerCore
import Foundation
import Testing
@testable import EchoCartographerExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class EchoCartographerA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class EchoCartographerA11yLoop: EchoCartographerLoopPlaying {
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
final class EchoCartographerA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [EchoCartographerA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> EchoCartographerA11yLoop {
        let loop: EchoCartographerA11yLoop = EchoCartographerA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> EchoCartographerSound {
        EchoCartographerSound(recipe: recipe, makePlayer: { next in self.make(next) })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum EchoCartographerA11y {
    typealias Shell = ExperienceShell<EchoCartographerPresenter>
    typealias Plan = EchoCartographerFeedbackPlan
    typealias Core = EchoCartographerExperienceCore

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: EchoCartographerA11yClock
    }

    /// The still size of the Reduce Motion and Reduce Flashing tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await EchoCartographerTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                               reduceFlashing: reduceFlashing,
                                                               size: CGSize(width: 360, height: 240))
        let opening: Core = try EchoCartographerTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: EchoCartographerA11yClock = EchoCartographerA11yClock()
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
        try EchoCartographerTest.core(shell)
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

    /// Moves the panel's cursor to `cell` with the adjustable column and row operations only (`stepColumn(±1)`,
    /// `stepRow(±1)`, each followed by `refreshSummary()` as the panel's increment and decrement do). Returns the
    /// presses made.
    static func moveCursor(_ presenter: EchoCartographerPresenter, to cell: EchoCartographerCell) -> Int {
        let mirror: EchoCartographerMirror = presenter.mirror
        var presses: Int = 0
        for _ in 0..<128 {
            if mirror.column < cell.x {
                mirror.stepColumn(1)
            } else if mirror.column > cell.x {
                mirror.stepColumn(-1)
            } else if mirror.row < cell.y {
                mirror.stepRow(1)
            } else if mirror.row > cell.y {
                mirror.stepRow(-1)
            } else {
                break
            }
            presenter.refreshSummary()
            presses += 1
        }
        return presses
    }

    /// Sends the refused `control` with `values` through the presenter, one clock second later; expects a refusal,
    /// an unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), its words in the panel and the
    /// code in `refusalLog`. Returns the plan.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: EchoCartographerPresenter = shell.presenter
        let digest: String = try EchoCartographerTest.digest(shell)
        let logBefore: Int = presenter.feedbackLog.count
        let playedBefore: Int = recorder.haptics.played.count
        recorder.clock.advance()
        let result: ActionResult = presenter.send(control, values, port: shell.port)
        #expect(!result.isAccepted, "\(control) \(values) is refused", sourceLocation: sourceLocation)
        let plan: Plan = Plan.refused(code: result.code)
        #expect(plan.kind == .rejection, sourceLocation: sourceLocation)
        #expect(plan.haptic == .error, sourceLocation: sourceLocation)
        #expect(plan.text == Plan.refusalText(code: result.code), sourceLocation: sourceLocation)
        #expect(presenter.feedbackLog.count == logBefore + 1, "a refusal routes one plan",
                sourceLocation: sourceLocation)
        #expect(presenter.feedbackLog.last == plan, sourceLocation: sourceLocation)
        #expect(presenter.mirror.message == Plan.refusalText(code: result.code), "the panel shows the same words",
                sourceLocation: sourceLocation)
        #expect(presenter.refusalLog.last == result.code, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        let after: String = try EchoCartographerTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }
}

@MainActor
@Suite(.serialized) struct EchoCartographerAccessibilityTests {
    typealias Access = EchoCartographerA11y
    typealias Plan = EchoCartographerFeedbackPlan
    typealias Presenter = EchoCartographerPresenter
    typealias Core = EchoCartographerExperienceCore

    // MARK: Values and the summary element (FR-R02G1106-001, 005; clarification Q5)

    /// After level 1 is described every value the panel reads is non-empty words; the summary element equals
    /// `summaryText(core:cursor:)` and follows a stepped column after `refreshSummary()`; stepping routes nothing.
    @Test func everyControlHasAValueInWords() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: EchoCartographerMirror = presenter.mirror
        let values: EchoCartographerControls.Values = EchoCartographerControls.values(mirror)
        let all: [String] = [values.energy, values.nextLevel, values.retry, values.playLevel, mirror.columnLabel,
                             mirror.rowLabel, mirror.cursorLabel, mirror.summary, mirror.status, mirror.measureLabel,
                             mirror.targetLabel, mirror.goalLabel]
        var index: Int = 0
        for value in all {
            #expect(!value.isEmpty, "value \(index) is empty")
            index += 1
        }
        let energy: Int = core.play.energy
        let budget: Int = core.play.level.energy
        #expect(values.energy == "\(energy) of \(budget) energy left", "\(values.energy)")
        #expect(values.nextLevel == "no further level open", "\(values.nextLevel)")
        #expect(values.retry == "level 1, campaign", "\(values.retry)")
        #expect(values.playLevel == "level 1", "\(values.playLevel)")
        let entry: EchoCartographerCell = core.play.level.entry
        #expect(mirror.column == entry.x && mirror.row == entry.y, "a level opens with the cursor on the entry")
        #expect(mirror.cursorLabel == core.play.level.cellName(entry, knowledge: core.play.knowledge))

        #expect(EchoCartographerControls.viewValue(true) == "authored view")
        #expect(EchoCartographerControls.viewValue(false) == "orbited view")
        #expect(EchoCartographerControls.selectedValue(true) == "selected")
        #expect(EchoCartographerControls.selectedValue(false) == "not selected")
        #expect(EchoCartographerControls.modeName(.campaign) == "campaign")
        #expect(EchoCartographerControls.modeName(.practice) == "practice")
        #expect(EchoCartographerControls.readableWidth == 520)

        // The summary element: the opening's words, then a stepped column changes the chosen cell.
        #expect(mirror.summary == Plan.summaryText(core: core, cursor: entry), "\(mirror.summary)")
        #expect(mirror.summary.contains("Chosen cell: " + mirror.cursorLabel + "."), "\(mirror.summary)")
        let delta: Int = entry.x < mirror.width - 1 ? 1 : -1
        mirror.stepColumn(delta)
        #expect(mirror.column == entry.x + delta)
        presenter.refreshSummary()
        let stepped: EchoCartographerCell = EchoCartographerCell(x: entry.x + delta, y: entry.y)
        #expect(mirror.summary == Plan.summaryText(core: core, cursor: stepped), "\(mirror.summary)")
        let steppedName: String = core.play.level.cellName(stepped, knowledge: core.play.knowledge)
        #expect(mirror.summary.contains("Chosen cell: " + steppedName + "."), "\(mirror.summary)")
        #expect(mirror.cursorLabel == steppedName)
        #expect(presenter.feedbackLog.isEmpty, "describing and stepping plan nothing")
    }

    // MARK: The panel alone (SC-R02G1106-001, 002)

    /// Level 1 (seed 0) is won with the panel's accessibility operations alone: the column and row move the cursor to
    /// each certified action's cell (never announced, no haptic) and Pulse / Claim / Mark send the cursor's cell; every
    /// accepted step routes exactly `after(old:new:)`; the sinks hold the plans' words and haptics in order; the last
    /// is the win outcome with a success haptic.
    @Test func levelOneWonWithThePanelOperations() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: EchoCartographerMirror = presenter.mirror
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        let actions: [EchoCartographerAction] = try EchoCartographerTest.certifiedActions(1)
        try #require(!actions.isEmpty, "level 1 has a certified solution")
        var expected: [Plan] = []
        var presses: Int = 0
        var sent: Int = 0

        for action in actions {
            let stage: EchoCartographerStage = try Access.core(shell).play.stage
            guard stage == .playing else { break }
            let logBefore: Int = presenter.feedbackLog.count
            let announcedBefore: Int = recorder.announcements.announced.count
            let playedBefore: Int = recorder.haptics.played.count
            presses += Access.moveCursor(presenter, to: action.cell)
            #expect(mirror.column == action.cell.x && mirror.row == action.cell.y, "the cursor reached \(action.cell)")
            #expect(presenter.feedbackLog.count == logBefore, "a cursor move plans nothing")
            #expect(recorder.announcements.announced.count == announcedBefore, "a cursor move is not announced")
            #expect(recorder.haptics.played.count == playedBefore, "a cursor move plays no haptic")
            let old: Core = try Access.core(shell)
            #expect(mirror.summary == Plan.summaryText(core: old, cursor: mirror.cursor), "\(mirror.summary)")

            // The panel's button sends the cursor's cell.
            let control: String = EchoCartographerTest.control(action).control
            let cursorValues: [Double] = [Double(mirror.column), Double(mirror.row)]
            recorder.clock.advance()
            let result: ActionResult = presenter.send(control, cursorValues, port: shell.port)
            #expect(result == .accepted, "action \(sent + 1) \(control) \(cursorValues): \(result.code)")
            sent += 1
            let new: Core = try Access.core(shell)
            let plan: Plan = Plan.after(old: old, new: new)
            #expect(plan.text != nil, "action \(sent) is announced")
            #expect(presenter.feedbackLog.count == logBefore + 1, "action \(sent) routes one plan")
            #expect(presenter.feedbackLog.last == plan)
            #expect(recorder.announcements.announced.last == plan.text)
            expected.append(plan)
            let routed: Int = presenter.feedbackLog.count
            _ = presenter.describe(new)
            #expect(presenter.feedbackLog.count == routed, "describing the same state again routes nothing")
            #expect(mirror.summary == Plan.summaryText(core: new, cursor: mirror.cursor), "\(mirror.summary)")
            if new.play.stage != .won {
                #expect(plan.kind == .state)
                #expect(plan.haptic == .selection)
            }
        }
        #expect(sent == actions.count, "every certified action was sent")
        #expect(presses > 0, "the column and row were used")

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        let spent: Int = EchoCartographerProgress.energySpent(won.play)
        let stars: Int = EchoCartographerProgress.stars(energySpent: spent, certified: won.certifiedPulses)
        #expect(stars == 3)
        let winText: String = Plan.wonText + " Level won spending " + String(spent) + " energy, "
            + String(stars) + " of 3 stars."
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
        #expect(recorder.haptics.played.last == .success)
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.message == nil)
    }

    // MARK: Refusals (FR-R02G1106-002, 003; clarification Q1)

    /// A locked level and a pulse from a cell not known open are refused: the panel shows `refusalText(code:)`, a
    /// rejection with an error haptic is routed, and nothing changes.
    @Test func refusalsAreShownAndAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count

        let locked: Plan = try Access.refused(shell, recorder, "level.select", [3])
        #expect(locked.text == "That level is not open yet.", "\(locked.text ?? "nil")")
        #expect(presenter.refusalLog.last?.contains(EchoCartographerExperienceRule.locked) == true)

        let opening: Core = try Access.core(shell)
        let entry: EchoCartographerCell = opening.play.level.entry
        let width: Int = opening.play.level.chamber.width
        let height: Int = opening.play.level.chamber.height
        let corner: EchoCartographerCell = entry.x == 0 && entry.y == 0
            ? EchoCartographerCell(x: width - 1, y: height - 1) : EchoCartographerCell(x: 0, y: 0)
        let unknown: Plan = try Access.refused(shell, recorder, "cell.pulse", [Double(corner.x), Double(corner.y)])
        #expect(unknown.text != nil)

        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == [locked, unknown])
        #expect(recorder.haptics.played == [HapticKind.error, HapticKind.error])
        #expect(recorder.announcements.announced == Access.texts(plans))
    }

    // MARK: Reduce Motion and Reduce Flashing stills (FR-R02G1106-004; SC-R02G1106-003)

    /// Under Reduce Motion two stills of the same pulsed state at different frame times are byte-identical. Under
    /// Reduce Flashing the scene draws the rings and flares at rest, and two stills right after a pulse at different
    /// times are byte-identical.
    @Test func reducedStillsAreIdentical() async throws {
        let motionSession = ExperienceSession()
        defer { motionSession.close() }
        let motion = try await Access.open(motionSession, seed: 0, reduceMotion: true)
        Access.quiet(motion)
        #expect(motion.presenter.scene.ringsAtRest)
        #expect(try EchoCartographerTest.advance(motion))
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        // Two first stills let any light fade finish (0.5 s apart, beyond the 0.15 s fade).
        _ = try EchoCartographerTest.still(motionSession, width: w, height: h, time: 0)
        _ = try EchoCartographerTest.still(motionSession, width: w, height: h, time: 0.5)
        let first: [UInt8] = try EchoCartographerTest.still(motionSession, width: w, height: h, time: 0.75)
        let second: [UInt8] = try EchoCartographerTest.still(motionSession, width: w, height: h, time: 1.9)
        #expect(EchoCartographerTest.nonGroundPixels(first) > 0, "the still shows the chamber")
        #expect(first == second, "Reduce Motion: stills at 0.75 s and 1.9 s are identical")
        #expect(motion.presenter.lights.isSettled, "the lights rest")

        let flashSession = ExperienceSession()
        defer { flashSession.close() }
        let flash = try await Access.open(flashSession, seed: 0, reduceFlashing: true)
        Access.quiet(flash)
        let scene: EchoCartographerChamberScene = flash.presenter.scene
        #expect(scene.reducedFlash)
        #expect(!scene.reduceMotion)
        #expect(scene.ringsAtRest, "Reduce Flashing draws the rings and flares at rest")
        let base: Double = 10
        _ = try EchoCartographerTest.still(flashSession, width: w, height: h, time: base)
        #expect(try EchoCartographerTest.advance(flash))
        let atPulse: [UInt8] = try EchoCartographerTest.still(flashSession, width: w, height: h, time: base + 0.05)
        let early: [UInt8] = try EchoCartographerTest.still(flashSession, width: w, height: h, time: base + 0.3)
        let late: [UInt8] = try EchoCartographerTest.still(flashSession, width: w, height: h, time: base + 1.2)
        #expect(EchoCartographerTest.nonGroundPixels(early) > 0, "the still shows the chamber")
        #expect(atPulse == early, "Reduce Flashing: no ring at the pulse's first frames")
        #expect(early == late, "Reduce Flashing: stills 0.3 s and 1.2 s after a pulse are identical")
        #expect(flash.presenter.lights.isSettled, "a pulse keeps the playing lights")
    }

    // MARK: Lights under Reduce Flashing (FR-R02G1106-004; SC-R02G1106-003)

    /// Under Reduce Flashing the won light rises over 0.45 s of frame time after the winning action: below 1 (and
    /// rising) at 0.1 … 0.4 s, 1 at 0.5 s, with the glow at its won level; the scene draws the presenter's lights.
    @Test func reduceFlashingWonLightFades() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0, reduceFlashing: true)
        Access.quiet(shell)
        let presenter: Presenter = shell.presenter
        let actions: [EchoCartographerAction] = try EchoCartographerTest.certifiedActions(1)
        try #require(!actions.isEmpty, "level 1 has a certified solution")
        var index: Int = 0
        for action in actions.dropLast() {
            index += 1
            let entry: (control: String, values: [Double]) = EchoCartographerTest.control(action)
            let result: ActionResult = shell.handle(control: entry.control, values: entry.values)
            #expect(result == .accepted, "action \(index): \(result.code)")
        }
        try #require(try Access.core(shell).play.stage == .playing, "only the last certified action wins")
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        let base: Double = 10
        _ = try EchoCartographerTest.still(session, width: w, height: h, time: base - 1)
        _ = try EchoCartographerTest.still(session, width: w, height: h, time: base)
        #expect(presenter.lights.won == 0, "the won light rests at 0 while playing")
        #expect(presenter.lights.glow == EchoCartographerLights.glowPlaying)

        let last: (control: String, values: [Double]) = EchoCartographerTest.control(try #require(actions.last))
        let winning: ActionResult = shell.handle(control: last.control, values: last.values)
        #expect(winning == .accepted, "\(winning.code)")
        #expect(try Access.core(shell).play.stage == .won)

        let rising: [Double] = [0.1, 0.2, 0.3, 0.4]
        var previous: Double = 0
        for offset in rising {
            _ = try EchoCartographerTest.still(session, width: w, height: h, time: base + offset)
            let level: Double = presenter.lights.won
            #expect(level > previous, "the won light rises at \(offset) s: \(level)")
            #expect(level < 1, "the won light is below 1 at \(offset) s: \(level)")
            #expect(presenter.scene.lights?.won == level, "the scene draws the presenter's lights")
            previous = level
        }
        _ = try EchoCartographerTest.still(session, width: w, height: h, time: base + 0.5)
        #expect(presenter.lights.won == 1, "the won light reaches 1 after 0.45 s")
        #expect(presenter.lights.glow == EchoCartographerLights.glowWon)
        #expect(presenter.lights.isSettled)
    }

    // MARK: Sound (FR-R02G1106-006; SC-R02G1106-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; each input turning off stops a playing loop; a new player is made only for a different recipe or the
    /// toggle turning on, never for the same recipe offered again. The presenter's toggle, driven off screen, makes no
    /// player.
    @Test func soundStateTable() throws {
        let calm: AmbientLoopRecipe = EchoCartographerSoundRecipe.recipe(rootStep: 3, located: 0, stage: .playing)
        let one: AmbientLoopRecipe = EchoCartographerSoundRecipe.recipe(rootStep: 3, located: 1, stage: .playing)
        let won: AmbientLoopRecipe = EchoCartographerSoundRecipe.recipe(rootStep: 3, located: 1, stage: .won)
        try #require(calm != one, "another located count sounds different")
        try #require(one != won, "a won play sounds different")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: EchoCartographerA11yLoopFactory = EchoCartographerA11yLoopFactory()
            let sound: EchoCartographerSound = factory.sound(calm)
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

        // Each input turning off stops a playing loop; turning back on plays again with the same player.
        let toggles: EchoCartographerA11yLoopFactory = EchoCartographerA11yLoopFactory()
        let live: EchoCartographerSound = toggles.sound(calm)
        #expect(!live.wanted, "the sound is off by default")
        live.setOnScreen(true)
        live.setWanted(true)
        #expect(live.started)
        live.setActive(false)
        #expect(!live.started, "an inactive scene stops the loop")
        #expect(toggles.made.first?.isPlaying == false)
        live.setActive(true)
        live.setOnScreen(false)
        #expect(!live.started, "controls off screen stop the loop")
        live.setOnScreen(true)
        live.setWanted(false)
        #expect(!live.started, "the sound off stops the loop")
        live.setWanted(true)
        #expect(live.started)
        #expect(live.playersMade == 1, "the same recipe keeps its player")

        // Rebuilds only when the recipe differs.
        let factory: EchoCartographerA11yLoopFactory = EchoCartographerA11yLoopFactory()
        let sound: EchoCartographerSound = factory.sound(calm)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(calm) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(one)
        #expect(sound.playersMade == 2, "a change of the located count makes a new player")
        if factory.made.count == 2 {
            #expect(!factory.made[0].isPlaying, "the old player stopped")
            #expect(factory.made[1].isPlaying)
        }
        sound.offer(won)
        #expect(sound.playersMade == 3, "a change of the stage makes a new player")
        #expect(sound.playerRecipe == won)
        sound.setWanted(false)
        sound.offer(calm)
        #expect(sound.playersMade == 3, "an offer while off makes no player")
        #expect(sound.recipe == calm, "kept for the next start")
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "the toggle turning on plays the latest recipe")
        #expect(factory.recipes == [calm, one, won, calm])

        // The presenter's toggle with the controls off screen: no player is made.
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(presenter.sound.recipe == Presenter.recipe(core), "the first state offers its recipe")
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        presenter.sceneActive(false)
        presenter.controlsAppeared()
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the loop silent")
        presenter.controlsDisappeared()
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        presenter.sceneActive(true)
        #expect(presenter.sound.playersMade == 0, "no player was made")
    }
}
#endif
