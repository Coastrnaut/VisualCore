// LissajousLabyrinthReconciliationTests — feature 317 (R02-G02-07) T-R02G0207-002 (FR-R02G0207-001, 003; clarifications
// Q1, Q2; SC-R02G0207-003; research R2–R4). Host checks of the traced results and of reconciliation: every certified
// level's solution recorded as a trace verifies (five bands of 20); a traced win is verified, fewer actions replace it
// and ties keep the earlier trace; `drop(level:)`; results encode with their traces, an encoding without them (schema 2)
// decodes unverified, and an overlong or out-of-range trace is refused; an edited star count, action count or trace step,
// an illegal trace and a trace that does not win are dropped and counted; a result without a trace is kept unverified;
// the frontier stays as saved. The certified levels are read from the witness files in docs/games/lissajous-labyrinth/
// levels/ (LissajousLabyrinthCatalogTests proves them equal to the regenerated catalog). Edited saves are made by
// editing the encoded JSON, as a tampered file would be. Test data uses explicit types and plain loops (CI type-check
// rule).
@testable import LissajousLabyrinthCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let reconciliationWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/lissajous-labyrinth/levels", isDirectory: true)

/// The 100 certified witnesses, decoded once per test process, in manifest order.
private let reconciliationWitnesses: Result<[LissajousLabyrinthWitness], any Error> = Result {
    var result: [LissajousLabyrinthWitness] = []
    for entry in LissajousLabyrinthManifest.entries {
        let name: String = String(LissajousLabyrinthGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: reconciliationWitnessDirectory.appendingPathComponent(name))
        result.append(try LissajousLabyrinthWitness.decode(data))
    }
    return result
}

@Suite struct LissajousLabyrinthReconciliationTests {
    /// The certified witness of level `number` (1 … 100).
    static func witness(_ number: Int) throws -> LissajousLabyrinthWitness {
        let witnesses: [LissajousLabyrinthWitness] = try reconciliationWitnesses.get()
        return witnesses[number - 1]
    }

    /// Progress with honest verified campaign wins of `levels` (each its certified solution as the trace).
    static func honest(_ levels: [Int]) throws -> LissajousLabyrinthProgress {
        var progress: LissajousLabyrinthProgress = LissajousLabyrinthProgress()
        for level in levels {
            let witness: LissajousLabyrinthWitness = try Self.witness(level)
            progress.record(level: level, actions: witness.actions.count, shortest: witness.actions.count,
                            opensNext: true, trace: witness.actions)
        }
        return progress
    }

