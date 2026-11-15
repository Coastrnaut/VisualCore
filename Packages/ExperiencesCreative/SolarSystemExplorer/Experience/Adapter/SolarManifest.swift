// SolarManifest — feature 103 (A14-P01) T-A14-105 (FR-A14-122; clarification Q5), state schema 2 by feature 104
// (A14-P02) T-A14-209 (FR-A14-222; contracts/orbit-view.md). The scenarios the verification runner plays for Solar
// System Explorer, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (every seed opens with the Sun selected);
//   - five fixtures `fixture-mercury`, `fixture-earth`, `fixture-jupiter`, `fixture-saturn` and `fixture-neptune` that
//     select Mercury, Earth, Jupiter, Saturn and Neptune by the action `body.select`. The final digest is pinned by
//     ``SolarCore/selectedFixtures`` (committed values; `SolarManifestTests` proves each equal to the derived digest
//     and the played core's selection equal to the fixture's body), and each expects the outcome `viewing-<id>`;
//   - the dated fixture `fixture-earth-2025` (A14-P02): Earth selected, then 25 date steps of +365 days and 7 of +1
//     day (day 9,132, 2025-01-01 12:00 UTC), pinned by ``SolarCore/datedFixtureDigest``.
// Input-response, save-restore and reset also step the date and move the camera; rejection also refuses a date step
// of 7 days (`a14.invalid-step`), one beyond the declared range (`action.out-of-range`), a tilt past 85°
// (`a14.out-of-range`) and a zoom step of 0 (`a14.invalid-step`).
// The completion scenario selects Earth and expects the outcome `viewing-earth`. The expected digests are derived by
// playing the entries on a core exactly as the engine plays them (the steps of an entry, then its action) and
// digesting it with the experience id as domain, as Light Maze's manifest does.
#if DEBUG || VISUALCORE_AUTOMATION
import SolarSystemExplorerCore
import VisualCoreExperience

