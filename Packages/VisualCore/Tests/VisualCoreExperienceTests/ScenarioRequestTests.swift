// ScenarioRequestTests — feature 195 T-U09-010 (FR-U09-011, FR-U09-030; data-model sections 4 and 5): parsing of the
// launch-environment request and the JSON shape of the evidence record of schema 1.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import Testing
import VisualCoreExperience

@Suite struct ScenarioRequestTests {
    private static let digest = DigestBuilder(domain: "scenario-request-tests").finish()

    /// A complete request environment.
    private static func environment() -> [String: String] {
        [ScenarioRequest.autorunKey: "scenario",
         ScenarioRequest.experienceKey: "a05.infinite-geometry",
         ScenarioRequest.scenarioKey: "save-restore",
         ScenarioRequest.seedKey: "18446744073709551615",
         ScenarioRequest.runKey: "Run-2026-11-12-a",
         ScenarioRequest.phaseKey: "restore",
         ScenarioRequest.expectedDigestKey: digest.hex]
    }

    /// The error of parsing `environment`, or `nil` when it is no request or parses.
    private static func error(_ environment: [String: String]) -> ScenarioRequestError? {
        guard case let .failure(error)? = ScenarioRequest.parse(environment) else { return nil }
        return error
    }

    @Test func theKeysAreThoseOfDataModelSection5() {
        #expect(ScenarioRequest.autorunKey == "VISUALCORE_AUTORUN")
        #expect(ScenarioRequest.autorunValue == "scenario")
        #expect(ScenarioRequest.experienceKey == "VISUALCORE_AUTORUN_EXPERIENCE")
        #expect(ScenarioRequest.scenarioKey == "VISUALCORE_AUTORUN_SCENARIO")
        #expect(ScenarioRequest.seedKey == "VISUALCORE_AUTORUN_SEED")
        #expect(ScenarioRequest.runKey == "VISUALCORE_AUTORUN_RUN")
        #expect(ScenarioRequest.phaseKey == "VISUALCORE_AUTORUN_PHASE")
        #expect(ScenarioRequest.expectedDigestKey == "VISUALCORE_AUTORUN_EXPECTED_DIGEST")
    }

    @Test func noAutorunOrAnotherModeIsNoRequest() {
        var environment = Self.environment()
        environment[ScenarioRequest.autorunKey] = nil
        #expect(ScenarioRequest.parse(environment) == nil)
        #expect(ScenarioRequest.parse([:]) == nil)
        for mode in ["smoke", "Scenario", "scenario ", ""] {
            environment[ScenarioRequest.autorunKey] = mode
            #expect(ScenarioRequest.parse(environment) == nil)
        }
    }

