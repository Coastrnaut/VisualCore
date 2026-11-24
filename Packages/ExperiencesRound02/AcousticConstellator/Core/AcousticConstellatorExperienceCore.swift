// AcousticConstellatorExperienceCore — feature 423 (R02-G13-03) T-R02G1303-005 (FR-R02G1303-003, 005; clarifications
// Q4, Q5; data-model.md; contracts/api.md). The adapter of the Acoustic Constellator kernel to the shared experience
// contract. The core holds the level number and the kernel's `AcousticConstellatorPlay`; it never draws and reads no
// clock. The presenter asks for an immutable `AcousticConstellatorSceneSnapshot` at its own presentation time
// (`snapshot(time:)`), so the stars can pulse and the shown listen tick can cycle while the state and its digest stay
// put (renderer purity). The snapshot carries the kernel's exact listen report, so the drawn pulse never decides a
// phase, a snapped link or the coherence. The panel's chosen star and partner are presentation state of the controls,
// not kernel state (Q5): a level opens with star 0 and partner 1 chosen.
//
// Preparation: the certified level number `seed % 100 + 1` of `AcousticConstellatorManifest`, certified once per
// process (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole generator only if that candidate no longer certifies; begun (and its tutorial dismissed, as
// `AcousticConstellatorPlay.replay` does) so the play is in stage `playing`. The tutorial of levels 1 … 3 is shown by
// the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   link.add [0…7, 0…7]       two stars, whole numbers (`r02-g13.not-whole` otherwise); links them (1 action);
//   link.remove [0…7, 0…7]    two stars; removes a link the player made (1 action);
//   star.nudge [0…7, −1…1]    a star and a step; shifts the star's starting phase by ±1 (1 action); a step of 0 is the
//                             kernel's `r02-g13.action` (`step`);
//   constellation.listen      listens to the constellation and decides the level (1 action): won, or failed
//                             `missing`, `disconnected` or `incoherent`;
//   play.undo, play.redo      the kernel's exact undo and redo (`r02-g13.action` when there is nothing to undo or redo;
//                             undo works in a failed play and returns it to playing; a won play is final);
//   level.next                the next certified level with a fresh play (since feature 425 the next open level; see
//                             below).
// The declared star range is the widest any level allows (`AcousticConstellatorLevel.starCounts`: at most 8 stars);
// the level's own star count, self links, existing, missing and fixed links and the degree and link limits are the
// kernel's to check (`r02-g13.action`); outside stage `playing` `r02-g13.stage`; the last of the budget spent by a
// link, unlink or nudge without a win fails the level `budget`. Every action is applied with the play's current
// fingerprint as the expected one, so `r02-g13.stale` cannot arise. A kernel refusal (`AcousticConstellatorError`)
// becomes `.rule(code: error.reasonCode)`. A refused action changes nothing.
//
// Digest ("r02-g13.acoustic-constellator.v1"): the level number and the play's fingerprint (not its record history, so
// undo restores the earlier digest exactly); never the quality tier or a time. Snapshot schema 1: the JSON object
// `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`AcousticConstellatorPlay.replay`) and throws `AcousticConstellatorRestoreRefusal` for a damaged payload, a level
// number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another level's seed among
// them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Feature 425 (R02-G13-05) T-R02G1305-004 (FR-R02G1305-001, 004 … 007; clarifications Q3–Q5): the core also holds the
// player's progress (`AcousticConstellatorProgress`: won levels with the least actions spent and stars, the open
// frontier), the mode (campaign, practice with the budget raised to the kernel's maximum 40, daily) and the tutorial
// step. No level is ever gated by payment: a locked level is one not yet unlocked (FR-R02G1305-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g13.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g13.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 40 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh). `level.next` moves to the next
// open level in campaign mode and is refused with `r02-g13.locked` when there is none (100 does not wrap). A win (the
// play reaching `won` on an accepted listen or redo) records `progress.record(level:actionsSpent:certified:mode:)` with
// the actions spent (`AcousticConstellatorProgress.actionsSpent`: every link, unlink, nudge and listen record, undone
// ones included) against the certified witness's action count (its links and nudges plus the listen): campaign opens
// the next level, daily records the level's best result and stars and opens nothing, practice records nothing. The
// tutorial starts at `AcousticConstellatorTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode)
// and is advanced after every accepted link, unlink, nudge, listen, undo and redo by
// `advanced(afterLink:complete:ended:)` (afterLink for a link; complete when no symbol pair is missing from the play's
// links; ended when the play is won or failed — an undo never ends it, a redo only when it restores a won or failed
// moment), never back. Digest "r02-g13.acoustic-constellator.v2": level, play fingerprint, progress and mode (never
// the tutorial step). Snapshot schema 2: `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys;
// schema-1 payloads migrate (no won levels, level 1 open plus the levels up to the restored level, campaign mode, the
// tutorial at its first step — `link` on the tutorial levels, else `done`).
//
// Feature 427 (R02-G13-07) T-R02G1307-003 (FR-R02G1307-001 … 007; clarifications Q1–Q5; research R2–R7): a campaign or
// daily win records its winning trace (`AcousticConstellatorReconciliation.netTrace` of the play's records: the
// effective links, unlinks, nudges and the listen, an undone action left out unless redone) as a verified result;
// restore reconciles every result (`AcousticConstellatorReconciliation.reconcile`, the frontier as saved) and exposes
// `reconciliationDropped` (not digested, not in `==`); the replay mode `replay(level)` plays a verified trace action by
// action:
//   replay.start [1…100]  a fresh play of that level in mode `replay(level)` (campaign budget) with the tutorial done
//                         (`r02-g13.no-replay` without a verified result with a trace);
//   replay.step           the next action of the trace (`r02-g13.replay-end` after the last or once the play ended;
//                         `r02-g13.no-replay` outside replay);
//   replay.stop           campaign at that level, the frontier when it is not open (`r02-g13.no-replay` outside
//                         replay);
//   settings.sound [0…1]  the sound choice (FR-R02G1307-007): 1 on, 0 off; whole; allowed in every mode.
// In replay every other action except `tutorial.dismiss` and `settings.sound` is refused with `r02-g13.replay` (the
// panel's chosen star and partner and the camera are presentation only and send no action), and nothing is recorded.
// A restored replay whose records are not exactly the first actions of its level's verified trace (links, unlinks,
// nudges and the listen only, in order, no undo or redo) is refused as `damaged`; a restored replay whose result did
// not survive reconciliation returns to campaign at that level (the frontier when it is not open). Digest
// "r02-g13.acoustic-constellator.v3" (the same parts as v2, the progress now with traces; never the sound choice or the
// dropped count); snapshot schema 3 `{"level", "mode", "progress", "records", "sound", "tutorial"}` (results carry
// `trace` and `verified`), migrating 1 → 2 → 3 (2 → 3: every result an empty trace and `verified` false, sound off).
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `AcousticConstellatorTier.of(t)`: level-0 = star pulse, 2 wave shells, 2 glow shells;
// level-1 = pulse, 1 glow shell; level-2 = none. Outcome: `won` or `failed` while the play is in that stage, else nil.
// Rules use integers only.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Acoustic Constellator's adapter refusals (feature 423).
public enum AcousticConstellatorExperienceRule {
    /// A value that must be a whole number (a star or a nudge step) and is not.
    public static let notWhole = "r02-g13.not-whole"
    /// A level that is not open yet, or no next open level (feature 425). Never a payment gate.
    public static let locked = "r02-g13.locked"
    /// An impossible calendar date (feature 425).
    public static let date = "r02-g13.date"
    /// No verified result with a trace to replay, or a replay control outside replay (feature 427).
    public static let noReplay = "r02-g13.no-replay"
    /// The replay has no further action: the trace is over or the play ended (feature 427).
    public static let replayEnd = "r02-g13.replay-end"
    /// An action that is not allowed during replay (feature 427).
    public static let replay = "r02-g13.replay"
}

