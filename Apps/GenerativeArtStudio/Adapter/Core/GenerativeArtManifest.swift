// GenerativeArtManifest — feature 193 (UA-F07) T-U07-009 (FR-U07-012; data-model section 3; feature 195). The
// scenarios the verification runner plays for Generative Art Studio: the nine standard ones and one `fixture-<n>`
// per regression fixture of the A01 card (docs/catalog/experience-catalog.json, `design.fixtures`). Committed digests
// hold for the manifest seed and are checked against the engine by the host tests.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience

extension GenerativeArtCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The digest right after a preparation with `manifestSeed`.
    public static let initialDigest = "9076cbcf0933978bd8a31f9dc8c99dcaa8c25534557a696191d2659198f60d9c"
    /// The digest after the input entries.
    public static let inputDigest = "a3c37c2844586b07dc9473a74a10771787e7379ad9edb662b716a63a0076fe15"
    /// The digests after the entries of fixtures 1, 2 and 4 (fixture 3 commits none; fixture 5 ends where a
    /// preparation starts, at the Particles default with time 0, so its final digest is `initialDigest`).
    public static let fixtureDigests = [
        "15696485a5179adae658f73a32f706a8dac4a4e5d1e1f406689d12ca8e1e3673",
        "c23152fa33ef55730e06ac2c5403e29cbe7f287d961cfce2333dfb2ff0b08cac",
        "fef495ea264017480da2554d5e45f25e4799d9c51cbe4d3cfaa437f1052f864f",
    ]

    /// The actions of input-response, save-restore and reset: a palette, a parameter, a shuffle, a pause and a
    /// scrub, six steps apart.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 6, action: ScriptedAction("palette", [5]), result: "accepted"),
         ScenarioStep(steps: 6, action: ScriptedAction("parameter.size", [0.8]), result: "accepted"),
         ScenarioStep(steps: 6, action: ScriptedAction("seed.shuffle"), result: "accepted"),
         ScenarioStep(steps: 6, action: ScriptedAction("pause"), result: "accepted"),
         ScenarioStep(steps: 6, action: ScriptedAction("scrub", [12]), result: "accepted")]
    }

    /// The entries of the five fixtures, in the order of the card.
    public static var fixtureEntries: [[ScenarioStep]] {
        // 1. Same seed and explicit time: a family, a seed, a value and a paused time give one state.
        let explicitTime = [
            ScenarioStep(steps: 4, action: ScriptedAction("family", [0]), result: "accepted"),
            ScenarioStep(steps: 4, action: ScriptedAction("seed.set", [0, 2024]), result: "accepted"),
            ScenarioStep(steps: 4, action: ScriptedAction("parameter.scale", [0.6]), result: "accepted"),
            ScenarioStep(steps: 4, action: ScriptedAction("pause"), result: "accepted"),
            ScenarioStep(steps: 4, action: ScriptedAction("scrub", [42.5]), result: "accepted"),
        ]
        // 2. Corrupt or newer values surface as recoverable rejections and change nothing.
        let corrupt = [
            ScenarioStep(steps: 2, action: ScriptedAction("open", [0, 99, 0, 1, 0]), result: "action.out-of-range"),
            ScenarioStep(steps: 2, action: ScriptedAction("value.size", [.infinity]), result: "action.non-finite"),
            ScenarioStep(steps: 2, action: ScriptedAction("parameter.cells", [0.5]),
                         result: "action.rule.a01.no-parameter"),
            ScenarioStep(steps: 2, action: ScriptedAction("scrub", [-1]), result: "action.out-of-range"),
        ]
        // 3. Rapid palette edits: forty in a row, one step apart; the close finds no live GPU object.
        let rapid = (0..<40).map { index in
            ScenarioStep(steps: 1, action: ScriptedAction("palette", [Double(index % 6)]), result: "accepted")
        }
        // 4. Export at an explicit time: a paused picture of another family at a chosen time.
        let explicitPicture = [
            ScenarioStep(steps: 3, action: ScriptedAction("family", [2]), result: "accepted"),
            ScenarioStep(steps: 3, action: ScriptedAction("pause"), result: "accepted"),
            ScenarioStep(steps: 3, action: ScriptedAction("scrub", [30]), result: "accepted"),
        ]
        // 5. Recreation: every family switch tears the scene down and builds the next one with fresh GPU objects.
        let recreation = [1.0, 3, 0, 2, 3].map { family in
            ScenarioStep(steps: 30, action: ScriptedAction("family", [family]), result: "accepted")
        }
        return [explicitTime, corrupt, rapid, explicitPicture, recreation]
    }

    /// The manifest of the experience `id`.
    public static func manifest(for id: ExperienceID, seed: UInt64 = manifestSeed) -> ScenarioManifest {
        let committed = seed == manifestSeed
        let initial = committed ? initialDigest : nil
        let input = inputEntries
        let fixtures = fixtureEntries
        let fixtureFinal: [String?] = committed
            ? [fixtureDigests[0], fixtureDigests[1], nil, fixtureDigests[2], initialDigest]
            : [nil, nil, nil, nil, nil]
        var specs = [
            ScenarioSpec(name: "launch-first-frame", seed: seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: initial)),
            ScenarioSpec(name: "input-response", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial,
                                                      finalDigest: committed ? inputDigest : nil)),
            ScenarioSpec(name: "completion", seed: seed, entries: [
                ScenarioStep(steps: 6, action: ScriptedAction("parameter.gravity", [0.3]), result: "accepted"),
                ScenarioStep(steps: 6, action: ScriptedAction("save"), result: "accepted"),
            ], expect: ScenarioExpectations(outcome: "work-saved")),
            ScenarioSpec(name: "rejection", seed: seed, entries: [
                ScenarioStep(steps: 0, action: ScriptedAction("family", [9]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("parameter.cells", [0.5]),
                             result: "action.rule.a01.no-parameter"),
                ScenarioStep(steps: 0, action: ScriptedAction("tour"), result: "action.unknown-control"),
            ]),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial,
                                                      finalDigest: committed ? inputDigest : nil)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        for (index, entries) in fixtures.enumerated() {
            specs.append(ScenarioSpec(name: "fixture-\(index + 1)", seed: seed, entries: entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: fixtureFinal[index])))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
