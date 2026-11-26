// MicroscopicAuroraAccessibilityTests — feature 486 (R02-G19-06) T-R02G1906-005 (FR-R02G1906-001 … 006;
// SC-R02G1906-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, ported from
// Apsides Workshop's feature-476 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; the presenter's own
// `feedbackLog` holds every routed plan. Every expected text is built from `MicroscopicAuroraFeedbackPlan`
// (`after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `hint(text:)`, `summaryText(core:selected:slot:)`) on the
// cores captured before and after each step. The tests describe the current core after every action, so the
// presenter's latest core is the current one; describing the same core again routes nothing.
// Labels and values: the `.accessibilityLabel` / `.accessibilityValue` modifiers are not inspectable from a unit test
// (SwiftUI's accessibility tree), so the panel's source is read (`#filePath`): every control's modifier run up to its
// identifier carries a label and a value; the slot, site and strength carry an adjustable action whose increment and
// decrement change the selection through the presenter (`changeSelection(_:)`) exactly like the − and + buttons, with
// the words of clarification Q5 ("well n", "site at row r, column c", "strength s"); the sense reads "clockwise" or
// "counterclockwise", Sound "on" or "off", the summary element the plan's words. Every value the panel reads from the
// mirror is non-empty words once level 1 is described. The adjustable slot, site and strength (the panel's closures
// replayed through `changeSelection(_:)`) wrap, wrap over the level's sites and clamp to 1 … 4; they are never
// announced. Level 1 (seed 0) is won with the accessibility operations alone, following the certified plan (one well:
// slot 0 at row 11, column 18, strength 2, clockwise): the adjustable values reach the well, Place sends `well.place`
// with the panel's selection, then Play `swim.play`; every step is announced as `after(old:new:)` and the win as an
// outcome with a success haptic and 3 stars. A scripted sequence on level 1 (a shown tick, refusals of every reachable
// kind, a failed play, a refusal after it, undo, a redo restoring the failure, undo, the certified placement, undo,
// redo) and a revealed hint record exactly the plans' texts and haptics; every refusal reads the plan's sentence with
// an error haptic and the panel shows exactly that sentence. Frames: nothing in the dish moves by time, so with Reduce
// Motion, Reduce Flashing, both and neither, two stills of the same won state at different frame times keep the eased
// lights at the won targets and are byte-identical once the fades settle. Under Reduce Flashing the won level brightens
// over at least 0.4 s of frame time (sampled at 1/60 s), in the shader path and in fallback mode (`breakDishShader()`
// before setup; the fallback dish is rebuilt per tenth of the level, not per frame);
// `MicroscopicAuroraDishScene.blendedColours(off:on:level:)` is checked without a host. Sound: the state table
// (wanted × on screen × active) uses a `MicroscopicAuroraSound` with injected recording loops and voices; the
// presenter's own toggle off, off screen or inactive plays no audition and makes no player; one test turns the
// presenter's sound on screen (the shared ambient loop and one-shot players): a change of the selected well plays
// `MicroscopicAuroraAudition.of(_:placeable:)` once, a change that leaves the well as it was (a clamped strength) plays
// none, and a slot whose site another well holds sounds the beating audition. Explicit timestamps, synthetic data,
// explicit types, plain loops, no sleep (except the bounded hint-search poll of the teaching helpers), no wall-clock
// assertion; each test well under 10 s.
#if os(iOS)
import CoreGraphics
import Foundation
import MicroscopicAuroraCore
import Testing
@testable import MicroscopicAuroraExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class MicroscopicAuroraA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class MicroscopicAuroraA11yLoop: MicroscopicAuroraLoopPlaying {
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
final class MicroscopicAuroraA11yVoice: MicroscopicAuroraAuditionPlaying {
    /// Every audition played, oldest first.
    private(set) var played: [MicroscopicAuroraAudition] = []
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0

    /// A silent recording voice.
    init() {}

    /// Records `audition`; true when it has partials.
    @discardableResult
    func play(_ audition: MicroscopicAuroraAudition) -> Bool {
        played.append(audition)
        return !audition.partials.isEmpty
    }

    /// Records a stop.
    func stop() { stops += 1 }
}

/// Makes fake loops and voices and keeps them.
@MainActor
final class MicroscopicAuroraA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [MicroscopicAuroraA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []
    /// Every voice made, oldest first.
    private(set) var voices: [MicroscopicAuroraA11yVoice] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> MicroscopicAuroraA11yLoop {
        let loop: MicroscopicAuroraA11yLoop = MicroscopicAuroraA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// Makes and keeps one fake voice.
    func makeVoice() -> MicroscopicAuroraA11yVoice {
        let voice: MicroscopicAuroraA11yVoice = MicroscopicAuroraA11yVoice()
        voices.append(voice)
        return voice
    }

    /// A sound policy starting from `recipe` that makes its players and its voice here.
    func sound(_ recipe: AmbientLoopRecipe) -> MicroscopicAuroraSound {
        let player: (AmbientLoopRecipe) -> any MicroscopicAuroraLoopPlaying = { (next: AmbientLoopRecipe) in
            self.make(next)
        }
        let voice: () -> any MicroscopicAuroraAuditionPlaying = { self.makeVoice() }
        return MicroscopicAuroraSound(recipe: recipe, makePlayer: player, makeVoice: voice)
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum MicroscopicAuroraA11y {
    typealias Shell = MicroscopicAuroraTest.Shell
    typealias Plan = MicroscopicAuroraFeedbackPlan
    typealias Core = MicroscopicAuroraExperienceCore
    typealias Presenter = MicroscopicAuroraPresenter
    typealias Mirror = MicroscopicAuroraMirror
    typealias Well = MicroscopicAuroraWell
    typealias Cell = MicroscopicAuroraCell

    /// A recording route on a presenter.
    struct Recorder {
        /// The haptics played, in order.
        let haptics: RecordingHapticSink
        /// The announcements posted, in order.
        let announcements: RecordingAnnouncementSink
        /// The clock of the route.
        let clock: MicroscopicAuroraA11yClock
    }

    /// The still size of the frame tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// Level 1's certified well (its stored witness): slot 0 at row 11, column 18, strength 2, clockwise.
    static let levelOneSlot: Int = 0
    static let levelOneWell: Well = Well(cell: Cell(row: 11, column: 18), strength: 2, sense: .clockwise)

    /// The controls of the panel by identifier name: each needs a label and a value (clarification Q5). The plain
    /// texts (actions, status, failure, progress, message, wells and tick detail lines, the bare tick, the selection
    /// line, tutorial, hint text, band, stars, goal) are read as text, not controls.
    static let controlNames: [String] = ["sound", "summary", "dismiss-tutorial", "hint", "slot-minus", "slot",
                                         "slot-plus", "site-minus", "site", "site-plus", "strength-minus", "strength",
                                         "strength-plus", "sense", "place", "remove", "tick-minus", "tick-plus",
                                         "play", "undo", "redo", "next-level", "campaign", "daily", "practice",
                                         "level-picker", "play-level", "freeze", "reset-view"]
    /// The adjustable elements (increment and decrement).
    static let adjustableNames: [String] = ["slot", "site", "strength"]

    /// The refusal codes of clarification Q1 with their sentences; any other code reads "That action was refused.".
    static let refusalSentences: [(code: String, text: String)] = [
        ("r02-g19.locked", "That level is not open yet."),
        ("r02-g19.date", "That date cannot be used."),
        ("r02-g19.action", "That well cannot be placed there, or there is nothing to remove, undo or redo."),
        ("r02-g19.budget", "No actions are left: undo or retry."),
        ("r02-g19.stage", "The level has ended."),
        ("r02-g19.stale", "The play changed before the action arrived."),
        ("r02-g19.level", "That level could not be made."),
        ("r02-g19.not-whole", "That value must be a whole number."),
        ("r02-g19.tick", "That tick is outside the swim."),
        ("r02-g19.malformed", "That action was refused."),
        ("action.out-of-range", "That action was refused."),
        ("r02-g19.unknown", "That action was refused."),
    ]

    /// Opens level `number` (seed `number − 1`) at a 360 × 240-point view (one frame drawn, tick 0 shown) and
    /// describes the opening so the presenter holds the latest core.
    static func open(_ session: ExperienceSession, number: Int = 1, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await MicroscopicAuroraTest.open(session, seed: UInt64(number - 1),
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
        let clock: MicroscopicAuroraA11yClock = MicroscopicAuroraA11yClock()
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
        try MicroscopicAuroraTest.core(shell)
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

    /// Undo and Redo's value as the panel words it: "k actions made" ("1 action made" for one).
    static func actionsMade(_ mirror: Mirror) -> String {
        let made: Int = max(mirror.budget - mirror.actionsLeft, 0)
        return made == 1 ? "1 action made" : "\(made) actions made"
    }

    /// The site's value as the panel words it (clarification Q5): "site at row r, column c", or "no site".
    static func siteValue(_ mirror: Mirror) -> String {
        guard let site = mirror.selectedSite else { return "no site" }
        return "site at " + MicroscopicAuroraLevel.cellWords(site)
    }

    /// The sense's value as the panel words it: "clockwise" or "counterclockwise".
    static func senseValue(_ mirror: Mirror) -> String {
        mirror.counterclockwise ? "counterclockwise" : "clockwise"
    }

    /// The summary element's words for the presenter's latest core `core` and the panel's selection.
    static func summary(_ core: Core, _ mirror: Mirror) -> String {
        Plan.summaryText(core: core, selected: mirror.selectedWell, slot: mirror.slot)
    }

    // MARK: The panel's selection operations (what each adjustable value's increment and decrement calls)

    /// One step of the adjustable slot (`Well −` / `Well +`): the slot wraps over 0 … 2.
    static func stepSlot(_ presenter: Presenter, _ step: Int) {
        presenter.changeSelection { (mirror: Mirror) in mirror.slot = ((mirror.slot + step) % 3 + 3) % 3 }
    }

    /// One step of the adjustable site (`Site −` / `Site +`): the site index wraps over the level's sites.
    static func stepSite(_ presenter: Presenter, _ step: Int) {
        presenter.changeSelection { (mirror: Mirror) in
            let count: Int = max(1, mirror.sites.count)
            mirror.siteIndex = ((mirror.siteIndex + step) % count + count) % count
        }
    }

    /// One step of the adjustable strength (`Strength −` / `Strength +`): clamped to 1 … 4.
    static func stepStrength(_ presenter: Presenter, _ step: Int) {
        presenter.changeSelection { (mirror: Mirror) in mirror.strength = min(4, max(1, mirror.strength + step)) }
    }

    /// The sense toggle (`Clockwise` / `Counterclockwise`).
    static func toggleSense(_ presenter: Presenter) {
        presenter.changeSelection { (mirror: Mirror) in mirror.counterclockwise.toggle() }
    }

    /// The index of `cell` among the mirror's sites, or nil when it is not a site.
    static func siteIndex(of cell: Cell, in mirror: Mirror) -> Int? {
        var index: Int = 0
        for site in mirror.sites {
            if site == cell { return index }
            index += 1
        }
        return nil
    }

    /// Steers the panel's selection to `well` in `slot` with the adjustable operations only (the slot and the site
    /// forward, the strength the shorter way, the sense by its toggle). Returns the operations made.
    @discardableResult
    static func steer(_ presenter: Presenter, slot: Int, well: Well) throws -> Int {
        let mirror: Mirror = presenter.mirror
        var operations: Int = 0
        for _ in 0..<3 {
            if mirror.slot == slot { break }
            stepSlot(presenter, 1)
            operations += 1
        }
        let target: Int = try #require(siteIndex(of: well.cell, in: mirror), "the well stands on a level site")
        for _ in 0..<max(1, mirror.sites.count) {
            if mirror.siteIndex == target { break }
            stepSite(presenter, 1)
            operations += 1
        }
        for _ in 0..<4 {
            if mirror.strength == well.strength { break }
            stepStrength(presenter, mirror.strength < well.strength ? 1 : -1)
            operations += 1
        }
        if mirror.counterclockwise != (well.sense == .counterclockwise) {
            toggleSense(presenter)
            operations += 1
        }
        return operations
    }

    /// What the panel's Place sends for the current selection: `well.place [slot, row, column, strength, sense]`.
    static func placeValues(_ mirror: Mirror) throws -> [Double] {
        let site: Cell = try #require(mirror.selectedSite, "the level has a site")
        return [Double(mirror.slot), Double(site.row), Double(site.column), Double(mirror.strength),
                mirror.counterclockwise ? 1 : 0]
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
        #expect(presenter.mirror.summary == summary(new, presenter.mirror), sourceLocation: sourceLocation)
        return plan
    }

    /// The accepted kernel action `action` through ``accepted(_:_:_:_:sourceLocation:)``.
    @discardableResult
    static func accepted(_ shell: Shell, _ recorder: Recorder, _ action: MicroscopicAuroraAction,
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let entry: (control: String, values: [Double]) = MicroscopicAuroraTest.control(action)
        return try accepted(shell, recorder, entry.control, entry.values, sourceLocation: sourceLocation)
    }

    /// Sends the refused `control` with `values` through the presenter one clock second later; expects a refusal, an
    /// unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), exactly its words in the panel and
    /// the bare code in `refusalLog`. Returns the plan and the bare code.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> (plan: Plan, code: String) {
        let presenter: Presenter = shell.presenter
        let digest: String = try MicroscopicAuroraTest.digest(shell)
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
        let after: String = try MicroscopicAuroraTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        try describe(shell)
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return (plan, bare)
    }

    // MARK: The panel's source

    /// The panel's source text (`Experience/MicroscopicAuroraControls.swift`, beside this test's folder).
    static func panelSource() throws -> String {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let file: URL = tests.deletingLastPathComponent().appendingPathComponent("Experience")
            .appendingPathComponent("MicroscopicAuroraControls.swift")
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
@Suite(.serialized) struct MicroscopicAuroraAccessibilityTests {
    typealias Access = MicroscopicAuroraA11y
    typealias Plan = MicroscopicAuroraFeedbackPlan
    typealias Presenter = MicroscopicAuroraPresenter
    typealias Core = MicroscopicAuroraExperienceCore
    typealias Mirror = MicroscopicAuroraMirror
    typealias Well = MicroscopicAuroraWell

    // MARK: Labels, values and the summary element (FR-R02G1906-001, 005; SC-R02G1906-001; clarification Q5)

    /// The panel's source gives every control a label and a value before its identifier; the slot, site and strength
    /// an adjustable action whose increment and decrement change the selection through the presenter like the − and +
    /// buttons, with the values of clarification Q5; the sense reads "clockwise" or "counterclockwise"; Sound reads
    /// "on" or "off"; the summary element reads the mirror's summary; the panel keeps a 520-point readable width.
    @Test func everyControlCarriesALabelAndAValueInTheSource() throws {
        let source: String = try Access.panelSource()
        for name in Access.controlNames {
            let run: Substring? = Access.modifierRun(name, in: source)
            #expect(run != nil, "\(name) has an identifier")
            guard let run else { continue }
            #expect(run.contains(".accessibilityLabel("), "\(name) has a label")
            #expect(run.contains(".accessibilityValue("), "\(name) has a value")
        }
        for name in Access.adjustableNames {
            let run: Substring? = Access.modifierRun(name, in: source)
            #expect(run?.contains(".accessibilityAdjustableAction") == true, "\(name) is adjustable")
        }
        let slot: Substring? = Access.modifierRun("slot", in: source)
        #expect(slot?.contains(".accessibilityValue(\"well \\(mirror.slot + 1)\")") == true, "the slot's value")
        #expect(slot?.contains("adjust(direction, slot: true)") == true)
        let site: Substring? = Access.modifierRun("site", in: source)
        #expect(site?.contains("\"site at \" + MicroscopicAuroraLevel.cellWords($0)") == true, "the site's value")
        #expect(site?.contains("adjust(direction, site: true)") == true)
        let strength: Substring? = Access.modifierRun("strength", in: source)
        #expect(strength?.contains(".accessibilityValue(\"strength \\(mirror.strength)\")") == true,
                "the strength's value")
        #expect(strength?.contains("adjust(direction, strength: true)") == true)
        let sense: Substring? = Access.modifierRun("sense", in: source)
        #expect(sense?.contains(".accessibilityValue(mirror.counterclockwise ? \"counterclockwise\" : \"clockwise\")")
                    == true, "the sense reads its words")
        let words: [String] = [
            "if let presenter { presenter.changeSelection(change) } else { change(mirror) }",
            "if slot { select { mirror in mirror.slot = ((mirror.slot + step) % 3 + 3) % 3 } }",
            "if site { moveSite(step) }",
            "if strength { select { mirror in mirror.strength = min(4, max(1, mirror.strength + step)) } }",
            "Button(\"Well −\") { select { mirror in mirror.slot = (mirror.slot + 2) % 3 } }",
            "Button(\"Well +\") { select { mirror in mirror.slot = (mirror.slot + 1) % 3 } }",
            "Button(\"Site −\") { moveSite(-1) }",
            "Button(\"Site +\") { moveSite(1) }",
            "Button(\"Strength −\") { select { mirror in mirror.strength = max(1, mirror.strength - 1) } }",
            "Button(\"Strength +\") { select { mirror in mirror.strength = min(4, mirror.strength + 1) } }",
            "select { mirror in mirror.counterclockwise.toggle() }",
            "mirror.siteIndex = ((mirror.siteIndex + step) % count + count) % count",
        ]
        for word in words {
            #expect(source.contains(word), "the panel's source holds \(word)")
        }
        let sound: Substring? = Access.modifierRun("sound", in: source)
        #expect(sound?.contains("mirror.soundOn ? \"on\" : \"off\"") == true, "Sound reads on or off")
        let summary: Substring? = Access.modifierRun("summary", in: source)
        #expect(summary?.contains(".accessibilityValue(mirror.summary)") == true, "the summary reads the plan's words")
        let freeze: Substring? = Access.modifierRun("freeze", in: source)
        #expect(freeze?.contains("mirror.frozen ? \"frozen\" : \"not frozen\"") == true)
        #expect(freeze?.contains(".accessibilityLabel(mirror.frozen ? \"Unfreeze the swim\" : \"Freeze the swim\")")
                    == true, "Freeze is labelled in words")
        #expect(MicroscopicAuroraControls.readableWidth == 520)
    }

    /// After level 1 is described every value the panel reads is non-empty words; the summary element equals
    /// `summaryText(core:selected:slot:)` of the opening and the panel's selection; describing the opening routes
    /// nothing; the sound is off; refusals read in the plan's words, with or without the engine's prefix.
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
        let frozenValue: String = mirror.frozen ? "frozen" : "not frozen"
        let modeValue: String = Mirror.modeName(mirror.mode) == "campaign" ? "selected" : "not selected"
        let values: [String] = [mirror.summary, tutorial, hintValue, modeValue, mirror.levelLabel(mirror.pickedLevel),
                                "well \(mirror.slot + 1)", Access.siteValue(mirror), "strength \(mirror.strength)",
                                Access.senseValue(mirror), mirror.selectionLabel, mirror.wellsLabel,
                                mirror.measureLabel, mirror.tickLabel, Access.actionsMade(mirror), nextValue,
                                frozenValue, orbitValue, soundValue, mirror.status, mirror.goalLabel,
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
        #expect(frozenValue == "not frozen")
        #expect(modeValue == "selected", "the campaign is selected")
        #expect(soundValue == "off", "the Sound toggle is off by default")
        #expect(mirror.status == "Ready", "\(mirror.status)")
        #expect(!mirror.sites.isEmpty, "level 1 has sites")
        #expect(Access.siteValue(mirror).hasPrefix("site at row "), "\(Access.siteValue(mirror))")

        // The summary element (clarification Q5).
        let summary: String = Plan.summaryText(core: core, selected: mirror.selectedWell, slot: mirror.slot)
        #expect(mirror.summary == summary, "\(mirror.summary)")
        #expect(mirror.summary.hasPrefix(Access.actionsLeftWords(core.play.actionsLeft).capitalizedForTest + ". "),
                "\(mirror.summary)")
        let well: Well = try #require(mirror.selectedWell, "a site is selected")
        let selected: String = "Selected: " + core.play.level.wellDescription(mirror.slot, well: well) + ". "
        #expect(mirror.summary.contains(selected), "\(mirror.summary)")
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
        #expect(Plan.hint(text: "Use the site at row 11, column 18 next").kind == .state)
        #expect(Plan.hint(text: "Use the site at row 11, column 18 next").haptic == nil)
    }

    /// The adjustable slot, site and strength and the sense toggle (the panel's closures through `changeSelection`)
    /// move the selection exactly like − and +: the slot wraps 0 … 2, the site wraps over the level's sites back to the
    /// start, the strength clamps to 1 … 4, the sense toggles; their values follow; the summary names the selection;
    /// the digest and the play stay; nothing is announced and, with the sound off, no audition plays.
    @Test func adjustableSelectionMovesLikeMinusAndPlus() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Access.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: Mirror = presenter.mirror
        let opening: Core = try Access.core(shell)
        let digest: String = try MicroscopicAuroraTest.digest(shell)
        let logBase: Int = presenter.feedbackLog.count
        let siteCount: Int = mirror.sites.count
        try #require(siteCount > 0, "level 1 has sites")

        // The slot: three increments wrap back, one decrement wraps to well 3.
        let slotStart: Int = mirror.slot
        for step in 1...3 {
            Access.stepSlot(presenter, 1)
            #expect(mirror.slot == (slotStart + step) % 3, "slot step \(step)")
            #expect("well \(mirror.slot + 1)" == "well \((slotStart + step) % 3 + 1)")
        }
        Access.stepSlot(presenter, -1)
        #expect(mirror.slot == (slotStart + 2) % 3, "the slot wraps down")
        Access.stepSlot(presenter, 1)
        #expect(mirror.slot == slotStart)

        // The site: a full turn over the level's sites returns to the start; the value names each site.
        let siteStart: Int = mirror.siteIndex
        for step in 1...siteCount {
            Access.stepSite(presenter, 1)
            let want: Int = (siteStart + step) % siteCount
            #expect(mirror.siteIndex == want, "site step \(step)")
            #expect(Access.siteValue(mirror) == "site at " + MicroscopicAuroraLevel.cellWords(mirror.sites[want]))
            #expect(mirror.summary == Access.summary(opening, mirror), "site step \(step): \(mirror.summary)")
        }
        Access.stepSite(presenter, -1)
        #expect(mirror.siteIndex == (siteStart + siteCount - 1) % siteCount, "the site wraps down")
        Access.stepSite(presenter, 1)
        #expect(mirror.siteIndex == siteStart)

        // The strength clamps at 4 and at 1.
        for _ in 0..<5 { Access.stepStrength(presenter, 1) }
        #expect(mirror.strength == 4, "the strength clamps at 4")
        #expect("strength \(mirror.strength)" == "strength 4")
        for _ in 0..<5 { Access.stepStrength(presenter, -1) }
        #expect(mirror.strength == 1, "the strength clamps at 1")

        // The sense toggles and reads its words.
        let senseStart: Bool = mirror.counterclockwise
        Access.toggleSense(presenter)
        #expect(mirror.counterclockwise == !senseStart)
        #expect(Access.senseValue(mirror) == (senseStart ? "clockwise" : "counterclockwise"))
        Access.toggleSense(presenter)
        #expect(mirror.counterclockwise == senseStart)
        #expect(mirror.summary == Access.summary(opening, mirror))

        let now: Core = try Access.core(shell)
        #expect(now.play == opening.play, "changing the selection never changes the play")
        #expect(presenter.feedbackLog.count == logBase, "changing the selection plans nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)
        let after: String = try MicroscopicAuroraTest.digest(shell)
        #expect(after == digest, "changing the selection never changes the digest")
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off plays no audition")
        #expect(presenter.sound.voice == nil)
    }

    // MARK: The accessibility operations alone (SC-R02G1906-001; clarifications Q1, Q2)

    /// Level 1 (seed 0) is won with the accessibility operations alone, following the certified plan (slot 0 at row
    /// 11, column 18, strength 2, clockwise): the adjustable selection reaches each well (never announced, no
    /// haptic), Place sends `well.place` with the panel's selection, Play `swim.play`, through the presenter; every
    /// step routes exactly `after(old:new:)`; the sinks hold the plans' words and haptics in order; the last is the win
    /// outcome with a success haptic and 3 stars.
    @Test func levelOneWonWithTheAccessibilityOperations() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Access.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: Mirror = presenter.mirror
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(1)
        try #require(!plan.isEmpty, "level 1 has a certified plan")
        if case let .place(slot, well)? = plan.first {
            #expect(slot == Access.levelOneSlot, "the certified well is in slot 0")
            #expect(well == Access.levelOneWell, "the certified well: row 11, column 18, strength 2, clockwise")
        } else {
            Issue.record("level 1's certified plan starts with a placement")
        }
        var expected: [Plan] = []
        var placements: Int = 0

        for action in plan {
            let logBefore: Int = presenter.feedbackLog.count
            let announcedBefore: Int = recorder.announcements.announced.count
            let playedBefore: Int = recorder.haptics.played.count
            switch action {
            case let .place(slot, well):
                try Access.steer(presenter, slot: slot, well: well)
                try #require(mirror.slot == slot, "the adjustable slot reaches \(slot)")
                try #require(mirror.selectedWell == well, "the adjustable selection reaches \(well)")
                #expect(Access.siteValue(mirror) == "site at " + MicroscopicAuroraLevel.cellWords(well.cell))
                #expect("strength \(mirror.strength)" == "strength \(well.strength)")
                #expect(Access.senseValue(mirror) == well.sense.rawValue)
                #expect(presenter.feedbackLog.count == logBefore, "changing the selection plans nothing")
                #expect(recorder.announcements.announced.count == announcedBefore, "the selection is not announced")
                #expect(recorder.haptics.played.count == playedBefore, "the selection plays no haptic")
                let values: [Double] = try Access.placeValues(mirror)
                let step: Plan = try Access.accepted(shell, recorder, "well.place", values)
                let words: String = "Well \(slot + 1) placed at " + MicroscopicAuroraLevel.cellWords(well.cell)
                    + ", strength \(well.strength), " + well.sense.rawValue + ". "
                #expect(step.text?.hasPrefix(words) == true, "\(step.text ?? "nil")")
                #expect(step.text?.hasSuffix(" left.") == true, "\(step.text ?? "nil")")
                #expect(step.kind == .state)
                #expect(step.haptic == .selection)
                expected.append(step)
                placements += 1
            case .remove:
                Issue.record("the certified plan holds placements only")
            case .play:
                Issue.record("the certified plan holds placements only")
            }
        }
        #expect(placements == opening.certifiedPlacements, "every certified well was placed")
        let before: Core = try Access.core(shell)
        try #require(before.play.stage == .playing, "\(before.play.stage)")
        #expect(before.play.report.wins, "playing now would win")
        let run: Plan = try Access.accepted(shell, recorder, "swim.play", [])
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

    // MARK: A scripted sequence (SC-R02G1906-002; clarifications Q1, Q2)

    /// On level 1: showing a tick (nothing routed); refusals — undo with nothing to undo, removing an empty slot, a
    /// strength that is not whole, a tick past the swim, a level not open yet and an impossible date — each read in the
    /// plan's sentence with an error haptic; the play at the opening (no well: a failure, outcome, warning, the failure
    /// explanation); a placement after it ("The level has ended."); undo (state); a redo restoring the failure (outcome
    /// only); undo; then the certified placement, undo and redo (state, selection): the recorded announcements and
    /// haptics equal the plans exactly, in order.
    @Test func scriptedSequenceAnnouncesExactlyThePlans() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Access.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        let ticks: Int = opening.play.report.ticks
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(1)
        let first: MicroscopicAuroraAction = try #require(plan.first, "level 1 has a certified placement")
        let firstEntry: (control: String, values: [Double]) = MicroscopicAuroraTest.control(first)
        var expected: [Plan] = []

        // Showing a tick routes nothing.
        try #require(ticks >= 1, "level 1 swims at least one tick")
        recorder.clock.advance()
        let shown: ActionResult = presenter.send("clock.show", [1], port: shell.port)
        #expect(shown == .accepted, "\(shown.code)")
        try Access.describe(shell)
        #expect(presenter.feedbackLog.count == logBase, "showing a tick routes nothing")
        #expect(recorder.announcements.announced.isEmpty)
        #expect(recorder.haptics.played.isEmpty)

        // Refusals, each in the plan's sentence.
        let undo: (plan: Plan, code: String) = try Access.refused(shell, recorder, "play.undo", [])
        #expect(undo.code == "r02-g19.action", "\(undo.code)")
        #expect(undo.plan.text == "That well cannot be placed there, or there is nothing to remove, undo or redo.")
        expected.append(undo.plan)
        let empty: (plan: Plan, code: String) = try Access.refused(shell, recorder, "well.remove", [0])
        #expect(empty.code == "r02-g19.action", "\(empty.code)")
        expected.append(empty.plan)
        var half: [Double] = firstEntry.values
        if half.count == 5 { half[3] = half[3] + 0.5 }
        let whole: (plan: Plan, code: String) = try Access.refused(shell, recorder, "well.place", half)
        #expect(whole.code == "r02-g19.not-whole", "\(whole.code)")
        #expect(whole.plan.text == "That value must be a whole number.")
        expected.append(whole.plan)
        let outside: (plan: Plan, code: String) = try Access.refused(shell, recorder, "clock.show",
                                                                     [Double(ticks + 1)])
        #expect(outside.code == "r02-g19.tick", "\(outside.code)")
        #expect(outside.plan.text == "That tick is outside the swim.")
        expected.append(outside.plan)
        if opening.progress.frontier == 1 {
            let locked: (plan: Plan, code: String) = try Access.refused(shell, recorder, "level.select", [2])
            #expect(locked.code == "r02-g19.locked", "\(locked.code)")
            #expect(locked.plan.text == "That level is not open yet.")
            expected.append(locked.plan)
        }
        let date: (plan: Plan, code: String) = try Access.refused(shell, recorder, "mode.daily", [2026, 2, 30])
        #expect(date.code == "r02-g19.date", "\(date.code)")
        #expect(date.plan.text == "That date cannot be used.")
        expected.append(date.plan)

        // The play at the opening (no well) fails.
        let failed: Plan = try Access.accepted(shell, recorder, "swim.play", [])
        let failedCore: Core = try Access.core(shell)
        #expect(failedCore.play.stage == .failed, "\(failedCore.play.stage)")
        #expect(failed.kind == .outcome)
        #expect(failed.haptic == .warning)
        #expect(failed.text == MicroscopicAuroraFailureExplanation(play: failedCore.play)?.text)
        expected.append(failed)
        let ended: (plan: Plan, code: String) = try Access.refused(shell, recorder, firstEntry.control,
                                                                   firstEntry.values)
        #expect(ended.code == "r02-g19.stage", "\(ended.code)")
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

        // The certified placement, undo and redo.
        let set: Plan = try Access.accepted(shell, recorder, first)
        #expect(set.kind == .state)
        #expect(set.haptic == .selection)
        if case let .place(slot, well) = first {
            let words: String = "Well \(slot + 1) placed at " + MicroscopicAuroraLevel.cellWords(well.cell)
                + ", strength \(well.strength), " + well.sense.rawValue + ". "
            #expect(set.text?.hasPrefix(words) == true, "\(set.text ?? "nil")")
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

    /// A revealed hint is announced as `state` with its words and no haptic (clarification Q1): level 1's first hint
    /// at its opening; the searching line is not announced; the panel's selection is not either.
    @Test func revealedHintIsAnnouncedAsState() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Access.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        recorder.clock.advance()
        try await MicroscopicAuroraTeaching.pressHint(presenter)
        let text: String = MicroscopicAuroraTeaching.levelOneOpeningHints[0]
        #expect(presenter.mirror.hintText == text, "\(presenter.mirror.hintText ?? "nil")")
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == [Plan.hint(text: text)], "\(plans)")
        #expect(recorder.announcements.announced == [text])
        #expect(recorder.haptics.played.isEmpty, "a hint plays no haptic")
        #expect(!recorder.announcements.announced.contains(Presenter.searchingText))
    }

    // MARK: Reduce Motion and Reduce Flashing frames (FR-R02G1906-004; SC-R02G1906-003)

    /// With Reduce Motion, Reduce Flashing, both and neither, two stills of the same won state at different frame
    /// times keep the eased lights at the won targets and are byte-identical once the fades settle (nothing in the
    /// dish moves by time).
    @Test func framesOfOneStateAreStill() async throws {
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(1)
        let actions: [MicroscopicAuroraAction] = plan + [.play]
        let modes: [(motion: Bool, flashing: Bool)] = [(true, false), (false, true), (true, true), (false, false)]
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
            #expect(MicroscopicAuroraTest.issue(shell, actions) == actions.count)
            let won: Core = try Access.core(shell)
            #expect(won.play.stage == .won, "\(what): \(won.play.stage)")
            let w: Int = Access.stillWidth
            let h: Int = Access.stillHeight
            let base: Double = 10
            // Two first stills let any light fade finish (0.5 s apart, beyond the 0.45 s fade).
            _ = try MicroscopicAuroraTest.still(session, width: w, height: h, time: base)
            _ = try MicroscopicAuroraTest.still(session, width: w, height: h, time: base + 0.5)
            let early: [UInt8] = try MicroscopicAuroraTest.still(session, width: w, height: h, time: base + 0.75)
            let earlyLights: MicroscopicAuroraLights = presenter.lights
            let late: [UInt8] = try MicroscopicAuroraTest.still(session, width: w, height: h, time: base + 1.9)
            #expect(MicroscopicAuroraTest.drawnPixels(early) > 0, "\(what): the still shows the dish")
            #expect(presenter.lights == earlyLights, "\(what): the lights do not move")
            #expect(presenter.lights.isSettled, "\(what): the lights rest")
            #expect(presenter.lights.won == 1, "\(what): the won look rests at 1")
            #expect(presenter.lights.glow == MicroscopicAuroraLights.glowWon, "\(what): the glow rests once won")
            #expect(presenter.scene.lights == presenter.lights, "\(what): the scene draws the presenter's lights")
            #expect(early == late, "\(what): stills at 0.75 s and 1.9 s are identical")
        }
    }

    // MARK: The won look under Reduce Flashing (FR-R02G1906-004; SC-R02G1906-003; clarification Q3)

    /// Under Reduce Flashing, in the shader path and in fallback mode, the drawn won level rises over at least 0.4 s
    /// of frame time after the winning play, sampled every 1/60 s: never falling, between 0 and 1 at first, 1 between
    /// 0.4 s and 0.5 s; the scene draws the presenter's lights; the shader frame changes as the level rises; the
    /// fallback dish is rebuilt about once per tenth of the level, never once per frame.
    @Test func wonBrightensSlowlyUnderReduceFlashing() async throws {
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(1)
        for broken in [false, true] {
            let what: String = broken ? "fallback" : "shader"
            let session: ExperienceSession = ExperienceSession()
            defer { session.close() }
            let configure: (Presenter) -> Void = { (presenter: Presenter) in
                if broken { presenter.breakDishShader() }
            }
            let shell: Access.Shell = try await MicroscopicAuroraTest.open(session, seed: 0, reduceFlashing: true,
                                                                           size: CGSize(width: 360, height: 240),
                                                                           atHalf: false, configure: configure)
            let presenter: Presenter = shell.presenter
            Access.quiet(presenter)
            #expect((presenter.fallbackReason != nil) == broken, "\(what): \(presenter.fallbackReason ?? "nil")")
            #expect(MicroscopicAuroraTest.issue(shell, plan) == plan.count)
            let playing: Core = try Access.core(shell)
            try #require(playing.play.stage != .won, "\(what): only the play wins")
            let w: Int = Access.stillWidth * 2
            let h: Int = Access.stillHeight * 2
            let base: Double = 10
            _ = try MicroscopicAuroraTest.still(session, width: w, height: h, time: base - 1)
            _ = try MicroscopicAuroraTest.still(session, width: w, height: h, time: base)
            #expect(presenter.lights.won == 0, "\(what): the won light rests at 0 while playing")
            #expect(presenter.scene.lights?.won == 0)

            let winning: ActionResult = shell.handle(control: "swim.play", values: [])
            #expect(winning == .accepted, "\(what): \(winning.code)")
            let won: Core = try Access.core(shell)
            #expect(won.play.stage == .won, "\(what): \(won.play.stage)")

            let buildsBefore: Int = presenter.scene.dishBuilds
            let frame: Double = 1.0 / 60
            let steps: Int = 36
            var previous: Double = 0
            var reachedAt: Double?
            var first: [UInt8] = []
            var latest: [UInt8] = []
            for step in 1...steps {
                let offset: Double = Double(step) * frame
                let rgba: [UInt8] = try MicroscopicAuroraTest.still(session, width: w, height: h, time: base + offset)
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
            let builds: Int = presenter.scene.dishBuilds - buildsBefore
            if broken {
                // The fallback dish is rebuilt when the stage changes and each time the level crosses a tenth.
                #expect(builds >= 10, "\(what): the fallback follows the level by tenths: \(builds) builds")
                #expect(builds <= 12, "\(what): the fallback is not rebuilt every frame: \(builds) builds")
            } else {
                #expect(first != latest, "\(what): the won look changes as the level rises")
            }
            #expect(MicroscopicAuroraTest.drawnPixels(latest) > 0, "\(what): the still shows the dish")
            #expect((presenter.fallbackReason != nil) == broken)
        }
    }

    /// The fallback's colour blend without a host: parts of equal size move each colour toward the won colour by the
    /// level, clamped to 0 … 1 (a non-finite level reads 0); parts of different sizes switch whole at 0.5.
    @Test func blendedColoursLerpClampAndSwitch() {
        typealias Scene = MicroscopicAuroraDishScene
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

    // MARK: Sound (FR-R02G1906-006; SC-R02G1906-004; clarification Q4)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations, and an audition plays only
    /// then; the sound off makes no player and no voice; each input turning off stops a playing loop and a sounding
    /// audition; a new player is made only for a different recipe or the toggle turning on.
    @Test func soundStateTable() throws {
        typealias Recipe = MicroscopicAuroraSoundRecipe
        let opening: Core = try Core.opening(number: 1)
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(1)
        let wonCore: Core = try MicroscopicAuroraTest.coreAfter(1, plan + [.play], showHalf: false)
        let failedCore: Core = try MicroscopicAuroraTest.coreAfter(1, [.play], showHalf: false)
        try #require(wonCore.play.stage == .won, "\(wonCore.play.stage)")
        try #require(failedCore.play.stage == .failed, "\(failedCore.play.stage)")
        let calm: AmbientLoopRecipe = Recipe.recipe(play: opening.play)
        let won: AmbientLoopRecipe = Recipe.recipe(play: wonCore.play)
        let failed: AmbientLoopRecipe = Recipe.recipe(play: failedCore.play)
        try #require(calm != won, "a won play sounds different")
        try #require(calm != failed, "a failed play sounds different")
        try #require(won != failed)
        let sample: MicroscopicAuroraAudition = MicroscopicAuroraAudition.of(Access.levelOneWell, placeable: true)
        try #require(!sample.partials.isEmpty, "a well's audition has tones")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: MicroscopicAuroraA11yLoopFactory = MicroscopicAuroraA11yLoopFactory()
            let sound: MicroscopicAuroraSound = factory.sound(calm)
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
        let toggles: MicroscopicAuroraA11yLoopFactory = MicroscopicAuroraA11yLoopFactory()
        let live: MicroscopicAuroraSound = toggles.sound(calm)
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
        #expect(!live.audition(MicroscopicAuroraAudition(partials: [])), "silence plays nothing")
        #expect(live.auditionsPlayed == 1)

        // A failing play() changes nothing else.
        let failing: MicroscopicAuroraA11yLoopFactory = MicroscopicAuroraA11yLoopFactory()
        failing.succeeds = false
        let silent: MicroscopicAuroraSound = failing.sound(calm)
        silent.setOnScreen(true)
        silent.setWanted(true)
        #expect(!silent.started, "a failed play() is not started")
        #expect(silent.shouldPlay)

        // Rebuilds only when the recipe differs.
        let factory: MicroscopicAuroraA11yLoopFactory = MicroscopicAuroraA11yLoopFactory()
        let sound: MicroscopicAuroraSound = factory.sound(calm)
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
    /// inactive, changing the selection plays no audition and makes no player or voice, so no audio is touched; the
    /// recipe is offered at the first state and follows a placement; changing the selection is never announced.
    @Test func presenterAuditionSilentUnlessOnScreenActiveAndOn() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        Access.quiet(presenter)
        let opening: Core = try Core.opening(number: 1)
        _ = presenter.describe(opening)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")
        #expect(Presenter.recipe(opening) == MicroscopicAuroraSoundRecipe.recipe(play: opening.play))

        Access.stepStrength(presenter, 1)
        #expect(presenter.sound.auditionsPlayed == 0, "the sound off: a selection change plays no audition")
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        Access.stepStrength(presenter, -1)
        #expect(presenter.sound.auditionsPlayed == 0, "off screen: a selection change plays no audition")
        presenter.sceneActive(false)
        presenter.controlsAppeared()
        #expect(!presenter.sound.shouldPlay, "an inactive scene keeps the sound silent")
        Access.toggleSense(presenter)
        #expect(presenter.sound.auditionsPlayed == 0, "inactive: a selection change plays no audition")
        presenter.controlsDisappeared()
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "a selection change keeps the recipe")

        // A placement re-offers the recipe of its play (kept while the loop cannot play).
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(1)
        let change: MicroscopicAuroraAction = try #require(plan.first)
        var changed: Core = opening
        let result: ActionResult = changed.apply(MicroscopicAuroraTest.experienceAction(change))
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
        #expect(presenter.feedbackLog.count == 1, "only the placement is announced; selection changes are not")
    }

    /// With the sound on, on screen and active, every change of the selected well (site, strength, sense, as the
    /// adjustable values and the toggle make it) plays `MicroscopicAuroraAudition.of(selected, placeable:)` once; a
    /// change that leaves the well as it was (the strength clamped at 4) plays none; with a well placed in slot 0,
    /// choosing slot 1 on that well's site sounds the beating audition (the well cannot be placed there); describing
    /// plays none and nothing is announced; with the sound off again a further change plays nothing. (This test makes
    /// the presenter's real loop and one-shot players.)
    @Test func selectionChangePlaysOneAuditionWhenTheSoundIsOn() throws {
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
        try #require(mirror.sites.count >= 2, "level 1 has at least two sites")

        // A site change, a strength change and a sense change: one audition each.
        var expected: Int = 0
        Access.stepSite(presenter, 1)
        expected += 1
        #expect(presenter.sound.auditionsPlayed == expected, "a site change plays one audition")
        let afterSite: Well = try #require(mirror.selectedWell)
        #expect(presenter.sound.lastAudition == MicroscopicAuroraAudition.of(afterSite, placeable: true))
        for _ in 0..<4 {
            let before: Int = mirror.strength
            Access.stepStrength(presenter, 1)
            if mirror.strength != before { expected += 1 }
        }
        #expect(mirror.strength == 4)
        #expect(presenter.sound.auditionsPlayed == expected, "one audition per change of the strength")
        let atClamp: Int = presenter.sound.auditionsPlayed
        Access.stepStrength(presenter, 1)
        #expect(presenter.sound.auditionsPlayed == atClamp, "an unchanged well plays no audition")
        Access.toggleSense(presenter)
        #expect(presenter.sound.auditionsPlayed == atClamp + 1, "a sense change plays one audition")
        let toggled: Well = try #require(mirror.selectedWell)
        #expect(presenter.sound.lastAudition == MicroscopicAuroraAudition.of(toggled, placeable: true))

        // A well in slot 0: slot 1 on the same site cannot be placed and beats.
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(1)
        let change: MicroscopicAuroraAction = try #require(plan.first)
        var placed: Core = opening
        let result: ActionResult = placed.apply(MicroscopicAuroraTest.experienceAction(change))
        #expect(result == .accepted, "\(result.code)")
        _ = presenter.describe(placed)
        let describedCount: Int = presenter.sound.auditionsPlayed
        #expect(describedCount == atClamp + 1, "describing plays no audition")
        guard case let .place(slot, well) = change else {
            Issue.record("level 1's certified plan starts with a placement")
            return
        }
        try Access.steer(presenter, slot: slot, well: well)
        #expect(mirror.selectedPlaceable, "the slot's own well can be placed again on its site")
        let steered: Int = presenter.sound.auditionsPlayed
        Access.stepSlot(presenter, 1)
        #expect(!mirror.selectedPlaceable, "another slot cannot use the held site")
        #expect(presenter.sound.auditionsPlayed == steered + 1, "the placeability change plays one audition")
        let beating: MicroscopicAuroraAudition = MicroscopicAuroraAudition.of(well, placeable: false)
        #expect(presenter.sound.lastAudition == beating)
        #expect(beating.partials.count == 2)
        if beating.partials.count == 2 {
            let beat: Double = beating.partials[1].frequency - beating.partials[0].frequency
            #expect(Swift.abs(beat - MicroscopicAuroraAudition.beatHertz) < 1e-9,
                    "the second partial beats 3 Hz above the tone: \(beat)")
        }
        #expect(presenter.feedbackLog.count == 1, "only the placement is announced; selection changes are not")

        presenter.setSound(on: false)
        presenter.controlsDisappeared()
        let silentCount: Int = presenter.sound.auditionsPlayed
        Access.stepSite(presenter, 1)
        #expect(presenter.sound.auditionsPlayed == silentCount, "no audition once the sound is off")
        #expect(!presenter.sound.shouldPlay)
    }
}

private extension String {
    /// The string with its first character upper-cased (as the summary capitalises its sentences).
    var capitalizedForTest: String { prefix(1).uppercased() + dropFirst() }
}
#endif
