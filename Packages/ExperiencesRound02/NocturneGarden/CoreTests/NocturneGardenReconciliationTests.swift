// NocturneGardenReconciliationTests — feature 387 (R02-G09-07) T-R02G0907-002 (FR-R02G0907-001, 002; clarifications
// Q1, Q2, Q4; research R2, R3, R6, R7; contracts/api.md). Host checks of the traced results and of reconciliation:
// every certified level's stored witness (docs/games/nocturne-garden/levels) recorded as a trace verifies with three
// stars (ten groups of ten levels; the 100 certified levels generated concurrently once per test process); a traced
// win is verified, a better one replaces it and ties keep the earlier trace; practice and replay record nothing;
// `drop(level:)`; an edited star count, a move count below the trace length, a removed or changed trace step, an
// illegal move and an over-long trace are dropped and counted, while a move count above the trace length with
// matching stars is kept; a result without a trace is kept unverified; the frontier stays as saved; old payloads
// without trace or verified decode; the net trace of hand-made records and of a real play with undo and redo equals
// the hand-computed list, and over seeded undo/redo sequences (seed 2_387) replays to the same fingerprint. Edited
// saves are made by editing the encoded JSON, as a tampered file would be. Explicit types and plain loops (CI
// type-check rule); each test < 10 s. Modelled on feature 377's FacetedForgeReconciliationTests.
import Foundation
import Testing
import VisualCoreSimulation
@testable import NocturneGardenCore

/// The repository's witness directory, found from this file.
private let reconciliationWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/nocturne-garden/levels", isDirectory: true)

/// The 100 certified levels in manifest order, generated concurrently once per test process (as the hint tests do;
/// the adapter's cache is shared, so whichever suite runs first pays the generation).
private let reconciliationCatalogResult: Result<[NocturneGardenGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? NocturneGardenExperienceCore.generated(number: index + 1)
    }
    var catalog: [NocturneGardenGenerated] = []
    for number in 1...100 { catalog.append(try NocturneGardenExperienceCore.generated(number: number)) }
    return catalog
}

@Suite struct NocturneGardenReconciliationTests {
    typealias Core = NocturneGardenExperienceCore
    typealias Progress = NocturneGardenProgress
    typealias Reconciliation = NocturneGardenReconciliation
    typealias Action = NocturneGardenAction
    typealias Play = NocturneGardenPlay

    /// The certified catalog (generated once, concurrently).
    static func catalog() throws -> [NocturneGardenGenerated] { try reconciliationCatalogResult.get() }

    /// The certified level and solution of level `number` (1 … 100), from the prewarmed catalog.
    static func certified(_ number: Int) throws -> NocturneGardenGenerated {
        let all: [NocturneGardenGenerated] = try Self.catalog()
        return all[number - 1]
    }

