// ColorfallCanyonsAccessibilityTests — feature 346 (R02-G05-06) T-R02G0506-006 (FR-R02G0506-001 … 006;
// SC-R02G0506-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host, modelled on Hue
// Compass's feature-336 tests. Recorded feedback: the presenter's route is an `ExperienceFeedback` with a
// `RecordingHapticSink`, a `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the haptic
// planner's 0.05 s and the announcement planner's 0.5 s) and VoiceOver reported running; a refusal (undo with nothing to
// undo, a locked level), a carve, a valve, a step, undo and redo record exactly `ColorfallCanyonsFeedbackPlan.after(old:
// new:)` and `refused(code:)` in the sinks and in the presenter's feedback log (the texts are also written out from
// clarification Q1), and the panel shows the refusal's words. Level 1 is won with the panel's operations alone: the cell
// picker (`pickCell`), Carve (`canyon.carve` of the picked cell), the valve buttons (`canyon.valve`) and Run
// (`time.step` of the ticks left, at most 600), following `ColorfallCanyonsExperienceCore.certifiedActions(1)`; every
// step is announced and the win is an outcome with a success haptic. A drag in progress (the highlight) announces
// nothing; its released carve is announced once. Sound: the presenter makes its own `ColorfallCanyonsSound` with the
// real `AmbientLoopPlayer`, so the state table, the offers and a failing `play()` use a `ColorfallCanyonsSound` with an
// injected recording player; the presenter's sound is only driven with the sound off or off screen (no audio starts):
// its recipe follows the described core, drawn frames leave it alone and no player is made. Reduce Flashing: the drawn
// lights (every fluid sheet, every emitter, the win glow) are sampled through off-screen stills at frame times 1/60 s
// apart over a flow, an undo/redo flicker and a hold; no element crosses half its range more than 3 times per second
// and 0.1 s after the flow every changed level lies strictly between its start and its target. Reduce Motion: two stills
// of the same state at different frame times are byte-identical and the drawn snapshot keeps time 0. The summary
// element's words are `ColorfallCanyonsFeedbackPlan.summaryText(core:)`, also written out. Synthetic data, explicit
// types, plain loops, no nested closure literals, no sleep, no wall-clock assertion; few frames, each test short.
#if os(iOS)
import ColorfallCanyonsCore
import CoreGraphics
import Foundation
import Testing
@testable import ColorfallCanyonsExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class ColorfallCanyonsAccessClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class ColorfallCanyonsFakeLoop: ColorfallCanyonsLoopPlaying {
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
final class ColorfallCanyonsFakeLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [ColorfallCanyonsFakeLoop] = []
    /// The recipe of every loop made, oldest first.
    private(set) var recipes: [AmbientLoopRecipe] = []

    /// Makes and keeps one fake loop for `recipe`.
    func make(_ recipe: AmbientLoopRecipe) -> ColorfallCanyonsFakeLoop {
        let loop: ColorfallCanyonsFakeLoop = ColorfallCanyonsFakeLoop(succeeds: succeeds)
        made.append(loop)
        recipes.append(recipe)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> ColorfallCanyonsSound {
        ColorfallCanyonsSound(recipe: recipe, makePlayer: { next in self.make(next) })
    }
}

/// One drawn frame's light levels: every sheet by cell, every emitter and the win glow.
struct ColorfallCanyonsLightSample {
    /// The sheet levels by cell (a cell missing here is at 0).
    let sheets: [Int: Double]
    /// The emitter levels in spring order.
    let emitters: [Double]
    /// The win glow.
    let glow: Double
}

/// Helpers of the accessibility tests.
@MainActor
enum ColorfallCanyonsAccess {
    typealias Shell = ExperienceShell<ColorfallCanyonsPresenter>
    typealias Plan = ColorfallCanyonsFeedbackPlan

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: ColorfallCanyonsAccessClock
    }

    /// The still size of the Reduce Flashing and Reduce Motion tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64
    /// The frame rate of the sampled stills.
    static let frameRate: Double = 60
    /// The most ticks one `time.step` runs.
    static let maxStep: Int = 600

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        try await ColorfallCanyonsTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                            reduceFlashing: reduceFlashing, size: CGSize(width: 360, height: 240))
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: ColorfallCanyonsAccessClock = ColorfallCanyonsAccessClock()
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
    static func core(_ shell: Shell) throws -> ColorfallCanyonsExperienceCore {
        try ColorfallCanyonsTest.core(shell)
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
    static func log(_ presenter: ColorfallCanyonsPresenter, after count: Int) -> [Plan] {
        Array(presenter.feedbackLog.dropFirst(count))
    }

    /// "1 action left" or "n actions left", written out here.
    static func leftText(_ count: Int) -> String { count == 1 ? "1 action left" : "\(count) actions left" }

    /// "row r, column c" of `cell` (1-based), written out here.
    static func cellText(_ cell: Int, columns: Int) -> String {
        "row \(cell / max(columns, 1) + 1), column \(cell % max(columns, 1) + 1)"
    }

    /// The number of basins of `core` that accept their masses.
    static func filled(_ core: ColorfallCanyonsExperienceCore) -> Int {
        let play: ColorfallCanyonsPlay = core.play
        var count: Int = 0
        for basin in play.level.basins where basin.accepts(play.fluid.masses[basin.cell]) { count += 1 }
        return count
    }

    /// The ticks the panel's Run button sends for `mirror`: the ticks left, at least 1 and at most 600.
    static func runTicks(_ mirror: ColorfallCanyonsMirror) -> Int {
        max(1, min(maxStep, mirror.tickLimit - mirror.tick))
    }

    /// The summary element's words of `core`, written out from clarification Q5.
    static func summaryText(_ core: ColorfallCanyonsExperienceCore) -> String {
        let play: ColorfallCanyonsPlay = core.play
        var text: String = "Tick \(play.fluid.tick) of \(play.level.tickLimit). \(leftText(play.remaining))."
        for index in play.level.basins.indices {
            let basin: ColorfallCanyonsBasin = play.level.basins[index]
            let masses: [Int] = play.fluid.masses[basin.cell]
            text += " Basin \(index + 1): cyan \(masses[0]), coral \(masses[1]), yellow \(masses[2]); "
                + "target \(basin.description)."
        }
        return text
    }

    /// Draws an off-screen still of `session` at frame time `time` and returns the presenter's drawn light levels.
    static func sample(_ session: ExperienceSession, _ presenter: ColorfallCanyonsPresenter,
                       time: Double) throws -> ColorfallCanyonsLightSample {
        _ = try ColorfallCanyonsTest.still(session, width: stillWidth, height: stillHeight, time: time)
        let lights: ColorfallCanyonsLights = presenter.lights
        var sheets: [Int: Double] = [:]
        for (cell, sheet) in lights.sheets { sheets[cell] = sheet.level }
        return ColorfallCanyonsLightSample(sheets: sheets, emitters: lights.emitters, glow: lights.glow)
    }

    /// The samples as one vector per frame over every sheet cell seen (sorted; 0 where absent), then the emitters (the
    /// fewest any sample has) and the glow.
    static func vectors(_ samples: [ColorfallCanyonsLightSample]) -> [[Double]] {
        var seen: Set<Int> = []
        var emitterCount: Int = Int.max
        for sample in samples {
            for key in sample.sheets.keys { seen.insert(key) }
            emitterCount = min(emitterCount, sample.emitters.count)
        }
        if samples.isEmpty { emitterCount = 0 }
        let keys: [Int] = seen.sorted()
        var result: [[Double]] = []
        for sample in samples {
            var row: [Double] = []
            for key in keys { row.append(sample.sheets[key] ?? 0) }
            for index in 0..<emitterCount { row.append(sample.emitters[index]) }
            row.append(sample.glow)
            result.append(row)
        }
        return result
    }

    /// Whether any value of `vectors` lies strictly between 0 and 1 and differs from the first and last row's value (a
    /// light caught mid-fade).
    static func anyMidFade(_ vectors: [[Double]]) -> Bool {
        guard let first = vectors.first, let last = vectors.last else { return false }
        for row in vectors {
            for index in 0..<min(row.count, first.count, last.count) {
                let value: Double = row[index]
                if value > 0 && value < 1 && value != first[index] && value != last[index] { return true }
            }
        }
        return false
    }
}

