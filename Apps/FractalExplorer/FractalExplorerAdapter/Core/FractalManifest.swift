// FractalManifest — feature 193 (UA-F07) T-U07-024 (FR-U07-012; data-model section 3; feature 195). The scenarios the
// verification runner plays for Fractal Explorer: the nine standard ones and one `fixture-<n>` per regression fixture of
// the A03 card (docs/catalog/experience-catalog.json, `design.fixtures`). Committed digests hold for the manifest seed
// and are checked against the engine by the host tests.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience

extension FractalCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The digest right after a preparation with `manifestSeed`.
    public static let initialDigest = "828f52ae183962728bfe30dcc2c37f2054d173ffc78caa97e876c109258865e0"
    /// The digest after the input entries.
    public static let inputDigest = "f992c333171a07d1b2b690a1d8727ff90648634d6dca0d186710913bae9520b5"
    /// The digests after the entries of the five fixtures.
    public static let fixtureDigests = [
        "ad9d56a5cc52d9230e5e0c8569394b12d2c2d91a5fe621b5ef01ec6b5cd06c7b",
        "fd0da17850d4e92387d97de6770a936571768a148c1b24143e9add028c9db053",
        "a8d85b0c2244c741ae9bbcff6308b70fedf64fa8483f1b8697d5e8c1d34f29b9",
        "2cb5e913d5ac7504fd0397ac4b55e00f56d25ee355f6cfa32015183fb043d9fa",
        "8e64ff6177ba535649ee1ff47e102417787d5aa98d8181dc939a9e49c0fc971d",
    ]

    /// The actions of input-response, save-restore and reset: a pan, a pinch, a zoom, a cap change and a palette.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 6, action: ScriptedAction("pan", [0.1, -0.05]), result: "accepted"),
         ScenarioStep(steps: 6, action: ScriptedAction("pinch", [1.5, 0.1, 0.1]), result: "accepted"),
         ScenarioStep(steps: 6, action: ScriptedAction("zoomIn"), result: "accepted"),
         ScenarioStep(steps: 6, action: ScriptedAction("cap.up"), result: "accepted"),
         ScenarioStep(steps: 6, action: ScriptedAction("palette", [2]), result: "accepted")]
    }

    /// The entries of the five fixtures, in the order of the card.
    public static var fixtureEntries: [[ScenarioStep]] {
        // 1. Known points: the Mandelbrot origin's interior, then a Julia view of a known seed.
        let known = [ScenarioStep(steps: 2, action: ScriptedAction("goTo", [0, 0, 20]), result: "accepted"),
                     ScenarioStep(steps: 2, action: ScriptedAction("mode", [1]), result: "accepted"),
                     ScenarioStep(steps: 2, action: ScriptedAction("seed", [-0.8, 0.156]), result: "accepted")]
        // 2. A centred pinch keeps the centre's coordinate: three pinches about the centre.
        let pinches = (0..<3).map { _ in
            ScenarioStep(steps: 2, action: ScriptedAction("pinch", [2, 0, 0]), result: "accepted")
        }
        // 3. Aspect changes keep the centre: the framing has no size; pans in both directions return to it.
        let aspect = [ScenarioStep(steps: 2, action: ScriptedAction("pan", [0.25, 0]), result: "accepted"),
                      ScenarioStep(steps: 2, action: ScriptedAction("pan", [-0.25, 0]), result: "accepted")]
        // 4. The precision limit: a go-to past it is clamped at the limit's span.
        let limit = [ScenarioStep(steps: 2, action: ScriptedAction("goTo", [-0.743643887, 0.131825904, 1e15]),
                                  result: "accepted")]
        // 5. A bookmark opens to the same view: its values in, the same framing out.
        let bookmark = [ScenarioStep(steps: 2, action: ScriptedAction("bookmark.open",
                                                                      [1, 0.1, -0.2, 0.75, -0.4, 0.6, 400, 3]),
                                     result: "accepted")]
        return [known, pinches, aspect, limit, bookmark]
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
            ScenarioSpec(name: "completion", seed: seed, entries: (0..<10).map { _ in
                ScenarioStep(steps: 2, action: ScriptedAction("zoomIn"), result: "accepted")
            }, expect: ScenarioExpectations(outcome: "deep-zoom")),
            ScenarioSpec(name: "rejection", seed: seed, entries: [
                ScenarioStep(steps: 0, action: ScriptedAction("mode", [0]), result: "action.rule.a03.same-mode"),
                ScenarioStep(steps: 0, action: ScriptedAction("palette", [9]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("tour.stop"), result: "action.rule.a03.no-tour"),
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
