// OffscreenExportTests — feature 015 T-A01-402 (FR-A01-402, FR-A01-403, FR-A01-405, FR-A01-408; research R2–R4, R7).
import CVisualCoreGL
import ImageIO
import VisualCoreDiagnostics
import VisualCoreTestSupport
import XCTest
@testable import VisualCoreRendering

/// Clears the four quadrants (in display orientation) to red (top-left), green (top-right), blue (bottom-left) and
/// white (bottom-right) with alpha 0.5, so readback orientation and opacity forcing are both visible.
@MainActor
private final class QuadrantScene: RenderScene {
    var renders = 0
    var throwOnRender = false
    func setup(_ context: RenderContext) throws {}
    func resize(_ context: RenderContext) {}
    func teardown(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        renders += 1
        if throwOnRender { throw CocoaError(.featureUnsupported) }
        let w = context.pixelWidth, h = context.pixelHeight, hw = w / 2, hh = h / 2
        vcglEnable(GLenum(GL_SCISSOR_TEST))
        // GL origin is bottom-left: the display's top half is y ≥ hh.
        let quads: [(Int32, Int32, Int32, Int32, (Float, Float, Float))] = [
            (0, Int32(hh), Int32(hw), Int32(h - hh), (1, 0, 0)), (Int32(hw), Int32(hh), Int32(w - hw), Int32(h - hh), (0, 1, 0)),
            (0, 0, Int32(hw), Int32(hh), (0, 0, 1)), (Int32(hw), 0, Int32(w - hw), Int32(hh), (1, 1, 1)),
        ]
        for (x, y, qw, qh, c) in quads {
            vcglScissor(x, y, qw, qh)
            vcglClearColor(c.0, c.1, c.2, 0.5)
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        }
        vcglDisable(GLenum(GL_SCISSOR_TEST))
    }
}

@MainActor
final class OffscreenExportTests: XCTestCase {
    private func makeHost(_ scene: RenderScene, budget: ResourceBudget = ResourceBudget()) throws -> RenderHost {
        let host = try RenderHost(scene: scene, budget: budget)
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        return host
    }

    func testMaxRenderSizeIsReported() throws {
        let host = try makeHost(QuadrantScene())
        defer { host.destroy() }
        XCTAssertGreaterThan(host.capabilities.maxRenderbufferSize, 0)
        XCTAssertGreaterThanOrEqual(host.maxRenderSize, 4096)
        XCTAssertLessThanOrEqual(host.maxRenderSize, host.capabilities.maxTextureSize)
    }

    func testExactSizesAndTopDownOrientation() throws {
        let host = try makeHost(QuadrantScene())
        defer { host.destroy() }
        for (w, h) in [(64, 64), (40, 50), (96, 54)] {
            let image = try host.renderOffscreen(width: w, height: h, time: 0)
            XCTAssertEqual(image.width, w); XCTAssertEqual(image.height, h)
            XCTAssertEqual(image.rgba.count, w * h * 4)
            XCTAssertEqual(image.pixel(x: 1, y: 1), SIMD4(255, 0, 0, 128), "top-left red")
            XCTAssertEqual(image.pixel(x: w - 2, y: 1), SIMD4(0, 255, 0, 128), "top-right green")
            XCTAssertEqual(image.pixel(x: 1, y: h - 2), SIMD4(0, 0, 255, 128), "bottom-left blue")
            XCTAssertEqual(image.pixel(x: w - 2, y: h - 2), SIMD4(255, 255, 255, 128), "bottom-right white")
        }
    }