@MainActor
@Suite(.serialized) struct ColorfallCanyonsAccessibilityTests {
    typealias Access = ColorfallCanyonsAccess
    typealias Script = ColorfallCanyonsGestureScript
    typealias Plan = ColorfallCanyonsFeedbackPlan
    typealias Presenter = ColorfallCanyonsPresenter

    // MARK: Recorded feedback (FR-R02G0506-002, 003; SC-R02G0506-002)

    /// A refusal, a carve, a valve, a step, undo, redo and a second refusal: the sinks receive exactly the plans of
    /// `ColorfallCanyonsFeedbackPlan`, in order, and the feedback log holds the same plans; texts written out; the panel
    /// shows each refusal's words.
    @Test func recordedFeedbackThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let announcedBase: Int = presenter.announcements.count
        var expected: [Plan] = []
        let opening: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        let level: ColorfallCanyonsLevel = opening.play.level
        try #require(level.budget >= 2, "a carve and a valve fit level 1")
        try #require(!level.springs.isEmpty, "level 1 has a spring")
        let columns: Int = level.columns

        // A refusal: undo with nothing to undo.
        var digest: String = try ColorfallCanyonsTest.digest(shell)
        recorder.clock.advance()
        let noUndo: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(!noUndo.isAccepted)
        #expect(noUndo.code.contains("r02-g05.action"), "\(noUndo.code)")
        let noUndoPlan: Plan = Plan.refused(code: noUndo.code)
        #expect(noUndoPlan.text == "That action is not allowed here.", "\(noUndoPlan.text ?? "nil")")
        #expect(noUndoPlan.kind == .rejection)
        #expect(noUndoPlan.haptic == .error)
        #expect(presenter.mirror.message == "That action is not allowed here.", "the panel shows the same words")
        #expect(try ColorfallCanyonsTest.digest(shell) == digest, "a refusal changes nothing")
        expected.append(noUndoPlan)

