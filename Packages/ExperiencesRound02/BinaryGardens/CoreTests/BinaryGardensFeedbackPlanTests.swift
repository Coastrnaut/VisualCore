// BinaryGardensFeedbackPlanTests — feature 506 (R02-G21-06) T-R02G2106-003 (FR-R02G2106-001, 002, 003;
// SC-R02G2106-002; clarifications Q1, Q2, Q5). The announcements, haptics and triggers of Binary Gardens compared
// exactly: scripted ring, phase, luminosity and tilt actions, undos and redos on a hand level (each followed by the
// worlds keeping their light, the verdict and the actions left); refusals of every code, bare and with the engine's
// `action.rule.` prefix, and refusals the core itself returns; won runs in campaign, daily and practice (stars only
// where awarded); failed runs of every failure kind (frozen, scorched, unstable, wilted, bleached) with feature 505's
// explanation; level and mode changes with the tutorial instruction; a revealed hint; showing a tick and an unchanged
// core plan nothing; equal inputs give equal plans over a seeded script (seed 2 506); the summary element; a certified
// catalog level won by its own plan names 3 of 3 stars (none in practice, reached with `mode.practice`). Mode, tutorial
// step and certified count are feature 505's adapter state on the cores (hand cores built through the adapter's
// internal initialiser). Explicit types, plain loops; each test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreSimulation
@testable import BinaryGardensCore

@Suite struct BinaryGardensFeedbackPlanTests {
    typealias Plan = BinaryGardensFeedbackPlan
    typealias Core = BinaryGardensExperienceCore
    typealias Play = BinaryGardensPlay
    typealias Level = BinaryGardensLevel
    typealias Star = BinaryGardensStar
    typealias World = BinaryGardensWorld

    /// The test seed of the feature.
    static let seed: UInt64 = 2_506

    /// The advice that ends every failure explanation.
    static let advice: String = "Undo the last action or retry the level."

    /// A world at radius 30 held still with the given bounds, window and bloom band (by default it never blooms).
    static func world(lethalLow: Int = 0, comfortLow: Int = 1, comfortHigh: Int = 199_999,
                      lethalHigh: Int = 200_000, window: Int = 1, bloomLow: Int = 9_600_000,
                      bloomHigh: Int = 9_600_000) -> World {
        World(radius: 30, phase: 0, speed: 0, lethalLow: lethalLow, comfortLow: comfortLow, comfortHigh: comfortHigh,
              lethalHigh: lethalHigh, window: window, bloomLow: bloomLow, bloomHigh: bloomHigh)
    }

    /// A world that keeps its light under every arrangement of the hand level (only beside a world that does not:
    /// a level may not start won).
    static let blooming: World = world(bloomLow: 0)

    /// The hand level's arrangement with star 1 at luminosity index `light`, star 2 at phase `phase` and tilt `tilt`.
    static func arranged(light: Int = 0, phase: Int = 24, tilt: Int = 0) -> BinaryGardensArrangement {
        BinaryGardensArrangement(rings: [0, 1], phases: [0, phase], luminosities: [light, 1], tilt: tilt)
    }

    /// A world whose bloom band holds the integrals of the hand level after star 1's luminosity rises to 16 (then
    /// star 2 at phase 30, then tilt 2) but not the starting integral: the start wilts or bleaches, and every one of
    /// those arrangements keeps its light.
    static func growing() throws -> World {
        let probe: Level = try hand(worlds: [world()])
        var low: Int = Int.max
        var high: Int = Int.min
        for arrangement in [arranged(light: 1), arranged(light: 1, phase: 30), arranged(light: 1, phase: 30, tilt: 2)] {
            let integral: Int = BinaryGardensSky.report(probe, arrangement: arrangement).worlds[0].integral
            low = min(low, integral)
            high = max(high, integral)
        }
        let start: Int = BinaryGardensSky.report(probe, arrangement: probe.start).worlds[0].integral
        try #require(start < low || start > high, "start integral \(start) inside \(low) … \(high)")
        return world(bloomLow: low, bloomHigh: high)
    }

