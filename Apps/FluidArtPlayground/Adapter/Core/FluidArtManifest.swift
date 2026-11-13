// FluidArtManifest — feature 193 (UA-F07) T-U07-021 (FR-U07-012; data-model section 3; feature 195). The scenarios
// the verification runner plays for Fluid Art Playground: the nine standard ones and one `fixture-<n>` per regression
// fixture of the A02 card (docs/catalog/experience-catalog.json, `design.fixtures`). The fixtures check the CPU state
// that drives the fields (ADR-0011); the GPU behaviour of each fixture stays covered by the app's field tests.
// Committed digests hold for the manifest seed and are checked against the engine by the host tests.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience

extension FluidArtCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The digest right after a preparation with `manifestSeed`.
    public static let initialDigest = "6035fe8d3405d03f48880b318ab10086e66ee6a5bd777c560f695342f1c68fdd"
    /// The digest after the input entries.
    public static let inputDigest = "a039e29a4dedc96123bc6e4068e48085defd39d1e274b5e2b7ae9b487cfc748d"
    /// The digests after the entries of the five fixtures.
    public static let fixtureDigests = [
        "77c5cd40173b9e8c7faa97faacd300c5c4c6d01ed6384a1f30396dc6ad73c6e7",
        "6ad5fdcd80201c97f823d2c95107ae6dbae78c0d2eb351b4cdcde42a9e582460",
        "e8506ab6c8dcddd26ea0e2747bd90bf16407bbce20475460c3c7011b3a8cf67b",
        "23d913fa785a69e3dc72388cdc6d16b95d3baaf4e662b56b3e0f41a963332bc5",
        "44397d97fccf53720579cd2493ac5d51e4d95ce81b19cfafb7d7a0741e732222",
    ]

    /// A stroke sample: position and velocity normalized to the view, phase (0 began, 1 moved, 2 ended), pointer.
    static func stroke(_ x: Double, _ y: Double, _ vx: Double, _ vy: Double, phase: Double, pointer: Double = 1)
        -> ScriptedAction {
        ScriptedAction("stroke", [x, y, vx, vy, phase, pointer])
    }

    /// The actions of input-response, save-restore and reset: one stroke across the canvas, a splash, a palette.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 4, action: stroke(0.2, 0.5, 0, 0, phase: 0), result: "accepted"),
         ScenarioStep(steps: 2, action: stroke(0.4, 0.45, 1.2, -0.3, phase: 1), result: "accepted"),
         ScenarioStep(steps: 2, action: stroke(0.6, 0.4, 1.2, -0.3, phase: 2), result: "accepted"),
         ScenarioStep(steps: 4, action: ScriptedAction("splash"), result: "accepted"),
         ScenarioStep(steps: 4, action: ScriptedAction("palette", [0]), result: "accepted")]
    }

    /// The entries of the five fixtures, in the order of the card.
    public static var fixtureEntries: [[ScenarioStep]] {
        // 1. Dye at rest decays only by the configured dissipation: a fade is set and the fluid runs untouched.
        let decay = [ScenarioStep(steps: 2, action: ScriptedAction("dyeFade", [2]), result: "accepted"),
                     ScenarioStep(steps: 120, action: ScriptedAction("motionFade", [0.5]), result: "accepted")]
        // 2. Zero velocity keeps the pattern bounded: no input, many steps, then a pause.
        let atRest = [ScenarioStep(steps: 240, action: ScriptedAction("pause"), result: "accepted")]
        // 3. Boundary modes: strokes toward both edges in open and in walls mode.
        let edges = [ScenarioStep(steps: 2, action: ScriptedAction("edges", [1]), result: "accepted"),
                     ScenarioStep(steps: 2, action: stroke(0.02, 0.5, -3, 0, phase: 0), result: "accepted"),
                     ScenarioStep(steps: 2, action: stroke(0.01, 0.5, -3, 0, phase: 2), result: "accepted"),
                     ScenarioStep(steps: 20, action: ScriptedAction("edges", [0]), result: "accepted"),
                     ScenarioStep(steps: 2, action: stroke(0.98, 0.5, 3, 0, phase: 0, pointer: 2), result: "accepted"),
                     ScenarioStep(steps: 2, action: stroke(0.99, 0.5, 3, 0, phase: 2, pointer: 2), result: "accepted")]
        // 4. Ping-pong passes: many splats and splashes over many steps at every detail level.
        let passes = [ScenarioStep(steps: 2, action: ScriptedAction("detail", [0]), result: "accepted"),
                      ScenarioStep(steps: 2, action: ScriptedAction("splash"), result: "accepted"),
                      ScenarioStep(steps: 10, action: ScriptedAction("detail", [2]), result: "accepted"),
                      ScenarioStep(steps: 2, action: ScriptedAction("splash"), result: "accepted"),
                      ScenarioStep(steps: 10, action: ScriptedAction("detail", [1]), result: "accepted")]
        // 5. Suspend and resume: paused time runs no step; one `step` runs exactly one.
        let catchUp = [ScenarioStep(steps: 2, action: ScriptedAction("pause"), result: "accepted"),
                       ScenarioStep(steps: 300, action: ScriptedAction("step"), result: "accepted"),
                       ScenarioStep(steps: 300, action: ScriptedAction("resume"), result: "accepted")]
        return [decay, atRest, edges, passes, catchUp]
    }

    /// The manifest of the experience `id`.
    public static func manifest(for id: ExperienceID, seed: UInt64 = manifestSeed) -> ScenarioManifest {
        let committed = seed == manifestSeed
        let initial = committed ? initialDigest : nil
        let input = inputEntries
        var specs = [
            ScenarioSpec(name: "launch-first-frame", seed: seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: initial)),
            ScenarioSpec(name: "input-response", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial,
                                                      finalDigest: committed ? inputDigest : nil)),
            ScenarioSpec(name: "completion", seed: seed, entries: [
                ScenarioStep(steps: 2, action: ScriptedAction("splash"), result: "accepted"),
                ScenarioStep(steps: 2, action: ScriptedAction("splash"), result: "accepted"),
            ], expect: ScenarioExpectations(outcome: "canvas-painted")),
            ScenarioSpec(name: "rejection", seed: seed, entries: [
                ScenarioStep(steps: 0, action: ScriptedAction("step"), result: "action.rule.a02.not-paused"),
                ScenarioStep(steps: 0, action: ScriptedAction("palette", [5]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("stroke", [0.5, 0.5]), result: "action.wrong-value-count"),
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
        for (index, entries) in fixtureEntries.enumerated() {
            specs.append(ScenarioSpec(name: "fixture-\(index + 1)", seed: seed, entries: entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: committed ? fixtureDigests[index] : nil)))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
