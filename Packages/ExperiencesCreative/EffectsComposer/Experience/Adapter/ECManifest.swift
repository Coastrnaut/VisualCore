// ECManifest — feature 181 (A25-P02) T-A25-209 (FR-A25-207; SC-A25-206). The scenarios the verification runner plays
// for Effects Composer, all short (owner rule of 2026-11-13), after Graphics Benchmark Lab's `GBLManifest`:
//   - the nine standard scenarios, prepared with seed 1 (nothing depends on the seed);
//   - one fixture per effect, `fixture-<effect>` (`fixture-grade`, `fixture-blur`, `fixture-distort`,
//     `fixture-vignette`, `fixture-posterize`): the effect added, its first parameter set to three quarters of its
//     range, the effect disabled and enabled again, outcome `effects-1`.
// Input-response, save-restore and reset add Color grade and Blur, set the grade's contrast to its top, move Blur
// first, disable it, then undo the disabling; completion adds Vignette, expecting `effects-1`; rejection refuses, on
// the opening (empty) chain, an effect index out of range, fractions (`a25.not-whole`), positions that name no node
// (`a25.bad-index`), undo and redo with nothing to undo or redo and wrong value counts. The expected digests are
// derived by playing the entries on a core exactly as the engine plays them (the steps of an entry, then its action)
// and digesting it with the experience id as domain. The frame probe is the presenter's (`ComposerPresenter.probes`):
// the opening chain is empty, so the test image is presented unchanged and its checker cell (2, 2) is `blue`.
#if DEBUG || VISUALCORE_AUTOMATION
import EffectsComposerCore
import VisualCoreExperience

extension ComposerCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// One accepted entry of `control` with `values`.
    static func accepted(_ control: String, _ values: [Double] = [], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
    }

    /// One entry of `control` with `values` refused with `result`.
    static func refused(_ control: String, _ values: [Double], _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 0, action: ScriptedAction(control, values), result: result)
    }

    /// The result code of a refusal by the rule `rule`.
    static func ruleResult(_ rule: String) -> String { "action.rule." + rule }

    /// The outcome code of `count` enabled effects.
    static func outcomeCode(_ count: Int) -> String { outcomePrefix + "\(count)" }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them (one per effect).
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String)] {
        effects.enumerated().map { index, effect in
            let entries = [accepted("chain.add", [Double(index), 0]),
                           accepted("chain.set", [0, 0, 0.75]),
                           accepted("chain.enable", [0, 0]),
                           accepted("chain.enable", [0, 1])]
            return ("fixture-" + effect.rawValue, entries, outcomeCode(1))
        }
    }

    /// The actions of input-response, save-restore and reset (see the file header).
    public static var inputEntries: [ScenarioStep] {
        [accepted("chain.add", [0, 0], steps: 10), accepted("chain.add", [1, 1], steps: 10),
         accepted("chain.set", [0, 1, 1], steps: 10), accepted("chain.move", [1, 0], steps: 10),
         accepted("chain.enable", [0, 0], steps: 10), accepted("edit.undo", steps: 10)]
    }

    /// The entries of completion: Vignette added.
    public static var completionEntries: [ScenarioStep] {
        [accepted("chain.add", [3, 0], steps: 10)]
    }

    /// The entries of rejection, from the opening (empty) chain (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let count = "action.wrong-value-count"
        let notWhole = ruleResult(ComposerRule.notWhole)
        let badIndex = ruleResult("a25.bad-index")
        return [
            refused("chain.add", [5, 0], outOfRange),
            refused("chain.add", [0, 9], outOfRange),
            refused("chain.add", [0.5, 0], notWhole),
            refused("chain.add", [0, 1], badIndex),
            refused("chain.remove", [0], badIndex),
            refused("chain.remove", [1.5], notWhole),
            refused("chain.move", [0, 1], badIndex),
            refused("chain.enable", [0, 0.5], notWhole),
            refused("chain.set", [0, 0, 0.5], badIndex),
            refused("edit.undo", [], ruleResult("a25.nothing-to-undo")),
            refused("edit.redo", [], ruleResult("a25.nothing-to-redo")),
            refused("chain.add", [0], count),
            refused("edit.undo", [1], count),
        ]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> ComposerCore {
        var core = ComposerCore()
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
                         expect: ScenarioExpectations(outcome: outcomeCode(1))),
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
