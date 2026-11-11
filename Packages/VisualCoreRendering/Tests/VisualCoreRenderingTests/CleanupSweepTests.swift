// CleanupSweepTests — feature 010 T-F919 (FR-F908): the package's own sample scenes go through setup → frames →
// context loss → frames → destroy with zero leaked GPU resources (app/harness scenes are swept in their own tests).
import XCTest
@testable import VisualCoreRendering

@MainActor
final class CleanupSweepTests: XCTestCase {
    static func sweep(_ scene: RenderScene, id: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        host.view.layoutIfNeeded()
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false), "\(id) before loss", file: file, line: line) }
        let generation = host.resources.generation
        host.recreateContext()
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false), "\(id) after loss", file: file, line: line) }
        XCTAssertEqual(host.resources.generation, generation + 1, id, file: file, line: line)
        XCTAssertEqual(host.resources.stats.leaked, 0, "\(id): after context loss", file: file, line: line)
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0, "\(id): after destroy", file: file, line: line)
    }

    func testGradientQuadScene() throws { try Self.sweep(GradientQuadScene(), id: "GradientQuadScene") }
    func testClearColorScene() throws { try Self.sweep(ClearColorScene(red: 0.1, green: 0.2, blue: 0.3), id: "ClearColorScene") }
}
