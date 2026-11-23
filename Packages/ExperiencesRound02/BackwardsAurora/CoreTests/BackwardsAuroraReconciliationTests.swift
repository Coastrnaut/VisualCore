// BackwardsAuroraReconciliationTests — feature 397 (R02-G10-07) T-R02G1007-002 (FR-R02G1007-001, 002, 003;
// clarifications Q1, Q2, Q3, Q4; research R2, R3, R4, R6, R7; contracts/api.md). Host checks of the traced results and
// of reconciliation: every certified level's solution recorded as a trace verifies with three stars (ten groups of ten
// levels; the 100 certified levels generated concurrently once per test process); a traced win is verified, a better
// one replaces it and ties keep the earlier trace; practice and replay record nothing; `drop(level:)`; an edited star
// count, a reversal count below the trace length, a removed or changed trace step, an illegal reversal and an over-long
// trace are dropped and counted, while a reversal count above the trace length with matching stars is kept; a result
// without a trace is kept unverified; the frontier stays as saved; old payloads without trace or verified decode; the
// replay mode encodes like daily and refuses levels outside 1 … 100; the net trace of hand-made records and of a real
// play with undo and redo equals the hand-computed list, and over seeded undo/redo sequences (seed 2_397) replays to
// the same fingerprint. Edited saves are made by editing the encoded JSON, as a tampered file would be. Explicit types
// and plain loops (CI type-check rule); each test < 10 s. Modelled on feature 387's NocturneGardenReconciliationTests.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BackwardsAuroraCore

/// The 100 certified levels in manifest order, generated concurrently once per test process (the adapter's cache is
/// shared, so whichever suite runs first pays the generation).
private let reconciliationCatalogResult: Swift.Result<[BackwardsAuroraGenerated], any Error> = Swift.Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? BackwardsAuroraExperienceCore.generated(number: index + 1)
    }
    var catalog: [BackwardsAuroraGenerated] = []
    for number in 1...100 { catalog.append(try BackwardsAuroraExperienceCore.generated(number: number)) }
    return catalog
}

@Suite struct BackwardsAuroraReconciliationTests {
    typealias Core = BackwardsAuroraExperienceCore
    typealias Progress = BackwardsAuroraProgress
    typealias Reconciliation = BackwardsAuroraReconciliation
    typealias Action = BackwardsAuroraAction
    typealias Play = BackwardsAuroraPlay
    typealias Mode = BackwardsAuroraMode

    /// The certified catalog (generated once, concurrently).
    static func catalog() throws -> [BackwardsAuroraGenerated] { try reconciliationCatalogResult.get() }

    /// The certified level and solution of level `number` (1 … 100), from the prewarmed catalog.
    static func certified(_ number: Int) throws -> BackwardsAuroraGenerated {
        let all: [BackwardsAuroraGenerated] = try Self.catalog()
        return all[number - 1]
    }

