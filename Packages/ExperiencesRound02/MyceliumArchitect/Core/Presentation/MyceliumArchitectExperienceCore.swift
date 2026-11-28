// MyceliumArchitectExperienceCore — feature 513 (R02-G22-03) T-R02G2203-002 (FR-R02G2203-003, 004, 005, 008, 009;
// SC-R02G2203-002, 004; clarifications Q1, Q4, Q5; research R10–R12; data-model.md; contracts/api.md). The adapter of
// the Mycelium Architect kernel to the shared experience contract. The core holds the level number, the kernel's
// `MyceliumArchitectPlay` and the shown pulse; it never draws and reads no clock. The presenter asks for an immutable
// `MyceliumArchitectSceneSnapshot` at its own presentation time (`snapshot(time:)`, or `snapshotForRendering` at time
// 0), so the veins can pulse while the state and its digest stay put (renderer purity). The snapshot carries the
// kernel's exact growth report of the current arrangement, so no drawn value decides a reach, a weight or the verdict.
// The shown pulse is presentation state of the adapter (`growth.show [pulse]`, research R10): equal to the report's
// pulses run at an opening and after every accepted action, undo, redo, `level.next`, reset and restore; never advanced
// by time and never in the digest, the snapshot payload or `==`. Lives in `Core/Presentation/`, outside the kernel's
// source scans (research R2). Modelled on `BinaryGardensExperienceCore` as recorded at feature 503.
//
// Preparation: the certified level number `seed % 100 + 1` of `MyceliumArchitectManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each R02-G22-02
// witness's `skipped`), the whole catalog (`MyceliumArchitectGenerator.catalog()`, once per process) only if that
// candidate no longer certifies; begun (and its tutorial dismissed) so the play is in stage `playing`.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   cell.nutrient [0…31, 0…31]   column and row, whole numbers (`r02-g22.not-whole` otherwise); places a nutrient
//                                (1 action); a cell off the board, not empty or not a site, or the nutrient limit
//                                reached is the kernel's `r02-g22.action`; no action left is `r02-g22.budget`;
//   cell.blocker [0…31, 0…31]    places a blocker (1 action); refusals as for a nutrient (the blocker limit);
//   cell.clear [0…31, 0…31]      clears a placed nutrient or blocker (1 action); a cell without one is
//                                `r02-g22.action`;
//   root.seed [0…7]              seeds a direction at the root (1 action); a direction already seeded or the seed limit
//                                reached is `r02-g22.action`;
//   root.unseed [0…7]            removes a player seed (1 action); a direction not seeded or a starting seed is
//                                `r02-g22.action`;
//   growth.run                   the run that ends the level (no action spent): `won` when the report wins, else
//                                `failed` with its failure;
//   play.undo, play.redo         the kernel's exact undo and redo (`r02-g22.action` when there is nothing to undo or
//                                redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                   the next certified level with a fresh play (since feature 515 the next open level in
//                                campaign mode, `r02-g22.locked` when none; no wrap from 100 to 1);
//   growth.show [0…128]          shows pulse 0 … the pulses run (presentation only; accepted in every stage); a pulse
//                                above the pulses run is refused `r02-g22.pulse` without touching the kernel.
// The declared ranges are column and row 0 … 31 (`MyceliumArchitectLevel.sides` upper bound − 1), direction 0 … 7 and
// pulse 0 … 128 (`MyceliumArchitectLevel.pulseRange` upper bound), so the engine refuses only values outside them and
// the kernel's and the adapter's own codes stay observable (research R10). Outside stage `playing` the kernel refuses
// an arrangement action and the run with `r02-g22.stage`. Every action is applied with the play's fingerprint as the
// expected one, so `r02-g22.stale` cannot arise. A kernel refusal (`MyceliumArchitectError`) becomes
// `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown pulse included.
//
// Digest ("r02-g22.mycelium-architect.v1" until feature 515, see below): the level number and the play's fingerprint
// (not its record history, so undo restores the earlier digest exactly); never the shown pulse, the quality tier or a
// time. Snapshot schema 1: the JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a
// fresh play of that level (`MyceliumArchitectPlay.replay`), shows the pulses run and throws
// `MyceliumArchitectRestoreRefusal` for a damaged payload, a level number outside 1 … 100 or a trace the kernel refuses
// (a record of a newer schema or of another level's seed among them). An envelope of a newer schema is refused by the
// engine before the core sees it.
//
// Quality (research R12): three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best
// and no budget may rise); `qualityTiers` is their count and the profile's level names are
// `MyceliumArchitectTier.all`'s names (`level-0`, `level-1`, `level-2`). Host tier `t` draws
// `MyceliumArchitectTier.of(t)`. Outcome: `won` or `failed` while the play is in that stage, else nil. Rules use
// integers only.
//
// Feature 514 (R02-G22-04) T-R02G2204-002 (FR-R02G2204-002, 005, 006, 008, 014; SC-R02G2204-003, 006; clarifications
// Q2, Q3, Q5; research R4, R7): the core also holds the presentation state of the gestures and the panel — the tool
// (nutrient by default), the preview (``MyceliumArchitectPreview``, computed by the kernel's change rule and growth),
// the inspected cell and the view orbit — never in the digest, the snapshot payload or `==`, and carried into
// `snapshot(time:)`. ``previewReport(_:)`` gives the kernel's report of a changed arrangement or its refusal without
// changing anything. The tool, the preview, the inspection and the orbit return to their defaults at an opening, at
// `level.next`, at `reset()` and at restore (with the shown pulse at the pulses run, as before); every other accepted
// action but `growth.show` clears the preview (its arrangement is gone), keeping the tool, the inspection and the orbit.
//
// Feature 515 (R02-G22-05) T-R02G2205-004 (FR-R02G2205-001, 003 … 007; SC-R02G2205-003 … 005; clarifications Q1–Q5):
// the core also holds the player's progress (`MyceliumArchitectProgress`: won levels with the least actions spent and
// stars, the open frontier), the mode (campaign, practice with the budget raised to the kernel's maximum 24 on a copy
// of the level, daily) and the tutorial step (`MyceliumArchitectTutorialStep`). No level is ever gated by payment: a
// locked level is one not yet unlocked (FR-R02G2205-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g22.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level ((days from 2026-01-01 × 11) mod 100 + 1), fresh
//                                  (`r02-g22.date` for an impossible date); a daily level still locked in the campaign
//                                  is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 24 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening (the shown pulse and the preview are kept).
// Non-whole values of the new controls are refused `r02-g22.not-whole`. Choosing a level or a mode starts a fresh play:
// the left level's records are dropped, the pulses run shown, the tutorial at its first step, and the tool, the
// preview, the inspection and the orbit at their defaults (as at an opening). `level.next` (above) moves to the next
// open level in campaign mode and is refused with `r02-g22.locked` when there is none (100 no longer wraps to 1). A win
// (the play reaching `won` on an accepted `growth.run` or redo) records
// `progress.record(level:actionsSpent:certified:mode:)` with the actions spent
// (`MyceliumArchitectProgress.actionsSpent`: every accepted nutrient, blocker, clear, seed and unseed record, undone
// ones included) against the certified plan's action count (`certifiedActionCount`): campaign opens the next level,
// daily records the level's best result and stars and opens nothing, practice records nothing. The certified plan
// (`certifiedPlan`: the certified witness's arrangement actions, without the run) feeds the hints (`hint(level:)`) and
// the stars. A fresh opening of level N (prepare, reset) has levels 1 … N open and no won levels. The tutorial starts
// at `MyceliumArchitectTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced
// after every accepted nutrient, blocker, clear, seed, unseed, run, undo and redo by
// `advanced(afterAction:actionsThisOpening:ended:)` (afterAction for an arrangement action, the actions this opening
// counted as for the stars, ended when the play is won or failed — an undo never ends it, a redo only when it restores
// a won or failed moment), never back; `growth.show` never moves it. The shown pulse, the quality tier, the tool, the
// preview, the inspected cell and the orbit stay presentation. Digest "r02-g22.mycelium-architect.v2": level, play
// fingerprint, progress and mode (never the tutorial step or the presentation state). Snapshot schema 2: `{"level",
// "mode", "progress", "records", "tutorial"}` with sorted keys; schema-1 payloads migrate (no won levels, levels 1 …
// the restored level open, campaign mode, the tutorial at its first step — `place` on levels 1 … 3, else `done`); a
// damaged payload (invalid progress — a frontier or a won level outside 1 … 100, stars outside 1 … 3, actions below 1
// —, an unknown mode or tutorial step, a daily mode naming another level) throws `.damaged`, a level outside 1 … 100
// `.levelNumber`, a trace the kernel refuses `.kernel`; an envelope of a newer schema is refused by the engine.
// Modelled on feature 505's `BinaryGardensExperienceCore`.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Mycelium Architect's adapter refusals (feature 513; `locked` and `date` since feature 515).
public enum MyceliumArchitectExperienceRule {
    /// A value that must be a whole number (a column, a row, a direction, a pulse, a level or a date part) and is not.
    public static let notWhole = "r02-g22.not-whole"
    /// A shown pulse above the pulses run within the declared range 0 … 128 (`growth.show`).
    public static let pulse = "r02-g22.pulse"
    /// A level that is not open yet, or no next open level (feature 515). Never a payment gate.
    public static let locked = "r02-g22.locked"
    /// An impossible calendar date (`mode.daily`, feature 515).
    public static let date = "r02-g22.date"
}

