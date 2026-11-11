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

/// Why composition data could not be opened; every case is recoverable ("Use default").
public enum CompositionOpenError: Error, Equatable, Sendable {
    /// Unreadable data (not JSON, bad fields, too large).
    case corrupt(String)
    /// Written by a newer version of the app.
    case unsupportedVersion(Int)
    /// Names a scene family this version does not have.
    case unknownFamily(String)

    /// Short user-facing title.
    public var title: String {
        switch self {
        case .corrupt: "Couldn’t read this composition"
        case .unsupportedVersion: "Made with a newer version"
        case .unknownFamily: "Unknown scene type"
        }
    }

    /// User-facing explanation with the recovery offered.
    public var message: String {
        switch self {
        case .corrupt: "The composition data is damaged. You can continue with the default preset."
        case .unsupportedVersion(let v): "This composition uses format version \(v), which this version of the app can’t open. You can continue with the default preset."
        case .unknownFamily(let id): "This composition uses a scene type (“\(id)”) that this version doesn’t have. You can continue with the default preset."
        }
    }
}

/// Outcome of opening composition data.
public enum OpenResult: Equatable, Sendable {
    /// Opened; `notes` lists corrections (clamped values, palette fallback).
    case opened(notes: [String])
    /// Not opened; the previous composition is kept and the error offers recovery.
    case failed(CompositionOpenError)
}

extension CompositionEditor {
    /// Largest composition data accepted (bytes).
    public static let maxDataSize = 64 * 1024

    /// Classifies and opens `data` for any family: an editor for the composition's family, or `fallback`'s default
    /// preset with a recoverable error. The data itself is never modified.
    public static func open(_ data: Data, fallback: SceneFamilyID) -> (editor: CompositionEditor, result: OpenResult) {
        switch decode(data) {
        case .success(let (document, notes)):
            var editor = CompositionEditor(family: document.family ?? FamilyCatalog.family(fallback))
            editor.composition = document
            editor.presetID = nil
            editor.notes = notes
            try? editor.editor.rebase(document.parameters)
            return (editor, .opened(notes: notes))
        case .failure(let error):
            return (CompositionEditor(family: FamilyCatalog.family(fallback)), .failed(error))
        }
    }

    /// Opens `data` into this editor when it is valid for the same family; on failure the current composition is kept.
    public mutating func open(_ data: Data) -> OpenResult {
        switch Self.decode(data) {
        case .success(let (document, notes)):
            guard document.familyID == family.id.rawValue else { return .failed(.unknownFamily(document.familyID)) }
            composition = document
            presetID = nil
            self.notes = notes
            try? editor.rebase(document.parameters)
            return .opened(notes: notes)
        case .failure(let error):
            return .failed(error)
        }
    }

    private static func decode(_ data: Data) -> Result<(ArtDocument, [String]), CompositionOpenError> {
        guard data.count <= maxDataSize else { return .failure(.corrupt("larger than \(maxDataSize) bytes")) }
        do { return .success(try ArtDocument.decode(data)) } catch {
            switch error {
            case .unsupportedVersion(let v): return .failure(.unsupportedVersion(v))
            case .unknownFamily(let id): return .failure(.unknownFamily(id))
            case .nonFinite(let name): return .failure(.corrupt("non-finite \(name)"))
            case .corrupt(let reason): return .failure(.corrupt(reason))
            }
        }
    }
}
