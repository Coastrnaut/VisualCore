// WaveKnotKeeperReconciliationTests — feature 327 (R02-G03-07) T-R02G0307-002 (FR-R02G0307-001, 003; clarifications
// Q1, Q2; SC-R02G0307-003). Host checks of the traced results and of reconciliation: every certified level's solution
// recorded as a trace verifies (five bands of 20); a traced win is verified, fewer moves replace it and ties keep the
// earlier trace; `drop(level:)`; results encode with their traces, an encoding without them (schema 2) decodes
// unverified, and an overlong or negative-point trace is refused; an edited star count, move count or trace step, an
// illegal trace and a trace that does not win are dropped and counted; a result without a trace is kept unverified; the
// frontier stays as saved; the replay mode round trips. The certified levels come from the per-process generation cache
// (``WaveKnotKeeperExperienceCore/generated(number:)``); the level of the record tests is the one seed 2_327 picks.
// Edited saves are made by editing the encoded JSON, as a tampered file would be. Test data uses explicit types and
// plain loops (CI type-check rule).
@testable import WaveKnotKeeperCore
import Foundation
import Testing

@Suite struct WaveKnotKeeperReconciliationTests {
    /// The test seed; it picks the level of the record tests (2_327 mod 100 + 1 = 28).
    static let seed: UInt64 = 2_327

    /// The certified solution moves of level `number` (1 … 100).
    static func solution(_ number: Int) throws -> [WaveKnotKeeperMove] {
        try WaveKnotKeeperExperienceCore.generated(number: number).solution.moves
    }

    /// Progress with honest verified campaign wins of `levels` (each its certified solution as the trace).
    static func honest(_ levels: [Int]) throws -> WaveKnotKeeperProgress {
        var progress: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
        for level in levels {
            let moves: [WaveKnotKeeperMove] = try Self.solution(level)
            progress.record(level: level, moves: moves.count, shortest: moves.count, opensNext: true, trace: moves)
        }
        return progress
    }

