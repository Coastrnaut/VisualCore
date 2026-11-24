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
//   level.next                the next certified level (100 wraps to 1) with a fresh play and its first turnable hinge
//                             chosen;
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
}

/// Why a saved Voxel Origami state was refused on restore (feature 443). A refused restore changes nothing.
public enum VoxelOrigamiRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(VoxelOrigamiError)
}

/// The state of Voxel Origami as an experience (see the file header). Snapshot schema 1.
public struct VoxelOrigamiExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g15.voxel-origami"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g15.voxel-origami.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["hinge.turn", "play.undo", "play.redo", "level.next", "hinge.choose"]
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
    /// The kernel's play of that level.
    public private(set) var play: VoxelOrigamiPlay
    /// The chosen hinge, 1 … cubes − 1; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var chosenHinge: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: VoxelOrigamiPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with its first turnable hinge chosen, whose reset returns to
    /// `openingPlay` of `openingNumber`.
    init(levelNumber: Int, play: VoxelOrigamiPlay, openingNumber: Int, openingPlay: VoxelOrigamiPlay) {
        self.levelNumber = levelNumber
        self.play = play
        self.chosenHinge = Self.openingHinge(of: play)
        self.openingNumber = openingNumber
        self.openingPlay = openingPlay
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

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions,
    /// with its first turnable hinge chosen.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(VoxelOrigamiError) -> VoxelOrigamiExperienceCore {
        let play: VoxelOrigamiPlay = try freshPlay(of: try level(number: number))
        return VoxelOrigamiExperienceCore(levelNumber: number, play: play, openingNumber: number, openingPlay: play)
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

    /// Equal states: the level number and the play (not the chosen hinge, the quality tier or the opening level).
    public static func == (lhs: VoxelOrigamiExperienceCore, rhs: VoxelOrigamiExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "hinge.turn", ranges: [declared(hingeRange), declared(stepRange)]),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "hinge.choose", ranges: [declared(hingeRange)]),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The five controls with their declared ranges (see the file header); undo, redo and next take no values.
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
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            case "hinge.choose":
                // Presentation only: the play and the digest do not change.
                guard values[0] >= 1, values[0] < play.level.cubes.count else {
                    return .rejected(.rule(code: VoxelOrigamiExperienceRule.hinge))
                }
                chosenHinge = values[0]
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: VoxelOrigamiPlay = try Self.freshPlay(of: try Self.level(number: next))
                levelNumber = next
                play = fresh
                chosenHinge = Self.openingHinge(of: fresh)
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

    /// Back to the fresh play of the level the seed chose with its first turnable hinge chosen; the quality tier,
    /// which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = openingPlay
        chosenHinge = Self.openingHinge(of: openingPlay)
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g15.voxel-origami.v1", then the level number and the play's fingerprint (level, turns, actions spent,
    /// stage, failure).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // chosen hinge (presentation).
        builder.add(play.fingerprint)
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The play's records.
        var records: [VoxelOrigamiRecord]
    }

    /// The JSON object `{"level", "records"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(level: levelNumber, records: play.records))
    }

    /// The core of `payload`: the records replayed on a fresh play of the saved level, its first turnable hinge chosen;
    /// a reset returns to the level `seed` chooses.
    ///
    /// - Throws: ``VoxelOrigamiRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level or
    ///   trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> VoxelOrigamiExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw VoxelOrigamiRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw VoxelOrigamiRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(VoxelOrigamiError) {
            let saved: VoxelOrigamiLevel = try level(number: decoded.level)
            let play: VoxelOrigamiPlay = try VoxelOrigamiPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: VoxelOrigamiPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return VoxelOrigamiExperienceCore(levelNumber: decoded.level, play: play, openingNumber: openingNumber,
                                              openingPlay: openingPlay)
        } catch {
            throw VoxelOrigamiRestoreRefusal.kernel(error)
        }
    }
}
