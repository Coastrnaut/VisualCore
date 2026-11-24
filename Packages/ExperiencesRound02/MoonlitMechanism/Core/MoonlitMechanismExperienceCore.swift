// MoonlitMechanismExperienceCore — feature 433 (R02-G14-03) T-R02G1403-005 (FR-R02G1403-005, 008, 009; SC-R02G1403-004;
// clarification Q5; data-model.md; contracts/api.md). The adapter of the Moonlit Mechanism kernel to the shared
// experience contract. The core holds the level number, the kernel's `MoonlitMechanismPlay` and the shown key frame; it
// never draws and reads no clock. The presenter asks for an immutable `MoonlitMechanismSceneSnapshot` at its own
// presentation time (`snapshot(time:)`), so the gears can turn in preview while the state and its digest stay put
// (renderer purity). The snapshot carries the kernel's exact run report, so the drawn shadows are the kernel's cast
// cells and no drawn value decides an alignment, a covered cell or the verdict. The shown key frame is presentation
// state of the adapter (`frame.show [k]`): key frame 0 when a level opens, never in the digest, the snapshot payload or
// `==`. The panel's chosen gear is presentation state of the controls, not of this core (Q5): a level opens with gear 1
// chosen (``openingGear``).
//
// Preparation: the certified level number `seed % 100 + 1` of `MoonlitMechanismManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole generator only if that candidate no longer certifies; begun (and its tutorial dismissed, as
// `MoonlitMechanismPlay.replay` does) so the play is in stage `playing`. The tutorial of levels 1 … 3 is shown by the
// presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   handle.turn [−1…1]          a step, a whole number (`r02-g14.not-whole` otherwise); turns the handle: every gear
//                               moves one tooth in its direction (1 action); a step of 0 is the kernel's
//                               `r02-g14.action` (`step`);
//   gear.reseat [0…4, −1…1]     a gear and a step; re-seats that gear by one tooth (1 action); the driver (gear 0) and
//                               a gear the level lacks are the kernel's `r02-g14.action` (`driver`, `gear`);
//   lamp.step [−1…1]            a step; moves the lamp one height (1 action); leaving the lamp's heights is the
//                               kernel's `r02-g14.action` (`lamp`);
//   machine.run                 runs the machine through its key frames and decides the level (1 action): won, or
//                               failed `jammed`, `forbidden`, `missing` or `stray`;
//   play.undo, play.redo        the kernel's exact undo and redo (`r02-g14.action` when there is nothing to undo or
//                               redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                  the next certified level with a fresh play and key frame 0 shown (since feature 435 the
//                               next open level; see below);
//   frame.show [0…5]            shows key frame k (presentation only; accepted in every stage); a key frame the level
//                               lacks is refused `r02-g14.frame`.
// The declared gear and key-frame ranges are the widest any level allows (`MoonlitMechanismLevel.gearCounts`: at most 5
// gears; `frameCounts`: at most 6 key frames). Outside stage `playing` the kernel refuses with `r02-g14.stage`; the
// last of the budget spent by a turn, re-seat or lamp step without a win fails the level `budget`. Every action is
// applied with the play's current fingerprint as the expected one, so `r02-g14.stale` cannot arise. A kernel refusal
// (`MoonlitMechanismError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing.
//
// Digest ("r02-g14.moonlit-mechanism.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the shown key frame, the quality tier or a time. Snapshot schema 1: the
// JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`MoonlitMechanismPlay.replay`), shows key frame 0, and throws `MoonlitMechanismRestoreRefusal` for a damaged
// payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another
// level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Feature 435 (R02-G14-05) T-R02G1405-004 (FR-R02G1405-001, 004 … 007; clarifications Q2–Q5): the core also holds the
// player's progress (`MoonlitMechanismProgress`: won levels with the least actions spent and stars, the open frontier),
// the mode (campaign, practice with the budget raised to the kernel's maximum 40, daily) and the tutorial step. No
// level is ever gated by payment: a locked level is one not yet unlocked (FR-R02G1405-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g14.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g14.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 40 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh, key frame 0 shown). `level.next`
// moves to the next open level in campaign mode and is refused with `r02-g14.locked` when there is none (100 does not
// wrap). A win (the play reaching `won` on an accepted run or redo) records
// `progress.record(level:actionsSpent:certified:mode:)` with the actions spent (`MoonlitMechanismProgress.actionsSpent`:
// every turn, re-seat, lamp step and run record, undone ones included) against the certified witness's action count
// (its turns, re-seats and lamp steps plus the run): campaign opens the next level, daily records the level's best
// result and stars and opens nothing, practice records nothing. The tutorial starts at
// `MoonlitMechanismTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced after
// every accepted turn, re-seat, lamp step, run, undo and redo by `advanced(afterChange:aligned:ended:)` (afterChange for
// a turn, re-seat or lamp step; aligned when the run report of the current set-up wins,
// `MoonlitMechanismTutorialStep.isAligned(_:)`; ended when the play is won or failed — an undo never ends it, a redo only
// when it restores a won or failed moment), never back; `frame.show` never moves it. Digest
// "r02-g14.moonlit-mechanism.v2": level, play fingerprint, progress and mode (never the tutorial step or the shown key
// frame). Snapshot schema 2: `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys; schema-1 payloads
// migrate (no won levels, level 1 open plus the levels up to the restored level, campaign mode, the tutorial at its
// first step — `change` on the tutorial levels, else `done`).
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `MoonlitMechanismTier.of(t)`: level-0 = 6 rim segments per tooth, soft shadow edges,
// 2 glow shells; level-1 = 4, soft edges, 1 glow shell; level-2 = 2, hard edges, no glow. Outcome: `won` or `failed`
// while the play is in that stage, else nil. Rules use integers only.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Moonlit Mechanism's adapter refusals (feature 433).
public enum MoonlitMechanismExperienceRule {
    /// A value that must be a whole number (a step, a gear or a key frame) and is not.
    public static let notWhole = "r02-g14.not-whole"
    /// A key frame the level does not have (`frame.show`).
    public static let frame = "r02-g14.frame"
    /// A level that is not open yet, or no next open level (feature 435). Never a payment gate.
    public static let locked = "r02-g14.locked"
    /// An impossible calendar date (feature 435).
    public static let date = "r02-g14.date"
}

