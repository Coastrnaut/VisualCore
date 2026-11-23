// BackwardsAuroraExperienceCoreTests — feature 393 (R02-G10-03) T-R02G1003-005 (FR-R02G1003-003, 005; clarification
// Q5). The adapter core: the shared conformance checks pass; the declared controls, ids, tiers and profile; the seed
// picks level `seed % 100 + 1` deterministically in stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and
// 1); every control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks,
// `r02-g10.not-whole`, and every kernel refusal the adapter can meet passing through with its code: `r02-g10.action`,
// `noop` and `stage`; `stale` cannot arise because every reversal names the current fingerprint); undo restores the
// earlier digest exactly and redo the later one; the certified solution wins, a tear and the budget fail, undo returns a
// failed play to playing; `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads
// (damaged, level out of range, a trace of another level, a record of a newer schema, an envelope of a newer schema);
// the certified-candidate table equals the 100 stored witnesses' `skipped` and the directly certified levels equal the
// stored ones; `snapshot(sectionStart:sectionEnd:time:)` mirrors the play. Fixture seed 2_393. Levels are certified
// once per process, so the run stays short. Explicit types, plain loops.
import Foundation
import Testing
@testable import BackwardsAuroraCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/backwards-aurora/levels", isDirectory: true)

@Suite struct BackwardsAuroraExperienceCoreTests {
    typealias Core = BackwardsAuroraExperienceCore

    /// The fixture seed of this feature.
    static let fixtureSeed: UInt64 = 2_393

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
    static func act(_ action: BackwardsAuroraAction) -> ExperienceAction {
        switch action {
        case let .reverse(start, end):
            act("wave.reverse", [Double(start), Double(end)])
        }
    }

    /// A neutral reversal of `core`: the first pair [k, k + 1] that is not a palindrome and holds no checkpoint, so it
    /// can never win; reversing it twice restores the wave.
    static func neutralReverse(_ core: Core) -> ExperienceAction? {
        let samples: [Int] = core.play.wave.samples
        let checkpoints: [Int] = core.play.level.checkpoints
        for k in 0..<(samples.count - 1) {
            if samples[k] != samples[k + 1], !checkpoints.contains(k), !checkpoints.contains(k + 1) {
                return act("wave.reverse", [Double(k), Double(k + 1)])
            }
        }
        return nil
    }

