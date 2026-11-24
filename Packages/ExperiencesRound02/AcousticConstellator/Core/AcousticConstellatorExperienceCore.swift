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
//   level.next                the next certified level (100 wraps to 1) with a fresh play.
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
}

/// Why a saved Acoustic Constellator state was refused on restore (feature 423). A refused restore changes nothing.
public enum AcousticConstellatorRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(AcousticConstellatorError)
}

/// The state of Acoustic Constellator as an experience (see the file header). Snapshot schema 1.
public struct AcousticConstellatorExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g13.acoustic-constellator"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g13.acoustic-constellator.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["link.add", "link.remove", "star.nudge", "constellation.listen", "play.undo",
                                   "play.redo", "level.next"]
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
    /// The kernel's play of that level.
    public private(set) var play: AcousticConstellatorPlay
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: AcousticConstellatorPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber`, whose reset returns to `openingPlay` of `openingNumber`.
    init(levelNumber: Int, play: AcousticConstellatorPlay, openingNumber: Int, openingPlay: AcousticConstellatorPlay) {
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

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(AcousticConstellatorError) -> AcousticConstellatorExperienceCore {
        let play: AcousticConstellatorPlay = try freshPlay(of: try level(number: number))
        return AcousticConstellatorExperienceCore(levelNumber: number, play: play, openingNumber: number,
                                                  openingPlay: play)
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

    /// Equal states: the level number and the play (not the quality tier or the opening level).
    public static func == (lhs: AcousticConstellatorExperienceCore, rhs: AcousticConstellatorExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "link.add", ranges: [declared(starRange), declared(starRange)]),
        ExperienceControl(id: "link.remove", ranges: [declared(starRange), declared(starRange)]),
        ExperienceControl(id: "star.nudge", ranges: [declared(starRange), declared(stepRange)]),
        ExperienceControl(id: "constellation.listen"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The seven controls with their declared ranges (see the file header); the last four take no values.
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
        do throws(AcousticConstellatorError) {
            switch action.control {
            case "link.add":
                try play.apply(.link(values[0], values[1]), expecting: play.fingerprint)
            case "link.remove":
                try play.apply(.unlink(values[0], values[1]), expecting: play.fingerprint)
            case "star.nudge":
                try play.apply(.nudge(values[0], values[1]), expecting: play.fingerprint)
            case "constellation.listen":
                try play.apply(.listen, expecting: play.fingerprint)
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: AcousticConstellatorPlay = try Self.freshPlay(of: try Self.level(number: next))
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

    /// "r02-g13.acoustic-constellator.v1", then the level number and the play's fingerprint (level, links, phases,
    /// actions spent, stage, failure).
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
        var records: [AcousticConstellatorRecord]
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
    /// - Throws: ``AcousticConstellatorRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a
    ///   level or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> AcousticConstellatorExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw AcousticConstellatorRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw AcousticConstellatorRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(AcousticConstellatorError) {
            let saved: AcousticConstellatorLevel = try level(number: decoded.level)
            let play: AcousticConstellatorPlay = try AcousticConstellatorPlay.replay(level: saved,
                                                                                    records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: AcousticConstellatorPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return AcousticConstellatorExperienceCore(levelNumber: decoded.level, play: play,
                                                      openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw AcousticConstellatorRestoreRefusal.kernel(error)
        }
    }
}