    @Test func aCompleteRequestParses() throws {
        let parsed = try #require(ScenarioRequest.parse(Self.environment()))
        let request = try parsed.get()
        let id = try ExperienceID("a05.infinite-geometry")
        #expect(request == ScenarioRequest(experience: id, scenario: "save-restore", seed: UInt64.max,
                                           run: "Run-2026-11-12-a", phase: .restore, expectedDigest: Self.digest))
    }

    @Test func optionalKeysDefault() throws {
        var environment = Self.environment()
        environment[ScenarioRequest.seedKey] = nil
        environment[ScenarioRequest.phaseKey] = nil
        environment[ScenarioRequest.expectedDigestKey] = nil
        let parsed = try #require(ScenarioRequest.parse(environment))
        let request = try parsed.get()
        #expect(request.seed == nil)
        #expect(request.phase == .single)
        #expect(request.expectedDigest == nil)
        environment[ScenarioRequest.phaseKey] = "save"
        let saved = try #require(ScenarioRequest.parse(environment))
        let savedRequest = try saved.get()
        #expect(savedRequest.phase == .save)
    }

    @Test func eachBadValueHasItsTypedError() {
        func with(_ key: String, _ value: String?) -> ScenarioRequestError? {
            var environment = Self.environment()
            environment[key] = value
            return Self.error(environment)
        }
        #expect(with(ScenarioRequest.experienceKey, nil) == .missingExperience)
        #expect(with(ScenarioRequest.experienceKey, "") == .missingExperience)
        #expect(with(ScenarioRequest.experienceKey, "A05.Infinite") == .badExperience)
        #expect(with(ScenarioRequest.scenarioKey, nil) == .missingScenario)
        #expect(with(ScenarioRequest.scenarioKey, "Save_Restore") == .badScenario)
        #expect(with(ScenarioRequest.scenarioKey, String(repeating: "a", count: 65)) == .badScenario)
        #expect(with(ScenarioRequest.seedKey, "-1") == .badSeed)
        #expect(with(ScenarioRequest.seedKey, "18446744073709551616") == .badSeed)
        #expect(with(ScenarioRequest.seedKey, "0x10") == .badSeed)
        #expect(with(ScenarioRequest.seedKey, "") == .badSeed)
        #expect(with(ScenarioRequest.runKey, nil) == .badRun)
        #expect(with(ScenarioRequest.runKey, "") == .badRun)
        #expect(with(ScenarioRequest.runKey, "run_1") == .badRun)
        #expect(with(ScenarioRequest.runKey, String(repeating: "R", count: 65)) == .badRun)
        #expect(with(ScenarioRequest.runKey, String(repeating: "R", count: 64)) == nil)
        #expect(with(ScenarioRequest.phaseKey, "single-ish") == .badPhase)
        #expect(with(ScenarioRequest.phaseKey, "Save") == .badPhase)
        #expect(with(ScenarioRequest.expectedDigestKey, "abc") == .badDigest)
        #expect(with(ScenarioRequest.expectedDigestKey, Self.digest.hex.uppercased()) == .badDigest)
    }

    @Test func valuesOver256CharactersAreRefused() {
        var environment = Self.environment()
        environment[ScenarioRequest.scenarioKey] = String(repeating: "a", count: 257)
        let error = Self.error(environment)
        #expect(error == .tooLong(key: ScenarioRequest.scenarioKey))
        #expect(error?.code == "request.too-long")
        environment[ScenarioRequest.scenarioKey] = "save-restore"
        environment[ScenarioRequest.expectedDigestKey] = String(repeating: "f", count: 300)
        #expect(Self.error(environment) == .tooLong(key: ScenarioRequest.expectedDigestKey))
    }

    @Test func theErrorCodesAreStable() {
        #expect(ScenarioRequestError.missingExperience.code == "request.missing-experience")
        #expect(ScenarioRequestError.badExperience.code == "request.bad-experience")
        #expect(ScenarioRequestError.missingScenario.code == "request.missing-scenario")
        #expect(ScenarioRequestError.badScenario.code == "request.bad-scenario")
        #expect(ScenarioRequestError.badSeed.code == "request.bad-seed")
        #expect(ScenarioRequestError.badRun.code == "request.bad-run")
        #expect(ScenarioRequestError.badPhase.code == "request.bad-phase")
        #expect(ScenarioRequestError.badDigest.code == "request.bad-digest")
    }
}

@Suite struct EvidenceRecordTests {
    private static let digest = DigestBuilder(domain: "evidence-record-tests").finish()

    /// The top-level keys of data-model section 4.
    private static let topLevelKeys: Set<String> = [
        "schema", "experience", "code", "scenario", "seed", "result", "run", "environment", "source", "configuration",
        "steps", "digests", "frames", "timing", "pacing", "resources", "thermal_state", "low_power", "battery",
        "artifacts", "failures",
    ]

    /// A record as the app writes it: everything the driver completes is absent.
    private static func record() -> EvidenceRecord {
        EvidenceRecord(
            experience: "a05.infinite-geometry", code: "A05", scenario: "launch-first-frame", seed: "42", result: .pass,
            run: EvidenceRecord.Run(id: "run-1"), environment: EvidenceRecord.Environment(kind: "simulator"),
            configuration: EvidenceRecord.Configuration(build: "Debug", automation: true, qualityTier: 1,
                                                        entitlement: "none", process: "single"),
            steps: [EvidenceRecord.Step(control: "tone", values: [0.5], result: "applied", digest: digest)],
            digests: EvidenceRecord.Digests(initial: digest, final: digest),
            frames: [EvidenceRecord.Frame(nonBlank: true, probes: [
                EvidenceRecord.ProbeResult(name: "centre", expected: "red", observed: "red", pass: true),
            ])],
            timing: EvidenceRecord.Timing(preparationMS: 12.5, shaderCompilationMS: 3, firstPresentMS: 40),
            pacing: nil, resources: EvidenceRecord.Resources(footprintBytes: 1_000_000, gpuBytes: 2048, live: 3, leaked: 0),
            thermalState: "nominal", lowPower: false, battery: nil, failures: [])
    }

