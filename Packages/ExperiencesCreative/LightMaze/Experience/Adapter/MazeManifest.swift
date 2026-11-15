// MazeManifest — feature 096 (A13-P01) T-A13-106 (FR-A13-113, FR-A13-122; SC-A13-103, SC-A13-106). The scenarios the
// verification runner plays for Light Maze, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (every seed opens the first level);
//   - five fixtures `fixture-lm-01`, `-05`, `-10`, `-16` and `-20` that solve levels 1, 5, 10, 16 and 20 by actions:
//     `level.select` of the level, then for every turnable tile whose recorded solution differs from its starting
//     orientation `tile.select` of that tile and `tile.turn`. The final digest is pinned by ``solvedFixtures``
//     (committed values; `MazeManifestTests` proves each equal to the derived digest, the played core solved and its
//     orientations equal to the recorded solution). The digest covers the beam, so each fixture pins the solved
//     beam path;
//   - three refusal scenarios: `refusal-level-out-of-range` (level 20, refused by the engine as out of range),
//     `refusal-level-before-first` (`level.previous` on the first level, `a13.invalid-choice`) and
//     `refusal-turn-without-selection` (`tile.turn` with nothing selected, `a13.invalid-choice`), each ending in its
//     initial digest.
// The completion scenario solves level 1 (select its mirror and turn it) and expects the outcome `level-solved`. The
// expected digests are derived by playing the entries on a core exactly as the engine plays them (the steps of an
// entry, then its action) and digesting it with the experience id as domain, as Tiny Worlds' manifest does.
// Feature 098 (A13-P03) T-A13-305 (FR-A13-310): the state is schema 2 (with `moves`), so every committed digest was
// regenerated; a sixth fixture `fixture-undo` solves level 1 (select its mirror, turn it) and takes the turn back with
// `move.undo`, ending unsolved with no moves (digest pinned by ``undoFixtureDigest``); the rejection scenario also
// refuses `move.undo` with nothing to undo (`a13.no-moves`).
// Feature 099 (A13-P04) T-A13-408 (FR-A13-402): a seventh fixture `fixture-hint` chooses level 1, asks for a hint
// (`hint.show` selects its mirror) and turns it, ending solved with one move (digest pinned by ``hintFixtureDigest``).
#if DEBUG || VISUALCORE_AUTOMATION
import LightMazeCore
import VisualCoreExperience

