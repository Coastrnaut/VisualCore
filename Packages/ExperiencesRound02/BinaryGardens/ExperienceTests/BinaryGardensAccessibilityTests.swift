// BinaryGardensAccessibilityTests — feature 506 (R02-G21-06) T-R02G2106-005 (FR-R02G2106-001 … 008;
// SC-R02G2106-001 … 005; clarifications Q1–Q6). On the simulator, through the one app's session host, ported from
// Mushroom Weather's feature-496 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; the presenter's own
// `feedbackLog` holds every routed plan. Every expected text is built from `BinaryGardensFeedbackPlan`
// (`after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `hint(text:)`, `summaryText(core:star:)`) on the cores
// captured before and after each step. The tests describe the current core after every action, so the presenter's
// latest core is the current one; describing the same core again routes nothing.
// Labels and values: the `.accessibilityLabel` / `.accessibilityValue` modifiers are not inspectable from a unit test
// (SwiftUI's accessibility tree), so the panel's source is read (`#filePath`): every control's modifier run up to its
// identifier carries a label and a value; the star, ring, phase, luminosity, tilt and shown tick carry an adjustable
// action with the words of clarification Q5 ("star n of 2", "ring r of R, ρ units", "phase p of 47, step g", "level l
// of m, luminosity L", "tilt t of T steps", "tick t of 48", ", locked" for a locked control); Sound reads "on" or
// "off", the summary element the plan's words. Every value the panel reads from the mirror is non-empty words once
// level 1 is described. The adjustable star clamps to 0 … 1 and the shown tick wraps over 1 … 48 (presentation only,
// never announced); the adjustable ring, phase, luminosity and tilt (the panel's closures replayed) send one action
// each, announced as `after(old:new:)` when accepted and as the refusal's sentence when refused. Level 1 (seed 0) is
// won with the accessibility operations alone, following its certified plan (the adjustable star, the adjustable or
// chosen ring, luminosity and tilt, the phase target and Set phase, then Run); every step is announced as
// `after(old:new:)` and the win as an outcome with a success haptic and 3 stars. A scripted sequence on level 1 (a
// shown tick, refusals of every reachable kind, a failed run, a refusal after it, undo, a redo restoring the failure,
// undo, the first certified action, undo and redo) and a revealed hint record exactly the plans' texts and haptics;
// every refusal reads the plan's sentence with an error haptic and the panel shows exactly that sentence. Frames: with
// Reduce Motion, Reduce Flashing or both, `u_motion` is 0, so two stills of the same won state at different frame
// times keep the eased lights at the won targets and are byte-identical. Under Reduce Flashing the won level brightens
// over at least 0.4 s of frame time (sampled at 1/60 s), in the shader path and in fallback mode (`breakSystemShader()`
// before setup; the fallback system is rebuilt per tenth of the level, not per frame);
// `BinaryGardensSystemScene.blendedColours(off:on:level:)` is checked without a host. Sound: the state table (wanted ×
// on screen × active) uses a `BinaryGardensSound` with injected recording loops and voices; the presenter's own toggle
// off, off screen or inactive plays no audition and makes no player; one test turns the presenter's sound on screen
// (the shared ambient loop and one-shot players): a change of the selected star plays
// `BinaryGardensAudition.of(ring:canChange:)` once, an accepted ring change of the selected star once, a ring change of
// the other star, a phase change and a preview none. Tiers: the same scripted session at level-0, level-1, level-2 and
// in the fallback gives equal feedback logs, and a tier change or a memory warning resets no eased level, feedback log
// or sound state. Explicit timestamps, synthetic data, explicit types, plain loops, no sleep (except the bounded
// hint-search poll of the teaching helpers), no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import BinaryGardensCore
import CoreGraphics
import Foundation
import Testing
@testable import BinaryGardensExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class BinaryGardensA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class BinaryGardensA11yLoop: BinaryGardensLoopPlaying {
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
final class BinaryGardensA11yVoice: BinaryGardensAuditionPlaying {
    /// Every audition played, oldest first.
    private(set) var played: [BinaryGardensAudition] = []
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0

    /// A silent recording voice.
    init() {}

    /// Records `audition`; true when it has partials.
    @discardableResult
    func play(_ audition: BinaryGardensAudition) -> Bool {
        played.append(audition)
        return !audition.partials.isEmpty
    }

    /// Records a stop.
    func stop() { stops += 1 }
}

/// Makes fake loops and voices and keeps them.
@MainActor
final class BinaryGardensA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [BinaryGardensA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []
    /// Every voice made, oldest first.
    private(set) var voices: [BinaryGardensA11yVoice] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> BinaryGardensA11yLoop {
        let loop: BinaryGardensA11yLoop = BinaryGardensA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// Makes and keeps one fake voice.
    func makeVoice() -> BinaryGardensA11yVoice {
        let voice: BinaryGardensA11yVoice = BinaryGardensA11yVoice()
        voices.append(voice)
        return voice
    }

    /// A sound policy starting from `recipe` that makes its players and its voice here.
    func sound(_ recipe: AmbientLoopRecipe) -> BinaryGardensSound {
        let player: (AmbientLoopRecipe) -> any BinaryGardensLoopPlaying = { (next: AmbientLoopRecipe) in
            self.make(next)
        }
        let voice: () -> any BinaryGardensAuditionPlaying = { self.makeVoice() }
        return BinaryGardensSound(recipe: recipe, makePlayer: player, makeVoice: voice)
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum BinaryGardensA11y {
    typealias Shell = BinaryGardensTest.Shell
    typealias Plan = BinaryGardensFeedbackPlan
    typealias Core = BinaryGardensExperienceCore
    typealias Presenter = BinaryGardensPresenter
    typealias Mirror = BinaryGardensMirror
    typealias Action = BinaryGardensAction

    /// A recording route on a presenter.
    struct Recorder {
        /// The haptics played, in order.
        let haptics: RecordingHapticSink
        /// The announcements posted, in order.
        let announcements: RecordingAnnouncementSink
        /// The clock of the route.
        let clock: BinaryGardensA11yClock
    }

    /// The still size of the frame tests (aspect 1.5, the open view's).
    nonisolated static let stillWidth: Int = 96
    nonisolated static let stillHeight: Int = 64
    /// The impossible day of the refusal script (2027 is not a leap year).
    nonisolated static let impossibleDate: [Double] = [2027, 2, 29]

    /// The controls of the panel by identifier name: each needs a label and a value (clarification Q5). The plain
    /// texts (actions, status, failure, progress, message, preview refusal, star and tick detail lines, inspected
    /// words, tutorial, hint text, band, stars, goal, mode) are read as text, not controls.
    nonisolated static let controlNames: [String] = [
        "sound", "summary", "dismiss-tutorial", "hint", "star", "ring-minus", "ring", "ring-plus", "phase-minus",
        "phase", "phase-plus", "luminosity-minus", "luminosity", "luminosity-plus", "tilt-minus", "tilt", "tilt-plus",
        "tick-minus", "tick", "tick-plus", "run", "undo", "redo", "next-level", "ring-choice", "luminosity-choice",
        "phase-target", "set-phase", "tilt-choice", "inspect", "reset-view", "campaign", "daily", "practice",
        "level-picker", "play-level",
    ]
    /// The adjustable elements (increment and decrement) with the value each reads.
    nonisolated static let adjustables: [(name: String, value: String, call: String)] = [
        ("star", ".accessibilityValue(mirror.starValue)", "adjust(direction, star: true)"),
        ("ring", ".accessibilityValue(mirror.ringValue)", "adjust(direction, ring: true)"),
        ("phase", ".accessibilityValue(mirror.phaseValue)", "adjust(direction, phase: true)"),
        ("luminosity", ".accessibilityValue(mirror.luminosityValue)", "adjust(direction, luminosity: true)"),
        ("tilt", ".accessibilityValue(mirror.tiltValue)", "adjust(direction, tilt: true)"),
        ("tick", ".accessibilityValue(mirror.tickValue)", "adjust(direction, tick: true)"),
    ]

    /// The refusal codes of clarification Q1 with their sentences; any other code reads "That action was refused.".
    nonisolated static let refusalSentences: [(code: String, text: String)] = [
        ("r02-g21.locked", "That level is not open yet."),
        ("r02-g21.date", "That date cannot be used."),
        ("r02-g21.action", "That ring, phase, brightness or tilt change cannot be made (locked, unchanged, off the "
            + "phase grid or too close to the other star), or there is nothing to undo or redo."),
        ("r02-g21.budget", "No actions are left: run the light or undo a change."),
        ("r02-g21.stage", "The level has ended."),
        ("r02-g21.stale", "The play changed before the action arrived."),
        ("r02-g21.level", "That level could not be made."),
        ("r02-g21.generation", "That level could not be made."),
        ("r02-g21.not-whole", "That value must be a whole number."),
        ("r02-g21.tick", "Only ticks 1 to 48 can be shown."),
        ("r02-g21.malformed", "That action was refused."),
        ("r02-g21.witness", "That action was refused."),
        ("action.out-of-range", "That action was refused."),
    ]

    /// Opens level `number` (seed `number − 1`) at a 360 × 240-point view (one frame drawn, tick 48 shown) and
    /// describes the opening so the presenter holds the latest core. `configure` runs on the presenter before setup.
    static func open(_ session: ExperienceSession, number: Int = 1, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false,
                     configure: ((Presenter) -> Void)? = nil) async throws -> Shell {
        let shell: Shell = try await BinaryGardensTest.open(session, seed: UInt64(number - 1),
                                                            reduceMotion: reduceMotion,
                                                            reduceFlashing: reduceFlashing,
                                                            size: CGSize(width: 360, height: 240),
                                                            atCheckTick: false, configure: configure)
        let opening: Core = try core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ presenter: Presenter) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: BinaryGardensA11yClock = BinaryGardensA11yClock()
        presenter.feedback = ExperienceFeedback(hapticSink: haptics, announcementSink: announcements,
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
        try BinaryGardensTest.core(shell)
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

    /// "a actions left" ("1 action left" for one), as the summary and the progress word it.
    static func actionsLeftWords(_ count: Int) -> String {
        count == 1 ? "1 action left" : "\(count) actions left"
    }

    /// The first sentence of an accepted `action` on `level` (clarification Q1).
    static func changeWords(_ action: Action, level: BinaryGardensLevel) -> String {
        switch action {
        case let .ring(star, index):
            return "Star \(star + 1) moved to ring \(index + 1) (\(level.ringRadii[index]) units)."
        case let .phase(star, step):
            return "Star \(star + 1) shifted to phase \(step)."
        case let .luminosity(star, index):
            return "Star \(star + 1)'s luminosity set to \(level.luminosityLevels[index])."
        case let .tilt(step):
            return "Tilt set to \(step) of \(level.maxTilt) steps."
        case .run:
            return ""
        }
    }

    // MARK: The panel's operations (what each adjustable element's increment and decrement does)

    /// One step of the adjustable star (presentation only): the star clamped to 0 … 1, through the presenter.
    static func stepStar(_ presenter: Presenter, _ step: Int) {
        presenter.changeStar(min(max(presenter.mirror.selectedStar + step, 0), 1))
    }

    /// One step of the adjustable shown tick: what it sends (`clock.show`, read cyclically over 1 … 48).
    static func tickValues(_ mirror: Mirror, _ step: Int) -> [Double] {
        [Double(Mirror.wrappedTick(mirror.shownTick + step))]
    }

    /// One step of the adjustable ring, phase, luminosity or tilt (`kind` 0 … 3): the control and values it sends,
    /// exactly like the panel's − and + buttons.
    static func adjustment(_ mirror: Mirror, kind: Int, step: Int) -> (control: String, values: [Double]) {
        let star: Double = Double(mirror.selectedStar)
        switch kind {
        case 0: return ("star.ring", [star, Double(mirror.ring(moved: step))])
        case 1: return ("star.phase", [star, Double(mirror.phase(moved: step))])
        case 2: return ("star.luminosity", [star, Double(mirror.luminosity(moved: step))])
        default: return ("orbit.tilt", [Double(mirror.tilt(moved: step))])
        }
    }

    /// Steers the panel's star to `star` with the adjustable star only. Returns the operations made.
    @discardableResult
    static func steerStar(_ presenter: Presenter, to star: Int) -> Int {
        var operations: Int = 0
        for _ in 0..<2 {
            if presenter.mirror.selectedStar == star { break }
            stepStar(presenter, presenter.mirror.selectedStar < star ? 1 : -1)
            operations += 1
        }
        return operations
    }

    /// Steers the panel's phase target to `step` with the phase target stepper only (presentation). Returns the
    /// operations made.
    @discardableResult
    static func steerPhaseTarget(_ mirror: Mirror, to step: Int) -> Int {
        var operations: Int = 0
        for _ in 0..<Mirror.cycle {
            if mirror.gridPhaseTarget == step { break }
            mirror.phaseTarget = mirror.phaseTarget(moved: 1)
            operations += 1
        }
        return operations
    }

    /// What the accessibility operations send for the certified `action` (the selected star already steered): the
    /// adjustable ring, luminosity or tilt for a neighbouring value, else the Ring, Luminosity or Tilt choice; Set
    /// phase with the steered phase target.
    static func operation(_ presenter: Presenter, _ action: Action) -> (control: String, values: [Double]) {
        let mirror: Mirror = presenter.mirror
        let star: Double = Double(mirror.selectedStar)
        switch action {
        case let .ring(_, index):
            let delta: Int = index - mirror.ring
            if Swift.abs(delta) == 1 { return adjustment(mirror, kind: 0, step: delta) }
            return ("star.ring", [star, Double(index)])
        case let .phase(_, step):
            steerPhaseTarget(mirror, to: step)
            return ("star.phase", [star, Double(mirror.gridPhaseTarget)])
        case let .luminosity(_, index):
            let delta: Int = index - mirror.luminosity
            if Swift.abs(delta) == 1 { return adjustment(mirror, kind: 2, step: delta) }
            return ("star.luminosity", [star, Double(index)])
        case let .tilt(step):
            let delta: Int = step - mirror.tilt
            if Swift.abs(delta) == 1 { return adjustment(mirror, kind: 3, step: delta) }
            return ("orbit.tilt", [Double(step)])
        case .run:
            return ("light.run", [])
        }
    }

    /// The star an action changes, or nil (tilt, run).
    static func star(of action: Action) -> Int? {
        switch action {
        case let .ring(star, _), let .phase(star, _), let .luminosity(star, _): return star
        case .tilt, .run: return nil
        }
    }

    // MARK: Sending

    /// Sends the accepted `control` with `values` through the presenter one clock second later, describes the new
    /// core, and expects exactly one routed plan equal to `after(old:new:)` of the cores before and after, posted to
    /// the sinks; describing it again routes nothing; the panel's message is cleared and the summary follows. Returns
    /// the plan.
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
        #expect(presenter.mirror.message == nil, "an accepted action clears the message",
                sourceLocation: sourceLocation)
        #expect(presenter.mirror.summary == Plan.summaryText(core: new, star: presenter.mirror.selectedStar),
                sourceLocation: sourceLocation)
        return plan
    }

    /// Sends the refused `control` with `values` through the presenter one clock second later; expects a refusal, an
    /// unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), exactly its words in the panel and
    /// the bare code in `refusalLog`. Returns the plan and the bare code.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> (plan: Plan, code: String) {
        let presenter: Presenter = shell.presenter
        let digest: String = try BinaryGardensTest.digest(shell)
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
        #expect(presenter.mirror.message == plan.text, "the panel shows exactly the plan's words",
                sourceLocation: sourceLocation)
        let bare: String = Mirror.bareCode(result.code)
        #expect(presenter.refusalLog.last == bare, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        let after: String = try BinaryGardensTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        try describe(shell)
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return (plan, bare)
    }

    /// The first accepted ring change of star `star` on `core` (another ring index, applied on a copy), or nil when
    /// the level locks that star's ring or the kernel refuses every other ring.
    static func ringChange(_ core: Core, star: Int) -> (action: Action, core: Core)? {
        let level: BinaryGardensLevel = core.play.level
        guard level.stars.indices.contains(star), level.stars[star].ringAdjustable else { return nil }
        let current: Int = core.play.arrangement.rings[star]
        for index in level.ringRadii.indices where index != current {
            var changed: Core = core
            let action: Action = .ring(star: star, index: index)
            if changed.apply(BinaryGardensTest.experienceAction(action)) == .accepted { return (action, changed) }
        }
        return nil
    }

    // MARK: The panel's source

    /// The panel's source text (`Experience/BinaryGardensControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("BinaryGardensControls.swift")
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

    /// The scripted session of the tier test, through the presenter on `shell` with a frame drawn and the core
    /// described after each step: a refused undo, the certified plan of level 1, undo, redo and the run.
    static func scriptedSession(_ session: ExperienceSession, _ shell: Shell) throws {
        let presenter: Presenter = shell.presenter
        var steps: [(control: String, values: [Double])] = [("play.undo", [])]
        for action in try BinaryGardensTest.certifiedPlan(1) { steps.append(BinaryGardensTest.control(action)) }
        steps.append(("play.undo", []))
        steps.append(("play.redo", []))
        steps.append(("light.run", []))
        for step in steps {
            _ = presenter.send(step.control, step.values, port: shell.port)
            try BinaryGardensTest.draw(session)
            try describe(shell)
        }
    }
}

