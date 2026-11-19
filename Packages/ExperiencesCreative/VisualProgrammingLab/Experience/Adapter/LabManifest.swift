// LabManifest — feature 167 (A23-P02) T-A23-210 (FR-A23-207; SC-A23-201, SC-A23-202). The scenarios the verification
// runner plays for Visual Programming Lab, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (nothing depends on the seed);
//   - the fixtures: `fixture-starter-graph` (the starter graph, a node selected: the digest stays the opening one, as
//     the selection is not in it; outcome `graph-ready`), `fixture-journey-graph` (the journey of SC-A23-201 from
//     the starter graph: Gradient, Mix and Blur added, the starter connection removed, Noise and Gradient into Mix, Mix
//     into Blur, Blur into Output; outcome `graph-ready`) and `fixture-refused-connection` (the phase's regression
//     fixture: a Constant added, its colour output refused into Noise's scalar input with `a23.type-mismatch`; the
//     graph is the one before the refusal, outcome `graph-ready`), `fixture-refused-loop` (Mix and Blur added, Noise
//     into Mix a and Mix into Blur, Blur back into Mix b refused with `a23.cycle`, then Noise into Mix b) and
//     `fixture-refused-second-output` (a second Output refused with `a23.one-output`, then a Gradient added).
// Input-response, save-restore and reset add a Gradient, move it and select it; completion removes the Output, adds a
// new one and connects Noise to it, expecting `graph-ready`; rejection refuses values out of range, fractional values
// (`a23.not-whole`), unknown nodes and ports, a type mismatch, a taken input, a second output and wrong value counts.
// The expected digests are derived by playing the entries on a core exactly as the engine plays them (the steps of an
// entry, then its action) and digesting it with the experience id as domain, as Shader Studio's manifest does.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience
import VisualProgrammingLabCore

extension LabCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// One accepted entry of `control` with `values`.
    static func accepted(_ control: String, _ values: [Double], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
    }

    /// One entry of `control` with `values` refused with `result`.
    static func refused(_ control: String, _ values: [Double], _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 0, action: ScriptedAction(control, values), result: result)
    }

    /// The journey graph's actions from the starter graph (SC-A23-201): Gradient (3), Mix (4) and Blur (5) added, the
    /// starter connection removed, then Noise → Mix a, Gradient → Mix b, Mix → Blur image, Blur → Output image.
    public static var journeyActions: [ScriptedAction] {
        [ScriptedAction("node.add", [3, 40, 240]), ScriptedAction("node.add", [4, 320, 240]),
         ScriptedAction("node.add", [5, 600, 240]), ScriptedAction("edge.disconnect", [2, 0]),
         ScriptedAction("edge.connect", [1, 0, 4, 0]), ScriptedAction("edge.connect", [3, 0, 4, 1]),
         ScriptedAction("edge.connect", [4, 0, 5, 0]), ScriptedAction("edge.connect", [5, 0, 2, 0])]
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them.
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String)] {
        let starter = [accepted("node.select", [1])]
        let journey = journeyActions.map { accepted($0.control, $0.values) }
        let refusedConnection = [accepted("node.add", [1, 40, 240]),
                                 refused("edge.connect", [3, 1, 1, 1], "action.rule." + LabRule.typeMismatch)]
        // Lead, T-A23-210: the planning catalog asks for five fixtures (the content-count audit), so a refused loop and
        // a refused second output follow.
        let refusedLoop = [accepted("node.add", [4, 40, 240]), accepted("node.add", [5, 320, 240]),
                           accepted("edge.connect", [1, 0, 3, 0]), accepted("edge.connect", [3, 0, 4, 0]),
                           refused("edge.connect", [4, 0, 3, 1], "action.rule." + LabRule.cycle),
                           accepted("edge.connect", [1, 0, 3, 1])]
        let refusedSecondOutput = [refused("node.add", [6, 600, 240], "action.rule." + LabRule.oneOutput),
                                   accepted("node.add", [3, 40, 240])]
        return [("fixture-starter-graph", starter, readyCode),
                ("fixture-journey-graph", journey, readyCode),
                ("fixture-refused-connection", refusedConnection, readyCode),
                ("fixture-refused-loop", refusedLoop, readyCode),
                ("fixture-refused-second-output", refusedSecondOutput, readyCode)]
    }

    /// The actions of input-response, save-restore and reset: a Gradient added, moved and selected.
    public static var inputEntries: [ScenarioStep] {
        [accepted("node.add", [3, 40, 240], steps: 10), accepted("node.move", [3, 60, 260], steps: 10),
         accepted("node.select", [3], steps: 10)]
    }

    /// The entries of completion: the Output removed, a new one added and fed by Noise.
    public static var completionEntries: [ScenarioStep] {
        [accepted("node.remove", [2], steps: 10), accepted("node.add", [6, 320, 80], steps: 10),
         accepted("edge.connect", [1, 0, 2, 0], steps: 10)]
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let rule = "action.rule."
        let outOfRange = "action.out-of-range"
        let count = "action.wrong-value-count"
        return [
            refused("node.add", [7, 0, 0], outOfRange),
            refused("node.add", [0, 5_000, 0], outOfRange),
            refused("node.move", [0, 0, 0], outOfRange),
            refused("node.select", [-1], outOfRange),
            refused("edge.connect", [1, 2, 2, 0], outOfRange),
            refused("edge.disconnect", [2, 3], outOfRange),
            refused("node.add", [0.5, 0, 0], rule + LabRule.notWhole),
            refused("node.select", [1.5], rule + LabRule.notWhole),
            refused("edge.connect", [1, 0, 2, 0.5], rule + LabRule.notWhole),
            refused("node.move", [9, 0, 0], rule + LabRule.unknownNode),
            refused("node.remove", [9], rule + LabRule.unknownNode),
            refused("node.select", [9], rule + LabRule.unknownNode),
            refused("edge.connect", [1, 0, 2, 1], rule + LabRule.unknownPort),
            refused("edge.connect", [1, 0, 1, 0], rule + LabRule.typeMismatch),
            refused("edge.connect", [1, 0, 2, 0], rule + LabRule.inputTaken),
            refused("node.add", [6, 0, 0], rule + LabRule.oneOutput),
            refused("node.add", [0, 0], count),
            refused("node.select", [], count),
            refused("edge.disconnect", [2], count),
        ]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> LabCore {
        var core = LabCore()
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
                         expect: ScenarioExpectations(outcome: readyCode)),
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
