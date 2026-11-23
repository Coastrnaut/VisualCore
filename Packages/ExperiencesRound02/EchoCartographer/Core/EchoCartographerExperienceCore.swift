// EchoCartographerExperienceCore — feature 403 (R02-G11-03) T-R02G1103-005 (FR-R02G1103-003, 005; clarifications Q4,
// Q5; data-model.md; contracts/api.md). The adapter of the Echo Cartographer kernel to the shared experience contract.
// The core holds the level number and the kernel's `EchoCartographerPlay`; it never draws and reads no clock. The
// presenter asks for an immutable `EchoCartographerSceneSnapshot` at its own presentation time (`snapshot(time:)`), so
// the rings and flares can move while the state and its digest stay put (renderer purity). The snapshot copies only
// what the player knows: the play's knowledge (which reveals only true walls) and the located beacons, never an unknown
// wall or an unlocated beacon. The panel's cursor is presentation state of the controls, not kernel state (Q5).
//
// Preparation: the certified level number `seed % 100 + 1` of `EchoCartographerManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole generator only if that candidate no longer certifies; begun (and its tutorial dismissed, as
// `EchoCartographerPlay.replay` does) so the play is in stage `playing`. The tutorial of levels 1 … 3 is shown by the
// presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   cell.pulse [0…15, 0…15]  column and row, whole numbers (`r02-g11.not-whole` otherwise); a pulse from the cell (1
//                            energy, reveals its rays);
//   cell.claim [0…15, 0…15]  a claim at the cell (free on a hit, the miss cost on a miss);
//   cell.mark  [0…15, 0…15]  toggles a marker (free; at most 8);
//                            a cell outside the chamber, a pulse from a cell not known open, a claim on a known wall or
//                            a ninth marker is the kernel's `r02-g11.action`; a claim within the tolerance only of
//                            located beacons `r02-g11.noop`; any of them outside stage `playing` `r02-g11.stage`;
//   play.undo, play.redo     the kernel's exact undo and redo (`r02-g11.action` when there is nothing to undo or redo;
//                            undo works in a failed play and returns it to playing; a won play is final);
//   level.next               the next certified level (100 wraps to 1) with a fresh play.
// The declared ranges are the widest any chamber allows (`EchoCartographerChamber.sizeRange`: at most 16 cells a side);
// the level's own chamber is the kernel's to check. Every cell action is applied with the play's current fingerprint as
// the expected one, so `r02-g11.stale` cannot arise. A kernel refusal (`EchoCartographerError`) becomes
// `.rule(code: error.reasonCode)`. A refused action changes nothing.
//
// Digest ("r02-g11.echo-cartographer.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the quality tier or a time. Snapshot schema 1: the JSON object
// `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`EchoCartographerPlay.replay`) and throws `EchoCartographerRestoreRefusal` for a damaged payload, a level number
// outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another level's seed among them). An
// envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `EchoCartographerTier.of(t)`: level-0 = rings, flare trails, 2 glow shells; level-1 =
// rings, 1 shell; level-2 = none. Outcome: `won` or `failed` while the play is in that stage, else nil.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Echo Cartographer's adapter refusals (feature 403).
public enum EchoCartographerExperienceRule {
    /// A value that must be a whole number (a cell's column or row) and is not.
    public static let notWhole = "r02-g11.not-whole"
}

/// Why a saved Echo Cartographer state was refused on restore (feature 403). A refused restore changes nothing.
public enum EchoCartographerRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(EchoCartographerError)
}