@MainActor
@Suite(.serialized) struct BinaryGardensAccessibilityTests {
    typealias Access = BinaryGardensA11y
    typealias Plan = BinaryGardensFeedbackPlan
    typealias Presenter = BinaryGardensPresenter
    typealias Core = BinaryGardensExperienceCore
    typealias Mirror = BinaryGardensMirror
    typealias Action = BinaryGardensAction

    // MARK: Labels, values and the summary element (FR-R02G2106-001, 005; SC-R02G2106-001; clarification Q5)

    /// The panel's source gives every control a label and a value before its identifier; the star, ring, phase,
    /// luminosity, tilt and shown tick an adjustable action with the values of clarification Q5; Sound reads "on" or
    /// "off"; the summary element reads the mirror's summary; the panel keeps a 520-point readable width and lays its
    /// rows out as columns at accessibility text sizes.
    @Test func everyControlCarriesALabelAndAValueInTheSource() throws {
        let source: String = try Access.panelSource()
        for name in Access.controlNames {
            let run: Substring? = Access.modifierRun(name, in: source)
            #expect(run != nil, "\(name) has an identifier")
            guard let run else { continue }
            #expect(run.contains(".accessibilityLabel("), "\(name) has a label")
            #expect(run.contains(".accessibilityValue("), "\(name) has a value")
        }
        for entry in Access.adjustables {
            let run: Substring? = Access.modifierRun(entry.name, in: source)
            #expect(run?.contains(".accessibilityAdjustableAction") == true, "\(entry.name) is adjustable")
            #expect(run?.contains(entry.value) == true, "\(entry.name) reads its words")
            #expect(run?.contains(entry.call) == true, "\(entry.name) adjusts through the panel's operation")
        }
        let words: [String] = [
            "if let presenter { presenter.changeStar(star) } else { mirror.select(star: star) }",
            "if star { selectStar(min(max(mirror.selectedStar + step, 0), 1)) }",
            "if ring { send(\"star.ring\", [Double(mirror.selectedStar), Double(mirror.ring(moved: step))]) }",
            "if phase { send(\"star.phase\", [Double(mirror.selectedStar), Double(mirror.phase(moved: step))]) }",
            "if luminosity { send(\"star.luminosity\", [Double(mirror.selectedStar), "
                + "Double(mirror.luminosity(moved: step))]) }",
            "if tilt { send(\"orbit.tilt\", [Double(mirror.tilt(moved: step))]) }",
            "if tick { show(tick: mirror.shownTick + step) }",
            "Button(\"Ring −\") { send(\"star.ring\", [Double(mirror.selectedStar), Double(mirror.ring(moved: -1))]) }",
            "Button(\"Ring +\") { send(\"star.ring\", [Double(mirror.selectedStar), Double(mirror.ring(moved: 1))]) }",
            "Picker(\"Star\", selection: starChoice)",
            "if typeSize.isAccessibilitySize {",
            ".frame(maxWidth: Self.readableWidth, alignment: .leading)",
            ".onAppear { presenter?.controlsAppeared() }",
            ".onDisappear { presenter?.controlsDisappeared() }",
            "presenter?.sceneActive(phase == .active)",
        ]
        for word in words {
            #expect(source.contains(word), "the panel's source holds \(word)")
        }
        #expect(!source.contains("HStack(spacing: 16)"), "every row wraps into a column at accessibility sizes")
        let sound: Substring? = Access.modifierRun("sound", in: source)
        #expect(sound?.contains("mirror.soundOn ? \"on\" : \"off\"") == true, "Sound reads on or off")
        // Since feature 507 (R02-G21-07) the toggle saves the choice through `settings.sound`.
        #expect(sound?.contains("saveSound(on: $0)") == true, "the toggle saves the sound choice")
        let summary: Substring? = Access.modifierRun("summary", in: source)
        #expect(summary?.contains(".accessibilityValue(mirror.summary)") == true, "the summary reads the plan's words")
        let reset: Substring? = Access.modifierRun("reset-view", in: source)
        #expect(reset?.contains("== .authored ? \"authored\" : \"orbited\"") == true, "Reset view reads its words")
        #expect(BinaryGardensControls.readableWidth == 520)
    }

