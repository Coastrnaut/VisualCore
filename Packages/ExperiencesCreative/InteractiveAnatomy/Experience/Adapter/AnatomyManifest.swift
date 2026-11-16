// AnatomyManifest — feature 125 (A17-P02) T-A17-207 (FR-A17-210). The scenarios the verification runner plays for
// Interactive Anatomy, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (every seed opens with the opening view);
//   - three fixtures: `fixture-femur-selected` (`structure.select [0]`), `fixture-ligaments-hidden`
//     (`layer.show [2, 0]`) and `fixture-turned` (three `camera.turn [1]`, one `camera.tilt [1]`), expecting the
//     outcomes `selected-knee-femur`, `viewing-knee` and `viewing-knee`.
// The completion scenario selects the femur and expects the outcome `selected-knee-femur`. The expected digests are
// derived by playing the entries on a core exactly as the engine plays them (the steps of an entry, then its action)
// and digesting it with the experience id as domain, as Molecular Explorer's manifest does.
#if DEBUG || VISUALCORE_AUTOMATION
import InteractiveAnatomyCore
import VisualCoreExperience

extension AnatomyCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them.
    public static let fixtures: [(name: String, entries: [ScenarioStep], outcome: String)] = [
        ("fixture-femur-selected",
         [ScenarioStep(steps: 1, action: ScriptedAction("structure.select", [0]), result: "accepted")],
         "selected-knee-femur"),
        ("fixture-ligaments-hidden",
         [ScenarioStep(steps: 1, action: ScriptedAction("layer.show", [2, 0]), result: "accepted")],
         "viewing-knee"),
        ("fixture-turned",
         [ScenarioStep(steps: 1, action: ScriptedAction("camera.turn", [1]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.turn", [1]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.turn", [1]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("camera.tilt", [1]), result: "accepted")],
         "viewing-knee"),
    ]

    /// The actions of input-response, save-restore and reset: select the tibia, hide the ligaments, zoom in, select
    /// the patella.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("structure.select", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("layer.show", [2, 0]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("camera.zoom", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("structure.select", [3]), result: "accepted")]
    }

    /// The entries of completion: the femur selected.
    public static var completionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("structure.select", [0]), result: "accepted")]
    }

    /// The entries of rejection, from the opening state: indices out of range and fractional, a bad layer switch,
    /// camera steps other than ±1, wrong value counts, a hidden part, and tilt steps beyond the limit.
    public static var rejectionEntries: [ScenarioStep] {
        let invalid = "action.rule." + AnatomyRule.invalidChoice
        let hidden = "action.rule." + AnatomyRule.hiddenStructure
        let limit = "action.rule." + AnatomyRule.cameraLimit
        var entries = [
            ScenarioStep(steps: 0, action: ScriptedAction("structure.select", [14]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("structure.select", [0.5]), result: invalid),
            ScenarioStep(steps: 0, action: ScriptedAction("layer.show", [3, 1]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("layer.show", [0, 0.5]), result: invalid),
            ScenarioStep(steps: 0, action: ScriptedAction("camera.turn", [0]), result: invalid),
            ScenarioStep(steps: 0, action: ScriptedAction("structure.select"), result: "action.wrong-value-count"),
            ScenarioStep(steps: 0, action: ScriptedAction("view.reset", [1]), result: "action.wrong-value-count"),
            ScenarioStep(steps: 0, action: ScriptedAction("layer.show", [2, 0]), result: "accepted"),
            ScenarioStep(steps: 0, action: ScriptedAction("structure.select", [9]), result: hidden),
        ]
        let opening = AnatomyCameraState.opening.tilt
        for _ in opening..<AnatomyCameraState.tiltRange.upperBound {
            entries.append(ScenarioStep(steps: 0, action: ScriptedAction("camera.tilt", [1]), result: "accepted"))
        }
        entries.append(ScenarioStep(steps: 0, action: ScriptedAction("camera.tilt", [1]), result: limit))
        return entries
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    /// Nil when the bundled content cannot be prepared.
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> AnatomyCore? {
        guard var core = try? AnatomyCore(seed: seed) else { return nil }
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
    /// core cannot be prepared or the digest cannot be written.
    public static func expectedDigest(for id: ExperienceID, seed: UInt64, entries: [ScenarioStep]) -> String? {
        guard let core = played(seed: seed, entries: entries) else { return nil }
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
                         expect: ScenarioExpectations(outcome: outcomeCode(partID: "knee.femur"))),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        for fixture in fixtures {
            specs.append(ScenarioSpec(name: fixture.name, seed: seed, entries: fixture.entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: expectedDigest(
                                                                       for: id, seed: seed, entries: fixture.entries),
                                                                   outcome: fixture.outcome)))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
