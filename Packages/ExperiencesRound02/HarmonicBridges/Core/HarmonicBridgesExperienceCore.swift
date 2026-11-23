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
//   level.next                the next certified level (100 wraps to 1) with a fresh play.
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
}

/// Why a saved Harmonic Bridges state was refused on restore (feature 413). A refused restore changes nothing.
public enum HarmonicBridgesRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(HarmonicBridgesError)
}

/// The state of Harmonic Bridges as an experience (see the file header). Snapshot schema 1.
public struct HarmonicBridgesExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g12.harmonic-bridges"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g12.harmonic-bridges.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["string.tune", "crossing.test", "play.undo", "play.redo", "level.next"]
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
    /// The kernel's play of that level.
    public private(set) var play: HarmonicBridgesPlay
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: HarmonicBridgesPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber`, whose reset returns to `openingPlay` of `openingNumber`.
    init(levelNumber: Int, play: HarmonicBridgesPlay, openingNumber: Int, openingPlay: HarmonicBridgesPlay) {
        self.levelNumber = levelNumber
        self.play = play
        self.openingNumber = openingNumber
        self.openingPlay = openingPlay
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

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(HarmonicBridgesError) -> HarmonicBridgesExperienceCore {
        let play: HarmonicBridgesPlay = try freshPlay(of: try level(number: number))
        return HarmonicBridgesExperienceCore(levelNumber: number, play: play, openingNumber: number,
                                             openingPlay: play)
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

    /// Equal states: the level number and the play (not the quality tier or the opening level).
    public static func == (lhs: HarmonicBridgesExperienceCore, rhs: HarmonicBridgesExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "string.tune", ranges: [declared(stringRange), declared(pegRange)]),
        ExperienceControl(id: "crossing.test"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The five controls with their declared ranges (see the file header); the last four take no values.
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
            case "crossing.test":
                try play.apply(.test, expecting: play.fingerprint)
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: HarmonicBridgesPlay = try Self.freshPlay(of: try Self.level(number: next))
                levelNumber = next
                play = fresh
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

    /// Back to the fresh play of the level the seed chose; the quality tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = openingPlay
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g12.harmonic-bridges.v1", then the level number and the play's fingerprint (level, pegs, actions spent,
    /// stage, failure).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly.
        builder.add(play.fingerprint)
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The play's records.
        var records: [HarmonicBridgesRecord]
    }

    /// The JSON object `{"level", "records"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(level: levelNumber, records: play.records))
    }

    /// The core of `payload`: the records replayed on a fresh play of the saved level; a reset returns to the level
    /// `seed` chooses.
    ///
    /// - Throws: ``HarmonicBridgesRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level
    ///   or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> HarmonicBridgesExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw HarmonicBridgesRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw HarmonicBridgesRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(HarmonicBridgesError) {
            let saved: HarmonicBridgesLevel = try level(number: decoded.level)
            let play: HarmonicBridgesPlay = try HarmonicBridgesPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: HarmonicBridgesPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return HarmonicBridgesExperienceCore(levelNumber: decoded.level, play: play,
                                                 openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw HarmonicBridgesRestoreRefusal.kernel(error)
        }
    }
}
