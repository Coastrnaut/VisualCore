// CompositionEditor.swift — the composition being edited on the scene screen: preset, palette, seed and parameters, kept
// validated, with a VisualCore ParameterEditor for the panel (feature 013 T-A01-205; FR-A01-201, FR-A01-203).
import Foundation
import VisualCoreParameters

/// Edits one family's composition. Every mutation leaves `composition` validated; parameter edits go through the
/// VisualCore `ParameterEditor`, whose baseline is the selected preset (reset target).
public struct CompositionEditor: Sendable {
    /// The family being edited.
    public let family: SceneFamily
    /// The current, validated composition.
    public private(set) var composition: ArtDocument
    /// The selected preset id (nil after opening external data).
    public private(set) var presetID: String?
    /// Corrections made while opening or choosing (clamped values, palette fallbacks).
    public private(set) var notes: [String] = []
    /// Parameter editing state for the panel; its baseline is the selected preset.
    public private(set) var editor: ParameterEditor

    /// Starts from the family's default preset.
    public init(family: SceneFamily) {
        self.family = family
        let preset = family.defaultPreset
        let doc = (try? ArtDocument.from(preset, family: family.id).validated().document)
            ?? ArtDocument(family: family.id, seed: preset.seed, paletteID: family.defaultPaletteID, parameters: family.schema.defaults)
        composition = doc
        presetID = preset.id
        editor = (try? ParameterEditor(schema: family.schema, values: doc.parameters))
            ?? (try! ParameterEditor(schema: family.schema))
    }

    /// Applies a preset: its seed, palette and values; the editor baseline becomes the preset values.
    public mutating func choosePreset(_ id: String) {
        guard let preset = family.presets.first(where: { $0.id == id }) else { return }
        var doc = composition
        doc.seed = preset.seed
        doc.paletteID = preset.paletteID
        doc.parameters = preset.values
        apply(doc, rebase: true)
        presetID = id
    }

    /// Switches the palette (unknown ids are ignored).
    public mutating func choosePalette(_ id: String) {
        guard FamilyCatalog.palette(id) != nil else { return }
        composition.paletteID = id
    }

    /// Sets the seed.
    public mutating func setSeed(_ seed: UInt64) { composition.seed = seed }

    /// Picks a new seed from `generator` (the UI passes the system generator).
    public mutating func shuffleSeed<G: RandomNumberGenerator>(using generator: inout G) {
        var next = generator.next()
        if next == composition.seed { next &+= 1 }
        composition.seed = next
    }

    /// Sets a parameter from a slider position; values stay in range.
    public mutating func setParameter(_ name: String, normalized t: Double) {
        editor.set(name, normalized: t)
        composition.parameters = editor.values
    }

    /// Replaces the editing state (from the panel binding); values are already clamped by the editor.
    public mutating func updateEditor(_ newEditor: ParameterEditor) {
        guard newEditor.schema == editor.schema else { return }
        editor = newEditor
        composition.parameters = editor.values
    }

    /// Returns one parameter to the preset value.
    public mutating func resetParameter(_ name: String) {
        editor.reset(name)
        composition.parameters = editor.values
    }

    /// Returns every parameter to the preset values.
    public mutating func resetAll() {
        editor.resetAll()
        composition.parameters = editor.values
    }

    /// Restarts from the family's default preset (recovery action).
    public mutating func useDefault() {
        self = CompositionEditor(family: family)
    }

    mutating func apply(_ document: ArtDocument, rebase: Bool) {
        guard let (valid, warnings) = try? document.validated() else { return }
        composition = valid
        notes = warnings
        if rebase { try? editor.rebase(valid.parameters) } else { updateEditorValues(valid.parameters) }
    }

    private mutating func updateEditorValues(_ values: [String: Double]) {
        for (name, value) in values { editor.set(name, to: value) }
    }
}
