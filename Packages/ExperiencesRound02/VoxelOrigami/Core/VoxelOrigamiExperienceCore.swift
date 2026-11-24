// VoxelOrigamiExperienceCore — feature 443 (R02-G15-03) T-R02G1503-005 (FR-R02G1503-003, 005, 008, 009;
// SC-R02G1503-004; clarifications Q4, Q5; research R7; data-model.md; contracts/api.md). The adapter of the Voxel
// Origami kernel to the shared experience contract. The core holds the level number, the kernel's `VoxelOrigamiPlay`
// and the chosen hinge; it never draws and reads no clock. The presenter asks for an immutable
// `VoxelOrigamiSceneSnapshot` at its own presentation time (`snapshot(time:)`), so the preview can move while the state
// and its digest stay put (renderer purity). The snapshot carries the kernel's pose cells and exact shape report, so
// the drawn cubes are the kernel's cells and no drawn value decides a match, a covered count or the verdict. The chosen
// hinge is presentation state of the adapter (`hinge.choose [h]`): the first hinge that can turn when a level opens
// (hinge 1 when none can), never in the digest, the snapshot payload or `==`. Modelled on
// `MoonlitMechanismExperienceCore` (feature 433).
//
// Preparation: the certified level number `seed % 100 + 1` of `VoxelOrigamiManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole generator only if that candidate no longer certifies; begun (and its tutorial dismissed, as
// `VoxelOrigamiPlay.replay` does) so the play is in stage `playing`. The tutorial of levels 1 … 3 is shown by the
// presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   hinge.turn [0…11, −1…1]   a hinge and a step, whole numbers (`r02-g15.not-whole` otherwise); turns that hinge one
//                             quarter turn (1 action); the root (hinge 0), a hinge the level lacks, a step of 0 and a
//                             hinge with nothing that would move are the kernel's `r02-g15.action` (`hinge`, `step`,
//                             `idle`); a turn the lattice check refuses fails the level `collision` or `sweep`;
//   play.undo, play.redo      the kernel's exact undo and redo (`r02-g15.action` when there is nothing to undo or redo;
//                             undo works in a failed play and returns it to playing; a won play is final);
//   level.next                the next certified level with a fresh play and its first turnable hinge chosen (since
//                             feature 445 the next open level; see below);
//   hinge.choose [0…11]       chooses the shown hinge (presentation only; accepted in every stage); the root and a
//                             hinge the level lacks are refused `r02-g15.hinge`.
// The declared hinge range is the widest any level allows (`VoxelOrigamiLevel.cubeCounts`: at most 12 cubes, so hinges
// 0 … 11; the kernel or the adapter refuses the ones a level lacks). Outside stage `playing` the kernel refuses with
// `r02-g15.stage`; the last of the budget spent by a turn without a match fails the level `budget`. Every turn is
// applied with the play's current fingerprint as the expected one, so `r02-g15.stale` cannot arise. A kernel refusal
// (`VoxelOrigamiError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing.
//
// Digest ("r02-g15.voxel-origami.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the chosen hinge, the quality tier or a time. Snapshot schema 1: the JSON
// object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`VoxelOrigamiPlay.replay`), chooses the first turnable hinge, and throws `VoxelOrigamiRestoreRefusal` for a damaged
// payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another
// level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `VoxelOrigamiTier.of(t)`: level-0 = 2 bevel steps, edges 0.06 s, 2 glow shells;
// level-1 = 1 bevel step, edges 0.05 s, 1 glow shell; level-2 = plain cubes, edges 0.04 s, no glow. Outcome: `won` or
// `failed` while the play is in that stage, else nil. Rules use integers only.
//
// Feature 445 (R02-G15-05) T-R02G1505-004 (FR-R02G1505-001, 004 … 007; clarifications Q2–Q5): the core also holds the
// player's progress (`VoxelOrigamiProgress`: won levels with the least actions spent and stars, the open frontier), the
// mode (campaign, practice with the budget raised to the kernel's maximum 40, daily) and the tutorial step. No level is
// ever gated by payment: a locked level is one not yet unlocked (FR-R02G1505-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g15.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g15.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 40 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh, its first turnable hinge chosen).
// `level.next` moves to the next open level in campaign mode and is refused with `r02-g15.locked` when there is none
// (100 does not wrap). A win (the play reaching `won` on an accepted turn or redo) records
// `progress.record(level:actionsSpent:certified:mode:)` with the actions spent (`VoxelOrigamiProgress.actionsSpent`:
// every turn record, undone ones included) against the certified witness's turn count: campaign opens the next level,
// daily records the level's best result and stars and opens nothing, practice records nothing. The tutorial starts at
// `VoxelOrigamiTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced after every
// accepted turn, undo and redo by `advanced(afterTurn:ended:)` (afterTurn for a turn; ended when the play is won or
// failed — an undo never ends it, a redo only when it restores a won or failed moment), never back; `hinge.choose`
// never moves it. Digest "r02-g15.voxel-origami.v2": level, play fingerprint, progress and mode (never the tutorial
// step or the chosen hinge). Snapshot schema 2: `{"level", "mode", "progress", "records", "tutorial"}` with sorted
// keys; schema-1 payloads migrate (no won levels, level 1 open plus the levels up to the restored level, campaign mode,
// the tutorial at its first step — `turn` on the tutorial levels, else `done`).
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Voxel Origami's adapter refusals (feature 443).
public enum VoxelOrigamiExperienceRule {
    /// A value that must be a whole number (a hinge or a step) and is not.
    public static let notWhole = "r02-g15.not-whole"
    /// A hinge the level does not have, or the root (`hinge.choose`).
    public static let hinge = "r02-g15.hinge"
    /// A level that is not open yet, or no next open level (feature 445). Never a payment gate.
    public static let locked = "r02-g15.locked"
    /// An impossible calendar date (feature 445).
    public static let date = "r02-g15.date"
}

