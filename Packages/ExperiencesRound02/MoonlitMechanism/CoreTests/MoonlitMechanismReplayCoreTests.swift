// MoonlitMechanismReplayCoreTests — feature 437 (R02-G14-07) T-R02G1407-003 (FR-R02G1407-001 … 007; clarifications
// Q1–Q5). The adapter's persistence and replay: the migrations 2 → 3 (each result gains an empty trace and `verified`
// false, the sound choice off) and 1 → 3 (chained); reconciliation on restore (an edited stars, actions-spent or trace
// field restores with the result dropped and `reconciliationDropped` counted, the frontier kept); the replay rules and
// codes (`r02-g14.no-replay` without a verified traced result or outside replay, `replay.step` through the whole trace
// to a win that records nothing, `r02-g14.replay-end` after the last action, every other play control refused
// `r02-g14.replay` while `tutorial.dismiss`, `frame.show` and `settings.sound` stay allowed, `replay.stop` to campaign
// at that level or at the frontier); a replay saved mid-way restores, while a changed, reordered or undo-carrying replay
// payload is refused `.damaged`; a replay whose result does not reconcile returns to campaign; `settings.sound` toggles
// `soundOn`, is snapshotted, survives restore and never changes the digest. Fixture seed 2_437 (level 38, whose
// certified witness is turn(1), reseat(2, 1), lamp(−1), run; the test reads it from the generator, never hard-codes
// it). Witness actions come from `MoonlitMechanismExperienceCore.generated(number:).actions`. Levels are certified once
// per process, so the run stays short. Explicit types, plain loops, no wall-clock asserts.
import Foundation
import Testing
@testable import MoonlitMechanismCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct MoonlitMechanismReplayCoreTests {
    typealias Core = MoonlitMechanismExperienceCore

    /// The fixture seed (feature 437); it chooses level `2_437 % 100 + 1` = 38.
    private static let seed: UInt64 = 2_437

    /// The level the fixture seed chooses.
    private static var level: Int { Core.levelNumber(forSeed: seed) }

    /// The digest of `core` as the engine computes it.
    private static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// An action of `control` with `values`.
    private static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    private static func act(_ action: MoonlitMechanismAction) -> ExperienceAction {
        switch action {
        case let .turn(step): act("handle.turn", [Double(step)])
        case let .reseat(gear, step): act("gear.reseat", [Double(gear), Double(step)])
        case let .lamp(step): act("lamp.step", [Double(step)])
        case .run: act("machine.run")
        }
    }

    /// The certified witness actions of level `number` (its turns, re-seats and lamp steps, then the run).
    private static func witness(_ number: Int) throws -> [MoonlitMechanismAction] {
        try Core.generated(number: number).actions
    }

    /// The fixture's opening state after the witness won its level in campaign: a verified result with the witness as
    /// its trace, the next level open.
    private static func wonCore() async throws -> Core {
        var core: Core = try await Core.prepare(seed: seed)
        for step in try witness(level) { #expect(core.apply(act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.mode == .campaign)
        return core
    }

    /// `payload` as a JSON object.
    private static func object(_ payload: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
    }

    /// `object` as JSON with sorted keys.
    private static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// `object` with the first stored result's field `key` set to `value` (nil removes it).
    private static func editingFirstResult(_ object: [String: Any], key: String, value: Any?) throws -> [String: Any] {
        var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
        var solved: [Any] = try #require(progress["solved"] as? [Any])
        try #require(!solved.isEmpty)
        var result: [String: Any] = try #require(solved[0] as? [String: Any])
        result[key] = value
        solved[0] = result
        progress["solved"] = solved
        var edited: [String: Any] = object
        edited["progress"] = progress
        return edited
    }

    /// `object` with its records replaced by `records`.
    private static func replacingRecords(_ object: [String: Any], with records: [MoonlitMechanismRecord]) throws
        -> [String: Any] {
        var edited: [String: Any] = object
        edited["records"] = try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(records))
        return edited
    }

    /// A date in 2026 whose daily level is not a tutorial level and lies beyond `frontier` (not open), with that level.
    private static func closedDaily(beyond frontier: Int) -> (date: [Double], level: Int)? {
        for month in 1...12 {
            for day in 1...28 {
                guard let daily = MoonlitMechanismProgress.dailyLevel(year: 2026, month: month, day: day) else {
                    continue
                }
                if daily > frontier && daily > MoonlitMechanismTutorialStep.tutorialLevels.upperBound {
                    return ([2026, Double(month), Double(day)], daily)
                }
            }
        }
        return nil
    }

    // MARK: Migrations

    @Test func aSchemaTwoPayloadMigratesToThreeWithEmptyTracesAndSoundOff() async throws {
        let won: Core = try await Self.wonCore()
        let actions: [MoonlitMechanismAction] = try Self.witness(Self.level)
        // A schema-2 object: results without trace or verified, no sound key.
        var schemaTwo: [String: Any] = try Self.object(try won.snapshotPayload())
        schemaTwo = try Self.editingFirstResult(schemaTwo, key: "trace", value: nil)
        schemaTwo = try Self.editingFirstResult(schemaTwo, key: "verified", value: nil)
        schemaTwo["sound"] = nil
        let migrated: [String: Any] = try Core.migrations.migrate(schemaTwo, from: 2)
        #expect(migrated["sound"] as? Bool == false)
        let direct: [String: Any] = try Core.migratedToSchemaThree(schemaTwo)
        #expect(try Self.data(direct) == (try Self.data(migrated)))
        let progress: [String: Any] = try #require(migrated["progress"] as? [String: Any])
        let solved: [Any] = try #require(progress["solved"] as? [Any])
        let first: [String: Any] = try #require(solved.first as? [String: Any])
        #expect((first["trace"] as? [Any])?.isEmpty == true && first["verified"] as? Bool == false)
        // Restored: the unverified result is kept (not dropped), the frontier kept, sound off.
        let restored: Core = try Core.restore(payload: try Self.data(migrated), seed: Self.seed)
        let unverified: MoonlitMechanismProgress.Result = MoonlitMechanismProgress.Result(actionsSpent: actions.count,
                                                                                          stars: 3)
        #expect(restored.progress.solved[Self.level] == unverified)
        #expect(restored.reconciliationDropped == 0 && restored.soundOn == false)
        #expect(restored.progress.frontier == won.progress.frontier && restored.play == won.play)
        // An unverified result has nothing to replay.
        var replaying: Core = restored
        #expect(replaying.apply(Self.act("replay.start", [Double(Self.level)]))
            == .rejected(.rule(code: MoonlitMechanismExperienceRule.noReplay)))
        #expect(replaying == restored)
        // A schema-2 object without a progress is refused.
        #expect(throws: MoonlitMechanismRestoreRefusal.damaged) {
            try Core.migratedToSchemaThree(["level": 3, "records": [Any]()])
        }
    }

    @Test func aSchemaOnePayloadMigratesThroughTwoToThree() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let first: MoonlitMechanismAction = try #require(try Self.witness(Self.level).first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let records: Any = try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(core.play.records))
        let schemaOne: [String: Any] = ["level": Self.level, "records": records]
        let migrated: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
        let stepped: [String: Any] = try Core.migratedToSchemaThree(try Core.migratedToSchemaTwo(schemaOne))
        #expect(try Self.data(migrated) == (try Self.data(stepped)))
        #expect(migrated["sound"] as? Bool == false && migrated["mode"] != nil && migrated["progress"] != nil)
        let restored: Core = try Core.restore(payload: try Self.data(migrated), seed: Self.seed)
        #expect(restored.levelNumber == Self.level && restored.play == core.play && restored.mode == .campaign)
        #expect(restored.progress.frontier == Self.level && restored.progress.solved.isEmpty)
        #expect(restored.soundOn == false && restored.reconciliationDropped == 0)
        #expect(try Self.digest(restored) == Self.digest(core))
    }

    // MARK: Reconciliation

    @Test func anEditedResultIsDroppedOnRestoreAndTheFrontierKept() async throws {
        let won: Core = try await Self.wonCore()
        let actions: [MoonlitMechanismAction] = try Self.witness(Self.level)
        let saved: [String: Any] = try Self.object(try won.snapshotPayload())
        // The honest payload keeps its verified result.
        let honest: Core = try Core.restore(payload: try Self.data(saved), seed: Self.seed)
        #expect(honest == won && honest.reconciliationDropped == 0)
        #expect(honest.progress.solved[Self.level]?.verified == true)
        // Edited stars (the stars rule gives 3), edited actions spent (below what the trace spends), an edited trace
        // (the run removed, so the play never wins), a verified result without a trace.
        let shortTrace: [MoonlitMechanismAction] = Array(actions.dropLast())
        let shortTraceObject: Any = try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(shortTrace))
        let edits: [[String: Any]] = [
            try Self.editingFirstResult(saved, key: "stars", value: 2),
            try Self.editingFirstResult(saved, key: "actionsSpent", value: actions.count - 1),
            try Self.editingFirstResult(saved, key: "trace", value: shortTraceObject),
            try Self.editingFirstResult(saved, key: "trace", value: [Any]()),
        ]
        for edit in edits {
            let restored: Core = try Core.restore(payload: try Self.data(edit), seed: Self.seed)
            #expect(restored.progress.solved[Self.level] == nil)
            #expect(restored.reconciliationDropped == 1)
            #expect(restored.progress.frontier == won.progress.frontier && restored.progress.isOpen(Self.level + 1))
            #expect(restored.levelNumber == won.levelNumber && restored.play == won.play)
            // The dropped result is gone from the state, so the restored state differs from the saved one.
            #expect(restored != won)
            #expect(try Self.digest(restored) != Self.digest(won))
        }
    }

    // MARK: Replay rules

    @Test func replayNeedsAVerifiedTracedResultAndOnlyReplayControlsWorkInIt() async throws {
        // Without a verified traced result, and outside replay.
        var fresh: Core = try await Core.prepare(seed: Self.seed)
        let freshBefore: Core = fresh
        let noReplay: ActionResult = .rejected(.rule(code: MoonlitMechanismExperienceRule.noReplay))
        #expect(fresh.apply(Self.act("replay.start", [Double(Self.level)])) == noReplay)
        #expect(fresh.apply(Self.act("replay.step")) == noReplay)
        #expect(fresh.apply(Self.act("replay.stop")) == noReplay)
        #expect(fresh == freshBefore)
        var won: Core = try await Self.wonCore()
        #expect(won.apply(Self.act("replay.step")) == noReplay)
        #expect(won.apply(Self.act("replay.stop")) == noReplay)
        #expect(won.apply(Self.act("replay.start", [1])) == noReplay)
        // replay.start: a fresh play of the level, tutorial done, campaign budget.
        let progress: MoonlitMechanismProgress = won.progress
        let trace: [MoonlitMechanismAction] = try #require(progress.solved[Self.level]?.trace)
        #expect(trace == (try Self.witness(Self.level)))
        var core: Core = won
        #expect(core.apply(Self.act("replay.start", [Double(Self.level)])) == .accepted)
        #expect(core.mode == .replay(level: Self.level) && core.levelNumber == Self.level)
        #expect(core.play.records.isEmpty && core.play.stage == .playing && core.tutorial == .done)
        #expect(core.play.level == (try Core.level(number: Self.level)))
        // Every other play control is refused with r02-g14.replay and changes nothing.
        let refused: [ExperienceAction] = [
            Self.act("handle.turn", [1]), Self.act("gear.reseat", [1, 1]), Self.act("lamp.step", [1]),
            Self.act("machine.run"), Self.act("play.undo"), Self.act("play.redo"), Self.act("level.next"),
            Self.act("level.select", [1]), Self.act("mode.daily", [2026, 1, 1]), Self.act("mode.practice"),
            Self.act("mode.campaign"),
        ]
        let inReplay: Core = core
        let replayDigest: StateDigest = try Self.digest(core)
        for action in refused {
            #expect(core.apply(action) == .rejected(.rule(code: MoonlitMechanismExperienceRule.replay)),
                    "\(action.control)")
            #expect(core == inReplay && core.shownFrame == inReplay.shownFrame)
        }
        #expect(try Self.digest(core) == replayDigest)
        // tutorial.dismiss, frame.show and settings.sound stay allowed.
        #expect(core.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(core.apply(Self.act("frame.show", [1])) == .accepted && core.shownFrame == 1)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        #expect(core.apply(Self.act("frame.show", [0])) == .accepted)
        #expect(core.play == inReplay.play && core.mode == inReplay.mode)
        // replay.step through the whole trace to a win; no stars recorded, progress unchanged.
        for index in 0..<trace.count {
            #expect(core.apply(Self.act("replay.step")) == .accepted)
            #expect(core.play.records.count == index + 1 && core.play.records[index].action == trace[index])
            #expect(core.progress == progress)
        }
        #expect(core.play.stage == .won && core.outcome == ExperienceOutcome(code: Core.wonCode))
        #expect(core.progress == progress && core.progress.frontier == progress.frontier)
        // After the last action: r02-g14.replay-end, nothing changes.
        let ended: Core = core
        #expect(core.apply(Self.act("replay.step")) == .rejected(.rule(code: MoonlitMechanismExperienceRule.replayEnd)))
        #expect(core == ended)
        // replay.stop: campaign at that level (open), fresh.
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == Self.level && core.play.records.isEmpty)
        #expect(core.progress == progress && core.soundOn)
    }

    @Test func replayStopOfALevelThatIsNotOpenGoesToTheFrontier() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let (date, daily): ([Double], Int) = try #require(Self.closedDaily(beyond: core.progress.frontier))
        #expect(core.apply(Self.act("mode.daily", date)) == .accepted)
        for step in try Self.witness(daily) { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && !core.progress.isOpen(daily))
        #expect(core.progress.solved[daily]?.verified == true)
        #expect(core.apply(Self.act("replay.start", [Double(daily)])) == .accepted)
        #expect(core.mode == .replay(level: daily) && core.levelNumber == daily && core.tutorial == .done)
        #expect(core.apply(Self.act("replay.step")) == .accepted)
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == core.progress.frontier && core.play.records.isEmpty)
    }

    // MARK: Saved replays

    @Test func aReplaySavedMidwayRestoresAndAnAlteredOneIsDamaged() async throws {
        let won: Core = try await Self.wonCore()
        let trace: [MoonlitMechanismAction] = try Self.witness(Self.level)
        try #require(trace.count >= 3 && trace[0] != trace[1])
        var core: Core = won
        #expect(core.apply(Self.act("replay.start", [Double(Self.level)])) == .accepted)
        #expect(core.apply(Self.act("replay.step")) == .accepted)
        #expect(core.apply(Self.act("replay.step")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        let restored: Core = try Core.restore(payload: payload, seed: Self.seed)
        #expect(restored == core && restored.mode == .replay(level: Self.level))
        #expect(try Self.digest(restored) == Self.digest(core) && restored.reconciliationDropped == 0)
        // The restored replay continues to the win.
        var finishing: Core = restored
        for _ in 2..<trace.count { #expect(finishing.apply(Self.act("replay.step")) == .accepted) }
        #expect(finishing.play.stage == .won && finishing.progress == won.progress)
        let saved: [String: Any] = try Self.object(payload)
        // Changed: a first record whose action is not the trace's first.
        var other: Core = won
        #expect(other.apply(Self.act("level.select", [Double(Self.level)])) == .accepted)
        let candidates: [MoonlitMechanismAction] = [.turn(1), .turn(-1), .lamp(1), .lamp(-1)]
        var changedRecords: [MoonlitMechanismRecord] = []
        for candidate in candidates where candidate != trace[0] {
            var attempt: Core = other
            if attempt.apply(Self.act(candidate)) == .accepted {
                changedRecords = attempt.play.records
                break
            }
        }
        try #require(changedRecords.count == 1)
        // Reordered: the first two records swapped.
        var reordered: [MoonlitMechanismRecord] = core.play.records
        reordered.swapAt(0, 1)
        // Undo-carrying: the trace's first action, then an undo.
        var undoing: Core = other
        #expect(undoing.apply(Self.act(trace[0])) == .accepted)
        #expect(undoing.apply(Self.act("play.undo")) == .accepted)
        let undoRecords: [MoonlitMechanismRecord] = undoing.play.records
        #expect(undoRecords.count == 2)
        let alterations: [[MoonlitMechanismRecord]] = [changedRecords, reordered, undoRecords]
        for records in alterations {
            let altered: Data = try Self.data(try Self.replacingRecords(saved, with: records))
            #expect(altered != payload)
            #expect(throws: MoonlitMechanismRestoreRefusal.damaged) {
                try Core.restore(payload: altered, seed: Self.seed)
            }
        }
        // A replay mode naming another level than the saved one is damaged too.
        var otherLevel: [String: Any] = saved
        otherLevel["mode"] = ["mode": "replay", "level": Self.level + 1]
        #expect(throws: MoonlitMechanismRestoreRefusal.damaged) {
            try Core.restore(payload: try Self.data(otherLevel), seed: Self.seed)
        }
    }

    @Test func aReplayWhoseResultDoesNotReconcileReturnsToCampaign() async throws {
        // An open level: back to campaign at that level.
        let won: Core = try await Self.wonCore()
        var core: Core = won
        #expect(core.apply(Self.act("replay.start", [Double(Self.level)])) == .accepted)
        #expect(core.apply(Self.act("replay.step")) == .accepted)
        let edited: [String: Any] = try Self.editingFirstResult(try Self.object(try core.snapshotPayload()),
                                                                key: "stars", value: 2)
        let restored: Core = try Core.restore(payload: try Self.data(edited), seed: Self.seed)
        #expect(restored.mode == .campaign && restored.levelNumber == Self.level && restored.play.records.isEmpty)
        #expect(restored.reconciliationDropped == 1 && restored.progress.solved[Self.level] == nil)
        #expect(restored.progress.frontier == won.progress.frontier)
        // A level that is not open: back to campaign at the frontier.
        var daily: Core = try await Core.prepare(seed: Self.seed)
        let (date, dailyLevel): ([Double], Int) = try #require(Self.closedDaily(beyond: daily.progress.frontier))
        #expect(daily.apply(Self.act("mode.daily", date)) == .accepted)
        for step in try Self.witness(dailyLevel) { #expect(daily.apply(Self.act(step)) == .accepted) }
        #expect(daily.apply(Self.act("replay.start", [Double(dailyLevel)])) == .accepted)
        #expect(daily.apply(Self.act("replay.step")) == .accepted)
        let dailyEdited: [String: Any] = try Self.editingFirstResult(try Self.object(try daily.snapshotPayload()),
                                                                     key: "stars", value: 2)
        let dailyRestored: Core = try Core.restore(payload: try Self.data(dailyEdited), seed: Self.seed)
        #expect(dailyRestored.mode == .campaign && dailyRestored.levelNumber == daily.progress.frontier)
        #expect(dailyRestored.reconciliationDropped == 1 && dailyRestored.progress.solved[dailyLevel] == nil)
        #expect(dailyRestored.play.records.isEmpty)
    }

    // MARK: Sound

    @Test func settingsSoundTogglesIsSavedAndNeverDigested() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.soundOn == false)
        let off: Core = core
        let digest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted)
        #expect(core.soundOn && core != off && core.play == off.play && core.progress == off.progress)
        #expect(try Self.digest(core) == digest)
        let payload: Data = try core.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).contains("\"sound\":true"))
        let restored: Core = try Core.restore(payload: payload, seed: Self.seed)
        #expect(restored.soundOn && restored == core)
        #expect(try Self.digest(restored) == digest)
        // Refusals change nothing: a value that is not whole, a value outside 0 … 1, a missing value.
        let on: Core = core
        #expect(core.apply(Self.act("settings.sound", [0.5])) == .rejected(.rule(code: "r02-g14.not-whole")))
        #expect(core.apply(Self.act("settings.sound", [2])) != .accepted)
        #expect(core.apply(Self.act("settings.sound")) != .accepted)
        #expect(core == on && core.soundOn)
        // Off again; the digest never moved.
        #expect(core.apply(Self.act("settings.sound", [0])) == .accepted)
        #expect(!core.soundOn && core == off)
        #expect(try Self.digest(core) == digest)
        #expect(String(decoding: try core.snapshotPayload(), as: UTF8.self).contains("\"sound\":false"))
        // Allowed in every mode (practice here; replay is covered above) and turned off by a reset.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        core.reset()
        #expect(!core.soundOn && core == off)
    }
}
