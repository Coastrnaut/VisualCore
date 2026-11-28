// MyceliumArchitectExperienceCore — feature 513 (R02-G22-03) T-R02G2203-002 (FR-R02G2203-003, 004, 005, 008, 009;
// SC-R02G2203-002, 004; clarifications Q1, Q4, Q5; research R10–R12; data-model.md; contracts/api.md). The adapter of
// the Mycelium Architect kernel to the shared experience contract. The core holds the level number, the kernel's
// `MyceliumArchitectPlay` and the shown pulse; it never draws and reads no clock. The presenter asks for an immutable
// `MyceliumArchitectSceneSnapshot` at its own presentation time (`snapshot(time:)`, or `snapshotForRendering` at time
// 0), so the veins can pulse while the state and its digest stay put (renderer purity). The snapshot carries the
// kernel's exact growth report of the current arrangement, so no drawn value decides a reach, a weight or the verdict.
// The shown pulse is presentation state of the adapter (`growth.show [pulse]`, research R10): equal to the report's
// pulses run at an opening and after every accepted action, undo, redo, `level.next`, reset and restore; never advanced
// by time and never in the digest, the snapshot payload or `==`. Lives in `Core/Presentation/`, outside the kernel's
// source scans (research R2). Modelled on `BinaryGardensExperienceCore` as recorded at feature 503.
//
// Preparation: the certified level number `seed % 100 + 1` of `MyceliumArchitectManifest`, certified once per process
// (lazily, one level at a time) directly from its certified candidate (`certifiedCandidates`, each R02-G22-02
// witness's `skipped`), the whole catalog (`MyceliumArchitectGenerator.catalog()`, once per process) only if that
// candidate no longer certifies; begun (and its tutorial dismissed) so the play is in stage `playing`.
//
// Actions (the engine refuses an undeclared control, a wrong value count, a non-finite or out-of-range value before the
// core sees it; called directly, the core refuses them itself with the same reasons):
//   cell.nutrient [0…31, 0…31]   column and row, whole numbers (`r02-g22.not-whole` otherwise); places a nutrient
//                                (1 action); a cell off the board, not empty or not a site, or the nutrient limit
//                                reached is the kernel's `r02-g22.action`; no action left is `r02-g22.budget`;
//   cell.blocker [0…31, 0…31]    places a blocker (1 action); refusals as for a nutrient (the blocker limit);
//   cell.clear [0…31, 0…31]      clears a placed nutrient or blocker (1 action); a cell without one is
//                                `r02-g22.action`;
//   root.seed [0…7]              seeds a direction at the root (1 action); a direction already seeded or the seed limit
//                                reached is `r02-g22.action`;
//   root.unseed [0…7]            removes a player seed (1 action); a direction not seeded or a starting seed is
//                                `r02-g22.action`;
//   growth.run                   the run that ends the level (no action spent): `won` when the report wins, else
//                                `failed` with its failure;
//   play.undo, play.redo         the kernel's exact undo and redo (`r02-g22.action` when there is nothing to undo or
//                                redo; undo works in a failed play and returns it to playing; a won play is final);
//   level.next                   the next certified level (100 wraps to 1) with a fresh play;
//   growth.show [0…128]          shows pulse 0 … the pulses run (presentation only; accepted in every stage); a pulse
//                                above the pulses run is refused `r02-g22.pulse` without touching the kernel.
// The declared ranges are column and row 0 … 31 (`MyceliumArchitectLevel.sides` upper bound − 1), direction 0 … 7 and
// pulse 0 … 128 (`MyceliumArchitectLevel.pulseRange` upper bound), so the engine refuses only values outside them and
// the kernel's and the adapter's own codes stay observable (research R10). Outside stage `playing` the kernel refuses
// an arrangement action and the run with `r02-g22.stage`. Every action is applied with the play's fingerprint as the
// expected one, so `r02-g22.stale` cannot arise. A kernel refusal (`MyceliumArchitectError`) becomes
// `.rule(code: error.reasonCode)`. A refused action changes nothing, the shown pulse included.
//
// Digest ("r02-g22.mycelium-architect.v1"): the level number and the play's fingerprint (not its record history, so
// undo restores the earlier digest exactly); never the shown pulse, the quality tier or a time. Snapshot schema 1: the
// JSON object `{"level", "records"}` with sorted keys; restoring replays the records on a fresh play of that level
// (`MyceliumArchitectPlay.replay`), shows the pulses run and throws `MyceliumArchitectRestoreRefusal` for a damaged
// payload, a level number outside 1 … 100 or a trace the kernel refuses (a record of a newer schema or of another
// level's seed among them). An envelope of a newer schema is refused by the engine before the core sees it.
//
// Quality (research R12): three host tiers, best first as the contract requires (`qualityProfile` level 0 is the best
// and no budget may rise); `qualityTiers` is their count and the profile's level names are
// `MyceliumArchitectTier.all`'s names (`level-0`, `level-1`, `level-2`). Host tier `t` draws
// `MyceliumArchitectTier.of(t)`. Outcome: `won` or `failed` while the play is in that stage, else nil. Rules use
// integers only.
//
// Feature 514 (R02-G22-04) T-R02G2204-002 (FR-R02G2204-002, 005, 006, 008, 014; SC-R02G2204-003, 006; clarifications
// Q2, Q3, Q5; research R4, R7): the core also holds the presentation state of the gestures and the panel — the tool
// (nutrient by default), the preview (``MyceliumArchitectPreview``, computed by the kernel's change rule and growth),
// the inspected cell and the view orbit — never in the digest, the snapshot payload or `==`, and carried into
// `snapshot(time:)`. ``previewReport(_:)`` gives the kernel's report of a changed arrangement or its refusal without
// changing anything. The tool, the preview, the inspection and the orbit return to their defaults at an opening, at
// `level.next`, at `reset()` and at restore (with the shown pulse at the pulses run, as before); every other accepted
// action but `growth.show` clears the preview (its arrangement is gone), keeping the tool, the inspection and the orbit.
import Foundation
import Synchronization
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Mycelium Architect's adapter refusals (feature 513).
public enum MyceliumArchitectExperienceRule {
    /// A value that must be a whole number (a column, a row, a direction or a pulse) and is not.
    public static let notWhole = "r02-g22.not-whole"
    /// A shown pulse above the pulses run within the declared range 0 … 128 (`growth.show`).
    public static let pulse = "r02-g22.pulse"
}

