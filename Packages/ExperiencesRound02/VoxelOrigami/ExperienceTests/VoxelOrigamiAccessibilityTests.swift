// VoxelOrigamiAccessibilityTests — feature 446 (R02-G15-06) T-R02G1506-005 (FR-R02G1506-001 … 006)
// (SC-R02G1506-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Moonlit Mechanism's feature-436 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; the presenter's own
// `feedbackLog` holds every routed plan. Every expected text is built from `VoxelOrigamiFeedbackPlan`
// (`after(old:new:)`, `refused(code:)`, `summaryText(core:hinge:)`) on the cores captured before and after each step.
// The shell describes the new core after every accepted action (the port's summary), so the mirror follows at once;
// describing the same core again routes nothing.
// Values: every value the panel reads from the mirror (the chosen hinge and its detail, the summary, the status, the
// progress, the level, the goal, the mode, the instruction) is non-empty words once level 1 is described; the summary
// element equals `summaryText(core:hinge:)`. The adjustable hinge (`hinge.choose [clampedHinge(hinge ± 1)]` through
// the presenter, what the panel's increment and decrement send) steps through the level's hinges 1 … cubes − 1 within
// their bounds, the summary follows, and it is never announced. Level 1 (seed 0) is won with the panel's operations
// alone: the adjustable hinge chooses each certified turn's hinge and Turn − / + is sent through `presenter.send`;
// every accepted turn routes exactly `after(old:new:)` and the last one is the win outcome with a success haptic.
// Refusals (`hinge.choose [0]`, a locked `level.next`) are announced as rejections in the plan's words with an error
// haptic. Reduce Motion and Reduce Flashing: two stills of the same state at different frame times are byte-identical
// once the fades settle. Under Reduce Flashing a win's glow and won levels rise over at least 0.4 s of frame time
// (sampled at 1/60 s), and in fallback mode (`breakVoxelShader()` before setup) the drawn won level brightens over at
// least 0.4 s. Sound: the state table (wanted × on screen × active → shouldPlay, a player made only when it plays, an
// audition only while the loop may play) uses a `VoxelOrigamiSound` with an injected recording loop and voice; the
// presenter's own toggle is driven off screen (no player made), a hinge choice plays no audition while the sound is off
// or cannot play, and the recipe is re-offered only at a level opening or a change of the recipe. One test turns the
// presenter's sound on screen, so it makes the shared ambient loop and one-shot players (ambient session, no input):
// choosing a hinge then plays `VoxelOrigamiAudition.of(play, hinge:)`. Synthetic data, explicit types, plain loops, no
// nested closure literals, no wall-clock assertion; each test short.
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
@testable import VoxelOrigamiExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI
import VoxelOrigamiCore

/// A clock the accessibility tests move by hand.
@MainActor
final class VoxelOrigamiA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class VoxelOrigamiA11yLoop: VoxelOrigamiLoopPlaying {
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
final class VoxelOrigamiA11yVoice: VoxelOrigamiAuditionPlaying {
    /// Every audition played, oldest first.
    private(set) var played: [VoxelOrigamiAudition] = []
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0

    /// A silent recording voice.
    init() {}

    /// Records `audition`; true when it has partials.
    @discardableResult
    func play(_ audition: VoxelOrigamiAudition) -> Bool {
        played.append(audition)
        return !audition.partials.isEmpty
    }