        // A carve of the picked cell.
        let cell: Int = try #require(presenter.mirror.pickedCell, "level 1 has a carvable cell")
        recorder.clock.advance()
        let carved: ActionResult = presenter.send("canyon.carve", [Double(cell)], port: shell.port)
        #expect(carved == .accepted, "\(carved.code)")
        #expect(presenter.mirror.message == nil, "an accepted action clears the refusal")
        let afterCarve: ColorfallCanyonsExperienceCore = try Access.core(shell)
        let carvePlan: Plan = Plan.after(old: opening, new: afterCarve)
        let carveText: String = "Carved \(Access.cellText(cell, columns: columns)). "
            + "\(Access.leftText(afterCarve.play.remaining))."
        #expect(carvePlan.text == carveText, "\(carvePlan.text ?? "nil")")
        #expect(carvePlan.kind == .state)
        #expect(carvePlan.haptic == .selection)
        expected.append(carvePlan)

        // A valve toggle of spring 1.
        recorder.clock.advance()
        let toggled: ActionResult = presenter.send("canyon.valve", [0], port: shell.port)
        #expect(toggled == .accepted, "\(toggled.code)")
        let afterValve: ColorfallCanyonsExperienceCore = try Access.core(shell)
        let valvePlan: Plan = Plan.after(old: afterCarve, new: afterValve)
        let colour: String = level.springs[0].color.name.capitalized
        let state: String = afterValve.play.fluid.valves[0] ? "open" : "closed"
        #expect(afterValve.play.fluid.valves[0] != afterCarve.play.fluid.valves[0], "the valve toggled")
        let valveText: String = "\(colour) valve \(state). \(Access.leftText(afterValve.play.remaining))."
        #expect(valvePlan.text == valveText, "\(valvePlan.text ?? "nil")")
        #expect(valvePlan.kind == .state)
        #expect(valvePlan.haptic == .selection)
        expected.append(valvePlan)

