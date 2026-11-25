// ApsidesWorkshopExperienceCore — feature 473 (R02-G18-03) T-R02G1803-005 (FR-R02G1803-005, 008, 009;
// SC-R02G1803-004; clarifications Q4, Q5; data-model.md; contracts/api.md). The adapter of the Apsides Workshop kernel
// to the shared experience contract. The core holds the level number, the kernel's `ApsidesWorkshopPlay` and the shown
// tick; it never draws and reads no clock. The presenter asks for an immutable `ApsidesWorkshopSceneSnapshot` at its
// own presentation time (`snapshot(time:)`), so the star can pulse while the state and its digest stay put (renderer
// purity). The snapshot carries the kernel's report positions of the current orbit, the starting orbit's positions,
// the orbiter at the shown tick, the shares, the apsis readings and one gauge per target, so the drawn orbit is the
// kernel's positions and no drawn value decides a target, a contact or the verdict. The shown tick is presentation
// state of the adapter (`clock.show [tick]`): at an opening, after `level.next`, a reset and a restore it is tick 0; a
// tuning, the play, undo and redo keep it (the period of a level never changes); never in the digest, the snapshot
// payload or `==`. Modelled on `CelestialEclipseLabExperienceCore` (feature 463).
//
// Preparation: the certified level number `seed % 100 + 1` of `ApsidesWorkshopManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole catalog (`ApsidesWorkshopGenerator.catalog()`, once per process) only if that candidate no
// longer certifies; begun (and its tutorial dismissed, as `ApsidesWorkshopSolver.replayWins` does) so the play is in
// stage `playing`. The tutorial of levels 1 … 3 is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   orbit.periapsis [0…15, 0…23]  the eccentricity step k and the periapsis direction step d, whole numbers
//                                 (`r02-g18.not-whole` otherwise); one tuning (1 action); a tuning equal to the
//                                 current orbit or making the orbit invalid is the kernel's `r02-g18.action`; no
//                                 action left is `r02-g18.budget`;
//   orbit.size [8…48]             the size a in lattice units, whole (`r02-g18.not-whole` otherwise); refusals as
//                                 above;
//   orbit.play                    the play that ends the level (no action spent): `won` when the report wins, else
//                                 `failed` with its failure;
//   play.undo, play.redo          the kernel's exact undo and redo (`r02-g18.action` when there is nothing to undo or
//                                 redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                    the next certified level (100 wraps to 1) with a fresh play;
//   clock.show [0…95]             shows the orbiter at a tick (presentation only; accepted in every stage); a tick
//                                 outside 0 … period − 1 of the level is refused `r02-g18.tick` without touching the
//                                 kernel.
// The declared ranges are the kernel's step ranges (`ApsidesWorkshopOrbit.eccentricities`, `.directions`, `.sizes`) and
// the longest period any level allows (`ApsidesWorkshopLevel.periods`: ticks 0 … 95); the kernel or the adapter refuses
// the values a level lacks. Outside stage `playing` the kernel refuses a tuning and the play with `r02-g18.stage`.
// Every action is applied with the play's fingerprint as the expected one, so `r02-g18.stale` cannot arise. A kernel
// refusal (`ApsidesWorkshopError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown
// tick included.
//
// Digest ("r02-g18.apsides-workshop.v1"): the level number and the play's fingerprint (not its record history, so
// undo restores the earlier digest exactly); never the shown tick, the quality tier or a time. Snapshot schema 1: the
// JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`ApsidesWorkshopPlay.replay`), resets the shown tick and throws `ApsidesWorkshopRestoreRefusal` for a damaged
// payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another
// level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `ApsidesWorkshopTier.of(t)`: level-0 = spheres of 24 × 16 segments, 4 refinement
// points per tick, 2 glow shells; level-1 = 16 × 12 segments, 2 points, 1 glow shell; level-2 = flat 20-sided discs,
// chords only, no glow. Outcome: `won` or `failed` while the play is in that stage, else nil. Rules use integers only.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Apsides Workshop's adapter refusals (feature 473).
public enum ApsidesWorkshopExperienceRule {
    /// A value that must be a whole number (a step, a size or a tick) and is not.
    public static let notWhole = "r02-g18.not-whole"
    /// A shown tick outside 0 … period − 1 of the level (`clock.show`).
    public static let tick = "r02-g18.tick"
}

