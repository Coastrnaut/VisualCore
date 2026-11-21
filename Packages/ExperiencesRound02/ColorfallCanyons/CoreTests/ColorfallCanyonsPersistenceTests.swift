// ColorfallCanyonsPersistenceTests — feature 347 (R02-G05-07) T-R02G0507-004 (FR-R02G0507-001 … 005, 007;
// SC-R02G0507-001 … 004). Host checks of Colorfall Canyons's persistence and replay through the adapter core:
//   - SC-R02G0507-001: 500 seeded reachable states (random walks of canyon.carve, canyon.valve, time.step, undo, redo,
//     level.next, level.select of open levels, mode.daily, mode.practice, mode.campaign, tutorial.dismiss,
//     settings.sound on and off, certified wins played from `ColorfallCanyonsWitness.actions` and replay start, step
//     and stop) round-trip through `snapshotPayload()` and `restore(payload:seed:)` with equal states, digests,
//     progress, mode, tutorial step and sound choice, identical payload bytes and nothing dropped; toggling the sound
//     choice changes the state but never the digest (FR-R02G0507-007);
//   - SC-R02G0507-002: 100 seeded states as schema-1 payloads `{level, records}` and 100 as schema-2 payloads (the
//     schema-3 payload without `sound` and with `trace` and `verified` removed from each solved entry) migrate through
//     `migrations` (1 → 2 → 3 and 2 → 3) and restore, directly and as an `ExperienceEngine` envelope of that schema,
//     with the progress kept (frontier, solved levels, best actions, stars), unverified, without traces, the sound off;
//   - SC-R02G0507-003: 200 seeded saves with traced results: honest results (and honest untraced ones) survive restore;
//     edited ones (stars changed, best actions changed, the winning step removed from the trace, a trace action
//     replaced by `step(0)`, which the kernel never accepts) are dropped, `reconciliationDropped` equals the number
//     edited and the frontier stays as saved;
//   - FR-R02G0507-005: one payload restores twice to equal digests and states; the daily level of a date is the same on
//     repeated calls, equals (days since 2026-01-01 × 53) mod 100 + 1 counted here independently with Foundation's UTC
//     calendar, and does not depend on the seed, the level, the progress or the sound choice of the core it is chosen
//     from;
//   - SC-R02G0507-004: on each of the 100 certified levels the stored witness actions (read from
//     docs/games/colorfall-canyons/levels/NNN.witness.json) win a campaign play through the adapter, the stored trace
//     equals them, and `replay.start` / `replay.step` reproduce the witness's recorded play fingerprints action by
//     action and end won; `replay.step` after the end is refused with `r02-g05.replay-end`, the progress and its digest
//     never change during replay, and `replay.stop` returns to campaign. One test case per 5 levels.
// Synthetic data, explicit types, plain loops, no sleep, no clock. The states come from `ColorfallCanyonsRandom`
// (SplitMix64) seeded with 2_347; edited saves are made by editing the payload's JSON, as a tampered file would be.
//
// Speed: certifying a level runs the solver (generated once per process and cached). So the seeded states stay on
// levels 1 … 4: the seeds are 0 … 3, certified wins are played only on levels 1 … 3 and the daily dates are those of
// 2026 whose daily level is 1 … 4; level.next and level.select never pass level 4.
import Foundation
import Testing
@testable import ColorfallCanyonsCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct ColorfallCanyonsPersistenceTests {
    typealias Core = ColorfallCanyonsExperienceCore

    /// The seed of every generator in this file.
    static let baseSeed: UInt64 = 2_347

    /// The highest level a seeded state may reach (see the file header).
    static let highestLevel: Int = 4

    /// The highest level a win is played on, so the frontier never passes ``highestLevel``.
    static let highestWin: Int = 3

    /// The days from 1970-01-01 to 2026-01-01 (20 454), the daily epoch.
    static let epochDays: Int = 20_454

    /// The kinds of edit made to a saved result.
    enum Edit: CaseIterable {
        case stars
        case bestActions
        case winningStepRemoved
        case illegalAction
    }

    // MARK: Helpers

    /// A value in 0 ..< `bound` (bound > 0).
    static func below(_ bound: Int, _ random: inout ColorfallCanyonsRandom) -> Int {
        random.int(0...(bound - 1))
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// An action with values.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func action(_ kernel: ColorfallCanyonsAction) -> ExperienceAction {
        switch kernel {
        case .carve(let cell): Self.act("canyon.carve", [Double(cell)])
        case .valve(let spring): Self.act("canyon.valve", [Double(spring)])
        case .step(let ticks): Self.act("time.step", [Double(ticks)])
        }
    }

    /// Whether `kernel` is a step.
    static func isStep(_ kernel: ColorfallCanyonsAction) -> Bool {
        if case .step = kernel { return true }
        return false
    }

    /// The days from 1970-01-01 to a proleptic Gregorian date, counted with Foundation's UTC calendar (independent of
    /// the code under test).
    static func foundationDays(_ year: Int, _ month: Int, _ day: Int) throws -> Int {
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let date: Date = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        return Int((date.timeIntervalSince1970 / 86_400).rounded())
    }

    /// The daily level of a date by the rule of the spec, counted here: (days since 2026-01-01 × 53) mod 100 + 1.
    static func expectedDaily(_ year: Int, _ month: Int, _ day: Int) throws -> Int {
        let days: Int = try Self.foundationDays(year, month, day) - Self.epochDays
        return ((days * 53) % 100 + 100) % 100 + 1
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
    static func json(_ kernel: ColorfallCanyonsAction) throws -> Any {
        try JSONSerialization.jsonObject(with: try JSONEncoder().encode(kernel), options: [.fragmentsAllowed])
    }

    /// The first cell of `level` that can be carved at its starting heights, if any.
    static func carvable(_ level: ColorfallCanyonsLevel) -> Int? {
        for cell in 0..<level.cellCount where level.isCarvable(cell, heights: level.heights) { return cell }
        return nil
    }

    /// Re-opens the current level fresh in its mode (campaign, practice or daily), then plays its certified witness
    /// actions, optionally after a detour (`1`: a carve and its undo, net actions = the witness; `2`: a valve toggled
    /// twice when the budget leaves room, two more net actions). Does nothing in replay mode or above ``highestWin``.
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
        let generated: ColorfallCanyonsGenerated = try Core.generated(number: core.levelNumber)
        let witness: [ColorfallCanyonsAction] = ColorfallCanyonsWitness.actions(for: generated.solution,
                                                                                level: generated.level)
        var edits: Int = 0
        for kernel in witness where !Self.isStep(kernel) { edits += 1 }
        switch detour {
        case 1:
            if let cell = Self.carvable(core.play.level) {
                _ = core.apply(Self.act("canyon.carve", [Double(cell)]))
                _ = core.apply(Self.act("play.undo"))
            }
        case 2:
            if edits + 2 <= generated.level.budget {
                _ = core.apply(Self.act("canyon.valve", [0]))
                _ = core.apply(Self.act("canyon.valve", [0]))
            }
        default:
            break
        }
        for kernel in witness { _ = core.apply(Self.action(kernel)) }
    }

    /// One random action (legal or refused) on `core`; level changes and wins are rarer than edits.
    static func randomStep(_ core: inout Core, _ random: inout ColorfallCanyonsRandom, dates: [[Double]]) throws {
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
                _ = core.apply(Self.act("canyon.carve", [Double(random.int(0...119))]))
            }
            return
        }
        if roll < 18 {
            _ = core.apply(Self.act("canyon.carve", [Double(random.int(0...119))]))
        } else if roll < 24 {
            _ = core.apply(Self.act("canyon.valve", [Double(random.int(0...2))]))
        } else if roll < 30 {
            _ = core.apply(Self.act("time.step", [Double(random.int(1...60))]))
        } else if roll < 37 {
            _ = core.apply(Self.act("play.undo"))
        } else if roll < 41 {
            _ = core.apply(Self.act("play.redo"))
        } else if roll < 44 {
            if core.levelNumber < Self.highestLevel { _ = core.apply(Self.act("level.next")) }
        } else if roll < 47 {
            let top: Int = min(core.progress.frontier, Self.highestLevel)
            _ = core.apply(Self.act("level.select", [Double(random.int(1...top))]))
        } else if roll < 50 {
            _ = core.apply(Self.act("mode.practice"))
        } else if roll < 53 {
            _ = core.apply(Self.act("mode.campaign"))
        } else if roll < 56 {
            _ = core.apply(Self.act("mode.daily", dates[Self.below(dates.count, &random)]))
        } else if roll < 59 {
            _ = core.apply(Self.act("tutorial.dismiss"))
        } else if roll < 65 {
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

    /// A seeded reachable state: prepared with a random seed (levels 1 … 4), then 0 … 14 random actions.
    static func reachable(_ random: inout ColorfallCanyonsRandom,
                          dates: [[Double]]) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = UInt64(Self.below(Self.highestLevel, &random))
        var core: Core = try await Core.prepare(seed: seed)
        let count: Int = random.int(0...14)
        for _ in 0..<count { try Self.randomStep(&core, &random, dates: dates) }
        return (core, seed)
    }

    /// A seeded state with 1 … 3 certified wins (some daily) on levels 1 … 3, moved on with level.next after each, and
    /// the sound on or off.
    static func winner(_ random: inout ColorfallCanyonsRandom,
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

    // MARK: SC-R02G0507-001 — 500 seeded reachable states round-trip

    /// Round-trips `count` seeded states of generator stream `stream`; returns how many verified results, replay
    /// states, daily states, practice states and sound-on states they carried.
    static func roundTrips(stream: UInt64, count: Int) async throws
        -> (verified: Int, replays: Int, dailies: Int, practices: Int, sounds: Int) {
        let dates: [[Double]] = try Self.dailyDates()
        var random: ColorfallCanyonsRandom = ColorfallCanyonsRandom(seed: Self.baseSeed &+ stream)
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
            #expect(restored == state.core, "stream \(stream) state \(index)")
            #expect(try Self.digest(restored) == digest, "stream \(stream) state \(index)")
            #expect(restored.progress == state.core.progress && restored.mode == state.core.mode)
            #expect(restored.tutorial == state.core.tutorial, "stream \(stream) state \(index)")
            #expect(restored.soundOn == state.core.soundOn, "stream \(stream) state \(index)")
            #expect(restored.play.records == state.core.play.records)
            #expect(restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
            #expect(try restored.snapshotPayload() == payload, "stream \(stream) state \(index)")
            // The sound choice is state but never digested: toggling it changes `==` and the payload, not the digest.
            var toggled: Core = state.core
            let flipped: Double = state.core.soundOn ? 0 : 1
            #expect(toggled.apply(Self.act("settings.sound", [flipped])) == .accepted, "stream \(stream) \(index)")
            #expect(toggled.soundOn != state.core.soundOn && toggled != state.core, "stream \(stream) \(index)")
            #expect(try Self.digest(toggled) == digest, "stream \(stream) state \(index)")
            let toggledRestored: Core = try Core.restore(payload: try toggled.snapshotPayload(), seed: state.seed)
            #expect(toggledRestored == toggled && toggledRestored.soundOn == toggled.soundOn)
            #expect(try Self.digest(toggledRestored) == digest, "stream \(stream) state \(index)")
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

    @Test func roundTripsStates1To100() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int, sounds: Int) =
            try await Self.roundTrips(stream: 1, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0 && totals.dailies > 0 && totals.practices > 0)
        #expect(totals.sounds > 0 && totals.sounds < 100)
    }

    @Test func roundTripsStates101To200() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int, sounds: Int) =
            try await Self.roundTrips(stream: 2, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0 && totals.sounds > 0)
    }

    @Test func roundTripsStates201To300() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int, sounds: Int) =
            try await Self.roundTrips(stream: 3, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0 && totals.sounds > 0)
    }

    @Test func roundTripsStates301To400() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int, sounds: Int) =
            try await Self.roundTrips(stream: 4, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0 && totals.sounds > 0)
    }

    @Test func roundTripsStates401To500() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int, sounds: Int) =
            try await Self.roundTrips(stream: 5, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0 && totals.sounds > 0)
    }

    // MARK: SC-R02G0507-002 — schema 1 and schema 2 payloads migrate

    /// An engine prepared with seed 0 and active, ready to restore envelopes.
    static func activeEngine() async throws -> ExperienceEngine<Core> {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine: ExperienceEngine<Core> = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        return engine
    }

    /// Restores `object` as an envelope of schema `version` (seed `seed`) through `engine`; returns the engine's core.
    static func engineRestore(_ engine: inout ExperienceEngine<Core>, _ object: [String: Any], version: Int,
                              seed: UInt64, digest: StateDigest) throws -> Core {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        let envelope: ExperienceSnapshot = try ExperienceSnapshot(experience: id, schemaVersion: version, seed: seed,
                                                                  stepIndex: 0, digest: digest,
                                                                  payload: try Self.data(object))
        try engine.restore(envelope)
        return try #require(engine.core)
    }

    /// Migrates `count` seeded schema-1 payloads `{level, records}` of generator stream `stream` (campaign plays of
    /// random carves, valve toggles, steps, undo and redo, some with the sound on before saving).
    static func schemaOne(stream: UInt64, count: Int) async throws {
        var random: ColorfallCanyonsRandom = ColorfallCanyonsRandom(seed: Self.baseSeed &+ stream)
        var engine: ExperienceEngine<Core> = try await Self.activeEngine()
        for index in 0..<count {
            let seed: UInt64 = UInt64(Self.below(Self.highestLevel, &random))
            var core: Core = try await Core.prepare(seed: seed)
            let steps: Int = random.int(0...10)
            for _ in 0..<steps {
                let roll: Int = Self.below(20, &random)
                if roll < 8 {
                    _ = core.apply(Self.act("canyon.carve", [Double(random.int(0...119))]))
                } else if roll < 12 {
                    _ = core.apply(Self.act("canyon.valve", [Double(random.int(0...2))]))
                } else if roll < 15 {
                    _ = core.apply(Self.act("time.step", [Double(random.int(1...60))]))
                } else if roll < 18 {
                    _ = core.apply(Self.act("play.undo"))
                } else {
                    _ = core.apply(Self.act("play.redo"))
                }
            }
            if Self.below(2, &random) == 0 { _ = core.apply(Self.act("settings.sound", [1])) }
            let full: [String: Any] = try Self.object(try core.snapshotPayload())
            var old: [String: Any] = [:]
            old["level"] = full["level"]
            old["records"] = full["records"]
            let migrated: [String: Any] = try Core.migrations.migrate(old, from: 1)
            let restored: Core = try Core.restore(payload: try Self.data(migrated), seed: seed)
            var expected: ColorfallCanyonsProgress = ColorfallCanyonsProgress()
            expected.open(through: core.levelNumber)
            #expect(restored.levelNumber == core.levelNumber, "stream \(stream) state \(index)")
            #expect(restored.play.records == core.play.records && restored.play == core.play)
            #expect(restored.mode == .campaign && restored.progress == expected, "stream \(stream) state \(index)")
            #expect(restored.progress.frontier == core.progress.frontier, "stream \(stream) state \(index)")
            #expect(restored.tutorial == ColorfallCanyonsTutorialStep.initial(level: core.levelNumber))
            #expect(!restored.soundOn && restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
            // Without a win the schema-1 state's progress is exactly what migration rebuilds.
            #expect(restored.progress == core.progress, "stream \(stream) state \(index)")
            #expect(try Self.digest(restored) == Self.digest(core), "stream \(stream) state \(index)")
            // The engine applies the same chain to a schema-1 envelope.
            let viaEngine: Core = try Self.engineRestore(&engine, old, version: 1, seed: seed,
                                                         digest: try Self.digest(core))
            #expect(viaEngine == restored && !viaEngine.soundOn, "stream \(stream) state \(index)")
            #expect(try Self.digest(viaEngine) == Self.digest(restored), "stream \(stream) state \(index)")
        }
    }

    @Test func schemaOnePayloads1To50Migrate() async throws {
        try await Self.schemaOne(stream: 11, count: 50)
    }

    @Test func schemaOnePayloads51To100Migrate() async throws {
        try await Self.schemaOne(stream: 12, count: 50)
    }

    /// Migrates `count` seeded schema-2 payloads of generator stream `stream` (states with traced results, the sound on
    /// or off); returns how many results were carried over.
    static func schemaTwo(stream: UInt64, count: Int) async throws -> Int {
        let dates: [[Double]] = try Self.dailyDates()
        var random: ColorfallCanyonsRandom = ColorfallCanyonsRandom(seed: Self.baseSeed &+ stream)
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
            let migrated: [String: Any] = try Core.migrations.migrate(object, from: 2)
            let restored: Core = try Core.restore(payload: try Self.data(migrated), seed: state.seed)
            #expect(restored.progress.frontier == core.progress.frontier, "stream \(stream) state \(index)")
            #expect(restored.progress.solved.keys.sorted() == core.progress.solved.keys.sorted())
            for (level, result) in core.progress.solved {
                let kept: ColorfallCanyonsProgress.Result = try #require(restored.progress.solved[level])
                #expect(kept.bestActions == result.bestActions && kept.stars == result.stars, "level \(level)")
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
            let viaEngine: Core = try Self.engineRestore(&engine, object, version: 2, seed: state.seed,
                                                         digest: try Self.digest(core))
            #expect(viaEngine == restored && !viaEngine.soundOn, "stream \(stream) state \(index)")
            #expect(try Self.digest(viaEngine) == Self.digest(restored), "stream \(stream) state \(index)")
        }
        return results
    }

    @Test func schemaTwoPayloads1To50MigrateUnverified() async throws {
        let results: Int = try await Self.schemaTwo(stream: 21, count: 50)
        #expect(results >= 50)
    }

    @Test func schemaTwoPayloads51To100MigrateUnverified() async throws {
        let results: Int = try await Self.schemaTwo(stream: 22, count: 50)
        #expect(results >= 50)
    }

    // MARK: SC-R02G0507-003 — honest results survive, edited ones are dropped and counted

    /// `entry` (a traced result) edited by `edit`. Each edit fails the check for a reason that does not depend on the
    /// code under test: the stars or actions differ from the honest replay's, a trace without its last action (the step
    /// that reached the win; a won play accepts nothing more, so it is the winning one) never ends won, and `step(0)` is
    /// never a legal action.
    static func edited(_ entry: [String: Any], _ edit: Edit,
                       _ random: inout ColorfallCanyonsRandom) throws -> [String: Any] {
        var changed: [String: Any] = entry
        let stars: Int = try #require(entry["stars"] as? Int)
        let best: Int = try #require(entry["bestActions"] as? Int)
        var trace: [Any] = try #require(entry["trace"] as? [Any])
        #expect(!trace.isEmpty)
        switch edit {
        case .stars:
            // Raised when it can be; a three-star result is lowered instead (stars stay in 1 … 3, or decoding fails).
            changed["stars"] = stars < 3 ? stars + 1 : 2
        case .bestActions:
            changed["bestActions"] = Self.below(2, &random) == 0 || best <= 1 ? best + 1 : best - 1
        case .winningStepRemoved:
            trace.removeLast()
            changed["trace"] = trace
        case .illegalAction:
            trace[Self.below(trace.count, &random)] = try Self.json(.step(0))
            changed["trace"] = trace
        }
        return changed
    }

    /// Checks `count` seeded saves of generator stream `stream`; returns (honest, edited) totals.
    static func reconciledSaves(stream: UInt64, count: Int) async throws -> (honest: Int, edited: Int) {
        let dates: [[Double]] = try Self.dailyDates()
        var random: ColorfallCanyonsRandom = ColorfallCanyonsRandom(seed: Self.baseSeed &+ stream)
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
            var honest: [Int: ColorfallCanyonsProgress.Result] = [:]
            var editedCount: Int = 0
            for entry in solved {
                let level: Int = try #require(entry["level"] as? Int)
                let saved: ColorfallCanyonsProgress.Result = try #require(core.progress.solved[level])
                #expect(saved.verified && !saved.trace.isEmpty, "level \(level)")
                let roll: Int = Self.below(5, &random)
                if roll < 2 {
                    let edit: Edit = edits[Self.below(edits.count, &random)]
                    entries.append(try Self.edited(entry, edit, &random))
                    editedCount += 1
                } else if roll < 3 {
                    // An honest untraced result (as written before schema 3): kept, unverified.
                    var untraced: [String: Any] = entry
                    untraced["trace"] = [Any]()
                    untraced["verified"] = false
                    entries.append(untraced)
                    honest[level] = ColorfallCanyonsProgress.Result(bestActions: saved.bestActions, stars: saved.stars)
                } else {
                    entries.append(entry)
                    honest[level] = saved
                }
            }
            progress["solved"] = entries
            object["progress"] = progress
            let restored: Core = try Core.restore(payload: try Self.data(object), seed: state.seed)
            #expect(restored.reconciliationDropped == editedCount, "stream \(stream) save \(index)")
            #expect(restored.progress.solved.keys.sorted() == honest.keys.sorted(), "stream \(stream) save \(index)")
            for (level, result) in honest {
                #expect(restored.progress.solved[level] == result, "stream \(stream) save \(index) level \(level)")
            }
            #expect(restored.progress.frontier == core.progress.frontier, "stream \(stream) save \(index)")
            #expect(restored.levelNumber == core.levelNumber && restored.play == core.play)
            #expect(restored.mode == core.mode && restored.tutorial == core.tutorial)
            #expect(restored.soundOn == core.soundOn, "stream \(stream) save \(index)")
            honestTotal += honest.count
            editedTotal += editedCount
        }
        return (honestTotal, editedTotal)
    }

    @Test func saves1To50ReconcileExactly() async throws {
        let totals: (honest: Int, edited: Int) = try await Self.reconciledSaves(stream: 31, count: 50)
        #expect(totals.honest > 0 && totals.edited > 0)
    }

    @Test func saves51To100ReconcileExactly() async throws {
        let totals: (honest: Int, edited: Int) = try await Self.reconciledSaves(stream: 32, count: 50)
        #expect(totals.honest > 0 && totals.edited > 0)
    }

    @Test func saves101To150ReconcileExactly() async throws {
        let totals: (honest: Int, edited: Int) = try await Self.reconciledSaves(stream: 33, count: 50)
        #expect(totals.honest > 0 && totals.edited > 0)
    }

    @Test func saves151To200ReconcileExactly() async throws {
        let totals: (honest: Int, edited: Int) = try await Self.reconciledSaves(stream: 34, count: 50)
        #expect(totals.honest > 0 && totals.edited > 0)
    }

    // MARK: FR-R02G0507-005 — deterministic restore and daily level

    @Test func theSamePayloadRestoresTwiceToEqualDigests() async throws {
        let dates: [[Double]] = try Self.dailyDates()
        var random: ColorfallCanyonsRandom = ColorfallCanyonsRandom(seed: Self.baseSeed &+ 41)
        for index in 0..<50 {
            let state: (core: Core, seed: UInt64) = index % 2 == 0
                ? try await Self.reachable(&random, dates: dates) : try await Self.winner(&random, dates: dates)
            let payload: Data = try state.core.snapshotPayload()
            let first: Core = try Core.restore(payload: payload, seed: state.seed)
            let second: Core = try Core.restore(payload: payload, seed: state.seed)
            #expect(try Self.digest(first) == Self.digest(second), "state \(index)")
            #expect(first == second && first.reconciliationDropped == second.reconciliationDropped, "state \(index)")
            #expect(try first.snapshotPayload() == second.snapshotPayload(), "state \(index)")
        }
    }

    @Test func theDailyLevelDependsOnlyOnTheDate() async throws {
        var dates: [[Int]] = [[2026, 1, 1], [2026, 11, 21], [2025, 12, 31], [2024, 2, 29], [2030, 7, 4],
                              [2000, 3, 1], [2099, 12, 31], [1970, 1, 1]]
        for date in try Self.dailyDates() {
            var whole: [Int] = []
            for value in date { whole.append(Int(value)) }
            dates.append(whole)
        }
        // 400 consecutive days from 2026-01-01 visit every level and agree with the independent count.
        var seen: Set<Int> = []
        for offset in 0..<400 {
            let days: Int = Self.epochDays + offset
            let date: Date = Date(timeIntervalSince1970: Double(days) * 86_400)
            var calendar: Calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
            let parts: DateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let year: Int = try #require(parts.year)
            let monthValue: Int = try #require(parts.month)
            let day: Int = try #require(parts.day)
            let level: Int? = ColorfallCanyonsProgress.dailyLevel(year: year, month: monthValue, day: day)
            #expect(level == (offset * 53) % 100 + 1, "\(year)-\(monthValue)-\(day)")
            if let level { seen.insert(level) }
        }
        #expect(seen.count == 100)
        var cores: [Core] = []
        for seed: UInt64 in [0, 1, 2, 3] { cores.append(try await Core.prepare(seed: seed)) }
        var won: Core = try await Core.prepare(seed: 0)
        try Self.win(&won, detour: 0, dates: try Self.dailyDates())
        #expect(!won.progress.solved.isEmpty)
        _ = won.apply(Self.act("settings.sound", [1]))
        cores.append(won)
        for date in dates {
            let expected: Int = try Self.expectedDaily(date[0], date[1], date[2])
            let first: Int? = ColorfallCanyonsProgress.dailyLevel(year: date[0], month: date[1], day: date[2])
            let second: Int? = ColorfallCanyonsProgress.dailyLevel(year: date[0], month: date[1], day: date[2])
            #expect(first == expected && second == expected, "\(date)")
            // Only levels 1 … 4 are opened through the adapter (generating any other level runs the solver).
            guard expected <= Self.highestLevel else { continue }
            for var core in cores {
                let values: [Double] = [Double(date[0]), Double(date[1]), Double(date[2])]
                #expect(core.apply(Self.act("mode.daily", values)) == .accepted, "\(date)")
                #expect(core.levelNumber == expected && core.mode == .daily(level: expected), "\(date)")
            }
        }
    }

    // MARK: SC-R02G0507-004 — every stored trace of the 100 certified levels replays

    /// The repository's witness directory, found from this file.
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/colorfall-canyons/levels", isDirectory: true)

    /// The stored actions and recorded play fingerprints of level `number`'s witness file, read as JSON (not
    /// re-verified here; the catalog tests verify the files).
    static func storedWitness(_ number: Int) throws -> (actions: [ColorfallCanyonsAction], fingerprints: [String]) {
        let name: String = String(ColorfallCanyonsGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: Self.witnessDirectory.appendingPathComponent(name))
        let object: [String: Any] = try Self.object(data)
        #expect(object["number"] as? Int == number, "\(name)")
        let actionsJSON: Any = try #require(object["actions"])
        let actionsData: Data = try JSONSerialization.data(withJSONObject: actionsJSON)
        let actions: [ColorfallCanyonsAction] = try JSONDecoder().decode([ColorfallCanyonsAction].self,
                                                                         from: actionsData)
        let fingerprints: [String] = try #require(object["fingerprints"] as? [String])
        return (actions, fingerprints)
    }

    /// Wins each level of `numbers` with its stored witness actions in a campaign play, then replays the stored trace
    /// through `replay.start` and `replay.step` against the recorded fingerprints; returns the replayed actions.
    static func replays(_ numbers: ClosedRange<Int>) throws -> Int {
        var replayed: Int = 0
        for number in numbers {
            let stored: (actions: [ColorfallCanyonsAction], fingerprints: [String]) = try Self.storedWitness(number)
            #expect(stored.fingerprints.count == stored.actions.count + 1, "level \(number)")
            var core: Core = try Core.opening(number: number)
            #expect(core.play.fingerprint == stored.fingerprints.first, "level \(number) opening")
            for kernel in stored.actions {
                #expect(core.apply(Self.action(kernel)) == .accepted, "level \(number) \(kernel)")
            }
            #expect(core.play.stage == .won, "level \(number) is not won by its stored actions")
            let result: ColorfallCanyonsProgress.Result = try #require(core.progress.solved[number])
            #expect(result.verified && result.trace == stored.actions, "level \(number) stored trace")
            #expect(ColorfallCanyonsReconciliation.verifies(level: number, result: result), "level \(number)")
            _ = core.apply(Self.act("settings.sound", [Double(number % 2)]))
            let progress: ColorfallCanyonsProgress = core.progress
            let progressData: Data = try progress.encoded()
            #expect(core.apply(Self.act("replay.start", [Double(number)])) == .accepted, "level \(number)")
            #expect(core.mode == .replay(level: number) && core.tutorial == .done, "level \(number)")
            #expect(core.play.fingerprint == stored.fingerprints[0], "level \(number) replay start")
            for position in 0..<stored.actions.count {
                #expect(core.apply(Self.act("replay.step")) == .accepted, "level \(number) step \(position)")
                #expect(core.play.fingerprint == stored.fingerprints[position + 1], "level \(number) \(position)")
                #expect(core.progress == progress, "level \(number) step \(position)")
                replayed += 1
            }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number) replay end")
            let end: ActionResult = .rejected(.rule(code: ColorfallCanyonsExperienceRule.replayEnd))
            #expect(core.apply(Self.act("replay.step")) == end, "level \(number)")
            let progressAfter: Data = try core.progress.encoded()
            #expect(core.progress == progress && progressAfter == progressData, "level \(number)")
            #expect(core.apply(Self.act("replay.stop")) == .accepted, "level \(number)")
            #expect(core.mode == .campaign && core.levelNumber == number && core.progress == progress)
            #expect(core.soundOn == (number % 2 == 1), "level \(number)")
        }
        return replayed
    }

    /// Five levels per test (the first generation of a band-4 or band-5 level runs the solver), so each stays short.
    @Test(arguments: [1, 6, 11, 16, 21, 26, 31, 36, 41, 46, 51, 56, 61, 66, 71, 76, 81, 86, 91, 96])
    func storedTracesOfFiveLevelsReplay(first: Int) throws {
        #expect(try Self.replays(first...(first + 4)) >= 5)
    }
}
