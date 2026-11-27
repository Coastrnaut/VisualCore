// BinaryGardensExperienceCore — feature 503 (R02-G21-03) T-R02G2103-005 (FR-R02G2103-003, 004, 005, 008, 009;
// SC-R02G2103-002, 004; clarifications Q1, Q4, Q5; research R12–R14; data-model.md; contracts/api.md). The adapter of
// the Binary Gardens kernel to the shared experience contract. The core holds the level number, the kernel's
// `BinaryGardensPlay` and the shown tick; it never draws and reads no clock. The presenter asks for an immutable
// `BinaryGardensSceneSnapshot` at its own presentation time (`snapshot(time:)`), so the scene can breathe while the
// state and its digest stay put (renderer purity). The snapshot carries the kernel's exact report of the current
// arrangement — every body's position, every world's flux, shares, bands, windows and integral at ticks 1 … 48 — so no
// drawn value decides a band, a window or the verdict. The shown tick is presentation state of the adapter
// (`clock.show [tick]`, research R12): 48 at an opening (the starting configuration, since tick 48 is tick 0 again),
// after `level.next`, a reset and a restore; a ring, phase, luminosity or tilt change, the run, undo and redo keep it
// (the report always covers ticks 1 … 48); never advanced by time and never in the digest, the snapshot payload or
// `==`. Modelled on `MushroomWeatherExperienceCore` (feature 493).
//
// Preparation: the certified level number `seed % 100 + 1` of `BinaryGardensManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each R02-G21-02
// witness's `skipped`), the whole catalog (`BinaryGardensGenerator.catalog()`, once per process) only if that candidate
// no longer certifies; begun (and its tutorial dismissed, as `BinaryGardensSolver.replayWins` does) so the play is in
// stage `playing`. The tutorial of the first levels is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   star.ring [0…1, 0…7]         star and ring index, whole numbers (`r02-g21.not-whole` otherwise); moves the star to
//                                the ring (1 action); a ring the level lacks, a locked ring, the star's current ring or
//                                an arrangement that breaks the minimum separation is the kernel's `r02-g21.action`;
//                                no action left is `r02-g21.budget`;
//   star.phase [0…1, 0…47]       star and phase step (1 action); a step off the level's phase grid, a locked phase, the
//                                current phase or a separation break is `r02-g21.action`; budget as above;
//   star.luminosity [0…1, 0…3]   star and luminosity index (1 action); a level the level lacks, a locked luminosity or
//                                the current one is `r02-g21.action`; budget as above;
//   orbit.tilt [0…6]             the tilt step (1 action); a step above T_max, a locked tilt (T_max = 0), the current
//                                tilt or a separation break is `r02-g21.action`; budget as above;
//   light.run                    the run that ends the level (no action spent): `won` when the report wins, else
//                                `failed` with its failure;
//   play.undo, play.redo         the kernel's exact undo and redo (`r02-g21.action` when there is nothing to undo or
//                                redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                   the next certified level (100 wraps to 1) with a fresh play, tick 48 shown;
//   clock.show [0…60]            shows tick 1 … 48 (presentation only; accepted in every stage); 0 and 49 … 60 are
//                                refused `r02-g21.tick` without touching the kernel.
// The declared ranges are star 0 … 1, ring index 0 … 7 (`BinaryGardensLevel.ringCounts` upper bound − 1), phase 0 … 47,
// luminosity index 0 … 3 (`luminosityCounts` upper bound − 1), tilt 0 … 6 (`maxTilts`) and tick 0 … 60 (0 … 48 + the
// largest tolerance 12, the span of the kernel's walk ticks), so the engine refuses only values outside them and the
// adapter's own `r02-g21.tick` stays observable (research R12). Outside stage `playing` the kernel refuses an
// arrangement action and the run with `r02-g21.stage`. Every action is applied with the play's fingerprint as the
// expected one, so `r02-g21.stale` cannot arise. A kernel refusal (`BinaryGardensError`) becomes
// `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown tick included.
//
// Digest ("r02-g21.binary-gardens.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the shown tick, the quality tier or a time. Snapshot schema 1: the JSON
// object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`BinaryGardensPlay.replay`), shows tick 48 and throws `BinaryGardensRestoreRefusal` for a damaged payload, a level
// number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another level's seed among
// them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality (research R14): three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best
// and no budget may rise); `qualityTiers` is their count and the profile's level names are `BinaryGardensTier.all`'s
// names (`level-0`, `level-1`, `level-2`). Host tier `t` draws `BinaryGardensTier.of(t)`: level-0 = cube-spheres of
// 8 × 8 quads per face, 12 corona rays, trails of 8 ticks, 8 motes, 2 glow shells; level-1 = 5 × 5, 6 rays, 4 ticks,
// 4 motes, 1 shell; level-2 = 3 × 3, no rays, trails, motes or glow. Outcome: `won` or `failed` while the play is in
// that stage, else nil. Rules use integers only.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Binary Gardens' adapter refusals (feature 503).
public enum BinaryGardensExperienceRule {
    /// A value that must be a whole number (a star, a ring, a phase, a luminosity, a tilt or a tick) and is not.
    public static let notWhole = "r02-g21.not-whole"
    /// A shown tick outside 1 … 48 within the declared range 0 … 60 (`clock.show`).
    public static let tick = "r02-g21.tick"
}

