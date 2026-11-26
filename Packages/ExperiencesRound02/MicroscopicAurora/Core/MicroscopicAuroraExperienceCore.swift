// MicroscopicAuroraExperienceCore — feature 483 (R02-G19-03) T-R02G1903-005 (FR-R02G1903-005, 008, 009;
// SC-R02G1903-004; clarifications Q4, Q5; data-model.md; contracts/api.md). The adapter of the Microscopic Aurora
// kernel to the shared experience contract. The core holds the level number, the kernel's `MicroscopicAuroraPlay` and
// the shown tick; it never draws and reads no clock. The presenter asks for an immutable
// `MicroscopicAuroraSceneSnapshot` at its own presentation time (`snapshot(time:)`), so the scene can shimmer while the
// state and its digest stay put (renderer purity). The snapshot carries the kernel's swimmer positions and velocities
// at every tick of the predicted swim of the current wells, the ticks swum, the trail density and lit cells, the
// stencil, the sites, the wells, the coverage and coherence with their requirements, the failure, the stage and the
// actions left, so every drawn swimmer stands at a kernel position and no drawn value decides a cell, a group or the
// verdict. The shown tick is presentation state of the adapter (`clock.show [tick]`): at an opening, after
// `level.next`, a reset and a restore it is tick 0; a placement, a removal, the play, undo and redo keep it, clamped to
// the new ticks swum (a swim that now fails earlier swims fewer ticks); never in the digest, the snapshot payload or
// `==`. Modelled on `ApsidesWorkshopExperienceCore` (feature 473).
//
// Preparation: the certified level number `seed % 100 + 1` of `MicroscopicAuroraManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole catalog (`MicroscopicAuroraGenerator.catalog()`, once per process) only if that candidate no
// longer certifies; begun (and its tutorial dismissed, as `MicroscopicAuroraSolver.replayWins` does) so the play is in
// stage `playing`. The tutorial of levels 1 … 3 is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   well.place [0…2, 0…23, 0…23, 1…4, 0…1]  slot, row, column, strength and sense (0 clockwise, 1 counterclockwise),
//                                 whole numbers (`r02-g19.not-whole` otherwise); one placement (1 action); a cell off
//                                 the enclosure or not a site, a cell another slot's well occupies or a placement equal
//                                 to the slot's well is the kernel's `r02-g19.action`; no action left is
//                                 `r02-g19.budget`;
//   well.remove [0…2]             empties the slot (1 action); an empty slot is `r02-g19.action`; budget as above;
//   swim.play                     the play that ends the level (no action spent): `won` when the report wins, else
//                                 `failed` with its failure;
//   play.undo, play.redo          the kernel's exact undo and redo (`r02-g19.action` when there is nothing to undo or
//                                 redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                    the next certified level with a fresh play (since feature 485 the next open level;
//                                 see below);
//   clock.show [0…480]            shows the swimmers at a tick (presentation only; accepted in every stage); a tick
//                                 outside 0 … ticks swum of the current report is refused `r02-g19.tick` without
//                                 touching the kernel.
// The declared ranges are the kernel's (`MicroscopicAuroraLevel.slots`, `MicroscopicAuroraDish.cells`,
// `MicroscopicAuroraWell.strengths`, the two senses) and the longest swim any level allows
// (`MicroscopicAuroraLevel.lengths`: ticks 0 … 480); the kernel or the adapter refuses the values a level lacks.
// Outside stage `playing` the kernel refuses a placement, a removal and the play with `r02-g19.stage`. Every action is
// applied with the play's fingerprint as the expected one, so `r02-g19.stale` cannot arise. A kernel refusal
// (`MicroscopicAuroraError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown tick
// included.
//
// Digest ("r02-g19.microscopic-aurora.v1" until feature 485): the level number and the play's fingerprint (not its record history, so
// undo restores the earlier digest exactly); never the shown tick, the quality tier or a time. Snapshot schema 1: the
// JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`MicroscopicAuroraPlay.replay`), resets the shown tick and throws `MicroscopicAuroraRestoreRefusal` for a damaged
// payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another
// level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `MicroscopicAuroraTier.of(t)`: level-0 = capsules of 12 segments, ribbons of 64 ticks,
// fronds, 2 glow shells; level-1 = 8 segments, 32 ticks, fronds, 1 glow shell; level-2 = flat capsules, 16 ticks, no
// fronds, no glow. Outcome: `won` or `failed` while the play is in that stage, else nil. Rules use integers only.
//
// Feature 485 (R02-G19-05) T-R02G1905-004 (FR-R02G1905-001, 004 … 007; clarifications Q2–Q5): the core also holds the
// player's progress (`MicroscopicAuroraProgress`: won levels with the least actions spent and stars, the open
// frontier), the mode (campaign, practice with the budget raised to the kernel's maximum 24, daily) and the tutorial
// step (`MicroscopicAuroraTutorialStep`). No level is ever gated by payment: a locked level is one not yet unlocked
// (FR-R02G1905-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g19.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g19.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 24 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh with tick 0 shown). `level.next`
// moves to the next open level in campaign mode and is refused with `r02-g19.locked` when there is none (100 does not
// wrap). A win (the play reaching `won` on an accepted `swim.play` or redo) records
// `progress.record(level:actionsSpent:certified:mode:)` with the actions spent (`MicroscopicAuroraProgress.actionsSpent`:
// every accepted placement and removal record, undone ones included) against the certified plan's placement count
// (`certifiedPlacements`): campaign opens the next level, daily records the level's best result and stars and opens
// nothing, practice records nothing. The certified wells (`certifiedWells`) feed the hints. The tutorial starts at
// `MicroscopicAuroraTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced after
// every accepted placement, removal, play, undo and redo by `advanced(afterAction:placement:ended:)` (afterAction for a
// placement or removal, placement for a placement; ended when the play is won or failed — an undo never ends it, a redo
// only when it restores a won or failed moment), never back; `clock.show` never moves it. The shown tick stays
// presentation. Digest "r02-g19.microscopic-aurora.v2": level, play fingerprint, progress and mode (never the tutorial
// step or the shown tick). Snapshot schema 2: `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys;
// schema-1 payloads migrate (no won levels, level 1 open plus the levels up to the restored level, campaign mode, the
// tutorial at its first step — `place` on the tutorial levels, else `done`); an envelope of a newer schema is refused.
//
// Feature 487 (R02-G19-07) T-R02G1907-003 (FR-R02G1907-001 … 007; clarifications Q1–Q5): a campaign or daily win
// records its winning trace (`MicroscopicAuroraReconciliation.netTrace` of the play's records: the effective placements
// and removals, an undone action left out unless redone, then the play) as a verified result; restore reconciles every
// result (`MicroscopicAuroraReconciliation.reconcile`, the frontier as saved) and exposes `reconciliationDropped` (not
// digested, not in `==`); the replay mode `replay(level)` plays a verified trace action by action:
//   replay.start [1…100]  a fresh play of that level in mode `replay(level)` (campaign budget) with the tutorial done
//                         (`r02-g19.no-replay` without a verified result with a trace); during a replay it restarts it;
//   replay.step           the next action of the trace, a placement or removal or finally the play
//                         (`r02-g19.replay-end` after the last or once the play ended; `r02-g19.no-replay` outside
//                         replay);
//   replay.stop           campaign at that level, the frontier when it is not open (`r02-g19.no-replay` outside
//                         replay);
//   settings.sound [0…1]  the sound choice: 1 on, 0 off; whole; allowed in every mode.
// In replay every other action except `tutorial.dismiss` and `clock.show` (presentation) and `settings.sound` is
// refused with `r02-g19.replay`, and nothing is recorded. A restored replay whose placement, removal and play records
// are not exactly the first actions of its level's verified trace (in order, no undo or redo) is refused as `damaged`;
// a restored replay whose result did not survive reconciliation, or was never verified, returns to campaign at that
// level (the frontier when it is not open). Digest "r02-g19.microscopic-aurora.v3" (the same parts as v2, the progress
// now with traces; never the sound choice or the dropped count); snapshot schema 3 `{"level", "mode", "progress",
// "records", "sound", "tutorial"}` (results carry `trace` and `verified`), migrating 1 → 2 → 3 (2 → 3: every result an
// empty trace and `verified` false, sound off).
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Microscopic Aurora's adapter refusals (feature 483; `locked` and `date` since feature 485).
public enum MicroscopicAuroraExperienceRule {
    /// A value that must be a whole number (a slot, a cell, a strength, a sense or a tick) and is not.
    public static let notWhole = "r02-g19.not-whole"
    /// A shown tick outside 0 … ticks swum of the current report (`clock.show`).
    public static let tick = "r02-g19.tick"
    /// A level that is not open yet, or no next open level (feature 485). Never a payment gate.
    public static let locked = "r02-g19.locked"
    /// An impossible calendar date (`mode.daily`, feature 485).
    public static let date = "r02-g19.date"
    /// No verified result with a trace to replay, or a replay control outside replay (feature 487).
    public static let noReplay = "r02-g19.no-replay"
    /// The replay has no further action: the trace is over or the play ended (feature 487).
    public static let replayEnd = "r02-g19.replay-end"
    /// An action that is not allowed during replay (feature 487).
    public static let replay = "r02-g19.replay"
}