/// The state of Echo Cartographer as an experience (see the file header). Snapshot schema 1.
public struct EchoCartographerExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g11.echo-cartographer"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g11.echo-cartographer.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["cell.pulse", "cell.claim", "cell.mark", "play.undo", "play.redo", "level.next"]
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a cell's column or row: the largest chamber's cells
    /// (`EchoCartographerChamber.sizeRange`, 0 … 15).
    public static let coordinateRange: ClosedRange<Int> = 0...(EchoCartographerChamber.sizeRange.upperBound - 1)
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level.
    public private(set) var play: EchoCartographerPlay
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: EchoCartographerPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber`, whose reset returns to `openingPlay` of `openingNumber`.
    init(levelNumber: Int, play: EchoCartographerPlay, openingNumber: Int, openingPlay: EchoCartographerPlay) {
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
    public static func level(number: Int) throws(EchoCartographerError) -> EchoCartographerLevel {
        try generated(number: number).level
    }

    /// The certified levels generated so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 403).
    private static let generatedCache = Mutex<[Int: EchoCartographerGenerated]>([:])

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/echo-cartographer/levels/NNN.witness.json`).
    public static let certifiedCandidates: [Int] = [
        0, 1, 0, 1, 1, 4, 3, 1, 1, 0, 0, 0, 1, 0, 0, 2, 0, 0, 0, 0, 3, 0, 2, 0, 1,
        1, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 1, 0, 0, 3, 0, 0, 1, 7, 2,
        0, 0, 0, 0, 0, 1, 10, 2, 2, 0, 2, 5, 1, 0, 0, 5, 6, 6, 5, 23, 1, 7, 4, 7, 9,
        0, 2, 9, 1, 27, 33, 3, 15, 4, 12, 17, 2, 5, 5, 10, 0, 11, 0, 3, 11, 31, 7, 1, 4, 4,
    ]

    /// Candidate `index` of `entry` certified exactly as ``EchoCartographerGenerator/generate(_:)`` certifies a
    /// candidate (a solver plan within the work bound whose pulse count is in the band's range and at most energy − 1,
    /// and whose witness actions win through the kernel); nil otherwise.
    static func certify(_ entry: EchoCartographerManifestEntry, index: Int) -> EchoCartographerGenerated? {
        let profile: EchoCartographerBandProfile = .of(band: entry.band)
        guard let level = EchoCartographerGenerator.candidate(entry, index: index),
              let plan = EchoCartographerSolver.plan(level) else { return nil }
        let pulses: Int = plan.pulses.count
        guard profile.pulses.contains(pulses), pulses <= level.energy - 1 else { return nil }
        guard EchoCartographerSolver.wins(level, actions: EchoCartographerSolver.actions(level, plan: plan)) else {
            return nil
        }
        return EchoCartographerGenerated(entry: entry, level: level, plan: plan,
                                         difficulty: EchoCartographerDifficulty(level: level, plan: plan),
                                         skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole generator runs only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(EchoCartographerError) -> EchoCartographerGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: EchoCartographerManifestEntry = EchoCartographerManifest.entries[number - 1]
        let fresh: EchoCartographerGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try EchoCartographerGenerator.generate(entry)
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: EchoCartographerLevel) throws(EchoCartographerError) -> EchoCartographerPlay {
        try EchoCartographerPlay.replay(level: level, records: [])
    }

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(EchoCartographerError) -> EchoCartographerExperienceCore {
        let play: EchoCartographerPlay = try freshPlay(of: try level(number: number))
        return EchoCartographerExperienceCore(levelNumber: number, play: play, openingNumber: number,
                                              openingPlay: play)
    }

    // MARK: Scene snapshots

    /// An immutable copy of what the player knows of the play, with the level number, for drawing at the presenter's
    /// presentation time `time` (seconds since the last pulse; a non-finite or negative time becomes 0). Reads only;
    /// the state and its digest do not change.
    public func snapshot(time: Double) -> EchoCartographerSceneSnapshot {
        EchoCartographerSceneSnapshot(play: play, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `EchoCartographerTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: EchoCartographerTier { EchoCartographerTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest).
    public static var qualityTiers: Int { EchoCartographerTier.all.count }

    /// One level per host tier, best first: the element share is the ring and flare-trail layers drawn over the best
    /// tier's 2, the iteration share the glow shells over the best tier's 2 and the effect passes the glow shells;
    /// every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: EchoCartographerTier = EchoCartographerTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<EchoCartographerTier.all.count {
            let tier: EchoCartographerTier = EchoCartographerTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(layers(tier)) / Double(layers(best)),
                                       iterationShare: Double(tier.glowShells) / Double(best.glowShells),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// The animated layers `tier` draws: the rings (pulse and echo) and the flare trails, each 0 or 1.
    static func layers(_ tier: EchoCartographerTier) -> Int {
        (tier.rings ? 1 : 0) + (tier.flareTrails ? 1 : 0)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number and the play (not the quality tier or the opening level).
    public static func == (lhs: EchoCartographerExperienceCore, rhs: EchoCartographerExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "cell.pulse", ranges: [declared(coordinateRange), declared(coordinateRange)]),
        ExperienceControl(id: "cell.claim", ranges: [declared(coordinateRange), declared(coordinateRange)]),
        ExperienceControl(id: "cell.mark", ranges: [declared(coordinateRange), declared(coordinateRange)]),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The six controls with their declared ranges (see the file header); the last three take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing`; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> EchoCartographerExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(EchoCartographerError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Echo Cartographer level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the chamber changes only on an action, and the rings and flares move with the
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
                return .rejected(.rule(code: EchoCartographerExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(EchoCartographerError) {
            switch action.control {
            case "cell.pulse":
                try play.apply(.pulse(values[0], values[1]), expecting: play.fingerprint)
            case "cell.claim":
                try play.apply(.claim(values[0], values[1]), expecting: play.fingerprint)
            case "cell.mark":
                try play.apply(.mark(values[0], values[1]), expecting: play.fingerprint)
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: EchoCartographerPlay = try Self.freshPlay(of: try Self.level(number: next))
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

    /// "r02-g11.echo-cartographer.v1", then the level number and the play's fingerprint (level, knowledge, markers,
    /// located beacons, energy, stage, failure).
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
        var records: [EchoCartographerRecord]
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
    /// - Throws: ``EchoCartographerRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level
    ///   or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> EchoCartographerExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw EchoCartographerRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw EchoCartographerRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(EchoCartographerError) {
            let saved: EchoCartographerLevel = try level(number: decoded.level)
            let play: EchoCartographerPlay = try EchoCartographerPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: EchoCartographerPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return EchoCartographerExperienceCore(levelNumber: decoded.level, play: play,
                                                  openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw EchoCartographerRestoreRefusal.kernel(error)
        }
    }
}
