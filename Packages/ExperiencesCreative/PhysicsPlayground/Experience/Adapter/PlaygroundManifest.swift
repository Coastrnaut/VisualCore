// PlaygroundManifest — feature 082 (A11-P01) T-A11-106 (FR-A11-122; SC-A11-107; research D5). The scenarios the
// verification runner plays for Physics Playground: the nine standard ones and one `fixture-<n>` per regression fixture
// of research D5, all short (owner rule of 2026-11-13). Host steps advance the world, so the expected digests are
// derived by playing the entries on a core exactly as the engine plays them (the steps of an entry, then its action)
// and digesting it with the experience id as domain, as Neon Arcade's manifest does. The physical properties
// themselves are proved by the tests named with each fixture (`PhysicsFixtureTests`, `ReplayTests`,
// `MaterialCatalogTests` of the core, and the experience tests).
#if DEBUG || VISUALCORE_AUTOMATION
import PhysicsPlaygroundCore
import VisualCoreExperience

extension PlaygroundCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The recorded actions of the replay fixture: (step at which it applies, control, values), in step order.
    /// Several actions at one step apply in the listed order.
    public static let recordedInputs: [(step: Int, control: String, values: [Double])] = [
        (0, "world.drop", [0]), (60, "world.drop", [1]), (120, "world.timeScale", [3]), (200, "world.drop", [0]),
        (260, "world.timeScale", [0]), (360, "world.pause", [1]), (360, "world.step", []), (360, "world.step", []),
        (360, "world.pause", [0]), (400, "world.timeScale", [2]), (480, "world.drop", [1]),
    ]

    /// The number of host steps the replay fixture plays.
    public static let replaySteps = 600

    /// The number of drops of the body-cap fixture that are accepted (the starting scene holds 7 bodies; 41 more make
    /// 48).
    public static let capDrops = PhysicsWorld.maxBodies - 7

    /// The actions of input-response, save-restore and reset: drop a circle, drop a box, half speed, pause, one step.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 20, action: ScriptedAction("world.drop", [0]), result: "accepted"),
         ScenarioStep(steps: 40, action: ScriptedAction("world.drop", [1]), result: "accepted"),
         ScenarioStep(steps: 20, action: ScriptedAction("world.timeScale", [1]), result: "accepted"),
         ScenarioStep(steps: 20, action: ScriptedAction("world.pause", [1]), result: "accepted"),
         ScenarioStep(steps: 0, action: ScriptedAction("world.step"), result: "accepted")]
    }

    /// The entries of rejection: a pause value out of range, a fractional pause, a fractional and an out-of-range time
    /// scale, a single step while running, a reset carrying a value and a fractional drop.
    public static var rejectionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 0, action: ScriptedAction("world.pause", [2]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("world.pause", [0.5]),
                      result: "action.rule." + PlaygroundRule.invalidChoice),
         ScenarioStep(steps: 0, action: ScriptedAction("world.timeScale", [1.5]),
                      result: "action.rule." + PlaygroundRule.invalidChoice),
         ScenarioStep(steps: 0, action: ScriptedAction("world.timeScale", [4]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("world.step"),
                      result: "action.rule." + PlaygroundRule.notPaused),
         ScenarioStep(steps: 0, action: ScriptedAction("world.reset", [1]), result: "action.wrong-value-count"),
         ScenarioStep(steps: 0, action: ScriptedAction("world.drop", [0.5]),
                      result: "action.rule." + PlaygroundRule.invalidChoice)]
    }

    /// The recorded inputs up to (and including) `limit` as scenario entries, then the steps left up to `limit`.
    public static func replayEntries(upTo limit: Int = replaySteps) -> [ScenarioStep] {
        var entries: [ScenarioStep] = []
        var step = 0
        for input in recordedInputs where input.step <= limit {
            entries.append(ScenarioStep(steps: input.step - step, action: ScriptedAction(input.control, input.values),
                                        result: "accepted"))
            step = input.step
        }
        entries.append(ScenarioStep(steps: limit - step))
        return entries
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (a rejected action changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> PlaygroundCore {
        var core = PlaygroundCore(seed: seed)
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

    /// The entries of the ten fixtures (research D5):
    /// 1. free fall: a circle dropped at step 0, then 120 host steps (1 s at 1×); the 1 % free-fall property without
    ///    drag is proved by `PhysicsFixtureTests` (an action cannot switch the drag off);
    /// 2. two-body momentum: two circles dropped, then 240 steps; the head-on elastic exchange (momentum within 1e-9
    ///    relative, velocities within 2 %) is proved by `PhysicsFixtureTests`;
    /// 3. static zero mass: a box dropped, then 1,000 steps in which bodies land on and around the ledge; the ledge
    ///    (mass 0) never moves (`PlaygroundManifestTests`, `PhysicsFixtureTests`);
    /// 4. replay determinism: the recorded inputs over 600 steps (`PlaygroundManifestTests` plays them twice;
    ///    `ReplayTests` proves it for several seeds on the bare world);
    /// 5. frame pacing: the same entries — the same digest whatever the frame pacing, because the runner steps the
    ///    engine; frames of 1/30, 1/60 and 1/120 s are proved by `PlaygroundSessionTests`;
    /// 6. time scale and single step: ¼× for 40 steps (10 ticks), 2× for 40 steps (80 ticks), a pause, three single
    ///    steps (three ticks) and 30 paused steps that change nothing;
    /// 7. save/restore: the recorded inputs up to step 300 (the test round-trips the state through its snapshot
    ///    payload and continues both identically);
    /// 8. resume without catch-up: a drop, 60 steps, a pause, then 300 steps that change nothing (a suspension stops
    ///    host steps the same way; `PlaygroundSessionTests` suspends and resumes a session);
    /// 9. catalog: two circles and two boxes dropped, then 200 steps; every body names a material of the validated
    ///    bundled catalog (the refusals of malformed catalogs are proved by `MaterialCatalogTests`);
    /// 10. body cap: 41 drops, 10 steps apart, fill the world to 48 bodies; the 42nd drop is refused with
    ///    `a11.body-cap`; then 60 steps.
    public static var fixtureEntries: [[ScenarioStep]] {
        func act(_ control: String, _ values: [Double] = [], steps: Int = 0,
                 result: String = "accepted") -> ScenarioStep {
            ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: result)
        }
        let replay = replayEntries()
        let cap = (0..<capDrops).map { act("world.drop", [Double($0 % 2)], steps: $0 == 0 ? 0 : 10) }
            + [act("world.drop", [0], steps: 10, result: "action.rule." + PlaygroundRule.bodyCap),
               ScenarioStep(steps: 60)]
        return [
            [act("world.drop", [0]), ScenarioStep(steps: 120)],
            [act("world.drop", [0]), act("world.drop", [0]), ScenarioStep(steps: 240)],
            [act("world.drop", [1]), ScenarioStep(steps: 1_000)],
            replay,
            replay,
            [act("world.timeScale", [0]), act("world.timeScale", [3], steps: 40), act("world.pause", [1], steps: 40),
             act("world.step"), act("world.step"), act("world.step"), ScenarioStep(steps: 30)],
            replayEntries(upTo: 300),
            [act("world.drop", [0]), act("world.pause", [1], steps: 60), ScenarioStep(steps: 300)],
            [act("world.drop", [0]), act("world.drop", [1]), act("world.drop", [0]), act("world.drop", [1]),
             ScenarioStep(steps: 200)],
            cap,
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
                ScenarioStep(steps: 10, action: ScriptedAction("world.pause", [1]), result: "accepted"),
            ], expect: ScenarioExpectations(outcome: pausedOutcome)),
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
