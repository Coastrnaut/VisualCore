// MicroscopicAuroraExperienceCore — feature 483 (R02-G19-03) T-R02G1903-005 (FR-R02G1903-005, 008, 009;
// SC-R02G1903-004; clarifications Q4, Q5; data-model.md; contracts/api.md). The adapter of the Microscopic Aurora
// kernel to the shared experience contract. The core holds the level number, the kernel's `MicroscopicAuroraPlay` and
// the shown tick; it never draws and reads no clock. The presenter asks for an immutable
// `MicroscopicAuroraSceneSnapshot` at its own presentation time (`snapshot(time:)`), so the scene can shimmer while the
// state and its digest stay put (renderer purity). The snapshot carries the kernel's swimmer positions and velocities
// at every tick of the predicted swim of the current wells, the ticks swum, the trail density and lit cells, the
// stencil, the sites, the wells, the coverage and coherence with their requirements, the failure, the stage and the
// actions left, so every drawn swimmer stands at a kernel position and no drawn value decides a cell, a group or the
// verdict. The shown tick is presentation state of the adapter (`clock.show [tick]`): at an opening, after
// `level.next`, a reset and a restore it is tick 0; a placement, a removal, the play, undo and redo keep it, clamped to
// the new ticks swum (a swim that now fails earlier swims fewer ticks); never in the digest, the snapshot payload or
// `==`. Modelled on `ApsidesWorkshopExperienceCore` (feature 473).
//
// Preparation: the certified level number `seed % 100 + 1` of `MicroscopicAuroraManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole catalog (`MicroscopicAuroraGenerator.catalog()`, once per process) only if that candidate no
// longer certifies; begun (and its tutorial dismissed, as `MicroscopicAuroraSolver.replayWins` does) so the play is in
// stage `playing`. The tutorial of levels 1 … 3 is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   well.place [0…2, 0…23, 0…23, 1…4, 0…1]  slot, row, column, strength and sense (0 clockwise, 1 counterclockwise),
//                                 whole numbers (`r02-g19.not-whole` otherwise); one placement (1 action); a cell off
//                                 the enclosure or not a site, a cell another slot's well occupies or a placement equal
//                                 to the slot's well is the kernel's `r02-g19.action`; no action left is
//                                 `r02-g19.budget`;
//   well.remove [0…2]             empties the slot (1 action); an empty slot is `r02-g19.action`; budget as above;
//   swim.play                     the play that ends the level (no action spent): `won` when the report wins, else
//                                 `failed` with its failure;
//   play.undo, play.redo          the kernel's exact undo and redo (`r02-g19.action` when there is nothing to undo or
//                                 redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                    the next certified level (100 wraps to 1) with a fresh play;
//   clock.show [0…480]            shows the swimmers at a tick (presentation only; accepted in every stage); a tick
//                                 outside 0 … ticks swum of the current report is refused `r02-g19.tick` without
//                                 touching the kernel.
// The declared ranges are the kernel's (`MicroscopicAuroraLevel.slots`, `MicroscopicAuroraDish.cells`,
// `MicroscopicAuroraWell.strengths`, the two senses) and the longest swim any level allows
// (`MicroscopicAuroraLevel.lengths`: ticks 0 … 480); the kernel or the adapter refuses the values a level lacks.
// Outside stage `playing` the kernel refuses a placement, a removal and the play with `r02-g19.stage`. Every action is
// applied with the play's fingerprint as the expected one, so `r02-g19.stale` cannot arise. A kernel refusal
// (`MicroscopicAuroraError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown tick
// included.
//
// Digest ("r02-g19.microscopic-aurora.v1"): the level number and the play's fingerprint (not its record history, so
// undo restores the earlier digest exactly); never the shown tick, the quality tier or a time. Snapshot schema 1: the
// JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`MicroscopicAuroraPlay.replay`), resets the shown tick and throws `MicroscopicAuroraRestoreRefusal` for a damaged
// payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another
// level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `MicroscopicAuroraTier.of(t)`: level-0 = capsules of 12 segments, ribbons of 64 ticks,
// fronds, 2 glow shells; level-1 = 8 segments, 32 ticks, fronds, 1 glow shell; level-2 = flat capsules, 16 ticks, no
// fronds, no glow. Outcome: `won` or `failed` while the play is in that stage, else nil. Rules use integers only.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Microscopic Aurora's adapter refusals (feature 483).
public enum MicroscopicAuroraExperienceRule {
    /// A value that must be a whole number (a slot, a cell, a strength, a sense or a tick) and is not.
    public static let notWhole = "r02-g19.not-whole"
    /// A shown tick outside 0 … ticks swum of the current report (`clock.show`).
    public static let tick = "r02-g19.tick"
}

/// Why a saved Microscopic Aurora state was refused on restore (feature 483). A refused restore changes nothing.
public enum MicroscopicAuroraRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(MicroscopicAuroraError)
}

