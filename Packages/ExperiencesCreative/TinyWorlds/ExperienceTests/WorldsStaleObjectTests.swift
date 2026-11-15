// WorldsStaleObjectTests — feature 093 (A12-P05) T-A12-505 (FR-A12-503; SC-A12-503; clarification Q4; research D4).
// The stale-object fixture of Tiny Worlds: 20 short cycles, each in a new session over one shared `WorldStore`, open a
// pack (cycling the three), save slot 0 and open it, set the host tier (cycling 0…2), recreate the context and close.
// Before its resources are read every cycle returns to pack 0 at tier 0, so all cycles end in the same world: the
// registry then holds the same live objects and bytes per kind as in cycle 1, nothing has leaked, and every close
// leaves no GPU object behind. About 7 frames per cycle; nothing is measured by wall clock.
import Foundation
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class WorldsStaleObjectTests: XCTestCase {
    private var temporary: TemporaryWorldsStorage!

    override func setUp() async throws {
        temporary = TemporaryWorldsStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    func testTwentyLoadAndUnloadCyclesLeaveNoStaleGraphicsObjects() async throws {
        let store = WorldStore(storage: temporary.storage)
        var reference: ResourceLedger.Snapshot?
        for cycle in 1...20 {
            let session = ExperienceSession()
            let shell = try await WorldsTest.open(session, store: store)
            let presenter = shell.presenter
            let pack = (cycle - 1) % 3
            XCTAssertTrue(shell.handle(control: "world.pack", values: [Double(pack)]).isAccepted, "cycle \(cycle)")
            try WorldsTest.frames(session, 1)

            // Save slot 0 (with its thumbnail) and open it again.
            let saved = presenter.saveWorld(slot: 0, still: WorldsTest.stillRenderer(session))
            XCTAssertTrue(saved.hasPrefix("Saved"), "cycle \(cycle): \(saved)")
            let opened = presenter.openWorld(slot: 0)
            XCTAssertTrue(opened.hasPrefix("Opened"), "cycle \(cycle): \(opened)")

            // A host tier, then a context recreation.
            try shell.setQualityTier((cycle - 1) % 3)
            try WorldsTest.frames(session, 1)
            session.recreateContext()
            XCTAssertEqual(session.state, .running, "cycle \(cycle)")
            try WorldsTest.frames(session, 1)

            // Back to the same world and tier in every cycle, so the resources compare like with like.
            try shell.setQualityTier(0)
            XCTAssertTrue(shell.handle(control: "world.pack", values: [0]).isAccepted, "cycle \(cycle)")
            try WorldsTest.frames(session, 2)
            let stats = try XCTUnwrap(session.renderHost).resources.stats
            XCTAssertEqual(stats.leaked, 0, "cycle \(cycle)")
            if let reference {
                XCTAssertEqual(stats.liveCount, reference.liveCount, "cycle \(cycle): the same live objects per kind")
                XCTAssertEqual(stats.liveBytes, reference.liveBytes, "cycle \(cycle): the same live bytes per kind")
            } else {
                reference = stats
            }
            session.close()
            XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0, "cycle \(cycle)")
        }
    }
}
