// LibraryRenderTests — feature 014 T-A01-305 (FR-A01-303; SC-A01-302): a saved composition reloaded through a new
// library instance renders the same image as before saving.
import XCTest
import GenerativeArtStudioCore
import VisualCoreSimulation
import VisualCoreTestSupport
@testable import GenerativeArtStudio

@MainActor
final class LibraryRenderTests: XCTestCase {
    func testSavedCompositionReloadsAndRendersIdentically() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gas-lib-render-\(UUID().uuidString)")
        var rng = SeededRandom(seed: 77)
        var library = CompositionLibrary(directory: dir)
        var expected: [(UUID, [UInt8])] = []
        for family in FamilyCatalog.all {
            var editor = CompositionEditor(family: family)
            for d in family.schema.definitions { editor.setParameter(d.name, normalized: rng.double()) }
            editor.choosePalette(FamilyCatalog.palettes[Int(rng.next() % 6)].id)
            editor.setSeed(rng.next())
            let before = try ArtRender.pixels(editor.composition)
            let entry = try library.save(document: editor.composition, name: family.title)
            expected.append((entry.id, before))
        }
        var reopened = CompositionLibrary(directory: dir)
        reopened.reload()
        XCTAssertEqual(reopened.entries.count, 4)
        for (id, before) in expected {
            let entry = try XCTUnwrap(reopened.entry(id))
            let after = try ArtRender.pixels(entry.document)
            let d = ImageComparison.compare(before, after)
            XCTAssertGreaterThanOrEqual(d.fractionWithin(2), 0.99, entry.name)
            print("SC-A01-302 \(entry.document.familyID): within2=\(d.fractionWithin(2)) max=\(d.maxAbsolute)")
        }
    }
}
