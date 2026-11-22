// NocturneGardenAccessibilityTests — feature 386 (R02-G09-06) T-R02G0906-005 (FR-R02G0906-001 … 006;
// SC-R02G0906-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Faceted Forge's feature-376 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running. On level 1 (seed 0,
// tutorial `plant`) the tutorial's dismissal (nothing planned), the first certified move, its undo and redo, a redo
// with nothing to redo (`r02-g09.action`), a locked level (`level.select [5]`, `r02-g09.locked`) and
// `level.select [1]` (a `level` plan without haptic, with the tutorial instruction) record exactly
// `NocturneGardenFeedbackPlan.after(old:new:)` and `refused(code:)` in the sinks and in the presenter's feedback log
// (the refusal texts are written out from clarification Q1); a second description of the same state routes nothing;
// the panel shows the refusal's words (`refusalText`). A revealed hint is announced after the off-main-actor search
// finishes: `state`, its words, no haptic. Level 1 is won with the panel's accessibility operations alone: the
// adjustable kind, column, row, size, bloom and sun pickers (`pickKind`, `stepColumn`, `stepRow`, `stepSize`,
// `pickBloom`, `stepSun`, never announced) line up each certified move
// (`NocturneGardenExperienceCore.generated(number: 1).solution`) and Plant, Move, Resize, Remove or Set sun sends the
// mirror's choice as the panel's buttons do; every move is announced and the winning move routes only the outcome
// ("The shadow matches the target. Level won with …"), with a success haptic. The labels and values the panel reads
// from the mirror are words and never empty; the summary element's words equal `summaryText(core:)`. Reduce Motion:
// two stills of the same state at different frame times are byte-identical and the drawn snapshot keeps time 0.
// Sound: the presenter makes its own `NocturneGardenSound` with the real `AmbientLoopPlayer`, so the state table
// (wanted × on screen × active) and the offers use a `NocturneGardenSound` with an injected recording player; the
// presenter's own sound is only driven off screen (no audio starts) and its recipe follows the described core.
// Synthetic data, explicit types, plain loops, no nested closure literals, no sleep, no wall-clock assertion; few
// frames, each test short.
#if os(iOS)
import CoreGraphics
import Foundation
import NocturneGardenCore
import Testing
@testable import NocturneGardenExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class NocturneGardenA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class NocturneGardenA11yLoop: NocturneGardenLoopPlaying {
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
final class NocturneGardenA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [NocturneGardenA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> NocturneGardenA11yLoop {
        let loop: NocturneGardenA11yLoop = NocturneGardenA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> NocturneGardenSound {
        NocturneGardenSound(recipe: recipe, makePlayer: { next in self.make(next) })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum NocturneGardenA11y {
    typealias Shell = ExperienceShell<NocturneGardenPresenter>
    typealias Plan = NocturneGardenFeedbackPlan
    typealias Core = NocturneGardenExperienceCore

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: NocturneGardenA11yClock
    }

    /// The seed of the Reduce Motion test (level 87, no tutorial).
    static let seed: UInt64 = 2_386
    /// The still size of the Reduce Motion test (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await NocturneGardenTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                             reduceFlashing: reduceFlashing,
                                                             size: CGSize(width: 360, height: 240))
        let opening: Core = try NocturneGardenTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: NocturneGardenA11yClock = NocturneGardenA11yClock()
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
        try NocturneGardenTest.core(shell)
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
    static func log(_ presenter: NocturneGardenPresenter, after count: Int) -> [Plan] {
        Array(presenter.feedbackLog.dropFirst(count))
    }

    /// Presses Hint one clock second later and waits for the search it started (the search runs off the main actor;
    /// a cached play reveals at once).
    static func pressHint(_ presenter: NocturneGardenPresenter, _ recorder: Recorder) async {
        recorder.clock.advance()
        presenter.showHint()
        await presenter.hintSearch?.value
    }

    /// Sends the accepted `control` with `values` through the presenter as the panel does, one clock second later;
    /// expects the feedback log to grow by exactly the plan of the change (nothing for `.none`), the panel to show no
    /// refusal, the summary element to read `summaryText(core:)` and a second description of the same state to route
    /// nothing. Returns the plan.
    @discardableResult
    static func accepted(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double] = [],
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: NocturneGardenPresenter = shell.presenter
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
        #expect(presenter.mirror.summary == Plan.summaryText(core: new), "\(presenter.mirror.summary)",
                sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(new)
        #expect(presenter.feedbackLog.count == count, "describing the same state again routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// Sends the refused `control` with `values` through the presenter, one clock second later; expects a code that
    /// contains `code`, an unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`) and its words
    /// in the panel. Returns the plan.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double], code: String,
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: NocturneGardenPresenter = shell.presenter
        let digest: String = try NocturneGardenTest.digest(shell)
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
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        let after: String = try NocturneGardenTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// Moves the column and row picks to `column` and `row` with `stepColumn(±1)` and `stepRow(±1)`. Returns the
    /// presses made.
    static func lineUpCell(_ mirror: NocturneGardenMirror, column: Int, row: Int) -> Int {
        var presses: Int = 0
        for _ in 0..<32 where mirror.column != column {
            mirror.stepColumn(mirror.column < column ? 1 : -1)
            presses += 1
        }
        for _ in 0..<24 where mirror.row != row {
            mirror.stepRow(mirror.row < row ? 1 : -1)
            presses += 1
        }
        return presses
    }

    /// Moves the size pick to `size` with `stepSize(±1)`. Returns the presses made.
    static func lineUpSize(_ mirror: NocturneGardenMirror, size: Int) -> Int {
        var presses: Int = 0
        for _ in 0..<4 where mirror.size != size {
            mirror.stepSize(mirror.size < size ? 1 : -1)
            presses += 1
        }
        return presses
    }

    /// Moves the bloom pick to `bloom` with `pickBloom(1)`. Returns the presses made.
    static func lineUpBloom(_ mirror: NocturneGardenMirror, bloom: Int) -> Int {
        var presses: Int = 0
        for _ in 0..<12 where mirror.bloom != bloom {
            mirror.pickBloom(1)
            presses += 1
        }
        return presses
    }

    /// Lines the panel's picks up with `action` using only the adjustable pickers' operations, which route nothing
    /// and play no haptic, and returns the control and values the panel's button then sends (Plant, Move, Resize,
    /// Remove or Set sun, each with the mirror's picks) and the presses made.
    static func lineUp(_ shell: Shell, _ recorder: Recorder, _ action: NocturneGardenAction,
                       sourceLocation: SourceLocation = #_sourceLocation)
        -> (control: String, values: [Double], presses: Int) {
        let mirror: NocturneGardenMirror = shell.presenter.mirror
        let logBefore: Int = shell.presenter.feedbackLog.count
        let announcedBefore: Int = recorder.announcements.announced.count
        let playedBefore: Int = recorder.haptics.played.count
        var presses: Int = 0
        let control: String
        let values: [Double]
        switch action {
        case let .plant(kind, column, row, size):
            for _ in 0..<NocturneGardenKind.allCases.count where mirror.kind != kind.order {
                mirror.pickKind(1)
                presses += 1
            }
            presses += lineUpCell(mirror, column: column, row: row)
            presses += lineUpSize(mirror, size: size)
            #expect(mirror.kind == kind.order, "the kind picker reached \(kind.name)", sourceLocation: sourceLocation)
            #expect(mirror.column == column && mirror.row == row, "the cell pickers reached (\(column), \(row))",
                    sourceLocation: sourceLocation)
            #expect(mirror.size == size, "the size picker reached \(size)", sourceLocation: sourceLocation)
            control = "bloom.plant"
            values = [Double(mirror.kind), Double(mirror.column), Double(mirror.row), Double(mirror.size)]
        case let .move(bloom, column, row):
            presses += lineUpBloom(mirror, bloom: bloom)
            presses += lineUpCell(mirror, column: column, row: row)
            #expect(mirror.bloom == bloom, "the bloom picker reached \(bloom)", sourceLocation: sourceLocation)
            #expect(mirror.column == column && mirror.row == row, "the cell pickers reached (\(column), \(row))",
                    sourceLocation: sourceLocation)
            control = "bloom.move"
            values = [Double(mirror.bloom), Double(mirror.column), Double(mirror.row)]
        case let .resize(bloom, size):
            presses += lineUpBloom(mirror, bloom: bloom)
            presses += lineUpSize(mirror, size: size)
            #expect(mirror.bloom == bloom, "the bloom picker reached \(bloom)", sourceLocation: sourceLocation)
            #expect(mirror.size == size, "the size picker reached \(size)", sourceLocation: sourceLocation)
            control = "bloom.resize"
            values = [Double(mirror.bloom), Double(mirror.size)]
        case let .remove(bloom):
            presses += lineUpBloom(mirror, bloom: bloom)
            #expect(mirror.bloom == bloom, "the bloom picker reached \(bloom)", sourceLocation: sourceLocation)
            control = "bloom.remove"
            values = [Double(mirror.bloom)]
        case let .sun(elevation):
            for _ in 0..<4 where mirror.sunPick != elevation {
                mirror.stepSun(mirror.sunPick < elevation ? 1 : -1)
                presses += 1
            }
            #expect(mirror.sunPick == elevation, "the sun picker reached \(elevation)", sourceLocation: sourceLocation)
            control = "sun.set"
            values = [Double(mirror.sunPick)]
        }
        #expect(shell.presenter.feedbackLog.count == logBefore, "a pick plans nothing", sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.count == announcedBefore, "a pick is not announced",
                sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore, "a pick plays no haptic",
                sourceLocation: sourceLocation)
        return (control, values, presses)
    }
}

