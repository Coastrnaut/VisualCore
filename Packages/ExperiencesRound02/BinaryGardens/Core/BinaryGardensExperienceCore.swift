// BinaryGardensExperienceCore — feature 503 (R02-G21-03) T-R02G2103-005 (FR-R02G2103-003, 004, 005, 008, 009;
// SC-R02G2103-002, 004; clarifications Q1, Q4, Q5; research R12–R14; data-model.md; contracts/api.md). The adapter of
// the Binary Gardens kernel to the shared experience contract. The core holds the level number, the kernel's
// `BinaryGardensPlay` and the shown tick; it never draws and reads no clock. The presenter asks for an immutable
// `BinaryGardensSceneSnapshot` at its own presentation time (`snapshot(time:)`), so the scene can breathe while the
// state and its digest stay put (renderer purity). The snapshot carries the kernel's exact report of the current
// arrangement — every body's position, every world's flux, shares, bands, windows and integral at ticks 1 … 48 — so no
// drawn value decides a band, a window or the verdict. The shown tick is presentation state of the adapter
// (`clock.show [tick]`, research R12): 48 at an opening (the starting configuration, since tick 48 is tick 0 again),
// after `level.next`, a reset and a restore; a ring, phase, luminosity or tilt change, the run, undo and redo keep it
// (the report always covers ticks 1 … 48); never advanced by time and never in the digest, the snapshot payload or
// `==`. Modelled on `MushroomWeatherExperienceCore` (feature 493).
//
// Preparation: the certified level number `seed % 100 + 1` of `BinaryGardensManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each R02-G21-02
// witness's `skipped`), the whole catalog (`BinaryGardensGenerator.catalog()`, once per process) only if that candidate
// no longer certifies; begun (and its tutorial dismissed, as `BinaryGardensSolver.replayWins` does) so the play is in
// stage `playing`. The tutorial of the first levels is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   star.ring [0…1, 0…7]         star and ring index, whole numbers (`r02-g21.not-whole` otherwise); moves the star to
//                                the ring (1 action); a ring the level lacks, a locked ring, the star's current ring or
//                                an arrangement that breaks the minimum separation is the kernel's `r02-g21.action`;
//                                no action left is `r02-g21.budget`;
//   star.phase [0…1, 0…47]       star and phase step (1 action); a step off the level's phase grid, a locked phase, the
//                                current phase or a separation break is `r02-g21.action`; budget as above;
//   star.luminosity [0…1, 0…3]   star and luminosity index (1 action); a level the level lacks, a locked luminosity or
//                                the current one is `r02-g21.action`; budget as above;
//   orbit.tilt [0…6]             the tilt step (1 action); a step above T_max, a locked tilt (T_max = 0), the current
//                                tilt or a separation break is `r02-g21.action`; budget as above;
//   light.run                    the run that ends the level (no action spent): `won` when the report wins, else
//                                `failed` with its failure;
//   play.undo, play.redo         the kernel's exact undo and redo (`r02-g21.action` when there is nothing to undo or
//                                redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                   the next certified level with a fresh play, tick 48 shown (since feature 505 the
//                                next open level in campaign mode, `r02-g21.locked` when none; no wrap from 100 to 1);
//   clock.show [0…60]            shows tick 1 … 48 (presentation only; accepted in every stage); 0 and 49 … 60 are
//                                refused `r02-g21.tick` without touching the kernel.
// The declared ranges are star 0 … 1, ring index 0 … 7 (`BinaryGardensLevel.ringCounts` upper bound − 1), phase 0 … 47,
// luminosity index 0 … 3 (`luminosityCounts` upper bound − 1), tilt 0 … 6 (`maxTilts`) and tick 0 … 60 (0 … 48 + the
// largest tolerance 12, the span of the kernel's walk ticks), so the engine refuses only values outside them and the
// adapter's own `r02-g21.tick` stays observable (research R12). Outside stage `playing` the kernel refuses an
// arrangement action and the run with `r02-g21.stage`. Every action is applied with the play's fingerprint as the
// expected one, so `r02-g21.stale` cannot arise. A kernel refusal (`BinaryGardensError`) becomes
// `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown tick included.
//
// Digest ("r02-g21.binary-gardens.v1" until feature 505, see below): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the shown tick, the quality tier or a time. Snapshot schema 1: the JSON
// object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`BinaryGardensPlay.replay`), shows tick 48 and throws `BinaryGardensRestoreRefusal` for a damaged payload, a level
// number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another level's seed among
// them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality (research R14): three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best
// and no budget may rise); `qualityTiers` is their count and the profile's level names are `BinaryGardensTier.all`'s
// names (`level-0`, `level-1`, `level-2`). Host tier `t` draws `BinaryGardensTier.of(t)`: level-0 = cube-spheres of
// 8 × 8 quads per face, 12 corona rays, trails of 8 ticks, 8 motes, 2 glow shells; level-1 = 5 × 5, 6 rays, 4 ticks,
// 4 motes, 1 shell; level-2 = 3 × 3, no rays, trails, motes or glow. Outcome: `won` or `failed` while the play is in
// that stage, else nil. Rules use integers only.
//
// Feature 505 (R02-G21-05) T-R02G2105-004 (FR-R02G2105-001, 004 … 007; clarifications Q2–Q6): the core also holds the
// player's progress (`BinaryGardensProgress`: won levels with the least actions spent and stars, the open frontier),
// the mode (campaign, practice with the budget raised to the kernel's maximum 24 on a copy of the level, daily) and
// the tutorial step (`BinaryGardensTutorialStep`). No level is ever gated by payment: a locked level is one not yet
// unlocked (FR-R02G2105-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g21.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level ((days from 2026-01-01 × 13) mod 100 + 1), fresh
//                                  (`r02-g21.date` for an impossible date); a daily level still locked in the campaign
//                                  is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 24 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Non-whole values of the new controls are refused `r02-g21.not-whole`. Choosing a level or a mode drops the left
// level's records (the play starts fresh with tick 48 shown and the tutorial at its first step). `level.next` (above)
// moves to the next open level in campaign mode and is refused with `r02-g21.locked` when there is none (100 no longer
// wraps to 1). A win (the play reaching `won` on an accepted `light.run` or redo) records
// `progress.record(level:actionsSpent:certified:mode:)` with the actions spent (`BinaryGardensProgress.actionsSpent`:
// every accepted ring, phase, luminosity and tilt record, undone ones included) against the certified plan's action
// count (`certifiedActionCount`): campaign opens the next level, daily records the level's best result and stars and
// opens nothing, practice records nothing. The certified plan (`certifiedPlan`) feeds the hints (`hint(level:)`) and
// the stars. A fresh opening of level N (prepare, reset) has levels 1 … N open and no won levels. The tutorial starts at
// `BinaryGardensTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced after every
// accepted ring, phase, luminosity, tilt, run, undo and redo by `advanced(afterAction:actionsThisOpening:ended:)`
// (afterAction for an arrangement action, the actions this opening counted as for the stars, ended when the play is won
// or failed — an undo never ends it, a redo only when it restores a won or failed moment), never back; `clock.show`
// never moves it. The shown tick, the quality tier and the presenter's preview, orbit and inspected world stay
// presentation. Digest "r02-g21.binary-gardens.v2": level, play fingerprint, progress and mode (never the tutorial step
// or the shown tick). Snapshot schema 2: `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys;
// schema-1 payloads migrate (no won levels, levels 1 … the restored level open, campaign mode, the tutorial at its first
// step — `adjust` on levels 1 … 3, else `done`); a damaged payload (invalid progress — a frontier or a won level
// outside 1 … 100, stars outside 1 … 3, actions below 1 —, an unknown mode or tutorial step, a daily mode naming another
// level) throws `.damaged`, a level outside 1 … 100 `.levelNumber`, a trace the kernel refuses `.kernel`; an envelope
// of a newer schema is refused by the engine. Modelled on feature 495's `MushroomWeatherExperienceCore`.
//
// Feature 507 (R02-G21-07) T-R02G2107-003 (FR-R02G2107-001 … 009; clarifications Q1–Q6): a campaign or daily win
// records its winning trace (`BinaryGardensReconciliation.netTrace` of the play's records: the effective ring, phase,
// luminosity and tilt actions, an undone action left out unless redone, then the run) as a verified result; restore
// reconciles every result (`BinaryGardensReconciliation.reconcile`, the frontier as saved) and exposes
// `reconciliationDropped` (not digested, not in `==`); the replay mode `replay(level)` plays a verified trace action
// by action:
//   replay.start [1…100]  a fresh play of that level in mode `replay(level)` (campaign budget) with tick 48 shown and
//                         the tutorial done (`r02-g21.no-replay` without a verified result with a trace); during a
//                         replay it restarts it;
//   replay.step           the next action of the trace, a ring, phase, luminosity or tilt action or finally the run
//                         (`r02-g21.replay-end` after the last or once the run ended; `r02-g21.no-replay` outside
//                         replay); a step keeps the shown tick;
//   replay.stop           campaign at that level, the frontier when it is not open (`r02-g21.no-replay` outside
//                         replay);
//   settings.sound [0…1]  the sound choice: 1 on, 0 off; whole (`r02-g21.not-whole`); allowed in every mode.
// In replay every other action except `tutorial.dismiss` and `clock.show` (presentation) and `settings.sound` is
// refused with `r02-g21.replay`, and nothing is recorded. A restored replay whose ring, phase, luminosity, tilt and run
// records are not exactly the first actions of its level's verified trace (in order, no undo or redo) is refused as
// `damaged`; a restored replay whose result did not survive reconciliation, or was never verified, returns to campaign
// at that level (the frontier when it is not open). Digest "r02-g21.binary-gardens.v3" (the same parts as v2, the
// progress now with traces; never the tutorial step, the shown tick, the sound choice or the dropped count); snapshot
// schema 3 `{"level", "mode", "progress", "records", "sound", "tutorial"}` (results carry `trace` and `verified`),
// migrating 1 → 2 → 3 (2 → 3: every result an empty trace and `verified` false, sound off). The snapshot always writes
// the `"sound"` key; a result's `trace` and `verified` keys follow `BinaryGardensProgress`'s encoding (written when
// the trace is not empty or the result is verified, so an untraced result keeps its schema-2 form and feature 505's
// exact progress encodings stay valid; the decoder reads both forms). Modelled on feature 497's
// `MushroomWeatherExperienceCore`.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Binary Gardens' adapter refusals (feature 503; `locked` and `date` since feature 505).
public enum BinaryGardensExperienceRule {
    /// A value that must be a whole number (a star, a ring, a phase, a luminosity, a tilt, a tick, a level or a date
    /// part) and is not.
    public static let notWhole = "r02-g21.not-whole"
    /// A shown tick outside 1 … 48 within the declared range 0 … 60 (`clock.show`).
    public static let tick = "r02-g21.tick"
    /// A level that is not open yet, or no next open level (feature 505). Never a payment gate.
    public static let locked = "r02-g21.locked"
    /// An impossible calendar date (`mode.daily`, feature 505).
    public static let date = "r02-g21.date"
    /// No verified result with a trace to replay, or a replay control outside replay (feature 507).
    public static let noReplay = "r02-g21.no-replay"
    /// The replay has no further action: the trace is over or the run ended (feature 507).
    public static let replayEnd = "r02-g21.replay-end"
    /// An action that is not allowed during replay (feature 507).
    public static let replay = "r02-g21.replay"
}

