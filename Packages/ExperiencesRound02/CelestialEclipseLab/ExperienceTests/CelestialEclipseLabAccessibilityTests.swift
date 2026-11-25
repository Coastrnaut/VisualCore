// CelestialEclipseLabAccessibilityTests — feature 466 (R02-G17-06) T-R02G1706-005 (FR-R02G1706-001 … 006;
// SC-R02G1706-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Starlit Cartouche's feature-456 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; the presenter's own
// `feedbackLog` holds every routed plan. Every expected text is built from `CelestialEclipseLabFeedbackPlan`
// (`after(old:new:)`, `refused(code:)`, `summaryText(core:body:phase:)`) on the cores captured before and after each
// step. The tests describe the current core after every action, so the presenter's latest core is the current one;
// describing the same core again routes nothing.
// Labels and values: the `.accessibilityLabel` / `.accessibilityValue` modifiers are not inspectable from a unit test
// (SwiftUI's accessibility tree), so the panel's source is read (`#filePath`): every control's modifier run up to its
// identifier carries a label and a value, the chosen planet and the pending phase an adjustable action, and their
// values are the words of clarification Q5 ("body j, phase p of q", "pending phase p"); every value the panel reads
// from the mirror is non-empty words once level 1 is described, and the summary element equals
// `summaryText(core:body:phase:)`. The adjustable planet sends exactly what its increment and decrement send
// (`orbit.choose [nextBody(±1)]`) through `presenter.send`; the adjustable pending phase moves the mirror's pending
// offset like Phase + and − (`steppedPending(±1)`); neither is announced. Level 1 (seed 0) is won with those
// operations, Set phase (`orbit.phase [body, pending]`) and Run (`clock.run`) alone, following the certified witness,
// every step announced as `after(old:new:)` and the win as an outcome with a success haptic. A scripted sequence on
// level 1 (choosing a body and showing a tick, a refused body, a failed run, undo, a redo restoring the failure, a
// phase change, undo, redo) records exactly the plans' texts and haptics. Reduce Motion, Reduce Flashing and both: two
// stills of the same won state at different frame times hold the halo pulse at 1, keep the eased lights and are
// byte-identical once the fades settle; with neither the pulse follows the frame time. Under Reduce Flashing the won
// level brightens over at least 0.4 s of frame time (sampled at 1/60 s), in the shader path and in fallback mode
// (`breakSkyShader()` before setup); `CelestialEclipseLabSkyScene.blendedColours(off:on:level:)` is checked without a
// host. Sound: the state table (wanted × on screen × active) uses a `CelestialEclipseLabSound` with injected recording
// loops and voices; the presenter's own toggle off screen makes no player; one test turns the presenter's sound on
// screen (the shared ambient loop and one-shot players, ambient session, no input): choosing a body plays its audition,
// showing a tick none. Explicit timestamps, synthetic data, explicit types, plain loops, no nested closure literals, no
// sleep, no wall-clock assertion; each test short.
#if os(iOS)
import CelestialEclipseLabCore
import CoreGraphics
import Foundation
import Testing
@testable import CelestialEclipseLabExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class CelestialEclipseLabA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class CelestialEclipseLabA11yLoop: CelestialEclipseLabLoopPlaying {
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
final class CelestialEclipseLabA11yVoice: CelestialEclipseLabAuditionPlaying {
    /// Every audition played, oldest first.
    private(set) var played: [CelestialEclipseLabAudition] = []
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0

    /// A silent recording voice.
    init() {}

    /// Records `audition`; true when it has partials.
    @discardableResult
    func play(_ audition: CelestialEclipseLabAudition) -> Bool {
        played.append(audition)
        return !audition.partials.isEmpty
    }

    /// Records a stop.
    func stop() { stops += 1 }
}

/// Makes fake loops and voices and keeps them.
@MainActor
final class CelestialEclipseLabA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [CelestialEclipseLabA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []
    /// Every voice made, oldest first.
    private(set) var voices: [CelestialEclipseLabA11yVoice] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> CelestialEclipseLabA11yLoop {
        let loop: CelestialEclipseLabA11yLoop = CelestialEclipseLabA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// Makes and keeps one fake voice.
    func makeVoice() -> CelestialEclipseLabA11yVoice {
        let voice: CelestialEclipseLabA11yVoice = CelestialEclipseLabA11yVoice()
        voices.append(voice)
        return voice
    }

    /// A sound policy starting from `recipe` that makes its players and its voice here.
    func sound(_ recipe: AmbientLoopRecipe) -> CelestialEclipseLabSound {
        CelestialEclipseLabSound(recipe: recipe, makePlayer: { next in self.make(next) },
                                 makeVoice: { self.makeVoice() })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum CelestialEclipseLabA11y {
    typealias Shell = CelestialEclipseLabTest.Shell
    typealias Plan = CelestialEclipseLabFeedbackPlan
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Presenter = CelestialEclipseLabPresenter
    typealias Mirror = CelestialEclipseLabMirror

    /// A recording route on a presenter.
    struct Recorder {
        /// The haptics played, in order.
        let haptics: RecordingHapticSink
        /// The announcements posted, in order.
        let announcements: RecordingAnnouncementSink
        /// The clock of the route.
        let clock: CelestialEclipseLabA11yClock
    }

    /// The still size of the Reduce Motion and fade tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// The controls of the panel by identifier name: each needs a label and a value (clarification Q5). The plain
    /// texts (actions, status, progress, tick, band, stars, goal, the detail lines) are read as text, not controls.
    static let controlNames: [String] = ["sound", "summary", "dismiss-tutorial", "hint", "campaign", "daily",
                                         "practice", "level-picker", "play-level", "planet-minus", "planet",
                                         "planet-plus", "phase-minus", "phase", "phase-plus", "set-phase",
                                         "reset-view", "tick-minus", "tick-plus", "run", "undo", "redo",
                                         "next-level"]
    /// The adjustable elements (increment and decrement).
    static let adjustableNames: [String] = ["planet", "phase"]

    /// Opens level `number` (seed `number − 1`) at a 360 × 240-point view (one frame drawn) and describes the opening
    /// so the presenter holds the latest core.
    static func open(_ session: ExperienceSession, number: Int = 1, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await CelestialEclipseLabTest.open(session, seed: UInt64(number - 1),
                                                                  reduceMotion: reduceMotion,
                                                                  reduceFlashing: reduceFlashing,
                                                                  size: CGSize(width: 360, height: 240))
        let opening: Core = try core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: CelestialEclipseLabA11yClock = CelestialEclipseLabA11yClock()
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
        try CelestialEclipseLabTest.core(shell)
    }

    /// Describes the current core of `shell` (the presenter takes it in once).
    static func describe(_ shell: Shell) throws {
        let current: Core = try core(shell)
        _ = shell.presenter.describe(current)
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

    /// `text` with its first character upper-cased (as the plan starts a sentence with a body's name).
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// The chosen planet's value as the panel words it (clarification Q5): "body j, phase p of q", or "body j, fixed".
    static func chosenValue(_ mirror: Mirror) -> String {
        if mirror.chosenFixed { return "body \(mirror.chosenBody), fixed" }
        return "body \(mirror.chosenBody), phase \(mirror.chosenPhase) of \(mirror.chosenPeriod)"
    }

    /// The pending phase's value as the panel words it (clarification Q5): "pending phase p".
    static func pendingValue(_ mirror: Mirror) -> String {
        "pending phase \(mirror.pendingOffset ?? mirror.chosenPhase)"
    }

    /// The phase line as the panel words it: "phase P", or "phase P → Q" while a phase Q is pending.
    static func phaseLabel(_ mirror: Mirror) -> String {
        guard let pending = mirror.pendingOffset else { return "phase \(mirror.chosenPhase)" }
        return "phase \(mirror.chosenPhase) → \(pending)"
    }

    /// Undo and Redo's value as the panel words it: "k actions made" ("1 action made" for one).
    static func actionsMade(_ mirror: Mirror) -> String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return made == 1 ? "1 action made" : "\(made) actions made"
    }

    /// One press of the adjustable planet through the presenter, exactly what the panel's increment (`up`) or
    /// decrement sends: `orbit.choose [nextBody(±1)]`; then describes the result. Returns the result.
    @discardableResult
    static func adjustPlanet(_ shell: Shell, _ recorder: Recorder, up: Bool) throws -> ActionResult {
        let mirror: Mirror = shell.presenter.mirror
        let target: Int = mirror.nextBody(up ? 1 : -1)
        recorder.clock.advance()
        let result: ActionResult = shell.presenter.send("orbit.choose", [Double(target)], port: shell.port)
        try describe(shell)
        return result
    }

    /// One press of the adjustable pending phase, exactly what the panel's increment (`up`) or decrement does: the
    /// pending phase moved by one modulo the chosen planet's period (presentation only); a fixed planet says why.
    static func adjustPending(_ shell: Shell, up: Bool) {
        let mirror: Mirror = shell.presenter.mirror
        if mirror.chosenFixed {
            mirror.message = CelestialEclipseLabGestureController.fixedReason
            return
        }
        mirror.pendingOffset = mirror.steppedPending(up ? 1 : -1)
    }

    /// Chooses planet `body` with the adjustable planet's increments only (which wrap). Returns the presses made.
    @discardableResult
    static func choose(_ shell: Shell, _ recorder: Recorder, body: Int,
                       sourceLocation: SourceLocation = #_sourceLocation) throws -> Int {
        let mirror: Mirror = shell.presenter.mirror
        var presses: Int = 0
        for _ in 0..<mirror.bodyCount {
            if mirror.chosenBody == body { break }
            let result: ActionResult = try adjustPlanet(shell, recorder, up: true)
            #expect(result == .accepted, "planet +: \(result.code)", sourceLocation: sourceLocation)
            presses += 1
        }
        return presses
    }

    /// Moves the pending phase of the chosen planet to `phase` with the adjustable pending phase's increments only
    /// (which wrap). Returns the presses made.
    @discardableResult
    static func movePending(_ shell: Shell, to phase: Int) -> Int {
        let mirror: Mirror = shell.presenter.mirror
        var presses: Int = 0
        for _ in 0..<mirror.chosenPeriod {
            if mirror.pendingPhase == phase { break }
            adjustPending(shell, up: true)
            presses += 1
        }
        return presses
    }

    /// Sends the accepted `control` with `values` through the presenter one clock second later, describes the new
    /// core, and expects exactly one routed plan equal to `after(old:new:)` of the cores before and after, posted to
    /// the sinks; describing it again routes nothing; the summary follows. Returns the plan.
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
        let phase: Int = new.play.phases.indices.contains(new.chosenBody) ? new.play.phases[new.chosenBody] : 0
        let summary: String = Plan.summaryText(core: new, body: new.chosenBody, phase: phase)
        #expect(presenter.mirror.summary == summary, sourceLocation: sourceLocation)
        return plan
    }

    /// The accepted kernel action `action` through ``accepted(_:_:_:_:sourceLocation:)``.
    @discardableResult
    static func accepted(_ shell: Shell, _ recorder: Recorder, _ action: CelestialEclipseLabAction,
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let entry: (control: String, values: [Double]) = CelestialEclipseLabTest.control(action)
        return try accepted(shell, recorder, entry.control, entry.values, sourceLocation: sourceLocation)
    }

    /// Sends the refused `control` with `values` through the presenter one clock second later; expects a refusal, an
    /// unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), its words in the panel and the
    /// bare code in `refusalLog`. Returns the plan.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: Presenter = shell.presenter
        let digest: String = try CelestialEclipseLabTest.digest(shell)
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
        #expect(presenter.refusalLog.last == Mirror.bareCode(result.code), sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        let after: String = try CelestialEclipseLabTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        try describe(shell)
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }

    /// `core` with planet `body` chosen (`orbit.choose`, presentation only), applied on a copy.
    static func choosing(_ core: Core, body: Int) -> Core {
        var copy: Core = core
        let action: ExperienceAction = ExperienceAction(control: "orbit.choose", values: [Double(body)], step: 0)
        let result: ActionResult = copy.apply(action)
        #expect(result == .accepted, "orbit.choose \(body): \(result.code)")
        return copy
    }

    /// `core` with tick `tick` shown (`clock.show`, presentation only), applied on a copy.
    static func showing(_ core: Core, tick: Int) -> Core {
        var copy: Core = core
        let action: ExperienceAction = ExperienceAction(control: "clock.show", values: [Double(tick)], step: 0)
        let result: ActionResult = copy.apply(action)
        #expect(result == .accepted, "clock.show \(tick): \(result.code)")
        return copy
    }

    /// A body of `core` other than the chosen one, or nil.
    static func otherBody(_ core: Core) -> Int? {
        let count: Int = core.play.level.bodies.count
        for body in 0..<count where body != core.chosenBody { return body }
        return nil
    }

    /// The movable bodies of `core`'s level, in order.
    static func movableBodies(_ core: Core) -> [Int] {
        var result: [Int] = []
        let bodies: [CelestialEclipseLabBody] = core.play.level.bodies
        for index in bodies.indices where !bodies[index].fixed { result.append(index) }
        return result
    }

    /// The win text of `core`'s won campaign play, built as the plan words it.
    static func winText(_ core: Core) -> String {
        let spent: Int = CelestialEclipseLabProgress.actionsSpent(core.play)
        let stars: Int = CelestialEclipseLabProgress.stars(actionsSpent: spent, certified: core.certifiedChanges)
        let spentWords: String = spent == 1 ? "1 action" : "\(spent) actions"
        return Plan.wonText + " Level won spending " + spentWords + ", " + String(stars) + " of 3 stars."
    }

    /// The panel's source text (`Experience/CelestialEclipseLabControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("CelestialEclipseLabControls.swift")
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
@Suite(.serialized) struct CelestialEclipseLabAccessibilityTests {
    typealias Access = CelestialEclipseLabA11y
    typealias Plan = CelestialEclipseLabFeedbackPlan
    typealias Presenter = CelestialEclipseLabPresenter
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Mirror = CelestialEclipseLabMirror

    // MARK: Labels, values and the summary element (FR-R02G1706-001, 005; clarification Q5)

    /// The panel's source gives every control a label and a value before its identifier, and the chosen planet and
    /// the pending phase an adjustable action whose increment and decrement do what Planet ± and Phase ± do, with the
    /// values of clarification Q5; the Sound toggle is labelled and reads "on" or "off".
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
        }
        let planet: Substring? = Access.modifierRun("planet", in: source)
        #expect(planet?.contains(".accessibilityValue(chosenValue)") == true, "the planet reads its chosen value")
        #expect(planet?.contains("adjustPlanet(direction)") == true)
        let phase: Substring? = Access.modifierRun("phase", in: source)
        #expect(phase?.contains(".accessibilityValue(pendingValue)") == true, "the phase reads its pending value")
        #expect(phase?.contains("adjustPhase(direction)") == true)
        let words: [String] = [
            "return \"body \\(mirror.chosenBody), phase \\(mirror.chosenPhase) of \\(mirror.chosenPeriod)\"",
            "\"pending phase \\(mirror.pendingOffset ?? mirror.chosenPhase)\"",
            "case .increment: send(\"orbit.choose\", [Double(mirror.nextBody(1))])",
            "case .decrement: send(\"orbit.choose\", [Double(mirror.nextBody(-1))])",
            "case .increment: movePending(step: 1)",
            "case .decrement: movePending(step: -1)",
            "mirror.pendingOffset = mirror.steppedPending(step)",
        ]
        for word in words {
            #expect(source.contains(word), "the panel's source holds \(word)")
        }
        let sound: Substring? = Access.modifierRun("sound", in: source)
        #expect(sound?.contains("mirror.soundOn ? \"on\" : \"off\"") == true, "Sound reads on or off")
        let summary: Substring? = Access.modifierRun("summary", in: source)
        #expect(summary?.contains(".accessibilityValue(mirror.summary)") == true, "the summary reads the plan's words")
        #expect(CelestialEclipseLabControls.readableWidth == 520)
    }

    /// After level 1 is described every value the panel reads is non-empty words; the summary element equals
    /// `summaryText(core:body:phase:)`; describing the opening routes nothing; the sound is off; refusals read in the
    /// plan's words.
    @Test func everyControlHasANonEmptyValueInWords() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        Access.quiet(presenter)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: Mirror = presenter.mirror
        let tutorial: String = mirror.tutorialText ?? ""
        let hintValue: String = mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3"
        let nextValue: String = mirror.levelNumber < mirror.frontier ? "level \(mirror.levelNumber + 1)"
            : "no further level open"
        let orbitValue: String = presenter.gestures.orbit == .authored ? "authored" : "orbited"
        let soundValue: String = mirror.soundOn ? "on" : "off"
        let modeValue: String = Mirror.modeName(mirror.mode) == "campaign" ? "selected" : "not selected"
        let values: [String] = [mirror.summary, tutorial, hintValue, modeValue, mirror.levelLabel(mirror.pickedLevel),
                                mirror.bodyLabel, Access.chosenValue(mirror), Access.pendingValue(mirror),
                                Access.phaseLabel(mirror), orbitValue, mirror.tickLabel, mirror.measureLabel,
                                Access.actionsMade(mirror), nextValue, soundValue, mirror.status, mirror.goalLabel,
                                mirror.targetLabel]
        var index: Int = 0
        for value in values {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "value \(index) is empty")
            index += 1
        }
        #expect(mirror.budget > 0, "Undo and Redo read the actions made of a positive budget")
        #expect(mirror.actionsLeft == mirror.budget, "no action made at the opening")
        #expect(Access.actionsMade(mirror) == "0 actions made")
        #expect(nextValue == "no further level open", "before a win")
        #expect(hintValue == "none shown")
        #expect(orbitValue == "authored")
        #expect(modeValue == "selected", "the campaign is selected")
        #expect(soundValue == "off", "the Sound toggle is off by default")
        #expect(mirror.status == "Ready", "\(mirror.status)")
        #expect(!mirror.chosenFixed, "a level opens with a movable planet chosen")
        let phase: Int = core.play.phases[core.chosenBody]
        #expect(Access.chosenValue(mirror) == "body \(core.chosenBody), phase \(phase) of \(mirror.chosenPeriod)")
        #expect(Access.pendingValue(mirror) == "pending phase \(phase)")

        // The summary element (clarification Q5).
        let summary: String = Plan.summaryText(core: core, body: core.chosenBody, phase: phase)
        #expect(mirror.summary == summary, "\(mirror.summary)")
        #expect(mirror.summary.contains("Chosen: body \(core.chosenBody) at phase \(phase)."), "\(mirror.summary)")
        #expect(mirror.summary.contains("Level: " + Plan.levelWords(core) + "."), "\(mirror.summary)")
        #expect(presenter.feedbackLog.isEmpty, "describing the opening plans nothing")

        // Refusals read in the plan's words (clarification Q1), with or without the engine's prefix.
        #expect(Mirror.refusalText(code: "action.rule.r02-g17.locked") == "That level is not open yet.")
        #expect(Plan.refused(code: "r02-g17.date").text == "That date cannot be used.")
        #expect(Plan.refused(code: "r02-g17.choice").text == "That body is not in this level.")
        #expect(Plan.refused(code: "r02-g17.tick").text == "That tick is outside the timeline.")
        #expect(Plan.refused(code: "r02-g17.not-whole").text == "That value must be a whole number.")
        #expect(Plan.refused(code: "action.out-of-range").text == "That action was refused.")
    }

    /// The adjustable planet (`orbit.choose [nextBody(±1)]` through the presenter) steps through every movable body,
    /// wrapping, and its value "body j, phase p of q" follows; the adjustable pending phase steps 0 … period − 1,
    /// wrapping, and its value "pending phase p" follows; the digest and the play stay; nothing is announced and, with
    /// the sound off, no audition plays.
    @Test func adjustablePlanetAndPendingPhaseChangeTheirValues() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: Mirror = presenter.mirror
        let opening: Core = try Access.core(shell)
        let movable: [Int] = Access.movableBodies(opening)
        try #require(movable.count >= 2, "level 1 has at least two movable planets")
        let digest: String = try CelestialEclipseLabTest.digest(shell)
        let logBase: Int = presenter.feedbackLog.count
        let first: Int = mirror.chosenBody
        #expect(movable.contains(first), "a level opens with a movable planet chosen")

        // Increments visit every movable planet once and wrap back to the first.
        var visited: Set<Int> = []
        for _ in 0..<movable.count {
            let next: Int = mirror.nextBody(1)
            let result: ActionResult = try Access.adjustPlanet(shell, recorder, up: true)
            #expect(result == .accepted, "\(result.code)")
            let now: Core = try Access.core(shell)
            #expect(mirror.chosenBody == next)
            #expect(now.chosenBody == next, "the increment sends orbit.choose")
            #expect(movable.contains(next), "a fixed planet is skipped")
            let phase: Int = now.play.phases[next]
            let period: Int = now.play.level.bodies[next].period
            #expect(Access.chosenValue(mirror) == "body \(next), phase \(phase) of \(period)")
            #expect(mirror.summary == Plan.summaryText(core: now, body: next, phase: phase))
            visited.insert(next)
        }
        #expect(visited.count == movable.count, "every movable planet")
        #expect(mirror.chosenBody == first, "the planet wraps around")
        let previous: Int = mirror.nextBody(-1)
        let down: ActionResult = try Access.adjustPlanet(shell, recorder, up: false)
        #expect(down == .accepted, "\(down.code)")
        let afterDown: Core = try Access.core(shell)
        #expect(mirror.chosenBody == previous)
        #expect(afterDown.chosenBody == previous, "the decrement sends orbit.choose")
        let back: ActionResult = try Access.adjustPlanet(shell, recorder, up: true)
        #expect(back == .accepted, "\(back.code)")
        #expect(mirror.chosenBody == first)

        // The pending phase: increments wrap through the period back to the current phase.
        let current: Int = mirror.chosenPhase
        let period: Int = mirror.chosenPeriod
        try #require(period >= 2, "the chosen planet has at least two phases")
        #expect(Access.pendingValue(mirror) == "pending phase \(current)", "no change pending at first")
        #expect(!mirror.pendingDiffers)
        for step in 1...period {
            Access.adjustPending(shell, up: true)
            let want: Int = (current + step) % period
            #expect(mirror.pendingPhase == want)
            #expect(Access.pendingValue(mirror) == "pending phase \(want)")
            #expect(mirror.pendingDiffers == (want != current), "Set phase is enabled only for a change")
            #expect(mirror.summary.contains("Chosen: body \(first) at phase \(want)."), "\(mirror.summary)")
        }
        Access.adjustPending(shell, up: false)
        let lower: Int = (current - 1 + period) % period
        #expect(Access.pendingValue(mirror) == "pending phase \(lower)")
        #expect(Access.phaseLabel(mirror) == "phase \(current) → \(lower)")
        #expect(mirror.chosenPhase == current, "the pending phase changes nothing yet")

        // Choosing another planet drops the pending phase.
        let away: ActionResult = try Access.adjustPlanet(shell, recorder, up: true)
        #expect(away == .accepted, "\(away.code)")
        #expect(mirror.pendingOffset == nil, "another planet drops the pending phase")
        let now: Core = try Access.core(shell)
        #expect(now.play == opening.play, "adjusting never changes the play")
        #expect(presenter.feedbackLog.count == logBase, "adjusting plans nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        let after: String = try CelestialEclipseLabTest.digest(shell)
        #expect(after == digest, "choosing never changes the digest")
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off plays no audition")
        #expect(presenter.sound.voice == nil)
    }

    // MARK: The accessibility operations alone (SC-R02G1706-001)

    /// Level 1 (seed 0) is won with the accessibility operations alone, following the certified witness: the
    /// adjustable planet chooses each body and the adjustable pending phase moves to its offset (never announced, no
    /// haptic), Set phase sends `orbit.phase [body, pending]` and Run `clock.run` through the presenter; every step
    /// routes exactly `after(old:new:)`; the sinks hold the plans' words and haptics in order; the last is the win
    /// outcome with a success haptic and 3 stars.
    @Test func levelOneWonWithTheAccessibilityOperations() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        let plan: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(1)
        try #require(!plan.isEmpty, "level 1 has a certified plan")
        var expected: [Plan] = []
        var changes: Int = 0

        for action in plan {
            guard case let .phase(body, offset) = action else { continue }
            let logBefore: Int = presenter.feedbackLog.count
            let announcedBefore: Int = recorder.announcements.announced.count
            let playedBefore: Int = recorder.haptics.played.count
            try Access.choose(shell, recorder, body: body)
            try #require(presenter.mirror.chosenBody == body, "the adjustable planet reaches body \(body)")
            Access.movePending(shell, to: offset)
            try #require(presenter.mirror.pendingPhase == offset, "the adjustable phase reaches \(offset)")
            try #require(presenter.mirror.pendingDiffers, "Set phase is enabled")
            #expect(presenter.feedbackLog.count == logBefore, "choosing plans nothing")
            #expect(recorder.announcements.announced.count == announcedBefore, "choosing is not announced")
            #expect(recorder.haptics.played.count == playedBefore, "choosing plays no haptic")
            let mirror: Mirror = presenter.mirror
            let step: Plan = try Access.accepted(shell, recorder, "orbit.phase",
                                                 [Double(mirror.chosenBody), Double(mirror.pendingPhase)])
            expected.append(step)
            changes += 1
            #expect(step.kind == .state)
            #expect(step.haptic == .selection)
            let words: String = Access.capitalised(opening.play.level.bodyName(body)) + " set to phase \(offset). "
            #expect(step.text?.hasPrefix(words) == true, "\(step.text ?? "nil")")
            #expect(presenter.mirror.pendingOffset == nil, "Set phase drops the pending phase")
        }
        #expect(changes == opening.certifiedChanges, "every certified change was set")
        let before: Core = try Access.core(shell)
        try #require(before.play.timeline.wins, "a run now would win")
        let run: Plan = try Access.accepted(shell, recorder, "clock.run", [])
        expected.append(run)

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won, "\(won.play.stage)")
        let spent: Int = CelestialEclipseLabProgress.actionsSpent(won.play)
        let stars: Int = CelestialEclipseLabProgress.stars(actionsSpent: spent, certified: won.certifiedChanges)
        #expect(stars == 3, "the certified plan earns 3 stars")
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(plans.count == changes + 1, "every step is announced")
        #expect(plans.last?.text == Access.winText(won), "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.message == nil)
    }

    // MARK: A scripted sequence (SC-R02G1706-002; clarifications Q1, Q2)

    /// On level 1: choosing another body and showing a tick (nothing routed), a body the level lacks
    /// (`orbit.choose`, "That body is not in this level.", rejection, error), a tick outside the timeline when the
    /// declared range allows sending it, the run at the opening (a failure: outcome, warning), undo (state), a redo
    /// restoring the failure (outcome only), undo, then the certified first phase change, undo and redo (state,
    /// selection): the recorded announcements and haptics equal the plans exactly, in order.
    @Test func scriptedSequenceAnnouncesExactlyThePlans() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        let level: CelestialEclipseLabLevel = opening.play.level
        var expected: [Plan] = []

        // Choosing a body and showing a tick route nothing.
        let other: Int = try #require(Access.otherBody(opening), "level 1 has another body")
        recorder.clock.advance()
        let chose: ActionResult = presenter.send("orbit.choose", [Double(other)], port: shell.port)
        #expect(chose == .accepted, "\(chose.code)")
        try Access.describe(shell)
        try #require(level.horizon >= 2, "level 1 has at least two ticks")
        recorder.clock.advance()
        let shown: ActionResult = presenter.send("clock.show", [1], port: shell.port)
        #expect(shown == .accepted, "\(shown.code)")
        try Access.describe(shell)
        #expect(presenter.feedbackLog.count == logBase, "choosing a body or showing a tick routes nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)

        // Refusals.
        try #require(level.bodies.count <= Core.bodyRange.upperBound, "a body index the level lacks can be sent")
        let missing: Plan = try Access.refused(shell, recorder, "orbit.choose", [Double(level.bodies.count)])
        #expect(missing.text == "That body is not in this level.", "\(missing.text ?? "nil")")
        expected.append(missing)
        if level.horizon <= Core.tickRange.upperBound {
            let outside: Plan = try Access.refused(shell, recorder, "clock.show", [Double(level.horizon)])
            #expect(outside.text == "That tick is outside the timeline.", "\(outside.text ?? "nil")")
            expected.append(outside)
        }

        // The run at the opening fails.
        let failed: Plan = try Access.accepted(shell, recorder, "clock.run", [])
        let failedCore: Core = try Access.core(shell)
        #expect(failedCore.play.stage == .failed, "\(failedCore.play.stage)")
        #expect(failed.kind == .outcome)
        #expect(failed.haptic == .warning)
        #expect(failed.text == CelestialEclipseLabFailureExplanation(play: failedCore.play)?.text)
        expected.append(failed)
        let undone: Plan = try Access.accepted(shell, recorder, "play.undo", [])
        #expect(undone.kind == .state)
        #expect(undone.haptic == .selection)
        #expect(undone.text?.hasPrefix("Undone. ") == true, "\(undone.text ?? "nil")")
        expected.append(undone)
        let restored: Plan = try Access.accepted(shell, recorder, "play.redo", [])
        let restoredCore: Core = try Access.core(shell)
        #expect(restoredCore.play.stage == .failed, "the redo restores the failed moment")
        #expect(restored.kind == .outcome, "a redo restoring a failure plans only the outcome")
        #expect(restored.haptic == .warning)
        expected.append(restored)
        expected.append(try Access.accepted(shell, recorder, "play.undo", []))

        // A phase change, undo and redo.
        let plan: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(1)
        let change: CelestialEclipseLabAction = try #require(plan.first, "level 1 has a certified phase change")
        guard case let .phase(body, offset) = change else {
            Issue.record("the certified plan starts with a phase change")
            return
        }
        let set: Plan = try Access.accepted(shell, recorder, change)
        #expect(set.kind == .state)
        #expect(set.haptic == .selection)
        let words: String = Access.capitalised(level.bodyName(body)) + " set to phase \(offset). "
        #expect(set.text?.hasPrefix(words) == true, "\(set.text ?? "nil")")
        expected.append(set)
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

    // MARK: Reduce Motion and Reduce Flashing frames (FR-R02G1706-004; SC-R02G1706-003)

    /// Under Reduce Motion, Reduce Flashing and both, two stills of the same won state at different frame times hold
    /// the halo pulse at 1, keep the eased lights at the won targets and are byte-identical once the fades settle.
    @Test func reducedFramesOfOneStateAreStill() async throws {
        let plan: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(1)
        let actions: [CelestialEclipseLabAction] = plan + [.run]
        let modes: [(motion: Bool, flashing: Bool)] = [(true, false), (false, true), (true, true)]
        for mode in modes {
            let what: String = "Reduce Motion \(mode.motion), Reduce Flashing \(mode.flashing)"
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Access.open(session, number: 1, reduceMotion: mode.motion,
                                              reduceFlashing: mode.flashing)
            let presenter: Presenter = shell.presenter
            Access.quiet(presenter)
            #expect(presenter.scene.reduceMotion == mode.motion)
            #expect(presenter.scene.reducedFlash == mode.flashing)
            #expect(presenter.scene.halosStill, "\(what): the halos hold still")
            #expect(CelestialEclipseLabTest.issue(shell, actions) == actions.count)
            let won: Core = try Access.core(shell)
            #expect(won.play.stage == .won, "\(what): \(won.play.stage)")
            let w: Int = Access.stillWidth
            let h: Int = Access.stillHeight
            let base: Double = 10
            // Two first stills let any light fade finish (0.5 s apart, beyond the 0.45 s fade).
            _ = try CelestialEclipseLabTest.still(session, width: w, height: h, time: base)
            _ = try CelestialEclipseLabTest.still(session, width: w, height: h, time: base + 0.5)
            let early: [UInt8] = try CelestialEclipseLabTest.still(session, width: w, height: h, time: base + 0.75)
            let earlyPulse: Double = presenter.scene.lastPulse
            let earlyLights: CelestialEclipseLabLights = presenter.lights
            let late: [UInt8] = try CelestialEclipseLabTest.still(session, width: w, height: h, time: base + 1.9)
            #expect(CelestialEclipseLabTest.drawnPixels(early) > 0, "\(what): the still shows the sky")
            #expect(earlyPulse == 1, "\(what): the pulse is held at 1")
            #expect(presenter.scene.lastPulse == 1, "\(what): the pulse is held at 1")
            #expect(presenter.lights == earlyLights, "\(what): the lights do not move")
            #expect(presenter.lights.isSettled, "\(what): the lights rest")
            #expect(presenter.lights.won == 1, "\(what): the won look rests at 1")
            #expect(presenter.lights.glow == CelestialEclipseLabLights.glowWon)
            #expect(early == late, "\(what): stills at 0.75 s and 1.9 s are identical")
        }
    }

    /// With neither setting the halo pulse follows the frame time (`haloPulse(time:reduceMotion:)`), so two frame
    /// times of the same state draw different pulses while the lights rest.
    @Test func fullMotionPulseVariesWithTime() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        Access.quiet(presenter)
        #expect(!presenter.scene.halosStill)
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        let times: [Double] = [10.75, 11.9]
        var pulses: [Double] = []
        for time in times {
            _ = try CelestialEclipseLabTest.still(session, width: w, height: h, time: time)
            let want: Double = CelestialEclipseLabShaders.haloPulse(time: time, reduceMotion: false)
            #expect(Swift.abs(presenter.scene.lastPulse - want) < 1e-12, "the pulse at \(time) s")
            pulses.append(presenter.scene.lastPulse)
        }
        #expect(pulses[0] != pulses[1], "the pulse varies with time: \(pulses)")
        #expect(presenter.lights.isSettled)
    }

    // MARK: The won look under Reduce Flashing (FR-R02G1706-004; SC-R02G1706-003; clarification Q3)

    /// Under Reduce Flashing, in the shader path and in fallback mode, the drawn won level rises over at least 0.4 s
    /// of frame time after the winning run, sampled every 1/60 s: never falling, below 1 at first, 1 between 0.4 s
    /// and 0.5 s; the scene draws the presenter's lights and the frame changes as the level rises.
    @Test func wonBrightensSlowlyUnderReduceFlashing() async throws {
        let plan: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(1)
        for broken in [false, true] {
            let what: String = broken ? "fallback" : "shader"
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await CelestialEclipseLabTest.open(session, seed: 0, reduceFlashing: true,
                                                               size: CGSize(width: 360, height: 240),
                                                               configure: { (presenter: Presenter) in
                                                                   if broken { presenter.breakSkyShader() }
                                                               })
            let presenter: Presenter = shell.presenter
            Access.quiet(presenter)
            #expect((presenter.fallbackReason != nil) == broken, "\(what): \(presenter.fallbackReason ?? "nil")")
            #expect(CelestialEclipseLabTest.issue(shell, plan) == plan.count)
            let playing: Core = try Access.core(shell)
            try #require(playing.play.stage != .won, "\(what): only the run wins")
            let w: Int = Access.stillWidth * 2
            let h: Int = Access.stillHeight * 2
            let base: Double = 10
            _ = try CelestialEclipseLabTest.still(session, width: w, height: h, time: base - 1)
            _ = try CelestialEclipseLabTest.still(session, width: w, height: h, time: base)
            #expect(presenter.lights.won == 0, "\(what): the won light rests at 0 while playing")
            #expect(presenter.scene.lights?.won == 0)

            let winning: ActionResult = shell.handle(control: "clock.run", values: [])
            #expect(winning == .accepted, "\(what): \(winning.code)")
            let won: Core = try Access.core(shell)
            #expect(won.play.stage == .won, "\(what): \(won.play.stage)")

            let frame: Double = 1.0 / 60
            var previous: Double = 0
            var reachedAt: Double?
            var first: [UInt8] = []
            var latest: [UInt8] = []
            for step in 1...36 {
                let offset: Double = Double(step) * frame
                let rgba: [UInt8] = try CelestialEclipseLabTest.still(session, width: w, height: h,
                                                                      time: base + offset)
                if step == 1 { first = rgba }
                latest = rgba
                let level: Double = presenter.lights.won
                #expect(presenter.scene.lights?.won == level, "\(what): the scene draws the lights at \(offset) s")
                #expect(level >= previous, "\(what): the won level never falls: \(level) after \(previous)")
                if step == 1 { #expect(level > 0 && level < 1, "\(what): the brightening starts gradually: \(level)") }
                if reachedAt == nil && level >= 1 { reachedAt = offset }
                previous = level
            }
            let reached: Double = try #require(reachedAt, "\(what): the won level reaches 1 within 0.6 s")
            #expect(reached >= 0.4, "\(what): the won brightening takes at least 0.4 s: reached 1 at \(reached) s")
            #expect(reached <= 0.5, "\(what): the won brightening settles by 0.5 s: reached 1 at \(reached) s")
            #expect(presenter.lights.isSettled)
            #expect(first != latest, "\(what): the won look changes as the level rises")
            #expect(CelestialEclipseLabTest.drawnPixels(latest) > 0, "\(what): the still shows the sky")
            #expect((presenter.fallbackReason != nil) == broken)
        }
    }

    /// The fallback's colour blend without a host: parts of equal size move each colour toward the won colour by the
    /// level, clamped to 0 … 1 (a non-finite level reads 0); parts of different sizes switch whole at 0.5.
    @Test func blendedColoursLerpClampAndSwitch() {
        typealias Scene = CelestialEclipseLabSkyScene
        let off: [Vec4] = [Vec4(0, 0, 0, 1), Vec4(1, 0, 0, 1)]
        let on: [Vec4] = [Vec4(1, 1, 1, 1), Vec4(0, 1, 0, 1)]
        let quarter: [Vec4] = Scene.blendedColours(off: off, on: on, level: 0.25)
        #expect(quarter == [Vec4(0.25, 0.25, 0.25, 1), Vec4(0.75, 0.25, 0, 1)], "\(quarter)")
        let half: [Vec4] = Scene.blendedColours(off: off, on: on, level: 0.5)
        #expect(half == [Vec4(0.5, 0.5, 0.5, 1), Vec4(0.5, 0.5, 0, 1)], "\(half)")
        #expect(Scene.blendedColours(off: off, on: on, level: 0) == off)
        #expect(Scene.blendedColours(off: off, on: on, level: 1) == on)
        #expect(Scene.blendedColours(off: off, on: on, level: -2) == off, "a level below 0 reads 0")
        #expect(Scene.blendedColours(off: off, on: on, level: 7) == on, "a level above 1 reads 1")
        #expect(Scene.blendedColours(off: off, on: on, level: .nan) == off, "a non-finite level reads 0")
        #expect(Scene.blendedColours(off: off, on: on, level: .infinity) == off, "a non-finite level reads 0")
        let single: [Vec4] = [Vec4(1, 1, 1, 1)]
        #expect(Scene.blendedColours(off: off, on: single, level: 0.49) == off, "different sizes: off below 0.5")
        #expect(Scene.blendedColours(off: off, on: single, level: 0.5) == single, "different sizes: on from 0.5")
        #expect(Scene.blendedColours(off: off, on: single, level: 1) == single)
        #expect(Scene.blendedColours(off: [], on: [], level: 0.3).isEmpty)
    }

    // MARK: Sound (FR-R02G1706-006; SC-R02G1706-004; clarification Q4)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations, and an audition plays only
    /// then; the sound off makes no player and no voice; each input turning off stops a playing loop and a sounding
    /// audition; a new player is made only for a different recipe or the toggle turning on.
    @Test func soundStateTable() throws {
        typealias Recipe = CelestialEclipseLabSoundRecipe
        let calm: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 0, stage: .playing)
        let lit: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .playing)
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .won)
        try #require(calm != lit, "another matched quarter sounds different")
        try #require(lit != won, "a won play sounds different")
        let opening: Core = try Core.opening(number: 1)
        let sample: CelestialEclipseLabAudition = CelestialEclipseLabAudition.of(opening.play, body: opening.chosenBody)
        try #require(!sample.partials.isEmpty, "a body's audition has tones")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: CelestialEclipseLabA11yLoopFactory = CelestialEclipseLabA11yLoopFactory()
            let sound: CelestialEclipseLabSound = factory.sound(calm)
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
        let toggles: CelestialEclipseLabA11yLoopFactory = CelestialEclipseLabA11yLoopFactory()
        let live: CelestialEclipseLabSound = toggles.sound(calm)
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
        #expect(!live.audition(CelestialEclipseLabAudition(partials: [])), "silence plays nothing")
        #expect(live.auditionsPlayed == 1)

        // A failing play() changes nothing else.
        let failing: CelestialEclipseLabA11yLoopFactory = CelestialEclipseLabA11yLoopFactory()
        failing.succeeds = false
        let silent: CelestialEclipseLabSound = failing.sound(calm)
        silent.setOnScreen(true)
        silent.setWanted(true)
        #expect(!silent.started, "a failed play() is not started")
        #expect(silent.shouldPlay)

        // Rebuilds only when the recipe differs.
        let factory: CelestialEclipseLabA11yLoopFactory = CelestialEclipseLabA11yLoopFactory()
        let sound: CelestialEclipseLabSound = factory.sound(calm)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(calm) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(lit)
        #expect(sound.playersMade == 2, "a change of the matched quarters makes a new player")
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

    /// The presenter's toggle with the controls off screen makes no player, so no audio is touched; choosing a body
    /// (a described core whose only change is the chosen body) plays no audition while the sound is off, off screen
    /// or inactive; the recipe is offered at the first state and follows a phase change, never a choice; only the
    /// phase change is announced.
    @Test func presenterSoundOffScreenAndRecipeOffers() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        Access.quiet(presenter)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")
        #expect(Presenter.recipe(opening) == CelestialEclipseLabSoundRecipe.recipe(play: opening.play))

        let body: Int = try #require(Access.otherBody(opening), "level 1 has another body")
        let other: Core = Access.choosing(opening, body: body)
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off: choosing a body plays no audition")
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        _ = presenter.describe(opening)
        #expect(presenter.sound.auditionsPlayed == 0, "off screen: choosing a body plays no audition")
        presenter.sceneActive(false)
        presenter.controlsAppeared()
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the loop silent")
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 0, "inactive: choosing a body plays no audition")
        presenter.controlsDisappeared()
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "a choice keeps the recipe")

        // A phase change re-offers the recipe of its play (kept while the loop cannot play).
        let plan: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(1)
        let change: CelestialEclipseLabAction = try #require(plan.first)
        var changed: Core = other
        let result: ActionResult = changed.apply(CelestialEclipseLabTest.experienceAction(change))
        #expect(result == .accepted, "\(result.code)")
        _ = presenter.describe(changed)
        #expect(presenter.sound.recipe == Presenter.recipe(changed), "the recipe follows the play")
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        presenter.sceneActive(true)
        #expect(presenter.sound.playersMade == 0, "no player was made")
        #expect(presenter.sound.player == nil, "the sound off never touches audio")
        #expect(presenter.sound.voice == nil)
        #expect(presenter.feedbackLog.count == 1, "only the phase change is announced; choices are not")
    }

    /// With the sound on, on screen and active, choosing a body (described) plays
    /// `CelestialEclipseLabAudition.of(play, body:)` of the chosen body, one audition per choice; describing the same
    /// core again plays nothing; showing a tick plays none; with the sound off again a further choice plays nothing.
    /// (This test makes the presenter's real loop and one-shot players.)
    @Test func choosingABodyPlaysItsAuditionWhenTheSoundIsOn() throws {
        let presenter: Presenter = Presenter(reduceMotion: true, reduceFlashing: false)
        Access.quiet(presenter)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.setSound(on: true)
        presenter.controlsAppeared()
        presenter.sceneActive(true)
        #expect(presenter.sound.shouldPlay)
        #expect(presenter.sound.playersMade == 1, "the toggle turning on screen makes the loop's player")

        let body: Int = try #require(Access.otherBody(opening), "level 1 has another body")
        let other: Core = Access.choosing(opening, body: body)
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 1, "one choice, one audition")
        #expect(presenter.sound.lastAudition == CelestialEclipseLabAudition.of(other.play, body: body))
        _ = presenter.describe(other)
        #expect(presenter.sound.auditionsPlayed == 1, "describing the same choice again plays nothing")
        try #require(other.play.level.horizon >= 2, "level 1 has at least two ticks")
        let ticked: Core = Access.showing(other, tick: 1)
        _ = presenter.describe(ticked)
        #expect(presenter.sound.auditionsPlayed == 1, "showing a tick plays no audition")
        _ = presenter.describe(opening)
        #expect(presenter.sound.auditionsPlayed == 2)
        let want: CelestialEclipseLabAudition = CelestialEclipseLabAudition.of(opening.play, body: opening.chosenBody)
        #expect(presenter.sound.lastAudition == want)
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
