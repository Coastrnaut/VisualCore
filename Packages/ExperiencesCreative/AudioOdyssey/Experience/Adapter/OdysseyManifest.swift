// OdysseyManifest — feature 054 (A07-P01) T-A07-106 (FR-A07-120). The scenarios the verification runner plays for
// Audio Odyssey: the nine standard ones and one `fixture-<n>` per regression fixture this phase proves (watertight
// joins; comfort limits), all short (owner rule of 2026-11-13). The flight advances with every step, so the expected
// digests are derived by playing the entries on a core exactly as the engine plays them (the steps of an entry, then
// its action) and digesting it with the experience id as domain, like Music Lab's manifest.
#if DEBUG || VISUALCORE_AUTOMATION
import AudioOdysseyCore
import VisualCoreExperience

extension OdysseyCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The actions of input-response, save-restore and reset: fast speed, the landscape, a pause.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 30, action: ScriptedAction("speed.select", [2]), result: "accepted"),
         ScenarioStep(steps: 30, action: ScriptedAction("world.select", [1]), result: "accepted"),
         ScenarioStep(steps: 30, action: ScriptedAction("flight.pause"), result: "accepted")]
    }

    /// The entries of rejection: a world out of range, a speed out of range and a resume while flying.
    public static var rejectionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 0, action: ScriptedAction("world.select", [3]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("speed.select", [-1]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("flight.resume"), result: "action.rule." + OdysseyRule.notPaused)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (a rejected action changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> OdysseyCore {
        var core = OdysseyCore(seed: seed)
        var step = 0
        for entry in entries {
            for _ in 0..<max(0, entry.steps) {
                core.update(step: step)
                step += 1
            }
            guard let action = entry.action else { continue }
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: step))
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

    /// The entries of the two regression fixtures of this phase:
    /// 1. watertight joins: the flight crosses several piece boundaries (8 units each) while every world is selected in
    ///    turn and a new journey is started, so the presenter builds and joins fresh pieces of all three worlds (the
    ///    joins themselves are proved within 1e-9 by `WorldPiecesTests`); the final digest proves the switches kept
    ///    distance and speed;
    /// 2. comfort limits: fast is chosen and held, then slow, then a pause and a resume; the speed eases within the
    ///    standard limits throughout (proved step by step by `OdysseyCoreTests` and `RailFlightTests`).
    public static var fixtureEntries: [[ScenarioStep]] {
        func step(_ control: String, _ values: [Double] = [], _ result: String = "accepted", steps: Int) -> ScenarioStep {
            ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: result)
        }
        return [
            [step("world.select", [1], steps: 240), step("world.select", [2], steps: 240),
             step("journey.reseed", steps: 240), step("world.select", [0], steps: 240), ScenarioStep(steps: 240)],
            [step("speed.select", [2], steps: 10), step("speed.select", [0], steps: 600),
             step("flight.pause", steps: 240), step("flight.resume", steps: 240), ScenarioStep(steps: 120)],
        ]
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
            ScenarioSpec(name: "completion", seed: seed, entries: [
                ScenarioStep(steps: 30, action: ScriptedAction("speed.select", [2]), result: "accepted"),
            ], expect: ScenarioExpectations(outcome: outcomeCode)),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        for (index, entries) in fixtureEntries.enumerated() {
            specs.append(ScenarioSpec(name: "fixture-\(index + 1)", seed: seed, entries: entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: expectedDigest(for: id, seed: seed,
                                                                                               entries: entries))))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
