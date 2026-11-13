// ScenarioManifestValidator — feature 195 T-U09-005 (FR-U09-002, FR-U09-003, FR-U09-005; data-model section 2).
// The pure checks a scenario manifest must pass before the runner plays it: the standard scenarios, well-formed
// unique names, the limits, actions that name declared controls with the right number of values, expectations that
// follow an action, and the content a game or a creative experience must cover. Compiles only under DEBUG or
// VISUALCORE_AUTOMATION.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation

/// The checks on a scenario manifest; every problem is a readable text that names the scenario it concerns.
public enum ScenarioManifestValidator {
    /// The most scenarios a manifest may have.
    public static let maxScenarios = 1_000
    /// The most entries a scenario may have.
    public static let maxEntries = 10_000
    /// The legal number of steps of one entry.
    public static let stepRange = 0...100_000
    /// The legal number of teardown and reentry cycles.
    public static let cycleRange = 1...50
    /// The legal number of seconds of an endurance scenario.
    public static let secondRange = 1...600
    /// The scenarios in which an expectation needs no action before it.
    public static let scenariosWithoutActions: Set<String> = ["launch-first-frame", "reset"]

    /// Returns every problem of `manifest`, in a stable order; an empty list means the manifest is valid.
    ///
    /// - Parameters:
    ///   - manifest: The manifest to check.
    ///   - controls: The controls the experience declares; an action must name one and carry one value per range.
    ///   - content: The content the experience must cover (fixtures, acceptance and fault scenarios).
    public static func problems(_ manifest: ScenarioManifest, controls: [ExperienceControl],
                                content: ContentRequirement) -> [String] {
        var problems: [String] = []
        let names = manifest.scenarios.map(\.name)
        let present = Set(names)

        if manifest.scenarios.count > maxScenarios {
            problems.append("too many scenarios: \(manifest.scenarios.count) (at most \(maxScenarios))")
        }
        for name in ScenarioManifest.standardNames where !present.contains(name) {
            problems.append("missing scenario \(name)")
        }
        var seen: Set<String> = []
        var reported: Set<String> = []
        for name in names {
            if !seen.insert(name).inserted, reported.insert(name).inserted {
                problems.append("duplicate scenario \(name)")
            }
        }
        for spec in manifest.scenarios {
            problems += scenarioProblems(spec, controls: controls)
        }

        switch manifest.kind {
        case .game:
            for name in ["full-playthrough", "hero"] where !present.contains(name) {
                problems.append("missing scenario \(name)")
            }
            let acceptance = present.filter { $0.hasPrefix("acceptance-") }.count
            if acceptance < content.acceptance {
                problems.append("too few acceptance scenarios: \(acceptance) of \(content.acceptance)")
            }
            if let round = manifest.round {
                if !(2...4).contains(round) {
                    problems.append("game round \(round) is not 2, 3 or 4")
                } else if round >= 3 {
                    let faults = present.filter { $0.hasPrefix("fault-") }.count
                    if faults < content.faults {
                        problems.append("too few fault scenarios: \(faults) of \(content.faults)")
                    }
                }
            } else {
                problems.append("game without a round")
            }
        case .creative:
            let fixtures = present.filter { $0.hasPrefix("fixture-") }.count
            if fixtures < content.fixtures {
                problems.append("too few fixture scenarios: \(fixtures) of \(content.fixtures)")
            }
        }
        return problems
    }

    /// Whether `name` has 1 to 64 characters of `a-z`, `0-9` and `-`.
    public static func isValidName(_ name: String) -> Bool {
        let bytes = name.utf8
        return (1...64).contains(bytes.count)
            && bytes.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
    }

    /// Whether `text` is 64 lower-case hexadecimal digits.
    static func isDigest(_ text: String) -> Bool {
        let bytes = text.utf8
        return bytes.count == 64 && bytes.allSatisfy { (97...102).contains($0) || (48...57).contains($0) }
    }

    /// The problems of one scenario, each starting with `scenario <name>:`.
    private static func scenarioProblems(_ spec: ScenarioSpec, controls: [ExperienceControl]) -> [String] {
        var problems: [String] = []
        let label = "scenario \(spec.name)"
        if !isValidName(spec.name) {
            problems.append("\(label): the name is not 1 to 64 characters of a-z, 0-9 and -")
        }
        if spec.entries.count > maxEntries {
            problems.append("\(label): too many entries: \(spec.entries.count) (at most \(maxEntries))")
        }
        if let cycles = spec.cycles, !cycleRange.contains(cycles) {
            problems.append("\(label): cycles \(cycles) outside 1…50")
        }
        if let seconds = spec.seconds, !secondRange.contains(seconds) {
            problems.append("\(label): seconds \(seconds) outside 1…600")
        }
        let needsNoAction = scenariosWithoutActions.contains(spec.name)
        var actionSeen = false
        var totalSteps = 0
        for (index, entry) in spec.entries.enumerated() {
            if !stepRange.contains(entry.steps) {
                problems.append("\(label): entry \(index + 1): steps \(entry.steps) outside 0…100000")
            }
            totalSteps += max(entry.steps, 0)
            if let action = entry.action {
                actionSeen = true
                // A rejection scenario (and a fault case) sends invalid actions on purpose: an unknown control or a
                // wrong value count is allowed there when the entry expects a rejection.
                let invalidOnPurpose = (spec.name == "rejection" || spec.name.hasPrefix("fault-"))
                    && (entry.result.map { $0 != "accepted" } ?? false)
                if invalidOnPurpose {
                    // nothing to check: the expected rejection code is compared when the scenario runs
                } else if let control = controls.first(where: { $0.id == action.control }) {
                    if action.values.count != control.ranges.count {
                        problems.append("\(label): control \(control.id) takes \(control.ranges.count) values, "
                            + "entry \(index + 1) gives \(action.values.count)")
                    }
                } else {
                    problems.append("\(label): unknown control \(action.control)")
                }
            } else if entry.result != nil {
                problems.append("\(label): entry \(index + 1): result expected without an action")
            }
            if let digest = entry.digest {
                if !isDigest(digest) {
                    problems.append("\(label): entry \(index + 1): digest is not 64 lower-case hexadecimal digits")
                }
                if !actionSeen, !needsNoAction {
                    problems.append("\(label): entry \(index + 1) digest expected without an action before it")
                }
            }
        }
        if totalSteps > ExperienceScenario.maxSteps {
            problems.append("\(label): \(totalSteps) steps in total (at most \(ExperienceScenario.maxSteps))")
        }
        if let digest = spec.expect.initialDigest, !isDigest(digest) {
            problems.append("\(label): initial digest is not 64 lower-case hexadecimal digits")
        }
        if let digest = spec.expect.finalDigest {
            if !isDigest(digest) {
                problems.append("\(label): final digest is not 64 lower-case hexadecimal digits")
            }
            if !actionSeen, !needsNoAction {
                problems.append("\(label): final digest expected without an action before it")
            }
        }
        if spec.expect.outcome != nil, !actionSeen, !needsNoAction {
            problems.append("\(label): outcome expected without an action before it")
        }
        return problems
    }
}
#endif
