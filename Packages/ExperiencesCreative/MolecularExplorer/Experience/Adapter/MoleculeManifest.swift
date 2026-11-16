// MoleculeManifest — feature 110 (A15-P01) T-A15-108 (FR-A15-132; clarification Q5). The scenarios the verification
// runner plays for Molecular Explorer, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (every seed opens with water selected);
//   - five fixtures `fixture-water`, `fixture-methane`, `fixture-ethanol`, `fixture-benzene` and `fixture-caffeine`
//     that select each library molecule by the action `molecule.select`. The final digest is pinned by
//     ``MoleculeCore/selectedFixtures`` (committed values; `MoleculeManifestTests` proves each equal to the derived
//     digest and the played core's selection equal to the fixture's molecule), and each expects the outcome
//     `viewing-<id>`.
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
    /// run of `MoleculeManifestTests` on sim-27.2.
    public static let selectedFixtures: [(molecule: Int, digest: String)] = [
        (0, "898c8e0b69c5e417fe2dc097bbf564626db33d079da5052e064c2285b62079e2"),
        (1, "ba65d980c1636cb0721a19d795f57fb18251944c4cd7bb7167c05eb49bfc1807"),
        (2, "806d57b4423e5b3e9d79a8dac436e5d259bc020fd6f957b6c776b4c613bb71f4"),
        (3, "1464cbc58b73e81483fc88745cc7e5dcaa9429a0d1df376eae60c45b82cc5db9"),
        (4, "bea0e7a245b79525fd587db753352efa59a4edf4fb5b361d3395a37b13073afa"),
    ]

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

    /// The entries of rejection, from water: indices out of range and fractional, a step before the first molecule,
    /// actions with the wrong number of values, then caffeine selected and a step past the last molecule.
    public static var rejectionEntries: [ScenarioStep] {
        let invalid = "action.rule." + MoleculeRule.invalidChoice
        return [ScenarioStep(steps: 0, action: ScriptedAction("molecule.select", [5]), result: "action.out-of-range"),
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
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
