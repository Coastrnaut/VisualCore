// MoonlitMechanismAccessibilityTests — feature 436 (R02-G14-06) T-R02G1406-005 (FR-R02G1406-001 … 006)
// (SC-R02G1406-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Acoustic Constellator's feature-426 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; the presenter's own
// `feedbackLog` holds every routed plan. Every expected text is built from `MoonlitMechanismFeedbackPlan`
// (`after(old:new:)`, `refused(code:)`, `summaryText(core:gear:)`) on the cores captured before and after each step.
// Values: every value the panel reads from the mirror (the chosen gear and its detail, the lamp, the shown key frame,
// the summary, the status, the progress, the level, the goal) is non-empty words once level 1 is described; the summary
// element equals `summaryText(core:gear:)` and follows the adjustable gear after `chooseGear(_:)` (which refreshes it).
// The adjustable gear (`chooseGear(gear ± 1)`, what the panel's increment and decrement call) steps through the level's
// gears within their bounds and is never announced; the adjustable key frame (`frame.show [k]` through the presenter)
// steps through the key frames, is never announced, and a key frame the level lacks is refused in words.
// Level 1 (seed 0) is won with the panel's accessibility operations alone: the adjustable gear chooses each re-seated
// gear, Turn, Re-seat, Lamp and Run are sent through `presenter.send`; every accepted step routes exactly
// `after(old:new:)` and the last one is the win outcome with a success haptic. A scripted sequence (a locked
// `level.next`, Turn +, Undo, a failing Run, a turn refused after the failure, Retry, the certified win and
// `level.next` to level 2) records exactly the plans' announcements and haptics in order. A gear drag of several teeth
// routes exactly one plan ("Turned the handle forward n teeth." or "back", `after(old:new:)` of the cores before the
// first turn and after the last). Reduce Motion and Reduce Flashing: two stills of the same state at different frame
// times are byte-identical once the fades settle. In fallback mode (`breakClockworkShader()` before setup) under Reduce
// Flashing a win brightens the drawn won level over at least 0.4 s of frame time, sampled at 1/60 s. Sound: the state
// table (wanted × on screen × active → shouldPlay, a player made only when it plays, an audition only while the loop
// may play) uses a `MoonlitMechanismSound` with an injected recording loop and voice; the presenter's own toggle is
// driven off screen (no player made) and choosing a gear plays no audition while the sound is off or cannot play. One
// test turns the presenter's sound on screen, so it makes the shared ambient loop and one-shot players (ambient
// session, no input): choosing a gear then plays `MoonlitMechanismAudition.of(play, gear:)`. Synthetic data, explicit
// types, plain loops, no nested closure literals, no wall-clock assertion; each test short.
#if os(iOS)
import CoreGraphics
import Foundation
import MoonlitMechanismCore
import Testing
@testable import MoonlitMechanismExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class MoonlitMechanismA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class MoonlitMechanismA11yLoop: MoonlitMechanismLoopPlaying {
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
final class MoonlitMechanismA11yVoice: MoonlitMechanismAuditionPlaying {
    /// Every audition played, oldest first.
    private(set) var played: [MoonlitMechanismAudition] = []
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0

    /// A silent recording voice.
    init() {}

    /// Records `audition`; true when it has partials.
    @discardableResult
    func play(_ audition: MoonlitMechanismAudition) -> Bool {
        played.append(audition)
        return !audition.partials.isEmpty
    }

    /// Records a stop.
    func stop() { stops += 1 }
}

/// Makes fake loops and voices and keeps them.
@MainActor
final class MoonlitMechanismA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [MoonlitMechanismA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []
    /// Every voice made, oldest first.
    private(set) var voices: [MoonlitMechanismA11yVoice] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> MoonlitMechanismA11yLoop {
        let loop: MoonlitMechanismA11yLoop = MoonlitMechanismA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// Makes and keeps one fake voice.
    func makeVoice() -> MoonlitMechanismA11yVoice {
        let voice: MoonlitMechanismA11yVoice = MoonlitMechanismA11yVoice()
        voices.append(voice)
        return voice
    }

    /// A sound policy starting from `recipe` that makes its players and its voice here.
    func sound(_ recipe: AmbientLoopRecipe) -> MoonlitMechanismSound {
        MoonlitMechanismSound(recipe: recipe, makePlayer: { next in self.make(next) },
                              makeVoice: { self.makeVoice() })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum MoonlitMechanismA11y {
    typealias Shell = MoonlitMechanismTest.Shell
    typealias Plan = MoonlitMechanismFeedbackPlan
    typealias Core = MoonlitMechanismExperienceCore
    typealias Presenter = MoonlitMechanismPresenter

    /// A recording route on a presenter.
    struct Recorder {
        /// The haptics played, in order.
        let haptics: RecordingHapticSink
        /// The announcements posted, in order.
        let announcements: RecordingAnnouncementSink
        /// The clock of the route.
        let clock: MoonlitMechanismA11yClock
    }

    /// The still size of the Reduce Motion and Reduce Flashing tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await MoonlitMechanismTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                               reduceFlashing: reduceFlashing,
                                                               size: CGSize(width: 360, height: 240))
        _ = shell.presenter.describe(try core(shell))
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: MoonlitMechanismA11yClock = MoonlitMechanismA11yClock()
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
        try MoonlitMechanismTest.core(shell)
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

    /// Chooses `gear` in the panel with the adjustable gear's operations only (`chooseGear(gear ± 1)`, what the
    /// increment and decrement call). Returns the presses made.
    @discardableResult
    static func choose(_ presenter: Presenter, gear: Int) -> Int {
        let mirror: MoonlitMechanismMirror = presenter.mirror
        var presses: Int = 0
        for _ in 0..<16 {
            if mirror.gear < gear {
                presenter.chooseGear(mirror.gear + 1)
            } else if mirror.gear > gear {
                presenter.chooseGear(mirror.gear - 1)
            } else {
                break
            }
            presses += 1
        }
        return presses
    }

    /// The panel's control and values for the kernel action `action`: Turn − / + the handle, Re-seat − / + the gear
    /// chosen with the adjustable gear first, Lamp − / +, Run. Returns nil for a step the panel cannot send (only ±1).
    static func panel(_ action: MoonlitMechanismAction, _ presenter: Presenter) -> (control: String, values: [Double])? {
        switch action {
        case let .turn(step):
            guard step == 1 || step == -1 else { return nil }
            return ("handle.turn", [Double(step)])
        case let .reseat(gear, step):
            guard step == 1 || step == -1 else { return nil }
            choose(presenter, gear: gear)
            guard presenter.mirror.gear == gear else { return nil }
            return ("gear.reseat", [Double(presenter.mirror.gear), Double(step)])
        case let .lamp(step):
            guard step == 1 || step == -1 else { return nil }
            return ("lamp.step", [Double(step)])
        case .run:
            return ("machine.run", [])
        }
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
        #expect(presenter.mirror.summary == Plan.summaryText(core: new, gear: presenter.mirror.gear),
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
        let digest: String = try MoonlitMechanismTest.digest(shell)
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
        #expect(presenter.refusalLog.last == MoonlitMechanismMirror.bareCode(result.code),
                sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        #expect(try MoonlitMechanismTest.digest(shell) == digest, "a refusal changes nothing",
                sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// The win text of `core`'s won campaign play, built as the plan words it.
    static func winText(_ core: Core) -> String {
        let spent: Int = MoonlitMechanismProgress.actionsSpent(core.play)
        let stars: Int = MoonlitMechanismProgress.stars(actionsSpent: spent, certified: core.certifiedActions)
        let spentWords: String = spent == 1 ? "1 action" : "\(spent) actions"
        return Plan.wonText + " Level won spending " + spentWords + ", " + String(stars) + " of 3 stars."
    }
}

@MainActor
@Suite(.serialized) struct MoonlitMechanismAccessibilityTests {
    typealias Access = MoonlitMechanismA11y
    typealias Plan = MoonlitMechanismFeedbackPlan
    typealias Presenter = MoonlitMechanismPresenter
    typealias Core = MoonlitMechanismExperienceCore
    typealias Snapshot = MoonlitMechanismSceneSnapshot
    typealias Script = MoonlitMechanismGestureScript

    // MARK: Values and the summary element (FR-R02G1406-001, 005; clarification Q5)

    /// After level 1 is described every value the panel reads is non-empty words; the summary element equals
    /// `summaryText(core:gear:)`; describing the opening routes nothing; the sound is off.
    @Test func everyControlHasALabelAndAValueInWords() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: MoonlitMechanismMirror = presenter.mirror
        let values: [String] = [mirror.gearLabel, mirror.gearDetail, mirror.lampLabel, mirror.frameLabel,
                                mirror.summary, mirror.status, mirror.measureLabel, mirror.targetLabel,
                                mirror.goalLabel, MoonlitMechanismControls.modeName(mirror.mode)]
        var index: Int = 0
        for value in values {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "value \(index) is empty")
            index += 1
        }
        #expect(MoonlitMechanismControls.modeName(.campaign) == "campaign")
        #expect(MoonlitMechanismControls.modeName(.practice) == "practice")
        #expect(MoonlitMechanismControls.modeName(.daily(level: 1)) == "daily")
        #expect(MoonlitMechanismControls.readableWidth == 520)

        // The chosen gear, lamp and key frame read as the level words them.
        let play: MoonlitMechanismPlay = core.play
        #expect(mirror.gear == Core.openingGear, "a level opens with gear 1 chosen")
        #expect(mirror.gearDetail == play.level.gearName(mirror.gear, phase: play.phases[mirror.gear]),
                "\(mirror.gearDetail)")
        #expect(mirror.lampLabel == play.level.lampName(play.height), "\(mirror.lampLabel)")
        #expect(mirror.frameLabel.hasPrefix("key frame 0 of \(play.level.keyFrames.count), "), "\(mirror.frameLabel)")
        #expect(mirror.status == "Ready", "\(mirror.status)")

        // The summary element (clarification Q5).
        #expect(mirror.summary == Plan.summaryText(core: core, gear: mirror.gear), "\(mirror.summary)")
        #expect(mirror.summary.contains("Level: " + Plan.levelWords(core) + "."), "\(mirror.summary)")
        #expect(mirror.soundOn == false, "the Sound toggle is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.feedbackLog.isEmpty, "describing the opening plans nothing")

        // Refusals read in the plan's words (clarification Q1), with or without the engine's prefix.
        #expect(MoonlitMechanismMirror.refusalText(code: "action.rule.r02-g14.locked") == "That level is not open yet.")
        #expect(Plan.refused(code: "r02-g14.stage").text == "The level has ended.")
        #expect(Plan.refused(code: "action.out-of-range").text == "That action was refused.")
    }

    /// The adjustable gear steps through the level's gears (clamped to 0 … count − 1); its value reads the gear as the
    /// level words it; the summary follows; nothing is announced and, with the sound off, no audition plays.
    @Test func adjustableGearStepsThroughTheGears() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: MoonlitMechanismMirror = presenter.mirror
        let play: MoonlitMechanismPlay = core.play
        let count: Int = play.level.gears.count
        try #require(count >= 2, "level 1 has at least two gears")
        #expect(mirror.gearCount == count)

        presenter.chooseGear(mirror.gear - 1)
        #expect(mirror.gear == 0)
        #expect(mirror.gearLabel == "gear 0 (driver)")
        presenter.chooseGear(mirror.gear - 1)
        #expect(mirror.gear == 0, "the gear does not go below 0")
        for target in 1..<count {
            presenter.chooseGear(mirror.gear + 1)
            #expect(mirror.gear == target)
            #expect(mirror.gearLabel == "gear \(target)")
            #expect(mirror.gearDetail == play.level.gearName(target, phase: play.phases[target]),
                    "\(mirror.gearDetail)")
            #expect(mirror.summary == Plan.summaryText(core: core, gear: target), "\(mirror.summary)")
        }
        presenter.chooseGear(mirror.gear + 1)
        #expect(mirror.gear == count - 1, "the gear does not go past the last")
        for _ in 0..<(count + 2) { presenter.chooseGear(mirror.gear - 1) }
        #expect(mirror.gear == 0)
        #expect(mirror.summary == Plan.summaryText(core: core, gear: 0))
        #expect(presenter.feedbackLog.isEmpty, "adjusting the gear plans nothing")
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off plays no audition")
        #expect(presenter.sound.voice == nil)
    }

    /// The adjustable key frame (`frame.show [k]` through the presenter, clamped as the panel clamps it) steps through
    /// the level's key frames; the core and the mirror show it, the value reads it, the digest stays and nothing is
    /// announced; a key frame the level lacks is refused in the plan's words.
    @Test func adjustableKeyFrameStepsThroughTheFrames() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: MoonlitMechanismMirror = presenter.mirror
        let opening: Core = try Access.core(shell)
        let count: Int = opening.play.level.keyFrames.count
        #expect(mirror.frameCount == count)
        let digest: String = try MoonlitMechanismTest.digest(shell)
        let logBase: Int = presenter.feedbackLog.count

        // Decrement at key frame 0 stays at 0.
        recorder.clock.advance()
        #expect(presenter.send("frame.show", [Double(mirror.clampedFrame(mirror.shownFrame - 1))],
                               port: shell.port) == .accepted)
        #expect(try Access.core(shell).shownFrame == 0)
        for target in 1..<max(count, 1) {
            recorder.clock.advance()
            let result: ActionResult = presenter.send("frame.show", [Double(mirror.clampedFrame(mirror.shownFrame + 1))],
                                                      port: shell.port)
            #expect(result == .accepted, "\(result.code)")
            #expect(try Access.core(shell).shownFrame == target)
            #expect(mirror.shownFrame == target)
            #expect(mirror.frameLabel.hasPrefix("key frame \(target) of \(count), "), "\(mirror.frameLabel)")
            #expect(mirror.summary.contains("Showing key frame \(target)."), "\(mirror.summary)")
        }
        recorder.clock.advance()
        #expect(presenter.send("frame.show", [Double(mirror.clampedFrame(mirror.shownFrame + 1))],
                               port: shell.port) == .accepted)
        #expect(mirror.shownFrame == count - 1, "the key frame does not go past the last")
        #expect(presenter.feedbackLog.count == logBase, "showing a key frame plans nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        #expect(try MoonlitMechanismTest.digest(shell) == digest, "showing a key frame never changes the digest")

        // A key frame the level lacks (within the declared 0 … 5) is refused in words.
        if count < 6 {
            let plan: Plan = try Access.refused(shell, recorder, "frame.show", [Double(count)])
            #expect(plan.text == "This level has no such key frame.", "\(plan.text ?? "nil")")
        }
    }

    // MARK: The panel alone (SC-R02G1406-001, 002)

    /// Level 1 (seed 0) is won with the panel's accessibility operations alone: the adjustable gear chooses each
    /// re-seated gear (never announced, no haptic), Turn, Re-seat, Lamp and Run are sent through the presenter; every
    /// accepted step routes exactly `after(old:new:)`; the sinks hold the plans' words and haptics in order; the last
    /// is the win outcome with a success haptic.
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
        let actions: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedActions(1)
        try #require(!actions.isEmpty, "level 1 has a certified solution")
        try #require(actions.last == .run, "the certified solution ends with a run")
        var expected: [Plan] = []
        var sent: Int = 0

        for action in actions {
            guard try Access.core(shell).play.stage == .playing else { break }
            let old: Core = try Access.core(shell)
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
            if now.play.stage == .playing {
                #expect(plan.kind == .state)
                #expect(plan.haptic == .selection)
                switch action {
                case let .turn(step):
                    let words: String = "Turned the handle " + (step > 0 ? "forward" : "back") + " one tooth. "
                    #expect(plan.text?.hasPrefix(words) == true, "\(plan.text ?? "nil")")
                case let .reseat(gear, _):
                    let words: String = "Gear \(gear) re-seated to phase \(now.play.phases[gear]). "
                    #expect(plan.text?.hasPrefix(words) == true, "\(plan.text ?? "nil")")
                case .lamp:
                    let verb: String = now.play.height > old.play.height ? "raised" : "lowered"
                    let words: String = "Lamp " + verb + " to height \(now.play.height) of "
                        + "\(now.play.level.lampHeights). "
                    #expect(plan.text?.hasPrefix(words) == true, "\(plan.text ?? "nil")")
                case .run:
                    Issue.record("a run always ends the level")
                }
            }
        }
        #expect(sent == actions.count, "every certified action was sent")

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        let spent: Int = MoonlitMechanismProgress.actionsSpent(won.play)
        let stars: Int = MoonlitMechanismProgress.stars(actionsSpent: spent, certified: won.certifiedActions)
        #expect(stars == 3, "the certified solution earns 3 stars")
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

    // MARK: Recorded feedback of a scripted sequence (FR-R02G1406-002, 003; clarifications Q1, Q2)

    /// A scripted sequence on level 1 — a locked `level.next`, Turn +, Undo, a failing Run, a turn refused after the
    /// failure, Retry, the certified win and `level.next` — records exactly the plans' announcements and haptics in
    /// order: rejections with an error haptic, states with a selection haptic, the failure with a warning, the win with
    /// a success and the level changes without a haptic.
    @Test func recordedFeedbackEqualsThePlans() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let moves: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedMoves(1)
        try #require(!moves.isEmpty, "a run at the opening does not win")
        var expected: [Plan] = []

        // A refusal: the next level is not open before a win.
        let locked: Plan = try Access.refused(shell, recorder, "level.next", [])
        #expect(locked.text == "That level is not open yet.", "\(locked.text ?? "nil")")
        expected.append(locked)

        // Turn +, then Undo.
        let turned: Plan = try Access.accepted(shell, recorder, "handle.turn", [1])
        #expect(turned.kind == .state && turned.haptic == .selection)
        #expect(turned.text?.hasPrefix("Turned the handle forward one tooth. ") == true, "\(turned.text ?? "nil")")
        expected.append(turned)
        let undone: Plan = try Access.accepted(shell, recorder, "play.undo", [])
        #expect(undone.text?.hasPrefix("Undone. ") == true, "\(undone.text ?? "nil")")
        #expect(undone.haptic == .selection)
        expected.append(undone)

        // A failure: a run of the unsolved opening set-up.
        let failed: Plan = try Access.accepted(shell, recorder, "machine.run", [])
        let failedCore: Core = try Access.core(shell)
        #expect(failedCore.play.stage == .failed, "a run of the opening set-up fails: \(failedCore.play.stage)")
        #expect(failed.kind == .outcome)
        #expect(failed.haptic == .warning)
        #expect(failed.text == MoonlitMechanismFailureExplanation(play: failedCore.play)?.text,
                "\(failed.text ?? "nil")")
        expected.append(failed)

        // A refusal after the failure: the level has ended.
        let ended: Plan = try Access.refused(shell, recorder, "handle.turn", [1])
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
        for action in try MoonlitMechanismTest.certifiedActions(1) {
            let entry: (control: String, values: [Double])? = Access.panel(action, presenter)
            let issued: (control: String, values: [Double]) = try #require(entry)
            expected.append(try Access.accepted(shell, recorder, issued.control, issued.values))
        }
        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(expected.last?.haptic == .success)
        #expect(expected.last?.text == Access.winText(won))

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

    // MARK: A gear drag is announced once (FR-R02G1406-002; clarification Q2)

    /// A gear drag of several teeth sends that many `handle.turn` actions but routes exactly one plan, equal to
    /// `after(old:new:)` of the core before the first turn and the core after the last: "Turned the handle forward n
    /// teeth." (or "back") and the progress, one selection haptic, one announcement.
    @Test func aGearDragIsAnnouncedOnce() async throws {
        let number: Int = try Script.level("a gear ≥ 1 and three actions") { (core: Core, snapshot: Snapshot) -> Bool in
            core.play.actionsLeft >= 3 && Script.movableGear(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let presenter: Presenter = shell.presenter
        _ = presenter.describe(try Access.core(shell))
        let recorder: Access.Recorder = Access.record(shell)
        let before: Core = try Access.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: MoonlitMechanismOrbit = presenter.gestures.orbit
        let target = try #require(Script.movableGear(snapshot, orbit: orbit), "a gear ≥ 1 picks inside the view")
        let pivot: Vec2 = try #require(Script.pivot(target.gear, snapshot, orbit: orbit))
        let teeth: Int = before.play.actionsLeft >= 4 ? 3 : 2
        let sense: Int = MoonlitMechanismSceneGeometry.turnSense(target.gear, snapshot)
        let logBase: Int = presenter.feedbackLog.count
        let acceptedBefore: Int = shell.engine.acceptedActions
        var time: Double = Script.clock()
        recorder.clock.advance()

        let end: Vec2 = Script.gearDragOver(shell, id: 1, start: target.point, pivot: pivot, teeth: teeth,
                                            toothCount: snapshot.gears[target.gear].teeth, time: &time)
        #expect(presenter.feedbackLog.count == logBase, "nothing is planned while dragging")
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(shell.engine.acceptedActions == acceptedBefore + teeth, "\(teeth) handle.turn accepted")
        let after: Core = try Access.core(shell)
        #expect(after.play.actionsSpent == before.play.actionsSpent + teeth)
        #expect(after.play.stage == .playing)
        let plan: Plan = Plan.after(old: before, new: after)
        let words: String = "Turned the handle " + (sense > 0 ? "forward" : "back") + " \(teeth) teeth. "
        #expect(plan.text?.hasPrefix(words) == true, "\(plan.text ?? "nil")")
        #expect(plan.kind == .state)
        #expect(plan.haptic == .selection)
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == [plan], "the drag routes exactly one plan: \(plans)")
        #expect(recorder.announcements.announced == Access.texts([plan]))
        #expect(recorder.haptics.played == [HapticKind.selection], "\(recorder.haptics.played)")
        _ = presenter.describe(after)
        #expect(presenter.feedbackLog.count == logBase + 1, "describing the dragged state again routes nothing")
        #expect(presenter.mirror.summary == Plan.summaryText(core: after, gear: presenter.mirror.gear))
    }

    // MARK: Reduce Motion and Reduce Flashing stills (FR-R02G1406-004; SC-R02G1406-003)

    /// Under Reduce Motion, and separately under Reduce Flashing, two stills of the same changed state at different
    /// frame times are byte-identical once the fades settle.
    @Test func reduceMotionAndReduceFlashingStillsAreIdentical() async throws {
        let moves: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedMoves(1)
        let move: MoonlitMechanismAction = try #require(moves.first, "level 1 has a certified move")
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
            #expect(MoonlitMechanismTest.issue(shell, [move]) == 1)
            let w: Int = Access.stillWidth
            let h: Int = Access.stillHeight
            let base: Double = 10
            // Two first stills let any light fade finish (0.5 s apart, beyond the 0.45 s fade).
            _ = try MoonlitMechanismTest.still(session, width: w, height: h, time: base)
            _ = try MoonlitMechanismTest.still(session, width: w, height: h, time: base + 0.5)
            let early: [UInt8] = try MoonlitMechanismTest.still(session, width: w, height: h, time: base + 0.75)
            let late: [UInt8] = try MoonlitMechanismTest.still(session, width: w, height: h, time: base + 1.9)
            #expect(MoonlitMechanismTest.nonNightPixels(early) > 0, "\(what): the still shows the clockwork")
            #expect(early == late, "\(what): stills at 0.75 s and 1.9 s are identical")
            #expect(shell.presenter.lights.isSettled, "\(what): the lights rest")
            if mode.motion {
                let drawn: Snapshot = try #require(shell.presenter.lastSnapshot)
                #expect(drawn.time == 0, "Reduce Motion presents time 0")
            }
        }
    }

    // MARK: Lights under Reduce Flashing in fallback mode (FR-R02G1406-004; SC-R02G1406-003)

    /// In fallback mode under Reduce Flashing the drawn won level rises over at least 0.4 s of frame time after the
    /// winning run, sampled every 1/60 s: never falling, below 1 at 0.4 s, 1 by 0.5 s; the scene draws the presenter's
    /// lights and the fallback frame changes as the level rises.
    @Test func fallbackWonBrightensSlowlyUnderReduceFlashing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MoonlitMechanismTest.open(session, seed: 0, reduceFlashing: true,
                                                        size: CGSize(width: 360, height: 240),
                                                        configure: { presenter in
                                                            presenter.breakClockworkShader()
                                                        })
        Access.quiet(shell)
        let presenter: Presenter = shell.presenter
        #expect(presenter.fallbackReason != nil, "the broken program falls back")
        let moves: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedMoves(1)
        #expect(MoonlitMechanismTest.issue(shell, moves) == moves.count)
        try #require(try Access.core(shell).play.stage == .playing, "only the run wins")
        let w: Int = Access.stillWidth * 2
        let h: Int = Access.stillHeight * 2
        let base: Double = 10
        _ = try MoonlitMechanismTest.still(session, width: w, height: h, time: base - 1)
        _ = try MoonlitMechanismTest.still(session, width: w, height: h, time: base)
        #expect(presenter.lights.won == 0, "the won light rests at 0 while playing")
        #expect(presenter.scene.lights?.won == 0)

        let winning: ActionResult = shell.handle(control: "machine.run", values: [])
        #expect(winning == .accepted, "\(winning.code)")
        #expect(try Access.core(shell).play.stage == .won)

        let frame: Double = 1.0 / 60
        var previous: Double = 0
        var reachedAt: Double?
        var first: [UInt8] = []
        var last: [UInt8] = []
        for step in 1...36 {
            let offset: Double = Double(step) * frame
            let rgba: [UInt8] = try MoonlitMechanismTest.still(session, width: w, height: h, time: base + offset)
            if step == 1 { first = rgba }
            last = rgba
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
        #expect(first != last, "the fallback's won look changes as the level rises")
        #expect(MoonlitMechanismTest.nonNightPixels(last) > 0, "the fallback still shows the clockwork")
        #expect(presenter.fallbackReason != nil)
    }

    // MARK: Sound (FR-R02G1406-006; SC-R02G1406-004; clarification Q4)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations, and an audition plays only
    /// then; the sound off makes no player and no voice; each input turning off stops a playing loop and a sounding
    /// audition; a new player is made only for a different recipe or the toggle turning on. The presenter's toggle,
    /// driven off screen, makes no player, and choosing a gear then plays no audition.
    @Test func soundStateTable() throws {
        typealias Recipe = MoonlitMechanismSoundRecipe
        let calm: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 0, stage: .playing)
        let lit: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .playing)
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .won)
        try #require(calm != lit, "another covered quarter sounds different")
        try #require(lit != won, "a won play sounds different")
        let opening: Core = try Core.opening(number: 1)
        let sample: MoonlitMechanismAudition = MoonlitMechanismAudition.of(opening.play, gear: 1)
        try #require(!sample.partials.isEmpty, "a gear's audition has tones")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: MoonlitMechanismA11yLoopFactory = MoonlitMechanismA11yLoopFactory()
            let sound: MoonlitMechanismSound = factory.sound(calm)
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
        let toggles: MoonlitMechanismA11yLoopFactory = MoonlitMechanismA11yLoopFactory()
        let live: MoonlitMechanismSound = toggles.sound(calm)
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
        #expect(!live.audition(MoonlitMechanismAudition(partials: [])), "silence plays nothing")
        #expect(live.auditionsPlayed == 1)

        // A failing play() changes nothing else.
        let failing: MoonlitMechanismA11yLoopFactory = MoonlitMechanismA11yLoopFactory()
        failing.succeeds = false
        let silent: MoonlitMechanismSound = failing.sound(calm)
        silent.setOnScreen(true)
        silent.setWanted(true)
        #expect(!silent.started, "a failed play() is not started")
        #expect(silent.shouldPlay)

        // Rebuilds only when the recipe differs.
        let factory: MoonlitMechanismA11yLoopFactory = MoonlitMechanismA11yLoopFactory()
        let sound: MoonlitMechanismSound = factory.sound(calm)
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

        // The presenter's toggle with the controls off screen: no player is made, so no audio is touched; choosing a
        // gear plays no audition while the sound is off or cannot play.
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        _ = presenter.describe(opening)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")
        #expect(Presenter.recipe(opening) == Recipe.recipe(play: opening.play))
        presenter.chooseGear(0)
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off: choosing a gear plays no audition")
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        presenter.chooseGear(1)
        #expect(presenter.sound.auditionsPlayed == 0, "off screen: choosing a gear plays no audition")
        presenter.sceneActive(false)
        presenter.controlsAppeared()
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the loop silent")
        presenter.chooseGear(0)
        #expect(presenter.sound.auditionsPlayed == 0, "inactive: choosing a gear plays no audition")
        presenter.controlsDisappeared()
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        presenter.sceneActive(true)
        #expect(presenter.sound.playersMade == 0, "no player was made")
        #expect(presenter.sound.player == nil, "the sound off never touches audio")
        #expect(presenter.sound.voice == nil)
        #expect(presenter.feedbackLog.isEmpty, "choosing gears plans nothing")
    }

    /// With the sound on, on screen and active, choosing a gear plays `MoonlitMechanismAudition.of(play, gear:)` of
    /// the chosen gear, one audition per choice; with the sound off again a further choice plays nothing. (This test
    /// makes the presenter's real loop and one-shot players.)
    @Test func choosingAGearPlaysItsAuditionWhenTheSoundIsOn() throws {
        let presenter: Presenter = Presenter(reduceMotion: true, reduceFlashing: false)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.setSound(on: true)
        presenter.controlsAppeared()
        presenter.sceneActive(true)
        #expect(presenter.sound.shouldPlay)
        #expect(presenter.sound.playersMade == 1, "the toggle turning on screen makes the loop's player")

        presenter.chooseGear(0)
        #expect(presenter.sound.auditionsPlayed == 1, "one choice, one audition")
        #expect(presenter.sound.lastAudition == MoonlitMechanismAudition.of(opening.play, gear: 0))
        presenter.chooseGear(1)
        #expect(presenter.sound.auditionsPlayed == 2)
        #expect(presenter.sound.lastAudition == MoonlitMechanismAudition.of(opening.play, gear: 1))
        #expect(presenter.feedbackLog.isEmpty, "choosing a gear is not announced")

        presenter.setSound(on: false)
        presenter.controlsDisappeared()
        presenter.chooseGear(0)
        #expect(presenter.sound.auditionsPlayed == 2, "no audition once the sound is off")
        #expect(!presenter.sound.shouldPlay)
    }
}
#endif
