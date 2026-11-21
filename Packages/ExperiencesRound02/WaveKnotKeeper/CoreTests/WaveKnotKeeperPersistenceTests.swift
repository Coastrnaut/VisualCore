// WaveKnotKeeperPersistenceTests — feature 327 (R02-G03-07) T-R02G0307-004 (FR-R02G0307-001 … 003;
// SC-R02G0307-001 … 003). Host checks of Wave Knot Keeper's persistence through the adapter core:
//   - 500 seeded reachable states (random walks of point.move, point.select, undo, redo, level.next, level.select of
//     open levels, mode.daily, mode.practice, mode.campaign, tutorial actions, certified wins with traced results and
//     replay start, step and stop) round-trip through `snapshotPayload()` and `restore(payload:seed:)` with equal
//     states, equal digests, equal progress, mode and tutorial step, identical payload bytes and nothing dropped;
//   - 100 seeded states as schema-1 payloads `{level, records}` and 100 as schema-2 payloads (the schema-3 payload with
//     `trace` and `verified` removed from each solved entry) migrate through `migrations` (1 → 2 → 3 and 2 → 3, the
//     chain the engine applies) and restore with the progress kept (schema 1: the saved level open, campaign mode, the
//     first tutorial step; schema 2: results unverified with empty traces, the frontier as saved);
//   - 200 seeded saves with traced results: honest results (and honest untraced ones) survive restore with
//     `reconciliationDropped` 0 for them; edited ones (stars changed, best moves changed, one trace step replaced by a
//     move the kernel refuses there, a trace step removed) are dropped and counted exactly, and the frontier stays as
//     saved.
// Synthetic data, explicit types, plain loops, no sleep. The states come from an in-file SplitMix64 seeded with 2_327;
// edited saves are made by editing the payload's JSON, as a tampered file would be.
//
// Speed: certifying a level costs 0.1 … 2 s in a debug build (generated once per process and cached), and a campaign
// play of levels 1 … 3 runs the hint solver for its first tutorial step. So the states stay on a few low levels: the
// seeds are 0 … 3 (levels 1 … 4), certified wins are played only on levels 1 … 3, and the daily dates are the four whose
// daily level is 1 … 4 ((days × 43) mod 100 + 1 with days 0, 7, 14, 21 from 2026-01-01); only a rare random walk that
// happens to win level 4 opens level 5.
import Foundation
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// A small deterministic generator (SplitMix64) for the seeded states of these tests.
struct WaveKnotKeeperSplitMix {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// The next 64 random bits.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
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
        range.lowerBound + below(range.upperBound - range.lowerBound + 1)
    }
}

@Suite struct WaveKnotKeeperPersistenceTests {
    typealias Core = WaveKnotKeeperExperienceCore

    /// The seed of every generator in this file.
    static let baseSeed: UInt64 = 2_327

    /// The highest level a state may reach (see the file header).
    static let highestLevel: Int = 4

    /// The highest level a win is played on, so the frontier never passes ``highestLevel``.
    static let highestWin: Int = 3

    /// The daily dates whose daily levels are 1, 2, 3 and 4.
    static let dailyDates: [[Double]] = [[2026, 1, 1], [2026, 1, 8], [2026, 1, 15], [2026, 1, 22]]

    /// The kinds of edit made to a saved result.
    enum Edit: CaseIterable {
        case stars
        case bestMoves
        case traceStep
        case traceRemoved
    }

    // MARK: Helpers

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The `point.move` action for a kernel move.
    static func action(_ move: WaveKnotKeeperMove) -> ExperienceAction {
        let index: Int = Core.directionOrder.firstIndex(of: move.direction) ?? 0
        return ExperienceAction(control: "point.move", values: [Double(move.point), Double(index)], step: 0)
    }

    /// An action without values.
    static func bare(_ control: String) -> ExperienceAction {
        ExperienceAction(control: control, step: 0)
    }

    /// An action with values.
    static func valued(_ control: String, _ values: [Double]) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// A random `point.move` inside the declared ranges (the kernel may still refuse it).
    static func randomMove(_ random: inout WaveKnotKeeperSplitMix) -> ExperienceAction {
        Self.valued("point.move", [Double(random.int(0...15)), Double(random.int(0...5))])
    }

    /// A random daily date of ``dailyDates``.
    static func randomDate(_ random: inout WaveKnotKeeperSplitMix) -> [Double] {
        Self.dailyDates[random.below(Self.dailyDates.count)]
    }