    /// Records a stop.
    func stop() { stops += 1 }
}

/// Makes fake loops and voices and keeps them.
@MainActor
final class VoxelOrigamiA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [VoxelOrigamiA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []
    /// Every voice made, oldest first.
    private(set) var voices: [VoxelOrigamiA11yVoice] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> VoxelOrigamiA11yLoop {
        let loop: VoxelOrigamiA11yLoop = VoxelOrigamiA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// Makes and keeps one fake voice.
    func makeVoice() -> VoxelOrigamiA11yVoice {
        let voice: VoxelOrigamiA11yVoice = VoxelOrigamiA11yVoice()
        voices.append(voice)
        return voice
    }

    /// A sound policy starting from `recipe` that makes its players and its voice here.
    func sound(_ recipe: AmbientLoopRecipe) -> VoxelOrigamiSound {
        VoxelOrigamiSound(recipe: recipe, makePlayer: { next in self.make(next) },
                          makeVoice: { self.makeVoice() })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum VoxelOrigamiA11y {
    typealias Shell = VoxelOrigamiTest.Shell
    typealias Plan = VoxelOrigamiFeedbackPlan
    typealias Core = VoxelOrigamiExperienceCore
    typealias Presenter = VoxelOrigamiPresenter

    /// A recording route on a presenter.
    struct Recorder {
        /// The haptics played, in order.
        let haptics: RecordingHapticSink
        /// The announcements posted, in order.
        let announcements: RecordingAnnouncementSink
        /// The clock of the route.
        let clock: VoxelOrigamiA11yClock
    }

    /// The still size of the Reduce Motion and Reduce Flashing tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await VoxelOrigamiTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                           reduceFlashing: reduceFlashing,
                                                           size: CGSize(width: 360, height: 240))
        _ = shell.presenter.describe(try core(shell))
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: VoxelOrigamiA11yClock = VoxelOrigamiA11yClock()
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
        try VoxelOrigamiTest.core(shell)
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

    /// Sends one press of the adjustable hinge through the presenter, exactly what the panel's increment (`up`) or
    /// decrement sends: `hinge.choose [clampedHinge(hinge ± 1)]`. Returns the result.
    @discardableResult
    static func adjust(_ shell: Shell, _ recorder: Recorder, up: Bool) -> ActionResult {
        let mirror: VoxelOrigamiMirror = shell.presenter.mirror
        let target: Int = mirror.clampedHinge(up ? mirror.hinge + 1 : mirror.hinge - 1)
        recorder.clock.advance()
        return shell.presenter.send("hinge.choose", [Double(target)], port: shell.port)
    }

    /// Chooses `hinge` with the adjustable hinge's operations only. Returns the presses made.
    @discardableResult
    static func choose(_ shell: Shell, _ recorder: Recorder, hinge: Int) -> Int {
        let mirror: VoxelOrigamiMirror = shell.presenter.mirror
        var presses: Int = 0
        for _ in 0..<16 {
            if mirror.hinge == hinge { break }
            let result: ActionResult = adjust(shell, recorder, up: mirror.hinge < hinge)
            #expect(result == .accepted, "hinge.choose: \(result.code)")
            presses += 1
        }
        return presses
    }

    /// Sends the accepted `control` with `values` through the presenter one clock second later (the shell describes the
    /// new core at once) and expects exactly one routed plan equal to `after(old:new:)` of the cores before and after,
    /// posted to the sinks. Returns the plan.
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
        #expect(presenter.mirror.summary == Plan.summaryText(core: new, hinge: new.chosenHinge),
                sourceLocation: sourceLocation)
        return plan
    }

    /// Sends the refused `control` with `values` through the presenter one clock second later; expects a refusal, an
    /// unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), its words in the panel and the
    /// bare code in `refusalLog`. Returns the plan.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: Presenter = shell.presenter
        let digest: String = try VoxelOrigamiTest.digest(shell)
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
        #expect(presenter.refusalLog.last == VoxelOrigamiMirror.bareCode(result.code),
                sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        #expect(try VoxelOrigamiTest.digest(shell) == digest, "a refusal changes nothing",
                sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// The win text of `core`'s won campaign play, built as the plan words it.
    static func winText(_ core: Core) -> String {
        let spent: Int = VoxelOrigamiProgress.actionsSpent(core.play)
        let stars: Int = VoxelOrigamiProgress.stars(actionsSpent: spent, certified: core.certifiedTurns)
        let spentWords: String = spent == 1 ? "1 action" : "\(spent) actions"
        return Plan.wonText + " Level won spending " + spentWords + ", " + String(stars) + " of 3 stars."
    }

    /// `core` with `hinge` chosen (`hinge.choose`, presentation only), applied on a copy.
    static func choosing(_ core: Core, hinge: Int) -> Core {
        var copy: Core = core
        let action: ExperienceAction = ExperienceAction(control: "hinge.choose", values: [Double(hinge)], step: 0)
        let result: ActionResult = copy.apply(action)
        #expect(result == .accepted, "hinge.choose \(hinge): \(result.code)")
        return copy
    }

    /// A hinge of `core` other than its chosen one (1 … cubes − 1).
    static func otherHinge(_ core: Core) -> Int {
        core.chosenHinge == 1 ? 2 : 1
    }
}

@MainActor
@Suite(.serialized) struct VoxelOrigamiAccessibilityTests {
    typealias Access = VoxelOrigamiA11y
    typealias Plan = VoxelOrigamiFeedbackPlan
    typealias Presenter = VoxelOrigamiPresenter
    typealias Core = VoxelOrigamiExperienceCore
    typealias Snapshot = VoxelOrigamiSceneSnapshot

