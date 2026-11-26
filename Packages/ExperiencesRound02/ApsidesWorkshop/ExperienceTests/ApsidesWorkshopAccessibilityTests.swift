// ApsidesWorkshopAccessibilityTests — feature 476 (R02-G18-06) T-R02G1806-005 (FR-R02G1806-001 … 006;
// SC-R02G1806-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on
// Celestial Eclipse Lab's feature-466 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; the presenter's own
// `feedbackLog` holds every routed plan. Every expected text is built from `ApsidesWorkshopFeedbackPlan`
// (`after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `summaryText(core:pending:)`) on the cores captured before
// and after each step. The tests describe the current core after every action, so the presenter's latest core is the
// current one; describing the same core again routes nothing.
// Labels and values: the `.accessibilityLabel` / `.accessibilityValue` modifiers are not inspectable from a unit test
// (SwiftUI's accessibility tree), so the panel's source is read (`#filePath`): every control's modifier run up to its
// identifier carries a label and a value, the pending eccentricity, direction and size an adjustable action whose
// increment and decrement move the pending orbit through the presenter exactly like the − and + buttons, and their
// values are the words of clarification Q5 ("pending eccentricity 0.ee", "pending periapsis at d°", "pending size a");
// every value the panel reads from the mirror is non-empty words once level 1 is described, and the summary element
// equals `summaryText(core:pending:)`. The adjustable pending orbit (`presenter.movePending(eccentricity:direction:
// size:)`, what the increment and decrement call) steps, clamps and wraps like − and +, draws the valid pending orbit as
// the preview and is never announced. Level 1 (seed 0) is won with those operations, Set periapsis
// (`orbit.periapsis [k, d]`), Set size (`orbit.size [a]`) and Play (`orbit.play`) alone, following the certified
// witness, every step announced as `after(old:new:)` and the win as an outcome with a success haptic and 3 stars. A
// scripted sequence on level 1 (a shown tick, refusals of every reachable kind, a failed play, a refusal after it, undo,
// a redo restoring the failure, undo, a tuning, undo, redo) records exactly the plans' texts and haptics; every refusal
// reads the plan's sentence with an error haptic. Reduce Motion, Reduce Flashing and both: two stills of the same won
// state at different frame times hold the star pulse at 1, keep the eased lights at the won targets and are
// byte-identical once the fades settle; with neither the pulse follows the frame time. Under Reduce Flashing the won
// level brightens over at least 0.4 s of frame time (sampled at 1/60 s), in the shader path and in fallback mode
// (`breakCompassShader()` before setup); `ApsidesWorkshopCompassScene.blendedColours(off:on:level:)` is checked without
// a host. Sound: the state table (wanted × on screen × active) uses an `ApsidesWorkshopSound` with injected recording
// loops and voices; the presenter's own toggle off screen or inactive makes no player and plays no audition; one test
// turns the presenter's sound on screen (the shared ambient loop and one-shot players, ambient session, no input):
// every change of the pending orbit plays `ApsidesWorkshopAudition.of(pending)` once, a step that changes nothing (a
// clamped eccentricity) plays none, and a drag preview plays none. Explicit timestamps, synthetic data, explicit types,
// plain loops, no nested closure literals, no sleep, no wall-clock assertion; each test short.
#if os(iOS)
import ApsidesWorkshopCore
import CoreGraphics
import Foundation
import Testing
@testable import ApsidesWorkshopExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class ApsidesWorkshopA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class ApsidesWorkshopA11yLoop: ApsidesWorkshopLoopPlaying {
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
final class ApsidesWorkshopA11yVoice: ApsidesWorkshopAuditionPlaying {
    /// Every audition played, oldest first.
    private(set) var played: [ApsidesWorkshopAudition] = []
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0

    /// A silent recording voice.
    init() {}

    /// Records `audition`; true when it has partials.
    @discardableResult
    func play(_ audition: ApsidesWorkshopAudition) -> Bool {
        played.append(audition)
        return !audition.partials.isEmpty
    }

    /// Records a stop.
    func stop() { stops += 1 }
}

/// Makes fake loops and voices and keeps them.
@MainActor
final class ApsidesWorkshopA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [ApsidesWorkshopA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []
    /// Every voice made, oldest first.
    private(set) var voices: [ApsidesWorkshopA11yVoice] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> ApsidesWorkshopA11yLoop {
        let loop: ApsidesWorkshopA11yLoop = ApsidesWorkshopA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// Makes and keeps one fake voice.
    func makeVoice() -> ApsidesWorkshopA11yVoice {
        let voice: ApsidesWorkshopA11yVoice = ApsidesWorkshopA11yVoice()
        voices.append(voice)
        return voice
    }

    /// A sound policy starting from `recipe` that makes its players and its voice here.
    func sound(_ recipe: AmbientLoopRecipe) -> ApsidesWorkshopSound {
        ApsidesWorkshopSound(recipe: recipe, makePlayer: { next in self.make(next) },
                             makeVoice: { self.makeVoice() })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum ApsidesWorkshopA11y {
    typealias Shell = ApsidesWorkshopTest.Shell
    typealias Plan = ApsidesWorkshopFeedbackPlan
    typealias Core = ApsidesWorkshopExperienceCore
    typealias Presenter = ApsidesWorkshopPresenter
    typealias Mirror = ApsidesWorkshopMirror
    typealias Orbit = ApsidesWorkshopOrbit

    /// A recording route on a presenter.
    struct Recorder {
        /// The haptics played, in order.
        let haptics: RecordingHapticSink
        /// The announcements posted, in order.
        let announcements: RecordingAnnouncementSink
        /// The clock of the route.
        let clock: ApsidesWorkshopA11yClock
    }

    /// The still size of the Reduce Motion and fade tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// The controls of the panel by identifier name: each needs a label and a value (clarification Q5). The plain
    /// texts (actions, status, progress, the level line, tutorial, hint text, failure, band, stars, goal, the orbit and
    /// tick detail lines, the bare tick line, the pending reason, the replay position) are read as text, not
    /// controls; since feature 477 the replay controls (Replay, Step, Stop) are listed too.
    static let controlNames: [String] = ["sound", "summary", "dismiss-tutorial", "hint", "campaign", "daily",
                                         "practice", "level-picker", "play-level", "eccentricity-minus",
                                         "eccentricity", "eccentricity-plus", "direction-minus", "direction",
                                         "direction-plus", "size-minus", "size", "size-plus", "set-periapsis",
                                         "set-size", "reset-view", "tick-minus", "tick-plus", "play", "undo", "redo",
                                         "next-level", "replay", "replay-step", "replay-stop"]
    /// The adjustable elements (increment and decrement).
    static let adjustableNames: [String] = ["eccentricity", "direction", "size"]

    /// The refusal codes of clarification Q1 with their sentences; any other code reads "That action was refused.".
    static let refusalSentences: [(code: String, text: String)] = [
        ("r02-g18.locked", "That level is not open yet."),
        ("r02-g18.date", "That date cannot be used."),
        ("r02-g18.action", "That orbit cannot be set, or there is nothing to undo or redo."),
        ("r02-g18.budget", "No actions are left: undo or retry."),
        ("r02-g18.stage", "The level has ended."),
        ("r02-g18.stale", "The play changed before the action arrived."),
        ("r02-g18.level", "That level could not be made."),
        ("r02-g18.not-whole", "That value must be a whole number."),
        ("r02-g18.tick", "That tick is outside the revolution."),
        ("action.out-of-range", "That action was refused."),
        ("r02-g18.unknown", "That action was refused."),
    ]

    /// Opens level `number` (seed `number − 1`) at a 360 × 240-point view (one frame drawn, tick 0 shown) and
    /// describes the opening so the presenter holds the latest core.
    static func open(_ session: ExperienceSession, number: Int = 1, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await ApsidesWorkshopTest.open(session, seed: UInt64(number - 1),
                                                              reduceMotion: reduceMotion,
                                                              reduceFlashing: reduceFlashing,
                                                              size: CGSize(width: 360, height: 240), atHalf: false)
        let opening: Core = try core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: ApsidesWorkshopA11yClock = ApsidesWorkshopA11yClock()
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
        try ApsidesWorkshopTest.core(shell)
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

    /// Eccentricity step `k` in words: "0.ee" (k × 0.05, two decimals).
    static func eccentricityWords(_ k: Int) -> String {
        let e: Int = k * 5
        return "0." + (e < 10 ? "0" : "") + "\(e)"
    }

    /// The pending eccentricity's value as the panel words it (clarification Q5): "pending eccentricity 0.ee".
    static func eccentricityValue(_ mirror: Mirror) -> String {
        "pending eccentricity " + eccentricityWords(mirror.pending.eccentricity)
    }

    /// The pending direction's value as the panel words it (clarification Q5): "pending periapsis at d°".
    static func directionValue(_ mirror: Mirror) -> String {
        "pending periapsis at \(mirror.pending.direction * 15)°"
    }

    /// The pending size's value as the panel words it (clarification Q5): "pending size a".
    static func sizeValue(_ mirror: Mirror) -> String {
        "pending size \(mirror.pending.size)"
    }

    /// The summary's pending sentence of `orbit` (clarification Q5): "Pending: size a, eccentricity 0.ee, periapsis
    /// at d°.".
    static func pendingSentence(_ orbit: Orbit) -> String {
        "Pending: size \(orbit.size), eccentricity " + eccentricityWords(orbit.eccentricity) + ", periapsis at "
            + "\(orbit.direction * 15)°."
    }

    /// Undo and Redo's value as the panel words it: "k actions made" ("1 action made" for one).
    static func actionsMade(_ mirror: Mirror) -> String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return made == 1 ? "1 action made" : "\(made) actions made"
    }

    /// `orbit` moved as the panel's − and + move a pending orbit: the eccentricity clamped to 0 … 15, the direction
    /// wrapped 0 … 23, the size clamped to 8 … 48.
    static func stepped(_ orbit: Orbit, eccentricity: Int, direction: Int, size: Int) -> Orbit {
        let k: Int = min(max(orbit.eccentricity + eccentricity, Orbit.eccentricities.lowerBound),
                         Orbit.eccentricities.upperBound)
        let d: Int = ((orbit.direction + direction) % 24 + 24) % 24
        let a: Int = min(max(orbit.size + size, Orbit.sizes.lowerBound), Orbit.sizes.upperBound)
        return Orbit(size: a, eccentricity: k, direction: d)
    }

    /// One press of an adjustable pending value through the presenter, exactly what the panel's increment or
    /// decrement calls (`movePending(eccentricity:direction:size:)` with one step, negated for the decrement).
    static func adjust(_ presenter: Presenter, eccentricity: Int = 0, direction: Int = 0, size: Int = 0) {
        presenter.movePending(eccentricity: eccentricity, direction: direction, size: size)
    }

    /// Moves the pending eccentricity to `k` and the pending direction to `d` with the adjustable values only (the
    /// direction the shorter way round). Returns the presses made.
    @discardableResult
    static func steerPeriapsis(_ presenter: Presenter, eccentricity k: Int, direction d: Int) -> Int {
        let mirror: Mirror = presenter.mirror
        var presses: Int = 0
        for _ in 0...Orbit.eccentricities.upperBound {
            let now: Int = mirror.pending.eccentricity
            if now == k { break }
            adjust(presenter, eccentricity: now < k ? 1 : -1)
            presses += 1
        }
        for _ in 0..<24 {
            let now: Int = mirror.pending.direction
            if now == d { break }
            let ahead: Int = ((d - now) % 24 + 24) % 24
            adjust(presenter, direction: ahead <= 12 ? 1 : -1)
            presses += 1
        }
        return presses
    }

    /// Moves the pending size to `a` with the adjustable size only. Returns the presses made.
    @discardableResult
    static func steerSize(_ presenter: Presenter, size a: Int) -> Int {
        let mirror: Mirror = presenter.mirror
        var presses: Int = 0
        for _ in Orbit.sizes {
            let now: Int = mirror.pending.size
            if now == a { break }
            adjust(presenter, size: now < a ? 1 : -1)
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
        #expect(presenter.mirror.pendingOrbit == nil, "an accepted action drops the pending orbit",
                sourceLocation: sourceLocation)
        let summary: String = Plan.summaryText(core: new, pending: nil)
        #expect(presenter.mirror.summary == summary, sourceLocation: sourceLocation)
        return plan
    }

    /// The accepted kernel action `action` through ``accepted(_:_:_:_:sourceLocation:)``.
    @discardableResult
    static func accepted(_ shell: Shell, _ recorder: Recorder, _ action: ApsidesWorkshopAction,
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let entry: (control: String, values: [Double]) = ApsidesWorkshopTest.control(action)
        return try accepted(shell, recorder, entry.control, entry.values, sourceLocation: sourceLocation)
    }

    /// Sends the refused `control` with `values` through the presenter one clock second later; expects a refusal, an
    /// unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), its words in the panel and the
    /// bare code in `refusalLog`. Returns the plan and the bare code.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> (plan: Plan, code: String) {
        let presenter: Presenter = shell.presenter
        let digest: String = try ApsidesWorkshopTest.digest(shell)
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
        let bare: String = Mirror.bareCode(result.code)
        #expect(presenter.refusalLog.last == bare, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        let after: String = try ApsidesWorkshopTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        try describe(shell)
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return (plan, bare)
    }

    /// The panel's source text (`Experience/ApsidesWorkshopControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("ApsidesWorkshopControls.swift")
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
@Suite(.serialized) struct ApsidesWorkshopAccessibilityTests {
    typealias Access = ApsidesWorkshopA11y
    typealias Plan = ApsidesWorkshopFeedbackPlan
    typealias Presenter = ApsidesWorkshopPresenter
    typealias Core = ApsidesWorkshopExperienceCore
    typealias Mirror = ApsidesWorkshopMirror
    typealias Orbit = ApsidesWorkshopOrbit

    // MARK: Labels, values and the summary element (FR-R02G1806-001, 005; clarification Q5)

    /// The panel's source gives every control a label and a value before its identifier, and the pending
    /// eccentricity, direction and size an adjustable action whose increment and decrement move the pending orbit
    /// through the presenter like the − and + buttons, with the values of clarification Q5; the Sound toggle is
    /// labelled and reads "on" or "off"; the summary element reads the plan's words.
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
        let eccentricity: Substring? = Access.modifierRun("eccentricity", in: source)
        #expect(eccentricity?.contains(".accessibilityValue(Self.eccentricityValue(mirror.pending.eccentricity))")
                    == true, "the eccentricity reads its pending value")
        #expect(eccentricity?.contains("adjust(direction, eccentricity: 1)") == true)
        let direction: Substring? = Access.modifierRun("direction", in: source)
        #expect(direction?.contains(".accessibilityValue(\"pending periapsis at \\(mirror.pending.direction * 15)°\")")
                    == true, "the direction reads its pending value")
        #expect(direction?.contains("adjust(direction, direction: 1)") == true)
        let size: Substring? = Access.modifierRun("size", in: source)
        #expect(size?.contains(".accessibilityValue(\"pending size \\(mirror.pending.size)\")") == true,
                "the size reads its pending value")
        #expect(size?.contains("adjust(direction, size: 1)") == true)
        let words: [String] = [
            "case .increment: movePending(eccentricity: eccentricity, direction: direction, size: size)",
            "case .decrement: movePending(eccentricity: -eccentricity, direction: -direction, size: -size)",
            "presenter.movePending(eccentricity: eccentricity, direction: direction, size: size)",
            "Button(\"Eccentricity −\") { movePending(eccentricity: -1, direction: 0, size: 0) }",
            "Button(\"Eccentricity +\") { movePending(eccentricity: 1, direction: 0, size: 0) }",
            "Button(\"Direction −\") { movePending(eccentricity: 0, direction: -1, size: 0) }",
            "Button(\"Direction +\") { movePending(eccentricity: 0, direction: 1, size: 0) }",
            "Button(\"Size −\") { movePending(eccentricity: 0, direction: 0, size: -1) }",
            "Button(\"Size +\") { movePending(eccentricity: 0, direction: 0, size: 1) }",
        ]
        for word in words {
            #expect(source.contains(word), "the panel's source holds \(word)")
        }
        let sound: Substring? = Access.modifierRun("sound", in: source)
        #expect(sound?.contains("mirror.soundOn ? \"on\" : \"off\"") == true, "Sound reads on or off")
        let summary: Substring? = Access.modifierRun("summary", in: source)
        #expect(summary?.contains(".accessibilityValue(mirror.summary)") == true, "the summary reads the plan's words")
        #expect(ApsidesWorkshopControls.readableWidth == 520)
        #expect(ApsidesWorkshopControls.eccentricityValue(0) == "pending eccentricity 0.00")
        #expect(ApsidesWorkshopControls.eccentricityValue(1) == "pending eccentricity 0.05")
        #expect(ApsidesWorkshopControls.eccentricityValue(3) == "pending eccentricity 0.15")
        #expect(ApsidesWorkshopControls.eccentricityValue(15) == "pending eccentricity 0.75")
    }

    /// After level 1 is described every value the panel reads is non-empty words; the summary element equals
    /// `summaryText(core:pending:)` with the current orbit; describing the opening routes nothing; the sound is off;
    /// refusals read in the plan's words, with or without the engine's prefix.
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
        let setValue: String = mirror.periapsisSettable || mirror.sizeSettable ? "change" : "no change pending"
        let values: [String] = [mirror.summary, tutorial, hintValue, modeValue, mirror.levelLabel(mirror.pickedLevel),
                                Access.eccentricityValue(mirror), Access.directionValue(mirror),
                                Access.sizeValue(mirror), mirror.orbitLabel, setValue, orbitValue, mirror.tickLabel,
                                mirror.measureLabel, Access.actionsMade(mirror), nextValue, soundValue, mirror.status,
                                mirror.goalLabel, mirror.targetLabel]
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
        #expect(setValue == "no change pending", "nothing is pending at the opening")
        #expect(mirror.status == "Ready", "\(mirror.status)")
        #expect(mirror.pendingOrbit == nil)
        let orbit: Orbit = core.play.orbit
        #expect(Access.eccentricityValue(mirror) == "pending eccentricity " + Access.eccentricityWords(orbit.eccentricity))
        #expect(Access.directionValue(mirror) == "pending periapsis at \(orbit.direction * 15)°")
        #expect(Access.sizeValue(mirror) == "pending size \(orbit.size)")

        // The summary element (clarification Q5): the current orbit while nothing is pending.
        let summary: String = Plan.summaryText(core: core, pending: nil)
        #expect(mirror.summary == summary, "\(mirror.summary)")
        #expect(mirror.summary.contains(Access.pendingSentence(orbit)), "\(mirror.summary)")
        #expect(mirror.summary.contains("Level: "), "\(mirror.summary)")
        #expect(presenter.feedbackLog.isEmpty, "describing the opening plans nothing")

        // Refusals read in the plan's words (clarification Q1), with or without the engine's prefix.
        for entry in Access.refusalSentences {
            let plan: Plan = Plan.refused(code: entry.code)
            #expect(plan.text == entry.text, "\(entry.code): \(plan.text ?? "nil")")
            #expect(plan.kind == .rejection)
            #expect(plan.haptic == .error)
            #expect(Plan.refusalText(code: entry.code) == entry.text)
            #expect(Plan.refusalText(code: Mirror.rulePrefix + entry.code) == entry.text, "\(entry.code) prefixed")
            #expect(Mirror.refusalMessage(code: Mirror.rulePrefix + entry.code) == entry.text,
                    "the panel shows the plan's sentence for \(entry.code)")
        }
        #expect(Plan.hint(text: "Turn the periapsis knob next").kind == .state)
        #expect(Plan.hint(text: "Turn the periapsis knob next").haptic == nil)
    }

    /// The adjustable pending eccentricity, direction and size (`movePending` through the presenter, what each
    /// increment and decrement calls) move the pending orbit exactly like − and +: the eccentricity clamps to 0 … 15,
    /// the direction wraps through 24 steps back to the start, the size clamps to 8 … 48; their values follow; a valid
    /// pending orbit is drawn as the preview; the summary names the pending orbit; the digest and the play stay;
    /// nothing is announced and, with the sound off, no audition plays.
    @Test func adjustablePendingOrbitMovesLikeMinusAndPlus() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: Mirror = presenter.mirror
        let opening: Core = try Access.core(shell)
        let current: Orbit = opening.play.orbit
        let digest: String = try ApsidesWorkshopTest.digest(shell)
        let logBase: Int = presenter.feedbackLog.count
        #expect(mirror.pending == current, "nothing is pending at first")

        // Single steps up and down of each value, then a full turn of the direction.
        var steps: [(e: Int, d: Int, a: Int)] = [(1, 0, 0), (-1, 0, 0), (-1, 0, 0), (1, 0, 0), (0, 1, 0), (0, -1, 0),
                                                 (0, -1, 0), (0, 1, 0), (0, 0, 1), (0, 0, -1), (0, 0, -1), (0, 0, 1)]
        for _ in 0..<24 { steps.append((0, 1, 0)) }
        var model: Orbit = current
        var index: Int = 0
        for step in steps {
            model = Access.stepped(model, eccentricity: step.e, direction: step.d, size: step.a)
            Access.adjust(presenter, eccentricity: step.e, direction: step.d, size: step.a)
            #expect(mirror.pending == model, "step \(index): \(mirror.pending) is \(model)")
            let pendingWant: Orbit? = model == current ? nil : model
            #expect(mirror.pendingOrbit == pendingWant, "step \(index): the pending orbit equal to the current drops")
            #expect(Access.eccentricityValue(mirror) == "pending eccentricity "
                        + Access.eccentricityWords(model.eccentricity))
            #expect(Access.directionValue(mirror) == "pending periapsis at \(model.direction * 15)°")
            #expect(Access.sizeValue(mirror) == "pending size \(model.size)")
            #expect(mirror.summary == Plan.summaryText(core: opening, pending: mirror.pendingOrbit))
            #expect(mirror.summary.contains(Access.pendingSentence(model)), "step \(index): \(mirror.summary)")
            let drawn: ApsidesWorkshopSceneSnapshot? = presenter.lastSnapshot
            if model != current && model.isValid {
                #expect(drawn?.previewOrbit == model, "step \(index): the valid pending orbit is drawn")
            } else if model == current {
                #expect(drawn?.isPreviewing == false, "step \(index): nothing pending, nothing previewed")
            }
            index += 1
        }
        #expect(mirror.pending == current, "the steps return to the current orbit")
        #expect(mirror.pendingOrbit == nil)

        // The clamps: 16 decrements of the eccentricity reach 0 and stay; 41 increments of the size reach 48.
        for _ in 0...Orbit.eccentricities.upperBound { Access.adjust(presenter, eccentricity: -1) }
        #expect(mirror.pending.eccentricity == Orbit.eccentricities.lowerBound, "the eccentricity clamps at 0")
        for _ in Orbit.sizes { Access.adjust(presenter, size: 1) }
        #expect(mirror.pending.size == Orbit.sizes.upperBound, "the size clamps at 48")
        #expect(mirror.pending.direction == current.direction)

        let now: Core = try Access.core(shell)
        #expect(now.play == opening.play, "adjusting never changes the play")
        #expect(presenter.feedbackLog.count == logBase, "adjusting plans nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        let after: String = try ApsidesWorkshopTest.digest(shell)
        #expect(after == digest, "adjusting never changes the digest")
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off plays no audition")
        #expect(presenter.sound.voice == nil)
    }

    // MARK: The accessibility operations alone (SC-R02G1806-001)

    /// Level 1 (seed 0) is won with the accessibility operations alone, following the certified witness: the
    /// adjustable pending values reach each tuning (never announced, no haptic), Set periapsis sends
    /// `orbit.periapsis [k, d]` and Set size `orbit.size [a]` with the pending values, and Play `orbit.play`, through
    /// the presenter; every step routes exactly `after(old:new:)`; the sinks hold the plans' words and haptics in
    /// order; the last is the win outcome with a success haptic and 3 stars.
    @Test func levelOneWonWithTheAccessibilityOperations() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: Mirror = presenter.mirror
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(1)
        try #require(!plan.isEmpty, "level 1 has a certified plan")
        var expected: [Plan] = []
        var tunings: Int = 0

        for action in plan {
            let logBefore: Int = presenter.feedbackLog.count
            let announcedBefore: Int = recorder.announcements.announced.count
            let playedBefore: Int = recorder.haptics.played.count
            switch action {
            case let .periapsis(k, d):
                Access.steerPeriapsis(presenter, eccentricity: k, direction: d)
                try #require(mirror.pending.eccentricity == k, "the adjustable eccentricity reaches \(k)")
                try #require(mirror.pending.direction == d, "the adjustable direction reaches \(d)")
                try #require(mirror.periapsisSettable, "Set periapsis is enabled")
                #expect(presenter.feedbackLog.count == logBefore, "adjusting plans nothing")
                #expect(recorder.announcements.announced.count == announcedBefore, "adjusting is not announced")
                #expect(recorder.haptics.played.count == playedBefore, "adjusting plays no haptic")
                let pending: Orbit = mirror.pending
                let step: Plan = try Access.accepted(shell, recorder, "orbit.periapsis",
                                                     [Double(pending.eccentricity), Double(pending.direction)])
                let words: String = "Periapsis set: eccentricity " + Access.eccentricityWords(k) + ", periapsis at "
                    + "\(d * 15)°. "
                #expect(step.text?.hasPrefix(words) == true, "\(step.text ?? "nil")")
                #expect(step.kind == .state)
                #expect(step.haptic == .selection)
                expected.append(step)
            case let .size(a):
                Access.steerSize(presenter, size: a)
                try #require(mirror.pending.size == a, "the adjustable size reaches \(a)")
                try #require(mirror.sizeSettable, "Set size is enabled")
                #expect(presenter.feedbackLog.count == logBefore, "adjusting plans nothing")
                #expect(recorder.announcements.announced.count == announcedBefore, "adjusting is not announced")
                #expect(recorder.haptics.played.count == playedBefore, "adjusting plays no haptic")
                let step: Plan = try Access.accepted(shell, recorder, "orbit.size", [Double(mirror.pending.size)])
                #expect(step.text?.hasPrefix("Size set to \(a). ") == true, "\(step.text ?? "nil")")
                #expect(step.kind == .state)
                #expect(step.haptic == .selection)
                expected.append(step)
            case .play:
                Issue.record("the certified plan holds tunings only")
            }
            tunings += 1
            let now: Core = try Access.core(shell)
            #expect(now.play.orbit == Access.coreOrbit(after: plan, count: tunings, opening: opening),
                    "the tunings follow the certified plan")
        }
        #expect(tunings == opening.certifiedTunings, "every certified tuning was set")
        let before: Core = try Access.core(shell)
        try #require(before.play.stage == .playing, "\(before.play.stage)")
        let run: Plan = try Access.accepted(shell, recorder, "orbit.play", [])
        expected.append(run)

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won, "\(won.play.stage)")
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(plans.count == tunings + 1, "every step is announced")
        let winText: String = plans.last?.text ?? ""
        #expect(winText.hasPrefix("Every target was met in order. Level won spending "), "\(winText)")
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

    // MARK: A scripted sequence (SC-R02G1806-002; clarifications Q1, Q2)

    /// On level 1: showing a tick (nothing routed); refusals — undo with nothing to undo, a size that is not whole, a
    /// tick outside the revolution when the declared range allows sending it, a level not open yet and an impossible
    /// date — each read in the plan's sentence with an error haptic; the play at the opening (a failure: outcome,
    /// warning, the failure explanation); a tuning after it ("The level has ended."); undo (state); a redo restoring
    /// the failure (outcome only); undo; then the certified first tuning, undo and redo (state, selection): the
    /// recorded announcements and haptics equal the plans exactly, in order.
    @Test func scriptedSequenceAnnouncesExactlyThePlans() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        let level: ApsidesWorkshopLevel = opening.play.level
        let orbit: Orbit = opening.play.orbit
        var expected: [Plan] = []

        // Showing a tick routes nothing.
        try #require(level.period >= 2, "level 1 has at least two ticks")
        recorder.clock.advance()
        let shown: ActionResult = presenter.send("clock.show", [1], port: shell.port)
        #expect(shown == .accepted, "\(shown.code)")
        try Access.describe(shell)
        #expect(presenter.feedbackLog.count == logBase, "showing a tick routes nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)

        // Refusals, each in the plan's sentence.
        let undo: (plan: Plan, code: String) = try Access.refused(shell, recorder, "play.undo", [])
        #expect(undo.code == "r02-g18.action", "\(undo.code)")
        #expect(undo.plan.text == "That orbit cannot be set, or there is nothing to undo or redo.")
        expected.append(undo.plan)
        let half: Double = Double(orbit.size) + 0.5
        let whole: (plan: Plan, code: String) = try Access.refused(shell, recorder, "orbit.size", [half])
        #expect(whole.code == "r02-g18.not-whole", "\(whole.code)")
        #expect(whole.plan.text == "That value must be a whole number.")
        expected.append(whole.plan)
        if level.period <= Core.tickRange.upperBound {
            let outside: (plan: Plan, code: String) = try Access.refused(shell, recorder, "clock.show",
                                                                         [Double(level.period)])
            #expect(outside.code == "r02-g18.tick", "\(outside.code)")
            #expect(outside.plan.text == "That tick is outside the revolution.")
            expected.append(outside.plan)
        }
        if !opening.progress.isOpen(100) {
            let locked: (plan: Plan, code: String) = try Access.refused(shell, recorder, "level.select", [100])
            #expect(locked.code == "r02-g18.locked", "\(locked.code)")
            #expect(locked.plan.text == "That level is not open yet.")
            expected.append(locked.plan)
        }
        let date: (plan: Plan, code: String) = try Access.refused(shell, recorder, "mode.daily", [2026, 2, 30])
        #expect(date.code == "r02-g18.date", "\(date.code)")
        #expect(date.plan.text == "That date cannot be used.")
        expected.append(date.plan)

        // The play at the opening fails.
        let failed: Plan = try Access.accepted(shell, recorder, "orbit.play", [])
        let failedCore: Core = try Access.core(shell)
        #expect(failedCore.play.stage == .failed, "\(failedCore.play.stage)")
        #expect(failed.kind == .outcome)
        #expect(failed.haptic == .warning)
        #expect(failed.text == ApsidesWorkshopFailureExplanation(play: failedCore.play)?.text)
        expected.append(failed)
        let grown: Double = Double(orbit.size < Orbit.sizes.upperBound ? orbit.size + 1 : orbit.size - 1)
        let ended: (plan: Plan, code: String) = try Access.refused(shell, recorder, "orbit.size", [grown])
        #expect(ended.code == "r02-g18.stage", "\(ended.code)")
        #expect(ended.plan.text == "The level has ended.")
        expected.append(ended.plan)
        let undone: Plan = try Access.accepted(shell, recorder, "play.undo", [])
        #expect(undone.kind == .state)
        #expect(undone.haptic == .selection)
        #expect(undone.text?.hasPrefix("Undone. ") == true, "\(undone.text ?? "nil")")
        expected.append(undone)
        let restored: Plan = try Access.accepted(shell, recorder, "play.redo", [])
        let restoredCore: Core = try Access.core(shell)
        #expect(restoredCore.play.stage == .failed, "the redo restores the failed play")
        #expect(restored.kind == .outcome, "a redo restoring a failure plans only the outcome")
        #expect(restored.haptic == .warning)
        expected.append(restored)
        expected.append(try Access.accepted(shell, recorder, "play.undo", []))

        // A tuning, undo and redo.
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(1)
        let change: ApsidesWorkshopAction = try #require(plan.first, "level 1 has a certified tuning")
        let set: Plan = try Access.accepted(shell, recorder, change)
        #expect(set.kind == .state)
        #expect(set.haptic == .selection)
        switch change {
        case let .periapsis(k, d):
            let words: String = "Periapsis set: eccentricity " + Access.eccentricityWords(k) + ", periapsis at "
                + "\(d * 15)°. "
            #expect(set.text?.hasPrefix(words) == true, "\(set.text ?? "nil")")
        case let .size(a):
            #expect(set.text?.hasPrefix("Size set to \(a). ") == true, "\(set.text ?? "nil")")
        case .play:
            Issue.record("the certified plan holds tunings only")
        }
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

    // MARK: Reduce Motion and Reduce Flashing frames (FR-R02G1806-004; SC-R02G1806-003)

    /// Under Reduce Motion, Reduce Flashing and both, two stills of the same won state at different frame times hold
    /// the star pulse at 1, keep the eased lights at the won targets and are byte-identical once the fades settle.
    @Test func reducedFramesOfOneStateAreStill() async throws {
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(1)
        let actions: [ApsidesWorkshopAction] = plan + [.play]
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
            #expect(presenter.scene.starStill, "\(what): the star holds still")
            #expect(ApsidesWorkshopTest.issue(shell, actions) == actions.count)
            let won: Core = try Access.core(shell)
            #expect(won.play.stage == .won, "\(what): \(won.play.stage)")
            let w: Int = Access.stillWidth
            let h: Int = Access.stillHeight
            let base: Double = 10
            // Two first stills let any light fade finish (0.5 s apart, beyond the 0.45 s fade).
            _ = try ApsidesWorkshopTest.still(session, width: w, height: h, time: base)
            _ = try ApsidesWorkshopTest.still(session, width: w, height: h, time: base + 0.5)
            let early: [UInt8] = try ApsidesWorkshopTest.still(session, width: w, height: h, time: base + 0.75)
            let earlyPulse: Double = presenter.scene.lastPulse
            let earlyLights: ApsidesWorkshopLights = presenter.lights
            let late: [UInt8] = try ApsidesWorkshopTest.still(session, width: w, height: h, time: base + 1.9)
            #expect(ApsidesWorkshopTest.drawnPixels(early) > 0, "\(what): the still shows the sky")
            #expect(earlyPulse == 1, "\(what): the pulse is held at 1")
            #expect(presenter.scene.lastPulse == 1, "\(what): the pulse is held at 1")
            #expect(presenter.lights == earlyLights, "\(what): the lights do not move")
            #expect(presenter.lights.isSettled, "\(what): the lights rest")
            #expect(presenter.lights.won == 1, "\(what): the won look rests at 1")
            #expect(presenter.lights.glow == 1, "\(what): the glow rests at 1 once won")
            #expect(presenter.scene.lights == presenter.lights, "\(what): the scene draws the presenter's lights")
            #expect(early == late, "\(what): stills at 0.75 s and 1.9 s are identical")
        }
    }

    /// With neither setting the star pulse follows the frame time (`starPulse(time:reduceMotion:)`), so two frame
    /// times of the same state draw different pulses while the lights rest.
    @Test func fullMotionPulseVariesWithTime() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        Access.quiet(presenter)
        #expect(!presenter.scene.starStill)
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        let times: [Double] = [10.75, 11.9]
        var pulses: [Double] = []
        for time in times {
            _ = try ApsidesWorkshopTest.still(session, width: w, height: h, time: time)
            let want: Double = ApsidesWorkshopShaders.starPulse(time: time, reduceMotion: false)
            #expect(Swift.abs(presenter.scene.lastPulse - want) < 1e-12, "the pulse at \(time) s")
            pulses.append(presenter.scene.lastPulse)
        }
        #expect(pulses[0] != pulses[1], "the pulse varies with time: \(pulses)")
        #expect(presenter.lights.isSettled)
    }

    // MARK: The won look under Reduce Flashing (FR-R02G1806-004; SC-R02G1806-003; clarification Q3)

    /// Under Reduce Flashing, in the shader path and in fallback mode, the drawn won level rises over at least 0.4 s
    /// of frame time after the winning play, sampled every 1/60 s: never falling, below 1 at first, 1 between 0.4 s
    /// and 0.5 s; the scene draws the presenter's lights; the shader frame changes as the level rises (in fallback
    /// mode a winning orbit's gauge marks are already met, so its pixels stay the same).
    @Test func wonBrightensSlowlyUnderReduceFlashing() async throws {
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(1)
        for broken in [false, true] {
            let what: String = broken ? "fallback" : "shader"
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await ApsidesWorkshopTest.open(session, seed: 0, reduceFlashing: true,
                                                           size: CGSize(width: 360, height: 240), atHalf: false,
                                                           configure: { (presenter: Presenter) in
                                                               if broken { presenter.breakCompassShader() }
                                                           })
            let presenter: Presenter = shell.presenter
            Access.quiet(presenter)
            #expect((presenter.fallbackReason != nil) == broken, "\(what): \(presenter.fallbackReason ?? "nil")")
            #expect(ApsidesWorkshopTest.issue(shell, plan) == plan.count)
            let playing: Core = try Access.core(shell)
            try #require(playing.play.stage != .won, "\(what): only the play wins")
            let w: Int = Access.stillWidth * 2
            let h: Int = Access.stillHeight * 2
            let base: Double = 10
            _ = try ApsidesWorkshopTest.still(session, width: w, height: h, time: base - 1)
            _ = try ApsidesWorkshopTest.still(session, width: w, height: h, time: base)
            #expect(presenter.lights.won == 0, "\(what): the won light rests at 0 while playing")
            #expect(presenter.scene.lights?.won == 0)

            let winning: ActionResult = shell.handle(control: "orbit.play", values: [])
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
                let rgba: [UInt8] = try ApsidesWorkshopTest.still(session, width: w, height: h, time: base + offset)
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
            if broken {
                // The fallback's won flag only marks every gauge met (the geometry's `markMaterial`), and a winning
                // orbit's gauges are already met by the prediction, so the unlit won look draws the same pixels; the
                // eased level is still the one drawn (checked above).
                #expect(first == latest, "\(what): a winning orbit's marks are already met, so nothing changes")
            } else {
                #expect(first != latest, "\(what): the won look changes as the level rises")
            }
            #expect(ApsidesWorkshopTest.drawnPixels(latest) > 0, "\(what): the still shows the sky")
            #expect((presenter.fallbackReason != nil) == broken)
        }
    }

    /// The fallback's colour blend without a host: parts of equal size move each colour toward the won colour by the
    /// level, clamped to 0 … 1 (a non-finite level reads 0); parts of different sizes switch whole at 0.5.
    @Test func blendedColoursLerpClampAndSwitch() {
        typealias Scene = ApsidesWorkshopCompassScene
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

    // MARK: Sound (FR-R02G1806-006; SC-R02G1806-004; clarification Q4)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations, and an audition plays only
    /// then; the sound off makes no player and no voice; each input turning off stops a playing loop and a sounding
    /// audition; a new player is made only for a different recipe or the toggle turning on.
    @Test func soundStateTable() throws {
        typealias Recipe = ApsidesWorkshopSoundRecipe
        let opening: Core = try Core.opening(number: 1)
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(1)
        let wonCore: Core = try ApsidesWorkshopTest.coreAfter(1, plan + [.play], showHalf: false)
        let failedCore: Core = try ApsidesWorkshopTest.coreAfter(1, [.play], showHalf: false)
        try #require(wonCore.play.stage == .won, "\(wonCore.play.stage)")
        try #require(failedCore.play.stage == .failed, "\(failedCore.play.stage)")
        let calm: AmbientLoopRecipe = Recipe.recipe(play: opening.play)
        let won: AmbientLoopRecipe = Recipe.recipe(play: wonCore.play)
        let failed: AmbientLoopRecipe = Recipe.recipe(play: failedCore.play)
        try #require(calm != won, "a won play sounds different")
        try #require(calm != failed, "a failed play sounds different")
        try #require(won != failed)
        let sample: ApsidesWorkshopAudition = ApsidesWorkshopAudition.of(opening.play.orbit)
        try #require(!sample.partials.isEmpty, "an orbit's audition has tones")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: ApsidesWorkshopA11yLoopFactory = ApsidesWorkshopA11yLoopFactory()
            let sound: ApsidesWorkshopSound = factory.sound(calm)
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
        let toggles: ApsidesWorkshopA11yLoopFactory = ApsidesWorkshopA11yLoopFactory()
        let live: ApsidesWorkshopSound = toggles.sound(calm)
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
        #expect(!live.audition(ApsidesWorkshopAudition(partials: [])), "silence plays nothing")
        #expect(live.auditionsPlayed == 1)

        // A failing play() changes nothing else.
        let failing: ApsidesWorkshopA11yLoopFactory = ApsidesWorkshopA11yLoopFactory()
        failing.succeeds = false
        let silent: ApsidesWorkshopSound = failing.sound(calm)
        silent.setOnScreen(true)
        silent.setWanted(true)
        #expect(!silent.started, "a failed play() is not started")
        #expect(silent.shouldPlay)

        // Rebuilds only when the recipe differs.
        let factory: ApsidesWorkshopA11yLoopFactory = ApsidesWorkshopA11yLoopFactory()
        let sound: ApsidesWorkshopSound = factory.sound(calm)
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
    /// inactive, moving the pending orbit plays no audition and makes no player or voice, so no audio is touched; the
    /// recipe is offered at the first state and follows a tuning; moving the pending orbit is never announced.
    @Test func presenterAuditionSilentUnlessOnScreenActiveAndOn() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        Access.quiet(presenter)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")
        #expect(Presenter.recipe(opening) == ApsidesWorkshopSoundRecipe.recipe(play: opening.play))

        presenter.movePending(eccentricity: 0, direction: 1, size: 0)
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off: a pending change plays no audition")
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        presenter.movePending(eccentricity: 0, direction: 1, size: 0)
        #expect(presenter.sound.auditionsPlayed == 0, "off screen: a pending change plays no audition")
        presenter.sceneActive(false)
        presenter.controlsAppeared()
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the sound silent")
        presenter.movePending(eccentricity: 0, direction: -1, size: 0)
        #expect(presenter.sound.auditionsPlayed == 0, "inactive: a pending change plays no audition")
        presenter.controlsDisappeared()
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "a pending change keeps the recipe")

        // A tuning re-offers the recipe of its play (kept while the loop cannot play).
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(1)
        let change: ApsidesWorkshopAction = try #require(plan.first)
        var changed: Core = opening
        let result: ActionResult = changed.apply(ApsidesWorkshopTest.experienceAction(change))
        #expect(result == .accepted, "\(result.code)")
        _ = presenter.describe(changed)
        #expect(presenter.sound.recipe == Presenter.recipe(changed), "the recipe follows the play")
        #expect(presenter.mirror.pendingOrbit == nil, "a tuning drops the pending orbit")
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        presenter.sceneActive(true)
        #expect(presenter.sound.auditionsPlayed == 0)
        #expect(presenter.sound.playersMade == 0, "no player was made")
        #expect(presenter.sound.player == nil, "the sound off never touches audio")
        #expect(presenter.sound.voice == nil)
        #expect(presenter.feedbackLog.count == 1, "only the tuning is announced; pending changes are not")
    }

    /// With the sound on, on screen and active, every change of the pending orbit (the adjustable values, as − and +)
    /// plays `ApsidesWorkshopAudition.of(pending)` once, the return to the current orbit included; a step that changes
    /// nothing (the eccentricity clamped at 0) plays none; a new described core plays none; with the sound off again
    /// a further change plays nothing. (This test makes the presenter's real loop and one-shot players.)
    @Test func pendingOrbitChangePlaysOneAuditionWhenTheSoundIsOn() throws {
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

        presenter.movePending(eccentricity: 0, direction: 1, size: 0)
        #expect(presenter.sound.auditionsPlayed == 1, "one change, one audition")
        #expect(presenter.sound.lastAudition == ApsidesWorkshopAudition.of(mirror.pending))
        presenter.movePending(eccentricity: 0, direction: -1, size: 0)
        #expect(mirror.pendingOrbit == nil, "back at the current orbit")
        #expect(presenter.sound.auditionsPlayed == 2, "the return is a change too")
        #expect(presenter.sound.lastAudition == ApsidesWorkshopAudition.of(opening.play.orbit))

        // Down to the clamp: one audition per change, none for a step that changes nothing.
        var changes: Int = 0
        for _ in 0...Orbit.eccentricities.upperBound {
            let before: Orbit = mirror.pending
            presenter.movePending(eccentricity: -1, direction: 0, size: 0)
            if mirror.pending != before { changes += 1 }
        }
        #expect(mirror.pending.eccentricity == Orbit.eccentricities.lowerBound)
        #expect(presenter.sound.auditionsPlayed == 2 + changes, "one audition per change of the pending orbit")
        let atClamp: Int = presenter.sound.auditionsPlayed
        presenter.movePending(eccentricity: -1, direction: 0, size: 0)
        #expect(presenter.sound.auditionsPlayed == atClamp, "an unchanged pending orbit plays no audition")
        #expect(presenter.sound.lastAudition == ApsidesWorkshopAudition.of(mirror.pending))

        // Describing the same core or a new one plays no audition.
        _ = presenter.describe(opening)
        #expect(presenter.sound.auditionsPlayed == atClamp, "describing plays no audition")
        #expect(presenter.feedbackLog.isEmpty, "moving the pending orbit is not announced")

        presenter.setSound(on: false)
        presenter.controlsDisappeared()
        presenter.movePending(eccentricity: 1, direction: 0, size: 0)
        #expect(presenter.sound.auditionsPlayed == atClamp, "no audition once the sound is off")
        #expect(!presenter.sound.shouldPlay)
    }

    /// A knob drag's preview plays no audition, with the sound on, on screen and active; the panel's adjustable
    /// direction then plays one; cancelling the drag sends nothing. (This test makes the presenter's real players.)
    @Test func dragPreviewPlaysNoAudition() async throws {
        typealias Script = ApsidesWorkshopGestureScript
        let number: Int = try #require(try Script.dragLevel(knob: true), "a knob drag fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number, atHalf: true)
        let presenter: Presenter = shell.presenter
        Access.quiet(presenter)
        try Access.describe(shell)
        presenter.setSound(on: true)
        presenter.controlsAppeared()
        presenter.sceneActive(true)
        #expect(presenter.sound.shouldPlay)
        let snapshot: ApsidesWorkshopSceneSnapshot = try Script.drawn(shell)
        let drag: Script.HandleDrag = try #require(Script.handleDrag(snapshot, orbit: presenter.orbit, knob: true),
                                                   "a knob drag fits on the drawn snapshot")
        let digest: String = try ApsidesWorkshopTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(presenter.mirror.preview == drag.pending, "the drag previews its pending orbit")
        #expect(presenter.sound.auditionsPlayed == 0, "a drag preview plays no audition")
        presenter.cancelPointers()
        #expect(presenter.mirror.preview == nil)
        #expect(Script.sent(shell) == sentBefore, "a cancelled drag sends nothing")
        #expect(try ApsidesWorkshopTest.digest(shell) == digest)
        #expect(presenter.sound.auditionsPlayed == 0)

        presenter.movePending(eccentricity: 0, direction: 1, size: 0)
        #expect(presenter.sound.auditionsPlayed == 1, "the adjustable direction plays its audition")
        #expect(presenter.sound.lastAudition == ApsidesWorkshopAudition.of(presenter.mirror.pending))
        presenter.setSound(on: false)
        presenter.controlsDisappeared()
    }
}

extension ApsidesWorkshopA11y {
    /// The orbit of `opening` after the first `count` tunings of `plan` (no host): the certified path.
    static func coreOrbit(after plan: [ApsidesWorkshopAction], count: Int, opening: Core) -> Orbit {
        var core: Core = opening
        var index: Int = 0
        for action in plan where index < count {
            _ = core.apply(ApsidesWorkshopTest.experienceAction(action))
            index += 1
        }
        return core.play.orbit
    }
}
#endif
