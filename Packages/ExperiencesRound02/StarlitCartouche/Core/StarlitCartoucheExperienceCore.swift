// StarlitCartoucheExperienceCore — feature 453 (R02-G16-03) T-R02G1603-005 (FR-R02G1603-003, 005, 008, 009;
// SC-R02G1603-004; clarifications Q1, Q4, Q5; data-model.md; contracts/api.md). The adapter of the Starlit Cartouche
// kernel to the shared experience contract. The core holds the level number, the kernel's `StarlitCartouchePlay` and
// the chosen destination and wait; it never draws and reads no clock. The presenter asks for an immutable
// `StarlitCartoucheSceneSnapshot` at its own presentation time (`snapshot(time:)`), so the firmament and the ship's
// glide can move while the state and its digest stay put (renderer purity). The snapshot carries the kernel's star
// positions at the current beat and the kernel's exact route report, so the drawn stars are the kernel's positions and
// no drawn value decides a leg, a stroke or the verdict. The chosen destination and wait are presentation state of the
// adapter (`route.choose [star, wait]`): at an opening, after every accepted leg, undo and redo, after `level.next`, a
// reset and a restore they are `StarlitCartoucheSceneSnapshot.defaultChoice(level, star:)` from the ship's star (the
// other end of the lowest-index corridor touching it, clarification Q1) with wait 0; never in the digest, the snapshot
// payload or `==`. Modelled on `VoxelOrigamiExperienceCore` (feature 443).
//
// Preparation: the certified level number `seed % 100 + 1` of `StarlitCartoucheManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole generator only if that candidate no longer certifies; begun (and its tutorial dismissed, as
// `StarlitCartouchePlay.replay` does) so the play is in stage `playing`. The tutorial of levels 1 … 3 is shown by the
// presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   route.fly [0…11, 0…8]     a destination star and a wait, whole numbers (`r02-g16.not-whole` otherwise); flies one
//                             leg (1 action); a star the level lacks, the ship's own star, no corridor and stars out of
//                             range at departure are the kernel's `r02-g16.action`; a leg the chart's check fails fails
//                             the level (`departure`, `hazard`, `arrival`, `deadline`, `stroke`);
//   play.undo, play.redo      the kernel's exact undo and redo (`r02-g16.action` when there is nothing to undo or redo;
//                             undo works in a failed play and returns it to playing; a won play is final);
//   level.next                the next certified level with a fresh play (since feature 455 the next open level; see
//                             below);
//   route.choose [0…11, 0…8]  chooses the shown destination and wait (presentation only; accepted in every stage); a
//                             star the level lacks or the ship's own star is refused `r02-g16.choice` without touching
//                             the kernel; a wait outside 0 … 8 is outside the declared range.
// The declared star range is the widest any level allows (`StarlitCartoucheLevel.starCounts`: at most 12 stars, so
// stars 0 … 11; the kernel or the adapter refuses the ones a level lacks); the wait range is the chart's
// (`StarlitCartoucheChart.waits`). Outside stage `playing` the kernel refuses with `r02-g16.stage`; the last of the
// budget spent by a leg without a win fails the level `budget`. Every leg is applied with the play's fingerprint as
// the expected one, so `r02-g16.stale` cannot arise. A kernel refusal (`StarlitCartoucheError`) becomes
// `.rule(code: error.reasonCode)`. A refused action changes nothing, the choice included.
//
// Digest ("r02-g16.starlit-cartouche.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the choice, the quality tier or a time. Snapshot schema 1: the JSON
// object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`StarlitCartouchePlay.replay`), resets the choice and throws `StarlitCartoucheRestoreRefusal` for a damaged payload,
// a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another level's seed
// among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `StarlitCartoucheTier.of(t)`: level-0 = star spheres of 16 × 12 segments, 3 ghosts,
// 2 glow shells; level-1 = 12 × 8 segments, 1 ghost, 1 glow shell; level-2 = flat 12-sided discs, no ghost, no glow.
// Outcome: `won` or `failed` while the play is in that stage, else nil. Rules use integers only.
//
// Feature 455 (R02-G16-05) T-R02G1605-004 (FR-R02G1605-001, 004 … 007; clarifications Q2–Q5): the core also holds the
// player's progress (`StarlitCartoucheProgress`: won levels with the least actions spent and stars, the open frontier),
// the mode (campaign, practice with the budget raised to the kernel's maximum 24, daily) and the tutorial step
// (`StarlitCartoucheTutorialStep`). No level is ever gated by payment: a locked level is one not yet unlocked
// (FR-R02G1605-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g16.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g16.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 24 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh with the default choice).
// `level.next` moves to the next open level in campaign mode and is refused with `r02-g16.locked` when there is none
// (100 does not wrap). A win (the play reaching `won` on an accepted leg or redo) records
// `progress.record(level:actionsSpent:certified:mode:)` with the actions spent
// (`StarlitCartoucheProgress.actionsSpent`: every leg record, undone ones included) against the certified witness's
// leg count: campaign opens the next level, daily records the level's best result and stars and opens nothing,
// practice records nothing. The tutorial starts at
// `StarlitCartoucheTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced after
// every accepted leg, undo and redo by `advanced(afterLeg:ended:)` (afterLeg for a leg; ended when the play is won or
// failed — an undo never ends it, a redo only when it restores a won or failed moment), never back; `route.choose`
// never moves it. The chosen destination and wait stay presentation. Digest "r02-g16.starlit-cartouche.v2": level,
// play fingerprint, progress and mode (never the tutorial step or the choice). Snapshot schema 2: `{"level", "mode",
// "progress", "records", "tutorial"}` with sorted keys; schema-1 payloads migrate (no won levels, level 1 open plus the
// levels up to the restored level, campaign mode, the tutorial at its first step — `fly` on the tutorial levels, else
// `done`); an envelope of a newer schema is refused.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Starlit Cartouche's adapter refusals (feature 453).
public enum StarlitCartoucheExperienceRule {
    /// A value that must be a whole number (a star or a wait) and is not.
    public static let notWhole = "r02-g16.not-whole"
    /// A chosen destination the level does not have, or the ship's own star (`route.choose`).
    public static let choice = "r02-g16.choice"
    /// A level that is not open yet, or no next open level (feature 455). Never a payment gate.
    public static let locked = "r02-g16.locked"
    /// An impossible calendar date (`mode.daily`, feature 455).
    public static let date = "r02-g16.date"
}

