// NocturneGardenExperienceCore — feature 383 (R02-G09-03) T-R02G0903-005 (FR-R02G0903-005, 008, 009; clarifications
// Q4, Q5; data-model.md "Controls"; contracts/api.md). The adapter of the Nocturne Garden kernel to the shared
// experience contract. The core holds the level number and the kernel's `NocturneGardenPlay`; it never draws and reads
// no clock. The presenter asks for an immutable `NocturneGardenSceneSnapshot` at its own presentation time
// (`snapshot(time:)`), so the mist and the sway can move while the state and its digest stay put (renderer purity).
//
// Preparation: the certified level number `seed % 100 + 1` of `NocturneGardenManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), begun (and its tutorial dismissed) so the play is in stage `playing`.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   bloom.plant [0…5, 0…31, 0…23, 1…3]  kind (`NocturneGardenKind.order`), column, row and size;
//   bloom.move [0…11, 0…31, 0…23]       bloom, column and row;
//   bloom.resize [0…11, 1…3]            bloom and size;
//   bloom.remove [0…11]                 bloom;
//   sun.set [1…4]                       elevation;
//                                       all whole numbers (`r02-g09.not-whole` otherwise); an anchor outside the bed, a
//                                       size or elevation the level does not allow or a bloom the play does not have is
//                                       the kernel's `r02-g09.action`; a used-up kind `r02-g09.supply`; a change to the
//                                       same cell, size or elevation `r02-g09.noop`; any action outside stage `playing`
//                                       `r02-g09.stage`; each spends one move; a leak fails, a match wins, the budget
//                                       fails;
//   play.undo, play.redo                the kernel's exact undo and redo (`r02-g09.action` when there is nothing to undo
//                                       or redo; undo works in a failed play and returns it to playing; a won play is
//                                       final);
//   level.next                          the next open certified level with a fresh play (feature 385: no longer
//                                       wraps; see below).
// The declared ranges are the widest any level allows (`NocturneGardenLevel.widths`, `heights`, `supplyTotals`;
// `NocturneGardenBloom.sizes`, `elevations`); the level's own bed, sizes and elevations are the kernel's to check.
// Every kernel action is applied with the play's current fingerprint as the expected one. A kernel refusal
// (`NocturneGardenError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing.
//
// Digest ("r02-g09.nocturne-garden.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the quality tier or a time. Snapshot schema 1: the JSON object
// `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`NocturneGardenPlay.replay`) and throws `NocturneGardenRestoreRefusal` for a damaged payload, a level number outside
// 1 … 100 or a trace the kernel refuses (a record of a newer schema among them). An envelope of a newer schema is
// refused by the engine before the core sees it.
//
// Feature 385 (R02-G09-05) T-R02G0905-004 (FR-R02G0905-001 … 005; clarifications Q2–Q5): the core also holds the
// player's progress (`NocturneGardenProgress`: won levels with the fewest moves made and stars, the open frontier), the
// mode (campaign, practice with the budget raised to the kernel's maximum 40, daily) and the tutorial step. New
// actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g09.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g09.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 40;
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing daily or practice drops the left level's records (the play starts fresh). `level.next` moves to the next
// open level in campaign mode and is refused with `r02-g09.locked` when there is none (100 does not wrap). A win (the
// play reaching `won` on an accepted move or redo) records `progress.record(level:movesMade:smallest:mode:)` with the
// moves made (the play's action records, undone ones included) and the certified smallest move count (campaign opens
// the next level; daily never does; practice records nothing). The tutorial starts at
// `NocturneGardenTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and advances after each
// accepted new move (plant, move, resize, remove, sun); a redo only ends it when it ends the level; undo and redo never
// move it otherwise. Digest "r02-g09.nocturne-garden.v2": level, play fingerprint, progress and mode (never the
// tutorial step). Snapshot schema 2: `{"level", "mode", "progress", "records", "tutorial"}`; schema-1 payloads migrate
// (no won levels, the levels up to the saved level open, campaign mode, the tutorial at its initial step).
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `NocturneGardenTier.of(t)`: level-0 = 3 mist layers, stem depth 3, feather 0.3, 2 glow
// shells; level-1 = 2, 2, 0.15, 1; level-2 = 1, 1, 0, 0. Outcome: `won` or `failed` while the play is in that stage,
// else nil.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Nocturne Garden's adapter refusals (feature 383).
public enum NocturneGardenExperienceRule {
    /// A value that must be a whole number (kind, column, row, size, bloom, elevation) and is not.
    public static let notWhole = "r02-g09.not-whole"
    /// A level that is not open yet, or no next open level (feature 385).
    public static let locked = "r02-g09.locked"
    /// An impossible calendar date (feature 385).
    public static let date = "r02-g09.date"
}

