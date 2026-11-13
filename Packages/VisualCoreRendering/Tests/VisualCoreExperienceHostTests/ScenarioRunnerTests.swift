// ScenarioRunnerTests — feature 195 (UA-F09) T-U09-013 (US2, US5; FR-U09-001, FR-U09-010, FR-U09-013, FR-U09-014,
// FR-U09-040; SC-U09-001, SC-U09-002, SC-U09-007). The nine standard scenarios of the sample experience run
// through a real session and pass; the faults `LossySnapshot` and `WrongReset`, a blank frame and a wrong
// probe each fail with a named expectation. Every test attaches its evidence record
// (`evidence-a99.contract-sample-<scenario>.json`) to the result bundle, where the driver reads it.
//
// The expected digests are independent of the session: the initial digest is the committed golden digest of seed
// 42, and the digests after actions come from the same entries run on a bare engine (`ExperienceEngine
// .runScenario`), which never sees a session, a render host or a presenter.
#if DEBUG || VISUALCORE_AUTOMATION
import XCTest
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

@MainActor
final class ScenarioRunnerTests: XCTestCase {
    // MARK: Manifest of the sample

    private static let seed: UInt64 = 42

    private static var golden42: String {
        SampleExperience.goldenDigests.first { $0.seed == seed }?.hex ?? ""
    }

    /// Accepted actions, 30 steps apart.
    private static let inputEntries: [ScenarioStep] = [
        ScenarioStep(steps: 30, action: ScriptedAction("tone", [0.5]), result: "accepted"),
        ScenarioStep(steps: 30, action: ScriptedAction("ping"), result: "accepted"),
        ScenarioStep(steps: 30, action: ScriptedAction("move", [1, 0]), result: "accepted"),
        ScenarioStep(steps: 30, action: ScriptedAction("tone", [0.25]), result: "accepted"),
    ]

    /// The digest the entries give on a bare engine prepared with `seed`.
    private func bareDigest(_ entries: [ScenarioStep]) async -> String? {
        let scenario = ExperienceScenario(seed: Self.seed,
                                          entries: entries.map { .init(steps: $0.steps, action: $0.action) })
        let result = await ExperienceEngine<SampleExperienceCore<NoFault>>.runScenario(scenario, id: SampleExperience.id)
        return result.digest?.hex
    }

    /// Moves that bring the marker of a seed-42 preparation onto its target, found on a bare engine.
    private func movesToTarget() async throws -> [ScenarioStep] {
        var engine = ExperienceEngine<SampleExperienceCore<NoFault>>(id: SampleExperience.id)
        try await engine.prepare(seed: Self.seed)
        try engine.activate()
        var moves: [ScenarioStep] = []
        for _ in 0..<32 {
            let core = try XCTUnwrap(engine.core)
            guard core.x != core.targetX || core.y != core.targetY else { break }
            let dx = Double((core.targetX - core.x).signum())
            let dy = Double((core.targetY - core.y).signum())
            XCTAssertEqual(engine.handle(control: "move", values: [dx, dy]), .accepted)
            moves.append(ScenarioStep(steps: 0, action: ScriptedAction("move", [dx, dy]), result: "accepted"))
        }
        XCTAssertNotNil(engine.outcome, "the moves reach the target")
        return moves
    }

