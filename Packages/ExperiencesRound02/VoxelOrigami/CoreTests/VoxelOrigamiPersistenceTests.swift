// VoxelOrigamiPersistenceTests — feature 447 (R02-G15-07) T-R02G1507-004 (FR-R02G1507-001 … 005, 007;
// SC-R02G1507-001 … 003; clarifications Q1–Q5). Host checks of Voxel Origami's persistence through the adapter core:
//   - SC-R02G1507-001: 500 seeded reachable states (random walks of hinge.turn (any hinge index of the level by ±1,
//     the root and the always refused step 0 included; a turn may collide or sweep and fail the level), hinge.choose,
//     play.undo, play.redo, level.next, level.select of open levels, mode.daily, mode.practice, mode.campaign,
//     tutorial.dismiss, settings.sound on and off, certified wins played from the certified plan with and without
//     detours, and replay start, step and stop) round-trip through `snapshotPayload()` and `restore(payload:seed:)`
//     with equal states, digests, progress, mode, tutorial step and sound choice, identical payload bytes and nothing
//     dropped; toggling the sound choice changes the state but never the digest (FR-R02G1507-007);
//   - SC-R02G1507-002: 100 seeded states as schema-1 payloads `{level, records}` and 100 as schema-2 payloads (the
//     schema-3 payload without `sound` and with `trace` and `verified` removed from each solved entry) migrate through
//     `migratedToSchemaTwo` / `migratedToSchemaThree` (and `Core.migrations.migrate(_:from:)`, and the engine's chain
//     for an envelope of that schema) and restore with the level, the records and the progress kept (frontier as saved
//     or rebuilt by the 1 → 2 rule, won levels, actions spent, stars), unverified, without traces, the sound off;
//   - SC-R02G1507-003: 200 seeded saves with traced results: honest results (and honest untraced ones) survive restore;
//     edited ones (stars changed, actions spent below the turns the trace spends, a trace turn changed into a turn of
//     the root (never legal), the winning turn removed) are dropped, `reconciliationDropped` equals the number edited
//     and the frontier stays as saved;
//   - FR-R02G1507-005: one payload restores twice to equal digests and states; the daily level of a date is the same on
//     repeated calls and equals (days since 2026-01-01 × 31) mod 100 + 1 counted here independently with Foundation's
//     UTC calendar, whatever state asks for it.
// Synthetic data, explicit types, plain loops, no sleep, no clock. The states come from `SeededRandom` seeded with
// 2_447; edited saves are made by editing the payload's JSON, as a tampered file would be.
//
// Speed: certifying a level runs the solver (once per process, cached in the adapter, prewarmed concurrently here). So
// the seeded states stay on levels 1 … 6: the seeds are 0 … 5, certified wins are played only on levels 1 … 5 and the
// daily dates are those of 2026 whose daily level is 1 … 6; level.next and level.select never pass level 6. The loops
// are split into parametrized groups of 25 or 50 so each case stays short.
// Modelled on feature 437's MoonlitMechanismPersistenceTests.
import Foundation
import Testing
@testable import VoxelOrigamiCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct VoxelOrigamiPersistenceTests {
    typealias Core = VoxelOrigamiExperienceCore
    typealias Progress = VoxelOrigamiProgress

    /// The seed of every generator in this file.
    static let baseSeed: UInt64 = 2_447

    /// The highest level a seeded state may reach (see the file header).
    static let highestLevel: Int = 6

    /// The highest level a win is played on, so the frontier never passes ``highestLevel``.
    static let highestWin: Int = 5

    /// The days from 1970-01-01 to 2026-01-01 (20 454), the daily epoch.
    static let epochDays: Int = 20_454

    /// The daily level's multiplier of the spec (31).
    static let dailyMultiplier: Int = 31

    /// The rule code of a play action refused during a replay (contract: `r02-g15.replay`).
    static let replayRefusal: String = "r02-g15.replay"

    /// The illegal action an edited trace turn becomes: a turn of the root, hinge 0, is always refused.
    static let illegalAction: VoxelOrigamiAction = VoxelOrigamiAction.turn(0, 1)

    /// The kinds of edit made to a saved result.
    enum Edit: CaseIterable {
        case stars
        case actionsBelowTrace
        case turnChanged
        case winningTurnRemoved
    }

    // MARK: Helpers

    /// Levels 1 … ``highestLevel`` certified concurrently into the adapter's cache, once per test process.
    static let prewarmed: Bool = {
        DispatchQueue.concurrentPerform(iterations: 6) { (index: Int) in
            _ = try? VoxelOrigamiExperienceCore.generated(number: index + 1)
        }
        return true
    }()

    /// Certifies levels 1 … ``highestLevel`` (concurrently, the first time only).
    static func prewarm() {
        #expect(Self.prewarmed)
    }

    /// A value in 0 ..< `bound` (bound > 0).
    static func below(_ bound: Int, _ random: inout SeededRandom) -> Int {
        random.int(0...(bound - 1))
    }

    /// A random step, −1 or +1.
    static func step(_ random: inout SeededRandom) -> Int {
        Self.below(2, &random) == 0 ? -1 : 1
    }

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
    static func act(_ kernel: VoxelOrigamiAction) -> ExperienceAction {
        switch kernel {
        case let .turn(hinge, step):
            Self.act("hinge.turn", [Double(hinge), Double(step)])
        }
    }

    /// The certified plan turns of level `number`.
    static func plan(_ number: Int) throws -> [VoxelOrigamiAction] {
        try Core.generated(number: number).plan.turns
    }

    /// The days from 1970-01-01 to a proleptic Gregorian date, counted with Foundation's UTC calendar (independent of
    /// the code under test).
    static func foundationDays(_ year: Int, _ month: Int, _ day: Int) throws -> Int {
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let date: Date = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        return Int((date.timeIntervalSince1970 / 86_400).rounded())
    }

    /// The daily level of a date by the rule of the spec, counted here: (days since 2026-01-01 × 31) mod 100 + 1.
    static func expectedDaily(_ year: Int, _ month: Int, _ day: Int) throws -> Int {
        let days: Int = try Self.foundationDays(year, month, day) - Self.epochDays
        return ((days * Self.dailyMultiplier) % 100 + 100) % 100 + 1
    }

    /// The first date of 2026 whose daily level is `level`, as `[year, month, day]` values.
    static func dailyDate(for level: Int) throws -> [Double] {
        for month in 1...12 {
            for day in 1...28 where try Self.expectedDaily(2026, month, day) == level {
                return [2026, Double(month), Double(day)]
            }
        }
        Issue.record("no 2026 date has daily level \(level)")
        return [2026, 1, 1]
    }

    /// The dates whose daily levels are 1 … ``highestLevel`` (index = level − 1).
    static func dailyDates() throws -> [[Double]] {
        var dates: [[Double]] = []
        for level in 1...Self.highestLevel { dates.append(try Self.dailyDate(for: level)) }
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
    static func json(_ kernel: VoxelOrigamiAction) throws -> Any {
        try JSONSerialization.jsonObject(with: try JSONEncoder().encode(kernel), options: [.fragmentsAllowed])
    }

    /// The turns `trace` spends on a fresh play of certified level `level` (the kernel's actions spent after it),
    /// counted by replaying it through the kernel here.
    static func traceActions(level: Int, trace: [VoxelOrigamiAction]) throws -> Int {
        let certified: VoxelOrigamiGenerated = try Core.generated(number: level)
        var play: VoxelOrigamiPlay = try Core.freshPlay(of: certified.level)
        for action in trace {
            try play.apply(action, expecting: play.fingerprint)
        }
        #expect(play.stage == .won, "level \(level)")
        return play.actionsSpent
    }

    /// Re-opens the current level fresh in its mode (campaign, practice or daily), then plays its certified plan,
    /// optionally after a detour (`1`: the first plan turn and its undo, one more action spent for the stars; `2`: the
    /// first plan turn, its undo and its redo, the rest of the plan after it). The effective turns are always the plan.
    /// A plan of one turn is played without a detour (its turn wins at once). Does nothing in replay mode or above
    /// ``highestWin``.
    static func win(_ core: inout Core, detour: Int, dates: [[Double]]) throws {
        switch core.mode {
        case .replay:
            return
        case .practice:
            guard core.levelNumber <= Self.highestWin else { return }
            _ = core.apply(Self.act("mode.practice"))
        case .campaign:
            guard core.levelNumber <= Self.highestWin else { return }
            _ = core.apply(Self.act("mode.campaign"))
        case .daily(let level):
            guard level <= Self.highestWin else { return }
            _ = core.apply(Self.act("mode.daily", dates[level - 1]))
        }
        guard core.levelNumber <= Self.highestWin else { return }
        let turns: [VoxelOrigamiAction] = try Self.plan(core.levelNumber)
        try #require(!turns.isEmpty)
        var rest: [VoxelOrigamiAction] = turns
        let effectiveDetour: Int = turns.count >= 2 ? detour : 0
        switch effectiveDetour {
        case 1:
            #expect(core.apply(Self.act(turns[0])) == .accepted)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
        case 2:
            #expect(core.apply(Self.act(turns[0])) == .accepted)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
            #expect(core.apply(Self.act("play.redo")) == .accepted)
            rest.removeFirst()
        default:
            break
        }
        for kernel in rest {
            let result: ActionResult = core.apply(Self.act(kernel))
            #expect(result == .accepted, "\(kernel)")
        }
        #expect(core.play.stage == .won, "level \(core.levelNumber)")
    }

    /// One random kernel action (legal or refused) on the current play: a turn of any hinge index of the level (the
    /// root refused) by ±1 (a turn may collide or sweep and fail the level), a turn of a hinge the level may lack, a
    /// hinge choice (presentation), undo or redo, or the always refused turn of step 0.
    static func randomKernel(_ core: inout Core, _ random: inout SeededRandom) {
        let roll: Int = Self.below(100, &random)
        let cubes: Int = core.play.level.cubes.count
        if roll < 44 {
            let hinge: Int = Self.below(cubes, &random)
            _ = core.apply(Self.act(VoxelOrigamiAction.turn(hinge, Self.step(&random))))
        } else if roll < 52 {
            let hinge: Int = random.int(Core.hingeRange)
            _ = core.apply(Self.act(VoxelOrigamiAction.turn(hinge, Self.step(&random))))
        } else if roll < 58 {
            _ = core.apply(Self.act("hinge.choose", [Double(random.int(Core.hingeRange))]))
        } else if roll < 76 {
            _ = core.apply(Self.act("play.undo"))
        } else if roll < 92 {
            _ = core.apply(Self.act("play.redo"))
        } else {
            let hinge: Int = Self.below(cubes, &random)
            _ = core.apply(Self.act(VoxelOrigamiAction.turn(hinge, 0)))
        }
    }

    /// One random action (legal or refused) on `core`; level changes and wins are rarer than kernel actions.
    static func randomStep(_ core: inout Core, _ random: inout SeededRandom, dates: [[Double]]) throws {
        let roll: Int = Self.below(100, &random)
        if case .replay = core.mode {
            if roll < 65 {
                _ = core.apply(Self.act("replay.step"))
            } else if roll < 80 {
                _ = core.apply(Self.act("replay.stop"))
            } else if roll < 87 {
                _ = core.apply(Self.act("tutorial.dismiss"))
            } else if roll < 94 {
                _ = core.apply(Self.act("settings.sound", [Double(Self.below(2, &random))]))
            } else {
                let refused: ActionResult = core.apply(Self.act("play.undo"))
                #expect(refused == .rejected(.rule(code: Self.replayRefusal)))
            }
            return
        }
        if roll < 40 {
            Self.randomKernel(&core, &random)
        } else if roll < 43 {
            if core.levelNumber < Self.highestLevel { _ = core.apply(Self.act("level.next")) }
        } else if roll < 46 {
            let top: Int = min(core.progress.frontier, Self.highestLevel)
            _ = core.apply(Self.act("level.select", [Double(random.int(1...top))]))
        } else if roll < 49 {
            _ = core.apply(Self.act("mode.practice"))
        } else if roll < 52 {
            if core.progress.frontier <= Self.highestLevel { _ = core.apply(Self.act("mode.campaign")) }
        } else if roll < 55 {
            _ = core.apply(Self.act("mode.daily", dates[Self.below(dates.count, &random)]))
        } else if roll < 58 {
            _ = core.apply(Self.act("tutorial.dismiss"))
        } else if roll < 64 {
            _ = core.apply(Self.act("settings.sound", [Double(Self.below(2, &random))]))
        } else if roll < 84 {
            try Self.win(&core, detour: Self.below(3, &random), dates: dates)
        } else {
            var verified: [Int] = []
            for level in core.progress.solved.keys.sorted() where core.progress.solved[level]?.verified == true {
                verified.append(level)
            }
            let level: Int = verified.isEmpty ? random.int(1...Self.highestLevel)
                : verified[Self.below(verified.count, &random)]
            _ = core.apply(Self.act("replay.start", [Double(level)]))
        }
    }

    /// A seeded reachable state: prepared with a random seed (levels 1 … 6), then 0 … 14 random actions.
    static func reachable(_ random: inout SeededRandom,
                          dates: [[Double]]) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = UInt64(Self.below(Self.highestLevel, &random))
        var core: Core = try await Core.prepare(seed: seed)
        let count: Int = random.int(0...14)
        for _ in 0..<count { try Self.randomStep(&core, &random, dates: dates) }
        return (core, seed)
    }

    /// A seeded state with 1 … 3 certified wins (some daily) on levels 1 … 5, moved on with level.next after each, and
    /// the sound on or off.
    static func winner(_ random: inout SeededRandom,
                       dates: [[Double]]) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = UInt64(Self.below(Self.highestWin, &random))
        var core: Core = try await Core.prepare(seed: seed)
        let wins: Int = random.int(1...3)
        for _ in 0..<wins {
            if Self.below(4, &random) == 0 {
                _ = core.apply(Self.act("mode.daily", dates[Self.below(Self.highestWin, &random)]))
            }
            try Self.win(&core, detour: Self.below(3, &random), dates: dates)
            if core.levelNumber < Self.highestLevel { _ = core.apply(Self.act("level.next")) }
        }
        _ = core.apply(Self.act("settings.sound", [Double(Self.below(2, &random))]))
        return (core, seed)
    }

    // MARK: SC-R02G1507-001 — 500 seeded reachable states round-trip

    /// Round-trips `count` seeded states of generator stream `stream`; returns how many verified results, replay
    /// states, daily states, practice states and sound-on states they carried.
    static func roundTrips(stream: UInt64, count: Int) async throws
        -> (verified: Int, replays: Int, dailies: Int, practices: Int, sounds: Int) {
        Self.prewarm()
        let dates: [[Double]] = try Self.dailyDates()
        var random: SeededRandom = SeededRandom(seed: Self.baseSeed &+ stream)
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
            #expect(restored.play.records == state.core.play.records)
            #expect(restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
            let again: Data = try restored.snapshotPayload()
            #expect(again == payload, "stream \(stream) state \(index)")
            // The sound choice is state but never digested: toggling it changes `==` and the payload, not the digest.
            var toggled: Core = state.core
            let flipped: Double = state.core.soundOn ? 0 : 1
            let toggleResult: ActionResult = toggled.apply(Self.act("settings.sound", [flipped]))
            #expect(toggleResult == .accepted, "stream \(stream) \(index)")
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
        // Every state also round-trips with its sound choice flipped, so both choices are checked in every state; the
        // walks themselves reach the sound on in some states and never in all 50 states of one group.
        #expect(totals.verified > 0 && totals.sounds < 50, "group \(group)")
        #expect(totals.dailies + totals.practices + totals.replays > 0, "group \(group)")
    }

    // MARK: SC-R02G1507-002 — schema 1 and schema 2 payloads migrate

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
    /// random turns, hinge choices, undo and redo, some with the sound on before saving).
    static func schemaOne(stream: UInt64, count: Int) async throws {
        Self.prewarm()
        var random: SeededRandom = SeededRandom(seed: Self.baseSeed &+ stream)
        var engine: ExperienceEngine<Core> = try await Self.activeEngine()
        for index in 0..<count {
            let seed: UInt64 = UInt64(Self.below(Self.highestLevel, &random))
            var core: Core = try await Core.prepare(seed: seed)
            let steps: Int = random.int(0...10)
            for _ in 0..<steps { Self.randomKernel(&core, &random) }
            if Self.below(2, &random) == 0 { _ = core.apply(Self.act("settings.sound", [1])) }
            let full: [String: Any] = try Self.object(try core.snapshotPayload())
            var old: [String: Any] = [:]
            old["level"] = full["level"]
            old["records"] = full["records"]
            let two: [String: Any] = try Core.migratedToSchemaTwo(old)
            let three: [String: Any] = try Core.migratedToSchemaThree(two)
            let restored: Core = try Core.restore(payload: try Self.data(three), seed: seed)
            var expected: Progress = Progress()
            expected.open(through: core.levelNumber)
            let initialStep: VoxelOrigamiTutorialStep = VoxelOrigamiTutorialStep.initial(level: core.levelNumber)
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
            // The chain the engine uses gives the same object, and the engine restores a schema-1 envelope alike.
            let chained: [String: Any] = try Core.migrations.migrate(old, from: 1)
            let chainedData: Data = try Self.data(chained)
            let threeData: Data = try Self.data(three)
            #expect(chainedData == threeData, "stream \(stream) state \(index)")
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

    /// Migrates `count` seeded schema-2 payloads of generator stream `stream` (states with traced results, the sound on
    /// or off); returns how many results were carried over.
    static func schemaTwo(stream: UInt64, count: Int) async throws -> Int {
        Self.prewarm()
        let dates: [[Double]] = try Self.dailyDates()
        var random: SeededRandom = SeededRandom(seed: Self.baseSeed &+ stream)
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
            let migrated: [String: Any] = try Core.migratedToSchemaThree(object)
            let chained: [String: Any] = try Core.migrations.migrate(object, from: 2)
            let migratedData: Data = try Self.data(migrated)
            let chainedData: Data = try Self.data(chained)
            #expect(chainedData == migratedData, "stream \(stream) state \(index)")
            let sound: Any? = migrated["sound"]
            #expect((sound as? Bool) == false, "stream \(stream) state \(index)")
            let restored: Core = try Core.restore(payload: migratedData, seed: state.seed)
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

    // MARK: SC-R02G1507-003 — honest results survive, edited ones are dropped and counted

    /// `entry` (a traced result of `level`) edited by `edit`. Each edit fails the check for a reason that does not
    /// depend on the code under test: the stars differ from the stars rule for the honest actions spent; actions spent
    /// below the turns the trace spends (counted here by replay; the stars set by rule for them) claim less than the
    /// trace proves; a turn of the root is never legal; and without its winning turn the trace never ends won (a play
    /// is won the moment a turn matches, so no shorter prefix of an honest trace is won, and an empty trace never
    /// verifies).
    static func edited(_ entry: [String: Any], level: Int, _ edit: Edit,
                       _ random: inout SeededRandom) throws -> [String: Any] {
        var changed: [String: Any] = entry
        let stars: Int = try #require(entry["stars"] as? Int)
        var trace: [Any] = try #require(entry["trace"] as? [Any])
        try #require(!trace.isEmpty)
        let saved: [VoxelOrigamiAction] = try JSONDecoder().decode(
            [VoxelOrigamiAction].self, from: try JSONSerialization.data(withJSONObject: trace))
        let spent: Int = try Self.traceActions(level: level, trace: saved)
        try #require(spent >= 1)
        switch edit {
        case .stars:
            // Raised when it can be; a three-star result is lowered instead (stars stay in 1 … 3, or decoding fails).
            changed["stars"] = stars < 3 ? stars + 1 : 2
        case .actionsBelowTrace:
            let certified: Int = try Self.plan(level).count
            changed["actionsSpent"] = spent - 1
            changed["stars"] = Progress.stars(actionsSpent: spent - 1, certified: certified)
        case .turnChanged:
            trace[Self.below(trace.count, &random)] = try Self.json(Self.illegalAction)
            changed["trace"] = trace
        case .winningTurnRemoved:
            trace.removeLast()
            changed["trace"] = trace
        }
        return changed
    }

    /// Checks `count` seeded saves of generator stream `stream`; returns (honest, edited) totals.
    static func reconciledSaves(stream: UInt64, count: Int) async throws -> (honest: Int, edited: Int) {
        Self.prewarm()
        let dates: [[Double]] = try Self.dailyDates()
        var random: SeededRandom = SeededRandom(seed: Self.baseSeed &+ stream)
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
                let spent: Int = try Self.traceActions(level: level, trace: saved.trace)
                #expect(spent <= saved.actionsSpent, "level \(level)")
                let roll: Int = Self.below(5, &random)
                if roll < 2 {
                    let edit: Edit = edits[Self.below(edits.count, &random)]
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
        Self.prewarm()
        let dates: [[Double]] = try Self.dailyDates()
        var core: Core = try await Core.prepare(seed: 0)
        try Self.win(&core, detour: 0, dates: dates)
        let object: [String: Any] = try Self.object(try core.snapshotPayload())
        var random: SeededRandom = SeededRandom(seed: Self.baseSeed &+ 51)
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

    // MARK: FR-R02G1507-005 — deterministic restore and daily level

    /// The same payload restores twice to equal digests, states, dropped counts and payloads (50 seeded states).
    @Test func theSamePayloadRestoresTwiceToEqualDigests() async throws {
        Self.prewarm()
        let dates: [[Double]] = try Self.dailyDates()
        var random: SeededRandom = SeededRandom(seed: Self.baseSeed &+ 41)
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

    /// The daily level is a function of the given date alone: repeated calls agree with the count made here, 400
    /// consecutive days visit every level, and every state (fresh, won, sound on, practising) opens the same daily
    /// level.
    @Test func theDailyLevelDependsOnlyOnTheDate() async throws {
        Self.prewarm()
        #expect(Progress.dailyMultiplier == Self.dailyMultiplier && Progress.dailyEpochYear == 2026)
        var dates: [[Int]] = [[2026, 1, 1], [2026, 11, 24], [2025, 12, 31], [2024, 2, 29], [2030, 7, 4],
                              [2000, 3, 1], [2099, 12, 31], [1970, 1, 1]]
        for date in try Self.dailyDates() {
            var whole: [Int] = []
            for value in date { whole.append(Int(value)) }
            dates.append(whole)
        }
        // 400 consecutive days from 2026-01-01 visit every level and agree with the independent count.
        var seen: Set<Int> = []
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        for offset in 0..<400 {
            let days: Int = Self.epochDays + offset
            let date: Date = Date(timeIntervalSince1970: Double(days) * 86_400)
            let parts: DateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let year: Int = try #require(parts.year)
            let monthValue: Int = try #require(parts.month)
            let day: Int = try #require(parts.day)
            let level: Int? = Progress.dailyLevel(year: year, month: monthValue, day: day)
            let expected: Int = (offset * Self.dailyMultiplier) % 100 + 1
            #expect(level == expected, "\(year)-\(monthValue)-\(day)")
            if let level { seen.insert(level) }
        }
        #expect(seen.count == 100)
        var cores: [Core] = []
        let seeds: [UInt64] = [0, 1, 2, 3]
        for seed in seeds { cores.append(try await Core.prepare(seed: seed)) }
        var won: Core = try await Core.prepare(seed: 0)
        try Self.win(&won, detour: 0, dates: try Self.dailyDates())
        #expect(!won.progress.solved.isEmpty)
        _ = won.apply(Self.act("settings.sound", [1]))
        #expect(won.soundOn)
        cores.append(won)
        var practising: Core = try await Core.prepare(seed: 2)
        _ = practising.apply(Self.act("mode.practice"))
        cores.append(practising)
        for date in dates {
            let expected: Int = try Self.expectedDaily(date[0], date[1], date[2])
            let first: Int? = Progress.dailyLevel(year: date[0], month: date[1], day: date[2])
            let second: Int? = Progress.dailyLevel(year: date[0], month: date[1], day: date[2])
            #expect(first == expected && second == expected, "\(date)")
            // Only levels 1 … 6 are opened through the adapter (certifying any other level runs the solver).
            guard expected <= Self.highestLevel else { continue }
            for var core in cores {
                let values: [Double] = [Double(date[0]), Double(date[1]), Double(date[2])]
                let opened: ActionResult = core.apply(Self.act("mode.daily", values))
                #expect(opened == .accepted, "\(date)")
                #expect(core.levelNumber == expected && core.mode == .daily(level: expected), "\(date)")
                // Twice with the same date from the state it reached: the same level again.
                let reopened: ActionResult = core.apply(Self.act("mode.daily", values))
                #expect(reopened == .accepted && core.levelNumber == expected, "\(date)")
            }
        }
    }
}
