// ArcadeManifest — feature 075 (A10-P01) T-A10-106 (FR-A10-123; SC-A10-106; research D5). The scenarios the
// verification runner plays for Neon Arcade: the nine standard ones and one `fixture-<n>` per regression fixture of
// research D5 that this phase can express through actions, all short (owner rule of 2026-11-13). Host steps advance
// the run, so the expected digests are derived by playing the entries on a core exactly as the engine plays them (the
// steps of an entry, then its action) and digesting it with the experience id as domain, as Digital Aquarium's
// manifest does. The properties themselves are proved by the tests named with each fixture.
// Fixtures 8–11 — feature 076 (A10-P02) T-A10-204 (FR-A10-221; SC-A10-206; research D5): wave progression, the wall
// gap, background/resume in wave 3 and the Phase 01 migration. The waves' pattern order depends only on the seed and
// the restarts (every spawn makes the same draws whatever the player does), so steering never changes which pattern a
// wave plays; the steering inputs of fixtures 8 and 10 were chosen so the run survives to the waves they name. Fixtures
// 1–7 keep their entries except fixture 3 (steering half left; half right no longer meets a hazard); their digests
// changed with the waves.
// Fixtures 12–14 — feature 077 (A10-P03) T-A10-305 (FR-A10-330; SC-A10-306; research D5): a run played past its
// first hit (the high-speed crossings at 20, 50 and 100 units/s cannot be set up by actions; `HighSpeedFixtureTests`
// proves them on the core), the title screen held until `run.start`, and the sound and haptics settings off. Since
// schema 3 a new experience opens on the title screen, so fixtures 1–11 and the standard scenarios with actions begin
// with `run.start`; fixture 9 pauses before its restart (a restart is allowed only from the paused or game-over
// screen); every digest changed with the screen and the settings.
// Fixtures 15–16 — feature 078 (A10-P04) T-A10-405 (FR-A10-401, FR-A10-402, FR-A10-412; research D3): a run played to
// game over (the run the presenter enters into the high-score table; the crash-safe table write itself happens in the
// presenter, outside the digest, and is proved by `HighScoreStoreTests`) and a sensitivity change (steps 4 then 0, a
// recorded setting that never changes the run). Every digest changed with schema 4 (sensitivity and run number).
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

    /// The steering inputs of the wave progression fixture (8): (step, value); with them the run of seed 7 lives
    /// through waves 1–4 (rain, orb-trail, wall, rain).
    public static let waveInputs: [(step: Int, value: Double)] = [(300, 0.5), (660, -1.0), (1680, 0.5), (1740, -1.0)]
    /// The steps of the wave progression fixture (wave 4 begins at step 1,800).
    public static let waveSteps = 1_900
    /// The steps before the restart of the wall gap fixture (9): the first spawn's draws (step 30) shift the
    /// generator so that the next run's wave 2 plays `wall` with seed 7.
    public static let wallRestartSteps = 31
    /// The steps the wall gap fixture plays after its restart (wave 2 from step 600, rows at 630 and 750).
    public static let wallSteps = 800
    /// The steps of the background/resume fixture (10) before its pause: inside wave 3 (steps 1,200…1,799).
    public static let waveThreeSteps = 1_300
    /// The steps the migration fixture (11) plays after the 120 steps the schema-1 example was saved after.
    public static let migrationSteps = 60

    /// The `run.start` entry the scenarios with actions begin with (the title screen → playing, feature 077).
    public static var startEntry: ScenarioStep {
        ScenarioStep(steps: 0, action: ScriptedAction("run.start"), result: "accepted")
    }

    /// The steps the high-speed fixture (12) plays straight on: past its first hit (at step 595 with seed 7) and on
    /// with one life less.
    public static let firstHitSteps = 660
    /// The steps the title fixture (13) holds the title screen before `run.start`, and plays after it.
    public static let titleSteps = 30
    /// The steps the settings fixture (14) plays with sound and haptics off.
    public static let settingsSteps = 120
    /// The steering of the game-over fixture (15): hard left from the start; with seed 7 the run ends at step 679 in
    /// wave 2 with score 11.
    public static let gameOverSteering = -1.0
    /// The steps the game-over fixture (15) plays (the run is over before the last; the over screen holds).
    public static let gameOverSteps = 700
    /// The steps the sensitivity fixture (16) plays after each of its two sensitivity changes.
    public static let sensitivitySteps = 60

    /// `inputs` as scenario entries: the steps up to each input, the `run.steer` action, and the steps left up to
    /// `steps`.
    public static func steeringEntries(_ inputs: [(step: Int, value: Double)], steps: Int) -> [ScenarioStep] {
        var entries: [ScenarioStep] = []
        var step = 0
        for input in inputs where input.step <= steps {
            entries.append(ScenarioStep(steps: input.step - step, action: ScriptedAction("run.steer", [input.value]),
                                        result: "accepted"))
            step = input.step
        }
        entries.append(ScenarioStep(steps: steps - step))
        return entries
    }

    /// The actions of input-response, save-restore and reset: start, steer right, steer half left, pause.
    public static var inputEntries: [ScenarioStep] {
        [startEntry,
         ScenarioStep(steps: 10, action: ScriptedAction("run.steer", [1]), result: "accepted"),
         ScenarioStep(steps: 30, action: ScriptedAction("run.steer", [-0.5]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("run.pause", [1]), result: "accepted")]
    }

    /// The entries of rejection: a steering value out of range, a pause value out of range, a fractional pause choice,
    /// a restart carrying a value, a pause on the title screen (`a10.wrong-screen`), a fractional sound setting and
    /// (feature 078) a fractional and an out-of-range sensitivity step.
    public static var rejectionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 0, action: ScriptedAction("run.steer", [2]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("run.pause", [-1]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("run.pause", [0.5]),
                      result: "action.rule." + ArcadeRule.invalidChoice),
         ScenarioStep(steps: 0, action: ScriptedAction("run.restart", [1]), result: "action.wrong-value-count"),
         ScenarioStep(steps: 0, action: ScriptedAction("run.pause", [1]),
                      result: "action.rule." + ArcadeRule.wrongScreen),
         ScenarioStep(steps: 0, action: ScriptedAction("settings.sound", [0.5]),
                      result: "action.rule." + ArcadeRule.invalidChoice),
         ScenarioStep(steps: 0, action: ScriptedAction("settings.sensitivity", [2.5]),
                      result: "action.rule." + ArcadeRule.invalidChoice),
         ScenarioStep(steps: 0, action: ScriptedAction("settings.sensitivity", [5]), result: "action.out-of-range")]
    }

    /// The recorded inputs as scenario entries: the steps up to each input, the `run.steer` action, and the steps
    /// left up to ``replaySteps``.
    public static var replayEntries: [ScenarioStep] {
        steeringEntries(recordedInputs, steps: replaySteps)
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

    /// The entries of the sixteen fixtures (research D5 of features 075, 076 and 077, research D3 of 078); each begins
    /// with ``startEntry`` except 13, which holds the title screen first:
    /// 1. replay: the twelve recorded steering inputs over 1,200 steps (`ArcadeManifestTests` plays them twice and
    ///    compares score, lives and the events; `ReplayTests` proves it for three seeds on the bare run);
    /// 2. frame pacing: the same entries — the same digest whatever the frame pacing, because the runner steps the
    ///    engine; the frame-time property (frames of 1/30, 1/60 and 1/120 s) is proved by `ArcadeSessionTests`;
    /// 3. swept hit: steering half left from the start (half right until A10-P02, whose lanes let that run pass
    ///    untouched), then 500 steps, in which a falling hazard hits the player
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
    ///    by `GameSimulationTests`);
    /// 8. wave progression (A10-P02): the ``waveInputs`` over 1,900 steps — waves 1–4 (rain, orb-trail, wall, rain)
    ///    with the run alive (`ArcadeManifestTests` checks the wave, the wave step and the patterns; the difficulty per
    ///    wave is proved by `DifficultyTests`);
    /// 9. wall gap: 31 steps, a pause and a restart (the generator continues), then 800 steps — the new run's wave 2
    ///    is `wall` (with seed 7 its wave 2 is `orb-trail` without the restart); the test checks two rows of four
    ///    spike-balls of radius 0.5 sharing one speed at the lane centres, each with exactly one free lane, the
    ///    second's free lane not the first's and equal to the run's (`WaveDirectorTests` proves the rule over many
    ///    rows);
    /// 10. background/resume in wave 3: the first two ``waveInputs`` to step 1,300 (wave 3, `wall`), a pause, 300
    ///     steps that change nothing, the resume and 60 steps — the same state as 1,360 steps played without the pause
    ///     (`ArcadeSessionTests` suspends a session in wave 3 for several lengths and finds wave, step, objects and
    ///     score identical);
    /// 11. Phase 01 migration: the first 120 steps of the recorded replay, as the schema-1 example (`schemaOneExample`)
    ///     was saved after, then 60 steps. A scenario cannot restore a stored payload, so the fixture plays the run the
    ///     example was saved from; `ArcadeManifestTests` restores the stored example in an engine, plays the same 60
    ///     steps and checks the migrated run (wave 1 restarted at wave step 0, score, lives, player and objects kept)
    ///     advances validly; the registry's migration check (`SnapshotMigrationCheck`) restores the same example;
    /// 12. high-speed hazards (A10-P03): ``firstHitSteps`` steps straight on — the run past its first hit
    ///     (`ArcadeManifestTests` checks one life lost at the hit and the run advancing after it). Hazards at 20, 50
    ///     and 100 units/s crossing the player within one step, and the same hazards 1.5 units aside, cannot be placed
    ///     by an action; `HighSpeedFixtureTests` proves one hit (and none) for each speed on the core;
    /// 13. title → start: ``titleSteps`` steps on the title screen (nothing advances), `run.start`, then
    ///     ``titleSteps`` steps — the run at step 30 (`ArcadeManifestTests` checks the held title and the start);
    /// 14. settings off: `settings.sound [0]` and `settings.haptics [0]`, then ``settingsSteps`` steps — the run and
    ///     the generator identical to the same steps with both settings on (`ArcadeManifestTests`);
    /// 15. game over (A10-P04): steering hard left, then ``gameOverSteps`` steps — the run is over (score above 0, run
    ///     number 1), the run a finished game enters into the high-score table once (`ArcadeManifestTests` checks the
    ///     over screen and the entry; the crash-safe write and the interrupted save are `HighScoreStoreTests`');
    /// 16. sensitivity: `settings.sensitivity [4]`, ``sensitivitySteps`` steps, `settings.sensitivity [0]`,
    ///     ``sensitivitySteps`` steps — the step saved, and the run and generator identical to the same steps at the
    ///     default step (`ArcadeManifestTests`).
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
        let fixtures: [[ScenarioStep]] = [
            replay,
            replay,
            [step("run.steer", [-0.5]), ScenarioStep(steps: 500)],
            halfway,
            [step("run.steer", [0.5], steps: 60), step("run.pause", [1]), ScenarioStep(steps: 300)],
            [step("run.steer", [-0.5]), ScenarioStep(steps: 400)],
            (0..<12).map { step("run.steer", [$0 % 2 == 0 ? -1 : 1], steps: $0 == 0 ? 0 : 200) }
                + [ScenarioStep(steps: 200)],
            steeringEntries(waveInputs, steps: waveSteps),
            [step("run.pause", [1], steps: wallRestartSteps), step("run.restart", []), ScenarioStep(steps: wallSteps)],
            steeringEntries(waveInputs, steps: waveThreeSteps)
                + [step("run.pause", [1]), step("run.pause", [0], steps: 300), ScenarioStep(steps: 60)],
            steeringEntries(schemaOneExampleInputs, steps: schemaOneExampleSteps + migrationSteps),
            [ScenarioStep(steps: firstHitSteps)],
        ]
        return fixtures.map { [startEntry] + $0 } + [
            [step("run.start", [], steps: titleSteps), ScenarioStep(steps: titleSteps)],
            [startEntry, step("settings.sound", [0]), step("settings.haptics", [0]),
             ScenarioStep(steps: settingsSteps)],
            [startEntry, step("run.steer", [gameOverSteering]), ScenarioStep(steps: gameOverSteps)],
            [startEntry, step("settings.sensitivity", [4]), step("settings.sensitivity", [0], steps: sensitivitySteps),
             ScenarioStep(steps: sensitivitySteps)],
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
                startEntry,
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
