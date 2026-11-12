// ExperienceScenario — feature 188 T-U02-030 (FR-U02-062; research R9; contract specs/188-ua-f02-experience-sdk/
// contracts/experience-core-api.md, section "Automation hooks"). Scenario hooks for automation: a script of seed,
// steps and actions, and its result. The whole file compiles only under DEBUG or VISUALCORE_AUTOMATION, so a shipping
// release build contains none of it (scripts/check_experience_symbols.py proves that).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation

/// A script for one experience: a seed and a list of entries, each a number of steps and then an optional action.
public struct ExperienceScenario: Sendable, Equatable, Codable {
    /// One entry: run `steps` fixed steps, then carry out `action` if there is one.
    public struct Entry: Sendable, Equatable, Codable {
        /// Steps to run before the action; a negative number counts as 0.
        public let steps: Int
        /// The action to carry out after the steps.
        public let action: ScriptedAction?

        /// Creates an entry.
        public init(steps: Int, action: ScriptedAction? = nil) {
            self.steps = steps
            self.action = action
        }
    }

    /// The most entries a scenario may have.
    public static let maxEntries = 10_000
    /// The most steps a scenario may run in total.
    public static let maxSteps = 1_000_000
    /// The code reported for a scenario beyond the limits.
    public static let tooLargeCode = "experience.scenario-too-large"

    /// The seed the experience is prepared with by `runScenario`.
    public let seed: UInt64
    /// The entries, run in order.
    public let entries: [Entry]

    /// Creates a scenario.
    public init(seed: UInt64, entries: [Entry]) {
        self.seed = seed
        self.entries = entries
    }

    /// Whether the scenario is within the limits.
    public var isWithinLimits: Bool {
        guard entries.count <= Self.maxEntries else { return false }
        var total = 0
        for entry in entries {
            total += max(entry.steps, 0)
            if total > Self.maxSteps { return false }
        }
        return true
    }
}

/// What a scenario run reports.
public struct ExperienceScenarioResult: Sendable, Equatable, Codable {
    /// The digest at the end; nil when there is no prepared state.
    public let digest: StateDigest?
    /// The step index at the end.
    public let stepIndex: Int
    /// One code per action of the scenario, in order: `accepted` or the rejection code.
    public let results: [String]
    /// The error that ended the run early, if any.
    public let error: ExperienceFailure?

    /// Creates a result.
    public init(digest: StateDigest?, stepIndex: Int, results: [String], error: ExperienceFailure?) {
        self.digest = digest
        self.stepIndex = stepIndex
        self.results = results
        self.error = error
    }
}

extension ExperienceEngine {
    /// Runs the entries of `scenario` on this engine, which must be active. The scenario's seed is not used here.
    /// A scenario beyond the limits runs nothing and reports `experience.scenario-too-large`.
    public mutating func run(_ scenario: ExperienceScenario) -> ExperienceScenarioResult {
        guard scenario.isWithinLimits else {
            let failure = ExperienceFailure(code: ExperienceScenario.tooLargeCode,
                                            message: "a scenario has at most \(ExperienceScenario.maxEntries) entries and "
                                                + "\(ExperienceScenario.maxSteps) steps")
            return ExperienceScenarioResult(digest: try? digest(), stepIndex: stepIndex, results: [], error: failure)
        }
        var results: [String] = []
        for entry in scenario.entries {
            do {
                try run(steps: entry.steps)
            } catch {
                return ExperienceScenarioResult(digest: try? digest(), stepIndex: stepIndex, results: results,
                                                error: error.failure)
            }
            if let action = entry.action {
                results.append(handle(control: action.control, values: action.values).code)
            }
        }
        return ExperienceScenarioResult(digest: try? digest(), stepIndex: stepIndex, results: results, error: nil)
    }

    /// Prepares a fresh engine with the scenario's seed, activates it and runs the scenario.
    public static func runScenario(_ scenario: ExperienceScenario, id: ExperienceID) async -> ExperienceScenarioResult {
        var engine = ExperienceEngine(id: id)
        do {
            try await engine.prepare(seed: scenario.seed)
            try engine.activate()
        } catch {
            return ExperienceScenarioResult(digest: nil, stepIndex: 0, results: [], error: error.failure)
        }
        return engine.run(scenario)
    }
}
#endif