    /// The stored witness of level `number` (1 … 100), read with the plain decoder (the proof not re-run).
    static func storedWitness(_ number: Int) throws -> NocturneGardenWitness {
        let name: String = String(NocturneGardenGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: reconciliationWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(NocturneGardenWitness.self, from: data)
    }

    /// The stored witness moves of level `number`.
    static func witness(_ number: Int) throws -> [Action] {
        let actions: [Action] = try Self.storedWitness(number).actions
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The certified smallest move count of level `number`.
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

    /// Progress with honest verified campaign wins of `levels` (each its witness moves as the trace).
    static func honest(_ levels: [Int]) throws -> Progress {
        var progress: Progress = Progress()
        for level in levels {
            let trace: [Action] = try Self.witness(level)
            let moves: Int = Progress.movesMade(try Self.played(level, trace))
            progress.record(level: level, movesMade: moves, smallest: try Self.smallest(level), mode: .campaign,
                            trace: trace)
        }
        return progress
    }

    /// The first level of 1 … 100 whose budget leaves room for a detour move beyond its smallest move count.
    static func roomyLevel() throws -> Int {
        for number in Core.levelNumbers {
            let generated: NocturneGardenGenerated = try Self.certified(number)
            if generated.level.budget >= generated.solution.smallest + 2 { return number }
        }
        Issue.record("no level with budget ≥ smallest + 2")
        return 1
    }

    /// The first legal action on `play` other than `excluded` after which the play is not won: a sun move, then a
    /// plant (kinds, sizes, rows and columns ascending), then a removal; nil when there is none.
    static func nonWinning(_ play: Play, excluding excluded: Action) -> Action? {
        let level: NocturneGardenLevel = play.level
        var candidates: [Action] = []
        for elevation in level.elevations.sorted() { candidates.append(Action.sun(elevation)) }
        for kind in NocturneGardenKind.allCases where play.available(kind) > 0 {
            for size in level.sizes.sorted() {
                for row in 0..<level.height {
                    for column in 0..<level.width { candidates.append(Action.plant(kind, column, row, size)) }
                }
            }
        }
        for index in play.blooms.indices { candidates.append(Action.remove(index)) }
        for candidate in candidates where candidate != excluded {
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
    /// stored witness as the trace, verifies with its certified smallest move count and three stars and is kept.
    @Test(arguments: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    func certifiedWitnessesVerify(group: Int) throws {
        var levels: [Int] = []
        for offset in 1...10 { levels.append(group * 10 + offset) }
        _ = try Self.catalog()
        let progress: Progress = try Self.honest(levels)
        for level in levels {
            let result: Progress.Result = try #require(progress.solved[level])
            #expect(result.verified && result.stars == 3, "level \(level)")
            #expect(result.movesMade == (try Self.smallest(level)), "level \(level)")
            #expect(result.trace.count == result.movesMade, "level \(level)")
            #expect(result.trace.count <= Reconciliation.maxTraceLength, "level \(level)")
            #expect(result.trace == Core.certifiedActions(level), "level \(level)")
            #expect(Reconciliation.verifies(level: level, result: result), "level \(level)")
        }
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
    }

    @Test func aTracedWinIsVerifiedAndOnlyABetterOneReplacesIt() throws {
        let level: Int = try Self.roomyLevel()
        let best: [Action] = try Self.witness(level)
        let smallest: Int = try Self.smallest(level)
        // A detour: a neutral plant undone, then the witness (one more move made, the same effective moves).
        var detour: Play = try Self.fresh(level)
        let neutral: Action = try #require(Core.neutralPlant(detour))
        try detour.apply(neutral, expecting: detour.fingerprint)
        try detour.undo()
        for action in best { try detour.apply(action, expecting: detour.fingerprint) }
        #expect(detour.stage == .won)
        let detourMoves: Int = Progress.movesMade(detour)
        #expect(detourMoves == smallest + 1)
        let detourTrace: [Action] = Reconciliation.netTrace(detour.records)
        #expect(detourTrace == best)
        var progress: Progress = Progress()
        let first: Bool = progress.record(level: level, movesMade: detourMoves, smallest: smallest, trace: detourTrace)
        #expect(first)
        #expect(progress.solved[level]?.verified == true)
        #expect(progress.solved[level]?.stars == 2)
        #expect(Reconciliation.verifies(level: level, result: try #require(progress.solved[level])))
        let fewer: Bool = progress.record(level: level, movesMade: smallest, smallest: smallest, trace: best)
        #expect(fewer)
        #expect(progress.solved[level]?.movesMade == smallest && progress.solved[level]?.stars == 3)
        // A tie keeps the earlier trace; more moves never replace.
        let other: [Action] = [Action.sun(1)]
        let tie: Bool = progress.record(level: level, movesMade: smallest, smallest: smallest, trace: other)
        #expect(!tie && progress.solved[level]?.trace == best)
        let more: Bool = progress.record(level: level, movesMade: smallest + 2, smallest: smallest, trace: other)
        #expect(!more && progress.solved[level]?.trace == best)
        #expect(progress.frontier == level + 1)
        // Daily opens nothing; practice and replay record nothing; a level outside 1 … 100 is ignored.
        let daily: Bool = progress.record(level: 60, movesMade: 9, smallest: 8, mode: .daily(level: 60), trace: best)
        #expect(daily && progress.frontier == level + 1 && progress.solved[60]?.verified == true)
        let practice: Bool = progress.record(level: 61, movesMade: 9, smallest: 8, mode: .practice, trace: best)
        let replay: Bool = progress.record(level: 62, movesMade: 9, smallest: 8, mode: .replay(level: 62), trace: best)
        let outside: Bool = progress.record(level: 101, movesMade: 9, smallest: 8, trace: best)
        let below: Bool = progress.record(level: 0, movesMade: 9, smallest: 8, trace: best)
        #expect(!practice && !replay && !outside && !below)
        #expect(progress.solved[61] == nil && progress.solved[62] == nil && progress.solved[101] == nil)
        let untracedReplay: Bool = progress.record(level: 63, movesMade: 9, smallest: 8, mode: .replay(level: 63))
        #expect(!untracedReplay && progress.solved[63] == nil)
        // A win without a trace is unverified, as before.
        progress.record(level: 2, movesMade: 19, smallest: 6, opensNext: false)
        #expect(progress.solved[2] == Progress.Result(movesMade: 19, stars: 1))
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
        let old: Data = Data("{\"frontier\":3,\"solved\":[{\"level\":1,\"movesMade\":5,\"stars\":2}]}".utf8)
        let restored: Progress = try JSONDecoder().decode(Progress.self, from: old)
        #expect(restored.solved[1] == Progress.Result(movesMade: 5, stars: 2))
        #expect(restored.solved[1]?.verified == false && restored.solved[1]?.trace.isEmpty == true)
        let reencoded: String = String(decoding: try restored.encoded(), as: UTF8.self)
        #expect(reencoded == "{\"frontier\":3,\"solved\":[{\"level\":1,\"movesMade\":5,\"stars\":2,\"trace\":[],"
            + "\"verified\":false}]}")
        // The result alone decodes without trace and verified too.
        let bare: Data = Data("{\"movesMade\":4,\"stars\":3}".utf8)
        #expect(try JSONDecoder().decode(Progress.Result.self, from: bare) == Progress.Result(movesMade: 4, stars: 3))
        // A trace of every action kind round trips.
        let actions: [Action] = [Action.plant(.tulip, 3, 1, 2), Action.move(0, 5, 2), Action.resize(0, 1),
                                 Action.sun(3), Action.remove(0)]
        let encodedActions: Data = try JSONEncoder().encode(actions)
        #expect(try JSONDecoder().decode([Action].self, from: encodedActions) == actions)
        // The replay mode; the campaign, practice and daily encodings are unchanged.
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let replay: NocturneGardenMode = .replay(level: 48)
        let replayData: Data = try encoder.encode(replay)
        #expect(String(decoding: replayData, as: UTF8.self) == "{\"level\":48,\"mode\":\"replay\"}")
        #expect(try JSONDecoder().decode(NocturneGardenMode.self, from: replayData) == replay)
        #expect(String(decoding: try encoder.encode(NocturneGardenMode.campaign), as: UTF8.self)
            == "{\"mode\":\"campaign\"}")
        #expect(String(decoding: try encoder.encode(NocturneGardenMode.practice), as: UTF8.self)
            == "{\"mode\":\"practice\"}")
        #expect(String(decoding: try encoder.encode(NocturneGardenMode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        let badModes: [String] = ["{\"mode\":\"replay\",\"level\":0}", "{\"mode\":\"replay\",\"level\":101}",
                                  "{\"mode\":\"replay\"}", "{\"mode\":\"rewind\",\"level\":1}"]
        for json in badModes {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(NocturneGardenMode.self, from: Data(json.utf8))
            }
        }
        #expect(!replay.awardsStars && !replay.opensLevels)
        #expect(replay.budget(base: 9) == 9)
        #expect(NocturneGardenMode.campaign.awardsStars && NocturneGardenMode.daily(level: 3).awardsStars)
        #expect(!NocturneGardenMode.practice.awardsStars)
        let largestBudget: Int = NocturneGardenLevel.budgets.upperBound
        #expect(Reconciliation.maxTraceLength == 40 && Reconciliation.maxTraceLength == largestBudget)
    }

