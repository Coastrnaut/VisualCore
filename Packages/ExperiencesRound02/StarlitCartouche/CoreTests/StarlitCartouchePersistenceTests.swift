// StarlitCartouchePersistenceTests — feature 457 (R02-G16-07) T-R02G1607-004 (FR-R02G1607-001 … 007; clarifications
// Q1–Q5). Host checks of Starlit Cartouche's persistence through the adapter core:
//   - 500 seeded reachable states (random walks from seeded openings of route.fly legs among the corridors of the
//     ship's star (a leg may be refused, or accepted and fail the level), play.undo, play.redo, level.next,
//     level.select of open levels, mode.daily, mode.practice, mode.campaign, tutorial.dismiss, settings.sound on and
//     off, certified wins played from the certified plan with and without detours, and replay start, step and stop)
//     round-trip through `snapshotPayload()` and `restore(payload:seed:)` with equal states, digests, progress, mode,
//     tutorial step and sound choice, identical payload bytes and nothing dropped; toggling the sound choice changes
//     the state and the payload but never the digest;
//   - 100 seeded states as schema-1 payloads `{level, records}` and 100 as schema-2 payloads (the schema-3 payload
//     without `sound` and with `trace` and `verified` removed from each solved entry) migrate through
//     `Core.migrations.migrate(_:from:)` (the same object as `migratedToSchemaTwo` / `migratedToSchemaThree`, and the
//     engine's chain for an envelope of that schema) and restore with the level, the records and the progress kept
//     (schema 1: feature 455's rule — no won levels, levels up to the restored one open, campaign, the first tutorial
//     step; schema 2: the frontier, the won levels, actions spent and stars kept, every result unverified with an
//     empty trace), the sound off;
//   - 200 seeded saves with won levels: honest traced results (and honest untraced ones) survive restore with
//     `reconciliationDropped` 0 for them; edited ones (stars changed, actions spent below the legs the trace spends, a
//     trace leg changed into a leg to the ship's own star (never legal), an extra leg after the winning one (a won play
//     takes no leg)) are dropped and counted, the frontier unchanged;
//   - FR-R02G1607-005: the same save restores twice to equal digests, states and payloads; the daily level depends
//     only on the date given (the same date twice agrees, with the count made here with Foundation's UTC calendar, and
//     from every state the adapter opens the same daily level), and 100 consecutive days visit all 100 levels.
// Synthetic data, explicit types, plain loops, no sleep, no clock. The states come from a SplitMix64 generator seeded
// with 2_457 (one stream per group); edited saves are made by editing the payload's JSON, as a tampered file would be.
// Certifying a level takes a few milliseconds and is cached per process, so the walks may visit all 100 levels; the
// loops are split into parametrized groups of 25 or 50 so each case stays short.
// Modelled on feature 447's VoxelOrigamiPersistenceTests.
import Foundation
import Testing
@testable import StarlitCartoucheCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// A small deterministic integer generator (SplitMix64), so the seeded states depend on this file alone.
struct StarlitCartouchePersistenceRandom {
    /// The generator's state.
    private var state: UInt64

    /// A generator seeded with `seed`.
    init(seed: UInt64) {
        state = seed
    }

    /// The next 64-bit value.
    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0 ..< `bound` (bound > 0).
    mutating func below(_ bound: Int) -> Int {
        Int(next() % UInt64(bound))
    }

    /// A value in `range`.
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + below(range.count)
    }
}

@Suite struct StarlitCartouchePersistenceTests {
    typealias Core = StarlitCartoucheExperienceCore
    typealias Progress = StarlitCartoucheProgress
    typealias Random = StarlitCartouchePersistenceRandom

    /// The seed of every generator in this file.
    static let baseSeed: UInt64 = 2_457

    /// The days from 1970-01-01 to 2026-01-01 (20 454), the daily epoch.
    static let epochDays: Int = 20_454

    /// The daily level's multiplier (37).
    static let dailyMultiplier: Int = 37

    /// The kinds of edit made to a saved result.
    enum Edit: CaseIterable {
        case stars
        case actionsBelowTrace
        case legChanged
        case extraLeg
    }