/// Why a saved Mycelium Architect state was refused on restore (feature 513). A refused restore changes nothing.
public enum MyceliumArchitectRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 515).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(MyceliumArchitectError)
}

/// The state of Mycelium Architect as an experience (see the file header). Snapshot schema 2.
public struct MyceliumArchitectExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g22.mycelium-architect"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g22.mycelium-architect.v2"
    /// The action ids in declaration order.
    public static let actionIDs = ["cell.nutrient", "cell.blocker", "cell.clear", "root.seed", "root.unseed",
                                   "growth.run", "play.undo", "play.redo", "level.next", "growth.show",
                                   "level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"]
    /// The budget of a practice play: the kernel's maximum (`MyceliumArchitectMode.practiceBudget`, 24).
    public static let practiceBudget: Int = MyceliumArchitectMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a column or a row: 0 … `MyceliumArchitectLevel.sides` upper bound − 1 (0 … 31).
    public static let cellRange: ClosedRange<Int> = 0...(MyceliumArchitectLevel.sides.upperBound - 1)
    /// The declared range of a direction: 0 … 7 (north … north-west).
    public static let directionRange: ClosedRange<Int> = 0...(MyceliumArchitectDirection.allCases.count - 1)
    /// The declared range of a shown pulse: 0 … `MyceliumArchitectLevel.pulseRange` upper bound (0 … 128).
    public static let pulseRange: ClosedRange<Int> = 0...MyceliumArchitectLevel.pulseRange.upperBound
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: MyceliumArchitectPlay
    /// The player's progress (feature 515): in the digest, the snapshot and `==`.
    public private(set) var progress: MyceliumArchitectProgress
    /// The mode (feature 515): in the digest, the snapshot and `==`.
    public private(set) var mode: MyceliumArchitectMode
    /// The tutorial step (feature 515): in the snapshot and `==`, not in the digest.
    public private(set) var tutorial: MyceliumArchitectTutorialStep
    /// The certified plan of the current level: its certified witness's arrangement actions without the closing run
    /// (1, 2, 3, 3 or 4 by band), which the hints follow and the stars count against (feature 515). Derived from the
    /// level number.
    public private(set) var certifiedPlan: [MyceliumArchitectAction]
    /// The shown pulse, 0 … the pulses run; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownPulse: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0
    /// The placement tool (feature 514); presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var tool: MyceliumArchitectTool = .nutrient
    /// The previewed change (feature 514); presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var preview: MyceliumArchitectPreview? = nil
    /// The inspected cell (feature 514); presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var inspectedCell: MyceliumArchitectCell? = nil
    /// The view orbit, clamped (feature 514); presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var orbit: MyceliumArchitectViewOrbit = .authored

    /// What a reset restores (feature 515).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: MyceliumArchitectPlay
        /// The opening progress: levels 1 … the opening level open, none won.
        let progress: MyceliumArchitectProgress
        /// The opening level's initial tutorial step.
        let tutorial: MyceliumArchitectTutorialStep
        /// The opening level's certified plan (arrangement actions, without the run).
        let certifiedPlan: [MyceliumArchitectAction]
    }

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial` and the pulses run shown,
    /// whose reset returns to `opening` of `openingNumber`.
    init(levelNumber: Int, play: MyceliumArchitectPlay, progress: MyceliumArchitectProgress,
         mode: MyceliumArchitectMode, tutorial: MyceliumArchitectTutorialStep,
         certifiedPlan: [MyceliumArchitectAction], openingNumber: Int, opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedPlan = certifiedPlan
        self.shownPulse = play.report.pulsesRun
        self.openingNumber = openingNumber
        self.opening = opening
    }

    // MARK: Teaching and progression (feature 515)

    /// The certified plan's action count of the current level (nutrient, blocker, clear, seed and unseed actions, the
    /// run excluded: 1, 2, 3, 3 or 4 by band), against which a win's stars are counted.
    public var certifiedActionCount: Int { certifiedPlan.count }

    /// The difficulty band (1 … 5) of the current level: 20 levels per band, the certified difficulty bands
    /// (`MyceliumArchitectProgress.band(of:)`).
    public var band: Int { MyceliumArchitectProgress.band(of: levelNumber) }

    /// The hint at `level` (1 … 3) for the current play against the certified plan
    /// (`MyceliumArchitectHints.hint(level:play:certified:)`); nil when the play is won or not playing (a failed play
    /// gives the retry advice). Reads only; it may search up to `MyceliumArchitectHints.workBound` arrangements, so the
    /// presenter runs it off the main actor.
    public func hint(level: Int) -> MyceliumArchitectHint? {
        MyceliumArchitectHints.hint(level: level, play: play, certified: certifiedPlan)
    }

    /// The explanation of the play's failure (`MyceliumArchitectFailureExplanation(play:)`); nil unless it failed.
    public var failureExplanation: MyceliumArchitectFailureExplanation? {
        MyceliumArchitectFailureExplanation(play: play)
    }

    /// The arrangement actions of `generated`'s certified plan: its solution's actions without the closing run.
    public static func arrangementPlan(of generated: MyceliumArchitectGeneratedLevel) -> [MyceliumArchitectAction] {
        var actions: [MyceliumArchitectAction] = []
        for action in generated.solution.actions where action != .run { actions.append(action) }
        return actions
    }

    /// The level number a seed chooses: `seed % 100 + 1`.
    public static func levelNumber(forSeed seed: UInt64) -> Int {
        Int(seed % UInt64(levelNumbers.count)) + 1
    }

    /// The certified level of manifest number `number` (1 … 100).
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func level(number: Int) throws(MyceliumArchitectError) -> MyceliumArchitectLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for.
    private static let generatedCache = Mutex<[Int: MyceliumArchitectGeneratedLevel]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[MyceliumArchitectGeneratedLevel]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/mycelium-architect/levels/NNN.witness.json`, read
    /// 2026-11-27; recomputed with the generator by `MyceliumArchitectExperienceCoreTests`).
    public static let certifiedCandidates: [Int] = [
        0, 1, 2, 0, 38, 4, 1, 0, 1, 12, 0, 5, 5, 0, 99, 1, 2, 0, 1, 4, 9, 12, 2, 0, 39,
        1, 14, 3, 0, 25, 1, 15, 2, 3, 37, 15, 3, 7, 3, 71, 8, 3, 29, 13, 51, 5, 9, 8, 41, 98,
        17, 9, 0, 1, 54, 4, 59, 11, 1, 22, 80, 4, 10, 0, 1, 0, 49, 13, 11, 349, 26, 0, 6, 19, 0,
        1, 6, 7, 7, 72, 22, 8, 1, 8, 116, 65, 17, 12, 50, 3, 16, 40, 43, 4, 111, 39, 38, 52, 9, 146,
    ]

    /// Candidate `index` of `entry` certified as ``MyceliumArchitectGenerator/generate(_:previous:)`` certifies a
    /// candidate (a candidate whose minimal plan, found within the solver's work bound, has the band's plan length and
    /// wins through the play); nil otherwise. The neighbour rule is not checked here: the table names the candidate the
    /// generator kept under it.
    static func certify(_ entry: MyceliumArchitectManifestEntry, index: Int) -> MyceliumArchitectGeneratedLevel? {
        MyceliumArchitectGenerator.candidate(entry, index: index, previous: nil)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(MyceliumArchitectError) -> MyceliumArchitectGeneratedLevel {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: MyceliumArchitectManifestEntry = MyceliumArchitectManifest.entries[number - 1]
        let fresh: MyceliumArchitectGeneratedLevel
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try catalog()[number - 1]
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// The whole certified catalog (the fallback of ``generated(number:)``), generated once per process.
    ///
    /// - Throws: the generator's `.generation(number)`.
    static func catalog() throws(MyceliumArchitectError) -> [MyceliumArchitectGeneratedLevel] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [MyceliumArchitectGeneratedLevel] = try MyceliumArchitectGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: MyceliumArchitectLevel) throws(MyceliumArchitectError)
        -> MyceliumArchitectPlay {
        var play = MyceliumArchitectPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The practice copy of `level` (feature 515): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: MyceliumArchitectLevel) throws(MyceliumArchitectError)
        -> MyceliumArchitectLevel {
        try MyceliumArchitectLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, width: level.width,
                                   height: level.height, root: level.root, terminals: level.terminals,
                                   rocks: level.rocks, toxins: level.toxins, fixedNutrients: level.fixedNutrients,
                                   strength: level.strength, reach: level.reach, curvature: level.curvature,
                                   obstacle: level.obstacle, maxNutrients: level.maxNutrients,
                                   maxBlockers: level.maxBlockers, maxSeeds: level.maxSeeds,
                                   startSeeds: level.startSeeds, pulses: level.pulses,
                                   nutrientBudget: level.nutrientBudget, weightLimit: level.weightLimit,
                                   budget: MyceliumArchitectMode.practice.budget(base: level.budget),
                                   tutorial: level.tutorial, sites: level.sites)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: MyceliumArchitectGeneratedLevel, mode: MyceliumArchitectMode)
        throws(MyceliumArchitectError) -> MyceliumArchitectLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with the pulses run shown; campaign mode, levels 1 … `number` open, none won, the tutorial at
    /// its first step (feature 515).
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(MyceliumArchitectError) -> MyceliumArchitectExperienceCore {
        let certified: MyceliumArchitectGeneratedLevel = try generated(number: number)
        let play: MyceliumArchitectPlay = try freshPlay(of: certified.level)
        var progress: MyceliumArchitectProgress = MyceliumArchitectProgress()
        progress.open(through: number)
        let tutorial: MyceliumArchitectTutorialStep = MyceliumArchitectTutorialStep.initial(level: number)
        let plan: [MyceliumArchitectAction] = arrangementPlan(of: certified)
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedPlan: plan)
        return MyceliumArchitectExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                               tutorial: tutorial, certifiedPlan: plan, openingNumber: number,
                                               opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (the level; the arrangement; the report's network, path weights, consumed
    /// nutrients, weights, terminal pulses and pulses run; the shown pulse, the fit scale, the failure, the stage and
    /// the actions left) with the level number, for drawing at the presenter's presentation time `time` (a non-finite
    /// or negative time becomes 0). Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> MyceliumArchitectSceneSnapshot {
        MyceliumArchitectSceneSnapshot(play: play, shownPulse: shownPulse, levelNumber: levelNumber, time: time)
            .presenting(tool: tool, preview: preview, inspectedCell: inspectedCell, orbit: orbit)
    }

    /// The snapshot the renderer reads at presentation time 0 (``snapshot(time:)``); the presenter supplies its own
    /// time through ``snapshot(time:)``.
    public var snapshotForRendering: MyceliumArchitectSceneSnapshot { snapshot(time: 0) }

    /// The tier the host quality tier draws: `MyceliumArchitectTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: MyceliumArchitectTier { MyceliumArchitectTier.of(qualityTier) }

    // MARK: Presentation state (feature 514)

    /// The kernel's growth report of the arrangement `action` would make, or the refusal the play would give it, in
    /// the play's order (`.stage` outside `playing`, the change rule `MyceliumArchitectPlay.changed`, `.budget` with no
    /// action left), through ``MyceliumArchitectPreview/of(_:level:arrangement:stage:actionsLeft:)`` —
    /// `MyceliumArchitectPlay.changed` and `MyceliumArchitectGrowth.report`, never a second implementation. Reads only:
    /// the state, its digest and the preview do not change.
    public func previewReport(_ action: MyceliumArchitectAction)
        -> Result<MyceliumArchitectReport, MyceliumArchitectError> {
        let previewed: MyceliumArchitectPreview = MyceliumArchitectPreview.of(
            action, level: play.level, arrangement: play.arrangement, stage: play.stage,
            actionsLeft: play.actionsLeft)
        switch previewed.outcome {
        case .accepted(_, let report): return .success(report)
        case .refused(let error): return .failure(error)
        }
    }

    /// Chooses `tool`; the state and its digest do not change.
    public mutating func setTool(_ tool: MyceliumArchitectTool) {
        self.tool = tool
    }

    /// Previews `change` (``MyceliumArchitectPreview/of(_:level:arrangement:stage:actionsLeft:)`` of the play); the
    /// state and its digest do not change.
    public mutating func setPreview(_ change: MyceliumArchitectAction) {
        preview = MyceliumArchitectPreview.of(change, level: play.level, arrangement: play.arrangement,
                                              stage: play.stage, actionsLeft: play.actionsLeft)
    }

    /// Clears the preview; the state and its digest do not change.
    public mutating func clearPreview() {
        preview = nil
    }

    /// Inspects `cell` (nil, or a cell off the board, clears the inspection); the state and its digest do not change.
    public mutating func inspect(_ cell: MyceliumArchitectCell?) {
        if let target = cell, play.level.contains(target) {
            inspectedCell = target
        } else {
            inspectedCell = nil
        }
    }

    /// Sets the view orbit (clamped); the state and its digest do not change.
    public mutating func setOrbit(_ orbit: MyceliumArchitectViewOrbit) {
        self.orbit = orbit.clamped()
    }

    /// Returns to the authored view; the state and its digest do not change.
    public mutating func resetView() {
        orbit = .authored
    }

    /// The tool, the preview, the inspection and the orbit back to their defaults (an opening, `level.next`, reset).
    mutating func resetPresentation() {
        tool = .nutrient
        preview = nil
        inspectedCell = nil
        orbit = .authored
    }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `MyceliumArchitectTier.all`.
    public static var qualityTiers: Int { MyceliumArchitectTier.all.count }

    /// One level per host tier, best first, named as `MyceliumArchitectTier.all` (research R12): the element share is
    /// the spores over the best tier's (1, 0.5, 0), the iteration share the tube sides over the best tier's (1, 0.75,
    /// 0.5), the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: MyceliumArchitectTier = MyceliumArchitectTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<MyceliumArchitectTier.all.count {
            let tier: MyceliumArchitectTier = MyceliumArchitectTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.spores) / Double(best.spores),
                                       iterationShare: Double(tier.tubeSides) / Double(best.tubeSides),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode and the tutorial step (not the shown pulse, the
    /// quality tier, the opening level or the presentation state of feature 514).
    public static func == (lhs: MyceliumArchitectExperienceCore, rhs: MyceliumArchitectExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial
    }

    // MARK: Contract

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``); a payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) }])
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 515): no won levels with levels 1 … the
    /// restored level open, campaign mode, no tutorial key (restore starts the tutorial at its first step: `place` on
    /// the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``MyceliumArchitectRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw MyceliumArchitectRestoreRefusal.damaged
        }
        var progress: MyceliumArchitectProgress = MyceliumArchitectProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(MyceliumArchitectMode.campaign))
        return migrated
    }

    /// The encoder of payloads and digested values: sorted keys, unescaped slashes.
    static func payloadEncoder() -> JSONEncoder {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "cell.nutrient", ranges: [declared(cellRange), declared(cellRange)]),
        ExperienceControl(id: "cell.blocker", ranges: [declared(cellRange), declared(cellRange)]),
        ExperienceControl(id: "cell.clear", ranges: [declared(cellRange), declared(cellRange)]),
        ExperienceControl(id: "root.seed", ranges: [declared(directionRange)]),
        ExperienceControl(id: "root.unseed", ranges: [declared(directionRange)]),
        ExperienceControl(id: "growth.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "growth.show", ranges: [declared(pulseRange)]),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(MyceliumArchitectProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The fifteen controls with their declared ranges (see the file header); `growth.run`, `play.undo`, `play.redo`,
    /// `level.next`, `mode.practice`, `mode.campaign` and `tutorial.dismiss` take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with the pulses run shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> MyceliumArchitectExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(MyceliumArchitectError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Mycelium Architect level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the growth changes only on an action, and the veins pulse with the presenter's
    /// time, not the state (the shown pulse is never advanced by time).
    public mutating func update(step: Int) {}

    /// The kernel action of an arrangement control's or the run's whole values (in the declared ranges); nil for any
    /// other control.
    static func kernelAction(_ control: String, _ values: [Int]) -> MyceliumArchitectAction? {
        switch control {
        case "cell.nutrient": .nutrient(MyceliumArchitectCell(column: values[0], row: values[1]))
        case "cell.blocker": .blocker(MyceliumArchitectCell(column: values[0], row: values[1]))
        case "cell.clear": .clear(MyceliumArchitectCell(column: values[0], row: values[1]))
        case "root.seed": MyceliumArchitectDirection(rawValue: values[0]).map { .seed($0) }
        case "root.unseed": MyceliumArchitectDirection(rawValue: values[0]).map { .unseed($0) }
        case "growth.run": .run
        default: nil
        }
    }

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        var values: [Int] = []
        for value in action.values {
            guard let whole = Self.whole(value) else {
                return .rejected(.rule(code: MyceliumArchitectExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(MyceliumArchitectError) {
            if let kernel = Self.kernelAction(action.control, values) {
                try play.apply(kernel, expecting: play.fingerprint)
                if case .run = kernel {
                    advanceTutorial(afterAction: false)
                    recordIfWon()
                } else {
                    advanceTutorial(afterAction: true)
                }
            } else {
                switch action.control {
                case "play.undo":
                    try play.undo()
                    advanceTutorial(afterAction: false)
                case "play.redo":
                    try play.redo()
                    advanceTutorial(afterAction: false)
                    recordIfWon()
                case "growth.show":
                    // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                    guard values[0] <= play.report.pulsesRun else {
                        return .rejected(.rule(code: MyceliumArchitectExperienceRule.pulse))
                    }
                    shownPulse = values[0]
                    return .accepted
                case "level.next":
                    // The next open level in campaign mode; no wrap from 100 to 1 (feature 515).
                    guard let next = progress.nextOpen(after: levelNumber) else {
                        return .rejected(.rule(code: MyceliumArchitectExperienceRule.locked))
                    }
                    try open(number: next, mode: .campaign)
                case "level.select":
                    guard progress.isOpen(values[0]) else {
                        return .rejected(.rule(code: MyceliumArchitectExperienceRule.locked))
                    }
                    try open(number: values[0], mode: .campaign)
                case "mode.daily":
                    guard let daily = MyceliumArchitectProgress.dailyLevel(year: values[0], month: values[1],
                                                                            day: values[2]) else {
                        return .rejected(.rule(code: MyceliumArchitectExperienceRule.date))
                    }
                    try open(number: daily, mode: .daily(level: daily))
                case "mode.practice":
                    try open(number: levelNumber, mode: .practice)
                case "mode.campaign":
                    try open(number: progress.isOpen(levelNumber) ? levelNumber : progress.frontier, mode: .campaign)
                default:   // tutorial.dismiss: the play, the shown pulse and the preview do not change.
                    tutorial = tutorial.dismissed()
                    return .accepted
                }
            }
        } catch {
            return .rejected(.rule(code: error.reasonCode))
        }
        // Every accepted action but `growth.show` shows the whole growth of the report again, and its preview is gone.
        shownPulse = play.report.pulsesRun
        preview = nil
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Advances the tutorial step after an accepted nutrient, blocker, clear, seed, unseed, run, undo or redo
    /// (`MyceliumArchitectTutorialStep.advanced(afterAction:actionsThisOpening:ended:)`): `afterAction` for an
    /// arrangement action, the actions this opening counted as for the stars (`MyceliumArchitectProgress.actionsSpent`,
    /// undone ones included), ended when the play is won or failed (never after an undo, which always lands on a moment
    /// before the end; after a redo only when it restores a won or failed moment). Never back.
    private mutating func advanceTutorial(afterAction: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterAction: afterAction,
                                     actionsThisOpening: MyceliumArchitectProgress.actionsSpent(play), ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step, the pulses run shown and the presentation state at its defaults (feature 514); the records of
    /// the level left are dropped. Changes nothing when the kernel refuses.
    private mutating func open(number: Int, mode: MyceliumArchitectMode) throws(MyceliumArchitectError) {
        let certified: MyceliumArchitectGeneratedLevel = try Self.generated(number: number)
        let fresh: MyceliumArchitectPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedPlan = Self.arrangementPlan(of: certified)
        tutorial = MyceliumArchitectTutorialStep.initial(level: number)
        shownPulse = play.report.pulsesRun
        resetPresentation()
    }

    /// After an accepted action that won the play: records the actions spent
    /// (`MyceliumArchitectProgress.actionsSpent(_:)`) against the certified plan's action count in the current mode
    /// (campaign opens the next level; daily records the best result and stars and opens nothing; practice records
    /// nothing). A won play is final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        progress.record(level: levelNumber, actionsSpent: MyceliumArchitectProgress.actionsSpent(play),
                        certified: certifiedActionCount, mode: mode)
    }

    /// Back to the opening state the seed chose (levels 1 … the opening level open, none won, campaign mode, the
    /// tutorial at its first step, the pulses run shown) with the presentation state at its defaults (feature 514);
    /// the quality tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedPlan = opening.certifiedPlan
        shownPulse = play.report.pulsesRun
        resetPresentation()
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g22.mycelium-architect.v2", then the level number, the play's fingerprint (actions spent, blockers,
    /// failure, level, nutrients, seeds, stage), the progress and the mode (their sorted JSON); never the tutorial
    /// step, the shown pulse, the presentation state, the quality tier or a time.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // shown pulse (presentation) or the tutorial step.
        builder.add(play.fingerprint)
        let encoder: JSONEncoder = Self.payloadEncoder()
        builder.add(String(decoding: (try? encoder.encode(progress)) ?? Data(), as: UTF8.self))
        builder.add(String(decoding: (try? encoder.encode(mode)) ?? Data(), as: UTF8.self))
    }

    // MARK: Snapshot

    /// The payload's JSON form (schema 2); `tutorial` is absent in a migrated schema-1 payload.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The mode.
        var mode: MyceliumArchitectMode
        /// The progress.
        var progress: MyceliumArchitectProgress
        /// The play's records.
        var records: [MyceliumArchitectRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: MyceliumArchitectTutorialStep?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, tutorial: tutorial))
    }

    /// The core of `payload` (schema 2): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the saved progress, mode and tutorial step (the first step when absent), the pulses run
    /// shown and the presentation state at its defaults; a reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``MyceliumArchitectRestoreRefusal`` for a damaged payload (invalid progress — a frontier or a won
    ///   level outside 1 … 100, stars outside 1 … 3, actions spent below 1 —, an unknown mode or tutorial step, or a
    ///   daily mode naming another level among them), a level number outside 1 … 100 or a level or trace the kernel
    ///   refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> MyceliumArchitectExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw MyceliumArchitectRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw MyceliumArchitectRestoreRefusal.levelNumber(decoded.level)
        }
        guard decoded.progress.isValid, decoded.mode.isValid else { throw MyceliumArchitectRestoreRefusal.damaged }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw MyceliumArchitectRestoreRefusal.damaged
        }
        do throws(MyceliumArchitectError) {
            let certified: MyceliumArchitectGeneratedLevel = try generated(number: decoded.level)
            let play: MyceliumArchitectPlay = try MyceliumArchitectPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: MyceliumArchitectTutorialStep = decoded.tutorial
                ?? MyceliumArchitectTutorialStep.initial(level: decoded.level)
            let openingCore: MyceliumArchitectExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return MyceliumArchitectExperienceCore(levelNumber: decoded.level, play: play, progress: decoded.progress,
                                                   mode: decoded.mode, tutorial: tutorial,
                                                   certifiedPlan: arrangementPlan(of: certified),
                                                   openingNumber: openingCore.openingNumber,
                                                   opening: openingCore.opening)
        } catch {
            throw MyceliumArchitectRestoreRefusal.kernel(error)
        }
    }
}
