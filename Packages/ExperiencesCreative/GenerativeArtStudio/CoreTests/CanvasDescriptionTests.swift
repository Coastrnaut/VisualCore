// CanvasDescriptionTests — feature 016 T-A01-506 (FR-A01-503).
import Testing
@testable import GenerativeArtStudioCore

@Test func defaultPresetIsDescribed() {
    for family in FamilyCatalog.all {
        let editor = CompositionEditor(family: family)
        let d = CanvasDescription(document: editor.composition, isPlaying: true)
        #expect(d.family == family.title)
        #expect(d.preset == family.defaultPreset.title)
        #expect(d.palette == FamilyCatalog.palette(family.defaultPreset.paletteID)?.name)
        #expect(d.text == "\(family.title), \(family.defaultPreset.title) preset, \(d.palette!) palette, seed \(family.defaultPreset.seed), playing.")
    }
}

@Test func editsChangeTheDescription() {
    let family = FamilyCatalog.all[0]
    var editor = CompositionEditor(family: family)
    let before = CanvasDescription(document: editor.composition, isPlaying: true)
    let other = FamilyCatalog.palettes.first { $0.id != editor.composition.paletteID }!
    editor.choosePalette(other.id)
    let after = CanvasDescription(document: editor.composition, isPlaying: false)
    #expect(after.palette == other.name)
    #expect(after.preset == nil, "a changed palette no longer matches the preset")
    #expect(after.text.contains("custom preset, \(other.name) palette"))
    #expect(after.text.hasSuffix("paused."))
    #expect(after != before)
}

@Test func unknownPaletteIsCustom() {
    var doc = CompositionEditor(family: FamilyCatalog.all[1]).composition
    doc.paletteID = "nope"
    #expect(CanvasDescription(document: doc, isPlaying: true).text.contains("custom palette"))
}
