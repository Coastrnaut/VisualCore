// RapidEditLeakTests — feature 014 T-A01-306 (US4; FR-A01-308; SC-A01-305; manual Phase 03 regression fixture):
// 200 rapid palette, seed and preset edits on a live scene leave program, texture and render-target counts where
// they started, and destroy reports 0 leaked.
import XCTest
import GenerativeArtStudioCore
import VisualCoreDiagnostics
import VisualCoreRendering
@testable import GenerativeArtStudio

@MainActor
final class RapidEditLeakTests: XCTestCase {
    func testTwoHundredRapidEditsDoNotLeak() throws {
        let kinds: [ResourceKind] = [.program, .texture, .framebuffer, .renderbuffer, .buffer, .vertexArray]
        for family in FamilyCatalog.all {
            let model = SceneModel(family: family, reduceMotion: false)
            let host = try XCTUnwrap(model.host)
            host.view.frame = CGRect(origin: .zero, size: ArtRender.size)
            host.view.layoutIfNeeded()
            for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
            let before = host.resources.stats.liveCount
            let palettes = FamilyCatalog.palettes.map(\.id)
            for i in 0..<200 {
                switch i % 3 {
                case 0: model.editor.choosePalette(palettes[i % palettes.count])
                case 1: model.editor.setSeed(UInt64(i) &* 0x9E37_79B9_7F4A_7C15)
                default: model.editor.choosePreset(family.presets[i % family.presets.count].id)
                }
                XCTAssertTrue(host.renderOneFrame(present: false))
            }
            let after = host.resources.stats.liveCount
            for kind in kinds {
                XCTAssertEqual(after[kind] ?? 0, before[kind] ?? 0, "\(family.id) live \(kind) after 200 edits")
            }
            XCTAssertEqual(host.resources.stats.leaked, 0)
            print("SC-A01-305 \(family.id.rawValue): live before=\(before.values.reduce(0, +)) after=\(after.values.reduce(0, +))")
            model.close()
            XCTAssertEqual(host.resources.stats.leaked, 0, "\(family.id) after destroy")
        }
    }
}