    /// After level 1 is described every value the panel reads is non-empty words in the words of clarification Q5;
    /// ", locked" marks exactly the controls the level locks; the summary element equals `summaryText(core:star:)` of
    /// the opening and the selected star; describing the opening routes nothing; the sound is off; refusals read in
    /// the plan's words, with or without the engine's prefix.
    @Test func everyControlHasANonEmptyValueInWords() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        Access.quiet(presenter)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: Mirror = presenter.mirror
        let level: BinaryGardensLevel = core.play.level
        let tutorial: String = mirror.tutorialText ?? ""
        let hintValue: String = mirror.hintLevel == 0 ? "none shown" : "level \(mirror.hintLevel) of 3"
        let orbitValue: String = presenter.orbit == .authored ? "authored" : "orbited"
        let soundValue: String = mirror.soundOn ? "on" : "off"
        let modeValue: String = Mirror.modeName(mirror.mode) == "campaign" ? "selected" : "not selected"
        let values: [String] = [mirror.summary, tutorial, hintValue, modeValue, mirror.levelLabel(mirror.pickedLevel),
                                mirror.starValue, mirror.ringValue, mirror.phaseValue, mirror.luminosityValue,
                                mirror.tiltValue, mirror.tickValue, mirror.starLabel, mirror.measureLabel,
                                mirror.actionsMadeLabel, mirror.nextLevelLabel, orbitValue, soundValue,
                                mirror.status, mirror.goalLabel, mirror.targetLabel, mirror.tickLabel]
        var index: Int = 0
        for value in values {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "value \(index) is empty")
            index += 1
        }
        #expect(mirror.budget > 0, "Undo and Redo read the actions made of a positive budget")
        #expect(mirror.actionsMadeLabel == "0 actions made")
        #expect(mirror.nextLevelLabel == "no further level open", "before a win")
        #expect(hintValue == "none shown")
        #expect(orbitValue == "authored")
        #expect(modeValue == "selected", "the campaign is selected")
        #expect(soundValue == "off", "the Sound toggle is off by default")
        #expect(mirror.status == "Ready", "\(mirror.status)")

        // The adjustables' words (clarification Q5), ", locked" exactly where the level locks the control.
        let star: Int = mirror.selectedStar
        let rules: BinaryGardensStar = level.stars[star]
        let ring: Int = core.play.arrangement.rings[star]
        let phase: Int = core.play.arrangement.phases[star]
        let light: Int = core.play.arrangement.luminosities[star]
        let tilt: Int = core.play.arrangement.tilt
        #expect(mirror.starValue == "star \(star + 1) of 2", "\(mirror.starValue)")
        #expect(mirror.ringValue == Mirror.locking("ring \(ring + 1) of \(level.ringRadii.count), "
                                                   + "\(level.ringRadii[ring]) units", !rules.ringAdjustable),
                "\(mirror.ringValue)")
        #expect(mirror.phaseValue == Mirror.locking("phase \(phase) of 47, step \(level.phaseStep)",
                                                    !rules.phaseAdjustable), "\(mirror.phaseValue)")
        #expect(mirror.luminosityValue == Mirror.locking("level \(light + 1) of \(level.luminosityLevels.count), "
                                                         + "luminosity \(level.luminosityLevels[light])",
                                                         !rules.luminosityAdjustable), "\(mirror.luminosityValue)")
        #expect(mirror.tiltValue == Mirror.locking("tilt \(tilt) of \(level.maxTilt) steps", level.maxTilt == 0),
                "\(mirror.tiltValue)")
        #expect(mirror.tickValue == "tick \(core.shownTick) of 48", "\(mirror.tickValue)")
        #expect(Mirror.locking("ring 1 of 3, 12 units", true) == "ring 1 of 3, 12 units, locked")
        #expect(Mirror.locking("tick 4 of 48", false) == "tick 4 of 48")
        for other in 0...1 {
            presenter.changeStar(other)
            let otherRules: BinaryGardensStar = level.stars[other]
            #expect(mirror.starValue == "star \(other + 1) of 2")
            #expect(mirror.ringValue.hasSuffix(", locked") == !otherRules.ringAdjustable, "star \(other + 1) ring")
            #expect(mirror.phaseValue.hasSuffix(", locked") == !otherRules.phaseAdjustable, "star \(other + 1) phase")
            #expect(mirror.luminosityValue.hasSuffix(", locked") == !otherRules.luminosityAdjustable,
                    "star \(other + 1) luminosity")
        }
        presenter.changeStar(star)

        // The summary element (clarification Q5).
        let summary: String = Plan.summaryText(core: core, star: mirror.selectedStar)
        #expect(mirror.summary == summary, "\(mirror.summary)")
        #expect(presenter.summaryText == summary)
        #expect(mirror.summary.hasPrefix(Access.actionsLeftWords(core.play.actionsLeft).capitalizedForTest + ". "),
                "\(mirror.summary)")
        let selected: String = "Selected: " + level.starDescription(star, arrangement: core.play.arrangement) + ". "
        #expect(mirror.summary.contains(selected), "\(mirror.summary)")
        #expect(mirror.summary.contains(". Shown: tick \(core.shownTick) of 48: "), "\(mirror.summary)")
        #expect(mirror.summary.contains(". Level: level 1, band 1, campaign; "), "\(mirror.summary)")
        #expect(mirror.summary.hasSuffix("."), "\(mirror.summary)")
        #expect(presenter.feedbackLog.isEmpty, "describing the opening plans nothing")

        // Refusals read in the plan's words (clarification Q1), with or without the engine's prefix.
        for entry in Access.refusalSentences {
            let plan: Plan = Plan.refused(code: entry.code)
            #expect(plan.text == entry.text, "\(entry.code): \(plan.text ?? "nil")")
            #expect(plan.kind == .rejection)
            #expect(plan.haptic == .error)
            #expect(Plan.refusalText(code: entry.code) == entry.text)
            #expect(Plan.refusalText(code: Plan.rulePrefix + entry.code) == entry.text, "\(entry.code) prefixed")
            #expect(Mirror.refusalMessage(code: Mirror.rulePrefix + entry.code) == entry.text,
                    "the panel shows the plan's sentence for \(entry.code)")
            #expect(Mirror.refusalText(code: entry.code) == entry.text)
        }
        #expect(Plan.hint(text: "Move a star to another ring").kind == .state)
        #expect(Plan.hint(text: "Move a star to another ring").haptic == nil)
    }

    /// The adjustable star clamps to 0 … 1 and the adjustable shown tick wraps over 1 … 48, presentation only (no
    /// plan, no haptic, the play unchanged; the summary names the selected star and the shown tick); the adjustable
    /// ring, phase, luminosity and tilt each send one action like − and +, announced as `after(old:new:)` when
    /// accepted (then undone) and as the refusal's sentence when refused; with the sound off no audition plays.
    @Test func adjustablesMoveLikeMinusAndPlus() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Access.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(presenter)
        let mirror: Mirror = presenter.mirror
        let opening: Core = try Access.core(shell)
        let digest: String = try BinaryGardensTest.digest(shell)
        let logBase: Int = presenter.feedbackLog.count

        // The star clamps at 2 and at 1.
        for _ in 0..<3 { Access.stepStar(presenter, 1) }
        #expect(mirror.selectedStar == 1, "the star clamps at star 2")
        #expect(mirror.starValue == "star 2 of 2")
        #expect(mirror.summary == Plan.summaryText(core: opening, star: 1))
        for _ in 0..<3 { Access.stepStar(presenter, -1) }
        #expect(mirror.selectedStar == 0, "the star clamps at star 1")
        #expect(mirror.starValue == "star 1 of 2")

        // The shown tick wraps over 1 … 48 (48 at an opening; + wraps to 1, − back to 48).
        #expect(mirror.shownTick == 48)
        let up: ActionResult = presenter.send("clock.show", Access.tickValues(mirror, 1), port: shell.port)
        #expect(up == .accepted, "\(up.code)")
        try Access.describe(shell)
        #expect(mirror.shownTick == 1, "the tick wraps to 1")
        #expect(mirror.tickValue == "tick 1 of 48")
        let shownCore: Core = try Access.core(shell)
        #expect(mirror.summary == Plan.summaryText(core: shownCore, star: mirror.selectedStar))
        let down: ActionResult = presenter.send("clock.show", Access.tickValues(mirror, -1), port: shell.port)
        #expect(down == .accepted, "\(down.code)")
        try Access.describe(shell)
        #expect(mirror.shownTick == 48, "the tick wraps back to 48")
        #expect(try Access.core(shell).play == opening.play, "the star and the tick never change the play")
        #expect(presenter.feedbackLog.count == logBase, "the star and the tick plan nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        #expect(try BinaryGardensTest.digest(shell) == digest, "the presentation never changes the digest")

        // The ring, phase, luminosity and tilt: one action per step, announced either way.
        for kind in 0..<4 {
            let entry: (control: String, values: [Double]) = Access.adjustment(mirror, kind: kind, step: 1)
            let before: Core = try Access.core(shell)
            var check: Core = before
            let wouldAccept: Bool = check.apply(ExperienceAction(control: entry.control, values: entry.values,
                                                                 step: 0)) == .accepted
            if wouldAccept {
                let plan: Plan = try Access.accepted(shell, recorder, entry.control, entry.values)
                #expect(plan.kind == .state, "\(entry.control)")
                #expect(plan.haptic == .selection, "\(entry.control)")
                try Access.accepted(shell, recorder, "play.undo", [])
            } else {
                let refusal: (plan: Plan, code: String) = try Access.refused(shell, recorder, entry.control,
                                                                             entry.values)
                #expect(refusal.plan.trigger == refusal.code, "\(entry.control): \(refusal.code)")
            }
        }
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off plays no audition")
        #expect(presenter.sound.voice == nil)
    }

    // MARK: The accessibility operations alone (SC-R02G2106-001; clarifications Q1, Q2)

    /// Level 1 (seed 0) is won with the accessibility operations alone, following its certified plan: the adjustable
    /// star steers the selected star (never announced, no haptic), the adjustable or chosen ring, luminosity and tilt
    /// and Set phase with the steered phase target send one action each, then Run `light.run`, through the presenter;
    /// every step routes exactly `after(old:new:)` with the change's words; the sinks hold the plans' words and
    /// haptics in order; the last is the win outcome with a success haptic and 3 stars.
    @Test func levelOneWonWithTheAccessibilityOperations() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Access.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(presenter)
        let mirror: Mirror = presenter.mirror
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        let plan: [Action] = try BinaryGardensTest.certifiedPlan(1)
        try #require(!plan.isEmpty, "level 1 has a certified plan")
        var expected: [Plan] = []

        for action in plan {
            if let star = Access.star(of: action) {
                Access.steerStar(presenter, to: star)
                try #require(mirror.selectedStar == star, "the adjustable star reaches star \(star + 1)")
                #expect(mirror.starValue == "star \(star + 1) of 2")
            }
            let logBefore: Int = presenter.feedbackLog.count
            let announcedBefore: Int = recorder.announcements.announced.count
            let playedBefore: Int = recorder.haptics.played.count
            let entry: (control: String, values: [Double]) = Access.operation(presenter, action)
            #expect(entry.control == BinaryGardensTest.control(action).control, "\(action)")
            #expect(entry.values == BinaryGardensTest.control(action).values, "\(action): \(entry.values)")
            let step: Plan = try Access.accepted(shell, recorder, entry.control, entry.values)
            let words: String = Access.changeWords(action, level: opening.play.level) + " "
            #expect(step.text?.hasPrefix(words) == true, "\(step.text ?? "nil")")
            #expect(presenter.feedbackLog.count == logBefore + 1, "the steering plans nothing, the action one plan")
            #expect(recorder.announcements.announced.count == announcedBefore + 1, "only the action is announced")
            #expect(recorder.haptics.played.count == playedBefore + 1, "only the action plays a haptic")
            #expect(step.text?.hasSuffix(" left.") == true, "\(step.text ?? "nil")")
            #expect(step.kind == .state)
            #expect(step.haptic == .selection)
            expected.append(step)
        }
        let before: Core = try Access.core(shell)
        try #require(before.play.stage == .playing, "\(before.play.stage)")
        #expect(before.play.report.wins, "running now would win")
        #expect(expected.last?.text?.contains("running now would win") == true, "\(expected.last?.text ?? "nil")")
        let run: Plan = try Access.accepted(shell, recorder, "light.run", [])
        expected.append(run)

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won, "\(won.play.stage)")
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(plans.count == plan.count + 1, "every step is announced")
        let winText: String = plans.last?.text ?? ""
        #expect(winText.hasPrefix(Plan.wonText + " Level won spending "), "\(winText)")
        #expect(winText.hasSuffix(", 3 of 3 stars."), "the certified plan earns 3 stars: \(winText)")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
        #expect(mirror.status == "Won")
        #expect(mirror.bestStars == 3, "Best: 3 of 3 stars")
        #expect(mirror.message == nil)
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off plays no audition")
    }

    // MARK: A scripted sequence (SC-R02G2106-002; clarifications Q1, Q2)

    /// On level 1: showing a tick (nothing routed); refusals — undo with nothing to undo, a star that is not whole, a
    /// tick past the cycle, a level not open yet and an impossible date — each read in the plan's sentence with an
    /// error haptic; the run at the opening (a failure, outcome, warning, the failure explanation); the first certified
    /// action after it ("The level has ended."); undo (state); a redo restoring the failure (outcome only); undo; then
    /// the first certified action, undo and redo (state, selection): the recorded announcements and haptics equal the
    /// plans exactly, in order.
    @Test func scriptedSequenceAnnouncesExactlyThePlans() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Access.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(presenter)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        let plan: [Action] = try BinaryGardensTest.certifiedPlan(1)
        let first: Action = try #require(plan.first, "level 1 has a certified action")
        let firstEntry: (control: String, values: [Double]) = BinaryGardensTest.control(first)
        var expected: [Plan] = []

        // Showing a tick routes nothing.
        recorder.clock.advance()
        let shown: ActionResult = presenter.send("clock.show", [24], port: shell.port)
        #expect(shown == .accepted, "\(shown.code)")
        try Access.describe(shell)
        #expect(presenter.feedbackLog.count == logBase, "showing a tick routes nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)

        // Refusals, each in the plan's sentence.
        let undo: (plan: Plan, code: String) = try Access.refused(shell, recorder, "play.undo", [])
        #expect(undo.code == "r02-g21.action", "\(undo.code)")
        #expect(undo.plan.text == Access.refusalSentences[2].text)
        expected.append(undo.plan)
        let whole: (plan: Plan, code: String) = try Access.refused(shell, recorder, "clock.show", [24.5])
        #expect(whole.code == "r02-g21.not-whole", "\(whole.code)")
        #expect(whole.plan.text == "That value must be a whole number.")
        expected.append(whole.plan)
        let outside: (plan: Plan, code: String) = try Access.refused(shell, recorder, "clock.show", [49])
        #expect(outside.code == "r02-g21.tick", "\(outside.code)")
        #expect(outside.plan.text == "Only ticks 1 to 48 can be shown.")
        expected.append(outside.plan)
        if opening.progress.frontier == 1 {
            let locked: (plan: Plan, code: String) = try Access.refused(shell, recorder, "level.select", [2])
            #expect(locked.code == "r02-g21.locked", "\(locked.code)")
            #expect(locked.plan.text == "That level is not open yet.")
            expected.append(locked.plan)
        }
        let date: (plan: Plan, code: String) = try Access.refused(shell, recorder, "mode.daily", Access.impossibleDate)
        #expect(date.code == "r02-g21.date", "\(date.code)")
        #expect(date.plan.text == "That date cannot be used.")
        expected.append(date.plan)

        // The run at the opening fails (a level refuses a winning start).
        let failed: Plan = try Access.accepted(shell, recorder, "light.run", [])
        let failedCore: Core = try Access.core(shell)
        try #require(failedCore.play.stage == .failed, "\(failedCore.play.stage)")
        #expect(failed.kind == .outcome)
        #expect(failed.haptic == .warning)
        #expect(failed.text == BinaryGardensFailureExplanation(play: failedCore.play)?.text)
        expected.append(failed)
        let ended: (plan: Plan, code: String) = try Access.refused(shell, recorder, firstEntry.control,
                                                                   firstEntry.values)
        #expect(ended.code == "r02-g21.stage", "\(ended.code)")
        #expect(ended.plan.text == "The level has ended.")
        expected.append(ended.plan)
        let undone: Plan = try Access.accepted(shell, recorder, "play.undo", [])
        #expect(undone.kind == .state)
        #expect(undone.haptic == .selection)
        #expect(undone.text?.hasPrefix("Undone. ") == true, "\(undone.text ?? "nil")")
        expected.append(undone)
        let restored: Plan = try Access.accepted(shell, recorder, "play.redo", [])
        let restoredCore: Core = try Access.core(shell)
        #expect(restoredCore.play.stage == .failed, "the redo restores the failed run")
        #expect(restored.kind == .outcome, "a redo restoring a failure plans only the outcome")
        #expect(restored.haptic == .warning)
        expected.append(restored)
        expected.append(try Access.accepted(shell, recorder, "play.undo", []))

        // The first certified action, undo and redo.
        let set: Plan = try Access.accepted(shell, recorder, firstEntry.control, firstEntry.values)
        #expect(set.kind == .state)
        #expect(set.haptic == .selection)
        #expect(set.text?.hasPrefix(Access.changeWords(first, level: opening.play.level) + " ") == true,
                "\(set.text ?? "nil")")
        expected.append(set)
        let back: Plan = try Access.accepted(shell, recorder, "play.undo", [])
        #expect(back.text?.hasPrefix("Undone. ") == true, "\(back.text ?? "nil")")
        expected.append(back)
        let redo: Plan = try Access.accepted(shell, recorder, "play.redo", [])
        #expect(redo.text?.hasPrefix("Redone. ") == true, "\(redo.text ?? "nil")")
        #expect(redo.haptic == .selection)
        expected.append(redo)

        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(recorder.announcements.announced == Access.texts(expected), "\(recorder.announcements.announced)")
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
    }

    /// A revealed hint is announced as `state` with its words and no haptic (clarification Q1): level 1's first hint
    /// at its opening; the searching line is not announced; the selected star is not either.
    @Test func revealedHintIsAnnouncedAsState() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Access.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(presenter)
        let opening: Core = try Access.core(shell)
        let logBase: Int = presenter.feedbackLog.count
        recorder.clock.advance()
        try await BinaryGardensTeaching.pressHint(presenter)
        let text: String = try #require(presenter.mirror.hintText, "a hint is shown")
        #expect(text == BinaryGardensTeaching.expectedTexts(opening)[0], "\(text)")
        #expect(presenter.mirror.hintLevel == 1)
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == [Plan.hint(text: text)], "\(plans)")
        #expect(recorder.announcements.announced == [text])
        #expect(recorder.haptics.played.isEmpty, "a hint plays no haptic")
        #expect(!recorder.announcements.announced.contains(Presenter.searchingText))
        Access.stepStar(presenter, 1)
        #expect(presenter.feedbackLog.count == logBase + 1, "the selected star is not announced")
    }

    // MARK: Reduce Motion and Reduce Flashing frames (FR-R02G2106-004; SC-R02G2106-003)

    /// With Reduce Motion, Reduce Flashing or both, `u_motion` is 0 (without either it is 1), and two stills of the
    /// same won state at different frame times keep the eased lights at the won targets and are byte-identical once the
    /// fades settle (the coronas and motes held still at level-0).
    @Test func framesOfOneStateAreStill() async throws {
        let plan: [Action] = try BinaryGardensTest.certifiedPlan(1)
        let actions: [Action] = plan + [.run]
        let modes: [(motion: Bool, flashing: Bool)] = [(true, false), (false, true), (true, true)]
        for mode in modes {
            let what: String = "Reduce Motion \(mode.motion), Reduce Flashing \(mode.flashing)"
            let session: ExperienceSession = ExperienceSession()
            defer { session.close() }
            let shell: Access.Shell = try await Access.open(session, number: 1, reduceMotion: mode.motion,
                                                            reduceFlashing: mode.flashing)
            let presenter: Presenter = shell.presenter
            Access.quiet(presenter)
            #expect(presenter.reduceMotion == mode.motion)
            #expect(presenter.scene.reducedFlash == mode.flashing)
            #expect(presenter.lights.reducedFlash == mode.flashing)
            #expect(presenter.scene.motion == 0, "\(what): the coronas and motes stand still")
            #expect(BinaryGardensTest.issue(shell, actions) == actions.count)
            let won: Core = try Access.core(shell)
            #expect(won.play.stage == .won, "\(what): \(won.play.stage)")
            let w: Int = Access.stillWidth
            let h: Int = Access.stillHeight
            let base: Double = 10
            // Two first stills let any light fade finish (0.5 s apart, beyond the 0.45 s fade).
            _ = try BinaryGardensTest.still(session, width: w, height: h, time: base)
            _ = try BinaryGardensTest.still(session, width: w, height: h, time: base + 0.5)
            let early: [UInt8] = try BinaryGardensTest.still(session, width: w, height: h, time: base + 0.75)
            let earlyLights: BinaryGardensLights = presenter.lights
            let late: [UInt8] = try BinaryGardensTest.still(session, width: w, height: h, time: base + 1.9)
            #expect(BinaryGardensTest.drawnPixels(early) > 0, "\(what): the still shows the system")
            #expect(presenter.lights == earlyLights, "\(what): the lights do not move")
            #expect(presenter.lights.isSettled, "\(what): the lights rest")
            #expect(presenter.lights.won == 1, "\(what): the won look rests at 1")
            #expect(presenter.lights.glow == BinaryGardensLights.glowWon, "\(what): the glow rests once won")
            #expect(presenter.scene.lights == presenter.lights, "\(what): the scene draws the presenter's lights")
            #expect(early == late, "\(what): stills at 0.75 s and 1.9 s are identical")
        }
        let plain: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        #expect(plain.scene.motion == 1, "without Reduce Motion or Reduce Flashing the coronas and motes move")
    }

    // MARK: The won look under Reduce Flashing (FR-R02G2106-004; SC-R02G2106-003; clarification Q3)

    /// Under Reduce Flashing, in the shader path and in fallback mode, the drawn won level rises over at least 0.4 s
    /// of frame time after the winning run, sampled every 1/60 s: never falling, between 0 and 1 at first, 1 between
    /// 0.4 s and 0.5 s; the scene draws the presenter's lights; the shader frame changes as the level rises; the
    /// fallback system is rebuilt about once per tenth of the level, never once per frame.
    @Test func wonBrightensSlowlyUnderReduceFlashing() async throws {
        let plan: [Action] = try BinaryGardensTest.certifiedPlan(1)
        for broken in [false, true] {
            let what: String = broken ? "fallback" : "shader"
            let session: ExperienceSession = ExperienceSession()
            defer { session.close() }
            let configure: (Presenter) -> Void = { (presenter: Presenter) in
                if broken { presenter.breakSystemShader() }
            }
            let shell: Access.Shell = try await Access.open(session, number: 1, reduceFlashing: true,
                                                            configure: configure)
            let presenter: Presenter = shell.presenter
            Access.quiet(presenter)
            #expect((presenter.fallbackReason != nil) == broken, "\(what): \(presenter.fallbackReason ?? "nil")")
            #expect(BinaryGardensTest.issue(shell, plan) == plan.count)
            let playing: Core = try Access.core(shell)
            try #require(playing.play.stage != .won, "\(what): only the run wins")
            let w: Int = Access.stillWidth * 2
            let h: Int = Access.stillHeight * 2
            let base: Double = 10
            _ = try BinaryGardensTest.still(session, width: w, height: h, time: base - 1)
            _ = try BinaryGardensTest.still(session, width: w, height: h, time: base)
            #expect(presenter.lights.won == 0, "\(what): the won light rests at 0 while playing")
            #expect(presenter.scene.lights?.won == 0)

            let winning: ActionResult = shell.handle(control: "light.run", values: [])
            #expect(winning == .accepted, "\(what): \(winning.code)")
            let won: Core = try Access.core(shell)
            #expect(won.play.stage == .won, "\(what): \(won.play.stage)")

            let buildsBefore: Int = presenter.scene.systemBuilds
            let frame: Double = 1.0 / 60
            let steps: Int = 36
            var previous: Double = 0
            var reachedAt: Double?
            var first: [UInt8] = []
            var latest: [UInt8] = []
            for step in 1...steps {
                let offset: Double = Double(step) * frame
                let rgba: [UInt8] = try BinaryGardensTest.still(session, width: w, height: h, time: base + offset)
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
            let builds: Int = presenter.scene.systemBuilds - buildsBefore
            if broken {
                // The fallback system is rebuilt when the stage changes and each time the level crosses a tenth.
                #expect(builds >= 10, "\(what): the fallback follows the level by tenths: \(builds) builds")
                #expect(builds <= 12, "\(what): the fallback is not rebuilt every frame: \(builds) builds")
            } else {
                // The drawn won level rises from below 1 to 1 (the pixels may already agree when every world blooms).
                #expect(presenter.scene.lights?.won == 1, "\(what): the scene draws the settled won level")
                _ = (first, latest)
            }
            #expect(BinaryGardensTest.drawnPixels(latest) > 0, "\(what): the still shows the system")
            #expect((presenter.fallbackReason != nil) == broken)
        }
    }

    /// The fallback's colour blend without a host: parts of equal size move each colour toward the won colour by the
    /// level, clamped to 0 … 1 (a non-finite level reads 0); parts of different sizes switch whole at 0.5.
    @Test func blendedColoursLerpClampAndSwitch() {
        typealias Scene = BinaryGardensSystemScene
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

    // MARK: Sound (FR-R02G2106-006; SC-R02G2106-004; clarification Q4)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations, and an audition plays only
    /// then; the sound off makes no player and no voice; each input turning off stops a playing loop and a sounding
    /// audition; a new player is made only for a different recipe or the toggle turning on.
    @Test func soundStateTable() throws {
        typealias Recipe = BinaryGardensSoundRecipe
        let opening: Core = try Core.opening(number: 1)
        let plan: [Action] = try BinaryGardensTest.certifiedPlan(1)
        let wonCore: Core = try BinaryGardensTest.coreAfter(1, plan + [.run], showCheckTick: false)
        let failedCore: Core = try BinaryGardensTest.coreAfter(1, [.run], showCheckTick: false)
        try #require(wonCore.play.stage == .won, "\(wonCore.play.stage)")
        try #require(failedCore.play.stage == .failed, "\(failedCore.play.stage)")
        let calm: AmbientLoopRecipe = Recipe.recipe(play: opening.play)
        let won: AmbientLoopRecipe = Recipe.recipe(play: wonCore.play)
        let failed: AmbientLoopRecipe = Recipe.recipe(play: failedCore.play)
        try #require(calm != won, "a won play sounds different")
        try #require(calm != failed, "a failed play sounds different")
        try #require(won != failed)
        let sample: BinaryGardensAudition = BinaryGardensAudition.of(ring: 0, canChange: true)
        try #require(!sample.partials.isEmpty, "a star's audition has tones")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: BinaryGardensA11yLoopFactory = BinaryGardensA11yLoopFactory()
            let sound: BinaryGardensSound = factory.sound(calm)
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
        let toggles: BinaryGardensA11yLoopFactory = BinaryGardensA11yLoopFactory()
        let live: BinaryGardensSound = toggles.sound(calm)
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
        #expect(!live.audition(BinaryGardensAudition(partials: [])), "silence plays nothing")
        #expect(live.auditionsPlayed == 1)

        // A failing play() changes nothing else.
        let failing: BinaryGardensA11yLoopFactory = BinaryGardensA11yLoopFactory()
        failing.succeeds = false
        let silent: BinaryGardensSound = failing.sound(calm)
        silent.setOnScreen(true)
        silent.setWanted(true)
        #expect(!silent.started, "a failed play() is not started")
        #expect(silent.shouldPlay)

        // Rebuilds only when the recipe differs.
        let factory: BinaryGardensA11yLoopFactory = BinaryGardensA11yLoopFactory()
        let sound: BinaryGardensSound = factory.sound(calm)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(calm) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(failed)
        #expect(sound.playersMade == 2, "a change of the stage makes a new player")
        if factory.made.count == 2 {
            #expect(!factory.made[0].isPlaying, "the old player stopped")
            #expect(factory.made[1].isPlaying)
        }
        sound.offer(won)
        #expect(sound.playersMade == 3, "a won play makes a new player")
        #expect(sound.playerRecipe == won)
        sound.setWanted(false)
        sound.offer(calm)
        #expect(sound.playersMade == 3, "an offer while off makes no player")
        #expect(sound.recipe == calm, "kept for the next start")
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "the toggle turning on plays the latest recipe")
        #expect(factory.recipes == [calm, failed, won, calm])
    }

    /// The presenter's sound is off by default; with the sound off, with the controls off screen and with the scene
    /// inactive, changing the selected star plays no audition and makes no player or voice, so no audio is touched;
    /// the recipe is offered at the first state and follows an accepted action; changing the star is never announced.
    @Test func presenterAuditionSilentUnlessOnScreenActiveAndOn() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        Access.quiet(presenter)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")
        #expect(Presenter.recipe(opening) == BinaryGardensSoundRecipe.recipe(play: opening.play))

        presenter.changeStar(1)
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off: a star change plays no audition")
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        presenter.changeStar(0)
        #expect(presenter.sound.auditionsPlayed == 0, "off screen: a star change plays no audition")
        presenter.sceneActive(false)
        presenter.controlsAppeared()
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the sound silent")
        presenter.changeStar(1)
        #expect(presenter.sound.auditionsPlayed == 0, "inactive: a star change plays no audition")
        presenter.controlsDisappeared()
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "a star change keeps the recipe")

        // An accepted action re-offers the recipe of its play (kept while the loop cannot play).
        let plan: [Action] = try BinaryGardensTest.certifiedPlan(1)
        let change: Action = try #require(plan.first)
        var changed: Core = opening
        let result: ActionResult = changed.apply(BinaryGardensTest.experienceAction(change))
        #expect(result == .accepted, "\(result.code)")
        _ = presenter.describe(changed)
        #expect(presenter.sound.recipe == Presenter.recipe(changed), "the recipe follows the play")
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        presenter.sceneActive(true)
        #expect(presenter.sound.auditionsPlayed == 0)
        #expect(presenter.sound.playersMade == 0, "no player was made")
        #expect(presenter.sound.player == nil, "the sound off never touches audio")
        #expect(presenter.sound.voice == nil)
        #expect(presenter.feedbackLog.count == 1, "only the action is announced; star changes are not")
    }

    /// With the sound on, on screen and active, every change of the selected star plays
    /// `BinaryGardensAudition.of(ring:canChange:)` of that star once (the same star again plays none); an accepted ring
    /// change of the selected star plays its audition once; a ring change of the other star, a phase change and a
    /// preview play none; describing plays none; a won play's stars cannot change and beat; with the sound off again a
    /// further change plays nothing. (This test makes the presenter's real loop and one-shot players.)
    @Test func starAndRingChangesPlayOneAuditionWhenTheSoundIsOn() throws {
        let presenter: Presenter = Presenter(reduceMotion: true, reduceFlashing: false)
        Access.quiet(presenter)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.setSound(on: true)
        presenter.controlsAppeared()
        presenter.sceneActive(true)
        #expect(presenter.sound.shouldPlay)
        #expect(presenter.sound.playersMade == 1, "the toggle turning on screen makes the loop's player")
        let mirror: Mirror = presenter.mirror

        // Star changes: one audition each, of the selected star; the same star again plays none.
        presenter.changeStar(1)
        #expect(presenter.sound.auditionsPlayed == 1, "a star change plays one audition")
        #expect(presenter.sound.lastAudition == Presenter.audition(star: 1, play: opening.play))
        #expect(presenter.sound.lastAudition == presenter.selectedAudition)
        presenter.changeStar(1)
        #expect(presenter.sound.auditionsPlayed == 1, "the same star again plays no audition")
        Access.stepStar(presenter, 1)
        #expect(presenter.sound.auditionsPlayed == 1, "the adjustable star clamped at star 2 plays no audition")
        Access.stepStar(presenter, -1)
        #expect(presenter.sound.auditionsPlayed == 2, "the adjustable star plays one audition")
        #expect(mirror.selectedStar == 0)
        let ring0: Int = opening.play.arrangement.rings[0]
        let canChange0: Bool = BinaryGardensAudition.canChange(star: 0, play: opening.play)
        let expected0: BinaryGardensAudition = BinaryGardensAudition.of(ring: ring0, canChange: canChange0)
        #expect(presenter.sound.lastAudition == expected0)

        // A preview plays none.
        mirror.preview = .ring(star: 0, index: ring0)
        #expect(presenter.sound.auditionsPlayed == 2, "a preview plays no audition")
        mirror.preview = nil

        // An accepted ring change of the selected star plays one audition; of the other star none. On level 1 only
        // star 2 is adjustable, so star 2 is selected first (one audition) and star 1 never changes.
        presenter.changeStar(1)
        #expect(presenter.sound.auditionsPlayed == 3, "selecting star 2 again plays one audition")
        var current: Core = opening
        var routed: Int = 0
        if let change = Access.ringChange(current, star: 1) {
            _ = presenter.describe(change.core)
            routed += 1
            #expect(presenter.sound.auditionsPlayed == 4, "a ring change of the selected star plays one audition")
            #expect(presenter.sound.lastAudition == Presenter.audition(star: 1, play: change.core.play))
            current = change.core
        } else {
            Issue.record("level 1 has no accepted ring change of star 2")
        }
        let afterOwn: Int = presenter.sound.auditionsPlayed
        if let other = Access.ringChange(current, star: 0) {
            _ = presenter.describe(other.core)
            routed += 1
            #expect(presenter.sound.auditionsPlayed == afterOwn, "a ring change of the other star plays no audition")
            current = other.core
        }
        _ = presenter.describe(current)
        #expect(presenter.sound.auditionsPlayed == afterOwn, "describing plays no audition")
        #expect(presenter.feedbackLog.count == routed, "only the accepted actions are announced")

        // A won play: no star can change, so the audition beats 3 Hz above the tone.
        let plan: [Action] = try BinaryGardensTest.certifiedPlan(1)
        let wonCore: Core = try BinaryGardensTest.coreAfter(1, plan + [.run], showCheckTick: false)
        let beating: BinaryGardensAudition = Presenter.audition(star: 1, play: wonCore.play)
        #expect(!BinaryGardensAudition.canChange(star: 1, play: wonCore.play), "a won play's stars cannot change")
        #expect(beating.partials.count == 2)
        if beating.partials.count == 2 {
            let beat: Double = beating.partials[1].frequency - beating.partials[0].frequency
            #expect(Swift.abs(beat - BinaryGardensAudition.beatHertz) < 1e-9,
                    "the second partial beats 3 Hz above the tone: \(beat)")
        }

        presenter.setSound(on: false)
        presenter.controlsDisappeared()
        let silentCount: Int = presenter.sound.auditionsPlayed
        presenter.changeStar(1)
        #expect(presenter.sound.auditionsPlayed == silentCount, "no audition once the sound is off")
        #expect(!presenter.sound.shouldPlay)
    }

    // MARK: Tier-safe presentation (FR-R02G2106-007, 008; SC-R02G2106-005; clarification Q6)

    /// The same scripted session (a refused undo, level 1's certified plan, undo, redo and the run, a frame drawn
    /// after each step) at level-0, level-1, level-2 and in the fallback gives equal feedback logs; afterwards a
    /// memory warning and a tier change reset no eased level, feedback log or sound state.
    @Test func feedbackLogsAreEqualAtEveryTierAndInTheFallback() async throws {
        var logs: [[Plan]] = []
        let cases: [(tier: Int, broken: Bool)] = [(0, false), (1, false), (2, false), (0, true)]
        for entry in cases {
            let what: String = entry.broken ? "fallback" : "level-\(entry.tier)"
            let session: ExperienceSession = ExperienceSession()
            defer { session.close() }
            session.qualityPin = entry.tier
            let configure: (Presenter) -> Void = { (presenter: Presenter) in
                if entry.broken { presenter.breakSystemShader() }
            }
            let shell: Access.Shell = try await Access.open(session, number: 1, configure: configure)
            let presenter: Presenter = shell.presenter
            Access.quiet(presenter)
            #expect(shell.engine.qualityTier == entry.tier, "\(what)")
            #expect((presenter.fallbackReason != nil) == entry.broken, "\(what)")
            let logBase: Int = presenter.feedbackLog.count
            try Access.scriptedSession(session, shell)
            let log: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
            #expect(log.count == (try BinaryGardensTest.certifiedPlan(1)).count + 4, "\(what): \(log.count) plans")
            #expect(log.first?.kind == .rejection, "\(what)")
            #expect(log.last?.kind == .outcome && log.last?.haptic == .success, "\(what): the run wins")
            logs.append(log)

            // A memory warning and a tier change reset nothing of the feedback, the lights or the sound.
            presenter.setSound(on: true)
            let lights: BinaryGardensLights = presenter.lights
            let feedback: [Plan] = presenter.feedbackLog
            let recipe: AmbientLoopRecipe = presenter.sound.recipe
            presenter.shedCaches()
            #expect(presenter.scene.liveObjectCount == 0, "\(what): the memory warning released the GPU objects")
            session.qualityPin = (entry.tier + 1) % BinaryGardensExperienceCore.qualityTiers
            #expect(presenter.lights == lights, "\(what): the eased levels stay")
            #expect(presenter.feedbackLog == feedback, "\(what): the feedback log stays")
            #expect(presenter.sound.recipe == recipe, "\(what): the sound's recipe stays")
            #expect(presenter.sound.wanted && presenter.mirror.soundOn, "\(what): the sound choice stays")
            try BinaryGardensTest.draw(session)
            #expect(presenter.feedbackLog == feedback, "\(what): a frame after the change routes nothing")
            #expect(presenter.lights.reducedFlash == lights.reducedFlash)
            presenter.setSound(on: false)
        }
        try #require(logs.count == cases.count)
        for index in 1..<logs.count {
            #expect(logs[index] == logs[0], "case \(index) gives the same feedback log as level-0")
        }
    }
}

private extension String {
    /// The string with its first character upper-cased (as the summary capitalises its sentences).
    var capitalizedForTest: String { prefix(1).uppercased() + dropFirst() }
}
#endif