/// Why a saved Nocturne Garden state was refused on restore (feature 383). A refused restore changes nothing.
public enum NocturneGardenRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress or the mode is
    /// invalid (feature 385).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(NocturneGardenError)
}

/// The state of Nocturne Garden as an experience (see the file header). Snapshot schema 2.
public struct NocturneGardenExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g09.nocturne-garden"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g09.nocturne-garden.v2"
    /// The action ids in declaration order.
    public static let actionIDs = ["bloom.plant", "bloom.move", "bloom.resize", "bloom.remove", "sun.set",
                                   "play.undo", "play.redo", "level.next", "level.select", "mode.daily",
                                   "mode.practice", "mode.campaign", "tutorial.dismiss"]
    /// The budget of a practice play: the kernel's maximum (`NocturneGardenMode.practiceBudget`, 40).
    public static let practiceBudget: Int = NocturneGardenMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a bloom kind: `NocturneGardenKind.order`, tulip 0 … lily 5.
    public static let kindRange: ClosedRange<Int> = 0...(NocturneGardenKind.allCases.count - 1)
    /// The declared range of a column: the widest bed's columns (`NocturneGardenLevel.widths`).
    public static let columnRange: ClosedRange<Int> = 0...(NocturneGardenLevel.widths.upperBound - 1)
    /// The declared range of a row: the tallest bed's rows (`NocturneGardenLevel.heights`).
    public static let rowRange: ClosedRange<Int> = 0...(NocturneGardenLevel.heights.upperBound - 1)
    /// The declared range of a bloom size: `NocturneGardenBloom.sizes` (1 … 3).
    public static let sizeRange: ClosedRange<Int> = NocturneGardenBloom.sizes
    /// The declared range of a bloom index: a play has at most the largest supply of blooms
    /// (`NocturneGardenLevel.supplyTotals`).
    public static let bloomRange: ClosedRange<Int> = 0...(NocturneGardenLevel.supplyTotals.upperBound - 1)
    /// The declared range of a sun elevation: `NocturneGardenBloom.elevations` (1 … 4).
    public static let elevationRange: ClosedRange<Int> = NocturneGardenBloom.elevations
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: NocturneGardenPlay
    /// The player's progress (feature 385): in the digest and the snapshot.
    public private(set) var progress: NocturneGardenProgress
    /// The mode (feature 385): in the digest and the snapshot.
    public private(set) var mode: NocturneGardenMode
    /// The tutorial step (feature 385): in the snapshot, not in the digest.
    public private(set) var tutorial: NocturneGardenTutorialStep
    /// The certified smallest move count of the current level (stars). Derived from the level number.
    public private(set) var certifiedSmallest: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening

    /// What a reset restores (feature 385).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: NocturneGardenPlay
        /// The opening progress: the levels up to the opening level open, none won.
        let progress: NocturneGardenProgress
        /// The opening level's initial tutorial step.
        let tutorial: NocturneGardenTutorialStep
        /// The opening level's certified smallest move count.
        let certifiedSmallest: Int
    }
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial`, whose reset returns to
    /// `opening` of `openingNumber`.
    init(levelNumber: Int, play: NocturneGardenPlay, progress: NocturneGardenProgress, mode: NocturneGardenMode,
         tutorial: NocturneGardenTutorialStep, certifiedSmallest: Int, openingNumber: Int, opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedSmallest = certifiedSmallest
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
    public static func level(number: Int) throws(NocturneGardenError) -> NocturneGardenLevel {
        try generated(number: number).level
    }

    /// The certified levels generated so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 383).
    private static let generatedCache = Mutex<[Int: NocturneGardenGenerated]>([:])

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/nocturne-garden/levels/NNN.witness.json`).
    public static let certifiedCandidates: [Int] = [
        0, 1, 0, 2, 13, 1, 2, 1, 0, 1, 1, 1, 0, 5, 0, 5, 0, 0, 1, 4, 3, 10, 2, 2, 0,
        2, 8, 1, 0, 2, 4, 4, 7, 0, 2, 4, 1, 8, 8, 0, 0, 1, 2, 3, 0, 6, 3, 1, 8, 0,
        11, 0, 1, 0, 14, 1, 2, 6, 1, 6, 16, 5, 3, 5, 25, 7, 7, 19, 4, 5, 0, 0, 0, 3, 5,
        6, 1, 5, 2, 0, 0, 2, 9, 0, 16, 5, 4, 11, 3, 1, 2, 6, 4, 3, 1, 7, 0, 0, 5, 1,
    ]

    /// Candidate `index` of `entry` certified exactly as ``NocturneGardenGenerator/generate(_:)`` certifies a candidate
    /// (a lower bound whose smallest move count is in the band's range and within the budget, and a solution of exactly
    /// that count); nil otherwise.
    static func certify(_ entry: NocturneGardenManifestEntry, index: Int) -> NocturneGardenGenerated? {
        let profile: NocturneGardenBandProfile = .of(band: entry.band)
        guard let level = NocturneGardenGenerator.candidate(entry, index: index),
              let bound = NocturneGardenSolver.lowerBound(level),
              profile.smallest.contains(bound.smallest), bound.smallest <= level.budget,
              let solution = NocturneGardenSolver.solve(level),
              solution.smallest == bound.smallest else { return nil }
        return NocturneGardenGenerated(entry: entry, level: level, solution: solution, bound: bound,
                                       difficulty: NocturneGardenDifficulty(level: level, actions: solution.actions,
                                                                            work: solution.work),
                                       skipped: index)
    }

    /// The certified level and its solution of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole generator runs only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(NocturneGardenError) -> NocturneGardenGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: NocturneGardenManifestEntry = NocturneGardenManifest.entries[number - 1]
        let fresh: NocturneGardenGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try NocturneGardenGenerator.generate(entry)
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: NocturneGardenLevel) throws(NocturneGardenError) -> NocturneGardenPlay {
        try NocturneGardenPlay.replay(level: level, records: [])
    }

    /// The practice copy of `level` (feature 385): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: NocturneGardenLevel) throws(NocturneGardenError) -> NocturneGardenLevel {
        try NocturneGardenLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, width: level.width,
                                height: level.height, target: level.target, forbidden: level.forbidden,
                                supply: level.supply, sizes: level.sizes, elevations: level.elevations,
                                sun: level.sun, budget: NocturneGardenMode.practice.budget(base: level.budget),
                                required: level.required, leakAllowance: level.leakAllowance,
                                tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: NocturneGardenGenerated,
                            mode: NocturneGardenMode) throws(NocturneGardenError) -> NocturneGardenLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: campaign mode, the levels up to `number` open, none won, the
    /// tutorial at its initial step.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(NocturneGardenError) -> NocturneGardenExperienceCore {
        let certified: NocturneGardenGenerated = try generated(number: number)
        let play: NocturneGardenPlay = try freshPlay(of: certified.level)
        var progress: NocturneGardenProgress = NocturneGardenProgress()
        progress.open(through: number)
        let tutorial: NocturneGardenTutorialStep = NocturneGardenTutorialStep.initial(level: number)
        let smallest: Int = certified.solution.smallest
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedSmallest: smallest)
        return NocturneGardenExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                            tutorial: tutorial, certifiedSmallest: smallest, openingNumber: number,
                                            opening: opening)
    }

    /// The bloom kind of control value `index` (`NocturneGardenKind.order`), or nil outside 0 … 5.
    public static func kind(_ index: Int) -> NocturneGardenKind? {
        NocturneGardenKind.allCases.first { $0.order == index }
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play and the level number for drawing at the presenter's presentation time `time`
    /// (seconds; a non-finite time becomes 0). Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> NocturneGardenSceneSnapshot {
        NocturneGardenSceneSnapshot(play: play, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `NocturneGardenTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: NocturneGardenTier { NocturneGardenTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest).
    public static var qualityTiers: Int { NocturneGardenTier.all.count }

    /// One level per host tier, best first: the element share is the stem depth over the best tier's 3, the iteration
    /// share the mist layers over 3 and the effect passes the glow shells; every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: NocturneGardenTier = NocturneGardenTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<NocturneGardenTier.all.count {
            let tier: NocturneGardenTier = NocturneGardenTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.stemDepth) / Double(best.stemDepth),
                                       iterationShare: Double(tier.mistLayers) / Double(best.mistLayers),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode and the tutorial step (not the quality tier or
    /// the opening level).
    public static func == (lhs: NocturneGardenExperienceCore, rhs: NocturneGardenExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial
    }

    // MARK: Contract

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``); a payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) }])
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 385): no won levels with the levels up
    /// to the saved level open, campaign mode, no tutorial key (restore starts the tutorial at its initial step).
    ///
    /// - Throws: ``NocturneGardenRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw NocturneGardenRestoreRefusal.damaged
        }
        var progress: NocturneGardenProgress = NocturneGardenProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(NocturneGardenMode.campaign))
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
        ExperienceControl(id: "bloom.plant", ranges: [declared(kindRange), declared(columnRange), declared(rowRange),
                                                      declared(sizeRange)]),
        ExperienceControl(id: "bloom.move", ranges: [declared(bloomRange), declared(columnRange), declared(rowRange)]),
        ExperienceControl(id: "bloom.resize", ranges: [declared(bloomRange), declared(sizeRange)]),
        ExperienceControl(id: "bloom.remove", ranges: [declared(bloomRange)]),
        ExperienceControl(id: "sun.set", ranges: [declared(elevationRange)]),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(NocturneGardenProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The thirteen controls with their declared ranges (see the file header); `play.undo`, `play.redo`, `level.next`,
    /// `mode.practice`, `mode.campaign` and `tutorial.dismiss` take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing`; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> NocturneGardenExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(NocturneGardenError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Nocturne Garden level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the garden changes only on an action, and the mist and the sway move with the
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
                return .rejected(.rule(code: NocturneGardenExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(NocturneGardenError) {
            switch action.control {
            case "bloom.plant":
                guard let kind = Self.kind(values[0]) else { throw .action("kind") }
                try applyMove(.plant(kind, values[1], values[2], values[3]))
            case "bloom.move":
                try applyMove(.move(values[0], values[1], values[2]))
            case "bloom.resize":
                try applyMove(.resize(values[0], values[1]))
            case "bloom.remove":
                try applyMove(.remove(values[0]))
            case "sun.set":
                try applyMove(.sun(values[0]))
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
                advanceTutorial()
                recordIfWon()
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: NocturneGardenExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: NocturneGardenExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = NocturneGardenProgress.dailyLevel(year: values[0], month: values[1],
                                                                    day: values[2]) else {
                    return .rejected(.rule(code: NocturneGardenExperienceRule.date))
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

    /// Applies the kernel move `action` with the play's current fingerprint, then advances the tutorial and records a
    /// win.
    ///
    /// - Throws: the kernel's refusal; then nothing changed.
    private mutating func applyMove(_ action: NocturneGardenAction) throws(NocturneGardenError) {
        try play.apply(action, expecting: play.fingerprint)
        advanceTutorial()
        recordIfWon()
    }

    /// Advances the tutorial step after an accepted move or redo (`NocturneGardenTutorialStep.advanced(afterMove:
    /// ended:)`): a new move moves it on, the end of the level ends it; an undo or a redo never moves the step (a redo
    /// only ends it when it ends the level).
    private mutating func advanceTutorial() {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        let kind: NocturneGardenRecordKind? = play.records.last?.kind
        let afterMove: Bool = kind != nil && kind != .undo && kind != .redo
        tutorial = tutorial.advanced(afterMove: afterMove, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's initial
    /// tutorial step; the records of the level left are dropped. Changes nothing when the kernel refuses.
    private mutating func open(number: Int, mode: NocturneGardenMode) throws(NocturneGardenError) {
        let certified: NocturneGardenGenerated = try Self.generated(number: number)
        let fresh: NocturneGardenPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedSmallest = certified.solution.smallest
        tutorial = NocturneGardenTutorialStep.initial(level: number)
    }

    /// After an accepted action that won the play: records the moves made against the certified smallest move count
    /// in the current mode (campaign opens the next level; daily does not; practice records nothing). A won play is
    /// final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        progress.record(level: levelNumber, movesMade: NocturneGardenProgress.movesMade(play),
                        smallest: certifiedSmallest, mode: mode)
    }

    /// Back to the opening state the seed chose (progress included); the quality tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedSmallest = opening.certifiedSmallest
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g09.nocturne-garden.v2", then the level number, the play's fingerprint (level, blooms, sun, moves, stage,
    /// failure), the progress and the mode (their sorted JSON); never the tutorial step.
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

    /// The payload's JSON form (schema 2); `tutorial` is absent in a migrated schema-1 payload.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The mode.
        var mode: NocturneGardenMode
        /// The progress.
        var progress: NocturneGardenProgress
        /// The play's records.
        var records: [NocturneGardenRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: NocturneGardenTutorialStep?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "tutorial"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, tutorial: tutorial))
    }

    /// The core of `payload` (schema 2): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the saved progress, mode and tutorial step (the initial step when absent); a reset returns
    /// to the opening state `seed` chooses.
    ///
    /// - Throws: ``NocturneGardenRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or a daily
    ///   mode naming another level among them), a level number outside 1 … 100 or a level or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> NocturneGardenExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw NocturneGardenRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw NocturneGardenRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw NocturneGardenRestoreRefusal.damaged
        }
        do throws(NocturneGardenError) {
            let certified: NocturneGardenGenerated = try generated(number: decoded.level)
            let play: NocturneGardenPlay = try NocturneGardenPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: NocturneGardenTutorialStep = decoded.tutorial
                ?? NocturneGardenTutorialStep.initial(level: decoded.level)
            let openingCore: NocturneGardenExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return NocturneGardenExperienceCore(levelNumber: decoded.level, play: play, progress: decoded.progress,
                                                mode: decoded.mode, tutorial: tutorial,
                                                certifiedSmallest: certified.solution.smallest,
                                                openingNumber: openingCore.openingNumber,
                                                opening: openingCore.opening)
        } catch {
            throw NocturneGardenRestoreRefusal.kernel(error)
        }
    }
}
