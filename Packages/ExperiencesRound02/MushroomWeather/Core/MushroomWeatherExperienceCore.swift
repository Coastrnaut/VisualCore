// MushroomWeatherExperienceCore — feature 493 (R02-G20-03) T-R02G2003-005 (FR-R02G2003-003, 004, 005, 008, 009;
// SC-R02G2003-004; clarifications Q4, Q5; data-model.md; contracts/api.md). The adapter of the Mushroom Weather kernel
// to the shared experience contract. The core holds the level number, the kernel's `MushroomWeatherPlay` and the shown
// cycle; it never draws and reads no clock. The presenter asks for an immutable `MushroomWeatherSceneSnapshot` at its
// own presentation time (`snapshot(time:)`), so the scene can breathe while the state and its digest stay put (renderer
// purity). The snapshot carries the kernel's integer humidity of every cell at every cycle of the predicted run of the
// current arrangement, the cycles run, the colonies with their bands and runs, the pods with their growth cycles, the
// sites, the vents, the moonlight, the failure, the stage and the actions left, so every drawn humidity is a kernel
// humidity and no drawn value decides a cell, a colony or the verdict. The shown cycle is presentation state of the
// adapter (`clock.show [cycle]`): at an opening, after `level.next`, a reset and a restore it is cycle 0; a placement,
// a removal, a vent, the moonlight, the run, undo and redo keep it, clamped to the new cycles run (a run that now fails
// earlier runs fewer cycles); never in the digest, the snapshot payload or `==`. Modelled on
// `MicroscopicAuroraExperienceCore` (feature 483).
//
// Preparation: the certified level number `seed % 100 + 1` of `MushroomWeatherManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole catalog (`MushroomWeatherGenerator.catalog()`, once per process) only if that candidate no
// longer certifies; begun (and its tutorial dismissed, as `MushroomWeatherSolver.replayWins` does) so the play is in
// stage `playing`. The tutorial of the first levels is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   pod.place [0…5, 0…11, 0…13]   slot, row and column, whole numbers (`r02-g20.not-whole` otherwise); puts the slot's
//                                 pod on the cell or moves it there (1 action); a slot the level lacks, a cell off the
//                                 floor, a colony cell, a cell that is not a site, a cell another slot's pod occupies
//                                 or the slot's own cell is the kernel's `r02-g20.action`; no action left is
//                                 `r02-g20.budget`;
//   pod.remove [0…5]              empties the slot (1 action); a slot the level lacks or an empty slot is
//                                 `r02-g20.action`; budget as above;
//   vent.set [0…5, 0…1]           vent index and state (1 open, 0 shut) (1 action); a vent the level lacks or the
//                                 vent's current state is `r02-g20.action`; budget as above;
//   moon.set [0…3]                the moonlight level (1 action); the current level is `r02-g20.action`; budget as
//                                 above;
//   weather.run                   the run that ends the level (no action spent): `won` when the report wins, else
//                                 `failed` with its failure;
//   play.undo, play.redo          the kernel's exact undo and redo (`r02-g20.action` when there is nothing to undo or
//                                 redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                    the next certified level with a fresh play (since feature 495 the next open level;
//                                 see below);
//   clock.show [0…200]            shows the humidity at a cycle (presentation only; accepted in every stage); a cycle
//                                 outside 0 … cycles run of the current report is refused `r02-g20.cycle` without
//                                 touching the kernel.
// The declared ranges are the kernel's (`MushroomWeatherPodRules.slotCounts`, `MushroomWeatherLevel.rowCounts`,
// `.columnCounts`, `.ventCounts`, `.moonlightLevels`) and the longest run any level allows
// (`MushroomWeatherLevel.lengths`: cycles 0 … 200); the kernel or the adapter refuses the values a level lacks.
// Outside stage `playing` the kernel refuses an arrangement action and the run with `r02-g20.stage`. Every action is
// applied with the play's fingerprint as the expected one, so `r02-g20.stale` cannot arise. A kernel refusal
// (`MushroomWeatherError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown cycle
// included.
//
// Digest ("r02-g20.mushroom-weather.v1" until feature 495): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the shown cycle, the quality tier or a time. Snapshot schema 1: the JSON
// object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`MushroomWeatherPlay.replay`), resets the shown cycle and throws `MushroomWeatherRestoreRefusal` for a damaged
// payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another
// level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise); `qualityTiers` is their count and the profile's level names are `MushroomWeatherTier.all`'s names
// (`level-0`, `level-1`, `level-2`). Host tier `t` draws `MushroomWeatherTier.of(t)`: level-0 = lathes of 16 segments,
// 12 droplets per pod, fronds, 8 motes, 2 glow shells; level-1 = 10 segments, 6 droplets, fronds, 4 motes, 1 glow
// shell; level-2 = flat caps and pods, no droplets, fronds, motes or glow. Outcome: `won` or `failed` while the play is
// in that stage, else nil. Rules use integers only.
//
// Feature 495 (R02-G20-05) T-R02G2005-004 (FR-R02G2005-001, 004 … 007; clarifications Q2–Q5): the core also holds the
// player's progress (`MushroomWeatherProgress`: won levels with the least actions spent and stars, the open frontier),
// the mode (campaign, practice with the budget raised to the kernel's maximum 24, daily) and the tutorial step
// (`MushroomWeatherTutorialStep`). No level is ever gated by payment: a locked level is one not yet unlocked
// (FR-R02G2005-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g20.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g20.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 24 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh with cycle 0 shown). `level.next`
// moves to the next open level in campaign mode and is refused with `r02-g20.locked` when there is none (100 does not
// wrap). A win (the play reaching `won` on an accepted `weather.run` or redo) records
// `progress.record(level:actionsSpent:certified:mode:)` with the actions spent (`MushroomWeatherProgress.actionsSpent`:
// every accepted pod, vent and moonlight record, undone ones included) against the certified plan's action count
// (`certifiedActionCount`): campaign opens the next level, daily records the level's best result and stars and opens
// nothing, practice records nothing. The certified plan (`certifiedPlan`) feeds the hints and the stars. The tutorial
// starts at `MushroomWeatherTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced
// after every accepted placement, removal, vent, moonlight, run, undo and redo by
// `advanced(afterAction:placement:ended:)` (afterAction for a placement, a removal, a vent or the moonlight, placement
// for a placement; ended when the play is won or failed — an undo never ends it, a redo only when it restores a won or
// failed moment), never back; `clock.show` never moves it. The shown cycle stays presentation. Digest
// "r02-g20.mushroom-weather.v2": level, play fingerprint, progress and mode (never the tutorial step or the shown
// cycle). Snapshot schema 2: `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys; schema-1 payloads
// migrate (no won levels, level 1 open plus the levels up to the restored level, campaign mode, the tutorial at its
// first step — `place` on the tutorial levels, else `done`); an envelope of a newer schema is refused.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Mushroom Weather's adapter refusals (feature 493; `locked` and `date` since feature 495).
public enum MushroomWeatherExperienceRule {
    /// A value that must be a whole number (a slot, a cell, a vent, a state, a level or a cycle) and is not.
    public static let notWhole = "r02-g20.not-whole"
    /// A shown cycle outside 0 … cycles run of the current report (`clock.show`).
    public static let cycle = "r02-g20.cycle"
    /// A level that is not open yet, or no next open level (feature 495). Never a payment gate.
    public static let locked = "r02-g20.locked"
    /// An impossible calendar date (`mode.daily`, feature 495).
    public static let date = "r02-g20.date"
}

