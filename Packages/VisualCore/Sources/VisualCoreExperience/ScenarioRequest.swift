// ScenarioRequest — feature 195 T-U09-011 (FR-U09-011; data-model section 5; research R2; contract
// specs/195-ua-f09-verification-runner/contracts/verification-api.md). The launch-environment keys by which the
// verification driver asks the app to run one scenario, and their parsing. The whole file compiles only under DEBUG
// or VISUALCORE_AUTOMATION, so a shipping release build contains none of it.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation

/// Why a scenario request in the launch environment was refused.
public enum ScenarioRequestError: Error, Sendable, Equatable {
    /// `VISUALCORE_AUTORUN_EXPERIENCE` is absent or empty.
    case missingExperience
    /// `VISUALCORE_AUTORUN_EXPERIENCE` is not a well-formed experience id.
    case badExperience
    /// `VISUALCORE_AUTORUN_SCENARIO` is absent or empty.
    case missingScenario
    /// The scenario name is not 1 to 64 characters of `a-z`, `0-9` and `-`.
    case badScenario
    /// The seed is not a decimal unsigned 64-bit integer.
    case badSeed
    /// The run id is absent or not 1 to 64 characters of `A-Z`, `a-z`, `0-9` and `-`.
    case badRun
    /// The phase is neither `save` nor `restore`.
    case badPhase
    /// The expected digest is not 64 lower-case hexadecimal digits.
    case badDigest
    /// The value of `key` is longer than `ScenarioRequest.maxValueLength` characters.
    case tooLong(key: String)

    /// The stable code of the refusal, for logs and the evidence record.
    public var code: String {
        switch self {
        case .missingExperience: "request.missing-experience"
        case .badExperience: "request.bad-experience"
        case .missingScenario: "request.missing-scenario"
        case .badScenario: "request.bad-scenario"
        case .badSeed: "request.bad-seed"
        case .badRun: "request.bad-run"
        case .badPhase: "request.bad-phase"
        case .badDigest: "request.bad-digest"
        case .tooLong: "request.too-long"
        }
    }
}

/// One scenario run the driver asks the app for through the launch environment.
public struct ScenarioRequest: Sendable, Equatable {
    /// Which launch of a scenario this is.
    public enum Phase: String, Sendable, Equatable, CaseIterable {
        /// One launch runs the whole scenario (no `VISUALCORE_AUTORUN_PHASE`).
        case single
        /// The first of two launches: run, save, and record the digest.
        case save
        /// The second of two launches: restore and compare with the expected digest.
        case restore
    }

    /// The key that selects an automation mode.
    public static let autorunKey = "VISUALCORE_AUTORUN"
    /// The value of `autorunKey` that asks for a scenario run; any other value is not a scenario request.
    public static let autorunValue = "scenario"
    /// The key of the experience id.
    public static let experienceKey = "VISUALCORE_AUTORUN_EXPERIENCE"
    /// The key of the scenario name.
    public static let scenarioKey = "VISUALCORE_AUTORUN_SCENARIO"
    /// The key of the decimal seed.
    public static let seedKey = "VISUALCORE_AUTORUN_SEED"
    /// The key of the run id.
    public static let runKey = "VISUALCORE_AUTORUN_RUN"
    /// The key of the phase: `save` or `restore`.
    public static let phaseKey = "VISUALCORE_AUTORUN_PHASE"
    /// The key of the digest the restore phase expects.
    public static let expectedDigestKey = "VISUALCORE_AUTORUN_EXPECTED_DIGEST"
    /// The longest value any request key may have, in characters.
    public static let maxValueLength = 256
    /// The longest scenario name or run id, in characters.
    public static let maxNameLength = 64

    /// The experience to run.
    public let experience: ExperienceID
    /// The scenario name, for example `launch-first-frame`.
    public let scenario: String
    /// The seed, or `nil` for the scenario's own seed.
    public let seed: UInt64?
    /// The run id the evidence record carries.
    public let run: String
    /// Which launch of the scenario this is.
    public let phase: Phase
    /// The digest the restore phase expects; `nil` when none was given.
    public let expectedDigest: StateDigest?

    /// Creates a request.
    public init(experience: ExperienceID, scenario: String, seed: UInt64? = nil, run: String,
                phase: Phase = .single, expectedDigest: StateDigest? = nil) {
        self.experience = experience
        self.scenario = scenario
        self.seed = seed
        self.run = run
        self.phase = phase
        self.expectedDigest = expectedDigest
    }

    /// Reads a request from a launch environment. `nil` when `VISUALCORE_AUTORUN` is absent or is not exactly
    /// `scenario` (the older automation modes such as `smoke` are not scenario requests); otherwise the request or
    /// the first refusal, checked in the order: length, experience, scenario, seed, run, phase, digest.
    public static func parse(_ environment: [String: String]) -> Result<ScenarioRequest, ScenarioRequestError>? {
        guard environment[autorunKey] == autorunValue else { return nil }
        for key in [experienceKey, scenarioKey, seedKey, runKey, phaseKey, expectedDigestKey] {
            if let value = environment[key], value.count > maxValueLength { return .failure(.tooLong(key: key)) }
        }
        guard let experienceText = environment[experienceKey], !experienceText.isEmpty else {
            return .failure(.missingExperience)
        }
        guard let experience = ExperienceID(rawValue: experienceText) else { return .failure(.badExperience) }
        guard let scenario = environment[scenarioKey], !scenario.isEmpty else { return .failure(.missingScenario) }
        guard isName(scenario, upperCase: false) else { return .failure(.badScenario) }
        var seed: UInt64?
        if let seedText = environment[seedKey] {
            guard !seedText.isEmpty, seedText.utf8.allSatisfy({ (48...57).contains($0) }),
                  let value = UInt64(seedText) else { return .failure(.badSeed) }
            seed = value
        }
        guard let run = environment[runKey], isName(run, upperCase: true) else { return .failure(.badRun) }
        var phase = Phase.single
        if let phaseText = environment[phaseKey] {
            switch phaseText {
            case Phase.save.rawValue: phase = .save
            case Phase.restore.rawValue: phase = .restore
            default: return .failure(.badPhase)
            }
        }
        var expectedDigest: StateDigest?
        if let digestText = environment[expectedDigestKey] {
            guard let digest = StateDigest(hex: digestText) else { return .failure(.badDigest) }
            expectedDigest = digest
        }
        return .success(ScenarioRequest(experience: experience, scenario: scenario, seed: seed, run: run,
                                        phase: phase, expectedDigest: expectedDigest))
    }

    /// Whether the text has 1 to 64 characters of `a-z`, `0-9` and `-`, plus `A-Z` when `upperCase` is true.
    private static func isName(_ text: String, upperCase: Bool) -> Bool {
        let bytes = text.utf8
        guard (1...maxNameLength).contains(bytes.count) else { return false }
        return bytes.allSatisfy { byte in
            (97...122).contains(byte) || (48...57).contains(byte) || byte == 45 || (upperCase && (65...90).contains(byte))
        }
    }
}
#endif
