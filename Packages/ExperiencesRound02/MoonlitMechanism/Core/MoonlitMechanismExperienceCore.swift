// MoonlitMechanismExperienceCore — feature 433 (R02-G14-03) T-R02G1403-005 (FR-R02G1403-005, 008, 009; SC-R02G1403-004;
// clarification Q5; data-model.md; contracts/api.md). The adapter of the Moonlit Mechanism kernel to the shared
// experience contract. The core holds the level number, the kernel's `MoonlitMechanismPlay` and the shown key frame; it
// never draws and reads no clock. The presenter asks for an immutable `MoonlitMechanismSceneSnapshot` at its own
// presentation time (`snapshot(time:)`), so the gears can turn in preview while the state and its digest stay put
// (renderer purity). The snapshot carries the kernel's exact run report, so the drawn shadows are the kernel's cast
// cells and no drawn value decides an alignment, a covered cell or the verdict. The shown key frame is presentation
// state of the adapter (`frame.show [k]`): key frame 0 when a level opens, never in the digest, the snapshot payload or
// `==`. The panel's chosen gear is presentation state of the controls, not of this core (Q5): a level opens with gear 1
// chosen (``openingGear``).
//
// Preparation: the certified level number `seed % 100 + 1` of `MoonlitMechanismManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole generator only if that candidate no longer certifies; begun (and its tutorial dismissed, as
// `MoonlitMechanismPlay.replay` does) so the play is in stage `playing`. The tutorial of levels 1 … 3 is shown by the
// presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   handle.turn [−1…1]          a step, a whole number (`r02-g14.not-whole` otherwise); turns the handle: every gear
//                               moves one tooth in its direction (1 action); a step of 0 is the kernel's
//                               `r02-g14.action` (`step`);
//   gear.reseat [0…4, −1…1]     a gear and a step; re-seats that gear by one tooth (1 action); the driver (gear 0) and
//                               a gear the level lacks are the kernel's `r02-g14.action` (`driver`, `gear`);
//   lamp.step [−1…1]            a step; moves the lamp one height (1 action); leaving the lamp's heights is the
//                               kernel's `r02-g14.action` (`lamp`);
//   machine.run                 runs the machine through its key frames and decides the level (1 action): won, or
//                               failed `jammed`, `forbidden`, `missing` or `stray`;
//   play.undo, play.redo        the kernel's exact undo and redo (`r02-g14.action` when there is nothing to undo or
//                               redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                  the next certified level (100 wraps to 1) with a fresh play and key frame 0 shown;
//   frame.show [0…5]            shows key frame k (presentation only; accepted in every stage); a key frame the level
//                               lacks is refused `r02-g14.frame`.
// The declared gear and key-frame ranges are the widest any level allows (`MoonlitMechanismLevel.gearCounts`: at most 5
// gears; `frameCounts`: at most 6 key frames). Outside stage `playing` the kernel refuses with `r02-g14.stage`; the
// last of the budget spent by a turn, re-seat or lamp step without a win fails the level `budget`. Every action is
// applied with the play's current fingerprint as the expected one, so `r02-g14.stale` cannot arise. A kernel refusal
// (`MoonlitMechanismError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing.
//
// Digest ("r02-g14.moonlit-mechanism.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the shown key frame, the quality tier or a time. Snapshot schema 1: the
// JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`MoonlitMechanismPlay.replay`), shows key frame 0, and throws `MoonlitMechanismRestoreRefusal` for a damaged
// payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another
// level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `MoonlitMechanismTier.of(t)`: level-0 = 6 rim segments per tooth, soft shadow edges,
// 2 glow shells; level-1 = 4, soft edges, 1 glow shell; level-2 = 2, hard edges, no glow. Outcome: `won` or `failed`
// while the play is in that stage, else nil. Rules use integers only.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Moonlit Mechanism's adapter refusals (feature 433).
public enum MoonlitMechanismExperienceRule {
    /// A value that must be a whole number (a step, a gear or a key frame) and is not.
    public static let notWhole = "r02-g14.not-whole"
    /// A key frame the level does not have (`frame.show`).
    public static let frame = "r02-g14.frame"
}

/// Why a saved Moonlit Mechanism state was refused on restore (feature 433). A refused restore changes nothing.
public enum MoonlitMechanismRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(MoonlitMechanismError)
}

