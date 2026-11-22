// AmethystEscapeReconciliationTests — feature 367 (R02-G07-07) T-R02G0707-002 (clarifications Q1 … Q3; research R2,
// R3, R6; contracts/api.md). Host checks of the traced results and of reconciliation: every certified level's solution
// actions (the solver's shortest sequence, the witness) recorded as a trace verify with three stars (five bands of 20,
// each prewarmed concurrently); a traced win is verified, a better one replaces it and ties keep the earlier trace;
// practice and replay record nothing; `drop(level:)`; an edited star count, move count or trace step, an illegal trace
// and an over-long trace are dropped and counted; a result without a trace is kept unverified; the frontier stays as
// saved; the net trace of records with undo and redo equals the hand-computed list, and over seeded undo/redo sequences
// (seed 2_367) replays to the same fingerprint. Edited saves are made by editing the encoded JSON, as a tampered file
// would be. Explicit types and plain loops (CI type-check rule); each test < 3 s. Modelled on feature 357's
// ChronoConstellatorReconciliationTests.
import Foundation
import Testing
@testable import AmethystEscapeCore

@Suite struct AmethystEscapeReconciliationTests {
    typealias Core = AmethystEscapeExperienceCore
    typealias Progress = AmethystEscapeProgress
    typealias Reconciliation = AmethystEscapeReconciliation
    typealias Action = AmethystEscapeAction

