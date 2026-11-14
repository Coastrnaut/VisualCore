// GeometryManifest — feature 040 (A05-P01) T-A05-108 (FR-A05-130). The scenarios the verification runner plays for
// Infinite Geometry: the nine standard ones, all short (owner rule of 2026-11-13). Unlike Particle Universe, whose
// committed digests are constants checked by the host tests, the expected digests here are derived when the manifest
// is built: a composition is static (`update(step:)` does nothing), so the state after the entries is the prepared
// core with the accepted actions applied, and its digest is computed exactly as the engine computes it (a
// `DigestBuilder` with the experience id as domain). The input values are chosen against curated preset 0 so that
// each one changes the preset. The committed `scenario-manifest.json` is checked against this manifest by
// `GeometryManifestTests` and rewritten with `UPDATE_SCENARIO_MANIFEST=1`.
#if DEBUG || VISUALCORE_AUTOMATION
import InfiniteGeometryCore
import VisualCoreExperience

extension GeometryCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The actions of input-response, save-restore and reset: repetitions, scale, palette and a new motif seed on
    /// curated preset 0, then the 3D composition with another symmetry order. Each value differs from the current
    /// one, so every action is accepted.
    public static var inputEntries: [ScenarioStep] {
        let start = GeometryPreset.curated[0]
        let repeats = start.repeats == 2 ? 3 : 2
        let scale = start.scale == 1.5 ? 2.0 : 1.5
        let palette = (start.palette + 1) % (GeometryPreset.paletteRange.upperBound + 1)
        let solidIndex = GeometryPreset.curated.firstIndex { $0.kind == .solid } ?? GeometryPreset.curated.count - 1
        let order = GeometryPreset.curated[solidIndex].order == 6 ? 5 : 6
        return [ScenarioStep(steps: 2, action: ScriptedAction("repeats.set", [Double(repeats)]), result: "accepted"),
                ScenarioStep(steps: 2, action: ScriptedAction("scale.set", [scale]), result: "accepted"),
                ScenarioStep(steps: 2, action: ScriptedAction("palette.set", [Double(palette)]), result: "accepted"),
                ScenarioStep(steps: 2, action: ScriptedAction("reseed"), result: "accepted"),
                ScenarioStep(steps: 2, action: ScriptedAction("preset.select", [Double(solidIndex)]), result: "accepted"),
                ScenarioStep(steps: 2, action: ScriptedAction("symmetry.order", [Double(order)]), result: "accepted")]
    }

    /// The entries of rejection on curated preset 0 (a tiling): an order on the lattice, an unchanged selection and
    /// a palette outside the range.
    public static var rejectionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 0, action: ScriptedAction("symmetry.order", [6]), result: "action.rule." + orderFixedCode),
         ScenarioStep(steps: 0, action: ScriptedAction("preset.select", [0]), result: "action.rule." + unchangedCode),
         ScenarioStep(steps: 0, action: ScriptedAction("palette.set", [9]), result: "action.out-of-range")]
    }

    /// The digest of the core prepared with `seed` after the accepted actions of `entries`, computed as the engine
    /// computes it; nil when the preparation does not build or the digest cannot be written.
    public static func expectedDigest(for id: ExperienceID, seed: UInt64, entries: [ScenarioStep]) -> String? {
        guard var core = try? GeometryCore(seed: seed) else { return nil }
        for entry in entries {
            guard let action = entry.action else { continue }
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: 0))
        }
        var builder = DigestBuilder(domain: id.rawValue)
        do {
            try core.writeDigest(into: &builder)
        } catch {
            return nil
        }
        return builder.finish().hex
    }

    /// The manifest of the experience `id`.
    public static func manifest(for id: ExperienceID, seed: UInt64 = manifestSeed) -> ScenarioManifest {
        let input = inputEntries
        let initial = expectedDigest(for: id, seed: seed, entries: [])
        let final = expectedDigest(for: id, seed: seed, entries: input)
        let specs = [
            ScenarioSpec(name: "launch-first-frame", seed: seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: initial)),
            ScenarioSpec(name: "input-response", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "completion", seed: seed, entries: [
                ScenarioStep(steps: 2, action: ScriptedAction("preset.select", [1]), result: "accepted"),
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
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