    /// `progress` encoded, its solved entry for `level` edited by `edit`, decoded again.
    static func edited(_ progress: WaveKnotKeeperProgress, level: Int,
                       _ edit: (inout [String: Any]) -> Void) throws -> WaveKnotKeeperProgress {
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try progress.encoded()) as? [String: Any])
        var entries: [[String: Any]] = try #require(object["solved"] as? [[String: Any]])
        for index in entries.indices where entries[index]["level"] as? Int == level {
            edit(&entries[index])
        }
        object["solved"] = entries
        return try JSONDecoder().decode(WaveKnotKeeperProgress.self,
                                        from: try JSONSerialization.data(withJSONObject: object))
    }

    /// `move` as encoded JSON.
    static func object(_ move: WaveKnotKeeperMove) -> [String: Any] {
        ["point": move.point, "direction": move.direction.rawValue]
    }

    /// Every certified level of `band` (1 … 5), recorded with its solution as the trace, verifies and is kept.
    func verifyBand(_ band: Int) throws {
        var levels: [Int] = []
        for entry in WaveKnotKeeperManifest.entries where entry.band == band { levels.append(entry.number) }
        #expect(levels.count == 20)
        let progress: WaveKnotKeeperProgress = try Self.honest(levels)
        for level in levels {
            let result: WaveKnotKeeperProgress.Result = try #require(progress.solved[level])
            #expect(result.verified && result.stars == 3, "level \(level)")
            #expect(WaveKnotKeeperReconciliation.verifies(level: level, result: result), "level \(level)")
        }
        let reconciled: (progress: WaveKnotKeeperProgress, dropped: Int) =
            WaveKnotKeeperReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
    }

    @Test func certifiedSolutionsBand1Verify() throws { try verifyBand(1) }
    @Test func certifiedSolutionsBand2Verify() throws { try verifyBand(2) }
    @Test func certifiedSolutionsBand3Verify() throws { try verifyBand(3) }
    @Test func certifiedSolutionsBand4Verify() throws { try verifyBand(4) }
    @Test func certifiedSolutionsBand5Verify() throws { try verifyBand(5) }

    @Test func aTracedWinIsVerifiedAndOnlyFewerMovesReplaceIt() throws {
        let level: Int = WaveKnotKeeperExperienceCore.levelNumber(forSeed: Self.seed)
        #expect(level == 28)
        let moves: [WaveKnotKeeperMove] = try Self.solution(level)
        let shortest: Int = moves.count
        let longer: [WaveKnotKeeperMove] = moves + moves
        var progress: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
        progress.open(through: level)
        progress.record(level: level, moves: longer.count, shortest: shortest, opensNext: true, trace: longer)
        #expect(progress.solved[level]?.verified == true)
        #expect(progress.solved[level]?.trace == longer)
        let longerStars: Int = WaveKnotKeeperProgress.stars(moves: longer.count, shortest: shortest)
        #expect(progress.solved[level]?.stars == longerStars)
        progress.record(level: level, moves: shortest, shortest: shortest, opensNext: true, trace: moves)
        #expect(progress.solved[level]?.trace == moves)
        #expect(progress.solved[level]?.stars == 3)
        // A tie keeps the earlier trace.
        let other: [WaveKnotKeeperMove] = Array(moves.reversed())
        progress.record(level: level, moves: shortest, shortest: shortest, opensNext: true, trace: other)
        #expect(progress.solved[level]?.trace == moves)
        // More moves never replace.
        progress.record(level: level, moves: shortest + 3, shortest: shortest, opensNext: true, trace: longer)
        #expect(progress.solved[level]?.trace == moves)
        #expect(progress.frontier == level + 1)
        // A daily traced win never opens a level; a level outside 1 … 100 is ignored.
        progress.record(level: 50, moves: 4, shortest: 4, opensNext: false, trace: moves)
        #expect(progress.frontier == level + 1 && progress.solved[50]?.verified == true)
        progress.record(level: 101, moves: 4, shortest: 4, opensNext: true, trace: moves)
        #expect(progress.solved[101] == nil && progress.frontier == level + 1)
        // A win without a trace is unverified, as before.
        progress.record(level: 2, moves: 9, shortest: 4, opensNext: true)
        #expect(progress.solved[2] == WaveKnotKeeperProgress.Result(bestMoves: 9, stars: 1))
        #expect(progress.solved[2]?.verified == false && progress.solved[2]?.trace.isEmpty == true)
        // drop removes the result; the frontier is unchanged.
        progress.drop(level: level)
        #expect(progress.solved[level] == nil && progress.frontier == level + 1)
        progress.drop(level: 77)
        #expect(progress.solved.count == 2)
    }

    @Test func tracesEncodeAndASchemaTwoEncodingDecodesUnverified() throws {
        let progress: WaveKnotKeeperProgress = try Self.honest([1, 2])
        let data: Data = try progress.encoded()
        let decoded: WaveKnotKeeperProgress = try JSONDecoder().decode(WaveKnotKeeperProgress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"trace\":[{\"direction\":"))
        #expect(text.contains("\"verified\":true"))
        let old: Data = Data("{\"frontier\":3,\"solved\":[{\"bestMoves\":5,\"level\":1,\"stars\":2}]}".utf8)
        let restored: WaveKnotKeeperProgress = try JSONDecoder().decode(WaveKnotKeeperProgress.self, from: old)
        #expect(restored.solved[1] == WaveKnotKeeperProgress.Result(bestMoves: 5, stars: 2))
        #expect(restored.solved[1]?.verified == false)
        #expect(restored.solved[1]?.trace.isEmpty == true)
        #expect(restored.frontier == 3)
    }

    @Test func overlongOrNegativePointTracesAreRefused() throws {
        var long: String = ""
        for index in 0..<65 {
            long += (index == 0 ? "" : ",") + "{\"direction\":\"plusX\",\"point\":\(index % 2)}"
        }
        let bad: [String] = [
            "{\"frontier\":2,\"solved\":[{\"bestMoves\":65,\"level\":1,\"stars\":1,\"trace\":[" + long
                + "],\"verified\":true}]}",
            "{\"frontier\":2,\"solved\":[{\"bestMoves\":1,\"level\":1,\"stars\":3,"
                + "\"trace\":[{\"direction\":\"plusX\",\"point\":-1}],\"verified\":true}]}",
            "{\"frontier\":2,\"solved\":[{\"bestMoves\":1,\"level\":1,\"stars\":3,"
                + "\"trace\":[{\"direction\":\"sideways\",\"point\":0}],\"verified\":true}]}",
        ]
        for json in bad {
            #expect(throws: DecodingError.self, "\(json.prefix(80))") {
                _ = try JSONDecoder().decode(WaveKnotKeeperProgress.self, from: Data(json.utf8))
            }
        }
        // 64 moves is the most accepted.
        var limit: String = ""
        for index in 0..<64 {
            limit += (index == 0 ? "" : ",") + "{\"direction\":\"plusX\",\"point\":\(index % 2)}"
        }
        let accepted: String = "{\"frontier\":2,\"solved\":[{\"bestMoves\":64,\"level\":1,\"stars\":1,\"trace\":["
            + limit + "],\"verified\":true}]}"
        let decoded: WaveKnotKeeperProgress = try JSONDecoder().decode(WaveKnotKeeperProgress.self,
                                                                       from: Data(accepted.utf8))
        #expect(decoded.solved[1]?.trace.count == 64)
    }

    /// A legal first move of a fresh play of level `level`, other than the certified first move, after which the
    /// certified solution's later moves no longer replay to a win (the trace step a tampered file could change).
    static func losingStep(level: Int) throws -> WaveKnotKeeperMove {
        let generated: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: level)
        let moves: [WaveKnotKeeperMove] = generated.solution.moves
        let pointCount: Int = generated.level.points.count
        for point in 0..<pointCount {
            for direction in WaveKnotKeeperDirection.allCases {
                let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                if move == moves[0] { continue }
                var play: WaveKnotKeeperPlay = try WaveKnotKeeperExperienceCore.freshPlay(of: generated.level)
                do {
                    try play.apply(move, expecting: play.fingerprint)
                } catch {
                    continue
                }
                if play.stage == .won { continue }
                var trace: [WaveKnotKeeperMove] = moves
                trace[0] = move
                let result: WaveKnotKeeperProgress.Result = WaveKnotKeeperProgress.Result(
                    bestMoves: trace.count, stars: 3, trace: trace, verified: true)
                if !WaveKnotKeeperReconciliation.verifies(level: level, result: result) { return move }
            }
        }
        throw WaveKnotKeeperError.level("no losing step")
    }

    @Test func editedStarsMovesStepsAndIllegalTracesAreDropped() throws {
        let progress: WaveKnotKeeperProgress = try Self.honest([1, 2, 3, 4, 5, 6])
        // Level 1: stars edited.
        var tampered: WaveKnotKeeperProgress = try Self.edited(progress, level: 1) { entry in
            entry["stars"] = ((entry["stars"] as? Int) ?? 3) == 3 ? 2 : 3
        }
        // Level 2: best moves edited.
        tampered = try Self.edited(tampered, level: 2) { entry in
            entry["bestMoves"] = ((entry["bestMoves"] as? Int) ?? 0) + 1
        }
        // Level 4: the first trace step changed to a legal move after which the trace does not win.
        let changed: [String: Any] = Self.object(try Self.losingStep(level: 4))
        tampered = try Self.edited(tampered, level: 4) { entry in
            var trace: [[String: Any]] = (entry["trace"] as? [[String: Any]]) ?? []
            trace[0] = changed
            entry["trace"] = trace
        }
        // Level 5: an illegal trace (a point beyond the rope, refused as out of range).
        tampered = try Self.edited(tampered, level: 5) { entry in
            var trace: [[String: Any]] = (entry["trace"] as? [[String: Any]]) ?? []
            trace[0] = ["point": 99, "direction": WaveKnotKeeperDirection.plusX.rawValue]
            entry["trace"] = trace
        }
        // Level 3: a trace that does not win (the last move removed, best moves matching).
        tampered = try Self.edited(tampered, level: 3) { entry in
            var trace: [[String: Any]] = (entry["trace"] as? [[String: Any]]) ?? []
            trace.removeLast()
            entry["trace"] = trace
            entry["bestMoves"] = trace.count
        }
        #expect(tampered.solved[3]?.trace.count == (progress.solved[3]?.trace.count ?? 0) - 1)
        let reconciled: (progress: WaveKnotKeeperProgress, dropped: Int) =
            WaveKnotKeeperReconciliation.reconcile(tampered)
        #expect(reconciled.dropped == 5)
        #expect(reconciled.progress.solved.keys.sorted() == [6])
        #expect(reconciled.progress.solved[6] == progress.solved[6])
        #expect(reconciled.progress.frontier == progress.frontier)
    }

    @Test func tracelessResultsAreKeptAndTheFrontierStaysAsSaved() throws {
        var progress: WaveKnotKeeperProgress = try Self.honest([7])
        progress.record(level: 3, moves: 12, shortest: 5, opensNext: false)
        // A daily traced win beyond the frontier.
        let daily: [WaveKnotKeeperMove] = try Self.solution(60)
        progress.record(level: 60, moves: daily.count, shortest: daily.count, opensNext: false, trace: daily)
        #expect(progress.frontier == 8)
        let reconciled: (progress: WaveKnotKeeperProgress, dropped: Int) =
            WaveKnotKeeperReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
        #expect(reconciled.progress.solved[3]?.verified == false)
        #expect(reconciled.progress.frontier == 8)
        // Dropping never lowers the frontier.
        let tampered: WaveKnotKeeperProgress = try Self.edited(progress, level: 7) { entry in entry["stars"] = 1 }
        let after: (progress: WaveKnotKeeperProgress, dropped: Int) = WaveKnotKeeperReconciliation.reconcile(tampered)
        #expect(after.dropped == 1 && after.progress.frontier == 8 && after.progress.solved[7] == nil)
        // A verified result without a trace, a traced result on another or an out-of-range level never verifies.
        let empty: WaveKnotKeeperProgress.Result = WaveKnotKeeperProgress.Result(
            bestMoves: 0, stars: 3, trace: [], verified: true)
        #expect(!WaveKnotKeeperReconciliation.verifies(level: 1, result: empty))
        let claimed: WaveKnotKeeperProgress = try Self.edited(progress, level: 3) { entry in entry["verified"] = true }
        #expect(WaveKnotKeeperReconciliation.reconcile(claimed).dropped == 1)
        let moves: [WaveKnotKeeperMove] = try Self.solution(1)
        let honest: WaveKnotKeeperProgress.Result = WaveKnotKeeperProgress.Result(
            bestMoves: moves.count, stars: 3, trace: moves, verified: true)
        #expect(WaveKnotKeeperReconciliation.verifies(level: 1, result: honest))
        #expect(!WaveKnotKeeperReconciliation.verifies(level: 0, result: honest))
        #expect(!WaveKnotKeeperReconciliation.verifies(level: 101, result: honest))
        #expect(!WaveKnotKeeperReconciliation.verifies(level: 2, result: honest))
    }

    @Test func replayModeRoundTrips() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for level in [1, 42, 100] {
            let mode: WaveKnotKeeperMode = .replay(level: level)
            let data: Data = try encoder.encode(mode)
            #expect(String(decoding: data, as: UTF8.self) == "{\"level\":\(level),\"mode\":\"replay\"}")
            #expect(try JSONDecoder().decode(WaveKnotKeeperMode.self, from: data) == mode)
        }
        let bad: [String] = ["{\"mode\":\"replay\",\"level\":0}", "{\"mode\":\"replay\",\"level\":101}",
                             "{\"mode\":\"replay\"}"]
        for json in bad {
            #expect(throws: DecodingError.self, "\(json)") {
                _ = try JSONDecoder().decode(WaveKnotKeeperMode.self, from: Data(json.utf8))
            }
        }
        #expect(WaveKnotKeeperFeedbackPlan.modeName(.replay(level: 3)) == "Replay")
    }
}