/// Why a saved Binary Gardens state was refused on restore (feature 503). A refused restore changes nothing.
public enum BinaryGardensRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(BinaryGardensError)
}

/// The state of Binary Gardens as an experience (see the file header). Snapshot schema 1.
public struct BinaryGardensExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g21.binary-gardens"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g21.binary-gardens.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["star.ring", "star.phase", "star.luminosity", "orbit.tilt", "light.run",
                                   "play.undo", "play.redo", "level.next", "clock.show"]
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a star: 0 … 1.
    public static let starRange: ClosedRange<Int> = 0...1
    /// The declared range of a ring index: 0 … `BinaryGardensLevel.ringCounts` upper bound − 1 (0 … 7).
    public static let ringRange: ClosedRange<Int> = 0...(BinaryGardensLevel.ringCounts.upperBound - 1)
    /// The declared range of a phase step: `BinaryGardensLevel.phases` (0 … 47).
    public static let phaseRange: ClosedRange<Int> = BinaryGardensLevel.phases
    /// The declared range of a luminosity index: 0 … `BinaryGardensLevel.luminosityCounts` upper bound − 1 (0 … 3).
    public static let luminosityRange: ClosedRange<Int> = 0...(BinaryGardensLevel.luminosityCounts.upperBound - 1)
    /// The declared range of a tilt step: `BinaryGardensLevel.maxTilts` (0 … 6).
    public static let tiltRange: ClosedRange<Int> = BinaryGardensLevel.maxTilts
    /// The declared range of a shown tick: 0 … 48 + the largest tolerance (`BinaryGardensLevel.tolerances` upper bound
    /// 12), the span of the kernel's walk ticks (0 … 60).
    public static let tickRange: ClosedRange<Int> = 0...(BinaryGardensSky.cycle
                                                         + BinaryGardensLevel.tolerances.upperBound)
    /// The ticks `clock.show` accepts: 1 … 48.
    public static let shownTicks: ClosedRange<Int> = 1...BinaryGardensSky.cycle
    /// The tick shown at an opening, after `level.next`, a reset and a restore: 48 (the starting configuration).
    public static let openingTick: Int = BinaryGardensSky.cycle
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level.
    public private(set) var play: BinaryGardensPlay
    /// The shown tick, 1 … 48; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownTick: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: BinaryGardensPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with tick 48 shown, whose reset returns to `openingPlay` of
    /// `openingNumber`.
    init(levelNumber: Int, play: BinaryGardensPlay, openingNumber: Int, openingPlay: BinaryGardensPlay) {
        self.levelNumber = levelNumber
        self.play = play
        self.shownTick = Self.openingTick
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
    public static func level(number: Int) throws(BinaryGardensError) -> BinaryGardensLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for.
    private static let generatedCache = Mutex<[Int: BinaryGardensGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[BinaryGardensGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/binary-gardens/levels/NNN.witness.json`, read 2026-11-27).
    public static let certifiedCandidates: [Int] = [
        1, 1, 2, 3, 0, 2, 1, 3, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 3, 4, 0, 3, 6,
        1, 8, 0, 0, 0, 8, 0, 7, 0, 6, 1, 3, 0, 5, 8, 3, 12, 6, 16, 4, 14, 1, 3, 1, 6,
        0, 1, 20, 24, 3, 9, 11, 14, 6, 2, 11, 3, 2, 0, 1, 0, 0, 6, 4, 5, 1, 1, 1, 6, 0,
        1, 6, 3, 8, 8, 0, 0, 8, 0, 2, 1, 0, 2, 4, 3, 3, 3, 1, 6, 10, 4, 2, 7, 0, 14,
    ]

    /// Candidate `index` of `entry` certified as ``BinaryGardensGenerator/generate(_:previous:)`` certifies a
    /// candidate (a candidate the generator accepts whose minimal plan, found within the solver's work bound, has the
    /// band's plan length and wins through the play); nil otherwise. The neighbour rule is not checked here: the table
    /// names the candidate the generator kept under it.
    static func certify(_ entry: BinaryGardensManifestEntry, index: Int) -> BinaryGardensGenerated? {
        let length: Int = BinaryGardensBandProfile.of(band: entry.band).plan
        guard let level = BinaryGardensGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = BinaryGardensSolver.plan(level, maxDepth: length), plan.size == length else { return nil }
        guard BinaryGardensSolver.replayWins(level, actions: plan.actions) else { return nil }
        return BinaryGardensGenerated(entry: entry, level: level, plan: plan,
                                      difficulty: BinaryGardensDifficulty(level: level, plan: plan), skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(BinaryGardensError) -> BinaryGardensGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: BinaryGardensManifestEntry = BinaryGardensManifest.entries[number - 1]
        let fresh: BinaryGardensGenerated
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
    static func catalog() throws(BinaryGardensError) -> [BinaryGardensGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [BinaryGardensGenerated] = try BinaryGardensGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: BinaryGardensLevel) throws(BinaryGardensError) -> BinaryGardensPlay {
        var play = BinaryGardensPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions,
    /// with tick 48 shown.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(BinaryGardensError) -> BinaryGardensExperienceCore {
        let play: BinaryGardensPlay = try freshPlay(of: try level(number: number))
        return BinaryGardensExperienceCore(levelNumber: number, play: play, openingNumber: number, openingPlay: play)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (the level's rings, luminosity levels, tilt range, phase step and worlds with
    /// their bounds; the arrangement; the report's positions, fluxes, shares, bands, windows and integrals; the shown
    /// tick, the fit scale, the failure, the stage, the actions left and the budget) with the level number, for
    /// drawing at the presenter's presentation time `time` (a non-finite or negative time becomes 0). Reads only; the
    /// state and its digest do not change.
    public func snapshot(time: Double) -> BinaryGardensSceneSnapshot {
        BinaryGardensSceneSnapshot(play: play, shownTick: shownTick, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `BinaryGardensTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: BinaryGardensTier { BinaryGardensTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `BinaryGardensTier.all`.
    public static var qualityTiers: Int { BinaryGardensTier.all.count }

    /// One level per host tier, best first, named as `BinaryGardensTier.all` (research R14): the element share is the
    /// motes over the best tier's (1, 0.5, 0), the iteration share the quads per cube face over the best tier's
    /// (1, 25 / 64, 9 / 64), the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: BinaryGardensTier = BinaryGardensTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<BinaryGardensTier.all.count {
            let tier: BinaryGardensTier = BinaryGardensTier.of(hostTier)
            let quads: Double = Double(tier.faceQuads * tier.faceQuads) / Double(best.faceQuads * best.faceQuads)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.motes) / Double(best.motes),
                                       iterationShare: quads, effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number and the play (not the shown tick, the quality tier or the opening level).
    public static func == (lhs: BinaryGardensExperienceCore, rhs: BinaryGardensExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "star.ring", ranges: [declared(starRange), declared(ringRange)]),
        ExperienceControl(id: "star.phase", ranges: [declared(starRange), declared(phaseRange)]),
        ExperienceControl(id: "star.luminosity", ranges: [declared(starRange), declared(luminosityRange)]),
        ExperienceControl(id: "orbit.tilt", ranges: [declared(tiltRange)]),
        ExperienceControl(id: "light.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "clock.show", ranges: [declared(tickRange)]),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The nine controls with their declared ranges (see the file header); run, undo, redo and next take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with tick 48 shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> BinaryGardensExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(BinaryGardensError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Binary Gardens level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the light changes only on an action, and the scene breathes with the presenter's
    /// time, not the state (the shown tick is never advanced by time).
    public mutating func update(step: Int) {}

    /// The kernel action of an arrangement control's whole values (in the declared ranges); nil for any other control.
    static func kernelAction(_ control: String, _ values: [Int]) -> BinaryGardensAction? {
        switch control {
        case "star.ring": .ring(star: values[0], index: values[1])
        case "star.phase": .phase(star: values[0], step: values[1])
        case "star.luminosity": .luminosity(star: values[0], index: values[1])
        case "orbit.tilt": .tilt(step: values[0])
        case "light.run": .run
        default: nil
        }
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
                return .rejected(.rule(code: BinaryGardensExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(BinaryGardensError) {
            if let kernel = Self.kernelAction(action.control, values) {
                try play.apply(kernel, expecting: play.fingerprint)
            } else {
                switch action.control {
                case "play.undo":
                    try play.undo()
                case "play.redo":
                    try play.redo()
                case "clock.show":
                    // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                    guard Self.shownTicks.contains(values[0]) else {
                        return .rejected(.rule(code: BinaryGardensExperienceRule.tick))
                    }
                    shownTick = values[0]
                default:   // level.next
                    let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                    let fresh: BinaryGardensPlay = try Self.freshPlay(of: try Self.level(number: next))
                    levelNumber = next
                    play = fresh
                    shownTick = Self.openingTick
                }
            }
        } catch {
            return .rejected(.rule(code: error.reasonCode))
        }
        // The shown tick stays: the report always covers ticks 1 … 48.
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Back to the fresh play of the level the seed chose with tick 48 shown; the quality tier, which is not state, is
    /// kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = openingPlay
        shownTick = Self.openingTick
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g21.binary-gardens.v1", then the level number and the play's fingerprint (actions spent, failure, level,
    /// luminosities, phases, rings, stage, tilt).
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
        var records: [BinaryGardensRecord]
    }

    /// The JSON object `{"level", "records"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(level: levelNumber, records: play.records))
    }

    /// The core of `payload`: the records replayed on a fresh play of the saved level, with tick 48 shown; a reset
    /// returns to the level `seed` chooses.
    ///
    /// - Throws: ``BinaryGardensRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level or
    ///   trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> BinaryGardensExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw BinaryGardensRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw BinaryGardensRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(BinaryGardensError) {
            let saved: BinaryGardensLevel = try level(number: decoded.level)
            let play: BinaryGardensPlay = try BinaryGardensPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: BinaryGardensPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return BinaryGardensExperienceCore(levelNumber: decoded.level, play: play, openingNumber: openingNumber,
                                               openingPlay: openingPlay)
        } catch {
            throw BinaryGardensRestoreRefusal.kernel(error)
        }
    }
}