    /// The stored witness of level `number`.
    static func storedWitness(_ number: Int) throws -> BackwardsAuroraWitness {
        let name: String = String(BackwardsAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(BackwardsAuroraWitness.self, from: data)
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 2 (then 2 and 3): a reversal, undo and redo, another reversal, undo, a third reversal, then
        // level.next and a reversal. None of the sections holds a solution, so no play ends.
        let actions: [ScriptedAction] = [ScriptedAction("wave.reverse", [0, 2]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("wave.reverse", [10, 13]), ScriptedAction("play.undo"),
                                         ScriptedAction("wave.reverse", [5, 7]),
                                         ScriptedAction("level.next"), ScriptedAction("wave.reverse", [0, 2])]
        // Refused on the opening of levels 1 and 2 (14 and 15 samples; [5, 6] is a palindrome on both).
        let rejected: [ScriptedAction] = [ScriptedAction("wave.reverse", [32, 1]),
                                          ScriptedAction("wave.reverse", [0, 32]),
                                          ScriptedAction("wave.reverse", [0.5, 2]),
                                          ScriptedAction("wave.reverse", [0]),
                                          ScriptedAction("wave.reverse", [2, 1]),
                                          ScriptedAction("wave.reverse", [3, 3]),
                                          ScriptedAction("wave.reverse", [0, 20]),
                                          ScriptedAction("wave.reverse", [5, 6]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 1], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g10.backwards-aurora" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g10.backwards-aurora.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["wave.reverse", "play.undo", "play.redo", "level.next"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...31, 0...31])
        let plainIndices: [Int] = [1, 2, 3]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 1)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == BackwardsAuroraTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 2.0 / 3.0, 1.0 / 3.0] && iterations == [1, 0.5, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(BackwardsAuroraExperienceRule.notWhole == "r02-g10.not-whole")
        #expect(Core.wonCode == "won" && Core.failedCode == "failed")
    }

    @Test func theSeedPicksTheLevelDeterministically() async throws {
        let seeds: [UInt64] = [0, 1, 99, 100]
        let numbers: [Int] = [1, 2, 100, 1]
        for index in seeds.indices {
            #expect(Core.levelNumber(forSeed: seeds[index]) == numbers[index])
            let first: Core = try await Core.prepare(seed: seeds[index])
            let second: Core = try await Core.prepare(seed: seeds[index])
            #expect(first.levelNumber == numbers[index] && first.openingNumber == numbers[index])
            #expect(first == second)
            #expect(try Self.digest(first) == Self.digest(second))
            let expected: BackwardsAuroraLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.wave == expected.opening)
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.spent == 0 && first.qualityTier == 0)
        }
        #expect(Core.levelNumber(forSeed: Self.fixtureSeed) == 94)
        #expect(throws: BackwardsAuroraError.level("number")) { try Core.level(number: 0) }
        #expect(throws: BackwardsAuroraError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheWitnessesAndCertifiesTheStoredLevels() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for number in 1...100 {
            let witness: BackwardsAuroraWitness = try Self.storedWitness(number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "level \(number)")
        }
        // Directly certified levels equal the stored witness levels and solutions.
        let numbers: [Int] = [1, 9, 63, 100]
        for number in numbers {
            let witness: BackwardsAuroraWitness = try Self.storedWitness(number)
            let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
            #expect(generated.level == witness.level && generated.solution.actions == witness.actions)
            #expect(generated.skipped == witness.skipped && generated.bound == witness.bound)
            #expect(generated.entry == BackwardsAuroraManifest.entries[number - 1])
            // The candidate just before the certified one does not certify (the generator skipped it).
            if witness.skipped > 0 {
                let entry: BackwardsAuroraManifestEntry = BackwardsAuroraManifest.entries[number - 1]
                #expect(Core.certify(entry, index: witness.skipped - 1) == nil, "level \(number)")
            }
        }
        // The generator itself gives the same level as the direct certification.
        let entry: BackwardsAuroraManifestEntry = BackwardsAuroraManifest.entries[8]
        #expect(try BackwardsAuroraGenerator.generate(entry) == Core.generated(number: 9))
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: 14 samples, sections 2 … 14, bend limit 1, breaking limit 128, budget 9.
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.act("wave.reverse", [32, 1]), Self.act("wave.reverse", [-1, 1]),
                                           Self.act("wave.reverse", [0, 32]), Self.act("wave.reverse", [0.5, 2]),
                                           Self.act("wave.reverse", [0, .nan]), Self.act("wave.reverse", [0]),
                                           Self.act("wave.reverse", [0, 1, 2]), Self.act("wave.reverse", [2, 1]),
                                           Self.act("wave.reverse", [3, 3]), Self.act("wave.reverse", [0, 14]),
                                           Self.act("wave.reverse", [5, 6]), Self.act("wave.reverse", [1, 2]),
                                           Self.act("play.undo"), Self.act("play.redo"),
                                           Self.act("play.undo", [1]), Self.act("level.next", [1]),
                                           Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "\(action.control) \(action.values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "\(action.control)")
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("wave.reverse", [32, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("wave.reverse", [-1, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("wave.reverse", [0, 32])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("wave.reverse", [0])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("play.undo", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let notWhole: ActionResult = .rejected(.rule(code: BackwardsAuroraExperienceRule.notWhole))
        #expect(probe.apply(Self.act("wave.reverse", [0.5, 2])) == notWhole)
        #expect(probe.apply(Self.act("wave.reverse", [0, 2.25])) == notWhole)
        // Every kernel refusal the adapter can meet passes through with its reason code.
        let action: ActionResult = .rejected(.rule(code: BackwardsAuroraError.action("end").reasonCode))
        let noop: ActionResult = .rejected(.rule(code: BackwardsAuroraError.noop.reasonCode))
        #expect(action == .rejected(.rule(code: "r02-g10.action")) && noop == .rejected(.rule(code: "r02-g10.noop")))
        #expect(probe.apply(Self.act("wave.reverse", [0, 14])) == action)     // end outside the wave
        #expect(probe.apply(Self.act("wave.reverse", [2, 1])) == action)      // start not before end
        #expect(probe.apply(Self.act("wave.reverse", [3, 3])) == action)      // start not before end
        #expect(probe.apply(Self.act("wave.reverse", [5, 6])) == noop)        // -20, -20 reads the same both ways
        #expect(probe.apply(Self.act("wave.reverse", [1, 2])) == noop)        // -23, -23
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)
        // A section length below the level's shortest cannot be named (start < end gives at least 2 = shortest), so
        // the length refusal is the kernel's only on a longer section than the level allows: the whole wave is
        // allowed (longest = N), so it reverses.
        var whole: Core = core
        #expect(whole.apply(Self.act("wave.reverse", [0, 13])) == .accepted)
        #expect(whole.play.wave.samples == Array(core.play.wave.samples.reversed()))

        // A reversal spends one and reverses the section.
        #expect(core.apply(Self.act("wave.reverse", [0, 2])) == .accepted)
        #expect(core.play.wave.samples.prefix(3) == [-23, -23, -24] && core.play.spent == 1)
        #expect(core.play.records.count == 1 && core.play.stage == .playing)
        #expect(try Self.digest(core) != opening)
        // The stage refusal: a won play refuses everything but level.next.
        var won: Core = try Core.opening(number: 1)
        let generated: BackwardsAuroraGenerated = try Core.generated(number: 1)
        for step in generated.solution.actions { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.play.stage == .won)
        let stage: ActionResult = .rejected(.rule(code: BackwardsAuroraError.stage.reasonCode))
        #expect(stage == .rejected(.rule(code: "r02-g10.stage")))
        let final: Core = won
        #expect(won.apply(Self.act("wave.reverse", [0, 2])) == stage)
        #expect(won.apply(Self.act("play.undo")) == stage)
        #expect(won.apply(Self.act("play.redo")) == stage)
        #expect(won == final)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 20)
        let startDigest: StateDigest = try Self.digest(core)
        let start: BackwardsAuroraWave = core.play.wave
        let sections: [[Double]] = [[0, 2], [5, 7], [10, 13]]
        for section in sections { #expect(core.apply(Self.act("wave.reverse", section)) == .accepted) }
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest && core.play.stage == .playing)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.wave == start && core.play.spent == 0 && core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.wave == moved.play.wave && core.play.spent == 3)
        #expect(core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let other: ExperienceAction = try #require(Self.neutralReverse(core))
        #expect(core.apply(other) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g10.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theSolutionWinsTheBudgetFailsAndUndoRetries() async throws {
        // Bands 1 and 2 (breaking limit 128): a neutral pair reversed back and forth never tears and never wins.
        let numbers: [Int] = [1, 21, 32]
        let stageCode: ActionResult = .rejected(.rule(code: "r02-g10.stage"))
        for number in numbers {
            let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
            let level: BackwardsAuroraLevel = generated.level
            var core: Core = try Core.opening(number: number)
            var failing: Core = core
            let before: StateDigest = try Self.digest(failing)
            let neutral: ExperienceAction = try #require(Self.neutralReverse(failing))
            for _ in 0..<level.budget { #expect(failing.apply(neutral) == .accepted) }
            #expect(failing.play.stage == .failed && failing.play.failure == .budget, "level \(number)")
            #expect(failing.outcome?.code == Core.failedCode)
            let failedSnapshot: BackwardsAuroraSceneSnapshot = failing.snapshot(sectionStart: 0, sectionEnd: 1, time: 0)
            #expect(failedSnapshot.stage == .failed && failedSnapshot.failure == .budget)
            #expect(failedSnapshot.tear == nil && failedSnapshot.spent == level.budget)
            let failed: Core = failing
            #expect(failing.apply(neutral) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            #expect(failing.apply(Self.act("play.undo")) == .accepted)
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(try Self.digest(failing) == before)
            // The certified solution: won on its last action.
            for step in generated.solution.actions { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.spent == generated.solution.smallest)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            let next: Int = number % 100 + 1
            #expect(core.play.stage == .playing && core.levelNumber == next && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    @Test func aTearFailsAndUndoRetries() async throws {
        // The first section of level 100 (breaking limit 18) whose reversal tears the aurora.
        let core: Core = try Core.opening(number: 100)
        let before: StateDigest = try Self.digest(core)
        let count: Int = core.play.wave.count
        var torn: Core? = nil
        for start in 0..<(count - 1) where torn == nil {
            for end in (start + 1)..<count where torn == nil {
                var copy: Core = core
                if copy.apply(Self.act("wave.reverse", [Double(start), Double(end)])).isAccepted,
                   case .tear = copy.play.failure {
                    torn = copy
                }
            }
        }
        var failed: Core = try #require(torn)
        guard case let .tear(move, seam)? = failed.play.failure else {
            Issue.record("no tear")
            return
        }
        #expect(move == 0 && failed.play.stage == .failed && failed.outcome?.code == Core.failedCode)
        let snapshot: BackwardsAuroraSceneSnapshot = failed.snapshot(sectionStart: 3, sectionEnd: 7, time: 1)
        #expect(snapshot.tear == seam && snapshot.failure == failed.play.failure)
        #expect(abs(failed.play.wave.bend(at: seam)) > failed.play.level.breakingLimit)
        #expect(failed.apply(Self.act("wave.reverse", [0, 2])) == .rejected(.rule(code: "r02-g10.stage")))
        #expect(failed.apply(Self.act("play.undo")) == .accepted)
        let retried: StateDigest = try Self.digest(failed)
        #expect(failed.play.stage == .playing && failed.play.failure == nil && retried == before)
    }

    @Test func nextLevelWrapsAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41)
        let neutral: ExperienceAction = try #require(Self.neutralReverse(core))
        #expect(core.apply(neutral) == .accepted)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 42 && core.play.records.isEmpty && core.play.stage == .playing)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 40)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
        // The wrap: level 100 → 1.
        var last: Core = try Core.opening(number: 100)
        #expect(last.apply(Self.act("level.next")) == .accepted)
        let first: Core = try await Core.prepare(seed: 0)
        #expect(last.levelNumber == 1 && last == first)
        last.reset()
        #expect(last.levelNumber == 100)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 31)
        let generated: BackwardsAuroraGenerated = try Core.generated(number: 32)
        // Every action of the solution but the last (none of them ends the play), then an undo.
        try #require(generated.solution.actions.count >= 2)
        for step in generated.solution.actions.dropLast() { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .playing)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"level\":32,\"records\":["))
        let restored: Core = try Core.restore(payload: payload, seed: 31)
        let restoredDigest: StateDigest = try Self.digest(restored)
        let savedDigest: StateDigest = try Self.digest(core)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 32)
        var redone: Core = restored
        var original: Core = core
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(original.apply(Self.act("play.redo")) == .accepted)
        #expect(redone == original)
        let other: Core = try Core.restore(payload: payload, seed: 0)
        #expect(other == core && other.openingNumber == 1)
        var otherReset: Core = other
        otherReset.reset()
        #expect(otherReset.levelNumber == 1 && otherReset.play.records.isEmpty)

        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: BackwardsAuroraRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: BackwardsAuroraRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 31)
        }
        // The same records on another level: the records carry level 32's seed.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: BackwardsAuroraRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: BackwardsAuroraRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 31)
        }
        // A trace that no longer replays: an edited next fingerprint.
        let first: BackwardsAuroraRecord = try #require(core.play.records.first)
        let edited: Data = Data(text.replacingOccurrences(of: first.next, with: String(repeating: "0", count: 64)).utf8)
        #expect(edited != payload)
        var editedRefused: Bool = false
        do {
            _ = try Core.restore(payload: edited, seed: 31)
        } catch let refusal as BackwardsAuroraRestoreRefusal {
            if case .kernel(.malformed) = refusal { editedRefused = true }
        }
        #expect(editedRefused)
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        #expect(engine.handle(control: "wave.reverse", values: [0, 1]) == .accepted)
        let before: StateDigest = try engine.digest()
        let saved: ExperienceSnapshot = try engine.snapshot()
        let newer = try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: saved.seed,
                                           stepIndex: saved.stepIndex, digest: saved.digest,
                                           payload: Data(saved.payload.utf8))
        var refused: Bool = false
        do {
            try engine.restore(newer)
        } catch {
            refused = error == .snapshot(.newerSchema(found: 2, current: 1))
        }
        #expect(refused)
        #expect(try engine.digest() == before)
        try engine.restore(saved)
        #expect(try engine.digest() == before)
    }

    @Test func theSnapshotMirrorsThePlay() async throws {
        // Level 1 after the first reversal of its solution: the snapshot copies the kernel exactly.
        var core: Core = try await Core.prepare(seed: 0)
        let generated: BackwardsAuroraGenerated = try Core.generated(number: 1)
        let first: BackwardsAuroraAction = try #require(generated.solution.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: BackwardsAuroraPlay = core.play
        let level: BackwardsAuroraLevel = play.level
        let snapshot: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 2, sectionEnd: 5, time: 2.5)
        #expect(snapshot.samples == play.wave.samples && snapshot.target == level.target.samples)
        #expect(snapshot.checkpoints == level.checkpoints && snapshot.matched == play.matched)
        #expect(snapshot.bendLimit == level.bendLimit && snapshot.tear == nil)
        var kinks: [Int] = []
        for k in 1...(play.wave.count - 2) where abs(play.wave.bend(at: k)) > level.bendLimit { kinks.append(k) }
        #expect(snapshot.kinks == kinks && kinks.count == 4)
        #expect(snapshot.sectionStart == 2 && snapshot.sectionEnd == 5)
        #expect(snapshot.stage == play.stage && snapshot.failure == nil && snapshot.levelNumber == 1)
        #expect(snapshot.spent == 1 && snapshot.budget == level.budget && snapshot.time == 2.5)
        // The section is clamped to the wave: 0 ≤ start < end ≤ N − 1.
        let clamped: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 40, sectionEnd: -3, time: 0)
        #expect(clamped.sectionStart == 12 && clamped.sectionEnd == 13)
        let low: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: -5, sectionEnd: 0, time: 0)
        #expect(low.sectionStart == 0 && low.sectionEnd == 1)
        let nan: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 2, sectionEnd: 5, time: .nan)
        #expect(nan.time == 0 && core.snapshot(sectionStart: 2, sectionEnd: 5, time: .infinity) == nan)
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: Self.fixtureSeed)
        let neutral: ExperienceAction = try #require(Self.neutralReverse(core))
        #expect(core.apply(neutral) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let layers: [Int] = [3, 3, 2, 1, 1]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.trailingLayers == layers[index])
            #expect(core.renderTier == BackwardsAuroraTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 0, sectionEnd: 1, time: time)
            #expect(snapshot.stage == core.play.stage && snapshot.spent == core.play.spent)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
