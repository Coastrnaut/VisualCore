// HarmonicBridgesExperienceCore — feature 413 (R02-G12-03) T-R02G1203-005 (FR-R02G1203-003, 005; clarifications Q4,
// Q5; data-model.md; contracts/api.md). The adapter of the Harmonic Bridges kernel to the shared experience contract.
// The core holds the level number and the kernel's `HarmonicBridgesPlay`; it never draws and reads no clock. The
// presenter asks for an immutable `HarmonicBridgesSceneSnapshot` at its own presentation time (`snapshot(time:)`), so
// the strings can swing and the shown step can cycle while the state and its digest stay put (renderer purity). The
// snapshot carries the kernel's exact report, so the drawn wave never decides a bridge or a sample mark. The panel's
// chosen string and peg are presentation state of the controls, not kernel state (Q5).
//
// Preparation: the certified level number `seed % 100 + 1` of `HarmonicBridgesManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole generator only if that candidate no longer certifies; begun (and its tutorial dismissed, as
// `HarmonicBridgesPlay.replay` does) so the play is in stage `playing`. The tutorial of levels 1 … 3 is shown by the
// presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   string.tune [0…11, 1…12]  string and peg, whole numbers (`r02-g12.not-whole` otherwise); sets the string's peg and
//                             spends 1 action (the last of the budget without a win fails the level `budget`);
//                             a string the level lacks or a locked string is the kernel's `r02-g12.action`, a tuning to
//                             the current peg `r02-g12.noop`; outside stage `playing` `r02-g12.stage`;
//   crossing.test             tests the crossing over every step (1 action): won, or failed `broken(step, string)`;
//   play.undo, play.redo      the kernel's exact undo and redo (`r02-g12.action` when there is nothing to undo or redo;
//                             undo works in a failed play and returns it to playing; a won play is final);
//   level.next                the next certified level with a fresh play (since feature 415 the next open level; see
//                             below).
// The declared string range is the widest any level allows (`HarmonicBridgesLevel.stringCounts`: at most 12 strings);
// the level's own string count is the kernel's to check. Every tuning and test is applied with the play's current
// fingerprint as the expected one, so `r02-g12.stale` cannot arise. A kernel refusal (`HarmonicBridgesError`) becomes
// `.rule(code: error.reasonCode)`. A refused action changes nothing.
//
// Digest ("r02-g12.harmonic-bridges.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the quality tier or a time. Snapshot schema 1: the JSON object
// `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`HarmonicBridgesPlay.replay`) and throws `HarmonicBridgesRestoreRefusal` for a damaged payload, a level number
// outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another level's seed among them). An
// envelope of a newer schema is refused by the engine before the core sees it.
//
// Feature 415 (R02-G12-05) T-R02G1205-004 (FR-R02G1205-001, 004 … 007; clarifications Q2–Q5): the core also holds the
// player's progress (`HarmonicBridgesProgress`: won levels with the least actions spent and stars, the open frontier),
// the mode (campaign, practice with the budget raised to the kernel's maximum 60, daily) and the tutorial step. No
// level is ever gated by payment: a locked level is one not yet unlocked (FR-R02G1205-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g12.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g12.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the budget raised to 60 (a copy of the level);
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh). `level.next` moves to the next
// open level in campaign mode and is refused with `r02-g12.locked` when there is none (100 does not wrap). A win (the
// play reaching `won` on an accepted test) records `progress.record(level:actionsSpent:certified:mode:)` with the
// actions spent (`HarmonicBridgesProgress.actionsSpent`: every tuning and test record, undone ones included) against
// the certified witness's action count (its tunings plus the test): campaign opens the next level, daily records the
// level's best result and stars and opens nothing, practice records nothing. The tutorial starts at
// `HarmonicBridgesTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and is advanced after
// every applied tuning, test, undo and redo by `advanced(afterTune:bridged:ended:)` (afterTune for a tuning; bridged
// when the play's report reaches the goal in every step; ended when the play is won or failed — an undo never ends
// it, a redo only when it restores a failed moment), never back. Digest "r02-g12.harmonic-bridges.v2": level, play
// fingerprint, progress and mode (never the tutorial step). Snapshot schema 2: `{"level", "mode", "progress",
// "records", "tutorial"}` with sorted keys; schema-1 payloads migrate (no won levels, level 1 open plus the levels up
// to the saved level, campaign mode, the tutorial at its initial step — `tune` on the tutorial levels).
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `HarmonicBridgesTier.of(t)`: level-0 = string motion, 2 wave shells, 2 glow shells;
// level-1 = motion, 1 glow shell; level-2 = none. Outcome: `won` or `failed` while the play is in that stage, else nil.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Harmonic Bridges' adapter refusals (feature 413).
public enum HarmonicBridgesExperienceRule {
    /// A value that must be a whole number (a string index or a peg) and is not.
    public static let notWhole = "r02-g12.not-whole"
    /// A level that is not open yet, or no next open level (feature 415).
    public static let locked = "r02-g12.locked"
    /// An impossible calendar date (feature 415).
    public static let date = "r02-g12.date"
}