/// Why a saved Starlit Cartouche state was refused on restore (feature 453). A refused restore changes nothing.
public enum StarlitCartoucheRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 455).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(StarlitCartoucheError)
}

/// The state of Starlit Cartouche as an experience (see the file header). Snapshot schema 2.
public struct StarlitCartoucheExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g16.starlit-cartouche"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g16.starlit-cartouche.v2"
    /// The action ids in declaration order.
    public static let actionIDs = ["route.fly", "play.undo", "play.redo", "level.next", "route.choose",
                                   "level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"]
    /// The budget of a practice play: the kernel's maximum (`StarlitCartoucheMode.practiceBudget`, 24).
    public static let practiceBudget: Int = StarlitCartoucheMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a star: the most stars any level has (`StarlitCartoucheLevel.starCounts`, stars 0 … 11).
    public static let starRange: ClosedRange<Int> = 0...(StarlitCartoucheLevel.starCounts.upperBound - 1)
    /// The declared range of a wait: the chart's waits, 0 … 8.
    public static let waitRange: ClosedRange<Int> = StarlitCartoucheChart.waits
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: StarlitCartouchePlay
    /// The player's progress (feature 455): in the digest and the snapshot.
    public private(set) var progress: StarlitCartoucheProgress
    /// The mode (feature 455): in the digest and the snapshot.
    public private(set) var mode: StarlitCartoucheMode
    /// The tutorial step (feature 455): in the snapshot and `==`, not in the digest.
    public private(set) var tutorial: StarlitCartoucheTutorialStep
    /// The certified witness's leg count of the current level, against which a win's stars are counted. Derived from
    /// the level number.
    public private(set) var certifiedLegs: Int
    /// The chosen destination star, never the ship's own star; presentation only — not in the digest, the snapshot
    /// payload or `==`.
    public private(set) var chosenStar: Int
    /// The chosen wait, 0 … 8; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var chosenWait: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// What a reset restores (feature 455).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: StarlitCartouchePlay
        /// The opening progress: level 1 open plus the levels up to the opening level, none won.
        let progress: StarlitCartoucheProgress
        /// The opening level's initial tutorial step.
        let tutorial: StarlitCartoucheTutorialStep
        /// The opening level's certified witness leg count.
        let certifiedLegs: Int
    }

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial` and the default choice,
    /// whose reset returns to `opening` of `openingNumber`.
    init(levelNumber: Int, play: StarlitCartouchePlay, progress: StarlitCartoucheProgress, mode: StarlitCartoucheMode,
         tutorial: StarlitCartoucheTutorialStep, certifiedLegs: Int, openingNumber: Int, opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedLegs = certifiedLegs
        self.chosenStar = StarlitCartoucheSceneSnapshot.defaultChoice(play.level, star: play.star)
        self.chosenWait = 0
        self.openingNumber = openingNumber
        self.opening = opening
    }

    /// The difficulty band (1 … 5) of the current level: 20 levels per band, the certified difficulty bands
    /// (`StarlitCartoucheProgress.band(of:)`; feature 455).
    public var band: Int { StarlitCartoucheProgress.band(of: levelNumber) }

    /// The level number a seed chooses: `seed % 100 + 1`.
    public static func levelNumber(forSeed seed: UInt64) -> Int {
        Int(seed % UInt64(levelNumbers.count)) + 1
    }

    /// The certified level of manifest number `number` (1 … 100).
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func level(number: Int) throws(StarlitCartoucheError) -> StarlitCartoucheLevel {
        try generated(number: number).level
    }

    /// The certified levels generated so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 453).
    private static let generatedCache = Mutex<[Int: StarlitCartoucheGenerated]>([:])

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/starlit-cartouche/levels/NNN.witness.json`, read
    /// 2026-11-24).
    public static let certifiedCandidates: [Int] = [
        0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 1, 0, 2, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1,
        0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1,
        0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
    ]

    /// Candidate `index` of `entry` certified exactly as ``StarlitCartoucheGenerator/generate(_:)`` certifies a
    /// candidate (a valid candidate whose minimal plan lies in its band's range and within the budget, within the
    /// solver's work bound), and whose plan wins through the kernel on its last leg; nil otherwise.
    static func certify(_ entry: StarlitCartoucheManifestEntry, index: Int) -> StarlitCartoucheGenerated? {
        let range: ClosedRange<Int> = StarlitCartoucheBandProfile.of(band: entry.band).planRange
        guard let level = StarlitCartoucheGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = StarlitCartoucheSolver.plan(level, maxLegs: range.upperBound) else { return nil }
        guard range.contains(plan.size), plan.size <= entry.budget else { return nil }
        guard StarlitCartoucheSolver.wins(level, actions: plan.legs) else { return nil }
        return StarlitCartoucheGenerated(entry: entry, level: level, plan: plan,
                                         difficulty: StarlitCartoucheDifficulty(level: level, plan: plan),
                                         skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole generator runs only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(StarlitCartoucheError) -> StarlitCartoucheGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: StarlitCartoucheManifestEntry = StarlitCartoucheManifest.entries[number - 1]
        let fresh: StarlitCartoucheGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try StarlitCartoucheGenerator.generate(entry)
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: StarlitCartoucheLevel)
        throws(StarlitCartoucheError) -> StarlitCartouchePlay {
        try StarlitCartouchePlay.replay(level: level, records: [])
    }

    /// The practice copy of `level` (feature 455): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: StarlitCartoucheLevel)
        throws(StarlitCartoucheError) -> StarlitCartoucheLevel {
        try StarlitCartoucheLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, stars: level.stars,
                                  range: level.range, corridors: level.corridors, hazards: level.hazards,
                                  start: level.start, beacon: level.beacon, deadline: level.deadline,
                                  symbol: level.symbol,
                                  budget: StarlitCartoucheMode.practice.budget(base: level.budget),
                                  tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: StarlitCartoucheGenerated,
                            mode: StarlitCartoucheMode) throws(StarlitCartoucheError) -> StarlitCartoucheLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with the default choice; campaign mode, level 1 open plus the levels up to `number`, none won,
    /// the tutorial at its first step (feature 455).
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(StarlitCartoucheError) -> StarlitCartoucheExperienceCore {
        let certified: StarlitCartoucheGenerated = try generated(number: number)
        let play: StarlitCartouchePlay = try freshPlay(of: certified.level)
        var progress: StarlitCartoucheProgress = StarlitCartoucheProgress()
        progress.open(through: number)
        let tutorial: StarlitCartoucheTutorialStep = StarlitCartoucheTutorialStep.initial(level: number)
        let legs: Int = certified.plan.size
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedLegs: legs)
        return StarlitCartoucheExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                              tutorial: tutorial, certifiedLegs: legs, openingNumber: number,
                                              opening: opening)
    }

    /// Sets the choice to the default from the ship's star
    /// (``StarlitCartoucheSceneSnapshot/defaultChoice(_:star:)``) with wait 0.
    private mutating func resetChoice() {
        chosenStar = StarlitCartoucheSceneSnapshot.defaultChoice(play.level, star: play.star)
        chosenWait = 0
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (stars and their positions at the current beat, corridors, hazards and which are
    /// active, flown legs with their departure and arrival positions, drawn strokes, symbol, ship, beacon, deadline,
    /// the choice, the kernel's route report, stage, failure, failed leg and actions) with the level number, for
    /// drawing at the presenter's presentation time `time` (a non-finite or negative time becomes 0). Reads only; the
    /// state and its digest do not change.
    public func snapshot(time: Double) -> StarlitCartoucheSceneSnapshot {
        StarlitCartoucheSceneSnapshot(play: play, chosenStar: chosenStar, chosenWait: chosenWait,
                                      levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `StarlitCartoucheTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: StarlitCartoucheTier { StarlitCartoucheTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `StarlitCartoucheTier.all`.
    public static var qualityTiers: Int { StarlitCartoucheTier.all.count }

    /// The faces of one star at `tier`: longitudes × latitudes for a sphere, the disc's sides for a flat disc.
    static func starFaces(_ tier: StarlitCartoucheTier) -> Int {
        tier.flatStars ? StarlitCartoucheTier.discSides : tier.longitudes * tier.latitudes
    }

    /// One level per host tier, best first, named as `StarlitCartoucheTier.all`: the element share is a star's faces
    /// over the best tier's (1, 0.5, 0.0625), the iteration share the glow shells over the best tier's (1, 0.5, 0), the
    /// effect passes the glow shells; every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: StarlitCartoucheTier = StarlitCartoucheTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<StarlitCartoucheTier.all.count {
            let tier: StarlitCartoucheTier = StarlitCartoucheTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(starFaces(tier)) / Double(starFaces(best)),
                                       iterationShare: Double(tier.glowShells) / Double(best.glowShells),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode and the tutorial step (not the choice, the
    /// quality tier or the opening level).
    public static func == (lhs: StarlitCartoucheExperienceCore, rhs: StarlitCartoucheExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial
    }

    // MARK: Contract

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``); a payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) }])
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 455): no won levels with level 1 open
    /// plus the levels up to the restored level, campaign mode, no tutorial key (restore starts the tutorial at its
    /// first step: `fly` on the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``StarlitCartoucheRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw StarlitCartoucheRestoreRefusal.damaged
        }
        var progress: StarlitCartoucheProgress = StarlitCartoucheProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(StarlitCartoucheMode.campaign))
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
        ExperienceControl(id: "route.fly", ranges: [declared(starRange), declared(waitRange)]),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "route.choose", ranges: [declared(starRange), declared(waitRange)]),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(StarlitCartoucheProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The ten controls with their declared ranges (see the file header); `play.undo`, `play.redo`, `level.next`,
    /// `mode.practice`, `mode.campaign` and `tutorial.dismiss` take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with the default choice; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> StarlitCartoucheExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(StarlitCartoucheError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Starlit Cartouche level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the route changes only on an action, and the firmament and the glide move with the
    /// presenter's time, not the state.
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
                return .rejected(.rule(code: StarlitCartoucheExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(StarlitCartoucheError) {
            switch action.control {
            case "route.fly":
                try play.apply(.leg(values[0], values[1]), expecting: play.fingerprint)
                resetChoice()
                advanceTutorial(afterLeg: true)
                recordIfWon()
            case "play.undo":
                try play.undo()
                resetChoice()
                advanceTutorial(afterLeg: false)
            case "play.redo":
                try play.redo()
                resetChoice()
                advanceTutorial(afterLeg: false)
                recordIfWon()
            case "route.choose":
                // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                guard values[0] < play.level.stars.count, values[0] != play.star,
                      Self.waitRange.contains(values[1]) else {
                    return .rejected(.rule(code: StarlitCartoucheExperienceRule.choice))
                }
                chosenStar = values[0]
                chosenWait = values[1]
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: StarlitCartoucheExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: StarlitCartoucheExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = StarlitCartoucheProgress.dailyLevel(year: values[0], month: values[1],
                                                                      day: values[2]) else {
                    return .rejected(.rule(code: StarlitCartoucheExperienceRule.date))
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

    /// Advances the tutorial step after an accepted leg, undo or redo
    /// (`StarlitCartoucheTutorialStep.advanced(afterLeg:ended:)`): `afterLeg` for a leg, ended when the play is won or
    /// failed (never after an undo, which always lands on a moment before the end; after a redo only when it restores a
    /// won or failed moment). Never back.
    private mutating func advanceTutorial(afterLeg: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterLeg: afterLeg, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step and the default choice; the records of the level left are dropped. Changes nothing when the
    /// kernel refuses.
    private mutating func open(number: Int, mode: StarlitCartoucheMode) throws(StarlitCartoucheError) {
        let certified: StarlitCartoucheGenerated = try Self.generated(number: number)
        let fresh: StarlitCartouchePlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedLegs = certified.plan.size
        tutorial = StarlitCartoucheTutorialStep.initial(level: number)
        resetChoice()
    }

    /// After an accepted action that won the play: records the actions spent
    /// (`StarlitCartoucheProgress.actionsSpent(_:)`) against the certified witness's leg count in the current mode
    /// (campaign opens the next level; daily records the best result and stars and opens nothing; practice records
    /// nothing). A won play is final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        _ = progress.record(level: levelNumber, actionsSpent: StarlitCartoucheProgress.actionsSpent(play),
                            certified: certifiedLegs, mode: mode)
    }

    /// Back to the opening state the seed chose (progress included, campaign mode, the default choice); the quality
    /// tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedLegs = opening.certifiedLegs
        resetChoice()
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g16.starlit-cartouche.v2", then the level number, the play's fingerprint (actions spent, beat, drawn
    /// strokes, failure, legs, level, stage, star), the progress and the mode (their sorted JSON); never the tutorial
    /// step or the choice.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // choice (presentation) or the tutorial step.
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
        var mode: StarlitCartoucheMode
        /// The progress.
        var progress: StarlitCartoucheProgress
        /// The play's records.
        var records: [StarlitCartoucheRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: StarlitCartoucheTutorialStep?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, tutorial: tutorial))
    }

    /// The core of `payload` (schema 2): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the saved progress, mode and tutorial step (the first step when absent), with the default
    /// choice; a reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``StarlitCartoucheRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or
    ///   tutorial step, or a daily mode naming another level among them), a level number outside 1 … 100 or a level or
    ///   trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> StarlitCartoucheExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw StarlitCartoucheRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw StarlitCartoucheRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw StarlitCartoucheRestoreRefusal.damaged
        }
        do throws(StarlitCartoucheError) {
            let certified: StarlitCartoucheGenerated = try generated(number: decoded.level)
            let play: StarlitCartouchePlay = try StarlitCartouchePlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: StarlitCartoucheTutorialStep = decoded.tutorial
                ?? StarlitCartoucheTutorialStep.initial(level: decoded.level)
            let openingCore: StarlitCartoucheExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return StarlitCartoucheExperienceCore(levelNumber: decoded.level, play: play, progress: decoded.progress,
                                                  mode: decoded.mode, tutorial: tutorial,
                                                  certifiedLegs: certified.plan.size,
                                                  openingNumber: openingCore.openingNumber,
                                                  opening: openingCore.opening)
        } catch {
            throw StarlitCartoucheRestoreRefusal.kernel(error)
        }
    }
}