/// Why a saved Apsides Workshop state was refused on restore (feature 473). A refused restore changes nothing.
public enum ApsidesWorkshopRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(ApsidesWorkshopError)
}

/// The state of Apsides Workshop as an experience (see the file header). Snapshot schema 1.
public struct ApsidesWorkshopExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g18.apsides-workshop"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g18.apsides-workshop.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["orbit.periapsis", "orbit.size", "orbit.play", "play.undo", "play.redo",
                                   "level.next", "clock.show"]
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a shown tick: the longest period any level allows (`ApsidesWorkshopLevel.periods`,
    /// 0 … 95).
    public static let tickRange: ClosedRange<Int> = 0...(ApsidesWorkshopLevel.periods.upperBound - 1)
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level.
    public private(set) var play: ApsidesWorkshopPlay
    /// The shown tick, 0 … period − 1; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownTick: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: ApsidesWorkshopPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with tick 0 shown, whose reset returns to `openingPlay` of
    /// `openingNumber`.
    init(levelNumber: Int, play: ApsidesWorkshopPlay, openingNumber: Int, openingPlay: ApsidesWorkshopPlay) {
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
    public static func level(number: Int) throws(ApsidesWorkshopError) -> ApsidesWorkshopLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 473).
    private static let generatedCache = Mutex<[Int: ApsidesWorkshopGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[ApsidesWorkshopGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/apsides-workshop/levels/NNN.witness.json`, read
    /// 2026-11-25).
    public static let certifiedCandidates: [Int] = [
        1, 2, 8, 2, 0, 3, 0, 0, 0, 0, 0, 0, 4, 1, 3, 1, 1, 1, 0, 3, 1, 1, 0, 0, 1,
        0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]

    /// Candidate `index` of `entry` certified as ``ApsidesWorkshopGenerator/generate(_:previous:)`` certifies a
    /// candidate (a valid candidate whose minimal plan lies in its band's range and within the budget, within the
    /// solver's work bound), and whose plan followed by the play wins through the kernel; nil otherwise. The neighbour
    /// rule is not checked here: the table names the candidate the generator kept under it.
    static func certify(_ entry: ApsidesWorkshopManifestEntry, index: Int) -> ApsidesWorkshopGenerated? {
        let range: ClosedRange<Int> = ApsidesWorkshopBandProfile.of(band: entry.band).planRange
        guard let level = ApsidesWorkshopGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = ApsidesWorkshopSolver.plan(level) else { return nil }
        guard range.contains(plan.size), plan.size <= entry.budget else { return nil }
        guard ApsidesWorkshopSolver.replayWins(level, actions: plan.actions) else { return nil }
        return ApsidesWorkshopGenerated(entry: entry, level: level, plan: plan,
                                        difficulty: ApsidesWorkshopDifficulty(level: level, plan: plan),
                                        skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(ApsidesWorkshopError) -> ApsidesWorkshopGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: ApsidesWorkshopManifestEntry = ApsidesWorkshopManifest.entries[number - 1]
        let fresh: ApsidesWorkshopGenerated
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
    static func catalog() throws(ApsidesWorkshopError) -> [ApsidesWorkshopGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [ApsidesWorkshopGenerated] = try ApsidesWorkshopGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: ApsidesWorkshopLevel) throws(ApsidesWorkshopError) -> ApsidesWorkshopPlay {
        var play = ApsidesWorkshopPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions,
    /// with tick 0 shown.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(ApsidesWorkshopError) -> ApsidesWorkshopExperienceCore {
        let play: ApsidesWorkshopPlay = try freshPlay(of: try level(number: number))
        return ApsidesWorkshopExperienceCore(levelNumber: number, play: play, openingNumber: number,
                                             openingPlay: play)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (orbit steps, the kernel's positions, the ghost loop, the orbiter at the shown
    /// tick, shares, apsis readings, planets, gauges, failure, shown tick, period, stage, actions left and budget) with
    /// the level number, for drawing at the presenter's presentation time `time` (a non-finite or negative time becomes
    /// 0). Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> ApsidesWorkshopSceneSnapshot {
        ApsidesWorkshopSceneSnapshot(play: play, shownTick: shownTick, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `ApsidesWorkshopTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: ApsidesWorkshopTier { ApsidesWorkshopTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `ApsidesWorkshopTier.all`.
    public static var qualityTiers: Int { ApsidesWorkshopTier.all.count }

    /// The faces of one sphere at `tier`: longitudes × latitudes for a sphere, the disc's sides for a flat disc.
    static func sphereFaces(_ tier: ApsidesWorkshopTier) -> Int {
        tier.flatSpheres ? ApsidesWorkshopTier.discSides : tier.longitudes * tier.latitudes
    }

    /// One level per host tier, best first, named as `ApsidesWorkshopTier.all`: the element share is a sphere's faces
    /// over the best tier's (1, 0.5, 20 / 384), the iteration share the orbit loop's refinement points over the best
    /// tier's (1, 0.5, 0), the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: ApsidesWorkshopTier = ApsidesWorkshopTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<ApsidesWorkshopTier.all.count {
            let tier: ApsidesWorkshopTier = ApsidesWorkshopTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(sphereFaces(tier)) / Double(sphereFaces(best)),
                                       iterationShare: Double(tier.refinement) / Double(best.refinement),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number and the play (not the shown tick, the quality tier or the opening level).
    public static func == (lhs: ApsidesWorkshopExperienceCore, rhs: ApsidesWorkshopExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "orbit.periapsis",
                          ranges: [declared(ApsidesWorkshopOrbit.eccentricities),
                                   declared(ApsidesWorkshopOrbit.directions)]),
        ExperienceControl(id: "orbit.size", ranges: [declared(ApsidesWorkshopOrbit.sizes)]),
        ExperienceControl(id: "orbit.play"),
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
    public static func prepare(seed: UInt64) async throws -> ApsidesWorkshopExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(ApsidesWorkshopError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Apsides Workshop level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the orbit changes only on an action, and the star pulses with the presenter's
    /// time, not the state.
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
                return .rejected(.rule(code: ApsidesWorkshopExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(ApsidesWorkshopError) {
            switch action.control {
            case "orbit.periapsis":
                // The shown tick stays (presentation of the same level; the period does not change).
                try play.apply(.periapsis(values[0], values[1]), expecting: play.fingerprint)
            case "orbit.size":
                try play.apply(.size(values[0]), expecting: play.fingerprint)
            case "orbit.play":
                try play.apply(.play, expecting: play.fingerprint)
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            case "clock.show":
                // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                guard values[0] < play.level.period else {
                    return .rejected(.rule(code: ApsidesWorkshopExperienceRule.tick))
                }
                shownTick = values[0]
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: ApsidesWorkshopPlay = try Self.freshPlay(of: try Self.level(number: next))
                levelNumber = next
                play = fresh
                shownTick = 0
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

    /// "r02-g18.apsides-workshop.v1", then the level number and the play's fingerprint (actions spent, failure,
    /// level, orbit, stage).
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
        var records: [ApsidesWorkshopRecord]
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
    /// - Throws: ``ApsidesWorkshopRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level or
    ///   trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> ApsidesWorkshopExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw ApsidesWorkshopRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw ApsidesWorkshopRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(ApsidesWorkshopError) {
            let saved: ApsidesWorkshopLevel = try level(number: decoded.level)
            let play: ApsidesWorkshopPlay = try ApsidesWorkshopPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: ApsidesWorkshopPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return ApsidesWorkshopExperienceCore(levelNumber: decoded.level, play: play,
                                                 openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw ApsidesWorkshopRestoreRefusal.kernel(error)
        }
    }
}
