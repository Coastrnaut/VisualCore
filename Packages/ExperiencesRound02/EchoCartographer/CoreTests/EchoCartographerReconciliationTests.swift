// EchoCartographerReconciliationTests — feature 407 (R02-G11-07) T-R02G1107-002 (FR-R02G1107-001, 003; SC-R02G1107-001,
// 003; clarifications Q1, Q2, Q4). Every certified level's witness, stored as a trace with the witness energy and the
// stars by rule, verifies (five groups of 20 levels); an edited star count, an energy spent below the trace's energy, a
// changed trace step, an illegal action, an unwon trace and an overlong trace are dropped and counted; untraced results
// are kept unverified; the frontier is unchanged; the effective actions of record sequences with undo and redo
// (including the undo of a mark); the replacement rules of a traced record; Codable round trips and the decoding of
// schema 1 and 2 JSON; the replay mode's rules and encoding.
// Test data uses explicit types and plain loops (CI type-check rule).
@testable import EchoCartographerCore
import Foundation
import Testing

@Suite struct EchoCartographerReconciliationTests {
    typealias Progress = EchoCartographerProgress
    typealias Result = EchoCartographerProgress.Result
    typealias Mode = EchoCartographerMode
    typealias Play = EchoCartographerPlay
    typealias Core = EchoCartographerExperienceCore
    typealias Reconciliation = EchoCartographerReconciliation

    /// The witness result of certified level `number`: its witness actions as the trace, the witness energy (the plan's
    /// pulse count) as the energy spent, and the stars by rule.
    static func witnessResult(_ number: Int) throws -> Result {
        let certified: EchoCartographerGenerated = try Core.generated(number: number)
        let pulses: Int = certified.plan.pulses.count
        let trace: [EchoCartographerAction] = certified.actions
        return Result(energySpent: pulses, stars: Progress.stars(energySpent: pulses, certified: pulses),
                      trace: trace, verified: true)
    }

    /// Checks that every witness of levels `first` … `last` verifies and spends exactly the plan's pulse count.
    static func checkWitnesses(_ first: Int, _ last: Int) throws {
        for number in first...last {
            let result: Result = try Self.witnessResult(number)
            #expect(Reconciliation.verifies(level: number, result: result), "level \(number)")
            let certified: EchoCartographerGenerated = try Core.generated(number: number)
            var play: Play = try Core.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            #expect(play.stage == .won)
            #expect(certified.level.energy - play.energy == result.energySpent, "level \(number)")
            #expect(result.stars == 3)
        }
    }

    // MARK: Witnesses

    @Test func witnessesOfBand1Verify() throws { try Self.checkWitnesses(1, 20) }
    @Test func witnessesOfBand2Verify() throws { try Self.checkWitnesses(21, 40) }
    @Test func witnessesOfBand3Verify() throws { try Self.checkWitnesses(41, 60) }
    @Test func witnessesOfBand4Verify() throws { try Self.checkWitnesses(61, 80) }
    @Test func witnessesOfBand5Verify() throws { try Self.checkWitnesses(81, 100) }

    @Test func honestHigherEnergyVerifiesWithItsStars() throws {
        let witness: Result = try Self.witnessResult(4)
        let pulses: Int = witness.energySpent
        for extra in 0...5 {
            let spent: Int = pulses + extra
            let result: Result = Result(energySpent: spent, stars: Progress.stars(energySpent: spent, certified: pulses),
                                        trace: witness.trace, verified: true)
            #expect(Reconciliation.verifies(level: 4, result: result))
        }
    }

    // MARK: Tampering

