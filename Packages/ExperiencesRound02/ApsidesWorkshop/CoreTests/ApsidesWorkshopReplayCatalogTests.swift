// ApsidesWorkshopReplayCatalogTests — feature 477 (R02-G18-07) T-R02G1807-005 (SC-R02G1807-004; clarifications Q1,
// Q4), modelled on feature 467's CelestialEclipseLabReplayCatalogTests. Every stored trace of the 100 certified levels
// replays through the adapter: each level is opened by preparing its seed (the opening opens every level up to it) and
// won in campaign with its certified tunings and the play (a verified result whose trace is those tunings and the play,
// equal to the witness's actions), then `replay.start [level]` opens a fresh play with the tutorial done (its
// fingerprint the witness file's fingerprint before the first action) and `replay.step` runs to the end, each step's
// play fingerprint equal to the witness file's recorded fingerprint after that action
// (`docs/games/apsides-workshop/levels/NNN.witness.json`, read with the plain decoder as ApsidesWorkshopCatalogTests
// reads it: the fingerprints after begin, after the dismissed tutorial on a tutorial level, then one per action); the
// replay ends won, one more step is refused `r02-g18.replay-end`, the progress never changes, and `replay.stop` returns
// to campaign at that level. A fresh play holds its begin (and dismissTutorial) records, so the replay's start is
// checked as a fresh play, not as empty records. The witness files must be present: a missing directory fails, never
// passes silently. Ten groups of ten levels, each well under the 10 s rule. Explicit types, plain loops, no wall-clock
// asserts.
import Foundation
import Testing
@testable import ApsidesWorkshopCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct ApsidesWorkshopReplayCatalogTests {
    typealias Core = ApsidesWorkshopExperienceCore

    /// The repository's witness directory, found from this file (five levels up: CoreTests, ApsidesWorkshop, the
    /// package, Packages).
    private static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/apsides-workshop/levels", isDirectory: true)

    /// The first level of each group of ten, 1, 11, … 91.
    static let groups: [Int] = [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]

    /// The `r02-g18.replay-end` refusal.
    private static let replayEnd: ActionResult = .rejected(.rule(code: ApsidesWorkshopExperienceRule.replayEnd))

    /// An action of `control` with `values`.
    private static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    private static func act(_ action: ApsidesWorkshopAction) -> ExperienceAction {
        switch action {
        case let .periapsis(eccentricity, direction): act("orbit.periapsis", [Double(eccentricity), Double(direction)])
        case let .size(size): act("orbit.size", [Double(size)])
        case .play: act("orbit.play")
        }
    }

    /// The file name of level `number`'s witness, `NNN.witness.json`.
    private static func witnessName(_ number: Int) -> String {
        String(ApsidesWorkshopGenerator.levelID(number).suffix(3)) + ".witness.json"
    }

    /// The stored witness of level `number`, read with the plain decoder.
    private static func witness(_ number: Int) throws -> ApsidesWorkshopWitness {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        return try JSONDecoder().decode(ApsidesWorkshopWitness.self, from: data)
    }

    /// Wins level `number` in campaign, replays its stored trace step by step against the recorded fingerprints and
    /// checks the replay ends won with the progress unchanged.
    private static func check(_ number: Int) async throws {
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        #expect(core.levelNumber == number && core.mode == .campaign, "level \(number)")
        #expect(core.progress.isOpen(number), "level \(number)")
        let tunings: [ApsidesWorkshopAction] = try Core.generated(number: number).plan.actions
        let actions: [ApsidesWorkshopAction] = tunings + [ApsidesWorkshopAction.play]
        for action in actions { #expect(core.apply(act(action)) == .accepted, "level \(number) \(action)") }
        #expect(core.play.stage == .won, "level \(number)")
        let result: ApsidesWorkshopProgress.Result = try #require(core.progress.solved[number])
        #expect(result.verified && result.trace == actions, "level \(number)")
        let stored: ApsidesWorkshopWitness = try witness(number)
        #expect(stored.number == number && stored.actions == result.trace, "level \(number)")
        try #require(stored.fingerprints.count > result.trace.count)
        let recorded: [String] = Array(stored.fingerprints.suffix(result.trace.count))
        let opening: String = stored.fingerprints[stored.fingerprints.count - result.trace.count - 1]
        let progress: ApsidesWorkshopProgress = core.progress
        #expect(core.apply(act("replay.start", [Double(number)])) == .accepted, "level \(number)")
        #expect(core.mode == .replay(level: number) && core.tutorial == .done, "level \(number)")
        let fresh: ApsidesWorkshopPlay = try Core.freshPlay(of: try Core.level(number: number))
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
}
