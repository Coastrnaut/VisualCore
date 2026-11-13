// ScenarioLaunchTests — feature 195 (UA-F09) T-U09-017 (US3; FR-U09-011, FR-U09-015, FR-U09-034). The app's
// scenario run: the request comes from the launch environment only; the debug experience runs under its own id with
// its manifest; a run writes a valid record into `Documents/visualcore-evidence/<run>/` and reports the exit code
// (the exit itself is not taken here); an unknown experience or scenario writes an error record with code 2.
#if DEBUG
import CryptoKit
import Foundation
import VisualCoreExperience
import XCTest
@testable import VisualCoreApp

@MainActor
final class ScenarioLaunchTests: XCTestCase {
    private func environment(_ scenario: String, experience: String = "a98.debug-experience",
                             run: String = "unit-run") -> [String: String] {
        ["VISUALCORE_AUTORUN": "scenario", "VISUALCORE_AUTORUN_EXPERIENCE": experience,
         "VISUALCORE_AUTORUN_SCENARIO": scenario, "VISUALCORE_AUTORUN_RUN": run]
    }

    private func perform(_ environment: [String: String], _ storage: TestStorage) async -> ScenarioLaunch.Outcome? {
        await ScenarioLaunch.perform(environment: environment, documents: storage.root.appendingPathComponent("Documents"),
                                     dataRoot: storage.root.appendingPathComponent("Experiences"),
                                     defaults: storage.defaults)
    }

    private func record(_ outcome: ScenarioLaunch.Outcome?) throws -> EvidenceRecord {
        let url = try XCTUnwrap(outcome?.record)
        return try JSONDecoder().decode(EvidenceRecord.self, from: Data(contentsOf: url))
    }

    func testNoRequestMeansANormalStart() async throws {
        let storage = try TestStorage(self)
        let none = await perform([:], storage)
        XCTAssertNil(none)
        let older = await perform(["VISUALCORE_AUTORUN": "smoke"], storage)
        XCTAssertNil(older, "the modes of the standalone apps are no scenario request")
    }

    func testTheDebugExperienceRunsUnderItsOwnIdWithACompleteManifest() throws {
        let id = try XCTUnwrap(ScenarioLaunch.debugID)
        let target = try XCTUnwrap(ScenarioLaunch.targets()[id])
        XCTAssertEqual(target.code, "debug")
        let problems = ScenarioManifestValidator.problems(target.manifest, controls: DebugExperienceCore.controls,
                                                          content: ContentRequirement())
        XCTAssertEqual(problems, [])
        XCTAssertNil(DebugLaunch.fixture.freeIDs.first { $0 == id }, "not a catalog id")
    }