/// The state of Microscopic Aurora as an experience (see the file header). Snapshot schema 1.
public struct MicroscopicAuroraExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g19.microscopic-aurora"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g19.microscopic-aurora.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["well.place", "well.remove", "swim.play", "play.undo", "play.redo", "level.next",
                                   "clock.show"]
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a slot: 0 … `MicroscopicAuroraLevel.slots` − 1.
    public static let slotRange: ClosedRange<Int> = 0...(MicroscopicAuroraLevel.slots - 1)
    /// The declared range of a row or a column: 0 … `MicroscopicAuroraDish.cells` − 1.
    public static let cellRange: ClosedRange<Int> = 0...(MicroscopicAuroraDish.cells - 1)
    /// The declared range of a sense: 0 (clockwise) … 1 (counterclockwise).
    public static let senseRange: ClosedRange<Int> = 0...1
    /// The declared range of a shown tick: the longest swim any level allows (`MicroscopicAuroraLevel.lengths`,
    /// 0 … 480).
    public static let tickRange: ClosedRange<Int> = 0...MicroscopicAuroraLevel.lengths.upperBound
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level.
    public private(set) var play: MicroscopicAuroraPlay
    /// The shown tick, 0 … ticks swum; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownTick: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: MicroscopicAuroraPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with tick 0 shown, whose reset returns to `openingPlay` of
    /// `openingNumber`.
    init(levelNumber: Int, play: MicroscopicAuroraPlay, openingNumber: Int, openingPlay: MicroscopicAuroraPlay) {
        self.levelNumber = levelNumber
        self.play = play
        self.shownTick = 0
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
    public static func level(number: Int) throws(MicroscopicAuroraError) -> MicroscopicAuroraLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 483).
    private static let generatedCache = Mutex<[Int: MicroscopicAuroraGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[MicroscopicAuroraGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/microscopic-aurora/levels/NNN.witness.json`, read
    /// 2026-11-26).
    public static let certifiedCandidates: [Int] = [
        0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 2, 1, 0, 3, 1, 1,
        0, 2, 0, 0, 0, 2, 0, 1, 0, 0, 0, 0, 0, 2, 2, 1, 3, 2, 0, 2, 0, 0, 2, 0, 7,
        2, 2, 8, 3, 1, 2, 5, 3, 0, 2, 4, 0, 3, 2, 9, 6, 2, 3, 1, 9, 3, 0, 4, 2, 11,
        1, 1, 0, 1, 1, 1, 6, 5, 7, 0, 6, 0, 4, 0, 0, 2, 3, 1, 3, 6, 1, 0, 3, 5, 5,
    ]

    /// Candidate `index` of `entry` certified as ``MicroscopicAuroraGenerator/generate(_:previous:)`` certifies a
    /// candidate (a candidate the kernel accepts whose minimal plan, found within the solver's work bound, has the
    /// band's plan length), and whose plan followed by the play wins through the kernel; nil otherwise. The neighbour
    /// rule is not checked here: the table names the candidate the generator kept under it.
    static func certify(_ entry: MicroscopicAuroraManifestEntry, index: Int) -> MicroscopicAuroraGenerated? {
        let length: Int = MicroscopicAuroraBandProfile.of(band: entry.band).plan
        guard let level = MicroscopicAuroraGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = MicroscopicAuroraSolver.plan(level), plan.size == length else { return nil }
        guard MicroscopicAuroraSolver.replayWins(level, actions: plan.actions) else { return nil }
        return MicroscopicAuroraGenerated(entry: entry, level: level, plan: plan,
                                          difficulty: MicroscopicAuroraDifficulty(level: level, plan: plan),
                                          skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(MicroscopicAuroraError) -> MicroscopicAuroraGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifest.entries[number - 1]
        let fresh: MicroscopicAuroraGenerated
        if let direct = certify(entry, index: certifiedCandidates[number - 1]) {
            fresh = direct
        } else {
            fresh = try catalog()[number - 1]
        }
        generatedCache.withLock { $0[number] = fresh }
        return fresh
    }

    /// The whole certified catalog (the fallback of ``generated(number:)``), generated once per process.
    ///
    /// - Throws: the generator's `.generation(number)`.
    static func catalog() throws(MicroscopicAuroraError) -> [MicroscopicAuroraGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [MicroscopicAuroraGenerated] = try MicroscopicAuroraGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: MicroscopicAuroraLevel) throws(MicroscopicAuroraError)
        -> MicroscopicAuroraPlay {
        var play = MicroscopicAuroraPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions,
    /// with tick 0 shown.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(MicroscopicAuroraError) -> MicroscopicAuroraExperienceCore {
        let play: MicroscopicAuroraPlay = try freshPlay(of: try level(number: number))
        return MicroscopicAuroraExperienceCore(levelNumber: number, play: play, openingNumber: number,
                                               openingPlay: play)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (the swimmers' positions and velocities at every tick of the predicted swim, the
    /// ticks swum, the shown tick, density, lit and stray cells, stencil, sites, wells, coverage and coherence with
    /// their requirements, failure, stage, actions left and budget) with the level number, for drawing at the
    /// presenter's presentation time `time` (a non-finite or negative time becomes 0). Reads only; the state and its
    /// digest do not change.
    public func snapshot(time: Double) -> MicroscopicAuroraSceneSnapshot {
        MicroscopicAuroraSceneSnapshot(play: play, shownTick: shownTick, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `MicroscopicAuroraTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: MicroscopicAuroraTier { MicroscopicAuroraTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `MicroscopicAuroraTier.all`.
    public static var qualityTiers: Int { MicroscopicAuroraTier.all.count }

    /// One level per host tier, best first, named as `MicroscopicAuroraTier.all`: the element share is a ribbon's ticks
    /// over the best tier's (1, 0.5, 0.25), the iteration share a capsule's segments over the best tier's (1, 8 / 12,
    /// 0), the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: MicroscopicAuroraTier = MicroscopicAuroraTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<MicroscopicAuroraTier.all.count {
            let tier: MicroscopicAuroraTier = MicroscopicAuroraTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.ribbonTicks) / Double(best.ribbonTicks),
                                       iterationShare: Double(tier.capsuleSegments) / Double(best.capsuleSegments),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number and the play (not the shown tick, the quality tier or the opening level).
    public static func == (lhs: MicroscopicAuroraExperienceCore, rhs: MicroscopicAuroraExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "well.place",
                          ranges: [declared(slotRange), declared(cellRange), declared(cellRange),
                                   declared(MicroscopicAuroraWell.strengths), declared(senseRange)]),
        ExperienceControl(id: "well.remove", ranges: [declared(slotRange)]),
        ExperienceControl(id: "swim.play"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "clock.show", ranges: [declared(tickRange)]),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The seven controls with their declared ranges (see the file header); play, undo, redo and next take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with tick 0 shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> MicroscopicAuroraExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(MicroscopicAuroraError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Microscopic Aurora level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the swim changes only on an action, and the scene shimmers with the presenter's
    /// time, not the state.
    public mutating func update(step: Int) {}

    /// The kernel well of a `well.place` action's values `[slot, row, column, strength, sense]` (whole numbers in the
    /// declared ranges).
    static func well(_ values: [Int]) -> MicroscopicAuroraWell {
        let sense: MicroscopicAuroraSense = values[4] == 0 ? .clockwise : .counterclockwise
        return MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: values[1], column: values[2]),
                                     strength: values[3], sense: sense)
    }

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        var values: [Int] = []
        for value in action.values {
            guard let whole = Self.whole(value) else {
                return .rejected(.rule(code: MicroscopicAuroraExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(MicroscopicAuroraError) {
            switch action.control {
            case "well.place":
                try play.apply(.place(slot: values[0], well: Self.well(values)), expecting: play.fingerprint)
            case "well.remove":
                try play.apply(.remove(slot: values[0]), expecting: play.fingerprint)
            case "swim.play":
                try play.apply(.play, expecting: play.fingerprint)
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            case "clock.show":
                // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                guard values[0] <= play.report.ticks else {
                    return .rejected(.rule(code: MicroscopicAuroraExperienceRule.tick))
                }
                shownTick = values[0]
                return .accepted
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: MicroscopicAuroraPlay = try Self.freshPlay(of: try Self.level(number: next))
                levelNumber = next
                play = fresh
                shownTick = 0
                return .accepted
            }
        } catch {
            return .rejected(.rule(code: error.reasonCode))
        }
        // The shown tick stays, clamped to the ticks the current report swims.
        shownTick = min(shownTick, play.report.ticks)
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Back to the fresh play of the level the seed chose with tick 0 shown; the quality tier, which is not state, is
    /// kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = openingPlay
        shownTick = 0
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g19.microscopic-aurora.v1", then the level number and the play's fingerprint (actions spent, failure,
    /// level, stage, wells).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // shown tick (presentation).
        builder.add(play.fingerprint)
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The play's records.
        var records: [MicroscopicAuroraRecord]
    }

    /// The JSON object `{"level", "records"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(level: levelNumber, records: play.records))
    }

    /// The core of `payload`: the records replayed on a fresh play of the saved level, with tick 0 shown; a reset
    /// returns to the level `seed` chooses.
    ///
    /// - Throws: ``MicroscopicAuroraRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level
    ///   or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> MicroscopicAuroraExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw MicroscopicAuroraRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw MicroscopicAuroraRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(MicroscopicAuroraError) {
            let saved: MicroscopicAuroraLevel = try level(number: decoded.level)
            let play: MicroscopicAuroraPlay = try MicroscopicAuroraPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: MicroscopicAuroraPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return MicroscopicAuroraExperienceCore(levelNumber: decoded.level, play: play,
                                                   openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw MicroscopicAuroraRestoreRefusal.kernel(error)
        }
    }
}