        // A step of one tick.
        recorder.clock.advance()
        let stepped: ActionResult = presenter.send("time.step", [1], port: shell.port)
        #expect(stepped == .accepted, "\(stepped.code)")
        let afterStep: ColorfallCanyonsExperienceCore = try Access.core(shell)
        try #require(afterStep.play.stage == .playing, "one tick leaves level 1 playing")
        let stepPlan: Plan = Plan.after(old: afterValve, new: afterStep)
        let stepText: String = "Tick \(afterStep.play.fluid.tick) of \(level.tickLimit). "
            + "\(Access.filled(afterStep)) of \(level.basins.count) basins filled."
        #expect(afterStep.play.fluid.tick == 1)
        #expect(stepPlan.text == stepText, "\(stepPlan.text ?? "nil")")
        #expect(stepPlan.kind == .state)
        #expect(stepPlan.haptic == .selection)
        expected.append(stepPlan)

        // Undo and redo name the tick and the actions left after them with their prefix.
        recorder.clock.advance()
        let undone: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: ColorfallCanyonsExperienceCore = try Access.core(shell)
        let undoPlan: Plan = Plan.after(old: afterStep, new: afterUndo)
        let undoText: String = "Undone. Tick \(afterUndo.play.fluid.tick) of \(level.tickLimit). "
            + "\(Access.leftText(afterUndo.play.remaining))."
        #expect(afterUndo.play.fluid.tick == 0)
        #expect(undoPlan.text == undoText, "\(undoPlan.text ?? "nil")")
        #expect(undoPlan.kind == .state)
        #expect(undoPlan.haptic == .selection)
        expected.append(undoPlan)

        recorder.clock.advance()
        let redone: ActionResult = presenter.send("play.redo", [], port: shell.port)
        #expect(redone == .accepted, "\(redone.code)")
        let afterRedo: ColorfallCanyonsExperienceCore = try Access.core(shell)
        let redoPlan: Plan = Plan.after(old: afterUndo, new: afterRedo)
        let redoText: String = "Redone. Tick \(afterRedo.play.fluid.tick) of \(level.tickLimit). "
            + "\(Access.leftText(afterRedo.play.remaining))."
        #expect(afterRedo.play.fluid.tick == 1)
        #expect(redoPlan.text == redoText, "\(redoPlan.text ?? "nil")")
        #expect(redoPlan.kind == .state)
        #expect(redoPlan.haptic == .selection)
        expected.append(redoPlan)

