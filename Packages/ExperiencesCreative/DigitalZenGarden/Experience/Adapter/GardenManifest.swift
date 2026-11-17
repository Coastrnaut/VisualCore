// GardenManifest — feature 146 (A20-P02) T-A20-208 (FR-A20-206; clarification Q5). The scenarios the verification
// runner plays for Digital Zen Garden, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (nothing depends on the seed);
//   - five fixtures: `fixture-raked-garden` (two fine strokes, `strokes-2`), `fixture-wide-rake` (`rake.style [1]`
//     and one wide stroke, `strokes-1`), `fixture-undo` (a stroke, then `edit.undo`, `strokes-0`), `fixture-redo`
//     (a stroke, `edit.undo`, `edit.redo`, `strokes-1`) and `fixture-tone` (`sand.tone [2]`, grey sand,
//     `strokes-0`).
// A stroke is `stroke.begin [x, y, rake]`, one `stroke.add` of twelve points along a straight drag and `stroke.end`.
// Input-response and reset rake one stroke, change the tone and choose the wide rake; completion rakes one stroke and
// expects `strokes-1`; rejection refuses `stroke.add` and `stroke.end` without a stroke, undo and redo with nothing to
// undo or redo, values out of range, fractional choices and wrong value counts. Save-restore plays the input entries:
// the snapshot and the digest are the garden document (clarification Q5), so the restored garden has the same digest.
// The expected digests are derived by playing the entries on a core exactly as the engine plays them (the steps of an
// entry, then its action) and digesting it with the experience id as domain, as Living Wallpapers' manifest does.
//
// Feature 147 (A20-P03) T-A20-307 (FR-A20-301, FR-A20-303; SC-A20-301; contracts/stones.md "Commands"): five stone
// fixtures, each ending at `strokes-0` (no stroke is raked): `fixture-stone-placed` (`tool.mode [1]` and
// `stone.place [2, 0.4, 0.5]`, a round granite), `fixture-stone-moved` (placed, `stone.select [1]` and `stone.move
// [0.7, 0.3]`), `fixture-stone-rotated` (placed and `stone.rotate [0.5]`), `fixture-stone-removed` (placed and
// `stone.remove`) and `fixture-stone-remove-undone` (placed, removed and `edit.undo`: the stone is back, unselected).
// Rejection also refuses `stone.move`, `stone.rotate` and `stone.remove` without a selection, `stone.select` of an
// unknown id and a fractional `tool.mode`.
#if DEBUG || VISUALCORE_AUTOMATION
import DigitalZenGardenCore
import VisualCoreExperience
import VisualCoreMath

