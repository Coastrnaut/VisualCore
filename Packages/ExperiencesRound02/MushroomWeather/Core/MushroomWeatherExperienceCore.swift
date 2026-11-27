// MushroomWeatherExperienceCore — feature 493 (R02-G20-03) T-R02G2003-005 (FR-R02G2003-003, 004, 005, 008, 009;
// SC-R02G2003-004; clarifications Q4, Q5; data-model.md; contracts/api.md). The adapter of the Mushroom Weather kernel
// to the shared experience contract. The core holds the level number, the kernel's `MushroomWeatherPlay` and the shown
// cycle; it never draws and reads no clock. The presenter asks for an immutable `MushroomWeatherSceneSnapshot` at its
// own presentation time (`snapshot(time:)`), so the scene can breathe while the state and its digest stay put (renderer
// purity). The snapshot carries the kernel's integer humidity of every cell at every cycle of the predicted run of the
// current arrangement, the cycles run, the colonies with their bands and runs, the pods with their growth cycles, the
// sites, the vents, the moonlight, the failure, the stage and the actions left, so every drawn humidity is a kernel
// humidity and no drawn value decides a cell, a colony or the verdict. The shown cycle is presentation state of the
// adapter (`clock.show [cycle]`): at an opening, after `level.next`, a reset and a restore it is cycle 0; a placement,
// a removal, a vent, the moonlight, the run, undo and redo keep it, clamped to the new cycles run (a run that now fails
// earlier runs fewer cycles); never in the digest, the snapshot payload or `==`. Modelled on
// `MicroscopicAuroraExperienceCore` (feature 483).
//
// Preparation: the certified level number `seed % 100 + 1` of `MushroomWeatherManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each witness's
// `skipped`), the whole catalog (`MushroomWeatherGenerator.catalog()`, once per process) only if that candidate no
// longer certifies; begun (and its tutorial dismissed, as `MushroomWeatherSolver.replayWins` does) so the play is in
// stage `playing`. The tutorial of the first levels is shown by the presenter as presentation, not as a kernel stage.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   pod.place [0…5, 0…11, 0…13]   slot, row and column, whole numbers (`r02-g20.not-whole` otherwise); puts the slot's
//                                 pod on the cell or moves it there (1 action); a slot the level lacks, a cell off the
//                                 floor, a colony cell, a cell that is not a site, a cell another slot's pod occupies
//                                 or the slot's own cell is the kernel's `r02-g20.action`; no action left is
//                                 `r02-g20.budget`;
//   pod.remove [0…5]              empties the slot (1 action); a slot the level lacks or an empty slot is
//                                 `r02-g20.action`; budget as above;
//   vent.set [0…5, 0…1]           vent index and state (1 open, 0 shut) (1 action); a vent the level lacks or the
//                                 vent's current state is `r02-g20.action`; budget as above;
//   moon.set [0…3]                the moonlight level (1 action); the current level is `r02-g20.action`; budget as
//                                 above;
//   weather.run                   the run that ends the level (no action spent): `won` when the report wins, else
//                                 `failed` with its failure;
//   play.undo, play.redo          the kernel's exact undo and redo (`r02-g20.action` when there is nothing to undo or
//                                 redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                    the next certified level (100 wraps to 1) with a fresh play;
//   clock.show [0…200]            shows the humidity at a cycle (presentation only; accepted in every stage); a cycle
//                                 outside 0 … cycles run of the current report is refused `r02-g20.cycle` without
//                                 touching the kernel.
// The declared ranges are the kernel's (`MushroomWeatherPodRules.slotCounts`, `MushroomWeatherLevel.rowCounts`,
// `.columnCounts`, `.ventCounts`, `.moonlightLevels`) and the longest run any level allows
// (`MushroomWeatherLevel.lengths`: cycles 0 … 200); the kernel or the adapter refuses the values a level lacks.
// Outside stage `playing` the kernel refuses an arrangement action and the run with `r02-g20.stage`. Every action is
// applied with the play's fingerprint as the expected one, so `r02-g20.stale` cannot arise. A kernel refusal
// (`MushroomWeatherError`) becomes `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown cycle
// included.
//
// Digest ("r02-g20.mushroom-weather.v1"): the level number and the play's fingerprint (not its record history, so undo
// restores the earlier digest exactly); never the shown cycle, the quality tier or a time. Snapshot schema 1: the JSON
// object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`MushroomWeatherPlay.replay`), resets the shown cycle and throws `MushroomWeatherRestoreRefusal` for a damaged
// payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another
// level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality: three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best and no budget
// may rise); `qualityTiers` is their count and the profile's level names are `MushroomWeatherTier.all`'s names
// (`level-0`, `level-1`, `level-2`). Host tier `t` draws `MushroomWeatherTier.of(t)`: level-0 = lathes of 16 segments,
// 12 droplets per pod, fronds, 8 motes, 2 glow shells; level-1 = 10 segments, 6 droplets, fronds, 4 motes, 1 glow
// shell; level-2 = flat caps and pods, no droplets, fronds, motes or glow. Outcome: `won` or `failed` while the play is
// in that stage, else nil. Rules use integers only.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Mushroom Weather's adapter refusals (feature 493).
public enum MushroomWeatherExperienceRule {
    /// A value that must be a whole number (a slot, a cell, a vent, a state, a level or a cycle) and is not.
    public static let notWhole = "r02-g20.not-whole"
    /// A shown cycle outside 0 … cycles run of the current report (`clock.show`).
    public static let cycle = "r02-g20.cycle"
}