/// Why a saved Mushroom Weather state was refused on restore (feature 493). A refused restore changes nothing.
public enum MushroomWeatherRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 495).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(MushroomWeatherError)
}

/// The state of Mushroom Weather as an experience (see the file header). Snapshot schema 2.
public struct MushroomWeatherExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g20.mushroom-weather"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g20.mushroom-weather.v2"
    /// The action ids in declaration order.
    public static let actionIDs = ["pod.place", "pod.remove", "vent.set", "moon.set", "weather.run", "play.undo",
                                   "play.redo", "level.next", "clock.show", "level.select", "mode.daily",
                                   "mode.practice", "mode.campaign", "tutorial.dismiss"]
    /// The budget of a practice play: the kernel's maximum (`MushroomWeatherMode.practiceBudget`, 24).
    public static let practiceBudget: Int = MushroomWeatherMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a pod slot: 0 … `MushroomWeatherPodRules.slotCounts` upper bound − 1 (0 … 5).
    public static let slotRange: ClosedRange<Int> = 0...(MushroomWeatherPodRules.slotCounts.upperBound - 1)
    /// The declared range of a row: 0 … `MushroomWeatherLevel.rowCounts` upper bound − 1 (0 … 11).
    public static let rowRange: ClosedRange<Int> = 0...(MushroomWeatherLevel.rowCounts.upperBound - 1)
    /// The declared range of a column: 0 … `MushroomWeatherLevel.columnCounts` upper bound − 1 (0 … 13).
    public static let columnRange: ClosedRange<Int> = 0...(MushroomWeatherLevel.columnCounts.upperBound - 1)
    /// The declared range of a vent index: 0 … `MushroomWeatherLevel.ventCounts` upper bound − 1 (0 … 5).
    public static let ventRange: ClosedRange<Int> = 0...(MushroomWeatherLevel.ventCounts.upperBound - 1)
    /// The declared range of a vent state: 0 (shut) … 1 (open).
    public static let openRange: ClosedRange<Int> = 0...1
    /// The declared range of the moonlight: `MushroomWeatherLevel.moonlightLevels` (0 … 3).
    public static let moonRange: ClosedRange<Int> = MushroomWeatherLevel.moonlightLevels
    /// The declared range of a shown cycle: the longest run any level allows (`MushroomWeatherLevel.lengths`,
    /// 0 … 200).
    public static let cycleRange: ClosedRange<Int> = 0...MushroomWeatherLevel.lengths.upperBound
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: MushroomWeatherPlay
    /// The player's progress (feature 495): in the digest and the snapshot.
    public private(set) var progress: MushroomWeatherProgress
    /// The mode (feature 495): in the digest and the snapshot.
    public private(set) var mode: MushroomWeatherMode
    /// The tutorial step (feature 495): in the snapshot and `==`, not in the digest.
    public private(set) var tutorial: MushroomWeatherTutorialStep
    /// The certified plan of the current level (its minimal witness without the run), which the hints follow and the
    /// stars count against. Derived from the level number.
    public private(set) var certifiedPlan: MushroomWeatherPlan
    /// The shown cycle, 0 … cycles run; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownCycle: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// What a reset restores (feature 495).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: MushroomWeatherPlay
        /// The opening progress: level 1 open plus the levels up to the opening level, none won.
        let progress: MushroomWeatherProgress
        /// The opening level's initial tutorial step.
        let tutorial: MushroomWeatherTutorialStep
        /// The opening level's certified plan.
        let certifiedPlan: MushroomWeatherPlan
    }

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial` and cycle 0 shown, whose
    /// reset returns to `opening` of `openingNumber`.
    init(levelNumber: Int, play: MushroomWeatherPlay, progress: MushroomWeatherProgress, mode: MushroomWeatherMode,
         tutorial: MushroomWeatherTutorialStep, certifiedPlan: MushroomWeatherPlan, openingNumber: Int,
         opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedPlan = certifiedPlan
        self.shownCycle = 0
        self.openingNumber = openingNumber
        self.opening = opening
    }

    /// The certified plan's action count of the current level (pods, vents and moonlight, the run excluded), against
    /// which a win's stars are counted (feature 495).
    public var certifiedActionCount: Int { certifiedPlan.size }

    /// The difficulty band (1 … 5) of the current level: 20 levels per band, the certified difficulty bands
    /// (`MushroomWeatherProgress.band(of:)`; feature 495).
    public var band: Int { MushroomWeatherProgress.band(of: levelNumber) }

    /// The level number a seed chooses: `seed % 100 + 1`.
    public static func levelNumber(forSeed seed: UInt64) -> Int {
        Int(seed % UInt64(levelNumbers.count)) + 1
    }

    /// The certified level of manifest number `number` (1 … 100).
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func level(number: Int) throws(MushroomWeatherError) -> MushroomWeatherLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 493).
    private static let generatedCache = Mutex<[Int: MushroomWeatherGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[MushroomWeatherGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/mushroom-weather/levels/NNN.witness.json`, read
    /// 2026-11-26).
    public static let certifiedCandidates: [Int] = [
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1,
        0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 1,
        2, 0, 1, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0,
    ]

    /// Candidate `index` of `entry` certified as ``MushroomWeatherGenerator/generate(_:previous:)`` certifies a
    /// candidate (a candidate the generator accepts whose minimal plan, found within the solver's work bound, has the
    /// band's plan length), and whose plan followed by the run wins through the kernel; nil otherwise. The neighbour
    /// rule is not checked here: the table names the candidate the generator kept under it.
    static func certify(_ entry: MushroomWeatherManifestEntry, index: Int) -> MushroomWeatherGenerated? {
        let length: Int = MushroomWeatherBandProfile.of(band: entry.band).plan
        guard let level = MushroomWeatherGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = MushroomWeatherSolver.plan(level), plan.size == length else { return nil }
        guard MushroomWeatherSolver.replayWins(level, actions: plan.actions) else { return nil }
        return MushroomWeatherGenerated(entry: entry, level: level, plan: plan,
                                        difficulty: MushroomWeatherDifficulty(level: level, plan: plan),
                                        skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(MushroomWeatherError) -> MushroomWeatherGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: MushroomWeatherManifestEntry = MushroomWeatherManifest.entries[number - 1]
        let fresh: MushroomWeatherGenerated
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
    static func catalog() throws(MushroomWeatherError) -> [MushroomWeatherGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [MushroomWeatherGenerated] = try MushroomWeatherGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: MushroomWeatherLevel) throws(MushroomWeatherError) -> MushroomWeatherPlay {
        var play = MushroomWeatherPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The practice copy of `level` (feature 495): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: MushroomWeatherLevel)
        throws(MushroomWeatherError) -> MushroomWeatherLevel {
        try MushroomWeatherLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, rows: level.rows,
                                 columns: level.columns, blocked: level.blocked, humidity: level.humidity,
                                 diffusion: level.diffusion, rates: level.rates, vents: level.vents,
                                 podRules: level.podRules, colonies: level.colonies, moldBound: level.moldBound,
                                 length: level.length, required: level.required, start: level.start,
                                 budget: MushroomWeatherMode.practice.budget(base: level.budget),
                                 tutorial: level.tutorial, sites: level.sites)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: MushroomWeatherGenerated, mode: MushroomWeatherMode)
        throws(MushroomWeatherError) -> MushroomWeatherLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with cycle 0 shown; campaign mode, level 1 open plus the levels up to `number`, none won, the
    /// tutorial at its first step (feature 495).
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(MushroomWeatherError) -> MushroomWeatherExperienceCore {
        let certified: MushroomWeatherGenerated = try generated(number: number)
        let play: MushroomWeatherPlay = try freshPlay(of: certified.level)
        var progress: MushroomWeatherProgress = MushroomWeatherProgress()
        progress.open(through: number)
        let tutorial: MushroomWeatherTutorialStep = MushroomWeatherTutorialStep.initial(level: number)
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial,
                                       certifiedPlan: certified.plan)
        return MushroomWeatherExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                             tutorial: tutorial, certifiedPlan: certified.plan, openingNumber: number,
                                             opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (the humidity of every cell at every cycle of the predicted run of the current
    /// arrangement, the cycles run, the shown cycle, the colonies, pods, growth cycles, sites, vents, moonlight,
    /// failure, stage, actions left and budget) with the level number, for drawing at the presenter's presentation time
    /// `time` (a non-finite or negative time becomes 0). Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> MushroomWeatherSceneSnapshot {
        MushroomWeatherSceneSnapshot(play: play, shownCycle: shownCycle, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `MushroomWeatherTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: MushroomWeatherTier { MushroomWeatherTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `MushroomWeatherTier.all`.
    public static var qualityTiers: Int { MushroomWeatherTier.all.count }

    /// One level per host tier, best first, named as `MushroomWeatherTier.all`: the element share is a pod's droplets
    /// over the best tier's (1, 0.5, 0), the iteration share a lathe's segments over the best tier's (1, 10 / 16, 0),
    /// the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: MushroomWeatherTier = MushroomWeatherTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<MushroomWeatherTier.all.count {
            let tier: MushroomWeatherTier = MushroomWeatherTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.droplets) / Double(best.droplets),
                                       iterationShare: Double(tier.latheSegments) / Double(best.latheSegments),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode and the tutorial step (not the shown cycle, the
    /// quality tier or the opening level).
    public static func == (lhs: MushroomWeatherExperienceCore, rhs: MushroomWeatherExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial
    }

    // MARK: Contract

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``); a payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) }])
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 495): no won levels with level 1 open
    /// plus the levels up to the restored level, campaign mode, no tutorial key (restore starts the tutorial at its
    /// first step: `place` on the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``MushroomWeatherRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw MushroomWeatherRestoreRefusal.damaged
        }
        var progress: MushroomWeatherProgress = MushroomWeatherProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(MushroomWeatherMode.campaign))
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
        ExperienceControl(id: "pod.place", ranges: [declared(slotRange), declared(rowRange), declared(columnRange)]),
        ExperienceControl(id: "pod.remove", ranges: [declared(slotRange)]),
        ExperienceControl(id: "vent.set", ranges: [declared(ventRange), declared(openRange)]),
        ExperienceControl(id: "moon.set", ranges: [declared(moonRange)]),
        ExperienceControl(id: "weather.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "clock.show", ranges: [declared(cycleRange)]),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(MushroomWeatherProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The fourteen controls with their declared ranges (see the file header); `weather.run`, `play.undo`,
    /// `play.redo`, `level.next`, `mode.practice`, `mode.campaign` and `tutorial.dismiss` take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with cycle 0 shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> MushroomWeatherExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(MushroomWeatherError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Mushroom Weather level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the run changes only on an action, and the scene breathes with the presenter's
    /// time, not the state.
    public mutating func update(step: Int) {}

    /// The kernel action of an arrangement control's whole values (in the declared ranges); nil for any other control.
    static func kernelAction(_ control: String, _ values: [Int]) -> MushroomWeatherAction? {
        switch control {
        case "pod.place": .place(slot: values[0], cell: MushroomWeatherCell(row: values[1], column: values[2]))
        case "pod.remove": .remove(slot: values[0])
        case "vent.set": .vent(index: values[0], open: values[1] == 1)
        case "moon.set": .moonlight(level: values[0])
        case "weather.run": .run
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
                return .rejected(.rule(code: MushroomWeatherExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(MushroomWeatherError) {
            if let kernel = Self.kernelAction(action.control, values) {
                try play.apply(kernel, expecting: play.fingerprint)
                if case .run = kernel {
                    advanceTutorial(afterAction: false, placement: false)
                    recordIfWon()
                } else if case .place = kernel {
                    advanceTutorial(afterAction: true, placement: true)
                } else {
                    advanceTutorial(afterAction: true, placement: false)
                }
            } else {
                switch action.control {
                case "play.undo":
                    try play.undo()
                    advanceTutorial(afterAction: false, placement: false)
                case "play.redo":
                    try play.redo()
                    advanceTutorial(afterAction: false, placement: false)
                    recordIfWon()
                case "clock.show":
                    // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                    guard values[0] <= play.report.cycles else {
                        return .rejected(.rule(code: MushroomWeatherExperienceRule.cycle))
                    }
                    shownCycle = values[0]
                    return .accepted
                case "level.next":
                    guard let next = progress.nextOpen(after: levelNumber) else {
                        return .rejected(.rule(code: MushroomWeatherExperienceRule.locked))
                    }
                    try open(number: next, mode: .campaign)
                    return .accepted
                case "level.select":
                    guard progress.isOpen(values[0]) else {
                        return .rejected(.rule(code: MushroomWeatherExperienceRule.locked))
                    }
                    try open(number: values[0], mode: .campaign)
                    return .accepted
                case "mode.daily":
                    guard let daily = MushroomWeatherProgress.dailyLevel(year: values[0], month: values[1],
                                                                         day: values[2]) else {
                        return .rejected(.rule(code: MushroomWeatherExperienceRule.date))
                    }
                    try open(number: daily, mode: .daily(level: daily))
                    return .accepted
                case "mode.practice":
                    try open(number: levelNumber, mode: .practice)
                    return .accepted
                case "mode.campaign":
                    try open(number: progress.isOpen(levelNumber) ? levelNumber : progress.frontier, mode: .campaign)
                    return .accepted
                default:   // tutorial.dismiss
                    tutorial = tutorial.dismissed()
                    return .accepted
                }
            }
        } catch {
            return .rejected(.rule(code: error.reasonCode))
        }
        // The shown cycle stays, clamped to the cycles the current report runs.
        shownCycle = min(shownCycle, play.report.cycles)
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Advances the tutorial step after an accepted placement, removal, vent, moonlight, run, undo or redo
    /// (`MushroomWeatherTutorialStep.advanced(afterAction:placement:ended:)`): `afterAction` for a placement, a removal,
    /// a vent or the moonlight, `placement` for a placement, ended when the play is won or failed (never after an undo,
    /// which always lands on a moment before the end; after a redo only when it restores a won or failed moment). Never
    /// back.
    private mutating func advanceTutorial(afterAction: Bool, placement: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterAction: afterAction, placement: placement, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step and cycle 0 shown; the records of the level left are dropped. Changes nothing when the kernel
    /// refuses.
    private mutating func open(number: Int, mode: MushroomWeatherMode) throws(MushroomWeatherError) {
        let certified: MushroomWeatherGenerated = try Self.generated(number: number)
        let fresh: MushroomWeatherPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedPlan = certified.plan
        tutorial = MushroomWeatherTutorialStep.initial(level: number)
        shownCycle = 0
    }

    /// After an accepted action that won the play: records the actions spent
    /// (`MushroomWeatherProgress.actionsSpent(_:)`) against the certified plan's action count in the current mode
    /// (campaign opens the next level; daily records the best result and stars and opens nothing; practice records
    /// nothing). A won play is final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        progress.record(level: levelNumber, actionsSpent: MushroomWeatherProgress.actionsSpent(play),
                        certified: certifiedActionCount, mode: mode)
    }

    /// Back to the opening state the seed chose (progress included, campaign mode, cycle 0 shown); the quality tier,
    /// which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedPlan = opening.certifiedPlan
        shownCycle = 0
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g20.mushroom-weather.v2", then the level number, the play's fingerprint (actions spent, failure, level,
    /// moonlight, pods, stage, vents), the progress and the mode (their sorted JSON); never the tutorial step or the
    /// shown cycle.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // shown cycle (presentation) or the tutorial step.
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
        var mode: MushroomWeatherMode
        /// The progress.
        var progress: MushroomWeatherProgress
        /// The play's records.
        var records: [MushroomWeatherRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: MushroomWeatherTutorialStep?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, tutorial: tutorial))
    }

    /// The core of `payload` (schema 2): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the saved progress, mode and tutorial step (the first step when absent), with cycle 0
    /// shown; a reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``MushroomWeatherRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or
    ///   tutorial step, or a daily mode naming another level among them), a level number outside 1 … 100 or a level or
    ///   trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> MushroomWeatherExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw MushroomWeatherRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw MushroomWeatherRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw MushroomWeatherRestoreRefusal.damaged
        }
        do throws(MushroomWeatherError) {
            let certified: MushroomWeatherGenerated = try generated(number: decoded.level)
            let play: MushroomWeatherPlay = try MushroomWeatherPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: MushroomWeatherTutorialStep = decoded.tutorial
                ?? MushroomWeatherTutorialStep.initial(level: decoded.level)
            let openingCore: MushroomWeatherExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return MushroomWeatherExperienceCore(levelNumber: decoded.level, play: play, progress: decoded.progress,
                                                 mode: decoded.mode, tutorial: tutorial,
                                                 certifiedPlan: certified.plan,
                                                 openingNumber: openingCore.openingNumber,
                                                 opening: openingCore.opening)
        } catch {
            throw MushroomWeatherRestoreRefusal.kernel(error)
        }
    }
}
