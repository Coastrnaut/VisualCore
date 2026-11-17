// WallpaperManifest — feature 139 (A19-P02) T-A19-212 (FR-A19-206; clarification Q5). The scenarios the verification
// runner plays for Living Wallpapers, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (the A19-P01 default project's seed);
//   - five fixtures (the planning catalog's content count): `fixture-scene-ink-flow` (`scene.select [1]`),
//     `fixture-preset-third` (`scene.preset [2]`), `fixture-template-ipad-landscape` (`canvas.template [5]`, the
//     iPad Pro 13-inch (M4), then `canvas.orientation [1]`), `fixture-time-set` (`scene.time [42.5]`) and
//     `fixture-parameter-changed` (`scene.parameter [0, 6]`, six aurora bands), expecting `scene-ink-flow` and four
//     times `scene-aurora-bands`.
// Input-response, save-restore and reset play `scene.preset [1]`, `scene.parameter [1, 0.8]` and
// `canvas.template [3]`; completion selects the ripple dunes and expects `scene-ripple-dunes`; rejection refuses
// values out of range, fractional choices, a parameter outside its scene's range and a wrong value count. The
// expected digests are derived by playing the entries on a core exactly as the engine plays them (the steps of an
// entry, then its action) and digesting it with the experience id as domain, as Ambient Clock's manifest does.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience

extension WallpaperCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// The outcome code of scene `id`: `scene-<id>`.
    static func sceneCode(_ id: String) -> String { sceneCodePrefix + id }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them.
    public static let fixtures: [(name: String, entries: [ScenarioStep], outcome: String)] = [
        ("fixture-scene-ink-flow",
         [ScenarioStep(steps: 1, action: ScriptedAction("scene.select", [1]), result: "accepted")],
         sceneCode("ink-flow")),
        ("fixture-preset-third",
         [ScenarioStep(steps: 1, action: ScriptedAction("scene.preset", [2]), result: "accepted")],
         sceneCode("aurora-bands")),
        ("fixture-template-ipad-landscape",
         [ScenarioStep(steps: 1, action: ScriptedAction("canvas.template", [5]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("canvas.orientation", [1]), result: "accepted")],
         sceneCode("aurora-bands")),
        ("fixture-time-set",
         [ScenarioStep(steps: 1, action: ScriptedAction("scene.time", [42.5]), result: "accepted")],
         sceneCode("aurora-bands")),
        ("fixture-parameter-changed",
         [ScenarioStep(steps: 1, action: ScriptedAction("scene.parameter", [0, 6]), result: "accepted")],
         sceneCode("aurora-bands")),
    ]

    /// The actions of input-response, save-restore and reset: the second preset, more drift, the iPhone 16.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("scene.preset", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("scene.parameter", [1, 0.8]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("canvas.template", [3]), result: "accepted")]
    }

    /// The entries of completion: the ripple dunes selected.
    public static var completionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("scene.select", [3]), result: "accepted")]
    }

    /// The entries of rejection, from the opening state: values out of range, fractional choices, a parameter
    /// outside its scene's range and a wrong value count.
    public static var rejectionEntries: [ScenarioStep] {
        let invalid = "action.rule." + WallpaperRule.invalidChoice
        return [
            ScenarioStep(steps: 0, action: ScriptedAction("scene.select", [4]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("scene.preset", [0.5]), result: invalid),
            ScenarioStep(steps: 0, action: ScriptedAction("scene.parameter", [0, 9]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("scene.time", [3601]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("canvas.orientation", [0.5]), result: invalid),
            ScenarioStep(steps: 0, action: ScriptedAction("motion.enabled", [2]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("scene.parameter", [0]), result: "action.wrong-value-count"),
        ]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> WallpaperCore {
        var core = WallpaperCore(seed: seed)
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
                         expect: ScenarioExpectations(outcome: sceneCode("ripple-dunes"))),
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
