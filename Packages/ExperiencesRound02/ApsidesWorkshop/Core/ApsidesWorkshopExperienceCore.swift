// ApsidesWorkshopExperienceCore — feature 473 (R02-G18-03) T-R02G1803-005 (FR-R02G1803-005, 008, 009;
// SC-R02G1803-004; clarifications Q4, Q5; data-model.md; contracts/api.md). The adapter of the Apsides Workshop kernel
// to the shared experience contract. The core holds the level number, the kernel's `ApsidesWorkshopPlay` and the shown
// tick; it never draws and reads no clock. The presenter asks for an immutable `ApsidesWorkshopSceneSnapshot` at its
// own presentation time (`snapshot(time:)`), so the star can pulse while the state and its digest stay put (renderer
// purity). The snapshot carries the kernel's report positions of the current orbit, the starting orbit's positions,
// the orbiter at the shown tick, the shares, the apsis readings and one gauge per target, so the drawn orbit is the
// kernel's positions and no drawn value decides a target, a contact or the verdict. The shown tick is presentation
// state of the adapter (`clock.show [tick]`): at an opening, after `level.next`, a reset and a restore it is tick 0; a
// tuning, the play, undo and redo keep it (the period of a level never changes); never in the digest, the snapshot
// payload or `==`. Modelled on `CelestialEclipseLabExperienceCore` (feature 463).
//
// Preparation: the certified level number `seed % 100 + 1` of `ApsidesWorkshopManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole catalog (`ApsidesWorkshopGenerator.catalog()`, once per process) only if that candidate no
// longer certifies; begun (and its tutorial dismissed, as `ApsidesWorkshopSolver.replayWins` does) so the play is in
// stage `playing`. The tutorial of levels 1 … 3 is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   orbit.periapsis [0…15, 0…23]  the eccentricity step k and the periapsis direction step d, whole numbers
//                                 (`r02-g18.not-whole` otherwise); one tuning (1 action); a tuning equal to the
//                                 current orbit or making the orbit invalid is the kernel's `r02-g18.action`; no
//                                 action left is `r02-g18.budget`;
//   orbit.size [8…48]             the size a in lattice units, whole (`r02-g18.not-whole` otherwise); refusals as
//                                 above;
//   orbit.play                    the play that ends the level (no action spent): `won` when the report wins, else
//                                 `failed` with its failure;
//   play.undo, play.redo          the kernel's exact undo and redo (`r02-g18.action` when there is nothing to undo or
//                                 redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                    the next certified level with a fresh play (since feature 475 the next open level;
//                                 see below);
//   clock.show [0…95]             shows the orbiter at a tick (presentation only; accepted in every stage); a tick
//                                 outside 0 … period − 1 of the level is refused `r02-g18.tick` without touching the
//                                 kernel.
// The declared ranges are the kernel's step ranges (`ApsidesWorkshopOrbit.eccentricities`, `.directions`, `.sizes`) and
// the longest period any level allows (`ApsidesWorkshopLevel.periods`: ticks 0 … 95); the kernel or the adapter refuses
// the values a level lacks. Outside stage `playing` the kernel refuses a tuning and the play with `r02-g18.stage`.
// Every action is applied with the play's fingerprint as the expected one, so `r02-g18.stale` cannot arise. A kernel
// refusal (`ApsidesWorkshopError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown
// tick included.
//
// Digest ("r02-g18.apsides-workshop.v1" until feature 475): the level number and the play's fingerprint (not its
// record history, so undo restores the earlier digest exactly); never the shown tick, the quality tier or a time.
// Snapshot schema 1: the JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh
// play of that level (`ApsidesWorkshopPlay.replay`), resets the shown tick and throws `ApsidesWorkshopRestoreRefusal`
// for a damaged payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of
// another level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `ApsidesWorkshopTier.of(t)`: level-0 = spheres of 24 × 16 segments, 4 refinement
// points per tick, 2 glow shells; level-1 = 16 × 12 segments, 2 points, 1 glow shell; level-2 = flat 20-sided discs,
// chords only, no glow. Outcome: `won` or `failed` while the play is in that stage, else nil. Rules use integers only.
//
// Feature 475 (R02-G18-05) T-R02G1805-004 (FR-R02G1805-001, 004 … 007; clarifications Q2–Q5): the core also holds the
// player's progress (`ApsidesWorkshopProgress`: won levels with the least actions spent and stars, the open frontier),
// the mode (campaign, practice with the budget raised to the kernel's maximum 24, daily) and the tutorial step
// (`ApsidesWorkshopTutorialStep`). No level is ever gated by payment: a locked level is one not yet unlocked
// (FR-R02G1805-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g18.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g18.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 24 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh with tick 0 shown). `level.next`
// moves to the next open level in campaign mode and is refused with `r02-g18.locked` when there is none (100 does not
// wrap). A win (the play reaching `won` on an accepted `orbit.play` or redo) records
// `progress.record(level:actionsSpent:certified:mode:)` with the actions spent (`ApsidesWorkshopProgress.actionsSpent`:
// every accepted tuning record, undone ones included) against the certified witness's tuning count
// (`certifiedTunings`, the certified plan's size): campaign opens the next level, daily records the level's best result
// and stars and opens nothing, practice records nothing. The tutorial starts at
// `ApsidesWorkshopTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced after
// every accepted tuning, play, undo and redo by `advanced(afterTuning:ended:)` (afterTuning for a tuning; ended when
// the play is won or failed — an undo never ends it, a redo only when it restores a won or failed moment), never back;
// `clock.show` never moves it. The shown tick stays presentation. Digest "r02-g18.apsides-workshop.v2": level, play
// fingerprint, progress and mode (never the tutorial step or the shown tick). Snapshot schema 2:
// `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys; schema-1 payloads migrate (no won levels,
// level 1 open plus the levels up to the restored level, campaign mode, the tutorial at its first step — `knob` on the
// tutorial levels, else `done`); an envelope of a newer schema is refused.
//
// Feature 477 (R02-G18-07) T-R02G1807-003 (FR-R02G1807-001 … 007; clarifications Q1–Q5): a campaign or daily win
// records its winning trace (`ApsidesWorkshopReconciliation.netTrace` of the play's records: the effective tunings, an
// undone tuning left out unless redone, then the play) as a verified result; restore reconciles every result
// (`ApsidesWorkshopReconciliation.reconcile`, the frontier as saved) and exposes `reconciliationDropped` (not
// digested, not in `==`); the replay mode `replay(level)` plays a verified trace action by action:
//   replay.start [1…100]  a fresh play of that level in mode `replay(level)` (campaign budget) with the tutorial done
//                         (`r02-g18.no-replay` without a verified result with a trace); during a replay it restarts it;
//   replay.step           the next action of the trace, a tuning or finally the play (`r02-g18.replay-end` after the
//                         last or once the play ended; `r02-g18.no-replay` outside replay);
//   replay.stop           campaign at that level, the frontier when it is not open (`r02-g18.no-replay` outside
//                         replay);
//   settings.sound [0…1]  the sound choice: 1 on, 0 off; whole; allowed in every mode.
// In replay every other action except `tutorial.dismiss` and `clock.show` (presentation) and `settings.sound` is
// refused with `r02-g18.replay`, and nothing is recorded. A restored replay whose tuning and play records are not
// exactly the first actions of its level's verified trace (in order, no undo or redo) is refused as `damaged`; a
// restored replay whose result did not survive reconciliation, or was never verified, returns to campaign at that level
// (the frontier when it is not open). Digest "r02-g18.apsides-workshop.v3" (the same parts as v2, the progress now with
// traces; never the sound choice or the dropped count); snapshot schema 3 `{"level", "mode", "progress", "records",
// "sound", "tutorial"}` (results carry `trace` and `verified`), migrating 1 → 2 → 3 (2 → 3: every result an empty
// trace and `verified` false, sound off).
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Apsides Workshop's adapter refusals (feature 473; `locked` and `date` since feature 475).
public enum ApsidesWorkshopExperienceRule {
    /// A value that must be a whole number (a step, a size or a tick) and is not.
    public static let notWhole = "r02-g18.not-whole"
    /// A shown tick outside 0 … period − 1 of the level (`clock.show`).
    public static let tick = "r02-g18.tick"
    /// A level that is not open yet, or no next open level (feature 475). Never a payment gate.
    public static let locked = "r02-g18.locked"
    /// An impossible calendar date (`mode.daily`, feature 475).
    public static let date = "r02-g18.date"
    /// No verified result with a trace to replay, or a replay control outside replay (feature 477).
    public static let noReplay = "r02-g18.no-replay"
    /// The replay has no further action: the trace is over or the play ended (feature 477).
    public static let replayEnd = "r02-g18.replay-end"
    /// An action that is not allowed during replay (feature 477).
    public static let replay = "r02-g18.replay"
}

