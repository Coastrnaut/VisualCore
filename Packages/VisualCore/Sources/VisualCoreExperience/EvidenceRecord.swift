// EvidenceRecord — feature 195 T-U09-011 (FR-U09-030; data-model section 4; Auto-Creator.md section 22.3; contract
// specs/195-ua-f09-verification-runner/contracts/verification-api.md). The app's part of an evidence record of
// schema 1. Every key of the schema is always written: a value the app cannot know (most of the environment, the
// source, the artifacts, the attempt) is written as an explicit JSON `null`, which the driver later completes, because
// scripts/check_evidence.py requires every key to be present. The whole file compiles only under DEBUG or
// VISUALCORE_AUTOMATION, so a shipping release build contains none of it.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation

/// The result of a scenario run.
public enum EvidenceResult: String, Codable, Sendable, Equatable, CaseIterable {
    /// Every expectation held.
    case pass
    /// At least one expectation failed.
    case fail
    /// The run could not be carried out.
    case error
}

private extension KeyedEncodingContainer {
    /// Encodes the value, or an explicit `null` when there is none (never omits the key).
    mutating func encodeOrNull<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

/// One evidence record of schema 1, as the app writes it; the driver completes the fields marked as its own.
public struct EvidenceRecord: Sendable, Equatable, Codable {
    /// The schema version this type writes.
    public static let schemaVersion = 1

    /// The run: its id (passed to the app), the attempt and the lock hash (both completed by the driver).
    public struct Run: Sendable, Equatable, Codable {
        /// The run id.
        public var id: String
        /// The attempt number; `null` until the driver writes it.
        public var attempt: Int?
        /// The SHA-256 of the lock; `null` in schema 1.
        public var lockSHA256: String?

        enum CodingKeys: String, CodingKey {
            case id, attempt
            case lockSHA256 = "lock_sha256"
        }

        /// Creates a run.
        public init(id: String, attempt: Int? = nil, lockSHA256: String? = nil) {
            self.id = id
            self.attempt = attempt
            self.lockSHA256 = lockSHA256
        }

        /// Encodes every key, absent values as `null`.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encodeOrNull(attempt, forKey: .attempt)
            try container.encodeOrNull(lockSHA256, forKey: .lockSHA256)
        }
    }

    /// Where the run happened. The app knows only `kind`; the driver completes the rest.
    public struct Environment: Sendable, Equatable, Codable {
        /// `simulator` or `device`.
        public var kind: String
        /// The operating system version.
        public var osVersion: String?
        /// The operating system build.
        public var osBuild: String?
        /// The device type, for example the simulator model.
        public var deviceType: String?
        /// The Xcode version.
        public var xcode: String?
        /// The Swift version.
        public var swift: String?
        /// The SDK.
        public var sdk: String?
        /// The host operating system.
        public var hostOS: String?
        /// The signing, `none` for a simulator build.
        public var signing: String?

        enum CodingKeys: String, CodingKey {
            case kind
            case osVersion = "os_version"
            case osBuild = "os_build"
            case deviceType = "device_type"
            case xcode, swift, sdk
            case hostOS = "host_os"
            case signing
        }

        /// Creates an environment.
        public init(kind: String, osVersion: String? = nil, osBuild: String? = nil, deviceType: String? = nil,
                    xcode: String? = nil, swift: String? = nil, sdk: String? = nil, hostOS: String? = nil,
                    signing: String? = nil) {
            self.kind = kind
            self.osVersion = osVersion
            self.osBuild = osBuild
            self.deviceType = deviceType
            self.xcode = xcode
            self.swift = swift
            self.sdk = sdk
            self.hostOS = hostOS
            self.signing = signing
        }