    // MARK: Values and the summary element (FR-R02G1506-001, 005; clarification Q5)

    /// After level 1 is described every value the panel reads is non-empty words; the summary element equals
    /// `summaryText(core:hinge:)`; the chosen hinge's detail reads as the level words it; describing the opening routes
    /// nothing; the sound is off; refusals read in the plan's words.
    @Test func everyControlHasALabelAndAValueInWords() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: VoxelOrigamiMirror = presenter.mirror
        let instruction: String = mirror.instruction ?? ""
        let values: [String] = [mirror.hingeLabel, mirror.hingeDetail, mirror.summary, mirror.status,
                                mirror.measureLabel, mirror.targetLabel, mirror.goalLabel, instruction,
                                VoxelOrigamiControls.modeName(mirror.mode)]
        var index: Int = 0
        for value in values {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "value \(index) is empty")
            index += 1
        }
        #expect(VoxelOrigamiControls.modeName(.campaign) == "campaign")
        #expect(VoxelOrigamiControls.modeName(.practice) == "practice")
        #expect(VoxelOrigamiControls.readableWidth == 520)
        #expect(mirror.budget > 0, "Undo and Redo read the actions made of a positive budget")
        #expect(mirror.actionsLeft == mirror.budget, "no action made at the opening")
        #expect(mirror.frontier == 1, "Next level reads no further level open before a win")
        #expect(mirror.hintLevel == 0, "Hint reads none shown")

        // The chosen hinge reads as the level words it.
        let play: VoxelOrigamiPlay = core.play
        #expect(mirror.hinge == core.chosenHinge, "a level opens with its first turnable hinge chosen")
        #expect(mirror.hinge == Core.openingHinge(of: play))
        #expect(mirror.hingeLabel == "hinge \(mirror.hinge)")
        let name: String = play.level.hingeName(mirror.hinge, turn: play.turns[mirror.hinge])
        #expect(mirror.hingeDetail == name, "the opening hinge can turn: \(mirror.hingeDetail)")
        #expect(mirror.status == "Ready", "\(mirror.status)")

        // The summary element (clarification Q5).
        #expect(mirror.summary == Plan.summaryText(core: core, hinge: mirror.hinge), "\(mirror.summary)")
        #expect(mirror.summary.contains("Level: " + Plan.levelWords(core) + "."), "\(mirror.summary)")
        #expect(mirror.summary.contains("Chosen: " + Plan.hingeWords(play, mirror.hinge) + "."), "\(mirror.summary)")
        #expect(mirror.soundOn == false, "the Sound toggle is off by default")
        #expect(presenter.feedbackLog.isEmpty, "describing the opening plans nothing")

