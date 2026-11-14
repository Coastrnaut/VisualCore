// GeometryManifest — feature 040 (A05-P01) T-A05-108 (FR-A05-130). The scenarios the verification runner plays for
// Infinite Geometry: the nine standard ones and one `fixture-<n>` per regression fixture of the planning catalog
// (the content-count audit requires the five), all short (owner rule of 2026-11-13). Unlike Particle Universe, whose
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

    /// The index of the first curated preset of `kind`.
    static func curatedIndex(_ kind: GeometryPreset.Kind) -> Int {
        GeometryPreset.curated.firstIndex { $0.kind == kind } ?? 0
    }

    /// The entries of the five regression fixtures of the planning catalog, in its order:
    /// 1. symmetry order one is the identity and higher orders repeat: the kaleidoscope at order 1, then 6;
    /// 2. mesh generation has index bounds and valid normals: the 3D composition rebuilt at orders 3 and 8 (every
    ///    accepted build is a closed, validated mesh — `Composition.build` refuses anything else);
    /// 3. zoom clamps avoid singular states: the scale at both bounds is accepted and beyond them refused; the 2D
    ///    camera zoomed far beyond its upper bound stops at 8, a further zoom is refused as unchanged and a zero
    ///    factor is out of range (A05-P02); on the 3D composition the field of view is accepted at 30° and 75° and refused
    ///    beyond, a pan stops at the target radius (a further pan is refused as unchanged) and the maximum zoom stops at
    ///    the bounding-sphere distance (A05-P03, FR-A05-330);
    /// 4. repeated preset transitions leave the state stable: two full cycles through the four presets end where they
    ///    began (final digest = initial digest; the records' GPU counts show no leak);
    /// 5. non-square displays keep proportions: the hexagonal tiling at scale 0.5 drawn on the phone's non-square
    ///    view (the presenter fits the shorter side; `GeometrySessionTests` checks the fit on a 160 × 240 view).
    public static var fixtureEntries: [[ScenarioStep]] {
        let kaleidoscope = Double(curatedIndex(.kaleidoscope)), solid = Double(curatedIndex(.solid))
        let hex = Double(curatedIndex(.hexTiling))
        func step(_ control: String, _ values: [Double] = [], _ result: String = "accepted") -> ScenarioStep {
            ScenarioStep(steps: 1, action: ScriptedAction(control, values), result: result)
        }
        let cycle = (1..<GeometryPreset.curated.count).map { step("preset.select", [Double($0)]) } + [step("preset.select", [0])]
        return [
            [step("preset.select", [kaleidoscope]), step("symmetry.order", [1]), step("symmetry.order", [6])],
            [step("preset.select", [solid]), step("symmetry.order", [3]), step("symmetry.order", [8])],
            [step("scale.set", [GeometryPreset.scaleRange.lowerBound]), step("scale.set", [GeometryPreset.scaleRange.upperBound]),
             step("scale.set", [GeometryPreset.scaleRange.upperBound + 1], "action.out-of-range"),
             step("scale.set", [GeometryPreset.scaleRange.lowerBound / 2], "action.out-of-range"),
             step("camera.zoom", [GeometryCore.zoomFactorRange.upperBound]),
             step("camera.zoom", [GeometryCore.zoomFactorRange.upperBound], "action.rule." + unchangedCode),
             step("camera.zoom", [0], "action.out-of-range"),
             step("preset.select", [solid]),
             step("camera.fov", [GeometryCore.fovRange.lowerBound]), step("camera.fov", [GeometryCore.fovRange.upperBound]),
             step("camera.fov", [GeometryCore.fovRange.upperBound + 5], "action.out-of-range"),
             step("camera.pan", [0.6, 0]), step("camera.pan", [0.6, 0]),
             step("camera.pan", [0.6, 0], "action.rule." + unchangedCode),
             step("camera.zoom", [GeometryCore.zoomFactorRange.upperBound]),
             step("camera.zoom", [GeometryCore.zoomFactorRange.upperBound], "action.rule." + unchangedCode)],
            cycle + cycle,
            [step("preset.select", [hex]), step("scale.set", [0.5])],
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
