// StudioManifest — feature 160 (A22-P02) T-A22-209 (FR-A22-207). The scenarios the verification runner plays for
// Shader Studio, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (nothing depends on the seed);
//   - the fixtures: one per template (`fixture-gradient`, `fixture-noise-flow`, `fixture-rings` and, from feature 161,
//     `fixture-texture-mix`, each
//     `template.select [i]` then `shader.run [1]`, outcome `template-<id>`) and a broken run that keeps the preview
//     (`fixture-broken-run-keeps-preview`: a run of the opening template, a refused uniform index past its uniform
//     count, a refused fractional template, then a uniform change; the outcome stays `template-gradient`). The core
//     holds no source, so the broken compile itself is the experience tests' (`LastGoodPreviewTests`); the fixture
//     proves the state a failed run leaves is the state before it; and repeated runs (`fixture-repeated-runs`: Rings
//     run three times, then Gradient picked and run, outcome `template-gradient`; manual fixture 5, whose leak check is
//     the experience tests' `RebuildTests` and `RunQueueTests`); and from feature 161 `fixture-textures` (Texture mix
//     picked, noise on input 0 and checker on input 1, then a run, outcome `template-texture-mix`).
// Input-response and reset pick Rings, move both its uniforms and run; completion picks Noise flow and expects
// `template-noise-flow`; rejection refuses values out of range, fractional and missing uniform and texture indices
// (Gradient has no texture input) and wrong value
// counts (a template index one past the last is out of range). The expected digests are derived by playing the entries on a core exactly as the engine plays them (the steps
// of an entry, then its action) and digesting it with the experience id as domain, as Aurora's manifest does.
#if DEBUG || VISUALCORE_AUTOMATION
import ShaderStudioCore
import VisualCoreExperience

extension StudioCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// The outcome code of the template at `index` in `ShaderTemplates.all`: `template-<id>`.
    static func templateCode(_ index: Int) -> String { templateCodePrefix + ShaderTemplates.all[index].id }

    /// One accepted entry of `control` with `values`.
    static func accepted(_ control: String, _ values: [Double], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them.
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String)] {
        var list: [(name: String, entries: [ScenarioStep], outcome: String)] = []
        for (index, template) in ShaderTemplates.all.enumerated() {
            list.append(("fixture-" + template.id,
                         [accepted("template.select", [Double(index)]), accepted("shader.run", [1])],
                         templateCode(index)))
        }
        let broken = [accepted("shader.run", [1]),
                      ScenarioStep(steps: 0, action: ScriptedAction("uniform.set", [1, 0.5]),
                                   result: "action.rule." + StudioRule.noUniform),
                      ScenarioStep(steps: 0, action: ScriptedAction("template.select", [0.5]),
                                   result: "action.rule." + StudioRule.notWhole),
                      accepted("uniform.set", [0, 0.75])]
        list.append(("fixture-broken-run-keeps-preview", broken, templateCode(0)))
        let repeated = [accepted("template.select", [2]), accepted("shader.run", [1]), accepted("shader.run", [1]),
                        accepted("shader.run", [1]), accepted("template.select", [0]), accepted("shader.run", [1])]
        list.append(("fixture-repeated-runs", repeated, templateCode(0)))
        let mix = Double(ShaderTemplates.ids.firstIndex(of: "texture-mix") ?? 3)
        let textures = [accepted("template.select", [mix]), accepted("texture.set", [0, 2]),
                        accepted("texture.set", [1, 0]), accepted("shader.run", [1])]
        list.append(("fixture-textures", textures, templateCode(Int(mix))))
        return list
    }

    /// The actions of input-response and reset: Rings, both its uniforms moved, then a run.
    public static var inputEntries: [ScenarioStep] {
        [accepted("template.select", [2], steps: 10), accepted("uniform.set", [0, 0.25], steps: 10),
         accepted("uniform.set", [1, 0.8], steps: 10), accepted("shader.run", [1], steps: 10)]
    }

    /// The entries of completion: Noise flow chosen.
    public static var completionEntries: [ScenarioStep] {
        [accepted("template.select", [1], steps: 10)]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let notWhole = "action.rule." + StudioRule.notWhole
        let noUniform = "action.rule." + StudioRule.noUniform
        let noTexture = "action.rule." + StudioRule.noTexture
        let outOfRange = "action.out-of-range"
        let count = "action.wrong-value-count"
        return [
            ScenarioStep(steps: 0, action: ScriptedAction("template.select", [Double(ShaderTemplates.all.count)]),
                         result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("template.select", [-1]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("template.select", [1.5]), result: notWhole),
            ScenarioStep(steps: 0, action: ScriptedAction("uniform.set", [16, 0.5]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("uniform.set", [0, 1.5]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("uniform.set", [0.5, 0.5]), result: notWhole),
            ScenarioStep(steps: 0, action: ScriptedAction("uniform.set", [1, 0.5]), result: noUniform),
            ScenarioStep(steps: 0, action: ScriptedAction("texture.set", [0.5, 0]), result: notWhole),
            ScenarioStep(steps: 0, action: ScriptedAction("texture.set", [0, 1]), result: noTexture),
            ScenarioStep(steps: 0, action: ScriptedAction("texture.set", [2, 0]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("texture.set", [0, 3]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("shader.run", [0]), result: outOfRange),
            ScenarioStep(steps: 0, action: ScriptedAction("shader.run", []), result: count),
            ScenarioStep(steps: 0, action: ScriptedAction("uniform.set", [0]), result: count),
        ]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> StudioCore {
        var core = StudioCore()
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
                         expect: ScenarioExpectations(outcome: templateCode(1))),
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