/// Why a saved Microscopic Aurora state was refused on restore (feature 483). A refused restore changes nothing.
public enum MicroscopicAuroraRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 485).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(MicroscopicAuroraError)
}

/// The state of Microscopic Aurora as an experience (see the file header). Snapshot schema 3.
public struct MicroscopicAuroraExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g19.microscopic-aurora"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 3
    /// The digest's domain string (schema 3).
    public static let digestDomain = "r02-g19.microscopic-aurora.v3"
    /// The action ids in declaration order.
    public static let actionIDs = ["well.place", "well.remove", "swim.play", "play.undo", "play.redo", "level.next",
                                   "clock.show", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                                   "tutorial.dismiss", "replay.start", "replay.step", "replay.stop", "settings.sound"]
    /// The declared range of `settings.sound`: 0 off, 1 on (feature 487).
    public static let soundRange: ClosedRange<Int> = 0...1
    /// The budget of a practice play: the kernel's maximum (`MicroscopicAuroraMode.practiceBudget`, 24).
    public static let practiceBudget: Int = MicroscopicAuroraMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a slot: 0 … `MicroscopicAuroraLevel.slots` − 1.
    public static let slotRange: ClosedRange<Int> = 0...(MicroscopicAuroraLevel.slots - 1)
    /// The declared range of a row or a column: 0 … `MicroscopicAuroraDish.cells` − 1.
    public static let cellRange: ClosedRange<Int> = 0...(MicroscopicAuroraDish.cells - 1)
    /// The declared range of a sense: 0 (clockwise) … 1 (counterclockwise).
    public static let senseRange: ClosedRange<Int> = 0...1
    /// The declared range of a shown tick: the longest swim any level allows (`MicroscopicAuroraLevel.lengths`,
    /// 0 … 480).
    public static let tickRange: ClosedRange<Int> = 0...MicroscopicAuroraLevel.lengths.upperBound
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: MicroscopicAuroraPlay
    /// The player's progress (feature 485): in the digest and the snapshot.
    public private(set) var progress: MicroscopicAuroraProgress
    /// The mode (feature 485): in the digest and the snapshot.
    public private(set) var mode: MicroscopicAuroraMode
    /// The tutorial step (feature 485): in the snapshot and `==`, not in the digest.
    public private(set) var tutorial: MicroscopicAuroraTutorialStep
    /// The certified plan's wells of the current level (its placements in slot order), which the hints try first.
    /// Derived from the level number.
    public private(set) var certifiedWells: [MicroscopicAuroraWell]
    /// The shown tick, 0 … ticks swum; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownTick: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0
    /// How many saved results the last restore dropped because they did not verify (feature 487); not in the digest,
    /// the snapshot or `==`.
    public private(set) var reconciliationDropped = 0
    /// The player's sound choice (feature 487), set by `settings.sound`: in the snapshot (key `"sound"`) and `==`,
    /// never in the digest; off at an opening, after a reset and in a migrated save.
    public private(set) var soundOn = false

    /// What a reset restores (feature 485).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: MicroscopicAuroraPlay
        /// The opening progress: level 1 open plus the levels up to the opening level, none won.
        let progress: MicroscopicAuroraProgress
        /// The opening level's initial tutorial step.
        let tutorial: MicroscopicAuroraTutorialStep
        /// The opening level's certified wells.
        let certifiedWells: [MicroscopicAuroraWell]
    }

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial` and tick 0 shown, whose
    /// reset returns to `opening` of `openingNumber`.
    init(levelNumber: Int, play: MicroscopicAuroraPlay, progress: MicroscopicAuroraProgress, mode: MicroscopicAuroraMode,
         tutorial: MicroscopicAuroraTutorialStep, certifiedWells: [MicroscopicAuroraWell], openingNumber: Int,
         opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedWells = certifiedWells
        self.shownTick = 0
        self.openingNumber = openingNumber
        self.opening = opening
    }

    /// The certified plan's placement count of the current level, against which a win's stars are counted.
    public var certifiedPlacements: Int { certifiedWells.count }

    /// The difficulty band (1 … 5) of the current level: 20 levels per band, the certified difficulty bands
    /// (`MicroscopicAuroraProgress.band(of:)`; feature 485).
    public var band: Int { MicroscopicAuroraProgress.band(of: levelNumber) }

    /// The level number a seed chooses: `seed % 100 + 1`.
    public static func levelNumber(forSeed seed: UInt64) -> Int {
        Int(seed % UInt64(levelNumbers.count)) + 1
    }

    /// The certified level of manifest number `number` (1 … 100).
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func level(number: Int) throws(MicroscopicAuroraError) -> MicroscopicAuroraLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 483).
    private static let generatedCache = Mutex<[Int: MicroscopicAuroraGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[MicroscopicAuroraGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/microscopic-aurora/levels/NNN.witness.json`, read
    /// 2026-11-26).
    public static let certifiedCandidates: [Int] = [
        0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 2, 1, 0, 3, 1, 1,
        0, 2, 0, 0, 0, 2, 0, 1, 0, 0, 0, 0, 0, 2, 2, 1, 3, 2, 0, 2, 0, 0, 2, 0, 7,
        2, 2, 8, 3, 1, 2, 5, 3, 0, 2, 4, 0, 3, 2, 9, 6, 2, 3, 1, 9, 3, 0, 4, 2, 11,
        1, 1, 0, 1, 1, 1, 6, 5, 7, 0, 6, 0, 4, 0, 0, 2, 3, 1, 3, 6, 1, 0, 3, 5, 5,
    ]

    /// Candidate `index` of `entry` certified as ``MicroscopicAuroraGenerator/generate(_:previous:)`` certifies a
    /// candidate (a candidate the kernel accepts whose minimal plan, found within the solver's work bound, has the
    /// band's plan length), and whose plan followed by the play wins through the kernel; nil otherwise. The neighbour
    /// rule is not checked here: the table names the candidate the generator kept under it.
    static func certify(_ entry: MicroscopicAuroraManifestEntry, index: Int) -> MicroscopicAuroraGenerated? {
        let length: Int = MicroscopicAuroraBandProfile.of(band: entry.band).plan
        guard let level = MicroscopicAuroraGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = MicroscopicAuroraSolver.plan(level), plan.size == length else { return nil }
        guard MicroscopicAuroraSolver.replayWins(level, actions: plan.actions) else { return nil }
        return MicroscopicAuroraGenerated(entry: entry, level: level, plan: plan,
                                          difficulty: MicroscopicAuroraDifficulty(level: level, plan: plan),
                                          skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(MicroscopicAuroraError) -> MicroscopicAuroraGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifest.entries[number - 1]
        let fresh: MicroscopicAuroraGenerated
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
    static func catalog() throws(MicroscopicAuroraError) -> [MicroscopicAuroraGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [MicroscopicAuroraGenerated] = try MicroscopicAuroraGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: MicroscopicAuroraLevel) throws(MicroscopicAuroraError)
        -> MicroscopicAuroraPlay {
        var play = MicroscopicAuroraPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The practice copy of `level` (feature 485): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: MicroscopicAuroraLevel)
        throws(MicroscopicAuroraError) -> MicroscopicAuroraLevel {
        try MicroscopicAuroraLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, radius: level.radius,
                                   length: level.length, rules: level.rules, swimmers: level.swimmers,
                                   stencil: level.stencil, threshold: level.threshold, coverage: level.coverage,
                                   coherence: level.coherence, wells: level.wells,
                                   budget: MicroscopicAuroraMode.practice.budget(base: level.budget),
                                   tutorial: level.tutorial, sites: level.sites)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: MicroscopicAuroraGenerated, mode: MicroscopicAuroraMode)
        throws(MicroscopicAuroraError) -> MicroscopicAuroraLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with tick 0 shown; campaign mode, level 1 open plus the levels up to `number`, none won, the
    /// tutorial at its first step (feature 485).
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(MicroscopicAuroraError) -> MicroscopicAuroraExperienceCore {
        let certified: MicroscopicAuroraGenerated = try generated(number: number)
        let play: MicroscopicAuroraPlay = try freshPlay(of: certified.level)
        var progress: MicroscopicAuroraProgress = MicroscopicAuroraProgress()
        progress.open(through: number)
        let tutorial: MicroscopicAuroraTutorialStep = MicroscopicAuroraTutorialStep.initial(level: number)
        let wells: [MicroscopicAuroraWell] = certified.plan.wells
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedWells: wells)
        return MicroscopicAuroraExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                               tutorial: tutorial, certifiedWells: wells, openingNumber: number,
                                               opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (the swimmers' positions and velocities at every tick of the predicted swim, the
    /// ticks swum, the shown tick, density, lit and stray cells, stencil, sites, wells, coverage and coherence with
    /// their requirements, failure, stage, actions left and budget) with the level number, for drawing at the
    /// presenter's presentation time `time` (a non-finite or negative time becomes 0). Reads only; the state and its
    /// digest do not change.
    public func snapshot(time: Double) -> MicroscopicAuroraSceneSnapshot {
        MicroscopicAuroraSceneSnapshot(play: play, shownTick: shownTick, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `MicroscopicAuroraTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: MicroscopicAuroraTier { MicroscopicAuroraTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `MicroscopicAuroraTier.all`.
    public static var qualityTiers: Int { MicroscopicAuroraTier.all.count }

    /// One level per host tier, best first, named as `MicroscopicAuroraTier.all`: the element share is a ribbon's ticks
    /// over the best tier's (1, 0.5, 0.25), the iteration share a capsule's segments over the best tier's (1, 8 / 12,
    /// 0), the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: MicroscopicAuroraTier = MicroscopicAuroraTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<MicroscopicAuroraTier.all.count {
            let tier: MicroscopicAuroraTier = MicroscopicAuroraTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.ribbonTicks) / Double(best.ribbonTicks),
                                       iterationShare: Double(tier.capsuleSegments) / Double(best.capsuleSegments),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode, the tutorial step and the sound choice (not
    /// the shown tick, the quality tier, the dropped count or the opening level).
    public static func == (lhs: MicroscopicAuroraExperienceCore, rhs: MicroscopicAuroraExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial && lhs.soundOn == rhs.soundOn
    }

    // MARK: Contract

    /// Schema 3 with the steps 1 → 2 (``migratedToSchemaTwo(_:)``) and 2 → 3 (``migratedToSchemaThree(_:)``); a
    /// payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) },
                                                             2: { payload in try migratedToSchemaThree(payload) }])
    }

    /// The schema-3 object of a schema-2 object (feature 487): every won result gains an empty `trace` and `verified`
    /// false, and the sound choice is off.
    ///
    /// - Throws: ``MicroscopicAuroraRestoreRefusal/damaged`` when `object` has no progress with a solved list.
    public static func migratedToSchemaThree(_ object: [String: Any]) throws -> [String: Any] {
        guard var progress = object["progress"] as? [String: Any], let solved = progress["solved"] as? [Any] else {
            throw MicroscopicAuroraRestoreRefusal.damaged
        }
        var entries: [Any] = []
        for entry in solved {
            guard var result = entry as? [String: Any] else {
                entries.append(entry)
                continue
            }
            result["trace"] = [Any]()
            result["verified"] = false
            entries.append(result)
        }
        progress["solved"] = entries
        var migrated: [String: Any] = object
        migrated["progress"] = progress
        migrated["sound"] = false
        return migrated
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 485): no won levels with level 1 open
    /// plus the levels up to the restored level, campaign mode, no tutorial key (restore starts the tutorial at its
    /// first step: `place` on the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``MicroscopicAuroraRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw MicroscopicAuroraRestoreRefusal.damaged
        }
        var progress: MicroscopicAuroraProgress = MicroscopicAuroraProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(MicroscopicAuroraMode.campaign))
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
        ExperienceControl(id: "well.place",
                          ranges: [declared(slotRange), declared(cellRange), declared(cellRange),
                                   declared(MicroscopicAuroraWell.strengths), declared(senseRange)]),
        ExperienceControl(id: "well.remove", ranges: [declared(slotRange)]),
        ExperienceControl(id: "swim.play"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "clock.show", ranges: [declared(tickRange)]),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(MicroscopicAuroraProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
        ExperienceControl(id: "replay.start", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "replay.step"),
        ExperienceControl(id: "replay.stop"),
        ExperienceControl(id: "settings.sound", ranges: [declared(soundRange)]),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The sixteen controls with their declared ranges (see the file header); `swim.play`, `play.undo`, `play.redo`,
    /// `level.next`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`, `replay.step` and `replay.stop` take no
    /// values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with tick 0 shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> MicroscopicAuroraExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(MicroscopicAuroraError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Microscopic Aurora level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the swim changes only on an action, and the scene shimmers with the presenter's
    /// time, not the state.
    public mutating func update(step: Int) {}

    /// The kernel well of a `well.place` action's values `[slot, row, column, strength, sense]` (whole numbers in the
    /// declared ranges).
    static func well(_ values: [Int]) -> MicroscopicAuroraWell {
        let sense: MicroscopicAuroraSense = values[4] == 0 ? .clockwise : .counterclockwise
        return MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: values[1], column: values[2]),
                                     strength: values[3], sense: sense)
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
                return .rejected(.rule(code: MicroscopicAuroraExperienceRule.notWhole))
            }
            values.append(whole)
        }
        if case .replay = mode, !Self.replayControls.contains(action.control) {
            return .rejected(.rule(code: MicroscopicAuroraExperienceRule.replay))
        }
        do throws(MicroscopicAuroraError) {
            switch action.control {
            case "well.place":
                try play.apply(.place(slot: values[0], well: Self.well(values)), expecting: play.fingerprint)
                advanceTutorial(afterAction: true, placement: true)
            case "well.remove":
                try play.apply(.remove(slot: values[0]), expecting: play.fingerprint)
                advanceTutorial(afterAction: true, placement: false)
            case "swim.play":
                try play.apply(.play, expecting: play.fingerprint)
                advanceTutorial(afterAction: false, placement: false)
                recordIfWon()
            case "play.undo":
                try play.undo()
                advanceTutorial(afterAction: false, placement: false)
            case "play.redo":
                try play.redo()
                advanceTutorial(afterAction: false, placement: false)
                recordIfWon()
            case "clock.show":
                // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                guard values[0] <= play.report.ticks else {
                    return .rejected(.rule(code: MicroscopicAuroraExperienceRule.tick))
                }
                shownTick = values[0]
                return .accepted
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: MicroscopicAuroraExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
                return .accepted
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: MicroscopicAuroraExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
                return .accepted
            case "mode.daily":
                guard let daily = MicroscopicAuroraProgress.dailyLevel(year: values[0], month: values[1],
                                                                       day: values[2]) else {
                    return .rejected(.rule(code: MicroscopicAuroraExperienceRule.date))
                }
                try open(number: daily, mode: .daily(level: daily))
                return .accepted
            case "mode.practice":
                try open(number: levelNumber, mode: .practice)
                return .accepted
            case "mode.campaign":
                try open(number: progress.isOpen(levelNumber) ? levelNumber : progress.frontier, mode: .campaign)
                return .accepted
            case "replay.start":
                guard let result = progress.solved[values[0]], result.verified, !result.trace.isEmpty else {
                    return .rejected(.rule(code: MicroscopicAuroraExperienceRule.noReplay))
                }
                try open(number: values[0], mode: .replay(level: values[0]))
                tutorial = .done
                return .accepted
            case "replay.step":
                guard case .replay(let level) = mode, let result = progress.solved[level], result.verified else {
                    return .rejected(.rule(code: MicroscopicAuroraExperienceRule.noReplay))
                }
                // Replay never undoes, so each trace action made exactly one placement, removal or play record (a
                // fresh play also holds its begin and tutorial records, which are not counted).
                let index: Int = Self.actionRecordCount(play.records)
                guard play.stage == .playing, index < result.trace.count else {
                    return .rejected(.rule(code: MicroscopicAuroraExperienceRule.replayEnd))
                }
                try play.apply(result.trace[index], expecting: play.fingerprint)
            case "replay.stop":
                guard case .replay(let level) = mode else {
                    return .rejected(.rule(code: MicroscopicAuroraExperienceRule.noReplay))
                }
                try open(number: progress.isOpen(level) ? level : progress.frontier, mode: .campaign)
                return .accepted
            case "settings.sound":
                soundOn = values[0] == 1
                return .accepted
            default:   // tutorial.dismiss
                tutorial = tutorial.dismissed()
                return .accepted
            }
        } catch {
            return .rejected(.rule(code: error.reasonCode))
        }
        // The shown tick stays, clamped to the ticks the current report swims.
        shownTick = min(shownTick, play.report.ticks)
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Advances the tutorial step after an accepted placement, removal, play, undo or redo
    /// (`MicroscopicAuroraTutorialStep.advanced(afterAction:placement:ended:)`): `afterAction` for a placement or a
    /// removal, `placement` for a placement, ended when the play is won or failed (never after an undo, which always
    /// lands on a moment before the end; after a redo only when it restores a won or failed moment). Never back.
    private mutating func advanceTutorial(afterAction: Bool, placement: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterAction: afterAction, placement: placement, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step and tick 0 shown; the records of the level left are dropped. Changes nothing when the kernel
    /// refuses.
    private mutating func open(number: Int, mode: MicroscopicAuroraMode) throws(MicroscopicAuroraError) {
        let certified: MicroscopicAuroraGenerated = try Self.generated(number: number)
        let fresh: MicroscopicAuroraPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedWells = certified.plan.wells
        tutorial = MicroscopicAuroraTutorialStep.initial(level: number)
        shownTick = 0
    }

    /// After an accepted action that won the play: records the actions spent
    /// (`MicroscopicAuroraProgress.actionsSpent(_:)`) against the certified plan's placement count in the current mode
    /// (campaign opens the next level; daily records the best result and stars and opens nothing; practice records
    /// nothing). A won play is final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        if case .replay = mode { return }
        progress.record(level: levelNumber, actionsSpent: MicroscopicAuroraProgress.actionsSpent(play),
                        certified: certifiedPlacements, mode: mode, trace: winningTrace)
    }

    /// The controls accepted during replay (feature 487).
    static let replayControls: Set<String> = ["replay.start", "replay.step", "replay.stop", "tutorial.dismiss",
                                              "clock.show", "settings.sound"]

    /// The winning trace of the current play (feature 487): its effective placements and removals in order, then the
    /// play (``MicroscopicAuroraReconciliation/netTrace(_:)``), never an undo or a redo.
    var winningTrace: [MicroscopicAuroraAction] { MicroscopicAuroraReconciliation.netTrace(play.records) }

    /// The number of placement, removal and play records among `records` (feature 487): the trace actions a replay
    /// applied.
    static func actionRecordCount(_ records: [MicroscopicAuroraRecord]) -> Int {
        var count: Int = 0
        for record in records where record.kind == .place || record.kind == .remove || record.kind == .play {
            count += 1
        }
        return count
    }

    /// Back to the opening state the seed chose (progress included, campaign mode, tick 0 shown, sound off); the
    /// quality tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedWells = opening.certifiedWells
        shownTick = 0
        soundOn = false
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g19.microscopic-aurora.v3", then the level number, the play's fingerprint (actions spent, failure, level,
    /// stage, wells), the progress (with its traces) and the mode (their sorted JSON); never the tutorial step, the shown
    /// tick, the sound choice or the dropped count.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // shown tick (presentation) or the tutorial step.
        builder.add(play.fingerprint)
        let encoder: JSONEncoder = Self.payloadEncoder()
        builder.add(String(decoding: (try? encoder.encode(progress)) ?? Data(), as: UTF8.self))
        builder.add(String(decoding: (try? encoder.encode(mode)) ?? Data(), as: UTF8.self))
    }

    // MARK: Snapshot

    /// The payload's JSON form (schema 3); `tutorial` is absent in a migrated schema-1 payload.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The mode.
        var mode: MicroscopicAuroraMode
        /// The progress.
        var progress: MicroscopicAuroraProgress
        /// The play's records.
        var records: [MicroscopicAuroraRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: MicroscopicAuroraTutorialStep?
        /// The sound choice; nil (off) in a payload written before schema 3.
        var sound: Bool?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "sound", "tutorial"}` with sorted keys and unescaped
    /// slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, tutorial: tutorial, sound: soundOn))
    }

    /// The core of `payload` (schema 2): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the saved progress, mode and tutorial step (the first step when absent), with tick 0 shown;
    /// a reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``MicroscopicAuroraRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or
    ///   tutorial step, or a daily mode naming another level among them), a level number outside 1 … 100 or a level or
    ///   trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> MicroscopicAuroraExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw MicroscopicAuroraRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw MicroscopicAuroraRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw MicroscopicAuroraRestoreRefusal.damaged
        }
        if case .replay(let replayed) = decoded.mode, replayed != decoded.level {
            throw MicroscopicAuroraRestoreRefusal.damaged
        }
        // Feature 487: a saved replay's placement, removal and play records are exactly the first actions of its
        // level's saved trace — in order, no undo or redo — or the payload is damaged.
        if case .replay(let replayed) = decoded.mode, let saved = decoded.progress.solved[replayed], saved.verified {
            var applied: [MicroscopicAuroraAction] = []
            for record in decoded.records {
                switch record.kind {
                case .place, .remove, .play:
                    guard let action = record.action else { throw MicroscopicAuroraRestoreRefusal.damaged }
                    applied.append(action)
                case .undo, .redo:
                    throw MicroscopicAuroraRestoreRefusal.damaged
                default:
                    continue
                }
            }
            guard applied.count <= saved.trace.count, Array(saved.trace.prefix(applied.count)) == applied else {
                throw MicroscopicAuroraRestoreRefusal.damaged
            }
        }
        do throws(MicroscopicAuroraError) {
            let certified: MicroscopicAuroraGenerated = try generated(number: decoded.level)
            let play: MicroscopicAuroraPlay = try MicroscopicAuroraPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: MicroscopicAuroraTutorialStep = decoded.tutorial
                ?? MicroscopicAuroraTutorialStep.initial(level: decoded.level)
            let openingCore: MicroscopicAuroraExperienceCore = try opening(number: levelNumber(forSeed: seed))
            // Feature 487: every saved result is checked by replaying its trace; the frontier stays as saved.
            let reconciled = MicroscopicAuroraReconciliation.reconcile(decoded.progress)
            var core: MicroscopicAuroraExperienceCore = MicroscopicAuroraExperienceCore(
                levelNumber: decoded.level, play: play, progress: reconciled.progress, mode: decoded.mode,
                tutorial: tutorial, certifiedWells: certified.plan.wells, openingNumber: openingCore.openingNumber,
                opening: openingCore.opening)
            core.reconciliationDropped = reconciled.dropped
            core.soundOn = decoded.sound ?? false
            // A replay whose result did not survive the check returns to campaign at that level (or the frontier).
            if case .replay(let level) = decoded.mode, reconciled.progress.solved[level]?.verified != true {
                try core.open(number: core.progress.isOpen(level) ? level : core.progress.frontier, mode: .campaign)
            }
            return core
        } catch {
            throw MicroscopicAuroraRestoreRefusal.kernel(error)
        }
    }
}
