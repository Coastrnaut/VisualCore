// LissajousLabyrinthPersistenceTests — feature 317 (R02-G02-07) T-R02G0207-004 (FR-R02G0207-001 … 003;
// SC-R02G0207-001 … 003). Host checks of Lissajous Labyrinth's persistence through the adapter core:
//   - 500 seeded reachable states (random walks of dial.set, undo, redo, level.next, level.select of open levels,
//     mode.daily with valid dates, mode.practice, mode.campaign, tutorial actions, certified wins with traced results
//     and replay start, step and stop) round-trip through `snapshotPayload()` and `restore(payload:seed:)` with equal
//     states, equal digests, identical payload bytes and nothing dropped;
//   - 100 seeded states as schema-1 payloads `{level, records}` and 100 as schema-2 payloads (the schema-3 payload with
//     `trace` and `verified` removed from each solved entry) migrate through `migrations` and restore with the level,
//     the records and the progress kept (schema 2: results unverified with empty traces, the frontier as saved);
//   - 200 seeded saves with traced results: honest results (and honest untraced ones) survive restore; edited ones
//     (stars raised, best actions changed, one trace step's value changed, a trace action dropped, an untraced result
//     marked verified) are dropped and counted exactly, and the frontier stays as saved.
// Synthetic data, explicit types, plain loops, no sleep. The states come from an in-file SplitMix64 seeded with 2_317;
// edited saves are made by editing the payload's JSON, as a tampered file would be.
import Foundation
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// A small deterministic generator (SplitMix64) for the seeded states of these tests.
struct LissajousLabyrinthSplitMix {
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

@Suite struct LissajousLabyrinthPersistenceTests {
    typealias Core = LissajousLabyrinthExperienceCore

    /// The seed of every generator in this file.
    static let baseSeed: UInt64 = 2_317

    /// The kinds of edit made to a saved result.
    enum Edit: CaseIterable {
        case stars
        case bestActions
        case traceStep
        case traceDropped
        case untracedVerified
    }

    // MARK: Helpers

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The `dial.set` action for a kernel action.
    static func action(_ move: LissajousLabyrinthAction) -> ExperienceAction {
        let index: Int = Core.dialOrder.firstIndex(of: move.dial) ?? 0
        return ExperienceAction(control: "dial.set", values: [Double(index), Double(move.value)], step: 0)
    }

    /// An action without values.
    static func bare(_ control: String) -> ExperienceAction {
        ExperienceAction(control: control, step: 0)
    }

    /// An action with values.
    static func valued(_ control: String, _ values: [Double]) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// A random `dial.set` inside the declared ranges and the dial's own range (the kernel may still refuse it: the
    /// current value or non-coprime frequencies).
    static func randomDial(_ random: inout LissajousLabyrinthSplitMix) -> ExperienceAction {
        let index: Int = random.int(0...3)
        let range: ClosedRange<Int> = Core.dialOrder[index].range
        return Self.valued("dial.set", [Double(index), Double(random.int(range))])
    }

    /// A valid calendar date `[year, month, day]`.
    static func randomDate(_ random: inout LissajousLabyrinthSplitMix) -> [Double] {
        [Double(random.int(2000...2100)), Double(random.int(1...12)), Double(random.int(1...28))]
    }

    /// The payload's JSON object.
    static func object(_ payload: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
    }

