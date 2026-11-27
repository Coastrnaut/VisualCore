// MushroomWeatherFeedbackPlanTests — feature 496 (R02-G20-06) T-R02G2006-003 (FR-R02G2006-001, 002, 003;
// SC-R02G2006-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `MushroomWeatherFeedbackPlan` on
// real certified cores driven through `MushroomWeatherExperienceCore.apply`: a placement with an undo and a redo, a
// vent closed, then a 3-star campaign win along the certified plan (the run plans only the outcome) and the `stage`
// refusals after it; moves, removals, vents opened and the moonlight; 2-star and 1-star wins (undone actions count), a
// 1-action win, practice wins without stars and daily wins with them; every refusal code (provoked through the adapter
// where the core can produce it, with the engine's `action.rule.` prefix as `ActionResult.code` reports it, the
// engine's own range refusal, and every code by table, bare and prefixed); failed runs of every failure kind (unstable
// from level 1's opening, dried from level 2's, mold on a constructed level), each with an undo (state) and a redo back
// into the failure (only the outcome); a whole budget spent ("1 action left", the 10th action refused `budget`, the run
// then fails); level and mode changes with and without the tutorial; showing a cycle plans nothing; a revealed hint;
// the summary element; a seeded random walk (seed 2_496) checking the classification of every step.
//
// Level facts used (read from the kernel's reports of the certified levels, worked out independently of the plan):
// level 1 (tutorial): 6 × 6, 2 colonies, 2 pod slots, required 6 of 31 cycles, budget 9, sites (0, 4), (2, 4), (2, 5),
// (5, 2), vent 1 at (0, 5) open, moonlight 2, certified plan pod on (2, 5) then vent 1 closed; final in-band runs: the
// opening [0, 10] (colony 1 fails unstable with run 0), pod on (2, 5) [1, 10], pod on (0, 4) or (2, 4) [0, 10], pods on
// (2, 4) and (5, 2) fail with colony 2 out too, moonlight 3 [0, 13], moonlight 0 [0, 0]. Level 2 (tutorial): budget 10,
// its opening dries colony 2 at cycle 25 with runs [0, 0]. Level 3 (tutorial): budget 11, vent 1 starts closed; opened,
// colony 2 dries at cycle 17 with runs [0, 0]. Level 4: band 1, no tutorial. Level 41 (band 3): 3 colonies, 3 slots,
// budget 13, certified plan pods on (0, 4), (3, 7) and (5, 7). The constructed mold level: 6 × 6 at humidity 990, no
// evaporation, one slot whose pod starts on (0, 0) and releases 40, mold bound 1000, so (0, 0) grows mold at cycle 1;
// removing the pod wins. The expected texts are written out here, not built with the plan's helpers. Explicit types,
// plain loops, short runs. Modelled on feature 486's MicroscopicAuroraFeedbackPlanTests.
import Foundation
import Testing
@testable import MushroomWeatherCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct MushroomWeatherFeedbackPlanTests {
    typealias Core = MushroomWeatherExperienceCore
    typealias Plan = MushroomWeatherFeedbackPlan

    /// The tutorial's first instruction (feature 495).
    static let placeStep: String = "Tap a marked site (or choose a site and press Place) to put a spore pod there; the "
        + "mist and gauges show the new weather"

    /// The advice that ends every failure explanation (feature 495).
    static let advice: String = "Undo the last action or retry the level."

    /// The opening sentence of a win.
    static let won: String = "Every colony stayed in its band."

    /// The words of a `stage` refusal.
    static let ended: String = "The level has ended."

    /// The words of an `action` refusal.
    static let cannot: String = "That pod, vent or moonlight change cannot be made, or there is nothing to remove, "
        + "undo or redo."

    /// The fixed seed of the feature's random walk.
    static let seed: UInt64 = 2_496

    /// The bare action `control` with `values`.
    static func bare(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// Applies `control` with `values` to `core`, expects it accepted and returns the plan of the change.
    static func accepted(_ core: inout Core, _ control: String, _ values: [Double] = []) -> Plan {
        let old: Core = core
        let result: ActionResult = core.apply(bare(control, values))
        #expect(result == .accepted, "\(control) \(values): \(result)")
        return Plan.after(old: old, new: core)
    }

    /// Places the pod of `slot` on (`row`, `column`) and returns the plan.
    static func place(_ core: inout Core, _ slot: Int, _ row: Int, _ column: Int) -> Plan {
        accepted(&core, "pod.place", [Double(slot), Double(row), Double(column)])
    }

    /// Runs the weather and returns the plan.
    static func run(_ core: inout Core) -> Plan {
        accepted(&core, "weather.run")
    }

    /// Applies `control` with `values` to `core`, expects the refusal with bare reason code `code` and the core
    /// unchanged with no change plan, and returns the refusal plan of the code as the engine reports it.
    static func refused(_ core: inout Core, _ control: String, _ values: [Double], code: String) -> Plan {
        let old: Core = core
        let result: ActionResult = core.apply(bare(control, values))
        #expect(result == .rejected(.rule(code: code)), "\(control) \(values): \(result)")
        #expect(result.code == "action.rule." + code)
        #expect(core == old)
        #expect(Plan.after(old: old, new: core) == Plan.none)
        #expect(Plan.refused(code: code) == Plan.refused(code: result.code))
        return Plan.refused(code: result.code)
    }

    /// A constructed core of level `levelNumber` playing `play` in `mode` with `tutorial` against `certifiedPlan`
    /// (campaign progress through that level), for states the adapter's actions cannot reach: several records between
    /// two cores, and the constructed mold level.
    static func constructed(levelNumber: Int, play: MushroomWeatherPlay, mode: MushroomWeatherMode,
                            tutorial: MushroomWeatherTutorialStep, certifiedPlan: MushroomWeatherPlan) -> Core {
        var progress: MushroomWeatherProgress = MushroomWeatherProgress()
        progress.open(through: levelNumber)
        let opening: Core.Opening = Core.Opening(play: play, progress: progress, tutorial: tutorial,
                                                 certifiedPlan: certifiedPlan)
        return Core(levelNumber: levelNumber, play: play, progress: progress, mode: mode, tutorial: tutorial,
                    certifiedPlan: certifiedPlan, openingNumber: levelNumber, opening: opening)
    }

    /// The constructed mold level (see the file header).
    static func moldLevel() throws -> MushroomWeatherLevel {
        let cells: Int = 36
        let start: MushroomWeatherArrangement = MushroomWeatherArrangement(
            pods: [MushroomWeatherCell(row: 0, column: 0)], ventsOpen: [], moonlight: 0)
        let colony: MushroomWeatherColony = MushroomWeatherColony(cell: MushroomWeatherCell(row: 5, column: 5),
                                                                  low: 900, high: 1000)
        let sites: [MushroomWeatherCell] = [MushroomWeatherCell(row: 0, column: 0),
                                            MushroomWeatherCell(row: 0, column: 1)]
        return try MushroomWeatherLevel(id: "mold-test", seed: 7, difficulty: 1, rows: 6, columns: 6, blocked: [],
                                        humidity: Array(repeating: 990, count: cells), diffusion: 1,
                                        rates: Array(repeating: 0, count: cells), vents: [],
                                        podRules: MushroomWeatherPodRules(slots: 1, release: 40, grownRelease: 40,
                                                                          growthThreshold: 100_000),
                                        colonies: [colony], moldBound: 1000, length: 20, required: 5, start: start,
                                        budget: 3, tutorial: false, sites: sites)
    }

    /// A core playing the constructed mold level in `mode` (numbered 1 for the level words), whose certified plan is
    /// the one removal that wins it.
    static func moldCore(mode: MushroomWeatherMode = .campaign) throws -> Core {
        let level: MushroomWeatherLevel = try moldLevel()
        let play: MushroomWeatherPlay = try Core.freshPlay(of: level)
        let plan: MushroomWeatherPlan = MushroomWeatherPlan(
            actions: [.remove(slot: 0)],
            arrangement: MushroomWeatherArrangement(pods: [nil], ventsOpen: [], moonlight: 0),
            arrangementsByDepth: [1], nearestMiss: 0, work: 2)
        return constructed(levelNumber: 1, play: play, mode: mode, tutorial: .done, certifiedPlan: plan)
    }

    /// A `state` plan with haptic `selection`.
    static func state(_ text: String) -> Plan { Plan(text: text, kind: .state, haptic: .selection) }

    /// A `level` plan without haptic.
    static func level(_ text: String) -> Plan { Plan(text: text, kind: .level, haptic: nil) }

    /// A `rejection` plan with haptic `error`.
    static func rejection(_ text: String) -> Plan { Plan(text: text, kind: .rejection, haptic: .error) }

    /// An `outcome` plan with haptic `success`.
    static func success(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .success) }

    /// An `outcome` plan with haptic `warning`.
    static func warning(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .warning) }

    @Test func placementUndoRedoVentAndA3StarCampaignWin() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(core.play.level.budget == 9 && core.play.level.required == 6)
        #expect(Self.place(&core, 0, 2, 5) == Self.state("Pod 1 placed at row 2, column 5. 1 of 2 colonies stay in "
            + "band, running now would fail, 8 actions left."))
        #expect(core.play.report.colonies[0].finalRun == 1 && core.play.report.colonies[1].finalRun == 10)
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 of 2 colonies stay in band, running now "
            + "would fail, 9 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 1 of 2 colonies stay in band, running now "
            + "would fail, 8 actions left."))
        #expect(Self.accepted(&core, "vent.set", [0, 0]) == Self.state("Vent 1 closed. 2 of 2 colonies stay in band, "
            + "running now would win, 7 actions left."))
        // The run plans only the outcome: 2 actions (the redo spends nothing) against the certified 2.
        #expect(Self.run(&core) == Self.success(Self.won + " Level won spending 2 actions, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won run is final: the real `stage` refusals.
        let ended: Plan = Self.rejection(Self.ended)
        #expect(Self.refused(&core, "pod.place", [1, 0, 4], code: "r02-g20.stage") == ended)
        #expect(Self.refused(&core, "pod.remove", [0], code: "r02-g20.stage") == ended)
        #expect(Self.refused(&core, "vent.set", [0, 1], code: "r02-g20.stage") == ended)
        #expect(Self.refused(&core, "moon.set", [3], code: "r02-g20.stage") == ended)
        #expect(Self.refused(&core, "weather.run", [], code: "r02-g20.stage") == ended)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g20.stage") == ended)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g20.stage") == ended)
        // The next level shows the tutorial again.
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.placeStep))
        // Level 41: three placements, a 3-star win.
        var forest: Core = try Core.opening(number: 41)
        #expect(Self.place(&forest, 0, 0, 4) == Self.state("Pod 1 placed at row 0, column 4. 0 of 3 colonies stay in "
            + "band, running now would fail, 12 actions left."))
        #expect(Self.place(&forest, 1, 3, 7) == Self.state("Pod 2 placed at row 3, column 7. 1 of 3 colonies stay in "
            + "band, running now would fail, 11 actions left."))
        #expect(Self.place(&forest, 2, 5, 7) == Self.state("Pod 3 placed at row 5, column 7. 3 of 3 colonies stay in "
            + "band, running now would win, 10 actions left."))
        #expect(Self.run(&forest) == Self.success(Self.won + " Level won spending 3 actions, 3 of 3 stars."))
    }

    @Test func movesRemovalsVentsAndTheMoonlight() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.place(&core, 0, 0, 4) == Self.state("Pod 1 placed at row 0, column 4. 1 of 2 colonies stay in "
            + "band, running now would fail, 8 actions left."))
        #expect(Self.place(&core, 0, 2, 4) == Self.state("Pod 1 moved to row 2, column 4. 1 of 2 colonies stay in "
            + "band, running now would fail, 7 actions left."))
        #expect(Self.place(&core, 1, 5, 2) == Self.state("Pod 2 placed at row 5, column 2. 0 of 2 colonies stay in "
            + "band, running now would fail, 6 actions left."))
        #expect(Self.accepted(&core, "pod.remove", [1]) == Self.state("Pod 2 removed. 1 of 2 colonies stay in band, "
            + "running now would fail, 5 actions left."))
        #expect(Self.accepted(&core, "moon.set", [3]) == Self.state("Moonlight set to level 3. 1 of 2 colonies stay "
            + "in band, running now would fail, 4 actions left."))
        #expect(Self.accepted(&core, "moon.set", [0]) == Self.state("Moonlight set to level 0. 1 of 2 colonies stay "
            + "in band, running now would fail, 3 actions left."))
        // An undo of a move restores the earlier cell and says only "Undone.".
        #expect(Self.accepted(&core, "play.undo").text == "Undone. 1 of 2 colonies stay in band, running now would "
            + "fail, 4 actions left.")
        // Level 3: vent 1 starts closed.
        var third: Core = try Core.opening(number: 3)
        #expect(Self.accepted(&third, "vent.set", [0, 1]) == Self.state("Vent 1 opened. 0 of 2 colonies stay in band, "
            + "running now would fail, 10 actions left."))
        #expect(Self.accepted(&third, "vent.set", [0, 0]) == Self.state("Vent 1 closed. 0 of 2 colonies stay in band, "
            + "running now would fail, 9 actions left."))
        // Several records at once (two kernel actions between two cores; one adapter action records at most one, so the
        // later core is constructed) say the progress alone.
        let start: Core = try Core.opening(number: 1)
        var play: MushroomWeatherPlay = start.play
        try play.apply(.place(slot: 0, cell: MushroomWeatherCell(row: 2, column: 5)), expecting: play.fingerprint)
        try play.apply(.vent(index: 0, open: false), expecting: play.fingerprint)
        let after: Core = Self.constructed(levelNumber: 1, play: play, mode: .campaign, tutorial: .recover,
                                           certifiedPlan: start.certifiedPlan)
        #expect(Plan.after(old: start, new: after) == Self.state("2 of 2 colonies stay in band, running now would "
            + "win, 7 actions left."))
    }

    @Test func starsUndoneActionsCountAndPracticeAndDailyWins() throws {
        // Two extra moonlight changes on the way: 4 actions against the certified 2 → 2 stars.
        var two: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&two, "moon.set", [3]).kind == .state)
        #expect(Self.accepted(&two, "moon.set", [2]) == Self.state("Moonlight set to level 2. 1 of 2 colonies stay "
            + "in band, running now would fail, 7 actions left."))
        #expect(Self.place(&two, 0, 2, 5).kind == .state)
        #expect(Self.accepted(&two, "vent.set", [0, 0]).text?.hasSuffix("running now would win, 5 actions left.")
                == true)
        #expect(Self.run(&two) == Self.success(Self.won + " Level won spending 4 actions, 2 of 3 stars."))
        // Three undone placements: 5 actions against the certified 2 → 1 star, in campaign, practice (budget 24, no
        // stars) and the daily level of 2026-01-01 (level 1, with stars).
        let campaign: Core = try Core.opening(number: 1)
        var practice: Core = campaign
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.placeStep))
        var daily: Core = campaign
        #expect(Self.accepted(&daily, "mode.daily", [2026, 1, 1]) == Self.level("Level 1, band 1, daily. "
            + Self.placeStep))
        let cases: [(Core, Int, String)] = [
            (campaign, 9, Self.won + " Level won spending 5 actions, 1 of 3 stars."),
            (practice, 24, Self.won + " Level won spending 5 actions."),
            (daily, 9, Self.won + " Level won spending 5 actions, 1 of 3 stars."),
        ]
        for (start, budget, outcome) in cases {
            var one: Core = start
            #expect(one.play.level.budget == budget && one.certifiedActionCount == 2)
            for _ in 0..<3 {
                #expect(Self.place(&one, 0, 2, 5).haptic == .selection)
                #expect(Self.accepted(&one, "play.undo") == Self.state("Undone. 1 of 2 colonies stay in band, running "
                    + "now would fail, \(budget) actions left."))
            }
            #expect(Self.place(&one, 0, 2, 5).kind == .state)
            #expect(Self.accepted(&one, "vent.set", [0, 0]) == Self.state("Vent 1 closed. 2 of 2 colonies stay in "
                + "band, running now would win, \(budget - 2) actions left."))
            #expect(Self.run(&one) == Self.success(outcome), "\(start.mode)")
        }
        // "1 action": the constructed level is won by removing its pod (certified plan of 1 action).
        var mold: Core = try Self.moldCore()
        let opening: Core = mold
        #expect(Self.accepted(&mold, "pod.remove", [0]).text == "Pod 1 removed. 1 of 1 colonies stay in band, running "
            + "now would win, 2 actions left.")
        #expect(Self.run(&mold) == Self.success(Self.won + " Level won spending 1 action, 3 of 3 stars."))
        var practiceMold: Core = try Self.moldCore(mode: .practice)
        #expect(Self.accepted(&practiceMold, "pod.remove", [0]).kind == .state)
        #expect(Self.run(&practiceMold) == Self.success(Self.won + " Level won spending 1 action."))
        #expect(opening.play.stage == .playing)
    }

    @Test func everyRefusalCodeInWords() throws {
        var core: Core = try Core.opening(number: 1)
        let action: Plan = Self.rejection(Self.cannot)
        // Provoked through the adapter (the engine reports `action.rule.<code>`): a cell that is not a site, a colony
        // cell, a cell off the floor, a slot the level lacks, an empty slot removed, a vent the level lacks, the
        // current vent state and moonlight, nothing to undo or redo.
        #expect(Self.refused(&core, "pod.place", [0, 3, 3], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "pod.place", [0, 1, 5], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "pod.place", [0, 11, 13], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "pod.place", [3, 0, 4], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "pod.remove", [0], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "vent.set", [1, 0], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "vent.set", [0, 1], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "moon.set", [2], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g20.action") == action)
        // The same cell again, and another slot's cell.
        #expect(Self.place(&core, 0, 0, 4).kind == .state)
        #expect(Self.refused(&core, "pod.place", [0, 0, 4], code: "r02-g20.action") == action)
        #expect(Self.refused(&core, "pod.place", [1, 0, 4], code: "r02-g20.action") == action)
        let whole: Plan = Self.rejection("That value must be a whole number.")
        #expect(Self.refused(&core, "pod.place", [0, 2.5, 5], code: "r02-g20.not-whole") == whole)
        #expect(Self.refused(&core, "moon.set", [0.25], code: "r02-g20.not-whole") == whole)
        // Level 1's run lasts 31 cycles.
        let cycle: Plan = Self.rejection("That cycle is outside the run.")
        #expect(Self.refused(&core, "clock.show", [32], code: "r02-g20.cycle") == cycle)
        #expect(Self.refused(&core, "clock.show", [200], code: "r02-g20.cycle") == cycle)
        // The engine's own range refusal (slot 6 is outside 0 … 5) is "any other code".
        let old: Core = core
        let range: ActionResult = core.apply(Self.bare("pod.place", [6, 0, 4]))
        #expect(range.code == "action.out-of-range")
        #expect(core == old)
        #expect(Plan.refused(code: range.code) == Self.rejection("That action was refused."))
        // Every code by table, bare and with the engine's prefix.
        let table: [(String, String)] = [
            ("r02-g20.locked", "That level is not open yet."),
            ("r02-g20.date", "That date cannot be used."),
            ("r02-g20.action", "That pod, vent or moonlight change cannot be made, or there is nothing to remove, "
                + "undo or redo."),
            ("r02-g20.budget", "No actions are left: undo or retry."),
            ("r02-g20.stage", "The level has ended."),
            ("r02-g20.stale", "The play changed before the action arrived."),
            ("r02-g20.level", "That level could not be made."),
            ("r02-g20.not-whole", "That value must be a whole number."),
            ("r02-g20.cycle", "That cycle is outside the run."),
            ("r02-g20.malformed", "That action was refused."),
            ("r02-g20.newer-schema", "That action was refused."),
            ("r02-g20.generation", "That action was refused."),
            ("r02-g20.witness", "That action was refused."),
            ("r02-g19.locked", "That action was refused."),
            ("action.out-of-range", "That action was refused."),
            ("", "That action was refused."),
        ]
        for (code, text) in table {
            #expect(Plan.refusalText(code: code) == text, "\(code)")
            #expect(Plan.refusalText(code: "action.rule." + code) == text, "prefixed \(code)")
            #expect(Plan.refused(code: code) == Self.rejection(text), "\(code)")
            #expect(Plan.refused(code: "action.rule." + code) == Self.rejection(text), "prefixed \(code)")
        }
    }

    @Test func everyFailureKindPlansOnlyItsOutcome() throws {
        // Unstable: level 1's opening.
        var unstable: Core = try Core.opening(number: 1)
        let unstablePlan: Plan = Self.warning("Colony 1 stayed in its band for only the last 0 cycles; 6 were needed. "
            + Self.advice)
        #expect(Self.run(&unstable) == unstablePlan)
        #expect(Self.accepted(&unstable, "play.undo") == Self.state("Undone. 1 of 2 colonies stay in band, running now "
            + "would fail, 9 actions left."))
        #expect(Self.accepted(&unstable, "play.redo") == unstablePlan)
        // Dried: level 2's opening.
        var dried: Core = try Core.opening(number: 2)
        let driedPlan: Plan = Self.warning("Colony 2 dried out at cycle 25: it fell below its survival floor. "
            + Self.advice)
        #expect(Self.run(&dried) == driedPlan)
        #expect(Self.accepted(&dried, "play.undo") == Self.state("Undone. 0 of 2 colonies stay in band, running now "
            + "would fail, 10 actions left."))
        #expect(Self.accepted(&dried, "play.redo") == driedPlan)
        // Dried after a vent: level 3.
        var vented: Core = try Core.opening(number: 3)
        #expect(Self.accepted(&vented, "vent.set", [0, 1]).kind == .state)
        #expect(Self.run(&vented) == Self.warning("Colony 2 dried out at cycle 17: it fell below its survival floor. "
            + Self.advice))
        // Mold: the constructed level.
        var mold: Core = try Self.moldCore()
        #expect(mold.play.report.failure == .mold(cell: MushroomWeatherCell(row: 0, column: 0), cycle: 1))
        let moldPlan: Plan = Self.warning("The cell at row 0, column 0 grew mold at cycle 1: it rose above the mold "
            + "bound. " + Self.advice)
        #expect(Self.run(&mold) == moldPlan)
        #expect(Self.accepted(&mold, "play.undo") == Self.state("Undone. 0 of 1 colonies stay in band, running now "
            + "would fail, 3 actions left."))
        #expect(Self.accepted(&mold, "play.redo") == moldPlan)
        let codes: [String] = [unstable.play.failure?.code ?? "", dried.play.failure?.code ?? "",
                               mold.play.failure?.code ?? ""]
        #expect(codes == ["unstable", "dried", "mold"])
    }

    @Test func aWholeBudgetSpentThenTheBudgetRefusalAndAFailedRun() throws {
        // Level 1 (budget 9): the moonlight 3, 2, 3, … nine times; every setting keeps colony 2 alone in band.
        var core: Core = try Core.opening(number: 1)
        let left: [String] = ["8 actions left", "7 actions left", "6 actions left", "5 actions left",
                              "4 actions left", "3 actions left", "2 actions left", "1 action left", "0 actions left"]
        for index in 0..<left.count {
            let moonlight: Int = index % 2 == 0 ? 3 : 2
            let expected: Plan = Self.state("Moonlight set to level \(moonlight). 1 of 2 colonies stay in band, "
                + "running now would fail, " + left[index] + ".")
            #expect(Self.accepted(&core, "moon.set", [Double(moonlight)]) == expected, "action \(index + 1)")
            if index == 7 {
                #expect(Plan.summaryText(core: core, slot: 1, site: nil).hasPrefix("1 action left. Pod 1 empty; "))
            }
        }
        let budget: Plan = Self.rejection("No actions are left: undo or retry.")
        #expect(Self.refused(&core, "moon.set", [2], code: "r02-g20.budget") == budget)
        #expect(Self.refused(&core, "pod.place", [0, 2, 5], code: "r02-g20.budget") == budget)
        #expect(Self.refused(&core, "vent.set", [0, 0], code: "r02-g20.budget") == budget)
        // The run is still allowed and plans only the warning.
        let failing: Plan = Self.warning("Colony 1 stayed in its band for only the last 0 cycles; 6 were needed. "
            + Self.advice)
        #expect(Self.run(&core) == failing)
        #expect(Self.refused(&core, "weather.run", [], code: "r02-g20.stage") == Self.rejection(Self.ended))
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g20.stage") == Self.rejection(Self.ended))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 of 2 colonies stay in band, running now "
            + "would fail, 0 actions left."))
        #expect(Self.accepted(&core, "play.redo") == failing)
    }

    @Test func levelAndModeChanges() throws {
        // Level 4's opening opens levels 1 … 4. level.select and level.next: levels 1 … 3 show the tutorial, level 4
        // none; past the frontier both are refused `locked`.
        var core: Core = try Core.opening(number: 4)
        #expect(Self.accepted(&core, "level.select", [1]) == Self.level("Level 1, band 1, campaign. " + Self.placeStep))
        #expect(Self.place(&core, 0, 0, 4).kind == .state)
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.placeStep))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 3, band 1, campaign. " + Self.placeStep))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 4, band 1, campaign."))
        let locked: Plan = Self.rejection("That level is not open yet.")
        #expect(Self.refused(&core, "level.next", [], code: "r02-g20.locked") == locked)
        #expect(Self.refused(&core, "level.select", [5], code: "r02-g20.locked") == locked)
        // A played level chosen again opens fresh: a level plan.
        let site: MushroomWeatherCell = try #require(core.play.level.sites?.first)
        #expect(Self.place(&core, 0, site.row, site.column).kind == .state)
        #expect(Self.accepted(&core, "level.select", [4]) == Self.level("Level 4, band 1, campaign."))
        // Mode changes: practice, back to campaign, the daily level of 2026-01-04 (level 52) and of 2026-01-21 (41).
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 4, band 1, practice."))
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 4, band 1, campaign."))
        #expect(Self.accepted(&core, "mode.daily", [2026, 1, 4]) == Self.level("Level 52, band 3, daily."))
        #expect(Self.accepted(&core, "mode.daily", [2026, 1, 21]) == Self.level("Level 41, band 3, daily."))
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g20.date")
                == Self.rejection("That date cannot be used."))
        // mode.campaign on a daily level not open in the campaign goes to the frontier.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 4, band 1, campaign."))
        // The same untouched play in the same mode again plans nothing.
        let untouched: Core = core
        #expect(Self.accepted(&core, "level.select", [4]) == Plan.none)
        #expect(core == untouched)
        // The tutorial: dismissing it is not announced; the same untouched play reopened shows it again (a level plan);
        // a touched play reopened is a fresh play (a level plan); level 1 in practice shows it too.
        var first: Core = try Core.opening(number: 1)
        #expect(first.tutorial == .place)
        #expect(Self.accepted(&first, "tutorial.dismiss") == Plan.none)
        #expect(first.tutorial == .done)
        #expect(Self.accepted(&first, "level.select", [1]) == Self.level("Level 1, band 1, campaign. "
            + Self.placeStep))
        #expect(Self.accepted(&first, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&first, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.placeStep))
        #expect(Self.place(&first, 0, 0, 4).kind == .state)
        #expect(Self.accepted(&first, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&first, "level.select", [1]) == Self.level("Level 1, band 1, campaign. "
            + Self.placeStep))
        #expect(Self.accepted(&first, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.placeStep))
        // The tutorial instruction follows the core's step: after a placement it is the next step.
        #expect(Self.place(&first, 0, 2, 5).kind == .state)
        #expect(first.tutorial == .balance)
        #expect(Plan.levelPlan(first) == Self.level("Level 1, band 1, practice. " + first.tutorial.text))
        #expect(first.tutorial.text != Self.placeStep)
    }

    @Test func showingACyclePlansNothingAHintAndTheSummary() throws {
        var core: Core = try Core.opening(number: 1)
        let cycles: [Double] = [10, 31, 0, 17]
        for cycle in cycles {
            #expect(Self.accepted(&core, "clock.show", [cycle]) == Plan.none, "cycle \(cycle)")
        }
        let hint: Plan = Plan.hint(text: "Use the site at row 2, column 5")
        #expect(hint == Plan(text: "Use the site at row 2, column 5", kind: .state, haptic: nil))
        let level1: String = "Level: level 1, band 1, campaign; a forest of 6 rows by 6 columns, 2 colonies, 4 sites, "
            + "2 pod slots, 1 vent; a run of 31 cycles; a budget of 9 actions."
        #expect(Plan.summaryText(core: core, slot: 0, site: 2) == "9 actions left. Pod 1 empty; pod 2 empty; vent 1 at "
            + "row 0, column 5, open; moonlight 2 of 3; colony 1 at row 1, column 5: 16 units, band 32 … 44, in band "
            + "for the last 0 of 31 cycles; colony 2 at row 5, column 1: 29 units, band 23 … 40, survival floor 17, in "
            + "band for the last 10 of 31 cycles; needs every colony in band for the last 6 cycles of 31 cycles; "
            + "running now would fail: colony 1 is in band for only the last 0 cycles, needs 6. Selected: pod 1, site "
            + "at row 2, column 5. " + level1)
        #expect(Self.place(&core, 0, 2, 5).kind == .state)
        #expect(Self.accepted(&core, "vent.set", [0, 0]).kind == .state)
        // Showing a cycle after actions still plans nothing.
        #expect(Self.accepted(&core, "clock.show", [5]) == Plan.none)
        #expect(Plan.summaryText(core: core, slot: 1, site: nil) == "7 actions left. Pod 1 at row 2, column 5, not "
            + "grown; pod 2 empty; vent 1 at row 0, column 5, closed; moonlight 2 of 3; colony 1 at row 1, column 5: "
            + "42 units, band 32 … 44, in band for the last 26 of 31 cycles; colony 2 at row 5, column 1: 29 units, "
            + "band 23 … 40, survival floor 17, in band for the last 10 of 31 cycles; needs every colony in band for "
            + "the last 6 cycles of 31 cycles; running now would win. Selected: pod 2, no site. " + level1)
        // A site number the level lacks reads as no site.
        #expect(Plan.summaryText(core: core, slot: 0, site: 4).contains("Selected: pod 1, no site. "))
        #expect(Plan.summaryText(core: core, slot: 0, site: -1).contains("Selected: pod 1, no site. "))
        // Level 41 and the practice mode's words.
        let forest: Core = try Core.opening(number: 41)
        let summary: String = Plan.summaryText(core: forest, slot: 2, site: 4)
        #expect(summary.hasPrefix("13 actions left. Pod 1 empty; pod 2 empty; pod 3 empty; vent 1 at row 7, column 6, "
            + "open; vent 2 at row 2, column 5, open; moonlight 0 of 3; colony 1 at row 4, column 7: "))
        #expect(summary.hasSuffix("; running now would fail: colony 2 dries out at cycle 13. Selected: pod 3, site at "
            + "row 5, column 7. Level: level 41, band 3, campaign; a forest of 8 rows by 8 columns, 3 colonies, 5 "
            + "sites, 3 pod slots, 2 vents; a run of 39 cycles; a budget of 13 actions."))
        var practice: Core = forest
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 41, band 3, practice."))
        let practiceSummary: String = Plan.summaryText(core: practice, slot: 0, site: 0)
        #expect(practiceSummary.hasPrefix("24 actions left. Pod 1 empty; "))
        #expect(practiceSummary.hasSuffix("Selected: pod 1, site at row 0, column 4. Level: level 41, band 3, "
            + "practice; a forest of 8 rows by 8 columns, 3 colonies, 5 sites, 3 pod slots, 2 vents; a run of 39 "
            + "cycles; a budget of 24 actions."))
        // The constructed level: one colony, one slot, no vents.
        let mold: Core = try Self.moldCore()
        #expect(Plan.summaryText(core: mold, slot: 0, site: 1).hasSuffix("Selected: pod 1, site at row 0, column 1. "
            + "Level: level 1, band 1, campaign; a forest of 6 rows by 6 columns, 1 colony, 2 sites, 1 pod slot, no "
            + "vents; a run of 20 cycles; a budget of 3 actions."))
    }

    @Test func aSeededRandomWalkClassifiesEveryStep() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        let controls: [String] = ["pod.place", "pod.remove", "vent.set", "moon.set", "weather.run", "play.undo",
                                  "play.redo", "clock.show"]
        let rare: [String] = ["mode.daily", "tutorial.dismiss", "mode.campaign", "mode.practice", "level.select",
                              "level.next"]
        let levelControls: Set<String> = ["level.next", "level.select", "mode.daily", "mode.practice", "mode.campaign"]
        var core: Core = try Core.opening(number: 4)
        var kinds: [AnnouncementKind: Int] = [:]
        for step in 0..<160 {
            // Levels, modes and the tutorial change rarely (weight 1 of 40 each) so plays run long enough to end.
            let pick: Int = random.int(0...39)
            let control: String = pick >= 34 ? rare[pick - 34] : controls[pick % controls.count]
            var values: [Double] = []
            switch control {
            case "level.select": values = [Double(random.int(1...6))]
            case "mode.daily": values = [2026, 1, Double(random.int(1...31))]
            case "pod.place": values = [Double(random.int(0...2)), Double(random.int(0...6)), Double(random.int(0...6))]
            case "pod.remove": values = [Double(random.int(0...2))]
            case "vent.set": values = [Double(random.int(0...1)), Double(random.int(0...1))]
            case "moon.set": values = [Double(random.int(0...3))]
            case "clock.show": values = [Double(random.int(0...45))]
            default: values = []
            }
            let old: Core = core
            let result: ActionResult = core.apply(Self.bare(control, values))
            let plan: Plan = Plan.after(old: old, new: core)
            guard result == .accepted else {
                #expect(core == old && plan == Plan.none, "step \(step)")
                let refusal: Plan = Plan.refused(code: result.code)
                #expect(refusal.kind == .rejection && refusal.haptic == .error, "step \(step)")
                #expect(refusal.text != "That action was refused.", "step \(step) \(result.code)")
                continue
            }
            switch control {
            case "clock.show":
                #expect(plan == Plan.none, "step \(step)")
            case "tutorial.dismiss":
                #expect(plan == Plan.none, "step \(step)")
            case _ where levelControls.contains(control):
                // A level or mode change; the same untouched play in the same mode chosen again plans nothing unless
                // it shows a dismissed tutorial again.
                let same: Bool = old.levelNumber == core.levelNumber && old.mode == core.mode && old.play == core.play
                if same && old.tutorial == core.tutorial {
                    #expect(plan == Plan.none, "step \(step)")
                } else {
                    #expect(plan.kind == .level && plan.haptic == nil, "step \(step)")
                }
            case "weather.run":
                #expect(plan.kind == .outcome, "step \(step)")
                #expect(plan.haptic == (core.play.stage == .won ? .success : .warning), "step \(step)")
            case "play.redo" where core.play.stage == .won || core.play.stage == .failed:
                #expect(plan.kind == .outcome, "step \(step)")
            default:
                #expect(plan.kind == .state && plan.haptic == .selection, "step \(step)")
                let total: Int = core.play.level.colonies.count
                let left: Int = core.play.actionsLeft
                let words: String = left == 1 ? "1 action left." : "\(left) actions left."
                #expect(plan.text?.hasSuffix(words) == true, "step \(step)")
                #expect(plan.text?.contains("\(Plan.coloniesInBand(core.play)) of \(total) colonies stay in band")
                        == true, "step \(step)")
            }
            if let kind = plan.kind { kinds[kind, default: 0] += 1 }
            // An ended play moves on so the walk keeps playing: the next open level, else an open level chosen.
            if core.play.stage == .won || core.play.stage == .failed, random.int(0...1) == 0 {
                let before: Core = core
                var result: ActionResult = core.apply(Self.bare("level.next"))
                if result != .accepted {
                    #expect(result == .rejected(.rule(code: MushroomWeatherExperienceRule.locked)), "step \(step)")
                    result = core.apply(Self.bare("level.select", [Double(random.int(1...core.progress.frontier))]))
                }
                #expect(result == .accepted, "step \(step)")
                #expect(Plan.after(old: before, new: core).kind == .level)
            }
        }
        #expect((kinds[.state] ?? 0) > 0 && (kinds[.outcome] ?? 0) > 0 && (kinds[.level] ?? 0) > 0)
    }
}
