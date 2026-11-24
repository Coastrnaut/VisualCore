// VoxelOrigamiReplayCatalogTests — feature 447 (R02-G15-07) T-R02G1507-013 (SC-R02G1507-004; convergence round 1).
// Every stored trace of the 100 certified levels replays through the adapter: each level is won in campaign with its
// certified turns (a verified result whose trace is those turns), then `replay.start [level]` and `replay.step` to the
// end, each step's play fingerprint equal to the witness file's recorded fingerprint after that action
// (`docs/games/voxel-origami/levels/NNN.witness.json`, its last fingerprints, one per action); the replay ends won,
// one more step is refused `r02-g15.replay-end`, and the progress never changes. Ten groups of ten levels, each well
// under the 10 s rule. Explicit types, plain loops, no wall-clock asserts.
import Foundation
import Testing
@testable import VoxelOrigamiCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct VoxelOrigamiReplayCatalogTests {
    typealias Core = VoxelOrigamiExperienceCore

    /// The repository's witness directory, found from this file (five levels up: CoreTests, VoxelOrigami, the package,
    /// Packages).
    private static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/voxel-origami/levels", isDirectory: true)

    /// The first level of each group of ten, 1, 11, … 91.
    static let groups: [Int] = [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]

    /// The `r02-g15.replay-end` refusal.
    private static let replayEnd: ActionResult = .rejected(.rule(code: VoxelOrigamiExperienceRule.replayEnd))

    /// An action of `control` with `values`.
    private static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    private static func act(_ action: VoxelOrigamiAction) -> ExperienceAction {
        switch action {
        case let .turn(hinge, step): act("hinge.turn", [Double(hinge), Double(step)])
        }
    }

    /// The recorded fingerprints after each action of level `number`'s witness file, and its action count.
    private static func recorded(_ number: Int) throws -> (fingerprints: [String], actions: Int) {
        let name: String = String(VoxelOrigamiGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        let object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let fingerprints: [String] = try #require(object["fingerprints"] as? [String])
        let actions: [Any] = try #require(object["actions"] as? [Any])
        try #require(fingerprints.count >= actions.count)
        return (Array(fingerprints.suffix(actions.count)), actions.count)
    }

    /// Wins level `number` in campaign, replays its stored trace step by step against the recorded fingerprints and
    /// checks the replay ends won with the progress unchanged.
    private static func check(_ number: Int) async throws {
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        #expect(core.levelNumber == number && core.mode == .campaign)
        let turns: [VoxelOrigamiAction] = try Core.generated(number: number).plan.turns
        for turn in turns { #expect(core.apply(act(turn)) == .accepted, "level \(number)") }
        #expect(core.play.stage == .won, "level \(number)")
        let result: VoxelOrigamiProgress.Result = try #require(core.progress.solved[number])
        #expect(result.verified && result.trace == turns, "level \(number)")
        let witness: (fingerprints: [String], actions: Int) = try recorded(number)
        #expect(witness.actions == result.trace.count, "level \(number)")
        let progress: VoxelOrigamiProgress = core.progress
        #expect(core.apply(act("replay.start", [Double(number)])) == .accepted, "level \(number)")
        #expect(core.mode == .replay(level: number) && core.play.records.isEmpty, "level \(number)")
        var index: Int = 0
        while index < result.trace.count {
            #expect(core.apply(act("replay.step")) == .accepted, "level \(number) step \(index)")
            #expect(core.play.fingerprint == witness.fingerprints[index], "level \(number) step \(index)")
            #expect(core.progress == progress, "level \(number) step \(index)")
            index += 1
        }
        #expect(core.play.stage == .won, "level \(number)")
        #expect(core.apply(act("replay.step")) == replayEnd, "level \(number)")
        #expect(core.progress == progress, "level \(number)")
    }

    @Test(arguments: groups)
    func storedTracesOfTenLevelsReplayToTheirRecordedFingerprints(first: Int) async throws {
        var number: Int = first
        while number <= first + 9 {
            try await Self.check(number)
            number += 1
        }
    }
}
