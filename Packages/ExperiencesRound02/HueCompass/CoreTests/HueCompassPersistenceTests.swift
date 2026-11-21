// HueCompassPersistenceTests — feature 337 (R02-G04-07) T-R02G0407-004 (FR-R02G0407-001 … 003, 005;
// SC-R02G0407-001 … 003). Host checks of Hue Compass's persistence through the adapter core:
//   - 500 seeded reachable states (random walks of compass.turn, compass.probe, compass.select, undo, redo, level.next,
//     level.select of open levels, mode.daily, mode.practice, mode.campaign, tutorial.dismiss, certified wins played
//     from `HueCompassWitness.actions` and replay start, step and stop) round-trip through `snapshotPayload()` and
//     `restore(payload:seed:)` with equal states, digests, progress, mode and tutorial step, identical payload bytes
//     and nothing dropped;
//   - 100 seeded states as schema-1 payloads `{level, records}` and 100 as schema-2 payloads (the schema-3 payload with
//     `trace` and `verified` removed from each solved entry) migrate through `migrations` (1 → 2 → 3 and 2 → 3, the
//     chain the engine applies) and restore with the progress kept (schema 1: the saved level open, campaign mode, the
//     initial tutorial step; schema 2: results unverified with empty traces, the frontier as saved);
//   - 200 seeded saves with traced results: honest results (and honest untraced ones) survive restore; edited ones
//     (stars changed, best units changed, the selection's band shifted by 12 so it misses, a step replaced by a turn of
//     0, which the kernel never accepts) are dropped and counted exactly, and the frontier stays as saved;
//   - FR-R02G0407-005: one payload restores twice to equal digests; the daily level of a date is the same on repeated
//     calls, equals (days since 2026-01-01 × 47) mod 100 + 1 counted here independently, and does not depend on the
//     seed, the level or the progress of the core it is chosen from.
// Synthetic data, explicit types, plain loops, no sleep. The states come from `HueCompassRandom` (SplitMix64) seeded
// with 2_337; edited saves are made by editing the payload's JSON, as a tampered file would be.
//
// Speed: certifying a level runs the solver (generated once per process and cached). So the states stay on a few low
// levels: the seeds are 0 … 3 (levels 1 … 4), certified wins are played only on levels 1 … 3 and the daily dates are
// the four in 2026 whose daily level is 1 … 4; level.next and level.select never pass level 4.
import Foundation
import Testing
@testable import HueCompassCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct HueCompassPersistenceTests {
    typealias Core = HueCompassExperienceCore

    /// The seed of every generator in this file.
    static let baseSeed: UInt64 = 2_337

    /// The highest level a state may reach (see the file header).
    static let highestLevel: Int = 4

    /// The highest level a win is played on, so the frontier never passes ``highestLevel``.
    static let highestWin: Int = 3

    /// The days from 1970-01-01 to 2026-01-01 (20 454), the daily epoch.
    static let epochDays: Int = 20_454

    /// The kinds of edit made to a saved result.
    enum Edit: CaseIterable {
        case stars
        case bestUnits
        case selectionBand
        case zeroTurn
    }

    // MARK: Helpers

    /// A value in 0 ..< `bound` (bound > 0).
    static func below(_ bound: Int, _ random: inout HueCompassRandom) -> Int {
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
    static func action(_ kernel: HueCompassAction) -> ExperienceAction {
        switch kernel {
        case .turn(let steps): Self.act("compass.turn", [Double(steps)])
        case .probe: Self.act("compass.probe")
        case .select(let bearing, let band): Self.act("compass.select", [Double(bearing), Double(band)])
        }
    }

    /// The days from 1970-01-01 to a proleptic Gregorian date, counted with Foundation's UTC calendar (independent of
    /// the code under test).
    static func foundationDays(_ year: Int, _ month: Int, _ day: Int) throws -> Int {
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let date: Date = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        return Int((date.timeIntervalSince1970 / 86_400).rounded())
    }

    /// The daily level of a date by the rule of the spec, counted here: (days since 2026-01-01 × 47) mod 100 + 1.
    static func expectedDaily(_ year: Int, _ month: Int, _ day: Int) throws -> Int {
        let days: Int = try Self.foundationDays(year, month, day) - Self.epochDays
        return ((days * 47) % 100 + 100) % 100 + 1
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
    static func json(_ kernel: HueCompassAction) throws -> Any {
        try JSONSerialization.jsonObject(with: try JSONEncoder().encode(kernel), options: [.fragmentsAllowed])
    }

    /// The kernel action of a JSON trace step.
    static func kernel(_ step: Any) throws -> HueCompassAction {
        let data: Data = try JSONSerialization.data(withJSONObject: step, options: [.fragmentsAllowed])
        return try JSONDecoder().decode(HueCompassAction.self, from: data)
    }

    /// Re-opens the current level fresh in its mode (campaign, practice or daily), then plays its certified witness
    /// actions, optionally after a detour (`1`: a turn and its undo, net actions = the witness; `2`: a turn and the
    /// turn back, two more net turns; `3`: an extra probe first when the allowance leaves room, one more unit). Does
    /// nothing in replay mode or above ``highestWin``.
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
        let generated: HueCompassGenerated = try Core.generated(number: core.levelNumber)
        let witness: [HueCompassAction] = HueCompassWitness.actions(for: generated.solution, level: generated.level)
        let units: Int = witness.filter { !Self.isTurn($0) }.count
        switch detour {
        case 1:
            _ = core.apply(Self.act("compass.turn", [7]))
            _ = core.apply(Self.act("play.undo"))
        case 2:
            _ = core.apply(Self.act("compass.turn", [5]))
            _ = core.apply(Self.act("compass.turn", [-5]))
        case 3:
            if units + 1 < core.play.level.allowance { _ = core.apply(Self.act("compass.probe")) }
        default:
            break
        }
        for kernel in witness { _ = core.apply(Self.action(kernel)) }
    }

    /// Whether `kernel` is a turn.
    static func isTurn(_ kernel: HueCompassAction) -> Bool {
        if case .turn = kernel { return true }
        return false
    }

    /// One random action (legal or refused) on `core`; level changes and wins are rarer than turns.
    static func randomStep(_ core: inout Core, _ random: inout HueCompassRandom, dates: [[Double]]) throws {
        let roll: Int = Self.below(100, &random)
        if case .replay = core.mode {
            if roll < 70 {
                _ = core.apply(Self.act("replay.step"))
            } else if roll < 85 {
                _ = core.apply(Self.act("replay.stop"))
            } else if roll < 92 {
                _ = core.apply(Self.act("tutorial.dismiss"))
            } else {
                _ = core.apply(Self.act("compass.turn", [Double(random.int(-48...48))]))
            }
            return
        }
        if roll < 30 {
            _ = core.apply(Self.act("compass.turn", [Double(random.int(-48...48))]))
        } else if roll < 36 {
            _ = core.apply(Self.act("compass.probe"))
        } else if roll < 38 {
            _ = core.apply(Self.act("compass.select", [Double(random.int(0...95)), Double(random.int(0...23))]))
        } else if roll < 46 {
            _ = core.apply(Self.act("play.undo"))
        } else if roll < 51 {
            _ = core.apply(Self.act("play.redo"))
        } else if roll < 54 {
            if core.levelNumber < Self.highestLevel { _ = core.apply(Self.act("level.next")) }
        } else if roll < 57 {
            let top: Int = min(core.progress.frontier, Self.highestLevel)
            _ = core.apply(Self.act("level.select", [Double(random.int(1...top))]))
        } else if roll < 60 {
            _ = core.apply(Self.act("mode.practice"))
        } else if roll < 63 {
            _ = core.apply(Self.act("mode.campaign"))
        } else if roll < 66 {
            _ = core.apply(Self.act("mode.daily", dates[Self.below(dates.count, &random)]))
        } else if roll < 69 {
            _ = core.apply(Self.act("tutorial.dismiss"))
        } else if roll < 86 {
            try Self.win(&core, detour: Self.below(4, &random), dates: dates)
        } else {
            let verified: [Int] = core.progress.solved.keys.sorted().filter { level in
                core.progress.solved[level]?.verified == true
            }
            let level: Int = verified.isEmpty ? random.int(1...Self.highestLevel)
                : verified[Self.below(verified.count, &random)]
            _ = core.apply(Self.act("replay.start", [Double(level)]))
        }
    }

    /// A seeded reachable state: prepared with a random seed (levels 1 … 4), then 0 … 14 random actions.
    static func reachable(_ random: inout HueCompassRandom,
                          dates: [[Double]]) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = UInt64(Self.below(Self.highestLevel, &random))
        var core: Core = try await Core.prepare(seed: seed)
        let count: Int = random.int(0...14)
        for _ in 0..<count { try Self.randomStep(&core, &random, dates: dates) }
        return (core, seed)
    }

    /// A seeded state with 1 … 3 certified wins (some daily) on levels 1 … 3, moved on with level.next after each.
    static func winner(_ random: inout HueCompassRandom, dates: [[Double]]) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = UInt64(Self.below(Self.highestWin, &random))
        var core: Core = try await Core.prepare(seed: seed)
        let wins: Int = random.int(1...3)
        for _ in 0..<wins {
            if Self.below(4, &random) == 0 {
                _ = core.apply(Self.act("mode.daily", dates[Self.below(Self.highestWin, &random)]))
            }
            try Self.win(&core, detour: Self.below(4, &random), dates: dates)
            if core.levelNumber < Self.highestLevel { _ = core.apply(Self.act("level.next")) }
        }
        return (core, seed)
    }

    // MARK: SC-R02G0407-001 — 500 seeded reachable states round-trip

    /// Round-trips `count` seeded states of generator stream `stream`; returns how many verified results, replay
    /// states, daily states and practice states they carried.
    static func roundTrips(stream: UInt64, count: Int) async throws
        -> (verified: Int, replays: Int, dailies: Int, practices: Int) {
        let dates: [[Double]] = try Self.dailyDates()
        var random: HueCompassRandom = HueCompassRandom(seed: Self.baseSeed &+ stream)
        var verified: Int = 0
        var replays: Int = 0
        var dailies: Int = 0
        var practices: Int = 0
        for index in 0..<count {
            let state: (core: Core, seed: UInt64) = try await Self.reachable(&random, dates: dates)
            let payload: Data = try state.core.snapshotPayload()
            let restored: Core = try Core.restore(payload: payload, seed: state.seed)
            #expect(restored == state.core, "stream \(stream) state \(index)")
            #expect(try Self.digest(restored) == Self.digest(state.core), "stream \(stream) state \(index)")
            #expect(restored.progress == state.core.progress && restored.mode == state.core.mode)
            #expect(restored.tutorial == state.core.tutorial, "stream \(stream) state \(index)")
            #expect(restored.play.records == state.core.play.records)
            #expect(restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
            #expect(try restored.snapshotPayload() == payload, "stream \(stream) state \(index)")
            for result in state.core.progress.solved.values where result.verified { verified += 1 }
            switch state.core.mode {
            case .replay: replays += 1
            case .daily: dailies += 1
            case .practice: practices += 1
            case .campaign: break
            }
        }
        return (verified, replays, dailies, practices)
    }

    @Test func roundTripsStates1To100() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 1, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0 && totals.dailies > 0 && totals.practices > 0)
    }

    @Test func roundTripsStates101To200() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 2, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0)
    }

    @Test func roundTripsStates201To300() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 3, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0)
    }

    @Test func roundTripsStates301To400() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 4, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0)
    }

    @Test func roundTripsStates401To500() async throws {
        let totals: (verified: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 5, count: 100)
        #expect(totals.verified > 0 && totals.replays > 0)
    }

    // MARK: SC-R02G0407-002 — schema 1 and schema 2 payloads migrate

    /// Migrates `count` seeded schema-1 payloads `{level, records}` of generator stream `stream` (campaign plays of
    /// random turns, probes, selections, undo and redo).
    static func schemaOne(stream: UInt64, count: Int) async throws {
        var random: HueCompassRandom = HueCompassRandom(seed: Self.baseSeed &+ stream)
        for index in 0..<count {
            let seed: UInt64 = UInt64(Self.below(Self.highestLevel, &random))
            var core: Core = try await Core.prepare(seed: seed)
            let steps: Int = random.int(0...10)
            for _ in 0..<steps {
                let roll: Int = Self.below(20, &random)
                if roll < 12 {
                    _ = core.apply(Self.act("compass.turn", [Double(random.int(-48...48))]))
                } else if roll < 15 {
                    _ = core.apply(Self.act("compass.probe"))
                } else if roll < 16 {
                    _ = core.apply(Self.act("compass.select", [Double(random.int(0...95)), Double(random.int(0...23))]))
                } else if roll < 18 {
                    _ = core.apply(Self.act("play.undo"))
                } else {
                    _ = core.apply(Self.act("play.redo"))
                }
            }
            let full: [String: Any] = try Self.object(try core.snapshotPayload())
            var old: [String: Any] = [:]
            old["level"] = full["level"]
            old["records"] = full["records"]
            let migrated: [String: Any] = try Core.migrations.migrate(old, from: 1)
            let restored: Core = try Core.restore(payload: try Self.data(migrated), seed: seed)
            var expected: HueCompassProgress = HueCompassProgress()
            expected.open(through: core.levelNumber)
            #expect(restored.levelNumber == core.levelNumber, "stream \(stream) state \(index)")
            #expect(restored.play.records == core.play.records && restored.play == core.play)
            #expect(restored.mode == .campaign && restored.progress == expected, "stream \(stream) state \(index)")
            #expect(restored.tutorial == HueCompassTutorialStep.initial(level: core.levelNumber))
            if core.progress.solved.isEmpty {
                // Without a win the schema-1 state's progress is exactly what migration rebuilds.
                #expect(restored.progress == core.progress, "stream \(stream) state \(index)")
                #expect(try Self.digest(restored) == Self.digest(core), "stream \(stream) state \(index)")
            }
            #expect(restored.reconciliationDropped == 0)
        }
    }

    @Test func schemaOnePayloads1To50Migrate() async throws {
        try await Self.schemaOne(stream: 11, count: 50)
    }

    @Test func schemaOnePayloads51To100Migrate() async throws {
        try await Self.schemaOne(stream: 12, count: 50)
    }

    /// Migrates `count` seeded schema-2 payloads of generator stream `stream` (states with traced results).
    static func schemaTwo(stream: UInt64, count: Int) async throws {
        let dates: [[Double]] = try Self.dailyDates()
        var random: HueCompassRandom = HueCompassRandom(seed: Self.baseSeed &+ stream)
        for index in 0..<count {
            var state: (core: Core, seed: UInt64) = try await Self.winner(&random, dates: dates)
            let steps: Int = random.int(0...4)
            for _ in 0..<steps { try Self.randomStep(&state.core, &random, dates: dates) }
            let core: Core = state.core
            #expect(!core.progress.solved.isEmpty, "stream \(stream) state \(index)")
            var object: [String: Any] = try Self.object(try core.snapshotPayload())
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
                let kept: HueCompassProgress.Result = try #require(restored.progress.solved[level])
                #expect(kept.bestUnits == result.bestUnits && kept.stars == result.stars, "level \(level)")
                #expect(!kept.verified && kept.trace.isEmpty, "level \(level)")
            }
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
            #expect(restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
        }
    }

    @Test func schemaTwoPayloads1To50MigrateUnverified() async throws {
        try await Self.schemaTwo(stream: 21, count: 50)
    }

    @Test func schemaTwoPayloads51To100MigrateUnverified() async throws {
        try await Self.schemaTwo(stream: 22, count: 50)
    }

    // MARK: SC-R02G0407-003 — honest results survive, edited ones are dropped and counted

    /// `entry` (a traced result) edited by `edit`. Each edit fails the check for a reason that does not depend on the
    /// code under test: the stars or units differ from the honest replay's, a selection band 12 away from a winning one
    /// misses (band tolerances are at most 2 of 24 bands, so the new band is at least 10 bands from the target), and a
    /// turn of 0 is never a legal action.
    static func edited(_ entry: [String: Any], _ edit: Edit,
                       _ random: inout HueCompassRandom) throws -> [String: Any] {
        var changed: [String: Any] = entry
        let stars: Int = try #require(entry["stars"] as? Int)
        let best: Int = try #require(entry["bestUnits"] as? Int)
        var trace: [Any] = try #require(entry["trace"] as? [Any])
        switch edit {
        case .stars:
            // Raised when it can be; a three-star result is lowered instead (stars stay in 1 … 3, or decoding fails).
            changed["stars"] = stars < 3 ? stars + 1 : 2
        case .bestUnits:
            changed["bestUnits"] = Self.below(2, &random) == 0 || best <= 1 ? best + 1 : best - 1
        case .selectionBand:
            var index: Int? = nil
            for position in trace.indices {
                if case .select = try Self.kernel(trace[position]) { index = position }
            }
            let position: Int = try #require(index, "a winning trace ends with its selection")
            guard case .select(let bearing, let band) = try Self.kernel(trace[position]) else {
                Issue.record("not a selection")
                return changed
            }
            trace[position] = try Self.json(.select(bearing: bearing, band: (band + 12) % 24))
            changed["trace"] = trace
        case .zeroTurn:
            trace[Self.below(trace.count, &random)] = try Self.json(.turn(0))
            changed["trace"] = trace
        }
        return changed
    }

    /// Checks `count` seeded saves of generator stream `stream`; returns (honest, edited) totals.
    static func reconciledSaves(stream: UInt64, count: Int) async throws -> (honest: Int, edited: Int) {
        let dates: [[Double]] = try Self.dailyDates()
        var random: HueCompassRandom = HueCompassRandom(seed: Self.baseSeed &+ stream)
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
            var honest: [Int: HueCompassProgress.Result] = [:]
            var editedCount: Int = 0
            for entry in solved {
                let level: Int = try #require(entry["level"] as? Int)
                let saved: HueCompassProgress.Result = try #require(core.progress.solved[level])
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
                    honest[level] = HueCompassProgress.Result(bestUnits: saved.bestUnits, stars: saved.stars)
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

    // MARK: FR-R02G0407-005 — deterministic restore and daily level

    @Test func theSamePayloadRestoresTwiceToEqualDigests() async throws {
        let dates: [[Double]] = try Self.dailyDates()
        var random: HueCompassRandom = HueCompassRandom(seed: Self.baseSeed &+ 41)
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
        for date in try Self.dailyDates() { dates.append(date.map { Int($0) }) }
        var cores: [Core] = []
        for seed: UInt64 in [0, 1, 2, 3] { cores.append(try await Core.prepare(seed: seed)) }
        var won: Core = try await Core.prepare(seed: 0)
        try Self.win(&won, detour: 0, dates: try Self.dailyDates())
        #expect(!won.progress.solved.isEmpty)
        cores.append(won)
        for date in dates {
            let expected: Int = try Self.expectedDaily(date[0], date[1], date[2])
            let first: Int? = HueCompassProgress.dailyLevel(year: date[0], month: date[1], day: date[2])
            let second: Int? = HueCompassProgress.dailyLevel(year: date[0], month: date[1], day: date[2])
            #expect(first == expected && second == expected, "\(date)")
            // Only levels 1 … 4 are opened through the adapter (generating any other level runs the solver).
            guard expected <= Self.highestLevel else { continue }
            for var core in cores {
                let values: [Double] = date.map { Double($0) }
                #expect(core.apply(Self.act("mode.daily", values)) == .accepted, "\(date)")
                #expect(core.levelNumber == expected && core.mode == .daily(level: expected), "\(date)")
            }
        }
    }
}
