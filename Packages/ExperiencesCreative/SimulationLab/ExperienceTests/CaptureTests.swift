// CaptureTests — feature 120 (A16-P04) T-A16-409 (FR-A16-440; SC-A16-404; clarification Q5). Capturing the field in a
// session through the host's own still renderer (`ExperienceSession.renderStill`): two captures of a running
// simulation leave one 1024 × 1024 PNG, the simulation is paused around each capture and running again afterwards, and
// the field, the step count and the digest are those of before; a throwing renderer leaves no file and the message.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class CaptureTests: XCTestCase {
    func testCapturesLeaveOnePNGAndChangeNothing() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        XCTAssertTrue(try SimulationTest.core(shell).isRunning)
        let core = try SimulationTest.core(shell)
        for _ in 0..<2 {
            presenter.captureStill(through: shell.port) { width, height in
                try session.renderStill(width: width, height: height)
            }
        }
        let url = try XCTUnwrap(presenter.capture.url, "\(presenter.capture.message ?? "")")
        XCTAssertEqual(presenter.capture.folder.fileCount, 1, "one PNG")
        let png = try Data(contentsOf: url)
        XCTAssertEqual(png.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]), "a PNG")
        // The IHDR chunk holds the width and the height as big-endian 32-bit integers at bytes 16 and 20.
        let width = png[16..<20].reduce(0) { $0 << 8 | Int($1) }, height = png[20..<24].reduce(0) { $0 << 8 | Int($1) }
        XCTAssertEqual([width, height], [1024, 1024])
        let after = try SimulationTest.core(shell)
        XCTAssertEqual(after.model.field, core.model.field)
        XCTAssertEqual(after.stepCount, core.stepCount)
        XCTAssertTrue(after.isRunning, "resumed")
        XCTAssertEqual(after.model.scheduler.speedIndex, core.model.scheduler.speedIndex)
        struct Failure: Error {}
        presenter.captureStill(through: shell.port) { _, _ in throw Failure() }
        XCTAssertNil(presenter.capture.url)
        XCTAssertEqual(presenter.capture.folder.fileCount, 0)
        XCTAssertEqual(presenter.capture.message, SimulationCapture.failureSentence)
        session.close()
    }
}