/// Why a saved Apsides Workshop state was refused on restore (feature 473). A refused restore changes nothing.
public enum ApsidesWorkshopRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 475).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(ApsidesWorkshopError)
}

/// The state of Apsides Workshop as an experience (see the file header). Snapshot schema 3.
public struct ApsidesWorkshopExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g18.apsides-workshop"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 3
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g18.apsides-workshop.v3"
    /// The action ids in declaration order.
    public static let actionIDs = ["orbit.periapsis", "orbit.size", "orbit.play", "play.undo", "play.redo",
                                   "level.next", "clock.show", "level.select", "mode.daily", "mode.practice",
                                   "mode.campaign", "tutorial.dismiss", "replay.start", "replay.step", "replay.stop",
                                   "settings.sound"]
    /// The declared range of `settings.sound`: 0 off, 1 on (feature 477).
    public static let soundRange: ClosedRange<Int> = 0...1
    /// The budget of a practice play: the kernel's maximum (`ApsidesWorkshopMode.practiceBudget`, 24).
    public static let practiceBudget: Int = ApsidesWorkshopMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a shown tick: the longest period any level allows (`ApsidesWorkshopLevel.periods`,
    /// 0 … 95).
    public static let tickRange: ClosedRange<Int> = 0...(ApsidesWorkshopLevel.periods.upperBound - 1)
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: ApsidesWorkshopPlay
    /// The player's progress (feature 475): in the digest and the snapshot.
    public private(set) var progress: ApsidesWorkshopProgress
    /// The mode (feature 475): in the digest and the snapshot.
    public private(set) var mode: ApsidesWorkshopMode
    /// The tutorial step (feature 475): in the snapshot and `==`, not in the digest.
    public private(set) var tutorial: ApsidesWorkshopTutorialStep
    /// The certified witness's tuning count of the current level (its certified plan's size), against which a win's
    /// stars are counted. Derived from the level number.
    public private(set) var certifiedTunings: Int
    /// How many saved results the last restore dropped because they did not verify (feature 477); not in the digest,
    /// the snapshot or `==`.
    public private(set) var reconciliationDropped = 0
    /// The player's sound choice (feature 477), set by `settings.sound`: in the snapshot (key `"sound"`) and `==`,
    /// never in the digest; off at an opening, after a reset and in a migrated save.
    public private(set) var soundOn = false
    /// The shown tick, 0 … period − 1; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownTick: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// What a reset restores (feature 475).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: ApsidesWorkshopPlay
        /// The opening progress: level 1 open plus the levels up to the opening level, none won.
        let progress: ApsidesWorkshopProgress
        /// The opening level's initial tutorial step.
        let tutorial: ApsidesWorkshopTutorialStep
        /// The opening level's certified witness tuning count.
        let certifiedTunings: Int
    }

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial` and tick 0 shown, whose
    /// reset returns to `opening` of `openingNumber`.
    init(levelNumber: Int, play: ApsidesWorkshopPlay, progress: ApsidesWorkshopProgress, mode: ApsidesWorkshopMode,
         tutorial: ApsidesWorkshopTutorialStep, certifiedTunings: Int, openingNumber: Int, opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedTunings = certifiedTunings
        self.shownTick = 0
        self.openingNumber = openingNumber
        self.opening = opening
    }

    /// The difficulty band (1 … 5) of the current level: 20 levels per band, the certified difficulty bands
    /// (`ApsidesWorkshopProgress.band(of:)`; feature 475).
    public var band: Int { ApsidesWorkshopProgress.band(of: levelNumber) }

    /// The level number a seed chooses: `seed % 100 + 1`.
    public static func levelNumber(forSeed seed: UInt64) -> Int {
        Int(seed % UInt64(levelNumbers.count)) + 1
    }

    /// The certified level of manifest number `number` (1 … 100).
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func level(number: Int) throws(ApsidesWorkshopError) -> ApsidesWorkshopLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 473).
    private static let generatedCache = Mutex<[Int: ApsidesWorkshopGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[ApsidesWorkshopGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/apsides-workshop/levels/NNN.witness.json`, read
    /// 2026-11-25).
    public static let certifiedCandidates: [Int] = [
        1, 2, 8, 2, 0, 3, 0, 0, 0, 0, 0, 0, 4, 1, 3, 1, 1, 1, 0, 3, 1, 1, 0, 0, 1,
        0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]

    /// Candidate `index` of `entry` certified as ``ApsidesWorkshopGenerator/generate(_:previous:)`` certifies a
    /// candidate (a valid candidate whose minimal plan lies in its band's range and within the budget, within the
    /// solver's work bound), and whose plan followed by the play wins through the kernel; nil otherwise. The neighbour
    /// rule is not checked here: the table names the candidate the generator kept under it.
    static func certify(_ entry: ApsidesWorkshopManifestEntry, index: Int) -> ApsidesWorkshopGenerated? {
        let range: ClosedRange<Int> = ApsidesWorkshopBandProfile.of(band: entry.band).planRange
        guard let level = ApsidesWorkshopGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = ApsidesWorkshopSolver.plan(level) else { return nil }
        guard range.contains(plan.size), plan.size <= entry.budget else { return nil }
        guard ApsidesWorkshopSolver.replayWins(level, actions: plan.actions) else { return nil }
        return ApsidesWorkshopGenerated(entry: entry, level: level, plan: plan,
                                        difficulty: ApsidesWorkshopDifficulty(level: level, plan: plan),
                                        skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(ApsidesWorkshopError) -> ApsidesWorkshopGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: ApsidesWorkshopManifestEntry = ApsidesWorkshopManifest.entries[number - 1]
        let fresh: ApsidesWorkshopGenerated
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
    static func catalog() throws(ApsidesWorkshopError) -> [ApsidesWorkshopGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [ApsidesWorkshopGenerated] = try ApsidesWorkshopGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: ApsidesWorkshopLevel) throws(ApsidesWorkshopError) -> ApsidesWorkshopPlay {
        var play = ApsidesWorkshopPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The practice copy of `level` (feature 475): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: ApsidesWorkshopLevel)
        throws(ApsidesWorkshopError) -> ApsidesWorkshopLevel {
        try ApsidesWorkshopLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, period: level.period,
                                 planets: level.planets, targets: level.targets, orbit: level.orbit,
                                 budget: ApsidesWorkshopMode.practice.budget(base: level.budget),
                                 tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: ApsidesWorkshopGenerated, mode: ApsidesWorkshopMode)
        throws(ApsidesWorkshopError) -> ApsidesWorkshopLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with tick 0 shown; campaign mode, level 1 open plus the levels up to `number`, none won, the
    /// tutorial at its first step (feature 475).
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(ApsidesWorkshopError) -> ApsidesWorkshopExperienceCore {
        let certified: ApsidesWorkshopGenerated = try generated(number: number)
        let play: ApsidesWorkshopPlay = try freshPlay(of: certified.level)
        var progress: ApsidesWorkshopProgress = ApsidesWorkshopProgress()
        progress.open(through: number)
        let tutorial: ApsidesWorkshopTutorialStep = ApsidesWorkshopTutorialStep.initial(level: number)
        let tunings: Int = certified.plan.size
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedTunings: tunings)
        return ApsidesWorkshopExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                             tutorial: tutorial, certifiedTunings: tunings, openingNumber: number,
                                             opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (orbit steps, the kernel's positions, the ghost loop, the orbiter at the shown
    /// tick, shares, apsis readings, planets, gauges, failure, shown tick, period, stage, actions left and budget) with
    /// the level number, for drawing at the presenter's presentation time `time` (a non-finite or negative time becomes
    /// 0). Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> ApsidesWorkshopSceneSnapshot {
        ApsidesWorkshopSceneSnapshot(play: play, shownTick: shownTick, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `ApsidesWorkshopTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: ApsidesWorkshopTier { ApsidesWorkshopTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `ApsidesWorkshopTier.all`.
    public static var qualityTiers: Int { ApsidesWorkshopTier.all.count }

    /// The faces of one sphere at `tier`: longitudes × latitudes for a sphere, the disc's sides for a flat disc.
    static func sphereFaces(_ tier: ApsidesWorkshopTier) -> Int {
        tier.flatSpheres ? ApsidesWorkshopTier.discSides : tier.longitudes * tier.latitudes
    }

    /// One level per host tier, best first, named as `ApsidesWorkshopTier.all`: the element share is a sphere's faces
    /// over the best tier's (1, 0.5, 20 / 384), the iteration share the orbit loop's refinement points over the best
    /// tier's (1, 0.5, 0), the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: ApsidesWorkshopTier = ApsidesWorkshopTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<ApsidesWorkshopTier.all.count {
            let tier: ApsidesWorkshopTier = ApsidesWorkshopTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(sphereFaces(tier)) / Double(sphereFaces(best)),
                                       iterationShare: Double(tier.refinement) / Double(best.refinement),
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
    public static func == (lhs: ApsidesWorkshopExperienceCore, rhs: ApsidesWorkshopExperienceCore) -> Bool {
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

    /// The schema-3 object of a schema-2 object (feature 477): every won result gains an empty `trace` and `verified`
    /// false, and the sound choice is off.
    ///
    /// - Throws: ``ApsidesWorkshopRestoreRefusal/damaged`` when `object` has no progress with a solved list.
    public static func migratedToSchemaThree(_ object: [String: Any]) throws -> [String: Any] {
        guard var progress = object["progress"] as? [String: Any], let solved = progress["solved"] as? [Any] else {
            throw ApsidesWorkshopRestoreRefusal.damaged
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

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 475): no won levels with level 1 open
    /// plus the levels up to the restored level, campaign mode, no tutorial key (restore starts the tutorial at its
    /// first step: `knob` on the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``ApsidesWorkshopRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw ApsidesWorkshopRestoreRefusal.damaged
        }
        var progress: ApsidesWorkshopProgress = ApsidesWorkshopProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(ApsidesWorkshopMode.campaign))
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
        ExperienceControl(id: "orbit.periapsis",
                          ranges: [declared(ApsidesWorkshopOrbit.eccentricities),
                                   declared(ApsidesWorkshopOrbit.directions)]),
        ExperienceControl(id: "orbit.size", ranges: [declared(ApsidesWorkshopOrbit.sizes)]),
        ExperienceControl(id: "orbit.play"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "clock.show", ranges: [declared(tickRange)]),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(ApsidesWorkshopProgress.dailyYears), 1...12, 1...31]),
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

    /// The sixteen controls with their declared ranges (see the file header); `orbit.play`, `play.undo`, `play.redo`,
    /// `level.next`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`, `replay.step` and `replay.stop` take no
    /// values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with tick 0 shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> ApsidesWorkshopExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(ApsidesWorkshopError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Apsides Workshop level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the orbit changes only on an action, and the star pulses with the presenter's
    /// time, not the state.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        if case .replay = mode, !Self.replayControls.contains(action.control) {
            return .rejected(.rule(code: ApsidesWorkshopExperienceRule.replay))
        }
        var values: [Int] = []
        for value in action.values {
            guard let whole = Self.whole(value) else {
                return .rejected(.rule(code: ApsidesWorkshopExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(ApsidesWorkshopError) {
            switch action.control {
            case "orbit.periapsis":
                // The shown tick stays (presentation of the same level; the period does not change).
                try play.apply(.periapsis(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterTuning: true)
            case "orbit.size":
                try play.apply(.size(values[0]), expecting: play.fingerprint)
                advanceTutorial(afterTuning: true)
            case "orbit.play":
                try play.apply(.play, expecting: play.fingerprint)
                advanceTutorial(afterTuning: false)
                recordIfWon()
            case "play.undo":
                try play.undo()
                advanceTutorial(afterTuning: false)
            case "play.redo":
                try play.redo()
                advanceTutorial(afterTuning: false)
                recordIfWon()
            case "clock.show":
                // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                guard values[0] < play.level.period else {
                    return .rejected(.rule(code: ApsidesWorkshopExperienceRule.tick))
                }
                shownTick = values[0]
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: ApsidesWorkshopExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: ApsidesWorkshopExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = ApsidesWorkshopProgress.dailyLevel(year: values[0], month: values[1],
                                                                     day: values[2]) else {
                    return .rejected(.rule(code: ApsidesWorkshopExperienceRule.date))
                }
                try open(number: daily, mode: .daily(level: daily))
            case "mode.practice":
                try open(number: levelNumber, mode: .practice)
            case "mode.campaign":
                try open(number: progress.isOpen(levelNumber) ? levelNumber : progress.frontier, mode: .campaign)
            case "replay.start":
                guard let result = progress.solved[values[0]], result.verified, !result.trace.isEmpty else {
                    return .rejected(.rule(code: ApsidesWorkshopExperienceRule.noReplay))
                }
                try open(number: values[0], mode: .replay(level: values[0]))
                tutorial = .done
            case "replay.step":
                guard case .replay(let level) = mode, let result = progress.solved[level], result.verified else {
                    return .rejected(.rule(code: ApsidesWorkshopExperienceRule.noReplay))
                }
                // Replay never undoes, so each trace action made exactly one tuning or play record (a fresh play also
                // holds its begin and tutorial records, which are not counted).
                let index: Int = Self.actionRecordCount(play.records)
                guard play.stage == .playing, index < result.trace.count else {
                    return .rejected(.rule(code: ApsidesWorkshopExperienceRule.replayEnd))
                }
                try play.apply(result.trace[index], expecting: play.fingerprint)
            case "replay.stop":
                guard case .replay(let level) = mode else {
                    return .rejected(.rule(code: ApsidesWorkshopExperienceRule.noReplay))
                }
                try open(number: progress.isOpen(level) ? level : progress.frontier, mode: .campaign)
            case "settings.sound":
                soundOn = values[0] == 1
            default:   // tutorial.dismiss
                tutorial = tutorial.dismissed()
            }
        } catch {
            return .rejected(.rule(code: error.reasonCode))
        }
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Advances the tutorial step after an accepted tuning, play, undo or redo
    /// (`ApsidesWorkshopTutorialStep.advanced(afterTuning:ended:)`): `afterTuning` for a tuning, ended when the play is
    /// won or failed (never after an undo, which always lands on a moment before the end; after a redo only when it
    /// restores a won or failed moment). Never back.
    private mutating func advanceTutorial(afterTuning: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterTuning: afterTuning, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step and tick 0 shown; the records of the level left are dropped. Changes nothing when the kernel
    /// refuses.
    private mutating func open(number: Int, mode: ApsidesWorkshopMode) throws(ApsidesWorkshopError) {
        let certified: ApsidesWorkshopGenerated = try Self.generated(number: number)
        let fresh: ApsidesWorkshopPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedTunings = certified.plan.size
        tutorial = ApsidesWorkshopTutorialStep.initial(level: number)
        shownTick = 0
    }

    /// After an accepted action that won the play: records the actions spent
    /// (`ApsidesWorkshopProgress.actionsSpent(_:)`) against the certified witness's tuning count in the current mode
    /// (campaign opens the next level; daily records the best result and stars and opens nothing; practice records
    /// nothing). A won play is final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        if case .replay = mode { return }
        progress.record(level: levelNumber, actionsSpent: ApsidesWorkshopProgress.actionsSpent(play),
                        certified: certifiedTunings, mode: mode, trace: winningTrace)
    }

    /// The controls accepted during replay (feature 477).
    static let replayControls: Set<String> = ["replay.start", "replay.step", "replay.stop", "tutorial.dismiss",
                                              "clock.show", "settings.sound"]

    /// The winning trace of the current play (feature 477): its effective tunings in order, then the play
    /// (``ApsidesWorkshopReconciliation/netTrace(_:)``), never an undo or a redo.
    var winningTrace: [ApsidesWorkshopAction] { ApsidesWorkshopReconciliation.netTrace(play.records) }

    /// The number of tuning and play records among `records` (feature 477): the trace actions a replay applied.
    static func actionRecordCount(_ records: [ApsidesWorkshopRecord]) -> Int {
        var count: Int = 0
        for record in records where record.kind == .periapsis || record.kind == .size || record.kind == .play {
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
        certifiedTunings = opening.certifiedTunings
        soundOn = false
        shownTick = 0
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g18.apsides-workshop.v3", then the level number, the play's fingerprint (actions spent, failure, level,
    /// orbit, stage), the progress (with its traces) and the mode (their sorted JSON); never the tutorial step, the
    /// shown tick, the sound choice or the dropped count.
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
        var mode: ApsidesWorkshopMode
        /// The progress.
        var progress: ApsidesWorkshopProgress
        /// The play's records.
        var records: [ApsidesWorkshopRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: ApsidesWorkshopTutorialStep?
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
    /// practice mode) with the saved progress (reconciled: a result whose trace does not verify is dropped and counted
    /// in ``reconciliationDropped``), mode, tutorial step (the first step when absent) and sound choice (off when
    /// absent), with tick 0 shown; a reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``ApsidesWorkshopRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or tutorial
    ///   step, or a daily mode naming another level among them), a level number outside 1 … 100 or a level or trace
    ///   the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> ApsidesWorkshopExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw ApsidesWorkshopRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw ApsidesWorkshopRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw ApsidesWorkshopRestoreRefusal.damaged
        }
        if case .replay(let replayed) = decoded.mode, replayed != decoded.level {
            throw ApsidesWorkshopRestoreRefusal.damaged
        }
        // Feature 477: a saved replay's tuning and play records are exactly the first actions of its level's saved
        // trace — in order, no undo or redo — or the payload is damaged.
        if case .replay(let replayed) = decoded.mode, let saved = decoded.progress.solved[replayed], saved.verified {
            var applied: [ApsidesWorkshopAction] = []
            for record in decoded.records {
                switch record.kind {
                case .periapsis, .size, .play:
                    guard let action = record.action else { throw ApsidesWorkshopRestoreRefusal.damaged }
                    applied.append(action)
                case .undo, .redo:
                    throw ApsidesWorkshopRestoreRefusal.damaged
                default:
                    continue
                }
            }
            guard applied.count <= saved.trace.count, Array(saved.trace.prefix(applied.count)) == applied else {
                throw ApsidesWorkshopRestoreRefusal.damaged
            }
        }
        do throws(ApsidesWorkshopError) {
            let certified: ApsidesWorkshopGenerated = try generated(number: decoded.level)
            let play: ApsidesWorkshopPlay = try ApsidesWorkshopPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: ApsidesWorkshopTutorialStep = decoded.tutorial
                ?? ApsidesWorkshopTutorialStep.initial(level: decoded.level)
            let openingCore: ApsidesWorkshopExperienceCore = try opening(number: levelNumber(forSeed: seed))
            // Feature 477: every saved result is checked by replaying its trace; the frontier stays as saved.
            let reconciled = ApsidesWorkshopReconciliation.reconcile(decoded.progress)
            var core: ApsidesWorkshopExperienceCore = ApsidesWorkshopExperienceCore(
                levelNumber: decoded.level, play: play, progress: reconciled.progress, mode: decoded.mode,
                tutorial: tutorial, certifiedTunings: certified.plan.size, openingNumber: openingCore.openingNumber,
                opening: openingCore.opening)
            core.reconciliationDropped = reconciled.dropped
            core.soundOn = decoded.sound ?? false
            // A replay whose result did not survive the check returns to campaign at that level (or the frontier).
            if case .replay(let level) = decoded.mode, reconciled.progress.solved[level]?.verified != true {
                try core.open(number: core.progress.isOpen(level) ? level : core.progress.frontier, mode: .campaign)
            }
            return core
        } catch {
            throw ApsidesWorkshopRestoreRefusal.kernel(error)
        }
    }
}
