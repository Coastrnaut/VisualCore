// PingPongTargetTests — feature 019 T-A02-104 (G-PINGPONG; FR-A02-103, FR-A02-105, FR-A02-107).
import VisualCoreDiagnostics
import XCTest
@testable import VisualCoreRendering

@MainActor
final class PingPongTargetTests: XCTestCase {
    func testSwapAlternatesAndRolesNeverCoincide() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let pair = try PingPongTarget(registry: context.resources, width: 8, height: 4, format: .rgba8, label: "p")
            defer { pair.release() }
            let a = pair.read, b = pair.write
            XCTAssertFalse(a === b)
            pair.swap()
            XCTAssertTrue(pair.read === b && pair.write === a)
            pair.swap()
            XCTAssertTrue(pair.read === a && pair.write === b)
            XCTAssertEqual(pair.swapCount, 2)
            XCTAssertEqual([pair.width, pair.height], [8, 4])
            XCTAssertEqual(pair.format, .rgba8)
        }
    }

    func testBudgetAccountingAndRelease() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let before = context.resources.stats
            let pair = try PingPongTarget(registry: context.resources, width: 16, height: 8, format: .rgba16f, label: "p")
            XCTAssertEqual(pair.bytes, 2 * 16 * 8 * 8)
            let during = context.resources.stats
            XCTAssertEqual(during.liveCount[.framebuffer, default: 0], before.liveCount[.framebuffer, default: 0] + 2)
            XCTAssertEqual(during.liveBytes[.framebuffer, default: 0], before.liveBytes[.framebuffer, default: 0] + pair.bytes)
            pair.release()
            pair.release()   // idempotent
            XCTAssertEqual(context.resources.stats.liveCount, before.liveCount)
            XCTAssertEqual(context.resources.stats.liveBytes, before.liveBytes)
            XCTAssertFalse(pair.isValid)
            let count = pair.swapCount
            pair.swap()
            XCTAssertEqual(pair.swapCount, count, "swap after release is ignored")
        }
    }

    func testFailedSecondAllocationLeaksNothing() throws {
        let scene = ClosureScene()
        // Room for exactly one 16x16 RGBA8 target (1 KiB) in the framebuffer budget.
        let host = try RenderHost(scene: scene, budget: ResourceBudget(total: 64 << 20, perKind: [.framebuffer: 1024 + 512]))
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let before = context.resources.stats
            XCTAssertThrowsError(try PingPongTarget(registry: context.resources, width: 16, height: 16, format: .rgba8, label: "p"))
            XCTAssertEqual(context.resources.stats.liveCount, before.liveCount)
            XCTAssertEqual(context.resources.stats.liveBytes, before.liveBytes)
        }
    }

    func testContextLossInvalidatesAndStaleUseIsRejected() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var kept: PingPongTarget?
        try withContext(host, scene) { context in
            kept = try PingPongTarget(registry: context.resources, width: 4, height: 4, format: .rgba8, label: "p")
        }
        let pair = try XCTUnwrap(kept)
        XCTAssertTrue(pair.isValid)
        host.recreateContext()
        XCTAssertFalse(pair.isValid)
        try withContext(host, scene) { context in
            let stale = context.resources.stats.staleRejected
            pair.read.bind()
            XCTAssertEqual(context.resources.stats.staleRejected, stale + 1)
            pair.release()   // ignored for stale GL names, no crash
        }
    }
}
