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
//   level.next                          the next certified level (100 wraps to 1) with a fresh play.
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
}

/// Why a saved Nocturne Garden state was refused on restore (feature 383). A refused restore changes nothing.
public enum NocturneGardenRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(NocturneGardenError)
}

/// The state of Nocturne Garden as an experience (see the file header). Snapshot schema 1.
public struct NocturneGardenExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g09.nocturne-garden"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g09.nocturne-garden.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["bloom.plant", "bloom.move", "bloom.resize", "bloom.remove", "sun.set",
                                   "play.undo", "play.redo", "level.next"]
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
    /// The kernel's play of that level.
    public private(set) var play: NocturneGardenPlay
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: NocturneGardenPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber`, whose reset returns to `openingPlay` of `openingNumber`.
    init(levelNumber: Int, play: NocturneGardenPlay, openingNumber: Int, openingPlay: NocturneGardenPlay) {
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

    /// The opening state of manifest number `number`.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(NocturneGardenError) -> NocturneGardenExperienceCore {
        let play: NocturneGardenPlay = try freshPlay(of: try level(number: number))
        return NocturneGardenExperienceCore(levelNumber: number, play: play, openingNumber: number, openingPlay: play)
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

    /// Equal states: the level number and the play (not the quality tier or the opening level).
    public static func == (lhs: NocturneGardenExperienceCore, rhs: NocturneGardenExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

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
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The eight controls with their declared ranges (see the file header); the last three take no values.
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
                try play.apply(.plant(kind, values[1], values[2], values[3]), expecting: play.fingerprint)
            case "bloom.move":
                try play.apply(.move(values[0], values[1], values[2]), expecting: play.fingerprint)
            case "bloom.resize":
                try play.apply(.resize(values[0], values[1]), expecting: play.fingerprint)
            case "bloom.remove":
                try play.apply(.remove(values[0]), expecting: play.fingerprint)
            case "sun.set":
                try play.apply(.sun(values[0]), expecting: play.fingerprint)
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: NocturneGardenPlay = try Self.freshPlay(of: try Self.level(number: next))
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

    /// "r02-g09.nocturne-garden.v1", then the level number and the play's fingerprint (level, blooms, sun, moves,
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
        var records: [NocturneGardenRecord]
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
    /// - Throws: ``NocturneGardenRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level or
    ///   trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> NocturneGardenExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw NocturneGardenRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw NocturneGardenRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(NocturneGardenError) {
            let saved: NocturneGardenLevel = try level(number: decoded.level)
            let play: NocturneGardenPlay = try NocturneGardenPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: NocturneGardenPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return NocturneGardenExperienceCore(levelNumber: decoded.level, play: play,
                                                openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw NocturneGardenRestoreRefusal.kernel(error)
        }
    }
}
