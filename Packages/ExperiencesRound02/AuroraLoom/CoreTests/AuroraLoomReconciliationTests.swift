// AuroraLoomReconciliationTests — feature 307 (R02-G01-07) T-R02G0107-002 (FR-R02G0107-001, 003; clarifications Q1, Q2;
// SC-R02G0107-003). Host checks of the traced results and of reconciliation: a win with its trace is a verified result;
// fewer moves replace it and ties keep the earlier trace; results encode with their traces and an encoding without them
// (schema 2) decodes unverified; honest traces are kept; an edited star count, move count or trace step is dropped; a
// result without a trace is kept unverified; the frontier stays as saved (a daily win may lie beyond it).
// Edited saves are made by editing the encoded JSON, as a tampered file would be. Short runs, plain loops.
import Foundation
import Testing
@testable import AuroraLoomCore

@Suite struct AuroraLoomReconciliationTests {
    /// The certified level `number` and its shortest solution's moves.
    static func certified(_ number: Int) throws -> (shortest: Int, moves: [AuroraLoomMove]) {
        let generated: AuroraLoomGenerated = try AuroraLoomExperienceCore.generated(number: number)
        return (generated.solution.shortest, generated.solution.moves)
    }

    /// `progress` encoded, its solved entry for `level` edited by `edit`, decoded again.
    static func edited(_ progress: AuroraLoomProgress, level: Int,
                       _ edit: (inout [String: Any]) -> Void) throws -> AuroraLoomProgress {
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try progress.encoded()) as? [String: Any])
        var entries: [[String: Any]] = try #require(object["solved"] as? [[String: Any]])
        for index in entries.indices where entries[index]["level"] as? Int == level {
            edit(&entries[index])
        }
        object["solved"] = entries
        return try JSONDecoder().decode(AuroraLoomProgress.self,
                                        from: try JSONSerialization.data(withJSONObject: object))
    }

    /// Progress with honest verified wins of `levels` (each its certified solution).
    static func honest(_ levels: [Int]) throws -> AuroraLoomProgress {
        var progress: AuroraLoomProgress = AuroraLoomProgress()
        for level in levels {
            let solution = try Self.certified(level)
            progress.record(level: level, moves: solution.moves.count, shortest: solution.shortest,
                            trace: solution.moves)
        }
        return progress
    }

    @Test func aTracedWinIsVerifiedAndFewerMovesReplaceIt() throws {
        let solution = try Self.certified(1)
        var progress: AuroraLoomProgress = AuroraLoomProgress()
        let longer: [AuroraLoomMove] = solution.moves + solution.moves
        progress.record(level: 1, moves: longer.count, shortest: solution.shortest, trace: longer)
        #expect(progress.solved[1]?.verified == true)
        #expect(progress.solved[1]?.trace == longer)
        progress.record(level: 1, moves: solution.moves.count, shortest: solution.shortest, trace: solution.moves)
        #expect(progress.solved[1]?.trace == solution.moves)
        #expect(progress.solved[1]?.stars == 3)
        // A tie keeps the earlier trace.
        let other: [AuroraLoomMove] = Array(solution.moves.reversed())
        progress.record(level: 1, moves: solution.moves.count, shortest: solution.shortest, trace: other)
        #expect(progress.solved[1]?.trace == solution.moves)
        // More moves never replace.
        progress.record(level: 1, moves: solution.moves.count + 3, shortest: solution.shortest, trace: longer)
        #expect(progress.solved[1]?.trace == solution.moves)
        #expect(progress.frontier == 2)
        // A win without a trace is unverified.
        progress.record(level: 2, moves: 9, shortest: 4)
        #expect(progress.solved[2]?.verified == false)
        #expect(progress.solved[2]?.trace.isEmpty == true)
    }

    @Test func tracesEncodeAndASchemaTwoEncodingDecodesUnverified() throws {
        let progress: AuroraLoomProgress = try Self.honest([1, 2])
        let data: Data = try progress.encoded()
        let decoded: AuroraLoomProgress = try JSONDecoder().decode(AuroraLoomProgress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let old: Data = Data(#"{"frontier":3,"solved":[{"bestMoves":5,"level":1,"stars":2}]}"#.utf8)
        let restored: AuroraLoomProgress = try JSONDecoder().decode(AuroraLoomProgress.self, from: old)
        #expect(restored.solved[1] == AuroraLoomProgress.Result(bestMoves: 5, stars: 2))
        #expect(restored.solved[1]?.verified == false)
    }

    @Test func honestTracesAreKept() throws {
        let progress: AuroraLoomProgress = try Self.honest([1, 2, 3, 41, 100])
        for level in [1, 2, 3, 41, 100] {
            let result: AuroraLoomProgress.Result = try #require(progress.solved[level])
            #expect(AuroraLoomReconciliation.verifies(level: level, result: result))
        }
        let reconciled = AuroraLoomReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
    }

    @Test func editedStarsMovesAndStepsAreDropped() throws {
        let progress: AuroraLoomProgress = try Self.honest([1, 2, 3, 4])
        var tampered: AuroraLoomProgress = try Self.edited(progress, level: 1) { entry in entry["stars"] = 1 }
        tampered = try Self.edited(tampered, level: 2) { entry in
            entry["bestMoves"] = ((entry["bestMoves"] as? Int) ?? 0) + 1
        }
        tampered = try Self.edited(tampered, level: 3) { entry in
            var trace: [[String: Any]] = (entry["trace"] as? [[String: Any]]) ?? []
            if !trace.isEmpty {
                let step: Int = (trace[0]["step"] as? Int) ?? 0
                trace[0]["step"] = (step + 1) % 16
            }
            entry["trace"] = trace
        }
        let reconciled = AuroraLoomReconciliation.reconcile(tampered)
        #expect(reconciled.dropped == 3)
        #expect(reconciled.progress.solved.keys.sorted() == [4])
        #expect(reconciled.progress.solved[4] == progress.solved[4])
    }

    @Test func tracelessResultsAreKeptAndTheFrontierStaysAsSaved() throws {
        var progress: AuroraLoomProgress = try Self.honest([7])
        progress.record(level: 3, moves: 12, shortest: 5)
        progress.frontier = 2
        let reconciled = AuroraLoomReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress.solved[3]?.verified == false)
        #expect(reconciled.progress.frontier == 2)
        // A verified result without a trace, or on a level out of range, never verifies.
        let empty: AuroraLoomProgress.Result = AuroraLoomProgress.Result(bestMoves: 0, stars: 3, trace: [], verified: true)
        #expect(!AuroraLoomReconciliation.verifies(level: 1, result: empty))
        let solution = try Self.certified(1)
        let honest: AuroraLoomProgress.Result = AuroraLoomProgress.Result(
            bestMoves: solution.moves.count, stars: 3, trace: solution.moves, verified: true)
        #expect(!AuroraLoomReconciliation.verifies(level: 0, result: honest))
        #expect(!AuroraLoomReconciliation.verifies(level: 2, result: honest))
    }
}