/// Why a saved Acoustic Constellator state was refused on restore (feature 423). A refused restore changes nothing.
public enum AcousticConstellatorRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 425).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(AcousticConstellatorError)
}

/// The state of Acoustic Constellator as an experience (see the file header). Snapshot schema 3.
public struct AcousticConstellatorExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g13.acoustic-constellator"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 3
    /// The digest's domain string (schema 3).
    public static let digestDomain = "r02-g13.acoustic-constellator.v3"
    /// The action ids in declaration order.
    public static let actionIDs = ["link.add", "link.remove", "star.nudge", "constellation.listen", "play.undo",
                                   "play.redo", "level.next", "level.select", "mode.daily", "mode.practice",
                                   "mode.campaign", "tutorial.dismiss", "replay.start", "replay.step",
                                   "replay.stop", "settings.sound"]
    /// The declared range of `settings.sound`: 0 off, 1 on (feature 427).
    public static let soundRange: ClosedRange<Int> = 0...1
    /// The budget of a practice play: the kernel's maximum (`AcousticConstellatorMode.practiceBudget`, 40).
    public static let practiceBudget: Int = AcousticConstellatorMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a star index: the most stars any level has (`AcousticConstellatorLevel.starCounts`,
    /// 0 … 7).
    public static let starRange: ClosedRange<Int> = 0...(AcousticConstellatorLevel.starCounts.upperBound - 1)
    /// The declared range of a nudge step (−1 … 1; the kernel refuses 0).
    public static let stepRange: ClosedRange<Int> = -1...1
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"
    /// The star the panel chooses when a level opens (presentation state of the controls, Q5).
    public static let openingStar = 0
    /// The partner the panel chooses when a level opens (presentation state of the controls, Q5).
    public static let openingPartner = 1

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: AcousticConstellatorPlay
    /// The player's progress (feature 425): in the digest and the snapshot.
    public private(set) var progress: AcousticConstellatorProgress
    /// The mode (feature 425): in the digest and the snapshot.
    public private(set) var mode: AcousticConstellatorMode
    /// The tutorial step (feature 425): in the snapshot, not in the digest.
    public private(set) var tutorial: AcousticConstellatorTutorialStep
    /// How many saved results the last restore dropped because they did not verify (feature 427); not in the digest,
    /// the snapshot or `==`.
    public private(set) var reconciliationDropped = 0
    /// The player's sound choice (feature 427, FR-R02G1307-007), set by `settings.sound`: in the snapshot (key
    /// `"sound"`) and `==`, never in the digest; off at an opening, after a reset and in a migrated save.
    public private(set) var soundOn = false
    /// The certified witness's action count of the current level (its links and nudges plus the listen), against which
    /// a win's stars are counted. Derived from the level number.
    public private(set) var certifiedActions: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening

    /// What a reset restores (feature 425).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: AcousticConstellatorPlay
        /// The opening progress: level 1 open plus the levels up to the opening level, none won.
        let progress: AcousticConstellatorProgress
        /// The opening level's initial tutorial step.
        let tutorial: AcousticConstellatorTutorialStep
        /// The opening level's certified witness action count.
        let certifiedActions: Int
    }
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial`, whose reset returns to
    /// `opening` of `openingNumber`.
    init(levelNumber: Int, play: AcousticConstellatorPlay, progress: AcousticConstellatorProgress,
         mode: AcousticConstellatorMode, tutorial: AcousticConstellatorTutorialStep, certifiedActions: Int,
         openingNumber: Int, opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedActions = certifiedActions
        self.openingNumber = openingNumber
        self.opening = opening
    }

    /// The level number a seed chooses: `seed % 100 + 1`.
    public static func levelNumber(forSeed seed: UInt64) -> Int {
        Int(seed % UInt64(levelNumbers.count)) + 1
    }

    /// The certified level of manifest number `number` (1 … 100).
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func level(number: Int) throws(AcousticConstellatorError) -> AcousticConstellatorLevel {
        try generated(number: number).level
    }

    /// The certified levels generated so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 423).
    private static let generatedCache = Mutex<[Int: AcousticConstellatorGenerated]>([:])

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/acoustic-constellator/levels/NNN.witness.json`).
    public static let certifiedCandidates: [Int] = [
        2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
        0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 2, 0,
        0, 3, 0, 0, 0, 5, 4, 2, 3, 0, 2, 0, 0, 0, 0, 0, 2, 3, 3, 0, 3, 1, 5, 2, 1,
        0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 2, 0, 1, 3, 0, 0, 7, 5, 0, 0, 3, 0, 0, 7,
    ]

    /// Candidate `index` of `entry` certified exactly as ``AcousticConstellatorGenerator/generate(_:)`` certifies a
    /// candidate (a solver plan within the work bound whose size is at least 1, in the band's plan range and at most
    /// budget − 1, and whose witness actions win through the kernel); nil otherwise.
    static func certify(_ entry: AcousticConstellatorManifestEntry, index: Int) -> AcousticConstellatorGenerated? {
        let profile: AcousticConstellatorBandProfile = .of(band: entry.band)
        guard let level = AcousticConstellatorGenerator.candidate(entry, index: index),
              let plan = AcousticConstellatorSolver.plan(level) else { return nil }
        let size: Int = plan.size
        guard size >= 1, profile.planRange.contains(size), size <= level.budget - 1 else { return nil }
        guard AcousticConstellatorSolver.wins(level, actions: AcousticConstellatorSolver.actions(plan)) else {
            return nil
        }
        return AcousticConstellatorGenerated(entry: entry, level: level, plan: plan,
                                             difficulty: AcousticConstellatorDifficulty(level: level, plan: plan),
                                             skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole generator runs only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(AcousticConstellatorError) -> AcousticConstellatorGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: AcousticConstellatorManifestEntry = AcousticConstellatorManifest.entries[number - 1]
        let fresh: AcousticConstellatorGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try AcousticConstellatorGenerator.generate(entry)
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: AcousticConstellatorLevel) throws(AcousticConstellatorError)
        -> AcousticConstellatorPlay {
        try AcousticConstellatorPlay.replay(level: level, records: [])
    }

    /// The practice copy of `level` (feature 425): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(
        of level: AcousticConstellatorLevel
    ) throws(AcousticConstellatorError) -> AcousticConstellatorLevel {
        try AcousticConstellatorLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, stars: level.stars,
                                      fixedLinks: level.fixedLinks, symbol: level.symbol, coupling: level.coupling,
                                      degreeLimit: level.degreeLimit, linkLimit: level.linkLimit,
                                      snapLimit: level.snapLimit, threshold: level.threshold, hold: level.hold,
                                      window: level.window,
                                      budget: AcousticConstellatorMode.practice.budget(base: level.budget),
                                      tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: AcousticConstellatorGenerated,
                            mode: AcousticConstellatorMode) throws(AcousticConstellatorError)
        -> AcousticConstellatorLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions; campaign mode, level 1 open plus the levels up to `number`, none won, the tutorial at its first
    /// step.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(AcousticConstellatorError) -> AcousticConstellatorExperienceCore {
        let certified: AcousticConstellatorGenerated = try generated(number: number)
        let play: AcousticConstellatorPlay = try freshPlay(of: certified.level)
        var progress: AcousticConstellatorProgress = AcousticConstellatorProgress()
        progress.open(through: number)
        let tutorial: AcousticConstellatorTutorialStep = AcousticConstellatorTutorialStep.initial(level: number)
        let actions: Int = certified.actions.count
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedActions: actions)
        return AcousticConstellatorExperienceCore(levelNumber: number, play: play, progress: progress,
                                                  mode: .campaign, tutorial: tutorial, certifiedActions: actions,
                                                  openingNumber: number, opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (stars, links, fixed links, symbol, starting phases, the kernel's exact listen
    /// report, threshold, hold, window, stage, failure and actions) with the level number, for drawing at the
    /// presenter's presentation time `time` (a non-finite or negative time becomes 0). Reads only; the state and its
    /// digest do not change.
    public func snapshot(time: Double) -> AcousticConstellatorSceneSnapshot {
        AcousticConstellatorSceneSnapshot(play: play, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `AcousticConstellatorTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: AcousticConstellatorTier { AcousticConstellatorTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `AcousticConstellatorTier.all`.
    public static var qualityTiers: Int { AcousticConstellatorTier.all.count }

    /// One level per host tier, best first, named as `AcousticConstellatorTier.all`: the element share is the animated
    /// layers (star pulse, wave shells) drawn over the best tier's 2, the iteration share the glow shells over the best
    /// tier's 2 and the effect passes the glow shells; every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: AcousticConstellatorTier = AcousticConstellatorTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<AcousticConstellatorTier.all.count {
            let tier: AcousticConstellatorTier = AcousticConstellatorTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(layers(tier)) / Double(layers(best)),
                                       iterationShare: Double(tier.glowShells) / Double(best.glowShells),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// The animated layers `tier` draws: the star pulse and the wave shells, each 0 or 1.
    static func layers(_ tier: AcousticConstellatorTier) -> Int {
        (tier.pulse ? 1 : 0) + (tier.waveShells > 0 ? 1 : 0)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode, the tutorial step and the sound choice (not
    /// the quality tier, the dropped count or the opening level).
    public static func == (lhs: AcousticConstellatorExperienceCore, rhs: AcousticConstellatorExperienceCore) -> Bool {
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

    /// The schema-3 object of a schema-2 object (feature 427): every won result gains an empty `trace` and `verified`
    /// false, and the sound choice is off.
    ///
    /// - Throws: ``AcousticConstellatorRestoreRefusal/damaged`` when `object` has no progress with a solved list.
    public static func migratedToSchemaThree(_ object: [String: Any]) throws -> [String: Any] {
        guard var progress = object["progress"] as? [String: Any], let solved = progress["solved"] as? [Any] else {
            throw AcousticConstellatorRestoreRefusal.damaged
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

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 425): no won levels with level 1 open
    /// plus the levels up to the restored level, campaign mode, no tutorial key (restore starts the tutorial at its
    /// first step: `link` on the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``AcousticConstellatorRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw AcousticConstellatorRestoreRefusal.damaged
        }
        var progress: AcousticConstellatorProgress = AcousticConstellatorProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(AcousticConstellatorMode.campaign))
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
        ExperienceControl(id: "link.add", ranges: [declared(starRange), declared(starRange)]),
        ExperienceControl(id: "link.remove", ranges: [declared(starRange), declared(starRange)]),
        ExperienceControl(id: "star.nudge", ranges: [declared(starRange), declared(stepRange)]),
        ExperienceControl(id: "constellation.listen"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily",
                          ranges: [declared(AcousticConstellatorProgress.dailyYears), 1...12, 1...31]),
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

    /// The sixteen controls with their declared ranges (see the file header); `constellation.listen`, `play.undo`,
    /// `play.redo`, `level.next`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`, `replay.step` and `replay.stop`
    /// take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing`; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> AcousticConstellatorExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(AcousticConstellatorError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Acoustic Constellator level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the constellation changes only on an action, and the pulse and the shown listen
    /// tick move with the presenter's time, not the state.
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
                return .rejected(.rule(code: AcousticConstellatorExperienceRule.notWhole))
            }
            values.append(whole)
        }
        if case .replay = mode, !Self.replayControls.contains(action.control) {
            return .rejected(.rule(code: AcousticConstellatorExperienceRule.replay))
        }
        do throws(AcousticConstellatorError) {
            switch action.control {
            case "link.add":
                try play.apply(.link(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterLink: true)
            case "link.remove":
                try play.apply(.unlink(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterLink: false)
            case "star.nudge":
                try play.apply(.nudge(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterLink: false)
            case "constellation.listen":
                try play.apply(.listen, expecting: play.fingerprint)
                advanceTutorial(afterLink: false)
                recordIfWon()
            case "play.undo":
                try play.undo()
                advanceTutorial(afterLink: false)
            case "play.redo":
                try play.redo()
                advanceTutorial(afterLink: false)
                recordIfWon()
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: AcousticConstellatorExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: AcousticConstellatorExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = AcousticConstellatorProgress.dailyLevel(year: values[0], month: values[1],
                                                                          day: values[2]) else {
                    return .rejected(.rule(code: AcousticConstellatorExperienceRule.date))
                }
                try open(number: daily, mode: .daily(level: daily))
            case "mode.practice":
                try open(number: levelNumber, mode: .practice)
            case "mode.campaign":
                try open(number: progress.isOpen(levelNumber) ? levelNumber : progress.frontier, mode: .campaign)
            case "replay.start":
                guard let result = progress.solved[values[0]], result.verified, !result.trace.isEmpty else {
                    return .rejected(.rule(code: AcousticConstellatorExperienceRule.noReplay))
                }
                try open(number: values[0], mode: .replay(level: values[0]))
                tutorial = .done
            case "replay.step":
                guard case .replay(let level) = mode, let result = progress.solved[level], result.verified else {
                    return .rejected(.rule(code: AcousticConstellatorExperienceRule.noReplay))
                }
                // Replay never undoes, so each trace action made exactly one record.
                let index: Int = play.records.count
                guard play.stage == .playing, index < result.trace.count else {
                    return .rejected(.rule(code: AcousticConstellatorExperienceRule.replayEnd))
                }
                try play.apply(result.trace[index], expecting: play.fingerprint)
            case "replay.stop":
                guard case .replay(let level) = mode else {
                    return .rejected(.rule(code: AcousticConstellatorExperienceRule.noReplay))
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

    /// Advances the tutorial step after an accepted link, unlink, nudge, listen, undo or redo
    /// (`AcousticConstellatorTutorialStep.advanced(afterLink:complete:ended:)`): `afterLink` for a link, complete when
    /// no symbol pair is missing from the play's links (`AcousticConstellatorTutorialStep.isComplete(_:)`), ended when
    /// the play is won or failed (never after an undo, which always lands on a moment before the end; after a redo
    /// only when it restores a won or failed moment). Never back.
    private mutating func advanceTutorial(afterLink: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterLink: afterLink,
                                     complete: AcousticConstellatorTutorialStep.isComplete(play), ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step; the records of the level left are dropped. Changes nothing when the kernel refuses.
    private mutating func open(number: Int, mode: AcousticConstellatorMode) throws(AcousticConstellatorError) {
        let certified: AcousticConstellatorGenerated = try Self.generated(number: number)
        let fresh: AcousticConstellatorPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedActions = certified.actions.count
        tutorial = AcousticConstellatorTutorialStep.initial(level: number)
    }

    /// After an accepted action that won the play: records the actions spent
    /// (`AcousticConstellatorProgress.actionsSpent(_:)`) against the certified witness's action count in the current
    /// mode with the winning trace (``winningTrace``) as a verified result (campaign opens the next level; daily
    /// records the best result and stars and opens nothing; practice and replay record nothing). A won play is final,
    /// so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        if case .replay = mode { return }
        progress.record(level: levelNumber, actionsSpent: AcousticConstellatorProgress.actionsSpent(play),
                        certified: certifiedActions, mode: mode, trace: winningTrace)
    }

    /// The controls accepted during replay (feature 427); the panel's chosen star and partner and the camera are
    /// presentation only and send no action.
    static let replayControls: Set<String> = ["replay.start", "replay.step", "replay.stop", "tutorial.dismiss",
                                              "settings.sound"]

    /// The winning trace of the current play (feature 427): its effective actions in order
    /// (``AcousticConstellatorReconciliation/netTrace(_:)``), never an undo or a redo.
    var winningTrace: [AcousticConstellatorAction] { AcousticConstellatorReconciliation.netTrace(play.records) }

    /// Back to the opening state the seed chose (progress included, campaign mode); the quality tier, which is not
    /// state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedActions = opening.certifiedActions
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

    /// "r02-g13.acoustic-constellator.v3", then the level number, the play's fingerprint (level, links, phases,
    /// actions spent, stage, failure), the progress (with its traces) and the mode (their sorted JSON); never the
    /// tutorial step, the sound choice or the dropped count.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly.
        builder.add(play.fingerprint)
        let encoder: JSONEncoder = Self.payloadEncoder()
        builder.add(String(decoding: (try? encoder.encode(progress)) ?? Data(), as: UTF8.self))
        builder.add(String(decoding: (try? encoder.encode(mode)) ?? Data(), as: UTF8.self))
    }

    // MARK: Snapshot

    /// The payload's JSON form (schema 3); `tutorial` is absent in a migrated schema-1 payload and `sound` (absent
    /// means off) is written by every schema-3 payload and by the 2 → 3 migration.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The mode.
        var mode: AcousticConstellatorMode
        /// The progress.
        var progress: AcousticConstellatorProgress
        /// The play's records.
        var records: [AcousticConstellatorRecord]
        /// The sound choice; nil (off) in a payload written before schema 3.
        var sound: Bool?
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: AcousticConstellatorTutorialStep?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "sound", "tutorial"}` with sorted keys and unescaped
    /// slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, sound: soundOn, tutorial: tutorial))
    }

    /// The core of `payload` (schema 3): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the reconciled progress (``AcousticConstellatorReconciliation/reconcile(_:)``, the frontier
    /// as saved, the number dropped in ``reconciliationDropped``), the saved mode, tutorial step (the first step when
    /// absent) and sound choice (off when absent); a saved replay whose result did not survive the check returns to
    /// campaign at that level (the frontier when it is not open). A reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``AcousticConstellatorRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or
    ///   tutorial step, a daily or replay mode naming another level, or a replay whose records are not exactly the
    ///   first actions of its level's verified trace among them), a level number outside 1 … 100 or a level or trace
    ///   the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> AcousticConstellatorExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw AcousticConstellatorRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw AcousticConstellatorRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw AcousticConstellatorRestoreRefusal.damaged
        }
        if case .replay(let replayed) = decoded.mode, replayed != decoded.level {
            throw AcousticConstellatorRestoreRefusal.damaged
        }
        // Feature 427: a saved replay's records are exactly the first actions of its level's saved trace — links,
        // unlinks, nudges and the listen only, in order, no undo or redo — or the payload is damaged.
        if case .replay(let replayed) = decoded.mode, let saved = decoded.progress.solved[replayed], saved.verified {
            var applied: [AcousticConstellatorAction] = []
            for record in decoded.records {
                guard record.kind != .undo, record.kind != .redo, let action = record.action else {
                    throw AcousticConstellatorRestoreRefusal.damaged
                }
                applied.append(action)
            }
            guard applied.count <= saved.trace.count, Array(saved.trace.prefix(applied.count)) == applied else {
                throw AcousticConstellatorRestoreRefusal.damaged
            }
        }
        do throws(AcousticConstellatorError) {
            let certified: AcousticConstellatorGenerated = try generated(number: decoded.level)
            let play: AcousticConstellatorPlay = try AcousticConstellatorPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: AcousticConstellatorTutorialStep = decoded.tutorial
                ?? AcousticConstellatorTutorialStep.initial(level: decoded.level)
            let openingCore: AcousticConstellatorExperienceCore = try opening(number: levelNumber(forSeed: seed))
            // Feature 427: every saved result is checked by replaying its trace; the frontier stays as saved.
            let reconciled = AcousticConstellatorReconciliation.reconcile(decoded.progress)
            var core: AcousticConstellatorExperienceCore = AcousticConstellatorExperienceCore(
                levelNumber: decoded.level, play: play, progress: reconciled.progress, mode: decoded.mode,
                tutorial: tutorial, certifiedActions: certified.actions.count,
                openingNumber: openingCore.openingNumber, opening: openingCore.opening)
            core.reconciliationDropped = reconciled.dropped
            core.soundOn = decoded.sound ?? false
            // A replay whose result did not survive the check returns to campaign at that level (or the frontier).
            if case .replay(let level) = decoded.mode, reconciled.progress.solved[level]?.verified != true {
                try core.open(number: core.progress.isOpen(level) ? level : core.progress.frontier, mode: .campaign)
            }
            return core
        } catch {
            throw AcousticConstellatorRestoreRefusal.kernel(error)
        }
    }
}
