// BackwardsAuroraExperienceCore — feature 393 (R02-G10-03) T-R02G1003-005 (FR-R02G1003-003, 005; clarification Q5;
// data-model.md; contracts/api.md). The adapter of the Backwards Aurora kernel to the shared experience contract. The
// core holds the level number and the kernel's `BackwardsAuroraPlay`; it never draws and reads no clock. The presenter
// asks for an immutable `BackwardsAuroraSceneSnapshot` at its own presentation time with the panel's chosen section
// (`snapshot(sectionStart:sectionEnd:time:)`), so the pulses and the shimmer can move and the section can be chosen
// while the state and its digest stay put (renderer purity). The chosen section is presentation state of the controls,
// not kernel state (clarification Q5).
//
// Preparation: the certified level number `seed % 100 + 1` of `BackwardsAuroraManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole generator only if that candidate no longer certifies; begun (and its tutorial dismissed) so the
// play is in stage `playing`.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   wave.reverse [0…31, 0…31]  start and end of the section, whole numbers (`r02-g10.not-whole` otherwise); an end
//                              outside the wave, a start not before the end or a section length the level does not
//                              allow is the kernel's `r02-g10.action`; a palindromic section `r02-g10.noop`; any
//                              reversal outside stage `playing` `r02-g10.stage`; each spends one reversal; a tear
//                              fails, a win wins, the budget fails;
//   play.undo, play.redo       the kernel's exact undo and redo (`r02-g10.action` when there is nothing to undo or
//                              redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                 the next open certified level with a fresh play (feature 395: no longer wraps; see
//                              below).
// The declared ranges are the widest any wave allows (`BackwardsAuroraWave.lengthRange`: at most 32 samples); the
// level's own wave length and section lengths are the kernel's to check. Every reversal is applied with the play's
// current fingerprint as the expected one. A kernel refusal (`BackwardsAuroraError`) becomes
// `.rule(code: error.reasonCode)`. A refused action changes nothing.
//
// Digest ("r02-g10.backwards-aurora.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the quality tier, the chosen section or a time. Snapshot schema 1: the
// JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`BackwardsAuroraPlay.replay`) and throws `BackwardsAuroraRestoreRefusal` for a damaged payload, a level number
// outside 1 … 100 or a trace the kernel refuses (a record of a newer schema among them). An envelope of a newer schema
// is refused by the engine before the core sees it.
//
// Feature 395 (R02-G10-05) T-R02G1005-004 (FR-R02G1005-001 … 007; clarifications Q2–Q5): the core also holds the
// player's progress (`BackwardsAuroraProgress`: won levels with the fewest reversals made and stars, the open
// frontier), the mode (campaign, practice with the budget raised to the kernel's maximum 40, daily) and the tutorial
// step. No level is ever gated by payment: a locked level is one not yet unlocked (FR-R02G1005-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g10.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g10.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 40;
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh). `level.next` moves to the next
// open level in campaign mode and is refused with `r02-g10.locked` when there is none (100 does not wrap). A win (the
// play reaching `won` on an accepted reversal or redo) records `progress.record(level:reversalsMade:smallest:mode:)`
// with the reversals made (the play's reversal records, undone ones included) and the certified smallest reversal
// count (campaign opens the next level; daily never does; practice records nothing). The tutorial starts at
// `BackwardsAuroraTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and advances after each
// accepted new reversal; a redo only ends it when it ends the level; undo never moves it. Digest
// "r02-g10.backwards-aurora.v2": level, play fingerprint, progress and mode (never the tutorial step). Snapshot schema
// 2: `{"level", "mode", "progress", "records", "tutorial"}`; schema-1 payloads migrate (no won levels, the levels up to
// the saved level open, campaign mode, the tutorial at its initial step).
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `BackwardsAuroraTier.of(t)`: level-0 = 3 aurora layers, 2 pulses, 2 glow shells;
// level-1 = 2, 1, 1; level-2 = 1, 0, 0. Outcome: `won` or `failed` while the play is in that stage, else nil.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Backwards Aurora's adapter refusals (feature 393).
public enum BackwardsAuroraExperienceRule {
    /// A value that must be a whole number (a section's start or end) and is not.
    public static let notWhole = "r02-g10.not-whole"
    /// A level that is not open yet, or no next open level (feature 395).
    public static let locked = "r02-g10.locked"
    /// An impossible calendar date (feature 395).
    public static let date = "r02-g10.date"
}