/// Why a saved Harmonic Bridges state was refused on restore (feature 413). A refused restore changes nothing.
public enum HarmonicBridgesRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress or the mode is
    /// invalid (feature 415).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(HarmonicBridgesError)
}

/// The state of Harmonic Bridges as an experience (see the file header). Snapshot schema 2.
public struct HarmonicBridgesExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g12.harmonic-bridges"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 2
    /// The digest's domain string (schema 2).
    public static let digestDomain = "r02-g12.harmonic-bridges.v2"
    /// The action ids in declaration order.
    public static let actionIDs = ["string.tune", "crossing.test", "play.undo", "play.redo", "level.next",
                                   "level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"]
    /// The budget of a practice play: the kernel's maximum (`HarmonicBridgesMode.practiceBudget`, 60).
    public static let practiceBudget: Int = HarmonicBridgesMode.practiceBudget
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a string index: the most strings any level has (`HarmonicBridgesLevel.stringCounts`,
    /// 0 … 11).
    public static let stringRange: ClosedRange<Int> = 0...(HarmonicBridgesLevel.stringCounts.upperBound - 1)
    /// The declared range of a peg (`HarmonicBridgesLevel.pegs`, 1 … 12).
    public static let pegRange: ClosedRange<Int> = HarmonicBridgesLevel.pegs
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: HarmonicBridgesPlay
    /// The player's progress (feature 415): in the digest and the snapshot.
    public private(set) var progress: HarmonicBridgesProgress
    /// The mode (feature 415): in the digest and the snapshot.
    public private(set) var mode: HarmonicBridgesMode
    /// The tutorial step (feature 415): in the snapshot, not in the digest.
    public private(set) var tutorial: HarmonicBridgesTutorialStep
    /// The certified witness's action count of the current level (its tunings plus the test), against which a win's
    /// stars are counted. Derived from the level number.
    public private(set) var certifiedActions: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening

    /// What a reset restores (feature 415).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: HarmonicBridgesPlay
        /// The opening progress: level 1 open plus the levels up to the opening level, none won.
        let progress: HarmonicBridgesProgress
        /// The opening level's initial tutorial step.
        let tutorial: HarmonicBridgesTutorialStep
        /// The opening level's certified witness action count.
        let certifiedActions: Int
    }
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial`, whose reset returns to
    /// `opening` of `openingNumber`.
    init(levelNumber: Int, play: HarmonicBridgesPlay, progress: HarmonicBridgesProgress, mode: HarmonicBridgesMode,
         tutorial: HarmonicBridgesTutorialStep, certifiedActions: Int, openingNumber: Int, opening: Opening) {
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
    public static func level(number: Int) throws(HarmonicBridgesError) -> HarmonicBridgesLevel {
        try generated(number: number).level
    }

    /// The certified levels generated so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 413).
    private static let generatedCache = Mutex<[Int: HarmonicBridgesGenerated]>([:])

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/harmonic-bridges/levels/NNN.witness.json`).
    public static let certifiedCandidates: [Int] = [
        0, 4, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 2, 0, 0, 1, 0, 2, 6, 0,
        1, 2, 1, 0, 1, 3, 0, 1, 3, 0, 0, 1, 1, 0, 2, 2, 14, 3, 2, 1, 3, 4, 3, 23, 0,
        0, 0, 0, 1, 5, 0, 3, 2, 13, 0, 9, 8, 1, 19, 20, 11, 27, 10, 16, 1, 3, 2, 3, 1, 9,
        0, 11, 6, 5, 35, 20, 20, 0, 6, 0, 4, 15, 12, 3, 29, 8, 9, 2, 3, 31, 16, 2, 0, 40, 4,
    ]

    /// Candidate `index` of `entry` certified exactly as ``HarmonicBridgesGenerator/generate(_:)`` certifies a
    /// candidate (a solver plan within the work bound whose tuning count is at least 1, in the band's scrambled range
    /// and at most budget − 1, and whose witness actions win through the kernel); nil otherwise.
    static func certify(_ entry: HarmonicBridgesManifestEntry, index: Int) -> HarmonicBridgesGenerated? {
        let profile: HarmonicBridgesBandProfile = .of(band: entry.band)
        guard let level = HarmonicBridgesGenerator.candidate(entry, index: index),
              let plan = HarmonicBridgesSolver.plan(level) else { return nil }
        let tunings: Int = plan.tunings.count
        guard tunings >= 1, profile.scrambled.contains(tunings), tunings <= level.budget - 1 else { return nil }
        guard HarmonicBridgesSolver.wins(level, actions: HarmonicBridgesSolver.actions(plan)) else { return nil }
        return HarmonicBridgesGenerated(entry: entry, level: level, plan: plan,
                                        difficulty: HarmonicBridgesDifficulty(level: level, plan: plan),
                                        skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole generator runs only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(HarmonicBridgesError) -> HarmonicBridgesGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: HarmonicBridgesManifestEntry = HarmonicBridgesManifest.entries[number - 1]
        let fresh: HarmonicBridgesGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try HarmonicBridgesGenerator.generate(entry)
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: HarmonicBridgesLevel) throws(HarmonicBridgesError) -> HarmonicBridgesPlay {
        try HarmonicBridgesPlay.replay(level: level, records: [])
    }

    /// The practice copy of `level` (feature 415): every field kept, the budget raised to ``practiceBudget``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(
        of level: HarmonicBridgesLevel
    ) throws(HarmonicBridgesError) -> HarmonicBridgesLevel {
        try HarmonicBridgesLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, islands: level.islands,
                                 strings: level.strings, start: level.start, goal: level.goal, steps: level.steps,
                                 threshold: level.threshold,
                                 budget: HarmonicBridgesMode.practice.budget(base: level.budget),
                                 tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: HarmonicBridgesGenerated,
                            mode: HarmonicBridgesMode) throws(HarmonicBridgesError) -> HarmonicBridgesLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions; campaign mode, level 1 open plus the levels up to `number`, none won, the tutorial at its
    /// initial step.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(HarmonicBridgesError) -> HarmonicBridgesExperienceCore {
        let certified: HarmonicBridgesGenerated = try generated(number: number)
        let play: HarmonicBridgesPlay = try freshPlay(of: certified.level)
        var progress: HarmonicBridgesProgress = HarmonicBridgesProgress()
        progress.open(through: number)
        let tutorial: HarmonicBridgesTutorialStep = HarmonicBridgesTutorialStep.initial(level: number)
        let actions: Int = certified.actions.count
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedActions: actions)
        return HarmonicBridgesExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                             tutorial: tutorial, certifiedActions: actions, openingNumber: number,
                                             opening: opening)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (islands, strings, pegs, the kernel's exact report, the resonant modes, stage,
    /// failure and actions) with the level number, for drawing at the presenter's presentation time `time` (a
    /// non-finite or negative time becomes 0). Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> HarmonicBridgesSceneSnapshot {
        HarmonicBridgesSceneSnapshot(play: play, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `HarmonicBridgesTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: HarmonicBridgesTier { HarmonicBridgesTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest).
    public static var qualityTiers: Int { HarmonicBridgesTier.all.count }

    /// One level per host tier, best first: the element share is the animated layers (string motion, wave shells)
    /// drawn over the best tier's 2, the iteration share the glow shells over the best tier's 2 and the effect passes
    /// the glow shells; every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: HarmonicBridgesTier = HarmonicBridgesTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<HarmonicBridgesTier.all.count {
            let tier: HarmonicBridgesTier = HarmonicBridgesTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(layers(tier)) / Double(layers(best)),
                                       iterationShare: Double(tier.glowShells) / Double(best.glowShells),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// The animated layers `tier` draws: the string motion and the wave shells, each 0 or 1.
    static func layers(_ tier: HarmonicBridgesTier) -> Int {
        (tier.motion ? 1 : 0) + (tier.waveShells > 0 ? 1 : 0)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number, the play, the progress, the mode and the tutorial step (not the quality tier or
    /// the opening level).
    public static func == (lhs: HarmonicBridgesExperienceCore, rhs: HarmonicBridgesExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial
    }

    // MARK: Contract

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``); a payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) }])
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 415): no won levels with level 1 open
    /// plus the levels up to the saved level, campaign mode, no tutorial key (restore starts the tutorial at its
    /// initial step: `tune` on the tutorial levels 1 … 3, else `done`).
    ///
    /// - Throws: ``HarmonicBridgesRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw HarmonicBridgesRestoreRefusal.damaged
        }
        var progress: HarmonicBridgesProgress = HarmonicBridgesProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(HarmonicBridgesMode.campaign))
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
        ExperienceControl(id: "string.tune", ranges: [declared(stringRange), declared(pegRange)]),
        ExperienceControl(id: "crossing.test"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(HarmonicBridgesProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The ten controls with their declared ranges (see the file header); `crossing.test`, `play.undo`, `play.redo`,
    /// `level.next`, `mode.practice`, `mode.campaign` and `tutorial.dismiss` take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing`; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> HarmonicBridgesExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(HarmonicBridgesError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Harmonic Bridges level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the strings change only on an action, and the wave and the shown step move with
    /// the presenter's time, not the state.
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
                return .rejected(.rule(code: HarmonicBridgesExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(HarmonicBridgesError) {
            switch action.control {
            case "string.tune":
                try play.apply(.tune(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterTune: true)
            case "crossing.test":
                try play.apply(.test, expecting: play.fingerprint)
                advanceTutorial(afterTune: false)
                recordIfWon()
            case "play.undo":
                try play.undo()
                advanceTutorial(afterTune: false)
            case "play.redo":
                try play.redo()
                advanceTutorial(afterTune: false)
                recordIfWon()
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: HarmonicBridgesExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: HarmonicBridgesExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = HarmonicBridgesProgress.dailyLevel(year: values[0], month: values[1],
                                                                     day: values[2]) else {
                    return .rejected(.rule(code: HarmonicBridgesExperienceRule.date))
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

    /// Advances the tutorial step after an accepted tuning, test, undo or redo
    /// (`HarmonicBridgesTutorialStep.advanced(afterTune:bridged:ended:)`): `afterTune` for a tuning, bridged when the
    /// play's report reaches the goal in every step, ended when the play is won or failed (never after an undo, which
    /// always lands on a moment before the end; after a redo only when it restores a failed moment). Never back.
    private mutating func advanceTutorial(afterTune: Bool) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        tutorial = tutorial.advanced(afterTune: afterTune, bridged: play.report.goalReachedInEveryStep, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's initial
    /// tutorial step; the records of the level left are dropped. Changes nothing when the kernel refuses.
    private mutating func open(number: Int, mode: HarmonicBridgesMode) throws(HarmonicBridgesError) {
        let certified: HarmonicBridgesGenerated = try Self.generated(number: number)
        let fresh: HarmonicBridgesPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedActions = certified.actions.count
        tutorial = HarmonicBridgesTutorialStep.initial(level: number)
    }

    /// After an accepted action that won the play: records the actions spent
    /// (`HarmonicBridgesProgress.actionsSpent(_:)`) against the certified witness's action count in the current mode
    /// (campaign opens the next level; daily records the best result and stars and opens nothing; practice records
    /// nothing). A won play is final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        progress.record(level: levelNumber, actionsSpent: HarmonicBridgesProgress.actionsSpent(play),
                        certified: certifiedActions, mode: mode)
    }

    /// Back to the opening state the seed chose (progress included, campaign mode); the quality tier, which is not
    /// state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedActions = opening.certifiedActions
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g12.harmonic-bridges.v2", then the level number, the play's fingerprint (level, pegs, actions spent, stage,
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
        var mode: HarmonicBridgesMode
        /// The progress.
        var progress: HarmonicBridgesProgress
        /// The play's records.
        var records: [HarmonicBridgesRecord]
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: HarmonicBridgesTutorialStep?
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
    /// - Throws: ``HarmonicBridgesRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode or a daily
    ///   mode naming another level among them), a level number outside 1 … 100 or a level or trace the kernel
    ///   refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> HarmonicBridgesExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw HarmonicBridgesRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw HarmonicBridgesRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw HarmonicBridgesRestoreRefusal.damaged
        }
        do throws(HarmonicBridgesError) {
            let certified: HarmonicBridgesGenerated = try generated(number: decoded.level)
            let play: HarmonicBridgesPlay = try HarmonicBridgesPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: HarmonicBridgesTutorialStep = decoded.tutorial
                ?? HarmonicBridgesTutorialStep.initial(level: decoded.level)
            let openingCore: HarmonicBridgesExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return HarmonicBridgesExperienceCore(levelNumber: decoded.level, play: play, progress: decoded.progress,
                                                 mode: decoded.mode, tutorial: tutorial,
                                                 certifiedActions: certified.actions.count,
                                                 openingNumber: openingCore.openingNumber,
                                                 opening: openingCore.opening)
        } catch {
            throw HarmonicBridgesRestoreRefusal.kernel(error)
        }
    }
}
