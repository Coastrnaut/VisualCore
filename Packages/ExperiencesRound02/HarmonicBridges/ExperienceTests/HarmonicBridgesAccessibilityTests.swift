// HarmonicBridgesAccessibilityTests — feature 416 (R02-G12-06) T-R02G1206-005 (FR-R02G1206-001 … 006)
// (SC-R02G1206-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on Echo
// Cartographer's feature-406 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the
// haptic planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running.
// Values: every value the panel reads (`HarmonicBridgesControls.values(_:)`, read field by field by reflection, the
// chosen string and peg in words, the summary, the status and the labels) is non-empty words after level 1 is
// described; the summary element equals `HarmonicBridgesFeedbackPlan.summaryText(core:string:peg:)` and follows the
// adjustable string and peg after `refreshSummary()`. The adjustable string and peg (`stepString(±1)`, `stepPeg(±1)`)
// increment and decrement within their bounds and are never announced.
// Level 1 (seed 0) is won with the panel's accessibility operations alone: the adjustable string and peg choose each
// certified tuning, Tune sends the chosen string and peg and Test tests the crossing, both through `presenter.send`;
// every accepted step routes exactly `HarmonicBridgesFeedbackPlan.after(old:new:)` of the cores captured before and
// after it (kinds, texts and haptics), and the last one is the win outcome with a success haptic. Refusals (a locked
// level, a tuning to the current peg) show `refusalText(code:)` and route a rejection with an error haptic. Reduce
// Motion: two stills of the same tuned state at different frame times (across the 1.2 s step cycle) are
// byte-identical. Reduce Flashing: the scene holds the strings at rest and the resting step, the level-0 bridge mesh it
// builds then has no wave shell, two stills at different times are identical once the fades settle, and after a win the
// won light rises below 1 for 0.4 s of frame time and reaches 1 by 0.5 s (the 0.45 s fade). Sound: the state table
// (wanted × on screen × active) and the rebuilds use a `HarmonicBridgesSound` with an injected recording player; the
// presenter's own sound is only driven off screen (no player made, no audio touched). Synthetic data, explicit types,
// plain loops, no nested closure literals, no wall-clock assertion.
#if os(iOS)
import CoreGraphics
import Foundation
import HarmonicBridgesCore
import Testing
@testable import HarmonicBridgesExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class HarmonicBridgesA11yClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class HarmonicBridgesA11yLoop: HarmonicBridgesLoopPlaying {
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
final class HarmonicBridgesA11yLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [HarmonicBridgesA11yLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> HarmonicBridgesA11yLoop {
        let loop: HarmonicBridgesA11yLoop = HarmonicBridgesA11yLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> HarmonicBridgesSound {
        HarmonicBridgesSound(recipe: recipe, makePlayer: { next in self.make(next) })
    }
}

/// Helpers of the accessibility tests.
@MainActor
enum HarmonicBridgesA11y {
    typealias Shell = ExperienceShell<HarmonicBridgesPresenter>
    typealias Plan = HarmonicBridgesFeedbackPlan
    typealias Core = HarmonicBridgesExperienceCore

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: HarmonicBridgesA11yClock
    }

    /// The still size of the Reduce Motion and Reduce Flashing tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn) and describes the opening so the
    /// presenter holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        let shell: Shell = try await HarmonicBridgesTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                                              reduceFlashing: reduceFlashing,
                                                              size: CGSize(width: 360, height: 240))
        let opening: Core = try HarmonicBridgesTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: HarmonicBridgesA11yClock = HarmonicBridgesA11yClock()
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
        try HarmonicBridgesTest.core(shell)
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

    /// The first string of `play` that is not locked.
    static func freeString(_ play: HarmonicBridgesPlay) -> Int? {
        for index in 0..<play.level.strings.count where !play.level.strings[index].locked { return index }
        return nil
    }

    /// Chooses `string` and `peg` in the panel with the adjustable string and peg operations only (`stepString(±1)`
    /// first, which takes that string's current peg, then `stepPeg(±1)`), each followed by `refreshSummary()` as the
    /// panel's increment and decrement do. Returns the presses made.
    static func choose(_ presenter: HarmonicBridgesPresenter, string: Int, peg: Int) -> Int {
        let mirror: HarmonicBridgesMirror = presenter.mirror
        var presses: Int = 0
        for _ in 0..<64 {
            if mirror.string < string {
                mirror.stepString(1)
            } else if mirror.string > string {
                mirror.stepString(-1)
            } else if mirror.peg < peg {
                mirror.stepPeg(1)
            } else if mirror.peg > peg {
                mirror.stepPeg(-1)
            } else {
                break
            }
            presenter.refreshSummary()
            presses += 1
        }
        return presses
    }

    /// Sends the refused `control` with `values` through the presenter, one clock second later; expects a refusal,
    /// an unchanged digest, the refusal plan routed (kind `rejection`, haptic `error`), its words in the panel and the
    /// code in `refusalLog`. Returns the plan.
    @discardableResult
    static func refused(_ shell: Shell, _ recorder: Recorder, _ control: String, _ values: [Double],
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Plan {
        let presenter: HarmonicBridgesPresenter = shell.presenter
        let digest: String = try HarmonicBridgesTest.digest(shell)
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
        #expect(presenter.mirror.message == Plan.refusalText(code: result.code), "the panel shows the same words",
                sourceLocation: sourceLocation)
        #expect(presenter.refusalLog.last == result.code, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.count == playedBefore + 1, sourceLocation: sourceLocation)
        #expect(recorder.haptics.played.last == .error, "a refusal plays an error haptic",
                sourceLocation: sourceLocation)
        #expect(recorder.announcements.announced.last == plan.text, sourceLocation: sourceLocation)
        let after: String = try HarmonicBridgesTest.digest(shell)
        #expect(after == digest, "a refusal changes nothing", sourceLocation: sourceLocation)
        let count: Int = presenter.feedbackLog.count
        _ = presenter.describe(try core(shell))
        #expect(presenter.feedbackLog.count == count, "describing after a refusal routes nothing",
                sourceLocation: sourceLocation)
        return plan
    }
}