    /// A random daily date of ``dailyDates`` whose level is at most ``highestWin``.
    static func winnableDate(_ random: inout WaveKnotKeeperSplitMix) -> [Double] {
        Self.dailyDates[random.below(Self.highestWin)]
    }

    /// A random seed whose level is 1 … ``highestLevel``.
    static func randomSeed(_ random: inout WaveKnotKeeperSplitMix) -> UInt64 {
        UInt64(random.below(Self.highestLevel))
    }

    /// The payload's JSON object.
    static func object(_ payload: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
    }

    /// The JSON data of `object`.
    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The first move in point-then-direction order that is legal from `level`'s start, does not win there and whose
    /// opposite is legal back.
    static func quietMove(on level: WaveKnotKeeperLevel) -> WaveKnotKeeperMove? {
        for point in level.points.indices {
            for direction in Core.directionOrder {
                let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                guard WaveKnotKeeperPlay.refusal(of: move, points: level.points, level: level) == nil else { continue }
                var moved: [WaveKnotKeeperPoint] = level.points
                moved[point] = moved[point].moved(direction)
                if level.wins(moved) { continue }
                let back: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction.opposite)
                if WaveKnotKeeperPlay.refusal(of: back, points: moved, level: level) == nil { return move }
            }
        }
        return nil
    }

    /// Re-opens the current level fresh in its mode (campaign, practice or daily), then plays its certified solution,
    /// optionally after a detour (`1`: a quiet move and its undo, net moves = the solution; `2`: a quiet move and its
    /// opposite, two more net moves, when the allowance allows). Does nothing in replay mode or above ``highestWin``.
    static func win(_ core: inout Core, detour: Int) throws {
        switch core.mode {
        case .replay:
            return
        case .practice:
            guard core.levelNumber <= Self.highestWin else { return }
            _ = core.apply(Self.bare("mode.practice"))
        case .campaign:
            guard core.levelNumber <= Self.highestWin else { return }
            _ = core.apply(Self.bare("mode.campaign"))
        case .daily(let level):
            guard level <= Self.highestWin else { return }
            let index: Int = level - 1
            _ = core.apply(Self.valued("mode.daily", Self.dailyDates[index]))
        }
        let generated: WaveKnotKeeperGenerated = try Core.generated(number: core.levelNumber)
        let moves: [WaveKnotKeeperMove] = generated.solution.moves
        let allowance: Int = core.play.level.allowance
        if let quiet = Self.quietMove(on: core.play.level) {
            if detour == 1 && allowance > 1 {
                _ = core.apply(Self.action(quiet))
                _ = core.apply(Self.bare("play.undo"))
            } else if detour == 2 && moves.count + 2 <= allowance {
                _ = core.apply(Self.action(quiet))
                _ = core.apply(Self.action(WaveKnotKeeperMove(point: quiet.point, direction: quiet.direction.opposite)))
            }
        }
        for move in moves {
            _ = core.apply(Self.action(move))
        }
    }

    /// One random action (legal or refused) on `core`; level changes and wins are rarer than moves.
    static func randomStep(_ core: inout Core, _ random: inout WaveKnotKeeperSplitMix) throws {
        let roll: Int = random.below(100)
        if case .replay = core.mode {
            if roll < 70 {
                _ = core.apply(Self.bare("replay.step"))
            } else if roll < 85 {
                _ = core.apply(Self.bare("replay.stop"))
            } else if roll < 90 {
                _ = core.apply(Self.bare("tutorial.dismiss"))
            } else if roll < 95 {
                _ = core.apply(Self.valued("point.select", [Double(random.int(0...15))]))
            } else {
                _ = core.apply(Self.randomMove(&random))
            }
            return
        }
        if roll < 35 {
            _ = core.apply(Self.randomMove(&random))
        } else if roll < 40 {
            _ = core.apply(Self.valued("point.select", [Double(random.int(0...15))]))
        } else if roll < 50 {
            _ = core.apply(Self.bare("play.undo"))
        } else if roll < 55 {
            _ = core.apply(Self.bare("play.redo"))
        } else if roll < 58 {
            _ = core.apply(Self.bare("level.next"))
        } else if roll < 61 {
            _ = core.apply(Self.valued("level.select", [Double(random.int(1...core.progress.frontier))]))
        } else if roll < 63 {
            _ = core.apply(Self.bare("mode.practice"))
        } else if roll < 65 {
            _ = core.apply(Self.bare("mode.campaign"))
        } else if roll < 67 {
            _ = core.apply(Self.valued("mode.daily", Self.randomDate(&random)))
        } else if roll < 70 {
            _ = core.apply(Self.bare("tutorial.dismiss"))
        } else if roll < 73 {
            _ = core.apply(Self.bare("tutorial.hint"))
        } else if roll < 87 {
            try Self.win(&core, detour: random.below(3))
        } else {
            let verified: [Int] = core.progress.solved.keys.sorted().filter { level in
                core.progress.solved[level]?.verified == true
            }
            let level: Int = verified.isEmpty ? random.int(1...Self.highestLevel) : verified[random.below(verified.count)]
            _ = core.apply(Self.valued("replay.start", [Double(level)]))
        }
    }

    /// A seeded reachable state: prepared with a random seed, then 0 … 14 random actions.
    static func reachable(_ random: inout WaveKnotKeeperSplitMix) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = Self.randomSeed(&random)
        var core: Core = try await Core.prepare(seed: seed)
        let count: Int = random.int(0...14)
        for _ in 0..<count {
            try Self.randomStep(&core, &random)
        }
        return (core, seed)
    }

    // MARK: SC-R02G0307-001 — 500 seeded reachable states round-trip

    /// Round-trips `count` seeded states of generator stream `stream`; returns how many traced results, replay states,
    /// daily states and practice states they carried.
    static func roundTrips(stream: UInt64, count: Int) async throws
        -> (traced: Int, replays: Int, dailies: Int, practices: Int) {
        var random: WaveKnotKeeperSplitMix = WaveKnotKeeperSplitMix(seed: Self.baseSeed &+ stream)
        var traced: Int = 0
        var replays: Int = 0
        var dailies: Int = 0
        var practices: Int = 0
        for index in 0..<count {
            let state: (core: Core, seed: UInt64) = try await Self.reachable(&random)
            let payload: Data = try state.core.snapshotPayload()
            let restored: Core = try Core.restore(payload: payload, seed: state.seed)
            #expect(restored == state.core, "stream \(stream) state \(index)")
            #expect(try Self.digest(restored) == Self.digest(state.core), "stream \(stream) state \(index)")
            #expect(restored.progress == state.core.progress && restored.mode == state.core.mode)
            #expect(restored.tutorial == state.core.tutorial, "stream \(stream) state \(index)")
            #expect(restored.play.records == state.core.play.records)
            #expect(restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
            #expect(try restored.snapshotPayload() == payload, "stream \(stream) state \(index)")
            for result in state.core.progress.solved.values where result.verified { traced += 1 }
            switch state.core.mode {
            case .replay: replays += 1
            case .daily: dailies += 1
            case .practice: practices += 1
            case .campaign: break
            }
        }
        return (traced, replays, dailies, practices)
    }

    @Test func roundTripsStates1To100() async throws {
        let totals: (traced: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 1, count: 100)
        #expect(totals.traced > 0 && totals.replays > 0 && totals.dailies > 0 && totals.practices > 0)
    }

    @Test func roundTripsStates101To200() async throws {
        let totals: (traced: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 2, count: 100)
        #expect(totals.traced > 0 && totals.replays > 0)
    }

    @Test func roundTripsStates201To300() async throws {
        let totals: (traced: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 3, count: 100)
        #expect(totals.traced > 0 && totals.replays > 0)
    }

    @Test func roundTripsStates301To400() async throws {
        let totals: (traced: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 4, count: 100)
        #expect(totals.traced > 0 && totals.replays > 0)
    }

    @Test func roundTripsStates401To500() async throws {
        let totals: (traced: Int, replays: Int, dailies: Int, practices: Int) =
            try await Self.roundTrips(stream: 5, count: 100)
        #expect(totals.traced > 0 && totals.replays > 0)
    }

    // MARK: SC-R02G0307-002 — schema 1 and schema 2 payloads migrate

    /// Migrates `count` seeded schema-1 payloads `{level, records}` of generator stream `stream`.
    static func schemaOne(stream: UInt64, count: Int) async throws {
        var random: WaveKnotKeeperSplitMix = WaveKnotKeeperSplitMix(seed: Self.baseSeed &+ stream)
        for index in 0..<count {
            let seed: UInt64 = Self.randomSeed(&random)
            var core: Core = try await Core.prepare(seed: seed)
            let steps: Int = random.int(0...10)
            for _ in 0..<steps {
                let roll: Int = random.below(10)
                if roll < 7 {
                    _ = core.apply(Self.randomMove(&random))
                } else if roll < 9 {
                    _ = core.apply(Self.bare("play.undo"))
                } else {
                    _ = core.apply(Self.bare("play.redo"))
                }
            }
            let full: [String: Any] = try Self.object(try core.snapshotPayload())
            var old: [String: Any] = [:]
            old["level"] = full["level"]
            old["records"] = full["records"]
            let migrated: [String: Any] = try Core.migrations.migrate(old, from: 1)
            let restored: Core = try Core.restore(payload: try Self.data(migrated), seed: seed)
            var expected: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
            expected.open(through: core.levelNumber)
            let firstStep: WaveKnotKeeperTutorialStep = Core.firstTutorialStep(
                number: core.levelNumber, mode: .campaign,
                play: try Core.freshPlay(of: try Core.level(number: core.levelNumber)))
            #expect(restored.levelNumber == core.levelNumber, "stream \(stream) state \(index)")
            #expect(restored.play.records == core.play.records && restored.play == core.play)
            #expect(restored.mode == .campaign && restored.progress == expected, "stream \(stream) state \(index)")
            #expect(restored.tutorial == firstStep, "stream \(stream) state \(index)")
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
        var random: WaveKnotKeeperSplitMix = WaveKnotKeeperSplitMix(seed: Self.baseSeed &+ stream)
        for index in 0..<count {
            let seed: UInt64 = UInt64(random.below(Self.highestWin))
            var core: Core = try await Core.prepare(seed: seed)
            let wins: Int = random.int(1...3)
            for _ in 0..<wins {
                if random.below(4) == 0 { _ = core.apply(Self.valued("mode.daily", Self.winnableDate(&random))) }
                try Self.win(&core, detour: random.below(3))
                let steps: Int = random.int(0...3)
                for _ in 0..<steps { try Self.randomStep(&core, &random) }
                if case .replay = core.mode { _ = core.apply(Self.bare("replay.stop")) }
                _ = core.apply(Self.bare("level.next"))
            }
            let moves: Int = random.int(0...4)
            for _ in 0..<moves { _ = core.apply(Self.randomMove(&random)) }
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
            let restored: Core = try Core.restore(payload: try Self.data(migrated), seed: seed)
            #expect(restored.levelNumber == core.levelNumber && restored.mode == core.mode, "stream \(stream) \(index)")
            #expect(restored.play.records == core.play.records && restored.play == core.play)
            #expect(restored.tutorial == core.tutorial)
            #expect(restored.progress.frontier == core.progress.frontier, "stream \(stream) state \(index)")
            #expect(restored.progress.solved.keys.sorted() == core.progress.solved.keys.sorted())
            for (level, result) in core.progress.solved {
                let kept: WaveKnotKeeperProgress.Result = try #require(restored.progress.solved[level])
                #expect(kept.bestMoves == result.bestMoves && kept.stars == result.stars, "level \(level)")
                #expect(!kept.verified && kept.trace.isEmpty, "level \(level)")
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

    // MARK: SC-R02G0307-003 — honest results survive, edited ones are dropped and counted

    /// `entry` (a traced result of certified level `generated`) edited by `edit`.
    static func edited(_ entry: [String: Any], _ edit: Edit, _ generated: WaveKnotKeeperGenerated,
                       _ random: inout WaveKnotKeeperSplitMix) throws -> [String: Any] {
        var changed: [String: Any] = entry
        let stars: Int = try #require(entry["stars"] as? Int)
        let best: Int = try #require(entry["bestMoves"] as? Int)
        var trace: [[String: Any]] = try #require(entry["trace"] as? [[String: Any]])
        switch edit {
        case .stars:
            // Raised when it can be; a three-star result is lowered instead (stars stay in 1 … 3, or decoding fails).
            changed["stars"] = stars < 3 ? stars + 1 : 2
        case .bestMoves:
            changed["bestMoves"] = random.below(2) == 0 ? best + 1 : max(best - 1, 0)
        case .traceStep:
            // The step becomes a move the kernel refuses on the rope just before it (the first such move in
            // point-then-direction order, or a point outside the rope), so the edited trace can never replay.
            let index: Int = random.below(trace.count)
            var play: WaveKnotKeeperPlay = try Core.freshPlay(of: generated.level)
            for position in 0..<index {
                let point: Int = try #require(trace[position]["point"] as? Int)
                let name: String = try #require(trace[position]["direction"] as? String)
                let direction: WaveKnotKeeperDirection = try #require(WaveKnotKeeperDirection(rawValue: name))
                try play.apply(WaveKnotKeeperMove(point: point, direction: direction), expecting: play.fingerprint)
            }
            var replacement: WaveKnotKeeperMove = WaveKnotKeeperMove(point: play.points.count, direction: .plusX)
            var found: Bool = false
            for point in play.points.indices where !found {
                for direction in Core.directionOrder where !found {
                    let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                    if WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level) != nil {
                        replacement = move
                        found = true
                    }
                }
            }
            #expect(WaveKnotKeeperPlay.refusal(of: replacement, points: play.points, level: play.level) != nil)
            trace[index] = ["direction": replacement.direction.rawValue, "point": replacement.point]
            changed["trace"] = trace
        case .traceRemoved:
            trace.remove(at: random.below(trace.count))
            changed["trace"] = trace
        }
        return changed
    }

    /// Checks `count` seeded saves of generator stream `stream`; returns (honest, edited) totals.
    static func reconciledSaves(stream: UInt64, count: Int) async throws -> (honest: Int, edited: Int) {
        var random: WaveKnotKeeperSplitMix = WaveKnotKeeperSplitMix(seed: Self.baseSeed &+ stream)
        var honestTotal: Int = 0
        var editedTotal: Int = 0
        let edits: [Edit] = Edit.allCases
        for index in 0..<count {
            let seed: UInt64 = UInt64(random.below(Self.highestWin))
            var core: Core = try await Core.prepare(seed: seed)
            let wins: Int = random.int(1...3)
            for _ in 0..<wins {
                if random.below(4) == 0 { _ = core.apply(Self.valued("mode.daily", Self.winnableDate(&random))) }
                try Self.win(&core, detour: random.below(3))
                _ = core.apply(Self.bare("level.next"))
            }
            var object: [String: Any] = try Self.object(try core.snapshotPayload())
            var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
            let solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
            #expect(!solved.isEmpty, "stream \(stream) save \(index)")
            var entries: [[String: Any]] = []
            var honest: [Int: WaveKnotKeeperProgress.Result] = [:]
            var editedCount: Int = 0
            for entry in solved {
                let level: Int = try #require(entry["level"] as? Int)
                let saved: WaveKnotKeeperProgress.Result = try #require(core.progress.solved[level])
                #expect(saved.verified && !saved.trace.isEmpty, "level \(level)")
                let roll: Int = random.below(5)
                if roll < 2 {
                    let generated: WaveKnotKeeperGenerated = try Core.generated(number: level)
                    let edit: Edit = edits[random.below(edits.count)]
                    entries.append(try Self.edited(entry, edit, generated, &random))
                    editedCount += 1
                } else if roll < 3 {
                    // An honest untraced result (as written before schema 3): kept, unverified.
                    var untraced: [String: Any] = entry
                    untraced["trace"] = [Any]()
                    untraced["verified"] = false
                    entries.append(untraced)
                    honest[level] = WaveKnotKeeperProgress.Result(bestMoves: saved.bestMoves, stars: saved.stars)
                } else {
                    entries.append(entry)
                    honest[level] = saved
                }
            }
            progress["solved"] = entries
            object["progress"] = progress
            let restored: Core = try Core.restore(payload: try Self.data(object), seed: seed)
            #expect(restored.reconciliationDropped == editedCount, "stream \(stream) save \(index)")
            #expect(restored.progress.solved.keys.sorted() == honest.keys.sorted(), "stream \(stream) save \(index)")
            for (level, result) in honest {
                #expect(restored.progress.solved[level] == result, "stream \(stream) save \(index) level \(level)")
            }
            #expect(restored.progress.frontier == core.progress.frontier, "stream \(stream) save \(index)")
            #expect(restored.levelNumber == core.levelNumber && restored.play == core.play)
            #expect(restored.mode == core.mode && restored.tutorial == core.tutorial)
            if editedCount == 0 {
                // An honest save restores exactly.
                #expect(restored.progress.solved.count == honest.count)
            }
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
}