extension SolarCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 1

    /// The committed digests (engine digest, the experience id as domain) of the state after selecting Mercury,
    /// Earth, Jupiter, Saturn and Neptune by ``fixtureEntries(body:)`` from the first state, by body index (1, 3, 5,
    /// 6, 8), pinned from the first run of `SolarManifestTests` on sim-27.2 (re-pinned at A14-P02: state schema 2).
    public static let selectedFixtures: [(body: Int, digest: String)] = [
        (1, "baeed8b1a8d680336d9e2f878d66ab31ed2318ac9f7998f45e9ce8015880c031"),
        (3, "890b547505b1c63dc84da161a57030f62349994aaff375f8d12c5b3eda10c6f1"),
        (5, "5f9ad101f524613138d1f5ab4864e240a5616a6e7db13a5dae50dc1e008e0ef7"),
        (6, "fb6578cd4b2c8f2df91f769bc36b0a5e3d4630c850f158e8dffdf20653645baa"),
        (8, "458b44ac50bd868a3e1572056fd13ec1486a82e2c9e7e09c3a88c31a28ca97eb"),
    ]

    /// The name of the dated fixture.
    public static let datedFixtureName = "fixture-earth-2025"

    /// The committed digest of the dated fixture (see the file header), pinned from the first run of
    /// `SolarManifestTests` on sim-27.2.
    public static let datedFixtureDigest = "cf1d04fd1ae3373948db427a7cec5bd5ae1b04343e375cbc0d24cb6362d2d398"

    /// The entries of the dated fixture: Earth, then 25 steps of +365 days and 7 of +1 day (day 9,132).
    public static var datedFixtureEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = [ScenarioStep(steps: 1, action: ScriptedAction("body.select", [3]),
                                                    result: "accepted")]
        for _ in 0..<25 {
            entries.append(ScenarioStep(steps: 0, action: ScriptedAction("date.step", [365]), result: "accepted"))
        }
        for _ in 0..<7 {
            entries.append(ScenarioStep(steps: 0, action: ScriptedAction("date.step", [1]), result: "accepted"))
        }
        return entries
    }

    /// The name of the fixture of body index `body`: `fixture-<body id>` (`fixture-earth`).
    public static func fixtureName(body: Int) -> String {
        "fixture-" + (catalog.body(at: body)?.id ?? "body-\(body)")
    }

    /// The outcome code of body index `body`: `viewing-<body id>`.
    public static func outcomeCode(body: Int) -> String {
        outcomePrefix + (catalog.body(at: body)?.id ?? "unknown")
    }

    /// The entry that selects body index `body` from any state (accepted for 0…8).
    public static func fixtureEntries(body: Int) -> [ScenarioStep] {
        [ScenarioStep(steps: 1, action: ScriptedAction("body.select", [Double(body)]), result: "accepted")]
    }

    /// The actions of input-response, save-restore and reset: Earth by the menu, then Mars, back to Earth, a year
    /// and a month forward, the camera orbited, tilted and zoomed, then Neptune.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("body.select", [3]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("body.next"), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("body.previous"), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("date.step", [365]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("date.step", [30]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("camera.orbit", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("camera.tilt", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("camera.zoom", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("body.select", [8]), result: "accepted")]
    }

    /// The entries of completion: Earth selected.
    public static var completionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("body.select", [3]), result: "accepted")]
    }

    /// The entries of rejection, from the Sun: indices out of range and fractional, a step before the first body,
    /// actions with the wrong number of values, then Neptune selected and a step past the last body; then date and
    /// camera steps refused (see the file header) and a view reset accepted.
    public static var rejectionEntries: [ScenarioStep] {
        let invalid = "action.rule." + SolarRule.invalidChoice
        let invalidStep = "action.rule." + SolarRule.invalidStep
        let outOfRange = "action.rule." + SolarRule.outOfRange
        return [ScenarioStep(steps: 0, action: ScriptedAction("body.select", [9]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("body.select", [-1]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("body.select", [0.5]), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("body.previous"), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("body.next", [1]), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("body.previous", [0]),
                             result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("body.select"), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("body.select", [8]), result: "accepted"),
                ScenarioStep(steps: 0, action: ScriptedAction("body.next"), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("date.step", [7]), result: invalidStep),
                ScenarioStep(steps: 0, action: ScriptedAction("date.step", [400]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("camera.tilt", [1]), result: "accepted"),
                ScenarioStep(steps: 0, action: ScriptedAction("camera.tilt", [1]), result: "accepted"),
                ScenarioStep(steps: 0, action: ScriptedAction("camera.tilt", [1]), result: "accepted"),
                ScenarioStep(steps: 0, action: ScriptedAction("camera.tilt", [1]), result: "accepted"),
                ScenarioStep(steps: 0, action: ScriptedAction("camera.tilt", [1]), result: "accepted"),
                ScenarioStep(steps: 0, action: ScriptedAction("camera.tilt", [1]), result: outOfRange),
                ScenarioStep(steps: 0, action: ScriptedAction("camera.zoom", [0]), result: invalidStep),
                ScenarioStep(steps: 0, action: ScriptedAction("view.reset"), result: "accepted")]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> SolarCore {
        var core = SolarCore(seed: seed)
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
                         expect: ScenarioExpectations(outcome: outcomeCode(body: 3))),
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
            specs.append(ScenarioSpec(name: fixtureName(body: fixture.body), seed: seed,
                                      entries: fixtureEntries(body: fixture.body),
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: fixture.digest,
                                                                   outcome: outcomeCode(body: fixture.body))))
        }
        specs.append(ScenarioSpec(name: datedFixtureName, seed: seed, entries: datedFixtureEntries,
                                  expect: ScenarioExpectations(initialDigest: initial, finalDigest: datedFixtureDigest,
                                                               outcome: outcomeCode(body: 3))))
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
