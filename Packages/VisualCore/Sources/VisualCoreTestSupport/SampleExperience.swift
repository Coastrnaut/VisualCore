// SampleExperience — feature 188 T-U02-014 (FR-U02-072; data-model section 7; contract
// specs/188-ua-f02-experience-sdk/contracts/experience-core-api.md, section "Sample"). The id of the sample
// experience and the ingredients of its conformance plan. Test-only (rule R5).
import Foundation
import VisualCoreExperience

/// The constants of the sample experience `a99.contract-sample`, which exists only for tests.
public enum SampleExperience {
    // MARK: - Identity

    /// The id of the sample: `a99.contract-sample`.
    public static let id: ExperienceID = parsedID("a99.contract-sample")

    /// The id for a text that is a compile-time constant of this file.
    private static func parsedID(_ text: String) -> ExperienceID {
        guard let id = ExperienceID(rawValue: text) else {
            // Cannot happen: the only caller passes a well-formed constant. This module is linked by tests only,
            // so a wrong constant stops the test run here instead of travelling on as a wrong id.
            preconditionFailure("the sample id \(text) is malformed")
        }
        return id
    }

    // MARK: - Ingredients of the conformance plan

    /// The seeds of the conformance plan: 0, 1, 42 and the largest 64-bit value.
    public static let seeds: [UInt64] = [0, 1, 42, .max]

    /// The number of steps between two actions of the conformance plan.
    public static let stepsPerSegment = 30

    /// The actions the sample accepts: `tone` 0.5, `ping`, `tone` 0.25.
    public static let acceptedActions: [ScriptedAction] = [
        ScriptedAction("tone", [0.5]),
        ScriptedAction("ping"),
        ScriptedAction("tone", [0.25]),
    ]

    /// The actions the sample rejects: `move` 0, 0 (rule `sample.no-move`) and `tone` 2 (out of range).
    public static let rejectedActions: [ScriptedAction] = [
        ScriptedAction("move", [0, 0]),
        ScriptedAction("tone", [2]),
    ]

    // MARK: - Conformance plan (T-U02-040)

    // MARK: - Committed digests (T-U02-017)

    // MARK: - Version-1 snapshot (migration tests)
}
