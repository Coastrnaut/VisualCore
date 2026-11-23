// HarmonicBridgesExperienceCoreTests — feature 413 (R02-G12-03) T-R02G1203-005 (FR-R02G1203-003, 005; clarifications
// Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls, ids, tiers and profile; the seed
// picks level `seed % 100 + 1` deterministically in stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and
// 1); every control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks,
// `r02-g12.not-whole`, and every kernel refusal the adapter can meet passing through with its code: `r02-g12.action`
// for a string the level lacks, a locked string and nothing to undo or redo, `noop` and `stage`; `stale` cannot arise
// because every tuning and test names the current fingerprint); undo restores the earlier digest exactly and redo the
// later one; the certified witness wins, a broken test and a spent budget fail, undo returns a failed play to playing;
// `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads (damaged, level out of
// range, a trace of another level, a record of a newer schema, an edited trace, an envelope of a newer schema); the
// certified-candidate table equals the 100 stored witnesses' `skipped` and the directly certified levels equal the
// stored ones (level fingerprint); `snapshot(time:)` copies the play and the kernel's exact report. Fixture seed 2_413.
// Levels are certified once per process, so the run stays short. Explicit types, plain loops.
import Foundation
import Testing
@testable import HarmonicBridgesCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/harmonic-bridges/levels", isDirectory: true)

@Suite struct HarmonicBridgesExperienceCoreTests {
    typealias Core = HarmonicBridgesExperienceCore

    /// The fixture seed of this feature.
    static let fixtureSeed: UInt64 = 2_413

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
    static func act(_ action: HarmonicBridgesAction) -> ExperienceAction {
        switch action {
        case let .tune(string, peg): act("string.tune", [Double(string), Double(peg)])
        case .test: act("crossing.test")
        }
    }

