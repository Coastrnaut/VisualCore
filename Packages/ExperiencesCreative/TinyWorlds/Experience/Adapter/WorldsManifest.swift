// WorldsManifest — feature 089 (A12-P01) T-A12-106 (FR-A12-112, FR-A12-122; SC-A12-101, SC-A12-106; research D5).
// The scenarios the verification runner plays for Tiny Worlds, all short (owner rule of 2026-11-13):
//   - the nine standard scenarios, prepared with seed 1 (the default world: the island, seed 1);
//   - nine fixtures `fixture-<preset id>-<seed>` for the presets island, asteroid-garden and miniature-city and the
//     seeds 1, 2 and 3: each is prepared with the seed (the preparation seed names the world's seed, `WorldsCore`),
//     chooses its preset and expects the final digest of that world. The core's digest includes the terrain digest,
//     so each fixture pins the terrain; `terrainFixtures` holds the nine committed terrain digests (the same values
//     as the core's `TerrainFixtureTests`), and `WorldsManifestTests` proves every fixture's world generates its
//     committed terrain digest;
//   - three refusal scenarios: `refusal-preset-out-of-range` (preset 3, refused by the engine as out of range),
//     `refusal-preset-fractional` (preset 1.5, refused with `a12.invalid-choice`) and `refusal-zoom-out-of-range`
//     (zoom factor 0.25, a fraction below the 0.5…2 range, refused as out of range), each ending in its initial
//     digest.
// The expected digests are derived by playing the entries on a core exactly as the engine plays them (the steps of an
// entry, then its action) and digesting it with the experience id as domain, as Physics Playground's manifest does.
//
// Feature 091 (A12-P03) T-A12-303 (FR-A12-302, FR-A12-303, FR-A12-310, FR-A12-323; SC-A12-301, SC-A12-302): the prop
// and light scenarios, all on the island of seed 1:
//   - `fixture-props-island-1` (the phase's regression fixture: placed props persist at exact transforms): places a
//     tree at the centre, a house at (1.5, 0.5) and a rock at (−1, 1.25), selects the tree, moves it by (0.5, −0.5),
//     turns it by 45°, selects the rock and deletes it, then sets the light (azimuth 120°, elevation 30°, ambient
//     0.2); its final digest pins every transform and the light;
//   - `refusal-prop-outside` (x 5.8 m: `a12.outside`), `refusal-prop-under-water` (the island's corner (5.4, 5.4):
//     `a12.under-water`), `refusal-prop-too-close` (a second prop 0.3 m from the first: `a12.too-close`, after an
//     accepted placement) and `refusal-prop-no-selection` (`prop.delete` with nothing selected: `a12.no-selection`);
//     the first, second and fourth end in their initial digest;
//   - the rejection scenario also refuses a prop kind 4 and an elevation of 90° (out of range) and a move with
//     nothing selected.
#if DEBUG || VISUALCORE_AUTOMATION
import TinyWorldsCore
import VisualCoreExperience

extension WorldsCore {
    /// The seed of every standard scenario: the default world, seed 1.
    public static let manifestSeed: UInt64 = 1

    /// The fixture seeds.
    public static let fixtureSeeds: [UInt32] = [1, 2, 3]

    /// The committed terrain digests (`TerrainGenerator.digest(preset:seed:)`) of the three presets for seeds 1, 2 and
    /// 3, in preset order, then seed order.
    public static let terrainFixtures: [(preset: WorldPresetID, seed: UInt32, digest: String)] = [
        (.island, 1, "6ad87d5fc0b62b720eae3d381c2600ef634d0acee52982bacdf688452f70f2b7"),
        (.island, 2, "28eac395e65fc6fcf2713725b6c5b1b2515af373ee85b76fdd5610daa2c06dec"),
        (.island, 3, "b05b9dc71fa964666d6d6d7c15f10485d0590611b1395ef10ff00f09d6a792d8"),
        (.asteroidGarden, 1, "7ccda10cef6cbf900d8a63fcb8fe0ae4cc730e309f0b1218a70e3f18f25fd8da"),
        (.asteroidGarden, 2, "25e90b4078828e0df874e530dcdd92d4473e177f51cd9332295e3f51167da032"),
        (.asteroidGarden, 3, "9d44402cdee8b731ee4c7ae86378e76e7db3752b33d4068ae8dd0da9a04f1bd0"),
        (.miniatureCity, 1, "a82c2679d9bb729d61c166aede28cc798627e5f7189d2975dfc3c0c22d12082a"),
        (.miniatureCity, 2, "0f7cfa9a93f4d79fb66cbea3cfdd278d2b8c2205c11aa8d8a80eb64edfa7d644"),
        (.miniatureCity, 3, "12581638b5b7a92b00efc0e1f3ba45bdeba5d36767cdafb5ed95bbcfbcbb65d4"),
    ]

    /// The name of the fixture of `preset` and `seed`: `fixture-<preset content id>-<seed>`.
    public static func fixtureName(_ preset: WorldPresetID, seed: UInt32) -> String {
        "fixture-\(preset.contentId)-\(seed)"
    }

    /// The entries of the fixture of `preset`: choose the preset (accepted, also when it is already shown).
    public static func fixtureEntries(_ preset: WorldPresetID) -> [ScenarioStep] {
        [ScenarioStep(steps: 0, action: ScriptedAction("world.preset", [Double(preset.rawValue)]), result: "accepted")]
    }

