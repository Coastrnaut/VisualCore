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
//
// Feature 084 (A11-P03) T-A11-304 (FR-A11-321; SC-A11-305; research D5): the world is schema 3 (every digest now
// covers the pins, selection, grab and overlay flags), the rejection scenario adds a refusal for each new rule
// (`a11.no-room`, `a11.unknown-body`, `a11.not-grabbable`, `a11.no-grab`, `a11.static-body`, `a11.no-selection` and
// fractional ids, kinds and overlay values), the body-cap fixture also refuses an `edit.add` at 48 bodies, and fixtures
// 19–26 are added, scripted over the edit actions on the seed-independent spring bodies (the hanging box id 7 at
// (7.5, 6.2) m, the joined circles ids 8 and 9 at (7, 1.5) and (8, 1.5) m): 19 add at a point, 20 grab, move and
// release, 21 pin with impacts (the mass-zero fixture), 22 unpin and fall, 23 delete with springs, 24 selection and
// nudge, 25 overlays on and off, 26 schema-2 migration. The exact bounds (a pinned body bit-identical over 1,000 ticks,
// the fall at g within 1 %, the grab within 5 cm in 1 s) are the core's `PinFixtureTests` and `WorldEditingTests`.
//
// Feature 085 (A11-P04) T-A11-404 (FR-A11-430; SC-A11-401, SC-A11-403, SC-A11-404, SC-A11-405; research D5): the state
// is schema 4 (every digest now covers the origin, the starting world and the tutorial progress), the rejection
// scenario adds `tutorial.stop` without a tutorial (`a11.no-tutorial`) and fractional preset and tutorial values
// (`a11.invalid-choice`), and fixtures 27–33 are added, scripted over the experiment and tutorial actions: 27 pendulum,
// 28 spring-chain energy over 1,200 steps, 29 stacked objects, 30 reset to the experiment after edits and time
// controls, 31 the tutorial "Controlling time" completed by its actions, 32 the tutorial "Springs and energy", 33
// schema-3 migration. Saving and opening slots is outside the replay (the experience's storage) and is proved by
// `ExperimentStoreTests` and `ExperimentSampleFileTests`; the energy bounds are the core's `SpringEnergyFixtureTests`.
//
// Feature 086 (A11-P05) T-A11-505 (FR-A11-501, FR-A11-502, FR-A11-510; SC-A11-501, SC-A11-505; research D4): the state
// is schema 5 with the world at world schema 4 (every digest now covers each body's `asleep` and `restTicks`), and
// fixtures 34–38 are added: 34 a stress session (stiffness level 3, the world filled to 48 bodies by drops, nudges of a
// selected circle and gravity and drag level changes, 600 steps), 35 the stacked objects settling to sleep
// (360 steps), 36 the settled stack woken by a circle added above it and falling onto it, 37 replay across quality (the
// recorded inputs with the overlays switched on and off; the tests play it with the quality tier changed during the
// run and get the same digest), 38 schema-4 migration. The stress bounds over five seeds and 1,200 ticks, the work
// budget and the energy bound are the core's `StressTests`, `WorkBudgetTests` and `SleepTests`.
#if DEBUG || VISUALCORE_AUTOMATION
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreMath

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

    /// The hanging box's id and the joined circles' ids in every starting scene (feature 084 fixtures).
    public static let hangingBoxId = 7, firstCircleId = 8, secondCircleId = 9

    /// The host steps fixture 21 runs with the pinned circle under impacts.
    public static let pinSteps = 1_000

    /// The host steps fixtures 27 and 29 run their preset (5 s at 1×; feature 085).
    public static let presetSteps = 600

    /// The host steps of the stress fixture 34 (5 s at 1×; feature 086).
    public static let stressSteps = 600

    /// The host steps the stack of fixtures 35 and 36 settles for (3 s at 1×; the core puts it to sleep within 360
    /// ticks, `SleepTests`; feature 086).
    public static let sleepSteps = 360

    /// The host steps fixture 36 runs after the circle is added above the settled stack (2 s at 1×; feature 086).
    public static let wakeSteps = 240

    /// The point fixture 36 adds a circle at, in metres: above the middle of the stack (its top at 2.5 m), clear of it.
    public static let wakePoint = Vec2(Presets.stackX, 4)

    /// The tiers fixture 37 is played at in turn (the tests change the engine's tier at each overlay action; feature
    /// 086).
    public static let qualityFixtureTiers = [2, 1, 0, 2]

    /// The overlay actions fixture 37 adds to the recorded inputs: (step, control, values).
    public static let qualityOverlayInputs: [(step: Int, control: String, values: [Double])] = [
        (100, "overlay.velocity", [1]), (250, "overlay.forces", [1]), (400, "overlay.velocity", [0]),
        (550, "overlay.forces", [0]),
    ]

    /// The points fixture 19 adds a circle and a box at, in metres (clear of the starting bodies at step 0).
    public static let addPoints = (circle: Vec2(4.5, 1.5), box: Vec2(5.0, 3.0))

    /// The targets fixture 20 moves the grabbed circle to, in metres.
    public static let grabTargets = [Vec2(6, 3), Vec2(5, 3.5)]

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
    /// out-of-range drag and a fractional stiffness; then (feature 084) an add leaving the stage, an add of a
    /// fractional kind, an add outside the range, a select of a missing body and of a fractional id, a grab of the
    /// static ledge, a move and a release without a grab, a pin of the static ledge, a delete of a missing body, a
    /// nudge without a selection and a fractional overlay value; then (feature 085) a stop without a tutorial, a
    /// fractional preset and a fractional tutorial.
    public static var rejectionEntries: [ScenarioStep] {
        func refused(_ control: String, _ values: [Double], _ rule: String) -> ScenarioStep {
            ScenarioStep(steps: 0, action: ScriptedAction(control, values), result: "action.rule." + rule)
        }
        return [ScenarioStep(steps: 0, action: ScriptedAction("world.pause", [2]), result: "action.out-of-range"),
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
                      result: "action.rule." + PlaygroundRule.invalidChoice),
         refused("edit.add", [0.2, 0.2, 0], PlaygroundRule.noRoom),
         refused("edit.add", [4.5, 1.5, 0.5], PlaygroundRule.invalidChoice),
         ScenarioStep(steps: 0, action: ScriptedAction("edit.add", [11, 4, 0]), result: "action.out-of-range"),
         refused("edit.select", [99], PlaygroundRule.unknownBody),
         refused("edit.select", [1.5], PlaygroundRule.invalidChoice),
         refused("edit.grab", [0, StartingScene.ledgeCenter.x, StartingScene.ledgeCenter.y],
                 PlaygroundRule.notGrabbable),
         refused("edit.move", [5, 4], PlaygroundRule.noGrab),
         refused("edit.release", [], PlaygroundRule.noGrab),
         refused("edit.pin", [0], PlaygroundRule.staticBody),
         refused("edit.delete", [99], PlaygroundRule.unknownBody),
         refused("edit.nudge", [1, 0], PlaygroundRule.noSelection),
         refused("overlay.velocity", [0.5], PlaygroundRule.invalidChoice),
         refused("tutorial.stop", [], PlaygroundRule.noTutorial),
         refused("experiment.preset", [1.5], PlaygroundRule.invalidChoice),
         refused("tutorial.start", [0.5], PlaygroundRule.invalidChoice)]
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

    /// The entries of the stress fixture 34 (feature 086): stiffness level 3; the world filled to 48 bodies by
    /// ``capDrops`` drops 5 steps apart (circles and boxes in turn); circle 8 selected; then four rounds of 60 steps,
    /// each a nudge of the circle followed by a gravity and a drag level change; then the steps left up to
    /// ``stressSteps``.
    public static var stressEntries: [ScenarioStep] {
        func act(_ control: String, _ values: [Double] = [], steps: Int = 0) -> ScenarioStep {
            ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
        }
        var entries = [act("world.stiffness", [3])]
        entries += (0..<capDrops).map { act("world.drop", [Double($0 % 2)], steps: $0 == 0 ? 0 : 5) }
        entries.append(act("edit.select", [Double(firstCircleId)]))
        let rounds: [(nudge: [Double], gravity: Double, drag: Double)] = [
            ([1, 1], 1, 0), ([-1, 0.5], 0, 2), ([0.5, -1], 2, 0), ([-0.5, 1], 2, 1),
        ]
        for round in rounds {
            entries += [act("edit.nudge", round.nudge, steps: 60), act("world.gravity", [round.gravity], steps: 30),
                        act("world.drag", [round.drag])]
        }
        let used = entries.reduce(0) { $0 + $1.steps }
        entries.append(ScenarioStep(steps: stressSteps - used))
        return entries
    }

    /// The entries of the replay-across-quality fixture 37 (feature 086): the recorded inputs with
    /// ``qualityOverlayInputs`` merged in step order (an overlay action after the recorded ones of its step), then the
    /// steps left up to ``replaySteps``.
    public static var qualityReplayEntries: [ScenarioStep] {
        typealias Input = (step: Int, control: String, values: [Double])
        var inputs: [Input] = recordedInputs
        for overlay in qualityOverlayInputs {
            // After every input at or before the overlay's step.
            let index = inputs.firstIndex { $0.step > overlay.step } ?? inputs.count
            inputs.insert(overlay, at: index)
        }
        var entries: [ScenarioStep] = []
        var step = 0
        for input in inputs {
            entries.append(ScenarioStep(steps: input.step - step, action: ScriptedAction(input.control, input.values),
                                        result: "accepted"))
            step = input.step
        }
        entries.append(ScenarioStep(steps: replaySteps - step))
        return entries
    }

    /// The entries of the thirty-eight fixtures (research D5 of features 082, 083, 084 and 085, D4 of feature 086):
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
    ///    (`schemaOneExample()`) restores through the steps 1 → 2 → 3 with the same generator and dropped bodies;
    /// and (feature 084, research D5):
    /// 19. add at a point: a circle at (4.5, 1.5) m and a box at (5, 3) m added at step 0 (ids 10 and 11, centred
    ///    there), then 120 steps;
    /// 20. grab, move and release: circle 8 grabbed at its centre, its target moved to (6, 3) m after 30 steps and to
    ///    (5, 3.5) m after 30 more, held for 120 steps (1 s), released, then 60 steps; the body keeps its own velocity;
    /// 21. pin with impacts (the mass-zero fixture): circle 8 pinned at step 0, a box added above it at (7, 3) m and a
    ///    circle at (7, 4.5) m that fall onto it, then 1,000 steps; the pinned circle never moves and every number
    ///    stays finite;
    /// 22. unpin and fall: circle 8 pinned for 60 steps, then unpinned; 60 steps later it has fallen;
    /// 23. delete with springs: the hanging box selected, then deleted with its spring, and circle 8 deleted with the
    ///    spring to circle 9; no springs and no selection remain; then 60 steps;
    /// 24. selection and nudge: circle 9 selected and nudged by (1, 1) and (−0.5, 1), then 60 steps;
    /// 25. overlays on and off: velocity and force arrows on, 60 steps, velocity arrows off, 60 steps; the world equals
    ///    the same steps without the overlay actions except for the flags;
    /// 26. schema-2 migration: the A11-P02 actions the stored schema-2 example was saved after (a circle and a box
    ///    dropped, stiff springs, Moon gravity, high drag, half speed, pause), 30 paused steps, then running for 60
    ///    steps; the stored example (`schemaTwoExample()`) restores through the step 2 → 3 to the same world with no
    ///    pins, selection, grab or overlays;
    /// and (feature 085, research D5):
    /// 27. pendulum: the pendulum preset opened at step 0, then 600 steps (5 s); without drag its total energy stays
    ///    within 5 % of the start (`SpringEnergyFixtureTests`);
    /// 28. spring-chain energy: the spring chain opened at step 0, then 1,200 steps (10 s); with gravity and low drag
    ///    the total energy sampled each second never rises by more than 0.5 % and ends below its start;
    /// 29. stacked objects: the five-box stack opened at step 0, then 600 steps; the stack stands on the floor;
    /// 30. reset to the experiment: the pendulum opened, 60 steps, the bob selected and nudged, quarter speed, a drop,
    ///    40 steps, a pause and two single steps, stiff springs and Moon gravity, then `world.reset`: the world equals
    ///    the pendulum as it opened (running, normal speed, no grab, no selection);
    /// 31. tutorial "Controlling time": the tutorial started, 10 steps, a pause, one single step, half speed and a
    ///    reset complete its four steps in order and end it; then 30 steps;
    /// 32. tutorial "Springs and energy": the tutorial started, the spring chain opened and force arrows shown complete
    ///    its first two steps; 360 steps (3 s) running complete the last one and end it;
    /// 33. schema-3 migration: the A11-P03 actions the stored schema-3 example was saved after (two drops, a pin, a
    ///    selection, a grab, velocity arrows, half speed, pause), 30 paused steps, then running for 60 steps; the
    ///    stored example (`schemaThreeExample()`) restores through the step 3 → 4 to the same world and generator,
    ///    origin free play, the world without grab and selection as the starting world and no tutorial;
    /// and (feature 086, research D4):
    /// 34. stress: ``stressEntries`` — stiffness level 3, 38 drops fill the world to 48 bodies, circle 8 selected and
    ///    nudged four times with gravity and drag level changes, 600 steps in all; every value stays finite, every
    ///    body inside the stage and every cap respected (five seeds over 1,200 ticks: the core's `StressTests`);
    /// 35. settle to sleep: the stacked objects opened at step 0, then 360 steps; every box is asleep;
    /// 36. wake by a hit: the stacked objects settled for 360 steps, a circle added above the stack at (5, 4) m, then
    ///    240 steps; the falling circle wakes the stack;
    /// 37. replay across quality: ``qualityReplayEntries`` — the recorded inputs with the overlays switched on and off;
    ///    the tests play it with the engine's quality tier changed at each overlay action and get the digest of the
    ///    run without tier changes (the tier is presentation only);
    /// 38. schema-4 migration: the A11-P04 actions the stored schema-4 example was saved after (the tutorial "Springs
    ///    and energy" started, the spring chain opened, force arrows on, a box dropped, Moon gravity, half speed,
    ///    pause), 30 paused steps, then running for 60 steps; the stored example (`schemaFourExample()`) restores
    ///    through the step 4 → 5 to the same worlds (every body awake with 0 rest ticks), generator, origin and
    ///    tutorial.
    public static var fixtureEntries: [[ScenarioStep]] {
        func act(_ control: String, _ values: [Double] = [], steps: Int = 0,
                 result: String = "accepted") -> ScenarioStep {
            ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: result)
        }
        let replay = replayEntries()
        let cap = (0..<capDrops).map { act("world.drop", [Double($0 % 2)], steps: $0 == 0 ? 0 : 10) }
            + [act("world.drop", [0], steps: 10, result: "action.rule." + PlaygroundRule.bodyCap),
               act("edit.add", [addPoints.circle.x, addPoints.circle.y, 0],
                   result: "action.rule." + PlaygroundRule.bodyCap),
               ScenarioStep(steps: 60)]
        let circle = Double(firstCircleId), other = Double(secondCircleId), box = Double(hangingBoxId)
        let start = StartingScene.pairCenters.0
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
            [act("edit.add", [addPoints.circle.x, addPoints.circle.y, 0]),
             act("edit.add", [addPoints.box.x, addPoints.box.y, 1]), ScenarioStep(steps: 120)],
            [act("edit.grab", [circle, start.x, start.y]),
             act("edit.move", [grabTargets[0].x, grabTargets[0].y], steps: 30),
             act("edit.move", [grabTargets[1].x, grabTargets[1].y], steps: 30),
             act("edit.release", steps: 120), ScenarioStep(steps: 60)],
            [act("edit.pin", [circle]), act("edit.add", [7, 3, 1]), act("edit.add", [7, 4.5, 0]),
             ScenarioStep(steps: pinSteps)],
            [act("edit.pin", [circle]), act("edit.pin", [circle], steps: 60), ScenarioStep(steps: 60)],
            [act("edit.select", [box]), act("edit.delete", [box]), act("edit.delete", [circle]),
             ScenarioStep(steps: 60)],
            [act("edit.select", [other]), act("edit.nudge", [1, 1]), act("edit.nudge", [-0.5, 1]),
             ScenarioStep(steps: 60)],
            [act("overlay.velocity", [1]), act("overlay.forces", [1]), act("overlay.velocity", [0], steps: 60),
             ScenarioStep(steps: 60)],
            schemaTwoExampleActions.map { act($0.control, $0.values) }
                + [act("world.pause", [0], steps: 30), ScenarioStep(steps: 60)],
            [act("experiment.preset", [Double(PresetID.pendulum.rawValue)]), ScenarioStep(steps: presetSteps)],
            [act("experiment.preset", [Double(PresetID.springChain.rawValue)]), ScenarioStep(steps: settleSteps)],
            [act("experiment.preset", [Double(PresetID.stackedObjects.rawValue)]), ScenarioStep(steps: presetSteps)],
            [act("experiment.preset", [Double(PresetID.pendulum.rawValue)]), act("edit.select", [1], steps: 60),
             act("edit.nudge", [1, 0]), act("world.timeScale", [0]), act("world.drop", [0]),
             act("world.pause", [1], steps: 40), act("world.step"), act("world.step"), act("world.stiffness", [3]),
             act("world.gravity", [1]), act("world.reset")],
            [act("tutorial.start", [0]), act("world.pause", [1], steps: 10), act("world.step"),
             act("world.timeScale", [1]), act("world.reset"), ScenarioStep(steps: 30)],
            [act("tutorial.start", [1]), act("experiment.preset", [Double(PresetID.springChain.rawValue)]),
             act("overlay.forces", [1]), ScenarioStep(steps: Tutorials.runTicks)],
            schemaThreeExampleActions.map { act($0.control, $0.values) }
                + [act("world.pause", [0], steps: 30), ScenarioStep(steps: 60)],
            stressEntries,
            [act("experiment.preset", [Double(PresetID.stackedObjects.rawValue)]), ScenarioStep(steps: sleepSteps)],
            [act("experiment.preset", [Double(PresetID.stackedObjects.rawValue)]),
             act("edit.add", [wakePoint.x, wakePoint.y, 0], steps: sleepSteps), ScenarioStep(steps: wakeSteps)],
            qualityReplayEntries,
            schemaFourExampleActions.map { act($0.control, $0.values) }
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
