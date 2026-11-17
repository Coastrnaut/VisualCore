// AuroraManifest — feature 153 (A21-P02) T-A21-208 (FR-A21-201, FR-A21-202). The scenarios the verification runner
// plays for Aurora, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (nothing depends on the seed);
//   - five fixtures: one per preset (`fixture-polar-night`, `fixture-violet-veil`, `fixture-dawn-haze`, each
//     `preset.select [i]` and the outcome `preset-<id>`), a tuned sky (`fixture-tuned`: hue, speed, ribbons, stars
//     and clouds changed on the default preset, `preset-polar-night`) and a lowered limit (`fixture-low-limit`:
//     `light.limit [0.2]`, `preset-polar-night`).
// Input-response and reset shift the hue, slow the sky and choose the violet veil; completion chooses the dawn haze
// and expects `preset-dawn-haze`; rejection refuses values out of range, fractional whole-number values and wrong
// value counts. Save-restore plays the input entries: the snapshot is the digested state, so the restored sky has the
// same digest. The expected digests are derived by playing the entries on a core exactly as the engine plays them
// (the steps of an entry, then its action) and digesting it with the experience id as domain, as Digital Zen
// Garden's manifest does. The presenter's `horizon` frame probe is not part of the manifest's expectations.
#if DEBUG || VISUALCORE_AUTOMATION
import AuroraCore
import VisualCoreExperience

extension SkyCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// The outcome code of the preset at `index` in `SkyPresets.all`: `preset-<id>`.
    static func presetCode(_ index: Int) -> String { presetCodePrefix + SkyPresets.all[index].id }

    /// One accepted entry of `control` with `values`.
    static func accepted(_ control: String, _ values: [Double], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them.
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String)] {
        var list: [(name: String, entries: [ScenarioStep], outcome: String)] = []
        for (index, preset) in SkyPresets.all.enumerated() {
            list.append(("fixture-" + preset.id, [accepted("preset.select", [Double(index)])], presetCode(index)))
        }
        let tuned = [accepted("colour.hue", [0.25]), accepted("motion.speed", [1.5]), accepted("sky.ribbons", [4]),
                     accepted("sky.stars", [100]), accepted("sky.clouds", [0.5])]
        list.append(("fixture-tuned", tuned, presetCode(0)))
        list.append(("fixture-low-limit", [accepted("light.limit", [0.2])], presetCode(0)))
        return list
    }

    /// The actions of input-response and reset: a hue shift, a slower sky and the violet veil.
    public static var inputEntries: [ScenarioStep] {
        [accepted("colour.hue", [-0.2], steps: 10), accepted("motion.speed", [0.5], steps: 10),
         accepted("preset.select", [1], steps: 10)]
    }

    /// The entries of completion: the dawn haze chosen.
    public static var completionEntries: [ScenarioStep] {
        [accepted("preset.select", [2], steps: 10)]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let notWhole = "action.rule." + SkyRule.notWhole
        let outOfRange = "action.out-of-range"
        return [
            ScenarioStep(steps: 0, action: ScriptedAction("preset.select", [3]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("preset.select", [0.5]), result: notWhole),
            ScenarioStep(steps: 0, action: ScriptedAction("colour.hue", [0.75]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("motion.speed", [2.5]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("motion.turbulence", [-0.1]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("sky.ribbons", [0]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("sky.ribbons", [2.5]), result: notWhole),
            ScenarioStep(steps: 0, action: ScriptedAction("sky.stars", [401]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("sky.stars", [10.5]), result: notWhole),
            ScenarioStep(steps: 0, action: ScriptedAction("sky.clouds", [1.5]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("light.limit", [0.1]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("light.limit", [0.8]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("colour.hue", []), result: "action.wrong-value-count"),
            ScenarioStep(steps: 0, action: ScriptedAction("motion.speed", [1, 1]), result: "action.wrong-value-count"),
        ]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> SkyCore {
        var core = SkyCore()
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
                         expect: ScenarioExpectations(outcome: presetCode(2))),
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