/// Why a saved Binary Gardens state was refused on restore (feature 503). A refused restore changes nothing.
public enum BinaryGardensRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 505).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(BinaryGardensError)
}

/// The state of Binary Gardens as an experience (see the file header). Snapshot schema 3.
public struct BinaryGardensExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g21.binary-gardens"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 3
    /// The digest's domain string (schema 3).
    public static let digestDomain = "r02-g21.binary-gardens.v3"
    /// The action ids in declaration order.
    public static let actionIDs = ["star.ring", "star.phase", "star.luminosity", "orbit.tilt", "light.run",
                                   "play.undo", "play.redo", "level.next", "clock.show", "level.select", "mode.daily",
                                   "mode.practice", "mode.campaign", "tutorial.dismiss", "replay.start",
                                   "replay.step", "replay.stop", "settings.sound"]
    /// The declared range of `settings.sound`: 0 off, 1 on (feature 507).
    public static let soundRange: ClosedRange<Int> = 0...1
    /// The budget of a practice play: the kernel's maximum (`BinaryGardensMode.practiceBudget`, 24).
    public static let practiceBudget: Int = BinaryGardensMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a star: 0 … 1.
    public static let starRange: ClosedRange<Int> = 0...1
    /// The declared range of a ring index: 0 … `BinaryGardensLevel.ringCounts` upper bound − 1 (0 … 7).
    public static let ringRange: ClosedRange<Int> = 0...(BinaryGardensLevel.ringCounts.upperBound - 1)
    /// The declared range of a phase step: `BinaryGardensLevel.phases` (0 … 47).
    public static let phaseRange: ClosedRange<Int> = BinaryGardensLevel.phases
    /// The declared range of a luminosity index: 0 … `BinaryGardensLevel.luminosityCounts` upper bound − 1 (0 … 3).
    public static let luminosityRange: ClosedRange<Int> = 0...(BinaryGardensLevel.luminosityCounts.upperBound - 1)
    /// The declared range of a tilt step: `BinaryGardensLevel.maxTilts` (0 … 6).
    public static let tiltRange: ClosedRange<Int> = BinaryGardensLevel.maxTilts
    /// The declared range of a shown tick: 0 … 48 + the largest tolerance (`BinaryGardensLevel.tolerances` upper bound
    /// 12), the span of the kernel's walk ticks (0 … 60).
    public static let tickRange: ClosedRange<Int> = 0...(BinaryGardensSky.cycle
                                                         + BinaryGardensLevel.tolerances.upperBound)
    /// The ticks `clock.show` accepts: 1 … 48.
    public static let shownTicks: ClosedRange<Int> = 1...BinaryGardensSky.cycle
    /// The tick shown at an opening, after `level.next`, a reset and a restore: 48 (the starting configuration).
    public static let openingTick: Int = BinaryGardensSky.cycle
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: BinaryGardensPlay
    /// The player's progress (feature 505): in the digest, the snapshot and `==`.
    public private(set) var progress: BinaryGardensProgress
    /// The mode (feature 505): in the digest, the snapshot and `==`.
    public private(set) var mode: BinaryGardensMode
    /// The tutorial step (feature 505): in the snapshot and `==`, not in the digest.
    public private(set) var tutorial: BinaryGardensTutorialStep
    /// The certified plan of the current level (its minimal witness without the run), which the hints follow and the
    /// stars count against. Derived from the level number.
    public private(set) var certifiedPlan: BinaryGardensPlan
    /// The shown tick, 1 … 48; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownTick: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0
    /// How many saved results the last restore dropped because they did not verify (feature 507); not in the digest,
    /// the snapshot or `==`. 0 at an opening.
    public private(set) var reconciliationDropped = 0
    /// The player's sound choice (feature 507), set by `settings.sound`: in the snapshot (key `"sound"`) and `==`,
    /// never in the digest; off at an opening, after a reset and in a migrated save.
    public private(set) var soundOn = false

    /// What a reset restores (feature 505).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: BinaryGardensPlay
        /// The opening progress: levels 1 … the opening level open, none won.
        let progress: BinaryGardensProgress
        /// The opening level's initial tutorial step.
        let tutorial: BinaryGardensTutorialStep
        /// The opening level's certified plan.
        let certifiedPlan: BinaryGardensPlan
    }

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial` and tick 48 shown, whose
    /// reset returns to `opening` of `openingNumber`.
    init(levelNumber: Int, play: BinaryGardensPlay, progress: BinaryGardensProgress, mode: BinaryGardensMode,
         tutorial: BinaryGardensTutorialStep, certifiedPlan: BinaryGardensPlan, openingNumber: Int,
         opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedPlan = certifiedPlan
        self.shownTick = Self.openingTick
        self.openingNumber = openingNumber
        self.opening = opening
    }

    /// The certified plan's action count of the current level (ring, phase, luminosity and tilt actions, the run
    /// excluded: 1, 2, 3, 3 or 4 by band), against which a win's stars are counted (feature 505).
    public var certifiedActionCount: Int { certifiedPlan.size }

    /// The difficulty band (1 … 5) of the current level: 20 levels per band, the certified difficulty bands
    /// (`BinaryGardensProgress.band(of:)`; feature 505).
    public var band: Int { BinaryGardensProgress.band(of: levelNumber) }

    /// The hint at `level` (1 … 3) for the current play against the certified plan
    /// (`BinaryGardensHints.hint(level:play:certified:)`); nil when the play is won or not playing. Reads only.
    public func hint(level: Int) -> BinaryGardensHint? {
        BinaryGardensHints.hint(level: level, play: play, certified: certifiedPlan)
    }

    /// The explanation of the play's failure (`BinaryGardensFailureExplanation(play:)`); nil unless it failed.
    public var failureExplanation: BinaryGardensFailureExplanation? { BinaryGardensFailureExplanation(play: play) }

    /// The level number a seed chooses: `seed % 100 + 1`.
    public static func levelNumber(forSeed seed: UInt64) -> Int {
        Int(seed % UInt64(levelNumbers.count)) + 1
    }

    /// The certified level of manifest number `number` (1 … 100).
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func level(number: Int) throws(BinaryGardensError) -> BinaryGardensLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for.
    private static let generatedCache = Mutex<[Int: BinaryGardensGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[BinaryGardensGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/binary-gardens/levels/NNN.witness.json`, read 2026-11-27).
    public static let certifiedCandidates: [Int] = [
        1, 1, 2, 3, 0, 2, 1, 3, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 3, 4, 0, 3, 6,
        1, 8, 0, 0, 0, 8, 0, 7, 0, 6, 1, 3, 0, 5, 8, 3, 12, 6, 16, 4, 14, 1, 3, 1, 6,
        0, 1, 20, 24, 3, 9, 11, 14, 6, 2, 11, 3, 2, 0, 1, 0, 0, 6, 4, 5, 1, 1, 1, 6, 0,
        1, 6, 3, 8, 8, 0, 0, 8, 0, 2, 1, 0, 2, 4, 3, 3, 3, 1, 6, 10, 4, 2, 7, 0, 14,
    ]

    /// Candidate `index` of `entry` certified as ``BinaryGardensGenerator/generate(_:previous:)`` certifies a
    /// candidate (a candidate the generator accepts whose minimal plan, found within the solver's work bound, has the
    /// band's plan length and wins through the play); nil otherwise. The neighbour rule is not checked here: the table
    /// names the candidate the generator kept under it.
    static func certify(_ entry: BinaryGardensManifestEntry, index: Int) -> BinaryGardensGenerated? {
        let length: Int = BinaryGardensBandProfile.of(band: entry.band).plan
        guard let level = BinaryGardensGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = BinaryGardensSolver.plan(level, maxDepth: length), plan.size == length else { return nil }
        guard BinaryGardensSolver.replayWins(level, actions: plan.actions) else { return nil }
        return BinaryGardensGenerated(entry: entry, level: level, plan: plan,
                                      difficulty: BinaryGardensDifficulty(level: level, plan: plan), skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(BinaryGardensError) -> BinaryGardensGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: BinaryGardensManifestEntry = BinaryGardensManifest.entries[number - 1]
        let fresh: BinaryGardensGenerated
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
    static func catalog() throws(BinaryGardensError) -> [BinaryGardensGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [BinaryGardensGenerated] = try BinaryGardensGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: BinaryGardensLevel) throws(BinaryGardensError) -> BinaryGardensPlay {
        var play = BinaryGardensPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The practice copy of `level` (feature 505): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: BinaryGardensLevel) throws(BinaryGardensError) -> BinaryGardensLevel {
        try BinaryGardensLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, ringRadii: level.ringRadii,
                               starSpeed: level.starSpeed, luminosityLevels: level.luminosityLevels,
                               stars: level.stars, maxTilt: level.maxTilt, startTilt: level.startTilt,
                               minimumSeparation: level.minimumSeparation, clampRadius: level.clampRadius,
                               worlds: level.worlds, lethalTolerance: level.lethalTolerance,
                               budget: BinaryGardensMode.practice.budget(base: level.budget),
                               tutorial: level.tutorial, phaseStep: level.phaseStep)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: BinaryGardensGenerated, mode: BinaryGardensMode)
        throws(BinaryGardensError) -> BinaryGardensLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with tick 48 shown; campaign mode, levels 1 … `number` open, none won, the tutorial at its
    /// first step (feature 505).
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(BinaryGardensError) -> BinaryGardensExperienceCore {
        let certified: BinaryGardensGenerated = try generated(number: number)
        let play: BinaryGardensPlay = try freshPlay(of: certified.level)
        var progress: BinaryGardensProgress = BinaryGardensProgress()
        progress.open(through: number)
        let tutorial: BinaryGardensTutorialStep = BinaryGardensTutorialStep.initial(level: number)
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial,
                                       certifiedPlan: certified.plan)
        return BinaryGardensExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                           tutorial: tutorial, certifiedPlan: certified.plan, openingNumber: number,
                                           opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (the level's rings, luminosity levels, tilt range, phase step and worlds with
    /// their bounds; the arrangement; the report's positions, fluxes, shares, bands, windows and integrals; the shown
    /// tick, the fit scale, the failure, the stage, the actions left and the budget) with the level number, for
    /// drawing at the presenter's presentation time `time` (a non-finite or negative time becomes 0). Reads only; the
    /// state and its digest do not change.
    public func snapshot(time: Double) -> BinaryGardensSceneSnapshot {
        BinaryGardensSceneSnapshot(play: play, shownTick: shownTick, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `BinaryGardensTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: BinaryGardensTier { BinaryGardensTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `BinaryGardensTier.all`.
    public static var qualityTiers: Int { BinaryGardensTier.all.count }

    /// One level per host tier, best first, named as `BinaryGardensTier.all` (research R14): the element share is the
    /// motes over the best tier's (1, 0.5, 0), the iteration share the quads per cube face over the best tier's
    /// (1, 25 / 64, 9 / 64), the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: BinaryGardensTier = BinaryGardensTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<BinaryGardensTier.all.count {
            let tier: BinaryGardensTier = BinaryGardensTier.of(hostTier)
            let quads: Double = Double(tier.faceQuads * tier.faceQuads) / Double(best.faceQuads * best.faceQuads)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.motes) / Double(best.motes),
                                       iterationShare: quads, effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode, the tutorial step and the sound choice (not
    /// the shown tick, the quality tier, the dropped count or the opening level).
    public static func == (lhs: BinaryGardensExperienceCore, rhs: BinaryGardensExperienceCore) -> Bool {
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

    /// The schema-3 object of a schema-2 object (feature 507): every won result gains an empty `trace` and `verified`
    /// false, and the sound choice is off.
    ///
    /// - Throws: ``BinaryGardensRestoreRefusal/damaged`` when `object` has no progress with a solved list.
    public static func migratedToSchemaThree(_ object: [String: Any]) throws -> [String: Any] {
        guard var progress = object["progress"] as? [String: Any], let solved = progress["solved"] as? [Any] else {
            throw BinaryGardensRestoreRefusal.damaged
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

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 505): no won levels with levels 1 … the
    /// restored level open, campaign mode, no tutorial key (restore starts the tutorial at its first step: `adjust` on
    /// the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``BinaryGardensRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw BinaryGardensRestoreRefusal.damaged
        }
        var progress: BinaryGardensProgress = BinaryGardensProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(BinaryGardensMode.campaign))
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
        ExperienceControl(id: "star.ring", ranges: [declared(starRange), declared(ringRange)]),
        ExperienceControl(id: "star.phase", ranges: [declared(starRange), declared(phaseRange)]),
        ExperienceControl(id: "star.luminosity", ranges: [declared(starRange), declared(luminosityRange)]),
        ExperienceControl(id: "orbit.tilt", ranges: [declared(tiltRange)]),
        ExperienceControl(id: "light.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "clock.show", ranges: [declared(tickRange)]),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(BinaryGardensProgress.dailyYears), 1...12, 1...31]),
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

    /// The eighteen controls with their declared ranges (see the file header); `light.run`, `play.undo`, `play.redo`,
    /// `level.next`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`, `replay.step` and `replay.stop` take no
    /// values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with tick 48 shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> BinaryGardensExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(BinaryGardensError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Binary Gardens level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the light changes only on an action, and the scene breathes with the presenter's
    /// time, not the state (the shown tick is never advanced by time).
    public mutating func update(step: Int) {}

    /// The kernel action of an arrangement control's whole values (in the declared ranges); nil for any other control.
    static func kernelAction(_ control: String, _ values: [Int]) -> BinaryGardensAction? {
        switch control {
        case "star.ring": .ring(star: values[0], index: values[1])
        case "star.phase": .phase(star: values[0], step: values[1])
        case "star.luminosity": .luminosity(star: values[0], index: values[1])
        case "orbit.tilt": .tilt(step: values[0])
        case "light.run": .run
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
                return .rejected(.rule(code: BinaryGardensExperienceRule.notWhole))
            }
            values.append(whole)
        }
        if case .replay = mode, !Self.replayControls.contains(action.control) {
            return .rejected(.rule(code: BinaryGardensExperienceRule.replay))
        }
        do throws(BinaryGardensError) {
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
                case "clock.show":
                    // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                    guard Self.shownTicks.contains(values[0]) else {
                        return .rejected(.rule(code: BinaryGardensExperienceRule.tick))
                    }
                    shownTick = values[0]
                case "level.next":
                    // The next open level in campaign mode; no wrap from 100 to 1 (feature 505).
                    guard let next = progress.nextOpen(after: levelNumber) else {
                        return .rejected(.rule(code: BinaryGardensExperienceRule.locked))
                    }
                    try open(number: next, mode: .campaign)
                case "level.select":
                    guard progress.isOpen(values[0]) else {
                        return .rejected(.rule(code: BinaryGardensExperienceRule.locked))
                    }
                    try open(number: values[0], mode: .campaign)
                case "mode.daily":
                    guard let daily = BinaryGardensProgress.dailyLevel(year: values[0], month: values[1],
                                                                       day: values[2]) else {
                        return .rejected(.rule(code: BinaryGardensExperienceRule.date))
                    }
                    try open(number: daily, mode: .daily(level: daily))
                case "mode.practice":
                    try open(number: levelNumber, mode: .practice)
                case "mode.campaign":
                    try open(number: progress.isOpen(levelNumber) ? levelNumber : progress.frontier, mode: .campaign)
                case "replay.start":
                    // Feature 507: a verified result with a trace; during a replay this restarts it.
                    guard let result = progress.solved[values[0]], result.verified, !result.trace.isEmpty else {
                        return .rejected(.rule(code: BinaryGardensExperienceRule.noReplay))
                    }
                    try open(number: values[0], mode: .replay(level: values[0]))
                    tutorial = .done
                case "replay.step":
                    guard case .replay(let level) = mode, let result = progress.solved[level], result.verified else {
                        return .rejected(.rule(code: BinaryGardensExperienceRule.noReplay))
                    }
                    // Replay never undoes, so each trace action made exactly one ring, phase, luminosity, tilt or run
                    // record (the fresh play's begin and tutorial records are not counted).
                    let index: Int = replayPosition
                    guard play.stage == .playing, index < result.trace.count else {
                        return .rejected(.rule(code: BinaryGardensExperienceRule.replayEnd))
                    }
                    try play.apply(result.trace[index], expecting: play.fingerprint)
                case "replay.stop":
                    guard case .replay(let level) = mode else {
                        return .rejected(.rule(code: BinaryGardensExperienceRule.noReplay))
                    }
                    try open(number: progress.isOpen(level) ? level : progress.frontier, mode: .campaign)
                case "settings.sound":
                    soundOn = values[0] == 1
                default:   // tutorial.dismiss
                    tutorial = tutorial.dismissed()
                }
            }
        } catch {
            return .rejected(.rule(code: error.reasonCode))
        }
        // The shown tick stays: the report always covers ticks 1 … 48.
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Advances the tutorial step after an accepted ring, phase, luminosity, tilt, run, undo or redo
    /// (`BinaryGardensTutorialStep.advanced(afterAction:actionsThisOpening:ended:)`): `afterAction` for an arrangement
    /// action, the actions this opening counted as for the stars (`BinaryGardensProgress.actionsSpent`, undone ones
    /// included), ended when the play is won or failed (never after an undo, which always lands on a moment before the
    /// end; after a redo only when it restores a won or failed moment). Never back.
    private mutating func advanceTutorial(afterAction: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterAction: afterAction,
                                     actionsThisOpening: BinaryGardensProgress.actionsSpent(play), ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step and tick 48 shown; the records of the level left are dropped. Changes nothing when the kernel
    /// refuses.
    private mutating func open(number: Int, mode: BinaryGardensMode) throws(BinaryGardensError) {
        let certified: BinaryGardensGenerated = try Self.generated(number: number)
        let fresh: BinaryGardensPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedPlan = certified.plan
        tutorial = BinaryGardensTutorialStep.initial(level: number)
        shownTick = Self.openingTick
    }

    /// After an accepted action that won the play: records the actions spent (`BinaryGardensProgress.actionsSpent(_:)`)
    /// against the certified plan's action count in the current mode (campaign opens the next level; daily records the
    /// best result and stars and opens nothing; practice records nothing). A won play is final, so a win is recorded
    /// once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        if case .replay = mode { return }
        progress.record(level: levelNumber, actionsSpent: BinaryGardensProgress.actionsSpent(play),
                        certified: certifiedActionCount, mode: mode, trace: winningTrace)
    }

    /// The controls accepted during replay (feature 507): the replay controls, `tutorial.dismiss` and `clock.show`
    /// (presentation) and `settings.sound`.
    public static let replayControls: Set<String> = ["replay.start", "replay.step", "replay.stop", "tutorial.dismiss",
                                                     "clock.show", "settings.sound"]

    /// The winning trace of the current play (feature 507): its effective ring, phase, luminosity and tilt actions in
    /// order, then the run (``BinaryGardensReconciliation/netTrace(_:)``), never an undo or a redo.
    var winningTrace: [BinaryGardensAction] { BinaryGardensReconciliation.netTrace(play.records) }

    /// The number of ring, phase, luminosity, tilt and run records among `records` (feature 507): in a replay, the
    /// trace actions applied so far.
    static func actionRecordCount(_ records: [BinaryGardensRecord]) -> Int {
        var count: Int = 0
        for record in records {
            switch record.kind {
            case .ring, .phase, .luminosity, .tilt, .run: count += 1
            case .undo, .redo, .begin, .dismissTutorial, .pause, .resume, .showResult: break
            }
        }
        return count
    }

    /// Whether the replay controls can start a replay of `level`: a verified result with a trace is stored for it
    /// (feature 507). Reads only.
    public func canReplay(level: Int) -> Bool {
        guard let result = progress.solved[level] else { return false }
        return result.verified && !result.trace.isEmpty
    }

    /// Whether the mode is a replay (feature 507).
    public var isReplaying: Bool {
        if case .replay = mode { return true }
        return false
    }

    /// In a replay, the trace actions applied so far (0 … ``replayLength``); 0 outside a replay (feature 507).
    public var replayPosition: Int {
        guard isReplaying else { return 0 }
        return Self.actionRecordCount(play.records)
    }

    /// In a replay, the length of the replayed trace (its arrangement actions and the run); 0 outside a replay
    /// (feature 507).
    public var replayLength: Int {
        guard case .replay(let level) = mode else { return 0 }
        return progress.solved[level]?.trace.count ?? 0
    }

    /// Back to the opening state the seed chose (levels 1 … the opening level open, none won, campaign mode, the
    /// tutorial at its first step, tick 48 shown, sound off — feature 507); the quality tier and the dropped count,
    /// which are not state, are kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedPlan = opening.certifiedPlan
        shownTick = Self.openingTick
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

    /// "r02-g21.binary-gardens.v3", then the level number, the play's fingerprint (actions spent, failure, level,
    /// luminosities, phases, rings, stage, tilt), the progress (with its traces) and the mode (their sorted JSON); never
    /// the tutorial step, the shown tick, the sound choice or the dropped count.
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
        var mode: BinaryGardensMode
        /// The progress.
        var progress: BinaryGardensProgress
        /// The play's records.
        var records: [BinaryGardensRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: BinaryGardensTutorialStep?
        /// The sound choice; nil (off) in a payload written before schema 3.
        var sound: Bool?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "sound", "tutorial"}` with sorted keys and unescaped
    /// slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, tutorial: tutorial, sound: soundOn))
    }

    /// The core of `payload` (schema 3): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the saved progress (reconciled: results that do not replay are dropped and counted in
    /// ``reconciliationDropped``; the frontier as saved), mode, tutorial step (the first step when absent) and sound
    /// choice (off when absent), with tick 48 shown; a saved replay whose result was dropped or is not verified returns
    /// to campaign at that level (the frontier when it is not open); a reset returns to the opening state `seed`
    /// chooses.
    ///
    /// - Throws: ``BinaryGardensRestoreRefusal`` for a damaged payload (invalid progress — a frontier or a won level
    ///   outside 1 … 100, stars outside 1 … 3, actions spent below 1 —, an unknown mode or tutorial step, a daily or
    ///   replay mode naming another level, or a saved replay whose action records are not exactly the first actions of
    ///   its level's verified trace among them), a level number outside 1 … 100 or a level or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> BinaryGardensExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw BinaryGardensRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw BinaryGardensRestoreRefusal.levelNumber(decoded.level)
        }
        guard decoded.progress.isValid, decoded.mode.isValid else { throw BinaryGardensRestoreRefusal.damaged }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw BinaryGardensRestoreRefusal.damaged
        }
        if case .replay(let replayed) = decoded.mode, replayed != decoded.level {
            throw BinaryGardensRestoreRefusal.damaged
        }
        // Feature 507: a saved replay's ring, phase, luminosity, tilt and run records are exactly the first actions of
        // its level's saved trace — in order, no undo or redo — or the payload is damaged.
        if case .replay(let replayed) = decoded.mode, let saved = decoded.progress.solved[replayed], saved.verified {
            var applied: [BinaryGardensAction] = []
            for record in decoded.records {
                switch record.kind {
                case .ring, .phase, .luminosity, .tilt, .run:
                    guard let action = record.action else { throw BinaryGardensRestoreRefusal.damaged }
                    applied.append(action)
                case .undo, .redo:
                    throw BinaryGardensRestoreRefusal.damaged
                case .begin, .dismissTutorial, .pause, .resume, .showResult:
                    continue
                }
            }
            guard applied.count <= saved.trace.count, Array(saved.trace.prefix(applied.count)) == applied else {
                throw BinaryGardensRestoreRefusal.damaged
            }
        }
        do throws(BinaryGardensError) {
            let certified: BinaryGardensGenerated = try generated(number: decoded.level)
            let play: BinaryGardensPlay = try BinaryGardensPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: BinaryGardensTutorialStep = decoded.tutorial
                ?? BinaryGardensTutorialStep.initial(level: decoded.level)
            let openingCore: BinaryGardensExperienceCore = try opening(number: levelNumber(forSeed: seed))
            // Feature 507: every saved result is checked by replaying its trace; the frontier stays as saved.
            let reconciled = BinaryGardensReconciliation.reconcile(decoded.progress)
            var core: BinaryGardensExperienceCore = BinaryGardensExperienceCore(
                levelNumber: decoded.level, play: play, progress: reconciled.progress, mode: decoded.mode,
                tutorial: tutorial, certifiedPlan: certified.plan, openingNumber: openingCore.openingNumber,
                opening: openingCore.opening)
            core.reconciliationDropped = reconciled.dropped
            core.soundOn = decoded.sound ?? false
            // A replay whose result did not survive the check returns to campaign at that level (or the frontier).
            if case .replay(let level) = decoded.mode, reconciled.progress.solved[level]?.verified != true {
                try core.open(number: core.progress.isOpen(level) ? level : core.progress.frontier, mode: .campaign)
            }
            return core
        } catch {
            throw BinaryGardensRestoreRefusal.kernel(error)
        }
    }
}