@MainActor
@Suite(.serialized) struct NocturneGardenAccessibilityTests {
    typealias Access = NocturneGardenA11y
    typealias Plan = NocturneGardenFeedbackPlan
    typealias Presenter = NocturneGardenPresenter
    typealias Core = NocturneGardenExperienceCore

    // MARK: Recorded feedback (FR-R02G0906-002, 003; SC-R02G0906-002)

    /// The dismissal, the first certified move, undo, redo, a redo with nothing to redo, a locked level and
    /// `level.select [1]` on level 1: the sinks receive exactly the plans of `NocturneGardenFeedbackPlan`, in order,
    /// and the feedback log holds the same plans; haptics per clarification Q2 (selection, error, none for the level
    /// change); the panel shows each refusal's words.
    @Test func recordedFeedbackThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .plant)
        #expect(opening.play.stage == .playing)
        let budget: Int = opening.play.level.budget
        let actions: [NocturneGardenAction] = try NocturneGardenTest.certifiedActions(1)
        try #require(actions.count >= 2, "level 1 needs more than one move")
        var expected: [Plan] = []

        func state(_ plan: Plan, prefix: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let text: String = plan.text ?? ""
            #expect(text.hasPrefix(prefix), "\(text)", sourceLocation: sourceLocation)
            #expect(plan.kind == .state, sourceLocation: sourceLocation)
            #expect(plan.haptic == .selection, sourceLocation: sourceLocation)
            expected.append(plan)
        }

        // The dismissal plans nothing.
        let dismissed: Plan = try Access.accepted(shell, recorder, "tutorial.dismiss")
        #expect(dismissed == Plan.none, "the dismissal is not announced")

        // The first certified move, its undo and redo: `state` with the measure and the moves left.
        let first = NocturneGardenTest.control(actions[0])
        let moved: Plan = try Access.accepted(shell, recorder, first.control, first.values)
        let movePrefix: String
        switch actions[0] {
        case .plant: movePrefix = "Planted bloom "
        case .sun(let elevation): movePrefix = "Sun \(elevation) of 4. Match "
        default: movePrefix = ""
        }
        state(moved, prefix: movePrefix)
        let left: String = Plan.movesLeft(budget - 1) + "."
        #expect(moved.text?.hasSuffix(" " + left) == true, "\(moved.text ?? "nil")")
        state(try Access.accepted(shell, recorder, "play.undo"), prefix: "Undone. Match ")
        state(try Access.accepted(shell, recorder, "play.redo"), prefix: "Redone. Match ")
        #expect(expected.last?.text?.hasSuffix(" " + left) == true, "\(expected.last?.text ?? "nil")")

        // Nothing to redo, and a level that is not open yet.
        let nothing: Plan = try Access.refused(shell, recorder, "play.redo", [], code: "r02-g09.action")
        #expect(nothing.text == "That move is not possible here.", "\(nothing.text ?? "nil")")
        expected.append(nothing)
        let locked: Plan = try Access.refused(shell, recorder, "level.select", [5], code: "r02-g09.locked")
        #expect(locked.text == "That level is not open yet.", "\(locked.text ?? "nil")")
        expected.append(locked)

        // The level reopened is a `level` plan with the tutorial instruction and no haptic.
        let reopened: Plan = try Access.accepted(shell, recorder, "level.select", [1])
        let plant: String = NocturneGardenTutorialStep.plant.text
        #expect(reopened.text == "Level 1, band 1, campaign. " + plant, "\(reopened.text ?? "nil")")
        #expect(reopened.kind == .level)
        #expect(reopened.haptic == nil, "a level change plays no haptic")
        expected.append(reopened)

        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.announcements.announced.count == expected.count, "every plan here is announced")
        let haptics: [HapticKind] = [.selection, .selection, .selection, .error, .error]
        #expect(recorder.haptics.played == haptics, "\(recorder.haptics.played)")
        #expect(recorder.haptics.played == Access.haptics(expected))
        let now: Core = try Access.core(shell)
        #expect(presenter.mirror.summary == Plan.summaryText(core: now))
    }

    /// A refusal is announced as `rejection` with an error haptic and the panel shows the same words; an accepted
    /// action afterwards clears them.
    @Test func aRefusalIsAnnouncedAndShown() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let undo: Plan = try Access.refused(shell, recorder, "play.undo", [], code: "r02-g09.action")
        #expect(undo.text == "That move is not possible here.", "\(undo.text ?? "nil")")
        #expect(recorder.haptics.played == [HapticKind.error])
        #expect(recorder.announcements.announced == ["That move is not possible here."])
        #expect(presenter.refusalLog.last?.contains("r02-g09.action") == true)
        #expect(Plan.refusalText(code: "r02-g09.locked") == "That level is not open yet.")
        #expect(Plan.refusalText(code: "action.out-of-range") == "That move was refused.")
        try Access.accepted(shell, recorder, "tutorial.dismiss")
        #expect(presenter.mirror.message == nil, "an accepted action clears the refusal's words")
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
        let digest: String = try NocturneGardenTest.digest(shell)
        var expected: [Plan] = []
        for level in 1...2 {
            await Access.pressHint(presenter, recorder)
            let want: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: level, play: opening.play))
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
        #expect(try NocturneGardenTest.digest(shell) == digest, "a hint changes nothing")
    }

    // MARK: The panel alone (SC-R02G0906-001)

    /// Level 1 (seed 0) is won with the panel's accessibility operations alone: the pickers line up each certified
    /// move (never announced) and the panel's button sends the mirror's picks; every move is announced with a
    /// selection haptic and equals `after(old:new:)`; the winning move routes only the outcome, with a success haptic.
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
        let actions: [NocturneGardenAction] = try NocturneGardenTest.certifiedActions(1)
        try #require(!actions.isEmpty, "level 1 has a certified solution")
        var presses: Int = 0
        var winRouted: Int = -1
        var sent: Int = 0

        for (index, action) in actions.enumerated() {
            let stage: NocturneGardenStage = try Access.core(shell).play.stage
            guard stage == .playing else { break }
            let button: (control: String, values: [Double], presses: Int) = Access.lineUp(shell, recorder, action)
            presses += button.presses
            let old: Core = try Access.core(shell)
            let before: Int = presenter.feedbackLog.count
            recorder.clock.advance()
            let result: ActionResult = presenter.send(button.control, button.values, port: shell.port)
            #expect(result == .accepted, "move \(index + 1) \(button.control) \(button.values): \(result.code)")
            sent += 1
            let new: Core = try Access.core(shell)
            let plan: Plan = Plan.after(old: old, new: new)
            #expect(plan.text != nil, "move \(index + 1) is announced")
            #expect(presenter.feedbackLog.count == before + 1, "move \(index + 1) routes one plan")
            #expect(presenter.feedbackLog.last == plan)
            #expect(recorder.announcements.announced.last == plan.text)
            #expect(presenter.mirror.summary == Plan.summaryText(core: new))
            if new.play.stage == .won {
                winRouted = presenter.feedbackLog.count - before
            } else {
                #expect(plan.kind == .state)
                #expect(plan.haptic == .selection)
                #expect(recorder.haptics.played.last == .selection)
                let left: String = Plan.movesLeft(new.play.remaining) + "."
                #expect(plan.text?.hasSuffix(" " + left) == true, "\(plan.text ?? "nil")")
            }
        }
        #expect(sent == actions.count, "every certified move was sent")
        #expect(presses > 0, "the pickers were used")

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(winRouted == 1, "the winning move routes only the outcome")
        let made: Int = NocturneGardenProgress.movesMade(won.play)
        #expect(made == actions.count)
        let stars: Int = NocturneGardenProgress.stars(movesMade: made, smallest: won.certifiedSmallest)
        #expect(stars == 3)
        let winText: String = "The shadow matches the target. Level won with " + Plan.moves(made)
            + " made, 3 of 3 stars."
        let plans: [Plan] = Access.log(presenter, after: logBase)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced.last == winText)
        #expect(plans.count == actions.count, "every move announced, no pick")
        #expect(recorder.announcements.announced == Access.texts(plans))
        #expect(recorder.haptics.played == Access.haptics(plans), "\(recorder.haptics.played)")
        #expect(recorder.haptics.played.last == .success)
        #expect(presenter.mirror.status == "Won")
    }

    // MARK: Labels, pickers and the summary (FR-R02G0906-001, 005; clarification Q5)

    /// The labels and values the panel reads from the mirror are non-empty words; the adjustable kind, column, row,
    /// size, bloom and sun pickers move their picks and their values change in words, never announced; the summary
    /// element's words equal `summaryText(core:)` at the opening (written out in part) and after a plant; the Sound
    /// toggle's choice.
    @Test func labelsPickersAndSummary() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: NocturneGardenMirror = presenter.mirror
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        let level: NocturneGardenLevel = opening.play.level

        // Every value the panel's elements read is words.
        let values: [String] = [mirror.kindLabel, mirror.columnLabel, mirror.rowLabel, mirror.sizeLabel,
                                mirror.bloomLabel, mirror.sunLabel, mirror.sunPickLabel, mirror.summary,
                                mirror.status, mirror.measureLabel, mirror.targetLabel]
        for (index, value) in values.enumerated() {
            #expect(!value.isEmpty, "value \(index) is empty")
        }
        #expect(mirror.bloomLabel == "no bloom planted")
        #expect(mirror.summary == Plan.summaryText(core: opening))
        #expect(mirror.summary.hasPrefix(Plan.movesLeft(level.budget) + ". Match "), "\(mirror.summary)")
        #expect(mirror.summary.contains("; sun \(opening.play.elevation) of 4. Blooms: none. Target: "),
                "\(mirror.summary)")

        // Kind: wraps over the supplied kinds.
        let supplied: [Int] = NocturneGardenMirror.suppliedKinds(level)
        try #require(!supplied.isEmpty)
        #expect(mirror.kind == supplied[0])
        #expect(mirror.kindLabel == "kind " + NocturneGardenKind.allCases[supplied[0]].name)
        for press in 1...supplied.count {
            mirror.pickKind(1)
            let kind: Int = supplied[press % supplied.count]
            #expect(mirror.kind == kind, "kind increment \(press)")
            #expect(mirror.kindLabel == "kind " + NocturneGardenKind.allCases[kind].name)
        }
        // Column and row: clamped to the bed.
        mirror.stepColumn(-1)
        #expect(mirror.column == 0)
        mirror.stepColumn(1)
        #expect(mirror.column == min(1, level.width - 1))
        #expect(mirror.columnLabel == "column \(mirror.column)")
        mirror.stepRow(1)
        #expect(mirror.row == min(1, level.height - 1))
        #expect(mirror.rowLabel == "row \(mirror.row)")
        // Size: clamped to the level's sizes.
        let sizes: [Int] = level.sizes.sorted()
        #expect(mirror.size == sizes[0])
        mirror.stepSize(1)
        #expect(mirror.size == sizes[min(1, sizes.count - 1)])
        #expect(mirror.sizeLabel == "size \(mirror.size)")
        mirror.stepSize(-1)
        #expect(mirror.size == sizes[0])
        // Sun: clamped to the allowed elevations.
        let elevations: [Int] = level.elevations.sorted()
        #expect(mirror.sunPick == opening.play.elevation)
        mirror.stepSun(1)
        let at: Int = elevations.firstIndex(of: opening.play.elevation) ?? 0
        #expect(mirror.sunPick == elevations[min(at + 1, elevations.count - 1)])
        #expect(mirror.sunPickLabel == "picked " + NocturneGardenLevel.sunName(mirror.sunPick))
        mirror.stepSun(-1)
        // Bloom: nothing to pick on an empty bed.
        mirror.pickBloom(1)
        #expect(mirror.bloom == 0)
        #expect(presenter.feedbackLog.count == logBase, "picks are not announced")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        #expect(try Access.core(shell) == opening, "a pick changes no state")

        // After the first certified plant the bloom picker names the bloom and the summary follows the core.
        let prefix: [NocturneGardenAction] = try NocturneGardenTest.firstPlant(1)
        for action in prefix {
            let issued = NocturneGardenTest.control(action)
            try Access.accepted(shell, recorder, issued.control, issued.values)
        }
        let planted: Core = try Access.core(shell)
        try #require(!planted.play.blooms.isEmpty)
        #expect(mirror.bloomNames.count == planted.play.blooms.count)
        let named: String = mirror.bloomNames[mirror.bloom]
        #expect(mirror.bloomLabel == named.prefix(1).uppercased() + named.dropFirst())
        #expect(mirror.bloomLabel.hasPrefix("Bloom 1: "), "\(mirror.bloomLabel)")
        #expect(mirror.bloomLabel.lowercased().hasPrefix("bloom \(mirror.bloom + 1): "), "\(mirror.bloomLabel)")
        let pickedBefore: Int = mirror.bloom
        mirror.pickBloom(1)
        #expect(mirror.bloom == (pickedBefore + 1) % planted.play.blooms.count, "the bloom picker wraps")
        #expect(mirror.summary == Plan.summaryText(core: planted))
        #expect(!mirror.summary.contains("Blooms: none."), "\(mirror.summary)")

        // The Sound toggle (kept off screen, so nothing plays).
        presenter.controlsDisappeared()
        #expect(mirror.soundOn == false, "the sound is off by default")
        presenter.setSound(on: true)
        #expect(mirror.soundOn)
        presenter.setSound(on: false)
        #expect(!mirror.soundOn)
        #expect(presenter.sound.playersMade == 0)
    }

    // MARK: Sound (FR-R02G0906-006; SC-R02G0906-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; each input turning off stops a playing loop; a `play()` that fails changes nothing else; the recipe is
    /// rebuilt only for a new recipe or the toggle turning on, never for the same recipe offered again.
    @Test func soundStateTable() throws {
        let empty: AmbientLoopRecipe = NocturneGardenSoundRecipe.recipe(blooms: 0, sun: 1, stage: .playing)
        let one: AmbientLoopRecipe = NocturneGardenSoundRecipe.recipe(blooms: 1, sun: 1, stage: .playing)
        let won: AmbientLoopRecipe = NocturneGardenSoundRecipe.recipe(blooms: 1, sun: 1, stage: .won)
        try #require(empty != one, "another bloom count sounds different")
        try #require(one != won, "a won play sounds different")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: NocturneGardenA11yLoopFactory = NocturneGardenA11yLoopFactory()
            let sound: NocturneGardenSound = factory.sound(empty)
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
        let toggles: NocturneGardenA11yLoopFactory = NocturneGardenA11yLoopFactory()
        let live: NocturneGardenSound = toggles.sound(empty)
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
        let failing: NocturneGardenA11yLoopFactory = NocturneGardenA11yLoopFactory()
        failing.succeeds = false
        let broken: NocturneGardenSound = failing.sound(empty)
        broken.setOnScreen(true)
        broken.setWanted(true)
        #expect(broken.playersMade == 1)
        #expect(!broken.started)
        #expect(broken.wanted)
        #expect(broken.onScreen)
        #expect(broken.active)
        #expect(broken.shouldPlay)
        #expect(broken.recipe == empty)
        #expect(failing.made.first?.plays == 1)
        #expect(failing.made.first?.isPlaying == false)
        #expect(failing.made.first?.stops == 0)

        // The sound off: offers make no player but are kept.
        let silent: NocturneGardenA11yLoopFactory = NocturneGardenA11yLoopFactory()
        let off: NocturneGardenSound = silent.sound(empty)
        off.setOnScreen(true)
        off.offer(one)
        off.offer(won)
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)
        #expect(off.recipe == won, "kept for the next start")

        // Rebuilds only at the named moments.
        let factory: NocturneGardenA11yLoopFactory = NocturneGardenA11yLoopFactory()
        let sound: NocturneGardenSound = factory.sound(empty)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(empty) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(one)
        #expect(sound.playersMade == 2, "a change of the bloom count makes a new player")
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
        sound.offer(empty)
        #expect(sound.playersMade == 3, "an offer while off makes no player")
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "the toggle turning on plays the latest recipe")
        #expect(sound.playerRecipe == empty)
        #expect(factory.recipes == [empty, one, won, empty])
        sound.setWanted(false)
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "toggling with the same recipe keeps the player")
        #expect(sound.started)
    }

    /// The presenter's own sound (real `AmbientLoopPlayer`; never started here) follows the described core: picks, a
    /// refusal and the dismissal keep its recipe, the first plant offers the new one. With the sound on but the
    /// controls off screen, or the scene inactive, the presenter makes no player.
    @Test func thePresenterOffersTheGardensRecipe() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        presenter.controlsDisappeared()
        #expect(!presenter.sound.onScreen)
        #expect(!presenter.sound.wanted)
        let opening: Core = try Access.core(shell)
        let openingRecipe: AmbientLoopRecipe = Presenter.recipe(opening)
        #expect(presenter.sound.recipe == openingRecipe, "the first state offers its recipe")

        // Drawn frames, picks, a refusal and the dismissal: the recipe stays.
        try NocturneGardenTest.draw(session, frames: 2)
        presenter.mirror.pickKind(1)
        presenter.mirror.stepColumn(1)
        let refusal: ActionResult = presenter.send("level.select", [5], port: shell.port)
        #expect(!refusal.isAccepted)
        let dismissal: ActionResult = presenter.send("tutorial.dismiss", [], port: shell.port)
        #expect(dismissal == .accepted, "\(dismissal.code)")
        #expect(presenter.sound.recipe == openingRecipe)

        // The first certified plant changes the bloom count and offers the core's recipe.
        for action in try NocturneGardenTest.firstPlant(1) {
            let issued = NocturneGardenTest.control(action)
            let result: ActionResult = presenter.send(issued.control, issued.values, port: shell.port)
            #expect(result == .accepted, "\(issued.control) \(issued.values): \(result.code)")
        }
        let planted: Core = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(planted), "the plant offers the core's recipe")
        #expect(presenter.sound.recipe != openingRecipe, "a plant changes the recipe")

        // On while off screen, then inactive and on screen: the presenter's sound never makes a player.
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
        presenter.sceneActive(true)
        #expect(!presenter.sound.shouldPlay)
        #expect(presenter.sound.playersMade == 0, "no player was made")
    }

    // MARK: Reduce Motion (FR-R02G0906-004)

    /// Under Reduce Motion two stills of the same planted state at different frame times are byte-identical, the
    /// drawn snapshot keeps time 0 and equals the core's snapshot at time 0, and the lights rest.
    @Test func reduceMotionStillsIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: Access.seed, reduceMotion: true)
        Access.quiet(shell)
        let accepted: Int = try NocturneGardenTest.advance(shell)
        #expect(accepted >= 1)
        // Two first stills let any light fade finish (0.5 s apart, beyond the 0.15 s fade).
        _ = try NocturneGardenTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0)
        _ = try NocturneGardenTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0.5)
        let first: [UInt8] = try NocturneGardenTest.still(session, width: Access.stillWidth,
                                                          height: Access.stillHeight, time: 0.75)
        let firstDrawn: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let second: [UInt8] = try NocturneGardenTest.still(session, width: Access.stillWidth,
                                                           height: Access.stillHeight, time: 1.9)
        let secondDrawn: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(NocturneGardenTest.nonGroundPixels(first) > 0, "the still shows the garden")
        #expect(first == second, "Reduce Motion: stills at 0.75 s and 1.9 s are identical")
        #expect(firstDrawn.time == 0)
        #expect(secondDrawn.time == 0)
        #expect(firstDrawn == secondDrawn)
        #expect(shell.presenter.lights.isSettled, "the lights rest")
        let core: Core = try Access.core(shell)
        #expect(secondDrawn == core.snapshot(time: 0))
    }
}
#endif
