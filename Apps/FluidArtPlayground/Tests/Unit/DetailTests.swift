// DetailTests — feature 023 T-A02-509 (FR-A02-511, SC-A02-507; US1 AC6; edge cases "detail change during a swipe",
// "a detail level larger than the device allows").
import FluidArtPlaygroundCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import XCTest
@testable import FluidArtPlayground

@MainActor
final class DetailTests: XCTestCase {
    private func makeModel(maxEdge: Int = 512) throws -> PlaygroundModel {
        let model = PlaygroundModel(maxEdge: maxEdge)
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
        host.view.layoutIfNeeded()
        model.scene.fixedDelta = 1.0 / 60
        return model
    }

    /// SC-A02-507: each level gives its grid; the default is Medium; other settings and the pause are kept.
    func testEachLevelBuildsItsGrid() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.detail, .medium)
        XCTAssertEqual(model.scene.configuration.gridWidth, 128)
        model.configuration.viscosity = 0.25
        model.togglePause()
        for level in [FluidDetail.low, .high, .medium] {
            model.setDetail(level)
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertEqual(model.scene.configuration.gridWidth, level.edge, "\(level)")
            XCTAssertEqual(model.scene.configuration.gridHeight, level.edge)
            XCTAssertEqual(model.scene.velocity?.width, level.edge)
            XCTAssertEqual(model.detail, level)
            XCTAssertEqual(model.scene.stepCount, 0, "restarted from the seed")
            XCTAssertEqual(model.scene.configuration.viscosity, 0.25, "tuning kept")
            XCTAssertTrue(model.scene.paused, "pause kept")
            XCTAssertNil(model.scene.lastError)
        }
    }

    /// SC-A02-507: 10 switches leave no leaked resources, and the live count returns to the Medium setup's.
    func testTenSwitchesLeakNothing() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let medium = host.resources.stats
        let levels: [FluidDetail] = [.low, .high, .medium, .high, .low, .medium, .low, .high, .low, .medium]
        for level in levels {
            model.setDetail(level)
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertTrue(host.renderOneFrame(present: false))
        }
        let after = host.resources.stats
        XCTAssertEqual(after.leaked, 0)
        XCTAssertEqual(after.liveCount, medium.liveCount)
        XCTAssertEqual(after.liveBytes, medium.liveBytes)
        XCTAssertEqual(model.scene.rebuildCount, 10)
    }

    /// Edge case: a level larger than the device allows is capped, as at first open.
    func testOversizedLevelIsCapped() throws {
        let model = try makeModel(maxEdge: 100)
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.configuration.gridWidth, 100, "Medium capped at first open")
        model.setDetail(.high)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.configuration.gridWidth, 100)
        XCTAssertNil(model.detailMessage)
    }

    /// Edge case: if the new fields cannot be built, the previous grid comes back with a message.
    func testFailedRebuildFallsBack() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        var failures = 1
        model.scene.uploadSeed = { target, values in
            if failures > 0 { failures -= 1; return false }
            return target.upload(rgbaFloats: values)
        }
        model.setDetail(.high)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertTrue(model.scene.rebuildFellBack)
        XCTAssertEqual(model.scene.configuration.gridWidth, 128, "previous grid restored")
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.configuration.gridWidth, 128)
        XCTAssertEqual(model.detail, .medium)
        XCTAssertEqual(model.detailMessage, "That detail level is not available on this device.")
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }

    /// Edge case: a detail change during a swipe ends the stroke and drops queued touches.
    func testDetailChangeDuringSwipeEndsStroke() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        model.handle(PointerEvent(id: 1, phase: .began, location: Vec2(20, 50), timestamp: 0))
        model.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(40, 60), timestamp: 0.05))
        XCTAssertGreaterThan(model.queue.pendingCount, 0)
        model.setDetail(.low)
        XCTAssertEqual(model.queue.pendingCount, 0)
        model.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(60, 70), timestamp: 0.1))
        XCTAssertEqual(model.queue.pendingCount, 0, "the ended stroke adds nothing")
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.configuration.gridWidth, 64)
    }
}
