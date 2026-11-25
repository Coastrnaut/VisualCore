// StarlitCartoucheReplayCatalogTests — feature 457 (R02-G16-07) T-R02G1607-013 (SC-R02G1607-004), modelled on
// VoxelOrigamiReplayCatalogTests (feature 447). Every stored trace of the 100 certified levels replays through the
// adapter: each level is won in campaign with its certified legs (a verified result whose trace is those legs), then
// `replay.start [level]` and `replay.step` to the end, each step's play fingerprint equal to the witness file's recorded
// fingerprint after that leg (`docs/games/starlit-cartouche/levels/NNN.witness.json`, its last fingerprints, one per
// leg, after the opening and, for a tutorial level, the dismissed tutorial); the replay ends won, one more step is
// refused `r02-g16.replay-end`, and the progress never changes. The witness files must be present: a missing directory
// fails, never passes silently. Ten groups of ten levels, each well under the 10 s rule. Explicit types, plain loops,
// no wall-clock asserts.
import Foundation
import Testing
@testable import StarlitCartoucheCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct StarlitCartoucheReplayCatalogTests {
    typealias Core = StarlitCartoucheExperienceCore

    /// The repository's witness directory, found from this file (five levels up: CoreTests, StarlitCartouche, the
    /// package, Packages).
    private static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/starlit-cartouche/levels", isDirectory: true)

    /// The first level of each group of ten, 1, 11, … 91.
    static let groups: [Int] = [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]

    /// The `r02-g16.replay-end` refusal.
    private static let replayEnd: ActionResult = .rejected(.rule(code: StarlitCartoucheExperienceRule.replayEnd))

    /// An action of `control` with `values`.
    private static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    private static func act(_ action: StarlitCartoucheAction) -> ExperienceAction {
        switch action {
        case let .leg(star, wait): act("route.fly", [Double(star), Double(wait)])
        }
    }

    /// The file name of level `number`'s witness, `NNN.witness.json`.
    private static func witnessName(_ number: Int) -> String {
        String(StarlitCartoucheGenerator.levelID(number).suffix(3)) + ".witness.json"
    }

    /// The recorded fingerprints after each leg of level `number`'s witness file, and its leg count.
    private static func recorded(_ number: Int) throws -> (fingerprints: [String], actions: Int) {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
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
        #expect(core.levelNumber == number && core.mode == .campaign, "level \(number)")
        let legs: [StarlitCartoucheAction] = try Core.generated(number: number).plan.legs
        for leg in legs { #expect(core.apply(act(leg)) == .accepted, "level \(number)") }
        #expect(core.play.stage == .won, "level \(number)")
        let result: StarlitCartoucheProgress.Result = try #require(core.progress.solved[number])
        #expect(result.verified && result.trace == legs, "level \(number)")
        let witness: (fingerprints: [String], actions: Int) = try recorded(number)
        #expect(witness.actions == result.trace.count, "level \(number)")
        let progress: StarlitCartoucheProgress = core.progress
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
}
