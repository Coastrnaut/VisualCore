// CelestialEclipseLabExperienceCore — feature 463 (R02-G17-03) T-R02G1703-005 (FR-R02G1703-003, 005; SC-R02G1703-002,
// 004; clarifications Q1, Q4, Q5; data-model.md; contracts/api.md). The adapter of the Celestial Eclipse Lab kernel to
// the shared experience contract. The core holds the level number, the kernel's `CelestialEclipseLabPlay`, the chosen
// body and the shown tick; it never draws and reads no clock. The presenter asks for an immutable
// `CelestialEclipseLabSceneSnapshot` at its own presentation time (`snapshot(time:)`), so the halos can pulse while the
// state and its digest stay put (renderer purity). The snapshot carries the kernel's body positions at the shown tick
// for the current phases, the eclipses under way at that tick and the kernel's predicted timeline, so the drawn bodies
// are the kernel's positions and no drawn value decides an eclipse, a match or the verdict. The chosen body and the
// shown tick are presentation state of the adapter (`orbit.choose [body]`, `clock.show [tick]`): at an opening, after
// `level.next`, a reset and a restore they are `CelestialEclipseLabSceneSnapshot.defaultChoice(level)` (the
// lowest-numbered movable body, clarification Q1) and tick 0; a phase change, the run, undo and redo keep both; never
// in the digest, the snapshot payload or `==`. Modelled on `StarlitCartoucheExperienceCore` (feature 453).
//
// Preparation: the certified level number `seed % 100 + 1` of `CelestialEclipseLabManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole catalog (`CelestialEclipseLabGenerator.catalog()`, once per process) only if that candidate no
// longer certifies; begun (and its tutorial dismissed, as `CelestialEclipseLabSolver.wins` does) so the play is in
// stage `playing`. The tutorial of levels 1 … 3 is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   orbit.phase [0…5, 0…23]  a body and its new phase offset, whole numbers (`r02-g17.not-whole` otherwise); one phase
//                            change (1 action); an unknown or fixed body, an offset outside the body's period or equal
//                            to its current phase are the kernel's `r02-g17.action`; no action left is
//                            `r02-g17.budget`;
//   clock.run                the run that ends the level (no action spent): `won` when the predicted timeline wins,
//                            else `failed` with its failure;
//   play.undo, play.redo     the kernel's exact undo and redo (`r02-g17.action` when there is nothing to undo or redo;
//                            undo works in a failed play and returns it to playing; a won play is final);
//   level.next               the next certified level with a fresh play (since feature 465 the next open level; see
//                            below);
//   orbit.choose [0…5]       chooses the shown body (presentation only; accepted in every stage); a body the level
//                            lacks is refused `r02-g17.choice` without touching the kernel;
//   clock.show [0…95]        shows the sky at a tick (presentation only; accepted in every stage); a tick outside
//                            0 … horizon − 1 of the level is refused `r02-g17.tick` without touching the kernel.
// The declared body range is the widest any level allows (`CelestialEclipseLabLevel.bodyCounts`: at most 6 bodies, so
// bodies 0 … 5), the offset range the longest period (`CelestialEclipseLabLevel.periods`: offsets 0 … 23) and the tick
// range the longest horizon (`CelestialEclipseLabLevel.horizons`: ticks 0 … 95); the kernel or the adapter refuses the
// values a level lacks. Outside stage `playing` the kernel refuses a phase change and the run with `r02-g17.stage`.
// Every action is applied with the play's fingerprint as the expected one, so `r02-g17.stale` cannot arise. A kernel
// refusal (`CelestialEclipseLabError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing, the
// chosen body and the shown tick included.
//
// Digest ("r02-g17.celestial-eclipse-lab.v1" until feature 465): the level number and the play's fingerprint (not its
// record history, so undo restores the earlier digest exactly); never the chosen body, the shown tick, the quality tier
// or a time. Snapshot schema 1: the JSON object `{"level", "records"}` with sorted keys; restoring replays the records
// on a fresh play of that level (`CelestialEclipseLabPlay.replay`), resets the presentation state and throws
// `CelestialEclipseLabRestoreRefusal` for a damaged payload, a level number outside 1 … 100 or a trace the kernel
// refuses (a record of a newer schema or of another level's seed among them). An envelope of a newer schema is refused
// by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `CelestialEclipseLabTier.of(t)`: level-0 = body spheres of 24 × 16 segments, 2 glow
// shells; level-1 = 16 × 12 segments, 1 glow shell; level-2 = flat 20-sided discs, no glow. Outcome: `won` or `failed`
// while the play is in that stage, else nil. Rules use integers only.
//
// Feature 465 (R02-G17-05) T-R02G1705-004 (FR-R02G1705-001, 004 … 006; clarifications Q3–Q5): the core also holds the
// player's progress (`CelestialEclipseLabProgress`: won levels with the least actions spent and stars, the open
// frontier), the mode (campaign, practice with the budget raised to the kernel's maximum 24, daily) and the tutorial
// step (`CelestialEclipseLabTutorialStep`). No level is ever gated by payment: a locked level is one not yet unlocked
// (FR-R02G1705-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g17.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g17.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 24 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh with the default presentation).
// `level.next` moves to the next open level in campaign mode and is refused with `r02-g17.locked` when there is none
// (100 does not wrap). A win (the play reaching `won` on an accepted run or redo) records
// `progress.record(level:actionsSpent:certified:mode:)` with the actions spent (`CelestialEclipseLabProgress
// .actionsSpent`: every phase-change record, undone ones included) against the certified witness's phase-change count
// (`certifiedChanges`, the certified plan's size): campaign opens the next level, daily records the level's best result
// and stars and opens nothing, practice records nothing. The tutorial starts at
// `CelestialEclipseLabTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced after
// every accepted phase change, run, undo and redo by `advanced(afterChange:ended:)` (afterChange for a phase change;
// ended when the play is won or failed — an undo never ends it, a redo only when it restores a won or failed moment),
// never back; `orbit.choose` and `clock.show` never move it. The chosen body and the shown tick stay presentation.
// Digest "r02-g17.celestial-eclipse-lab.v2": level, play fingerprint, progress and mode (never the tutorial step, the
// chosen body or the shown tick). Snapshot schema 2: `{"level", "mode", "progress", "records", "tutorial"}` with
// sorted keys; schema-1 payloads migrate (no won levels, level 1 open plus the levels up to the restored level,
// campaign mode, the tutorial at its first step — `phase` on the tutorial levels, else `done`); an envelope of a newer
// schema is refused.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Celestial Eclipse Lab's adapter refusals (feature 463; `locked` and `date` since feature 465).
public enum CelestialEclipseLabExperienceRule {
    /// A value that must be a whole number (a body, an offset or a tick) and is not.
    public static let notWhole = "r02-g17.not-whole"
    /// A chosen body the level does not have (`orbit.choose`).
    public static let choice = "r02-g17.choice"
    /// A shown tick outside 0 … horizon − 1 of the level (`clock.show`).
    public static let tick = "r02-g17.tick"
    /// A level that is not open yet, or no next open level (feature 465). Never a payment gate.
    public static let locked = "r02-g17.locked"
    /// An impossible calendar date (`mode.daily`, feature 465).
    public static let date = "r02-g17.date"
}