    /// The hand level (as feature 501's play tests): rings 2, 10 and 12 units; luminosities 4 and 16; star 1 on ring
    /// 1 at phase 0 with luminosity 4 (ring and luminosity adjustable); star 2 on ring 2 at phase 24 with luminosity
    /// 16 (ring and phase adjustable); tilt 0 of 3; minimum separation 9; tolerance 0.
    static func hand(worlds: [World] = [world()], budget: Int = 3, id: String = "hand",
                     seed: UInt64 = 7) throws(BinaryGardensError) -> Level {
        let stars: [Star] = [
            Star(ring: 0, phase: 0, luminosity: 0, ringAdjustable: true, phaseAdjustable: false,
                 luminosityAdjustable: true),
            Star(ring: 1, phase: 24, luminosity: 1, ringAdjustable: true, phaseAdjustable: true,
                 luminosityAdjustable: false),
        ]
        return try Level(id: id, seed: seed, difficulty: 1, ringRadii: [2, 10, 12], starSpeed: 1,
                         luminosityLevels: [4, 16], stars: stars, maxTilt: 3, startTilt: 0,
                         minimumSeparation: 9, clampRadius: 1, worlds: worlds, lethalTolerance: 0, budget: budget,
                         tutorial: false)
    }

    /// A certified plan of `size` arrangement actions on `level` (only its size is read: the stars count against it).
    static func certifiedPlan(size: Int, _ level: Level) -> BinaryGardensPlan {
        BinaryGardensPlan(actions: Array(repeating: BinaryGardensAction.tilt(step: 1), count: max(size, 0)),
                          arrangement: level.start, arrangementsByDepth: [], nearestMiss: 0,
                          nearestMissArrangement: level.start, work: 0)
    }

    /// A core playing a fresh play of `level` as level number `number` in `mode` with tutorial step `tutorial` and a
    /// certified plan of `certified` actions (feature 505's adapter state); levels 1 … `number` open.
    static func core(_ level: Level, number: Int = 4, mode: BinaryGardensMode = .campaign,
                     tutorial: BinaryGardensTutorialStep = .done, certified: Int = 1) throws -> Core {
        let play: Play = try Core.freshPlay(of: level)
        let plan: BinaryGardensPlan = Self.certifiedPlan(size: certified, level)
        var progress: BinaryGardensProgress = BinaryGardensProgress()
        progress.open(through: number)
        let opening: Core.Opening = Core.Opening(play: play, progress: progress, tutorial: tutorial,
                                                 certifiedPlan: plan)
        return Core(levelNumber: number, play: play, progress: progress, mode: mode, tutorial: tutorial,
                    certifiedPlan: plan, openingNumber: number, opening: opening)
    }

    /// The adapter control and values of kernel action `action`.
    static func input(_ action: BinaryGardensAction) -> (String, [Double]) {
        switch action {
        case .ring(let star, let index): ("star.ring", [Double(star), Double(index)])
        case .phase(let star, let step): ("star.phase", [Double(star), Double(step)])
        case .luminosity(let star, let index): ("star.luminosity", [Double(star), Double(index)])
        case .tilt(let step): ("orbit.tilt", [Double(step)])
        case .run: ("light.run", [])
        }
    }

    /// Applies `control` with `values` to `core` and returns the result.
    @discardableResult
    static func apply(_ core: inout Core, _ control: String, _ values: [Double] = []) -> ActionResult {
        core.apply(ExperienceAction(control: control, values: values, step: 0))
    }

    /// Applies an accepted action and returns the plan from before to after.
    static func step(_ core: inout Core, _ control: String, _ values: [Double] = []) throws -> Plan {
        let old: Core = core
        let result: ActionResult = apply(&core, control, values)
        try #require(result == .accepted, "\(control) \(values) was refused: \(result.code)")
        return Plan.after(old: old, new: core)
    }