/// Why a saved Voxel Origami state was refused on restore (feature 443). A refused restore changes nothing.
public enum VoxelOrigamiRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress, the mode or the
    /// tutorial step is invalid (feature 445).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(VoxelOrigamiError)
}

/// The state of Voxel Origami as an experience (see the file header). Snapshot schema 2.
public struct VoxelOrigamiExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g15.voxel-origami"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g15.voxel-origami.v2"
    /// The action ids in declaration order.
    public static let actionIDs = ["hinge.turn", "play.undo", "play.redo", "level.next", "hinge.choose",
                                   "level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"]
    /// The budget of a practice play: the kernel's maximum (`VoxelOrigamiMode.practiceBudget`, 40).
    public static let practiceBudget: Int = VoxelOrigamiMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a step (−1 … 1; the kernel refuses 0).
    public static let stepRange: ClosedRange<Int> = -1...1
    /// The declared range of a hinge: the most cubes any level has (`VoxelOrigamiLevel.cubeCounts`, hinges 0 … 11; the
    /// root, hinge 0, is refused).
    public static let hingeRange: ClosedRange<Int> = 0...(VoxelOrigamiLevel.cubeCounts.upperBound - 1)
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: VoxelOrigamiPlay
    /// The player's progress (feature 445): in the digest and the snapshot.
    public private(set) var progress: VoxelOrigamiProgress
    /// The mode (feature 445): in the digest and the snapshot.
    public private(set) var mode: VoxelOrigamiMode
    /// The tutorial step (feature 445): in the snapshot, not in the digest.
    public private(set) var tutorial: VoxelOrigamiTutorialStep
    /// The certified witness's turn count of the current level, against which a win's stars are counted. Derived from
    /// the level number.
    public private(set) var certifiedTurns: Int
    /// The chosen hinge, 1 … cubes − 1; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var chosenHinge: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// What a reset restores (feature 445).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: VoxelOrigamiPlay
        /// The opening progress: level 1 open plus the levels up to the opening level, none won.
        let progress: VoxelOrigamiProgress
        /// The opening level's initial tutorial step.
        let tutorial: VoxelOrigamiTutorialStep
        /// The opening level's certified witness turn count.
        let certifiedTurns: Int
    }

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial` and its first turnable
    /// hinge chosen, whose reset returns to `opening` of `openingNumber`.
    init(levelNumber: Int, play: VoxelOrigamiPlay, progress: VoxelOrigamiProgress, mode: VoxelOrigamiMode,
         tutorial: VoxelOrigamiTutorialStep, certifiedTurns: Int, openingNumber: Int, opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedTurns = certifiedTurns
        self.chosenHinge = Self.openingHinge(of: play)
        self.openingNumber = openingNumber
        self.opening = opening
    }

    /// The level number a seed chooses: `seed % 100 + 1`.
    public static func levelNumber(forSeed seed: UInt64) -> Int {
        Int(seed % UInt64(levelNumbers.count)) + 1
    }

    /// The hinge chosen when `play` opens: the first hinge that can turn at its turns, else hinge 1.
    public static func openingHinge(of play: VoxelOrigamiPlay) -> Int {
        for hinge in 1..<play.level.cubes.count where play.level.canTurn(hinge, turns: play.turns) { return hinge }
        return 1
    }

    /// The certified level of manifest number `number` (1 … 100).
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func level(number: Int) throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
        try generated(number: number).level
    }

    /// The certified levels generated so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 443).
    private static let generatedCache = Mutex<[Int: VoxelOrigamiGenerated]>([:])

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/voxel-origami/levels/NNN.witness.json`, read 2026-11-24).
    public static let certifiedCandidates: [Int] = [
        3, 0, 0, 5, 0, 0, 0, 0, 1, 0, 2, 3, 1, 0, 0, 0, 0, 0, 2, 1, 0, 2, 0, 0, 3,
        0, 4, 2, 0, 1, 0, 4, 0, 0, 0, 4, 0, 5, 2, 0, 10, 1, 3, 3, 3, 1, 1, 7, 5, 2,
        3, 0, 7, 3, 0, 7, 8, 0, 0, 0, 0, 10, 9, 1, 3, 14, 6, 9, 1, 1, 0, 2, 0, 7, 0,
        2, 2, 2, 0, 5, 3, 31, 45, 7, 24, 0, 0, 0, 1, 7, 12, 3, 1, 57, 0, 12, 2, 2, 50, 3,
    ]

    /// Candidate `index` of `entry` certified exactly as ``VoxelOrigamiGenerator/generate(_:)`` certifies a candidate
    /// (a valid candidate whose minimal plan lies in its band's range and within the budget, within the solver's work
    /// bound), and whose plan wins through the kernel; nil otherwise.
    static func certify(_ entry: VoxelOrigamiManifestEntry, index: Int) -> VoxelOrigamiGenerated? {
        let range: ClosedRange<Int> = VoxelOrigamiBandProfile.of(band: entry.band).planRange
        guard let level = VoxelOrigamiGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = VoxelOrigamiSolver.plan(level, maxTurns: range.upperBound) else { return nil }
        guard range.contains(plan.size), plan.size <= entry.budget else { return nil }
        guard VoxelOrigamiSolver.matches(level, actions: plan.turns) else { return nil }
        return VoxelOrigamiGenerated(entry: entry, level: level, plan: plan,
                                     difficulty: VoxelOrigamiDifficulty(level: level, plan: plan), skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole generator runs only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(VoxelOrigamiError) -> VoxelOrigamiGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: VoxelOrigamiManifestEntry = VoxelOrigamiManifest.entries[number - 1]
        let fresh: VoxelOrigamiGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try VoxelOrigamiGenerator.generate(entry)
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: VoxelOrigamiLevel) throws(VoxelOrigamiError) -> VoxelOrigamiPlay {
        try VoxelOrigamiPlay.replay(level: level, records: [])
    }

    /// The practice copy of `level` (feature 445): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: VoxelOrigamiLevel) throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
        try VoxelOrigamiLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, cubes: level.cubes,
                              target: level.target, orientations: level.orientations,
                              budget: VoxelOrigamiMode.practice.budget(base: level.budget), tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: VoxelOrigamiGenerated,
                            mode: VoxelOrigamiMode) throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with its first turnable hinge chosen; campaign mode, level 1 open plus the levels up to
    /// `number`, none won, the tutorial at its first step.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(VoxelOrigamiError) -> VoxelOrigamiExperienceCore {
        let certified: VoxelOrigamiGenerated = try generated(number: number)
        let play: VoxelOrigamiPlay = try freshPlay(of: certified.level)
        var progress: VoxelOrigamiProgress = VoxelOrigamiProgress()
        progress.open(through: number)
        let tutorial: VoxelOrigamiTutorialStep = VoxelOrigamiTutorialStep.initial(level: number)
        let turns: Int = certified.plan.size
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedTurns: turns)
        return VoxelOrigamiExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                          tutorial: tutorial, certifiedTurns: turns, openingNumber: number,
                                          opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (cubes, the pose's cells and orientations, turns, turnable hinges, the chosen
    /// hinge, the target at the best alignment, the kernel's exact shape report, stage, failure and actions) with the
    /// level number, for drawing at the presenter's presentation time `time` (a non-finite or negative time becomes 0).
    /// Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> VoxelOrigamiSceneSnapshot {
        VoxelOrigamiSceneSnapshot(play: play, chosenHinge: chosenHinge, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `VoxelOrigamiTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: VoxelOrigamiTier { VoxelOrigamiTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `VoxelOrigamiTier.all`.
    public static var qualityTiers: Int { VoxelOrigamiTier.all.count }

    /// One level per host tier, best first, named as `VoxelOrigamiTier.all`: the element share is the bevel steps plus
    /// one over the best tier's, the iteration share the glow shells over the best tier's, the effect passes the glow
    /// shells; every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: VoxelOrigamiTier = VoxelOrigamiTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<VoxelOrigamiTier.all.count {
            let tier: VoxelOrigamiTier = VoxelOrigamiTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.bevelSteps + 1) / Double(best.bevelSteps + 1),
                                       iterationShare: Double(tier.glowShells) / Double(best.glowShells),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode and the tutorial step (not the chosen hinge,
    /// the quality tier or the opening level).
    public static func == (lhs: VoxelOrigamiExperienceCore, rhs: VoxelOrigamiExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial
    }

    // MARK: Contract

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``); a payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) }])
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 445): no won levels with level 1 open
    /// plus the levels up to the restored level, campaign mode, no tutorial key (restore starts the tutorial at its
    /// first step: `turn` on the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``VoxelOrigamiRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw VoxelOrigamiRestoreRefusal.damaged
        }
        var progress: VoxelOrigamiProgress = VoxelOrigamiProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(VoxelOrigamiMode.campaign))
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
        ExperienceControl(id: "hinge.turn", ranges: [declared(hingeRange), declared(stepRange)]),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "hinge.choose", ranges: [declared(hingeRange)]),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(VoxelOrigamiProgress.dailyYears), 1...12, 1...31]),
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

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with its first turnable hinge chosen; no clock
    /// is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> VoxelOrigamiExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(VoxelOrigamiError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Voxel Origami level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the chain changes only on an action, and the turning preview moves with the
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
                return .rejected(.rule(code: VoxelOrigamiExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(VoxelOrigamiError) {
            switch action.control {
            case "hinge.turn":
                try play.apply(.turn(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterTurn: true)
                recordIfWon()
            case "play.undo":
                try play.undo()
                advanceTutorial(afterTurn: false)
            case "play.redo":
                try play.redo()
                advanceTutorial(afterTurn: false)
                recordIfWon()
            case "hinge.choose":
                // Presentation only: the play and the digest do not change.
                guard values[0] >= 1, values[0] < play.level.cubes.count else {
                    return .rejected(.rule(code: VoxelOrigamiExperienceRule.hinge))
                }
                chosenHinge = values[0]
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: VoxelOrigamiExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: VoxelOrigamiExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = VoxelOrigamiProgress.dailyLevel(year: values[0], month: values[1], day: values[2])
                else {
                    return .rejected(.rule(code: VoxelOrigamiExperienceRule.date))
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

    /// Advances the tutorial step after an accepted turn, undo or redo
    /// (`VoxelOrigamiTutorialStep.advanced(afterTurn:ended:)`): `afterTurn` for a turn, ended when the play is won or
    /// failed (never after an undo, which always lands on a moment before the end; after a redo only when it restores a
    /// won or failed moment). Never back.
    private mutating func advanceTutorial(afterTurn: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterTurn: afterTurn, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's first
    /// tutorial step and its first turnable hinge chosen; the records of the level left are dropped. Changes nothing
    /// when the kernel refuses.
    private mutating func open(number: Int, mode: VoxelOrigamiMode) throws(VoxelOrigamiError) {
        let certified: VoxelOrigamiGenerated = try Self.generated(number: number)
        let fresh: VoxelOrigamiPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedTurns = certified.plan.size
        tutorial = VoxelOrigamiTutorialStep.initial(level: number)
        chosenHinge = Self.openingHinge(of: fresh)
    }

    /// After an accepted action that won the play: records the actions spent (`VoxelOrigamiProgress.actionsSpent(_:)`)
    /// against the certified witness's turn count in the current mode (campaign opens the next level; daily records
    /// the best result and stars and opens nothing; practice records nothing). A won play is final, so a win is
    /// recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        _ = progress.record(level: levelNumber, actionsSpent: VoxelOrigamiProgress.actionsSpent(play),
                            certified: certifiedTurns, mode: mode)
    }

    /// Back to the opening state the seed chose (progress included, campaign mode, its first turnable hinge chosen);
    /// the quality tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedTurns = opening.certifiedTurns
        chosenHinge = Self.openingHinge(of: opening.play)
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g15.voxel-origami.v2", then the level number, the play's fingerprint (level, turns, actions spent, stage,
    /// failure), the progress and the mode (their sorted JSON); never the tutorial step or the chosen hinge.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // chosen hinge (presentation).
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
        var mode: VoxelOrigamiMode
        /// The progress.
        var progress: VoxelOrigamiProgress
        /// The play's records.
        var records: [VoxelOrigamiRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: VoxelOrigamiTutorialStep?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, tutorial: tutorial))
    }

    /// The core of `payload` (schema 2): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the saved progress, mode and tutorial step (the first step when absent), its first turnable
    /// hinge chosen; a reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``VoxelOrigamiRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or tutorial
    ///   step, or a daily mode naming another level among them), a level number outside 1 … 100 or a level or trace the
    ///   kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> VoxelOrigamiExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw VoxelOrigamiRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw VoxelOrigamiRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw VoxelOrigamiRestoreRefusal.damaged
        }
        do throws(VoxelOrigamiError) {
            let certified: VoxelOrigamiGenerated = try generated(number: decoded.level)
            let play: VoxelOrigamiPlay = try VoxelOrigamiPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: VoxelOrigamiTutorialStep = decoded.tutorial
                ?? VoxelOrigamiTutorialStep.initial(level: decoded.level)
            let openingCore: VoxelOrigamiExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return VoxelOrigamiExperienceCore(levelNumber: decoded.level, play: play, progress: decoded.progress,
                                              mode: decoded.mode, tutorial: tutorial,
                                              certifiedTurns: certified.plan.size,
                                              openingNumber: openingCore.openingNumber, opening: openingCore.opening)
        } catch {
            throw VoxelOrigamiRestoreRefusal.kernel(error)
        }
    }
}
