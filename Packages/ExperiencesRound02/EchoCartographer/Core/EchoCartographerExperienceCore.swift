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
//   level.next               the next certified level with a fresh play (since feature 405 the next open level; see
//                            below).
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
// Feature 405 (R02-G11-05) T-R02G1105-004 (FR-R02G1105-001 … 007; clarifications Q2–Q5): the core also holds the
// player's progress (`EchoCartographerProgress`: won levels with the least energy spent and stars, the open frontier),
// the mode (campaign, practice with the energy raised to the kernel's maximum 60, daily) and the tutorial step. No
// level is ever gated by payment: a locked level is one not yet unlocked (FR-R02G1105-006). New actions:
//   level.select [1…100]           an open level, fresh, in campaign mode (`r02-g11.locked` otherwise);
//   mode.daily [year, month, day]  the date's daily level, fresh (`r02-g11.date` for an impossible date); a daily level
//                                  still locked in the campaign is playable and is not opened;
//   mode.practice                  the current level fresh with the energy raised to 60;
//   mode.campaign                  the current level fresh in campaign mode (the frontier when it is not open);
//   tutorial.dismiss               the tutorial ends for this opening.
// Choosing a level or a mode drops the left level's records (the play starts fresh). `level.next` moves to the next
// open level in campaign mode and is refused with `r02-g11.locked` when there is none (100 does not wrap). A win (the
// play reaching `won` on an accepted claim or redo) records `progress.record(level:energySpent:certified:mode:)` with
// the energy spent (every pulse and claim record, undone ones included) and the certified plan's pulse count (campaign
// opens the next level; daily never does; practice records nothing). The tutorial starts at
// `EchoCartographerTutorialStep.initial(level:)` at every opening (levels 1 … 3 in every mode) and advances after an
// accepted new pulse or a newly located beacon; a redo only ends it when it ends the level; undo never moves it. Digest
// "r02-g11.echo-cartographer.v2": level, play fingerprint, progress and mode (never the tutorial step). Snapshot schema
// 2: `{"level", "mode", "progress", "records", "tutorial"}`; schema-1 payloads migrate (no won levels, the levels up to
// the saved level open, campaign mode, the tutorial at its initial step).
//
// Feature 407 (R02-G11-07) T-R02G1107-003 (FR-R02G1107-001 … 007; clarifications Q1–Q5; research R2–R7): a campaign or
// daily win records its winning trace (`EchoCartographerReconciliation.netTrace` of the play's records: the effective
// pulses, claims and marks, an undone action left out unless redone) as a verified result; restore reconciles every
// result (`EchoCartographerReconciliation.reconcile`, the frontier as saved) and exposes `reconciliationDropped` (not
// digested, not in `==`); the replay mode `replay(level)` plays a verified trace action by action:
//   replay.start [1…100]  a fresh play of that level in mode `replay(level)` with the tutorial done
//                         (`r02-g11.no-replay` without a verified result with a trace);
//   replay.step           the next action of the trace (`r02-g11.replay-end` after the last or once the play ended;
//                         `r02-g11.no-replay` outside replay);
//   replay.stop           campaign at that level, the frontier when it is not open (`r02-g11.no-replay` outside
//                         replay);
//   settings.sound [0…1]  the sound choice (FR-R02G1107-007): 1 on, 0 off; whole; allowed in every mode.
// In replay every other action except `tutorial.dismiss` and `settings.sound` is refused with `r02-g11.replay`, and
// nothing is recorded. Digest "r02-g11.echo-cartographer.v3" (the same parts as v2, the progress now with traces; never
// the sound choice or the dropped count); snapshot schema 3 `{"level", "mode", "progress", "records", "sound",
// "tutorial"}` (results carry `trace` and `verified`), migrating 1 → 2 → 3 (2 → 3: every result an empty trace and
// `verified` false, sound off).
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
    /// A level that is not open yet, or no next open level (feature 405).
    public static let locked = "r02-g11.locked"
    /// An impossible calendar date (feature 405).
    public static let date = "r02-g11.date"
    /// No verified result with a trace to replay, or a replay control outside replay (feature 407).
    public static let noReplay = "r02-g11.no-replay"
    /// The replay has no further action: the trace is over or the play ended (feature 407).
    public static let replayEnd = "r02-g11.replay-end"
    /// An action that is not allowed during replay (feature 407).
    public static let replay = "r02-g11.replay"
}

