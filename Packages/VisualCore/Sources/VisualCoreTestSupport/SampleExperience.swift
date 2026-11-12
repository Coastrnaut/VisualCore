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

    /// The digest of the sample right after preparation, for eight seeds. Computed once on the Mac host; the
    /// simulator runtimes must reproduce every value.
    public static let goldenDigests: [(seed: UInt64, hex: String)] = [
        (0, "ad928107cbbb09a93b8a22848e7965050a1c86db95c28934306a6f39cf227c6d"),
        (1, "b3ab9d97dc84ac84b1b320d8fc82e21eaec91a0d209d21a1a178979204378033"),
        (2, "30ed5ecc2e9888ea409e3437f485fe89f13e4e558e3aa415cf2a19a283d697fb"),
        (42, "bd6c7d36efeb80cea40f3dff946c1af0edef97ab727accc3048bc7ece10600ef"),
        (1_000, "be8ddca6770a9dac0412d23994dd1b434d34aa55929c227fcce7cbc4fe43b9a8"),
        (65_535, "fe218b42efd7bcff12a51a9fad0278c595195c4380caa4a62bec1b60bfad8658"),
        (4_294_967_296, "4a249d904c41200bc8fdfb1651bfb6e39380054b966b1710afdbef82413c738a"),
        (.max, "fb3a8a2a7505aa51296621a97e7c3a6339af08761d5a22bca2731c66ab213312"),
    ]

    /// The digest of the sample prepared with seed 42 after 240 steps.
    public static let digestAfter240Steps = "e1df502ae639bed10e7f3d7aead5c21c68a5c8e3fd0aa869818842b807805839"

    // MARK: - Version-1 snapshot (migration tests)
}