    /// The certified solution actions of level `number` (1 … 100).
    static func witness(_ number: Int) throws -> [Action] {
        let actions: [Action] = try Core.generated(number: number).solution.actions
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The certified smallest move count of level `number`.
    static func smallest(_ number: Int) throws -> Int {
        try Core.generated(number: number).solution.smallest
    }

    /// A fresh campaign play of certified level `number`.
    static func fresh(_ number: Int) throws -> AmethystEscapePlay {
        try AmethystEscapePlay.replay(level: try Core.generated(number: number).level, records: [])
    }

    /// The play after replaying `trace` on a fresh play of level `number`.
    static func played(_ number: Int, _ trace: [Action]) throws -> AmethystEscapePlay {
        var play: AmethystEscapePlay = try Self.fresh(number)
        for action in trace { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// Progress with honest verified campaign wins of `levels` (each its solution actions as the trace).
    static func honest(_ levels: [Int]) throws -> Progress {
        var progress: Progress = Progress()
        for level in levels {
            let trace: [Action] = try Self.witness(level)
            let moves: Int = try Self.played(level, trace).moves
            progress.record(level: level, moves: moves, smallest: try Self.smallest(level), mode: .campaign,
                            trace: trace)
        }
        return progress
    }

    /// The first level of 1 … 100 whose budget leaves room for two more moves than its smallest count.
    static func roomyLevel() throws -> Int {
        for number in Core.levelNumbers {
            let generated: AmethystEscapeGenerated = try Core.generated(number: number)
            if generated.level.budget >= generated.solution.smallest + 2 { return number }
        }
        Issue.record("no level with budget ≥ smallest + 2")
        return 1
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

    /// Every certified level of `band` (1 … 5), recorded with its solution actions as the trace, verifies with its
    /// certified smallest move count and three stars and is kept.
    func verifyBand(_ band: Int) throws {
        var levels: [Int] = []
        for number in Core.levelNumbers where Progress.band(of: number) == band { levels.append(number) }
        #expect(levels.count == 20)
        Core.prewarm(levels)
        let progress: Progress = try Self.honest(levels)
        for level in levels {
            let result: Progress.Result = try #require(progress.solved[level])
            #expect(result.verified && result.stars == 3, "level \(level)")
            #expect(result.bestMoves == (try Self.smallest(level)), "level \(level)")
            #expect(result.trace.count <= Reconciliation.maxTraceLength, "level \(level)")
            #expect(Reconciliation.verifies(level: level, result: result), "level \(level)")
        }
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
    }

    @Test func certifiedWitnessesBand1Verify() throws { try verifyBand(1) }
    @Test func certifiedWitnessesBand2Verify() throws { try verifyBand(2) }
    @Test func certifiedWitnessesBand3Verify() throws { try verifyBand(3) }
    @Test func certifiedWitnessesBand4Verify() throws { try verifyBand(4) }
    @Test func certifiedWitnessesBand5Verify() throws { try verifyBand(5) }

    @Test func aTracedWinIsVerifiedAndOnlyABetterOneReplacesIt() throws {
        let level: Int = try Self.roomyLevel()
        let best: [Action] = try Self.witness(level)
        let smallest: Int = try Self.smallest(level)
        // A longer trace of the same win: a turn and its reverse first (two moves, same crystal).
        let longer: [Action] = [Action.rotate(0, 1), Action.rotate(0, -1)] + best
        #expect(try Self.played(level, longer).stage == .won)
        var progress: Progress = Progress()
        let first: Bool = progress.record(level: level, moves: smallest + 2, smallest: smallest, trace: longer)
        #expect(first)
        #expect(progress.solved[level]?.verified == true)
        #expect(progress.solved[level]?.trace == longer)
        #expect(progress.solved[level]?.stars == 2)
        #expect(Reconciliation.verifies(level: level, result: try #require(progress.solved[level])))
        let fewer: Bool = progress.record(level: level, moves: smallest, smallest: smallest, trace: best)
        #expect(fewer)
        #expect(progress.solved[level]?.trace == best && progress.solved[level]?.stars == 3)
        // A tie keeps the earlier trace; more moves never replace.
        let tie: Bool = progress.record(level: level, moves: smallest, smallest: smallest, trace: longer)
        #expect(!tie && progress.solved[level]?.trace == best)
        let more: Bool = progress.record(level: level, moves: smallest + 2, smallest: smallest, trace: longer)
        #expect(!more && progress.solved[level]?.trace == best)
        #expect(progress.frontier == level + 1)
        // Daily opens nothing; practice and replay record nothing; a level outside 1 … 100 is ignored.
        let daily: Bool = progress.record(level: 60, moves: 9, smallest: 8, mode: .daily(level: 60), trace: best)
        #expect(daily && progress.frontier == level + 1 && progress.solved[60]?.verified == true)
        let practice: Bool = progress.record(level: 61, moves: 9, smallest: 8, mode: .practice, trace: best)
        let replay: Bool = progress.record(level: 62, moves: 9, smallest: 8, mode: .replay(level: 62), trace: best)
        let outside: Bool = progress.record(level: 101, moves: 9, smallest: 8, trace: best)
        let below: Bool = progress.record(level: 0, moves: 9, smallest: 8, trace: best)
        #expect(!practice && !replay && !outside && !below)
        #expect(progress.solved[61] == nil && progress.solved[62] == nil && progress.solved[101] == nil)
        // A win without a trace is unverified, as before.
        progress.record(level: 2, moves: 19, smallest: 6)
        #expect(progress.solved[2] == Progress.Result(bestMoves: 19, stars: 1))
        #expect(progress.solved[2]?.verified == false && progress.solved[2]?.trace.isEmpty == true)
        // drop removes the result; the frontier is unchanged; dropping an absent level changes nothing.
        let frontier: Int = progress.frontier
        progress.drop(level: level)
        #expect(progress.solved[level] == nil && progress.frontier == frontier)
        progress.drop(level: 77)
        #expect(progress.solved.count == 2)
    }

    @Test func tracesEncodeAndTheReplayModeAwardsNothing() throws {
        let progress: Progress = try Self.honest([1, 2])
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"trace\":["))
        #expect(text.contains("\"verified\":true"))
        let old: Data = Data("{\"frontier\":3,\"solved\":[{\"bestMoves\":5,\"level\":1,\"stars\":2}]}".utf8)
        let restored: Progress = try JSONDecoder().decode(Progress.self, from: old)
        #expect(restored.solved[1] == Progress.Result(bestMoves: 5, stars: 2))
        #expect(restored.solved[1]?.verified == false && restored.solved[1]?.trace.isEmpty == true)
        let reencoded: String = String(decoding: try restored.encoded(), as: UTF8.self)
        #expect(reencoded == "{\"frontier\":3,\"solved\":[{\"bestMoves\":5,\"level\":1,\"stars\":2,\"trace\":[],"
            + "\"verified\":false}]}")
        // The result alone decodes without trace and verified too.
        let bare: Data = Data("{\"bestMoves\":4,\"stars\":3}".utf8)
        #expect(try JSONDecoder().decode(Progress.Result.self, from: bare) == Progress.Result(bestMoves: 4, stars: 3))
        // Every action kind round trips in a trace.
        let actions: [Action] = [.rotate(1, 1), .rotate(0, -1), .advance]
        let encodedActions: Data = try JSONEncoder().encode(actions)
        #expect(try JSONDecoder().decode([Action].self, from: encodedActions) == actions)
        // The replay mode; the campaign, practice and daily encodings are unchanged.
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let replay: AmethystEscapeMode = .replay(level: 48)
        let replayData: Data = try encoder.encode(replay)
        #expect(String(decoding: replayData, as: UTF8.self) == "{\"level\":48,\"mode\":\"replay\"}")
        #expect(try JSONDecoder().decode(AmethystEscapeMode.self, from: replayData) == replay)
        #expect(String(decoding: try encoder.encode(AmethystEscapeMode.campaign), as: UTF8.self)
            == "{\"mode\":\"campaign\"}")
        #expect(String(decoding: try encoder.encode(AmethystEscapeMode.practice), as: UTF8.self)
            == "{\"mode\":\"practice\"}")
        #expect(String(decoding: try encoder.encode(AmethystEscapeMode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        #expect(!replay.awardsStars && !replay.opensLevels)
        #expect(replay.budget(base: 9) == 9)
        #expect(AmethystEscapeMode.campaign.awardsStars && AmethystEscapeMode.daily(level: 3).awardsStars)
        #expect(AmethystEscapeFeedbackPlan.modeName(replay) == "replay")
    }

    @Test func editedStarsMovesStepsIllegalAndOverlongTracesAreDropped() throws {
        let levels: [Int] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        Core.prewarm(levels)
        let progress: Progress = try Self.honest(levels)
        // Level 4: stars edited.
        var tampered: Progress = try Self.edited(progress, level: 4) { (entry: inout [String: Any]) in
            entry["stars"] = 2
        }
        // Level 5: moves edited up.
        tampered = try Self.edited(tampered, level: 5) { (entry: inout [String: Any]) in
            entry["bestMoves"] = ((entry["bestMoves"] as? Int) ?? 0) + 1
        }
        // Level 6: moves edited down (still three stars: only the replay's move count sees it).
        tampered = try Self.edited(tampered, level: 6) { (entry: inout [String: Any]) in
            entry["bestMoves"] = ((entry["bestMoves"] as? Int) ?? 0) - 1
        }
        #expect(tampered.solved[6]?.stars == 3)
        // Level 7: one trace step removed (fewer moves than the certified smallest count cannot escape).
        var removed: [Action] = try Self.witness(7)
        try #require(removed.count >= 3)
        removed.remove(at: 1)
        tampered = try Self.retraced(tampered, level: 7, removed)
        // Level 3: the final advance changed into a turn (same move count, the play does not win).
        var changed: [Action] = try Self.witness(3)
        changed[changed.count - 1] = .rotate(0, 1)
        try #require(try Self.played(3, changed).stage != .won)
        tampered = try Self.retraced(tampered, level: 3, changed)
        // Level 9: an illegal trace (a shell index out of range).
        tampered = try Self.retraced(tampered, level: 9, [Action.rotate(99, 1)] + (try Self.witness(9)))
        // Level 10: an illegal trace (a step of 2).
        tampered = try Self.retraced(tampered, level: 10, [Action.rotate(0, 2)] + (try Self.witness(10)))
        // Level 11: an illegal trace (an advance after the win).
        tampered = try Self.retraced(tampered, level: 11, (try Self.witness(11)) + [Action.advance])
        // Level 12: an over-long trace (65 actions: turn pairs before the solution).
        let witness12: [Action] = try Self.witness(12)
        var overlong: [Action] = []
        while overlong.count + witness12.count < Reconciliation.maxTraceLength + 1 {
            overlong.append(overlong.count % 2 == 0 ? .rotate(0, 1) : .rotate(0, -1))
        }
        overlong += witness12
        #expect(overlong.count == 65 && Reconciliation.maxTraceLength == 64)
        tampered = try Self.retraced(tampered, level: 12, overlong)
        tampered = try Self.edited(tampered, level: 12) { (entry: inout [String: Any]) in entry["bestMoves"] = 65 }
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(tampered)
        #expect(reconciled.dropped == 9)
        let expectedKept: [Int] = [8, 13, 14, 15]
        #expect(reconciled.progress.solved.keys.sorted() == expectedKept)
        for level in expectedKept { #expect(reconciled.progress.solved[level] == progress.solved[level]) }
        #expect(reconciled.progress.frontier == progress.frontier)
    }

    @Test func untracedResultsAreKeptAndTheFrontierStaysAsSaved() throws {
        var progress: Progress = try Self.honest([9])
        progress.record(level: 3, moves: 12, smallest: 5)
        // A daily traced win beyond the frontier.
        let daily: [Action] = try Self.witness(60)
        progress.record(level: 60, moves: try Self.played(60, daily).moves, smallest: try Self.smallest(60),
                        mode: .daily(level: 60), trace: daily)
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
        let empty: Progress.Result = Progress.Result(bestMoves: 3, stars: 3, trace: [], verified: true)
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

    @Test func netTraceCancelsUndoneActionsAndRestoresRedoneOnes() throws {
        // Hand-made records: rotate, advance, undo, undo, redo, rotate, redo (nothing to redo), advance
        // → rotate, rotate, advance.
        let kinds: [AmethystEscapeRecordKind] = [.rotate, .advance, .undo, .undo, .redo, .rotate, .redo, .advance]
        let actions: [Action?] = [.rotate(0, 1), .advance, nil, nil, nil, .rotate(1, -1), nil, .advance]
        var records: [AmethystEscapeRecord] = []
        for index in kinds.indices {
            records.append(AmethystEscapeRecord(schema: 1, seed: 1, move: 0, kind: kinds[index],
                                                action: actions[index], previous: "a", next: "b"))
        }
        let expected: [Action] = [.rotate(0, 1), .rotate(1, -1), .advance]
        #expect(Reconciliation.netTrace(records) == expected)
        #expect(Reconciliation.netTrace([]).isEmpty)
        // A redo after a new action restores nothing (the new action cleared the redo stack).
        let clearedKinds: [AmethystEscapeRecordKind] = [.advance, .undo, .rotate, .redo]
        let clearedActions: [Action?] = [.advance, nil, .rotate(2, 1), nil]
        var cleared: [AmethystEscapeRecord] = []
        for index in clearedKinds.indices {
            cleared.append(AmethystEscapeRecord(schema: 1, seed: 1, move: 0, kind: clearedKinds[index],
                                                action: clearedActions[index], previous: "a", next: "b"))
        }
        #expect(Reconciliation.netTrace(cleared) == [Action.rotate(2, 1)])

        // A real play with detours undone and redone: its net trace is the hand-computed list, replays to the same
        // fingerprint and verifies with two stars.
        let level: Int = try Self.roomyLevel()
        let best: [Action] = try Self.witness(level)
        let generated: AmethystEscapeGenerated = try Core.generated(number: level)
        var play: AmethystEscapePlay = try Self.fresh(level)
        try play.apply(best[0], expecting: play.fingerprint)
        try play.apply(.rotate(0, 1), expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        try play.undo()
        try play.apply(.rotate(0, 1), expecting: play.fingerprint)
        try play.apply(.rotate(0, -1), expecting: play.fingerprint)
        try play.apply(.rotate(0, 1), expecting: play.fingerprint)
        try play.undo()
        for index in 1..<best.count { try play.apply(best[index], expecting: play.fingerprint) }
        #expect(play.stage == .won)
        var handNet: [Action] = [best[0], Action.rotate(0, 1), Action.rotate(0, -1)]
        for index in 1..<best.count { handNet.append(best[index]) }
        let net: [Action] = Reconciliation.netTrace(play.records)
        #expect(net == handNet)
        let again: AmethystEscapePlay = try Self.played(level, net)
        #expect(again.fingerprint == play.fingerprint)
        let stars: Int = Progress.stars(moves: play.moves, smallest: generated.solution.smallest)
        #expect(stars == 2)
        let result: Progress.Result = Progress.Result(bestMoves: play.moves, stars: stars, trace: net, verified: true)
        #expect(Reconciliation.verifies(level: level, result: result))
    }

    @Test func netTraceOfSeededUndoRedoSequencesReplaysToTheSameFingerprint() throws {
        // Seed 2_367: 200 random sequences of turns, undos and redos on the practice copy of a band-3 level (budget
        // 60, turns only, so the play never ends); the net trace replayed on a fresh practice play reaches the same
        // fingerprint and holds exactly `moves` actions.
        var random: AmethystEscapeRandom = AmethystEscapeRandom(seed: 2_367)
        let certified: AmethystEscapeLevel = try Core.generated(number: 48).level
        let practice: AmethystEscapeLevel = try Core.practiceLevel(of: certified)
        let shells: Int = practice.shells.count
        for _ in 0..<200 {
            var play: AmethystEscapePlay = try AmethystEscapePlay.replay(level: practice, records: [])
            let length: Int = random.int(0...40)
            for _ in 0..<length {
                let roll: Int = random.int(0...9)
                if roll < 6 {
                    if play.moves + 1 >= practice.budget { continue }
                    let action: Action = .rotate(random.int(0..<shells), random.bool() ? 1 : -1)
                    try play.apply(action, expecting: play.fingerprint)
                } else if roll < 8 {
                    if play.canUndo { try play.undo() }
                } else {
                    if play.canRedo { try play.redo() }
                }
            }
            let net: [Action] = Reconciliation.netTrace(play.records)
            #expect(net.count == play.moves)
            var again: AmethystEscapePlay = try AmethystEscapePlay.replay(level: practice, records: [])
            for action in net { try again.apply(action, expecting: again.fingerprint) }
            #expect(again.fingerprint == play.fingerprint)
        }
    }
}
