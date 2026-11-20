// AuroraLoomFeedbackPlanTests — feature 306 (R02-G01-06) T-R02G0106-003 (FR-R02G0106-002, FR-R02G0106-003;
// clarifications Q1, Q2). The exact announcement texts, kinds and haptics of `AuroraLoomFeedbackPlan` for a move of the
// wave and of the phase, undo, redo, a campaign win and a practice win, a failure and the undo that rewinds it,
// `level.next`, `level.select`, `mode.daily`, `mode.practice`, the tutorial dismissal on level 1, no change, and the
// refusal codes; from feature 307 the replay texts (start, each move, the win), the replay refusals and the dropped-results
// announcement. Seed 2_306 (level 7: start wave [9, 15, 9], phase [8, 4, 4], allowance 11, certified shortest 2).
// Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct AuroraLoomFeedbackPlanTests {
    typealias Core = AuroraLoomExperienceCore
    typealias Plan = AuroraLoomFeedbackPlan

    /// The seed of every scenario: level 7.
    static let seed: UInt64 = 2_306

    /// The `ribbon.move` action of `ribbon`, `control` (0 = wave, 1 = phase) and `step`.
    static func move(_ ribbon: Int, _ control: Int, _ step: Int) -> ExperienceAction {
        ExperienceAction(control: "ribbon.move", values: [Double(ribbon), Double(control), Double(step)], step: 0)
    }

    /// The bare action `control` with `values`.
    static func bare(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The `ribbon.move` action of a kernel move.
    static func action(_ move: AuroraLoomMove) -> ExperienceAction {
        Self.move(move.ribbon, move.control == .wave ? 0 : 1, move.step)
    }

    /// Applies `action` to `core` (it must be accepted) and returns the plan of the change.
    static func step(_ core: inout Core, _ action: ExperienceAction) -> Plan {
        let old: Core = core
        let result: ActionResult = core.apply(action)
        #expect(result == .accepted, "\(action.control) \(action.values)")
        return Plan.after(old: old, new: core)
    }

    @Test func movesOfBothControlsUndoAndRedo() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 7 && core.tutorial == .done && core.play.level.allowance == 11)
        let wave: Plan = Self.step(&core, Self.move(1, 0, 2))
        #expect(wave == Plan(text: "Ribbon 2 wave 2. 4 of 12 gate crossings in harmony. Moves 1 of 11.", kind: .state,
                             haptic: .selection))
        let phase: Plan = Self.step(&core, Self.move(0, 1, 12))
        let phaseText: String = "Ribbon 1 phase 12. 4 of 12 gate crossings in harmony. Moves 2 of 11."
        #expect(phase == Plan(text: phaseText, kind: .state, haptic: .selection))
        let undo: Plan = Self.step(&core, Self.bare("play.undo"))
        let undoText: String = "Undone: Ribbon 1 phase 8. 4 of 12 gate crossings in harmony. Moves 1 of 11."
        #expect(undo == Plan(text: undoText, kind: .state, haptic: .selection))
        let redo: Plan = Self.step(&core, Self.bare("play.redo"))
        let redoText: String = "Redone: Ribbon 1 phase 12. 4 of 12 gate crossings in harmony. Moves 2 of 11."
        #expect(redo == Plan(text: redoText, kind: .state, haptic: .selection))
        // Nothing changed: no plan.
        #expect(Plan.after(old: core, new: core) == .none)
    }

    @Test func campaignAndPracticeWins() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let certified: AuroraLoomGenerated = try Core.generated(number: core.levelNumber)
        #expect(certified.solution.moves.count == 2)
        let first: Plan = Self.step(&core, Self.action(certified.solution.moves[0]))
        #expect(first.kind == .state && first.haptic == .selection)
        let won: Plan = Self.step(&core, Self.action(certified.solution.moves[1]))
        #expect(won == Plan(text: "Harmony. Level won in 2 moves, 3 of 3 stars.", kind: .outcome, haptic: .success))
        #expect(core.progress.solved[7]?.stars == 3)
        let practice: Plan = Self.step(&core, Self.bare("mode.practice"))
        #expect(practice == Plan(text: "Level 7, band 1, Practice.", kind: .level, haptic: nil))
        #expect(core.play.level.allowance == Core.practiceAllowance)
        var last: Plan = .none
        for move in certified.solution.moves { last = Self.step(&core, Self.action(move)) }
        #expect(last == Plan(text: "Harmony. Practice won in 2 moves.", kind: .outcome, haptic: .success))
    }

    @Test func aFailureAndItsRewind() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        var last: Plan = .none
        var guardCount: Int = 0
        while core.play.stage == .playing && guardCount < 64 {
            guardCount += 1
            let ribbon: Int = core.play.spent % 3
            let current: Int = core.play.steps.phase[ribbon]
            var next: Int = (current + 1) % 16
            var moved: Bool = false
            while next != current {
                var trial: Core = core
                if trial.apply(Self.move(ribbon, 1, next)) == .accepted, trial.play.stage != .won {
                    last = Plan.after(old: core, new: trial)
                    core = trial
                    moved = true
                    break
                }
                next = (next + 1) % 16
            }
            if !moved { break }
        }
        #expect(core.play.stage == .failed && core.play.spent == 11)
        let explanation: AuroraLoomFailureExplanation = try #require(core.failureExplanation)
        #expect(last == Plan(text: explanation.text, kind: .outcome, haptic: .warning))
        #expect(last.text == "Ribbon 1 is furthest off at gate 4, tick 0: 0.46 of a turn outside the tolerance after "
            + "the last move. Undo or retry.")
        // Undo after the failure rewinds the failing move (ribbon 2, the 11th move): its ribbon and the restored step.
        let failing: AuroraLoomRecord = try #require(core.play.records.last)
        #expect(failing.ribbon == 1 && failing.control == .phase && failing.kind == .move)
        let rewind: Plan = Self.step(&core, Self.bare("play.undo"))
        let rewindText: String = "Undone: Ribbon 2 phase 7. 0 of 12 gate crossings in harmony. Moves 10 of 11."
        #expect(rewind == Plan(text: rewindText, kind: .state, haptic: .selection))
    }

    @Test func levelAndModeChanges() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        _ = Self.step(&core, Self.move(1, 0, 2))
        // Level 8 is not open: the next open level after 7, in cyclic order, is 1 (a tutorial level).
        let next: Plan = Self.step(&core, Self.bare("level.next"))
        #expect(core.levelNumber == 1 && core.tutorial != .done)
        let nextText: String = "Level 1, band 1, Campaign. Drag ribbon 3's anchor up or down to change its wave."
        #expect(next == Plan(text: nextText, kind: .level, haptic: nil))
        let skipped: Plan = Self.step(&core, Self.bare("tutorial.dismiss"))
        #expect(skipped == Plan(text: "Tutorial skipped.", kind: .state, haptic: nil))
        // Dismissing again changes nothing.
        let again: Plan = Self.step(&core, Self.bare("tutorial.dismiss"))
        #expect(again == .none)
        let select: Plan = Self.step(&core, Self.bare("level.select", [3]))
        let selectText: String = "Level 3, band 1, Campaign. Drag ribbon 2's anchor up or down to change its wave."
        #expect(select == Plan(text: selectText, kind: .level, haptic: nil))
        let daily: Plan = Self.step(&core, Self.bare("mode.daily", [2026, 1, 2]))
        #expect(daily == Plan(text: "Level 38, band 2, Daily level.", kind: .level, haptic: nil))
        let campaign: Plan = Self.step(&core, Self.bare("mode.campaign"))
        #expect(campaign == Plan(text: "Level 7, band 1, Campaign.", kind: .level, haptic: nil))
        // The same level and mode opened afresh after a move is a level change too.
        _ = Self.step(&core, Self.move(1, 0, 2))
        let reopened: Plan = Self.step(&core, Self.bare("level.select", [7]))
        #expect(reopened == Plan(text: "Level 7, band 1, Campaign.", kind: .level, haptic: nil))
    }

    @Test func refusals() {
        let codes: [String] = ["r02-g01.locked", "rule:r02-g01.date", "r02-g01.allowance", "r02-g01.stage",
                               "r02-g01.move", ""]
        let texts: [String] = ["That level is not open yet.", "That date is not a calendar date.", "No moves are left.",
                               "That move was refused.", "That move was refused.", "That move was refused."]
        for index in codes.indices {
            #expect(Plan.refused(code: codes[index]) == Plan(text: texts[index], kind: .rejection, haptic: .error))
        }
        #expect(Plan.none == Plan(text: nil, kind: nil, haptic: nil))
        let replayCodes: [String] = ["action.rule.r02-g01.no-replay", "action.rule.r02-g01.replay-end",
                                     "action.rule.r02-g01.replay"]
        let replayTexts: [String] = ["No replay is stored for that level.", "The replay is over.",
                                     "Stop the replay first."]
        for index in replayCodes.indices {
            #expect(Plan.refused(code: replayCodes[index])
                == Plan(text: replayTexts[index], kind: .rejection, haptic: .error))
        }
    }

    @Test func droppedResultsAreAnnouncedOnce() {
        #expect(Plan.dropped(count: 0) == .none)
        #expect(Plan.dropped(count: 1) == Plan(text: "1 saved result could not be verified and was removed.",
                                               kind: .state, haptic: nil))
        #expect(Plan.dropped(count: 3) == Plan(text: "3 saved results could not be verified and were removed.",
                                               kind: .state, haptic: nil))
    }

    @Test func replayStartEachMoveAndTheWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let certified: AuroraLoomGenerated = try Core.generated(number: core.levelNumber)
        for move in certified.solution.moves { _ = Self.step(&core, Self.action(move)) }
        let level: Int = core.levelNumber
        let start: Plan = Self.step(&core, Self.bare("replay.start", [Double(level)]))
        #expect(start == Plan(text: "Level \(level), band 1, Replay.", kind: .level, haptic: nil))
        let count: Int = certified.solution.moves.count
        for index in 0..<count {
            let plan: Plan = Self.step(&core, Self.bare("replay.step"))
            if index == count - 1 {
                #expect(plan == Plan(text: "Replay complete in \(count) moves.", kind: .outcome, haptic: .success))
            } else {
                #expect(plan.text?.hasPrefix("Replay move \(index + 1) of \(count): Ribbon ") == true)
                #expect(plan.kind == .state && plan.haptic == .selection)
            }
        }
    }
}
