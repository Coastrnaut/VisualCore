// CelestialEclipseLabReplayCoreTests — feature 467 (R02-G17-07) T-R02G1707-003 (FR-R02G1707-001 … 007;
// SC-R02G1707-001; clarifications Q1–Q5). Snapshot schema 3 and digest v3 of the adapter core: a campaign win stores
// its effective trace (the phase changes, an undone probe change left out but counted in actions spent, then the run)
// as a verified result, practice stores nothing; the replay rules and codes (`r02-g17.no-replay`,
// `r02-g17.replay-end`, `r02-g17.replay`) and the allow-list (replay.*, tutorial.dismiss, orbit.choose, clock.show,
// settings.sound); a replay reproducing the campaign fingerprints and recording nothing; a replay saved mid-way
// restoring while a changed, reordered or undo-carrying replay is refused `damaged`; reconciliation on restore (an
// edited result dropped and counted in `reconciliationDropped`, a replay whose result was dropped or never verified
// returning to campaign); the migrations 2 → 3 and 1 → 3; and the sound setting (snapshotted, never digested, off
// after a reset). Modelled on feature 457's `StarlitCartoucheReplayCoreTests`. Level 1 is certified once per process,
// so the run stays short. Explicit types, plain loops, no `try` inside `#expect`.
import Foundation
import Testing
@testable import CelestialEclipseLabCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct CelestialEclipseLabReplayCoreTests {
    typealias Core = CelestialEclipseLabExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// An action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func act(_ action: CelestialEclipseLabAction) -> ExperienceAction {
        switch action {
        case let .phase(body, offset): act("orbit.phase", [Double(body), Double(offset)])
        case .run: act("clock.run")
        }
    }

    /// The certified plan's phase changes of level `number` (the run not included).
    static func plan(_ number: Int) throws -> [CelestialEclipseLabAction] {
        try Core.generated(number: number).plan.actions
    }

    /// The trace a win by the certified plan of level `number` stores: its phase changes, then the run.
    static func trace(_ number: Int) throws -> [CelestialEclipseLabAction] {
        try plan(number) + [.run]
    }

    /// The refusal of rule code `code`.
    static func refusal(_ code: String) -> ActionResult { .rejected(.rule(code: code)) }

    /// The number of phase and run records of `play` (a fresh play also holds its begin and tutorial records).
    static func actionRecords(_ play: CelestialEclipseLabPlay) -> Int {
        Core.actionRecordCount(play.records)
    }

    /// Level 1 won in campaign by its certified plan and the run, from seed 0.
    static func wonLevelOne() async throws -> Core {
        var core: Core = try await Core.prepare(seed: 0)
        for step in try trace(1) { #expect(core.apply(act(step)) == .accepted) }
        #expect(core.play.stage == .won)
        return core
    }

    /// A phase change from `core`'s opening that the kernel accepts, leaves the play playing and differs from `other`.
    static func otherPhase(from core: Core, than other: CelestialEclipseLabAction) -> CelestialEclipseLabAction? {
        for body in 0..<core.play.level.bodies.count {
            for offset in Core.offsetRange {
                let change: CelestialEclipseLabAction = .phase(body, offset)
                guard change != other else { continue }
                var trial: Core = core
                guard trial.apply(act(change)) == .accepted, trial.play.stage == .playing else { continue }
                return change
            }
        }
        return nil
    }

    /// `payload` as a JSON object.
    static func object(_ payload: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
    }

    /// `object` as sorted JSON data.
    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// `value` encoded by the core's payload encoder, as a JSON value.
    static func json<Value: Encodable>(_ value: Value) throws -> Any {
        try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(value))
    }

    /// `object` with field `key` of its first saved result set to `value`.
    static func editingFirstResult(_ object: [String: Any], key: String, value: Any) throws -> [String: Any] {
        var edited: [String: Any] = object
        var progress: [String: Any] = try #require(edited["progress"] as? [String: Any])
        var solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
        try #require(!solved.isEmpty)
        solved[0][key] = value
        progress["solved"] = solved
        edited["progress"] = progress
        return edited
    }

    @Test func aWinStoresItsTraceAndPracticeStoresNothing() async throws {
        let won: Core = try await Self.wonLevelOne()
        let result: CelestialEclipseLabProgress.Result = try #require(won.progress.solved[1])
        let certified: [CelestialEclipseLabAction] = try Self.trace(1)
        #expect(result.verified && result.trace == certified)
        #expect(result.trace.last == .run && won.progress.frontier == 2)
        // An undone probe change is left out of the trace (but spent: actions spent count it).
        var core: Core = try await Core.prepare(seed: 0)
        let plan: [CelestialEclipseLabAction] = try Self.plan(1)
        try #require(!plan.isEmpty)
        let probe: CelestialEclipseLabAction = try #require(Self.otherPhase(from: core, than: plan[0]))
        #expect(core.apply(Self.act(probe)) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in certified { #expect(core.apply(Self.act(step)) == .accepted) }
        let undone: CelestialEclipseLabProgress.Result = try #require(core.progress.solved[1])
        #expect(undone.trace == certified && undone.verified && undone.actionsSpent == plan.count + 1)
        #expect(!undone.trace.contains(probe))
        // Practice stores nothing.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        for step in certified { #expect(practice.apply(Self.act(step)) == .accepted) }
        #expect(practice.play.stage == .won && practice.progress.solved.isEmpty)
    }

    @Test func aReplayReproducesTheCampaignAndRecordsNothing() async throws {
        let won: Core = try await Self.wonLevelOne()
        let trace: [CelestialEclipseLabAction] = try Self.trace(1)
        // The campaign fingerprints after each action.
        var campaign: Core = try await Core.prepare(seed: 0)
        var fingerprints: [String] = []
        for step in trace {
            #expect(campaign.apply(Self.act(step)) == .accepted)
            fingerprints.append(campaign.play.fingerprint)
        }
        let fresh: CelestialEclipseLabPlay = try Core.freshPlay(of: try Core.level(number: 1))
        var replay: Core = won
        #expect(replay.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(replay.mode == .replay(level: 1) && replay.tutorial == .done)
        #expect(replay.play == fresh && Self.actionRecords(replay.play) == 0)
        for index in 0..<trace.count {
            #expect(replay.apply(Self.act("replay.step")) == .accepted)
            #expect(replay.play.fingerprint == fingerprints[index], "step \(index)")
        }
        #expect(replay.play.stage == .won && replay.progress == won.progress)
        #expect(replay.apply(Self.act("replay.step")) == Self.refusal(CelestialEclipseLabExperienceRule.replayEnd))
        // replay.start during a replay restarts it.
        #expect(replay.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(replay.play == fresh && replay.mode == .replay(level: 1))
        #expect(replay.apply(Self.act("replay.stop")) == .accepted)
        #expect(replay.mode == .campaign && replay.levelNumber == 1 && replay.progress == won.progress)
        #expect(replay.play == fresh)
    }

    @Test func theReplayRulesAndCodes() async throws {
        #expect(CelestialEclipseLabExperienceRule.noReplay == "r02-g17.no-replay")
        #expect(CelestialEclipseLabExperienceRule.replayEnd == "r02-g17.replay-end")
        #expect(CelestialEclipseLabExperienceRule.replay == "r02-g17.replay")
        let fresh: Core = try await Core.prepare(seed: 0)
        let noReplay: ActionResult = Self.refusal(CelestialEclipseLabExperienceRule.noReplay)
        var none: Core = fresh
        #expect(none.apply(Self.act("replay.start", [1])) == noReplay)
        #expect(none.apply(Self.act("replay.step")) == noReplay)
        #expect(none.apply(Self.act("replay.stop")) == noReplay)
        #expect(none == fresh)
        let won: Core = try await Self.wonLevelOne()
        var replay: Core = won
        #expect(replay.apply(Self.act("replay.start", [2])) == noReplay)
        #expect(replay.apply(Self.act("replay.start", [1])) == .accepted)
        let inReplay: Core = replay
        let refused: ActionResult = Self.refusal(CelestialEclipseLabExperienceRule.replay)
        let plan: [CelestialEclipseLabAction] = try Self.plan(1)
        try #require(!plan.isEmpty)
        let blocked: [ExperienceAction] = [Self.act(plan[0]), Self.act("clock.run"), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("level.next"),
                                           Self.act("level.select", [1]), Self.act("mode.daily", [2026, 1, 1]),
                                           Self.act("mode.practice"), Self.act("mode.campaign")]
        for action in blocked {
            #expect(replay.apply(action) == refused, "\(action.control)")
            #expect(replay == inReplay && replay.play == inReplay.play)
        }
        // Presentation, the tutorial and the sound stay allowed.
        let choice: Int = CelestialEclipseLabSceneSnapshot.defaultChoice(replay.play.level)
        #expect(replay.apply(Self.act("orbit.choose", [Double(choice)])) == .accepted)
        #expect(replay.apply(Self.act("clock.show", [3])) == .accepted && replay.shownTick == 3)
        #expect(replay.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(replay.apply(Self.act("settings.sound", [1])) == .accepted && replay.soundOn)
        #expect(Core.replayControls == ["replay.start", "replay.step", "replay.stop", "tutorial.dismiss",
                                        "orbit.choose", "clock.show", "settings.sound"])
        // A replayed win claims no stars.
        var steps: Int = 0
        while replay.play.stage == .playing && steps < 64 {
            #expect(replay.apply(Self.act("replay.step")) == .accepted)
            steps += 1
        }
        #expect(replay.play.stage == .won && replay.progress == won.progress)
        let words: String = CelestialEclipseLabFeedbackPlan.outcomePlan(replay).text ?? ""
        #expect(!words.contains("stars") && words.hasPrefix(CelestialEclipseLabFeedbackPlan.wonText))
        #expect(CelestialEclipseLabFeedbackPlan.refusalText(code: CelestialEclipseLabExperienceRule.noReplay)
                    == "There is no saved solution to replay for this level.")
        #expect(CelestialEclipseLabFeedbackPlan.refusalText(code: CelestialEclipseLabExperienceRule.replayEnd)
                    == "The replay is over.")
        let replayCode: String = CelestialEclipseLabFeedbackPlan.rulePrefix + CelestialEclipseLabExperienceRule.replay
        #expect(CelestialEclipseLabFeedbackPlan.refusalText(code: replayCode) == "Stop the replay first.")
    }

    @Test func aReplaySavedMidwayRestoresAndAChangedOneIsDamaged() async throws {
        let won: Core = try await Self.wonLevelOne()
        let plan: [CelestialEclipseLabAction] = try Self.plan(1)
        try #require(plan.count >= 2)
        var replay: Core = won
        #expect(replay.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(replay.apply(Self.act("replay.step")) == .accepted)
        let payload: Data = try replay.snapshotPayload()
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored == replay && restored.reconciliationDropped == 0)
        #expect(restored.mode == .replay(level: 1) && Self.actionRecords(restored.play) == 1)
        let restoredDigest: StateDigest = try Self.digest(restored)
        let replayDigest: StateDigest = try Self.digest(replay)
        #expect(restoredDigest == replayDigest)
        // The restored replay continues to the win.
        var continued: Core = restored
        var steps: Int = 0
        while continued.play.stage == .playing && steps < 64 {
            #expect(continued.apply(Self.act("replay.step")) == .accepted)
            steps += 1
        }
        #expect(continued.play.stage == .won && steps == plan.count)
        // Records of a campaign play that undid and redid the first change: phase and run records only are allowed.
        var undoing: Core = try await Core.prepare(seed: 0)
        #expect(undoing.apply(Self.act(plan[0])) == .accepted)
        #expect(undoing.apply(Self.act("play.undo")) == .accepted)
        #expect(undoing.apply(Self.act("play.redo")) == .accepted)
        // Records of a campaign play whose first change is not the trace's.
        var other: Core = try await Core.prepare(seed: 0)
        let stray: CelestialEclipseLabAction = try #require(Self.otherPhase(from: other, than: plan[0]))
        #expect(other.apply(Self.act(stray)) == .accepted)
        // Records of a campaign play that applied the trace's first two changes in the other order.
        var reordered: Core = try await Core.prepare(seed: 0)
        #expect(reordered.apply(Self.act(plan[1])) == .accepted)
        #expect(reordered.apply(Self.act(plan[0])) == .accepted)
        let damaged: [[CelestialEclipseLabRecord]] = [undoing.play.records, other.play.records,
                                                      reordered.play.records]
        for records in damaged {
            var edited: [String: Any] = try Self.object(payload)
            edited["records"] = try Self.json(records)
            let editedData: Data = try Self.data(edited)
            #expect(throws: CelestialEclipseLabRestoreRefusal.damaged) {
                try Core.restore(payload: editedData, seed: 0)
            }
        }
        // A replay whose result is not verified returns to campaign at that level.
        let unverifiedTrace: [String: Any] = try Self.editingFirstResult(try Self.object(payload), key: "trace",
                                                                         value: [Any]())
        let unverified: [String: Any] = try Self.editingFirstResult(unverifiedTrace, key: "verified", value: false)
        let back: Core = try Core.restore(payload: try Self.data(unverified), seed: 0)
        #expect(back.mode == .campaign && back.levelNumber == 1 && back.progress.solved[1]?.verified == false)
        #expect(back.reconciliationDropped == 0 && Self.actionRecords(back.play) == 0)
        // A replay whose result is dropped by reconciliation returns to campaign at that level.
        let stars: Int = try #require(won.progress.solved[1]?.stars)
        let edited: [String: Any] = try Self.editingFirstResult(try Self.object(payload), key: "stars",
                                                                value: stars == 1 ? 2 : 1)
        let dropped: Core = try Core.restore(payload: try Self.data(edited), seed: 0)
        #expect(dropped.mode == .campaign && dropped.levelNumber == 1 && dropped.progress.solved[1] == nil)
        #expect(dropped.reconciliationDropped == 1 && Self.actionRecords(dropped.play) == 0)
    }

    @Test func restoreReconcilesTheSavedResults() async throws {
        let won: Core = try await Self.wonLevelOne()
        let payload: Data = try won.snapshotPayload()
        let honest: Core = try Core.restore(payload: payload, seed: 0)
        #expect(honest == won && honest.reconciliationDropped == 0)
        // Edited stars, edited actions spent and a trace without its run are dropped and counted; the frontier stays.
        let stars: Int = try #require(won.progress.solved[1]?.stars)
        let noRun: Any = try Self.json(try Self.plan(1))
        let edits: [(String, Any)] = [("stars", stars == 1 ? 2 : 1), ("actionsSpent", 0), ("trace", noRun)]
        for (key, value) in edits {
            let edited: [String: Any] = try Self.editingFirstResult(try Self.object(payload), key: key, value: value)
            let restored: Core = try Core.restore(payload: try Self.data(edited), seed: 0)
            #expect(restored.reconciliationDropped == 1 && restored.progress.solved[1] == nil, "\(key)")
            #expect(restored.progress.frontier == won.progress.frontier)
            // The dropped count is not in ==: the restored state equals a won-and-dropped one.
            var droppedProgress: CelestialEclipseLabProgress = won.progress
            droppedProgress.drop(level: 1)
            #expect(restored.progress == droppedProgress)
        }
    }

    @Test func schemaTwoAndOnePayloadsMigrateToThree() async throws {
        let won: Core = try await Self.wonLevelOne()
        // A schema-2 object: no sound, results without trace or verified.
        var schemaTwo: [String: Any] = try Self.object(try won.snapshotPayload())
        schemaTwo.removeValue(forKey: "sound")
        var progress: [String: Any] = try #require(schemaTwo["progress"] as? [String: Any])
        var solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
        try #require(!solved.isEmpty)
        solved[0].removeValue(forKey: "trace")
        solved[0].removeValue(forKey: "verified")
        progress["solved"] = solved
        schemaTwo["progress"] = progress
        let three: [String: Any] = try Core.migratedToSchemaThree(schemaTwo)
        let chained: [String: Any] = try Core.migrations.migrate(schemaTwo, from: 2)
        let threeData: Data = try Self.data(three)
        let chainedData: Data = try Self.data(chained)
        #expect(threeData == chainedData)
        #expect(three["sound"] as? Bool == false)
        let restored: Core = try Core.restore(payload: threeData, seed: 0)
        let result: CelestialEclipseLabProgress.Result = try #require(restored.progress.solved[1])
        let spent: Int? = won.progress.solved[1]?.actionsSpent
        #expect(!result.verified && result.trace.isEmpty && result.actionsSpent == spent)
        #expect(restored.reconciliationDropped == 0 && !restored.soundOn && restored.progress.frontier == 2)
        var copy: Core = restored
        #expect(copy.apply(Self.act("replay.start", [1])) == Self.refusal(CelestialEclipseLabExperienceRule.noReplay))
        #expect(throws: CelestialEclipseLabRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 1]) }
        // Schema 1 → 3: the fresh opening of level 3, no won levels, sound off.
        let opening: Core = try await Core.prepare(seed: 2)
        #expect(opening.levelNumber == 3)
        let records: Any = try Self.json(opening.play.records)
        let one: [String: Any] = try Core.migrations.migrate(["level": 3, "records": records], from: 1)
        let fromOne: Core = try Core.restore(payload: try Self.data(one), seed: 2)
        #expect(fromOne.progress.solved.isEmpty && fromOne.progress.frontier == 3 && !fromOne.soundOn)
        #expect(fromOne.play == opening.play && fromOne.reconciliationDropped == 0)
    }

    @Test func theSoundSettingIsSavedButNotDigested() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(!core.soundOn)
        let before: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        let after: StateDigest = try Self.digest(core)
        #expect(after == before)
        let text: String = String(decoding: try core.snapshotPayload(), as: UTF8.self)
        #expect(text.contains("\"sound\":true"))
        let restored: Core = try Core.restore(payload: Data(text.utf8), seed: 0)
        #expect(restored.soundOn && restored == core)
        let notWhole: ActionResult = Self.refusal(CelestialEclipseLabExperienceRule.notWhole)
        #expect(core.apply(Self.act("settings.sound", [0.5])) == notWhole)
        #expect(core.apply(Self.act("settings.sound", [2])) != .accepted && core.soundOn)
        #expect(core.apply(Self.act("settings.sound", [0])) == .accepted && !core.soundOn)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted)
        core.reset()
        #expect(!core.soundOn)
    }
}
