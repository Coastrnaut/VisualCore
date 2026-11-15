// ArcadeManifest — feature 075 (A10-P01) T-A10-106 (FR-A10-123; SC-A10-106; research D5). The scenarios the
// verification runner plays for Neon Arcade: the nine standard ones and one `fixture-<n>` per regression fixture of
// research D5 that this phase can express through actions, all short (owner rule of 2026-11-13). Host steps advance
// the run, so the expected digests are derived by playing the entries on a core exactly as the engine plays them (the
// steps of an entry, then its action) and digesting it with the experience id as domain, as Digital Aquarium's
// manifest does. The properties themselves are proved by the tests named with each fixture.
#if DEBUG || VISUALCORE_AUTOMATION
import NeonArcadeCore
import VisualCoreExperience

extension ArcadeCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The twelve recorded steering inputs of the replay fixture: (step at which it applies, value), the same record
    /// as `ReplayTests` plays on the bare run.
    public static let recordedInputs: [(step: Int, value: Double)] = [
        (0, 0.6), (45, -0.3), (120, -1.0), (210, 0.25), (300, 1.0), (390, 0.0),
        (480, -0.75), (600, 0.5), (720, -0.2), (850, 0.9), (990, -1.0), (1100, 0.35),
    ]

    /// The number of steps the replay fixture plays.
    public static let replaySteps = 1_200

    /// The actions of input-response, save-restore and reset: steer right, steer half left, pause.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("run.steer", [1]), result: "accepted"),
         ScenarioStep(steps: 30, action: ScriptedAction("run.steer", [-0.5]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("run.pause", [1]), result: "accepted")]
    }

    /// The entries of rejection: a steering value out of range, a pause value out of range, a fractional pause choice
    /// and a restart carrying a value.
    public static var rejectionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 0, action: ScriptedAction("run.steer", [2]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("run.pause", [-1]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("run.pause", [0.5]),
                      result: "action.rule." + ArcadeRule.invalidChoice),
         ScenarioStep(steps: 0, action: ScriptedAction("run.restart", [1]), result: "action.wrong-value-count")]
    }

    /// The recorded inputs as scenario entries: the steps up to each input, the `run.steer` action, and the steps
    /// left up to ``replaySteps``.
    public static var replayEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        var step = 0
        for input in recordedInputs {
            entries.append(ScenarioStep(steps: input.step - step, action: ScriptedAction("run.steer", [input.value]),
                                        result: "accepted"))
            step = input.step
        }
        entries.append(ScenarioStep(steps: replaySteps - step))
        return entries
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (a rejected action changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> ArcadeCore {
        var core = ArcadeCore(seed: seed)
        var step = 0
        for entry in entries {
            for _ in 0..<max(0, entry.steps) {
                core.update(step: step)
                step += 1
            }
            guard let action = entry.action else { continue }
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: step))
        }
        return core
    }

    /// The digest of the core prepared with `seed` after `entries`, computed as the engine computes it; nil when the
    /// digest cannot be written.
    public static func expectedDigest(for id: ExperienceID, seed: UInt64, entries: [ScenarioStep]) -> String? {
        let core = played(seed: seed, entries: entries)
        var builder = DigestBuilder(domain: id.rawValue)
        do { try core.writeDigest(into: &builder) } catch { return nil }
        return builder.finish().hex
    }

    /// The entries of the seven fixtures (research D5):
    /// 1. replay: the twelve recorded steering inputs over 1,200 steps (`ArcadeManifestTests` plays them twice and
    ///    compares score, lives and the events; `ReplayTests` proves it for three seeds on the bare run);
    /// 2. frame pacing: the same entries — the same digest whatever the frame pacing, because the runner steps the
    ///    engine; the frame-time property (frames of 1/30, 1/60 and 1/120 s) is proved by `ArcadeSessionTests`;
    /// 3. swept hit: steering half right from the start, then 500 steps, in which a falling hazard hits the player
    ///    (`ArcadeManifestTests` checks the `hit` event; the swept test catching tunnelling at 4–50× the summed radii
    ///    is proved by `Collision2DTests` and `GameSimulationTests`, since an action cannot place a hazard);
    /// 4. save/restore mid-run: the recorded inputs up to step 600 (the test round-trips the state through its snapshot
    ///    payload and continues both runs identically);
    /// 5. resume without catch-up: steering after 60 steps, a pause, then 300 steps that change nothing (a suspension
    ///    stops host steps the same way; `ArcadeSessionTests` suspends and resumes a session);
    /// 6. catalog: steering left, then 400 steps of spawns from the validated bundled catalog (every spawned object
    ///    names a catalog item; the refusals of malformed catalogs are proved by `ArcadeCatalogTests`);
    /// 7. bounded objects: steering alternating hard left and right every 200 steps over 2,400 steps (at most 24
    ///    objects, the player inside the field and a valid run throughout; 10,000-step runs over 20 seeds are proved
    ///    by `GameSimulationTests`).
    public static var fixtureEntries: [[ScenarioStep]] {
        func step(_ control: String, _ values: [Double], steps: Int = 0) -> ScenarioStep {
            ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
        }
        let replay = replayEntries
        var halfway: [ScenarioStep] = []
        var step600 = 0
        for input in recordedInputs where input.step <= 600 {
            halfway.append(step("run.steer", [input.value], steps: input.step - step600))
            step600 = input.step
        }
        halfway.append(ScenarioStep(steps: 600 - step600))
        return [
            replay,
            replay,
            [step("run.steer", [0.5]), ScenarioStep(steps: 500)],
            halfway,
            [step("run.steer", [0.5], steps: 60), step("run.pause", [1]), ScenarioStep(steps: 300)],
            [step("run.steer", [-0.5]), ScenarioStep(steps: 400)],
            (0..<12).map { step("run.steer", [$0 % 2 == 0 ? -1 : 1], steps: $0 == 0 ? 0 : 200) }
                + [ScenarioStep(steps: 200)],
        ]
    }

    /// The manifest of the experience `id`.
    public static func manifest(for id: ExperienceID, seed: UInt64 = manifestSeed) -> ScenarioManifest {
        let input = inputEntries
        let initial = expectedDigest(for: id, seed: seed, entries: [])
        let final = expectedDigest(for: id, seed: seed, entries: input)
        var specs = [
            ScenarioSpec(name: "launch-first-frame", seed: seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: initial)),
            ScenarioSpec(name: "input-response", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "completion", seed: seed, entries: [
                ScenarioStep(steps: 10, action: ScriptedAction("run.steer", [1]), result: "accepted"),
            ], expect: ScenarioExpectations(outcome: playingOutcome)),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        for (index, entries) in fixtureEntries.enumerated() {
            specs.append(ScenarioSpec(name: "fixture-\(index + 1)", seed: seed, entries: entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: expectedDigest(for: id, seed: seed,
                                                                                               entries: entries))))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