/// The state of Moonlit Mechanism as an experience (see the file header). Snapshot schema 1.
public struct MoonlitMechanismExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g14.moonlit-mechanism"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g14.moonlit-mechanism.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["handle.turn", "gear.reseat", "lamp.step", "machine.run", "play.undo", "play.redo",
                                   "level.next", "frame.show"]
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a step (−1 … 1; the kernel refuses 0).
    public static let stepRange: ClosedRange<Int> = -1...1
    /// The declared range of a gear index: the most gears any level has (`MoonlitMechanismLevel.gearCounts`, 0 … 4).
    public static let gearRange: ClosedRange<Int> = 0...(MoonlitMechanismLevel.gearCounts.upperBound - 1)
    /// The declared range of a key frame: the most key frames any level has (`MoonlitMechanismLevel.frameCounts`,
    /// 0 … 5).
    public static let frameRange: ClosedRange<Int> = 0...(MoonlitMechanismLevel.frameCounts.upperBound - 1)
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"
    /// The gear the panel chooses when a level opens (presentation state of the controls, Q5).
    public static let openingGear = 1
    /// The key frame shown when a level opens.
    public static let openingFrame = 0

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level.
    public private(set) var play: MoonlitMechanismPlay
    /// The shown key frame, 0 … key frames − 1; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownFrame: Int = openingFrame
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: MoonlitMechanismPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with key frame 0 shown, whose reset returns to `openingPlay` of
    /// `openingNumber`.
    init(levelNumber: Int, play: MoonlitMechanismPlay, openingNumber: Int, openingPlay: MoonlitMechanismPlay) {
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
    public static func level(number: Int) throws(MoonlitMechanismError) -> MoonlitMechanismLevel {
        try generated(number: number).level
    }

    /// The certified levels generated so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 433).
    private static let generatedCache = Mutex<[Int: MoonlitMechanismGenerated]>([:])

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/moonlit-mechanism/levels/NNN.witness.json`).
    public static let certifiedCandidates: [Int] = [
        3, 1, 3, 0, 0, 0, 1, 0, 1, 2, 2, 0, 1, 0, 1, 2, 0, 2, 4, 0, 0, 1, 0, 1, 0,
        0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 2,
        2, 0, 1, 0, 0, 0, 1, 0, 3, 1, 2, 4, 0, 1, 1, 1, 0, 0, 0, 0, 2, 2, 0, 1, 2,
        1, 1, 2, 0, 0, 1, 2, 3, 8, 1, 1, 2, 1, 0, 3, 0, 1, 1, 5, 0, 0, 0, 1, 1, 0,
    ]

    /// Candidate `index` of `entry` certified exactly as ``MoonlitMechanismGenerator/generate(_:)`` certifies a
    /// candidate (a start that does not already win, a solver plan within the work bound and the band's plan range,
    /// at most budget − 1, whose witness actions win through the kernel); nil otherwise.
    static func certify(_ entry: MoonlitMechanismManifestEntry, index: Int) -> MoonlitMechanismGenerated? {
        let range: ClosedRange<Int> = MoonlitMechanismBandProfile.of(band: entry.band).planRange
        guard let level = MoonlitMechanismGenerator.candidate(entry, index: index) else { return nil }
        guard level.run(phases: level.startingPhases, height: level.startingHeight).outcome != .won else { return nil }
        guard let plan = MoonlitMechanismSolver.plan(level, maxActions: range.upperBound) else { return nil }
        guard range.contains(plan.size), plan.size <= entry.budget - 1 else { return nil }
        guard MoonlitMechanismSolver.wins(level, actions: MoonlitMechanismSolver.actions(plan)) else { return nil }
        return MoonlitMechanismGenerated(entry: entry, level: level, plan: plan,
                                         difficulty: MoonlitMechanismDifficulty(level: level, plan: plan),
                                         skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole generator runs only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(MoonlitMechanismError) -> MoonlitMechanismGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: MoonlitMechanismManifestEntry = MoonlitMechanismManifest.entries[number - 1]
        let fresh: MoonlitMechanismGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try MoonlitMechanismGenerator.generate(entry)
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: MoonlitMechanismLevel) throws(MoonlitMechanismError)
        -> MoonlitMechanismPlay {
        try MoonlitMechanismPlay.replay(level: level, records: [])
    }

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions,
    /// with key frame 0 shown.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(MoonlitMechanismError) -> MoonlitMechanismExperienceCore {
        let play: MoonlitMechanismPlay = try freshPlay(of: try level(number: number))
        return MoonlitMechanismExperienceCore(levelNumber: number, play: play, openingNumber: number,
                                              openingPlay: play)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play at the shown key frame (gears and their phases at that key frame, lamp, wall,
    /// cast, target and forbidden cells, the kernel's exact run report, stage, failure and actions) with the level
    /// number, for drawing at the presenter's presentation time `time` (a non-finite or negative time becomes 0). Reads
    /// only; the state and its digest do not change.
    public func snapshot(time: Double) -> MoonlitMechanismSceneSnapshot {
        MoonlitMechanismSceneSnapshot(play: play, shownFrame: shownFrame, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `MoonlitMechanismTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: MoonlitMechanismTier { MoonlitMechanismTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `MoonlitMechanismTier.all`.
    public static var qualityTiers: Int { MoonlitMechanismTier.all.count }

    /// One level per host tier, best first, named as `MoonlitMechanismTier.all`: the element share is the rim segments
    /// per tooth over the best tier's 6, the iteration share the glow shells over the best tier's 2, the effect passes
    /// the glow shells plus one for the soft shadow edges; every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: MoonlitMechanismTier = MoonlitMechanismTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<MoonlitMechanismTier.all.count {
            let tier: MoonlitMechanismTier = MoonlitMechanismTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.segmentsPerTooth) / Double(best.segmentsPerTooth),
                                       iterationShare: Double(tier.glowShells) / Double(best.glowShells),
                                       effectPasses: tier.glowShells + (tier.softEdge ? 1 : 0)))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number and the play (not the shown key frame, the quality tier or the opening level).
    public static func == (lhs: MoonlitMechanismExperienceCore, rhs: MoonlitMechanismExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "handle.turn", ranges: [declared(stepRange)]),
        ExperienceControl(id: "gear.reseat", ranges: [declared(gearRange), declared(stepRange)]),
        ExperienceControl(id: "lamp.step", ranges: [declared(stepRange)]),
        ExperienceControl(id: "machine.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "frame.show", ranges: [declared(frameRange)]),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The eight controls with their declared ranges (see the file header); run, undo, redo and next take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with key frame 0 shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> MoonlitMechanismExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(MoonlitMechanismError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Moonlit Mechanism level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the mechanism changes only on an action, and the turning preview moves with the
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
                return .rejected(.rule(code: MoonlitMechanismExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(MoonlitMechanismError) {
            switch action.control {
            case "handle.turn":
                try play.apply(.turn(values[0]), expecting: play.fingerprint)
            case "gear.reseat":
                try play.apply(.reseat(values[0], values[1]), expecting: play.fingerprint)
            case "lamp.step":
                try play.apply(.lamp(values[0]), expecting: play.fingerprint)
            case "machine.run":
                try play.apply(.run, expecting: play.fingerprint)
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            case "frame.show":
                // Presentation only: the play and the digest do not change.
                guard values[0] < play.level.keyFrames.count else {
                    return .rejected(.rule(code: MoonlitMechanismExperienceRule.frame))
                }
                shownFrame = values[0]
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: MoonlitMechanismPlay = try Self.freshPlay(of: try Self.level(number: next))
                levelNumber = next
                play = fresh
                shownFrame = Self.openingFrame
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

    /// Back to the fresh play of the level the seed chose with key frame 0 shown; the quality tier, which is not
    /// state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = openingPlay
        shownFrame = Self.openingFrame
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g14.moonlit-mechanism.v1", then the level number and the play's fingerprint (level, phases, lamp height,
    /// actions spent, stage, failure).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // shown key frame (presentation).
        builder.add(play.fingerprint)
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The play's records.
        var records: [MoonlitMechanismRecord]
    }

    /// The JSON object `{"level", "records"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(level: levelNumber, records: play.records))
    }

    /// The core of `payload`: the records replayed on a fresh play of the saved level, key frame 0 shown; a reset
    /// returns to the level `seed` chooses.
    ///
    /// - Throws: ``MoonlitMechanismRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level
    ///   or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> MoonlitMechanismExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw MoonlitMechanismRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw MoonlitMechanismRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(MoonlitMechanismError) {
            let saved: MoonlitMechanismLevel = try level(number: decoded.level)
            let play: MoonlitMechanismPlay = try MoonlitMechanismPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: MoonlitMechanismPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return MoonlitMechanismExperienceCore(levelNumber: decoded.level, play: play,
                                                  openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw MoonlitMechanismRestoreRefusal.kernel(error)
        }
    }
}
