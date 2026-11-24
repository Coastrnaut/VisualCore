// AcousticConstellatorAccessibilityTests — feature 426 (R02-G13-06) T-R02G1306-005 (FR-R02G1306-001 … 006)
// (SC-R02G1306-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Harmonic Bridges's feature-416 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; the presenter's own
// `feedbackLog` holds every routed plan.
// Values: every value the panel reads (`AcousticConstellatorControls.values(_:)`, read field by field by reflection,
// the static two-state values, the chosen star and partner in words, the missing pairs, the summary, the status and the
// labels) is non-empty words after level 1 is described; the summary element equals
// `AcousticConstellatorFeedbackPlan.summaryText(core:star:partner:)` and follows the adjustable star and partner after
// `refreshSummary()`. The adjustable star and partner (`stepStar(±1)`, `stepPartner(±1)`) step through the level's stars
// within their bounds and are never announced.
// Level 1 (seed 0) is won with the panel's accessibility operations alone: the adjustable star and partner choose each
// certified link (and the star of a nudge), Link, Nudge and Listen are sent through `presenter.send`; every accepted
// step routes exactly `AcousticConstellatorFeedbackPlan.after(old:new:)` of the cores captured before and after it, and
// the last one is the win outcome with a success haptic. A scripted sequence (a locked `level.next`, a nudge, an undo, a
// failing listen, a link refused after the failure, Retry, the certified win and `level.next` to level 2) records
// exactly the plans' announcements and haptics in order. Reduce Motion and Reduce Flashing: two stills of the same
// arranged state at different frame times are byte-identical once the fades settle; under Reduce Flashing the scene
// holds the stars at rest (tick 0, no pulse) and the level-0 glow mesh of the drawn snapshot has no wave shell (the same
// play's snapshot with motion has some, so the check is not vacuous). Sound: the state table (wanted × on screen ×
// active → shouldPlay, a player made only when wanted, an audition only while the loop may play) uses an
// `AcousticConstellatorSound` with an injected recording loop and voice; the presenter's own toggle is driven off
// screen (no player made). A link inspection (a tap on a link) with the sound on, under Reduce Motion, plays
// `AcousticConstellatorAudition.of(snapshot, link:, tick: 0)`; that one test turns the presenter's sound on screen, so
// it makes the shared ambient loop and one-shot players (ambient session, no input). In fallback mode
// (`breakConstellationShader()`) under Reduce Flashing a win brightens the unlit fallback over 0.45 s of frame time
// (`scene.fallbackWon` below 1 and rising at 0.1 … 0.4 s, 1 at 0.5 s). Synthetic data, explicit types, plain loops, no
// nested closure literals, no wall-clock assertion; each test short.
#if os(iOS)
import AcousticConstellatorCore
import CoreGraphics
import Foundation
import Testing
@testable import AcousticConstellatorExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class AcousticConstellatorA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class AcousticConstellatorA11yLoop: AcousticConstellatorLoopPlaying {
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

/// An audition voice that records what it was asked to play (no audio).
@MainActor
final class AcousticConstellatorA11yVoice: AcousticConstellatorAuditionPlaying {
    /// Every audition played, oldest first.
    private(set) var played: [AcousticConstellatorAudition] = []
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0

    /// A silent recording voice.
    init() {}

    /// Records `audition`; true when it has partials.
    @discardableResult
    func play(_ audition: AcousticConstellatorAudition) -> Bool {
        played.append(audition)
        return !audition.partials.isEmpty
    }

    /// Records a stop.
    func stop() { stops += 1 }
}

/// Makes fake loops and voices and keeps them.
@MainActor
final class AcousticConstellatorA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [AcousticConstellatorA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []
    /// Every voice made, oldest first.
    private(set) var voices: [AcousticConstellatorA11yVoice] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> AcousticConstellatorA11yLoop {
        let loop: AcousticConstellatorA11yLoop = AcousticConstellatorA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// Makes and keeps one fake voice.
    func makeVoice() -> AcousticConstellatorA11yVoice {
        let voice: AcousticConstellatorA11yVoice = AcousticConstellatorA11yVoice()
        voices.append(voice)
        return voice
    }

    /// A sound policy starting from `recipe` that makes its players and its voice here.
    func sound(_ recipe: AmbientLoopRecipe) -> AcousticConstellatorSound {
        AcousticConstellatorSound(recipe: recipe, makePlayer: { next in self.make(next) },
                                  makeVoice: { self.makeVoice() })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum AcousticConstellatorA11y {
    typealias Shell = ExperienceShell<AcousticConstellatorPresenter>
    typealias Plan = AcousticConstellatorFeedbackPlan
    typealias Core = AcousticConstellatorExperienceCore
    typealias Presenter = AcousticConstellatorPresenter
    typealias Snapshot = AcousticConstellatorSceneSnapshot

    /// A recording route on a presenter.
    struct Recorder {
        /// The haptics played, in order.
        let haptics: RecordingHapticSink
        /// The announcements posted, in order.
        let announcements: RecordingAnnouncementSink
        /// The clock of the route.
        let clock: AcousticConstellatorA11yClock
    }

    /// The still size of the Reduce Motion and Reduce Flashing tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await AcousticConstellatorTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                                   reduceFlashing: reduceFlashing,
                                                                   size: CGSize(width: 360, height: 240))
        _ = shell.presenter.describe(try core(shell))
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: AcousticConstellatorA11yClock = AcousticConstellatorA11yClock()
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
        try AcousticConstellatorTest.core(shell)
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

    /// The String fields of `value` (a struct of words), in declaration order, read by reflection so the test does not
    /// depend on the field names.
    static func strings(of value: Any) -> [String] {
        var result: [String] = []
        for child in Swift.Mirror(reflecting: value).children {
            if let text = child.value as? String { result.append(text) }
        }
        return result
    }

    /// Chooses `star` and `partner` in the panel with the adjustable star and partner operations only (`stepStar(±1)`
    /// first, then `stepPartner(±1)`), each followed by `refreshSummary()` as the panel's increment and decrement do.
    /// Returns the presses made.
    static func choose(_ presenter: Presenter, star: Int, partner: Int) -> Int {
        let mirror: AcousticConstellatorMirror = presenter.mirror
        var presses: Int = 0
        for _ in 0..<64 {
            if mirror.star < star {
                mirror.stepStar(1)
            } else if mirror.star > star {
                mirror.stepStar(-1)
            } else if mirror.partner < partner {
                mirror.stepPartner(1)
            } else if mirror.partner > partner {
                mirror.stepPartner(-1)
            } else {
                break
            }
            presenter.refreshSummary()
            presses += 1
        }
        return presses
    }

    /// The panel's control and values for the kernel action `action`, after choosing its stars with the adjustable
    /// star and partner (`choose`): Link and Unlink send the chosen pair, Nudge − or + the chosen star with −1 or +1,
    /// Listen nothing. Returns nil for a nudge step the panel cannot send (only ±1).
    static func panel(_ action: AcousticConstellatorAction,
                      _ presenter: Presenter) -> (control: String, values: [Double])? {
        let mirror: AcousticConstellatorMirror = presenter.mirror
        switch action {
        case let .link(a, b):
            _ = choose(presenter, star: a, partner: b)
            return ("link.add", [Double(mirror.star), Double(mirror.partner)])
        case let .unlink(a, b):
            _ = choose(presenter, star: a, partner: b)
            return ("link.remove", [Double(mirror.star), Double(mirror.partner)])
        case let .nudge(star, step):
            guard step == 1 || step == -1 else { return nil }
            _ = choose(presenter, star: star, partner: mirror.partner)
            return ("star.nudge", [Double(mirror.star), Double(step)])
        case .listen:
            return ("constellation.listen", [])
        }
    }

    /// Sends the accepted `control` with `values` through the presenter one clock second later, describes the new core
    /// and expects exactly one routed plan equal to `after(old:new:)` of the cores before and after, posted to the
    /// sinks. Returns the plan.
    @discardableResult
    static func accepted(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: Presenter = shell.presenter
        let old: Core = try core(shell)
        let logBefore: Int = presenter.feedbackLog.count
        recorder.clock.advance()
        let result: ActionResult = presenter.send(control, values, port: shell.port)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        let new: Core = try core(shell)
        _ = presenter.describe(new)
        let plan: Plan = Plan.after(old: old, new: new)
        #expect(plan.text != nil, "\(control) is announced", sourceLocation: sourceLocation)
        #expect(presenter.feedbackLog.count == logBefore + 1, "\(control) routes one plan",
                sourceLocation: sourceLocation)
        #expect(presenter.feedbackLog.last == plan, sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        if let haptic = plan.haptic {
            #expect(recorder.haptics.played.last == haptic, sourceLocation: sourceLocation)
        }
        let routed: Int = presenter.feedbackLog.count
        _ = presenter.describe(new)
        #expect(presenter.feedbackLog.count == routed, "describing the same state again routes nothing",
                sourceLocation: sourceLocation)
        #expect(presenter.mirror.summary == Plan.summaryText(core: new, star: presenter.mirror.star,
                                                             partner: presenter.mirror.partner),
                sourceLocation: sourceLocation)
        return plan
    }

    /// Sends the refused `control` with `values` through the presenter, one clock second later; expects a refusal,
    /// an unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), its words in the panel and the
    /// code in `refusalLog`. Returns the plan.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: Presenter = shell.presenter
        let digest: String = try AcousticConstellatorTest.digest(shell)
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
        #expect(presenter.mirror.message == plan.text, "the panel shows the same words",
                sourceLocation: sourceLocation)
        #expect(presenter.refusalLog.last == result.code, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        #expect(try AcousticConstellatorTest.digest(shell) == digest, "a refusal changes nothing",
                sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// The vertices of `mesh` (a glow mesh) whose glow kind is a wave shell.
    static func waveShellVertices(_ mesh: Mesh) -> Int {
        var count: Int = 0
        for uv in mesh.uvs where AcousticConstellatorGlowKind.decode(uv.x).kind == .waveShell { count += 1 }
        return count
    }

    /// The first snapshot of `core` at presentation times 0 … 8 s (0.05 s apart) whose level-0 glow mesh with motion
    /// has wave shells; nil when none.
    static func snapshotWithWaveShells(_ core: Core) throws -> Snapshot? {
        let tier: AcousticConstellatorTier = AcousticConstellatorTier.of(0)
        for step in 0...160 {
            let snapshot: Snapshot = core.snapshot(time: Double(step) * 0.05)
            let moving: Mesh = try AcousticConstellatorSceneGeometry.glowMesh(snapshot, tier: tier, reduceMotion: false)
            if waveShellVertices(moving) > 0 { return snapshot }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct AcousticConstellatorAccessibilityTests {
    typealias Access = AcousticConstellatorA11y
    typealias Plan = AcousticConstellatorFeedbackPlan
    typealias Presenter = AcousticConstellatorPresenter
    typealias Core = AcousticConstellatorExperienceCore
    typealias Snapshot = AcousticConstellatorSceneSnapshot
    typealias Script = AcousticConstellatorGestureScript

    // MARK: Values and the summary element (FR-R02G1306-001, 005; clarification Q5)

    /// After level 1 is described every value the panel reads is non-empty words; the two-state values differ; the
    /// summary element equals `summaryText(core:star:partner:)`; describing routes nothing.
    @Test func everyControlHasALabelAndAValueInWords() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: AcousticConstellatorMirror = presenter.mirror
        let values: [String] = Access.strings(of: AcousticConstellatorControls.values(mirror))
        #expect(values.count == 7, "the button values: \(values)")
        let all: [String] = values + [mirror.starLabel, mirror.partnerLabel, mirror.starDetail, mirror.partnerWords,
                                      mirror.choiceLabel, mirror.missingLabel, mirror.summary, mirror.status,
                                      mirror.measureLabel, mirror.targetLabel, mirror.goalLabel,
                                      AcousticConstellatorControls.hintValue(mirror.hintLevel),
                                      AcousticConstellatorControls.soundValue(mirror.soundOn)]
        var index: Int = 0
        for value in all {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "value \(index) is empty")
            index += 1
        }

        // The two-state values read in words and differ.
        let pairs: [(String, String)] = [
            (AcousticConstellatorControls.viewValue(true), AcousticConstellatorControls.viewValue(false)),
            (AcousticConstellatorControls.selectedValue(true), AcousticConstellatorControls.selectedValue(false)),
            (AcousticConstellatorControls.soundValue(true), AcousticConstellatorControls.soundValue(false)),
            (AcousticConstellatorControls.hintValue(0), AcousticConstellatorControls.hintValue(2)),
        ]
        for pair in pairs {
            #expect(!pair.0.isEmpty && !pair.1.isEmpty && pair.0 != pair.1, "\(pair.0) / \(pair.1)")
        }
        #expect(AcousticConstellatorControls.hintValue(2) == "level 2 of 3")
        #expect(AcousticConstellatorControls.modeName(.campaign) == "campaign")
        #expect(AcousticConstellatorControls.modeName(.practice) == "practice")
        #expect(AcousticConstellatorControls.modeName(.replay(level: 3)) == "replay")
        #expect(AcousticConstellatorControls.readableWidth == 520)

        // The buttons' values follow the mirror.
        let buttons: AcousticConstellatorControls.Values = AcousticConstellatorControls.values(mirror)
        #expect(buttons.pair == mirror.choiceLabel)
        #expect(buttons.nudge == mirror.starDetail)
        #expect(buttons.listen == mirror.missingLabel)
        #expect(buttons.actions == "0 actions made of \(core.play.level.budget)", "\(buttons.actions)")
        #expect(buttons.retry == "level 1, campaign")
        #expect(buttons.playLevel == "level 1")

        // The chosen star and partner read as the level words them.
        let play: AcousticConstellatorPlay = core.play
        #expect(mirror.star == 0 && mirror.partner == 1, "a level opens with star 0 and partner 1 chosen")
        #expect(mirror.starDetail == play.level.starName(0, phase: play.phases[0]), "\(mirror.starDetail)")

        // The summary element (clarification Q5).
        #expect(mirror.summary == Plan.summaryText(core: core, star: mirror.star, partner: mirror.partner),
                "\(mirror.summary)")
        #expect(mirror.summary.contains("Level: " + Plan.levelWords(core) + "."), "\(mirror.summary)")
        #expect(mirror.soundOn == false, "the Sound toggle is off by default")
        #expect(presenter.feedbackLog.isEmpty, "describing the opening plans nothing")
    }

    /// The adjustable star and partner step through the level's stars (clamped to 0 … count − 1); their values read
    /// the star as the level words it, the partner with whether the pair is linked; the summary follows after
    /// `refreshSummary()`; nothing is announced.
    @Test func adjustableStarAndPartnerStepThroughTheStars() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: AcousticConstellatorMirror = presenter.mirror
        let play: AcousticConstellatorPlay = core.play
        let count: Int = play.level.stars.count
        try #require(count >= 3, "level 1 has at least three stars")

        mirror.stepStar(-1)
        #expect(mirror.star == 0, "the star does not go below 0")
        for target in 1..<count {
            mirror.stepStar(1)
            presenter.refreshSummary()
            #expect(mirror.star == target)
            #expect(mirror.starDetail == play.level.starName(target, phase: play.phases[target]),
                    "\(mirror.starDetail)")
            #expect(mirror.summary == Plan.summaryText(core: core, star: target, partner: mirror.partner),
                    "\(mirror.summary)")
        }
        mirror.stepStar(1)
        #expect(mirror.star == count - 1, "the star does not go past the last")
        for _ in 0..<(count + 2) { mirror.stepStar(-1) }
        #expect(mirror.star == 0)

        // The partner: down to 0, then up through every star.
        for _ in 0..<(count + 2) { mirror.stepPartner(-1) }
        #expect(mirror.partner == 0, "the partner does not go below 0")
        for target in 0..<count {
            if target > 0 { mirror.stepPartner(1) }
            presenter.refreshSummary()
            #expect(mirror.partner == target)
            var words: String = play.level.starName(target, phase: play.phases[target])
            if target != mirror.star {
                let linked: Bool = play.links.contains(AcousticConstellatorLink.between(mirror.star, target))
                words += linked ? ", linked" : ", not linked"
            }
            #expect(mirror.partnerWords == words, "\(mirror.partnerWords)")
            #expect(mirror.summary == Plan.summaryText(core: core, star: mirror.star, partner: target),
                    "\(mirror.summary)")
        }
        mirror.stepPartner(1)
        #expect(mirror.partner == count - 1, "the partner does not go past the last")
        #expect(presenter.feedbackLog.isEmpty, "adjusting the star and partner plans nothing")
    }

    // MARK: The panel alone (SC-R02G1306-001, 002)

    /// Level 1 (seed 0) is won with the panel's accessibility operations alone: the adjustable star and partner choose
    /// each certified link and nudged star (never announced, no haptic), Link, Nudge and Listen are sent through the
    /// presenter; every accepted step routes exactly `after(old:new:)`; the sinks hold the plans' words and haptics in
    /// order; the last is the win outcome with a success haptic.
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
        let actions: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedActions(1)
        try #require(!actions.isEmpty, "level 1 has a certified solution")
        try #require(actions.last == .listen, "the certified solution ends with a listen")
        var expected: [Plan] = []
        var sent: Int = 0

        for action in actions {
            guard try Access.core(shell).play.stage == .playing else { break }
            let logBefore: Int = presenter.feedbackLog.count
            let announcedBefore: Int = recorder.announcements.announced.count
            let playedBefore: Int = recorder.haptics.played.count
            let entry: (control: String, values: [Double])? = Access.panel(action, presenter)
            let issued: (control: String, values: [Double]) = try #require(entry, "the panel can send \(action)")
            #expect(presenter.feedbackLog.count == logBefore, "choosing plans nothing")
            #expect(recorder.announcements.announced.count == announcedBefore, "choosing is not announced")
            #expect(recorder.haptics.played.count == playedBefore, "choosing plays no haptic")
            let plan: Plan = try Access.accepted(shell, recorder, issued.control, issued.values)
            expected.append(plan)
            sent += 1
            let now: Core = try Access.core(shell)
            if now.play.stage != .won {
                #expect(plan.kind == .state)
                #expect(plan.haptic == .selection)
                if case let .link(a, b) = action {
                    let link: AcousticConstellatorLink = AcousticConstellatorLink.between(a, b)
                    #expect(plan.text?.hasPrefix("Linked star \(link.a) to star \(link.b)") == true,
                            "\(plan.text ?? "nil")")
                }
            }
        }
        #expect(sent == actions.count, "every certified action was sent")

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        let spent: Int = AcousticConstellatorProgress.actionsSpent(won.play)
        let stars: Int = AcousticConstellatorProgress.stars(actionsSpent: spent, certified: won.certifiedActions)
        #expect(stars == 3, "the certified solution earns 3 stars")
        let spentWords: String = spent == 1 ? "1 action" : "\(spent) actions"
        let winText: String = Plan.wonText + " Level won spending " + spentWords + ", " + String(stars)
            + " of 3 stars."
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.message == nil)
    }

    // MARK: Recorded feedback of a scripted sequence (FR-R02G1306-002, 003; clarifications Q1, Q2)

    /// A scripted sequence on level 1 — a locked `level.next`, Nudge +, Undo, a failing Listen, a Link refused after
    /// the failure, Retry, the certified win and `level.next` — records exactly the plans' announcements and haptics in
    /// order: rejections with an error haptic, states with a selection haptic, the failure with a warning, the win
    /// with a success and the level changes without a haptic.
    @Test func recordedFeedbackEqualsThePlans() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        var expected: [Plan] = []

        // A refusal: the next level is not open before a win.
        let locked: Plan = try Access.refused(shell, recorder, "level.next", [])
        #expect(locked.text == "That level is not open yet.", "\(locked.text ?? "nil")")
        expected.append(locked)

        // Nudge + of the chosen star, then Undo.
        let star: Int = presenter.mirror.star
        let nudged: Plan = try Access.accepted(shell, recorder, "star.nudge", [Double(star), 1])
        #expect(nudged.kind == .state && nudged.haptic == .selection)
        #expect(nudged.text?.hasPrefix("Star \(star) nudged to phase ") == true, "\(nudged.text ?? "nil")")
        expected.append(nudged)
        let undone: Plan = try Access.accepted(shell, recorder, "play.undo", [])
        #expect(undone.text?.hasPrefix("Undone. ") == true, "\(undone.text ?? "nil")")
        #expect(undone.haptic == .selection)
        expected.append(undone)

        // A failure: a listen before the symbol is linked.
        let failed: Plan = try Access.accepted(shell, recorder, "constellation.listen", [])
        let failedCore: Core = try Access.core(shell)
        #expect(failedCore.play.stage == .failed, "a listen before the symbol is linked fails")
        #expect(failed.kind == .outcome)
        #expect(failed.haptic == .warning)
        #expect(failed.text == AcousticConstellatorFailureExplanation(play: failedCore.play)?.text,
                "\(failed.text ?? "nil")")
        expected.append(failed)

        // A refusal after the failure: the level has ended.
        let ended: Plan = try Access.refused(shell, recorder, "link.add", [0, 1])
        #expect(ended.text == "The level has ended.", "\(ended.text ?? "nil")")
        expected.append(ended)

        // Retry starts the level again: a level change, no haptic.
        let beforeRetry: Core = try Access.core(shell)
        let logBefore: Int = presenter.feedbackLog.count
        recorder.clock.advance()
        let retried: ActionResult = presenter.retry(port: shell.port)
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: Core = try Access.core(shell)
        _ = presenter.describe(fresh)
        let retryPlan: Plan = Plan.after(old: beforeRetry, new: fresh)
        #expect(retryPlan.kind == .level)
        #expect(retryPlan.haptic == nil)
        #expect(retryPlan.text?.hasPrefix("Level 1, band 1, campaign.") == true, "\(retryPlan.text ?? "nil")")
        #expect(presenter.feedbackLog.count == logBefore + 1)
        #expect(presenter.feedbackLog.last == retryPlan)
        expected.append(retryPlan)

        // The certified win through the panel's operations.
        for action in try AcousticConstellatorTest.certifiedActions(1) {
            let entry: (control: String, values: [Double])? = Access.panel(action, presenter)
            let issued: (control: String, values: [Double]) = try #require(entry)
            expected.append(try Access.accepted(shell, recorder, issued.control, issued.values))
        }
        #expect(try Access.core(shell).play.stage == .won)
        #expect(expected.last?.haptic == .success)

        // The next level: a level change.
        let next: Plan = try Access.accepted(shell, recorder, "level.next", [])
        #expect(try Access.core(shell).levelNumber == 2)
        #expect(next.kind == .level)
        #expect(next.haptic == nil)
        #expect(next.text?.hasPrefix("Level 2, band 1, campaign.") == true, "\(next.text ?? "nil")")
        expected.append(next)

        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(recorder.announcements.announced == Access.texts(expected), "\(recorder.announcements.announced)")
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
        var kinds: [AnnouncementKind] = []
        for plan in plans { if let kind = plan.kind { kinds.append(kind) } }
        #expect(kinds.contains(.rejection) && kinds.contains(.state) && kinds.contains(.outcome)
                && kinds.contains(.level), "\(kinds)")
    }

    // MARK: Reduce Motion and Reduce Flashing stills (FR-R02G1306-004; SC-R02G1306-003)

    /// Under Reduce Motion two stills of the same arranged state at different frame times (across several shown
    /// ticks) are byte-identical once the fades settle.
    @Test func reduceMotionStillsAreIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: AcousticConstellatorTest.seeds[0], reduceMotion: true)
        Access.quiet(shell)
        let scene: AcousticConstellatorConstellationScene = shell.presenter.scene
        #expect(scene.reduceMotion)
        #expect(scene.starsAtRest)
        #expect(try AcousticConstellatorTest.arrange(shell))
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        // Two first stills let any light fade finish (0.5 s apart, beyond the 0.15 s fade).
        _ = try AcousticConstellatorTest.still(session, width: w, height: h, time: 0)
        _ = try AcousticConstellatorTest.still(session, width: w, height: h, time: 0.5)
        let first: [UInt8] = try AcousticConstellatorTest.still(session, width: w, height: h, time: 0.75)
        let second: [UInt8] = try AcousticConstellatorTest.still(session, width: w, height: h, time: 1.9)
        #expect(AcousticConstellatorTest.nonSkyPixels(first) > 0, "the still shows the constellation")
        #expect(first == second, "Reduce Motion: stills at 0.75 s and 1.9 s are identical")
        #expect(shell.presenter.lights.isSettled, "the lights rest")
    }

    /// Under Reduce Flashing the scene holds the stars at rest (tick 0, no pulse), the level-0 glow mesh of the drawn
    /// snapshot has no wave shell (the same play's snapshot with motion has some), and two stills at different times
    /// are byte-identical once the fades settle.
    @Test func reduceFlashingDrawsNoWaveShellAndStillsAreIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: AcousticConstellatorTest.seeds[0], reduceFlashing: true)
        Access.quiet(shell)
        let scene: AcousticConstellatorConstellationScene = shell.presenter.scene
        #expect(scene.reducedFlash)
        #expect(!scene.reduceMotion)
        #expect(scene.starsAtRest, "Reduce Flashing draws the stars at rest")
        #expect(session.qualityPin == 0, "level-0, the tier with wave shells")
        #expect(try AcousticConstellatorTest.arrange(shell))
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        let base: Double = 10
        _ = try AcousticConstellatorTest.still(session, width: w, height: h, time: base)
        _ = try AcousticConstellatorTest.still(session, width: w, height: h, time: base + 0.5)
        let early: [UInt8] = try AcousticConstellatorTest.still(session, width: w, height: h, time: base + 0.75)
        let late: [UInt8] = try AcousticConstellatorTest.still(session, width: w, height: h, time: base + 1.9)
        #expect(AcousticConstellatorTest.nonSkyPixels(early) > 0, "the still shows the constellation")
        #expect(early == late, "Reduce Flashing: stills at 0.75 s and 1.9 s are identical")
        #expect(shell.presenter.lights.isSettled, "the lights rest")

        // The scene's facts on the drawn snapshot: tick 0, no pulse, no wave shell at level-0.
        let tier: AcousticConstellatorTier = AcousticConstellatorTier.of(0)
        let snapshot: Snapshot = try #require(shell.presenter.lastSnapshot)
        #expect(scene.drawnTick(snapshot, animate: true) == 0, "the stars are drawn at tick 0")
        #expect(scene.pulse(for: tier, animate: true) == 0, "the stars do not pulse")
        let drawn: Mesh = try AcousticConstellatorSceneGeometry.glowMesh(snapshot, tier: tier,
                                                                         reduceMotion: scene.starsAtRest)
        #expect(Access.waveShellVertices(drawn) == 0, "Reduce Flashing: no wave shell vertex")
        let arranged: Core = try Access.core(shell)
        let moving: Snapshot = try #require(try Access.snapshotWithWaveShells(arranged),
                                            "the arranged play shows wave shells with motion (not vacuous)")
        let held: Mesh = try AcousticConstellatorSceneGeometry.glowMesh(moving, tier: tier,
                                                                        reduceMotion: scene.starsAtRest)
        #expect(Access.waveShellVertices(held) == 0, "the same snapshot under Reduce Flashing has no wave shell")
        #expect(scene.drawnTick(moving, animate: true) == 0)
    }

    // MARK: Lights under Reduce Flashing in fallback mode (FR-R02G1306-004; SC-R02G1306-003)

    /// In fallback mode under Reduce Flashing the won look of the unlit fallback rises over 0.45 s of frame time after
    /// the winning listen: below 1 (and rising) at 0.1 … 0.4 s, 1 at 0.5 s; the scene's `fallbackWon` follows the
    /// presenter's lights.
    @Test func fallbackWonBrightensSlowlyUnderReduceFlashing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 0, reduceFlashing: true,
                                                            size: CGSize(width: 360, height: 240),
                                                            configure: { presenter in
                                                                presenter.breakConstellationShader()
                                                            })
        Access.quiet(shell)
        let presenter: Presenter = shell.presenter
        #expect(presenter.fallbackReason != nil, "the broken program falls back")
        let arrangement: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedArrangement(1)
        #expect(AcousticConstellatorTest.issue(shell, arrangement) == arrangement.count)
        try #require(try Access.core(shell).play.stage == .playing, "only the listen wins")
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        let base: Double = 10
        _ = try AcousticConstellatorTest.still(session, width: w, height: h, time: base - 1)
        _ = try AcousticConstellatorTest.still(session, width: w, height: h, time: base)
        #expect(presenter.lights.won == 0, "the won light rests at 0 while playing")
        #expect(presenter.scene.fallbackWon == 0)

        let winning: ActionResult = shell.handle(control: "constellation.listen", values: [])
        #expect(winning == .accepted, "\(winning.code)")
        #expect(try Access.core(shell).play.stage == .won)

        let rising: [Double] = [0.1, 0.2, 0.3, 0.4]
        var previous: Double = 0
        for offset in rising {
            _ = try AcousticConstellatorTest.still(session, width: w, height: h, time: base + offset)
            let level: Double = try #require(presenter.scene.fallbackWon, "the fallback draws the presenter's lights")
            #expect(level > previous, "the fallback's won look rises at \(offset) s: \(level)")
            #expect(level < 1, "the fallback's won look is below 1 at \(offset) s: \(level)")
            #expect(level == presenter.lights.won, "the scene draws the presenter's lights")
            previous = level
        }
        let last: [UInt8] = try AcousticConstellatorTest.still(session, width: w, height: h, time: base + 0.5)
        #expect(presenter.scene.fallbackWon == 1, "the won look reaches 1 after 0.45 s")
        #expect(presenter.lights.isSettled)
        #expect(AcousticConstellatorTest.nonSkyPixels(last) > 0, "the fallback still shows the constellation")
        #expect(presenter.fallbackReason != nil)
    }

    // MARK: Sound (FR-R02G1306-006; SC-R02G1306-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations, and an audition plays only
    /// then; the sound off makes no player and no voice; each input turning off stops a playing loop and a sounding
    /// audition; a new player is made only for a different recipe or the toggle turning on. The presenter's toggle,
    /// driven off screen, makes no player.
    @Test func soundStateTable() throws {
        typealias Recipe = AcousticConstellatorSoundRecipe
        let calm: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 0, stage: .playing)
        let lit: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .playing)
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .won)
        try #require(calm != lit, "another lit quarter sounds different")
        try #require(lit != won, "a won play sounds different")
        let opening: Core = try Core.opening(number: 1)
        let sample: AcousticConstellatorAudition = AcousticConstellatorAudition.of(opening.snapshot(time: 0),
                                                                                   link: .between(0, 1), tick: 0)
        try #require(sample.partials.count == 2, "a link's audition has two tones")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: AcousticConstellatorA11yLoopFactory = AcousticConstellatorA11yLoopFactory()
            let sound: AcousticConstellatorSound = factory.sound(calm)
            sound.setOnScreen(onScreen)
            sound.setActive(active)
            sound.setWanted(wanted)
            let expected: Bool = wanted && onScreen && active
            #expect(sound.shouldPlay == expected, "combination \(combination)")
            #expect(sound.started == expected, "combination \(combination)")
            #expect(sound.playersMade == (expected ? 1 : 0), "combination \(combination)")
            let playing: Bool = factory.made.last?.isPlaying ?? false
            #expect(playing == expected, "combination \(combination)")
            let auditioned: Bool = sound.audition(sample)
            #expect(auditioned == expected, "combination \(combination)")
            #expect(sound.auditionsPlayed == (expected ? 1 : 0), "combination \(combination)")
            #expect(factory.voices.count == (expected ? 1 : 0), "a voice only when it may sound (\(combination))")
            if !wanted {
                #expect(factory.made.isEmpty, "sound off makes no player (combination \(combination))")
                #expect(sound.player == nil)
                #expect(sound.voice == nil)
            }
        }

        // Each input turning off stops a playing loop and the audition; turning back on plays the same player again.
        let toggles: AcousticConstellatorA11yLoopFactory = AcousticConstellatorA11yLoopFactory()
        let live: AcousticConstellatorSound = toggles.sound(calm)
        #expect(!live.wanted, "the sound is off by default")
        #expect(live.active, "the scene starts active")
        live.setOnScreen(true)
        live.setWanted(true)
        #expect(live.started)
        #expect(live.audition(sample))
        #expect(live.lastAudition == sample)
        live.setActive(false)
        #expect(!live.started, "an inactive scene stops the loop")
        #expect(toggles.made.first?.isPlaying == false)
        #expect(toggles.voices.first?.stops == 1, "an inactive scene stops the audition")
        #expect(!live.audition(sample), "no audition while inactive")
        live.setActive(true)
        live.setOnScreen(false)
        #expect(!live.started, "controls off screen stop the loop")
        #expect(toggles.voices.first?.stops == 2)
        live.setOnScreen(true)
        live.setWanted(false)
        #expect(!live.started, "the sound off stops the loop")
        #expect(toggles.voices.first?.stops == 3)
        live.setWanted(true)
        #expect(live.started)
        #expect(live.playersMade == 1, "the same recipe keeps its player")
        #expect(live.auditionsPlayed == 1)
        #expect(!live.audition(AcousticConstellatorAudition(partials: [])), "silence plays nothing")
        #expect(live.auditionsPlayed == 1)

        // A failing play() changes nothing else.
        let failing: AcousticConstellatorA11yLoopFactory = AcousticConstellatorA11yLoopFactory()
        failing.succeeds = false
        let silent: AcousticConstellatorSound = failing.sound(calm)
        silent.setOnScreen(true)
        silent.setWanted(true)
        #expect(!silent.started, "a failed play() is not started")
        #expect(silent.shouldPlay)

        // Rebuilds only when the recipe differs.
        let factory: AcousticConstellatorA11yLoopFactory = AcousticConstellatorA11yLoopFactory()
        let sound: AcousticConstellatorSound = factory.sound(calm)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(calm) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(lit)
        #expect(sound.playersMade == 2, "a change of the lit quarters makes a new player")
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
        #expect(factory.recipes == [calm, lit, won, calm])

        // The presenter's toggle with the controls off screen: no player is made, so no audio is touched.
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        _ = presenter.describe(opening)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")
        #expect(Presenter.recipe(opening) == Recipe.recipe(play: opening.play))
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
        #expect(presenter.sound.player == nil, "the sound off never touches audio")
        #expect(presenter.sound.voice == nil)
    }

    /// Under Reduce Motion a tap on a link with the sound off describes it at tick 0 and plays nothing; with the sound
    /// on, on screen and active it plays `AcousticConstellatorAudition.of(snapshot, link:, tick: 0)` of the drawn
    /// snapshot. (This test makes the presenter's real loop and one-shot players.)
    @Test func linkInspectionPlaysItsAuditionUnderReduceMotion() async throws {
        let number: Int = try Script.level("a fixed link") { (core: Core, snapshot: Snapshot) -> Bool in
            Script.fixedLinkPoint(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: UInt64(number - 1), reduceMotion: true,
                                                            size: CGSize(width: Script.viewWidth,
                                                                         height: Script.viewHeight))
        Access.quiet(shell)
        let presenter: Presenter = shell.presenter
        _ = presenter.describe(try Access.core(shell))
        let snapshot: Snapshot = try Script.drawn(shell)
        let fixed = try #require(Script.fixedLinkPoint(snapshot, orbit: presenter.gestures.orbit),
                                 "a fixed link picks inside the view")
        let link: AcousticConstellatorLink = snapshot.links[fixed.index]
        #expect(presenter.scene.drawnTick(snapshot, animate: true) == 0, "Reduce Motion draws tick 0")
        let expected: AcousticConstellatorAudition = AcousticConstellatorAudition.of(snapshot, link: link, tick: 0)
        #expect(expected.partials.count == 2)
        let logBase: Int = presenter.feedbackLog.count
        var time: Double = Script.clock()

        // The sound off: described, nothing played, no voice made.
        Script.tap(shell, id: 1, at: fixed.point, time: &time)
        let text: String = Presenter.linkText(link.a, link.b, snapshot: snapshot, tick: 0)
        #expect(presenter.mirror.message == text, "the link is described at tick 0")
        #expect(text.hasSuffix(" at tick 0, fixed."), "\(text)")
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off plays no audition")
        #expect(presenter.sound.voice == nil)

        // The sound on, on screen and active: the inspection plays the link's audition at tick 0.
        presenter.setSound(on: true)
        presenter.controlsAppeared()
        presenter.sceneActive(true)
        #expect(presenter.sound.shouldPlay)
        time += 1
        Script.tap(shell, id: 2, at: fixed.point, time: &time)
        #expect(presenter.sound.auditionsPlayed == 1, "one inspection, one audition")
        #expect(presenter.sound.lastAudition == expected, "the audition of the link at tick 0")
        #expect(presenter.mirror.star == link.a && presenter.mirror.partner == link.b, "the tap chooses the pair")
        #expect(presenter.feedbackLog.count == logBase, "an inspection is not announced")

        // The sound off again: a further inspection plays nothing.
        presenter.setSound(on: false)
        presenter.controlsDisappeared()
        time += 1
        Script.tap(shell, id: 3, at: fixed.point, time: &time)
        #expect(presenter.sound.auditionsPlayed == 1, "no audition once the sound is off")
        #expect(!presenter.sound.shouldPlay)
    }
}
#endif
