// FieldsLifecycleTests — feature 019 T-A02-113 (FR-A02-106–FR-A02-108; SC-A02-104; US3 independent test).
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlayground

@MainActor
final class FieldsLifecycleTests: XCTestCase {
    private func makeHost(_ scene: FluidFieldsScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        host.view.layoutIfNeeded()
        return host
    }

    private func smallConfig(d: Double = 1) -> FluidConfiguration {
        var c = FluidConfiguration()
        c.gridWidth = 32
        c.gridHeight = 32
        c.dyeDissipation = d
        return c
    }

    /// Share of screen pixels clearly brighter than the near-black background.
    private func litFraction(_ host: RenderHost) -> Double {
        let pixels = host.readPixels()
        guard !pixels.isEmpty else { return 0 }
        let count = pixels.count / 4
        let lit = (0..<count).filter { Int(pixels[$0 * 4]) + Int(pixels[$0 * 4 + 1]) + Int(pixels[$0 * 4 + 2]) > 30 }.count
        return Double(lit) / Double(count)
    }

    private func meanDye(_ scene: FluidFieldsScene) throws -> Double {
        let g = try XCTUnwrap(scene.readDye())
        var sum = 0.0
        for cell in 0..<(g.width * g.height) { for c in 0..<3 { sum += Double(g.values[cell * 4 + c]) } }
        return sum / Double(g.width * g.height * 3)
    }

    /// SC-A02-104: a context loss rebuilds both fields with the same live resources, no stale use and no leak.
    func testContextLossRebuildsWithoutLeaks() throws {
        for fallback in [false, true] {
            let scene = FluidFieldsScene(configuration: smallConfig(), forceFallback: fallback)
            scene.fixedDelta = 1.0 / 60
            let host = try makeHost(scene)
            defer { host.destroy() }
            for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
            let afterSetup = host.resources.stats
            XCTAssertEqual(scene.stepCount, 5)
            host.recreateContext()
            XCTAssertEqual(scene.rebuildCount, 1)
            XCTAssertEqual(scene.stepCount, 0, "rebuilt from the configuration, not carried over")
            let staleBefore = host.resources.stats.staleRejected
            for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
            let afterRebuild = host.resources.stats
            XCTAssertEqual(afterRebuild.liveCount, afterSetup.liveCount, "live resources per category match the first setup")
            XCTAssertEqual(afterRebuild.liveBytes, afterSetup.liveBytes)
            XCTAssertEqual(afterRebuild.leaked, 0, "teardown released everything before the old context ended")
            XCTAssertEqual(afterRebuild.staleRejected, staleBefore, "the scene used no stale handle")
            XCTAssertNil(scene.lastError)
            XCTAssertEqual(scene.velocity?.isValid, true)
            XCTAssertGreaterThanOrEqual(litFraction(host), 0.01, "the canvas keeps rendering")
        }
    }

    /// FR-A02-108: one clamped step per frame, never a catch-up loop.
    func testTimeStepIsClamped() throws {
        let scene = FluidFieldsScene(configuration: smallConfig())
        let host = try makeHost(scene)
        defer { host.destroy() }
        scene.fixedDelta = 10
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.lastStep, 1.0 / 30)
        XCTAssertEqual(scene.stepCount, 1, "a long pause gives exactly one step")
        scene.fixedDelta = .nan
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.lastStep, 1.0 / 240)
        scene.fixedDelta = 1.0 / 60
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.lastStep, 1.0 / 60)
    }

    /// US3 independent test: at least 1% non-black pixels, and the mean dye strictly decreases over 30 steps.
    func testCanvasIsVisibleAndFades() throws {
        let scene = FluidFieldsScene(configuration: smallConfig(d: 1))
        scene.fixedDelta = 1.0 / 60
        let host = try makeHost(scene)
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertGreaterThanOrEqual(litFraction(host), 0.01)
        let first = try meanDye(scene)
        for _ in 0..<30 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let later = try meanDye(scene)
        XCTAssertLessThan(later, first, "dye fades when dissipation > 0")
        XCTAssertGreaterThan(later, 0)
    }

    /// Pausing shows the field without stepping it.
    func testPausedSceneDoesNotStep() throws {
        let scene = FluidFieldsScene(configuration: smallConfig())
        let host = try makeHost(scene)
        defer { host.destroy() }
        scene.paused = true
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(scene.stepCount, 0)
        XCTAssertEqual(scene.dye?.swapCount, 0)
    }
}