/// Why a saved Moonlit Mechanism state was refused on restore (feature 433). A refused restore changes nothing.
public enum MoonlitMechanismRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 435).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(MoonlitMechanismError)
}

/// The state of Moonlit Mechanism as an experience (see the file header). Snapshot schema 2.
public struct MoonlitMechanismExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g14.moonlit-mechanism"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g14.moonlit-mechanism.v2"
    /// The action ids in declaration order.
    public static let actionIDs = ["handle.turn", "gear.reseat", "lamp.step", "machine.run", "play.undo", "play.redo",
                                   "level.next", "frame.show", "level.select", "mode.daily", "mode.practice",
                                   "mode.campaign", "tutorial.dismiss"]
    /// The budget of a practice play: the kernel's maximum (`MoonlitMechanismMode.practiceBudget`, 40).
    public static let practiceBudget: Int = MoonlitMechanismMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a step (−1 … 1; the kernel refuses 0).
    public static let stepRange: ClosedRange<Int> = -1...1
    /// The declared range of a gear index: the most gears any level has (`MoonlitMechanismLevel.gearCounts`, 0 … 4).
    public static let gearRange: ClosedRange<Int> = 0...(MoonlitMechanismLevel.gearCounts.upperBound - 1)
    /// The declared range of a key frame: the most key frames any level has (`MoonlitMechanismLevel.frameCounts`,
    /// 0 … 5).
    public static let frameRange: ClosedRange<Int> = 0...(MoonlitMechanismLevel.frameCounts.upperBound - 1)
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"
    /// The gear the panel chooses when a level opens (presentation state of the controls, Q5).
    public static let openingGear = 1
    /// The key frame shown when a level opens.
    public static let openingFrame = 0

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: MoonlitMechanismPlay
    /// The player's progress (feature 435): in the digest and the snapshot.
    public private(set) var progress: MoonlitMechanismProgress
    /// The mode (feature 435): in the digest and the snapshot.
    public private(set) var mode: MoonlitMechanismMode
    /// The tutorial step (feature 435): in the snapshot, not in the digest.
    public private(set) var tutorial: MoonlitMechanismTutorialStep
    /// The certified witness's action count of the current level (its turns, re-seats and lamp steps plus the run),
    /// against which a win's stars are counted. Derived from the level number.
    public private(set) var certifiedActions: Int
    /// The shown key frame, 0 … key frames − 1; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownFrame: Int = openingFrame
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening

    /// What a reset restores (feature 435).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: MoonlitMechanismPlay
        /// The opening progress: level 1 open plus the levels up to the opening level, none won.
        let progress: MoonlitMechanismProgress
        /// The opening level's initial tutorial step.
        let tutorial: MoonlitMechanismTutorialStep
        /// The opening level's certified witness action count.
        let certifiedActions: Int
    }
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial` and key frame 0 shown, whose
    /// reset returns to `opening` of `openingNumber`.
    init(levelNumber: Int, play: MoonlitMechanismPlay, progress: MoonlitMechanismProgress, mode: MoonlitMechanismMode,
         tutorial: MoonlitMechanismTutorialStep, certifiedActions: Int, openingNumber: Int, opening: Opening) {
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
    public static func level(number: Int) throws(MoonlitMechanismError) -> MoonlitMechanismLevel {
        try generated(number: number).level
    }

    /// The certified levels generated so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 433).
    private static let generatedCache = Mutex<[Int: MoonlitMechanismGenerated]>([:])

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/moonlit-mechanism/levels/NNN.witness.json`).
    public static let certifiedCandidates: [Int] = [
        3, 1, 3, 0, 0, 0, 1, 0, 1, 2, 2, 0, 1, 0, 1, 2, 0, 2, 4, 0, 0, 1, 0, 1, 0,
        0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 2,
        2, 0, 1, 0, 0, 0, 1, 0, 3, 1, 2, 4, 0, 1, 1, 1, 0, 0, 0, 0, 2, 2, 0, 1, 2,
        1, 1, 2, 0, 0, 1, 2, 3, 8, 1, 1, 2, 1, 0, 3, 0, 1, 1, 5, 0, 0, 0, 1, 1, 0,
    ]

    /// Candidate `index` of `entry` certified exactly as ``MoonlitMechanismGenerator/generate(_:)`` certifies a
    /// candidate (a start that does not already win, a solver plan within the work bound and the band's plan range,
    /// at most budget − 1, whose witness actions win through the kernel); nil otherwise.
    static func certify(_ entry: MoonlitMechanismManifestEntry, index: Int) -> MoonlitMechanismGenerated? {
        let range: ClosedRange<Int> = MoonlitMechanismBandProfile.of(band: entry.band).planRange
        guard let level = MoonlitMechanismGenerator.candidate(entry, index: index) else { return nil }
        guard level.run(phases: level.startingPhases, height: level.startingHeight).outcome != .won else { return nil }
        guard let plan = MoonlitMechanismSolver.plan(level, maxActions: range.upperBound) else { return nil }
        guard range.contains(plan.size), plan.size <= entry.budget - 1 else { return nil }
        guard MoonlitMechanismSolver.wins(level, actions: MoonlitMechanismSolver.actions(plan)) else { return nil }
        return MoonlitMechanismGenerated(entry: entry, level: level, plan: plan,
                                         difficulty: MoonlitMechanismDifficulty(level: level, plan: plan),
                                         skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole generator runs only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(MoonlitMechanismError) -> MoonlitMechanismGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: MoonlitMechanismManifestEntry = MoonlitMechanismManifest.entries[number - 1]
        let fresh: MoonlitMechanismGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try MoonlitMechanismGenerator.generate(entry)
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: MoonlitMechanismLevel) throws(MoonlitMechanismError)
        -> MoonlitMechanismPlay {
        try MoonlitMechanismPlay.replay(level: level, records: [])
    }

    /// The practice copy of `level` (feature 435): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: MoonlitMechanismLevel) throws(MoonlitMechanismError)
        -> MoonlitMechanismLevel {
        try MoonlitMechanismLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, gears: level.gears,
                                  width: level.width, rows: level.rows, lampHeights: level.lampHeights,
                                  startingHeight: level.startingHeight, keyFrames: level.keyFrames,
                                  forbidden: level.forbidden, allowance: level.allowance,
                                  budget: MoonlitMechanismMode.practice.budget(base: level.budget),
                                  tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: MoonlitMechanismGenerated,
                            mode: MoonlitMechanismMode) throws(MoonlitMechanismError) -> MoonlitMechanismLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with key frame 0 shown; campaign mode, level 1 open plus the levels up to `number`, none won,
    /// the tutorial at its first step.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(MoonlitMechanismError) -> MoonlitMechanismExperienceCore {
        let certified: MoonlitMechanismGenerated = try generated(number: number)
        let play: MoonlitMechanismPlay = try freshPlay(of: certified.level)
        var progress: MoonlitMechanismProgress = MoonlitMechanismProgress()
        progress.open(through: number)
        let tutorial: MoonlitMechanismTutorialStep = MoonlitMechanismTutorialStep.initial(level: number)
        let actions: Int = MoonlitMechanismSolver.actions(certified.plan).count
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedActions: actions)
        return MoonlitMechanismExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                              tutorial: tutorial, certifiedActions: actions, openingNumber: number,
                                              opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play at the shown key frame (gears and their phases at that key frame, lamp, wall,
    /// cast, target and forbidden cells, the kernel's exact run report, stage, failure and actions) with the level
    /// number, for drawing at the presenter's presentation time `time` (a non-finite or negative time becomes 0). Reads
    /// only; the state and its digest do not change.
    public func snapshot(time: Double) -> MoonlitMechanismSceneSnapshot {
        MoonlitMechanismSceneSnapshot(play: play, shownFrame: shownFrame, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `MoonlitMechanismTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: MoonlitMechanismTier { MoonlitMechanismTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `MoonlitMechanismTier.all`.
    public static var qualityTiers: Int { MoonlitMechanismTier.all.count }

    /// One level per host tier, best first, named as `MoonlitMechanismTier.all`: the element share is the rim segments
    /// per tooth over the best tier's 6, the iteration share the glow shells over the best tier's 2, the effect passes
    /// the glow shells plus one for the soft shadow edges; every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: MoonlitMechanismTier = MoonlitMechanismTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<MoonlitMechanismTier.all.count {
            let tier: MoonlitMechanismTier = MoonlitMechanismTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.segmentsPerTooth) / Double(best.segmentsPerTooth),
                                       iterationShare: Double(tier.glowShells) / Double(best.glowShells),
                                       effectPasses: tier.glowShells + (tier.softEdge ? 1 : 0)))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode and the tutorial step (not the shown key frame,
    /// the quality tier or the opening level).
    public static func == (lhs: MoonlitMechanismExperienceCore, rhs: MoonlitMechanismExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial
    }

    // MARK: Contract

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``); a payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) }])
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 435): no won levels with level 1 open
    /// plus the levels up to the restored level, campaign mode, no tutorial key (restore starts the tutorial at its
    /// first step: `change` on the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``MoonlitMechanismRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw MoonlitMechanismRestoreRefusal.damaged
        }
        var progress: MoonlitMechanismProgress = MoonlitMechanismProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(MoonlitMechanismMode.campaign))
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
        ExperienceControl(id: "handle.turn", ranges: [declared(stepRange)]),
        ExperienceControl(id: "gear.reseat", ranges: [declared(gearRange), declared(stepRange)]),
        ExperienceControl(id: "lamp.step", ranges: [declared(stepRange)]),
        ExperienceControl(id: "machine.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "frame.show", ranges: [declared(frameRange)]),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(MoonlitMechanismProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The thirteen controls with their declared ranges (see the file header); `machine.run`, `play.undo`, `play.redo`,
    /// `level.next`, `mode.practice`, `mode.campaign` and `tutorial.dismiss` take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with key frame 0 shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> MoonlitMechanismExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(MoonlitMechanismError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Moonlit Mechanism level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the mechanism changes only on an action, and the turning preview moves with the
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
                return .rejected(.rule(code: MoonlitMechanismExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(MoonlitMechanismError) {
            switch action.control {
            case "handle.turn":
                try play.apply(.turn(values[0]), expecting: play.fingerprint)
                advanceTutorial(afterChange: true)
            case "gear.reseat":
                try play.apply(.reseat(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterChange: true)
            case "lamp.step":
                try play.apply(.lamp(values[0]), expecting: play.fingerprint)
                advanceTutorial(afterChange: true)
            case "machine.run":
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
            case "frame.show":
                // Presentation only: the play and the digest do not change.
                guard values[0] < play.level.keyFrames.count else {
                    return .rejected(.rule(code: MoonlitMechanismExperienceRule.frame))
                }
                shownFrame = values[0]
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: MoonlitMechanismExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: MoonlitMechanismExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = MoonlitMechanismProgress.dailyLevel(year: values[0], month: values[1],
                                                                      day: values[2]) else {
                    return .rejected(.rule(code: MoonlitMechanismExperienceRule.date))
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

    /// Advances the tutorial step after an accepted turn, re-seat, lamp step, run, undo or redo
    /// (`MoonlitMechanismTutorialStep.advanced(afterChange:aligned:ended:)`): `afterChange` for a turn, re-seat or lamp
    /// step, aligned when the run report of the current set-up wins (`MoonlitMechanismTutorialStep.isAligned(_:)`),
    /// ended when the play is won or failed (never after an undo, which always lands on a moment before the end; after a
    /// redo only when it restores a won or failed moment). Never back.
    private mutating func advanceTutorial(afterChange: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterChange: afterChange, aligned: MoonlitMechanismTutorialStep.isAligned(play),
                                     ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step and key frame 0 shown; the records of the level left are dropped. Changes nothing when the kernel
    /// refuses.
    private mutating func open(number: Int, mode: MoonlitMechanismMode) throws(MoonlitMechanismError) {
        let certified: MoonlitMechanismGenerated = try Self.generated(number: number)
        let fresh: MoonlitMechanismPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedActions = MoonlitMechanismSolver.actions(certified.plan).count
        tutorial = MoonlitMechanismTutorialStep.initial(level: number)
        shownFrame = Self.openingFrame
    }

    /// After an accepted action that won the play: records the actions spent
    /// (`MoonlitMechanismProgress.actionsSpent(_:)`) against the certified witness's action count in the current mode
    /// (campaign opens the next level; daily records the best result and stars and opens nothing; practice records
    /// nothing). A won play is final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        progress.record(level: levelNumber, actionsSpent: MoonlitMechanismProgress.actionsSpent(play),
                        certified: certifiedActions, mode: mode)
    }

    /// Back to the opening state the seed chose (progress included, campaign mode, key frame 0 shown); the quality
    /// tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedActions = opening.certifiedActions
        shownFrame = Self.openingFrame
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g14.moonlit-mechanism.v2", then the level number, the play's fingerprint (level, phases, lamp height,
    /// actions spent, stage, failure), the progress and the mode (their sorted JSON); never the tutorial step or the
    /// shown key frame.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // shown key frame (presentation).
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
        var mode: MoonlitMechanismMode
        /// The progress.
        var progress: MoonlitMechanismProgress
        /// The play's records.
        var records: [MoonlitMechanismRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: MoonlitMechanismTutorialStep?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, tutorial: tutorial))
    }

    /// The core of `payload` (schema 2): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the saved progress, mode and tutorial step (the first step when absent), key frame 0 shown;
    /// a reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``MoonlitMechanismRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or tutorial
    ///   step, or a daily mode naming another level among them), a level number outside 1 … 100 or a level or trace the
    ///   kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> MoonlitMechanismExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw MoonlitMechanismRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw MoonlitMechanismRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw MoonlitMechanismRestoreRefusal.damaged
        }
        do throws(MoonlitMechanismError) {
            let certified: MoonlitMechanismGenerated = try generated(number: decoded.level)
            let play: MoonlitMechanismPlay = try MoonlitMechanismPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: MoonlitMechanismTutorialStep = decoded.tutorial
                ?? MoonlitMechanismTutorialStep.initial(level: decoded.level)
            let openingCore: MoonlitMechanismExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return MoonlitMechanismExperienceCore(levelNumber: decoded.level, play: play, progress: decoded.progress,
                                                  mode: decoded.mode, tutorial: tutorial,
                                                  certifiedActions: MoonlitMechanismSolver.actions(certified.plan).count,
                                                  openingNumber: openingCore.openingNumber,
                                                  opening: openingCore.opening)
        } catch {
            throw MoonlitMechanismRestoreRefusal.kernel(error)
        }
    }
}