    @Test func tamperedResultsAreDroppedAndCounted() throws {
        let witness: Result = try Self.witnessResult(5)
        let trace: [EchoCartographerAction] = witness.trace
        let pulses: Int = witness.energySpent
        #expect(pulses >= 1)
        var tampered: [Result] = []
        // Edited stars.
        tampered.append(Result(energySpent: pulses, stars: 2, trace: trace, verified: true))
        // Energy spent below the energy the trace spends (stars still by rule).
        tampered.append(Result(energySpent: pulses - 1,
                               stars: Progress.stars(energySpent: pulses - 1, certified: pulses),
                               trace: trace, verified: true))
        // A changed step: the last claim becomes a mark on the same cell, so the last beacon stays hidden.
        var changed: [EchoCartographerAction] = trace
        let lastIndex: Int = changed.count - 1
        let lastCell: EchoCartographerCell = changed[lastIndex].cell
        changed[lastIndex] = EchoCartographerAction.mark(lastCell.x, lastCell.y)
        tampered.append(Result(energySpent: pulses, stars: 3, trace: changed, verified: true))
        // An illegal action (outside the chamber) first.
        var illegal: [EchoCartographerAction] = [EchoCartographerAction.pulse(-1, -1)]
        illegal.append(contentsOf: trace)
        tampered.append(Result(energySpent: pulses, stars: 3, trace: illegal, verified: true))
        // An action after the win (the play is final).
        var after: [EchoCartographerAction] = trace
        after.append(EchoCartographerAction.mark(lastCell.x, lastCell.y))
        tampered.append(Result(energySpent: pulses, stars: 3, trace: after, verified: true))
        // An unwon trace (the last claim left out).
        var short: [EchoCartographerAction] = trace
        short.removeLast()
        tampered.append(Result(energySpent: pulses, stars: 3, trace: short, verified: true))
        // Verified but without a trace.
        tampered.append(Result(energySpent: pulses, stars: 3, trace: [], verified: true))

        for result in tampered {
            #expect(!Reconciliation.verifies(level: 5, result: result))
            let entries: Data = try Self.progressData(frontier: 12, level: 5, result: result)
            let loaded: Progress = try JSONDecoder().decode(Progress.self, from: entries)
            let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(loaded)
            #expect(outcome.dropped == 1)
            #expect(outcome.progress.solved[5] == nil)
            #expect(outcome.progress.frontier == 12)
        }
        // A level outside 1 … 100 never verifies.
        #expect(!Reconciliation.verifies(level: 0, result: witness))
        #expect(!Reconciliation.verifies(level: 101, result: witness))
        // The witness of level 5 is not a solution of another level.
        #expect(!Reconciliation.verifies(level: 6, result: witness))
    }

    @Test func overlongTracesNeverVerify() throws {
        let witness: Result = try Self.witnessResult(2)
        let entry: EchoCartographerCell = (try Core.generated(number: 2)).level.entry
        #expect(Reconciliation.maxTraceLength == 128)
        // Pairs of marker toggles before the witness keep it a winning play; the longest accepted length verifies.
        let room: Int = Reconciliation.maxTraceLength - witness.trace.count
        let pairs: Int = room / 2
        var longest: [EchoCartographerAction] = []
        for _ in 0..<(pairs * 2) { longest.append(EchoCartographerAction.mark(entry.x, entry.y)) }
        longest.append(contentsOf: witness.trace)
        #expect(longest.count <= Reconciliation.maxTraceLength)
        let fits: Result = Result(energySpent: witness.energySpent, stars: witness.stars, trace: longest, verified: true)
        #expect(Reconciliation.verifies(level: 2, result: fits))
        var overlong: [EchoCartographerAction] = []
        for _ in 0..<((pairs + 1) * 2) { overlong.append(EchoCartographerAction.mark(entry.x, entry.y)) }
        overlong.append(contentsOf: witness.trace)
        #expect(overlong.count > Reconciliation.maxTraceLength)
        let tooLong: Result = Result(energySpent: witness.energySpent, stars: witness.stars, trace: overlong,
                                     verified: true)
        #expect(!Reconciliation.verifies(level: 2, result: tooLong))
        let data: Data = try Self.progressData(frontier: 3, level: 2, result: tooLong)
        let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(
            try JSONDecoder().decode(Progress.self, from: data))
        #expect(outcome.dropped == 1)
        #expect(outcome.progress.frontier == 3)
    }

