// FacetedForgeAccessibilityTests — feature 376 (R02-G08-06) T-R02G0806-005 (FR-R02G0806-001 … 006;
// SC-R02G0806-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Amethyst Escape's feature-366 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running. On level 1 (seed 0,
// budget 9, target 4 pieces, tutorial `aim`) a cut, its undo and redo, a plane that misses its piece
// (`r02-g08.miss`), a locked level (`level.select [5]`, `r02-g08.locked`), the tutorial's dismissal (nothing planned)
// and `level.select [1]` (a `level` plan without haptic) record exactly `FacetedForgeFeedbackPlan.after(old:new:)` and
// `refused(code:)` in the sinks and in the presenter's feedback log (the texts are also written out from clarification
// Q1); a second description of the same state routes nothing; the panel shows the refusal's words (`refusalText`).
// Level 1 is won with the panel's accessibility operations alone: the adjustable piece, direction and depth pickers
// (`pickPiece(±1)`, `pickDirection(±1)`, `stepDepth(±1)`, never announced) line up each certified cut
// (`FacetedForgeExperienceCore.certifiedActions(1)`) and Cut sends `piece.cut` with the mirror's choice; every cut is
// announced and the winning cut routes only the outcome ("The pieces match the target. Level won with …"), with a
// success haptic. A sliver failure (level 77, seed 2_376, the first cut x at −5) routes only the outcome, the failure
// explanation, with a warning haptic. The summary element's words equal `summaryText(core:choice:)`. Reduce Motion: two
// stills of the same state at different frame times are byte-identical and the drawn snapshot keeps time 0. Reduce
// Flashing: after the winning cut the presenter's cut-face glow, sampled over stills 1/60 s apart, fades from 0.7 to 1
// over at least 0.4 s (0.45 s), while without it the fade ends within 0.15 s. Sound: the presenter makes its own
// `FacetedForgeSound` with the real `AmbientLoopPlayer`, so the state table (wanted × on screen × active) and the
// offers use a `FacetedForgeSound` with an injected recording player; the presenter's own sound is only driven off
// screen (no audio starts) and its recipe follows the described core: a cut that changes the piece count offers a new
// recipe, and a player fed those recipes is rebuilt only then. Synthetic data, explicit types, plain loops, no nested
// closure literals, no sleep, no wall-clock assertion; few frames, each test short.
#if os(iOS)
import CoreGraphics
import FacetedForgeCore
import Foundation
import Testing
@testable import FacetedForgeExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class FacetedForgeA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class FacetedForgeA11yLoop: FacetedForgeLoopPlaying {
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
final class FacetedForgeA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [FacetedForgeA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> FacetedForgeA11yLoop {
        let loop: FacetedForgeA11yLoop = FacetedForgeA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> FacetedForgeSound {
        FacetedForgeSound(recipe: recipe, makePlayer: { next in self.make(next) })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum FacetedForgeA11y {
    typealias Shell = ExperienceShell<FacetedForgePresenter>
    typealias Plan = FacetedForgeFeedbackPlan
    typealias Core = FacetedForgeExperienceCore

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: FacetedForgeA11yClock
    }

    /// The seed of level 77 (band 4, no tutorial; budget 15, sliver limit 1/64), the level of the plan tests.
    static let sliverSeed: UInt64 = 2_376
    /// The still size of the Reduce Motion and Reduce Flashing tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64
    /// The frame rate of the sampled stills.
    static let frameRate: Double = 60
    /// The shared advice that ends every failure explanation (feature 375), written out.
    static let advice: String = "Undo the last cut or retry the level."

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await FacetedForgeTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                           reduceFlashing: reduceFlashing,
                                                           size: CGSize(width: 360, height: 240))
        let opening: Core = try FacetedForgeTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: FacetedForgeA11yClock = FacetedForgeA11yClock()
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
        try FacetedForgeTest.core(shell)
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
    static func log(_ presenter: FacetedForgePresenter, after count: Int) -> [Plan] {
        Array(presenter.feedbackLog.dropFirst(count))
    }

    /// "1 cut left" or "c cuts left", written out here.
    static func leftText(_ count: Int) -> String { count == 1 ? "1 cut left" : "\(count) cuts left" }

    /// The cut announcement of clarification Q1, written out here: "Piece p cut in direction x at depth d: n pieces
    /// now. c cuts left."
    static func cutText(piece: Int, direction: Int, depth: Int, pieces: Int, left: Int) -> String {
        "Piece \(piece + 1) cut in direction \(FacetedForgeDirection.all[direction].name) at depth \(depth): "
            + "\(pieces) pieces now. \(leftText(left))."
    }

    /// Sends the accepted `control` with `values` through the presenter as the panel does, one clock second later;
    /// expects the feedback log to grow by exactly the plan of the change (nothing for `.none`), the panel to show no
    /// refusal, the summary element to read `summaryText(core:choice:)` and a second description of the same state to
    /// route nothing. Returns the plan.
    @discardableResult
    static func accepted(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double] = [],
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: FacetedForgePresenter = shell.presenter
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
        #expect(presenter.mirror.summary == Plan.summaryText(core: new, choice: presenter.mirror.choice),
                "\(presenter.mirror.summary)", sourceLocation: sourceLocation)
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
        let presenter: FacetedForgePresenter = shell.presenter
        let digest: String = try FacetedForgeTest.digest(shell)
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
        let after: String = try FacetedForgeTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// The piece, direction and depth of the cut `action`.
    static func parts(_ action: FacetedForgeAction) -> (piece: Int, direction: Int, depth: Int) {
        switch action {
        case .cut(let piece, let direction, let depth): (piece, direction, depth)
        }
    }

    /// Lines the panel's choice up with `piece`, `direction` and `depth` using only the adjustable pickers'
    /// operations (`pickPiece(1)`, `pickDirection(1)`, `stepDepth(±1)`), which route nothing and play no haptic.
    /// Returns the presses made.
    static func lineUp(_ shell: Shell, _ recorder: Recorder, piece: Int, direction: Int, depth: Int,
                       sourceLocation: SourceLocation = #_sourceLocation) -> Int {
        let mirror: FacetedForgeMirror = shell.presenter.mirror
        let logBefore: Int = shell.presenter.feedbackLog.count
        let announcedBefore: Int = recorder.announcements.announced.count
        let playedBefore: Int = recorder.haptics.played.count
        var presses: Int = 0
        let pieces: Int = mirror.pieceNames.count
        for _ in 0..<max(pieces, 1) where mirror.choice.piece != piece {
            mirror.pickPiece(1)
            presses += 1
        }
        for _ in 0..<FacetedForgeDirection.all.count where mirror.choice.direction != direction {
            mirror.pickDirection(1)
            presses += 1
        }
        let span: Int = FacetedForgeHalfSpace.depths.count
        for _ in 0..<span {
            let now: Int = mirror.choice.depth
            if now == depth { break }
            mirror.stepDepth(now < depth ? 1 : -1)
            presses += 1
            if mirror.choice.depth == now { break }   // no crossing depth further that way
        }
        #expect(mirror.choice.piece == piece, "the piece picker reached piece \(piece + 1)",
                sourceLocation: sourceLocation)
        #expect(mirror.choice.direction == direction, "the direction picker reached \(direction)",
                sourceLocation: sourceLocation)
        #expect(mirror.choice.depth == depth, "the depth picker reached \(depth)", sourceLocation: sourceLocation)
        #expect(!mirror.misses, sourceLocation: sourceLocation)
        #expect(shell.presenter.feedbackLog.count == logBefore, "a choice change plans nothing",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.count == announcedBefore, "a choice change is not announced",
                sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore, "a choice change plays no haptic",
                sourceLocation: sourceLocation)
        return presses
    }

    /// The presenter's cut-face glow on level `seed % 100 + 1` around the winning cut of its certified solution:
    /// the cuts before it sent, a still at time 0, the winning cut sent, then `frames` stills 1/60 s apart. Returns
    /// the glow after each still, the one at time 0 first.
    static func winGlow(seed: UInt64, reduceFlashing: Bool, frames: Int) async throws -> [Double] {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Shell = try await open(session, seed: seed, reduceFlashing: reduceFlashing)
        quiet(shell)
        let presenter: FacetedForgePresenter = shell.presenter
        #expect(presenter.lights.reducedFlash == reduceFlashing)
        let number: Int = try core(shell).levelNumber
        let actions: [FacetedForgeAction] = Core.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number) has a certified solution")
        for index in 0..<(actions.count - 1) {
            let result: ActionResult = FacetedForgeTeaching.send(actions[index], shell)
            #expect(result == .accepted, "cut \(index + 1): \(result.code)")
        }
        var samples: [Double] = []
        _ = try FacetedForgeTest.still(session, width: stillWidth, height: stillHeight, time: 0)
        samples.append(presenter.lights.glow)
        let last: FacetedForgeAction = try #require(actions.last)
        let result: ActionResult = FacetedForgeTeaching.send(last, shell)
        #expect(result == .accepted, "the winning cut: \(result.code)")
        #expect(try core(shell).play.stage == .won)
        for frame in 1...frames {
            let time: Double = Double(frame) / frameRate
            _ = try FacetedForgeTest.still(session, width: stillWidth, height: stillHeight, time: time)
            samples.append(presenter.lights.glow)
        }
        return samples
    }
}