    /// The stored witness of level `number`, read with the plain decoder.
    static func storedWitness(_ number: Int) throws -> HarmonicBridgesWitness {
        let name: String = String(HarmonicBridgesGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(HarmonicBridgesWitness.self, from: data)
    }

    /// The first unlocked string of `level`.
    static func unlockedString(_ level: HarmonicBridgesLevel) -> Int? {
        for (index, string) in level.strings.enumerated() where !string.locked { return index }
        return nil
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 3 (then 2 and 4): string 0 is unlocked in both (pegs 11 and 8), string 1 in levels 2 and 4
        // (pegs 12 and 5). No action ends a play (tunings within the budgets of 9 and 11; no test).
        let actions: [ScriptedAction] = [ScriptedAction("string.tune", [0, 3]), ScriptedAction("string.tune", [0, 4]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("string.tune", [0, 5]), ScriptedAction("play.undo"),
                                         ScriptedAction("level.next"), ScriptedAction("string.tune", [1, 3])]
        // Refused on the openings of levels 1 and 3 (1 and 3 strings).
        let rejected: [ScriptedAction] = [ScriptedAction("string.tune", [12, 1]),
                                          ScriptedAction("string.tune", [0, 0]),
                                          ScriptedAction("string.tune", [0, 13]),
                                          ScriptedAction("string.tune", [0.5, 1]),
                                          ScriptedAction("string.tune", [0]),
                                          ScriptedAction("string.tune", [5, 1]),
                                          ScriptedAction("crossing.test", [1]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 2], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g12.harmonic-bridges" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g12.harmonic-bridges.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["string.tune", "crossing.test", "play.undo", "play.redo", "level.next"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...11, 1...12])
        let plainIndices: [Int] = [1, 2, 3, 4]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 1)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == HarmonicBridgesTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 0] && iterations == [1, 0.5, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(HarmonicBridgesExperienceRule.notWhole == "r02-g12.not-whole")
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
            let expected: HarmonicBridgesLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.pegs == expected.startingPegs)
            // The tutorial (levels 1 … 3) is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0)
        }
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(Core.levelNumber(forSeed: Self.fixtureSeed) == 14)
        #expect(throws: HarmonicBridgesError.level("number")) { try Core.level(number: 0) }
        #expect(throws: HarmonicBridgesError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheWitnessesAndCertifiesTheStoredLevels() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for number in 1...100 {
            let witness: HarmonicBridgesWitness = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "level \(number)")
        }
        // Directly certified levels equal the stored witness levels and actions.
        let numbers: [Int] = [1, 2, 49, 100]
        for number in numbers {
            let witness: HarmonicBridgesWitness = try Self.storedWitness(number)
            let generated: HarmonicBridgesGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.level.fingerprint, "level \(number)")
            #expect(generated.level == witness.level && generated.actions == witness.actions)
            #expect(generated.skipped == witness.skipped && generated.difficulty == witness.difficulty)
            #expect(generated.entry == HarmonicBridgesManifest.entries[number - 1])
            // The candidate just before the certified one does not certify (the generator skipped it).
            if witness.skipped > 0 {
                let entry: HarmonicBridgesManifestEntry = HarmonicBridgesManifest.entries[number - 1]
                #expect(Core.certify(entry, index: witness.skipped - 1) == nil, "level \(number)")
            }
        }
        // The generator itself gives the same level as the direct certification.
        let entry: HarmonicBridgesManifestEntry = HarmonicBridgesManifest.entries[1]
        #expect(try HarmonicBridgesGenerator.generate(entry) == Core.generated(number: 2))
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: one unlocked string (0) at peg 11, budget 9; the witness tunes it to 12 and tests.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.play.level.strings.count == 1 && core.play.pegs == [11] && core.play.level.budget == 9)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.act("string.tune", [12, 1]), Self.act("string.tune", [-1, 1]),
                                           Self.act("string.tune", [0, 0]), Self.act("string.tune", [0, 13]),
                                           Self.act("string.tune", [0.5, 2]), Self.act("string.tune", [0, .nan]),
                                           Self.act("string.tune", [0]), Self.act("string.tune", [0, 1, 2]),
                                           Self.act("string.tune", [1, 3]), Self.act("string.tune", [0, 11]),
                                           Self.act("crossing.test", [1]), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("play.undo", [1]),
                                           Self.act("level.next", [1]), Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "\(action.control) \(action.values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "\(action.control)")
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("string.tune", [12, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("string.tune", [-1, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("string.tune", [0, 0])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("string.tune", [0, 13])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("string.tune", [0, .nan])) == .rejected(.nonFinite(index: 1)))
        #expect(probe.apply(Self.act("string.tune", [0])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("crossing.test", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("play.undo", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let notWhole: ActionResult = .rejected(.rule(code: HarmonicBridgesExperienceRule.notWhole))
        #expect(probe.apply(Self.act("string.tune", [0.5, 2])) == notWhole)
        #expect(probe.apply(Self.act("string.tune", [0, 2.25])) == notWhole)
        // Every kernel refusal the adapter can meet passes through with its reason code.
        let action: ActionResult = .rejected(.rule(code: HarmonicBridgesError.action("string").reasonCode))
        let noop: ActionResult = .rejected(.rule(code: HarmonicBridgesError.noop.reasonCode))
        let stage: ActionResult = .rejected(.rule(code: HarmonicBridgesError.stage.reasonCode))
        #expect(action == .rejected(.rule(code: "r02-g12.action")) && noop == .rejected(.rule(code: "r02-g12.noop")))
        #expect(stage == .rejected(.rule(code: "r02-g12.stage")))
        #expect(probe.apply(Self.act("string.tune", [1, 3])) == action)     // a string level 1 lacks
        #expect(probe.apply(Self.act("string.tune", [11, 3])) == action)    // a string level 1 lacks
        #expect(probe.apply(Self.act("string.tune", [0, 11])) == noop)      // the current peg
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)

        // A tuning spends one action and changes the peg.
        #expect(core.apply(Self.act("string.tune", [0, 3])) == .accepted)
        #expect(core.play.pegs == [3] && core.play.actionsLeft == 8 && core.play.records.count == 1)
        #expect(core.play.stage == .playing && core.outcome == nil)
        #expect(try Self.digest(core) != opening)

        // The locked refusal: level 2's string 0 is locked.
        var locked: Core = try Core.opening(number: 2)
        #expect(locked.play.level.strings[0].locked)
        let lockedOpening: Core = locked
        #expect(locked.apply(Self.act("string.tune", [0, 3])) == action)
        #expect(locked == lockedOpening)

        // The stage refusal: a won play refuses everything but level.next.
        var won: Core = try Core.opening(number: 1)
        let generated: HarmonicBridgesGenerated = try Core.generated(number: 1)
        for step in generated.actions { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.play.stage == .won && won.outcome?.code == Core.wonCode)
        let final: Core = won
        #expect(won.apply(Self.act("string.tune", [0, 3])) == stage)
        #expect(won.apply(Self.act("crossing.test")) == stage)
        #expect(won.apply(Self.act("play.undo")) == stage)
        #expect(won.apply(Self.act("play.redo")) == stage)
        #expect(won == final)
        #expect(won.apply(Self.act("level.next")) == .accepted)
        #expect(won.levelNumber == 2 && won.play.stage == .playing)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 2)
        let startDigest: StateDigest = try Self.digest(core)
        let start: HarmonicBridgesPlay = core.play
        // Level 3: three unlocked strings at pegs 8, 1 and 5, budget 11.
        let steps: [ExperienceAction] = [Self.act("string.tune", [0, 3]), Self.act("string.tune", [1, 7]),
                                         Self.act("string.tune", [2, 9])]
        for step in steps { #expect(core.apply(step) == .accepted) }
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest && core.play.stage == .playing && core.play.pegs == [3, 7, 9])
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.pegs == start.pegs && core.play.actionsLeft == start.actionsLeft)
        #expect(core.play.report == start.report && core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.pegs == moved.play.pegs && core.play.actionsLeft == moved.play.actionsLeft)
        #expect(core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("string.tune", [2, 10])) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g12.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theWitnessWinsBrokenTestsAndSpentBudgetsFailAndUndoRetries() async throws {
        let numbers: [Int] = [1, 21, 41]
        let stageCode: ActionResult = .rejected(.rule(code: "r02-g12.stage"))
        for number in numbers {
            let generated: HarmonicBridgesGenerated = try Core.generated(number: number)
            let level: HarmonicBridgesLevel = generated.level
            var core: Core = try Core.opening(number: number)
            let before: StateDigest = try Self.digest(core)

            // A test at the starting pegs breaks (the certified plan needs at least one tuning).
            var broken: Core = core
            #expect(broken.apply(Self.act("crossing.test")) == .accepted)
            let expectedBreak: HarmonicBridgesBreak = try #require(level.firstBreak(core.play.report))
            let brokenFailure: HarmonicBridgesFailure = .broken(step: expectedBreak.step, string: expectedBreak.string)
            #expect(broken.play.stage == .failed && broken.play.failure == brokenFailure, "level \(number)")
            #expect(broken.outcome?.code == Core.failedCode && broken.play.actionsLeft == level.budget - 1)
            #expect(broken.apply(Self.act("play.undo")) == .accepted)
            #expect(broken.play.stage == .playing && broken.outcome == nil)
            #expect(try Self.digest(broken) == before)

            // Tunings back and forth on an unlocked string spend the budget: failed on the last one.
            var failing: Core = core
            let string: Int = try #require(Self.unlockedString(level))
            let current: Int = level.strings[string].peg
            let first: Int = current == 1 ? 2 : 1
            let second: Int = current == 3 ? 4 : 3
            var count: Int = 0
            while failing.play.stage == .playing && count < 64 {
                let peg: Int = count % 2 == 0 ? first : second
                #expect(failing.apply(Self.act("string.tune", [Double(string), Double(peg)])) == .accepted)
                count += 1
            }
            #expect(count == level.budget, "level \(number)")
            #expect(failing.play.stage == .failed && failing.play.failure == .budget(count - 1), "level \(number)")
            #expect(failing.play.actionsLeft == 0 && failing.outcome?.code == Core.failedCode)
            let failedSnapshot: HarmonicBridgesSceneSnapshot = failing.snapshot(time: 0)
            #expect(failedSnapshot.stage == .failed && failedSnapshot.failure == .budget(count - 1))
            #expect(failedSnapshot.actionsLeft == 0 && failedSnapshot.budget == level.budget)
            let failed: Core = failing
            #expect(failing.apply(Self.act("string.tune", [Double(string), Double(current)])) == stageCode)
            #expect(failing.apply(Self.act("crossing.test")) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            #expect(failing.apply(Self.act("play.undo")) == .accepted)
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(try Self.digest(failing) == before)

            // The certified witness: won on its last action (the test).
            for step in generated.actions { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.report.goalReachedInEveryStep && core.play.failure == nil)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            let next: Int = number % 100 + 1
            #expect(core.play.stage == .playing && core.levelNumber == next && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    @Test func nextLevelWrapsAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41)
        #expect(core.apply(Self.act("string.tune", [0, 12])) == .accepted)
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
        var core: Core = try await Core.prepare(seed: 20)
        let generated: HarmonicBridgesGenerated = try Core.generated(number: 21)
        // Every action of the witness but the test (no tuning ends the play), another tuning, then an undo.
        try #require(generated.actions.count >= 2)
        for step in generated.actions.dropLast() { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.apply(Self.act("string.tune", [0, 1])) == .accepted)
        #expect(core.play.stage == .playing)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"level\":21,\"records\":["))
        let restored: Core = try Core.restore(payload: payload, seed: 20)
        let restoredDigest: StateDigest = try Self.digest(restored)
        let savedDigest: StateDigest = try Self.digest(core)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 21)
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
        // A fresh play round-trips too.
        let opening: Core = try await Core.prepare(seed: 7)
        let openingPayload: Data = try opening.snapshotPayload()
        #expect(String(data: openingPayload, encoding: .utf8) == "{\"level\":8,\"records\":[]}")
        #expect(try Core.restore(payload: openingPayload, seed: 7) == opening)

        #expect(throws: HarmonicBridgesRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 20)
        }
        #expect(throws: HarmonicBridgesRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: HarmonicBridgesRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: HarmonicBridgesRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: HarmonicBridgesRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 20)
        }
        // The same records on another level: the records carry level 21's seed.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":21", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: HarmonicBridgesRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: HarmonicBridgesRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // A trace that no longer replays: an edited next fingerprint.
        let first: HarmonicBridgesRecord = try #require(core.play.records.first)
        let edited: Data = Data(text.replacingOccurrences(of: first.next, with: String(repeating: "0", count: 64)).utf8)
        #expect(edited != payload)
        var editedRefused: Bool = false
        do {
            _ = try Core.restore(payload: edited, seed: 20)
        } catch let refusal as HarmonicBridgesRestoreRefusal {
            if case .kernel(.malformed) = refusal { editedRefused = true }
        }
        #expect(editedRefused)
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        // Level 6: string 4 at peg 2 (its witness tunes it to 12).
        #expect(engine.handle(control: "string.tune", values: [4, 7]) == .accepted)
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

    @Test func theSnapshotCopiesThePlayAndTheKernelsReport() async throws {
        // Level 3 after the first tuning of its witness: the snapshot copies the play exactly.
        var core: Core = try await Core.prepare(seed: 2)
        let generated: HarmonicBridgesGenerated = try Core.generated(number: 3)
        let first: HarmonicBridgesAction = try #require(generated.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: HarmonicBridgesPlay = core.play
        let level: HarmonicBridgesLevel = play.level
        let snapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: 2.5)
        #expect(snapshot == HarmonicBridgesSceneSnapshot(play: play, levelNumber: 3, time: 2.5))
        #expect(snapshot.islands == level.islands && snapshot.strings == level.strings && snapshot.pegs == play.pegs)
        #expect(snapshot.report == play.report && snapshot.report == level.report(pegs: play.pegs))
        #expect(snapshot.threshold == level.threshold && snapshot.start == level.start && snapshot.goal == level.goal)
        #expect(snapshot.stage == .playing && snapshot.failure == nil && snapshot.levelNumber == 3)
        #expect(snapshot.actionsLeft == level.budget - 1 && snapshot.budget == level.budget && snapshot.time == 2.5)
        #expect(snapshot.steps == level.steps.count && snapshot.modes.count == level.steps.count)
        // Non-finite and negative times read as 0.
        let zero: HarmonicBridgesSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        #expect(core.snapshot(time: -3) == zero && zero.shownStep == 0)
        // After the win the goal is reached in every step of the snapshot's report.
        for step in generated.actions.dropFirst() { #expect(core.apply(Self.act(step)) == .accepted) }
        let won: HarmonicBridgesSceneSnapshot = core.snapshot(time: 1)
        #expect(won.stage == .won && won.report.goalReachedInEveryStep)
        for step in 0..<won.steps { #expect(won.isReached(won.goal, step: step)) }
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: Self.fixtureSeed)
        let string: Int = try #require(Self.unlockedString(core.play.level))
        let peg: Int = core.play.pegs[string] == 1 ? 2 : 1
        #expect(core.apply(Self.act("string.tune", [Double(string), Double(peg)])) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let shells: [Int] = [2, 2, 1, 0, 0]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.glowShells == shells[index])
            #expect(core.renderTier == HarmonicBridgesTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.stage == core.play.stage && snapshot.actionsLeft == core.play.actionsLeft)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