    @Test func reconcileKeepsHonestAndUntracedResults() throws {
        var progress: Progress = Progress()
        var changed: Bool = false
        progress.open(through: 40)
        for number in 1...3 {
            let witness: Result = try Self.witnessResult(number)
            changed = progress.record(level: number, energySpent: witness.energySpent,
                                    certified: witness.energySpent, trace: witness.trace)
            #expect(changed)
        }
        progress.record(level: 7, energySpent: 9, certified: 3)          // untraced
        progress.record(level: 9, energySpent: 2, certified: 3, mode: .daily(level: 9))   // untraced
        let witness: Result = try Self.witnessResult(8)
        progress.record(level: 8, energySpent: witness.energySpent, certified: witness.energySpent + 1,
                        trace: witness.trace)                            // stars by the wrong plan: 3, not dropped
        let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(outcome.dropped == 0)
        #expect(outcome.progress == progress)
        #expect(outcome.progress.frontier == 40)
        #expect(outcome.progress.solved[7]?.verified == false)
        #expect(outcome.progress.solved[7]?.trace.isEmpty == true)
        #expect(outcome.progress.solved[1]?.verified == true)

        // A tampered level among honest ones: only it is dropped; the frontier stays.
        let tampered: Result = Result(energySpent: witness.energySpent, stars: 1, trace: witness.trace, verified: true)
        var honest: Progress = progress
        honest.drop(level: 8)
        let honestText: String = String(decoding: try honest.encoded(), as: UTF8.self)
        let tamperedText: String = String(decoding: try Self.progressData(frontier: 40, level: 8, result: tampered),
                                          as: UTF8.self)
        let entryStart: String.Index = try #require(tamperedText.range(of: "[")).upperBound
        let entryText: String = String(tamperedText[entryStart...].dropLast(2))
        let mixedText: String = String(honestText.dropLast(2)) + "," + entryText + "]}"
        let loaded: Progress = try JSONDecoder().decode(Progress.self, from: Data(mixedText.utf8))
        #expect(loaded.solved.count == honest.solved.count + 1)
        let mixed: (progress: Progress, dropped: Int) = Reconciliation.reconcile(loaded)
        #expect(mixed.dropped == 1)
        #expect(mixed.progress == honest)
        #expect(mixed.progress.frontier == 40)
    }

    // MARK: Net trace

    @Test func netTraceFollowsUndoAndRedo() throws {
        let certified: EchoCartographerGenerated = try Core.generated(number: 6)
        let entry: EchoCartographerCell = certified.level.entry
        let witness: [EchoCartographerAction] = certified.actions
        let mark: EchoCartographerAction = EchoCartographerAction.mark(entry.x, entry.y)
        var play: Play = try Core.freshPlay(of: certified.level)
        // A mark, then undo of the mark: nothing effective.
        try play.apply(mark, expecting: play.fingerprint)
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        // Redo brings the mark back.
        try play.redo()
        var expected: [EchoCartographerAction] = [mark]
        #expect(Reconciliation.netTrace(play.records) == expected)
        // The witness's first pulse, undone and redone, twice.
        let first: EchoCartographerAction = witness[0]
        try play.apply(first, expecting: play.fingerprint)
        try play.undo()
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        try play.redo()
        try play.redo()
        expected.append(first)
        #expect(Reconciliation.netTrace(play.records) == expected)
        // An undo then a new action clears the redo stack.
        try play.undo()
        try play.apply(mark, expecting: play.fingerprint)      // toggles the mark off
        expected = [mark, mark]
        #expect(Reconciliation.netTrace(play.records) == expected)
        #expect(throws: EchoCartographerError.self) { try play.redo() }
        // Undo of that mark, then the rest of the witness.
        try play.undo()
        expected = [mark]
        #expect(Reconciliation.netTrace(play.records) == expected)
        for action in witness {
            try play.apply(action, expecting: play.fingerprint)
            expected.append(action)
        }
        #expect(play.stage == .won)
        let net: [EchoCartographerAction] = Reconciliation.netTrace(play.records)
        #expect(net == expected)
        // The net trace replays to the same outcome and energy; the energy spent counts the undone pulse too.
        var fresh: Play = try Core.freshPlay(of: certified.level)
        for action in net {
            try fresh.apply(action, expecting: fresh.fingerprint)
        }
        #expect(fresh.stage == .won)
        #expect(fresh.energy == play.energy)
        #expect(fresh.markers == play.markers)
        let spent: Int = Progress.energySpent(play)
        #expect(spent == certified.plan.pulses.count + 1)
        let result: Result = Result(energySpent: spent,
                                    stars: Progress.stars(energySpent: spent, certified: certified.plan.pulses.count),
                                    trace: net, verified: true)
        #expect(Reconciliation.verifies(level: 6, result: result))
    }