    /// The actions of input-response, save-restore and reset: the asteroid garden, a new seed, a turn with a tilt and
    /// a zoom in.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("world.preset", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("world.seed"), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("view.orbit", [-30, 15]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("view.zoom", [1.25]), result: "accepted")]
    }

    /// The entries of rejection: presets out of range and fractional, zoom factors out of range, an orbit step out of
    /// range, and actions with the wrong number of values.
    public static var rejectionEntries: [ScenarioStep] {
        let invalid = "action.rule." + WorldsRule.invalidChoice
        return [ScenarioStep(steps: 0, action: ScriptedAction("world.preset", [3]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("world.preset", [-1]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("world.preset", [0.5]), result: invalid),
                ScenarioStep(steps: 0, action: ScriptedAction("view.zoom", [3]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("view.zoom", [0.25]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("view.orbit", [200, 0]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("world.seed", [1]), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("view.reset", [0]), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("view.orbit", [10]), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("prop.place", [4, 0, 0]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("light.elevation", [90]), result: "action.out-of-range"),
                ScenarioStep(steps: 0, action: ScriptedAction("prop.move", [0.5, 0]),
                             result: "action.rule." + WorldEditRefusal.noSelection.rawValue)]
    }

    /// The entries of `fixture-props-island-1` (see the file header).
    public static var propEntries: [ScenarioStep] {
        func step(_ control: String, _ values: [Double] = []) -> ScenarioStep {
            ScenarioStep(steps: 1, action: ScriptedAction(control, values), result: "accepted")
        }
        return [step("prop.place", [0, 0, 0]), step("prop.place", [2, 1.5, 0.5]), step("prop.place", [1, -1, 1.25]),
                step("prop.select", [0]), step("prop.move", [0.5, -0.5]), step("prop.rotate", [45]),
                step("prop.select", [2]), step("prop.delete"), step("light.azimuth", [120]),
                step("light.elevation", [30]), step("light.ambient", [0.2])]
    }

    /// The prop refusal scenarios by name with their entries (see the file header), and whether they end in their
    /// initial digest.
    public static var propRefusalScenarios: [(name: String, entries: [ScenarioStep], unchanged: Bool)] {
        func rule(_ refusal: WorldEditRefusal) -> String { "action.rule." + refusal.rawValue }
        return [
            ("refusal-prop-outside",
             [ScenarioStep(steps: 0, action: ScriptedAction("prop.place", [0, 5.8, 0]), result: rule(.outside))], true),
            ("refusal-prop-under-water",
             [ScenarioStep(steps: 0, action: ScriptedAction("prop.place", [3, 5.4, 5.4]), result: rule(.underWater))],
             true),
            ("refusal-prop-too-close",
             [ScenarioStep(steps: 0, action: ScriptedAction("prop.place", [0, 0, 0]), result: "accepted"),
              ScenarioStep(steps: 0, action: ScriptedAction("prop.place", [1, 0.3, 0]), result: rule(.tooClose))],
             false),
            ("refusal-prop-no-selection",
             [ScenarioStep(steps: 0, action: ScriptedAction("prop.delete"), result: rule(.noSelection))], true),
        ]
    }

    /// The refusal scenarios by name with their single entry (see the file header).
    public static var refusalScenarios: [(name: String, entry: ScenarioStep)] {
        [("refusal-preset-out-of-range",
          ScenarioStep(steps: 0, action: ScriptedAction("world.preset", [3]), result: "action.out-of-range")),
         ("refusal-preset-fractional",
          ScenarioStep(steps: 0, action: ScriptedAction("world.preset", [1.5]),
                       result: "action.rule." + WorldsRule.invalidChoice)),
         ("refusal-zoom-out-of-range",
          ScenarioStep(steps: 0, action: ScriptedAction("view.zoom", [0.25]), result: "action.out-of-range"))]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> WorldsCore {
        var core = WorldsCore(seed: seed)
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
        let completion = [ScenarioStep(steps: 10, action: ScriptedAction("world.preset", [2]), result: "accepted")]
        var specs = [
            ScenarioSpec(name: "launch-first-frame", seed: seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: initial)),
            ScenarioSpec(name: "input-response", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "completion", seed: seed, entries: completion,
                         expect: ScenarioExpectations(outcome: outcomeCode(.miniatureCity))),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        for fixture in terrainFixtures {
            let fixtureSeed = UInt64(fixture.seed)
            let entries = fixtureEntries(fixture.preset)
            specs.append(ScenarioSpec(
                name: fixtureName(fixture.preset, seed: fixture.seed), seed: fixtureSeed, entries: entries,
                expect: ScenarioExpectations(initialDigest: expectedDigest(for: id, seed: fixtureSeed, entries: []),
                                             finalDigest: expectedDigest(for: id, seed: fixtureSeed,
                                                                         entries: entries))))
        }
        for refusal in refusalScenarios {
            specs.append(ScenarioSpec(name: refusal.name, seed: seed, entries: [refusal.entry],
                                      expect: ScenarioExpectations(initialDigest: initial, finalDigest: initial)))
        }
        let props = propEntries
        specs.append(ScenarioSpec(name: "fixture-props-island-1", seed: seed, entries: props,
                                  expect: ScenarioExpectations(initialDigest: initial,
                                                               finalDigest: expectedDigest(for: id, seed: seed,
                                                                                           entries: props))))
        for refusal in propRefusalScenarios {
            let final = refusal.unchanged ? initial : expectedDigest(for: id, seed: seed, entries: refusal.entries)
            specs.append(ScenarioSpec(name: refusal.name, seed: seed, entries: refusal.entries,
                                      expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