    /// The decoded JSON object of the record.
    private static func object() throws -> [String: Any] {
        let data = try record().encoded()
        let value = try JSONSerialization.jsonObject(with: data)
        return try #require(value as? [String: Any])
    }

    @Test func theSchemaVersionIsOne() {
        #expect(EvidenceRecord.schemaVersion == 1)
        #expect(Self.record().schema == 1)
    }

    @Test func theTopLevelKeysAreExactlyThoseOfSection4() throws {
        let object = try Self.object()
        #expect(Set(object.keys) == Self.topLevelKeys)
        #expect(object.keys.count == 21)
    }

    @Test func absentValuesAreWrittenAsNull() throws {
        let object = try Self.object()
        #expect(object["pacing"] is NSNull)
        #expect(object["battery"] is NSNull)
        let run = try #require(object["run"] as? [String: Any])
        #expect(Set(run.keys) == ["id", "attempt", "lock_sha256"])
        #expect(run["attempt"] is NSNull)
        #expect(run["lock_sha256"] is NSNull)
        let environment = try #require(object["environment"] as? [String: Any])
        #expect(Set(environment.keys) == ["kind", "os_version", "os_build", "device_type", "xcode", "swift", "sdk",
                                          "host_os", "signing"])
        #expect(environment["os_version"] is NSNull)
        let source = try #require(object["source"] as? [String: Any])
        #expect(Set(source.keys) == ["commit", "dirty", "tree", "submodules", "catalog_sha256", "app_sha256"])
        #expect(source["commit"] is NSNull)
        let configuration = try #require(object["configuration"] as? [String: Any])
        #expect(Set(configuration.keys) == ["build", "automation", "quality_tier", "entitlement", "process"])
        let steps = try #require(object["steps"] as? [[String: Any]])
        #expect(Set(steps.first?.keys.map { $0 } ?? []) == ["control", "values", "result", "reason", "digest"])
        let digests = try #require(object["digests"] as? [String: Any])
        #expect(Set(digests.keys) == ["initial", "final", "after_restore", "after_reset"])
        #expect(digests["after_restore"] is NSNull)
        let frames = try #require(object["frames"] as? [[String: Any]])
        #expect(Set(frames.first?.keys.map { $0 } ?? []) == ["non_blank", "probes", "path", "sha256"])
        let probes = try #require(frames.first?["probes"] as? [[String: Any]])
        #expect(Set(probes.first?.keys.map { $0 } ?? []) == ["name", "expected", "observed", "pass"])
        let timing = try #require(object["timing"] as? [String: Any])
        #expect(Set(timing.keys) == ["launch_ms", "preparation_ms", "shader_compilation_ms", "first_present_ms"])
        #expect(timing["launch_ms"] is NSNull)
        let resources = try #require(object["resources"] as? [String: Any])
        #expect(Set(resources.keys) == ["footprint_bytes", "gpu_bytes", "live", "leaked"])
        let artifacts = try #require(object["artifacts"] as? [String: Any])
        #expect(Set(artifacts.keys) == ["result_bundle", "log", "log_sha256", "record_sha256"])
        #expect(artifacts["log"] is NSNull)
    }

    @Test func theKeysAreSorted() throws {
        let data = try Self.record().encoded()
        let text = String(decoding: data, as: UTF8.self)
        let artifacts = try #require(text.range(of: "\"artifacts\""))
        let schema = try #require(text.range(of: "\"schema\""))
        #expect(artifacts.lowerBound < schema.lowerBound)
    }

    @Test func aRecordRoundTrips() throws {
        var record = Self.record()
        let data = try record.encoded()
        let decoded = try JSONDecoder().decode(EvidenceRecord.self, from: data)
        #expect(decoded == record)
        record.pacing = EvidenceRecord.Pacing(samples: 120, onTime: 118, medianMS: 16.7, p95MS: 17.1, p99MS: 18)
        record.battery = 0.8
        record.source = EvidenceRecord.Source(commit: "abc", dirty: false, submodules: ["External/projectm-ios": "def"])
        record.artifacts = EvidenceRecord.Artifacts(log: "run.log")
        let completed = try record.encoded()
        let decodedCompleted = try JSONDecoder().decode(EvidenceRecord.self, from: completed)
        #expect(decodedCompleted == record)
    }
}
#endif
