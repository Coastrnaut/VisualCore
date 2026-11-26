// MicroscopicAuroraReplayCatalogTests — feature 487 (R02-G19-07) T-R02G1907-005 (FR-R02G1907-004, 006;
// SC-R02G1907-004; clarifications Q1, Q4), modelled on feature 477's ApsidesWorkshopReplayCatalogTests. Every stored
// trace of the 100 certified levels replays through the adapter: each level is opened by preparing its seed (the
// opening opens every level up to it) and won in campaign with its certified placements and removals and the play (a
// verified result whose trace is those actions and the play, equal to the witness's actions), then
// `replay.start [level]` opens a fresh play with the tutorial done (its fingerprint the witness file's fingerprint
// before the first action) and `replay.step` runs to the end, each step's play fingerprint equal to the witness file's
// recorded fingerprint after that action (`docs/games/microscopic-aurora/levels/NNN.witness.json`, read with the plain
// decoder as MicroscopicAuroraProgressTests reads it: the fingerprints after begin, after the dismissed tutorial on a
// tutorial level, then one per action); the replay ends won, one more step is refused `r02-g19.replay-end`, the
// progress never changes, and `replay.stop` returns to campaign at that level. A fresh play holds its begin (and
// dismissTutorial) records, so the replay's start is checked as a fresh play, not as empty records. The witness files
// must be present: a missing directory fails, never passes silently. Ten groups of ten levels, each well under the
// 10 s rule. Also the replay refusals (`r02-g19.no-replay` without a verified traced result or outside a replay,
// `r02-g19.replay` for every other play action during a replay while presentation and the sound setting stay
// accepted, `r02-g19.replay-end`), `replay.stop` at a locked daily level returning to the frontier, and the
// saved-replay rule: a replay saved after any number of steps restores to an equal state and digest and continues to
// the win, while a saved replay whose action records are changed, reordered or carry an undo is refused `damaged`.
// Explicit types, plain loops, no wall-clock asserts.
import Foundation
import Testing
@testable import MicroscopicAuroraCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct MicroscopicAuroraReplayCatalogTests {
    typealias Core = MicroscopicAuroraExperienceCore
    typealias Action = MicroscopicAuroraAction
    typealias Record = MicroscopicAuroraRecord
    typealias Rule = MicroscopicAuroraExperienceRule

    /// The repository's witness directory, found from this file (five levels up: CoreTests, MicroscopicAurora, the
    /// package, Packages).
    private static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/microscopic-aurora/levels", isDirectory: true)

    /// The first level of each group of ten, 1, 11, … 91.
    static let groups: [Int] = [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]

    /// The `r02-g19.replay-end` refusal.
    private static let replayEnd: ActionResult = .rejected(.rule(code: Rule.replayEnd))

    /// The `r02-g19.no-replay` refusal.
    private static let noReplay: ActionResult = .rejected(.rule(code: Rule.noReplay))

    /// The `r02-g19.replay` refusal.
    private static let inReplay: ActionResult = .rejected(.rule(code: Rule.replay))

    /// An action of `control` with `values`.
    private static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    private static func act(_ action: Action) -> ExperienceAction {
        switch action {
        case let .place(slot, well):
            let sense: Double = well.sense == .clockwise ? 0 : 1
            return act("well.place", [Double(slot), Double(well.cell.row), Double(well.cell.column),
                                      Double(well.strength), sense])
        case let .remove(slot):
            return act("well.remove", [Double(slot)])
        case .play:
            return act("swim.play")
        }
    }

    /// The digest of `core` as the engine computes it.
    private static func digest(_ core: Core) throws -> StateDigest {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The file name of level `number`'s witness, `NNN.witness.json`.
    private static func witnessName(_ number: Int) -> String {
        String(MicroscopicAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
    }

    /// The stored witness of level `number`, read with the plain decoder.
    private static func witness(_ number: Int) throws -> MicroscopicAuroraWitness {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        return try JSONDecoder().decode(MicroscopicAuroraWitness.self, from: data)
    }

    /// The certified placements and removals of level `number`, then the play.
    private static func certifiedTrace(_ number: Int) throws -> [Action] {
        var actions: [Action] = try Core.generated(number: number).plan.actions
        actions.append(.play)
        return actions
    }

    /// The core prepared on level `number` (open, campaign) with the level won from its certified trace.
    private static func won(_ number: Int) async throws -> Core {
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        #expect(core.levelNumber == number && core.mode == .campaign, "level \(number)")
        #expect(core.progress.isOpen(number), "level \(number)")
        for action in try certifiedTrace(number) {
            #expect(core.apply(act(action)) == .accepted, "level \(number) \(action)")
        }
        #expect(core.play.stage == .won, "level \(number)")
        return core
    }

    /// Wins level `number` in campaign, replays its stored trace step by step against the recorded fingerprints and
    /// checks the replay ends won with the progress unchanged.
    private static func check(_ number: Int) async throws {
        var core: Core = try await won(number)
        let actions: [Action] = try certifiedTrace(number)
        let result: MicroscopicAuroraProgress.Result = try #require(core.progress.solved[number])
        #expect(result.verified && result.trace == actions, "level \(number)")
        let stored: MicroscopicAuroraWitness = try witness(number)
        #expect(stored.number == number && stored.actions == result.trace, "level \(number)")
        try #require(stored.fingerprints.count > result.trace.count)
        let recorded: [String] = Array(stored.fingerprints.suffix(result.trace.count))
        let opening: String = stored.fingerprints[stored.fingerprints.count - result.trace.count - 1]
        let progress: MicroscopicAuroraProgress = core.progress
        #expect(core.apply(act("replay.start", [Double(number)])) == .accepted, "level \(number)")
        #expect(core.mode == .replay(level: number) && core.tutorial == .done, "level \(number)")
        let fresh: MicroscopicAuroraPlay = try Core.freshPlay(of: try Core.level(number: number))
        #expect(core.play == fresh && core.play.fingerprint == opening, "level \(number)")
        #expect(core.progress == progress, "level \(number)")
        var index: Int = 0
        while index < result.trace.count {
            #expect(core.apply(act("replay.step")) == .accepted, "level \(number) step \(index)")
            #expect(core.play.fingerprint == recorded[index], "level \(number) step \(index)")
            #expect(core.progress == progress, "level \(number) step \(index)")
            index += 1
        }
        #expect(core.play.stage == .won, "level \(number)")
        #expect(core.apply(act("replay.step")) == replayEnd, "level \(number)")
        #expect(core.mode == .replay(level: number) && core.progress == progress, "level \(number)")
        #expect(core.apply(act("replay.stop")) == .accepted, "level \(number)")
        #expect(core.mode == .campaign && core.levelNumber == number && core.progress == progress, "level \(number)")
    }

    @Test("the 100 stored witness files are present (an isolated copy without them fails, never skips)")
    func witnessFilesArePresent() {
        var number: Int = 1
        var missing: [String] = []
        while number <= 100 {
            let path: String = Self.witnessDirectory.appendingPathComponent(Self.witnessName(number)).path
            if !FileManager.default.fileExists(atPath: path) { missing.append(Self.witnessName(number)) }
            number += 1
        }
        #expect(missing.isEmpty, "missing in \(Self.witnessDirectory.path): \(missing)")
    }

    @Test(arguments: groups)
    func storedTracesOfTenLevelsReplayToTheirRecordedFingerprints(first: Int) async throws {
        var number: Int = first
        while number <= first + 9 {
            try await Self.check(number)
            number += 1
        }
    }

    // MARK: Replay refusals

    @Test("no replay without a verified traced result or outside a replay")
    func noReplayRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let before: Core = core
        #expect(core.apply(Self.act("replay.start", [1])) == Self.noReplay && core == before)
        #expect(core.apply(Self.act("replay.step")) == Self.noReplay && core == before)
        #expect(core.apply(Self.act("replay.stop")) == Self.noReplay && core == before)
        // An untraced result (as a schema-2 save carries it) cannot be replayed.
        var won: Core = try await Self.won(1)
        var object: [String: Any] = try #require(try JSONSerialization.jsonObject(
            with: try won.snapshotPayload()) as? [String: Any])
        var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
        var solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
        try #require(solved.count == 1)
        solved[0]["trace"] = [Any]()
        solved[0]["verified"] = false
        progress["solved"] = solved
        object["progress"] = progress
        let untraced: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), seed: 0)
        #expect(untraced.progress.solved[1]?.verified == false && untraced.reconciliationDropped == 0)
        var tried: Core = untraced
        #expect(tried.apply(Self.act("replay.start", [1])) == Self.noReplay && tried == untraced)
        // The verified level replays; an unsolved level does not.
        #expect(won.apply(Self.act("replay.start", [2])) == Self.noReplay)
        #expect(won.apply(Self.act("replay.start", [1])) == .accepted && won.mode == .replay(level: 1))
    }

    @Test("during a replay every other play action is refused and presentation and sound stay accepted")
    func replayRefusesOtherActions() async throws {
        var core: Core = try await Self.won(41)
        #expect(core.apply(Self.act("replay.start", [41])) == .accepted)
        #expect(core.apply(Self.act("replay.step")) == .accepted)
        let before: Core = core
        let beforeDigest: StateDigest = try Self.digest(core)
        let trace: [Action] = try Self.certifiedTrace(41)
        let refused: [ExperienceAction] = [Self.act(trace[0]), Self.act("well.remove", [0]), Self.act("swim.play"),
                                           Self.act("play.undo"), Self.act("play.redo"), Self.act("level.next"),
                                           Self.act("level.select", [1]), Self.act("mode.daily", [2026, 1, 1]),
                                           Self.act("mode.practice"), Self.act("mode.campaign")]
        for action in refused {
            var copy: Core = core
            #expect(copy.apply(action) == Self.inReplay && copy == before, "\(action.control)")
        }
        #expect(core.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(core.apply(Self.act("clock.show", [0])) == .accepted)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        let afterDigest: StateDigest = try Self.digest(core)
        #expect(afterDigest == beforeDigest && core.play == before.play && core.progress == before.progress)
        // A restart from the middle begins the replay again.
        #expect(core.apply(Self.act("replay.start", [41])) == .accepted)
        let fresh: MicroscopicAuroraPlay = try Core.freshPlay(of: try Core.level(number: 41))
        #expect(core.play == fresh && core.mode == .replay(level: 41))
    }

    @Test("a replay of a locked daily level stops at the frontier")
    func replayStopAtLockedDailyLevel() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        // 2026-01-01 + d days has daily level (19 d) mod 100 + 1; d = 49 × 79 mod 100 = 71 gives level 50.
        let date: [Double] = [2026, 3, 13]
        #expect(MicroscopicAuroraProgress.dailyLevel(year: 2026, month: 3, day: 13) == 50)
        #expect(core.apply(Self.act("mode.daily", date)) == .accepted && core.levelNumber == 50)
        for action in try Self.certifiedTrace(50) { #expect(core.apply(Self.act(action)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.solved[50]?.verified == true)
        #expect(!core.progress.isOpen(50) && core.progress.frontier == 1)
        #expect(core.apply(Self.act("replay.start", [50])) == .accepted)
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1)
    }

    // MARK: Saved replays

    /// The payload of `core` with its records replaced by `records`.
    private static func payload(_ core: Core, records: [Record]) throws -> Data {
        var object: [String: Any] = try #require(try JSONSerialization.jsonObject(
            with: try core.snapshotPayload()) as? [String: Any])
        object["records"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(records))
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The positions of the place, remove and play records of `records`.
    private static func actionPositions(_ records: [Record]) -> [Int] {
        var positions: [Int] = []
        var index: Int = 0
        while index < records.count {
            let kind: MicroscopicAuroraRecordKind = records[index].kind
            if kind == .place || kind == .remove || kind == .play { positions.append(index) }
            index += 1
        }
        return positions
    }

    @Test("a replay saved after any step restores and continues; a changed, reordered or undo replay is damaged")
    func savedReplayPrefixRule() async throws {
        var core: Core = try await Self.won(41)
        let trace: [Action] = try Self.certifiedTrace(41)
        try #require(trace.count >= 3)
        #expect(core.apply(Self.act("replay.start", [41])) == .accepted)
        var steps: Int = 0
        while true {
            let payload: Data = try core.snapshotPayload()
            let restored: Core = try Core.restore(payload: payload, seed: 40)
            let restoredDigest: StateDigest = try Self.digest(restored)
            let digest: StateDigest = try Self.digest(core)
            #expect(restored == core && restoredDigest == digest, "after \(steps) steps")
            #expect(restored.mode == .replay(level: 41) && restored.reconciliationDropped == 0, "after \(steps)")
            // The restored replay continues to the win.
            var continued: Core = restored
            var left: Int = trace.count - steps
            while left > 0 {
                #expect(continued.apply(Self.act("replay.step")) == .accepted, "after \(steps) steps")
                left -= 1
            }
            #expect(continued.play.stage == .won && continued.apply(Self.act("replay.step")) == Self.replayEnd)
            if steps == trace.count { break }
            #expect(core.apply(Self.act("replay.step")) == .accepted)
            steps += 1
        }
        // The full replay's records: begin (and no tutorial on level 41), then the trace's actions.
        let records: [Record] = core.play.records
        let positions: [Int] = Self.actionPositions(records)
        try #require(positions.count == trace.count)
        // Changed: the first placement's well moved to another strength.
        guard case .place(let slot, let well) = trace[0] else {
            Issue.record("level 41's trace does not start with a placement")
            return
        }
        let other: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: well.cell, strength: well.strength == 1 ? 2 : 1,
                                                                 sense: well.sense)
        var changed: [Record] = records
        let first: Record = records[positions[0]]
        changed[positions[0]] = Record(schema: first.schema, seed: first.seed, index: first.index, kind: first.kind,
                                       action: .place(slot: slot, well: other), previous: first.previous,
                                       next: first.next)
        // Reordered: the first two actions swapped.
        var reordered: [Record] = records
        reordered[positions[0]] = records[positions[1]]
        reordered[positions[1]] = records[positions[0]]
        // Undo-carrying: an undo and a redo after the first action.
        var undone: [Record] = Array(records.prefix(positions[0] + 1))
        let undo: Record = Record(schema: first.schema, seed: first.seed, index: first.index + 1, kind: .undo,
                                  action: nil, previous: first.next, next: first.previous)
        let redo: Record = Record(schema: first.schema, seed: first.seed, index: first.index + 2, kind: .redo,
                                  action: nil, previous: first.previous, next: first.next)
        undone.append(undo)
        undone.append(redo)
        let variants: [(name: String, records: [Record])] = [("changed", changed), ("reordered", reordered),
                                                             ("undo", undone)]
        for variant in variants {
            let data: Data = try Self.payload(core, records: variant.records)
            #expect(throws: MicroscopicAuroraRestoreRefusal.damaged, "\(variant.name)") {
                _ = try Core.restore(payload: data, seed: 40)
            }
        }
        // A prefix longer than the trace (an extra play after the win) is damaged too.
        var longer: [Record] = records
        longer.append(records[positions[positions.count - 1]])
        let longerData: Data = try Self.payload(core, records: longer)
        #expect(throws: MicroscopicAuroraRestoreRefusal.damaged) {
            _ = try Core.restore(payload: longerData, seed: 40)
        }
    }
}
