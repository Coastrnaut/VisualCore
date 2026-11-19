// GPUFrameTimerTests — feature 175 (A24-P03) T-A24-304 (FR-A24-305, U-GPUTIMER). Simulator values are context only
// (constitution V): the tests check that a known draw yields a plausible, finite time, never a specific number.
import XCTest
import CVisualCoreGL
@testable import VisualCoreRendering

/// Brackets a gradient quad draw with the GPU timer and polls every frame.
@MainActor
private final class TimedQuadScene: RenderScene {
    let quad = GradientQuadScene()
    var timer: GPUFrameTimer?
    var releaseOnTeardown = true
    var frames = 0
    /// Each result with the frame number of the poll that returned it.
    var results: [(result: GPUFrameTime, arrivedAt: Int)] = []
    /// Extra work run inside `render`, after the timed draw (tests of an older generation's timer).
    var onRender: (RenderContext) -> Void = { _ in }

    func setup(_ context: RenderContext) throws {
        try quad.setup(context)
        timer = GPUFrameTimer(context: context)
    }
    func resize(_ context: RenderContext) { quad.resize(context) }
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        let number = frames
        frames += 1
        timer?.begin(frame: number)
        try quad.render(context, frame: frame)
        timer?.end()
        for result in timer?.poll() ?? [] { results.append((result, number)) }
        onRender(context)
    }
    func teardown(_ context: RenderContext) {
        if releaseOnTeardown { timer?.release() }
        quad.teardown(context)
    }
}

@MainActor
final class GPUFrameTimerTests: XCTestCase {
    func testAKnownDrawGivesAFiniteTimeWithinFourFramesOrTheTimerIsReportedUnsupported() throws {
        let scene = TimedQuadScene()
        let host = try RenderHost(scene: scene)
        defer { host.destroy() }
        let listed = host.capabilities.extensions.contains(GPUFrameTimer.extensionName)
        guard listed, vcglHasDisjointTimerQuery() == 1 else {
            XCTAssertNil(scene.timer, "no timer without the extension and its entry points")
            throw XCTSkip("GPU timer unsupported here: listed \(listed), resolved \(vcglHasDisjointTimerQuery())")
        }
        let timer = try XCTUnwrap(scene.timer, "the extension is listed and resolved, so the timer must exist")
        for _ in 0..<8 { _ = try host.renderOffscreen(width: 256, height: 256, time: 0) }
        XCTAssertFalse(scene.results.isEmpty, "no result in 8 frames (disjoint reads: \(timer.disjointCount))")
        let first = try XCTUnwrap(scene.results.first)
        XCTAssertLessThanOrEqual(first.arrivedAt - first.result.frame, 4, "first result arrives within 4 frames")
        XCTAssertEqual(scene.results.map(\.result.frame), scene.results.map(\.result.frame).sorted())
        for (result, _) in scene.results {
            XCTAssertTrue(result.milliseconds.isFinite)
            XCTAssertGreaterThanOrEqual(result.milliseconds, 0)
            XCTAssertLessThanOrEqual(result.milliseconds, 1000)
        }
        let values = scene.results.map(\.result.milliseconds)
        print("GPU timer (simulator context only): \(values.count) results, \(values.min() ?? -1)…\(values.max() ?? -1) ms, "
              + "disjoint \(timer.disjointCount)")
    }

    func testATimerFromBeforeRecreationReadsNothingAfterItAndReleasesSafely() throws {
        let scene = TimedQuadScene()
        scene.releaseOnTeardown = false
        let host = try RenderHost(scene: scene)
        defer { host.destroy() }
        guard let old = scene.timer else {
            XCTAssertNil(scene.timer)
            throw XCTSkip("GPU timer unsupported here: listed \(host.capabilities.extensions.contains(GPUFrameTimer.extensionName))")
        }
        scene.onRender = { _ in old.begin(frame: 99) }   // leaves a query open across the recreation
        _ = try host.renderOffscreen(width: 64, height: 64, time: 0)
        host.recreateContext()
        XCTAssertNotNil(scene.timer)
        XCTAssertFalse(scene.timer === old, "the new generation's setup made a new timer")
        var oldResults: [GPUFrameTime]?
        scene.onRender = { _ in
            old.begin(frame: 100)
            old.end()
            oldResults = old.poll()
            old.release()
            old.release()
        }
        _ = try host.renderOffscreen(width: 64, height: 64, time: 0)
        XCTAssertEqual(oldResults, [], "an older generation's queries are never read")
        scene.onRender = { _ in }
        scene.releaseOnTeardown = true
    }

    func testAContextWithoutTheExtensionGetsNoTimer() throws {
        let host = try RenderHost(scene: ClearColorScene())
        defer { host.destroy() }
        var made: GPUFrameTimer?
        let saved = host.resources.renderCapabilities
        host.resources.renderCapabilities.extensions.removeAll { $0 == GPUFrameTimer.extensionName }
        made = GPUFrameTimer(context: RenderContext(generation: host.generation, pixelWidth: 1, pixelHeight: 1,
                                                    framebuffer: 0, resources: host.resources))
        host.resources.renderCapabilities = saved
        XCTAssertNil(made)
    }
}
