// SimulationManifest — feature 117 (A16-P01) T-A16-107 (FR-A16-131). The scenarios the verification runner plays for
// Simulation Lab, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (the cellular automaton with the Life rule, running at ×1);
//   - three fixtures, one per family, each chosen by the action `sim.family`, run for a number of host steps, paused
//     and stepped once by hand: `fixture-automaton` (120 host steps: 20 generations, then one), `fixture-reaction-
//     diffusion` (30 host steps: 120 iterations, then one) and `fixture-wave` (30 host steps: 60 iterations, then
//     one). The final digests are pinned by ``SimulationCore/familyFixtures`` (committed values;
//     `SimulationManifestTests` proves each equal to the derived digest, printing `derived <hex>` when they differ, so
//     a re-pin copies the printed value), and each expects the outcome `simulating-<family>`.
// The simulation runs on host steps, so every digest depends on the step counts of the entries; the engine plays the
// same steps for the same entries, so the digests are deterministic. The completion scenario chooses the wave field
// and expects the outcome `simulating-wave`. The expected digests are derived by playing the entries on a core exactly
// as the engine plays them (the steps of an entry, then its action) and digesting it with the experience id as domain,
// as Molecular Explorer's manifest does.
#if DEBUG || VISUALCORE_AUTOMATION
import SimulationLabCore
import VisualCoreExperience

extension SimulationCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// The family fixtures: a name, the family index, the entries and the committed final digest (engine digest, the
    /// experience id as domain, seed ``manifestSeed``), pinned from the derived values (`SimulationManifestTests`
    /// prints `derived <hex>` for a fixture whose committed value differs).
    public static let familyFixtures: [(name: String, family: Int, entries: [ScenarioStep], digest: String)] = [
        ("fixture-automaton", 0, fixtureEntries(family: 0, steps: 120),
         "203cfde63b05302ef6faa3440b798025891563505dfc66be1984643eb66da04f"),
        ("fixture-reaction-diffusion", 1, fixtureEntries(family: 1, steps: 30),
         "1708928e068d2ff7e5a1ca5f01fc2855c8f020c591b9757f0273a08f572e8313"),
        ("fixture-wave", 2, fixtureEntries(family: 2, steps: 30),
         "3d1ba160d4195e0e1ba69fcd0e482ec410e309759d1f139f739afc0957dc7c67"),
        // Two preset fixtures (the planning catalog asks for five fixtures; T-A16-111): HighLife and Mazes.
        ("fixture-automaton-highlife", 0, fixtureEntries(family: 0, preset: 1, steps: 120),
         "e9aa5e02d7cd1cbf1a32369f516c531d49437a10567227de54f9a4336fb1f62f"),
        ("fixture-reaction-mazes", 1, fixtureEntries(family: 1, preset: 1, steps: 30),
         "4ce4811c1e5f1d438c7052b2f9b785b0c02a9a0055af467ce148bac463b68f53"),
    ]

    /// The entries of a family fixture: the family chosen by `sim.family [family]`, then `sim.preset [preset]` when a
    /// preset is given, `steps` host steps, `sim.pause`, then one `sim.step`.
    public static func fixtureEntries(family: Int, preset: Int? = nil, steps: Int) -> [ScenarioStep] {
        var entries = [ScenarioStep(steps: 0, action: ScriptedAction("sim.family", [Double(family)]), result: "accepted")]
        if let preset {
            entries.append(ScenarioStep(steps: 0, action: ScriptedAction("sim.preset", [Double(preset)]),
                                        result: "accepted"))
        }
        entries.append(ScenarioStep(steps: steps, action: ScriptedAction("sim.pause"), result: "accepted"))
        entries.append(ScenarioStep(steps: 0, action: ScriptedAction("sim.step"), result: "accepted"))
        return entries
    }

    /// The outcome code of the family at `family` (0…2): `simulating-<family>`.
    public static func outcomeCode(family: Int) -> String {
        outcomeCode(families[min(max(family, 0), families.count - 1)])
    }

    /// The actions of input-response, save-restore and reset: reaction-diffusion, its Mazes preset, speed ×2, a pause
    /// and one step by hand, so the final state is paused.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("sim.family", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("sim.preset", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("sim.speed", [3]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("sim.pause"), result: "accepted"),
         ScenarioStep(steps: 0, action: ScriptedAction("sim.step"), result: "accepted")]
    }

    /// The entries of completion: the wave field chosen.
    public static var completionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("sim.family", [2]), result: "accepted")]
    }

    /// The entries of rejection, from the running automaton: a family out of range and fractional, a fractional
    /// preset, a run while running, a step while running, a speed out of range, actions with the wrong number of
    /// values, then the wave field with a preset it does not have, and a second pause.
    public static var rejectionEntries: [ScenarioStep] {
        let invalid = "action.rule." + SimulationRule.invalidChoice
        return [ScenarioStep(steps: 0, action: ScriptedAction("sim.family", [3]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.family", [0.5]), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.preset", [1.5]), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.run"), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.step"), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.speed", [5]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.pause", [1]), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.family"), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.family", [2]), result: "accepted"),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.preset", [1]), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.pause"), result: "accepted"),
                ScenarioStep(steps: 0, action: ScriptedAction("sim.pause"), result: invalid)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> SimulationCore {
        var core = SimulationCore(seed: seed)
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
                         expect: ScenarioExpectations(outcome: outcomeCode(family: 2))),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        for fixture in familyFixtures {
            specs.append(ScenarioSpec(name: fixture.name, seed: seed, entries: fixture.entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: fixture.digest,
                                                                   outcome: outcomeCode(family: fixture.family))))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
