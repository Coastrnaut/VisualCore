// CelestialEclipseLabExperienceCore — feature 463 (R02-G17-03) T-R02G1703-005 (FR-R02G1703-003, 005; SC-R02G1703-002,
// 004; clarifications Q1, Q4, Q5; data-model.md; contracts/api.md). The adapter of the Celestial Eclipse Lab kernel to
// the shared experience contract. The core holds the level number, the kernel's `CelestialEclipseLabPlay`, the chosen
// body and the shown tick; it never draws and reads no clock. The presenter asks for an immutable
// `CelestialEclipseLabSceneSnapshot` at its own presentation time (`snapshot(time:)`), so the halos can pulse while the
// state and its digest stay put (renderer purity). The snapshot carries the kernel's body positions at the shown tick
// for the current phases, the eclipses under way at that tick and the kernel's predicted timeline, so the drawn bodies
// are the kernel's positions and no drawn value decides an eclipse, a match or the verdict. The chosen body and the
// shown tick are presentation state of the adapter (`orbit.choose [body]`, `clock.show [tick]`): at an opening, after
// `level.next`, a reset and a restore they are `CelestialEclipseLabSceneSnapshot.defaultChoice(level)` (the
// lowest-numbered movable body, clarification Q1) and tick 0; a phase change, the run, undo and redo keep both; never
// in the digest, the snapshot payload or `==`. Modelled on `StarlitCartoucheExperienceCore` (feature 453).
//
// Preparation: the certified level number `seed % 100 + 1` of `CelestialEclipseLabManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole catalog (`CelestialEclipseLabGenerator.catalog()`, once per process) only if that candidate no
// longer certifies; begun (and its tutorial dismissed, as `CelestialEclipseLabSolver.wins` does) so the play is in
// stage `playing`. The tutorial of levels 1 … 3 is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   orbit.phase [0…5, 0…23]  a body and its new phase offset, whole numbers (`r02-g17.not-whole` otherwise); one phase
//                            change (1 action); an unknown or fixed body, an offset outside the body's period or equal
//                            to its current phase are the kernel's `r02-g17.action`; no action left is
//                            `r02-g17.budget`;
//   clock.run                the run that ends the level (no action spent): `won` when the predicted timeline wins,
//                            else `failed` with its failure;
//   play.undo, play.redo     the kernel's exact undo and redo (`r02-g17.action` when there is nothing to undo or redo;
//                            undo works in a failed play and returns it to playing; a won play is final);
//   level.next               the next certified level (100 wraps to 1) with a fresh play;
//   orbit.choose [0…5]       chooses the shown body (presentation only; accepted in every stage); a body the level
//                            lacks is refused `r02-g17.choice` without touching the kernel;
//   clock.show [0…95]        shows the sky at a tick (presentation only; accepted in every stage); a tick outside
//                            0 … horizon − 1 of the level is refused `r02-g17.tick` without touching the kernel.
// The declared body range is the widest any level allows (`CelestialEclipseLabLevel.bodyCounts`: at most 6 bodies, so
// bodies 0 … 5), the offset range the longest period (`CelestialEclipseLabLevel.periods`: offsets 0 … 23) and the tick
// range the longest horizon (`CelestialEclipseLabLevel.horizons`: ticks 0 … 95); the kernel or the adapter refuses the
// values a level lacks. Outside stage `playing` the kernel refuses a phase change and the run with `r02-g17.stage`.
// Every action is applied with the play's fingerprint as the expected one, so `r02-g17.stale` cannot arise. A kernel
// refusal (`CelestialEclipseLabError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing, the
// chosen body and the shown tick included.
//
// Digest ("r02-g17.celestial-eclipse-lab.v1"): the level number and the play's fingerprint (not its record history, so
// undo restores the earlier digest exactly); never the chosen body, the shown tick, the quality tier or a time.
// Snapshot schema 1: the JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh
// play of that level (`CelestialEclipseLabPlay.replay`), resets the presentation state and throws
// `CelestialEclipseLabRestoreRefusal` for a damaged payload, a level number outside 1 … 100 or a trace the kernel
// refuses (a record of a newer schema or of another level's seed among them). An envelope of a newer schema is refused
// by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise). Host tier `t` draws `CelestialEclipseLabTier.of(t)`: level-0 = body spheres of 24 × 16 segments, 2 glow
// shells; level-1 = 16 × 12 segments, 1 glow shell; level-2 = flat 20-sided discs, no glow. Outcome: `won` or `failed`
// while the play is in that stage, else nil. Rules use integers only.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Celestial Eclipse Lab's adapter refusals (feature 463).
public enum CelestialEclipseLabExperienceRule {
    /// A value that must be a whole number (a body, an offset or a tick) and is not.
    public static let notWhole = "r02-g17.not-whole"
    /// A chosen body the level does not have (`orbit.choose`).
    public static let choice = "r02-g17.choice"
    /// A shown tick outside 0 … horizon − 1 of the level (`clock.show`).
    public static let tick = "r02-g17.tick"
}