    // MARK: Helpers

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// An action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func act(_ kernel: StarlitCartoucheAction) -> ExperienceAction {
        switch kernel {
        case let .leg(star, wait):
            Self.act("route.fly", [Double(star), Double(wait)])
        }
    }

    /// The certified plan legs of level `number`.
    static func plan(_ number: Int) throws -> [StarlitCartoucheAction] {
        try Core.generated(number: number).plan.legs
    }

    /// The proleptic Gregorian UTC calendar of Foundation (independent of the code under test).
    static func utcCalendar() throws -> Calendar {
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        return calendar
    }

    /// The date `offset` days after 2026-01-01 as `[year, month, day]`, counted with Foundation's UTC calendar.
    static func date(offset: Int, _ calendar: Calendar) throws -> [Int] {
        let date: Date = Date(timeIntervalSince1970: Double(Self.epochDays + offset) * 86_400)
        let parts: DateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        return [try #require(parts.year), try #require(parts.month), try #require(parts.day)]
    }

    /// The days from 1970-01-01 to a date, counted with Foundation's UTC calendar.
    static func foundationDays(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) throws -> Int {
        let date: Date = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        return Int((date.timeIntervalSince1970 / 86_400).rounded())
    }

    /// The daily level of a date by the rule, counted here: (days since 2026-01-01 × 37) mod 100 + 1.
    static func expectedDaily(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) throws -> Int {
        let days: Int = try Self.foundationDays(year, month, day, calendar) - Self.epochDays
        return ((days * Self.dailyMultiplier) % 100 + 100) % 100 + 1
    }

    /// For every level 1 … 100 (index level − 1) a date of 2026 whose daily level it is, as `mode.daily` values:
    /// 37 × 73 ≡ 1 (mod 100), so level `l` is the daily level of day ((l − 1) × 73) mod 100 after 2026-01-01.
    static func dailyDates() throws -> [[Double]] {
        let calendar: Calendar = try Self.utcCalendar()
        var dates: [[Double]] = []
        for level in 1...100 {
            let parts: [Int] = try Self.date(offset: ((level - 1) * 73) % 100, calendar)
            dates.append([Double(parts[0]), Double(parts[1]), Double(parts[2])])
        }
        return dates
    }

    /// The payload's JSON object.
    static func object(_ payload: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
    }

    /// The JSON data of `object`.
    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The JSON value of a kernel action, as the payload encodes it.
    static func json(_ kernel: StarlitCartoucheAction) throws -> Any {
        try JSONSerialization.jsonObject(with: try JSONEncoder().encode(kernel), options: [.fragmentsAllowed])
    }

    /// The kernel actions of a trace's JSON value.
    static func actions(_ trace: [Any]) throws -> [StarlitCartoucheAction] {
        try JSONDecoder().decode([StarlitCartoucheAction].self, from: try JSONSerialization.data(withJSONObject: trace))
    }

    /// A fresh campaign play of certified level `level` with `trace` applied (the kernel refusing nothing).
    static func played(level: Int, trace: [StarlitCartoucheAction]) throws -> StarlitCartouchePlay {
        let certified: StarlitCartoucheGenerated = try Core.generated(number: level)
        var play: StarlitCartouchePlay = try Core.freshPlay(of: certified.level)
        for action in trace {
            try play.apply(action, expecting: play.fingerprint)
        }
        return play
    }

    /// The stars joined to the ship's star by a corridor of the current level.
    static func neighbours(_ core: Core) -> [Int] {
        var stars: [Int] = []
        for corridor in core.play.level.corridors {
            if corridor.a == core.play.star { stars.append(corridor.b) }
            if corridor.b == core.play.star { stars.append(corridor.a) }
        }
        return stars
    }

    /// A random leg along a corridor of the ship's star with a random wait; up to four tries until one is accepted (a
    /// refused leg changes nothing; an accepted one may fail the level).
    static func randomLeg(_ core: inout Core, _ random: inout Random) {
        let stars: [Int] = Self.neighbours(core)
        guard !stars.isEmpty else { return }
        for _ in 0..<4 {
            let star: Int = stars[random.below(stars.count)]
            let wait: Int = random.int(Core.waitRange)
            if core.apply(Self.act(StarlitCartoucheAction.leg(star, wait))) == .accepted { return }
        }
    }

    /// One random kernel action on the current play: a leg (60 %), undo (22 %) or redo (18 %).
    static func randomKernel(_ core: inout Core, _ random: inout Random) {
        let roll: Int = random.below(100)
        if roll < 60 {
            Self.randomLeg(&core, &random)
        } else if roll < 82 {
            _ = core.apply(Self.act("play.undo"))
        } else {
            _ = core.apply(Self.act("play.redo"))
        }
    }

    /// Re-opens the current level fresh in its mode (campaign, practice or daily), then plays its certified plan,
    /// optionally after a detour (`1`: the first plan leg and its undo, one more action spent; `2`: the first plan leg,
    /// its undo and its redo, the rest of the plan after it). Certified plans have at least two legs, so the first leg
    /// never wins alone; the effective legs are always the plan. Does nothing in replay mode.
    static func win(_ core: inout Core, detour: Int, dates: [[Double]]) throws {
        switch core.mode {
        case .replay:
            return
        case .practice:
            #expect(core.apply(Self.act("mode.practice")) == .accepted)
        case .campaign:
            #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        case .daily(let level):
            #expect(core.apply(Self.act("mode.daily", dates[level - 1])) == .accepted)
        }
        let legs: [StarlitCartoucheAction] = try Self.plan(core.levelNumber)
        try #require(legs.count >= 2)
        var rest: [StarlitCartoucheAction] = legs
        switch detour {
        case 1:
            #expect(core.apply(Self.act(legs[0])) == .accepted)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
        case 2:
            #expect(core.apply(Self.act(legs[0])) == .accepted)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
            #expect(core.apply(Self.act("play.redo")) == .accepted)
            rest.removeFirst()
        default:
            break
        }
        for kernel in rest {
            let result: ActionResult = core.apply(Self.act(kernel))
            #expect(result == .accepted, "level \(core.levelNumber) \(kernel)")
        }
        #expect(core.play.stage == .won, "level \(core.levelNumber)")
    }

    /// The won levels of `core` whose results are verified.
    static func verifiedLevels(_ core: Core) -> [Int] {
        var levels: [Int] = []
        for level in core.progress.solved.keys.sorted() where core.progress.solved[level]?.verified == true {
            levels.append(level)
        }
        return levels
    }

    /// One random action on `core`; level and mode changes and wins are rarer than kernel actions.
    static func randomStep(_ core: inout Core, _ random: inout Random, dates: [[Double]]) throws {
        let roll: Int = random.below(100)
        if case .replay = core.mode {
            if roll < 65 {
                _ = core.apply(Self.act("replay.step"))
            } else if roll < 82 {
                _ = core.apply(Self.act("replay.stop"))
            } else if roll < 90 {
                _ = core.apply(Self.act("tutorial.dismiss"))
            } else {
                _ = core.apply(Self.act("settings.sound", [Double(random.below(2))]))
            }
            return
        }
        if roll < 46 {
            Self.randomKernel(&core, &random)
        } else if roll < 49 {
            _ = core.apply(Self.act("level.next"))
        } else if roll < 53 {
            _ = core.apply(Self.act("level.select", [Double(random.int(1...core.progress.frontier))]))
        } else if roll < 56 {
            _ = core.apply(Self.act("mode.practice"))
        } else if roll < 59 {
            _ = core.apply(Self.act("mode.campaign"))
        } else if roll < 62 {
            _ = core.apply(Self.act("mode.daily", dates[random.below(dates.count)]))
        } else if roll < 65 {
            _ = core.apply(Self.act("tutorial.dismiss"))
        } else if roll < 72 {
            _ = core.apply(Self.act("settings.sound", [Double(random.below(2))]))
        } else if roll < 88 {
            try Self.win(&core, detour: random.below(3), dates: dates)
        } else {
            let verified: [Int] = Self.verifiedLevels(core)
            let level: Int = verified.isEmpty ? random.int(1...100) : verified[random.below(verified.count)]
            _ = core.apply(Self.act("replay.start", [Double(level)]))
        }
    }

    /// A seeded reachable state: prepared with a random seed (any level), then 0 … 14 random actions.
    static func reachable(_ random: inout Random, dates: [[Double]]) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = UInt64(random.below(100))
        var core: Core = try await Core.prepare(seed: seed)
        let count: Int = random.int(0...14)
        for _ in 0..<count { try Self.randomStep(&core, &random, dates: dates) }
        return (core, seed)
    }

    /// A seeded state with 1 … 3 certified wins (some daily, some practised first), moved on with level.next after
    /// each, and the sound on or off.
    static func winner(_ random: inout Random, dates: [[Double]]) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = UInt64(random.below(100))
        var core: Core = try await Core.prepare(seed: seed)
        let wins: Int = random.int(1...3)
        for _ in 0..<wins {
            if random.below(4) == 0 {
                _ = core.apply(Self.act("mode.daily", dates[random.below(dates.count)]))
            } else if core.mode != .campaign {
                _ = core.apply(Self.act("mode.campaign"))
            }
            try Self.win(&core, detour: random.below(3), dates: dates)
            _ = core.apply(Self.act("level.next"))
        }
        _ = core.apply(Self.act("settings.sound", [Double(random.below(2))]))
        return (core, seed)
    }

    // MARK: 500 seeded reachable states round-trip

    /// Round-trips `count` seeded states of generator stream `stream`; returns how many verified results, replay,
    /// daily, practice and sound-on states they carried.
    static func roundTrips(stream: UInt64, count: Int) async throws
        -> (verified: Int, replays: Int, dailies: Int, practices: Int, sounds: Int) {
        let dates: [[Double]] = try Self.dailyDates()
        var random: Random = Random(seed: Self.baseSeed &+ stream)
        var verified: Int = 0
        var replays: Int = 0
        var dailies: Int = 0
        var practices: Int = 0
        var sounds: Int = 0
        for index in 0..<count {
            let state: (core: Core, seed: UInt64) = try await Self.reachable(&random, dates: dates)
            let payload: Data = try state.core.snapshotPayload()
            let restored: Core = try Core.restore(payload: payload, seed: state.seed)
            let digest: StateDigest = try Self.digest(state.core)
            let restoredDigest: StateDigest = try Self.digest(restored)
            #expect(restored == state.core, "stream \(stream) state \(index)")
            #expect(restoredDigest == digest, "stream \(stream) state \(index)")
            #expect(restored.progress == state.core.progress && restored.mode == state.core.mode)
            #expect(restored.levelNumber == state.core.levelNumber, "stream \(stream) state \(index)")
            #expect(restored.tutorial == state.core.tutorial, "stream \(stream) state \(index)")
            #expect(restored.soundOn == state.core.soundOn, "stream \(stream) state \(index)")
            #expect(restored.play.records == state.core.play.records, "stream \(stream) state \(index)")
            #expect(restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
            let again: Data = try restored.snapshotPayload()
            #expect(again == payload, "stream \(stream) state \(index)")
            // The sound choice is state but never digested: toggling it changes `==` and the payload, not the digest.
            var toggled: Core = state.core
            let flipped: Double = state.core.soundOn ? 0 : 1
            let toggleResult: ActionResult = toggled.apply(Self.act("settings.sound", [flipped]))
            #expect(toggleResult == .accepted, "stream \(stream) state \(index)")
            #expect(toggled.soundOn != state.core.soundOn && toggled != state.core, "stream \(stream) \(index)")
            let toggledDigest: StateDigest = try Self.digest(toggled)
            #expect(toggledDigest == digest, "stream \(stream) state \(index)")
            let toggledPayload: Data = try toggled.snapshotPayload()
            #expect(toggledPayload != payload, "stream \(stream) state \(index)")
            let toggledRestored: Core = try Core.restore(payload: toggledPayload, seed: state.seed)
            #expect(toggledRestored == toggled && toggledRestored.soundOn == toggled.soundOn)
            let toggledRestoredDigest: StateDigest = try Self.digest(toggledRestored)
            #expect(toggledRestoredDigest == digest, "stream \(stream) state \(index)")
            for result in state.core.progress.solved.values where result.verified { verified += 1 }
            if state.core.soundOn { sounds += 1 }
            switch state.core.mode {
            case .replay: replays += 1
            case .daily: dailies += 1
            case .practice: practices += 1
            case .campaign: break
            }
        }
        return (verified, replays, dailies, practices, sounds)
    }

    /// States 50 × group + 1 … 50 × group + 50 of the 500 (ten groups, one generator stream each).
    @Test(arguments: Array(0..<10))
    func fiveHundredSeededStatesRoundTrip(group: Int) async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int, sounds: Int) =
            try await Self.roundTrips(stream: UInt64(1 + group), count: 50)
        // Every state also round-trips with its sound choice flipped, so both choices are checked in every state.
        #expect(totals.verified > 0 && totals.sounds < 50, "group \(group)")
        #expect(totals.dailies + totals.practices + totals.replays > 0, "group \(group)")
    }

    // MARK: Schema 1 and schema 2 payloads migrate

    /// An engine prepared with seed 0 and active, ready to restore envelopes.
    static func activeEngine() async throws -> ExperienceEngine<Core> {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine: ExperienceEngine<Core> = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        return engine
    }

    /// Restores `object` as an envelope of schema `version` (seed `seed`, digest `digest`) through `engine`; returns
    /// the engine's core.
    static func engineRestore(_ engine: inout ExperienceEngine<Core>, _ object: [String: Any], version: Int,
                              seed: UInt64, digest: StateDigest) throws -> Core {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        let envelope: ExperienceSnapshot = try ExperienceSnapshot(experience: id, schemaVersion: version, seed: seed,
                                                                  stepIndex: 0, digest: digest,
                                                                  payload: try Self.data(object))
        try engine.restore(envelope)
        return try #require(engine.core)
    }

    /// The schema version this build writes is 3 and its chain carries the steps 1 → 2 and 2 → 3.
    @Test func theSnapshotIsSchemaThree() throws {
        #expect(Core.schemaVersion == 3)
        #expect(Core.migrations.currentVersion == 3)
    }

    /// Migrates `count` seeded schema-1 payloads `{level, records}` of generator stream `stream` (campaign plays of
    /// random legs, undo and redo, some with the sound on before saving).
    static func schemaOne(stream: UInt64, count: Int) async throws {
        var random: Random = Random(seed: Self.baseSeed &+ stream)
        var engine: ExperienceEngine<Core> = try await Self.activeEngine()
        for index in 0..<count {
            let seed: UInt64 = UInt64(random.below(100))
            var core: Core = try await Core.prepare(seed: seed)
            let steps: Int = random.int(0...10)
            for _ in 0..<steps { Self.randomKernel(&core, &random) }
            if random.below(2) == 0 { _ = core.apply(Self.act("settings.sound", [1])) }
            let full: [String: Any] = try Self.object(try core.snapshotPayload())
            var old: [String: Any] = [:]
            old["level"] = full["level"]
            old["records"] = full["records"]
            let chained: [String: Any] = try Core.migrations.migrate(old, from: 1)
            let stepwise: [String: Any] = try Core.migratedToSchemaThree(try Core.migratedToSchemaTwo(old))
            let chainedData: Data = try Self.data(chained)
            let stepwiseData: Data = try Self.data(stepwise)
            #expect(chainedData == stepwiseData, "stream \(stream) state \(index)")
            let restored: Core = try Core.restore(payload: chainedData, seed: seed)
            var expected: Progress = Progress()
            expected.open(through: core.levelNumber)
            let initialStep: StarlitCartoucheTutorialStep =
                StarlitCartoucheTutorialStep.initial(level: core.levelNumber)
            #expect(restored.levelNumber == core.levelNumber, "stream \(stream) state \(index)")
            #expect(restored.play.records == core.play.records && restored.play == core.play)
            #expect(restored.mode == .campaign && restored.progress == expected, "stream \(stream) state \(index)")
            #expect(restored.tutorial == initialStep, "stream \(stream) state \(index)")
            #expect(!restored.soundOn && restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
            if core.progress.solved.isEmpty {
                // Without a win the schema-1 state's progress is exactly what migration rebuilds.
                let restoredDigest: StateDigest = try Self.digest(restored)
                let coreDigest: StateDigest = try Self.digest(core)
                #expect(restored.progress == core.progress, "stream \(stream) state \(index)")
                #expect(restoredDigest == coreDigest, "stream \(stream) state \(index)")
            }
            // The engine restores a schema-1 envelope alike.
            let restoredDigest: StateDigest = try Self.digest(restored)
            let viaEngine: Core = try Self.engineRestore(&engine, old, version: 1, seed: seed, digest: restoredDigest)
            let engineDigest: StateDigest = try Self.digest(viaEngine)
            #expect(viaEngine == restored && !viaEngine.soundOn, "stream \(stream) state \(index)")
            #expect(engineDigest == restoredDigest, "stream \(stream) state \(index)")
        }
    }

    /// Schema-1 payloads 25 × group + 1 … 25 × group + 25 of the 100.
    @Test(arguments: Array(0..<4))
    func schemaOnePayloadsMigrate(group: Int) async throws {
        try await Self.schemaOne(stream: UInt64(11 + group), count: 25)
    }

    /// Migrates `count` seeded schema-2 payloads of generator stream `stream` (states with won levels, the sound on or
    /// off before saving); returns how many results were carried over.
    static func schemaTwo(stream: UInt64, count: Int) async throws -> Int {
        let dates: [[Double]] = try Self.dailyDates()
        var random: Random = Random(seed: Self.baseSeed &+ stream)
        var engine: ExperienceEngine<Core> = try await Self.activeEngine()
        var results: Int = 0
        for index in 0..<count {
            var state: (core: Core, seed: UInt64) = try await Self.winner(&random, dates: dates)
            let steps: Int = random.int(0...4)
            for _ in 0..<steps { try Self.randomStep(&state.core, &random, dates: dates) }
            let core: Core = state.core
            #expect(!core.progress.solved.isEmpty, "stream \(stream) state \(index)")
            var object: [String: Any] = try Self.object(try core.snapshotPayload())
            object["sound"] = nil
            var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
            let solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
            var stripped: [[String: Any]] = []
            for var entry in solved {
                entry["trace"] = nil
                entry["verified"] = nil
                stripped.append(entry)
            }
            progress["solved"] = stripped
            object["progress"] = progress
            let chained: [String: Any] = try Core.migrations.migrate(object, from: 2)
            let stepwise: [String: Any] = try Core.migratedToSchemaThree(object)
            let chainedData: Data = try Self.data(chained)
            let stepwiseData: Data = try Self.data(stepwise)
            #expect(chainedData == stepwiseData, "stream \(stream) state \(index)")
            #expect((chained["sound"] as? Bool) == false, "stream \(stream) state \(index)")
            let restored: Core = try Core.restore(payload: chainedData, seed: state.seed)
            let restoredLevels: [Int] = restored.progress.solved.keys.sorted()
            let savedLevels: [Int] = core.progress.solved.keys.sorted()
            #expect(restored.progress.frontier == core.progress.frontier, "stream \(stream) state \(index)")
            #expect(restoredLevels == savedLevels, "stream \(stream) state \(index)")
            for (level, result) in core.progress.solved {
                let kept: Progress.Result = try #require(restored.progress.solved[level])
                #expect(kept.actionsSpent == result.actionsSpent && kept.stars == result.stars, "level \(level)")
                #expect(!kept.verified && kept.trace.isEmpty, "level \(level)")
                results += 1
            }
            #expect(!restored.soundOn && restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
            if case .replay(let level) = core.mode {
                // The replayed result is unverified now, so restore returns to campaign at that level (the frontier
                // when it is not open: a daily win opens nothing).
                let back: Int = core.progress.isOpen(level) ? level : core.progress.frontier
                #expect(restored.mode == .campaign && restored.levelNumber == back, "stream \(stream) \(index)")
                #expect(restored.play.records.isEmpty, "stream \(stream) state \(index)")
            } else {
                #expect(restored.levelNumber == core.levelNumber, "stream \(stream) state \(index)")
                #expect(restored.play.records == core.play.records, "stream \(stream) state \(index)")
                #expect(restored.mode == core.mode && restored.play == core.play, "stream \(stream) \(index)")
                #expect(restored.tutorial == core.tutorial, "stream \(stream) state \(index)")
            }
            // The engine applies the same chain to a schema-2 envelope.
            let restoredDigest: StateDigest = try Self.digest(restored)
            let viaEngine: Core = try Self.engineRestore(&engine, object, version: 2, seed: state.seed,
                                                         digest: restoredDigest)
            let engineDigest: StateDigest = try Self.digest(viaEngine)
            #expect(viaEngine == restored && !viaEngine.soundOn, "stream \(stream) state \(index)")
            #expect(engineDigest == restoredDigest, "stream \(stream) state \(index)")
        }
        return results
    }

    /// Schema-2 payloads 25 × group + 1 … 25 × group + 25 of the 100.
    @Test(arguments: Array(0..<4))
    func schemaTwoPayloadsMigrateUnverified(group: Int) async throws {
        let results: Int = try await Self.schemaTwo(stream: UInt64(21 + group), count: 25)
        #expect(results >= 25, "group \(group)")
    }

    // MARK: Honest results survive, edited ones are dropped and counted

    /// `entry` (a traced result of `level`) edited by `edit`. Each edit fails the check for a reason that does not
    /// depend on the code under test: the stars differ from the stars rule for the honest actions spent; actions spent
    /// below the legs the trace spends (counted here by replay; the stars set by rule for them) claim less than the
    /// trace proves; a leg to the ship's own star is never legal; and a won play takes no further leg.
    static func edited(_ entry: [String: Any], level: Int, _ edit: Edit,
                       _ random: inout Random) throws -> [String: Any] {
        var changed: [String: Any] = entry
        let stars: Int = try #require(entry["stars"] as? Int)
        var trace: [Any] = try #require(entry["trace"] as? [Any])
        try #require(!trace.isEmpty)
        let saved: [StarlitCartoucheAction] = try Self.actions(trace)
        let play: StarlitCartouchePlay = try Self.played(level: level, trace: saved)
        #expect(play.stage == .won, "level \(level)")
        let spent: Int = play.actionsSpent
        try #require(spent >= 1)
        switch edit {
        case .stars:
            // Raised when it can be; a three-star result is lowered instead (stars stay in 1 … 3, or decoding fails).
            changed["stars"] = stars < 3 ? stars + 1 : 2
        case .actionsBelowTrace:
            let certified: Int = try Self.plan(level).count
            changed["actionsSpent"] = spent - 1
            changed["stars"] = Progress.stars(actionsSpent: spent - 1, certified: certified)
        case .legChanged:
            let index: Int = random.below(saved.count)
            let before: StarlitCartouchePlay = try Self.played(level: level, trace: Array(saved.prefix(index)))
            let wait: Int
            switch saved[index] {
            case let .leg(_, savedWait): wait = savedWait
            }
            trace[index] = try Self.json(StarlitCartoucheAction.leg(before.star, wait))
            changed["trace"] = trace
        case .extraLeg:
            trace.append(trace[random.below(trace.count)])
            changed["trace"] = trace
        }
        return changed
    }

    /// Checks `count` seeded saves of generator stream `stream`; returns (honest, edited) totals.
    static func reconciledSaves(stream: UInt64, count: Int) async throws -> (honest: Int, edited: Int) {
        let dates: [[Double]] = try Self.dailyDates()
        var random: Random = Random(seed: Self.baseSeed &+ stream)
        var honestTotal: Int = 0
        var editedTotal: Int = 0
        let edits: [Edit] = Edit.allCases
        for index in 0..<count {
            let state: (core: Core, seed: UInt64) = try await Self.winner(&random, dates: dates)
            let core: Core = state.core
            var object: [String: Any] = try Self.object(try core.snapshotPayload())
            var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
            let solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
            #expect(!solved.isEmpty, "stream \(stream) save \(index)")
            var entries: [[String: Any]] = []
            var honest: [Int: Progress.Result] = [:]
            var editedCount: Int = 0
            for entry in solved {
                let level: Int = try #require(entry["level"] as? Int)
                let saved: Progress.Result = try #require(core.progress.solved[level])
                #expect(saved.verified && !saved.trace.isEmpty, "level \(level)")
                let spent: Int = try Self.played(level: level, trace: saved.trace).actionsSpent
                #expect(spent <= saved.actionsSpent, "level \(level)")
                let roll: Int = random.below(5)
                if roll < 2 {
                    let edit: Edit = edits[random.below(edits.count)]
                    entries.append(try Self.edited(entry, level: level, edit, &random))
                    editedCount += 1
                } else if roll < 3 {
                    // An honest untraced result (as written before schema 3): kept, unverified.
                    var untraced: [String: Any] = entry
                    untraced["trace"] = [Any]()
                    untraced["verified"] = false
                    entries.append(untraced)
                    honest[level] = Progress.Result(actionsSpent: saved.actionsSpent, stars: saved.stars)
                } else {
                    entries.append(entry)
                    honest[level] = saved
                }
            }
            progress["solved"] = entries
            object["progress"] = progress
            let restored: Core = try Core.restore(payload: try Self.data(object), seed: state.seed)
            let restoredLevels: [Int] = restored.progress.solved.keys.sorted()
            let honestLevels: [Int] = honest.keys.sorted()
            #expect(restored.reconciliationDropped == editedCount, "stream \(stream) save \(index)")
            #expect(restoredLevels == honestLevels, "stream \(stream) save \(index)")
            for (level, result) in honest {
                let kept: Progress.Result? = restored.progress.solved[level]
                #expect(kept == result, "stream \(stream) save \(index) level \(level)")
            }
            #expect(restored.progress.frontier == core.progress.frontier, "stream \(stream) save \(index)")
            #expect(restored.levelNumber == core.levelNumber && restored.play == core.play)
            #expect(restored.mode == core.mode && restored.tutorial == core.tutorial)
            #expect(restored.soundOn == core.soundOn, "stream \(stream) save \(index)")
            // The unedited save restores every result with nothing dropped.
            let clean: Core = try Core.restore(payload: try core.snapshotPayload(), seed: state.seed)
            #expect(clean.reconciliationDropped == 0 && clean.progress == core.progress, "save \(index)")
            honestTotal += honest.count
            editedTotal += editedCount
        }
        return (honestTotal, editedTotal)
    }

    /// Saves 25 × group + 1 … 25 × group + 25 of the 200.
    @Test(arguments: Array(0..<8))
    func twoHundredSavesReconcileExactly(group: Int) async throws {
        let totals: (honest: Int, edited: Int) = try await Self.reconciledSaves(stream: UInt64(31 + group), count: 25)
        #expect(totals.honest > 0 && totals.edited > 0, "group \(group)")
    }

    /// Every kind of edit is dropped on its own (one traced win of level 1, each edit alone), so no edit relies on
    /// another being present in the same save.
    @Test func eachEditAloneIsDropped() async throws {
        let dates: [[Double]] = try Self.dailyDates()
        var core: Core = try await Core.prepare(seed: 0)
        try Self.win(&core, detour: 0, dates: dates)
        let object: [String: Any] = try Self.object(try core.snapshotPayload())
        var random: Random = Random(seed: Self.baseSeed &+ 51)
        for edit in Edit.allCases {
            var copy: [String: Any] = object
            var progress: [String: Any] = try #require(copy["progress"] as? [String: Any])
            let solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
            try #require(solved.count == 1)
            progress["solved"] = [try Self.edited(solved[0], level: 1, edit, &random)]
            copy["progress"] = progress
            let restored: Core = try Core.restore(payload: try Self.data(copy), seed: 0)
            #expect(restored.reconciliationDropped == 1 && restored.progress.solved.isEmpty, "\(edit)")
            #expect(restored.progress.frontier == core.progress.frontier, "\(edit)")
        }
    }

    // MARK: FR-R02G1607-005 — deterministic restore and daily level

    /// The same payload restores twice to equal digests, states, dropped counts and payloads (50 seeded states).
    @Test func theSamePayloadRestoresTwiceToEqualDigests() async throws {
        let dates: [[Double]] = try Self.dailyDates()
        var random: Random = Random(seed: Self.baseSeed &+ 41)
        for index in 0..<50 {
            let state: (core: Core, seed: UInt64) = index % 2 == 0
                ? try await Self.reachable(&random, dates: dates) : try await Self.winner(&random, dates: dates)
            let payload: Data = try state.core.snapshotPayload()
            let first: Core = try Core.restore(payload: payload, seed: state.seed)
            let second: Core = try Core.restore(payload: payload, seed: state.seed)
            let firstDigest: StateDigest = try Self.digest(first)
            let secondDigest: StateDigest = try Self.digest(second)
            let firstPayload: Data = try first.snapshotPayload()
            let secondPayload: Data = try second.snapshotPayload()
            #expect(firstDigest == secondDigest, "state \(index)")
            #expect(first == second && first.reconciliationDropped == second.reconciliationDropped, "state \(index)")
            #expect(firstPayload == secondPayload, "state \(index)")
        }
    }

    /// The daily level is a function of the given date alone: repeated calls agree with the count made here, 100
    /// consecutive days (from 2026-01-01 and from 2031-06-15) visit every level, and every state (fresh, won, sound on,
    /// practising) opens the same daily level; a replay refuses it until stopped, then opens the same level.
    @Test func theDailyLevelDependsOnlyOnTheDate() async throws {
        #expect(Progress.dailyMultiplier == Self.dailyMultiplier && Progress.dailyEpochYear == 2026)
        let calendar: Calendar = try Self.utcCalendar()
        let starts: [Int] = [0, try Self.foundationDays(2031, 6, 15, calendar) - Self.epochDays]
        for start in starts {
            var seen: Set<Int> = []
            for offset in start..<(start + 100) {
                let parts: [Int] = try Self.date(offset: offset, calendar)
                let first: Int? = Progress.dailyLevel(year: parts[0], month: parts[1], day: parts[2])
                let second: Int? = Progress.dailyLevel(year: parts[0], month: parts[1], day: parts[2])
                let expected: Int = ((offset * Self.dailyMultiplier) % 100 + 100) % 100 + 1
                #expect(first == expected && second == expected, "\(parts)")
                if let first { seen.insert(first) }
            }
            #expect(seen.count == 100, "from day \(start)")
        }
        let dates: [[Int]] = [[2026, 1, 1], [2026, 11, 24], [2025, 12, 31], [2024, 2, 29], [2030, 7, 4],
                              [2000, 3, 1], [2099, 12, 31], [1970, 1, 1]]
        var cores: [Core] = []
        let seeds: [UInt64] = [0, 1, 57, 99]
        for seed in seeds { cores.append(try await Core.prepare(seed: seed)) }
        var won: Core = try await Core.prepare(seed: 0)
        try Self.win(&won, detour: 0, dates: try Self.dailyDates())
        #expect(!won.progress.solved.isEmpty)
        _ = won.apply(Self.act("settings.sound", [1]))
        #expect(won.soundOn)
        cores.append(won)
        var replaying: Core = won
        #expect(replaying.apply(Self.act("replay.start", [1])) == .accepted)
        var practising: Core = try await Core.prepare(seed: 2)
        _ = practising.apply(Self.act("mode.practice"))
        cores.append(practising)
        for date in dates {
            let expected: Int = try Self.expectedDaily(date[0], date[1], date[2], calendar)
            let first: Int? = Progress.dailyLevel(year: date[0], month: date[1], day: date[2])
            let second: Int? = Progress.dailyLevel(year: date[0], month: date[1], day: date[2])
            #expect(first == expected && second == expected, "\(date)")
            let values: [Double] = [Double(date[0]), Double(date[1]), Double(date[2])]
            for var core in cores {
                let opened: ActionResult = core.apply(Self.act("mode.daily", values))
                #expect(opened == .accepted, "\(date)")
                #expect(core.levelNumber == expected && core.mode == .daily(level: expected), "\(date)")
                // Twice with the same date from the state it reached: the same level again.
                let reopened: ActionResult = core.apply(Self.act("mode.daily", values))
                #expect(reopened == .accepted && core.levelNumber == expected, "\(date)")
            }
            // A replay refuses the daily level (stop it first) and stays as it was.
            var inReplay: Core = replaying
            let refused: ActionResult = inReplay.apply(Self.act("mode.daily", values))
            #expect(refused == .rejected(.rule(code: StarlitCartoucheExperienceRule.replay)) && inReplay == replaying)
            #expect(inReplay.apply(Self.act("replay.stop")) == .accepted, "\(date)")
            #expect(inReplay.apply(Self.act("mode.daily", values)) == .accepted && inReplay.levelNumber == expected)
        }
    }
}