/// Why a saved Mushroom Weather state was refused on restore (feature 493). A refused restore changes nothing.
public enum MushroomWeatherRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(MushroomWeatherError)
}

/// The state of Mushroom Weather as an experience (see the file header). Snapshot schema 1.
public struct MushroomWeatherExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g20.mushroom-weather"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g20.mushroom-weather.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["pod.place", "pod.remove", "vent.set", "moon.set", "weather.run", "play.undo",
                                   "play.redo", "level.next", "clock.show"]
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a pod slot: 0 … `MushroomWeatherPodRules.slotCounts` upper bound − 1 (0 … 5).
    public static let slotRange: ClosedRange<Int> = 0...(MushroomWeatherPodRules.slotCounts.upperBound - 1)
    /// The declared range of a row: 0 … `MushroomWeatherLevel.rowCounts` upper bound − 1 (0 … 11).
    public static let rowRange: ClosedRange<Int> = 0...(MushroomWeatherLevel.rowCounts.upperBound - 1)
    /// The declared range of a column: 0 … `MushroomWeatherLevel.columnCounts` upper bound − 1 (0 … 13).
    public static let columnRange: ClosedRange<Int> = 0...(MushroomWeatherLevel.columnCounts.upperBound - 1)
    /// The declared range of a vent index: 0 … `MushroomWeatherLevel.ventCounts` upper bound − 1 (0 … 5).
    public static let ventRange: ClosedRange<Int> = 0...(MushroomWeatherLevel.ventCounts.upperBound - 1)
    /// The declared range of a vent state: 0 (shut) … 1 (open).
    public static let openRange: ClosedRange<Int> = 0...1
    /// The declared range of the moonlight: `MushroomWeatherLevel.moonlightLevels` (0 … 3).
    public static let moonRange: ClosedRange<Int> = MushroomWeatherLevel.moonlightLevels
    /// The declared range of a shown cycle: the longest run any level allows (`MushroomWeatherLevel.lengths`,
    /// 0 … 200).
    public static let cycleRange: ClosedRange<Int> = 0...MushroomWeatherLevel.lengths.upperBound
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level.
    public private(set) var play: MushroomWeatherPlay
    /// The shown cycle, 0 … cycles run; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownCycle: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: MushroomWeatherPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with cycle 0 shown, whose reset returns to `openingPlay` of
    /// `openingNumber`.
    init(levelNumber: Int, play: MushroomWeatherPlay, openingNumber: Int, openingPlay: MushroomWeatherPlay) {
        self.levelNumber = levelNumber
        self.play = play
        self.shownCycle = 0
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
    public static func level(number: Int) throws(MushroomWeatherError) -> MushroomWeatherLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for (feature 493).
    private static let generatedCache = Mutex<[Int: MushroomWeatherGenerated]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[MushroomWeatherGenerated]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/mushroom-weather/levels/NNN.witness.json`, read
    /// 2026-11-26).
    public static let certifiedCandidates: [Int] = [
        0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1,
        0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 1,
        2, 0, 1, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0,
    ]

    /// Candidate `index` of `entry` certified as ``MushroomWeatherGenerator/generate(_:previous:)`` certifies a
    /// candidate (a candidate the generator accepts whose minimal plan, found within the solver's work bound, has the
    /// band's plan length), and whose plan followed by the run wins through the kernel; nil otherwise. The neighbour
    /// rule is not checked here: the table names the candidate the generator kept under it.
    static func certify(_ entry: MushroomWeatherManifestEntry, index: Int) -> MushroomWeatherGenerated? {
        let length: Int = MushroomWeatherBandProfile.of(band: entry.band).plan
        guard let level = MushroomWeatherGenerator.candidate(entry, index: index) else { return nil }
        guard let plan = MushroomWeatherSolver.plan(level), plan.size == length else { return nil }
        guard MushroomWeatherSolver.replayWins(level, actions: plan.actions) else { return nil }
        return MushroomWeatherGenerated(entry: entry, level: level, plan: plan,
                                        difficulty: MushroomWeatherDifficulty(level: level, plan: plan),
                                        skipped: index)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(MushroomWeatherError) -> MushroomWeatherGenerated {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: MushroomWeatherManifestEntry = MushroomWeatherManifest.entries[number - 1]
        let fresh: MushroomWeatherGenerated
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
    static func catalog() throws(MushroomWeatherError) -> [MushroomWeatherGenerated] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [MushroomWeatherGenerated] = try MushroomWeatherGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: MushroomWeatherLevel) throws(MushroomWeatherError) -> MushroomWeatherPlay {
        var play = MushroomWeatherPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The opening state of manifest number `number`: a play begun and past its tutorial, ready to accept actions,
    /// with cycle 0 shown.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(MushroomWeatherError) -> MushroomWeatherExperienceCore {
        let play: MushroomWeatherPlay = try freshPlay(of: try level(number: number))
        return MushroomWeatherExperienceCore(levelNumber: number, play: play, openingNumber: number,
                                             openingPlay: play)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (the humidity of every cell at every cycle of the predicted run of the current
    /// arrangement, the cycles run, the shown cycle, the colonies, pods, growth cycles, sites, vents, moonlight,
    /// failure, stage, actions left and budget) with the level number, for drawing at the presenter's presentation time
    /// `time` (a non-finite or negative time becomes 0). Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> MushroomWeatherSceneSnapshot {
        MushroomWeatherSceneSnapshot(play: play, shownCycle: shownCycle, levelNumber: levelNumber, time: time)
    }

    /// The tier the host quality tier draws: `MushroomWeatherTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: MushroomWeatherTier { MushroomWeatherTier.of(qualityTier) }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `MushroomWeatherTier.all`.
    public static var qualityTiers: Int { MushroomWeatherTier.all.count }

    /// One level per host tier, best first, named as `MushroomWeatherTier.all`: the element share is a pod's droplets
    /// over the best tier's (1, 0.5, 0), the iteration share a lathe's segments over the best tier's (1, 10 / 16, 0),
    /// the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: MushroomWeatherTier = MushroomWeatherTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<MushroomWeatherTier.all.count {
            let tier: MushroomWeatherTier = MushroomWeatherTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.droplets) / Double(best.droplets),
                                       iterationShare: Double(tier.latheSegments) / Double(best.latheSegments),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number and the play (not the shown cycle, the quality tier or the opening level).
    public static func == (lhs: MushroomWeatherExperienceCore, rhs: MushroomWeatherExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "pod.place", ranges: [declared(slotRange), declared(rowRange), declared(columnRange)]),
        ExperienceControl(id: "pod.remove", ranges: [declared(slotRange)]),
        ExperienceControl(id: "vent.set", ranges: [declared(ventRange), declared(openRange)]),
        ExperienceControl(id: "moon.set", ranges: [declared(moonRange)]),
        ExperienceControl(id: "weather.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "clock.show", ranges: [declared(cycleRange)]),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The nine controls with their declared ranges (see the file header); run, undo, redo and next take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with cycle 0 shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> MushroomWeatherExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(MushroomWeatherError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Mushroom Weather level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the run changes only on an action, and the scene breathes with the presenter's
    /// time, not the state.
    public mutating func update(step: Int) {}

    /// The kernel action of an arrangement control's whole values (in the declared ranges); nil for any other control.
    static func kernelAction(_ control: String, _ values: [Int]) -> MushroomWeatherAction? {
        switch control {
        case "pod.place": .place(slot: values[0], cell: MushroomWeatherCell(row: values[1], column: values[2]))
        case "pod.remove": .remove(slot: values[0])
        case "vent.set": .vent(index: values[0], open: values[1] == 1)
        case "moon.set": .moonlight(level: values[0])
        case "weather.run": .run
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
                return .rejected(.rule(code: MushroomWeatherExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(MushroomWeatherError) {
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
                    guard values[0] <= play.report.cycles else {
                        return .rejected(.rule(code: MushroomWeatherExperienceRule.cycle))
                    }
                    shownCycle = values[0]
                    return .accepted
                default:   // level.next
                    let next: Int = levelNumber % Self.levelNumbers.upperBound + 1
                    let fresh: MushroomWeatherPlay = try Self.freshPlay(of: try Self.level(number: next))
                    levelNumber = next
                    play = fresh
                    shownCycle = 0
                    return .accepted
                }
            }
        } catch {
            return .rejected(.rule(code: error.reasonCode))
        }
        // The shown cycle stays, clamped to the cycles the current report runs.
        shownCycle = min(shownCycle, play.report.cycles)
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Back to the fresh play of the level the seed chose with cycle 0 shown; the quality tier, which is not state, is
    /// kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = openingPlay
        shownCycle = 0
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g20.mushroom-weather.v1", then the level number and the play's fingerprint (actions spent, failure, level,
    /// moonlight, pods, stage, vents).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly; never the
        // shown cycle (presentation).
        builder.add(play.fingerprint)
    }

    // MARK: Snapshot

    /// The payload's JSON form.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The play's records.
        var records: [MushroomWeatherRecord]
    }

    /// The JSON object `{"level", "records"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Payload(level: levelNumber, records: play.records))
    }

    /// The core of `payload`: the records replayed on a fresh play of the saved level, with cycle 0 shown; a reset
    /// returns to the level `seed` chooses.
    ///
    /// - Throws: ``MushroomWeatherRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level or
    ///   trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> MushroomWeatherExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw MushroomWeatherRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw MushroomWeatherRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(MushroomWeatherError) {
            let saved: MushroomWeatherLevel = try level(number: decoded.level)
            let play: MushroomWeatherPlay = try MushroomWeatherPlay.replay(level: saved, records: decoded.records)
            let openingNumber: Int = levelNumber(forSeed: seed)
            let openingPlay: MushroomWeatherPlay = openingNumber == decoded.level
                ? try freshPlay(of: saved)
                : try freshPlay(of: try Self.level(number: openingNumber))
            return MushroomWeatherExperienceCore(levelNumber: decoded.level, play: play,
                                                 openingNumber: openingNumber, openingPlay: openingPlay)
        } catch {
            throw MushroomWeatherRestoreRefusal.kernel(error)
        }
    }
}