/// Why a saved Celestial Eclipse Lab state was refused on restore (feature 463). A refused restore changes nothing.
public enum CelestialEclipseLabRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 465).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(CelestialEclipseLabError)
}

/// The state of Celestial Eclipse Lab as an experience (see the file header). Snapshot schema 2.
public struct CelestialEclipseLabExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g17.celestial-eclipse-lab"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g17.celestial-eclipse-lab.v2"
    /// The action ids in declaration order.
    public static let actionIDs = ["orbit.phase", "clock.run", "play.undo", "play.redo", "level.next", "orbit.choose",
                                   "clock.show", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                                   "tutorial.dismiss"]
    /// The budget of a practice play: the kernel's maximum (`CelestialEclipseLabMode.practiceBudget`, 24).
    public static let practiceBudget: Int = CelestialEclipseLabMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a body: the most bodies any level has (`CelestialEclipseLabLevel.bodyCounts`, 0 … 5).
    public static let bodyRange: ClosedRange<Int> = 0...(CelestialEclipseLabLevel.bodyCounts.upperBound - 1)
    /// The declared range of a phase offset: the longest period any body has (`CelestialEclipseLabLevel.periods`,
    /// 0 … 23).
    public static let offsetRange: ClosedRange<Int> = 0...(CelestialEclipseLabLevel.periods.upperBound - 1)
    /// The declared range of a shown tick: the longest horizon any level has (`CelestialEclipseLabLevel.horizons`,
    /// 0 … 95).
    public static let tickRange: ClosedRange<Int> = 0...(CelestialEclipseLabLevel.horizons.upperBound - 1)
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: CelestialEclipseLabPlay
    /// The player's progress (feature 465): in the digest and the snapshot.
    public private(set) var progress: CelestialEclipseLabProgress
    /// The mode (feature 465): in the digest and the snapshot.
    public private(set) var mode: CelestialEclipseLabMode
    /// The tutorial step (feature 465): in the snapshot and `==`, not in the digest.
    public private(set) var tutorial: CelestialEclipseLabTutorialStep
    /// The certified witness's phase-change count of the current level (its certified plan's size), against which a
    /// win's stars are counted. Derived from the level number.
    public private(set) var certifiedChanges: Int
    /// The chosen body, one the level has; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var chosenBody: Int
    /// The shown tick, 0 … horizon − 1; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownTick: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// What a reset restores (feature 465).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: CelestialEclipseLabPlay
        /// The opening progress: level 1 open plus the levels up to the opening level, none won.
        let progress: CelestialEclipseLabProgress
        /// The opening level's initial tutorial step.
        let tutorial: CelestialEclipseLabTutorialStep
        /// The opening level's certified witness phase-change count.
        let certifiedChanges: Int
    }

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial` and the default
    /// presentation (the default body, tick 0), whose reset returns to `opening` of `openingNumber`.
    init(levelNumber: Int, play: CelestialEclipseLabPlay, progress: CelestialEclipseLabProgress,
         mode: CelestialEclipseLabMode, tutorial: CelestialEclipseLabTutorialStep, certifiedChanges: Int,
         openingNumber: Int, opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedChanges = certifiedChanges
        self.chosenBody = CelestialEclipseLabSceneSnapshot.defaultChoice(play.level)
        self.shownTick = 0
        self.openingNumber = openingNumber
        self.opening = opening
    }

    /// The difficulty band (1 … 5) of the current level: 20 levels per band, the certified difficulty bands
    /// (`CelestialEclipseLabProgress.band(of:)`; feature 465).
    public var band: Int { CelestialEclipseLabProgress.band(of: levelNumber) }

    /// The level number a seed chooses: `seed % 100 + 1`.
    public static func levelNumber(forSeed seed: UInt64) -> Int {
        Int(seed % UInt64(levelNumbers.count)) + 1
    }

    /// The certified level of manifest number `number` (1 … 100).
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func level(number: Int) throws(CelestialEclipseLabError) -> CelestialEclipseLabLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 463).
    private static let generatedCache = Mutex<[Int: CelestialEclipseLabGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[CelestialEclipseLabGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/celestial-eclipse-lab/levels/NNN.witness.json`, read
    /// 2026-11-25).
    public static let certifiedCandidates: [Int] = [
        0, 0, 1, 0, 0, 0, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1,
        0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 1, 1, 1, 0, 3, 3, 1,
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0,
        0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 1, 0, 4, 2, 1, 0, 0, 0, 0,
    ]

    /// Candidate `index` of `entry` certified as ``CelestialEclipseLabGenerator/generate(_:previous:)`` certifies a
    /// candidate (a valid candidate whose minimal plan lies in its band's range and within the budget, within the
    /// solver's work bound), and whose plan followed by the run wins through the kernel; nil otherwise. The neighbour
    /// rule is not checked here: the table names the candidate the generator kept under it.
    static func certify(_ entry: CelestialEclipseLabManifestEntry, index: Int) -> CelestialEclipseLabGenerated? {
        let range: ClosedRange<Int> = CelestialEclipseLabBandProfile.of(band: entry.band).planRange
        guard let level = CelestialEclipseLabGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = CelestialEclipseLabSolver.plan(level, maxChanges: range.upperBound) else { return nil }
        guard range.contains(plan.size), plan.size <= entry.budget else { return nil }
        guard CelestialEclipseLabSolver.wins(level, actions: plan.actions) else { return nil }
        return CelestialEclipseLabGenerated(entry: entry, level: level, plan: plan,
                                            difficulty: CelestialEclipseLabDifficulty(level: level, plan: plan),
                                            skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(CelestialEclipseLabError) -> CelestialEclipseLabGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: CelestialEclipseLabManifestEntry = CelestialEclipseLabManifest.entries[number - 1]
        let fresh: CelestialEclipseLabGenerated
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
    static func catalog() throws(CelestialEclipseLabError) -> [CelestialEclipseLabGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [CelestialEclipseLabGenerated] = try CelestialEclipseLabGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: CelestialEclipseLabLevel)
        throws(CelestialEclipseLabError) -> CelestialEclipseLabPlay {
        var play = CelestialEclipseLabPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The practice copy of `level` (feature 465): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: CelestialEclipseLabLevel)
        throws(CelestialEclipseLabError) -> CelestialEclipseLabLevel {
        try CelestialEclipseLabLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, bodies: level.bodies,
                                     horizon: level.horizon, target: level.target, phases: level.phases,
                                     budget: CelestialEclipseLabMode.practice.budget(base: level.budget),
                                     tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: CelestialEclipseLabGenerated, mode: CelestialEclipseLabMode)
        throws(CelestialEclipseLabError) -> CelestialEclipseLabLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with the default body chosen and tick 0 shown; campaign mode, level 1 open plus the levels up to
    /// `number`, none won, the tutorial at its first step (feature 465).
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(CelestialEclipseLabError) -> CelestialEclipseLabExperienceCore {
        let certified: CelestialEclipseLabGenerated = try generated(number: number)
        let play: CelestialEclipseLabPlay = try freshPlay(of: certified.level)
        var progress: CelestialEclipseLabProgress = CelestialEclipseLabProgress()
        progress.open(through: number)
        let tutorial: CelestialEclipseLabTutorialStep = CelestialEclipseLabTutorialStep.initial(level: number)
        let changes: Int = certified.plan.size
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedChanges: changes)
        return CelestialEclipseLabExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                                 tutorial: tutorial, certifiedChanges: changes, openingNumber: number,
                                                 opening: opening)
    }

    /// Sets the presentation to the default: the lowest-numbered movable body
    /// (``CelestialEclipseLabSceneSnapshot/defaultChoice(_:)``) and tick 0.
    private mutating func resetPresentation() {
        chosenBody = CelestialEclipseLabSceneSnapshot.defaultChoice(play.level)
        shownTick = 0
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (bodies, phases, positions and eclipses at the shown tick, target, predicted
    /// intervals, matched count, failure, shown tick, horizon, chosen body, stage, actions left and budget) with the
    /// level number, for drawing at the presenter's presentation time `time` (a non-finite or negative time becomes 0).
    /// Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> CelestialEclipseLabSceneSnapshot {
        CelestialEclipseLabSceneSnapshot(play: play, chosenBody: chosenBody, shownTick: shownTick,
                                         levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `CelestialEclipseLabTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: CelestialEclipseLabTier { CelestialEclipseLabTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `CelestialEclipseLabTier.all`.
    public static var qualityTiers: Int { CelestialEclipseLabTier.all.count }

    /// The faces of one body at `tier`: longitudes × latitudes for a sphere, the disc's sides for a flat disc.
    static func bodyFaces(_ tier: CelestialEclipseLabTier) -> Int {
        tier.flatBodies ? CelestialEclipseLabTier.discSides : tier.longitudes * tier.latitudes
    }

    /// One level per host tier, best first, named as `CelestialEclipseLabTier.all`: the element share is a body's faces
    /// over the best tier's (1, 0.5, 20 / 384), the iteration share the glow shells over the best tier's (1, 0.5, 0),
    /// the effect passes the glow shells; every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: CelestialEclipseLabTier = CelestialEclipseLabTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<CelestialEclipseLabTier.all.count {
            let tier: CelestialEclipseLabTier = CelestialEclipseLabTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(bodyFaces(tier)) / Double(bodyFaces(best)),
                                       iterationShare: Double(tier.glowShells) / Double(best.glowShells),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode and the tutorial step (not the chosen body,
    /// the shown tick, the quality tier or the opening level).
    public static func == (lhs: CelestialEclipseLabExperienceCore, rhs: CelestialEclipseLabExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial
    }

    // MARK: Contract

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``); a payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) }])
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 465): no won levels with level 1 open
    /// plus the levels up to the restored level, campaign mode, no tutorial key (restore starts the tutorial at its
    /// first step: `phase` on the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``CelestialEclipseLabRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw CelestialEclipseLabRestoreRefusal.damaged
        }
        var progress: CelestialEclipseLabProgress = CelestialEclipseLabProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(CelestialEclipseLabMode.campaign))
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
        ExperienceControl(id: "orbit.phase", ranges: [declared(bodyRange), declared(offsetRange)]),
        ExperienceControl(id: "clock.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "orbit.choose", ranges: [declared(bodyRange)]),
        ExperienceControl(id: "clock.show", ranges: [declared(tickRange)]),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(CelestialEclipseLabProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The twelve controls with their declared ranges (see the file header); `clock.run`, `play.undo`, `play.redo`,
    /// `level.next`, `mode.practice`, `mode.campaign` and `tutorial.dismiss` take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with the default presentation; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> CelestialEclipseLabExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(CelestialEclipseLabError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Celestial Eclipse Lab level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the timeline changes only on an action, and the halos pulse with the presenter's
    /// time, not the state.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        var values: [Int] = []
        for value in action.values {
            guard let whole = Self.whole(value) else {
                return .rejected(.rule(code: CelestialEclipseLabExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(CelestialEclipseLabError) {
            switch action.control {
            case "orbit.phase":
                // The chosen body and the shown tick stay (presentation of the same level).
                try play.apply(.phase(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterChange: true)
            case "clock.run":
                try play.apply(.run, expecting: play.fingerprint)
                advanceTutorial(afterChange: false)
                recordIfWon()
            case "play.undo":
                try play.undo()
                advanceTutorial(afterChange: false)
            case "play.redo":
                try play.redo()
                advanceTutorial(afterChange: false)
                recordIfWon()
            case "orbit.choose":
                // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                guard values[0] < play.level.bodies.count else {
                    return .rejected(.rule(code: CelestialEclipseLabExperienceRule.choice))
                }
                chosenBody = values[0]
            case "clock.show":
                // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                guard values[0] < play.level.horizon else {
                    return .rejected(.rule(code: CelestialEclipseLabExperienceRule.tick))
                }
                shownTick = values[0]
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: CelestialEclipseLabExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: CelestialEclipseLabExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = CelestialEclipseLabProgress.dailyLevel(year: values[0], month: values[1],
                                                                         day: values[2]) else {
                    return .rejected(.rule(code: CelestialEclipseLabExperienceRule.date))
                }
                try open(number: daily, mode: .daily(level: daily))
            case "mode.practice":
                try open(number: levelNumber, mode: .practice)
            case "mode.campaign":
                try open(number: progress.isOpen(levelNumber) ? levelNumber : progress.frontier, mode: .campaign)
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

    /// Advances the tutorial step after an accepted phase change, run, undo or redo
    /// (`CelestialEclipseLabTutorialStep.advanced(afterChange:ended:)`): `afterChange` for a phase change, ended when
    /// the play is won or failed (never after an undo, which always lands on a moment before the end; after a redo only
    /// when it restores a won or failed moment). Never back.
    private mutating func advanceTutorial(afterChange: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterChange: afterChange, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step and the default presentation; the records of the level left are dropped. Changes nothing when the
    /// kernel refuses.
    private mutating func open(number: Int, mode: CelestialEclipseLabMode) throws(CelestialEclipseLabError) {
        let certified: CelestialEclipseLabGenerated = try Self.generated(number: number)
        let fresh: CelestialEclipseLabPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedChanges = certified.plan.size
        tutorial = CelestialEclipseLabTutorialStep.initial(level: number)
        resetPresentation()
    }

    /// After an accepted action that won the play: records the actions spent
    /// (`CelestialEclipseLabProgress.actionsSpent(_:)`) against the certified witness's phase-change count in the
    /// current mode (campaign opens the next level; daily records the best result and stars and opens nothing;
    /// practice records nothing). A won play is final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        _ = progress.record(level: levelNumber, actionsSpent: CelestialEclipseLabProgress.actionsSpent(play),
                            certified: certifiedChanges, mode: mode)
    }

    /// Back to the opening state the seed chose (progress included, campaign mode, the default presentation); the
    /// quality tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedChanges = opening.certifiedChanges
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

    /// "r02-g17.celestial-eclipse-lab.v2", then the level number, the play's fingerprint (actions spent, failure,
    /// level, phases, stage), the progress and the mode (their sorted JSON); never the tutorial step, the chosen body
    /// or the shown tick.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // chosen body or the shown tick (presentation) or the tutorial step.
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
        var mode: CelestialEclipseLabMode
        /// The progress.
        var progress: CelestialEclipseLabProgress
        /// The play's records.
        var records: [CelestialEclipseLabRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: CelestialEclipseLabTutorialStep?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, tutorial: tutorial))
    }

    /// The core of `payload` (schema 2): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the saved progress, mode and tutorial step (the first step when absent), with the default
    /// presentation; a reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``CelestialEclipseLabRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or
    ///   tutorial step, or a daily mode naming another level among them), a level number outside 1 … 100 or a level
    ///   or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> CelestialEclipseLabExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw CelestialEclipseLabRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw CelestialEclipseLabRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw CelestialEclipseLabRestoreRefusal.damaged
        }
        do throws(CelestialEclipseLabError) {
            let certified: CelestialEclipseLabGenerated = try generated(number: decoded.level)
            let play: CelestialEclipseLabPlay = try CelestialEclipseLabPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: CelestialEclipseLabTutorialStep = decoded.tutorial
                ?? CelestialEclipseLabTutorialStep.initial(level: decoded.level)
            let openingCore: CelestialEclipseLabExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return CelestialEclipseLabExperienceCore(levelNumber: decoded.level, play: play,
                                                     progress: decoded.progress, mode: decoded.mode,
                                                     tutorial: tutorial, certifiedChanges: certified.plan.size,
                                                     openingNumber: openingCore.openingNumber,
                                                     opening: openingCore.opening)
        } catch {
            throw CelestialEclipseLabRestoreRefusal.kernel(error)
        }
    }
}
