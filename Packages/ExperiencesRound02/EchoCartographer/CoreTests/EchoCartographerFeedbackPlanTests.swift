// EchoCartographerFeedbackPlanTests — feature 406 (R02-G11-06) T-R02G1106-003 (FR-R02G1106-002, 003, 005;
// SC-R02G1106-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `EchoCartographerFeedbackPlan` on
// real certified cores driven through `EchoCartographerExperienceCore.apply`: a pulse, a missed claim, a marker placed
// and removed, undo and redo, then a 3-star campaign win (the winning claim plans only the outcome); a 2-star campaign
// win; a practice win without stars; a located claim that does not win and the real `noop` refusal; every refusal code
// (provoked where the core can produce it, the rest by code, raw and prefixed); a failure by a pulse (only the outcome
// planned; undo after it; a redo that fails again plans only the outcome); a failure by a missed claim that takes less
// than the miss cost; `level.select`, `level.next`, `mode.practice`, `mode.daily`, `mode.campaign` with and without the
// tutorial; the dismissal and an unchanged core (none); a revealed hint; the summary element.
// Seed 2_406 opens level 7 (band 1, no tutorial, frontier 7): chamber 6 by 7, entry (3, 0), one beacon at (1, 4),
// tolerance 1, energy 11, a miss costs 1, certified plan 2 pulses. Seed 2_440 opens level 41 (band 3): chamber 9 by 9,
// entry (6, 6), beacons (4, 1) and (1, 4), tolerance 1, energy 13, a miss costs 2. (0, 0) is a miss on both. The daily
// level of 2026-11-23 is level 55 (band 3). The expected texts are written out here, not built with the plan's helpers.
// Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import EchoCartographerCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct EchoCartographerFeedbackPlanTests {
    typealias Core = EchoCartographerExperienceCore
    typealias Plan = EchoCartographerFeedbackPlan

    /// The seed of these tests: level 2_406 % 100 + 1 = 7.
    static let seed: UInt64 = 2_406

    /// A seed whose level has two beacons: level 41.
    static let twoBeaconSeed: UInt64 = 2_440

    /// Level 7's pulse from its entry in words, capitalised.
    static let entryPulse: String = "Pulse from column 3, row 0; north: edge at 1 cell; east: edge at 3 cells; south: "
        + "wall at 4 cells; west: edge at 4 cells; echo at 6 cells."

    /// Level 7 in words.
    static let level7: String = "chamber 6 by 7; entry at column 3, row 0; 1 beacon; tolerance 1 cell; 11 energy; "
        + "a miss costs 1"

    /// The tutorial's first instruction (feature 405).
    static let pulseStep: String = "Tap a lit floor cell to send a pulse (or use the panel) — the echoes tell how far "
        + "each beacon is along the open floor"

    /// The advice that ends every failure explanation (feature 405).
    static let advice: String = "Undo the last action or retry the level."

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

    /// Applies `control` with `values` to `core`, expects the refusal `code` with the core unchanged and no change
    /// plan, and returns the refusal plan.
    static func refused(_ core: inout Core, _ control: String, _ values: [Double], code: String) -> Plan {
        let old: Core = core
        let result: ActionResult = core.apply(bare(control, values))
        #expect(result == .rejected(.rule(code: code)), "\(control) \(values): \(result)")
        #expect(core == old)
        #expect(Plan.after(old: old, new: core) == Plan.none)
        return Plan.refused(code: code)
    }

    /// A `state` plan with haptic `selection`.
    static func state(_ text: String) -> Plan { Plan(text: text, kind: .state, haptic: .selection) }

    /// A `level` plan without haptic.
    static func level(_ text: String) -> Plan { Plan(text: text, kind: .level, haptic: nil) }

    /// A `rejection` plan with haptic `error`.
    static func rejection(_ text: String) -> Plan { Plan(text: text, kind: .rejection, haptic: .error) }

    /// An `outcome` plan with haptic `success`.
    static func won(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .success) }

    /// An `outcome` plan with haptic `warning`.
    static func failed(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .warning) }

    @Test func pulseMissMarkerUndoRedoAndA3StarWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 7 && core.tutorial == .done)
        #expect(Self.accepted(&core, "cell.pulse", [3, 0])
                == Self.state(Self.entryPulse + " 0 of 1 beacon located, 10 energy left."))
        let action: EchoCartographerAction? = core.play.records.last?.action
        #expect(action == EchoCartographerAction.pulse(3, 0))
        #expect(Self.accepted(&core, "cell.claim", [0, 0])
                == Self.state("No beacon at column 0, row 0; 1 energy spent. 0 of 1 beacon located, 9 energy left."))
        #expect(Self.accepted(&core, "cell.mark", [2, 3])
                == Self.state("Marker placed at column 2, row 3. 0 of 1 beacon located, 9 energy left."))
        #expect(Self.accepted(&core, "cell.mark", [2, 3])
                == Self.state("Marker removed from column 2, row 3. 0 of 1 beacon located, 9 energy left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 0 of 1 beacon located, 9 energy left."))
        #expect(core.play.markers == [EchoCartographerCell(x: 2, y: 3)])
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 0 of 1 beacon located, 9 energy left."))
        #expect(core.play.markers.isEmpty)
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 0 of 1 beacon located, 10 energy left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 0 of 1 beacon located, 9 energy left."))
        // The winning claim plans only the outcome: 1 pulse and 1 miss spent 2, the certified plan is 2 → 3 stars.
        #expect(Self.accepted(&core, "cell.claim", [1, 4])
                == Self.won("Every beacon is located. Level won spending 2 energy, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won play is final: further actions are the real `stage` refusal.
        #expect(Self.refused(&core, "cell.pulse", [3, 0], code: "r02-g11.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g11.stage") == Self.rejection("The level has ended."))
        // level.next after the win opens level 8.
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 8, band 1, campaign."))
    }

    @Test func a2StarCampaignWinAndAPracticeWinWithoutStars() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        for index in 0..<4 {
            let plan: Plan = Self.accepted(&core, "cell.pulse", [3, 0])
            #expect(plan == Self.state(Self.entryPulse + " 0 of 1 beacon located, \(10 - index) energy left."))
        }
        #expect(Self.accepted(&core, "cell.claim", [1, 4])
                == Self.won("Every beacon is located. Level won spending 4 energy, 2 of 3 stars."))
        var practice: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 7, band 1, practice."))
        #expect(Self.accepted(&practice, "cell.pulse", [3, 0])
                == Self.state(Self.entryPulse + " 0 of 1 beacon located, 59 energy left."))
        #expect(Self.accepted(&practice, "cell.claim", [1, 4])
                == Self.won("Every beacon is located. Level won spending 1 energy."))
    }

    @Test func aLocatedClaimThatDoesNotWinAndTheNoopRefusal() async throws {
        var core: Core = try await Core.prepare(seed: Self.twoBeaconSeed)
        #expect(core.levelNumber == 41)
        #expect(Self.accepted(&core, "cell.claim", [4, 1])
                == Self.state("Beacon located at column 4, row 1. 1 of 2 beacons located, 13 energy left."))
        #expect(Self.refused(&core, "cell.claim", [4, 1], code: "r02-g11.noop")
                == Self.rejection("That beacon is already located; claiming it again changes nothing."))
        #expect(Self.accepted(&core, "cell.claim", [0, 0])
                == Self.state("No beacon at column 0, row 0; 2 energy spent. 1 of 2 beacons located, 11 energy left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 of 2 beacons located, 13 energy left."))
        // The undone miss still counts (energy spent includes undone actions): 2 of the certified 4 → 3 stars.
        #expect(Self.accepted(&core, "cell.claim", [1, 4])
                == Self.won("Every beacon is located. Level won spending 2 energy, 3 of 3 stars."))
    }

    @Test func everyRefusalCode() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.refused(&core, "level.select", [100], code: "r02-g11.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g11.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g11.date")
                == Self.rejection("That date cannot be used."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g11.action")
                == Self.rejection("That action is not possible here."))
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g11.action")
                == Self.rejection("That action is not possible here."))
        #expect(Self.refused(&core, "cell.pulse", [5, 6], code: "r02-g11.action")
                == Self.rejection("That action is not possible here."))
        #expect(Self.refused(&core, "cell.pulse", [0.5, 0], code: "r02-g11.not-whole")
                == Self.rejection("That value must be a whole number."))
        // `noop` and `stage` are provoked in the tests above; the other codes cannot arise through the core.
        let codes: [String] = ["r02-g11.locked", "r02-g11.date", "r02-g11.action", "r02-g11.noop", "r02-g11.stage",
                               "r02-g11.not-whole", "r02-g11.stale", "r02-g11.malformed", "action.out-of-range"]
        let texts: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That action is not possible here.",
                               "That beacon is already located; claiming it again changes nothing.",
                               "The level has ended.", "That value must be a whole number.",
                               "That action was refused.", "That action was refused.", "That action was refused."]
        for index in codes.indices {
            #expect(Plan.refusalText(code: codes[index]) == texts[index])
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == texts[index])
            #expect(Plan.refused(code: codes[index]) == Self.rejection(texts[index]))
        }
    }

    @Test func aFailureByAPulsePlansOnlyTheOutcome() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        for index in 0..<10 {
            let plan: Plan = Self.accepted(&core, "cell.pulse", [3, 0])
            #expect(plan == Self.state(Self.entryPulse + " 0 of 1 beacon located, \(10 - index) energy left."))
        }
        let failure: String = "Action 11 (a pulse from column 3, row 0) spent the last energy: 0 of 1 beacons "
            + "located after 11 pulses and 0 missed claims. " + Self.advice
        #expect(Self.accepted(&core, "cell.pulse", [3, 0]) == Self.failed(failure))
        #expect(core.play.stage == .failed)
        #expect(Self.refused(&core, "cell.pulse", [3, 0], code: "r02-g11.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 0 of 1 beacon located, 1 energy left."))
        #expect(Self.accepted(&core, "play.redo") == Self.failed(failure))
    }

    @Test func aFailureByAMissedClaimTakesWhatWasLeft() async throws {
        var core: Core = try await Core.prepare(seed: Self.twoBeaconSeed)
        #expect(Self.accepted(&core, "cell.claim", [0, 0])
                == Self.state("No beacon at column 0, row 0; 2 energy spent. 0 of 2 beacons located, 11 energy left."))
        for _ in 0..<10 {
            let plan: Plan = Self.accepted(&core, "cell.pulse", [6, 6])
            #expect(plan.kind == .state && plan.haptic == .selection)
        }
        #expect(core.play.energy == 1)
        // The miss costs 2 but takes the 1 left; it ends the play, so only the outcome is planned.
        let failure: String = "Action 12 (a missed claim at column 0, row 0) spent the last energy: 0 of 2 beacons "
            + "located after 10 pulses and 2 missed claims. " + Self.advice
        #expect(Self.accepted(&core, "cell.claim", [0, 0]) == Self.failed(failure))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 0 of 2 beacons located, 1 energy left."))
    }

    @Test func levelAndModeChanges() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        // The same untouched level reopened without a tutorial changes nothing visible.
        #expect(Self.accepted(&core, "level.select", [7]) == Plan.none)
        // A played level reopened drops its records: a level plan.
        _ = Self.accepted(&core, "cell.pulse", [3, 0])
        #expect(Self.accepted(&core, "level.select", [7]) == Self.level("Level 7, band 1, campaign."))
        #expect(Self.accepted(&core, "level.select", [1])
                == Self.level("Level 1, band 1, campaign. " + Self.pulseStep))
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(core.tutorial == .done)
        // The untouched level reopened shows its tutorial again.
        #expect(Self.accepted(&core, "level.select", [1])
                == Self.level("Level 1, band 1, campaign. " + Self.pulseStep))
        #expect(Self.accepted(&core, "mode.practice")
                == Self.level("Level 1, band 1, practice. " + Self.pulseStep))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 23]) == Self.level("Level 55, band 3, daily."))
        // Level 55 is not open in the campaign: mode.campaign goes to the frontier.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 7, band 1, campaign."))
        // Dismissing an ended tutorial changes nothing.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
    }

    @Test func anUnchangedCoreAHintAndTheSummary() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        // Cursor moves are presentation only: the core does not change, so nothing is planned.
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Plan.hint(text: "Pulse from a cell nearer the beacon.")
                == Plan(text: "Pulse from a cell nearer the beacon.", kind: .state, haptic: nil))
        let entry: EchoCartographerCell = EchoCartographerCell(x: 3, y: 0)
        #expect(Plan.summaryText(core: core, cursor: entry) == "11 energy left. 0 of 1 beacon located. Last echo: "
                + "none. Chosen cell: column 3, row 0: open. Level: " + Self.level7 + ".")
        _ = Self.accepted(&core, "cell.pulse", [3, 0])
        let far: EchoCartographerCell = EchoCartographerCell(x: 5, y: 6)
        #expect(Plan.summaryText(core: core, cursor: far) == "10 energy left. 0 of 1 beacon located. Last echo: "
                + "pulse from column 3, row 0; north: edge at 1 cell; east: edge at 3 cells; south: wall at 4 cells; "
                + "west: edge at 4 cells; echo at 6 cells. Chosen cell: column 5, row 6: unknown. Level: "
                + Self.level7 + ".")
        let two: Core = try await Core.prepare(seed: Self.twoBeaconSeed)
        let text: String = Plan.summaryText(core: two, cursor: EchoCartographerCell(x: 6, y: 6))
        #expect(text.hasPrefix("13 energy left. 0 of 2 beacons located. Last echo: none. Chosen cell: column 6, "
                               + "row 6: open. Level: chamber 9 by 9;"))
    }
}