    /// The sample's manifest: the nine standard scenarios with their expectations.
    private func sampleManifest() async throws -> ScenarioManifest {
        let bare = await bareDigest(Self.inputEntries)
        let inputDigest = try XCTUnwrap(bare)
        let moves = try await movesToTarget()
        let rejected = [
            ScenarioStep(steps: 0, action: ScriptedAction("move", [0, 0]), result: "action.rule.sample.no-move"),
            ScenarioStep(steps: 0, action: ScriptedAction("tone", [2]), result: "action.out-of-range"),
        ]
        let golden = Self.golden42
        let specs = [
            ScenarioSpec(name: "launch-first-frame", seed: Self.seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: golden)),
            ScenarioSpec(name: "input-response", seed: Self.seed, entries: Self.inputEntries,
                         expect: ScenarioExpectations(initialDigest: golden, finalDigest: inputDigest)),
            ScenarioSpec(name: "completion", seed: Self.seed, entries: moves,
                         expect: ScenarioExpectations(initialDigest: golden, outcome: "target-reached")),
            ScenarioSpec(name: "rejection", seed: Self.seed, entries: rejected,
                         expect: ScenarioExpectations(initialDigest: golden, finalDigest: golden)),
            ScenarioSpec(name: "save-restore", seed: Self.seed, entries: Self.inputEntries,
                         expect: ScenarioExpectations(initialDigest: golden, finalDigest: inputDigest)),
            ScenarioSpec(name: "reset", seed: Self.seed, entries: Self.inputEntries,
                         expect: ScenarioExpectations(initialDigest: golden, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: Self.seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: golden)),
            ScenarioSpec(name: "teardown-reentry", seed: Self.seed, entries: [], expect: ScenarioExpectations(),
                         cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: Self.seed, entries: [], expect: ScenarioExpectations()),
        ]
        return ScenarioManifest(experience: SampleExperience.id, kind: .creative, scenarios: specs)
    }

    // MARK: Running

    /// A request for the sample with fault `Fault`; `configure` sets the presenter's switches.
    private func maker<Fault: SampleFault>(_ fault: Fault.Type,
                                           configure: ((SamplePresenter<Fault>) -> Void)? = nil) -> ScenarioRunner.RequestMaker {
        { seed, snapshot in
            sampleRequest(Fault.self, seed: seed, snapshot: snapshot, configure: { presenter in
                presenter.marksCorner = true
                configure?(presenter)
            }).request
        }
    }

    /// Runs `name` of the sample's manifest with fault `Fault` and attaches the record; returns the failures the
    /// runner and the evaluator found.
    @discardableResult
    private func run<Fault: SampleFault>(_ name: String, _ fault: Fault.Type, attach: Bool = true,
                                         configure: ((SamplePresenter<Fault>) -> Void)? = nil) async throws -> [String] {
        let manifest = try await sampleManifest()
        let spec = try XCTUnwrap(manifest.scenarios.first { $0.name == name })
        let runner = ScenarioRunner(session: ExperienceSession())
        let request: ScenarioRunner.RequestMaker = name == "cancel-prepare"
            ? maker(SlowPreparation.self) : maker(fault, configure: configure)
        let result = await runner.run(spec, request: request)
        let failures = ScenarioEvaluator.failures(spec, result.observation)
        let record = EvidenceRecord.observed(result.observation, experience: SampleExperience.id, code: "sample",
                                             run: "package-test", build: "Debug", process: result.process,
                                             qualityTier: nil, failures: failures, probes: result.probes,
                                             thermalState: "nominal", lowPower: false)
        if attach {
            let attachment = XCTAttachment(data: try record.encoded(), uniformTypeIdentifier: "public.json")
            attachment.name = "evidence-\(SampleExperience.id.rawValue)-\(name).json"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        return failures
    }

    // MARK: The nine standard scenarios pass

    func testTheManifestOfTheSampleIsComplete() async throws {
        let manifest = try await sampleManifest()
        let problems = ScenarioManifestValidator.problems(manifest, controls: SampleExperienceCore<NoFault>.controls,
                                                          content: ContentRequirement())
        XCTAssertEqual(problems, [])
        let decoded = try ScenarioManifest(data: manifest.encoded())
        XCTAssertEqual(decoded, manifest, "the manifest survives its JSON form")
    }

    func testLaunchFirstFrame() async throws {
        let failures = try await run("launch-first-frame", NoFault.self)
        XCTAssertEqual(failures, [])
    }

    func testInputResponse() async throws {
        let failures = try await run("input-response", NoFault.self)
        XCTAssertEqual(failures, [])
    }

    func testCompletion() async throws {
        let failures = try await run("completion", NoFault.self)
        XCTAssertEqual(failures, [])
    }

    func testRejection() async throws {
        let failures = try await run("rejection", NoFault.self)
        XCTAssertEqual(failures, [])
    }

    func testSaveRestore() async throws {
        let failures = try await run("save-restore", NoFault.self)
        XCTAssertEqual(failures, [])
    }

    func testReset() async throws {
        let failures = try await run("reset", NoFault.self)
        XCTAssertEqual(failures, [])
    }

    func testSuspendResume() async throws {
        let failures = try await run("suspend-resume", NoFault.self)
        XCTAssertEqual(failures, [])
    }

    func testTeardownReentry() async throws {
        let failures = try await run("teardown-reentry", NoFault.self)
        XCTAssertEqual(failures, [])
    }

    func testCancelPrepare() async throws {
        let failures = try await run("cancel-prepare", NoFault.self)
        XCTAssertEqual(failures, [])
    }

    // MARK: Deliberate failures (SC-U09-002, SC-U09-007)

    func testALossySnapshotFailsSaveRestoreByName() async throws {
        let failures = try await run("save-restore", LossySnapshot.self, attach: false)
        XCTAssertTrue(failures.contains { $0.hasPrefix("after-restore digest") || $0.hasSuffix("at restore") }, "\(failures)")
    }

    /// A rejection that changes the core is discarded by the engine before it reaches the session (the contract
    /// at work), so the deliberately failing state change is a wrong reset.
    func testAWrongResetFailsResetByName() async throws {
        let failures = try await run("reset", WrongReset.self, attach: false)
        XCTAssertTrue(failures.contains { $0.hasPrefix("after-reset digest") }, "\(failures)")
    }

    func testABlankFrameFailsLaunchFirstFrame() async throws {
        let failures = try await run("launch-first-frame", NoFault.self, attach: false) { $0.drawsBlank = true }
        XCTAssertTrue(failures.contains("frame: blank"), "\(failures)")
    }

    func testAProbeThatDoesNotMatchFails() async throws {
        let failures = try await run("launch-first-frame", NoFault.self, attach: false) { $0.wrongProbe = "green" }
        XCTAssertTrue(failures.contains { $0.hasPrefix("probe centre: declared green") }, "\(failures)")
    }

    // MARK: Endurance (FR-U09-060), outside the default nine

    func testEnduranceKeepsResourcesFlat() async throws {
        let spec = ScenarioSpec(name: "endurance", seed: Self.seed, entries: [], expect: ScenarioExpectations(),
                                seconds: 60)
        let runner = ScenarioRunner(session: ExperienceSession())
        let result = await runner.run(spec, request: maker(NoFault.self))
        XCTAssertEqual(ScenarioEvaluator.failures(spec, result.observation), [])
    }
}
#endif