        // Refusals read in the plan's words (clarification Q1), with or without the engine's prefix.
        let prefixed: String = VoxelOrigamiMirror.refusalText(code: "action.rule.r02-g15.locked")
        #expect(prefixed == "That level is not open yet.")
        #expect(Plan.refused(code: "r02-g15.stage").text == "The level has ended.")
        #expect(Plan.refused(code: "r02-g15.hinge").text == "This chain has no such hinge.")
        #expect(Plan.refused(code: "action.out-of-range").text == "That action was refused.")
    }

    /// The adjustable hinge (`hinge.choose [clampedHinge(hinge ± 1)]` through the presenter) steps through the level's
    /// hinges 1 … cubes − 1, clamped at both ends; its value reads the hinge as the level words it; the summary follows;
    /// the digest stays; nothing is announced and, with the sound off, no audition plays.
    @Test func adjustableHingeStepsThroughTheHinges() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: VoxelOrigamiMirror = presenter.mirror
        let opening: Core = try Access.core(shell)
        let play: VoxelOrigamiPlay = opening.play
        let cubes: Int = play.level.cubes.count
        try #require(cubes >= 3, "level 1 has at least two hinges")
        #expect(mirror.cubeCount == cubes)
        let digest: String = try VoxelOrigamiTest.digest(shell)
        let logBase: Int = presenter.feedbackLog.count

        for _ in 0..<(cubes + 1) {
            #expect(Access.adjust(shell, recorder, up: false) == .accepted)
        }
        #expect(mirror.hinge == 1, "the hinge does not go below 1")
        #expect(try Access.core(shell).chosenHinge == 1)
        for target in 2..<cubes {
            #expect(Access.adjust(shell, recorder, up: true) == .accepted)
            #expect(mirror.hinge == target)
            #expect(try Access.core(shell).chosenHinge == target)
            #expect(mirror.hingeLabel == "hinge \(target)")
            let name: String = play.level.hingeName(target, turn: play.turns[target])
            #expect(mirror.hingeDetail.hasPrefix(name), "\(mirror.hingeDetail)")
            #expect(mirror.summary == Plan.summaryText(core: opening, hinge: target), "\(mirror.summary)")
        }
        #expect(Access.adjust(shell, recorder, up: true) == .accepted)
        #expect(mirror.hinge == cubes - 1, "the hinge does not go past the last")
        Access.choose(shell, recorder, hinge: 1)
        #expect(mirror.hinge == 1)
        #expect(mirror.summary == Plan.summaryText(core: opening, hinge: 1))
        #expect(presenter.feedbackLog.count == logBase, "adjusting the hinge plans nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        #expect(try VoxelOrigamiTest.digest(shell) == digest, "choosing a hinge never changes the digest")
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off plays no audition")
        #expect(presenter.sound.voice == nil)
    }

    // MARK: The panel alone (SC-R02G1506-001, 002)

    /// Level 1 (seed 0) is won with the panel's accessibility operations alone: the adjustable hinge chooses each
    /// certified turn's hinge (never announced, no haptic), Turn − / + is sent through the presenter; every accepted
    /// turn routes exactly `after(old:new:)`; the sinks hold the plans' words and haptics in order; the last is the win
    /// outcome with a success haptic and 3 stars.
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
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(1)
        try #require(!turns.isEmpty, "level 1 has a certified plan")
        var expected: [Plan] = []
        var sent: Int = 0

        for action in turns {
            guard try Access.core(shell).play.stage == .playing else { break }
            guard case let .turn(hinge, step) = action else { continue }
            let logBefore: Int = presenter.feedbackLog.count
            let announcedBefore: Int = recorder.announcements.announced.count
            let playedBefore: Int = recorder.haptics.played.count
            Access.choose(shell, recorder, hinge: hinge)
            try #require(presenter.mirror.hinge == hinge, "the adjustable hinge reaches hinge \(hinge)")
            #expect(presenter.feedbackLog.count == logBefore, "choosing plans nothing")
            #expect(recorder.announcements.announced.count == announcedBefore, "choosing is not announced")
            #expect(recorder.haptics.played.count == playedBefore, "choosing plays no haptic")
            let plan: Plan = try Access.accepted(shell, recorder, "hinge.turn",
                                                 [Double(presenter.mirror.hinge), Double(step)])
            expected.append(plan)
            sent += 1
            let now: Core = try Access.core(shell)
            if now.play.stage == .playing {
                #expect(plan.kind == .state)
                #expect(plan.haptic == .selection)
                let words: String = "Turned hinge \(hinge) " + (step > 0 ? "forward" : "back") + " a quarter turn. "
                #expect(plan.text?.hasPrefix(words) == true, "\(plan.text ?? "nil")")
            }
        }
        #expect(sent == turns.count, "every certified turn was sent")

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        let spent: Int = VoxelOrigamiProgress.actionsSpent(won.play)
        let stars: Int = VoxelOrigamiProgress.stars(actionsSpent: spent, certified: won.certifiedTurns)
        #expect(stars == 3, "the certified plan earns 3 stars")
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(plans.last?.text == Access.winText(won), "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.message == nil)
    }

    // MARK: Refusals (FR-R02G1506-002, 003; clarification Q1)

    /// Refusals are announced as rejections in the plan's words with an error haptic, shown in the panel and logged
    /// bare: the root hinge (`hinge.choose [0]`), a locked `level.next` before a win, and a turn after the win.
    @Test func refusalsAreAnnouncedInThePlanWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        var expected: [Plan] = []

        let root: Plan = try Access.refused(shell, recorder, "hinge.choose", [0])
        #expect(root.text == "This chain has no such hinge.", "\(root.text ?? "nil")")
        #expect(presenter.refusalLog.last == VoxelOrigamiExperienceRule.hinge)
        expected.append(root)
        let locked: Plan = try Access.refused(shell, recorder, "level.next", [])
        #expect(locked.text == "That level is not open yet.", "\(locked.text ?? "nil")")
        #expect(presenter.refusalLog.last == VoxelOrigamiExperienceRule.locked)
        expected.append(locked)

        // An accepted action clears the panel's message.
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(1)
        for action in turns {
            guard case let .turn(hinge, step) = action else { continue }
            expected.append(try Access.accepted(shell, recorder, "hinge.turn", [Double(hinge), Double(step)]))
            #expect(presenter.mirror.message == nil, "an accepted action clears the refusal")
        }
        #expect(try Access.core(shell).play.stage == .won)
        if case let .turn(hinge, step)? = turns.first {
            let ended: Plan = try Access.refused(shell, recorder, "hinge.turn", [Double(hinge), Double(step)])
            #expect(ended.text == "The level has ended.", "\(ended.text ?? "nil")")
            expected.append(ended)
        }
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(recorder.announcements.announced == Access.texts(expected), "\(recorder.announcements.announced)")
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
    }

    // MARK: Reduce Motion and Reduce Flashing stills (FR-R02G1506-004; SC-R02G1506-003)

    /// Under Reduce Motion, and separately under Reduce Flashing, two stills of the same changed state at different
    /// frame times are byte-identical once the fades settle.
    @Test func reduceMotionAndReduceFlashingStillsAreIdentical() async throws {
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(1)
        try #require(turns.count >= 2, "level 1's first certified turn does not win")
        let move: VoxelOrigamiAction = turns[0]
        let modes: [(motion: Bool, flashing: Bool)] = [(true, false), (false, true)]
        for mode in modes {
            let what: String = mode.motion ? "Reduce Motion" : "Reduce Flashing"
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Access.open(session, seed: 0, reduceMotion: mode.motion,
                                              reduceFlashing: mode.flashing)
            Access.quiet(shell)
            #expect(shell.presenter.scene.reduceMotion == mode.motion)
            #expect(shell.presenter.scene.reducedFlash == mode.flashing)
            #expect(VoxelOrigamiTest.issue(shell, [move]) == 1)
            let w: Int = Access.stillWidth
            let h: Int = Access.stillHeight
            let base: Double = 10
            // Two first stills let any light fade finish (0.5 s apart, beyond the 0.45 s fade).
            _ = try VoxelOrigamiTest.still(session, width: w, height: h, time: base)
            _ = try VoxelOrigamiTest.still(session, width: w, height: h, time: base + 0.5)
            let early: [UInt8] = try VoxelOrigamiTest.still(session, width: w, height: h, time: base + 0.75)
            let late: [UInt8] = try VoxelOrigamiTest.still(session, width: w, height: h, time: base + 1.9)
            #expect(VoxelOrigamiTest.nonNightPixels(early) > 0, "\(what): the still shows the chain")
            #expect(early == late, "\(what): stills at 0.75 s and 1.9 s are identical")
            #expect(shell.presenter.lights.isSettled, "\(what): the lights rest")
            if mode.motion {
                let drawn: Snapshot = try #require(shell.presenter.lastSnapshot)
                #expect(drawn.time == 0, "Reduce Motion presents time 0")
            }
        }
    }

    // MARK: Lights under Reduce Flashing (FR-R02G1506-004; SC-R02G1506-003)

    /// Under Reduce Flashing the winning turn's glow (0.7 → 1) and won look (0 → 1) rise over at least 0.4 s of frame
    /// time, sampled every 1/60 s: never falling, starting gradually, reaching 1 between 0.4 s and 0.5 s; the scene
    /// draws the presenter's lights.
    @Test func reduceFlashingWinFadesSlowly() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0, reduceFlashing: true)
        Access.quiet(shell)
        let presenter: Presenter = shell.presenter
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(1)
        let last: VoxelOrigamiAction = try #require(turns.last)
        let setUp: [VoxelOrigamiAction] = Array(turns.dropLast())
        #expect(VoxelOrigamiTest.issue(shell, setUp) == setUp.count)
        try #require(try Access.core(shell).play.stage == .playing, "only the last turn wins")
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        let base: Double = 10
        _ = try VoxelOrigamiTest.still(session, width: w, height: h, time: base - 1)
        _ = try VoxelOrigamiTest.still(session, width: w, height: h, time: base)
        #expect(presenter.lights.won == 0, "the won light rests at 0 while playing")
        #expect(presenter.lights.glow == VoxelOrigamiLights.glowPlaying)
        #expect(VoxelOrigamiTest.issue(shell, [last]) == 1)
        #expect(try Access.core(shell).play.stage == .won)

        let frame: Double = 1.0 / 60
        var previousWon: Double = 0
        var previousGlow: Double = VoxelOrigamiLights.glowPlaying
        var wonAt: Double?
        var glowAt: Double?
        for step in 1...36 {
            let offset: Double = Double(step) * frame
            _ = try VoxelOrigamiTest.still(session, width: w, height: h, time: base + offset)
            let won: Double = presenter.lights.won
            let glow: Double = presenter.lights.glow
            #expect(presenter.scene.lights?.won == won, "the scene draws the presenter's lights at \(offset) s")
            #expect(won >= previousWon, "the won level never falls: \(won) after \(previousWon)")
            #expect(glow >= previousGlow, "the glow never falls: \(glow) after \(previousGlow)")
            if step == 1 {
                #expect(won > 0 && won < 1, "the won look starts gradually: \(won)")
                #expect(glow > VoxelOrigamiLights.glowPlaying && glow < 1, "the glow starts gradually: \(glow)")
            }
            if wonAt == nil && won >= 1 { wonAt = offset }
            if glowAt == nil && glow >= 1 { glowAt = offset }
            previousWon = won
            previousGlow = glow
        }
        let wonReached: Double = try #require(wonAt, "the won level reaches 1 within 0.6 s")
        let glowReached: Double = try #require(glowAt, "the glow reaches 1 within 0.6 s")
        #expect(wonReached >= 0.4 && wonReached <= 0.5, "the won look takes 0.4 … 0.5 s: \(wonReached) s")
        #expect(glowReached >= 0.4 && glowReached <= 0.5, "the glow takes 0.4 … 0.5 s: \(glowReached) s")
        #expect(presenter.lights.isSettled)
    }

    /// In fallback mode under Reduce Flashing the drawn won level rises over at least 0.4 s of frame time after the
    /// winning turn, sampled every 1/60 s: never falling, below 1 at 0.4 s, 1 by 0.5 s; the scene draws the presenter's
    /// lights and the fallback frame changes as the level rises.
    @Test func fallbackWonBrightensSlowlyUnderReduceFlashing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: 0, reduceFlashing: true,
                                                    size: CGSize(width: 360, height: 240),
                                                    configure: { presenter in
                                                        presenter.breakVoxelShader()
                                                    })
        Access.quiet(shell)
        let presenter: Presenter = shell.presenter
        #expect(presenter.fallbackReason != nil, "the broken program falls back")
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(1)
        let last: VoxelOrigamiAction = try #require(turns.last)
        let setUp: [VoxelOrigamiAction] = Array(turns.dropLast())
        #expect(VoxelOrigamiTest.issue(shell, setUp) == setUp.count)
        try #require(try Access.core(shell).play.stage == .playing, "only the last turn wins")
        let w: Int = Access.stillWidth * 2
        let h: Int = Access.stillHeight * 2
        let base: Double = 10
        _ = try VoxelOrigamiTest.still(session, width: w, height: h, time: base - 1)
        _ = try VoxelOrigamiTest.still(session, width: w, height: h, time: base)
        #expect(presenter.lights.won == 0, "the won light rests at 0 while playing")
        #expect(presenter.scene.lights?.won == 0)

        let entry: (control: String, values: [Double]) = VoxelOrigamiTest.control(last)
        let winning: ActionResult = shell.handle(control: entry.control, values: entry.values)
        #expect(winning == .accepted, "\(winning.code)")
        #expect(try Access.core(shell).play.stage == .won)

        let frame: Double = 1.0 / 60
        var previous: Double = 0
        var reachedAt: Double?
        var first: [UInt8] = []
        var latest: [UInt8] = []
        for step in 1...36 {
            let offset: Double = Double(step) * frame
            let rgba: [UInt8] = try VoxelOrigamiTest.still(session, width: w, height: h, time: base + offset)
            if step == 1 { first = rgba }
            latest = rgba
            let level: Double = presenter.lights.won
            #expect(presenter.scene.lights?.won == level, "the scene draws the presenter's lights at \(offset) s")
            #expect(level >= previous, "the won level never falls: \(level) after \(previous) at \(offset) s")
            if step == 1 { #expect(level > 0 && level < 1, "the brightening starts gradually: \(level)") }
            if reachedAt == nil && level >= 1 { reachedAt = offset }
            previous = level
        }
        let reached: Double = try #require(reachedAt, "the won level reaches 1 within 0.6 s")
        #expect(reached >= 0.4, "the won brightening takes at least 0.4 s: reached 1 at \(reached) s")
        #expect(reached <= 0.5, "the won brightening settles by 0.5 s: reached 1 at \(reached) s")
        #expect(presenter.lights.isSettled)
        #expect(first != latest, "the fallback's won look changes as the level rises")
        #expect(VoxelOrigamiTest.nonNightPixels(latest) > 0, "the fallback still shows the chain")
        #expect(presenter.fallbackReason != nil)
    }

    // MARK: Sound (FR-R02G1506-006; SC-R02G1506-004; clarification Q4)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations, and an audition plays only
    /// then; the sound off makes no player and no voice; each input turning off stops a playing loop and a sounding
    /// audition; a new player is made only for a different recipe or the toggle turning on.
    @Test func soundStateTable() throws {
        typealias Recipe = VoxelOrigamiSoundRecipe
        let calm: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 0, stage: .playing)
        let lit: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .playing)
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .won)
        try #require(calm != lit, "another covered quarter sounds different")
        try #require(lit != won, "a won play sounds different")
        let opening: Core = try Core.opening(number: 1)
        let sample: VoxelOrigamiAudition = VoxelOrigamiAudition.of(opening.play, hinge: opening.chosenHinge)
        try #require(!sample.partials.isEmpty, "a hinge's audition has tones")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: VoxelOrigamiA11yLoopFactory = VoxelOrigamiA11yLoopFactory()
            let sound: VoxelOrigamiSound = factory.sound(calm)
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
        let toggles: VoxelOrigamiA11yLoopFactory = VoxelOrigamiA11yLoopFactory()
        let live: VoxelOrigamiSound = toggles.sound(calm)
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
        #expect(!live.audition(VoxelOrigamiAudition(partials: [])), "silence plays nothing")
        #expect(live.auditionsPlayed == 1)

        // A failing play() changes nothing else.
        let failing: VoxelOrigamiA11yLoopFactory = VoxelOrigamiA11yLoopFactory()
        failing.succeeds = false
        let silent: VoxelOrigamiSound = failing.sound(calm)
        silent.setOnScreen(true)
        silent.setWanted(true)
        #expect(!silent.started, "a failed play() is not started")
        #expect(silent.shouldPlay)

        // Rebuilds only when the recipe differs.
        let factory: VoxelOrigamiA11yLoopFactory = VoxelOrigamiA11yLoopFactory()
        let sound: VoxelOrigamiSound = factory.sound(calm)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(calm) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(lit)
        #expect(sound.playersMade == 2, "a change of the covered quarters makes a new player")
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
    }

    /// The presenter's toggle with the controls off screen makes no player, so no audio is touched; choosing a hinge
    /// (a described core whose only change is the chosen hinge) plays no audition while the sound is off, off screen
    /// or inactive; the recipe is offered at the first state and re-offered only when it changes (a turn), never for a
    /// hinge choice; nothing is announced.
    @Test func presenterSoundOffScreenAndRecipeOffers() throws {
        typealias Recipe = VoxelOrigamiSoundRecipe
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        presenter.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(),
                                                announcementSink: RecordingAnnouncementSink(),
                                                voiceOverRunning: { false })
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")
        #expect(Presenter.recipe(opening) == Recipe.recipe(play: opening.play))

        let other: Core = Access.choosing(opening, hinge: Access.otherHinge(opening))
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off: choosing a hinge plays no audition")
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        _ = presenter.describe(opening)
        #expect(presenter.sound.auditionsPlayed == 0, "off screen: choosing a hinge plays no audition")
        presenter.sceneActive(false)
        presenter.controlsAppeared()
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the loop silent")
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 0, "inactive: choosing a hinge plays no audition")
        presenter.controlsDisappeared()
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "a hinge choice keeps the recipe")

        // A turn that changes the recipe re-offers it (kept while the loop cannot play).
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(1)
        var turned: Core = other
        var changed: Bool = false
        for action in turns where !changed {
            let result: ActionResult = turned.apply(VoxelOrigamiTest.experienceAction(action))
            #expect(result == .accepted, "\(result.code)")
            changed = Presenter.recipe(turned) != Presenter.recipe(opening)
        }
        if changed {
            _ = presenter.describe(turned)
            #expect(presenter.sound.recipe == Presenter.recipe(turned), "a changed recipe is re-offered")
        }
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        presenter.sceneActive(true)
        #expect(presenter.sound.playersMade == 0, "no player was made")
        #expect(presenter.sound.player == nil, "the sound off never touches audio")
        #expect(presenter.sound.voice == nil)
        #expect(presenter.feedbackLog.count == (changed ? 1 : 0), "only the turn is announced; hinge choices are not")
    }

    /// With the sound on, on screen and active, choosing a hinge (described) plays `VoxelOrigamiAudition.of(play,
    /// hinge:)` of the chosen hinge, one audition per choice; describing the same core again plays nothing; with the
    /// sound off again a further choice plays nothing. (This test makes the presenter's real loop and one-shot
    /// players.)
    @Test func choosingAHingePlaysItsAuditionWhenTheSoundIsOn() throws {
        let presenter: Presenter = Presenter(reduceMotion: true, reduceFlashing: false)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.setSound(on: true)
        presenter.controlsAppeared()
        presenter.sceneActive(true)
        #expect(presenter.sound.shouldPlay)
        #expect(presenter.sound.playersMade == 1, "the toggle turning on screen makes the loop's player")

        let hinge: Int = Access.otherHinge(opening)
        let other: Core = Access.choosing(opening, hinge: hinge)
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 1, "one choice, one audition")
        #expect(presenter.sound.lastAudition == VoxelOrigamiAudition.of(other.play, hinge: hinge))
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 1, "describing the same choice again plays nothing")
        _ = presenter.describe(opening)
        #expect(presenter.sound.auditionsPlayed == 2)
        #expect(presenter.sound.lastAudition == VoxelOrigamiAudition.of(opening.play, hinge: opening.chosenHinge))
        #expect(presenter.sound.playersMade == 1, "a hinge choice never rebuilds the loop")
        #expect(presenter.feedbackLog.isEmpty, "choosing a hinge is not announced")

        presenter.setSound(on: false)
        presenter.controlsDisappeared()
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 2, "no audition once the sound is off")
        #expect(!presenter.sound.shouldPlay)
    }
}
#endif
