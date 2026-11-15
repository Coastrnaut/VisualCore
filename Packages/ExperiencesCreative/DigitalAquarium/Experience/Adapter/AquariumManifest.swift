// AquariumManifest — feature 068 (A09-P01) T-A09-105 (FR-A09-122; SC-A09-105); fixtures 6 and 7 feature 069 (A09-P02)
// T-A09-207 (FR-A09-213). The scenarios the verification runner
// plays for Digital Aquarium: the nine standard ones and one `fixture-<n>` per catalog regression fixture this phase
// can express through actions (research D6), all short (owner rule of 2026-11-13). Host steps advance the fish, so the
// expected digests are derived by playing the entries on a core exactly as the engine plays them (the steps of an
// entry, then its action) and digesting it with the experience id as domain, like Oscilloscope Studio's manifest. The
// properties themselves (bounds over 10,000 steps, refusals of malformed catalogs) are proved by the core tests.
#if DEBUG || VISUALCORE_AUTOMATION
import DigitalAquariumCore
import VisualCoreExperience

extension AquariumCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The actions of input-response, save-restore and reset: the Kelp habitat, bright lighting, a pause.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("habitat.select", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("lighting.level", [2]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("motion.pause", [1]), result: "accepted")]
    }

    /// The entries of rejection: a habitat out of range, a lighting level out of range and a fractional choice.
    public static var rejectionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 0, action: ScriptedAction("habitat.select", [2]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("lighting.level", [-1]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("motion.pause", [0.5]),
                      result: "action.rule." + AquariumRule.invalidChoice)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (a rejected action changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> AquariumCore {
        var core = AquariumCore(seed: seed)
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

    /// The entries of the five catalog fixtures (research D6):
    /// 1. swim bounds: the Reef habitat swims for 600 steps (every fish stays inside, proved over 10,000 steps by
    ///    `AquariumSimulationTests`);
    /// 2. save/restore: the Kelp habitat at bright lighting after 120 steps (the standard save-restore scenario plays it
    ///    through a snapshot);
    /// 3. no fast-forward: paused, then 300 steps change nothing (a suspension stops host steps the same way);
    /// 4. validated catalog: both starter habitats are applied in turn (the bundled catalog validates; refusals of
    ///    malformed catalogs are proved by `SpeciesCatalogTests`);
    /// 5. bounded counts: five habitat switches never grow the fish or plant counts beyond the habitat's definition;
    /// 6. schooling (feature 069, T-A09-207): the Reef habitat swims for 1,800 steps (30 s); `AquariumManifestTests`
    ///    checks that same-species fish end closer together and heading alike (`SchoolMetrics`);
    /// 7. save/load: the Kelp habitat at bright lighting after 240 steps, with its starter decor; the test round-trips it
    ///    through a snapshot and compares species, decor transforms and lighting.
    public static var fixtureEntries: [[ScenarioStep]] {
        func step(_ control: String, _ values: [Double], steps: Int = 5) -> ScenarioStep {
            ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
        }
        return [
            [step("habitat.select", [0]), ScenarioStep(steps: 600)],
            [step("habitat.select", [1]), step("lighting.level", [2]), ScenarioStep(steps: 120)],
            [step("motion.pause", [1]), ScenarioStep(steps: 300)],
            [step("habitat.select", [1], steps: 30), step("habitat.select", [0], steps: 30), ScenarioStep(steps: 30)],
            [step("habitat.select", [1]), step("habitat.select", [0]), step("habitat.select", [1]),
             step("habitat.select", [0]), step("habitat.select", [1]), ScenarioStep(steps: 60)],
            [step("habitat.select", [0]), ScenarioStep(steps: 1_800)],
            [step("habitat.select", [1]), step("lighting.level", [2]), ScenarioStep(steps: 240)],
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
                ScenarioStep(steps: 10, action: ScriptedAction("lighting.level", [0]), result: "accepted"),
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
