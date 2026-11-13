// StillRenderTests — feature 193 (UA-F07) T-U07-009 (FR-U07-020). The session renders the open experience's current
// picture off screen on its own host for the experience's export, and refuses without an open experience. Test-only.
import XCTest
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

@MainActor
final class StillRenderTests: XCTestCase {
    func testTheOpenExperiencesPictureIsRenderedOffScreenAtTheAskedSize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        layOut(session)
        let image = try session.renderStill(width: 32, height: 24)
        XCTAssertEqual(image.width, 32)
        XCTAssertEqual(image.height, 24)
        // The centre shows the state's colour, as the live picture does.
        let shell = try XCTUnwrap(probe.shell)
        let core = try XCTUnwrap(shell.engine.core)
        let expected = expectedPixel(for: core)
        let index = (12 * 32 + 16) * 4
        XCTAssertEqual(Int(image.rgba[index]), expected.0, accuracy: 2)
        XCTAssertEqual(Int(image.rgba[index + 1]), expected.1, accuracy: 2)
        XCTAssertEqual(Int(image.rgba[index + 2]), expected.2, accuracy: 2)
        XCTAssertEqual(session.hostsAlive, 1, "no second render host")
    }

    func testWithoutAnOpenExperienceTheRenderIsRefused() async throws {
        let session = ExperienceSession()
        XCTAssertThrowsError(try session.renderStill(width: 8, height: 8))
        let (request, _) = sampleRequest()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        session.close()
        XCTAssertThrowsError(try session.renderStill(width: 8, height: 8))
    }
}