/// Why a saved Mycelium Architect state was refused on restore (feature 513). A refused restore changes nothing.
public enum MyceliumArchitectRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object `{"level", "records"}` or a field has the wrong type.
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(MyceliumArchitectError)
}

/// The state of Mycelium Architect as an experience (see the file header). Snapshot schema 1.
public struct MyceliumArchitectExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g22.mycelium-architect"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "r02-g22.mycelium-architect.v1"
    /// The action ids in declaration order.
    public static let actionIDs = ["cell.nutrient", "cell.blocker", "cell.clear", "root.seed", "root.unseed",
                                   "growth.run", "play.undo", "play.redo", "level.next", "growth.show"]
    /// The level numbers of the catalog.
    public static let levelNumbers: ClosedRange<Int> = 1...100
    /// The declared range of a column or a row: 0 … `MyceliumArchitectLevel.sides` upper bound − 1 (0 … 31).
    public static let cellRange: ClosedRange<Int> = 0...(MyceliumArchitectLevel.sides.upperBound - 1)
    /// The declared range of a direction: 0 … 7 (north … north-west).
    public static let directionRange: ClosedRange<Int> = 0...(MyceliumArchitectDirection.allCases.count - 1)
    /// The declared range of a shown pulse: 0 … `MyceliumArchitectLevel.pulseRange` upper bound (0 … 128).
    public static let pulseRange: ClosedRange<Int> = 0...MyceliumArchitectLevel.pulseRange.upperBound
    /// The outcome code of a won play.
    public static let wonCode = "won"
    /// The outcome code of a failed play.
    public static let failedCode = "failed"

    /// The number of the certified level being played (1 … 100).
    public private(set) var levelNumber: Int
    /// The kernel's play of that level.
    public private(set) var play: MyceliumArchitectPlay
    /// The shown pulse, 0 … the pulses run; presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var shownPulse: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The fresh play of the opening level; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let openingPlay: MyceliumArchitectPlay
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0
    /// The placement tool (feature 514); presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var tool: MyceliumArchitectTool = .nutrient
    /// The previewed change (feature 514); presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var preview: MyceliumArchitectPreview? = nil
    /// The inspected cell (feature 514); presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var inspectedCell: MyceliumArchitectCell? = nil
    /// The view orbit, clamped (feature 514); presentation only — not in the digest, the snapshot payload or `==`.
    public private(set) var orbit: MyceliumArchitectViewOrbit = .authored

    /// A state playing `play` of level `levelNumber` with the pulses run shown, whose reset returns to `openingPlay` of
    /// `openingNumber`.
    init(levelNumber: Int, play: MyceliumArchitectPlay, openingNumber: Int, openingPlay: MyceliumArchitectPlay) {
        self.levelNumber = levelNumber
        self.play = play
        self.shownPulse = play.report.pulsesRun
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
    public static func level(number: Int) throws(MyceliumArchitectError) -> MyceliumArchitectLevel {
        try generated(number: number).level
    }

    /// The certified levels prepared so far, by manifest number: certification runs the solver, so each level is
    /// certified once per process, and only when first asked for.
    private static let generatedCache = Mutex<[Int: MyceliumArchitectGeneratedLevel]>([:])

    /// The whole certified catalog, generated at most once per process and only when a certified candidate no longer
    /// certifies (the fallback).
    private static let catalogCache = Mutex<[MyceliumArchitectGeneratedLevel]?>(nil)

    /// The certified candidate of each manifest number 1 … 100: the candidates the generator skips before the one it
    /// keeps (each stored witness's `skipped`, `docs/games/mycelium-architect/levels/NNN.witness.json`, read
    /// 2026-11-27; recomputed with the generator by `MyceliumArchitectExperienceCoreTests`).
    public static let certifiedCandidates: [Int] = [
        0, 1, 2, 0, 38, 4, 1, 0, 1, 12, 0, 5, 5, 0, 99, 1, 2, 0, 1, 4, 9, 12, 2, 0, 39,
        1, 14, 3, 0, 25, 1, 15, 2, 3, 37, 15, 3, 7, 3, 71, 8, 3, 29, 13, 51, 5, 9, 8, 41, 98,
        17, 9, 0, 1, 54, 4, 59, 11, 1, 22, 80, 4, 10, 0, 1, 0, 49, 13, 11, 349, 26, 0, 6, 19, 0,
        1, 6, 7, 7, 72, 22, 8, 1, 8, 116, 65, 17, 12, 50, 3, 16, 40, 43, 4, 111, 39, 38, 52, 9, 146,
    ]

    /// Candidate `index` of `entry` certified as ``MyceliumArchitectGenerator/generate(_:previous:)`` certifies a
    /// candidate (a candidate whose minimal plan, found within the solver's work bound, has the band's plan length and
    /// wins through the play); nil otherwise. The neighbour rule is not checked here: the table names the candidate the
    /// generator kept under it.
    static func certify(_ entry: MyceliumArchitectManifestEntry, index: Int) -> MyceliumArchitectGeneratedLevel? {
        MyceliumArchitectGenerator.candidate(entry, index: index, previous: nil)
    }

    /// The certified level and its plan of manifest number `number` (1 … 100), certified once per process: its
    /// certified candidate (``certifiedCandidates``) is certified directly; the whole catalog is generated only if that
    /// candidate does not certify.
    ///
    /// - Throws: `.level("number")` for a number outside 1 … 100; the generator's `.generation(number)`.
    public static func generated(number: Int) throws(MyceliumArchitectError) -> MyceliumArchitectGeneratedLevel {
        guard levelNumbers.contains(number) else { throw .level("number") }
        if let cached = generatedCache.withLock({ $0[number] }) { return cached }
        let entry: MyceliumArchitectManifestEntry = MyceliumArchitectManifest.entries[number - 1]
        let fresh: MyceliumArchitectGeneratedLevel
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
    static func catalog() throws(MyceliumArchitectError) -> [MyceliumArchitectGeneratedLevel] {
        if let cached = catalogCache.withLock({ $0 }) { return cached }
        let fresh: [MyceliumArchitectGeneratedLevel] = try MyceliumArchitectGenerator.catalog()
        catalogCache.withLock { $0 = fresh }
        return fresh
    }

    /// A fresh play of `level` in stage `playing`: begun, with its tutorial dismissed when it has one.
    ///
    /// - Throws: the kernel's refusal of `begin` or `dismissTutorial` (never for a new play).
    public static func freshPlay(of level: MyceliumArchitectLevel) throws(MyceliumArchitectError)
        -> MyceliumArchitectPlay {
        var play = MyceliumArchitectPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions, with the pulses run shown.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(MyceliumArchitectError) -> MyceliumArchitectExperienceCore {
        let play: MyceliumArchitectPlay = try freshPlay(of: try level(number: number))
        return MyceliumArchitectExperienceCore(levelNumber: number, play: play, openingNumber: number,
                                               openingPlay: play)
    }

    // MARK: Scene snapshots

    /// An immutable copy of the play (the level; the arrangement; the report's network, path weights, consumed
    /// nutrients, weights, terminal pulses and pulses run; the shown pulse, the fit scale, the failure, the stage and
    /// the actions left) with the level number, for drawing at the presenter's presentation time `time` (a non-finite
    /// or negative time becomes 0). Reads only; the state and its digest do not change.
    public func snapshot(time: Double) -> MyceliumArchitectSceneSnapshot {
        MyceliumArchitectSceneSnapshot(play: play, shownPulse: shownPulse, levelNumber: levelNumber, time: time)
            .presenting(tool: tool, preview: preview, inspectedCell: inspectedCell, orbit: orbit)
    }

    /// The snapshot the renderer reads at presentation time 0 (``snapshot(time:)``); the presenter supplies its own
    /// time through ``snapshot(time:)``.
    public var snapshotForRendering: MyceliumArchitectSceneSnapshot { snapshot(time: 0) }

    /// The tier the host quality tier draws: `MyceliumArchitectTier.of(qualityTier)` (both ordered richest first).
    public var renderTier: MyceliumArchitectTier { MyceliumArchitectTier.of(qualityTier) }

    // MARK: Presentation state (feature 514)

    /// The kernel's growth report of the arrangement `action` would make, or the refusal the play would give it, in
    /// the play's order (`.stage` outside `playing`, the change rule `MyceliumArchitectPlay.changed`, `.budget` with no
    /// action left), through ``MyceliumArchitectPreview/of(_:level:arrangement:stage:actionsLeft:)`` —
    /// `MyceliumArchitectPlay.changed` and `MyceliumArchitectGrowth.report`, never a second implementation. Reads only:
    /// the state, its digest and the preview do not change.
    public func previewReport(_ action: MyceliumArchitectAction)
        -> Result<MyceliumArchitectReport, MyceliumArchitectError> {
        let previewed: MyceliumArchitectPreview = MyceliumArchitectPreview.of(
            action, level: play.level, arrangement: play.arrangement, stage: play.stage,
            actionsLeft: play.actionsLeft)
        switch previewed.outcome {
        case .accepted(_, let report): return .success(report)
        case .refused(let error): return .failure(error)
        }
    }

    /// Chooses `tool`; the state and its digest do not change.
    public mutating func setTool(_ tool: MyceliumArchitectTool) {
        self.tool = tool
    }

    /// Previews `change` (``MyceliumArchitectPreview/of(_:level:arrangement:stage:actionsLeft:)`` of the play); the
    /// state and its digest do not change.
    public mutating func setPreview(_ change: MyceliumArchitectAction) {
        preview = MyceliumArchitectPreview.of(change, level: play.level, arrangement: play.arrangement,
                                              stage: play.stage, actionsLeft: play.actionsLeft)
    }

    /// Clears the preview; the state and its digest do not change.
    public mutating func clearPreview() {
        preview = nil
    }

    /// Inspects `cell` (nil, or a cell off the board, clears the inspection); the state and its digest do not change.
    public mutating func inspect(_ cell: MyceliumArchitectCell?) {
        if let target = cell, play.level.contains(target) {
            inspectedCell = target
        } else {
            inspectedCell = nil
        }
    }

    /// Sets the view orbit (clamped); the state and its digest do not change.
    public mutating func setOrbit(_ orbit: MyceliumArchitectViewOrbit) {
        self.orbit = orbit.clamped()
    }

    /// Returns to the authored view; the state and its digest do not change.
    public mutating func resetView() {
        orbit = .authored
    }

    /// The tool, the preview, the inspection and the orbit back to their defaults (an opening, `level.next`, reset).
    mutating func resetPresentation() {
        tool = .nutrient
        preview = nil
        inspectedCell = nil
        orbit = .authored
    }

    // MARK: Quality

    /// Three quality tiers: level-0 (richest) … level-2 (cheapest), as many as `MyceliumArchitectTier.all`.
    public static var qualityTiers: Int { MyceliumArchitectTier.all.count }

    /// One level per host tier, best first, named as `MyceliumArchitectTier.all` (research R12): the element share is
    /// the spores over the best tier's (1, 0.5, 0), the iteration share the tube sides over the best tier's (1, 0.75,
    /// 0.5), the effect passes the glow shells (2, 1, 0); every level draws at the full resolution.
    public static var qualityProfile: QualityProfile {
        let best: MyceliumArchitectTier = MyceliumArchitectTier.all[0]
        var levels: [QualityLevel] = []
        for hostTier in 0..<MyceliumArchitectTier.all.count {
            let tier: MyceliumArchitectTier = MyceliumArchitectTier.of(hostTier)
            levels.append(QualityLevel(name: tier.name, resolutionShare: 1,
                                       elementShare: Double(tier.spores) / Double(best.spores),
                                       iterationShare: Double(tier.tubeSides) / Double(best.tubeSides),
                                       effectPasses: tier.glowShells))
        }
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: the level number and the play (not the shown pulse, the quality tier, the opening level or the
    /// presentation state of feature 514).
    public static func == (lhs: MyceliumArchitectExperienceCore, rhs: MyceliumArchitectExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play
    }

    // MARK: Contract

    /// Schema 1, no migration steps; a payload that does not decode is refused.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The encoder of payloads: sorted keys, unescaped slashes.
    static func payloadEncoder() -> JSONEncoder {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "cell.nutrient", ranges: [declared(cellRange), declared(cellRange)]),
        ExperienceControl(id: "cell.blocker", ranges: [declared(cellRange), declared(cellRange)]),
        ExperienceControl(id: "cell.clear", ranges: [declared(cellRange), declared(cellRange)]),
        ExperienceControl(id: "root.seed", ranges: [declared(directionRange)]),
        ExperienceControl(id: "root.unseed", ranges: [declared(directionRange)]),
        ExperienceControl(id: "growth.run"),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "growth.show", ranges: [declared(pulseRange)]),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The ten controls with their declared ranges (see the file header); `growth.run`, `play.undo`, `play.redo` and
    /// `level.next` take no values.
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state of level `seed % 100 + 1`, in stage `playing` with the pulses run shown; no clock is read.
    ///
    /// - Throws: `ExperienceFailure` with the kernel's reason code when the level cannot be certified.
    public static func prepare(seed: UInt64) async throws -> MyceliumArchitectExperienceCore {
        try Task.checkCancellation()
        let number: Int = levelNumber(forSeed: seed)
        do throws(MyceliumArchitectError) {
            return try opening(number: number)
        } catch {
            throw ExperienceFailure(code: error.reasonCode, message: "Mycelium Architect level \(number): \(error)")
        }
    }

    /// A host step changes nothing: the growth changes only on an action, and the veins pulse with the presenter's
    /// time, not the state (the shown pulse is never advanced by time).
    public mutating func update(step: Int) {}

    /// The kernel action of an arrangement control's or the run's whole values (in the declared ranges); nil for any
    /// other control.
    static func kernelAction(_ control: String, _ values: [Int]) -> MyceliumArchitectAction? {
        switch control {
        case "cell.nutrient": .nutrient(MyceliumArchitectCell(column: values[0], row: values[1]))
        case "cell.blocker": .blocker(MyceliumArchitectCell(column: values[0], row: values[1]))
        case "cell.clear": .clear(MyceliumArchitectCell(column: values[0], row: values[1]))
        case "root.seed": MyceliumArchitectDirection(rawValue: values[0]).map { .seed($0) }
        case "root.unseed": MyceliumArchitectDirection(rawValue: values[0]).map { .unseed($0) }
        case "growth.run": .run
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
                return .rejected(.rule(code: MyceliumArchitectExperienceRule.notWhole))
            }
            values.append(whole)
        }
        do throws(MyceliumArchitectError) {
            if let kernel = Self.kernelAction(action.control, values) {
                try play.apply(kernel, expecting: play.fingerprint)
            } else {
                switch action.control {
                case "play.undo":
                    try play.undo()
                case "play.redo":
                    try play.redo()
                case "growth.show":
                    // Presentation only: the play and the digest do not change, and the kernel is not consulted.
                    guard values[0] <= play.report.pulsesRun else {
                        return .rejected(.rule(code: MyceliumArchitectExperienceRule.pulse))
                    }
                    shownPulse = values[0]
                    return .accepted
                default:   // level.next: the next certified level, 100 wraps to 1.
                    let next: Int = levelNumber < Self.levelNumbers.upperBound
                        ? levelNumber + 1 : Self.levelNumbers.lowerBound
                    let fresh: MyceliumArchitectPlay = try Self.freshPlay(of: try Self.level(number: next))
                    levelNumber = next
                    play = fresh
                    resetPresentation()
                }
            }
        } catch {
            return .rejected(.rule(code: error.reasonCode))
        }
        // Every accepted action but `growth.show` shows the whole growth of the report again, and its preview is gone.
        shownPulse = play.report.pulsesRun
        preview = nil
        return .accepted
    }

    /// `value` as an `Int` when it is a finite whole number; nil otherwise.
    static func whole(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// Back to the opening state the seed chose with the pulses run shown and the presentation state at its defaults
    /// (feature 514); the quality tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = openingPlay
        shownPulse = play.report.pulsesRun
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

    /// "r02-g22.mycelium-architect.v1", then the level number and the play's fingerprint (actions spent, blockers,
    /// failure, level, nutrients, seeds, stage); never the shown pulse, the quality tier or a time.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly.
        builder.add(play.fingerprint)
    }

    // MARK: Snapshot

    /// The payload's JSON form (schema 1).
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The play's records.
        var records: [MyceliumArchitectRecord]
    }

    /// The JSON object `{"level", "records"}` with sorted keys and unescaped slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, records: play.records))
    }

    /// The core of `payload` (schema 1): the records replayed on a fresh play of the saved level, with the pulses run
    /// shown; a reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``MyceliumArchitectRestoreRefusal`` for a damaged payload, a level number outside 1 … 100 or a level
    ///   or trace the kernel refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> MyceliumArchitectExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw MyceliumArchitectRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw MyceliumArchitectRestoreRefusal.levelNumber(decoded.level)
        }
        do throws(MyceliumArchitectError) {
            let level: MyceliumArchitectLevel = try level(number: decoded.level)
            let play: MyceliumArchitectPlay = try MyceliumArchitectPlay.replay(level: level, records: decoded.records)
            let openingCore: MyceliumArchitectExperienceCore = try opening(number: levelNumber(forSeed: seed))
            return MyceliumArchitectExperienceCore(levelNumber: decoded.level, play: play,
                                                   openingNumber: openingCore.openingNumber,
                                                   openingPlay: openingCore.openingPlay)
        } catch {
            throw MyceliumArchitectRestoreRefusal.kernel(error)
        }
    }
}
