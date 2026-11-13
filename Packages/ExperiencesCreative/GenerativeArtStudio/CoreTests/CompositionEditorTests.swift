// CompositionEditorTests — feature 013 T-A01-205 (FR-A01-201, FR-A01-203; SC-A01-201).
import Foundation
import Testing
import VisualCoreParameters
import VisualCoreSimulation
@testable import GenerativeArtStudioCore

@Test func everyParameterStaysInRangeForAnyPosition() {
    var checked = 0
    for family in FamilyCatalog.all {
        var e = CompositionEditor(family: family)
        for d in family.schema.definitions {
            for t in [0.0, 1, -1, 2, .nan, .infinity, -.infinity] {
                e.setParameter(d.name, normalized: t)
                let v = e.composition.parameters[d.name]!
                #expect(v.isFinite && d.range.contains(v), "\(family.id).\(d.name) at \(t) → \(v)")
            }
            checked += 1
        }
        #expect((try? e.composition.validated().warnings) == [], "\(family.id) composition stays valid")
    }
    #expect(checked == 20, "SC-A01-201 covers all 20 parameters")
}

@Test func resetReturnsToThePresetBaseline() {
    let family = FamilyCatalog.family(.gradientNoise)
    var e = CompositionEditor(family: family)
    let preset = e.composition.parameters
    e.setParameter("warp", normalized: 1)
    e.setParameter("scale", normalized: 0)
    #expect(e.editor.modifiedNames == ["scale", "warp"])
    e.resetParameter("warp")
    #expect(e.composition.parameters["warp"] == preset["warp"])
    e.resetAll()
    #expect(e.composition.parameters == preset)
    e.choosePreset("noise-tide")
    #expect(e.presetID == "noise-tide" && e.composition.seed == 2024 && e.composition.paletteID == "ocean")
    #expect(e.composition.parameters["scale"] == 6)
    e.setParameter("scale", normalized: 0)
    e.resetAll()
    #expect(e.composition.parameters["scale"] == 6, "reset targets the selected preset, not schema defaults")
}

@Test func paletteAndSeedChoices() {
    var e = CompositionEditor(family: FamilyCatalog.family(.particles))
    let before = e.composition
    e.choosePalette("ocean")
    #expect(e.composition.paletteID == "ocean")
    #expect(e.composition.parameters == before.parameters && e.composition.seed == before.seed, "only the palette changed")
    e.choosePalette("nope")
    #expect(e.composition.paletteID == "ocean")
    var rng = SeededRandom(seed: 1)
    e.shuffleSeed(using: &rng)
    #expect(e.composition.seed != before.seed)
    e.setSeed(.max)
    #expect(e.composition.seed == .max)
    e.choosePreset("no-such-preset")
    #expect(e.composition.seed == .max)
    e.useDefault()
    #expect(e.composition == CompositionEditor(family: FamilyCatalog.family(.particles)).composition.with(id: e.composition.id))
}

@Test func editorUpdatesFromThePanelBinding() throws {
    var e = CompositionEditor(family: FamilyCatalog.family(.geometricTiling))
    var panel = e.editor
    panel.set("cells", to: 12)
    e.updateEditor(panel)
    #expect(e.composition.parameters["cells"] == 12)
    let other = try ParameterEditor(schema: FamilyCatalog.family(.particles).schema)
    e.updateEditor(other)
    #expect(e.composition.parameters["cells"] == 12, "an editor for another schema is ignored")
}

extension ArtDocument {
    func with(id: UUID) -> ArtDocument { var d = self; d.id = id; return d }
}
