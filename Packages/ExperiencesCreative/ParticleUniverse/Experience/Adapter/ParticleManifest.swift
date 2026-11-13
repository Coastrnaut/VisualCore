// ParticleManifest — feature 193 (UA-F07) T-U07-027 (FR-U07-012; data-model section 3; feature 195). The scenarios the
// verification runner plays for Particle Universe: the nine standard ones and one `fixture-<n>` per regression fixture
// of the A04 card (docs/catalog/experience-catalog.json, `design.fixtures`). All short (owner rule of 2026-11-13).
// Committed digests hold for the manifest seed and are checked against the engine by the host tests.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience

extension ParticleCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The digest right after a preparation with `manifestSeed`.
    public static let initialDigest = "901c2f8be5b4ddafe8451c6f277b3f1c80e218df373823c99e6716a4859ea65f"
    /// The digest after the input entries.
    public static let inputDigest = "0960cb630842b06242438442981217215185ed16b55ca0a8ec9de763ebefa29a"
    /// The digests after the entries of the five fixtures.
    public static let fixtureDigests = [
        "fdb8709fae72b31ff06917ce9e0773932a0351a684c7d811bc4635174882cc81",
        "155e831ff3ec71668719285b624cb7b8fa9cbffd8aa6353a334ba298b58bdab5",
        "56a07300a8f81771098721325fc3441250832fb0eb607f4400917344e9286814",
        "cc0245a37c87c57277c5310b03ddd7f34fb09ed6a51d0e1489ce93bccef37d4b",
        "be6863ad0cd7a945fdfc8fc4ab044a0a7697889afa05383c77566b3cb10c4b27",
    ]

    /// The actions of input-response, save-restore and reset: an emitter, a force, a family, a size.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 30, action: ScriptedAction("emitter.add"), result: "accepted"),
         ScenarioStep(steps: 30, action: ScriptedAction("force.place", [0.75, 0.25]), result: "accepted"),
         ScenarioStep(steps: 30, action: ScriptedAction("family", [2]), result: "accepted"),
         ScenarioStep(steps: 30, action: ScriptedAction("size", [16]), result: "accepted")]
    }

    /// The entries of the five fixtures, in the order of the card.
    public static var fixtureEntries: [[ScenarioStep]] {
        // 1. Seed, controls and the fixed-step stream reproduce the state: a scripted stream of steps and controls.
        let stream = [ScenarioStep(steps: 60, action: ScriptedAction("force.place", [0.25, 0.75]), result: "accepted"),
                      ScenarioStep(steps: 60, action: ScriptedAction("strength", [2]), result: "accepted"),
                      ScenarioStep(steps: 60, action: ScriptedAction("force.nudge", [50, -50]), result: "accepted")]
        // 2. Many emitters respect the scene's cap: seven more Firework emitters.
        let cap = [ScenarioStep(steps: 2, action: ScriptedAction("family", [3]), result: "accepted")]
            + (0..<7).map { _ in ScenarioStep(steps: 10, action: ScriptedAction("emitter.add"), result: "accepted") }
            + [ScenarioStep(steps: 2, action: ScriptedAction("emitter.add"), result: "action.rule.a04.emitters-full")]
        // 3. Trails on and off with a new seed between (the trail buffers are rebuilt without leaks at the close).
        let trails = [ScenarioStep(steps: 20, action: ScriptedAction("trails", [1]), result: "accepted"),
                      ScenarioStep(steps: 20, action: ScriptedAction("reseed"), result: "accepted"),
                      ScenarioStep(steps: 20, action: ScriptedAction("trails", [0]), result: "accepted")]
        // 4. A force at an emitter's position (a singularity) keeps every particle finite.
        let singular = [ScenarioStep(steps: 2, action: ScriptedAction("force.kind", [1]), result: "accepted"),
                        ScenarioStep(steps: 2, action: ScriptedAction("force.place", [0.5, 0.5]), result: "accepted"),
                        ScenarioStep(steps: 120, action: ScriptedAction("strength", [2]), result: "accepted")]
        // 5. Pause and play: paused steps hold the state; play does not catch up.
        let resume = [ScenarioStep(steps: 10, action: ScriptedAction("pause"), result: "accepted"),
                      ScenarioStep(steps: 120, action: ScriptedAction("play"), result: "accepted")]
        return [stream, cap, trails, singular, resume]
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
                ScenarioStep(steps: 10, action: ScriptedAction("emitter.add"), result: "accepted"),
                ScenarioStep(steps: 10, action: ScriptedAction("emitter.add"), result: "accepted"),
            ], expect: ScenarioExpectations(outcome: "scene-built")),
            ScenarioSpec(name: "rejection", seed: seed, entries: [
                ScenarioStep(steps: 0, action: ScriptedAction("play"), result: "action.rule.a04.already-playing"),
                ScenarioStep(steps: 0, action: ScriptedAction("emitter.remove"), result: "action.rule.a04.last-emitter"),
                ScenarioStep(steps: 0, action: ScriptedAction("family", [9]), result: "action.out-of-range"),
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