    // MARK: Record rules

    @Test func tracedRecordReplacesOnlyWhenBetter() throws {
        let traceA: [EchoCartographerAction] = [EchoCartographerAction.pulse(1, 1)]
        let traceB: [EchoCartographerAction] = [EchoCartographerAction.pulse(2, 2)]
        let traceC: [EchoCartographerAction] = [EchoCartographerAction.claim(3, 3)]
        var progress: Progress = Progress()
        var changed: Bool = false
        changed = progress.record(level: 4, energySpent: 6, certified: 3, trace: traceA)
        #expect(changed)
        #expect(progress.solved[4] == Result(energySpent: 6, stars: 1, trace: traceA, verified: true))
        #expect(progress.frontier == 5)
        // A tie keeps the earlier trace; a worse result keeps it too.
        changed = progress.record(level: 4, energySpent: 6, certified: 3, trace: traceB)
        #expect(!changed)
        changed = progress.record(level: 4, energySpent: 7, certified: 3, trace: traceB)
        #expect(!changed)
        #expect(progress.solved[4]?.trace == traceA)
        // Equal energy, more stars (an easier certified count) replaces.
        changed = progress.record(level: 4, energySpent: 6, certified: 4, trace: traceB)
        #expect(changed)
        #expect(progress.solved[4] == Result(energySpent: 6, stars: 2, trace: traceB, verified: true))
        // Less energy replaces.
        changed = progress.record(level: 4, energySpent: 3, certified: 3, trace: traceC)
        #expect(changed)
        #expect(progress.solved[4] == Result(energySpent: 3, stars: 3, trace: traceC, verified: true))
        // A traced result replaces an untraced worse one.
        progress.record(level: 9, energySpent: 8, certified: 3)
        #expect(progress.solved[9]?.verified == false)
        changed = progress.record(level: 9, energySpent: 5, certified: 3, trace: traceA)
        #expect(changed)
        #expect(progress.solved[9]?.verified == true)
        // Practice and replay record nothing and open nothing; daily records and opens nothing.
        let frontier: Int = progress.frontier
        changed = progress.record(level: 30, energySpent: 1, certified: 3, mode: .practice, trace: traceA)
        #expect(!changed)
        changed = progress.record(level: 30, energySpent: 1, certified: 3, mode: .replay(level: 30), trace: traceA)
        #expect(!changed)
        changed = progress.record(level: 30, energySpent: 1, certified: 3, mode: .replay(level: 30))
        #expect(!changed)
        #expect(progress.solved[30] == nil)
        changed = progress.record(level: 30, energySpent: 1, certified: 3, mode: .daily(level: 30), trace: traceA)
        #expect(changed)
        #expect(progress.solved[30]?.verified == true)
        #expect(progress.frontier == frontier)
        // Outside 1 … 100 is ignored.
        changed = progress.record(level: 0, energySpent: 1, certified: 3, trace: traceA)
        #expect(!changed)
        changed = progress.record(level: 101, energySpent: 1, certified: 3, trace: traceA)
        #expect(!changed)
        // Drop removes a result and keeps the frontier; dropping nothing changes nothing.
        progress.drop(level: 4)
        #expect(progress.solved[4] == nil)
        #expect(progress.frontier == frontier)
        let before: Progress = progress
        progress.drop(level: 50)
        #expect(progress == before)
    }

    // MARK: Codable