/// Why a saved Backwards Aurora state was refused on restore (feature 393). A refused restore changes nothing.
public enum BackwardsAuroraRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress or the mode is
    /// invalid (feature 395).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(BackwardsAuroraError)
}

/// The state of Backwards Aurora as an experience (see the file header). Snapshot schema 2.
public struct BackwardsAuroraExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g10.backwards-aurora"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g10.backwards-aurora.v2"
    /// The action ids in declaration order.
    public static let actionIDs = ["wave.reverse", "play.undo", "play.redo", "level.next", "level.select",
                                   "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"]
    /// The budget of a practice play: the kernel's maximum (`BackwardsAuroraMode.practiceBudget`, 40).
    public static let practiceBudget: Int = BackwardsAuroraMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a section's start or end: the longest wave's positions
    /// (`BackwardsAuroraWave.lengthRange`, 0 … 31).
    public static let positionRange: ClosedRange<Int> = 0...(BackwardsAuroraWave.lengthRange.upperBound - 1)
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: BackwardsAuroraPlay
    /// The player's progress (feature 395): in the digest and the snapshot.
    public private(set) var progress: BackwardsAuroraProgress
    /// The mode (feature 395): in the digest and the snapshot.
    public private(set) var mode: BackwardsAuroraMode
    /// The tutorial step (feature 395): in the snapshot, not in the digest.
    public private(set) var tutorial: BackwardsAuroraTutorialStep
    /// The certified smallest reversal count of the current level (stars). Derived from the level number.
    public private(set) var certifiedSmallest: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening

    /// What a reset restores (feature 395).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: BackwardsAuroraPlay
        /// The opening progress: the levels up to the opening level open, none won.
        let progress: BackwardsAuroraProgress
        /// The opening level's initial tutorial step.
        let tutorial: BackwardsAuroraTutorialStep
        /// The opening level's certified smallest reversal count.
        let certifiedSmallest: Int
    }
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial`, whose reset returns to
    /// `opening` of `openingNumber`.
    init(levelNumber: Int, play: BackwardsAuroraPlay, progress: BackwardsAuroraProgress, mode: BackwardsAuroraMode,
         tutorial: BackwardsAuroraTutorialStep, certifiedSmallest: Int, openingNumber: Int, opening: Opening) {
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
    public static func level(number: Int) throws(BackwardsAuroraError) -> BackwardsAuroraLevel {
        try generated(number: number).level
    }

    /// The certified levels generated so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 393).
    private static let generatedCache = Mutex<[Int: BackwardsAuroraGenerated]>([:])

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/backwards-aurora/levels/NNN.witness.json`).
    public static let certifiedCandidates: [Int] = [
        0, 0, 0, 1, 1, 0, 0, 1, 6, 0, 1, 4, 1, 2, 0, 1, 3, 0, 0, 2, 1, 1, 8, 0, 0,
        0, 1, 0, 1, 1, 1, 1, 0, 0, 2, 1, 4, 0, 4, 2, 6, 3, 2, 2, 2, 4, 1, 0, 1, 2,
        1, 0, 1, 3, 4, 7, 0, 1, 2, 1, 3, 2, 16, 2, 5, 5, 2, 10, 0, 0, 3, 1, 5, 12, 2,
        3, 36, 13, 10, 0, 32, 20, 28, 19, 36, 1, 25, 52, 15, 30, 12, 35, 23, 16, 28, 6, 44, 3, 16, 1,
    ]

    /// Candidate `index` of `entry` certified exactly as ``BackwardsAuroraGenerator/generate(_:)`` certifies a
    /// candidate (a seam-count lower bound within the band's reversal counts and the budget, and a solution of exactly
    /// that count); nil otherwise.
    static func certify(_ entry: BackwardsAuroraManifestEntry, index: Int) -> BackwardsAuroraGenerated? {
        let profile: BackwardsAuroraBandProfile = .of(band: entry.band)
        guard let level = BackwardsAuroraGenerator.candidate(entry, index: index) else { return nil }
        let bound: BackwardsAuroraBound = BackwardsAuroraSolver.lowerBound(level)
        guard profile.reversals.contains(bound.smallest), bound.smallest <= level.budget,
              let solution = BackwardsAuroraSolver.solve(level),
              solution.smallest == bound.smallest else { return nil }
        return BackwardsAuroraGenerated(entry: entry, level: level, solution: solution, bound: bound,
                                        difficulty: BackwardsAuroraDifficulty(level: level, actions: solution.actions,
                                                                              work: solution.work),
                                        skipped: index)
    }

    /// The certified level and its solution of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole generator runs only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(BackwardsAuroraError) -> BackwardsAuroraGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: BackwardsAuroraManifestEntry = BackwardsAuroraManifest.entries[number - 1]
        let fresh: BackwardsAuroraGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try BackwardsAuroraGenerator.generate(entry)
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: BackwardsAuroraLevel) throws(BackwardsAuroraError) -> BackwardsAuroraPlay {
        try BackwardsAuroraPlay.replay(level: level, records: [])
    }

    /// The practice copy of `level` (feature 395): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: BackwardsAuroraLevel) throws(BackwardsAuroraError) -> BackwardsAuroraLevel {
        try BackwardsAuroraLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, opening: level.opening,
                                 target: level.target, checkpoints: level.checkpoints, bendLimit: level.bendLimit,
                                 breakingLimit: level.breakingLimit, shortest: level.shortest, longest: level.longest,
                                 budget: BackwardsAuroraMode.practice.budget(base: level.budget),
                                 tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: BackwardsAuroraGenerated,
                            mode: BackwardsAuroraMode) throws(BackwardsAuroraError) -> BackwardsAuroraLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions; campaign mode, the levels up to `number` open, none won, the tutorial at its initial step.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(BackwardsAuroraError) -> BackwardsAuroraExperienceCore {
        let certified: BackwardsAuroraGenerated = try generated(number: number)
        let play: BackwardsAuroraPlay = try freshPlay(of: certified.level)
        var progress: BackwardsAuroraProgress = BackwardsAuroraProgress()
        progress.open(through: number)
        let tutorial: BackwardsAuroraTutorialStep = BackwardsAuroraTutorialStep.initial(level: number)
        let smallest: Int = certified.solution.smallest
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedSmallest: smallest)
        return BackwardsAuroraExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                             tutorial: tutorial, certifiedSmallest: smallest, openingNumber: number,
                                             opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play and the level number for drawing at the presenter's presentation time `time`
    /// (seconds; a non-finite time becomes 0) with the panel's chosen section [`sectionStart`, `sectionEnd`] (clamped
    /// to the wave by the snapshot). Reads only; the state and its digest do not change.
    public func snapshot(sectionStart: Int, sectionEnd: Int, time: Double) -> BackwardsAuroraSceneSnapshot {
        BackwardsAuroraSceneSnapshot(play: play, levelNumber: levelNumber, sectionStart: sectionStart,
                                     sectionEnd: sectionEnd, time: time)
    }

    /// The tier the host quality tier draws: `BackwardsAuroraTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: BackwardsAuroraTier { BackwardsAuroraTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest).
    public static var qualityTiers: Int { BackwardsAuroraTier.all.count }

    /// One level per host tier, best first: the element share is the aurora layers over the best tier's 3, the
    /// iteration share the pulses over 2 and the effect passes the glow shells; every level draws at the full
    /// resolution.
    public static var qualityProfile: QualityProfile {
        let best: BackwardsAuroraTier = BackwardsAuroraTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<BackwardsAuroraTier.all.count {
            let tier: BackwardsAuroraTier = BackwardsAuroraTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.trailingLayers) / Double(best.trailingLayers),
                                       iterationShare: Double(tier.pulses) / Double(best.pulses),
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
    public static func == (lhs: BackwardsAuroraExperienceCore, rhs: BackwardsAuroraExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial
    }

    // MARK: Contract

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``); a payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) }])
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 395): no won levels with the levels up
    /// to the saved level open, campaign mode, no tutorial key (restore starts the tutorial at its initial step).
    ///
    /// - Throws: ``BackwardsAuroraRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw BackwardsAuroraRestoreRefusal.damaged
        }
        var progress: BackwardsAuroraProgress = BackwardsAuroraProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(BackwardsAuroraMode.campaign))
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
        ExperienceControl(id: "wave.reverse", ranges: [declared(positionRange), declared(positionRange)]),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(BackwardsAuroraProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The nine controls with their declared ranges (see the file header); `play.undo`, `play.redo`, `level.next`,
    /// `mode.practice`, `mode.campaign` and `tutorial.dismiss` take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing`; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> BackwardsAuroraExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(BackwardsAuroraError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Backwards Aurora level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the wave changes only on an action, and the pulses and the shimmer move with the
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
                return .rejected(.rule(code: BackwardsAuroraExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(BackwardsAuroraError) {
            switch action.control {
            case "wave.reverse":
                try play.apply(.reverse(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial()
                recordIfWon()
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
                advanceTutorial()
                recordIfWon()
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: BackwardsAuroraExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: BackwardsAuroraExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = BackwardsAuroraProgress.dailyLevel(year: values[0], month: values[1],
                                                                     day: values[2]) else {
                    return .rejected(.rule(code: BackwardsAuroraExperienceRule.date))
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

    /// Advances the tutorial step after an accepted reversal or redo
    /// (`BackwardsAuroraTutorialStep.advanced(afterReversal:ended:)`): a new reversal moves it on, the end of the level
    /// ends it; an undo never moves the step and a redo only ends it when it ends the level.
    private mutating func advanceTutorial() {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        let afterReversal: Bool = play.records.last?.kind == .reverse
        tutorial = tutorial.advanced(afterReversal: afterReversal, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's initial
    /// tutorial step; the records of the level left are dropped. Changes nothing when the kernel refuses.
    private mutating func open(number: Int, mode: BackwardsAuroraMode) throws(BackwardsAuroraError) {
        let certified: BackwardsAuroraGenerated = try Self.generated(number: number)
        let fresh: BackwardsAuroraPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedSmallest = certified.solution.smallest
        tutorial = BackwardsAuroraTutorialStep.initial(level: number)
    }

    /// After an accepted action that won the play: records the reversals made against the certified smallest reversal
    /// count in the current mode (campaign opens the next level; daily does not; practice records nothing). A won play
    /// is final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        progress.record(level: levelNumber, reversalsMade: BackwardsAuroraProgress.reversalsMade(play),
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

    /// "r02-g10.backwards-aurora.v2", then the level number, the play's fingerprint (level, samples, spent, stage,
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
        var mode: BackwardsAuroraMode
        /// The progress.
        var progress: BackwardsAuroraProgress
        /// The play's records.
        var records: [BackwardsAuroraRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: BackwardsAuroraTutorialStep?
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
    /// - Throws: ``BackwardsAuroraRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or a daily
    ///   mode naming another level among them), a level number outside 1 … 100 or a level or trace the kernel
    ///   refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> BackwardsAuroraExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw BackwardsAuroraRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw BackwardsAuroraRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw BackwardsAuroraRestoreRefusal.damaged
        }
        do throws(BackwardsAuroraError) {
            let certified: BackwardsAuroraGenerated = try generated(number: decoded.level)
            let play: BackwardsAuroraPlay = try BackwardsAuroraPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: BackwardsAuroraTutorialStep = decoded.tutorial
                ?? BackwardsAuroraTutorialStep.initial(level: decoded.level)
            let openingCore: BackwardsAuroraExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return BackwardsAuroraExperienceCore(levelNumber: decoded.level, play: play, progress: decoded.progress,
                                                 mode: decoded.mode, tutorial: tutorial,
                                                 certifiedSmallest: certified.solution.smallest,
                                                 openingNumber: openingCore.openingNumber,
                                                 opening: openingCore.opening)
        } catch {
            throw BackwardsAuroraRestoreRefusal.kernel(error)
        }
    }
}