@MainActor
@Suite(.serialized) struct FacetedForgeAccessibilityTests {
    typealias Access = FacetedForgeA11y
    typealias Plan = FacetedForgeFeedbackPlan
    typealias Presenter = FacetedForgePresenter
    typealias Core = FacetedForgeExperienceCore
    typealias Lights = FacetedForgeLights

    // MARK: Recorded feedback (FR-R02G0806-002, 003; SC-R02G0806-002)

    /// A cut, undo, redo, a missing plane, a locked level, the tutorial's dismissal and `level.select [1]` on level 1:
    /// the sinks receive exactly the plans of `FacetedForgeFeedbackPlan`, in order, and the feedback log holds the same
    /// plans; the texts written out; haptics per clarification Q2 (selection, error, none for the level change); the
    /// panel shows each refusal's words.
    @Test func recordedFeedbackThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .aim)
        #expect(opening.play.stage == .playing)
        #expect(opening.play.level.budget == 9)
        var expected: [Plan] = []

        func state(_ plan: Plan, _ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(plan.text == text, "\(plan.text ?? "nil")", sourceLocation: sourceLocation)
            #expect(plan.kind == .state, sourceLocation: sourceLocation)
            #expect(plan.haptic == .selection, sourceLocation: sourceLocation)
            expected.append(plan)
        }

        state(try Access.accepted(shell, recorder, "piece.cut", [0, 0, 0]),
              "Piece 1 cut in direction x at depth 0: 2 pieces now. 8 cuts left.")
        state(try Access.accepted(shell, recorder, "play.undo"), "Undone. 1 piece. 9 cuts left.")
        state(try Access.accepted(shell, recorder, "play.redo"), "Redone. 2 pieces. 8 cuts left.")

        // A plane that misses its piece, and a level that is not open yet.
        let miss: Plan = try Access.refused(shell, recorder, "piece.cut", [0, 0, 20], code: "r02-g08.miss")
        #expect(miss.text == "That plane misses the piece.", "\(miss.text ?? "nil")")
        expected.append(miss)
        let locked: Plan = try Access.refused(shell, recorder, "level.select", [5], code: "r02-g08.locked")
        #expect(locked.text == "That level is not open yet.", "\(locked.text ?? "nil")")
        expected.append(locked)

        // The dismissal plans nothing; the level reopened is a `level` plan with the tutorial and no haptic.
        let dismissed: Plan = try Access.accepted(shell, recorder, "tutorial.dismiss")
        #expect(dismissed == Plan.none, "the dismissal is not announced")
        let reopened: Plan = try Access.accepted(shell, recorder, "level.select", [1])
        let aim: String = FacetedForgeTutorialStep.aim.text
        #expect(reopened.text == "Level 1, band 1, campaign. " + aim, "\(reopened.text ?? "nil")")
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
        #expect(presenter.mirror.summary == Plan.summaryText(core: now, choice: presenter.mirror.choice))
    }

    // MARK: The panel alone (SC-R02G0806-001)

    /// Level 1 (seed 0) is won with the panel's accessibility operations alone: the piece, direction and depth
    /// pickers line up each certified cut (never announced) and Cut sends `piece.cut` with the mirror's choice; every
    /// cut is announced with its written-out text and a selection haptic; the winning cut routes only the outcome, with
    /// a success haptic.
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
        let budget: Int = opening.play.level.budget
        let actions: [FacetedForgeAction] = Core.certifiedActions(1)
        try #require(actions.count >= 2, "level 1 needs more than one cut")
        var presses: Int = 0
        var winRouted: Int = -1

        for (index, action) in actions.enumerated() {
            let stage: FacetedForgeStage = try Access.core(shell).play.stage
            guard stage == .playing else { break }
            let cut: (piece: Int, direction: Int, depth: Int) = Access.parts(action)
            let piece: Int = cut.piece
            let direction: Int = cut.direction
            let depth: Int = cut.depth
            presses += Access.lineUp(shell, recorder, piece: piece, direction: direction, depth: depth)
            // Cut sends the mirror's choice, as the panel's button does.
            let choice: FacetedForgePreviewChoice = presenter.mirror.choice
            let values: [Double] = [Double(choice.piece), Double(choice.direction), Double(choice.depth)]
            let old: Core = try Access.core(shell)
            let before: Int = presenter.feedbackLog.count
            recorder.clock.advance()
            let result: ActionResult = presenter.send("piece.cut", values, port: shell.port)
            #expect(result == .accepted, "cut \(index + 1): \(result.code)")
            let new: Core = try Access.core(shell)
            let plan: Plan = Plan.after(old: old, new: new)
            #expect(plan.text != nil, "cut \(index + 1) is announced")
            #expect(presenter.feedbackLog.count == before + 1, "cut \(index + 1) routes one plan")
            #expect(presenter.feedbackLog.last == plan)
            #expect(recorder.announcements.announced.last == plan.text)
            #expect(presenter.mirror.summary == Plan.summaryText(core: new, choice: presenter.mirror.choice))
            if new.play.stage == .won {
                winRouted = presenter.feedbackLog.count - before
            } else {
                let text: String = Access.cutText(piece: piece, direction: direction, depth: depth,
                                                  pieces: new.play.pieces.count, left: budget - (index + 1))
                #expect(plan.text == text, "\(plan.text ?? "nil")")
                #expect(plan.kind == .state)
                #expect(plan.haptic == .selection)
                #expect(recorder.haptics.played.last == .selection)
            }
        }
        #expect(presses > 0, "the pickers were used")

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(winRouted == 1, "the winning cut routes only the outcome")
        let made: Int = FacetedForgeProgress.cutsMade(won.play)
        #expect(made == actions.count)
        let stars: Int = FacetedForgeProgress.stars(cutsMade: made, smallest: won.certifiedSmallest)
        #expect(stars == 3)
        let winText: String = "The pieces match the target. Level won with \(made) cuts made, 3 of 3 stars."
        let plans: [Plan] = Access.log(presenter, after: logBase)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced.last == winText)
        #expect(plans.count == actions.count, "every cut announced, no pick")
        #expect(recorder.announcements.announced == Access.texts(plans))
        #expect(recorder.haptics.played == Access.haptics(plans), "\(recorder.haptics.played)")
        #expect(recorder.haptics.played.last == .success)
        #expect(presenter.mirror.status == "Won")
    }

    // MARK: Failure (clarification Q2)

    /// A sliver failure on level 77 (the first cut in direction x at depth −5) routes only the outcome: the failure
    /// explanation, kind `outcome`, a warning haptic; the panel explains it; the undo is a `state` plan.
    @Test func aSliverFailurePlansOnlyTheOutcome() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: Access.sliverSeed)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 77)
        #expect(opening.tutorial == .done)
        #expect(opening.play.level.budget == 15)

        let fall: Plan = try Access.accepted(shell, recorder, "piece.cut", [0, 0, -5])
        let failed: Core = try Access.core(shell)
        #expect(failed.play.stage == .failed)
        let explanation: FacetedForgeFailureExplanation = try #require(failed.failureExplanation)
        let written: String = "Cut 1 left piece 2 at 1/432 of the crystal, thinner than the sliver limit of 1/64. "
            + Access.advice
        #expect(fall.text == explanation.text, "\(fall.text ?? "nil")")
        #expect(fall.text == written, "\(fall.text ?? "nil")")
        #expect(fall.kind == .outcome)
        #expect(fall.haptic == .warning)
        #expect(presenter.mirror.failureText == written)
        #expect(Access.log(presenter, after: logBase) == [fall], "only the outcome is planned")
        #expect(recorder.haptics.played == [HapticKind.warning])
        #expect(recorder.announcements.announced == [written])

        let undo: Plan = try Access.accepted(shell, recorder, "play.undo")
        #expect(undo.text == "Undone. 1 piece. 15 cuts left.", "\(undo.text ?? "nil")")
        #expect(undo.haptic == .selection)
        #expect(try Access.core(shell).play.stage == .playing)
        #expect(recorder.haptics.played == [HapticKind.warning, HapticKind.selection])
    }

    // MARK: Pickers, labels and the summary (FR-R02G0806-001, 005; clarification Q5)

    /// The adjustable pickers' values ("direction x", "depth d", "the plane misses this piece"), wrapping over the 13
    /// directions, never announced; the summary element's words at the opening of level 1, written out in part, and
    /// after a cut equal `summaryText(core:choice:)`; the Sound toggle's choice.
    @Test func pickersAndSummary() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: FacetedForgeMirror = presenter.mirror
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        let choice: FacetedForgePreviewChoice = mirror.choice
        #expect(choice == FacetedForgePreviewChoice.initial(opening.play))
        #expect(choice.direction == FacetedForgePreviewChoice.facingDirection)
        #expect(mirror.summary == Plan.summaryText(core: opening, choice: choice))
        #expect(mirror.summary.hasPrefix("9 cuts left. 1 piece: the whole crystal. Target: "), "\(mirror.summary)")
        #expect(mirror.summary.hasSuffix(". Next cut: piece 1, direction z, depth \(choice.depth)."),
                "\(mirror.summary)")
        #expect(mirror.directionLabel == "direction z")
        #expect(mirror.depthLabel == "depth \(choice.depth)")

        // The direction picker wraps over the 13 directions; each change moves the depth to a crossing one.
        let count: Int = FacetedForgeDirection.all.count
        for press in 1...count {
            mirror.pickDirection(1)
            let direction: Int = (choice.direction + press) % count
            #expect(mirror.choice.direction == direction, "increment \(press)")
            #expect(mirror.directionLabel == "direction " + FacetedForgeDirection.all[direction].name)
            #expect(!mirror.misses, "the middle crossing depth crosses the piece")
        }
        mirror.pickDirection(-1)
        #expect(mirror.choice.direction == (choice.direction + count - 1) % count, "a decrement wraps")
        mirror.pickDirection(1)
        // One piece: the piece picker stays on it.
        mirror.pickPiece(1)
        #expect(mirror.choice.piece == 0)
        mirror.stepDepth(1)
        #expect(mirror.depthLabel == "depth \(mirror.choice.depth)")
        // A plane that misses its piece names it.
        mirror.choice = FacetedForgePreviewChoice(piece: 0, direction: 0, depth: 20)
        #expect(mirror.misses)
        #expect(mirror.depthLabel == "the plane misses this piece")
        #expect(presenter.feedbackLog.count == logBase, "picks are not announced")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        #expect(try Access.core(shell) == opening, "a pick changes no state")

        // After a cut the summary follows the new core and the clamped choice.
        mirror.choice = choice
        try Access.accepted(shell, recorder, "piece.cut", [0, 0, 0])
        let cut: Core = try Access.core(shell)
        #expect(mirror.summary == Plan.summaryText(core: cut, choice: mirror.choice))
        #expect(mirror.summary.hasPrefix("8 cuts left. 2 pieces: "), "\(mirror.summary)")

        // The Sound toggle (kept off screen, so nothing plays).
        presenter.controlsDisappeared()
        #expect(mirror.soundOn == false, "the sound is off by default")
        presenter.setSound(on: true)
        #expect(mirror.soundOn)
        presenter.setSound(on: false)
        #expect(!mirror.soundOn)
        #expect(presenter.sound.playersMade == 0)
    }

    // MARK: Sound (FR-R02G0806-006; SC-R02G0806-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; each input turning off stops a playing loop; a `play()` that fails changes nothing else; the recipe is
    /// rebuilt only for a new recipe or the toggle turning on, never for the same recipe offered again.
    @Test func soundStateTable() throws {
        let whole: AmbientLoopRecipe = FacetedForgeSoundRecipe.recipe(pieces: 1, target: 4, stage: .playing)
        let halves: AmbientLoopRecipe = FacetedForgeSoundRecipe.recipe(pieces: 2, target: 4, stage: .playing)
        let won: AmbientLoopRecipe = FacetedForgeSoundRecipe.recipe(pieces: 4, target: 4, stage: .won)
        try #require(whole != halves, "another piece count sounds different")
        try #require(halves != won, "a won play sounds different")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: FacetedForgeA11yLoopFactory = FacetedForgeA11yLoopFactory()
            let sound: FacetedForgeSound = factory.sound(whole)
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
        let toggles: FacetedForgeA11yLoopFactory = FacetedForgeA11yLoopFactory()
        let live: FacetedForgeSound = toggles.sound(whole)
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
        let failing: FacetedForgeA11yLoopFactory = FacetedForgeA11yLoopFactory()
        failing.succeeds = false
        let broken: FacetedForgeSound = failing.sound(whole)
        broken.setOnScreen(true)
        broken.setWanted(true)
        #expect(broken.playersMade == 1)
        #expect(!broken.started)
        #expect(broken.wanted)
        #expect(broken.onScreen)
        #expect(broken.active)
        #expect(broken.shouldPlay)
        #expect(broken.recipe == whole)
        #expect(failing.made.first?.plays == 1)
        #expect(failing.made.first?.isPlaying == false)
        #expect(failing.made.first?.stops == 0)

        // The sound off: offers make no player but are kept.
        let silent: FacetedForgeA11yLoopFactory = FacetedForgeA11yLoopFactory()
        let off: FacetedForgeSound = silent.sound(whole)
        off.setOnScreen(true)
        off.offer(halves)
        off.offer(won)
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)
        #expect(off.recipe == won, "kept for the next start")

        // Rebuilds only at the named moments.
        let factory: FacetedForgeA11yLoopFactory = FacetedForgeA11yLoopFactory()
        let sound: FacetedForgeSound = factory.sound(whole)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(whole) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(halves)
        #expect(sound.playersMade == 2, "a change of the piece count makes a new player")
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
        sound.offer(whole)
        #expect(sound.playersMade == 3, "an offer while off makes no player")
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "the toggle turning on plays the latest recipe")
        #expect(sound.playerRecipe == whole)
        #expect(factory.recipes == [whole, halves, won, whole])
        sound.setWanted(false)
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "toggling with the same recipe keeps the player")
        #expect(sound.started)
    }

    /// The presenter's own sound (real `AmbientLoopPlayer`; never started here) follows the described core: picks, a
    /// refusal and the dismissal keep its recipe, a cut that changes the piece count offers the new one; a recording
    /// sound fed the presenter's recipe after every step (playing: wanted, on screen, active) makes a new player only
    /// at those cuts. With the sound on but the controls off screen, or the scene inactive, the presenter makes none.
    @Test func aCutThatChangesThePieceCountOffersANewRecipe() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        presenter.controlsDisappeared()
        #expect(!presenter.sound.onScreen)
        #expect(!presenter.sound.wanted)
        let opening: Core = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")

        let factory: FacetedForgeA11yLoopFactory = FacetedForgeA11yLoopFactory()
        let follower: FacetedForgeSound = factory.sound(presenter.sound.recipe)
        follower.setOnScreen(true)
        follower.setWanted(true)
        #expect(follower.playersMade == 1)

        // Drawn frames, picks, a refusal and the dismissal: the recipe stays, no new player.
        try FacetedForgeTest.draw(session, frames: 2)
        presenter.mirror.pickDirection(1)
        presenter.mirror.stepDepth(1)
        let refusal: ActionResult = presenter.send("level.select", [5], port: shell.port)
        #expect(!refusal.isAccepted)
        let dismissal: ActionResult = presenter.send("tutorial.dismiss", [], port: shell.port)
        #expect(dismissal == .accepted, "\(dismissal.code)")
        follower.offer(presenter.sound.recipe)
        #expect(presenter.sound.recipe == Presenter.recipe(opening))
        #expect(follower.playersMade == 1, "nothing but a new recipe makes a player")

        // Each certified cut of level 1 changes the piece count (up to the target's 4) and offers a new recipe.
        let actions: [FacetedForgeAction] = Core.certifiedActions(1)
        try #require(!actions.isEmpty)
        var expectedPlayers: Int = 1
        var previous: AmbientLoopRecipe = presenter.sound.recipe
        for (index, action) in actions.enumerated() {
            let before: Int = try Access.core(shell).play.pieces.count
            let result: ActionResult = FacetedForgeTeaching.send(action, shell)
            #expect(result == .accepted, "cut \(index + 1): \(result.code)")
            let now: Core = try Access.core(shell)
            #expect(now.play.pieces.count == before + 1, "a cut adds a piece")
            #expect(presenter.sound.recipe == Presenter.recipe(now), "cut \(index + 1) offers the core's recipe")
            #expect(presenter.sound.recipe != previous, "cut \(index + 1) changes the recipe")
            for _ in 0..<3 { follower.offer(presenter.sound.recipe) }
            expectedPlayers += 1
            #expect(follower.playersMade == expectedPlayers, "cut \(index + 1) makes exactly one new player")
            previous = presenter.sound.recipe
        }
        #expect(try Access.core(shell).play.stage == .won)
        #expect(factory.made.count == expectedPlayers)

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

    // MARK: Reduce Motion (FR-R02G0806-004)

    /// Under Reduce Motion two stills of the same cut state at different frame times are byte-identical and the drawn
    /// snapshot keeps time 0.
    @Test func reduceMotionStillsIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceMotion: true)
        Access.quiet(shell)
        let accepted: Int = try FacetedForgeTest.advance(shell)
        #expect(accepted == 1)
        // A first still lets any light fade finish (the next frame is 0.25 s later, beyond 0.15 s).
        _ = try FacetedForgeTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0)
        let first: [UInt8] = try FacetedForgeTest.still(session, width: Access.stillWidth,
                                                        height: Access.stillHeight, time: 0.25)
        let firstDrawn: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let second: [UInt8] = try FacetedForgeTest.still(session, width: Access.stillWidth,
                                                         height: Access.stillHeight, time: 1.3)
        let secondDrawn: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(FacetedForgeTest.nonGroundPixels(first) > 0, "the still shows the crystal")
        #expect(first == second, "Reduce Motion: stills at 0.25 s and 1.3 s are identical")
        #expect(firstDrawn.time == 0)
        #expect(secondDrawn.time == 0)
        #expect(firstDrawn == secondDrawn)
        let core: Core = try Access.core(shell)
        #expect(secondDrawn == core.snapshot(choice: shell.presenter.mirror.choice, time: 0))
    }

    // MARK: Reduce Flashing (FR-R02G0806-004; SC-R02G0806-003; clarification Q3)

    /// After the winning cut of level 2 the presenter's cut-face glow, sampled over stills 1/60 s apart, rises
    /// monotonically from 0.7 to 1 and the fade takes at least 0.4 s under Reduce Flashing (0.45 s); without it the
    /// same fade ends within 0.15 s (and a frame).
    @Test func reduceFlashingFadesTheWinGlowSlowly() async throws {
        let frames: Int = 36
        let slow: [Double] = try await Access.winGlow(seed: 1, reduceFlashing: true, frames: frames)
        let fast: [Double] = try await Access.winGlow(seed: 1, reduceFlashing: false, frames: frames)
        let tolerance: Double = 1e-9
        let runs: [(name: String, samples: [Double])] = [("reduced", slow), ("normal", fast)]
        for run in runs {
            let name: String = run.name
            let samples: [Double] = run.samples
            try #require(samples.count == frames + 1, "\(name)")
            #expect(abs(samples[0] - Lights.glowPlaying) < tolerance, "\(name): playing glow \(samples[0])")
            #expect(abs(samples[frames] - Lights.glowWon) < tolerance, "\(name): won glow \(samples[frames])")
            for index in 1..<samples.count {
                #expect(samples[index] >= samples[index - 1] - tolerance, "\(name): the glow only rises (\(index))")
            }
        }
        var slowEnd: Int = frames
        for index in 0..<slow.count where slow[index] >= Lights.glowWon - tolerance {
            slowEnd = index
            break
        }
        var fastEnd: Int = frames
        for index in 0..<fast.count where fast[index] >= Lights.glowWon - tolerance {
            fastEnd = index
            break
        }
        let slowSeconds: Double = Double(slowEnd) / Access.frameRate
        let fastSeconds: Double = Double(fastEnd) / Access.frameRate
        #expect(slowSeconds >= 0.4, "Reduce Flashing: the win glow fades over \(slowSeconds) s")
        #expect(slowSeconds <= Lights.reducedFlashDuration + 1 / Access.frameRate + tolerance, "\(slowSeconds) s")
        #expect(fastSeconds <= Lights.normalDuration + 1 / Access.frameRate + tolerance, "\(fastSeconds) s")
        #expect(slow[1] > slow[0], "the fade starts on the first frame after the win")
        #expect(slow[1] < Lights.glowWon - tolerance, "the fade does not jump")
    }
}
#endif