    @Test func tracedProgressRoundTrips() throws {
        var progress: Progress = Progress()
        for number in 1...4 {
            let witness: Result = try Self.witnessResult(number)
            progress.record(level: number, energySpent: witness.energySpent, certified: witness.energySpent,
                            trace: witness.trace)
        }
        progress.record(level: 12, energySpent: 5, certified: 3, opensNext: false)
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        #expect(decoded.solved[1]?.verified == true)
        #expect(decoded.solved[12]?.verified == false)
        // A result encodes its trace and verified flag, also when untraced.
        var single: Progress = Progress()
        single.record(level: 1, energySpent: 2, certified: 3)
        #expect(String(decoding: try single.encoded(), as: UTF8.self)
            == "{\"frontier\":2,\"solved\":[{\"energySpent\":2,\"level\":1,\"stars\":3,\"trace\":[],\"verified\":false}]}")
        var traced: Progress = Progress()
        traced.record(level: 1, energySpent: 1, certified: 3, trace: [EchoCartographerAction.pulse(2, 3)])
        #expect(String(decoding: try traced.encoded(), as: UTF8.self)
            == "{\"frontier\":2,\"solved\":[{\"energySpent\":1,\"level\":1,\"stars\":3,"
            + "\"trace\":[{\"pulse\":{\"_0\":2,\"_1\":3}}],\"verified\":true}]}")
    }

    @Test func schemaTwoJSONDecodesUnverified() throws {
        let old: String = "{\"frontier\":5,\"solved\":[{\"level\":1,\"energySpent\":2,\"stars\":3},"
            + "{\"level\":4,\"energySpent\":9,\"stars\":1}]}"
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: Data(old.utf8))
        #expect(decoded.frontier == 5)
        #expect(decoded.solved[1] == Result(energySpent: 2, stars: 3))
        #expect(decoded.solved[1]?.trace.isEmpty == true)
        #expect(decoded.solved[1]?.verified == false)
        #expect(decoded.solved[4] == Result(energySpent: 9, stars: 1, trace: [], verified: false))
        let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(decoded)
        #expect(outcome.dropped == 0)
        #expect(outcome.progress == decoded)
        // A result alone also decodes without trace and verified.
        let single: Result = try JSONDecoder().decode(Result.self, from: Data("{\"energySpent\":3,\"stars\":2}".utf8))
        #expect(single == Result(energySpent: 3, stars: 2))
        let encoded: Data = try JSONEncoder().encode(Result(energySpent: 3, stars: 2,
                                                            trace: [EchoCartographerAction.mark(1, 2)], verified: true))
        let back: Result = try JSONDecoder().decode(Result.self, from: encoded)
        #expect(back.trace == [EchoCartographerAction.mark(1, 2)])
        #expect(back.verified)
    }

    @Test func replayModeRulesAndEncoding() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder: JSONDecoder = JSONDecoder()
        #expect(String(decoding: try encoder.encode(Mode.replay(level: 5)), as: UTF8.self)
            == "{\"level\":5,\"mode\":\"replay\"}")
        let modes: [Mode] = [.replay(level: 1), .replay(level: 100), .campaign, .practice, .daily(level: 3)]
        for mode in modes {
            #expect(try decoder.decode(Mode.self, from: try encoder.encode(mode)) == mode)
        }
        let bad: [String] = ["{\"mode\":\"replay\",\"level\":0}", "{\"mode\":\"replay\",\"level\":101}",
                             "{\"mode\":\"replay\"}"]
        for text in bad {
            #expect(throws: DecodingError.self) { try decoder.decode(Mode.self, from: Data(text.utf8)) }
        }
        let replay: Mode = .replay(level: 9)
        #expect(!replay.awardsStars)
        #expect(!replay.opensLevels)
        #expect(replay.energy(base: 17) == 17)
        #expect(replay != .daily(level: 9))
        #expect(EchoCartographerFeedbackPlan.modeName(replay) == "replay")
    }

    /// The JSON of progress with frontier `frontier` and the single won level `level` with `result`.
    static func progressData(frontier: Int, level: Int, result: Result) throws -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let resultData: Data = try encoder.encode(result)
        let resultText: String = String(decoding: resultData, as: UTF8.self)
        let entry: String = "{\"level\":\(level)," + resultText.dropFirst()
        let text: String = "{\"frontier\":\(frontier),\"solved\":[" + entry + "]}"
        return Data(text.utf8)
    }
}