@MainActor
@Suite(.serialized) struct HarmonicBridgesAccessibilityTests {
    typealias Access = HarmonicBridgesA11y
    typealias Plan = HarmonicBridgesFeedbackPlan
    typealias Presenter = HarmonicBridgesPresenter
    typealias Core = HarmonicBridgesExperienceCore

    // MARK: Values and the summary element (FR-R02G1206-001, 005; clarification Q5)

    /// After level 1 is described every value the panel reads is non-empty words; the summary element equals
    /// `summaryText(core:string:peg:)`; describing routes nothing.
    @Test func everyControlHasALabelAndAValueInWords() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        let mirror: HarmonicBridgesMirror = presenter.mirror
        let values: [String] = Access.strings(of: HarmonicBridgesControls.values(mirror))
        #expect(values.count >= 4, "the button values: \(values)")
        let all: [String] = values + [mirror.stringLabel, mirror.pegLabel, mirror.choiceLabel, mirror.summary,
                                      mirror.status, mirror.measureLabel, mirror.targetLabel, mirror.goalLabel]
        var index: Int = 0
        for value in all {
            #expect(!value.isEmpty, "value \(index) is empty")
            index += 1
        }

        // The two-state values read in words and differ.
        let authored: String = HarmonicBridgesControls.viewValue(true)
        let orbited: String = HarmonicBridgesControls.viewValue(false)
        #expect(!authored.isEmpty && !orbited.isEmpty && authored != orbited, "\(authored) / \(orbited)")
        let selected: String = HarmonicBridgesControls.selectedValue(true)
        let unselected: String = HarmonicBridgesControls.selectedValue(false)
        #expect(!selected.isEmpty && !unselected.isEmpty && selected != unselected, "\(selected) / \(unselected)")
        #expect(HarmonicBridgesControls.modeName(.campaign) == "campaign")
        #expect(HarmonicBridgesControls.modeName(.practice) == "practice")
        #expect(HarmonicBridgesControls.modeName(.daily(level: 59)) == "daily")
        #expect(HarmonicBridgesControls.readableWidth == 520)

