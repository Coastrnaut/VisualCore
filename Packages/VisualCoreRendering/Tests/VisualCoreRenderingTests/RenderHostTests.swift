// RenderHostTests — feature 003 (T-F206 US1, T-F212 US2, T-F216 US3). Runs on iOS simulators.
// Pattern from the audited reference ANGLERendererTests: the view is laid out off screen, frames are
// rendered without presenting, and the window surface's default framebuffer is read back.
import XCTest
import VisualCoreDiagnostics
@testable import VisualCoreRendering

@MainActor
final class RenderHostTests: XCTestCase {
    private func makeLaidOut(_ scene: RenderScene, width: CGFloat = 64, height: CGFloat = 64) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        host.view.layoutIfNeeded()
        return host
    }

    /// RGBA at pixel (x, y) with y counted from the bottom row (GL convention).
    private func pixel(_ pixels: [UInt8], _ host: RenderHost, x: Int, y: Int) -> (Int, Int, Int, Int) {
        let i = (y * host.pixelSize.width + x) * 4
        return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]), Int(pixels[i + 3]))
    }

    // MARK: US1 — minimal scene (SC-F201)

    func testClearColorSceneMatchesWithinTwo() throws {
        let host = try makeLaidOut(ClearColorScene(red: 0.25, green: 0.5, blue: 0.75))
        XCTAssertEqual(host.state, .active)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let pixels = host.readPixels()
        XCTAssertEqual(pixels.count, host.pixelSize.width * host.pixelSize.height * 4)
        let (r, g, b, a) = pixel(pixels, host, x: host.pixelSize.width / 2, y: host.pixelSize.height / 2)
        XCTAssertLessThanOrEqual(abs(r - 64), 2)
        XCTAssertLessThanOrEqual(abs(g - 128), 2)
        XCTAssertLessThanOrEqual(abs(b - 191), 2)
        XCTAssertEqual(a, 255)
    }

    func testGradientQuadIsRedOnTheLeftAndBlueOnTheRight() throws {
        let host = try makeLaidOut(GradientQuadScene())
        XCTAssertNil(host.lastError)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let pixels = host.readPixels()
        let y = host.pixelSize.height / 2
        let left = pixel(pixels, host, x: 1, y: y)
        let right = pixel(pixels, host, x: host.pixelSize.width - 2, y: y)
        XCTAssertGreaterThan(left.0, 240); XCTAssertLessThan(left.2, 15)
        XCTAssertGreaterThan(right.2, 240); XCTAssertLessThan(right.0, 15)
    }

    func testCapabilitiesComeFromANGLE() throws {
        let host = try makeLaidOut(ClearColorScene())
        let caps = host.capabilities
        XCTAssertTrue(caps.glVersion.contains("OpenGL ES 3"), caps.glVersion)
        XCTAssertTrue(caps.renderer.contains("ANGLE"), caps.renderer)
        XCTAssertFalse(caps.glslVersion.isEmpty)
        XCTAssertFalse(caps.extensions.isEmpty)
        XCTAssertGreaterThanOrEqual(caps.maxTextureSize, 2048)
        XCTAssertGreaterThan(caps.maxViewport.width, 0)
    }

    func testSurfaceIsCreatedAtTheDisplayScale() throws {
        let host = try makeLaidOut(ClearColorScene(), width: 80, height: 40)
        let scale = host.view.contentScaleFactor
        XCTAssertEqual(host.pixelSize.width, Int((80 * scale).rounded()))
        XCTAssertEqual(host.pixelSize.height, Int((40 * scale).rounded()))
    }

    // MARK: US2 — resize, suspend, recreation, failures (SC-F202)

    func testResizeRecreatesTheSurfaceAndNotifiesTheScene() throws {
        let scene = RecordingScene()
        let host = try makeLaidOut(scene)
        let before = scene.resizes.count
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 96)
        host.view.layoutIfNeeded()
        XCTAssertEqual(scene.resizes.count, before + 1)
        let scale = host.view.contentScaleFactor
        XCTAssertEqual(scene.resizes.last?.width, Int((32 * scale).rounded()))
        XCTAssertTrue(host.renderOneFrame(present: false))
        // Same size again: no new surface.
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        XCTAssertEqual(scene.resizes.count, before + 1)
    }

    func testSuspendedHostDrawsNothingUntilResumed() throws {
        let scene = RecordingScene()
        let host = try makeLaidOut(scene)
        host.pause()
        XCTAssertEqual(host.state, .suspended)
        XCTAssertFalse(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.renders, 0)
        host.resume()
        XCTAssertEqual(host.state, .active)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.renders, 1)
    }

    func testBackgroundSuspendsAndForegroundResumesUnlessAppPaused() throws {
        let host = try makeLaidOut(ClearColorScene())
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertEqual(host.state, .suspended)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertEqual(host.state, .active)
        host.pause()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertEqual(host.state, .suspended, "an app-requested pause survives a foreground return")
    }

    func testHundredRecreationsKeepRendering() throws {
        let scene = RecordingScene()
        let host = try makeLaidOut(ClearColorScene(red: 1, green: 0, blue: 0))
        XCTAssertEqual(host.generation, 1)
        for _ in 0..<100 { host.recreateContext() }
        XCTAssertEqual(host.generation, 101)
        XCTAssertEqual(host.state, .active)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let p = pixel(host.readPixels(), host, x: 2, y: 2)
        XCTAssertGreaterThan(p.0, 250)
        // Setup/teardown are paired on every recreation.
        let host2 = try makeLaidOut(scene)
        for _ in 0..<5 { host2.recreateContext() }
        XCTAssertEqual(scene.setups, 6)
        XCTAssertEqual(scene.teardowns, 5)
        XCTAssertEqual(scene.generations, [1, 2, 3, 4, 5, 6])
    }

    func testZeroSizeIsSurfaceInvalidThenRecovers() throws {
        let host = try RenderHost(scene: ClearColorScene())
        host.view.frame = .zero
        host.view.setNeedsLayout()   // an unchanged zero frame triggers no layout pass by itself
        host.view.layoutIfNeeded()
        XCTAssertEqual(host.state, .surfaceInvalid)
        XCTAssertFalse(host.renderOneFrame(present: false))
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertEqual(host.state, .active)
        XCTAssertTrue(host.renderOneFrame(present: false))
    }

    func testThreeSurfaceFailuresReportOneAllocationErrorThenRecover() throws {
        let host = try RenderHost(scene: ClearColorScene())
        var errors: [RenderHostError] = []
        host.addErrorObserver { errors.append($0) }
        host.failNextSurfaceCreations(4)
        for width in [16, 17, 18, 19] {
            host.view.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: 16)
            host.view.layoutIfNeeded()
            XCTAssertEqual(host.state, .surfaceInvalid)
        }
        XCTAssertEqual(errors.count, 1)
        if case .allocation = errors.first {} else { XCTFail("expected allocation error, got \(String(describing: errors.first))") }
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertEqual(host.state, .active)
    }

    func testThrowingSceneSetupPresentsBlackAndDoesNotCrash() throws {
        let host = try makeLaidOut(FailingScene())
        if case .scene = host.lastError {} else { XCTFail("expected scene error") }
        XCTAssertTrue(host.renderOneFrame(present: false))
        let p = pixel(host.readPixels(), host, x: 3, y: 3)
        XCTAssertEqual(p.0 + p.1 + p.2, 0)
        host.replaceScene(ClearColorScene(red: 0, green: 1, blue: 0))
        XCTAssertNil(host.lastError)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertGreaterThan(pixel(host.readPixels(), host, x: 3, y: 3).1, 250)
    }

    func testLostContextIsReportedRecreatedAndRendersAgain() throws {
        let scene = RecordingScene()
        let host = try makeLaidOut(scene)
        var errors: [RenderHostError] = []
        host.addErrorObserver { errors.append($0) }
        host.simulateContextLossOnNextFrame()
        XCTAssertFalse(host.renderOneFrame(present: true), "the frame with the lost context is dropped")
        XCTAssertEqual(errors, [.contextLost])
        XCTAssertEqual(host.generation, 2)
        XCTAssertEqual(scene.setups, 2)
        XCTAssertEqual(scene.teardowns, 1)
        XCTAssertEqual(host.state, .active)
        XCTAssertTrue(host.renderOneFrame(present: false))
    }

    func testDestroyTearsDownAndLaterCallsAreNoOps() throws {
        let scene = RecordingScene()
        let host = try makeLaidOut(scene)
        host.destroy()
        XCTAssertEqual(host.state, .destroyed)
        XCTAssertEqual(scene.teardowns, 1)
        XCTAssertFalse(host.renderOneFrame(present: false))
        host.recreateContext(); host.resume(); host.destroy()
        XCTAssertEqual(host.state, .destroyed)
        XCTAssertEqual(scene.teardowns, 1)
    }

    func testTwoHostsRenderIndependently() throws {
        let a = try makeLaidOut(ClearColorScene(red: 1, green: 0, blue: 0))
        let b = try makeLaidOut(ClearColorScene(red: 0, green: 0, blue: 1))
        XCTAssertTrue(a.renderOneFrame(present: false))
        XCTAssertTrue(b.renderOneFrame(present: false))
        XCTAssertGreaterThan(pixel(a.readPixels(), a, x: 1, y: 1).0, 250)
        XCTAssertGreaterThan(pixel(b.readPixels(), b, x: 1, y: 1).2, 250)
        b.destroy()
        XCTAssertTrue(a.renderOneFrame(present: false), "destroying one host leaves the shared display usable")
    }

    // MARK: US3 — observation (T-F216)

    func testObserverSeesTheFullLifecycle() throws {
        var seen: [String] = []
        let host = try RenderHost(scene: ClearColorScene())
        host.addObserver { seen.append("\($0.from.rawValue)>\($0.to.rawValue)") }
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        host.pause(); host.resume(); host.recreateContext(); host.destroy()
        XCTAssertEqual(seen, ["surfaceReady>active", "active>suspended", "suspended>active",
                              "active>reinitialized", "reinitialized>active", "active>destroyed"])
        XCTAssertEqual(host.lifecycleHistory.first?.to, .surfaceReady, "creation is in the history")
    }
}

// MARK: - Test scenes

@MainActor
final class RecordingScene: RenderScene {
    var setups = 0, teardowns = 0, renders = 0
    var generations: [Int] = []
    var resizes: [(width: Int, height: Int)] = []
    func setup(_ context: RenderContext) throws { setups += 1; generations.append(context.generation) }
    func resize(_ context: RenderContext) { resizes.append((context.pixelWidth, context.pixelHeight)) }
    func render(_ context: RenderContext, frame: FrameInfo) throws { renders += 1 }
    func teardown(_ context: RenderContext) { teardowns += 1 }
}

@MainActor
final class FailingScene: RenderScene {
    struct Failure: Error {}
    func setup(_ context: RenderContext) throws { throw Failure() }
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {}
}
