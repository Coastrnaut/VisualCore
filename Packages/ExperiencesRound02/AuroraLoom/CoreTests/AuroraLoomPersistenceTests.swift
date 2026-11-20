// AuroraLoomPersistenceTests - feature 307 (R02-G01-07) T-R02G0107-004 (FR-R02G0107-001 ... 004; clarifications Q1-Q4;
// SC-R02G0107-001 ... 004). Host checks of Aurora Loom's persistence and replay through the adapter core:
//   - 500 seeded reachable states (random legal and refused actions: moves, undo, redo, level changes, modes, dates,
//     certified wins with traced results, replay start, step and stop) round-trip through `snapshotPayload()` and
//     `restore(payload:seed:)` with equal digests, equal states and identical payload bytes;
//   - 100 seeded schema-1 payloads and 100 seeded schema-2 payloads migrate through `migrations` and restore with the
//     level, the records and the progress (best moves, stars, frontier) kept; migrated results are unverified;
//   - 200 seeded saves with honest results (certified wins, some with detours) and edited ones (stars, best moves, a
//     trace step, a removed trace move): every honest result survives restore, every edited one is dropped and counted;
//   - every one of the 100 certified levels, won by its certified solution, replays step by step with the recorded
//     fingerprints, ends won and refuses a further step;
//   - replay never changes progress.
// Synthetic data, explicit types, plain loops, no sleep. The states come from an in-file SplitMix64 seeded with 2_307;
// edited saves are made by editing the payload's JSON, as a tampered file would be.
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// A small deterministic generator (SplitMix64) for the seeded states of these tests.
struct AuroraLoomSplitMix {
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

@Suite struct AuroraLoomPersistenceTests {
    typealias Core = AuroraLoomExperienceCore

    /// The seed of every generator in this file.
    static let baseSeed: UInt64 = 2_307

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

    /// The `ribbon.move` action for a kernel move.
    static func action(_ move: AuroraLoomMove) -> ExperienceAction {
        let control: Double = move.control == .wave ? 0 : 1
        return ExperienceAction(control: "ribbon.move", values: [Double(move.ribbon), control, Double(move.step)],
                                step: 0)
    }

    /// An action without values.
    static func bare(_ control: String) -> ExperienceAction {
        ExperienceAction(control: control, step: 0)
    }

    /// An action with values.
    static func valued(_ control: String, _ values: [Double]) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The certified level `number`, generated once per cache.
    static func certified(_ number: Int, _ cache: inout [Int: AuroraLoomGenerated]) throws -> AuroraLoomGenerated {
        if let known = cache[number] { return known }
        let generated: AuroraLoomGenerated = try Core.generated(number: number)
        cache[number] = generated
        return generated
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
    /// optionally after a detour (`1`: a move and its undo; `2`: a move and a move back, when the allowance allows).
    /// Does nothing in replay mode.
    static func win(_ core: inout Core, detour: Int, _ random: inout AuroraLoomSplitMix,
                    _ cache: inout [Int: AuroraLoomGenerated]) throws {
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
        let generated: AuroraLoomGenerated = try Self.certified(core.levelNumber, &cache)
        let moves: [AuroraLoomMove] = generated.solution.moves
        let ribbon: Int = random.int(0...2)
        let original: Int = core.play.steps.wave[ribbon]
        let awayStep: Int = (original + 1 + random.below(15)) % 16
        let away: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: .wave, step: awayStep)
        let back: AuroraLoomMove = AuroraLoomMove(ribbon: ribbon, control: .wave, step: original)
        if detour == 1 {
            _ = core.apply(Self.action(away))
            _ = core.apply(Self.bare("play.undo"))
        } else if detour == 2 && moves.count + 2 <= core.play.level.allowance {
            _ = core.apply(Self.action(away))
            _ = core.apply(Self.action(back))
        }
        for move in moves {
            _ = core.apply(Self.action(move))
        }
    }

