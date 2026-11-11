// OpenCompositionTests — feature 013 T-A01-209 (FR-A01-205; US3; SC-A01-204).
import Foundation
import Testing
@testable import GenerativeArtStudioCore

private func json(family: String = "geometric-tiling", version: Int = 1, extra: String = "") -> Data {
    Data(#"{"familyID":"\#(family)","id":"00000000-0000-0000-0000-0000000000AA","paletteID":"neon","parameters":{"cells":9\#(extra)},"previewTime":0,"schemaVersion":\#(version),"seed":"77"}"#.utf8)
}

@Test func threeFailureClassesAreRecoverable() {
    let cases: [(Data, CompositionOpenError)] = [
        (Data("not json".utf8), .corrupt("")), (json(version: 7), .unsupportedVersion(7)), (json(family: "watercolor"), .unknownFamily("watercolor")),
        (Data(repeating: 32, count: CompositionEditor.maxDataSize + 1), .corrupt("")),
    ]
    for (data, expected) in cases {
        let (editor, result) = CompositionEditor.open(data, fallback: .gradientNoise)
        guard case .failed(let error) = result else { Issue.record("expected failure for \(expected)"); continue }
        switch (error, expected) {
        case (.corrupt, .corrupt): break
        default: #expect(error == expected)
        }
        #expect(!error.title.isEmpty && error.message.contains("default preset"))
        #expect(editor.family.id == .gradientNoise && editor.presetID == FamilyCatalog.family(.gradientNoise).defaultPreset.id)
    }
    if case .failed(let e) = CompositionEditor.open(json(version: 7), fallback: .particles).result { #expect(e.message.contains("version 7")) }
}

@Test func correctableDataOpensWithNotes() throws {
    let (editor, result) = CompositionEditor.open(json(extra: #","symmetry":99,"bogus":1"#), fallback: .gradientNoise)
    guard case .opened(let notes) = result else { Issue.record("expected opened"); return }
    #expect(editor.family.id == .geometricTiling && editor.composition.seed == 77 && editor.presetID == nil)
    #expect(editor.composition.parameters["symmetry"] == 12)
    #expect(notes.contains("bogus: unknown parameter dropped") && notes.contains { $0.hasPrefix("symmetry: 99.0 clamped") })
    #expect(editor.editor.values == editor.composition.parameters && editor.editor.modifiedNames.isEmpty)
}

@Test func failedOpenKeepsThePreviousComposition() {
    var editor = CompositionEditor(family: FamilyCatalog.family(.geometricTiling))
    editor.setParameter("cells", normalized: 1)
    let before = editor.composition
    let data = json(version: 9)
    let copy = data
    #expect(editor.open(data) == .failed(.unsupportedVersion(9)))
    #expect(editor.composition == before)
    #expect(data == copy, "data is not modified")
    #expect(editor.open(json(family: "particles")) == .failed(.unknownFamily("particles")), "another family is not opened in place")
    #expect(editor.open(json()) == .opened(notes: []))
    #expect(editor.composition.parameters["cells"] == 9)
}
