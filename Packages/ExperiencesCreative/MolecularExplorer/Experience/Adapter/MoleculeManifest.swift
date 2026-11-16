// MoleculeManifest — feature 110 (A15-P01) T-A15-108 (FR-A15-132; clarification Q5). The scenarios the verification
// runner plays for Molecular Explorer, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (every seed opens with water selected);
//   - five fixtures `fixture-water`, `fixture-methane`, `fixture-ethanol`, `fixture-benzene` and `fixture-caffeine`
//     that select each library molecule by the action `molecule.select`. The final digest is pinned by
//     ``MoleculeCore/selectedFixtures`` (committed values; `MoleculeManifestTests` proves each equal to the derived
//     digest and the played core's selection equal to the fixture's molecule), and each expects the outcome
//     `viewing-<id>`.
//   - two fixtures of feature 111 (A15-P02) T-A15-206: `fixture-caffeine-space-filling` (caffeine, then
//     `display.mode [1]`) and `fixture-benzene-turned` (benzene, three `camera.orbit [1]`, one `camera.tilt [1]`, two
//     `camera.zoom [1]`), pinned by ``MoleculeCore/viewFixtures``;
//   - two fixtures of feature 112 (A15-P03) T-A15-307: `fixture-caffeine-picked` (caffeine, then `atom.select [2]`,
//     its third atom, a nitrogen) and `fixture-water-panned` (water, two `camera.pan [1, 0]`, one `camera.pan [0, 1]`).
// The completion scenario selects caffeine and expects the outcome `viewing-caffeine`. The expected digests are derived
// by playing the entries on a core exactly as the engine plays them (the steps of an entry, then its action) and
// digesting it with the experience id as domain, as Solar System Explorer's manifest does.
#if DEBUG || VISUALCORE_AUTOMATION
import MolecularExplorerCore
import VisualCoreExperience

extension MoleculeCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// The committed digests (engine digest, the experience id as domain) of the state after selecting each library
    /// molecule by ``fixtureEntries(molecule:)`` from the first state, by molecule index (0…4), pinned from the first
    /// run of `MoleculeManifestTests` on sim-27.2 (re-pinned at schema 4, feature 114).
    public static let selectedFixtures: [(molecule: Int, digest: String)] = [
        (0, "7c726aa5d6789341e8846cb0eedb832c50cef0b9f5cf3aac634261647b890ab5"),
        (1, "c794b0a757dda5ca746eea99ba9cb24e074261e82958c2f3bc5d16af30bc3b53"),
        (2, "ce290d0764c887e59a99af8b0208232a930bf445f366b0fa483c53d886547512"),
        (3, "e053a9ecb76bd6f66ba848a0b2089921a3f27e46f623ada70bde26371c3a72e0"),
        (4, "3d826bd4d8a82d011679ae972d0ee097983cefb3e1a4ec2f08ad5ee8d1574c35"),
    ]

    /// The view fixtures of feature 111: a name, the molecule index, the entries after selecting it and the committed
    /// final digest (pinned from the first run of `MoleculeManifestTests` on sim-27.2).
    public static let viewFixtures: [(name: String, molecule: Int, entries: [ScenarioStep], digest: String)] = [
        ("fixture-caffeine-space-filling", 4,
         [ScenarioStep(steps: 1, action: ScriptedAction("display.mode", [1]), result: "accepted")],
         "427b7694c7c4f4d174a2b5d32bb1285877f11f3e32d2ee5b04e5b0cd35124b03"),
        ("fixture-benzene-turned", 3,
         [ScenarioStep(steps: 1, action: ScriptedAction("camera.orbit", [1]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.orbit", [1]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.orbit", [1]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.tilt", [1]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.zoom", [1]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.zoom", [1]), result: "accepted")],
         "19f51f3c33694cbf3d115a5878a86b44ddb5c8124111775ead3e9847dad1d5ea"),
        ("fixture-caffeine-picked", 4,
         [ScenarioStep(steps: 1, action: ScriptedAction("atom.select", [2]), result: "accepted")],
         "cf7ef454f348f1a634860c6a2b0c101ba5b0950fdbbca6c4c0204f4db0a6ea15"),
        ("fixture-water-panned", 0,
         [ScenarioStep(steps: 1, action: ScriptedAction("camera.pan", [1, 0]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.pan", [1, 0]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.pan", [0, 1]), result: "accepted")],
         "7f5e1613e12c0c87030d49966f120dd09eee898293d957b6e6f56f14dc7d885c"),
    ]

    /// The entries of the view fixture `fixture`: its molecule selected, then its own entries.
    public static func viewFixtureEntries(_ fixture: (name: String, molecule: Int, entries: [ScenarioStep],
                                                      digest: String)) -> [ScenarioStep] {
        fixtureEntries(molecule: fixture.molecule) + fixture.entries
    }

    /// The name of the fixture of molecule index `molecule`: `fixture-<molecule id>` (`fixture-caffeine`).
    public static func fixtureName(molecule: Int) -> String {
        "fixture-" + (Self.molecule(index: molecule)?.id ?? "molecule-\(molecule)")
    }

    /// The outcome code of molecule index `molecule`: `viewing-<molecule id>`.
    public static func outcomeCode(molecule: Int) -> String {
        outcomePrefix + (Self.molecule(index: molecule)?.id ?? "unknown")
    }

    /// The entry that selects molecule index `molecule` from any state (accepted for 0…4).
    public static func fixtureEntries(molecule: Int) -> [ScenarioStep] {
        [ScenarioStep(steps: 1, action: ScriptedAction("molecule.select", [Double(molecule)]), result: "accepted")]
    }

    /// The actions of input-response, save-restore and reset: ethanol by the menu, then benzene, back to ethanol,
    /// then caffeine.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("molecule.select", [2]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("molecule.next"), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("molecule.previous"), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("molecule.select", [4]), result: "accepted")]
    }

    /// The entries of completion: caffeine selected.
    public static var completionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("molecule.select", [4]), result: "accepted")]
    }

    /// The entries of rejection, from water: indices out of range and fractional, the imported molecule without an
    /// import (`molecule.select [5]`, refused by the core since feature 114 declares 0…5), a step before the first
    /// molecule, actions with the wrong number of values, then caffeine selected and a step past the last molecule.
    public static var rejectionEntries: [ScenarioStep] {
        let invalid = "action.rule." + MoleculeRule.invalidChoice
        return [ScenarioStep(steps: 0, action: ScriptedAction("molecule.select", [6]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("molecule.select", [5]), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("molecule.select", [-1]),
                             result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("molecule.select", [0.5]), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("molecule.previous"), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("molecule.next", [1]),
                             result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("molecule.previous", [0]),
                             result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("molecule.select"), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("molecule.select", [4]), result: "accepted"),
                ScenarioStep(steps: 0, action: ScriptedAction("molecule.next"), result: invalid)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> MoleculeCore {
        var core = MoleculeCore(seed: seed)
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
                         expect: ScenarioExpectations(outcome: outcomeCode(molecule: 4))),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        for fixture in selectedFixtures {
            specs.append(ScenarioSpec(name: fixtureName(molecule: fixture.molecule), seed: seed,
                                      entries: fixtureEntries(molecule: fixture.molecule),
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: fixture.digest,
                                                                   outcome: outcomeCode(molecule: fixture.molecule))))
        }
        for fixture in viewFixtures {
            specs.append(ScenarioSpec(name: fixture.name, seed: seed, entries: viewFixtureEntries(fixture),
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: fixture.digest,
                                                                   outcome: outcomeCode(molecule: fixture.molecule))))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
