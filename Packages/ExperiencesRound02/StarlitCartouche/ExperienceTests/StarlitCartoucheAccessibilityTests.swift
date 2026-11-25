// StarlitCartoucheAccessibilityTests — feature 456 (R02-G16-06) T-R02G1606-005 (FR-R02G1606-001 … 006)
// (SC-R02G1606-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Voxel Origami's feature-446 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; the presenter's own
// `feedbackLog` holds every routed plan. Every expected text is built from `StarlitCartoucheFeedbackPlan`
// (`after(old:new:)`, `refused(code:)`, `summaryText(core:destination:wait:)`) on the cores captured before and after
// each step. The shell describes the new core after every accepted action (the port's summary), so the mirror follows
// at once; describing the same core again routes nothing.
// Labels and values: the `.accessibilityLabel` / `.accessibilityValue` modifiers are not inspectable from a unit test
// (SwiftUI's accessibility tree), so the panel's source is read (`#filePath`, as the identifier tests do): every
// control's modifier run up to its identifier carries a label and a value, and the destination and the wait an
// adjustable action; every value the panel reads from the mirror is non-empty words once level 1 is described, and the
// summary element equals `summaryText(core:destination:wait:)`. The adjustable destination and wait send exactly what
// the panel's increment and decrement send (`route.choose [nextDestination(±1), wait]` and
// `route.choose [destination, clampedWait(wait ± 1)]`) through `presenter.send`, never announced. Level 1 (seed 0) is
// won with those operations and Fly (`route.fly [destination, wait]`) alone, every leg announced as `after(old:new:)`.
// A scripted sequence (legs, undo, redo, refusals, a failure, a redo restoring it, practice and campaign openings) on
// the first level with a failing leg (the teaching tests' `failureCase()`) records exactly the plans' texts and
// haptics. Reduce Motion (alone and with Reduce Flashing): two stills of the same won state at different frame times
// are byte-identical once the fades settle (under Reduce Flashing alone the firmament still turns, so there the eased
// lights are compared instead). In fallback mode (`breakChartShader()` before setup) under Reduce Flashing the won
// level brightens over at least 0.4 s of frame time (sampled at 1/60 s). Sound: the state table (wanted × on screen ×
// active) uses a `StarlitCartoucheSound` with injected recording loops and voices; the presenter's own toggle off
// screen makes no player; one test turns the presenter's sound on screen (the shared ambient loop and one-shot
// players, ambient session, no input): choosing a destination plays its audition, choosing a wait none. Explicit
// timestamps, synthetic data, explicit types, plain loops, no nested closure literals, no sleep, no wall-clock
// assertion; each test short.
#if os(iOS)
import CoreGraphics
import Foundation
import StarlitCartoucheCore
import Testing
@testable import StarlitCartoucheExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class StarlitCartoucheA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class StarlitCartoucheA11yLoop: StarlitCartoucheLoopPlaying {
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
final class StarlitCartoucheA11yVoice: StarlitCartoucheAuditionPlaying {
    /// Every audition played, oldest first.
    private(set) var played: [StarlitCartoucheAudition] = []
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0

    /// A silent recording voice.
    init() {}

    /// Records `audition`; true when it has partials.
    @discardableResult
    func play(_ audition: StarlitCartoucheAudition) -> Bool {
        played.append(audition)
        return !audition.partials.isEmpty
    }

    /// Records a stop.
    func stop() { stops += 1 }
}

/// Makes fake loops and voices and keeps them.
@MainActor
final class StarlitCartoucheA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [StarlitCartoucheA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []
    /// Every voice made, oldest first.
    private(set) var voices: [StarlitCartoucheA11yVoice] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> StarlitCartoucheA11yLoop {
        let loop: StarlitCartoucheA11yLoop = StarlitCartoucheA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// Makes and keeps one fake voice.
    func makeVoice() -> StarlitCartoucheA11yVoice {
        let voice: StarlitCartoucheA11yVoice = StarlitCartoucheA11yVoice()
        voices.append(voice)
        return voice
    }

    /// A sound policy starting from `recipe` that makes its players and its voice here.
    func sound(_ recipe: AmbientLoopRecipe) -> StarlitCartoucheSound {
        StarlitCartoucheSound(recipe: recipe, makePlayer: { next in self.make(next) },
                              makeVoice: { self.makeVoice() })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum StarlitCartoucheA11y {
    typealias Shell = StarlitCartoucheTest.Shell
    typealias Plan = StarlitCartoucheFeedbackPlan
    typealias Core = StarlitCartoucheExperienceCore
    typealias Presenter = StarlitCartouchePresenter

    /// A recording route on a presenter.
    struct Recorder {
        /// The haptics played, in order.
        let haptics: RecordingHapticSink
        /// The announcements posted, in order.
        let announcements: RecordingAnnouncementSink
        /// The clock of the route.
        let clock: StarlitCartoucheA11yClock
    }

    /// The still size of the Reduce Motion and fallback tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// The controls of the panel by identifier name: each needs a label and a value (clarification Q5).
    static let controlNames: [String] = ["summary", "dismiss-tutorial", "hint", "failure-undo", "retry", "star-minus",
                                         "star", "star-plus", "wait-minus", "wait", "wait-plus", "fly", "undo",
                                         "redo", "next-level", "reset-view", "campaign", "daily", "practice",
                                         "level-picker", "play-level", "sound", "replay", "replay-step",
                                         "replay-stop"]
    /// The adjustable elements (increment and decrement).
    static let adjustableNames: [String] = ["star", "wait"]

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await StarlitCartoucheTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                               reduceFlashing: reduceFlashing,
                                                               size: CGSize(width: 360, height: 240))
        _ = shell.presenter.describe(try core(shell))
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: StarlitCartoucheA11yClock = StarlitCartoucheA11yClock()
        shell.presenter.feedback = ExperienceFeedback(hapticSink: haptics, announcementSink: announcements,
                                                      clock: { clock.now }, voiceOverRunning: { true })
        return Recorder(haptics: haptics, announcements: announcements, clock: clock)
    }

    /// Injects a route that records into throwaway sinks with VoiceOver off (no system haptic or announcement).
    static func quiet(_ presenter: Presenter) {
        presenter.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(),
                                                announcementSink: RecordingAnnouncementSink(),
                                                voiceOverRunning: { false })
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try StarlitCartoucheTest.core(shell)
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

    /// One press of the adjustable destination through the presenter, exactly what the panel's increment (`up`) or
    /// decrement sends: `route.choose [nextDestination(±1), wait]`. Returns the result.
    @discardableResult
    static func adjustDestination(_ shell: Shell, _ recorder: Recorder, up: Bool) -> ActionResult {
        let mirror: StarlitCartoucheMirror = shell.presenter.mirror
        let target: Int = mirror.nextDestination(up ? 1 : -1)
        recorder.clock.advance()
        return shell.presenter.send("route.choose", [Double(target), Double(mirror.wait)], port: shell.port)
    }

    /// One press of the adjustable wait through the presenter, exactly what the panel's increment (`up`) or decrement
    /// sends: `route.choose [destination, clampedWait(wait ± 1)]`. Returns the result.
    @discardableResult
    static func adjustWait(_ shell: Shell, _ recorder: Recorder, up: Bool) -> ActionResult {
        let mirror: StarlitCartoucheMirror = shell.presenter.mirror
        let target: Int = mirror.clampedWait(up ? mirror.wait + 1 : mirror.wait - 1)
        recorder.clock.advance()
        return shell.presenter.send("route.choose", [Double(mirror.destination), Double(target)], port: shell.port)
    }

    /// Chooses destination `star` and wait `wait` with the adjustable elements' operations only (the destination by
    /// increments, which wrap; the wait by increments or decrements). Returns the presses made.
    @discardableResult
    static func choose(_ shell: Shell, _ recorder: Recorder, star: Int, wait: Int,
                       sourceLocation: SourceLocation = #_sourceLocation) -> Int {
        let mirror: StarlitCartoucheMirror = shell.presenter.mirror
        var presses: Int = 0
        for _ in 0...mirror.starCount {
            if mirror.destination == star { break }
            let result: ActionResult = adjustDestination(shell, recorder, up: true)
            #expect(result == .accepted, "destination +: \(result.code)", sourceLocation: sourceLocation)
            presses += 1
        }
        for _ in 0..<10 {
            if mirror.wait == wait { break }
            let result: ActionResult = adjustWait(shell, recorder, up: mirror.wait < wait)
            #expect(result == .accepted, "wait ±: \(result.code)", sourceLocation: sourceLocation)
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
        let summary: String = Plan.summaryText(core: new, destination: new.chosenStar, wait: new.chosenWait)
        #expect(presenter.mirror.summary == summary, sourceLocation: sourceLocation)
        return plan
    }

    /// The accepted kernel action `action` (`route.fly [star, wait]`) through ``accepted(_:_:_:_:sourceLocation:)``.
    @discardableResult
    static func accepted(_ shell: Shell, _ recorder: Recorder, _ action: StarlitCartoucheAction,
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let entry: (control: String, values: [Double]) = StarlitCartoucheTest.control(action)
        return try accepted(shell, recorder, entry.control, entry.values, sourceLocation: sourceLocation)
    }

    /// Sends the refused `control` with `values` through the presenter one clock second later; expects a refusal, an
    /// unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), its words in the panel and the
    /// bare code in `refusalLog`. Returns the plan.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: Presenter = shell.presenter
        let digest: String = try StarlitCartoucheTest.digest(shell)
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
        #expect(presenter.refusalLog.last == StarlitCartoucheMirror.bareCode(result.code),
                sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        #expect(try StarlitCartoucheTest.digest(shell) == digest, "a refusal changes nothing",
                sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// `core` with destination `star` and wait `wait` chosen (`route.choose`, presentation only), applied on a copy.
    static func choosing(_ core: Core, star: Int, wait: Int) -> Core {
        var copy: Core = core
        let action: ExperienceAction = ExperienceAction(control: "route.choose", values: [Double(star), Double(wait)],
                                                        step: 0)
        let result: ActionResult = copy.apply(action)
        #expect(result == .accepted, "route.choose \(star) \(wait): \(result.code)")
        return copy
    }

    /// A star of `core` other than the ship's and the chosen one, or nil.
    static func otherStar(_ core: Core) -> Int? {
        let count: Int = core.play.level.stars.count
        for star in 0..<count where star != core.play.star && star != core.chosenStar { return star }
        return nil
    }

    /// The win text of `core`'s won campaign play, built as the plan words it.
    static func winText(_ core: Core) -> String {
        let spent: Int = StarlitCartoucheProgress.actionsSpent(core.play)
        let stars: Int = StarlitCartoucheProgress.stars(actionsSpent: spent, certified: core.certifiedLegs)
        let spentWords: String = spent == 1 ? "1 action" : "\(spent) actions"
        return Plan.wonText + " Level won spending " + spentWords + ", " + String(stars) + " of 3 stars."
    }

    /// Undo and Redo's value as the panel words it: "k actions made of B" ("1 action made" for one).
    static func actionsMade(_ mirror: StarlitCartoucheMirror) -> String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return (made == 1 ? "1 action made" : "\(made) actions made") + " of \(mirror.budget)"
    }

    /// The panel's source text (`Experience/StarlitCartoucheControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("StarlitCartoucheControls.swift")
        return try String(contentsOf: file, encoding: .utf8)
    }

    /// The modifier run of the control with identifier `name` in `source`: the text after the previous
    /// `.accessibilityIdentifier(` (or the start) up to `.accessibilityIdentifier(port.identifier("<name>"))`; nil
    /// when the identifier is missing.
    static func modifierRun(_ name: String, in source: String) -> Substring? {
        let marker: String = ".accessibilityIdentifier(port.identifier(\"" + name + "\"))"
        guard let end = source.range(of: marker) else { return nil }
        let before: Substring = source[source.startIndex..<end.lowerBound]
        let start: String.Index = before.range(of: ".accessibilityIdentifier(", options: .backwards)?.upperBound
            ?? source.startIndex
        return source[start..<end.lowerBound]
    }
}

@MainActor
@Suite(.serialized) struct StarlitCartoucheAccessibilityTests {
    typealias Access = StarlitCartoucheA11y
    typealias Plan = StarlitCartoucheFeedbackPlan
    typealias Presenter = StarlitCartouchePresenter
    typealias Core = StarlitCartoucheExperienceCore

    // MARK: Labels, values and the summary element (FR-R02G1606-001, 005; clarification Q5)

    /// The panel's source gives every control a label and a value before its identifier, and the destination and
    /// the wait an adjustable action; the Sound toggle is labelled and reads "on" or "off".
    @Test func everyControlCarriesALabelAndAValueInTheSource() throws {
        let source: String = try Access.panelSource()
        for name in Access.controlNames {
            let run: Substring? = Access.modifierRun(name, in: source)
            #expect(run != nil, "\(name) has an identifier")
            guard let run else { continue }
            #expect(run.contains(".accessibilityLabel(\""), "\(name) has a label")
            #expect(run.contains(".accessibilityValue("), "\(name) has a value")
        }
        for name in Access.adjustableNames {
            let run: Substring? = Access.modifierRun(name, in: source)
            #expect(run?.contains(".accessibilityAdjustableAction") == true, "\(name) is adjustable")
            #expect(run?.contains("route.choose") == false, "\(name) adjusts through the shared helpers")
        }
        let sound: Substring? = Access.modifierRun("sound", in: source)
        #expect(sound?.contains("mirror.soundOn ? \"on\" : \"off\"") == true, "Sound reads on or off")
        #expect(StarlitCartoucheControls.readableWidth == 520)
    }

    /// After level 1 is described every value the panel reads is non-empty words; the summary element equals
    /// `summaryText(core:destination:wait:)`; the chosen leg reads as the level words it; describing the opening routes
    /// nothing; the sound is off; refusals read in the plan's words.
    @Test func everyControlHasANonEmptyValueInWords() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        Access.quiet(presenter)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: StarlitCartoucheMirror = presenter.mirror
        let instruction: String = mirror.instruction ?? ""
        let hintValue: String = mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3"
        let nextValue: String = mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
            : "no further level open"
        let orbitValue: String = presenter.gestures.orbit == .authored ? "authored" : "orbited"
        let soundValue: String = mirror.soundOn ? "on" : "off"
        let values: [String] = [mirror.legLabel, mirror.summary, mirror.status, mirror.measureLabel,
                                mirror.targetLabel, mirror.goalLabel, instruction,
                                StarlitCartoucheControls.modeName(mirror.mode), Access.actionsMade(mirror), hintValue,
                                nextValue, orbitValue, soundValue, "level \(mirror.pickedLevel)"]
        var index: Int = 0
        for value in values {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "value \(index) is empty")
            index += 1
        }
        #expect(StarlitCartoucheControls.modeName(.campaign) == "campaign")
        #expect(StarlitCartoucheControls.modeName(.practice) == "practice")
        #expect(mirror.budget > 0, "Undo and Redo read the actions made of a positive budget")
        #expect(mirror.actionsLeft == mirror.budget, "no action made at the opening")
        #expect(Access.actionsMade(mirror) == "0 actions made of \(mirror.budget)")
        #expect(nextValue == "no further level open", "before a win")
        #expect(hintValue == "none shown")
        #expect(orbitValue == "authored")
        #expect(soundValue == "off", "the Sound toggle is off by default")
        #expect(mirror.status == "Ready", "\(mirror.status)")

        // The chosen leg reads as the level words it.
        let play: StarlitCartouchePlay = core.play
        #expect(mirror.destination == core.chosenStar)
        #expect(mirror.wait == core.chosenWait)
        #expect(mirror.destination != play.star, "the ship's star is never the destination")
        let leg: String = Plan.legWords(play, destination: mirror.destination, wait: mirror.wait)
        #expect(mirror.legLabel == leg, "\(mirror.legLabel)")

        // The summary element (clarification Q5).
        let summary: String = Plan.summaryText(core: core, destination: core.chosenStar, wait: core.chosenWait)
        #expect(mirror.summary == summary, "\(mirror.summary)")
        #expect(mirror.summary.contains("Chosen: " + leg + "."), "\(mirror.summary)")
        #expect(mirror.summary.contains("Level: " + Plan.levelWords(core) + "."), "\(mirror.summary)")
        #expect(presenter.feedbackLog.isEmpty, "describing the opening plans nothing")

        // Refusals read in the plan's words (clarification Q1), with or without the engine's prefix.
        #expect(StarlitCartoucheMirror.refusalText(code: "action.rule.r02-g16.locked") == "That level is not open yet.")
        #expect(Plan.refused(code: "r02-g16.date").text == "That date cannot be used.")
        #expect(Plan.refused(code: "r02-g16.choice").text == "That destination or wait cannot be chosen.")
        #expect(Plan.refused(code: "r02-g16.not-whole").text == "That value must be a whole number.")
        #expect(Plan.refused(code: "action.out-of-range").text == "That action was refused.")
    }

    /// The adjustable destination (`route.choose [nextDestination(±1), wait]` through the presenter) steps through
    /// every star but the ship's, wrapping; the adjustable wait (`route.choose [destination, clampedWait(wait ± 1)]`)
    /// steps 0 … 8, clamped at both ends; the core's chosen star and wait, the mirror and the summary follow; the
    /// digest stays; nothing is announced and, with the sound off, no audition plays.
    @Test func adjustableDestinationAndWaitChooseThroughRouteChoose() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: StarlitCartoucheMirror = presenter.mirror
        let opening: Core = try Access.core(shell)
        let ship: Int = opening.play.star
        let stars: Int = opening.play.level.stars.count
        try #require(stars >= 3, "level 1 has at least two destinations")
        #expect(mirror.starCount == stars)
        let digest: String = try StarlitCartoucheTest.digest(shell)
        let logBase: Int = presenter.feedbackLog.count
        let first: Int = mirror.destination

        // Increments visit every star but the ship's once and wrap back to the first.
        var visited: Set<Int> = []
        for _ in 0..<(stars - 1) {
            let next: Int = mirror.nextDestination(1)
            #expect(Access.adjustDestination(shell, recorder, up: true) == .accepted)
            let now: Core = try Access.core(shell)
            #expect(mirror.destination == next)
            #expect(now.chosenStar == next, "the increment sends route.choose")
            #expect(next != ship, "the ship's star is skipped")
            #expect(mirror.legLabel == Plan.legWords(now.play, destination: next, wait: mirror.wait))
            #expect(mirror.summary == Plan.summaryText(core: now, destination: next, wait: now.chosenWait))
            visited.insert(next)
        }
        #expect(visited.count == stars - 1, "every destination but the ship's star")
        #expect(mirror.destination == first, "the destination wraps around")
        let previous: Int = mirror.nextDestination(-1)
        #expect(Access.adjustDestination(shell, recorder, up: false) == .accepted)
        #expect(mirror.destination == previous)
        #expect(try Access.core(shell).chosenStar == previous, "the decrement sends route.choose")
        #expect(Access.adjustDestination(shell, recorder, up: true) == .accepted)
        #expect(mirror.destination == first)

        // The wait: clamped at 0, up to 8, clamped at 8, back to 0.
        #expect(mirror.wait == 0, "a level opens with wait 0")
        #expect(Access.adjustWait(shell, recorder, up: false) == .accepted)
        #expect(mirror.wait == 0, "the wait does not go below 0")
        for target in 1...8 {
            #expect(Access.adjustWait(shell, recorder, up: true) == .accepted)
            let now: Core = try Access.core(shell)
            #expect(mirror.wait == target)
            #expect(now.chosenWait == target, "the increment sends route.choose")
            #expect(now.chosenStar == first, "the destination is kept")
            #expect(mirror.summary == Plan.summaryText(core: now, destination: first, wait: target))
        }
        #expect(Access.adjustWait(shell, recorder, up: true) == .accepted)
        #expect(mirror.wait == 8, "the wait does not go past 8")
        for target in stride(from: 7, through: 0, by: -1) {
            #expect(Access.adjustWait(shell, recorder, up: false) == .accepted)
            #expect(mirror.wait == target)
            #expect(try Access.core(shell).chosenWait == target, "the decrement sends route.choose")
        }
        #expect(presenter.feedbackLog.count == logBase, "adjusting plans nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        #expect(try StarlitCartoucheTest.digest(shell) == digest, "choosing never changes the digest")
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off plays no audition")
        #expect(presenter.sound.voice == nil)
    }

    // MARK: The accessibility operations alone (SC-R02G1606-001)

    /// Level 1 (seed 0) is won with the accessibility operations alone: the adjustable destination and wait choose
    /// each certified leg (never announced, no haptic) and Fly sends `route.fly [destination, wait]` through the
    /// presenter; every leg routes exactly `after(old:new:)`; the sinks hold the plans' words and haptics in order; the
    /// last is the win outcome with a success haptic and 3 stars.
    @Test func levelOneWonWithTheAccessibilityOperations() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(1)
        try #require(!legs.isEmpty, "level 1 has a certified plan")
        var expected: [Plan] = []
        var flown: Int = 0

        for action in legs {
            let before: Core = try Access.core(shell)
            guard before.play.stage != .won, before.play.stage != .failed else { break }
            switch action {
            case let .leg(star, wait):
                let logBefore: Int = presenter.feedbackLog.count
                let announcedBefore: Int = recorder.announcements.announced.count
                let playedBefore: Int = recorder.haptics.played.count
                Access.choose(shell, recorder, star: star, wait: wait)
                try #require(presenter.mirror.destination == star, "the adjustable destination reaches star \(star)")
                try #require(presenter.mirror.wait == wait, "the adjustable wait reaches \(wait)")
                #expect(presenter.feedbackLog.count == logBefore, "choosing plans nothing")
                #expect(recorder.announcements.announced.count == announcedBefore, "choosing is not announced")
                #expect(recorder.haptics.played.count == playedBefore, "choosing plays no haptic")
                let mirror: StarlitCartoucheMirror = presenter.mirror
                let plan: Plan = try Access.accepted(shell, recorder, "route.fly",
                                                     [Double(mirror.destination), Double(mirror.wait)])
                expected.append(plan)
                flown += 1
                let now: Core = try Access.core(shell)
                if now.play.stage != .won && now.play.stage != .failed {
                    #expect(plan.kind == .state)
                    #expect(plan.haptic == .selection)
                    let words: String = "Flew to " + now.play.level.starName(star) + " after "
                    #expect(plan.text?.hasPrefix(words) == true, "\(plan.text ?? "nil")")
                }
            }
        }
        #expect(flown == legs.count, "every certified leg was flown")

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        let spent: Int = StarlitCartoucheProgress.actionsSpent(won.play)
        let stars: Int = StarlitCartoucheProgress.stars(actionsSpent: spent, certified: won.certifiedLegs)
        #expect(stars == 3, "the certified plan earns 3 stars")
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(plans.count == legs.count, "every step is announced")
        #expect(plans.last?.text == Access.winText(won), "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.message == nil)
    }

    // MARK: A scripted sequence (SC-R02G1606-002; clarifications Q1, Q2)

    /// On the first level with a failing leg: its set-up legs, a locked `level.next` and the ship's own star chosen
    /// (refusals), the failing leg (outcome, warning), undo (state), a redo restoring the failure (outcome only),
    /// undo, Practice and Campaign (level plans, no haptic), then the certified first leg, undo and redo (state,
    /// selection): the recorded announcements and haptics equal the plans exactly, in order.
    @Test func scriptedSequenceAnnouncesExactlyThePlans() async throws {
        let found = try #require(try StarlitCartoucheTeaching.failureCase(), "a level of 1 … 20 has a failing leg")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: UInt64(found.number - 1))
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let number: Int = found.number
        let band: Int = StarlitCartoucheProgress.band(of: number)
        var expected: [Plan] = []

        for leg in found.setUp {
            let plan: Plan = try Access.accepted(shell, recorder, leg)
            #expect(plan.kind == .state)
            #expect(plan.haptic == .selection)
            expected.append(plan)
        }
        let locked: Plan = try Access.refused(shell, recorder, "level.next", [])
        #expect(locked.text == "That level is not open yet.", "\(locked.text ?? "nil")")
        expected.append(locked)
        let ship: Int = try Access.core(shell).play.star
        let choice: Plan = try Access.refused(shell, recorder, "route.choose", [Double(ship), 0])
        #expect(choice.text == "That destination or wait cannot be chosen.", "\(choice.text ?? "nil")")
        expected.append(choice)

        let failed: Plan = try Access.accepted(shell, recorder, found.failing)
        let failedCore: Core = try Access.core(shell)
        #expect(failedCore.play.stage == .failed)
        #expect(failed.kind == .outcome)
        #expect(failed.haptic == .warning)
        #expect(failed.text == StarlitCartoucheFailureExplanation(play: failedCore.play)?.text)
        expected.append(failed)
        let undone: Plan = try Access.accepted(shell, recorder, "play.undo", [])
        #expect(undone.kind == .state)
        #expect(undone.haptic == .selection)
        #expect(undone.text?.hasPrefix("Undone. ") == true, "\(undone.text ?? "nil")")
        expected.append(undone)
        let restored: Plan = try Access.accepted(shell, recorder, "play.redo", [])
        #expect(try Access.core(shell).play.stage == .failed, "the redo restores the failed moment")
        #expect(restored.kind == .outcome, "a redo restoring a failure plans only the outcome")
        #expect(restored.haptic == .warning)
        expected.append(restored)
        expected.append(try Access.accepted(shell, recorder, "play.undo", []))

        let practice: Plan = try Access.accepted(shell, recorder, "mode.practice", [])
        #expect(practice.kind == .level)
        #expect(practice.haptic == nil, "a level change plays no haptic")
        let practiceWords: String = "Level \(number), band \(band), practice."
        #expect(practice.text?.hasPrefix(practiceWords) == true, "\(practice.text ?? "nil")")
        expected.append(practice)
        let campaign: Plan = try Access.accepted(shell, recorder, "mode.campaign", [])
        #expect(campaign.kind == .level)
        #expect(campaign.haptic == nil)
        let campaignWords: String = "Level \(number), band \(band), campaign."
        #expect(campaign.text?.hasPrefix(campaignWords) == true, "\(campaign.text ?? "nil")")
        expected.append(campaign)

        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(number)
        try #require(legs.count >= 2, "level \(number)'s first certified leg does not win")
        let flew: Plan = try Access.accepted(shell, recorder, legs[0])
        #expect(flew.kind == .state)
        #expect(flew.haptic == .selection)
        #expect(flew.text?.hasPrefix("Flew to ") == true, "\(flew.text ?? "nil")")
        expected.append(flew)
        let undo: Plan = try Access.accepted(shell, recorder, "play.undo", [])
        #expect(undo.text?.hasPrefix("Undone. ") == true, "\(undo.text ?? "nil")")
        expected.append(undo)
        let redo: Plan = try Access.accepted(shell, recorder, "play.redo", [])
        #expect(redo.text?.hasPrefix("Redone. ") == true, "\(redo.text ?? "nil")")
        #expect(redo.haptic == .selection)
        expected.append(redo)

        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(recorder.announcements.announced == Access.texts(expected), "\(recorder.announcements.announced)")
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
    }

    // MARK: Reduce Motion and Reduce Flashing frames (FR-R02G1606-004; SC-R02G1606-003)

    /// Under Reduce Motion, alone and with Reduce Flashing, two stills of the same won state at different frame
    /// times are byte-identical once the fades settle: the firmament is still (angle 0), the ship rests (glide 1) and
    /// the lights rest at the won targets.
    @Test func reduceMotionFramesOfOneStateAreIdentical() async throws {
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(1)
        try #require(!legs.isEmpty, "level 1 has a certified plan")
        let modes: [(motion: Bool, flashing: Bool)] = [(true, false), (true, true)]
        for mode in modes {
            let what: String = mode.flashing ? "Reduce Motion and Reduce Flashing" : "Reduce Motion"
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Access.open(session, seed: 0, reduceMotion: mode.motion,
                                              reduceFlashing: mode.flashing)
            let presenter: Presenter = shell.presenter
            Access.quiet(presenter)
            #expect(presenter.scene.reduceMotion == mode.motion)
            #expect(presenter.scene.reducedFlash == mode.flashing)
            #expect(StarlitCartoucheTest.issue(shell, legs) == legs.count)
            #expect(try Access.core(shell).play.stage == .won)
            let w: Int = Access.stillWidth
            let h: Int = Access.stillHeight
            let base: Double = 10
            // Two first stills let any light fade finish (0.5 s apart, beyond the 0.45 s fade).
            _ = try StarlitCartoucheTest.still(session, width: w, height: h, time: base)
            _ = try StarlitCartoucheTest.still(session, width: w, height: h, time: base + 0.5)
            let early: [UInt8] = try StarlitCartoucheTest.still(session, width: w, height: h, time: base + 0.75)
            let earlyLights: StarlitCartoucheLights = presenter.lights
            let late: [UInt8] = try StarlitCartoucheTest.still(session, width: w, height: h, time: base + 1.9)
            #expect(StarlitCartoucheTest.drawnPixels(early) > 0, "\(what): the still shows the chart")
            #expect(early == late, "\(what): stills at 0.75 s and 1.9 s are identical")
            #expect(presenter.lights == earlyLights, "\(what): the lights do not move")
            #expect(presenter.lights.isSettled, "\(what): the lights rest")
            #expect(presenter.lights.won == 1, "\(what): the won look rests at 1")
            #expect(presenter.lights.glow == StarlitCartoucheLights.glowWon)
            #expect(presenter.scene.lastFirmamentAngle == 0, "\(what): the firmament is still")
            #expect(presenter.lastGlide == 1, "\(what): the ship rests")
        }
    }

    /// Under Reduce Flashing alone (the firmament still turns, so frames differ by its angle only) the eased lights of
    /// the same won state are equal and settled at two frame times once the fade has finished.
    @Test func reduceFlashingAloneHoldsTheLightsBetweenFrames() async throws {
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(1)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0, reduceFlashing: true)
        let presenter: Presenter = shell.presenter
        Access.quiet(presenter)
        #expect(StarlitCartoucheTest.issue(shell, legs) == legs.count)
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        let base: Double = 10
        _ = try StarlitCartoucheTest.still(session, width: w, height: h, time: base)
        _ = try StarlitCartoucheTest.still(session, width: w, height: h, time: base + 0.5)
        let early: StarlitCartoucheLights = presenter.lights
        let earlyAngle: Double = presenter.scene.lastFirmamentAngle
        _ = try StarlitCartoucheTest.still(session, width: w, height: h, time: base + 1.9)
        #expect(presenter.lights == early, "the lights of one state do not move between frames")
        #expect(presenter.lights.isSettled)
        #expect(presenter.lights.won == 1)
        #expect(presenter.scene.lastFirmamentAngle != earlyAngle, "only the firmament turns (Reduce Motion is off)")
    }

    // MARK: The fallback's won look under Reduce Flashing (FR-R02G1606-004; SC-R02G1606-003)

    /// In fallback mode under Reduce Flashing the drawn won level rises over at least 0.4 s of frame time after the
    /// winning leg, sampled every 1/60 s: never falling, below 1 at first, 1 between 0.4 s and 0.5 s; the scene draws
    /// the presenter's lights and the fallback frame changes as the level rises.
    @Test func fallbackWonBrightensSlowlyUnderReduceFlashing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 0, reduceFlashing: true,
                                                        size: CGSize(width: 360, height: 240),
                                                        configure: { presenter in
                                                            presenter.breakChartShader()
                                                        })
        let presenter: Presenter = shell.presenter
        Access.quiet(presenter)
        #expect(presenter.fallbackReason != nil, "the broken program falls back")
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(1)
        let last: StarlitCartoucheAction = try #require(legs.last)
        let setUp: [StarlitCartoucheAction] = Array(legs.dropLast())
        #expect(StarlitCartoucheTest.issue(shell, setUp) == setUp.count)
        try #require(try Access.core(shell).play.stage != .won, "only the last leg wins")
        let w: Int = Access.stillWidth * 2
        let h: Int = Access.stillHeight * 2
        let base: Double = 10
        _ = try StarlitCartoucheTest.still(session, width: w, height: h, time: base - 1)
        _ = try StarlitCartoucheTest.still(session, width: w, height: h, time: base)
        #expect(presenter.lights.won == 0, "the won light rests at 0 while playing")
        #expect(presenter.scene.lights?.won == 0)

        let entry: (control: String, values: [Double]) = StarlitCartoucheTest.control(last)
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
            let rgba: [UInt8] = try StarlitCartoucheTest.still(session, width: w, height: h, time: base + offset)
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
        #expect(StarlitCartoucheTest.drawnPixels(latest) > 0, "the fallback still shows the chart")
        #expect(presenter.fallbackReason != nil)
    }

    // MARK: Sound (FR-R02G1606-006; SC-R02G1606-004; clarification Q4)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations, and an audition plays only
    /// then; the sound off makes no player and no voice; each input turning off stops a playing loop and a sounding
    /// audition; a new player is made only for a different recipe or the toggle turning on.
    @Test func soundStateTable() throws {
        typealias Recipe = StarlitCartoucheSoundRecipe
        let calm: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 0, stage: .playing)
        let lit: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .playing)
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .won)
        try #require(calm != lit, "another drawn quarter sounds different")
        try #require(lit != won, "a won play sounds different")
        let opening: Core = try Core.opening(number: 1)
        let sample: StarlitCartoucheAudition = StarlitCartoucheAudition.of(opening.play, star: opening.chosenStar)
        try #require(!sample.partials.isEmpty, "a destination's audition has tones")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: StarlitCartoucheA11yLoopFactory = StarlitCartoucheA11yLoopFactory()
            let sound: StarlitCartoucheSound = factory.sound(calm)
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
        let toggles: StarlitCartoucheA11yLoopFactory = StarlitCartoucheA11yLoopFactory()
        let live: StarlitCartoucheSound = toggles.sound(calm)
        #expect(!live.wanted, "the sound is off by default")
        #expect(!live.onScreen, "the controls start off screen")
        #expect(live.active, "the scene starts active")
        live.setOnScreen(true)
        live.setWanted(true)
        #expect(live.started)
        #expect(live.audition(sample))
        #expect(live.lastAudition == sample)
        #expect(toggles.voices.first?.played == [sample])
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
        #expect(!live.audition(StarlitCartoucheAudition(partials: [])), "silence plays nothing")
        #expect(live.auditionsPlayed == 1)

        // A failing play() changes nothing else.
        let failing: StarlitCartoucheA11yLoopFactory = StarlitCartoucheA11yLoopFactory()
        failing.succeeds = false
        let silent: StarlitCartoucheSound = failing.sound(calm)
        silent.setOnScreen(true)
        silent.setWanted(true)
        #expect(!silent.started, "a failed play() is not started")
        #expect(silent.shouldPlay)

        // Rebuilds only when the recipe differs.
        let factory: StarlitCartoucheA11yLoopFactory = StarlitCartoucheA11yLoopFactory()
        let sound: StarlitCartoucheSound = factory.sound(calm)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(calm) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(lit)
        #expect(sound.playersMade == 2, "a change of the drawn quarters makes a new player")
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

    /// The presenter's toggle with the controls off screen makes no player, so no audio is touched; choosing a
    /// destination (a described core whose only change is the chosen star) plays no audition while the sound is off,
    /// off screen or inactive; the recipe is offered at the first state and follows a leg, never a choice; only the
    /// leg is announced.
    @Test func presenterSoundOffScreenAndRecipeOffers() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        Access.quiet(presenter)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")
        #expect(Presenter.recipe(opening) == StarlitCartoucheSoundRecipe.recipe(play: opening.play))

        let star: Int = try #require(Access.otherStar(opening), "level 1 has another destination")
        let other: Core = Access.choosing(opening, star: star, wait: opening.chosenWait)
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off: choosing a destination plays no audition")
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        _ = presenter.describe(opening)
        #expect(presenter.sound.auditionsPlayed == 0, "off screen: choosing a destination plays no audition")
        presenter.sceneActive(false)
        presenter.controlsAppeared()
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the loop silent")
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 0, "inactive: choosing a destination plays no audition")
        presenter.controlsDisappeared()
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "a choice keeps the recipe")

        // A leg re-offers the recipe of its play (kept while the loop cannot play).
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(1)
        let firstLeg: StarlitCartoucheAction = try #require(legs.first)
        var flown: Core = other
        let result: ActionResult = flown.apply(StarlitCartoucheTest.experienceAction(firstLeg))
        #expect(result == .accepted, "\(result.code)")
        _ = presenter.describe(flown)
        #expect(presenter.sound.recipe == Presenter.recipe(flown), "the recipe follows the play")
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        presenter.sceneActive(true)
        #expect(presenter.sound.playersMade == 0, "no player was made")
        #expect(presenter.sound.player == nil, "the sound off never touches audio")
        #expect(presenter.sound.voice == nil)
        #expect(presenter.feedbackLog.count == 1, "only the leg is announced; choices are not")
    }

    /// With the sound on, on screen and active, choosing a destination (described) plays
    /// `StarlitCartoucheAudition.of(play, star:)` of the chosen star, one audition per choice; describing the same
    /// core again plays nothing; choosing a wait plays none; with the sound off again a further choice plays nothing.
    /// (This test makes the presenter's real loop and one-shot players.)
    @Test func choosingADestinationPlaysItsAuditionWhenTheSoundIsOn() throws {
        let presenter: Presenter = Presenter(reduceMotion: true, reduceFlashing: false)
        Access.quiet(presenter)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.setSound(on: true)
        presenter.controlsAppeared()
        presenter.sceneActive(true)
        #expect(presenter.sound.shouldPlay)
        #expect(presenter.sound.playersMade == 1, "the toggle turning on screen makes the loop's player")

        let star: Int = try #require(Access.otherStar(opening), "level 1 has another destination")
        let other: Core = Access.choosing(opening, star: star, wait: opening.chosenWait)
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 1, "one choice, one audition")
        #expect(presenter.sound.lastAudition == StarlitCartoucheAudition.of(other.play, star: star))
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 1, "describing the same choice again plays nothing")
        let waited: Core = Access.choosing(other, star: star, wait: 3)
        _ = presenter.describe(waited)
        #expect(presenter.sound.auditionsPlayed == 1, "choosing a wait plays no audition")
        _ = presenter.describe(opening)
        #expect(presenter.sound.auditionsPlayed == 2)
        #expect(presenter.sound.lastAudition == StarlitCartoucheAudition.of(opening.play, star: opening.chosenStar))
        #expect(presenter.sound.playersMade == 1, "a choice never rebuilds the loop")
        #expect(presenter.feedbackLog.isEmpty, "choosing is not announced")

        presenter.setSound(on: false)
        presenter.controlsDisappeared()
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 2, "no audition once the sound is off")
        #expect(!presenter.sound.shouldPlay)
    }
}
#endif