    @Test func arrangementActionsAnnounceTheChangeThenTheProgress() throws {
        var core: Core = try Self.core(try Self.hand(worlds: [try Self.growing()]))
        let luminosity: Plan = try Self.step(&core, "star.luminosity", [0, 1])
        #expect(luminosity == Plan(text: "Star 1's luminosity set to 16. 1 of 1 worlds keep their light, running now "
                                       + "would win, 2 actions left.",
                                   kind: .state, haptic: .selection, trigger: "star.luminosity"))
        let phase: Plan = try Self.step(&core, "star.phase", [1, 30])
        #expect(phase == Plan(text: "Star 2 shifted to phase 30. 1 of 1 worlds keep their light, running now would "
                                  + "win, 1 action left.",
                              kind: .state, haptic: .selection, trigger: "star.phase"))
        let tilt: Plan = try Self.step(&core, "orbit.tilt", [2])
        #expect(tilt == Plan(text: "Tilt set to 2 of 3 steps. 1 of 1 worlds keep their light, running now would win, "
                                 + "0 actions left.",
                             kind: .state, haptic: .selection, trigger: "orbit.tilt"))
        var ring: Core = try Self.core(try Self.hand(worlds: [Self.world()]))
        let moved: Plan = try Self.step(&ring, "star.ring", [0, 2])
        #expect(moved == Plan(text: "Star 1 moved to ring 3 (12 units). 0 of 1 worlds keep their light, running now "
                                  + "would fail, 2 actions left.",
                              kind: .state, haptic: .selection, trigger: "star.ring"))
    }

    @Test func undoAndRedoAnnounceThemselvesThenTheProgress() throws {
        var core: Core = try Self.core(try Self.hand(worlds: [Self.blooming, Self.world()]))
        _ = try Self.step(&core, "orbit.tilt", [1])
        let undone: Plan = try Self.step(&core, "play.undo")
        #expect(undone == Plan(text: "Undone. 1 of 2 worlds keep their light, running now would fail, 3 actions left.",
                               kind: .state, haptic: .selection, trigger: "play.undo"))
        let redone: Plan = try Self.step(&core, "play.redo")
        #expect(redone == Plan(text: "Redone. 1 of 2 worlds keep their light, running now would fail, 2 actions left.",
                               kind: .state, haptic: .selection, trigger: "play.redo"))
    }

    @Test func everyRefusalCodeHasItsSentenceBareAndPrefixed() {
        let cases: [(String, String)] = [
            ("r02-g21.locked", "That level is not open yet."),
            ("r02-g21.date", "That date cannot be used."),
            ("r02-g21.action", "That ring, phase, brightness or tilt change cannot be made (locked, unchanged, off "
                + "the phase grid or too close to the other star), or there is nothing to undo or redo."),
            ("r02-g21.budget", "No actions are left: run the light or undo a change."),
            ("r02-g21.stage", "The level has ended."),
            ("r02-g21.stale", "The play changed before the action arrived."),
            ("r02-g21.level", "That level could not be made."),
            ("r02-g21.generation", "That level could not be made."),
            ("r02-g21.not-whole", "That value must be a whole number."),
            ("r02-g21.tick", "Only ticks 1 to 48 can be shown."),
            ("r02-g21.newer-schema", "That action was refused."),
            ("r02-g21.malformed", "That action was refused."),
            ("r02-g21.witness", "That action was refused."),
            ("action.out-of-range", "That action was refused."),
            ("", "That action was refused."),
        ]
        for (code, sentence) in cases {
            #expect(Plan.refusalText(code: code) == sentence)
            #expect(Plan.refusalText(code: Plan.rulePrefix + code) == sentence)
            let expected: Plan = Plan(text: sentence, kind: .rejection, haptic: .error, trigger: code)
            #expect(Plan.refused(code: code) == expected)
            #expect(Plan.refused(code: Plan.rulePrefix + code) == expected)
        }
        #expect(Plan.rulePrefix == "action.rule.")
        #expect(BinaryGardensExperienceRule.locked == "r02-g21.locked")
        #expect(BinaryGardensExperienceRule.date == "r02-g21.date")
    }

    @Test func refusalsTheCoreReturnsReadAsTheirBareCode() throws {
        var core: Core = try Self.core(try Self.hand(worlds: [try Self.growing()], budget: 1))
        let cases: [(String, [Double], String)] = [
            ("star.phase", [0, 5], "r02-g21.action"),
            ("play.undo", [], "r02-g21.action"),
            ("clock.show", [0], "r02-g21.tick"),
            ("star.ring", [0, 1.5], "r02-g21.not-whole"),
        ]
        for (control, values, code) in cases {
            let before: Core = core
            let result: ActionResult = Self.apply(&core, control, values)
            #expect(result.code == Plan.rulePrefix + code)
            #expect(Plan.refused(code: result.code).trigger == code)
            #expect(Plan.after(old: before, new: core) == .none)
        }
        _ = try Self.step(&core, "star.luminosity", [0, 1])
        let spent: ActionResult = Self.apply(&core, "orbit.tilt", [2])
        #expect(spent.code == "action.rule.r02-g21.budget")
        #expect(Plan.refused(code: spent.code).text == "No actions are left: run the light or undo a change.")
        _ = try Self.step(&core, "light.run")
        let ended: ActionResult = Self.apply(&core, "play.undo")
        #expect(ended.code == "action.rule.r02-g21.stage")
        #expect(Plan.refused(code: ended.code) == Plan(text: "The level has ended.", kind: .rejection, haptic: .error,
                                                       trigger: "r02-g21.stage"))
    }

    @Test func wonRunsNameActionsAndStarsWhereAwarded() throws {
        let modes: [(BinaryGardensMode, String)] = [
            (.campaign, ", 3 of 3 stars"), (.daily(level: 4), ", 3 of 3 stars"), (.practice, ""),
        ]
        for (mode, stars) in modes {
            var core: Core = try Self.core(try Self.hand(worlds: [try Self.growing()]), mode: mode, certified: 1)
            #expect(core.mode == mode && core.certifiedActionCount == 1)
            _ = try Self.step(&core, "star.luminosity", [0, 1])
            let won: Plan = try Self.step(&core, "light.run")
            #expect(won == Plan(text: "Every world kept its light and bloomed. Level won spending 1 action"
                                    + stars + ".",
                                kind: .outcome, haptic: .success, trigger: "light.run"))
        }
        // Undone actions still count: two tilt changes undone, then the luminosity, spend 3 actions; certified 0 gives
        // 1 star, one tilt change undone gives 2 actions and 2 stars, and a redo spends nothing new.
        let growing: World = try Self.growing()
        let scripts: [([(String, [Double])], String)] = [
            ([("orbit.tilt", [1]), ("play.undo", []), ("orbit.tilt", [2]), ("play.undo", []),
              ("star.luminosity", [0, 1])], "3 actions, 1 of 3 stars"),
            ([("orbit.tilt", [1]), ("play.undo", []), ("star.luminosity", [0, 1])], "2 actions, 2 of 3 stars"),
            ([("star.luminosity", [0, 1]), ("play.undo", []), ("play.redo", [])], "1 action, 3 of 3 stars"),
        ]
        for (index, (script, words)) in scripts.enumerated() {
            var core: Core = try Self.core(try Self.hand(worlds: [growing]), certified: index == 2 ? 1 : 0)
            for (control, values) in script { _ = try Self.step(&core, control, values) }
            let won: Plan = try Self.step(&core, "light.run")
            #expect(won.text == "Every world kept its light and bloomed. Level won spending " + words + ".")
        }
    }

    @Test func failedRunsAnnounceTheExplanationOfEveryKind() throws {
        let integralCore: Core = try Self.core(try Self.hand(worlds: [Self.world()]))
        let integral: String = Level.grouped(integralCore.play.report.worlds[0].integral)
        let cases: [(World, String)] = [
            (Self.world(lethalLow: 199_997, comfortLow: 199_998, comfortHigh: 199_999, bloomLow: 0),
             "World 1 froze at tick 1: its light fell below its lethal floor."),
            (Self.world(comfortHigh: 2, lethalHigh: 3, bloomLow: 0),
             "World 1 scorched at tick 1: its light rose above its lethal ceiling."),
            (Self.world(comfortHigh: 2, window: 5, bloomLow: 0), "World 1 never had comfortable light; 5 were needed."),
            (Self.world(), "World 1 wilted: its light over the cycle totalled " + integral
                + ", below its bloom band 9 600 000 … 9 600 000."),
            (Self.world(bloomLow: 0, bloomHigh: 0), "World 1 bleached: its light over the cycle totalled " + integral
                + ", above its bloom band 0 … 0."),
        ]
        for (world, sentence) in cases {
            var core: Core = try Self.core(try Self.hand(worlds: [world]))
            let failed: Plan = try Self.step(&core, "light.run")
            let expected: String = sentence + " " + Self.advice
            #expect(failed == Plan(text: expected, kind: .outcome, haptic: .warning, trigger: "light.run"))
            #expect(failed.text == BinaryGardensFailureExplanation(play: core.play)?.text)
            #expect(failed.text == core.failureExplanation?.text)
            // An undo out of the failed play is a state; a redo that restores the failure plans only its outcome.
            let undone: Plan = try Self.step(&core, "play.undo")
            #expect(undone == Plan(text: "Undone. 0 of 1 worlds keep their light, running now would fail, 3 actions "
                                       + "left.",
                                   kind: .state, haptic: .selection, trigger: "play.undo"))
            let redone: Plan = try Self.step(&core, "play.redo")
            #expect(redone == Plan(text: expected, kind: .outcome, haptic: .warning, trigger: "play.redo"))
        }
    }

    @Test func levelAndModeChangesAnnounceTheLevel() throws {
        let four: Core = try Self.core(try Self.hand(), number: 4)
        let sixty: Core = try Self.core(try Self.hand(id: "other", seed: 9), number: 60)
        #expect(sixty.band == 3)
        #expect(Plan.after(old: four, new: sixty)
            == Plan(text: "Level 60, band 3, campaign.", kind: .level, haptic: nil, trigger: "level"))
        let fourPractice: Core = try Self.core(try Self.hand(), number: 4, mode: .practice)
        #expect(Plan.after(old: four, new: fourPractice)
            == Plan(text: "Level 4, band 1, practice.", kind: .level, haptic: nil, trigger: "level"))
        let sixtyDaily: Core = try Self.core(try Self.hand(id: "other", seed: 9), number: 60, mode: .daily(level: 60))
        #expect(Plan.after(old: four, new: sixtyDaily).text == "Level 60, band 3, daily.")
        // Back from practice to the campaign on the same level is a mode change too.
        #expect(Plan.after(old: fourPractice, new: four).text == "Level 4, band 1, campaign.")
        let tutorial: BinaryGardensTutorialStep = .adjust
        let firstLevel: Level = try Self.hand(id: "first", seed: 11)
        let one: Core = try Self.core(firstLevel, number: 1)
        let oneTaught: Core = try Self.core(firstLevel, number: 1, tutorial: tutorial)
        #expect(Plan.after(old: four, new: oneTaught)
            == Plan(text: "Level 1, band 1, campaign. " + tutorial.text, kind: .level, haptic: nil, trigger: "level"))
        // The same untouched play reopened with its tutorial shown again announces the level.
        #expect(Plan.after(old: one, new: oneTaught).text == "Level 1, band 1, campaign. " + tutorial.text)
        // A replaced play of the same level (a fresh play after actions) is a level change.
        var played: Core = one
        _ = try Self.step(&played, "orbit.tilt", [1])
        #expect(Plan.after(old: played, new: one) == Plan(text: "Level 1, band 1, campaign.", kind: .level,
                                                          haptic: nil, trigger: "level"))
        // Dismissing the tutorial is not announced, through the adapter or between built cores.
        #expect(Plan.after(old: oneTaught, new: one) == .none)
        var dismissed: Core = oneTaught
        #expect(Self.apply(&dismissed, "tutorial.dismiss") == .accepted)
        #expect(dismissed.tutorial == .done)
        #expect(Plan.after(old: oneTaught, new: dismissed) == .none)
        // A tutorial step advanced by an action is not a level change: the action is announced.
        var taught: Core = oneTaught
        let tilted: Plan = try Self.step(&taught, "orbit.tilt", [1])
        #expect(taught.tutorial == .balance && tilted.kind == .state && tilted.trigger == "orbit.tilt")
        #expect(Plan.modeName(.campaign) == "campaign" && Plan.modeName(.practice) == "practice")
        #expect(Plan.modeName(.daily(level: 7)) == "daily")
        // The core's band is the manifest entry's band for every catalog level.
        for entry in BinaryGardensManifest.entries {
            #expect(BinaryGardensProgress.band(of: entry.number) == entry.band, "level \(entry.number)")
        }
    }

    @Test func showingATickOrNothingPlansNothing() throws {
        var core: Core = try Self.core(try Self.hand())
        let unchanged: Core = core
        #expect(Plan.after(old: unchanged, new: core) == .none)
        for tick in [1, 17, 48] {
            let before: Core = core
            #expect(Self.apply(&core, "clock.show", [Double(tick)]) == .accepted)
            #expect(Plan.after(old: before, new: core) == .none)
        }
        #expect(Plan.none == Plan(text: nil, kind: nil, haptic: nil, trigger: ""))
    }

    @Test func aRevealedHintIsAStateWithoutHaptic() {
        let text: String = "Every world keeps its light: run the cycle"
        #expect(Plan.hint(text: text) == Plan(text: text, kind: .state, haptic: nil, trigger: "hint"))
    }

    @Test func equalInputsGiveEqualPlans() throws {
        let controls: [(String, Int)] = [("star.ring", 2), ("star.phase", 2), ("star.luminosity", 2),
                                         ("orbit.tilt", 1), ("play.undo", 0), ("play.redo", 0), ("clock.show", 1),
                                         ("light.run", 0)]
        var random = SeededRandom(seed: Self.seed)
        var first: Core = try Self.core(try Self.hand(worlds: [Self.blooming, Self.world()], budget: 6), certified: 2)
        var second: Core = first
        var plans: Int = 0
        for _ in 0..<40 {
            let (control, count) = controls[random.int(0...(controls.count - 1))]
            var values: [Double] = []
            if count == 2 { values = [Double(random.int(0...1)), Double(random.int(0...3))] }
            if count == 1 { values = [Double(random.int(0...3))] }
            if control == "clock.show" { values = [Double(random.int(1...48))] }
            let oldFirst: Core = first
            let oldSecond: Core = second
            let resultFirst: ActionResult = Self.apply(&first, control, values)
            let resultSecond: ActionResult = Self.apply(&second, control, values)
            #expect(resultFirst == resultSecond)
            let planFirst: Plan = resultFirst.isAccepted
                ? Plan.after(old: oldFirst, new: first) : Plan.refused(code: resultFirst.code)
            let planSecond: Plan = resultSecond.isAccepted
                ? Plan.after(old: oldSecond, new: second) : Plan.refused(code: resultSecond.code)
            #expect(planFirst == planSecond)
            if planFirst != .none { plans += 1 }
        }
        #expect(plans > 0)
    }

    @Test func keepsLightReadsTheReport() throws {
        let core: Core = try Self.core(try Self.hand(worlds: [Self.blooming, Self.world(),
                                                             Self.world(comfortHigh: 2, window: 5, bloomLow: 0)]))
        let play: Play = core.play
        #expect(Plan.keepsLight(0, play: play))
        #expect(!Plan.keepsLight(1, play: play))   // bloom below its band
        #expect(!Plan.keepsLight(2, play: play))   // no comfortable window
        #expect(!Plan.keepsLight(3, play: play) && !Plan.keepsLight(-1, play: play))
        #expect(Plan.worldsKeepingLight(play) == 1)
    }

    @Test func theSummaryElementReadsActionsProgressSelectionShownTickAndLevel() throws {
        var core: Core = try Self.core(try Self.hand(), number: 4)
        #expect(Self.apply(&core, "clock.show", [17]) == .accepted)
        let play: Play = core.play
        let text: String = Plan.summaryText(core: core, star: 1)
        let progress: String = play.level.progressDescription(report: play.report, arrangement: play.arrangement,
                                                              actionsLeft: 3)
        let world: String = play.level.worldTickDescription(0, tick: 17, report: play.report)
        #expect(progress.hasSuffix("; 3 actions left"))
        let expected: String = "3 actions left. S" + String(progress.dropFirst().dropLast("; 3 actions left".count))
            + ". Selected: star 2 on ring 2, 10 units, phase 24, luminosity 16. Shown: tick 17 of 48: " + world
            + ". Level: level 4, band 1, campaign; rings of 2, 10, 12 units; luminosity levels 4, 16; tilt up to 3 "
            + "steps; phase step 1; 1 world; lethal tolerance 0 ticks; a budget of 3 actions."
        #expect(text == expected)
        #expect(text.hasPrefix("3 actions left. Star 1 on ring 1, 2 units, phase 0, luminosity 4; star 2 on ring 2, "
                               + "10 units, phase 24, luminosity 16; tilt 0 of 3 steps; world 1: "))
        #expect(world.hasPrefix("world 1 at tick 17: "))
        // The star is clamped; the core's mode is named.
        var practice: Core = try Self.core(try Self.hand(), number: 4, mode: .practice)
        #expect(Self.apply(&practice, "clock.show", [17]) == .accepted)
        #expect(Plan.summaryText(core: practice, star: 7).contains(". Selected: star 2 on ring 2,"))
        #expect(Plan.summaryText(core: practice, star: -1).contains("level 4, band 1, practice;"))
        #expect(Plan.summaryText(core: core, star: 0).contains(". Selected: star 1 on ring 1, 2 units, phase 0,"))
    }

    @Test func aCatalogLevelWonByItsCertifiedPlanNamesThreeStars() throws {
        var core: Core = try Core.opening(number: 1)
        let plan: BinaryGardensPlan = try Core.generated(number: 1).plan
        for action in plan.actions {
            let old: Core = core
            let (control, values): (String, [Double]) = Self.input(action)
            try #require(Self.apply(&core, control, values) == .accepted)
            let step: Plan = Plan.after(old: old, new: core)
            #expect(step.kind == .state && step.haptic == .selection && step.trigger == control)
        }
        let old: Core = core
        try #require(Self.apply(&core, "light.run") == .accepted)
        let spent: String = plan.size == 1 ? "1 action" : "\(plan.size) actions"
        #expect(Plan.after(old: old, new: core) == Plan(text: "Every world kept its light and bloomed. Level won "
                                                            + "spending " + spent + ", 3 of 3 stars.",
                                                        kind: .outcome, haptic: .success, trigger: "light.run"))
        // In practice (`mode.practice`: the same level fresh, budget 24) the win names no stars.
        var practice: Core = try Core.opening(number: 1)
        let switched: Core = practice
        try #require(Self.apply(&practice, "mode.practice") == .accepted)
        #expect(practice.mode == .practice)
        #expect(Plan.after(old: switched, new: practice).kind == .level)
        for action in plan.actions {
            let (control, values): (String, [Double]) = Self.input(action)
            try #require(Self.apply(&practice, control, values) == .accepted)
        }
        let beforeRun: Core = practice
        try #require(Self.apply(&practice, "light.run") == .accepted)
        #expect(Plan.after(old: beforeRun, new: practice).text
            == "Every world kept its light and bloomed. Level won spending " + spent + ".")
    }
}
