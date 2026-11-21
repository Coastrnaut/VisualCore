// AuroraLoomPanelTests — feature 309 (R02-G01-09) T-R02G0109-003 (FR-R02G0109-008; SC-R02G0109-007; spec Amendment
// and Edge Cases). On the simulator, through the one app's session host: the panel's pending steps. `stepPending` sets
// a pending step per ribbon control, wraps 15 + 1 → 0 and 0 − 1 → 15 from the pending value, announces exactly
// "Ribbon r wave s pending. Apply to move." (phase likewise; kind state, no haptic) and sends no action (the play's
// records and the engine digest are unchanged). `clearPending` drops the pending steps and sends nothing.
// `applyPending` sends one `ribbon.move` per changed control in ribbon order, wave before phase (checked in the play's
// records), returns the results in order and clears the pending steps; with nothing pending it sends nothing. An
// outside change (an undo or a `level.next` sent through the port) drops the pending steps; describing an unchanged
// core keeps them. A pending set whose earlier moves win the level stops at the first refused move (`r02-g01.stage`),
// announces the refusal, keeps the moves already applied and drops the rest. SC-R02G0109-007: every certified level
// 1 … 100 (five band tests of 20 levels, one session each, opened at the band's first level by seed and advanced by
// `level.select` after each win) is won by stepping pending values from the start steps to the solution's steps (the
// shorter wrap direction, one step at a time, as the steppers do) and one `applyPending`, with
// `spent == solution.shortest`.
// Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the panel tests.
@MainActor
enum AuroraLoomPanel {
    typealias Shell = ExperienceShell<AuroraLoomPresenter>

    /// The rule code of a move refused because the play has ended.
    static let stageCode: String = "r02-g01.stage"

    /// The step of `ribbon`'s `control` (0 = wave, 1 = phase) in `steps`.
    static func step(_ steps: AuroraLoomSteps, ribbon: Int, control: Int) -> Int {
        control == 0 ? steps.wave[ribbon] : steps.phase[ribbon]
    }

    /// `steps` with `ribbon`'s `control` set to `value`.
    static func setting(_ steps: AuroraLoomSteps, ribbon: Int, control: Int, to value: Int) -> AuroraLoomSteps {
        var result: AuroraLoomSteps = steps
        if control == 0 { result.wave[ribbon] = value } else { result.phase[ribbon] = value }
        return result
    }

    /// The control index (0 = wave, 1 = phase) of `control`.
    static func index(_ control: AuroraLoomControl) -> Int {
        control == .wave ? 0 : 1
    }

    /// The exact announcement of a pending step.
    static func pendingText(ribbon: Int, control: Int, step: Int) -> String {
        let name: String = control == 0 ? "wave" : "phase"
        return "Ribbon \(ribbon + 1) \(name) \(step) pending. Apply to move."
    }

    /// The log entry of a pending step's announcement (kind state, no haptic).
    static func pendingEntry(ribbon: Int, control: Int, step: Int) -> AuroraLoomFeedbackEntry {
        AuroraLoomFeedbackEntry(text: pendingText(ribbon: ribbon, control: control, step: step), kind: .state,
                                haptic: nil)
    }

    /// The shorter signed wrap distance from `from` to `to` on 0 … 15 (−7 … 8).
    static func wrapDelta(from: Int, to: Int) -> Int {
        let forward: Int = ((to - from) % 16 + 16) % 16
        return forward > 8 ? forward - 16 : forward
    }

    /// The steps the solution's moves reach from `start`.
    static func target(start: AuroraLoomSteps, moves: [AuroraLoomMove]) -> AuroraLoomSteps {
        var result: AuroraLoomSteps = start
        for move in moves {
            result = setting(result, ribbon: move.ribbon, control: index(move.control), to: move.step)
        }
        return result
    }

    /// The `.move` records of `play`, as moves, in order.
    static func movesRecorded(_ play: AuroraLoomPlay) -> [AuroraLoomMove] {
        var result: [AuroraLoomMove] = []
        for record in play.records where record.kind == .move {
            result.append(AuroraLoomMove(ribbon: record.ribbon, control: record.control, step: record.step))
        }
        return result
    }