extension GardenCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// The outcome code of a garden of `count` strokes: `strokes-<count>`.
    static func strokesCode(_ count: Int) -> String { strokesCodePrefix + String(count) }

    /// The three entries of one straight stroke from `start` to `end` with the rake `rake`: the begin at `start`, one
    /// add of twelve points evenly along the drag (the last at `end`) and the end; `steps` steps before each.
    public static func strokeEntries(from start: Vec2, to end: Vec2, rake: Int, steps: Int = 1) -> [ScenarioStep] {
        var values: [Double] = []
        for index in 1...pointsPerAdd {
            let t = Double(index) / Double(pointsPerAdd)
            values.append(start.x + (end.x - start.x) * t)
            values.append(start.y + (end.y - start.y) * t)
        }
        return [ScenarioStep(steps: steps, action: ScriptedAction("stroke.begin", [start.x, start.y, Double(rake)]),
                             result: "accepted"),
                ScenarioStep(steps: steps, action: ScriptedAction("stroke.add", values), result: "accepted"),
                ScenarioStep(steps: steps, action: ScriptedAction("stroke.end"), result: "accepted")]
    }

    /// One accepted entry of `control` with `values`.
    static func accepted(_ control: String, _ values: [Double] = [], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them.
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String)] {
        let first = strokeEntries(from: Vec2(0.15, 0.3), to: Vec2(0.85, 0.35), rake: 0)
        let second = strokeEntries(from: Vec2(0.2, 0.7), to: Vec2(0.8, 0.6), rake: 0)
        let wide = [accepted("rake.style", [1])] + strokeEntries(from: Vec2(0.5, 0.15), to: Vec2(0.45, 0.85), rake: 1)
        return [
            ("fixture-raked-garden", first + second, strokesCode(2)),
            ("fixture-wide-rake", wide, strokesCode(1)),
            ("fixture-undo", first + [accepted("edit.undo")], strokesCode(0)),
            ("fixture-redo", first + [accepted("edit.undo"), accepted("edit.redo")], strokesCode(1)),
            ("fixture-tone", [accepted("sand.tone", [2])], strokesCode(0)),
        ] + stoneFixtures
    }

    /// The five stone fixtures (feature 147; see the file header).
    public static var stoneFixtures: [(name: String, entries: [ScenarioStep], outcome: String)] {
        let placed = [accepted("tool.mode", [1]), accepted("stone.place", [2, 0.4, 0.5])]
        return [
            ("fixture-stone-placed", placed, strokesCode(0)),
            ("fixture-stone-moved", placed + [accepted("stone.select", [1]), accepted("stone.move", [0.7, 0.3])],
             strokesCode(0)),
            ("fixture-stone-rotated", placed + [accepted("stone.rotate", [0.5])], strokesCode(0)),
            ("fixture-stone-removed", placed + [accepted("stone.remove")], strokesCode(0)),
            ("fixture-stone-remove-undone", placed + [accepted("stone.remove"), accepted("edit.undo")],
             strokesCode(0)),
        ]
    }

    /// The actions of input-response and reset: one fine stroke, the warm tone and the wide rake.
    public static var inputEntries: [ScenarioStep] {
        strokeEntries(from: Vec2(0.1, 0.5), to: Vec2(0.9, 0.45), rake: 0, steps: 10)
            + [accepted("sand.tone", [1], steps: 10), accepted("rake.style", [1], steps: 10)]
    }

    /// The entries of completion: one stroke raked.
    public static var completionEntries: [ScenarioStep] {
        strokeEntries(from: Vec2(0.3, 0.2), to: Vec2(0.7, 0.8), rake: 0, steps: 10)
    }

    /// The entries of rejection, from the opening state (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        let rule = "action.rule."
        let point = [Double](repeating: 0.5, count: pointsPerAdd * 2)
        return [
            ScenarioStep(steps: 0, action: ScriptedAction("stroke.add", point), result: rule + GardenRule.noStroke),
            ScenarioStep(steps: 0, action: ScriptedAction("stroke.end"), result: rule + GardenRule.noStroke),
            ScenarioStep(steps: 0, action: ScriptedAction("edit.undo"), result: rule + GardenRule.nothingToUndo),
            ScenarioStep(steps: 0, action: ScriptedAction("edit.redo"), result: rule + GardenRule.nothingToRedo),
            ScenarioStep(steps: 0, action: ScriptedAction("stroke.begin", [1.5, 0.5, 0]),
                         result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("stroke.begin", [0.5, 0.5, 0.5]),
                         result: rule + GardenRule.invalidChoice),
            ScenarioStep(steps: 0, action: ScriptedAction("stroke.begin", [0.5, 0.5]),
                         result: "action.wrong-value-count"),
            ScenarioStep(steps: 0, action: ScriptedAction("stroke.add", [0.5, 0.5]),
                         result: "action.wrong-value-count"),
            ScenarioStep(steps: 0, action: ScriptedAction("rake.style", [2]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("rake.style", [0.5]), result: rule + GardenRule.invalidChoice),
            ScenarioStep(steps: 0, action: ScriptedAction("sand.tone", [3]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("stone.move", [0.5, 0.5]), result: rule + GardenRule.noSelection),
            ScenarioStep(steps: 0, action: ScriptedAction("stone.rotate", [0.5]), result: rule + GardenRule.noSelection),
            ScenarioStep(steps: 0, action: ScriptedAction("stone.remove"), result: rule + GardenRule.noSelection),
            ScenarioStep(steps: 0, action: ScriptedAction("stone.select", [7]), result: rule + GardenRule.unknownStone),
            ScenarioStep(steps: 0, action: ScriptedAction("tool.mode", [0.5]), result: rule + GardenRule.invalidChoice),
            ScenarioStep(steps: 0, action: ScriptedAction("stone.place", [5, 0.5, 0.5]),
                         result: "action.out-of-range"),
        ]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> GardenCore {
        var core = GardenCore()
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
                         expect: ScenarioExpectations(outcome: strokesCode(1))),
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