    /// The JSON data of `object`.
    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// Re-opens the current level fresh in its mode (campaign, practice or daily), then plays its certified solution,
    /// optionally after a detour (`1`: a phase-C action and its undo; `2`: a phase-C action and one back, when the
    /// allowance allows). Does nothing in replay mode.
    static func win(_ core: inout Core, detour: Int, _ random: inout LissajousLabyrinthSplitMix) throws {
        switch core.mode {
        case .replay:
            return
        case .practice:
            _ = core.apply(Self.bare("mode.practice"))
        case .campaign:
            _ = core.apply(Self.bare("mode.campaign"))
        case .daily:
            if !core.play.records.isEmpty { _ = core.apply(Self.bare("mode.campaign")) }
        }
        let generated: LissajousLabyrinthGenerated = try Core.generated(number: core.levelNumber)
        let actions: [LissajousLabyrinthAction] = generated.solution.actions
        let original: Int = core.play.dials.phaseC
        let away: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: .phaseC,
                                                                      value: (original + 1 + random.below(15)) % 16)
        let back: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: .phaseC, value: original)
        if detour == 1 {
            _ = core.apply(Self.action(away))
            _ = core.apply(Self.bare("play.undo"))
        } else if detour == 2 && actions.count + 2 <= core.play.level.allowance {
            _ = core.apply(Self.action(away))
            _ = core.apply(Self.action(back))
        }
        for move in actions {
            _ = core.apply(Self.action(move))
        }
    }

    /// One random action (legal or refused) on `core`; level changes and wins are rarer than dial actions.
    static func randomStep(_ core: inout Core, _ random: inout LissajousLabyrinthSplitMix) throws {
        let roll: Int = random.below(100)
        if case .replay = core.mode {
            if roll < 70 {
                _ = core.apply(Self.bare("replay.step"))
            } else if roll < 85 {
                _ = core.apply(Self.bare("replay.stop"))
            } else if roll < 92 {
                _ = core.apply(Self.bare("tutorial.dismiss"))
            } else {
                _ = core.apply(Self.randomDial(&random))
            }
            return
        }
        if roll < 45 {
            _ = core.apply(Self.randomDial(&random))
        } else if roll < 55 {
            _ = core.apply(Self.bare("play.undo"))
        } else if roll < 60 {
            _ = core.apply(Self.bare("play.redo"))
        } else if roll < 62 {
            _ = core.apply(Self.bare("level.next"))
        } else if roll < 65 {
            _ = core.apply(Self.valued("level.select", [Double(random.int(1...core.progress.frontier))]))
        } else if roll < 67 {
            _ = core.apply(Self.bare("mode.practice"))
        } else if roll < 69 {
            _ = core.apply(Self.bare("mode.campaign"))
        } else if roll < 71 {
            _ = core.apply(Self.valued("mode.daily", Self.randomDate(&random)))
        } else if roll < 73 {
            _ = core.apply(Self.bare("tutorial.dismiss"))
        } else if roll < 75 {
            _ = core.apply(Self.bare("tutorial.hint"))
        } else if roll < 87 {
            try Self.win(&core, detour: random.below(3), &random)
        } else {
            let verified: [Int] = core.progress.solved.keys.sorted().filter { level in
                core.progress.solved[level]?.verified == true
            }
            let level: Int = verified.isEmpty ? random.int(1...100) : verified[random.below(verified.count)]
            _ = core.apply(Self.valued("replay.start", [Double(level)]))
        }
    }

    /// A seeded reachable state: prepared with a random seed, then 0 … 14 random actions.
    static func reachable(_ random: inout LissajousLabyrinthSplitMix) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = random.next() % 1_000
        var core: Core = try await Core.prepare(seed: seed)
        let count: Int = random.int(0...14)
        for _ in 0..<count {
            try Self.randomStep(&core, &random)
        }
        return (core, seed)
    }

    // MARK: SC-R02G0207-001 — 500 seeded reachable states round-trip

    /// Round-trips `count` seeded states of generator stream `stream`; returns how many traced results and replay
    /// states they carried.
    static func roundTrips(stream: UInt64, count: Int) async throws -> (traced: Int, replays: Int) {
        var random: LissajousLabyrinthSplitMix = LissajousLabyrinthSplitMix(seed: Self.baseSeed &+ stream)
        var traced: Int = 0
        var replays: Int = 0
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
            if case .replay = state.core.mode { replays += 1 }
        }
        return (traced, replays)
    }

    @Test func roundTripsStates1To100() async throws {
        let totals: (traced: Int, replays: Int) = try await Self.roundTrips(stream: 1, count: 100)
        #expect(totals.traced > 0)
    }

    @Test func roundTripsStates101To200() async throws {
        let totals: (traced: Int, replays: Int) = try await Self.roundTrips(stream: 2, count: 100)
        #expect(totals.traced > 0)
    }

    @Test func roundTripsStates201To300() async throws {
        let totals: (traced: Int, replays: Int) = try await Self.roundTrips(stream: 3, count: 100)
        #expect(totals.traced > 0)
    }

    @Test func roundTripsStates301To400() async throws {
        let totals: (traced: Int, replays: Int) = try await Self.roundTrips(stream: 4, count: 100)
        #expect(totals.traced > 0)
    }

    @Test func roundTripsStates401To500() async throws {
        let totals: (traced: Int, replays: Int) = try await Self.roundTrips(stream: 5, count: 100)
        #expect(totals.traced > 0)
    }

    // MARK: SC-R02G0207-002 — schema 1 and schema 2 payloads migrate

    /// Migrates `count` seeded schema-1 payloads `{level, records}` of generator stream `stream`.
    static func schemaOne(stream: UInt64, count: Int) async throws {
        var random: LissajousLabyrinthSplitMix = LissajousLabyrinthSplitMix(seed: Self.baseSeed &+ stream)
        for index in 0..<count {
            let seed: UInt64 = random.next() % 1_000
            var core: Core = try await Core.prepare(seed: seed)
            let steps: Int = random.int(0...10)
            for _ in 0..<steps {
                let roll: Int = random.below(10)
                if roll < 7 {
                    _ = core.apply(Self.randomDial(&random))
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
            var expected: LissajousLabyrinthProgress = LissajousLabyrinthProgress()
            expected.open(through: core.levelNumber)
            #expect(restored.levelNumber == core.levelNumber, "stream \(stream) state \(index)")
            #expect(restored.play.records == core.play.records && restored.play == core.play)
            #expect(restored.mode == .campaign && restored.progress == expected, "stream \(stream) state \(index)")
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
        var random: LissajousLabyrinthSplitMix = LissajousLabyrinthSplitMix(seed: Self.baseSeed &+ stream)
        for index in 0..<count {
            let seed: UInt64 = random.next() % 1_000
            var core: Core = try await Core.prepare(seed: seed)
            let wins: Int = random.int(1...3)
            for _ in 0..<wins {
                if random.below(4) == 0 { _ = core.apply(Self.valued("mode.daily", Self.randomDate(&random))) }
                try Self.win(&core, detour: random.below(3), &random)
                let steps: Int = random.int(0...3)
                for _ in 0..<steps { try Self.randomStep(&core, &random) }
                if case .replay = core.mode { _ = core.apply(Self.bare("replay.stop")) }
                _ = core.apply(Self.bare("level.next"))
            }
            let moves: Int = random.int(0...4)
            for _ in 0..<moves { _ = core.apply(Self.randomDial(&random)) }
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
                let kept: LissajousLabyrinthProgress.Result = try #require(restored.progress.solved[level])
                #expect(kept.bestActions == result.bestActions && kept.stars == result.stars, "level \(level)")
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

    // MARK: SC-R02G0207-003 — honest results survive, edited ones are dropped and counted

    /// `entry` (a traced result of certified level `generated`) edited by `edit`.
    static func edited(_ entry: [String: Any], _ edit: Edit, _ generated: LissajousLabyrinthGenerated,
                       _ random: inout LissajousLabyrinthSplitMix) throws -> [String: Any] {
        var changed: [String: Any] = entry
        let stars: Int = try #require(entry["stars"] as? Int)
        let best: Int = try #require(entry["bestActions"] as? Int)
        var trace: [[String: Any]] = try #require(entry["trace"] as? [[String: Any]])
        switch edit {
        case .stars:
            // Raised when it can be; a three-star result is lowered instead (stars stay in 1 … 3, or decoding fails).
            changed["stars"] = stars < 3 ? stars + 1 : 2
        case .bestActions:
            changed["bestActions"] = random.below(2) == 0 ? best + 1 : max(best - 1, 0)
        case .traceStep:
            // The value becomes the one its dial holds just before the action, so the action changes nothing and the
            // kernel refuses it: the edited trace can never replay.
            let index: Int = random.below(trace.count)
            var dials: LissajousLabyrinthDials = generated.level.start
            for position in 0..<index {
                let name: String = try #require(trace[position]["dial"] as? String)
                let dial: LissajousLabyrinthDial = try #require(LissajousLabyrinthDial(rawValue: name))
                dials[dial] = try #require(trace[position]["value"] as? Int)
            }
            let name: String = try #require(trace[index]["dial"] as? String)
            let dial: LissajousLabyrinthDial = try #require(LissajousLabyrinthDial(rawValue: name))
            #expect(trace[index]["value"] as? Int != dials[dial])
            trace[index]["value"] = dials[dial]
            changed["trace"] = trace
        case .traceDropped:
            trace.remove(at: random.below(trace.count))
            changed["trace"] = trace
        case .untracedVerified:
            changed["trace"] = [Any]()
            changed["verified"] = true
        }
        return changed
    }

    /// Checks `count` seeded saves of generator stream `stream`; returns (honest, edited) totals.
    static func reconciledSaves(stream: UInt64, count: Int) async throws -> (honest: Int, edited: Int) {
        var random: LissajousLabyrinthSplitMix = LissajousLabyrinthSplitMix(seed: Self.baseSeed &+ stream)
        var honestTotal: Int = 0
        var editedTotal: Int = 0
        let edits: [Edit] = Edit.allCases
        for index in 0..<count {
            let seed: UInt64 = random.next() % 1_000
            var core: Core = try await Core.prepare(seed: seed)
            let wins: Int = random.int(1...3)
            for _ in 0..<wins {
                if random.below(4) == 0 { _ = core.apply(Self.valued("mode.daily", Self.randomDate(&random))) }
                try Self.win(&core, detour: random.below(3), &random)
                _ = core.apply(Self.bare("level.next"))
            }
            var object: [String: Any] = try Self.object(try core.snapshotPayload())
            var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
            let solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
            var entries: [[String: Any]] = []
            var honest: [Int: LissajousLabyrinthProgress.Result] = [:]
            var editedCount: Int = 0
            for entry in solved {
                let level: Int = try #require(entry["level"] as? Int)
                let saved: LissajousLabyrinthProgress.Result = try #require(core.progress.solved[level])
                #expect(saved.verified && !saved.trace.isEmpty, "level \(level)")
                let roll: Int = random.below(5)
                if roll < 2 {
                    let generated: LissajousLabyrinthGenerated = try Core.generated(number: level)
                    let edit: Edit = edits[random.below(edits.count)]
                    entries.append(try Self.edited(entry, edit, generated, &random))
                    editedCount += 1
                } else if roll < 3 {
                    // An honest untraced result (as written before schema 3): kept, unverified.
                    var untraced: [String: Any] = entry
                    untraced["trace"] = [Any]()
                    untraced["verified"] = false
                    entries.append(untraced)
                    honest[level] = LissajousLabyrinthProgress.Result(bestActions: saved.bestActions,
                                                                      stars: saved.stars)
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