/// Why a saved Celestial Eclipse Lab state was refused on restore (feature 463). A refused restore changes nothing.
public enum CelestialEclipseLabRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(CelestialEclipseLabError)
}

/// The state of Celestial Eclipse Lab as an experience (see the file header). Snapshot schema 1.
public struct CelestialEclipseLabExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g17.celestial-eclipse-lab"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g17.celestial-eclipse-lab.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["orbit.phase", "clock.run", "play.undo", "play.redo", "level.next", "orbit.choose",
                                   "clock.show"]
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a body: the most bodies any level has (`CelestialEclipseLabLevel.bodyCounts`, 0 … 5).
    public static let bodyRange: ClosedRange<Int> = 0...(CelestialEclipseLabLevel.bodyCounts.upperBound - 1)
    /// The declared range of a phase offset: the longest period any body has (`CelestialEclipseLabLevel.periods`,
    /// 0 … 23).
    public static let offsetRange: ClosedRange<Int> = 0...(CelestialEclipseLabLevel.periods.upperBound - 1)
    /// The declared range of a shown tick: the longest horizon any level has (`CelestialEclipseLabLevel.horizons`,
    /// 0 … 95).
    public static let tickRange: ClosedRange<Int> = 0...(CelestialEclipseLabLevel.horizons.upperBound - 1)
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level.
    public private(set) var play: CelestialEclipseLabPlay
    /// The chosen body, one the level has; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var chosenBody: Int
    /// The shown tick, 0 … horizon − 1; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownTick: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: CelestialEclipseLabPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with the default presentation (the default body, tick 0), whose
    /// reset returns to `openingPlay` of `openingNumber`.
    init(levelNumber: Int, play: CelestialEclipseLabPlay, openingNumber: Int, openingPlay: CelestialEclipseLabPlay) {
        self.levelNumber = levelNumber
        self.play = play
        self.chosenBody = CelestialEclipseLabSceneSnapshot.defaultChoice(play.level)
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
    public static func level(number: Int) throws(CelestialEclipseLabError) -> CelestialEclipseLabLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 463).
    private static let generatedCache = Mutex<[Int: CelestialEclipseLabGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[CelestialEclipseLabGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/celestial-eclipse-lab/levels/NNN.witness.json`, read
    /// 2026-11-25).
    public static let certifiedCandidates: [Int] = [
        0, 0, 1, 0, 0, 0, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1,
        0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 1, 1, 1, 0, 3, 3, 1,
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0,
        0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 1, 0, 4, 2, 1, 0, 0, 0, 0,
    ]

    /// Candidate `index` of `entry` certified as ``CelestialEclipseLabGenerator/generate(_:previous:)`` certifies a
    /// candidate (a valid candidate whose minimal plan lies in its band's range and within the budget, within the
    /// solver's work bound), and whose plan followed by the run wins through the kernel; nil otherwise. The neighbour
    /// rule is not checked here: the table names the candidate the generator kept under it.
    static func certify(_ entry: CelestialEclipseLabManifestEntry, index: Int) -> CelestialEclipseLabGenerated? {
        let range: ClosedRange<Int> = CelestialEclipseLabBandProfile.of(band: entry.band).planRange
        guard let level = CelestialEclipseLabGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = CelestialEclipseLabSolver.plan(level, maxChanges: range.upperBound) else { return nil }
        guard range.contains(plan.size), plan.size <= entry.budget else { return nil }
        guard CelestialEclipseLabSolver.wins(level, actions: plan.actions) else { return nil }
        return CelestialEclipseLabGenerated(entry: entry, level: level, plan: plan,
                                            difficulty: CelestialEclipseLabDifficulty(level: level, plan: plan),
                                            skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(CelestialEclipseLabError) -> CelestialEclipseLabGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: CelestialEclipseLabManifestEntry = CelestialEclipseLabManifest.entries[number - 1]
        let fresh: CelestialEclipseLabGenerated
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
    static func catalog() throws(CelestialEclipseLabError) -> [CelestialEclipseLabGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [CelestialEclipseLabGenerated] = try CelestialEclipseLabGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: CelestialEclipseLabLevel)
        throws(CelestialEclipseLabError) -> CelestialEclipseLabPlay {
        var play = CelestialEclipseLabPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions,
    /// with the default body chosen and tick 0 shown.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(CelestialEclipseLabError) -> CelestialEclipseLabExperienceCore {
        let play: CelestialEclipseLabPlay = try freshPlay(of: try level(number: number))
        return CelestialEclipseLabExperienceCore(levelNumber: number, play: play, openingNumber: number,
                                                 openingPlay: play)
    }

    /// Sets the presentation to the default: the lowest-numbered movable body
    /// (``CelestialEclipseLabSceneSnapshot/defaultChoice(_:)``) and tick 0.
    private mutating func resetPresentation() {
        chosenBody = CelestialEclipseLabSceneSnapshot.defaultChoice(play.level)
        shownTick = 0
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (bodies, phases, positions and eclipses at the shown tick, target, predicted
    /// intervals, matched count, failure, shown tick, horizon, chosen body, stage, actions left and budget) with the
    /// level number, for drawing at the presenter's presentation time `time` (a non-finite or negative time becomes 0).
    /// Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> CelestialEclipseLabSceneSnapshot {
        CelestialEclipseLabSceneSnapshot(play: play, chosenBody: chosenBody, shownTick: shownTick,
                                         levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `CelestialEclipseLabTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: CelestialEclipseLabTier { CelestialEclipseLabTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `CelestialEclipseLabTier.all`.
    public static var qualityTiers: Int { CelestialEclipseLabTier.all.count }

    /// The faces of one body at `tier`: longitudes × latitudes for a sphere, the disc's sides for a flat disc.
    static func bodyFaces(_ tier: CelestialEclipseLabTier) -> Int {
        tier.flatBodies ? CelestialEclipseLabTier.discSides : tier.longitudes * tier.latitudes
    }

    /// One level per host tier, best first, named as `CelestialEclipseLabTier.all`: the element share is a body's faces
    /// over the best tier's (1, 0.5, 20 / 384), the iteration share the glow shells over the best tier's (1, 0.5, 0),
    /// the effect passes the glow shells; every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: CelestialEclipseLabTier = CelestialEclipseLabTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<CelestialEclipseLabTier.all.count {
            let tier: CelestialEclipseLabTier = CelestialEclipseLabTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(bodyFaces(tier)) / Double(bodyFaces(best)),
                                       iterationShare: Double(tier.glowShells) / Double(best.glowShells),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number and the play (not the chosen body, the shown tick, the quality tier or the
    /// opening level).
    public static func == (lhs: CelestialEclipseLabExperienceCore, rhs: CelestialEclipseLabExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "orbit.phase", ranges: [declared(bodyRange), declared(offsetRange)]),
        ExperienceControl(id: "clock.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "orbit.choose", ranges: [declared(bodyRange)]),
        ExperienceControl(id: "clock.show", ranges: [declared(tickRange)]),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The seven controls with their declared ranges (see the file header); run, undo, redo and next take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with the default presentation; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> CelestialEclipseLabExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(CelestialEclipseLabError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Celestial Eclipse Lab level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the timeline changes only on an action, and the halos pulse with the presenter's
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
                return .rejected(.rule(code: CelestialEclipseLabExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(CelestialEclipseLabError) {
            switch action.control {
            case "orbit.phase":
                // The chosen body and the shown tick stay (presentation of the same level).
                try play.apply(.phase(values[0], values[1]), expecting: play.fingerprint)
            case "clock.run":
                try play.apply(.run, expecting: play.fingerprint)
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
            case "orbit.choose":
                // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                guard values[0] < play.level.bodies.count else {
                    return .rejected(.rule(code: CelestialEclipseLabExperienceRule.choice))
                }
                chosenBody = values[0]
            case "clock.show":
                // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                guard values[0] < play.level.horizon else {
                    return .rejected(.rule(code: CelestialEclipseLabExperienceRule.tick))
                }
                shownTick = values[0]
            default:   // level.next
                let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                let fresh: CelestialEclipseLabPlay = try Self.freshPlay(of: try Self.level(number: next))
                levelNumber = next
                play = fresh
                resetPresentation()
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

    /// Back to the fresh play of the level the seed chose with the default presentation; the quality tier, which is
    /// not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = openingPlay
        resetPresentation()
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g17.celestial-eclipse-lab.v1", then the level number and the play's fingerprint (actions spent, failure,
    /// level, phases, stage).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // chosen body or the shown tick (presentation).
        builder.add(play.fingerprint)
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The play's records.
        var records: [CelestialEclipseLabRecord]
    }

    /// The JSON object `{"level", "records"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(level: levelNumber, records: play.records))
    }

    /// The core of `payload`: the records replayed on a fresh play of the saved level, with the default presentation;
    /// a reset returns to the level `seed` chooses.
    ///
    /// - Throws: ``CelestialEclipseLabRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level
    ///   or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> CelestialEclipseLabExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw CelestialEclipseLabRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw CelestialEclipseLabRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(CelestialEclipseLabError) {
            let saved: CelestialEclipseLabLevel = try level(number: decoded.level)
            let play: CelestialEclipseLabPlay = try CelestialEclipseLabPlay.replay(level: saved,
                                                                                   records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: CelestialEclipseLabPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return CelestialEclipseLabExperienceCore(levelNumber: decoded.level, play: play,
                                                     openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw CelestialEclipseLabRestoreRefusal.kernel(error)
        }
    }
}
