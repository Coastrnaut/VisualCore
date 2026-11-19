// GBLManifest — feature 174 (A24-P02) T-A24-211 (FR-A24-207; SC-A24-205). The scenarios the verification runner plays
// for Graphics Benchmark Lab, all short (owner rule of 2026-11-13), after Visual Programming Lab's `LabManifest`:
//   - the nine standard scenarios, prepared with seed 1 (nothing depends on the seed);
//   - the fixtures, one per built-in case and two more for the planning catalog's five: `fixture-case-quads` (alu
//     chosen, then quads again: the opening digest, outcome `case-quads`), `fixture-case-alu` (outcome `case-alu`),
//     `fixture-case-particles` (outcome `case-particles`), `fixture-run-start-stop` (alu chosen, a run started and
//     stopped: the counters are not in the digest, which is alu's, outcome `case-alu`) and
//     `fixture-refused-fraction` (`case.select [0.5]` refused with `a24.not-whole`, then particles chosen).
// Input-response, save-restore and reset choose alu, start a run and stop it; completion chooses particles, expecting
// `case-particles`; rejection refuses indices out of range, fractional indices (`a24.not-whole`) and wrong value
// counts. (`a24.unknown-case` cannot be reached through the engine, whose range check runs first; the core tests
// cover it.) The expected digests are derived by playing the entries on a core exactly as the engine plays them (the
// steps of an entry, then its action) and digesting it with the experience id as domain, as Shader Studio's manifest
// does. The frame probe is the presenter's (`BenchPresenter.probes(_:)`): the opening case is quads, and the probe
// follows the last layer's turn, so its class `red` holds at every frame the runner reads.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience

extension BenchCore {
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

    /// The outcome code of the case `id`.
    static func outcomeCode(_ id: String) -> String { outcomePrefix + id }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them.
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String)] {
        let quads = [accepted("case.select", [1]), accepted("case.select", [0])]
        let alu = [accepted("case.select", [1])]
        let particles = [accepted("case.select", [2])]
        let startStop = [accepted("case.select", [1]), accepted("run.start"), accepted("run.stop")]
        let refusedFraction = [refused("case.select", [0.5], "action.rule." + BenchRule.notWhole),
                               accepted("case.select", [2])]
        return [("fixture-case-quads", quads, outcomeCode("quads")),
                ("fixture-case-alu", alu, outcomeCode("alu")),
                ("fixture-case-particles", particles, outcomeCode("particles")),
                ("fixture-run-start-stop", startStop, outcomeCode("alu")),
                ("fixture-refused-fraction", refusedFraction, outcomeCode("particles"))]
    }

    /// The actions of input-response, save-restore and reset: alu chosen, a run started and stopped.
    public static var inputEntries: [ScenarioStep] {
        [accepted("case.select", [1], steps: 10), accepted("run.start", steps: 10), accepted("run.stop", steps: 10)]
    }

    /// The entries of completion: particles chosen.
    public static var completionEntries: [ScenarioStep] {
        [accepted("case.select", [2], steps: 10)]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let outOfRange = "action.out-of-range"
        let count = "action.wrong-value-count"
        return [
            refused("case.select", [3], outOfRange),
            refused("case.select", [-1], outOfRange),
            refused("case.select", [0.5], "action.rule." + BenchRule.notWhole),
            refused("case.select", [1.5], "action.rule." + BenchRule.notWhole),
            refused("case.select", [], count),
            refused("case.select", [0, 1], count),
            refused("run.start", [1], count),
            refused("run.stop", [0], count),
        ]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> BenchCore {
        var core = BenchCore()
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
                         expect: ScenarioExpectations(outcome: outcomeCode("particles"))),
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
