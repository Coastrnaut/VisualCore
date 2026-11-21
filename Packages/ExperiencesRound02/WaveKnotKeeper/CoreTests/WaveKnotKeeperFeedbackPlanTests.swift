// WaveKnotKeeperFeedbackPlanTests — feature 326 (R02-G03-06) T-R02G0306-002 (FR-R02G0306-002, 003; SC-R02G0306-002;
// clarifications Q1, Q2). The exact announcement texts, kinds and haptics of `WaveKnotKeeperFeedbackPlan` on real cores:
// moves with counted and degenerate projections, selection, undo and redo, a campaign win with 3 stars (the certified
// solution of level 1) and one with 2 stars, a practice win, a failure (`allowanceEntries`) and the undo that rewinds it,
// `level.select`, `level.next`, `mode.daily`, `mode.practice`, `mode.campaign` with and without the tutorial, the
// tutorial dismissal and hint, no change, and every refusal code (raw, prefixed and as the core reports it).
// Seed 2_326 opens level 27 (band 2, 7 points, target 2 crossings and writhe 0, allowance 13, certified shortest 1:
// point 2 left); its start projection is degenerate and point 2 right gives 1 crossing, writhe −1. Seed 0 opens level 1
// (target 1, 1; allowance 9; certified shortest 1: point 2 right; tutorial "Drag point 2 one step"). The expected texts
// are written out here, not built with the plan's helpers. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct WaveKnotKeeperFeedbackPlanTests {
    typealias Core = WaveKnotKeeperExperienceCore
    typealias Plan = WaveKnotKeeperFeedbackPlan

    /// The seed of the main scenarios: level 27.
    static let seed: UInt64 = 2_326

    /// The `point.move` action of 0-based `point` and direction index `direction` (0 +x, 1 −x, 2 +y, 3 −y, 4 +z, 5 −z).
    static func move(_ point: Int, _ direction: Int) -> ExperienceAction {
        ExperienceAction(control: "point.move", values: [Double(point), Double(direction)], step: 0)
    }

    /// The bare action `control` with `values`.
    static func bare(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// Applies `action` to `core` (it must be accepted) and returns the plan of the change.
    static func step(_ core: inout Core, _ action: ExperienceAction) -> Plan {
        let old: Core = core
        let result: ActionResult = core.apply(action)
        #expect(result == .accepted, "\(action.control) \(action.values)")
        return Plan.after(old: old, new: core)
    }

    /// A `state` plan with the selection haptic.
    static func state(_ text: String) -> Plan { Plan(text: text, kind: .state, haptic: .selection) }

    /// A `level` plan without a haptic.
    static func level(_ text: String) -> Plan { Plan(text: text, kind: .level, haptic: nil) }

    /// The degenerate text of level 27 after `spent` moves, with `prefix` and the move named.
    static func overlap(_ prefix: String, _ named: String, _ spent: Int) -> Plan {
        state("\(prefix)\(named). Two strands overlap in the view. Target 2 crossings, writhe 0. Moves \(spent) of 13.")
    }

    @Test func movesSelectionUndoRedoAndNoChange() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 27 && core.tutorial == .done && core.play.level.allowance == 13)
        #expect(core.play.points.count == 7 && core.certifiedShortest == 1 && core.play.summary.degenerate)
        #expect(Plan.after(old: core, new: core) == .none)
        // Selection: announced without a haptic; the same selection again is no change.
        let selected: Plan = Self.step(&core, Self.bare("point.select", [1]))
        #expect(selected == Plan(text: "Point 2 selected.", kind: .state, haptic: nil))
        #expect(Self.step(&core, Self.bare("point.select", [1])) == .none)
        // A counted projection.
        let counted: Plan = Self.step(&core, Self.move(1, 0))
        #expect(counted == Self.state("Point 2 moved right. 1 crossing, writhe -1; target 2, 0. Moves 1 of 13."))
        // Undo names the move that was undone (right), not the step back.
        let undo: Plan = Self.step(&core, Self.bare("play.undo"))
        #expect(undo == Self.overlap("Undone: ", "Point 2 moved right", 0))
        let redo: Plan = Self.step(&core, Self.bare("play.redo"))
        #expect(redo == Self.state("Redone: Point 2 moved right. 1 crossing, writhe -1; target 2, 0. Moves 1 of 13."))
        // Back at the start rope: degenerate projections, each move undone again.
        #expect(Self.step(&core, Self.bare("play.undo")) == Self.overlap("Undone: ", "Point 2 moved right", 0))
        let directions: [(Int, String)] = [(2, "up"), (3, "down"), (4, "over")]
        var spent: Int = 0
        for (direction, word) in directions {
            let plan: Plan = Self.step(&core, Self.move(4, direction))
            spent += 1
            #expect(plan == Self.overlap("", "Point 5 moved \(word)", spent), "\(word)")
            #expect(Self.step(&core, Self.bare("play.undo")) == Self.overlap("Undone: ", "Point 5 moved \(word)",
                                                                              spent - 1))
            spent -= 1
        }
        let left: Plan = Self.step(&core, Self.move(0, 1))
        #expect(left == Self.overlap("", "Point 1 moved left", 1))
        let under: Plan = Self.step(&core, Self.move(5, 5))
        #expect(under == Self.overlap("", "Point 6 moved under", 2))
        #expect(Plan.after(old: core, new: core) == .none)
    }

    @Test func campaignWinsWithStars() async throws {
        // The certified solution of level 1 (seed 0): 3 stars, and the outcome replaces the move's selection haptic.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.levelNumber == 1 && core.certifiedShortest == 1)
        let solution: [WaveKnotKeeperMove] = try Core.generated(number: 1).solution.moves
        #expect(solution.count == 1)
        var last: Plan = .none
        for move in solution {
            let index: Int = try #require(Core.directionOrder.firstIndex(of: move.direction))
            last = Self.step(&core, Self.move(move.point, index))
        }
        #expect(core.play.stage == .won)
        #expect(last == Plan(text: "The knot matches. Level won in 1 move, 3 of 3 stars.", kind: .outcome,
                             haptic: .success))
        // Ended: a further move is refused with the stage code.
        let refused: ActionResult = core.apply(Self.move(0, 0))
        #expect(refused.code == "action.rule.r02-g03.stage")
        #expect(Plan.refused(code: refused.code) == Plan(text: "The level has ended.", kind: .rejection,
                                                         haptic: .error))
        // Level 27 in three moves against a shortest of one: 2 stars.
        var slow: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.step(&slow, Self.move(0, 0)).haptic == .selection)
        #expect(Self.step(&slow, Self.move(0, 1)).haptic == .selection)
        let won: Plan = Self.step(&slow, Self.move(1, 1))
        #expect(won == Plan(text: "The knot matches. Level won in 3 moves, 2 of 3 stars.", kind: .outcome,
                            haptic: .success))
    }

    @Test func practiceWinHasNoStars() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let practice: Plan = Self.step(&core, Self.bare("mode.practice"))
        #expect(practice == Self.level("Level 27, band 2, Practice."))
        #expect(core.play.level.allowance == 64)
        let won: Plan = Self.step(&core, Self.move(1, 1))
        #expect(won == Plan(text: "The knot matches. Level won in 1 move.", kind: .outcome, haptic: .success))
        let campaign: Plan = Self.step(&core, Self.bare("mode.campaign"))
        #expect(campaign == Self.level("Level 27, band 2, Campaign."))
    }

    @Test func failureAndItsRewind() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let entries: [ScenarioStep] = Core.allowanceEntries
        #expect(entries.count == 9)
        var plans: [Plan] = []
        for entry in entries {
            let scripted: ScriptedAction = try #require(entry.action)
            plans.append(Self.step(&core, ExperienceAction(control: scripted.control, values: scripted.values, step: 0)))
        }
        #expect(core.play.stage == .failed)
        for index in 0..<8 {
            #expect(plans[index].kind == .state && plans[index].haptic == .selection, "move \(index)")
        }
        let explanation: String = "Two strands overlap in the view, so the crossings cannot be counted. "
            + "Undo the last move or retry the level."
        #expect(core.failureExplanation?.text == explanation)
        #expect(plans[8] == Plan(text: explanation, kind: .outcome, haptic: .warning))
        // The rewind names the failing move.
        let rewound: Plan = Self.step(&core, Self.bare("play.undo"))
        #expect(rewound == Self.state("Undone: Point 1 moved right. Two strands overlap in the view. "
                                      + "Target 1 crossing, writhe 1. Moves 8 of 9."))
    }

    @Test func levelAndModeChangesWithTheTutorial() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.step(&core, Self.move(1, 0)).kind == .state)
        // The same level selected again: a fresh play, announced as a level.
        let again: Plan = Self.step(&core, Self.bare("level.select", [27]))
        #expect(again == Self.level("Level 27, band 2, Campaign."))
        // Level 1 shows the tutorial (its first hint point is point 2).
        let tutorialText: String = "Level 1, band 1, Campaign. Drag point 2 one step (or use the panel)"
        let first: Plan = Self.step(&core, Self.bare("level.select", [1]))
        #expect(first == Self.level(tutorialText))
        // Dismissing the tutorial and a hint are not announced; reopening the untouched level shows it again.
        #expect(Self.step(&core, Self.bare("tutorial.hint")) == .none)
        #expect(Self.step(&core, Self.bare("tutorial.dismiss")) == .none)
        #expect(Self.step(&core, Self.bare("mode.campaign")) == Self.level(tutorialText))
        // A move advances the tutorial; its plan is still the move's.
        let moved: Plan = Self.step(&core, Self.move(0, 0))
        #expect(moved == Self.state("Point 1 moved right. Two strands overlap in the view. Target 1 crossing, "
                                    + "writhe 1. Moves 1 of 9."))
        #expect(core.tutorial == .signature)
        // Practice on level 1 has no tutorial.
        #expect(Self.step(&core, Self.bare("mode.practice")) == Self.level("Level 1, band 1, Practice."))
        // level.next from 27 wraps to level 1 (28 is not open).
        var fromTwentySeven: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.step(&fromTwentySeven, Self.bare("level.next")) == Self.level(tutorialText))
        // The daily level of 2026-11-21 is level 33, band 2.
        var daily: Core = try await Core.prepare(seed: Self.seed)
        let dailyPlan: Plan = Self.step(&daily, Self.bare("mode.daily", [2026, 11, 21]))
        #expect(dailyPlan == Self.level("Level 33, band 2, Daily level."))
    }

    @Test func refusals() async throws {
        let move: String = "That move is not allowed: it would leave the space, meet another point, pass through a "
            + "strand outside a gate or pull the rope too tight."
        let cases: [(String, String)] = [
            ("r02-g03.locked", "That level is not open yet."),
            ("r02-g03.date", "That date cannot be used."),
            ("r02-g03.move", move),
            ("r02-g03.allowance", "No moves are left."),
            ("r02-g03.stage", "The level has ended."),
            ("r02-g03.stale", "That change was refused."),
            ("r02-g03.not-whole", "That change was refused."),
            ("action.unknown-control", "That change was refused."),
        ]
        for (code, text) in cases {
            let expected: Plan = Plan(text: text, kind: .rejection, haptic: .error)
            #expect(Plan.refused(code: code) == expected, "\(code)")
            #expect(Plan.refused(code: "action.rule." + code) == expected, "prefixed \(code)")
            #expect(Plan.refusalText(code: code) == text, "text \(code)")
            #expect(Plan.refusalText(code: "action.rule." + code) == text, "prefixed text \(code)")
        }
        // The codes the core reports; a refused action changes nothing, so it plans nothing.
        var core: Core = try await Core.prepare(seed: Self.seed)
        let before: Core = core
        let outside: ActionResult = core.apply(Self.move(10, 0))
        let locked: ActionResult = core.apply(Self.bare("level.select", [50]))
        let date: ActionResult = core.apply(Self.bare("mode.daily", [2026, 2, 30]))
        let selectOutside: ActionResult = core.apply(Self.bare("point.select", [12]))
        #expect(core == before && core.selected == nil)
        #expect(Plan.after(old: before, new: core) == .none)
        #expect(Plan.refused(code: outside.code).text == move)
        #expect(Plan.refused(code: selectOutside.code).text == move)
        #expect(Plan.refused(code: locked.code).text == "That level is not open yet.")
        #expect(Plan.refused(code: date.code).text == "That date cannot be used.")
    }

    /// Feature 327: the replay refusals are announced in their own words, the longer codes before `replay`.
    @Test func replayRefusalsInWords() {
        let codes: [String] = ["action.rule.r02-g03.no-replay", "action.rule.r02-g03.replay-end",
                               "action.rule.r02-g03.replay"]
        let texts: [String] = ["There is no saved solution to replay for this level.", "The replay is over.",
                               "Stop the replay first."]
        for index in codes.indices {
            let expected: WaveKnotKeeperFeedbackPlan = WaveKnotKeeperFeedbackPlan(text: texts[index], kind: .rejection,
                                                                                  haptic: .error)
            #expect(WaveKnotKeeperFeedbackPlan.refused(code: codes[index]) == expected, "\(codes[index])")
        }
    }
}