    func testInputResponseWritesAValidPassingRecord() async throws {
        let storage = try TestStorage(self)
        let outcome = await perform(environment("input-response"), storage)
        XCTAssertEqual(outcome?.exitCode, 0)
        let url = try XCTUnwrap(outcome?.record)
        XCTAssertEqual(url.lastPathComponent, "a98.debug-experience.input-response.json")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "unit-run")
        XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent,
                       "visualcore-evidence")
        let found = try record(outcome)
        XCTAssertEqual(found.result, .pass, "\(found.failures)")
        XCTAssertEqual(found.steps.count, 4)
        XCTAssertTrue(found.steps.allSatisfy { $0.result == "accepted" && $0.digest != nil })
        XCTAssertEqual(found.code, "debug")
        XCTAssertEqual(found.configuration.process, "single")
    }

    func testCompletionReachesTheOutcomeOfTheCore() async throws {
        let storage = try TestStorage(self)
        let outcome = await perform(environment("completion"), storage)
        let found = try record(outcome)
        XCTAssertEqual(outcome?.exitCode, 0, "\(found.failures)")
    }

    func testEveryStandardScenarioOfTheDebugExperiencePasses() async throws {
        for name in ScenarioManifest.standardNames {
            let storage = try TestStorage(self)
            let outcome = await perform(environment(name), storage)
            let found = try record(outcome)
            XCTAssertEqual(outcome?.exitCode, 0, "\(name): \(found.failures)")
        }
    }

    func testSaveAndRestoreAcrossTwoRunsGiveTheSameDigest() async throws {
        let storage = try TestStorage(self)
        var save = environment("save-restore")
        save["VISUALCORE_AUTORUN_PHASE"] = "save"
        let first = await perform(save, storage)
        let saved = try record(first)
        XCTAssertEqual(first?.exitCode, 0, "\(saved.failures)")
        XCTAssertEqual(saved.configuration.process, "two-launch")
        let digest = try XCTUnwrap(saved.digests.final?.hex)
        var restore = environment("save-restore")
        restore["VISUALCORE_AUTORUN_PHASE"] = "restore"
        restore["VISUALCORE_AUTORUN_EXPECTED_DIGEST"] = digest
        let second = await perform(restore, storage)
        let restored = try record(second)
        XCTAssertEqual(second?.exitCode, 0, "\(restored.failures)")
        XCTAssertEqual(restored.digests.afterRestore?.hex, digest)
        // A wrong expected digest fails the restore phase.
        restore["VISUALCORE_AUTORUN_EXPECTED_DIGEST"] = String(repeating: "0", count: 64)
        let third = await perform(restore, storage)
        XCTAssertEqual(third?.exitCode, 1)
    }

    func testAnUnknownExperienceOrScenarioWritesAnErrorRecord() async throws {
        let storage = try TestStorage(self)
        let unknown = await perform(environment("input-response", experience: "a97.not-registered"), storage)
        XCTAssertEqual(unknown?.exitCode, 2)
        let unknownRecord = try record(unknown)
        XCTAssertEqual(unknownRecord.result, .error)
        XCTAssertEqual(unknownRecord.failures.first, "request.unknown-experience")
        let scenario = await perform(environment("no-such-scenario"), storage)
        XCTAssertEqual(scenario?.exitCode, 2)
        let scenarioRecord = try record(scenario)
        XCTAssertEqual(scenarioRecord.failures.first, "request.unknown-scenario")
        var broken = environment("input-response")
        broken["VISUALCORE_AUTORUN_SEED"] = "not a number"
        let bad = await perform(broken, storage)
        XCTAssertEqual(bad?.exitCode, 2)
        let badRecord = try record(bad)
        XCTAssertEqual(badRecord.failures.first, "request.bad-seed")
    }

    func testTheDebugCoreReportsItsOutcomeAfterThreeTaps() async throws {
        let id = try XCTUnwrap(ScenarioLaunch.debugID)
        var engine = ExperienceEngine<DebugExperienceCore>(id: id)
        try await engine.prepare(seed: 7)
        try engine.activate()
        for tap in 1...3 {
            XCTAssertNil(engine.outcome, "before tap \(tap)")
            XCTAssertEqual(engine.handle(control: "tap", values: []), .accepted)
        }
        XCTAssertEqual(engine.outcome?.code, "taps-counted")
    }

    /// The committed digests of the debug manifest hold on a bare engine, which sees no session (T-U09-051).
    func testTheDebugManifestDigestsHoldOnABareEngine() async throws {
        let id = try XCTUnwrap(ScenarioLaunch.debugID)
        var engine = ExperienceEngine<DebugExperienceCore>(id: id)
        try await engine.prepare(seed: DebugExperience.manifestSeed)
        try engine.activate()
        XCTAssertEqual(try engine.digest().hex, DebugExperience.initialDigest)
        for (index, expected) in DebugExperience.tapDigests.enumerated() {
            try engine.run(steps: 6)
            XCTAssertEqual(engine.handle(control: "tap", values: []), .accepted)
            XCTAssertEqual(try engine.digest().hex, expected, "after tap \(index + 1)")
        }
    }

    /// A damaged manifest is refused before anything runs, with exit 2 (T-U09-045).
    func testADamagedManifestIsRefusedWithExit2() async throws {
        let storage = try TestStorage(self)
        let id = try XCTUnwrap(ScenarioLaunch.debugID)
        var registration = DebugExperience.registration(for: id)
        let broken = ScenarioManifest(experience: id, kind: .creative, scenarios: [
            ScenarioSpec(name: "input-response", seed: 7, entries: [ScenarioStep(steps: 1, action: ScriptedAction("fly"))]),
        ])
        registration.scenarioManifest = broken
        let targets = ScenarioLaunch.targets(registry: [registration])
        let outcome = await ScenarioLaunch.perform(environment: environment("input-response"),
                                                   documents: storage.root.appendingPathComponent("Documents"),
                                                   dataRoot: storage.root.appendingPathComponent("Experiences"),
                                                   defaults: storage.defaults, targets: targets)
        XCTAssertEqual(outcome?.exitCode, 2)
        let found = try record(outcome)
        XCTAssertEqual(found.result, .error)
        XCTAssertEqual(found.failures.first, "request.invalid-manifest")
        XCTAssertTrue(found.failures.contains("missing scenario launch-first-frame"), "\(found.failures)")
        XCTAssertTrue(found.failures.contains { $0.contains("unknown control fly") }, "\(found.failures)")
    }

    /// A registered experience that carries a manifest is a target, under its catalog code (T-U09-046).
    func testARegisteredExperienceWithAManifestIsATarget() throws {
        let id = try XCTUnwrap(ExperienceID(rawValue: "a01.generative-art-studio"))
        var registration = DebugExperience.registration(for: id)
        XCTAssertNil(ScenarioLaunch.targets(registry: [registration])[id], "no manifest: no target")
        registration.scenarioManifest = DebugExperience.manifest(for: id)
        let target = try XCTUnwrap(ScenarioLaunch.targets(registry: [registration])[id])
        XCTAssertEqual(target.code, "A01")
    }

    /// A request error is written to the request's own run folder when its run id is usable (T-U09-052), and
    /// the frame of a drawing scenario is kept beside its record (T-U09-049).
    func testARequestErrorGoesToTheRunFolderAndFramesAreKept() async throws {
        let storage = try TestStorage(self)
        var broken = environment("input-response", run: "run-7")
        broken["VISUALCORE_AUTORUN_SEED"] = "x"
        let bad = await perform(broken, storage)
        XCTAssertEqual(bad?.record?.deletingLastPathComponent().lastPathComponent, "run-7")
        let launch = await perform(environment("launch-first-frame"), storage)
        let record = try self.record(launch)
        XCTAssertEqual(launch?.exitCode, 0, "\(record.failures)")
        let frameFile = try XCTUnwrap(launch?.record).deletingLastPathComponent()
            .appendingPathComponent("a98.debug-experience.launch-first-frame.frame.rgba")
        let bytes = try Data(contentsOf: frameFile)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hash, record.frames.first?.sha256, "the kept frame is the one the record names")
        XCTAssertFalse(record.configuration.automation, "a plain debug build is not an automation build")
    }

    func testTheEvidenceFolderIsListedByTheInventory() throws {
        let file = "Documents/visualcore-evidence/run-1/a98.debug-experience.input-response.json"
        XCTAssertEqual(DebugInventory.text(files: [file], keys: []), "inventory: 1 files, 0 keys; unlisted: none")
    }
}
#endif