    /// Steps the pending values of `shell`'s presenter from the current steps to `target`, one step at a time in the
    /// shorter wrap direction of each changed control, as the steppers do.
    static func stepPending(_ shell: Shell, from current: AuroraLoomSteps, to target: AuroraLoomSteps) {
        for ribbon in 0..<3 {
            for control in 0..<2 {
                let delta: Int = wrapDelta(from: step(current, ribbon: ribbon, control: control),
                                           to: step(target, ribbon: ribbon, control: control))
                let unit: Int = delta < 0 ? -1 : 1
                var taps: Int = 0
                while taps < abs(delta) {
                    shell.presenter.stepPending(ribbon: ribbon, control: control, by: unit)
                    taps += 1
                }
            }
        }
    }

    /// Wins levels `band` in one session: opened at the band's first level by seed, each level's solution set as
    /// pending steps and applied once, then `level.select` of the next level (opened by the win).
    static func winBand(_ band: ClosedRange<Int>) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomAccess.open(session, seed: UInt64(band.lowerBound - 1))
        let presenter: AuroraLoomPresenter = shell.presenter
        _ = AuroraLoomAccess.record(shell)
        for number in band {
            let opening: AuroraLoomExperienceCore = try AuroraLoomAccess.core(shell)
            #expect(opening.levelNumber == number)
            #expect(opening.mode == .campaign)
            #expect(opening.play.stage == .playing, "level \(number)")
            let certified: AuroraLoomGenerated = try AuroraLoomExperienceCore.generated(number: number)
            #expect(opening.play.steps == certified.level.startSteps, "level \(number) starts at its start steps")
            let start: AuroraLoomSteps = opening.play.steps
            let goal: AuroraLoomSteps = target(start: start, moves: certified.solution.moves)
            #expect(goal == certified.solution.setting, "level \(number) solution setting")

            stepPending(shell, from: start, to: goal)
            #expect(presenter.mirror.pending == goal, "level \(number) pending equals the solution's steps")
            let held: AuroraLoomExperienceCore = try AuroraLoomAccess.core(shell)
            #expect(held.play.records.count == opening.play.records.count, "level \(number): stepping sends nothing")

            let results: [ActionResult] = presenter.applyPending(port: shell.port)
            #expect(results.count == certified.solution.shortest, "level \(number): \(results.count) moves sent")
            for result in results {
                #expect(result == .accepted, "level \(number): \(result.code)")
            }
            #expect(presenter.mirror.pending == nil)
            let won: AuroraLoomExperienceCore = try AuroraLoomAccess.core(shell)
            #expect(won.play.stage == .won, "level \(number) is won by one Apply")
            #expect(won.play.spent == certified.solution.shortest,
                    "level \(number): spent \(won.play.spent), shortest \(certified.solution.shortest)")
            #expect(won.play.steps == goal)

            if number < band.upperBound {
                let picked: ActionResult = presenter.send("level.select", [Double(number + 1)], port: shell.port)
                #expect(picked == .accepted, "level \(number + 1): \(picked.code)")
            }
        }
    }
}

@MainActor
@Suite(.serialized) struct AuroraLoomPanelTests {
    typealias Panel = AuroraLoomPanel
    typealias Access = AuroraLoomAccess

    // MARK: Pending steps (FR-R02G0109-008)

    /// Stepping pending values sends nothing, wraps both ways from the pending value and announces exactly.
    @Test func pendingStepsWrapAnnounceAndSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let recorder: AuroraLoomAccess.Recorder = Access.record(shell)
        let opening: AuroraLoomExperienceCore = try Access.core(shell)
        let digest: String = try AuroraLoomTest.digest(shell)
        let start: AuroraLoomSteps = opening.play.steps
        #expect(presenter.mirror.pending == nil, "nothing is pending at the opening")