    /// `progress` encoded, its solved entry for `level` edited by `edit`, decoded again.
    static func edited(_ progress: LissajousLabyrinthProgress, level: Int,
                       _ edit: (inout [String: Any]) -> Void) throws -> LissajousLabyrinthProgress {
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try progress.encoded()) as? [String: Any])
        var entries: [[String: Any]] = try #require(object["solved"] as? [[String: Any]])
        for index in entries.indices where entries[index]["level"] as? Int == level {
            edit(&entries[index])
        }
        object["solved"] = entries
        return try JSONDecoder().decode(LissajousLabyrinthProgress.self,
                                        from: try JSONSerialization.data(withJSONObject: object))
    }

    /// Every certified level of `band` (1 … 5), recorded with its solution as the trace, verifies and is kept.
    func verifyBand(_ band: Int) throws {
        var levels: [Int] = []
        for entry in LissajousLabyrinthManifest.entries where entry.band == band { levels.append(entry.number) }
        #expect(levels.count == 20)
        let progress: LissajousLabyrinthProgress = try Self.honest(levels)
        for level in levels {
            let result: LissajousLabyrinthProgress.Result = try #require(progress.solved[level])
            #expect(result.verified && result.stars == 3, "level \(level)")
            #expect(LissajousLabyrinthReconciliation.verifies(level: level, result: result), "level \(level)")
        }
        let reconciled: (progress: LissajousLabyrinthProgress, dropped: Int) =
            LissajousLabyrinthReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
    }

    @Test func certifiedSolutionsBand1Verify() throws { try verifyBand(1) }
    @Test func certifiedSolutionsBand2Verify() throws { try verifyBand(2) }
    @Test func certifiedSolutionsBand3Verify() throws { try verifyBand(3) }
    @Test func certifiedSolutionsBand4Verify() throws { try verifyBand(4) }
    @Test func certifiedSolutionsBand5Verify() throws { try verifyBand(5) }

    @Test func aTracedWinIsVerifiedAndOnlyFewerActionsReplaceIt() throws {
        let witness: LissajousLabyrinthWitness = try Self.witness(1)
        let shortest: Int = witness.actions.count
        let longer: [LissajousLabyrinthAction] = witness.actions + witness.actions
        var progress: LissajousLabyrinthProgress = LissajousLabyrinthProgress()
        progress.record(level: 1, actions: longer.count, shortest: shortest, opensNext: true, trace: longer)
        #expect(progress.solved[1]?.verified == true)
        #expect(progress.solved[1]?.trace == longer)
        progress.record(level: 1, actions: shortest, shortest: shortest, opensNext: true, trace: witness.actions)
        #expect(progress.solved[1]?.trace == witness.actions)
        #expect(progress.solved[1]?.stars == 3)
        // A tie keeps the earlier trace.
        let other: [LissajousLabyrinthAction] = Array(witness.actions.reversed())
        progress.record(level: 1, actions: shortest, shortest: shortest, opensNext: true, trace: other)
        #expect(progress.solved[1]?.trace == witness.actions)
        // More actions never replace.
        progress.record(level: 1, actions: shortest + 3, shortest: shortest, opensNext: true, trace: longer)
        #expect(progress.solved[1]?.trace == witness.actions)
        #expect(progress.frontier == 2)
        // A daily traced win never opens a level; a level outside 1 … 100 is ignored.
        progress.record(level: 50, actions: 4, shortest: 4, opensNext: false, trace: witness.actions)
        #expect(progress.frontier == 2 && progress.solved[50]?.verified == true)
        progress.record(level: 101, actions: 4, shortest: 4, opensNext: true, trace: witness.actions)
        #expect(progress.solved[101] == nil && progress.frontier == 2)
        // A win without a trace is unverified, as before.
        progress.record(level: 2, actions: 9, shortest: 4, opensNext: true)
        #expect(progress.solved[2] == LissajousLabyrinthProgress.Result(bestActions: 9, stars: 1))
        #expect(progress.solved[2]?.verified == false && progress.solved[2]?.trace.isEmpty == true)
        // drop removes the result; the frontier is unchanged.
        progress.drop(level: 1)
        #expect(progress.solved[1] == nil && progress.frontier == 3)
        progress.drop(level: 77)
        #expect(progress.solved.count == 2)
    }

    @Test func tracesEncodeAndASchemaTwoEncodingDecodesUnverified() throws {
        let progress: LissajousLabyrinthProgress = try Self.honest([1, 2])
        let data: Data = try progress.encoded()
        let decoded: LissajousLabyrinthProgress = try JSONDecoder().decode(LissajousLabyrinthProgress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"trace\":[{\"dial\":"))
        #expect(text.contains("\"verified\":true"))
        let old: Data = Data("{\"frontier\":3,\"solved\":[{\"bestActions\":5,\"level\":1,\"stars\":2}]}".utf8)
        let restored: LissajousLabyrinthProgress = try JSONDecoder().decode(LissajousLabyrinthProgress.self, from: old)
        #expect(restored.solved[1] == LissajousLabyrinthProgress.Result(bestActions: 5, stars: 2))
        #expect(restored.solved[1]?.verified == false)
        #expect(restored.solved[1]?.trace.isEmpty == true)
        #expect(restored.frontier == 3)
    }

    @Test func overlongOrOutOfRangeTracesAreRefused() throws {
        var long: String = ""
        for index in 0..<65 {
            long += (index == 0 ? "" : ",") + "{\"dial\":\"phaseA\",\"value\":\(index % 2)}"
        }
        let bad: [String] = [
            "{\"frontier\":2,\"solved\":[{\"bestActions\":65,\"level\":1,\"stars\":1,\"trace\":[" + long
                + "],\"verified\":true}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":1,\"level\":1,\"stars\":3,"
                + "\"trace\":[{\"dial\":\"frequencyA\",\"value\":10}],\"verified\":true}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":1,\"level\":1,\"stars\":3,"
                + "\"trace\":[{\"dial\":\"phaseC\",\"value\":-1}],\"verified\":true}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":1,\"level\":1,\"stars\":3,"
                + "\"trace\":[{\"dial\":\"amplitude\",\"value\":1}],\"verified\":true}]}",
        ]
        for json in bad {
            #expect(throws: DecodingError.self, "\(json.prefix(80))") {
                _ = try JSONDecoder().decode(LissajousLabyrinthProgress.self, from: Data(json.utf8))
            }
        }
        // 64 actions is the most accepted.
        var limit: String = ""
        for index in 0..<64 {
            limit += (index == 0 ? "" : ",") + "{\"dial\":\"phaseA\",\"value\":\(index % 2)}"
        }
        let accepted: String = "{\"frontier\":2,\"solved\":[{\"bestActions\":64,\"level\":1,\"stars\":1,\"trace\":["
            + limit + "],\"verified\":true}]}"
        let decoded: LissajousLabyrinthProgress = try JSONDecoder().decode(LissajousLabyrinthProgress.self,
                                                                           from: Data(accepted.utf8))
        #expect(decoded.solved[1]?.trace.count == 64)
    }

    /// The first value of the first trace action's dial, other than the certified one, whose one-action change leaves a
    /// fresh play of level `level` legal but not won (the trace step a tampered file could change).
    static func losingStep(level: Int) throws -> LissajousLabyrinthAction {
        let witness: LissajousLabyrinthWitness = try Self.witness(level)
        let first: LissajousLabyrinthAction = witness.actions[0]
        for value in first.dial.range where value != first.value {
            var play: LissajousLabyrinthPlay = try LissajousLabyrinthExperienceCore.freshPlay(of: witness.level)
            let action: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: first.dial, value: value)
            do {
                try play.apply(action, expecting: play.fingerprint)
            } catch {
                continue
            }
            if play.stage != .won { return action }
        }
        throw LissajousLabyrinthError.level("no losing step")
    }

    /// `action` as encoded JSON.
    static func object(_ action: LissajousLabyrinthAction) -> [String: Any] {
        ["dial": action.dial.rawValue, "value": action.value]
    }

    @Test func editedStarsActionsStepsAndIllegalTracesAreDropped() throws {
        let progress: LissajousLabyrinthProgress = try Self.honest([1, 2, 3, 4, 5, 6])
        // Level 1: stars edited.
        var tampered: LissajousLabyrinthProgress = try Self.edited(progress, level: 1) { entry in
            entry["stars"] = ((entry["stars"] as? Int) ?? 3) == 3 ? 2 : 3
        }
        // Level 2: best actions edited.
        tampered = try Self.edited(tampered, level: 2) { entry in
            entry["bestActions"] = ((entry["bestActions"] as? Int) ?? 0) + 1
        }
        // Level 4: the first trace step changed to a legal value that does not win.
        let changed: [String: Any] = Self.object(try Self.losingStep(level: 4))
        tampered = try Self.edited(tampered, level: 4) { entry in
            var trace: [[String: Any]] = (entry["trace"] as? [[String: Any]]) ?? []
            trace[0] = changed
            entry["trace"] = trace
        }
        // Level 5: an illegal trace (the first action repeated: the repeat is refused, "no-change" or after the win).
        tampered = try Self.edited(tampered, level: 5) { entry in
            var trace: [[String: Any]] = (entry["trace"] as? [[String: Any]]) ?? []
            trace.insert(trace[0], at: 1)
            entry["trace"] = trace
            entry["bestActions"] = trace.count
        }
        // Level 3 (two actions): a trace that does not win (the last action removed, best actions matching).
        tampered = try Self.edited(tampered, level: 3) { entry in
            var trace: [[String: Any]] = (entry["trace"] as? [[String: Any]]) ?? []
            trace.removeLast()
            entry["trace"] = trace
            entry["bestActions"] = trace.count
        }
        #expect(tampered.solved[3]?.trace.count == 1)
        let reconciled: (progress: LissajousLabyrinthProgress, dropped: Int) =
            LissajousLabyrinthReconciliation.reconcile(tampered)
        #expect(reconciled.dropped == 5)
        #expect(reconciled.progress.solved.keys.sorted() == [6])
        #expect(reconciled.progress.solved[6] == progress.solved[6])
        #expect(reconciled.progress.frontier == progress.frontier)
    }

    @Test func tracelessResultsAreKeptAndTheFrontierStaysAsSaved() throws {
        var progress: LissajousLabyrinthProgress = try Self.honest([7])
        progress.record(level: 3, actions: 12, shortest: 5, opensNext: false)
        // A daily traced win beyond the frontier.
        let daily: LissajousLabyrinthWitness = try Self.witness(60)
        progress.record(level: 60, actions: daily.actions.count, shortest: daily.actions.count, opensNext: false,
                        trace: daily.actions)
        #expect(progress.frontier == 8)
        let reconciled: (progress: LissajousLabyrinthProgress, dropped: Int) =
            LissajousLabyrinthReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
        #expect(reconciled.progress.solved[3]?.verified == false)
        #expect(reconciled.progress.frontier == 8)
        // Dropping never lowers the frontier.
        let tampered: LissajousLabyrinthProgress = try Self.edited(progress, level: 7) { entry in entry["stars"] = 1 }
        let after: (progress: LissajousLabyrinthProgress, dropped: Int) =
            LissajousLabyrinthReconciliation.reconcile(tampered)
        #expect(after.dropped == 1 && after.progress.frontier == 8 && after.progress.solved[7] == nil)
        // A verified result without a trace, a traced result on another or an out-of-range level never verifies.
        let empty: LissajousLabyrinthProgress.Result = LissajousLabyrinthProgress.Result(
            bestActions: 0, stars: 3, trace: [], verified: true)
        #expect(!LissajousLabyrinthReconciliation.verifies(level: 1, result: empty))
        let claimed: LissajousLabyrinthProgress = try Self.edited(progress, level: 3) { entry in
            entry["verified"] = true
        }
        #expect(LissajousLabyrinthReconciliation.reconcile(claimed).dropped == 1)
        let witness: LissajousLabyrinthWitness = try Self.witness(1)
        let honest: LissajousLabyrinthProgress.Result = LissajousLabyrinthProgress.Result(
            bestActions: witness.actions.count, stars: 3, trace: witness.actions, verified: true)
        #expect(LissajousLabyrinthReconciliation.verifies(level: 1, result: honest))
        #expect(!LissajousLabyrinthReconciliation.verifies(level: 0, result: honest))
        #expect(!LissajousLabyrinthReconciliation.verifies(level: 101, result: honest))
        #expect(!LissajousLabyrinthReconciliation.verifies(level: 2, result: honest))
    }

    @Test func replayModeRoundTrips() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for level in [1, 42, 100] {
            let mode: LissajousLabyrinthMode = .replay(level: level)
            let data: Data = try encoder.encode(mode)
            #expect(String(decoding: data, as: UTF8.self) == "{\"level\":\(level),\"mode\":\"replay\"}")
            #expect(try JSONDecoder().decode(LissajousLabyrinthMode.self, from: data) == mode)
        }
        let bad: [String] = ["{\"mode\":\"replay\",\"level\":0}", "{\"mode\":\"replay\",\"level\":101}",
                             "{\"mode\":\"replay\"}"]
        for json in bad {
            #expect(throws: DecodingError.self, "\(json)") {
                _ = try JSONDecoder().decode(LissajousLabyrinthMode.self, from: Data(json.utf8))
            }
        }
        #expect(LissajousLabyrinthFeedbackPlan.modeName(.replay(level: 3)) == "replay")
    }
}
