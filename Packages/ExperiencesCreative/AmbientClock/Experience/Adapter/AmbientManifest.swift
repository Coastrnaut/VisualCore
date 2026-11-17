// AmbientManifest — feature 132 (A18-P02) T-A18-208 (FR-A18-210; research D6). The scenarios the verification
// runner plays for Ambient Clock, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (every seed opens with the default format and theme);
//   - five fixtures (the planning catalog's content count): `fixture-time-zone-changed` (`time.set` of a fixed
//     instant, then `time.changed [2]`), `fixture-motion-off` (`theme.motion [0]`), `fixture-twenty-four-hour`
//     (`clock.format [2, 0, 1]`), `fixture-seconds-shown` (`clock.format [0, 1, 1]`) and `fixture-slow-motion`
//     (`theme.speed [0.25]`), expecting the outcomes `showing-time`, `motion-off`, `showing-time`, `showing-time` and
//     `showing-time`.
// The completion scenario turns motion off and expects `motion-off`. The instant and the time-change revision come
// from the wall clock and are left out of the digest (research D1), so a fixture of time actions alone keeps the
// opening digest. The expected digests are derived by playing the entries on a core exactly as the engine plays them
// (the steps of an entry, then its action) and digesting it with the experience id as domain, as Interactive
// Anatomy's manifest does.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience

extension AmbientCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// A fixed instant of the fixtures: 2026-06-15T18:05:00Z.
    public static let fixtureInstant: Double = 1_781_546_700

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them.
    public static let fixtures: [(name: String, entries: [ScenarioStep], outcome: String)] = [
        ("fixture-time-zone-changed",
         [ScenarioStep(steps: 1, action: ScriptedAction("time.set", [fixtureInstant]), result: "accepted"),
          ScenarioStep(steps: 1, action: ScriptedAction("time.changed", [2]), result: "accepted")],
         showingTimeCode),
        ("fixture-motion-off",
         [ScenarioStep(steps: 1, action: ScriptedAction("theme.motion", [0]), result: "accepted")],
         motionOffCode),
        ("fixture-twenty-four-hour",
         [ScenarioStep(steps: 1, action: ScriptedAction("clock.format", [2, 0, 1]), result: "accepted")],
         showingTimeCode),
        ("fixture-seconds-shown",
         [ScenarioStep(steps: 1, action: ScriptedAction("clock.format", [0, 1, 1]), result: "accepted")],
         showingTimeCode),
        ("fixture-slow-motion",
         [ScenarioStep(steps: 1, action: ScriptedAction("theme.speed", [0.25]), result: "accepted")],
         showingTimeCode),
    ]

    /// The actions of input-response, save-restore and reset: 24-hour time with seconds, a slower background, the
    /// date line off.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("clock.format", [2, 1, 1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("theme.speed", [0.5]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("clock.format", [2, 1, 0]), result: "accepted")]
    }

    /// The entries of completion: motion turned off.
    public static var completionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("theme.motion", [0]), result: "accepted")]
    }

    /// The entries of rejection, from the opening state: values out of range, fractional choices and wrong value
    /// counts.
    public static var rejectionEntries: [ScenarioStep] {
        let invalid = "action.rule." + AmbientRule.invalidChoice
        return [
            ScenarioStep(steps: 0, action: ScriptedAction("theme.speed", [2.5]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("time.changed", [5]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("clock.format", [3, 0, 0]), result: "action.out-of-range"),
            ScenarioStep(steps: 0, action: ScriptedAction("time.changed", [0.5]), result: invalid),
            ScenarioStep(steps: 0, action: ScriptedAction("theme.motion", [0.5]), result: invalid),
            ScenarioStep(steps: 0, action: ScriptedAction("clock.format", [0, 1]), result: "action.wrong-value-count"),
        ]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> AmbientCore {
        var core = AmbientCore()
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
                         expect: ScenarioExpectations(outcome: motionOffCode)),
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
