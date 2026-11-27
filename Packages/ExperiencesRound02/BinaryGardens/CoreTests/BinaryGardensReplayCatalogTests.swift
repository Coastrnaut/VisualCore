// BinaryGardensReplayCatalogTests — feature 507 (R02-G21-07) T-R02G2107-005 (FR-R02G2107-004, 006;
// SC-R02G2107-004; clarifications Q1, Q4), modelled on feature 497's MushroomWeatherReplayCatalogTests. Every stored
// trace of the 100 certified levels replays through the adapter: each level is opened by preparing its seed (the
// opening opens every level up to it) and won in campaign with its certified ring, phase, luminosity and tilt actions
// and the run (a verified result whose trace is those actions and the run, equal to the witness's actions), then
// `replay.start [level]` opens a fresh play with the tutorial done and tick 48 shown (its fingerprint the witness file's
// fingerprint before the first action), a tick is shown with `clock.show`, and `replay.step` runs to the end, each
// step's play fingerprint equal to the witness file's recorded fingerprint after that action
// (`docs/games/binary-gardens/levels/NNN.witness.json`, located from this file as BinaryGardensCatalogTests locates it
// and read with the plain decoder: the fingerprints after begin, after the dismissed tutorial on a tutorial level, then
// one per action) and the shown tick kept; the replay ends won, one more step is refused `r02-g21.replay-end`, the
// progress never changes, and `replay.stop` returns to campaign at that level with the progress unchanged. A fresh play
// holds its begin (and dismissTutorial) records, so the replay's start is checked as a fresh play, not as empty
// records. The witness files must be present: a missing directory fails, never passes silently. Ten groups of ten
// levels, each well under the 10 s rule. Explicit types, plain loops, no wall-clock asserts.
import Foundation
import Testing
@testable import BinaryGardensCore
import VisualCoreExperience

@Suite struct BinaryGardensReplayCatalogTests {
    typealias Core = BinaryGardensExperienceCore
    typealias Action = BinaryGardensAction
    typealias Rule = BinaryGardensExperienceRule

    /// The repository's witness directory, found from this file (five levels up: CoreTests, BinaryGardens, the
    /// package, Packages).
    private static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/binary-gardens/levels", isDirectory: true)

    /// The first level of each group of ten, 1, 11, … 91.
    static let groups: [Int] = [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]

    /// The `r02-g21.replay-end` refusal.
    private static let replayEnd: ActionResult = .rejected(.rule(code: Rule.replayEnd))

    /// An action of `control` with `values`.
    private static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    private static func act(_ action: Action) -> ExperienceAction {
        switch action {
        case let .ring(star, index):
            return act("star.ring", [Double(star), Double(index)])
        case let .phase(star, step):
            return act("star.phase", [Double(star), Double(step)])
        case let .luminosity(star, index):
            return act("star.luminosity", [Double(star), Double(index)])
        case let .tilt(step):
            return act("orbit.tilt", [Double(step)])
        case .run:
            return act("light.run")
        }
    }

    /// The file name of level `number`'s witness, `NNN.witness.json`.
    private static func witnessName(_ number: Int) -> String {
        String(BinaryGardensGenerator.levelID(number).suffix(3)) + ".witness.json"
    }

    /// The stored witness of level `number`, read with the plain decoder.
    private static func witness(_ number: Int) throws -> BinaryGardensWitness {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        return try JSONDecoder().decode(BinaryGardensWitness.self, from: data)
    }

    /// The certified ring, phase, luminosity and tilt actions of level `number`, then the run.
    private static func certifiedTrace(_ number: Int) throws -> [Action] {
        var actions: [Action] = try Core.generated(number: number).plan.actions
        actions.append(.run)
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
    /// checks the replay ends won with the shown tick kept and the progress unchanged.
    private static func check(_ number: Int) async throws {
        var core: Core = try await won(number)
        let actions: [Action] = try certifiedTrace(number)
        let result: BinaryGardensProgress.Result = try #require(core.progress.solved[number])
        #expect(result.verified && result.trace == actions, "level \(number)")
        let stored: BinaryGardensWitness = try witness(number)
        #expect(stored.number == number && stored.actions == result.trace, "level \(number)")
        try #require(stored.fingerprints.count > result.trace.count)
        let recorded: [String] = Array(stored.fingerprints.suffix(result.trace.count))
        let opening: String = stored.fingerprints[stored.fingerprints.count - result.trace.count - 1]
        let progress: BinaryGardensProgress = core.progress
        #expect(core.apply(act("replay.start", [Double(number)])) == .accepted, "level \(number)")
        #expect(core.mode == .replay(level: number) && core.tutorial == .done, "level \(number)")
        #expect(core.shownTick == Core.openingTick && core.replayPosition == 0, "level \(number)")
        #expect(core.replayLength == result.trace.count, "level \(number)")
        let fresh: BinaryGardensPlay = try Core.freshPlay(of: try Core.level(number: number))
        #expect(core.play == fresh && core.play.fingerprint == opening, "level \(number)")
        #expect(core.progress == progress, "level \(number)")
        // A tick shown during the replay (presentation, allowed) is kept by every step.
        let tick: Int = number % Core.openingTick + 1
        #expect(core.apply(act("clock.show", [Double(tick)])) == .accepted, "level \(number)")
        var index: Int = 0
        while index < result.trace.count {
            #expect(core.apply(act("replay.step")) == .accepted, "level \(number) step \(index)")
            #expect(core.play.fingerprint == recorded[index], "level \(number) step \(index)")
            #expect(core.shownTick == tick && core.replayPosition == index + 1, "level \(number) step \(index)")
            #expect(core.progress == progress, "level \(number) step \(index)")
            index += 1
        }
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
        #expect(core.apply(act("replay.step")) == replayEnd, "level \(number)")
        #expect(core.mode == .replay(level: number) && core.progress == progress, "level \(number)")
        #expect(core.shownTick == tick, "level \(number)")
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