        /// Encodes every key, absent values as `null`.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind, forKey: .kind)
            try container.encodeOrNull(osVersion, forKey: .osVersion)
            try container.encodeOrNull(osBuild, forKey: .osBuild)
            try container.encodeOrNull(deviceType, forKey: .deviceType)
            try container.encodeOrNull(xcode, forKey: .xcode)
            try container.encodeOrNull(swift, forKey: .swift)
            try container.encodeOrNull(sdk, forKey: .sdk)
            try container.encodeOrNull(hostOS, forKey: .hostOS)
            try container.encodeOrNull(signing, forKey: .signing)
        }
    }

    /// The source the app was built from; the driver completes every field.
    public struct Source: Sendable, Equatable, Codable {
        /// The commit.
        public var commit: String?
        /// Whether the working tree had changes.
        public var dirty: Bool?
        /// The tree hash.
        public var tree: String?
        /// The submodule commits by path.
        public var submodules: [String: String]?
        /// The SHA-256 of the catalog.
        public var catalogSHA256: String?
        /// The SHA-256 of the app.
        public var appSHA256: String?

        enum CodingKeys: String, CodingKey {
            case commit, dirty, tree, submodules
            case catalogSHA256 = "catalog_sha256"
            case appSHA256 = "app_sha256"
        }

        /// Creates a source; every field defaults to `null`.
        public init(commit: String? = nil, dirty: Bool? = nil, tree: String? = nil, submodules: [String: String]? = nil,
                    catalogSHA256: String? = nil, appSHA256: String? = nil) {
            self.commit = commit
            self.dirty = dirty
            self.tree = tree
            self.submodules = submodules
            self.catalogSHA256 = catalogSHA256
            self.appSHA256 = appSHA256
        }

        /// Encodes every key, absent values as `null`.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeOrNull(commit, forKey: .commit)
            try container.encodeOrNull(dirty, forKey: .dirty)
            try container.encodeOrNull(tree, forKey: .tree)
            try container.encodeOrNull(submodules, forKey: .submodules)
            try container.encodeOrNull(catalogSHA256, forKey: .catalogSHA256)
            try container.encodeOrNull(appSHA256, forKey: .appSHA256)
        }
    }

    /// How the app was built and run.
    public struct Configuration: Sendable, Equatable, Codable {
        /// `Debug` or `Release`.
        public var build: String
        /// Whether the automation hooks were compiled in.
        public var automation: Bool
        /// The quality tier the experience ran at.
        public var qualityTier: String
        /// The entitlement, `none` for a scenario run.
        public var entitlement: String
        /// `two-launch` or `single`.
        public var process: String

        enum CodingKeys: String, CodingKey {
            case build, automation
            case qualityTier = "quality_tier"
            case entitlement, process
        }

        /// Creates a configuration.
        public init(build: String, automation: Bool, qualityTier: String, entitlement: String, process: String) {
            self.build = build
            self.automation = automation
            self.qualityTier = qualityTier
            self.entitlement = entitlement
            self.process = process
        }
    }

    /// One step of the scenario: the control used, its values, the result and the digest after it.
    public struct Step: Sendable, Equatable, Codable {
        /// The control.
        public var control: String
        /// The values sent to the control.
        public var values: [Double]
        /// The result of the step.
        public var result: String
        /// Why the step had its result; `null` when there is nothing to say.
        public var reason: String?
        /// The state digest after the step.
        public var digest: StateDigest

        enum CodingKeys: String, CodingKey {
            case control, values, result, reason, digest
        }

        /// Creates a step.
        public init(control: String, values: [Double], result: String, reason: String? = nil, digest: StateDigest) {
            self.control = control
            self.values = values
            self.result = result
            self.reason = reason
            self.digest = digest
        }

        /// Encodes every key, an absent reason as `null`.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(control, forKey: .control)
            try container.encode(values, forKey: .values)
            try container.encode(result, forKey: .result)
            try container.encodeOrNull(reason, forKey: .reason)
            try container.encode(digest, forKey: .digest)
        }
    }

    /// The digests of the run; each is `null` when the run did not reach it.
    public struct Digests: Sendable, Equatable, Codable {
        /// The digest after preparation.
        public var initial: StateDigest?
        /// The digest at the end.
        public var `final`: StateDigest?
        /// The digest after a restore.
        public var afterRestore: StateDigest?
        /// The digest after a reset.
        public var afterReset: StateDigest?

        enum CodingKeys: String, CodingKey {
            case initial, `final`
            case afterRestore = "after_restore"
            case afterReset = "after_reset"
        }

        /// Creates digests.
        public init(initial: StateDigest? = nil, `final`: StateDigest? = nil, afterRestore: StateDigest? = nil,
                    afterReset: StateDigest? = nil) {
            self.initial = initial
            self.`final` = `final`
            self.afterRestore = afterRestore
            self.afterReset = afterReset
        }

        /// Encodes every key, absent values as `null`.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeOrNull(initial, forKey: .initial)
            try container.encodeOrNull(`final`, forKey: .`final`)
            try container.encodeOrNull(afterRestore, forKey: .afterRestore)
            try container.encodeOrNull(afterReset, forKey: .afterReset)
        }
    }

    /// One probe of a frame: what was expected, what was observed, and whether they match.
    public struct ProbeResult: Sendable, Equatable, Codable {
        /// The probe name.
        public var name: String
        /// The expected colour class.
        public var expected: String
        /// The observed colour class.
        public var observed: String
        /// Whether the classes match.
        public var pass: Bool

        /// Creates a probe result.
        public init(name: String, expected: String, observed: String, pass: Bool) {
            self.name = name
            self.expected = expected
            self.observed = observed
            self.pass = pass
        }
    }

    /// One captured frame.
    public struct Frame: Sendable, Equatable, Codable {
        /// Whether the frame is non-blank.
        public var nonBlank: Bool
        /// The probe results.
        public var probes: [ProbeResult]
        /// The path of the saved frame; completed by the driver.
        public var path: String?
        /// The SHA-256 of the frame; completed by the driver when the app has not written it.
        public var sha256: String?

        enum CodingKeys: String, CodingKey {
            case nonBlank = "non_blank"
            case probes, path, sha256
        }

        /// Creates a frame.
        public init(nonBlank: Bool, probes: [ProbeResult], path: String? = nil, sha256: String? = nil) {
            self.nonBlank = nonBlank
            self.probes = probes
            self.path = path
            self.sha256 = sha256
        }

        /// Encodes every key, absent values as `null`.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(nonBlank, forKey: .nonBlank)
            try container.encode(probes, forKey: .probes)
            try container.encodeOrNull(path, forKey: .path)
            try container.encodeOrNull(sha256, forKey: .sha256)
        }
    }

    /// Durations of the run in milliseconds.
    public struct Timing: Sendable, Equatable, Codable {
        /// From launch to the scenario's start; `null` when the app cannot measure it.
        public var launchMS: Double?
        /// The preparation of the experience.
        public var preparationMS: Double
        /// The shader compilation.
        public var shaderCompilationMS: Double
        /// Until the first frame was presented.
        public var firstPresentMS: Double

        enum CodingKeys: String, CodingKey {
            case launchMS = "launch_ms"
            case preparationMS = "preparation_ms"
            case shaderCompilationMS = "shader_compilation_ms"
            case firstPresentMS = "first_present_ms"
        }

        /// Creates a timing.
        public init(launchMS: Double? = nil, preparationMS: Double, shaderCompilationMS: Double, firstPresentMS: Double) {
            self.launchMS = launchMS
            self.preparationMS = preparationMS
            self.shaderCompilationMS = shaderCompilationMS
            self.firstPresentMS = firstPresentMS
        }

        /// Encodes every key, an absent launch time as `null`.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeOrNull(launchMS, forKey: .launchMS)
            try container.encode(preparationMS, forKey: .preparationMS)
            try container.encode(shaderCompilationMS, forKey: .shaderCompilationMS)
            try container.encode(firstPresentMS, forKey: .firstPresentMS)
        }
    }

    /// Frame pacing over the samples taken.
    public struct Pacing: Sendable, Equatable, Codable {
        /// The number of frame intervals sampled.
        public var samples: Int
        /// The number on time.
        public var onTime: Int
        /// The median interval.
        public var medianMS: Double
        /// The 95th percentile interval.
        public var p95MS: Double
        /// The 99th percentile interval.
        public var p99MS: Double

        enum CodingKeys: String, CodingKey {
            case samples
            case onTime = "on_time"
            case medianMS = "median_ms"
            case p95MS = "p95_ms"
            case p99MS = "p99_ms"
        }

        /// Creates a pacing.
        public init(samples: Int, onTime: Int, medianMS: Double, p95MS: Double, p99MS: Double) {
            self.samples = samples
            self.onTime = onTime
            self.medianMS = medianMS
            self.p95MS = p95MS
            self.p99MS = p99MS
        }
    }

    /// Resource use at the end of the run.
    public struct Resources: Sendable, Equatable, Codable {
        /// The process footprint in bytes.
        public var footprintBytes: Int
        /// The GPU memory in bytes.
        public var gpuBytes: Int
        /// The live GPU objects.
        public var live: Int
        /// The leaked GPU objects.
        public var leaked: Int

        enum CodingKeys: String, CodingKey {
            case footprintBytes = "footprint_bytes"
            case gpuBytes = "gpu_bytes"
            case live, leaked
        }

        /// Creates resources.
        public init(footprintBytes: Int, gpuBytes: Int, live: Int, leaked: Int) {
            self.footprintBytes = footprintBytes
            self.gpuBytes = gpuBytes
            self.live = live
            self.leaked = leaked
        }
    }

    /// The files of the run; the driver completes every field.
    public struct Artifacts: Sendable, Equatable, Codable {
        /// The result bundle, when there is one.
        public var resultBundle: String?
        /// The log.
        public var log: String?
        /// The SHA-256 of the log.
        public var logSHA256: String?
        /// The SHA-256 of the record.
        public var recordSHA256: String?

        enum CodingKeys: String, CodingKey {
            case resultBundle = "result_bundle"
            case log
            case logSHA256 = "log_sha256"
            case recordSHA256 = "record_sha256"
        }

        /// Creates artifacts; every field defaults to `null`.
        public init(resultBundle: String? = nil, log: String? = nil, logSHA256: String? = nil, recordSHA256: String? = nil) {
            self.resultBundle = resultBundle
            self.log = log
            self.logSHA256 = logSHA256
            self.recordSHA256 = recordSHA256
        }

        /// Encodes every key, absent values as `null`.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeOrNull(resultBundle, forKey: .resultBundle)
            try container.encodeOrNull(log, forKey: .log)
            try container.encodeOrNull(logSHA256, forKey: .logSHA256)
            try container.encodeOrNull(recordSHA256, forKey: .recordSHA256)
        }
    }

    /// The schema version; 1.
    public var schema: Int
    /// The experience id.
    public var experience: String
    /// The catalog code (`A01` …), or `sample` or `debug`.
    public var code: String
    /// The scenario name.
    public var scenario: String
    /// The seed as decimal text.
    public var seed: String
    /// The result.
    public var result: EvidenceResult
    /// The run.
    public var run: Run
    /// The environment.
    public var environment: Environment
    /// The source.
    public var source: Source
    /// The configuration.
    public var configuration: Configuration
    /// The steps.
    public var steps: [Step]
    /// The digests.
    public var digests: Digests
    /// The captured frames.
    public var frames: [Frame]
    /// The timing.
    public var timing: Timing
    /// The frame pacing; `null` when it was not sampled.
    public var pacing: Pacing?
    /// The resources.
    public var resources: Resources
    /// The thermal state, for example `nominal`.
    public var thermalState: String
    /// Whether low-power mode was on.
    public var lowPower: Bool
    /// The battery level 0…1; `null` when unknown.
    public var battery: Double?
    /// The artifacts.
    public var artifacts: Artifacts
    /// The failures; empty for a pass.
    public var failures: [String]

    enum CodingKeys: String, CodingKey {
        case schema, experience, code, scenario, seed, result, run, environment, source, configuration, steps
        case digests, frames, timing, pacing, resources
        case thermalState = "thermal_state"
        case lowPower = "low_power"
        case battery, artifacts, failures
    }

    /// Creates a record of schema `schemaVersion` unless another schema is given.
    public init(schema: Int = EvidenceRecord.schemaVersion, experience: String, code: String, scenario: String,
                seed: String, result: EvidenceResult, run: Run, environment: Environment, source: Source = Source(),
                configuration: Configuration, steps: [Step], digests: Digests, frames: [Frame], timing: Timing,
                pacing: Pacing?, resources: Resources, thermalState: String, lowPower: Bool, battery: Double?,
                artifacts: Artifacts = Artifacts(), failures: [String]) {
        self.schema = schema
        self.experience = experience
        self.code = code
        self.scenario = scenario
        self.seed = seed
        self.result = result
        self.run = run
        self.environment = environment
        self.source = source
        self.configuration = configuration
        self.steps = steps
        self.digests = digests
        self.frames = frames
        self.timing = timing
        self.pacing = pacing
        self.resources = resources
        self.thermalState = thermalState
        self.lowPower = lowPower
        self.battery = battery
        self.artifacts = artifacts
        self.failures = failures
    }

    /// Encodes every key of schema 1, an absent pacing or battery as `null`.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(experience, forKey: .experience)
        try container.encode(code, forKey: .code)
        try container.encode(scenario, forKey: .scenario)
        try container.encode(seed, forKey: .seed)
        try container.encode(result, forKey: .result)
        try container.encode(run, forKey: .run)
        try container.encode(environment, forKey: .environment)
        try container.encode(source, forKey: .source)
        try container.encode(configuration, forKey: .configuration)
        try container.encode(steps, forKey: .steps)
        try container.encode(digests, forKey: .digests)
        try container.encode(frames, forKey: .frames)
        try container.encode(timing, forKey: .timing)
        try container.encodeOrNull(pacing, forKey: .pacing)
        try container.encode(resources, forKey: .resources)
        try container.encode(thermalState, forKey: .thermalState)
        try container.encode(lowPower, forKey: .lowPower)
        try container.encodeOrNull(battery, forKey: .battery)
        try container.encode(artifacts, forKey: .artifacts)
        try container.encode(failures, forKey: .failures)
    }

    /// The record as JSON with sorted keys and pretty printing; throws when a value cannot be encoded (for
    /// example a non-finite number).
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
#endif
