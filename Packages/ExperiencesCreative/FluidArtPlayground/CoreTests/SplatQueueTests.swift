// SplatQueueTests — feature 020 T-A02-208 (FR-A02-204, SC-A02-201; US1 AC1–AC3; research R5, R6).
import FluidArtPlaygroundCore
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import XCTest

final class SplatQueueTests: XCTestCase {
    private let view = SIMD2<Double>(400, 800)

    private func queue(cap: Int = 16) -> SplatQueue {
        var c = FluidConfiguration()
        c.maxSplatsPerFrame = cap
        c.gridWidth = 100
        c.gridHeight = 200
        return SplatQueue(configuration: c.validated().0)
    }

    private func swipe(id: Int, from: Vec2, to: Vec2, spacing: Double, tracker: inout PointerVelocityTracker) -> [PointerVelocityTracker.Sample] {
        var out = tracker.handle(PointerEvent(id: id, phase: .began, location: from, timestamp: 0))
        out += tracker.handle(PointerEvent(id: id, phase: .moved, location: to, timestamp: 0.1))
        return out
    }

    /// US1 AC1 / SC-A02-201: consecutive same-finger splats are at most the spacing apart.
    func testSplatsFollowThePathAtSpacing() {
        var q = queue(cap: 64)
        let spacing = 0.04 * 400 / 2   // brushRadius × shorter view edge / 2 = 8 points
        var tracker = PointerVelocityTracker(spacing: spacing)
        q.add(swipe(id: 1, from: Vec2(100, 400), to: Vec2(300, 400), spacing: spacing, tracker: &tracker), viewSize: view)
        let splats = q.drain()
        XCTAssertEqual(splats.count, 1 + 16, "began plus 200/8 = 25 capped at 16 per update")
        // Positions are normalized: 8 points = 0.02 of the 400-point width.
        for (a, b) in zip(splats.dropFirst(), splats.dropFirst(2)) {
            XCTAssertLessThanOrEqual(abs(b.position.x - a.position.x), 200 / 16 / 400 + 1e-6)
        }
        XCTAssertEqual(splats.last!.position.x, 0.75, accuracy: 1e-6)
        XCTAssertEqual(splats.last!.position.y, 0.5, accuracy: 1e-6, "y is flipped to a bottom-left origin")
    }

    /// US1 AC2: each finger's force points in its own direction, and fingers get different colors.
    func testFingersAreIndependent() {
        var q = queue()
        var tracker = PointerVelocityTracker(spacing: 1000)
        q.add(swipe(id: 1, from: Vec2(100, 100), to: Vec2(200, 100), spacing: 1000, tracker: &tracker), viewSize: view)
        q.add(swipe(id: 2, from: Vec2(300, 700), to: Vec2(300, 600), spacing: 1000, tracker: &tracker), viewSize: view)
        let splats = q.drain()
        let moved = splats.filter { $0.force != .zero }
        XCTAssertEqual(moved.count, 2)
        XCTAssertGreaterThan(moved[0].force.x, 0)
        XCTAssertEqual(moved[0].force.y, 0)
        XCTAssertGreaterThan(moved[1].force.y, 0, "moving up the screen is +y in grid space")
        XCTAssertEqual(moved[1].force.x, 0)
        XCTAssertNotEqual(moved[0].color, moved[1].color)
        // 1000 points/s across 400 points of 100 cells = 250 cells/s.
        XCTAssertEqual(moved[0].force.x, 250, accuracy: 1e-3)
    }

    /// US1 AC3: over the cap, splats are thinned evenly, keep the newest, and the excess is counted.
    func testCapKeepsEvenSubsetIncludingNewest() {
        var q = queue(cap: 4)
        var tracker = PointerVelocityTracker(spacing: 1, maxSamplesPerUpdate: 9)
        q.add(swipe(id: 1, from: Vec2(0, 0), to: Vec2(90, 0), spacing: 1, tracker: &tracker), viewSize: view)
        XCTAssertEqual(q.pendingCount, 10)
        let splats = q.drain()
        XCTAssertEqual(splats.count, 4)
        XCTAssertEqual(q.dropped, 6)
        XCTAssertEqual(q.pendingCount, 0)
        XCTAssertEqual(splats.first!.position.x, 0)
        XCTAssertEqual(splats.last!.position.x, 90 / 400, accuracy: 1e-6, "the newest is kept")
        let xs = splats.map(\.position.x)
        XCTAssertEqual(xs, xs.sorted(), "order is preserved")
    }

    func testCapOfOneKeepsNewest() {
        var q = queue(cap: 1)
        var tracker = PointerVelocityTracker(spacing: 10)
        q.add(swipe(id: 1, from: Vec2(0, 0), to: Vec2(100, 0), spacing: 10, tracker: &tracker), viewSize: view)
        let splats = q.drain()
        XCTAssertEqual(splats.count, 1)
        XCTAssertEqual(splats[0].position.x, 0.25, accuracy: 1e-6)
    }

    func testSplashIsDeterministic() {
        var a = queue(), b = queue()
        a.addSplash(); a.addSplash()
        b.addSplash(); b.addSplash()
        let sa = a.drain(), sb = b.drain()
        XCTAssertEqual(sa, sb)
        XCTAssertEqual(a.splashCount, 2)
        XCTAssertEqual(sa[0].position, SIMD2(0.5, 0.5))
        XCTAssertEqual(sa[0].force.x, 600, accuracy: 1e-3, "burst 0 points along +x")
        let angle = atan2(Double(sa[1].force.y), Double(sa[1].force.x)) * 180 / .pi
        XCTAssertEqual(angle, 137.5, accuracy: 1e-3, "burst 1 is rotated by the golden angle")
        XCTAssertNotEqual(sa[0].color, sa[1].color)
    }

    func testInvalidViewSizeAndPendingCapacity() {
        var q = queue()
        var tracker = PointerVelocityTracker(spacing: 10)
        q.add(swipe(id: 1, from: Vec2(0, 0), to: Vec2(50, 0), spacing: 10, tracker: &tracker), viewSize: SIMD2(0, 800))
        XCTAssertEqual(q.pendingCount, 0, "no splats without a valid view size")
        for _ in 0..<(SplatQueue.maxPending + 10) { q.addSplash() }
        XCTAssertEqual(q.pendingCount, SplatQueue.maxPending)
        XCTAssertEqual(q.dropped, 10, "the oldest are dropped beyond the pending capacity")
    }

    /// Feature 022: splat colors come from the active palette; changing it keeps pending splats.
    func testPaletteColors() {
        var c = FluidConfiguration()
        c.paletteID = "smoke"
        var q = SplatQueue(configuration: c)
        q.addSplash()
        XCTAssertEqual(q.drain()[0].color, SIMD4(FluidPalette.named("smoke").splatColors[0], 1))
        q.addSplash()
        c.paletteID = "ink"
        q.update(configuration: c)
        XCTAssertEqual(q.pendingCount, 1, "pending splats are kept")
        q.addSplash()
        XCTAssertEqual(q.drain()[1].color, SIMD4(FluidPalette.named("ink").splatColors[2], 1))
    }

    func testForgetReleasesPointerColor() {
        var q = queue()
        var tracker = PointerVelocityTracker(spacing: 1000)
        q.add(swipe(id: 7, from: Vec2(0, 0), to: Vec2(10, 0), spacing: 1000, tracker: &tracker), viewSize: view)
        XCTAssertEqual(q.trackedPointers, 1)
        q.forget(pointer: 7)
        XCTAssertEqual(q.trackedPointers, 0)
    }
}