extension MazeCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// The committed digests (engine digest, the experience id as domain) of the state after solving levels 1, 5, 10,
    /// 16 and 20 by ``fixtureEntries(level:)`` from the first state, by level index (0, 4, 9, 15, 19). State schema 2.
    public static let solvedFixtures: [(level: Int, digest: String)] = [
        (0, "f7dce4d2f7ab2e1633c1d342c03031d00ae6ec8ecab9adfdcd94513ddb9f6db0"),
        (4, "8b157f3280296441ceaba724e306f9d9789d73619ec9c40f0071c94750f4ce8a"),
        (9, "25884fffd0d22826cc762d66740fc950e01e0c95c9b671a436dc92400dc0a748"),
        (15, "8d619fc6555eca0ad704224ca5ed230bfb74c938cb7d2f72021b11479088ffce"),
        (19, "2ad678202a3fe2256ae28e506f7da8422d0f531869e245d28be0293fd05d6f02"),
    ]

    /// The name of the undo fixture.
    public static let undoFixtureName = "fixture-undo"

    /// The committed digest of the state after ``undoFixtureEntries`` from the first state (level 1 unsolved, its mirror
    /// selected, no moves).
    public static let undoFixtureDigest = "c1f0d91515e2b5d838e09bd2d8a96caed8b49d454671470b4f489be4459f2494"

    /// The entries of `fixture-undo`: level 1 chosen, its mirror selected and turned (solved), then the turn taken back
    /// (unsolved, no moves).
    public static var undoFixtureEntries: [ScenarioStep] {
        [ScenarioStep(steps: 1, action: ScriptedAction("level.select", [0]), result: "accepted"),
         ScenarioStep(steps: 1, action: ScriptedAction("tile.select", [0]), result: "accepted"),
         ScenarioStep(steps: 1, action: ScriptedAction("tile.turn"), result: "accepted"),
         ScenarioStep(steps: 1, action: ScriptedAction("move.undo"), result: "accepted")]
    }

    /// The name of the hint fixture (feature 099).
    public static let hintFixtureName = "fixture-hint"

    /// The committed digest of the state after ``hintFixtureEntries`` from the first state (level 1 solved through the
    /// hint, one move). It equals `fixture-lm-01`'s digest: the hint selects the same mirror the recorded solution
    /// turns, so both end in the same state.
    public static let hintFixtureDigest = "f7dce4d2f7ab2e1633c1d342c03031d00ae6ec8ecab9adfdcd94513ddb9f6db0"

    /// The entries of `fixture-hint`: level 1 chosen, a hint asked for (its mirror selected), the hinted tile turned
    /// (solved).
    public static var hintFixtureEntries: [ScenarioStep] {
        [ScenarioStep(steps: 1, action: ScriptedAction("level.select", [0]), result: "accepted"),
         ScenarioStep(steps: 1, action: ScriptedAction("hint.show"), result: "accepted"),
         ScenarioStep(steps: 1, action: ScriptedAction("tile.turn"), result: "accepted")]
    }

    /// The name of the fixture of level index `level`: `fixture-<level id>` (`fixture-lm-01`).
    public static func fixtureName(level: Int) -> String {
        "fixture-" + (MazeState.catalog.level(at: level)?.id ?? "lm-\(level + 1)")
    }

    /// The entries that solve level index `level` from any state: choose the level, then select and turn every
    /// turnable tile whose recorded solution differs from its starting orientation (all accepted).
    public static func fixtureEntries(level: Int) -> [ScenarioStep] {
        guard let data = MazeState.catalog.level(at: level) else { return [] }
        var entries = [ScenarioStep(steps: 1, action: ScriptedAction("level.select", [Double(level)]),
                                    result: "accepted")]
        let start = data.startOrientations
        for index in data.solution.indices where index < start.count && data.solution[index] != start[index] {
            entries.append(ScenarioStep(steps: 1, action: ScriptedAction("tile.select", [Double(index)]),
                                        result: "accepted"))
            entries.append(ScenarioStep(steps: 1, action: ScriptedAction("tile.turn"), result: "accepted"))
        }
        return entries
    }

    /// The actions of input-response, save-restore and reset: turn level 1's mirror, go to level 2, select its
    /// second mirror and turn it.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("tile.select", [0]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("tile.turn"), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("level.next"), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("tile.select", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("tile.turn"), result: "accepted")]
    }

    /// The entries of completion: level 1 solved by turning its mirror.
    public static var completionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("tile.select", [0]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("tile.turn"), result: "accepted")]
    }

    /// The entries of rejection, all on the first level: levels out of range and fractional, a step before the first
    /// level, a turn with nothing selected, tiles the level does not have and out of range, and actions with the
    /// wrong number of values.
    public static var rejectionEntries: [ScenarioStep] {
        let invalid = "action.rule." + MazeRule.invalidChoice
        return [ScenarioStep(steps: 0, action: ScriptedAction("level.select", [20]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("level.select", [-1]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("level.select", [0.5]), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("level.previous"), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("tile.turn"), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("tile.select", [1]), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("tile.select", [Double(maxTurnable)]),
                             result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("level.next", [1]), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("level.reset", [0]), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("tile.select"), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("move.undo"), result: "action.rule." + MazeRule.noMoves),
                ScenarioStep(steps: 0, action: ScriptedAction("move.undo", [0]), result: "action.wrong-value-count")]
    }

    /// The refusal scenarios by name with their single entry (see the file header).
    public static var refusalScenarios: [(name: String, entry: ScenarioStep)] {
        [("refusal-level-out-of-range",
          ScenarioStep(steps: 0, action: ScriptedAction("level.select", [20]), result: "action.out-of-range")),
         ("refusal-level-before-first",
          ScenarioStep(steps: 0, action: ScriptedAction("level.previous"),
                       result: "action.rule." + MazeRule.invalidChoice)),
         ("refusal-turn-without-selection",
          ScenarioStep(steps: 0, action: ScriptedAction("tile.turn"), result: "action.rule." + MazeRule.invalidChoice))]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> MazeCore {
        var core = MazeCore(seed: seed)
        var step = 0
        for entry in entries {
            for _ in 0..<max(0, entry.steps) {
                core.update(step: step)
                step += 1
            }
            guard let action = entry.action else { continue }
            if ExperienceInput.validate(control: action.control, values: action.values, controls: controls) != nil {
                continue
            }
            var next = core
            if next.apply(ExperienceAction(control: action.control, values: action.values, step: step)).isAccepted {
                core = next
            }
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
            ScenarioSpec(name: "completion", seed: seed, entries: completionEntries,
                         expect: ScenarioExpectations(outcome: solvedOutcome)),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        for fixture in solvedFixtures {
            let entries = fixtureEntries(level: fixture.level)
            specs.append(ScenarioSpec(name: fixtureName(level: fixture.level), seed: seed, entries: entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: fixture.digest,
                                                                   outcome: solvedOutcome)))
        }
        specs.append(ScenarioSpec(name: undoFixtureName, seed: seed, entries: undoFixtureEntries,
                                  expect: ScenarioExpectations(initialDigest: initial, finalDigest: undoFixtureDigest)))
        specs.append(ScenarioSpec(name: hintFixtureName, seed: seed, entries: hintFixtureEntries,
                                  expect: ScenarioExpectations(initialDigest: initial, finalDigest: hintFixtureDigest,
                                                               outcome: solvedOutcome)))
        for refusal in refusalScenarios {
            specs.append(ScenarioSpec(name: refusal.name, seed: seed, entries: [refusal.entry],
                                      expect: ScenarioExpectations(initialDigest: initial, finalDigest: initial)))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