/// Why a saved Echo Cartographer state was refused on restore (feature 403). A refused restore changes nothing.
public enum EchoCartographerRestoreRefusal: Error, Equatable, Sendable {
    /// The payload is not the JSON object of its schema, a field has the wrong type, or the progress or the mode is
    /// invalid (feature 405).
    case damaged
    /// The level number is outside 1 … 100; the value is that number.
    case levelNumber(Int)
    /// The kernel refused the level's generation or the record trace; the value is that refusal.
    case kernel(EchoCartographerError)
}

/// The state of Echo Cartographer as an experience (see the file header). Snapshot schema 3.
public struct EchoCartographerExperienceCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "r02-g11.echo-cartographer"
    /// The snapshot schema this build writes.
    public static let schemaVersion = 3
    /// The digest's domain string (schema 3).
    public static let digestDomain = "r02-g11.echo-cartographer.v3"
    /// The action ids in declaration order.
    public static let actionIDs = ["cell.pulse", "cell.claim", "cell.mark", "play.undo", "play.redo", "level.next",
                                   "level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss",
                                   "replay.start", "replay.step", "replay.stop", "settings.sound"]
    /// The declared range of `settings.sound`: 0 off, 1 on (feature 407).
    public static let soundRange: ClosedRange<Int> = 0...1
    /// The energy of a practice play: the kernel's maximum (`EchoCartographerMode.practiceEnergy`, 60).
    public static let practiceEnergy: Int = EchoCartographerMode.practiceEnergy
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
    /// The kernel's play of that level (of its practice copy in practice mode).
    public private(set) var play: EchoCartographerPlay
    /// The player's progress (feature 405): in the digest and the snapshot.
    public private(set) var progress: EchoCartographerProgress
    /// The mode (feature 405): in the digest and the snapshot.
    public private(set) var mode: EchoCartographerMode
    /// The tutorial step (feature 405): in the snapshot, not in the digest.
    public private(set) var tutorial: EchoCartographerTutorialStep
    /// How many saved results the last restore dropped because they did not verify (feature 407); not in the digest,
    /// the snapshot or `==`.
    public private(set) var reconciliationDropped = 0
    /// The player's sound choice (feature 407, FR-R02G1107-007), set by `settings.sound`: in the snapshot (key
    /// `"sound"`) and `==`, never in the digest; off at an opening, after a reset and in a migrated save.
    public private(set) var soundOn = false
    /// The certified plan's pulse count of the current level (stars). Derived from the level number.
    public private(set) var certifiedPulses: Int
    /// The level number the seed chose; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    public let openingNumber: Int
    /// The opening state; a reset returns to it. Derived from the seed, so not in the digest or `==`.
    private let opening: Opening

    /// What a reset restores (feature 405).
    struct Opening: Sendable {
        /// The fresh play of the opening level.
        let play: EchoCartographerPlay
        /// The opening progress: the levels up to the opening level open, none won.
        let progress: EchoCartographerProgress
        /// The opening level's initial tutorial step.
        let tutorial: EchoCartographerTutorialStep
        /// The opening level's certified plan pulse count.
        let certifiedPulses: Int
    }
    /// The host quality tier (0 = level-0, the best, … 2, clamped); presentation only — not in the digest, the snapshot
    /// or `==`.
    public private(set) var qualityTier = 0

    /// A state playing `play` of level `levelNumber` with `progress`, `mode` and `tutorial`, whose reset returns to
    /// `opening` of `openingNumber`.
    init(levelNumber: Int, play: EchoCartographerPlay, progress: EchoCartographerProgress, mode: EchoCartographerMode,
         tutorial: EchoCartographerTutorialStep, certifiedPulses: Int, openingNumber: Int, opening: Opening) {
        self.levelNumber = levelNumber
        self.play = play
        self.progress = progress
        self.mode = mode
        self.tutorial = tutorial
        self.certifiedPulses = certifiedPulses
        self.openingNumber = openingNumber
        self.opening = opening
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

    /// The practice copy of `level` (feature 405): every field kept, the energy raised to ``practiceEnergy``.
    ///
    /// - Throws: the kernel's refusal of the copy (never for a certified level).
    public static func practiceLevel(of level: EchoCartographerLevel) throws(EchoCartographerError) -> EchoCartographerLevel {
        try EchoCartographerLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, chamber: level.chamber,
                                  entry: level.entry, beacons: level.beacons, tolerance: level.tolerance,
                                  energy: EchoCartographerMode.practice.energy(base: level.energy),
                                  missCost: level.missCost, tutorial: level.tutorial)
    }

    /// The level a play of `certified` in `mode` uses: the practice copy in practice mode, otherwise the certified
    /// level.
    ///
    /// - Throws: as ``practiceLevel(of:)``.
    static func playedLevel(of certified: EchoCartographerGenerated,
                            mode: EchoCartographerMode) throws(EchoCartographerError) -> EchoCartographerLevel {
        mode == .practice ? try practiceLevel(of: certified.level) : certified.level
    }

    /// The opening state of manifest number `number`: a play begun and past the kernel's tutorial stage, ready to
    /// accept actions; campaign mode, the levels up to `number` open, none won, the tutorial at its initial step.
    ///
    /// - Throws: as ``level(number:)``.
    public static func opening(number: Int) throws(EchoCartographerError) -> EchoCartographerExperienceCore {
        let certified: EchoCartographerGenerated = try generated(number: number)
        let play: EchoCartographerPlay = try freshPlay(of: certified.level)
        var progress: EchoCartographerProgress = EchoCartographerProgress()
        progress.open(through: number)
        let tutorial: EchoCartographerTutorialStep = EchoCartographerTutorialStep.initial(level: number)
        let pulses: Int = certified.plan.pulses.count
        let opening: Opening = Opening(play: play, progress: progress, tutorial: tutorial, certifiedPulses: pulses)
        return EchoCartographerExperienceCore(levelNumber: number, play: play, progress: progress, mode: .campaign,
                                              tutorial: tutorial, certifiedPulses: pulses, openingNumber: number,
                                              opening: opening)
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

    /// Equal states: the level number, the play, the progress, the mode and the tutorial step (not the quality tier or
    /// the opening level).
    public static func == (lhs: EchoCartographerExperienceCore, rhs: EchoCartographerExperienceCore) -> Bool {
        lhs.levelNumber == rhs.levelNumber && lhs.play == rhs.play && lhs.progress == rhs.progress
            && lhs.mode == rhs.mode && lhs.tutorial == rhs.tutorial && lhs.soundOn == rhs.soundOn
    }

    // MARK: Contract

    /// Schema 3 with the steps 1 → 2 (``migratedToSchemaTwo(_:)``) and 2 → 3 (``migratedToSchemaThree(_:)``); a
    /// payload that does not decode is refused.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: schemaVersion, steps: [1: { payload in try migratedToSchemaTwo(payload) },
                                                             2: { payload in try migratedToSchemaThree(payload) }])
    }

    /// The schema-3 object of a schema-2 object (feature 407): every won result gains an empty `trace` and `verified`
    /// false, and the sound choice is off.
    ///
    /// - Throws: ``EchoCartographerRestoreRefusal/damaged`` when `object` has no progress with a solved list.
    public static func migratedToSchemaThree(_ object: [String: Any]) throws -> [String: Any] {
        guard var progress = object["progress"] as? [String: Any], let solved = progress["solved"] as? [Any] else {
            throw EchoCartographerRestoreRefusal.damaged
        }
        var entries: [Any] = []
        for entry in solved {
            guard var result = entry as? [String: Any] else {
                entries.append(entry)
                continue
            }
            result["trace"] = [Any]()
            result["verified"] = false
            entries.append(result)
        }
        progress["solved"] = entries
        var migrated: [String: Any] = object
        migrated["progress"] = progress
        migrated["sound"] = false
        return migrated
    }

    /// The schema-2 object of a schema-1 object `{"level", "records"}` (feature 405): no won levels with the levels up
    /// to the saved level open, campaign mode, no tutorial key (restore starts the tutorial at its initial step).
    ///
    /// - Throws: ``EchoCartographerRestoreRefusal/damaged`` when `object` is not a schema-1 object.
    public static func migratedToSchemaTwo(_ object: [String: Any]) throws -> [String: Any] {
        guard let level = object["level"] as? Int, object["records"] is [Any] else {
            throw EchoCartographerRestoreRefusal.damaged
        }
        var progress: EchoCartographerProgress = EchoCartographerProgress()
        progress.open(through: level)
        var migrated: [String: Any] = object
        migrated["progress"] = try JSONSerialization.jsonObject(with: try payloadEncoder().encode(progress))
        migrated["mode"] = try JSONSerialization.jsonObject(
            with: try payloadEncoder().encode(EchoCartographerMode.campaign))
        return migrated
    }

    /// The encoder of payloads and digested values: sorted keys, unescaped slashes.
    static func payloadEncoder() -> JSONEncoder {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// The declared controls, built once: the ranges of the file header as `Double` ranges.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "cell.pulse", ranges: [declared(coordinateRange), declared(coordinateRange)]),
        ExperienceControl(id: "cell.claim", ranges: [declared(coordinateRange), declared(coordinateRange)]),
        ExperienceControl(id: "cell.mark", ranges: [declared(coordinateRange), declared(coordinateRange)]),
        ExperienceControl(id: "play.undo"),
        ExperienceControl(id: "play.redo"),
        ExperienceControl(id: "level.next"),
        ExperienceControl(id: "level.select", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "mode.daily", ranges: [declared(EchoCartographerProgress.dailyYears), 1...12, 1...31]),
        ExperienceControl(id: "mode.practice"),
        ExperienceControl(id: "mode.campaign"),
        ExperienceControl(id: "tutorial.dismiss"),
        ExperienceControl(id: "replay.start", ranges: [declared(levelNumbers)]),
        ExperienceControl(id: "replay.step"),
        ExperienceControl(id: "replay.stop"),
        ExperienceControl(id: "settings.sound", ranges: [declared(soundRange)]),
    ]

    /// `range` as the `Double` range a control declares.
    private static func declared(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    /// The fifteen controls with their declared ranges (see the file header); `play.undo`, `play.redo`, `level.next`,
    /// `mode.practice`, `mode.campaign`, `tutorial.dismiss`, `replay.step` and `replay.stop` take no values.
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
        if case .replay = mode, !Self.replayControls.contains(action.control) {
            return .rejected(.rule(code: EchoCartographerExperienceRule.replay))
        }
        do throws(EchoCartographerError) {
            switch action.control {
            case "cell.pulse":
                let located: Int = play.located.count
                try play.apply(.pulse(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterPulse: true, locatedBefore: located)
            case "cell.claim":
                let located: Int = play.located.count
                try play.apply(.claim(values[0], values[1]), expecting: play.fingerprint)
                advanceTutorial(afterPulse: false, locatedBefore: located)
                recordIfWon()
            case "cell.mark":
                try play.apply(.mark(values[0], values[1]), expecting: play.fingerprint)
            case "play.undo":
                try play.undo()
            case "play.redo":
                try play.redo()
                advanceTutorial(afterPulse: false, locatedBefore: nil)
                recordIfWon()
            case "level.next":
                guard let next = progress.nextOpen(after: levelNumber) else {
                    return .rejected(.rule(code: EchoCartographerExperienceRule.locked))
                }
                try open(number: next, mode: .campaign)
            case "level.select":
                guard progress.isOpen(values[0]) else {
                    return .rejected(.rule(code: EchoCartographerExperienceRule.locked))
                }
                try open(number: values[0], mode: .campaign)
            case "mode.daily":
                guard let daily = EchoCartographerProgress.dailyLevel(year: values[0], month: values[1],
                                                                      day: values[2]) else {
                    return .rejected(.rule(code: EchoCartographerExperienceRule.date))
                }
                try open(number: daily, mode: .daily(level: daily))
            case "mode.practice":
                try open(number: levelNumber, mode: .practice)
            case "mode.campaign":
                try open(number: progress.isOpen(levelNumber) ? levelNumber : progress.frontier, mode: .campaign)
            case "replay.start":
                guard let result = progress.solved[values[0]], result.verified, !result.trace.isEmpty else {
                    return .rejected(.rule(code: EchoCartographerExperienceRule.noReplay))
                }
                try open(number: values[0], mode: .replay(level: values[0]))
                tutorial = .done
            case "replay.step":
                guard case .replay(let level) = mode, let result = progress.solved[level], result.verified else {
                    return .rejected(.rule(code: EchoCartographerExperienceRule.noReplay))
                }
                // Replay never undoes, so each trace action made exactly one record.
                let index: Int = play.records.count
                guard play.stage == .playing, index < result.trace.count else {
                    return .rejected(.rule(code: EchoCartographerExperienceRule.replayEnd))
                }
                try play.apply(result.trace[index], expecting: play.fingerprint)
            case "replay.stop":
                guard case .replay(let level) = mode else {
                    return .rejected(.rule(code: EchoCartographerExperienceRule.noReplay))
                }
                try open(number: progress.isOpen(level) ? level : progress.frontier, mode: .campaign)
            case "settings.sound":
                soundOn = values[0] == 1
            default:   // tutorial.dismiss
                tutorial = tutorial.dismissed()
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

    /// Advances the tutorial step after an accepted pulse, claim or redo
    /// (`EchoCartographerTutorialStep.advanced(afterPulse:located:ended:)`): a new pulse moves step pulse on, a newly
    /// located beacon moves step narrow on (`locatedBefore` is the located count before a new action; nil for a redo),
    /// the end of the level ends it; an undo never moves the step and a redo only ends it when it ends the level.
    private mutating func advanceTutorial(afterPulse: Bool, locatedBefore: Int?) {
        guard tutorial != .done else { return }
        let ended: Bool = play.stage == .won || play.stage == .failed
        var located: Bool = false
        if let before = locatedBefore { located = play.located.count > before }
        tutorial = tutorial.advanced(afterPulse: afterPulse, located: located, ended: ended)
    }

    /// A fresh play of manifest number `number` in `mode` (the practice copy in practice mode) with the level's initial
    /// tutorial step; the records of the level left are dropped. Changes nothing when the kernel refuses.
    private mutating func open(number: Int, mode: EchoCartographerMode) throws(EchoCartographerError) {
        let certified: EchoCartographerGenerated = try Self.generated(number: number)
        let fresh: EchoCartographerPlay = try Self.freshPlay(of: try Self.playedLevel(of: certified, mode: mode))
        levelNumber = number
        play = fresh
        self.mode = mode
        certifiedPulses = certified.plan.pulses.count
        tutorial = EchoCartographerTutorialStep.initial(level: number)
    }

    /// After an accepted action that won the play: records the energy spent against the certified plan's pulse count
    /// in the current mode (campaign opens the next level; daily does not; practice records nothing). A won play is
    /// final, so a win is recorded once.
    private mutating func recordIfWon() {
        guard play.stage == .won else { return }
        if case .replay = mode { return }
        progress.record(level: levelNumber, energySpent: EchoCartographerProgress.energySpent(play),
                        certified: certifiedPulses, mode: mode, trace: winningTrace)
    }

    /// The controls accepted during replay (feature 407); the panel's cursor and the camera are presentation only and
    /// send no action.
    static let replayControls: Set<String> = ["replay.start", "replay.step", "replay.stop", "tutorial.dismiss",
                                              "settings.sound"]

    /// The winning trace of the current play (feature 407): its effective actions in order
    /// (``EchoCartographerReconciliation/netTrace(_:)``), never an undo or a redo.
    var winningTrace: [EchoCartographerAction] { EchoCartographerReconciliation.netTrace(play.records) }

    /// Back to the opening state the seed chose (progress included); the quality tier, which is not state, is kept.
    public mutating func reset() {
        levelNumber = openingNumber
        play = opening.play
        progress = opening.progress
        mode = .campaign
        tutorial = opening.tutorial
        certifiedPulses = opening.certifiedPulses
        soundOn = false
    }

    /// `won` or `failed` while the play is in that stage; nil otherwise.
    public var outcome: ExperienceOutcome? {
        switch play.stage {
        case .won: ExperienceOutcome(code: Self.wonCode)
        case .failed: ExperienceOutcome(code: Self.failedCode)
        default: nil
        }
    }

    /// "r02-g11.echo-cartographer.v3", then the level number, the play's fingerprint (level, knowledge, markers,
    /// located beacons, energy, stage, failure), the progress and the mode (their sorted JSON); never the tutorial step.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(Self.digestDomain)
        builder.add(levelNumber)
        // The play's fingerprint and not its record history, so undo restores the earlier digest exactly.
        builder.add(play.fingerprint)
        let encoder: JSONEncoder = Self.payloadEncoder()
        builder.add(String(decoding: (try? encoder.encode(progress)) ?? Data(), as: UTF8.self))
        builder.add(String(decoding: (try? encoder.encode(mode)) ?? Data(), as: UTF8.self))
    }

    // MARK: Snapshot

    /// The payload's JSON form (schema 3); `tutorial` is absent in a migrated schema-1 payload and `sound` (absent
    /// means off) is written by every schema-3 payload and by the 2 → 3 migration.
    private struct Payload: Codable {
        /// The level number.
        var level: Int
        /// The mode.
        var mode: EchoCartographerMode
        /// The progress.
        var progress: EchoCartographerProgress
        /// The play's records.
        var records: [EchoCartographerRecord]
        /// The sound choice; nil (off) in a payload written before schema 3.
        var sound: Bool?
        /// The tutorial step; nil in a migrated schema-1 payload.
        var tutorial: EchoCartographerTutorialStep?
    }

    /// The JSON object `{"level", "mode", "progress", "records", "sound", "tutorial"}` with sorted keys and unescaped
    /// slashes.
    public func snapshotPayload() throws -> Data {
        try Self.payloadEncoder().encode(Payload(level: levelNumber, mode: mode, progress: progress,
                                                 records: play.records, sound: soundOn, tutorial: tutorial))
    }

    /// The core of `payload` (schema 3): the records replayed on a fresh play of the saved level (the practice copy in
    /// practice mode) with the reconciled progress (``EchoCartographerReconciliation/reconcile(_:)``, the frontier as
    /// saved, the number dropped in ``reconciliationDropped``), the saved mode, tutorial step (the initial step when
    /// absent) and sound choice (off when absent); a saved replay whose result did not survive the check returns to
    /// campaign at that level (the frontier when it is not open). A reset returns to the opening state `seed` chooses.
    ///
    /// - Throws: ``EchoCartographerRestoreRefusal`` for a damaged payload (invalid progress, an unknown mode, or a daily
    ///   or replay mode naming another level among them), a level number outside 1 … 100 or a level or trace the kernel
    ///   refuses.
    public static func restore(payload: Data, seed: UInt64) throws -> EchoCartographerExperienceCore {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            throw EchoCartographerRestoreRefusal.damaged
        }
        guard levelNumbers.contains(decoded.level) else {
            throw EchoCartographerRestoreRefusal.levelNumber(decoded.level)
        }
        if case .daily(let daily) = decoded.mode, daily != decoded.level {
            throw EchoCartographerRestoreRefusal.damaged
        }
        if case .replay(let replayed) = decoded.mode, replayed != decoded.level {
            throw EchoCartographerRestoreRefusal.damaged
        }
        do throws(EchoCartographerError) {
            let certified: EchoCartographerGenerated = try generated(number: decoded.level)
            let play: EchoCartographerPlay = try EchoCartographerPlay.replay(
                level: try playedLevel(of: certified, mode: decoded.mode), records: decoded.records)
            let tutorial: EchoCartographerTutorialStep = decoded.tutorial
                ?? EchoCartographerTutorialStep.initial(level: decoded.level)
            let openingCore: EchoCartographerExperienceCore = try opening(number: levelNumber(forSeed: seed))
            // Feature 407: every saved result is checked by replaying its trace; the frontier stays as saved.
            let reconciled = EchoCartographerReconciliation.reconcile(decoded.progress)
            var core: EchoCartographerExperienceCore = EchoCartographerExperienceCore(
                levelNumber: decoded.level, play: play, progress: reconciled.progress, mode: decoded.mode,
                tutorial: tutorial, certifiedPulses: certified.plan.pulses.count,
                openingNumber: openingCore.openingNumber, opening: openingCore.opening)
            core.reconciliationDropped = reconciled.dropped
            core.soundOn = decoded.sound ?? false
            // A replay whose result did not survive the check returns to campaign at that level (or the frontier).
            if case .replay(let level) = decoded.mode, reconciled.progress.solved[level]?.verified != true {
                try core.open(number: core.progress.isOpen(level) ? level : core.progress.frontier, mode: .campaign)
            }
            return core
        } catch {
            throw EchoCartographerRestoreRefusal.kernel(error)
        }
    }
}