    /// The certified solution reversals of level `number`.
    static func solution(_ number: Int) throws -> [Action] {
        let actions: [Action] = try Self.certified(number).solution.actions
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The certified smallest reversal count of level `number`.
    static func smallest(_ number: Int) throws -> Int {
        try Self.certified(number).solution.smallest
    }

    /// A fresh campaign play of certified level `number`.
    static func fresh(_ number: Int) throws -> Play {
        try Core.freshPlay(of: try Self.certified(number).level)
    }

    /// The play after applying `trace` on a fresh play of level `number`.
    static func played(_ number: Int, _ trace: [Action]) throws -> Play {
        var play: Play = try Self.fresh(number)
        for action in trace { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// Progress with honest verified campaign wins of `levels` (each its certified solution as the trace).
    static func honest(_ levels: [Int]) throws -> Progress {
        var progress: Progress = Progress()
        for level in levels {
            let trace: [Action] = try Self.solution(level)
            let made: Int = Progress.reversalsMade(try Self.played(level, trace))
            progress.record(level: level, reversalsMade: made, smallest: try Self.smallest(level), mode: .campaign,
                            trace: trace)
        }
        return progress
    }

    /// The first level of 1 … 100 whose smallest count is at least 2 and whose budget leaves room for a detour
    /// reversal beyond it.
    static func roomyLevel() throws -> Int {
        for number in Core.levelNumbers {
            let generated: BackwardsAuroraGenerated = try Self.certified(number)
            let smallest: Int = generated.solution.smallest
            if smallest >= 2 && generated.level.budget >= smallest + 2 { return number }
        }
        Issue.record("no level with smallest ≥ 2 and budget ≥ smallest + 2")
        return 1
    }

    /// Every reversal of `play`'s level in a fixed order (starts ascending, then lengths ascending).
    static func candidates(_ play: Play) -> [Action] {
        var all: [Action] = []
        let count: Int = play.wave.count
        for start in 0..<count {
            for length in play.level.sectionLengths where start + length - 1 < count {
                all.append(Action.reverse(start, start + length - 1))
            }
        }
        return all
    }

    /// The first accepted reversal on `play` other than `excluded` after which the play is not won; nil when none.
    static func nonWinning(_ play: Play, excluding excluded: Action?) -> Action? {
        for candidate in Self.candidates(play) where candidate != excluded {
            var probe: Play = play
            guard (try? probe.apply(candidate, expecting: probe.fingerprint)) != nil else { continue }
            if probe.stage != .won { return candidate }
        }
        return nil
    }

    /// `progress` encoded, its won entry for `level` edited by `edit`, decoded again.
    static func edited(_ progress: Progress, level: Int,
                       _ edit: (inout [String: Any]) throws -> Void) throws -> Progress {
        let data: Data = try progress.encoded()
        var object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var entries: [[String: Any]] = try #require(object["solved"] as? [[String: Any]])
        for index in entries.indices where entries[index]["level"] as? Int == level {
            try edit(&entries[index])
        }
        object["solved"] = entries
        return try JSONDecoder().decode(Progress.self, from: try JSONSerialization.data(withJSONObject: object))
    }

    /// `progress` with the trace of `level` replaced by `trace`.
    static func retraced(_ progress: Progress, level: Int, _ trace: [Action]) throws -> Progress {
        let encoded: Any = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(trace))
        return try Self.edited(progress, level: level) { (entry: inout [String: Any]) in entry["trace"] = encoded }
    }

    /// Every certified level of group `group` (0 … 9: levels 10 × group + 1 … 10 × group + 10), recorded with its
    /// certified solution as the trace, verifies with its certified smallest reversal count and three stars and is
    /// kept.
    @Test(arguments: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    func certifiedSolutionsVerify(group: Int) throws {
        var levels: [Int] = []
        for offset in 1...10 { levels.append(group * 10 + offset) }
        _ = try Self.catalog()
        let progress: Progress = try Self.honest(levels)
        for level in levels {
            let result: Progress.Result = try #require(progress.solved[level])
            #expect(result.verified && result.stars == 3, "level \(level)")
            #expect(result.reversalsMade == (try Self.smallest(level)), "level \(level)")
            #expect(result.trace.count == result.reversalsMade, "level \(level)")
            #expect(result.trace.count <= Reconciliation.maxTraceLength, "level \(level)")
            #expect(Reconciliation.verifies(level: level, result: result), "level \(level)")
        }
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
    }

    @Test func aTracedWinIsVerifiedAndOnlyABetterOneReplacesIt() throws {
        let level: Int = try Self.roomyLevel()
        let best: [Action] = try Self.solution(level)
        let smallest: Int = try Self.smallest(level)
        // A detour: a non-winning reversal undone, then the solution (one more reversal made, the same effective
        // reversals).
        var detour: Play = try Self.fresh(level)
        let neutral: Action = try #require(Self.nonWinning(detour, excluding: nil))
        try detour.apply(neutral, expecting: detour.fingerprint)
        try detour.undo()
        for action in best { try detour.apply(action, expecting: detour.fingerprint) }
        #expect(detour.stage == .won)
        let detourMade: Int = Progress.reversalsMade(detour)
        #expect(detourMade == smallest + 1)
        let detourTrace: [Action] = Reconciliation.netTrace(detour.records)
        #expect(detourTrace == best)
        var progress: Progress = Progress()
        let first: Bool = progress.record(level: level, reversalsMade: detourMade, smallest: smallest,
                                          trace: detourTrace)
        #expect(first)
        #expect(progress.solved[level]?.verified == true)
        #expect(progress.solved[level]?.stars == 2)
        #expect(Reconciliation.verifies(level: level, result: try #require(progress.solved[level])))
        let fewer: Bool = progress.record(level: level, reversalsMade: smallest, smallest: smallest, trace: best)
        #expect(fewer)
        #expect(progress.solved[level]?.reversalsMade == smallest && progress.solved[level]?.stars == 3)
        // A tie keeps the earlier trace; more reversals never replace.
        let other: [Action] = [Action.reverse(0, 1)]
        let tie: Bool = progress.record(level: level, reversalsMade: smallest, smallest: smallest, trace: other)
        #expect(!tie && progress.solved[level]?.trace == best)
        let more: Bool = progress.record(level: level, reversalsMade: smallest + 2, smallest: smallest, trace: other)
        #expect(!more && progress.solved[level]?.trace == best)
        #expect(progress.frontier == level + 1)
        // Daily opens nothing; practice and replay record nothing; a level outside 1 … 100 is ignored.
        let daily: Bool = progress.record(level: 60, reversalsMade: 9, smallest: 8, mode: .daily(level: 60),
                                          trace: best)
        #expect(daily && progress.frontier == level + 1 && progress.solved[60]?.verified == true)
        let practice: Bool = progress.record(level: 61, reversalsMade: 9, smallest: 8, mode: .practice, trace: best)
        let replay: Bool = progress.record(level: 62, reversalsMade: 9, smallest: 8, mode: .replay(level: 62),
                                           trace: best)
        let outside: Bool = progress.record(level: 101, reversalsMade: 9, smallest: 8, trace: best)
        let below: Bool = progress.record(level: 0, reversalsMade: 9, smallest: 8, trace: best)
        #expect(!practice && !replay && !outside && !below)
        #expect(progress.solved[61] == nil && progress.solved[62] == nil && progress.solved[101] == nil)
        let untracedReplay: Bool = progress.record(level: 63, reversalsMade: 9, smallest: 8, mode: .replay(level: 63))
        #expect(!untracedReplay && progress.solved[63] == nil)
        #expect(progress.frontier == level + 1)
        // A win without a trace is unverified, as before.
        progress.record(level: 2, reversalsMade: 19, smallest: 6, opensNext: false)
        #expect(progress.solved[2] == Progress.Result(reversalsMade: 19, stars: 1))
        #expect(progress.solved[2]?.verified == false && progress.solved[2]?.trace.isEmpty == true)
        // drop removes the result; the frontier is unchanged; dropping an absent level changes nothing.
        let frontier: Int = progress.frontier
        progress.drop(level: level)
        #expect(progress.solved[level] == nil && progress.frontier == frontier)
        progress.drop(level: 77)
        #expect(progress.solved.count == 2)
    }

    @Test func tracesEncodeOldPayloadsDecodeAndTheReplayModeAwardsNothing() throws {
        let progress: Progress = try Self.honest([1, 2])
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"trace\":["))
        #expect(text.contains("\"verified\":true"))
        let old: Data = Data("{\"frontier\":3,\"solved\":[{\"level\":1,\"reversalsMade\":5,\"stars\":2}]}".utf8)
        let restored: Progress = try JSONDecoder().decode(Progress.self, from: old)
        #expect(restored.solved[1] == Progress.Result(reversalsMade: 5, stars: 2))
        #expect(restored.solved[1]?.verified == false && restored.solved[1]?.trace.isEmpty == true)
        let reencoded: String = String(decoding: try restored.encoded(), as: UTF8.self)
        #expect(reencoded == "{\"frontier\":3,\"solved\":[{\"level\":1,\"reversalsMade\":5,\"stars\":2,\"trace\":[],"
            + "\"verified\":false}]}")
        // The result alone decodes without trace and verified too.
        let bare: Data = Data("{\"reversalsMade\":4,\"stars\":3}".utf8)
        #expect(try JSONDecoder().decode(Progress.Result.self, from: bare)
            == Progress.Result(reversalsMade: 4, stars: 3))
        // A traced result round trips with its reversals in order.
        let actions: [Action] = [Action.reverse(3, 7), Action.reverse(0, 2), Action.reverse(5, 9)]
        let traced: Progress.Result = Progress.Result(reversalsMade: 4, stars: 2, trace: actions, verified: true)
        let tracedData: Data = try JSONEncoder().encode(traced)
        #expect(try JSONDecoder().decode(Progress.Result.self, from: tracedData) == traced)
        // The replay mode; the campaign, practice and daily encodings are unchanged.
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let replay: Mode = .replay(level: 48)
        let replayData: Data = try encoder.encode(replay)
        #expect(String(decoding: replayData, as: UTF8.self) == "{\"level\":48,\"mode\":\"replay\"}")
        #expect(try JSONDecoder().decode(Mode.self, from: replayData) == replay)
        let edges: [Mode] = [.replay(level: 1), .replay(level: 100)]
        for mode in edges {
            #expect(try JSONDecoder().decode(Mode.self, from: try encoder.encode(mode)) == mode)
        }
        #expect(String(decoding: try encoder.encode(Mode.campaign), as: UTF8.self) == "{\"mode\":\"campaign\"}")
        #expect(String(decoding: try encoder.encode(Mode.practice), as: UTF8.self) == "{\"mode\":\"practice\"}")
        #expect(String(decoding: try encoder.encode(Mode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        let badModes: [String] = ["{\"mode\":\"replay\",\"level\":0}", "{\"mode\":\"replay\",\"level\":101}",
                                  "{\"mode\":\"replay\",\"level\":-3}", "{\"mode\":\"replay\"}",
                                  "{\"mode\":\"rewind\",\"level\":1}"]
        for json in badModes {
            #expect(throws: DecodingError.self) { try JSONDecoder().decode(Mode.self, from: Data(json.utf8)) }
        }
        #expect(!replay.awardsStars && !replay.opensLevels)
        #expect(replay.budget(base: 9) == 9)
        #expect(Mode.campaign.awardsStars && Mode.daily(level: 3).awardsStars)
        #expect(!Mode.practice.awardsStars)
        #expect(BackwardsAuroraFeedbackPlan.modeName(replay) == "replay")
        let largestBudget: Int = BackwardsAuroraLevel.budgets.upperBound
        #expect(Reconciliation.maxTraceLength == 40 && Reconciliation.maxTraceLength == largestBudget)
    }

    @Test func editedStarsReversalsStepsIllegalAndOverlongTracesAreDropped() throws {
        let levels: [Int] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
        _ = try Self.catalog()
        let progress: Progress = try Self.honest(levels)
        // Level 4: stars edited.
        var tampered: Progress = try Self.edited(progress, level: 4) { (entry: inout [String: Any]) in
            entry["stars"] = 2
        }
        // Level 5: reversals made edited below the trace length (still three stars: only the trace length sees it).
        tampered = try Self.edited(tampered, level: 5) { (entry: inout [String: Any]) in
            entry["reversalsMade"] = ((entry["reversalsMade"] as? Int) ?? 0) - 1
        }
        #expect(tampered.solved[5]?.stars == 3)
        // Level 6: one trace step removed (fewer reversals than the certified smallest count cannot win; a one-step
        // solution leaves an empty trace that claims to be verified, which never verifies either).
        var removed: [Action] = try Self.solution(6)
        removed.remove(at: 0)
        tampered = try Self.retraced(tampered, level: 6, removed)
        // Level 7: the last reversal changed into the first other accepted reversal that does not win (same length).
        let solution7: [Action] = try Self.solution(7)
        let lastIndex: Int = solution7.count - 1
        let before7: Play = try Self.played(7, Array(solution7.prefix(lastIndex)))
        let replacement: Action = try #require(Self.nonWinning(before7, excluding: solution7[lastIndex]))
        let changed: [Action] = Array(solution7.prefix(lastIndex)) + [replacement]
        #expect(changed.count == solution7.count && changed != solution7)
        tampered = try Self.retraced(tampered, level: 7, changed)
        // Level 8: an illegal reversal (a start not before its end) before the solution.
        tampered = try Self.retraced(tampered, level: 8, [Action.reverse(5, 2)] + (try Self.solution(8)))
        // Level 9: an illegal reversal (an end outside the wave) before the solution.
        tampered = try Self.retraced(tampered, level: 9, [Action.reverse(0, 99)] + (try Self.solution(9)))
        // Level 10: a reversal after the win (a won play refuses every action).
        let solution10: [Action] = try Self.solution(10)
        tampered = try Self.retraced(tampered, level: 10, solution10 + [solution10[0]])
        tampered = try Self.edited(tampered, level: 10) { (entry: inout [String: Any]) in
            entry["reversalsMade"] = solution10.count + 1
            entry["stars"] = 2
        }
        // Level 11: an over-long trace (41 reversals) with a matching reversal count and stars.
        let solution11: [Action] = try Self.solution(11)
        var overlong: [Action] = []
        while overlong.count < Reconciliation.maxTraceLength + 1 { overlong.append(solution11[0]) }
        #expect(overlong.count == 41 && Reconciliation.maxTraceLength == 40)
        tampered = try Self.retraced(tampered, level: 11, overlong)
        tampered = try Self.edited(tampered, level: 11) { (entry: inout [String: Any]) in
            entry["reversalsMade"] = 41
            entry["stars"] = 1
        }
        // Level 12: reversals made raised above the trace length with the stars that count gives (kept: R7).
        let smallest12: Int = try Self.smallest(12)
        tampered = try Self.edited(tampered, level: 12) { (entry: inout [String: Any]) in
            entry["reversalsMade"] = smallest12 + 3
            entry["stars"] = 1
        }
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(tampered)
        #expect(reconciled.dropped == 8)
        let expectedKept: [Int] = [3, 12, 13]
        #expect(reconciled.progress.solved.keys.sorted() == expectedKept)
        #expect(reconciled.progress.solved[3] == progress.solved[3])
        #expect(reconciled.progress.solved[13] == progress.solved[13])
        #expect(reconciled.progress.solved[12]?.reversalsMade == smallest12 + 3)
        #expect(reconciled.progress.solved[12]?.verified == true)
        #expect(reconciled.progress.frontier == progress.frontier)
        // The same raised count with three stars claimed is dropped.
        let greedy: Progress = try Self.edited(tampered, level: 12) { (entry: inout [String: Any]) in
            entry["stars"] = 3
        }
        #expect(!Reconciliation.verifies(level: 12, result: try #require(greedy.solved[12])))
    }

    @Test func untracedResultsAreKeptAndTheFrontierStaysAsSaved() throws {
        _ = try Self.catalog()
        var progress: Progress = try Self.honest([9])
        progress.record(level: 3, reversalsMade: 12, smallest: 5, mode: .campaign)
        // A daily traced win beyond the frontier.
        let daily: [Action] = try Self.solution(60)
        progress.record(level: 60, reversalsMade: Progress.reversalsMade(try Self.played(60, daily)),
                        smallest: try Self.smallest(60), mode: .daily(level: 60), trace: daily)
        #expect(progress.frontier == 10)
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
        #expect(reconciled.progress.solved[3]?.verified == false)
        #expect(reconciled.progress.frontier == 10)
        // Dropping never lowers the frontier.
        let tampered: Progress = try Self.edited(progress, level: 9) { (entry: inout [String: Any]) in
            entry["stars"] = 1
        }
        let after: (progress: Progress, dropped: Int) = Reconciliation.reconcile(tampered)
        #expect(after.dropped == 1 && after.progress.frontier == 10 && after.progress.solved[9] == nil)
        // A result claimed verified without a trace, or at a level outside 1 … 100, never verifies.
        let empty: Progress.Result = Progress.Result(reversalsMade: 3, stars: 3, trace: [], verified: true)
        #expect(!Reconciliation.verifies(level: 1, result: empty))
        let claimed: Progress = try Self.edited(progress, level: 3) { (entry: inout [String: Any]) in
            entry["verified"] = true
        }
        let claimedAfter: (progress: Progress, dropped: Int) = Reconciliation.reconcile(claimed)
        #expect(claimedAfter.dropped == 1 && claimedAfter.progress.solved[3] == nil)
        // A trace on a result marked unverified is still checked (and dropped when it does not replay).
        let unmarked: Progress = try Self.edited(tampered, level: 9) { (entry: inout [String: Any]) in
            entry["verified"] = false
        }
        #expect(Reconciliation.reconcile(unmarked).dropped == 1)
        let honest9: Progress.Result = try #require(progress.solved[9])
        #expect(Reconciliation.verifies(level: 9, result: honest9))
        #expect(!Reconciliation.verifies(level: 0, result: honest9))
        #expect(!Reconciliation.verifies(level: 101, result: honest9))
        // An honest trace stored under another level does not verify there.
        #expect(!Reconciliation.verifies(level: 10, result: honest9))
    }

    @Test func netTraceCancelsUndoneReversalsAndRestoresRedoneOnes() throws {
        // Hand-made records: a, b, undo, undo, redo, c, redo (nothing to redo), d → a, c, d.
        let a: Action = Action.reverse(0, 3)
        let b: Action = Action.reverse(2, 5)
        let c: Action = Action.reverse(4, 8)
        let d: Action = Action.reverse(1, 6)
        let kinds: [BackwardsAuroraRecordKind] = [.reverse, .reverse, .undo, .undo, .redo, .reverse, .redo, .reverse]
        let actions: [Action?] = [a, b, nil, nil, nil, c, nil, d]
        var records: [BackwardsAuroraRecord] = []
        for index in kinds.indices {
            records.append(BackwardsAuroraRecord(schema: 1, seed: 1, move: 0, kind: kinds[index],
                                                 action: actions[index], previous: "a", next: "b"))
        }
        let expected: [Action] = [a, c, d]
        #expect(Reconciliation.netTrace(records) == expected)
        #expect(Reconciliation.netTrace([]).isEmpty)
        // A redo after a new reversal restores nothing (the new reversal cleared the redo stack); an undo with
        // nothing to undo changes nothing.
        let clearedKinds: [BackwardsAuroraRecordKind] = [.undo, .reverse, .undo, .reverse, .redo]
        let clearedActions: [Action?] = [nil, a, nil, b, nil]
        var cleared: [BackwardsAuroraRecord] = []
        for index in clearedKinds.indices {
            cleared.append(BackwardsAuroraRecord(schema: 1, seed: 1, move: 0, kind: clearedKinds[index],
                                                 action: clearedActions[index], previous: "a", next: "b"))
        }
        let clearedExpected: [Action] = [b]
        #expect(Reconciliation.netTrace(cleared) == clearedExpected)

        // A real play with detours undone and redone: its net trace is the hand-computed list, replays to the same
        // fingerprint and verifies with the stars of its reversals made.
        let level: Int = try Self.roomyLevel()
        let best: [Action] = try Self.solution(level)
        let smallest: Int = try Self.smallest(level)
        var play: Play = try Self.fresh(level)
        try play.apply(best[0], expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        let neutral: Action = try #require(Self.nonWinning(play, excluding: best[1]))
        try play.apply(neutral, expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        try play.undo()
        for index in 1..<best.count { try play.apply(best[index], expecting: play.fingerprint) }
        #expect(play.stage == .won)
        let net: [Action] = Reconciliation.netTrace(play.records)
        #expect(net == best)
        let again: Play = try Self.played(level, net)
        #expect(again.fingerprint == play.fingerprint)
        let made: Int = Progress.reversalsMade(play)
        // Undo and redo records are not reversals: the solution plus the one undone detour.
        #expect(made == smallest + 1)
        let stars: Int = Progress.stars(reversalsMade: made, smallest: smallest)
        #expect(stars == 2)
        let result: Progress.Result = Progress.Result(reversalsMade: made, stars: stars, trace: net, verified: true)
        #expect(Reconciliation.verifies(level: level, result: result))
    }

    /// A seeded reversal for `play`: an allowed section length at a seeded start; it may be refused.
    static func seededAction(_ play: Play, _ random: inout SeededRandom) -> Action {
        let lengths: ClosedRange<Int> = play.level.sectionLengths
        let count: Int = play.wave.count
        let length: Int = min(random.int(lengths), count)
        let start: Int = random.int(0...(count - length))
        return Action.reverse(start, start + length - 1)
    }

    @Test func netTraceOfSeededUndoRedoSequencesReplaysToTheSameFingerprint() throws {
        // Seed 2_397: 60 random sequences of reversals (refusals ignored), undos and redos on the practice copy of
        // level 48 (budget 40); the net trace replayed on a fresh practice play reaches the same fingerprint and holds
        // exactly the reversals spent.
        var random: SeededRandom = SeededRandom(seed: 2_397)
        let certified: BackwardsAuroraLevel = try Self.certified(48).level
        let practice: BackwardsAuroraLevel = try Core.practiceLevel(of: certified)
        var undone: Int = 0
        var redone: Int = 0
        for _ in 0..<60 {
            var play: Play = try Core.freshPlay(of: practice)
            let length: Int = random.int(0...16)
            for _ in 0..<length {
                let roll: Int = random.int(0...9)
                if roll < 6 {
                    let action: Action = Self.seededAction(play, &random)
                    try? play.apply(action, expecting: play.fingerprint)
                } else if roll < 8 {
                    if play.canUndo {
                        try play.undo()
                        undone += 1
                    }
                } else {
                    if play.canRedo {
                        try play.redo()
                        redone += 1
                    }
                }
            }
            let net: [Action] = Reconciliation.netTrace(play.records)
            #expect(net.count == play.spent)
            var again: Play = try Core.freshPlay(of: practice)
            for action in net { try again.apply(action, expecting: again.fingerprint) }
            #expect(again.fingerprint == play.fingerprint)
        }
        #expect(undone > 0 && redone > 0)
    }
}