        // The chosen string reads as the level words it, with its current peg.
        let play: HarmonicBridgesPlay = core.play
        #expect(mirror.string == 0, "a level opens with string 0 chosen")
        #expect(mirror.peg == play.pegs[0], "at its current peg")
        let name: String = play.level.stringName(0, peg: play.pegs[0])
        #expect(mirror.choiceLabel.contains(name), "\(mirror.choiceLabel)")

        // The summary element (clarification Q5).
        #expect(mirror.summary == Plan.summaryText(core: core, string: mirror.string, peg: mirror.peg),
                "\(mirror.summary)")
        #expect(mirror.summary.contains("Chosen: " + name + ", tune to peg \(mirror.peg)."), "\(mirror.summary)")
        #expect(mirror.summary.contains("Level: " + Plan.levelWords(core) + "."), "\(mirror.summary)")
        #expect(mirror.soundOn == false, "the Sound toggle is off by default")
        #expect(presenter.feedbackLog.isEmpty, "describing the opening plans nothing")
    }

    /// The adjustable string and peg increment and decrement within their bounds (the string clamped to the level's
    /// strings and taking its current peg, the peg to 1 … 12); the summary follows after `refreshSummary()`; nothing is
    /// announced.
    @Test func adjustableStringAndPegIncrementAndDecrement() throws {
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        // The first certified level with at least two strings (level 1 has one).
        var opened: Core? = nil
        for number in 1...100 {
            let candidate: Core = try Core.opening(number: number)
            if candidate.play.level.strings.count >= 2 {
                opened = candidate
                break
            }
        }
        let core: Core = try #require(opened, "a certified level has at least two strings")
        _ = presenter.describe(core)
        let mirror: HarmonicBridgesMirror = presenter.mirror
        let play: HarmonicBridgesPlay = core.play
        let count: Int = play.level.strings.count

        // String: decrement at 0 stays; increment moves to 1 at its current peg; the summary follows.
        mirror.stepString(-1)
        #expect(mirror.string == 0, "the string does not go below 0")
        mirror.stepString(1)
        presenter.refreshSummary()
        #expect(mirror.string == 1)
        #expect(mirror.peg == play.pegs[1], "a chosen string takes its current peg")
        #expect(mirror.summary == Plan.summaryText(core: core, string: 1, peg: play.pegs[1]), "\(mirror.summary)")
        #expect(mirror.summary.contains("Chosen: " + play.level.stringName(1, peg: play.pegs[1])), "\(mirror.summary)")
        for _ in 0..<(count + 3) { mirror.stepString(1) }
        #expect(mirror.string == count - 1, "the string does not go past the last")
        mirror.stepString(-1)
        #expect(mirror.string == count - 2)
        for _ in 0..<(count + 3) { mirror.stepString(-1) }
        #expect(mirror.string == 0)

        // Peg: increment and decrement by one, clamped to the peg range.
        let start: Int = mirror.peg
        if start < HarmonicBridgesMirror.pegRange.upperBound {
            mirror.stepPeg(1)
            #expect(mirror.peg == start + 1)
            mirror.stepPeg(-1)
            #expect(mirror.peg == start)
        } else {
            mirror.stepPeg(-1)
            #expect(mirror.peg == start - 1)
            mirror.stepPeg(1)
            #expect(mirror.peg == start)
        }
        for _ in 0..<20 { mirror.stepPeg(1) }
        #expect(mirror.peg == HarmonicBridgesMirror.pegRange.upperBound, "the peg stops at 12")
        presenter.refreshSummary()
        #expect(mirror.summary == Plan.summaryText(core: core, string: 0, peg: 12), "\(mirror.summary)")
        #expect(mirror.pegLabel == "peg 12")
        for _ in 0..<20 { mirror.stepPeg(-1) }
        #expect(mirror.peg == HarmonicBridgesMirror.pegRange.lowerBound, "the peg stops at 1")
        presenter.refreshSummary()
        #expect(mirror.summary == Plan.summaryText(core: core, string: 0, peg: 1), "\(mirror.summary)")
        #expect(presenter.feedbackLog.isEmpty, "adjusting the string and peg plans nothing")
    }

    // MARK: The panel alone (SC-R02G1206-001, 002)

    /// Level 1 (seed 0) is won with the panel's accessibility operations alone: the adjustable string and peg choose
    /// each certified tuning (never announced, no haptic), Tune sends the chosen string and peg, Test tests the
    /// crossing; every accepted step routes exactly `after(old:new:)`; the sinks hold the plans' words and haptics in
    /// order; the last is the win outcome with a success haptic.
    @Test func levelOneWonWithThePanelOperations() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let mirror: HarmonicBridgesMirror = presenter.mirror
        let logBase: Int = presenter.feedbackLog.count
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        let actions: [HarmonicBridgesAction] = try HarmonicBridgesTest.certifiedActions(1)
        try #require(!actions.isEmpty, "level 1 has a certified solution")
        try #require(actions.last == .test, "the certified solution ends with a test")
        var expected: [Plan] = []
        var presses: Int = 0
        var sent: Int = 0

        for action in actions {
            let stage: HarmonicBridgesStage = try Access.core(shell).play.stage
            guard stage == .playing else { break }
            let logBefore: Int = presenter.feedbackLog.count
            let announcedBefore: Int = recorder.announcements.announced.count
            let playedBefore: Int = recorder.haptics.played.count
            let control: String
            let values: [Double]
            switch action {
            case let .tune(string, peg):
                presses += Access.choose(presenter, string: string, peg: peg)
                #expect(mirror.string == string && mirror.peg == peg, "the panel chose string \(string), peg \(peg)")
                control = "string.tune"
                values = [Double(mirror.string), Double(mirror.peg)]
            case .test:
                control = "crossing.test"
                values = []
            }
            #expect(presenter.feedbackLog.count == logBefore, "choosing plans nothing")
            #expect(recorder.announcements.announced.count == announcedBefore, "choosing is not announced")
            #expect(recorder.haptics.played.count == playedBefore, "choosing plays no haptic")
            let old: Core = try Access.core(shell)
            #expect(mirror.summary == Plan.summaryText(core: old, string: mirror.string, peg: mirror.peg),
                    "\(mirror.summary)")

            // The panel's button (Tune or Test).
            recorder.clock.advance()
            let result: ActionResult = presenter.send(control, values, port: shell.port)
            #expect(result == .accepted, "action \(sent + 1) \(control) \(values): \(result.code)")
            sent += 1
            let new: Core = try Access.core(shell)
            _ = presenter.describe(new)
            let plan: Plan = Plan.after(old: old, new: new)
            #expect(plan.text != nil, "action \(sent) is announced")
            #expect(presenter.feedbackLog.count == logBefore + 1, "action \(sent) routes one plan")
            #expect(presenter.feedbackLog.last == plan)
            #expect(recorder.announcements.announced.last == plan.text)
            expected.append(plan)
            let routed: Int = presenter.feedbackLog.count
            _ = presenter.describe(new)
            #expect(presenter.feedbackLog.count == routed, "describing the same state again routes nothing")
            #expect(mirror.summary == Plan.summaryText(core: new, string: mirror.string, peg: mirror.peg),
                    "\(mirror.summary)")
            if new.play.stage != .won {
                #expect(plan.kind == .state)
                #expect(plan.haptic == .selection)
                if case let .tune(string, peg) = action {
                    let words: String = "String \(string) tuned to peg \(peg). The start reaches the goal in "
                    #expect(plan.text?.hasPrefix(words) == true, "\(plan.text ?? "nil")")
                }
            }
        }
        #expect(sent == actions.count, "every certified action was sent")
        #expect(presses > 0, "the adjustable string and peg were used")

        let won: Core = try Access.core(shell)
        #expect(won.play.stage == .won)
        let spent: Int = HarmonicBridgesProgress.actionsSpent(won.play)
        let stars: Int = HarmonicBridgesProgress.stars(actionsSpent: spent, certified: won.certifiedActions)
        #expect(stars == 3, "the certified solution earns 3 stars")
        let spentWords: String = spent == 1 ? "1 action" : "\(spent) actions"
        let winText: String = Plan.wonText + " Level won spending " + spentWords + ", " + String(stars)
            + " of 3 stars."
        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == expected)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        var kinds: [AnnouncementKind] = []
        for plan in plans { if let kind = plan.kind { kinds.append(kind) } }
        var expectedKinds: [AnnouncementKind] = []
        for _ in 0..<(plans.count - 1) { expectedKinds.append(.state) }
        expectedKinds.append(.outcome)
        #expect(kinds == expectedKinds, "\(kinds)")
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected), "\(recorder.haptics.played)")
        #expect(recorder.haptics.played.last == .success)
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.message == nil)
    }

    // MARK: Refusals (FR-R02G1206-002, 003; clarification Q1)

    /// A locked level and a tuning to the string's current peg are refused: the panel shows `refusalText(code:)`, a
    /// rejection with an error haptic is routed with the words of clarification Q1, and nothing changes.
    @Test func refusalsAreShownAndAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count

        let locked: Plan = try Access.refused(shell, recorder, "level.select", [3])
        #expect(locked.text == "That level is not open yet.", "\(locked.text ?? "nil")")
        #expect(presenter.refusalLog.last?.contains(HarmonicBridgesExperienceRule.locked) == true)

        let opening: Core = try Access.core(shell)
        let free: Int = try #require(Access.freeString(opening.play), "level 1 has a string that is not locked")
        let current: Int = opening.play.pegs[free]
        let noop: Plan = try Access.refused(shell, recorder, "string.tune", [Double(free), Double(current)])
        #expect(noop.text == "That string is already at that peg.", "\(noop.text ?? "nil")")

        let plans: [Plan] = Array(presenter.feedbackLog.dropFirst(logBase))
        #expect(plans == [locked, noop])
        #expect(recorder.haptics.played == [HapticKind.error, HapticKind.error])
        #expect(recorder.announcements.announced == Access.texts(plans))
    }

    // MARK: Reduce Motion and Reduce Flashing stills (FR-R02G1206-004; SC-R02G1206-003)

    /// Under Reduce Motion two stills of the same tuned state at different frame times (across the 1.2 s step cycle)
    /// are byte-identical.
    @Test func reduceMotionStillsAreIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0, reduceMotion: true)
        Access.quiet(shell)
        #expect(shell.presenter.scene.reduceMotion)
        #expect(try HarmonicBridgesTest.tune(shell))
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        // Two first stills let any light fade finish (0.5 s apart, beyond the 0.15 s fade).
        _ = try HarmonicBridgesTest.still(session, width: w, height: h, time: 0)
        _ = try HarmonicBridgesTest.still(session, width: w, height: h, time: 0.5)
        let first: [UInt8] = try HarmonicBridgesTest.still(session, width: w, height: h, time: 0.75)
        let second: [UInt8] = try HarmonicBridgesTest.still(session, width: w, height: h, time: 1.9)
        #expect(HarmonicBridgesTest.nonGroundPixels(first) > 0, "the still shows the bridges")
        #expect(first == second, "Reduce Motion: stills at 0.75 s and 1.9 s are identical")
        #expect(shell.presenter.lights.isSettled, "the lights rest")
    }

    /// Under Reduce Flashing the scene holds the strings at rest and the resting step, the level-0 bridge mesh it
    /// builds has no wave shell (the same snapshot with motion has some), and two stills at different times, across
    /// the step cycle, are byte-identical once the fades settle.
    @Test func reduceFlashingDrawsNoWaveShellAndStillsAreIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0, reduceFlashing: true)
        Access.quiet(shell)
        let scene: HarmonicBridgesBridgeScene = shell.presenter.scene
        #expect(scene.reducedFlash)
        #expect(!scene.reduceMotion)
        #expect(scene.stringsAtRest, "Reduce Flashing draws the strings at rest")
        #expect(session.qualityPin == 0, "level-0, the tier with wave shells")
        #expect(try HarmonicBridgesTest.tune(shell))
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        let base: Double = 10
        _ = try HarmonicBridgesTest.still(session, width: w, height: h, time: base)
        _ = try HarmonicBridgesTest.still(session, width: w, height: h, time: base + 0.5)
        let early: [UInt8] = try HarmonicBridgesTest.still(session, width: w, height: h, time: base + 0.75)
        let late: [UInt8] = try HarmonicBridgesTest.still(session, width: w, height: h, time: base + 1.9)
        #expect(HarmonicBridgesTest.nonGroundPixels(early) > 0, "the still shows the bridges")
        #expect(early == late, "Reduce Flashing: stills at 0.75 s and 1.9 s are identical")
        #expect(shell.presenter.lights.isSettled, "the lights rest")

        // The scene's facts on the drawn snapshot: the resting step, and no wave shell at level-0.
        let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(scene.drawnStep(snapshot, animate: true) == snapshot.restingStep, "the shown step is held")
        let tier: HarmonicBridgesTier = HarmonicBridgesTier.all[0]
        let still: Mesh = try HarmonicBridgesSceneGeometry.bridgeMesh(snapshot, tier: tier,
                                                                      reduceMotion: scene.stringsAtRest)
        #expect(HarmonicBridgesTest.positionsWithoutWaveShells(still).count == still.positions.count,
                "Reduce Flashing: no wave shell vertex")
        let moving: Mesh = try HarmonicBridgesSceneGeometry.bridgeMesh(snapshot, tier: tier, reduceMotion: false)
        #expect(HarmonicBridgesTest.positionsWithoutWaveShells(moving).count < moving.positions.count,
                "the same tuned snapshot with motion has wave shells (the check is not vacuous)")
    }

    // MARK: Lights under Reduce Flashing (FR-R02G1206-004; SC-R02G1206-003)

    /// Under Reduce Flashing the won light rises over 0.45 s of frame time after the winning test: below 1 (and rising)
    /// at 0.1 … 0.4 s, 1 at 0.5 s, with the glow at its won level; the scene draws the presenter's lights.
    @Test func reduceFlashingWonLightFades() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0, reduceFlashing: true)
        Access.quiet(shell)
        let presenter: Presenter = shell.presenter
        #expect(try HarmonicBridgesTest.tune(shell))
        try #require(try Access.core(shell).play.stage == .playing, "only the test wins")
        let w: Int = Access.stillWidth
        let h: Int = Access.stillHeight
        let base: Double = 10
        _ = try HarmonicBridgesTest.still(session, width: w, height: h, time: base - 1)
        _ = try HarmonicBridgesTest.still(session, width: w, height: h, time: base)
        #expect(presenter.lights.won == 0, "the won light rests at 0 while playing")
        #expect(presenter.lights.glow == HarmonicBridgesLights.glowPlaying)

        let winning: ActionResult = shell.handle(control: "crossing.test", values: [])
        #expect(winning == .accepted, "\(winning.code)")
        #expect(try Access.core(shell).play.stage == .won)

        let rising: [Double] = [0.1, 0.2, 0.3, 0.4]
        var previous: Double = 0
        for offset in rising {
            _ = try HarmonicBridgesTest.still(session, width: w, height: h, time: base + offset)
            let level: Double = presenter.lights.won
            #expect(level > previous, "the won light rises at \(offset) s: \(level)")
            #expect(level < 1, "the won light is below 1 at \(offset) s: \(level)")
            #expect(presenter.scene.lights?.won == level, "the scene draws the presenter's lights")
            previous = level
        }
        _ = try HarmonicBridgesTest.still(session, width: w, height: h, time: base + 0.5)
        #expect(presenter.lights.won == 1, "the won light reaches 1 after 0.45 s")
        #expect(presenter.lights.glow == HarmonicBridgesLights.glowWon)
        #expect(presenter.lights.isSettled)
    }

    // MARK: Sound (FR-R02G1206-006; SC-R02G1206-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; each input turning off stops a playing loop; a new player is made only for a different recipe or the
    /// toggle turning on, never for the same recipe offered again. The presenter's toggle, driven off screen, makes no
    /// player.
    @Test func soundStateTable() throws {
        let calm: AmbientLoopRecipe = HarmonicBridgesSoundRecipe.recipe(rootStep: 0, reached: 0, stage: .playing)
        let one: AmbientLoopRecipe = HarmonicBridgesSoundRecipe.recipe(rootStep: 0, reached: 1, stage: .playing)
        let won: AmbientLoopRecipe = HarmonicBridgesSoundRecipe.recipe(rootStep: 0, reached: 1, stage: .won)
        try #require(calm != one, "another reached count sounds different")
        try #require(one != won, "a won play sounds different")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: HarmonicBridgesA11yLoopFactory = HarmonicBridgesA11yLoopFactory()
            let sound: HarmonicBridgesSound = factory.sound(calm)
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

        // Each input turning off stops a playing loop; turning back on plays again with the same player.
        let toggles: HarmonicBridgesA11yLoopFactory = HarmonicBridgesA11yLoopFactory()
        let live: HarmonicBridgesSound = toggles.sound(calm)
        #expect(!live.wanted, "the sound is off by default")
        live.setOnScreen(true)
        live.setWanted(true)
        #expect(live.started)
        live.setActive(false)
        #expect(!live.started, "an inactive scene stops the loop")
        #expect(toggles.made.first?.isPlaying == false)
        live.setActive(true)
        live.setOnScreen(false)
        #expect(!live.started, "controls off screen stop the loop")
        live.setOnScreen(true)
        live.setWanted(false)
        #expect(!live.started, "the sound off stops the loop")
        live.setWanted(true)
        #expect(live.started)
        #expect(live.playersMade == 1, "the same recipe keeps its player")

        // A failing play() changes nothing else.
        let failing: HarmonicBridgesA11yLoopFactory = HarmonicBridgesA11yLoopFactory()
        failing.succeeds = false
        let silent: HarmonicBridgesSound = failing.sound(calm)
        silent.setOnScreen(true)
        silent.setWanted(true)
        #expect(!silent.started, "a failed play() is not started")
        #expect(silent.shouldPlay)

        // Rebuilds only when the recipe differs.
        let factory: HarmonicBridgesA11yLoopFactory = HarmonicBridgesA11yLoopFactory()
        let sound: HarmonicBridgesSound = factory.sound(calm)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(calm) }
        #expect(sound.playersMade == 1, "the same recipe offered again keeps the player")
        sound.offer(one)
        #expect(sound.playersMade == 2, "a change of the steps reached makes a new player")
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
        #expect(factory.recipes == [calm, one, won, calm])

        // The presenter's toggle with the controls off screen: no player is made, so no audio is touched.
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let core: Core = try Core.opening(number: 1)
        _ = presenter.describe(core)
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.recipe == Presenter.recipe(core), "the first state offers its recipe")
        #expect(Presenter.recipe(core) == HarmonicBridgesSoundRecipe.recipe(play: core.play))
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
    }
}
#endif
