// PlaygroundManifest — feature 082 (A11-P01) T-A11-106 (FR-A11-122; SC-A11-107; research D5). The scenarios the
// verification runner plays for Physics Playground: the nine standard ones and one `fixture-<n>` per regression fixture
// of research D5, all short (owner rule of 2026-11-13). Host steps advance the world, so the expected digests are
// derived by playing the entries on a core exactly as the engine plays them (the steps of an entry, then its action)
// and digesting it with the experience id as domain, as Neon Arcade's manifest does. The physical properties
// themselves are proved by the tests named with each fixture (`PhysicsFixtureTests`, `ReplayTests`,
// `MaterialCatalogTests` of the core, and the experience tests).
//
// Feature 083 (A11-P02) T-A11-205 (FR-A11-222; research D5): the starting scene now holds ten bodies and two springs
// (the body-cap fixture needs 38 drops), the input and rejection scenarios use the level actions, and fixtures 11–18
// are added, each scripted over the experience's actions so the world reaches the situation it names: 11 resting pile,
// 12 spring equilibrium, 13 spring energy without gravity and drag, 14 damped spring energy, 15 stiffness clamp, 16
// broad phase equals all pairs, 17 gravity and drag levels, 18 schema-1 migration. The exact bounds (the five-box
// stack, the undamped and damped oscillators, the clamp, brute-force equality on 50 scenes) are proved by the core's
// `StackFixtureTests`, `SpringWorldTests`, `MigrationTests` and VisualCore's `Springs2DTests` and `BroadPhase2DTests`;
// `PlaygroundManifestTests` checks each fixture's end state.
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

    /// The number of bodies of the starting scene (the ledge, six seeded bodies, the hanging box and the two joined
    /// circles).
    public static let startingBodies = 10

    /// The number of drops of the body-cap fixture that are accepted (the starting scene holds 10 bodies; 38 more make
    /// 48).
    public static let capDrops = PhysicsWorld.maxBodies - startingBodies

    /// The host steps of the long fixtures (11–15): 10 s at 1×.
    public static let settleSteps = 1_200

    /// The host steps fixture 13 runs under Earth gravity before switching gravity and drag off (0.5 s), so the
    /// springs start out stretched and moving.
    public static let energyLeadSteps = 60

    /// The host steps of each segment of fixture 17 (1 s at 1×).
    public static let levelSegmentSteps = 120

    /// The host steps fixture 16 runs after its drops.
    public static let broadPhaseSteps = 240

    /// The actions of input-response, save-restore and reset: drop a circle, drop a box, stiffer springs, half speed,
    /// pause, one step.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 20, action: ScriptedAction("world.drop", [0]), result: "accepted"),
         ScenarioStep(steps: 40, action: ScriptedAction("world.drop", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("world.stiffness", [2]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("world.timeScale", [1]), result: "accepted"),
         ScenarioStep(steps: 20, action: ScriptedAction("world.pause", [1]), result: "accepted"),
         ScenarioStep(steps: 0, action: ScriptedAction("world.step"), result: "accepted")]
    }

    /// The entries of rejection: a pause value out of range, a fractional pause, a fractional and an out-of-range time
    /// scale, a single step while running, a reset carrying a value, a fractional drop, a fractional gravity, an
    /// out-of-range drag and a fractional stiffness.
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
                      result: "action.rule." + PlaygroundRule.invalidChoice),
         ScenarioStep(steps: 0, action: ScriptedAction("world.gravity", [1.5]),
                      result: "action.rule." + PlaygroundRule.invalidChoice),
         ScenarioStep(steps: 0, action: ScriptedAction("world.drag", [3]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("world.stiffness", [2.25]),
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

    /// The entries of the eighteen fixtures (research D5 of features 082 and 083):
    /// 1. free fall: a circle dropped at step 0, then 120 host steps (1 s at 1×); the 1 % free-fall property without
    ///    drag is proved by `PhysicsFixtureTests` and, through the level actions, by fixture 17;
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
    /// 10. body cap: 38 drops, 10 steps apart, fill the world to 48 bodies; the 39th drop is refused with
    ///    `a11.body-cap`; then 60 steps;
    /// 11. resting pile: five boxes dropped 30 steps apart with high drag, then 1,200 steps (10 s); the bodies come to
    ///    rest in contact (the five-box stack bound, drift < 2 cm and sink < 1 cm, is `StackFixtureTests`');
    /// 12. spring equilibrium: stiffness level 2 (150 N/m), then 1,200 steps; the hanging box rests within 2 % of
    ///    m·g/k' below its rest length;
    /// 13. spring energy: 60 steps under Earth gravity stretch the springs, then gravity and drag off and 1,200 steps;
    ///    with no gravity and no drag only the springs' own damping (ratio 0.1) and the contacts remove energy, so the
    ///    total energy never rises above its value at the switch (the undamped 2 % band is `Springs2DTests`');
    /// 14. damped spring energy: soft springs (level 0) and high drag, then 1,200 steps; the hanging box's motion dies
    ///    away (the 0.1 %/s and 10 % bounds at ζ = 0.5 are `Springs2DTests`');
    /// 15. stiffness clamp: level 3 (400 N/m), above the stable bound 0.1·m/dt² of the hanging box and the joined
    ///    circles, then 1,200 steps; every number stays finite and the box rests at the clamped stretch m·g/k';
    /// 16. broad phase equals all pairs: three circles and three boxes dropped, then 240 steps; the world equals the
    ///    same ticks run with every pair tested (`ContactPairing.allPairs`);
    /// 17. gravity and drag levels: Moon gravity and no drag with a circle dropped, 120 steps; then gravity off and
    ///    high drag, 120 steps; then Earth and low drag, 120 steps; the settings follow the levels, the circle falls at
    ///    1.62 m/s² and then slows as e^(−t);
    /// 18. schema-1 migration: the A11-P01 actions the stored schema-1 example was saved after (a circle and a box
    ///    dropped, half speed, pause), 30 paused steps, then running for 60 steps; the stored example
    ///    (`schemaOneExample()`) restores through the step 1 → 2 with the same generator and dropped bodies.
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
            [act("world.drag", [2])] + (0..<5).map { act("world.drop", [1], steps: $0 == 0 ? 0 : 30) }
                + [ScenarioStep(steps: settleSteps)],
            [act("world.stiffness", [2]), ScenarioStep(steps: settleSteps)],
            [act("world.gravity", [0], steps: energyLeadSteps), act("world.drag", [0]),
             ScenarioStep(steps: settleSteps)],
            [act("world.stiffness", [0]), act("world.drag", [2]), ScenarioStep(steps: settleSteps)],
            [act("world.stiffness", [3]), ScenarioStep(steps: settleSteps)],
            [act("world.drop", [0]), act("world.drop", [1]), act("world.drop", [0]), act("world.drop", [1]),
             act("world.drop", [0]), act("world.drop", [1]), ScenarioStep(steps: broadPhaseSteps)],
            [act("world.gravity", [1]), act("world.drag", [0]), act("world.drop", [0]),
             act("world.gravity", [0], steps: levelSegmentSteps), act("world.drag", [2]),
             act("world.gravity", [2], steps: levelSegmentSteps), act("world.drag", [1]),
             ScenarioStep(steps: levelSegmentSteps)],
            schemaOneExampleActions.map { act($0.control, $0.values) }
                + [act("world.pause", [0], steps: 30), ScenarioStep(steps: 60)],
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
