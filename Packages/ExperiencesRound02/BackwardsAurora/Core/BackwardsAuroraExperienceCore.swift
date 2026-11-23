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
//   level.next                 the next certified level (100 wraps to 1) with a fresh play.
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
}

/// Why a saved Backwards Aurora state was refused on restore (feature 393). A refused restore changes nothing.
public enum BackwardsAuroraRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(BackwardsAuroraError)
}

/// The state of Backwards Aurora as an experience (see the file header). Snapshot schema 1.
public struct BackwardsAuroraExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g10.backwards-aurora"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g10.backwards-aurora.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["wave.reverse", "play.undo", "play.redo", "level.next"]
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
    /// The kernel's play of that level.
    public private(set) var play: BackwardsAuroraPlay
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: BackwardsAuroraPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber`, whose reset returns to `openingPlay` of `openingNumber`.
    init(levelNumber: Int, play: BackwardsAuroraPlay, openingNumber: Int, openingPlay: BackwardsAuroraPlay) {
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

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(BackwardsAuroraError) -> BackwardsAuroraExperienceCore {
        let play: BackwardsAuroraPlay = try freshPlay(of: try level(number: number))
        return BackwardsAuroraExperienceCore(levelNumber: number, play: play, openingNumber: number, openingPlay: play)
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

    /// Equal states: the level number and the play (not the quality tier or the opening level).
    public static func == (lhs: BackwardsAuroraExperienceCore, rhs: BackwardsAuroraExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "wave.reverse", ranges: [declared(positionRange), declared(positionRange)]),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The four controls with their declared ranges (see the file header); the last three take no values.
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
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: BackwardsAuroraPlay = try Self.freshPlay(of: try Self.level(number: next))
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

    /// "r02-g10.backwards-aurora.v1", then the level number and the play's fingerprint (level, samples, spent, stage,
    /// failure).
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
        var records: [BackwardsAuroraRecord]
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
    /// - Throws: ``BackwardsAuroraRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level or
    ///   trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> BackwardsAuroraExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw BackwardsAuroraRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw BackwardsAuroraRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(BackwardsAuroraError) {
            let saved: BackwardsAuroraLevel = try level(number: decoded.level)
            let play: BackwardsAuroraPlay = try BackwardsAuroraPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: BackwardsAuroraPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return BackwardsAuroraExperienceCore(levelNumber: decoded.level, play: play,
                                                 openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw BackwardsAuroraRestoreRefusal.kernel(error)
        }
    }
}
