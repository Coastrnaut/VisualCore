// ExportModelTests — feature 015 T-A01-410 and T-A01-411 (announcements) (spec Clarifications: temporary file lifetime; edge case "the export file
// stays available until the sheet closes"; FR-A01-405, FR-A01-407).
import XCTest
import GenerativeArtStudioCore
import VisualCoreDiagnostics
import VisualCoreRendering
import VisualCoreScenes
@testable import GenerativeArtStudio

@MainActor
final class ExportModelTests: XCTestCase {
    private func sceneModel(budget: ResourceBudget = ResourceBudget()) throws -> SceneModel {
        let family = FamilyCatalog.family(.gradientNoise)
        let m = SceneModel(family: family, reduceMotion: false, editor: CompositionEditor(family: family),
                           makeHost: { try RenderHost(scene: $0, budget: budget) })
        let host = try XCTUnwrap(m.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 48)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        return m
    }

    func testFileLivesUntilOptionsChangeOrClose() async throws {
        let scene = try sceneModel()
        defer { scene.close() }
        let model = ExportModel(scene: scene, name: "My Stars")
        XCTAssertNotNil(model.preview, "crop preview rendered")
        model.options.longEdge = 1080
        model.options.aspect = .portrait
        await model.run()
        guard case .ready(let url) = model.phase else { return XCTFail("phase \(model.phase)") }
        XCTAssertEqual(url.lastPathComponent, "My-Stars-864x1080.png")
        XCTAssertEqual(model.announcement, "Export ready", "T-A01-411 completion announced")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "Exports")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "available while the sheet is open")

        model.options.aspect = .story   // options change → file removed, back to idle
        XCTAssertEqual(model.phase, .idle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))

        await model.run()
        guard case .ready(let second) = model.phase else { return XCTFail("phase \(model.phase)") }
        XCTAssertEqual(second.lastPathComponent, "My-Stars-608x1080.png")
        model.removeFile()   // what the sheet does on close
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
    }

    func testStartIsAnnounced() async throws {
        let scene = try sceneModel()
        defer { scene.close() }
        let model = ExportModel(scene: scene, name: "A")
        model.options.longEdge = 1080
        model.options.aspect = .landscape
        let task = Task { await model.run() }
        await Task.yield()
        XCTAssertEqual(model.phase, .rendering)
        XCTAssertEqual(model.announcement, "Rendering 1080 × 608 px", "T-A01-411 start announced")
        await task.value
        model.removeFile()
    }

    func testFailedExportIsReadable() async throws {
        let scene = try sceneModel(budget: ResourceBudget(total: 8 << 20))
        defer { scene.close() }
        let model = ExportModel(scene: scene, name: "Big")
        model.options.longEdge = 2048
        model.options.aspect = .square
        await model.run()
        guard case .failed(let message) = model.phase else { return XCTFail("phase \(model.phase)") }
        XCTAssertTrue(message.contains("graphics memory"), message)
        XCTAssertEqual(model.announcement, message, "T-A01-411 failure announced")
        XCTAssertEqual(try XCTUnwrap(scene.host).resources.stats.liveCount[.framebuffer], 0)
    }
}