    /// One random action (legal or refused) on `core`; level changes and wins are rarer than moves.
    static func randomStep(_ core: inout Core, _ random: inout AuroraLoomSplitMix,
                           _ cache: inout [Int: AuroraLoomGenerated]) throws {
        let roll: Int = random.below(100)
        if case .replay = core.mode {
            if roll < 70 {
                _ = core.apply(Self.bare("replay.step"))
            } else if roll < 85 {
                _ = core.apply(Self.bare("replay.stop"))
            } else {
                _ = core.apply(Self.valued("ribbon.move", [0, 0, Double(random.int(0...15))]))
            }
            return
        }
        if roll < 50 {
            let values: [Double] = [Double(random.int(0...2)), Double(random.int(0...1)), Double(random.int(0...15))]
            _ = core.apply(Self.valued("ribbon.move", values))
        } else if roll < 60 {
            _ = core.apply(Self.bare("play.undo"))
        } else if roll < 65 {
            _ = core.apply(Self.bare("play.redo"))
        } else if roll < 67 {
            _ = core.apply(Self.bare("level.next"))
        } else if roll < 70 {
            _ = core.apply(Self.valued("level.select", [Double(random.int(1...100))]))
        } else if roll < 72 {
            _ = core.apply(Self.bare("mode.practice"))
        } else if roll < 74 {
            _ = core.apply(Self.bare("mode.campaign"))
        } else if roll < 76 {
            let date: [Double] = [Double(random.int(2000...2100)), Double(random.int(1...12)),
                                  Double(random.int(1...28))]
            _ = core.apply(Self.valued("mode.daily", date))
        } else if roll < 78 {
            _ = core.apply(Self.bare("tutorial.dismiss"))
        } else if roll < 88 {
            try Self.win(&core, detour: random.below(3), &random, &cache)
        } else {
            let solved: [Int] = core.progress.solved.keys.sorted()
            let level: Int = solved.isEmpty ? random.int(1...100) : solved[random.below(solved.count)]
            _ = core.apply(Self.valued("replay.start", [Double(level)]))
        }
    }

    /// A seeded reachable state: prepared with a random seed, then 0 ... 14 random actions.
    static func reachable(_ random: inout AuroraLoomSplitMix,
                          _ cache: inout [Int: AuroraLoomGenerated]) async throws -> (core: Core, seed: UInt64) {
        let seed: UInt64 = random.next() % 1_000
        var core: Core = try await Core.prepare(seed: seed)
        let count: Int = random.int(0...14)
        for _ in 0..<count {
            try Self.randomStep(&core, &random, &cache)
        }
        return (core, seed)
    }

    // MARK: SC-R02G0107-001 - 500 seeded reachable states round-trip

    /// Round-trips `count` seeded states of generator stream `stream`; returns how many carried a traced result.
    static func roundTrips(stream: UInt64, count: Int) async throws -> Int {
        var random: AuroraLoomSplitMix = AuroraLoomSplitMix(seed: Self.baseSeed &+ stream)
        var cache: [Int: AuroraLoomGenerated] = [:]
        var traced: Int = 0
        for index in 0..<count {
            let state: (core: Core, seed: UInt64) = try await Self.reachable(&random, &cache)
            let payload: Data = try state.core.snapshotPayload()
            let restored: Core = try Core.restore(payload: payload, seed: state.seed)
            #expect(restored == state.core, "stream \(stream) state \(index)")
            #expect(try Self.digest(restored) == Self.digest(state.core), "stream \(stream) state \(index)")
            #expect(restored.tutorial == state.core.tutorial && restored.mode == state.core.mode)
            #expect(restored.play.records == state.core.play.records)
            #expect(restored.reconciliationDropped == 0, "stream \(stream) state \(index)")
            #expect(try restored.snapshotPayload() == payload, "stream \(stream) state \(index)")
            for result in state.core.progress.solved.values where result.verified { traced += 1 }
        }
        return traced
    }

    @Test func roundTripsStates1To100() async throws {
        let traced: Int = try await Self.roundTrips(stream: 1, count: 100)
        #expect(traced > 0)
    }

    @Test func roundTripsStates101To200() async throws {
        let traced: Int = try await Self.roundTrips(stream: 2, count: 100)
        #expect(traced > 0)
    }

    @Test func roundTripsStates201To300() async throws {
        let traced: Int = try await Self.roundTrips(stream: 3, count: 100)
        #expect(traced > 0)
    }