    func testPNGIsOpaqueSRGBWithIdenticalPixels() throws {
        let host = try makeHost(QuadrantScene())
        defer { host.destroy() }
        let image = try host.renderOffscreen(width: 48, height: 60, time: 0)
        let png = try StillImageEncoder.pngData(image)
        XCTAssertEqual(Array(png.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(decoded.width, 48); XCTAssertEqual(decoded.height, 60)
        XCTAssertTrue([.none, .noneSkipLast, .noneSkipFirst].contains(decoded.alphaInfo), "no alpha: \(decoded.alphaInfo.rawValue)")
        XCTAssertEqual(decoded.colorSpace?.name, CGColorSpace.sRGB)
        // Redraw into a known RGBA buffer and compare the color channels exactly.
        var redrawn = [UInt8](repeating: 0, count: 48 * 60 * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        redrawn.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: 48, height: 60, bitsPerComponent: 8, bytesPerRow: 48 * 4,
                                space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.draw(decoded, in: CGRect(x: 0, y: 0, width: 48, height: 60))
        }
        for i in stride(from: 0, to: redrawn.count, by: 4) {
            XCTAssertEqual(Array(redrawn[i..<i + 3]), Array(image.rgba[i..<i + 3]), "pixel \(i / 4)")
            if redrawn[i..<i + 3] != image.rgba[i..<i + 3] { break }
        }
    }

    func testBottomUpFlipAndSizeValidation() {
        let bottomUp: [UInt8] = [1, 1, 1, 1, 2, 2, 2, 2]   // 1×2: row 0 (bottom) = 1, row 1 (top) = 2
        let image = StillImage(width: 1, height: 2, bottomUpRGBA: bottomUp)
        XCTAssertEqual(image?.pixel(x: 0, y: 0), SIMD4(2, 2, 2, 2))
        XCTAssertNil(StillImage(width: 2, height: 2, topDownRGBA: bottomUp))
        XCTAssertNil(StillImage(width: 0, height: 2, bottomUpRGBA: []))
    }

    func testLiveFrameIsRestoredAfterExport() throws {
        let host = try makeHost(QuadrantScene())
        defer { host.destroy() }
        let before = host.readPixels()
        _ = try host.renderOffscreen(width: 128, height: 72, time: 3)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(ImageComparison.compare(before, host.readPixels()).maxAbsolute, 0)
        XCTAssertEqual(host.resources.stats.liveCount[.framebuffer], 0, "export target released")
    }

    func testOverBudgetFailsWithoutLeaksAndSceneKeepsRendering() throws {
        let scene = QuadrantScene()
        let host = try makeHost(scene, budget: ResourceBudget(total: 8 << 20))
        defer { host.destroy() }
        let live = host.resources.stats.liveCount
        XCTAssertThrowsError(try host.renderOffscreen(width: 2048, height: 2048, time: 0)) { error in
            guard case OffscreenRenderError.resource(let message) = error else { return XCTFail("\(error)") }
            XCTAssertTrue(message.contains("overBudget"), message)
        }
        XCTAssertEqual(host.resources.stats.liveCount, live)
        XCTAssertTrue(host.renderOneFrame(present: false), "live scene keeps rendering")
        XCTAssertNoThrow(try host.renderOffscreen(width: 256, height: 256, time: 0), "retry at a size that fits")
        XCTAssertEqual(host.resources.stats.liveCount, live)
    }

    func testSceneFailureLeavesLiveSceneWorking() throws {
        let scene = QuadrantScene()
        let host = try makeHost(scene)
        defer { host.destroy() }
        scene.throwOnRender = true
        XCTAssertThrowsError(try host.renderOffscreen(width: 32, height: 32, time: 0)) { error in
            guard case OffscreenRenderError.scene = error else { return XCTFail("\(error)") }
        }
        scene.throwOnRender = false
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNil(host.lastError, "an export failure is not a live scene failure")
        XCTAssertEqual(host.resources.stats.liveCount[.framebuffer], 0)
    }

    func testInvalidSizesAreRefusedBeforeGPUWork() throws {
        let host = try makeHost(QuadrantScene())
        defer { host.destroy() }
        let peak = host.resources.stats.peakBytes
        for (w, h) in [(0, 10), (10, -1), (host.maxRenderSize + 1, 10)] {
            XCTAssertThrowsError(try host.renderOffscreen(width: w, height: h, time: 0)) { error in
                guard case OffscreenRenderError.invalidSize = error else { return XCTFail("\(error)") }
            }
        }
        XCTAssertEqual(host.resources.stats.peakBytes, peak, "no allocation attempted")
    }

    func testDestroyedHostIsUnavailable() throws {
        let host = try makeHost(QuadrantScene())
        host.destroy()
        XCTAssertThrowsError(try host.renderOffscreen(width: 8, height: 8, time: 0)) { error in
            guard case OffscreenRenderError.unavailable = error else { return XCTFail("\(error)") }
        }
    }
}