    @Test func editedStarsMovesStepsIllegalAndOverlongTracesAreDropped() throws {
        let levels: [Int] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
        _ = try Self.catalog()
        let progress: Progress = try Self.honest(levels)
        // Level 4: stars edited.
        var tampered: Progress = try Self.edited(progress, level: 4) { (entry: inout [String: Any]) in
            entry["stars"] = 2
        }
        // Level 5: moves made edited below the trace length (still three stars: only the trace length sees it).
        tampered = try Self.edited(tampered, level: 5) { (entry: inout [String: Any]) in
            entry["movesMade"] = ((entry["movesMade"] as? Int) ?? 0) - 1
        }
        #expect(tampered.solved[5]?.stars == 3)
        // Level 6: one trace step removed (fewer moves than the certified smallest count cannot win).
        var removed: [Action] = try Self.witness(6)
        try #require(removed.count >= 2)
        removed.remove(at: 0)
        tampered = try Self.retraced(tampered, level: 6, removed)
        // Level 7: the last move changed into the first other legal move that does not win (same length).
        let witness7: [Action] = try Self.witness(7)
        let lastIndex: Int = witness7.count - 1
        let before7: Play = try Self.played(7, Array(witness7.prefix(lastIndex)))
        let replacement: Action = try #require(Self.nonWinning(before7, excluding: witness7[lastIndex]))
        let changed: [Action] = Array(witness7.prefix(lastIndex)) + [replacement]
        #expect(changed.count == witness7.count && changed != witness7)
        tampered = try Self.retraced(tampered, level: 7, changed)
        // Level 8: an illegal plant (an anchor outside the bed) before the witness.
        tampered = try Self.retraced(tampered, level: 8, [Action.plant(.tulip, 99, 0, 1)] + (try Self.witness(8)))
        // Level 9: an illegal move (a bloom that is not planted) before the witness.
        tampered = try Self.retraced(tampered, level: 9, [Action.move(99, 0, 0)] + (try Self.witness(9)))
        // Level 10: an illegal move after the win (a won play refuses every action).
        let witness10: [Action] = try Self.witness(10)
        tampered = try Self.retraced(tampered, level: 10, witness10 + [witness10[0]])
        tampered = try Self.edited(tampered, level: 10) { (entry: inout [String: Any]) in
            entry["movesMade"] = witness10.count + 1
            entry["stars"] = 2
        }
        // Level 11: an over-long trace (41 moves) with a matching move count and stars.
        let witness11: [Action] = try Self.witness(11)
        var overlong: [Action] = []
        while overlong.count < Reconciliation.maxTraceLength + 1 { overlong.append(witness11[0]) }
        #expect(overlong.count == 41 && Reconciliation.maxTraceLength == 40)
        tampered = try Self.retraced(tampered, level: 11, overlong)
        tampered = try Self.edited(tampered, level: 11) { (entry: inout [String: Any]) in
            entry["movesMade"] = 41
            entry["stars"] = 1
        }
        // Level 12: moves made raised above the trace length with the stars that count gives (kept: R7).
        let smallest12: Int = try Self.smallest(12)
        tampered = try Self.edited(tampered, level: 12) { (entry: inout [String: Any]) in
            entry["movesMade"] = smallest12 + 3
            entry["stars"] = 1
        }
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(tampered)
        #expect(reconciled.dropped == 8)
        let expectedKept: [Int] = [3, 12, 13]
        #expect(reconciled.progress.solved.keys.sorted() == expectedKept)
        #expect(reconciled.progress.solved[3] == progress.solved[3])
        #expect(reconciled.progress.solved[13] == progress.solved[13])
        #expect(reconciled.progress.solved[12]?.movesMade == smallest12 + 3)
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
        progress.record(level: 3, movesMade: 12, smallest: 5, mode: .campaign)
        // A daily traced win beyond the frontier.
        let daily: [Action] = try Self.witness(60)
        progress.record(level: 60, movesMade: Progress.movesMade(try Self.played(60, daily)),
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
        let empty: Progress.Result = Progress.Result(movesMade: 3, stars: 3, trace: [], verified: true)
        #expect(!Reconciliation.verifies(level: 1, result: empty))
        let claimed: Progress = try Self.edited(progress, level: 3) { (entry: inout [String: Any]) in
            entry["verified"] = true
        }
        let claimedAfter: (progress: Progress, dropped: Int) = Reconciliation.reconcile(claimed)
        #expect(claimedAfter.dropped == 1 && claimedAfter.progress.solved[3] == nil)
        let honest9: Progress.Result = try #require(progress.solved[9])
        #expect(Reconciliation.verifies(level: 9, result: honest9))
        #expect(!Reconciliation.verifies(level: 0, result: honest9))
        #expect(!Reconciliation.verifies(level: 101, result: honest9))
        // An honest trace stored under another level does not verify there.
        #expect(!Reconciliation.verifies(level: 10, result: honest9))
    }

    @Test func netTraceCancelsUndoneMovesAndRestoresRedoneOnes() throws {
        // Hand-made records: plant a, sun b, undo, undo, redo, move c, redo (nothing to redo), resize d → a, c, d.
        let a: Action = Action.plant(.tulip, 3, 1, 1)
        let b: Action = Action.sun(3)
        let c: Action = Action.move(0, 5, 2)
        let d: Action = Action.resize(0, 2)
        let kinds: [NocturneGardenRecordKind] = [.plant, .sun, .undo, .undo, .redo, .move, .redo, .resize]
        let actions: [Action?] = [a, b, nil, nil, nil, c, nil, d]
        var records: [NocturneGardenRecord] = []
        for index in kinds.indices {
            records.append(NocturneGardenRecord(schema: 1, seed: 1, move: 0, kind: kinds[index],
                                                action: actions[index], previous: "a", next: "b"))
        }
        let expected: [Action] = [a, c, d]
        #expect(Reconciliation.netTrace(records) == expected)
        #expect(Reconciliation.netTrace([]).isEmpty)
        // A redo after a new move restores nothing (the new move cleared the redo stack); a removal is a move.
        let clearedKinds: [NocturneGardenRecordKind] = [.plant, .undo, .remove, .redo]
        let clearedActions: [Action?] = [a, nil, Action.remove(0), nil]
        var cleared: [NocturneGardenRecord] = []
        for index in clearedKinds.indices {
            cleared.append(NocturneGardenRecord(schema: 1, seed: 1, move: 0, kind: clearedKinds[index],
                                                action: clearedActions[index], previous: "a", next: "b"))
        }
        let clearedExpected: [Action] = [Action.remove(0)]
        #expect(Reconciliation.netTrace(cleared) == clearedExpected)

        // A real play with detours undone and redone: its net trace is the hand-computed list, replays to the same
        // fingerprint and verifies with the stars of its moves made.
        let level: Int = try Self.roomyLevel()
        let best: [Action] = try Self.witness(level)
        let smallest: Int = try Self.smallest(level)
        var play: Play = try Self.fresh(level)
        try play.apply(best[0], expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        let neutral: Action = try #require(Core.neutralPlant(play))
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
        let moves: Int = Progress.movesMade(play)
        #expect(moves == smallest + 1)
        let stars: Int = Progress.stars(movesMade: moves, smallest: smallest)
        #expect(stars == 2)
        let result: Progress.Result = Progress.Result(movesMade: moves, stars: stars, trace: net, verified: true)
        #expect(Reconciliation.verifies(level: level, result: result))
    }

    /// A seeded action for `play`: a plant (a supplied kind, any anchor, an allowed size), a move, a resize, a removal
    /// or a sun move; it may be refused.
    static func seededAction(_ play: Play, _ random: inout SeededRandom) -> Action {
        let level: NocturneGardenLevel = play.level
        let sizes: [Int] = level.sizes.sorted()
        let elevations: [Int] = level.elevations.sorted()
        var kinds: [NocturneGardenKind] = []
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 { kinds.append(kind) }
        let count: Int = play.blooms.count
        let choice: Int = random.int(0...9)
        if count > 0 && choice == 0 {
            return Action.move(random.int(0...(count - 1)), random.int(0...(level.width - 1)),
                               random.int(0...(level.height - 1)))
        }
        if count > 0 && choice == 1 {
            return Action.resize(random.int(0...(count - 1)), sizes[random.int(0...(sizes.count - 1))])
        }
        if count > 0 && choice == 2 { return Action.remove(random.int(0...(count - 1))) }
        if choice == 3 { return Action.sun(elevations[random.int(0...(elevations.count - 1))]) }
        return Action.plant(kinds[random.int(0...(kinds.count - 1))], random.int(0...(level.width - 1)),
                            random.int(0...(level.height - 1)), sizes[random.int(0...(sizes.count - 1))])
    }

    @Test func netTraceOfSeededUndoRedoSequencesReplaysToTheSameFingerprint() throws {
        // Seed 2_387: 60 random sequences of moves (refusals ignored), undos and redos on the practice copy of level
        // 48 (budget 40); the net trace replayed on a fresh practice play reaches the same fingerprint and holds
        // exactly the moves spent.
        var random: SeededRandom = SeededRandom(seed: 2_387)
        let certified: NocturneGardenLevel = try Self.certified(48).level
        let practice: NocturneGardenLevel = try Core.practiceLevel(of: certified)
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
            #expect(net.count == play.moves)
            var again: Play = try Core.freshPlay(of: practice)
            for action in net { try again.apply(action, expecting: again.fingerprint) }
            #expect(again.fingerprint == play.fingerprint)
        }
        #expect(undone > 0 && redone > 0)
    }
}