    @Test func roundTripsStates301To400() async throws {
        let traced: Int = try await Self.roundTrips(stream: 4, count: 100)
        #expect(traced > 0)
    }

    @Test func roundTripsStates401To500() async throws {
        let traced: Int = try await Self.roundTrips(stream: 5, count: 100)
        #expect(traced > 0)
    }

    // MARK: SC-R02G0107-002 - schema 1 and schema 2 payloads migrate

    @Test func schemaOnePayloadsMigrateAndRestore() async throws {
        var random: AuroraLoomSplitMix = AuroraLoomSplitMix(seed: Self.baseSeed &+ 11)
        for index in 0..<100 {
            let seed: UInt64 = random.next() % 1_000
            var core: Core = try await Core.prepare(seed: seed)
            let count: Int = random.int(0...10)
            for _ in 0..<count {
                let roll: Int = random.below(10)
                if roll < 7 {
                    let values: [Double] = [Double(random.int(0...2)), Double(random.int(0...1)),
                                            Double(random.int(0...15))]
                    _ = core.apply(Self.valued("ribbon.move", values))
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
            var expected: AuroraLoomProgress = AuroraLoomProgress()
            expected.frontier = core.levelNumber
            #expect(restored.levelNumber == core.levelNumber, "state \(index)")
            #expect(restored.play.records == core.play.records, "state \(index)")
            #expect(restored.play == core.play, "state \(index)")
            #expect(restored.mode == .campaign && restored.progress == expected, "state \(index)")
            if core.progress.solved.isEmpty {
                // Without a win the schema-1 state's progress is exactly what migration rebuilds.
                #expect(restored.progress == core.progress, "state \(index)")
                #expect(try Self.digest(restored) == Self.digest(core), "state \(index)")
            }
            #expect(restored.reconciliationDropped == 0)
        }
    }

    /// Migrates `count` seeded schema-2 payloads of generator stream `stream` (states with traced results).
    static func schemaTwo(stream: UInt64, count: Int) async throws {
        var random: AuroraLoomSplitMix = AuroraLoomSplitMix(seed: Self.baseSeed &+ stream)
        var cache: [Int: AuroraLoomGenerated] = [:]
        for index in 0..<count {
            let seed: UInt64 = random.next() % 1_000
            var core: Core = try await Core.prepare(seed: seed)
            let wins: Int = random.int(1...3)
            for _ in 0..<wins {
                try Self.win(&core, detour: random.below(3), &random, &cache)
                let steps: Int = random.int(0...3)
                for _ in 0..<steps { try Self.randomStep(&core, &random, &cache) }
                if case .replay = core.mode { _ = core.apply(Self.bare("replay.stop")) }
                _ = core.apply(Self.bare("level.next"))
            }
            let moves: Int = random.int(0...4)
            for _ in 0..<moves {
                let values: [Double] = [Double(random.int(0...2)), Double(random.int(0...1)),
                                        Double(random.int(0...15))]
                _ = core.apply(Self.valued("ribbon.move", values))
            }
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
                let kept: AuroraLoomProgress.Result = try #require(restored.progress.solved[level])
                #expect(kept.bestMoves == result.bestMoves && kept.stars == result.stars, "level \(level)")
                #expect(!kept.verified && kept.trace.isEmpty, "level \(level)")
            }
            #expect(try Self.digest(restored) == Self.digest(core), "stream \(stream) state \(index)")
            #expect(restored.reconciliationDropped == 0)
        }
    }

    @Test func schemaTwoPayloads1To50MigrateUnverified() async throws {
        try await Self.schemaTwo(stream: 21, count: 50)
    }

    @Test func schemaTwoPayloads51To100MigrateUnverified() async throws {
        try await Self.schemaTwo(stream: 22, count: 50)
    }

    // MARK: SC-R02G0107-003 - honest results survive, edited ones are dropped and counted

    /// `entry` (a traced result of certified level `generated`) edited by `edit`.
    static func edited(_ entry: [String: Any], _ edit: Edit, _ generated: AuroraLoomGenerated,
                       _ random: inout AuroraLoomSplitMix) throws -> [String: Any] {
        var changed: [String: Any] = entry
        let stars: Int = try #require(entry["stars"] as? Int)
        let best: Int = try #require(entry["bestMoves"] as? Int)
        var trace: [[String: Any]] = try #require(entry["trace"] as? [[String: Any]])
        switch edit {
        case .stars:
            changed["stars"] = stars % 3 + 1
        case .bestMoves:
            changed["bestMoves"] = random.below(2) == 0 ? best + 1 : max(best - 1, 0)
        case .traceStep:
            // The step becomes the value its ribbon and control hold just before the move, so the move is a no-op the
            // kernel refuses: the edited trace can never replay.
            let index: Int = random.below(trace.count)
            var steps: AuroraLoomSteps = generated.level.startSteps
            for position in 0..<index {
                let ribbon: Int = try #require(trace[position]["ribbon"] as? Int)
                let control: String = try #require(trace[position]["control"] as? String)
                let step: Int = try #require(trace[position]["step"] as? Int)
                if control == "wave" { steps.wave[ribbon] = step } else { steps.phase[ribbon] = step }
            }
            let ribbon: Int = try #require(trace[index]["ribbon"] as? Int)
            let control: String = try #require(trace[index]["control"] as? String)
            trace[index]["step"] = control == "wave" ? steps.wave[ribbon] : steps.phase[ribbon]
            changed["trace"] = trace
        case .traceRemoved:
            trace.remove(at: random.below(trace.count))
            changed["trace"] = trace
        }
        return changed
    }

    /// Checks `count` seeded saves of generator stream `stream`; returns (honest, edited) totals.
    static func reconciledSaves(stream: UInt64, count: Int) async throws -> (honest: Int, edited: Int) {
        var random: AuroraLoomSplitMix = AuroraLoomSplitMix(seed: Self.baseSeed &+ stream)
        var cache: [Int: AuroraLoomGenerated] = [:]
        var honestTotal: Int = 0
        var editedTotal: Int = 0
        let edits: [Edit] = Edit.allCases
        for index in 0..<count {
            let seed: UInt64 = random.next() % 1_000
            var core: Core = try await Core.prepare(seed: seed)
            let wins: Int = random.int(1...3)
            for _ in 0..<wins {
                if random.below(4) == 0 {
                    let date: [Double] = [Double(random.int(2000...2100)), Double(random.int(1...12)),
                                          Double(random.int(1...28))]
                    _ = core.apply(Self.valued("mode.daily", date))
                }
                try Self.win(&core, detour: random.below(3), &random, &cache)
                _ = core.apply(Self.bare("level.next"))
            }
            var object: [String: Any] = try Self.object(try core.snapshotPayload())
            var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
            let solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
            var entries: [[String: Any]] = []
            var honest: [Int] = []
            var editedCount: Int = 0
            for entry in solved {
                let level: Int = try #require(entry["level"] as? Int)
                if random.below(2) == 0 {
                    let generated: AuroraLoomGenerated = try Self.certified(level, &cache)
                    let edit: Edit = edits[random.below(edits.count)]
                    entries.append(try Self.edited(entry, edit, generated, &random))
                    editedCount += 1
                } else {
                    entries.append(entry)
                    honest.append(level)
                }
            }
            progress["solved"] = entries
            object["progress"] = progress
            let restored: Core = try Core.restore(payload: try Self.data(object), seed: seed)
            #expect(restored.reconciliationDropped == editedCount, "stream \(stream) save \(index)")
            #expect(restored.progress.solved.keys.sorted() == honest.sorted(), "stream \(stream) save \(index)")
            for level in honest {
                #expect(restored.progress.solved[level] == core.progress.solved[level], "level \(level)")
                #expect(restored.progress.solved[level]?.verified == true, "level \(level)")
            }
            #expect(restored.progress.frontier == core.progress.frontier)
            #expect(restored.levelNumber == core.levelNumber && restored.play == core.play)
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

    // MARK: SC-R02G0107-004 - every certified level's trace replays with the recorded fingerprints

    /// Wins each level of `levels` by its certified solution, then replays its stored trace step by step.
    static func replays(_ levels: ClosedRange<Int>) async throws {
        for number in levels {
            var core: Core = try await Core.prepare(seed: UInt64(number - 1))
            #expect(core.levelNumber == number && core.progress.frontier == number)
            let generated: AuroraLoomGenerated = try Core.generated(number: number)
            for move in generated.solution.moves {
                #expect(core.apply(Self.action(move)) == .accepted, "level \(number) \(move)")
            }
            #expect(core.play.stage == .won, "level \(number)")
            let original: [AuroraLoomRecord] = core.play.records
            let progress: AuroraLoomProgress = core.progress
            let stored: AuroraLoomProgress.Result = try #require(progress.solved[number])
            #expect(stored.verified && stored.trace == generated.solution.moves, "level \(number)")
            #expect(core.apply(Self.valued("replay.start", [Double(number)])) == .accepted, "level \(number)")
            #expect(core.mode == .replay(level: number) && core.play.records.isEmpty)
            for step in 0..<original.count {
                #expect(core.apply(Self.bare("replay.step")) == .accepted, "level \(number) step \(step)")
                #expect(core.play.records == Array(original[0...step]), "level \(number) step \(step)")
                #expect(core.play.records.last?.previous == original[step].previous)
                #expect(core.play.records.last?.next == original[step].next)
                #expect(core.progress == progress, "level \(number) step \(step)")
            }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.apply(Self.bare("replay.step"))
                == .rejected(.rule(code: AuroraLoomExperienceRule.replayEnd)), "level \(number)")
            #expect(core.apply(Self.bare("replay.stop")) == .accepted, "level \(number)")
            #expect(core.mode == .campaign && core.levelNumber == number && core.progress == progress)
        }
    }

    @Test func band1TracesReplay() async throws {
        try await Self.replays(1...20)
    }

    @Test func band2TracesReplay() async throws {
        try await Self.replays(21...40)
    }

    @Test func band3TracesReplay() async throws {
        try await Self.replays(41...60)
    }

    @Test func band4TracesReplay() async throws {
        try await Self.replays(61...80)
    }

    @Test func band5TracesReplay() async throws {
        try await Self.replays(81...100)
    }

    // MARK: Replay never changes progress

    @Test func replayNeverChangesProgress() async throws {
        var random: AuroraLoomSplitMix = AuroraLoomSplitMix(seed: Self.baseSeed &+ 41)
        var cache: [Int: AuroraLoomGenerated] = [:]
        var replayed: Int = 0
        for index in 0..<40 {
            let seed: UInt64 = random.next() % 1_000
            var core: Core = try await Core.prepare(seed: seed)
            let wins: Int = random.int(1...3)
            for _ in 0..<wins {
                try Self.win(&core, detour: random.below(3), &random, &cache)
                _ = core.apply(Self.bare("level.next"))
            }
            let solved: [Int] = core.progress.solved.keys.sorted()
            if solved.isEmpty { continue }
            let level: Int = solved[random.below(solved.count)]
            let before: AuroraLoomProgress = core.progress
            let bytes: Data = try before.encoded()
            #expect(core.apply(Self.valued("replay.start", [Double(level)])) == .accepted, "state \(index)")
            #expect(core.progress == before)
            let trace: [AuroraLoomMove] = try #require(before.solved[level]?.trace)
            for _ in 0..<(trace.count + 2) {
                let roll: Int = random.below(10)
                if roll < 2 {
                    #expect(core.apply(Self.bare("play.undo"))
                        == .rejected(.rule(code: AuroraLoomExperienceRule.replay)))
                } else if roll < 3 {
                    #expect(core.apply(Self.valued("level.select", [1]))
                        == .rejected(.rule(code: AuroraLoomExperienceRule.replay)))
                } else {
                    _ = core.apply(Self.bare("replay.step"))
                }
                #expect(core.progress == before, "state \(index)")
                #expect(try core.progress.encoded() == bytes, "state \(index)")
            }
            #expect(core.apply(Self.bare("replay.stop")) == .accepted)
            #expect(core.progress == before, "state \(index)")
            #expect(try core.progress.encoded() == bytes, "state \(index)")
            #expect(core.apply(Self.bare("replay.step")) == .rejected(.rule(code: AuroraLoomExperienceRule.noReplay)))
            replayed += 1
        }
        #expect(replayed == 40)
    }
}
