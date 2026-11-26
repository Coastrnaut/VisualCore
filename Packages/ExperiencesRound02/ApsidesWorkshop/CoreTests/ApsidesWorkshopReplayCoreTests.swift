// ApsidesWorkshopReplayCoreTests — feature 477 (R02-G18-07) T-R02G1807-003 (FR-R02G1807-001 … 007;
// SC-R02G1807-001 … 004; clarifications Q1–Q5). Snapshot schema 3 and digest v3 of the adapter core: a campaign win
// stores its effective trace (the `.periapsis(k, d)` and `.size(a)` tunings, an undone tuning left out but counted in
// actions spent, then `.play`) as a verified result, practice stores nothing; the replay rules and codes
// (`r02-g18.no-replay`, `r02-g18.replay-end`, `r02-g18.replay`) and the allow-list (replay.*, tutorial.dismiss,
// clock.show, settings.sound); a replay reproducing the campaign fingerprints and recording nothing; `replay.stop`
// returning to campaign at that level, or the frontier when it is not open (a locked daily level); a replay saved
// mid-way restoring while a changed, reordered or undo-carrying replay is refused `damaged`; reconciliation on restore
// (an edited result dropped and counted in `reconciliationDropped`, a replay whose result was dropped or never verified
// returning to campaign); the migrations 2 → 3 and 1 → 3; and the sound setting (snapshotted, never digested, off after
// a reset and a migration). Modelled on feature 467's `CelestialEclipseLabReplayCoreTests`. Level 1's certified plan
// is the single tuning `.periapsis(0, 0)`; the replay saved mid-way uses the first level of a short list whose two
// certified tunings are also accepted in the other order. Levels are certified once per process, so the run stays
// short. Explicit types, plain loops, no `try` inside `#expect`.
@testable import ApsidesWorkshopCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct ApsidesWorkshopReplayCoreTests {
    typealias Core = ApsidesWorkshopExperienceCore

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
    static func act(_ action: ApsidesWorkshopAction) -> ExperienceAction {
        switch action {
        case let .periapsis(eccentricity, direction): act("orbit.periapsis", [Double(eccentricity), Double(direction)])
        case let .size(size): act("orbit.size", [Double(size)])
        case .play: act("orbit.play")
        }
    }

    /// The certified plan's tunings of level `number` (the play not included).
    static func plan(_ number: Int) throws -> [ApsidesWorkshopAction] {
        try Core.generated(number: number).plan.actions
    }

    /// The trace a win by the certified plan of level `number` stores: its tunings, then the play.
    static func trace(_ number: Int) throws -> [ApsidesWorkshopAction] {
        try plan(number) + [.play]
    }

    /// The refusal of rule code `code`.
    static func refusal(_ code: String) -> ActionResult { .rejected(.rule(code: code)) }

    /// The number of tuning and play records of `play` (a fresh play also holds its begin and tutorial records).
    static func actionRecords(_ play: ApsidesWorkshopPlay) -> Int {
        Core.actionRecordCount(play.records)
    }

    /// Level 1 won in campaign by its certified plan and the play, from seed 0.
    static func wonLevelOne() async throws -> Core {
        var core: Core = try await Core.prepare(seed: 0)
        for step in try trace(1) { #expect(core.apply(act(step)) == .accepted) }
        #expect(core.play.stage == .won)
        return core
    }

    /// The opening of level `number` (campaign, levels 1 … `number` open) won by its certified plan and the play.
    static func won(number: Int) throws -> Core {
        var core: Core = try Core.opening(number: number)
        for step in try trace(number) { #expect(core.apply(act(step)) == .accepted) }
        #expect(core.play.stage == .won)
        return core
    }

    /// A size tuning from `core`'s current orbit that the kernel accepts, leaves the play playing and differs from
    /// `other`.
    static func otherTuning(from core: Core, than other: ApsidesWorkshopAction) -> ApsidesWorkshopAction? {
        for size in ApsidesWorkshopOrbit.sizes {
            let change: ApsidesWorkshopAction = .size(size)
            guard change != other else { continue }
            var trial: Core = core
            guard trial.apply(act(change)) == .accepted, trial.play.stage == .playing else { continue }
            return change
        }
        return nil
    }

    /// The first level of a short list of two-tuning levels (55, 62, 64, 66, 50, 53, by their stored witnesses) whose
    /// certified plan has at least two tunings and whose first two tunings are also accepted in the other order from
    /// the opening; nil when none is.
    static func twoTuningLevel() throws -> Int? {
        let candidates: [Int] = [55, 62, 64, 66, 50, 53]
        for number in candidates {
            let tunings: [ApsidesWorkshopAction] = try plan(number)
            guard tunings.count >= 2 else { continue }
            var trial: Core = try Core.opening(number: number)
            guard trial.apply(act(tunings[1])) == .accepted, trial.play.stage == .playing else { continue }
            guard trial.apply(act(tunings[0])) == .accepted, trial.play.stage == .playing else { continue }
            return number
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
        let result: ApsidesWorkshopProgress.Result = try #require(won.progress.solved[1])
        let certified: [ApsidesWorkshopAction] = try Self.trace(1)
        #expect(certified == [.periapsis(0, 0), .play])
        #expect(result.verified && result.trace == certified)
        #expect(result.trace.last == .play && won.progress.frontier == 2)
        #expect(won.winningTrace == certified)
        // An undone probe tuning is left out of the trace (but spent: actions spent count it).
        var core: Core = try await Core.prepare(seed: 0)
        let plan: [ApsidesWorkshopAction] = try Self.plan(1)
        try #require(!plan.isEmpty)
        let probe: ApsidesWorkshopAction = try #require(Self.otherTuning(from: core, than: plan[0]))
        #expect(core.apply(Self.act(probe)) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in certified { #expect(core.apply(Self.act(step)) == .accepted) }
        let undone: ApsidesWorkshopProgress.Result = try #require(core.progress.solved[1])
        #expect(undone.trace == certified && undone.verified && undone.actionsSpent == plan.count + 1)
        #expect(!undone.trace.contains(probe))
        // A tuning undone and redone stays in the trace: it is effective again.
        var redone: Core = try await Core.prepare(seed: 0)
        #expect(redone.apply(Self.act(plan[0])) == .accepted)
        #expect(redone.apply(Self.act("play.undo")) == .accepted)
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(redone.apply(Self.act("orbit.play")) == .accepted && redone.play.stage == .won)
        #expect(redone.progress.solved[1]?.trace == certified && redone.progress.solved[1]?.verified == true)
        // Practice stores nothing.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        for step in certified { #expect(practice.apply(Self.act(step)) == .accepted) }
        #expect(practice.play.stage == .won && practice.progress.solved.isEmpty)
    }

    @Test func aReplayReproducesTheCampaignAndRecordsNothing() async throws {
        let won: Core = try await Self.wonLevelOne()
        let trace: [ApsidesWorkshopAction] = try Self.trace(1)
        // The campaign fingerprints after each action.
        var campaign: Core = try await Core.prepare(seed: 0)
        var fingerprints: [String] = []
        for step in trace {
            #expect(campaign.apply(Self.act(step)) == .accepted)
            fingerprints.append(campaign.play.fingerprint)
        }
        let fresh: ApsidesWorkshopPlay = try Core.freshPlay(of: try Core.level(number: 1))
        var replay: Core = won
        #expect(replay.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(replay.mode == .replay(level: 1) && replay.tutorial == .done && replay.levelNumber == 1)
        #expect(replay.play == fresh && Self.actionRecords(replay.play) == 0 && replay.shownTick == 0)
        for index in 0..<trace.count {
            #expect(replay.apply(Self.act("replay.step")) == .accepted)
            #expect(replay.play.fingerprint == fingerprints[index], "step \(index)")
            #expect(replay.progress == won.progress, "step \(index)")
        }
        #expect(replay.play.stage == .won && replay.progress == won.progress)
        #expect(replay.apply(Self.act("replay.step")) == Self.refusal(ApsidesWorkshopExperienceRule.replayEnd))
        // replay.start during a replay restarts it.
        #expect(replay.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(replay.play == fresh && replay.mode == .replay(level: 1))
        #expect(replay.apply(Self.act("replay.stop")) == .accepted)
        #expect(replay.mode == .campaign && replay.levelNumber == 1 && replay.progress == won.progress)
        #expect(replay.play == fresh && replay.tutorial == ApsidesWorkshopTutorialStep.initial(level: 1))
        // A replay of the two-tuning level reproduces its campaign too, step by step.
        let number: Int = try #require(try Self.twoTuningLevel())
        let longer: [ApsidesWorkshopAction] = try Self.trace(number)
        let wonLonger: Core = try Self.won(number: number)
        var longerCampaign: Core = try Core.opening(number: number)
        var longerReplay: Core = wonLonger
        #expect(longerReplay.apply(Self.act("replay.start", [Double(number)])) == .accepted)
        for index in 0..<longer.count {
            #expect(longerCampaign.apply(Self.act(longer[index])) == .accepted)
            #expect(longerReplay.apply(Self.act("replay.step")) == .accepted)
            #expect(longerReplay.play.fingerprint == longerCampaign.play.fingerprint, "step \(index)")
        }
        #expect(longerReplay.play.stage == .won && longerReplay.progress == wonLonger.progress)
    }

    @Test func theReplayRulesAndCodes() async throws {
        #expect(ApsidesWorkshopExperienceRule.noReplay == "r02-g18.no-replay")
        #expect(ApsidesWorkshopExperienceRule.replayEnd == "r02-g18.replay-end")
        #expect(ApsidesWorkshopExperienceRule.replay == "r02-g18.replay")
        let fresh: Core = try await Core.prepare(seed: 0)
        let noReplay: ActionResult = Self.refusal(ApsidesWorkshopExperienceRule.noReplay)
        var none: Core = fresh
        #expect(none.apply(Self.act("replay.start", [1])) == noReplay)
        #expect(none.apply(Self.act("replay.step")) == noReplay)
        #expect(none.apply(Self.act("replay.stop")) == noReplay)
        #expect(none.apply(Self.act("replay.start", [1.5])) == Self.refusal(ApsidesWorkshopExperienceRule.notWhole))
        #expect(none == fresh)
        let won: Core = try await Self.wonLevelOne()
        var replay: Core = won
        #expect(replay.apply(Self.act("replay.start", [2])) == noReplay)
        #expect(replay.apply(Self.act("replay.start", [1])) == .accepted)
        let inReplay: Core = replay
        let refused: ActionResult = Self.refusal(ApsidesWorkshopExperienceRule.replay)
        let plan: [ApsidesWorkshopAction] = try Self.plan(1)
        try #require(!plan.isEmpty)
        let blocked: [ExperienceAction] = [Self.act(plan[0]), Self.act("orbit.size", [17]), Self.act("orbit.play"),
                                           Self.act("play.undo"), Self.act("play.redo"), Self.act("level.next"),
                                           Self.act("level.select", [1]), Self.act("mode.daily", [2026, 1, 1]),
                                           Self.act("mode.practice"), Self.act("mode.campaign")]
        for action in blocked {
            #expect(replay.apply(action) == refused, "\(action.control)")
            #expect(replay == inReplay && replay.play == inReplay.play)
        }
        // The engine's checks come first: a wrong value count is refused as such even in replay.
        #expect(replay.apply(Self.act("replay.step", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(replay.apply(Self.act("orbit.play", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(replay == inReplay)
        // Presentation, the tutorial and the sound stay allowed.
        #expect(replay.apply(Self.act("clock.show", [3])) == .accepted && replay.shownTick == 3)
        #expect(replay.apply(Self.act("clock.show", [24])) == Self.refusal(ApsidesWorkshopExperienceRule.tick))
        #expect(replay.apply(Self.act("tutorial.dismiss")) == .accepted && replay.tutorial == .done)
        #expect(replay.apply(Self.act("settings.sound", [1])) == .accepted && replay.soundOn)
        let allowed: Set<String> = ["replay.start", "replay.step", "replay.stop", "tutorial.dismiss", "clock.show",
                                    "settings.sound"]
        #expect(Core.replayControls == allowed)
        // A replayed win claims no stars and records nothing.
        var steps: Int = 0
        while replay.play.stage == .playing && steps < 64 {
            #expect(replay.apply(Self.act("replay.step")) == .accepted)
            steps += 1
        }
        #expect(replay.play.stage == .won && replay.progress == won.progress && steps == plan.count + 1)
        #expect(replay.outcome?.code == Core.wonCode)
        let words: String = ApsidesWorkshopFeedbackPlan.outcomePlan(replay).text ?? ""
        #expect(!words.contains("stars") && words.hasPrefix(ApsidesWorkshopFeedbackPlan.wonText))
        let campaignWords: String = ApsidesWorkshopFeedbackPlan.outcomePlan(won).text ?? ""
        #expect(campaignWords.contains("3 of 3 stars"))
        #expect(ApsidesWorkshopFeedbackPlan.refusalText(code: ApsidesWorkshopExperienceRule.noReplay)
                    == "There is no saved solution to replay for this level.")
        #expect(ApsidesWorkshopFeedbackPlan.refusalText(code: ApsidesWorkshopExperienceRule.replayEnd)
                    == "The replay is over.")
        let replayCode: String = ApsidesWorkshopFeedbackPlan.rulePrefix + ApsidesWorkshopExperienceRule.replay
        #expect(ApsidesWorkshopFeedbackPlan.refusalText(code: replayCode) == "Stop the replay first.")
    }

    @Test func replayStopReturnsToCampaignOrTheFrontier() async throws {
        // Level 1, open: replay.stop returns to campaign at level 1, fresh, progress unchanged.
        let won: Core = try await Self.wonLevelOne()
        var open: Core = won
        #expect(open.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(open.apply(Self.act("replay.step")) == .accepted)
        #expect(open.apply(Self.act("replay.stop")) == .accepted)
        #expect(open.mode == .campaign && open.levelNumber == 1 && Self.actionRecords(open.play) == 0)
        #expect(open.progress == won.progress && open.play.stage == .playing)
        #expect(open.apply(Self.act("replay.stop")) == Self.refusal(ApsidesWorkshopExperienceRule.noReplay))
        // A locked daily level won in daily mode has a verified result: its replay stops at the frontier.
        var daily: Core = try await Core.prepare(seed: 0)
        let level: Int = try #require(ApsidesWorkshopProgress.dailyLevel(year: 2026, month: 11, day: 18))
        #expect(!daily.progress.isOpen(level))
        #expect(daily.apply(Self.act("mode.daily", [2026, 11, 18])) == .accepted)
        for step in try Self.trace(level) { #expect(daily.apply(Self.act(step)) == .accepted) }
        #expect(daily.play.stage == .won && daily.progress.frontier == 1)
        let result: ApsidesWorkshopProgress.Result = try #require(daily.progress.solved[level])
        let dailyTrace: [ApsidesWorkshopAction] = try Self.trace(level)
        #expect(result.verified && result.trace == dailyTrace)
        #expect(daily.apply(Self.act("replay.start", [Double(level)])) == .accepted)
        #expect(daily.mode == .replay(level: level) && daily.levelNumber == level && daily.tutorial == .done)
        #expect(daily.apply(Self.act("replay.step")) == .accepted)
        // Saved here with the result's stars edited: the result is dropped and the replay returns to the frontier.
        let payload: Data = try daily.snapshotPayload()
        let stars: Int = result.stars
        let edited: [String: Any] = try Self.editingFirstResult(try Self.object(payload), key: "stars",
                                                                value: stars == 1 ? 2 : 1)
        let dropped: Core = try Core.restore(payload: try Self.data(edited), seed: 0)
        #expect(dropped.mode == .campaign && dropped.levelNumber == 1 && dropped.progress.solved[level] == nil)
        #expect(dropped.reconciliationDropped == 1 && Self.actionRecords(dropped.play) == 0)
        #expect(daily.apply(Self.act("replay.stop")) == .accepted)
        #expect(daily.mode == .campaign && daily.levelNumber == 1 && daily.progress.frontier == 1)
        #expect(Self.actionRecords(daily.play) == 0 && daily.progress.solved[level] == result)
    }

    @Test func aReplaySavedMidwayRestoresAndAChangedOneIsDamaged() async throws {
        let number: Int = try #require(try Self.twoTuningLevel())
        let plan: [ApsidesWorkshopAction] = try Self.plan(number)
        try #require(plan.count >= 2)
        let seed: UInt64 = UInt64(number - 1)
        let won: Core = try Self.won(number: number)
        var replay: Core = won
        #expect(replay.apply(Self.act("replay.start", [Double(number)])) == .accepted)
        #expect(replay.apply(Self.act("replay.step")) == .accepted)
        let payload: Data = try replay.snapshotPayload()
        let restored: Core = try Core.restore(payload: payload, seed: seed)
        #expect(restored == replay && restored.reconciliationDropped == 0)
        #expect(restored.mode == .replay(level: number) && Self.actionRecords(restored.play) == 1)
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
        #expect(continued.play.stage == .won && steps == plan.count && continued.progress == won.progress)
        // Records of a campaign play that undid and redid the first tuning: tuning and play records only are allowed.
        var undoing: Core = try Core.opening(number: number)
        #expect(undoing.apply(Self.act(plan[0])) == .accepted)
        #expect(undoing.apply(Self.act("play.undo")) == .accepted)
        #expect(undoing.apply(Self.act("play.redo")) == .accepted)
        // Records of a campaign play whose first tuning is not the trace's.
        var other: Core = try Core.opening(number: number)
        let stray: ApsidesWorkshopAction = try #require(Self.otherTuning(from: other, than: plan[0]))
        #expect(other.apply(Self.act(stray)) == .accepted)
        // Records of a campaign play that applied the trace's first two tunings in the other order.
        var reordered: Core = try Core.opening(number: number)
        #expect(reordered.apply(Self.act(plan[1])) == .accepted)
        #expect(reordered.apply(Self.act(plan[0])) == .accepted)
        let damaged: [[ApsidesWorkshopRecord]] = [undoing.play.records, other.play.records, reordered.play.records]
        for records in damaged {
            var edited: [String: Any] = try Self.object(payload)
            edited["records"] = try Self.json(records)
            let editedData: Data = try Self.data(edited)
            #expect(throws: ApsidesWorkshopRestoreRefusal.damaged) {
                try Core.restore(payload: editedData, seed: seed)
            }
        }
        // The same records in campaign mode are a legal play: only the replay rule refuses them.
        for records in damaged {
            var campaign: [String: Any] = try Self.object(payload)
            campaign["records"] = try Self.json(records)
            campaign["mode"] = try Self.json(ApsidesWorkshopMode.campaign)
            let campaignCore: Core = try Core.restore(payload: try Self.data(campaign), seed: seed)
            #expect(campaignCore.mode == .campaign && campaignCore.play.records == records)
        }
        // A replay whose result is not verified returns to campaign at that level.
        let unverifiedTrace: [String: Any] = try Self.editingFirstResult(try Self.object(payload), key: "trace",
                                                                         value: [Any]())
        let unverified: [String: Any] = try Self.editingFirstResult(unverifiedTrace, key: "verified", value: false)
        let back: Core = try Core.restore(payload: try Self.data(unverified), seed: seed)
        #expect(back.mode == .campaign && back.levelNumber == number)
        #expect(back.progress.solved[number]?.verified == false)
        #expect(back.reconciliationDropped == 0 && Self.actionRecords(back.play) == 0)
        // A replay whose result is dropped by reconciliation returns to campaign at that level (still open).
        let stars: Int = try #require(won.progress.solved[number]?.stars)
        let edited: [String: Any] = try Self.editingFirstResult(try Self.object(payload), key: "stars",
                                                                value: stars == 1 ? 2 : 1)
        let dropped: Core = try Core.restore(payload: try Self.data(edited), seed: seed)
        #expect(dropped.mode == .campaign && dropped.levelNumber == number)
        #expect(dropped.progress.solved[number] == nil && dropped.progress.isOpen(number))
        #expect(dropped.reconciliationDropped == 1 && Self.actionRecords(dropped.play) == 0)
    }

    @Test func restoreReconcilesTheSavedResults() async throws {
        let won: Core = try await Self.wonLevelOne()
        let payload: Data = try won.snapshotPayload()
        let honest: Core = try Core.restore(payload: payload, seed: 0)
        #expect(honest == won && honest.reconciliationDropped == 0)
        let saved: ApsidesWorkshopProgress.Result = try #require(won.progress.solved[1])
        #expect(ApsidesWorkshopReconciliation.verifies(level: 1, result: saved))
        // Edited stars, edited actions spent and a trace without its play are dropped and counted; the frontier stays.
        let stars: Int = try #require(won.progress.solved[1]?.stars)
        let noPlay: Any = try Self.json(try Self.plan(1))
        let edits: [(String, Any)] = [("stars", stars == 1 ? 2 : 1), ("actionsSpent", 0), ("trace", noPlay)]
        for (key, value) in edits {
            let edited: [String: Any] = try Self.editingFirstResult(try Self.object(payload), key: key, value: value)
            let restored: Core = try Core.restore(payload: try Self.data(edited), seed: 0)
            #expect(restored.reconciliationDropped == 1 && restored.progress.solved[1] == nil, "\(key)")
            #expect(restored.progress.frontier == won.progress.frontier)
            // The dropped count is not in ==: the restored state equals a won-and-dropped one.
            var droppedProgress: ApsidesWorkshopProgress = won.progress
            droppedProgress.drop(level: 1)
            #expect(restored.progress == droppedProgress)
            #expect(restored.levelNumber == won.levelNumber && restored.play == won.play)
        }
        // Two dropped results are counted as two: level 1 and the two-tuning level, both with edited stars.
        let number: Int = try #require(try Self.twoTuningLevel())
        var both: Core = try Self.won(number: number)
        #expect(both.apply(Self.act("level.select", [1])) == .accepted)
        for step in try Self.trace(1) { #expect(both.apply(Self.act(step)) == .accepted) }
        #expect(both.progress.solved.count == 2)
        var object: [String: Any] = try Self.object(try both.snapshotPayload())
        var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
        var solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
        for index in solved.indices {
            let saved: Int = try #require(solved[index]["stars"] as? Int)
            solved[index]["stars"] = saved == 1 ? 2 : 1
        }
        progress["solved"] = solved
        object["progress"] = progress
        let twice: Core = try Core.restore(payload: try Self.data(object), seed: UInt64(number - 1))
        #expect(twice.reconciliationDropped == 2 && twice.progress.solved.isEmpty)
        #expect(twice.progress.frontier == both.progress.frontier)
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
        let result: ApsidesWorkshopProgress.Result = try #require(restored.progress.solved[1])
        let spent: Int? = won.progress.solved[1]?.actionsSpent
        #expect(!result.verified && result.trace.isEmpty && result.actionsSpent == spent)
        #expect(result.stars == won.progress.solved[1]?.stars)
        #expect(restored.reconciliationDropped == 0 && !restored.soundOn && restored.progress.frontier == 2)
        var copy: Core = restored
        #expect(copy.apply(Self.act("replay.start", [1])) == Self.refusal(ApsidesWorkshopExperienceRule.noReplay))
        // An unverified result still opens its level: level 2 can be chosen.
        #expect(copy.apply(Self.act("level.select", [2])) == .accepted && copy.levelNumber == 2)
        #expect(throws: ApsidesWorkshopRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 1]) }
        // Schema 1 → 3: the fresh opening of level 3, no won levels, sound off.
        let opening: Core = try await Core.prepare(seed: 2)
        #expect(opening.levelNumber == 3)
        let records: Any = try Self.json(opening.play.records)
        let one: [String: Any] = try Core.migrations.migrate(["level": 3, "records": records], from: 1)
        #expect(one["sound"] as? Bool == false)
        let fromOne: Core = try Core.restore(payload: try Self.data(one), seed: 2)
        #expect(fromOne.progress.solved.isEmpty && fromOne.progress.frontier == 3 && !fromOne.soundOn)
        #expect(fromOne.play == opening.play && fromOne.reconciliationDropped == 0 && fromOne == opening)
    }

    @Test func theSoundSettingIsSavedButNotDigested() async throws {
        var core: Core = try await Core.prepare(seed: 2_477)
        #expect(core.levelNumber == 78 && !core.soundOn)
        let off: String = String(decoding: try core.snapshotPayload(), as: UTF8.self)
        #expect(off.contains("\"sound\":false"))
        let before: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        let after: StateDigest = try Self.digest(core)
        #expect(after == before)
        let text: String = String(decoding: try core.snapshotPayload(), as: UTF8.self)
        #expect(text.contains("\"sound\":true") && text != off)
        let restored: Core = try Core.restore(payload: Data(text.utf8), seed: 2_477)
        #expect(restored.soundOn && restored == core)
        let restoredDigest: StateDigest = try Self.digest(restored)
        #expect(restoredDigest == before)
        // The sound choice is in ==.
        var silent: Core = core
        #expect(silent.apply(Self.act("settings.sound", [0])) == .accepted && silent != core)
        let notWhole: ActionResult = Self.refusal(ApsidesWorkshopExperienceRule.notWhole)
        #expect(core.apply(Self.act("settings.sound", [0.5])) == notWhole && core.soundOn)
        #expect(core.apply(Self.act("settings.sound", [2])) == .rejected(.outOfRange(index: 0)) && core.soundOn)
        #expect(core.apply(Self.act("settings.sound", [-1])) == .rejected(.outOfRange(index: 0)) && core.soundOn)
        #expect(core.apply(Self.act("settings.sound", [0])) == .accepted && !core.soundOn)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted)
        // Changing levels and modes keeps the choice; a reset turns it off.
        #expect(core.apply(Self.act("mode.practice")) == .accepted && core.soundOn)
        core.reset()
        #expect(!core.soundOn)
        // A payload without the sound key (written before schema 3) restores with the sound off.
        let noSound: String = text.replacingOccurrences(of: ",\"sound\":true", with: "")
        #expect(noSound != text)
        let quiet: Core = try Core.restore(payload: Data(noSound.utf8), seed: 2_477)
        #expect(!quiet.soundOn)
    }
}