        // A control whose current step is neither 0 nor 15, for each kind.
        var waveRibbon: Int?
        var phaseRibbon: Int?
        for ribbon in 0..<3 {
            if waveRibbon == nil, start.wave[ribbon] != 0, start.wave[ribbon] != 15 { waveRibbon = ribbon }
            if phaseRibbon == nil, start.phase[ribbon] != 0, start.phase[ribbon] != 15 { phaseRibbon = ribbon }
        }
        let checks: [(ribbon: Int?, control: Int)] = [(waveRibbon, 0), (phaseRibbon, 1)]
        let logStart: Int = presenter.feedbackLog.count
        var expectedEntries: [AuroraLoomFeedbackEntry] = []
        var expectedTexts: [String] = []
        var expectedPending: AuroraLoomSteps = start
        var checked: Int = 0
        for check in checks {
            guard let ribbon = check.ribbon else { continue }
            checked += 1
            let control: Int = check.control
            let current: Int = Panel.step(start, ribbon: ribbon, control: control)
            // Up to 15, then 15 + 1 → 0, then 0 − 1 → 15, then 15 + 17 → 0.
            let deltas: [Int] = [15 - current, 1, -1, 17]
            let values: [Int] = [15, 0, 15, 0]
            for index in 0..<deltas.count {
                recorder.clock.advance()
                presenter.stepPending(ribbon: ribbon, control: control, by: deltas[index])
                expectedPending = Panel.setting(expectedPending, ribbon: ribbon, control: control, to: values[index])
                #expect(presenter.mirror.pending == expectedPending,
                        "ribbon \(ribbon) control \(control) step \(index)")
                let entry: AuroraLoomFeedbackEntry = Panel.pendingEntry(ribbon: ribbon, control: control,
                                                                        step: values[index])
                expectedEntries.append(entry)
                expectedTexts.append(Panel.pendingText(ribbon: ribbon, control: control, step: values[index]))
            }
        }
        #expect(checked > 0, "level 1 has a control away from 0 and 15")
        #expect(Array(presenter.feedbackLog.dropFirst(logStart)) == expectedEntries)
        #expect(recorder.announcements.announced == expectedTexts)
        #expect(recorder.haptics.played.isEmpty, "a pending step plays no haptic")

        let after: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(after.play.records.isEmpty, "stepping pending values sends no move")
        #expect(after.play.steps == start)
        #expect(after.play.spent == opening.play.spent)
        #expect(try AuroraLoomTest.digest(shell) == digest, "the state is unchanged")
        // Describing the unchanged core keeps the pending steps.
        _ = shell.accessibilitySummary
        #expect(presenter.mirror.pending == expectedPending)
    }

    /// Clear drops the pending steps and sends nothing; Apply with nothing pending sends nothing.
    @Test func clearDropsPendingAndEmptyApplySendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        _ = Access.record(shell)
        let digest: String = try AuroraLoomTest.digest(shell)

        presenter.stepPending(ribbon: 0, control: 0, by: 3)
        presenter.stepPending(ribbon: 2, control: 1, by: -2)
        #expect(presenter.mirror.pending != nil)
        presenter.clearPending()
        #expect(presenter.mirror.pending == nil)
        #expect(try AuroraLoomTest.digest(shell) == digest, "Clear sends nothing")

        let results: [ActionResult] = presenter.applyPending(port: shell.port)
        #expect(results.isEmpty, "nothing pending, nothing sent")
        #expect(presenter.mirror.pending == nil)
        let core: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(core.play.records.isEmpty)
        #expect(try AuroraLoomTest.digest(shell) == digest)
    }

    /// Apply sends one move per changed control in ribbon order, wave before phase, whatever order they were stepped
    /// in, returns the results in order and clears the pending steps.
    @Test func applySendsChangedControlsInOrderAndClears() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        _ = Access.record(shell)
        let opening: AuroraLoomExperienceCore = try Access.core(shell)
        let start: AuroraLoomSteps = opening.play.steps

        // Four controls stepped out of order; a delta whose ordered moves keep the play going (checked by trial).
        let stepped: [(ribbon: Int, control: Int)] = [(2, 1), (0, 0), (1, 0), (0, 1)]
        let ordered: [(ribbon: Int, control: Int)] = [(0, 0), (0, 1), (1, 0), (2, 1)]
        var chosen: Int?
        for delta in 1..<16 {
            var trial: AuroraLoomPlay = opening.play
            var fine: Bool = true
            for pair in ordered {
                let value: Int = (Panel.step(start, ribbon: pair.ribbon, control: pair.control) + delta) % 16
                let kind: AuroraLoomControl = pair.control == 0 ? .wave : .phase
                let move: AuroraLoomMove = AuroraLoomMove(ribbon: pair.ribbon, control: kind, step: value)
                do {
                    try trial.apply(move, expecting: trial.fingerprint)
                } catch {
                    fine = false
                    break
                }
                if trial.stage != .playing {
                    fine = false
                    break
                }
            }
            if fine {
                chosen = delta
                break
            }
        }
        let delta: Int = try #require(chosen, "a delta that keeps level 1 playing over four moves")
        for pair in stepped {
            presenter.stepPending(ribbon: pair.ribbon, control: pair.control, by: delta)
        }
        var expected: [AuroraLoomMove] = []
        for pair in ordered {
            let value: Int = (Panel.step(start, ribbon: pair.ribbon, control: pair.control) + delta) % 16
            expected.append(AuroraLoomMove(ribbon: pair.ribbon, control: pair.control == 0 ? .wave : .phase,
                                           step: value))
        }
        let held: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(held.play.records.isEmpty, "nothing is sent before Apply")

        let logStart: Int = presenter.feedbackLog.count
        let results: [ActionResult] = presenter.applyPending(port: shell.port)
        #expect(results.count == expected.count)
        for result in results {
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(presenter.mirror.pending == nil, "Apply clears the pending steps")
        let after: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(Panel.movesRecorded(after.play) == expected, "ribbon order, wave before phase")
        #expect(after.play.spent == expected.count)
        #expect(after.play.stage == .playing)
        // Apply's moves are announced as ordinary moves, never as pending steps.
        for entry in presenter.feedbackLog.dropFirst(logStart) {
            #expect(entry.text?.contains("pending") != true, "\(entry.text ?? "nil")")
        }
        // The moves stay applied: the next described core keeps them and nothing is pending.
        _ = shell.accessibilitySummary
        #expect(presenter.mirror.pending == nil)
        #expect(try Access.core(shell).play.steps == after.play.steps)
    }

    /// An outside change drops the pending steps: an undo sent through the port, then a `level.next`.
    @Test func outsideChangeDropsPending() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        // Seed 4: level 5 with levels 1 … 5 open, so `level.next` opens another level (1).
        let shell = try await Access.open(session, seed: 4)
        let presenter: AuroraLoomPresenter = shell.presenter
        _ = Access.record(shell)
        let opening: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 5)

        // One move through the steppers' old operation, then a pending step, then an undo from elsewhere.
        let moved: ActionResult? = presenter.adjust(ribbon: 0, control: 0, by: 1, port: shell.port)
        #expect(moved == .accepted, "\(moved?.code ?? "nil")")
        let afterMove: AuroraLoomExperienceCore = try Access.core(shell)
        try #require(afterMove.play.stage == .playing, "level 5 is not won by one wave step")
        presenter.stepPending(ribbon: 1, control: 1, by: 2)
        #expect(presenter.mirror.pending != nil)
        let undone: ActionResult = presenter.send("play.undo", port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        #expect(presenter.mirror.pending == nil, "an undo from elsewhere drops the pending steps")

        // A pending step, then the next level from elsewhere.
        presenter.stepPending(ribbon: 2, control: 0, by: -3)
        #expect(presenter.mirror.pending != nil)
        let next: ActionResult = presenter.send("level.next", port: shell.port)
        #expect(next == .accepted, "\(next.code)")
        let opened: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(opened.levelNumber != 5)
        #expect(presenter.mirror.pending == nil, "a level change drops the pending steps")

        // Apply after the drop sends nothing.
        let results: [ActionResult] = presenter.applyPending(port: shell.port)
        #expect(results.isEmpty)
        #expect(try Access.core(shell).play.records.isEmpty)
    }

    /// A pending set whose earlier moves win the level: the next move is refused with the stage reason and announced,
    /// the rest is dropped, the moves already applied stay.
    @Test func refusalMidApplyStopsAndDropsTheRest() async throws {
        // The first level whose solution's last move comes before some later control (ribbon order, wave first).
        var found: (number: Int, certified: AuroraLoomGenerated, extra: (ribbon: Int, control: Int))?
        for number in AuroraLoomExperienceCore.levelNumbers {
            let certified: AuroraLoomGenerated = try AuroraLoomExperienceCore.generated(number: number)
            guard let last = certified.solution.moves.last else { continue }
            let lastIndex: Int = last.ribbon * 2 + Panel.index(last.control)
            if lastIndex < 5 {
                let extraIndex: Int = lastIndex + 1
                found = (number: number, certified: certified,
                         extra: (ribbon: extraIndex / 2, control: extraIndex % 2))
                break
            }
        }
        let chosenCase = try #require(found, "a level whose solution leaves a later control unchanged")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: UInt64(chosenCase.number - 1))
        let presenter: AuroraLoomPresenter = shell.presenter
        _ = Access.record(shell)
        let opening: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == chosenCase.number)
        let start: AuroraLoomSteps = opening.play.steps
        let goal: AuroraLoomSteps = Panel.target(start: start, moves: chosenCase.certified.solution.moves)

        Panel.stepPending(shell, from: start, to: goal)
        let extra: (ribbon: Int, control: Int) = chosenCase.extra
        presenter.stepPending(ribbon: extra.ribbon, control: extra.control, by: 1)
        let extraStep: Int = (Panel.step(start, ribbon: extra.ribbon, control: extra.control) + 1) % 16
        let expectedPending: AuroraLoomSteps = Panel.setting(goal, ribbon: extra.ribbon, control: extra.control,
                                                             to: extraStep)
        #expect(presenter.mirror.pending == expectedPending)

        let results: [ActionResult] = presenter.applyPending(port: shell.port)
        let shortest: Int = chosenCase.certified.solution.shortest
        #expect(results.count == shortest + 1, "the winning moves, then the refused one")
        for index in 0..<results.count where index < shortest {
            #expect(results[index] == .accepted, "move \(index): \(results[index].code)")
        }
        let refused: ActionResult = try #require(results.last)
        #expect(!refused.isAccepted)
        #expect(refused.code.contains(Panel.stageCode), "\(refused.code)")
        let refusal: AuroraLoomFeedbackEntry = Access.entry(AuroraLoomFeedbackPlan.refused(code: refused.code))
        #expect(presenter.feedbackLog.last == refusal, "the refusal is announced with its reason")
        #expect(presenter.mirror.pending == nil, "the remaining pending steps are dropped")

        let after: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(after.play.stage == .won)
        #expect(after.play.spent == shortest, "the moves already applied stay")
        #expect(after.play.steps == goal)
        #expect(Panel.movesRecorded(after.play) == chosenCase.certified.solution.moves)
    }

    // MARK: Every certified level through Apply (SC-R02G0109-007)

    /// Levels 1 … 20 are won by their solution's pending steps and one Apply.
    @Test func everyLevelBand1WonThroughApply() async throws {
        try await Panel.winBand(1...20)
    }

    /// Levels 21 … 40 are won by their solution's pending steps and one Apply.
    @Test func everyLevelBand2WonThroughApply() async throws {
        try await Panel.winBand(21...40)
    }

    /// Levels 41 … 60 are won by their solution's pending steps and one Apply.
    @Test func everyLevelBand3WonThroughApply() async throws {
        try await Panel.winBand(41...60)
    }

    /// Levels 61 … 80 are won by their solution's pending steps and one Apply.
    @Test func everyLevelBand4WonThroughApply() async throws {
        try await Panel.winBand(61...80)
    }

    /// Levels 81 … 100 are won by their solution's pending steps and one Apply.
    @Test func everyLevelBand5WonThroughApply() async throws {
        try await Panel.winBand(81...100)
    }
}
#endif