        // A refusal: a locked level.
        digest = try ColorfallCanyonsTest.digest(shell)
        recorder.clock.advance()
        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(!locked.isAccepted)
        #expect(locked.code.contains(ColorfallCanyonsExperienceRule.locked), "\(locked.code)")
        let lockedPlan: Plan = Plan.refused(code: locked.code)
        #expect(lockedPlan.text == "That level is not open yet.", "\(lockedPlan.text ?? "nil")")
        #expect(lockedPlan.kind == .rejection)
        #expect(lockedPlan.haptic == .error)
        #expect(presenter.mirror.message == "That level is not open yet.", "the panel shows the same words")
        #expect(try ColorfallCanyonsTest.digest(shell) == digest)
        expected.append(lockedPlan)

        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected))
        #expect(Array(presenter.announcements.dropFirst(announcedBase)) == Access.texts(expected))
        #expect(recorder.announcements.announced.count == expected.count, "every plan here is announced")
    }

    // MARK: The panel alone (SC-R02G0506-001)

    /// Level 1 (seed 0) is won with the panel's operations alone, following the certified actions: the cell picker to
    /// each carved cell and Carve, the valve buttons, and Run; every step announced, the win an outcome with a success
    /// haptic.
    @Test func levelOneWonWithThePanelOperations() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let announcedBase: Int = presenter.announcements.count
        let opening: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        let columns: Int = opening.play.level.columns
        let actions: [ColorfallCanyonsAction] = ColorfallCanyonsExperienceCore.certifiedActions(1)
        try #require(!actions.isEmpty, "level 1 has certified actions")
        var announced: Int = 0
        var previous: ColorfallCanyonsExperienceCore = opening

        for (index, action) in actions.enumerated() {
            guard try Access.core(shell).play.stage == .playing else { break }
            let result: ActionResult
            switch action {
            case .carve(let cell):
                #expect(presenter.mirror.carvable.contains(cell), "action \(index): cell \(cell) is in the picker")
                let limit: Int = presenter.mirror.carvable.count
                var presses: Int = 0
                while presenter.mirror.pickedCell != cell && presses < limit {
                    recorder.clock.advance()
                    presenter.pickCell(1)
                    presses += 1
                    announced += 1
                    let picked: Int = presenter.mirror.pickedCell ?? -1
                    let text: String = "Row \(picked / columns + 1), column \(picked % columns + 1) picked."
                    #expect(presenter.announcements.last == text, "\(presenter.announcements.last ?? "nil")")
                    #expect(recorder.announcements.announced.last == text)
                }
                let target: Int = try #require(presenter.mirror.pickedCell)
                #expect(target == cell, "action \(index): the picker reached cell \(cell)")
                recorder.clock.advance()
                result = presenter.send("canyon.carve", [Double(target)], port: shell.port)
            case .valve(let spring):
                recorder.clock.advance()
                result = presenter.send("canyon.valve", [Double(spring)], port: shell.port)
            case .step:
                let ticks: Int = Access.runTicks(presenter.mirror)
                recorder.clock.advance()
                result = presenter.send("time.step", [Double(ticks)], port: shell.port)
            }
            #expect(result == .accepted, "action \(index): \(result.code)")
            let next: ColorfallCanyonsExperienceCore = try Access.core(shell)
            let plan: Plan = Plan.after(old: previous, new: next)
            #expect(plan.text != nil, "action \(index) is announced")
            announced += 1
            #expect(presenter.announcements.last == plan.text, "\(presenter.announcements.last ?? "nil")")
            #expect(recorder.announcements.announced.last == plan.text)
            previous = next
        }

        // Run again while the play goes on (the certified run ends at the win; this only guards a longer level).
        let rounds: Int = opening.play.level.tickLimit / Access.maxStep + 2
        for _ in 0..<rounds {
            guard try Access.core(shell).play.stage == .playing else { break }
            recorder.clock.advance()
            let result: ActionResult = presenter.send("time.step", [Double(Access.runTicks(presenter.mirror))],
                                                      port: shell.port)
            #expect(result == .accepted, "\(result.code)")
            announced += 1
            previous = try Access.core(shell)
        }

        let won: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        let stars: Int = ColorfallCanyonsProgress.stars(actions: won.play.spent, smallest: won.certifiedSmallest)
        let spentText: String = won.play.spent == 1 ? "1 action" : "\(won.play.spent) actions"
        let winText: String = "Every basin is filled. Level won with \(spentText), \(stars) of 3 stars."
        let plans: [Plan] = Access.log(presenter, after: logBase)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(presenter.announcements.last == winText)
        #expect(recorder.announcements.announced.last == winText)
        #expect(presenter.announcements.count - announcedBase == announced, "every step announced")
        #expect(recorder.announcements.announced.count == announced)
        #expect(plans.count == announced)
        #expect(recorder.haptics.played == Access.haptics(plans), "\(recorder.haptics.played)")
        #expect(recorder.haptics.played.last == .success)
        #expect(presenter.mirror.status == "Won")
    }

    // MARK: Drag highlight (edge case)

    /// A drag in progress (finger down and moved, not released; the cell highlighted) adds no announcement, plan or
    /// haptic; the release announces its carve once.
    @Test func aDragHighlightIsNotAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let announcedBase: Int = presenter.announcements.count
        let before: ColorfallCanyonsExperienceCore = try Access.core(shell)
        let target = try #require(try Script.carvableTarget(shell), "a carvable cell visible at the authored orbit")
        let digest: String = try ColorfallCanyonsTest.digest(shell)
        let end: Vec2 = Script.dragEnd(from: target.point)
        var time: Double = 0

        recorder.clock.advance()
        Script.dragWithoutRelease(shell, from: target.point, to: end, time: &time)
        #expect(presenter.gestures.highlightedCell == target.cell, "the drag highlights the cell")
        try ColorfallCanyonsTest.draw(session)
        #expect(recorder.announcements.announced.isEmpty, "the highlight is not announced")
        #expect(presenter.feedbackLog.count == logBase, "the highlight plans nothing")
        #expect(presenter.announcements.count == announcedBase)
        #expect(recorder.haptics.played.isEmpty, "the highlight plays no haptic")
        #expect(try ColorfallCanyonsTest.digest(shell) == digest, "nothing is sent before the release")

        recorder.clock.advance()
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        let after: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(after.play.spent == before.play.spent + 1, "exactly one carve")
        let plan: Plan = Plan.after(old: before, new: after)
        let text: String = "Carved \(Access.cellText(target.cell, columns: before.play.level.columns)). "
            + "\(Access.leftText(after.play.remaining))."
        #expect(plan.text == text, "\(plan.text ?? "nil")")
        #expect(plan.haptic == .selection)
        let expected: [Plan] = [plan]
        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(Array(presenter.announcements.dropFirst(announcedBase)) == Access.texts(expected),
                "the release is announced once")
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected))
    }

    // MARK: Sound (FR-R02G0506-006; SC-R02G0506-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; a `play()` that fails changes nothing else; the recipe is rebuilt only for a new recipe (a level opening,
    /// a change of the basins or the stage) or the toggle turning on, never for the same recipe offered every frame.
    @Test func soundStateTable() throws {
        let empty: AmbientLoopRecipe = ColorfallCanyonsSoundRecipe.recipe(basinMasses: [[0, 0, 0]], stage: .playing)
        let filling: AmbientLoopRecipe = ColorfallCanyonsSoundRecipe.recipe(basinMasses: [[6, 0, 0]], stage: .playing)
        let won: AmbientLoopRecipe = ColorfallCanyonsSoundRecipe.recipe(basinMasses: [[6, 0, 0]], stage: .won)
        try #require(empty != filling, "another fill sounds different")
        try #require(filling != won, "a won play sounds different")

        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: ColorfallCanyonsFakeLoopFactory = ColorfallCanyonsFakeLoopFactory()
            let sound: ColorfallCanyonsSound = factory.sound(empty)
            sound.setOnScreen(onScreen)
            sound.setActive(active)
            sound.setWanted(wanted)
            let expected: Bool = wanted && onScreen && active
            #expect(sound.shouldPlay == expected, "combination \(combination)")
            #expect(sound.started == expected, "combination \(combination)")
            #expect(sound.playersMade == (expected ? 1 : 0), "combination \(combination)")
            #expect((factory.made.last?.isPlaying ?? false) == expected, "combination \(combination)")
            if !wanted {
                #expect(factory.made.isEmpty, "sound off makes no player (combination \(combination))")
                #expect(sound.player == nil)
            }
        }

        // A failing play: the choice stays on, nothing else moves.
        let failing: ColorfallCanyonsFakeLoopFactory = ColorfallCanyonsFakeLoopFactory()
        failing.succeeds = false
        let broken: ColorfallCanyonsSound = failing.sound(empty)
        broken.setOnScreen(true)
        broken.setWanted(true)
        #expect(broken.playersMade == 1)
        #expect(!broken.started)
        #expect(broken.wanted)
        #expect(broken.onScreen)
        #expect(broken.active)
        #expect(broken.shouldPlay)
        #expect(broken.recipe == empty)
        #expect(failing.made.first?.plays == 1)
        #expect(failing.made.first?.isPlaying == false)
        #expect(failing.made.first?.stops == 0)

        // The sound off: offers make no player but are kept.
        let silent: ColorfallCanyonsFakeLoopFactory = ColorfallCanyonsFakeLoopFactory()
        let off: ColorfallCanyonsSound = silent.sound(empty)
        off.setOnScreen(true)
        off.offer(filling)
        off.offer(won)
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)
        #expect(off.recipe == won, "kept for the next start")

        // Rebuilds only at the named moments.
        let factory: ColorfallCanyonsFakeLoopFactory = ColorfallCanyonsFakeLoopFactory()
        let sound: ColorfallCanyonsSound = factory.sound(empty)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1, "the toggle turning on makes the first player")
        for _ in 0..<30 { sound.offer(empty) }
        #expect(sound.playersMade == 1, "the same recipe every frame keeps the player")
        sound.offer(filling)
        #expect(sound.playersMade == 2, "a change of the basins makes a new player")
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
        sound.offer(empty)
        #expect(sound.playersMade == 3, "an offer while off makes no player")
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "the toggle turning on plays the latest recipe")
        #expect(sound.playerRecipe == empty)
        #expect(factory.recipes == [empty, filling, won, empty])
        sound.setWanted(false)
        sound.setWanted(true)
        #expect(sound.playersMade == 4, "toggling with the same recipe keeps the player")
        #expect(sound.started)
    }

    /// The presenter's own sound (real `AmbientLoopPlayer`; never started here: the sound is off, or on while off
    /// screen): the recipe follows the described core; drawn frames leave it; turning the sound on off screen keeps the
    /// choice on and makes no player.
    @Test func presenterSoundFollowsTheCore() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        #expect(!presenter.sound.wanted)
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        let opening: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")

        try ColorfallCanyonsTest.draw(session, frames: 3)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "drawn frames leave the recipe")
        #expect(presenter.sound.playersMade == 0)

        try ColorfallCanyonsTest.flow(shell)
        let flowing: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(flowing), "the basins' recipe after a run")

        #expect(presenter.send("level.select", [1], port: shell.port) == .accepted)
        let fresh: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(fresh), "a level opening offers its recipe")

        presenter.sceneActive(false)
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay, "the controls are not on screen")
        #expect(!presenter.sound.started)
        #expect(presenter.sound.playersMade == 0, "no player is made off screen")
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.playersMade == 0)
        presenter.sceneActive(true)
    }

    // MARK: Reduce Flashing (FR-R02G0506-004; SC-R02G0506-003)

    /// Under Reduce Flashing, drawn frames 1/60 s apart: a flow (valves open, two ticks) fades the sheets and emitters
    /// in; 0.1 s later every changed level lies strictly between its start and its target; then undo and redo alternate
    /// every frame for 40 frames and the lights are held 40 frames. No element crosses half its range more than 3 times
    /// per second.
    @Test func drawnLightsUnderReduceFlashing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceFlashing: true)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        #expect(presenter.lights.reducedFlash)

        let base: Double = 100
        var frame: Int = 0
        var samples: [ColorfallCanyonsLightSample] = [try Access.sample(session, presenter, time: base)]
        #expect(presenter.lights.isSettled, "the opening lights rest")

        let accepted: Int = try ColorfallCanyonsTest.flow(shell)
        #expect(accepted >= 1)
        try #require(try Access.core(shell).play.stage == .playing, "the flow leaves level 1 playing")
        for _ in 1...30 {
            frame += 1
            samples.append(try Access.sample(session, presenter, time: base + Double(frame) / Access.frameRate))
            #expect(presenter.scene.lights == presenter.lights, "frame \(frame): the scene draws the eased lights")
        }
        #expect(presenter.lights.isSettled, "a fade lasts 0.45 s")

        // 0.1 s after the flow: every changed level is between its start and its target.
        let early: [[Double]] = Access.vectors(Array(samples.prefix(31)))
        let start: [Double] = early[0]
        let target: [Double] = early[30]
        let tenth: [Double] = early[6]
        var changed: Int = 0
        for index in 0..<start.count where Swift.abs(target[index] - start[index]) > 0.01 {
            changed += 1
            let low: Double = Swift.min(start[index], target[index])
            let high: Double = Swift.max(start[index], target[index])
            #expect(tenth[index] > low && tenth[index] < high,
                    "element \(index): \(tenth[index]) after 0.1 s, from \(start[index]) to \(target[index])")
        }
        #expect(changed >= 1, "the flow changes a light")

        // Undo and redo every frame, ending on a redo; then held.
        for index in 1...40 {
            let result: ActionResult = index % 2 == 1
                ? shell.port.send("play.undo", [])
                : shell.port.send("play.redo", [])
            #expect(result == .accepted, "flicker \(index): \(result.code)")
            frame += 1
            samples.append(try Access.sample(session, presenter, time: base + Double(frame) / Access.frameRate))
        }
        for _ in 1...40 {
            frame += 1
            samples.append(try Access.sample(session, presenter, time: base + Double(frame) / Access.frameRate))
        }
        #expect(presenter.lights.isSettled, "the lights settle once the flicker stops")

        let vectors: [[Double]] = Access.vectors(samples)
        #expect(Access.anyMidFade(vectors), "the lights fade rather than switch")
        let crossings: Double = ColorfallCanyonsLights.maxHalfRangeCrossingsPerSecond(vectors,
                                                                                      frameRate: Access.frameRate)
        #expect(crossings <= 3, "Reduce Flashing: \(crossings) half-range crossings per second")
    }

    // MARK: Reduce Motion (FR-R02G0506-004)

    /// Under Reduce Motion two stills of the same flowing state at different frame times are byte-identical and the
    /// drawn snapshot keeps time 0.
    @Test func reduceMotionStillsIdentical() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceMotion: true)
        Access.quiet(shell)
        try ColorfallCanyonsTest.flow(shell)
        // A first still lets any light fade of the flow finish (the next frame is 0.25 s later, beyond 0.15 s).
        _ = try ColorfallCanyonsTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0)
        let first: [UInt8] = try ColorfallCanyonsTest.still(session, width: Access.stillWidth,
                                                            height: Access.stillHeight, time: 0.25)
        let firstDrawn: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let second: [UInt8] = try ColorfallCanyonsTest.still(session, width: Access.stillWidth,
                                                             height: Access.stillHeight, time: 1.3)
        let secondDrawn: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(ColorfallCanyonsTest.nonNightPixels(first) > 0, "the still shows the scene")
        #expect(first == second, "Reduce Motion: stills at 0.25 s and 1.3 s are identical")
        #expect(firstDrawn.time == 0)
        #expect(secondDrawn.time == 0)
        let core: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(secondDrawn == core.snapshot(time: 0))
    }

    // MARK: Summary element (FR-R02G0506-001, 005)

    /// The summary element's words are `summaryText(core:)`, written out: at the opening and after a flow.
    @Test func summaryElementWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        let opening: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(presenter.mirror.summary == Plan.summaryText(core: opening))
        #expect(presenter.mirror.summary == Access.summaryText(opening), "\(presenter.mirror.summary)")
        #expect(presenter.mirror.summary.hasPrefix("Tick 0 of \(opening.play.level.tickLimit). "))

        try ColorfallCanyonsTest.flow(shell)
        let flowing: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(presenter.mirror.summary == Plan.summaryText(core: flowing))
        #expect(presenter.mirror.summary == Access.summaryText(flowing), "\(presenter.mirror.summary)")
        #expect(presenter.mirror.summary.hasPrefix("Tick \(flowing.play.fluid.tick) of "))
    }
}
#endif
