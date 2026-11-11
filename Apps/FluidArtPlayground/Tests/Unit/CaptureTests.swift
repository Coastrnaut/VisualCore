// CaptureTests — feature 022 T-A02-405 (FR-A02-405, FR-A02-406; SC-A02-403; US3 AC1–AC3; analyze C2).
import FluidArtPlaygroundCore
import ImageIO
import VisualCoreRendering
import VisualCoreScenes
import XCTest
@testable import FluidArtPlayground

@MainActor
final class CaptureTests: XCTestCase {
    private func makeModel(palette: String = "ink") throws -> PlaygroundModel {
        var c = FluidConfiguration()
        c.paletteID = palette
        let model = PlaygroundModel(configuration: c)
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
        host.view.layoutIfNeeded()
        model.scene.fixedDelta = 1.0 / 60
        return model
    }

    /// SC-A02-403: an opaque PNG at the capture size in the canvas aspect, with no extra simulation step.
    func testCaptureProducesPNGWithoutStepping() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let steps = model.scene.stepCount
        model.captureStill()
        XCTAssertEqual(model.scene.stepCount, steps, "capture never advances the simulation")
        XCTAssertFalse(model.scene.paused, "the pause state is restored")
        guard case .done(let url) = model.capture.state else { return XCTFail("\(model.capture.state)") }
        let image = try XCTUnwrap(model.capture.lastImage)
        XCTAssertEqual(image.height, min(CaptureModel.longEdge, host.maxRenderSize) / 2 * 2)
        XCTAssertEqual(Double(image.width) / Double(image.height), 0.5, accuracy: 0.01, "canvas aspect 1:2")
        let data = try Data(contentsOf: url)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let cg = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(cg.width, image.width)
        XCTAssertTrue([CGImageAlphaInfo.none, .noneSkipLast, .noneSkipFirst].contains(cg.alphaInfo), "opaque PNG")
        // Ink palette: the top-left corner area shows paper or ink, never the black of an empty frame.
        let corner = image.pixel(x: 2, y: 2)
        XCTAssertGreaterThan(Int(corner.x) + Int(corner.y) + Int(corner.z), 60)
        let first = url
        model.captureStill()
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path), "only the latest capture is kept")
        model.close()
        guard case .idle = model.capture.state else { return XCTFail("removed on close") }
    }

    /// US3 AC3 / analyze C2: a size the device refuses is reported, and the scene's pause state is restored.
    func testTooLargeCaptureIsRefusedAndPauseRestored() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        model.scene.paused = false
        let huge = ExportSize(width: host.maxRenderSize * 2, height: 16)
        model.capture.capture(host: host, scene: model.scene, viewSize: CGSize(width: 300, height: 600), sizeOverride: huge)
        XCTAssertEqual(model.capture.state, .failed("This picture size is too large for this device."))
        XCTAssertFalse(model.scene.paused)
        model.scene.paused = true
        model.capture.capture(host: host, scene: model.scene, viewSize: CGSize(width: 300, height: 600), sizeOverride: huge)
        XCTAssertTrue(model.scene.paused, "a paused scene stays paused")
    }

    /// The capture shows the on-screen palette (glow included through the effect graph).
    func testCaptureMatchesOnScreenLook() throws {
        for palette in ["ink", "smoke", "glow"] {
            let model = try makeModel(palette: palette)
            defer { model.close() }
            let host = try XCTUnwrap(model.host)
            model.scene.paused = true
            XCTAssertTrue(host.renderOneFrame(present: false))
            model.captureStill()
            let image = try XCTUnwrap(model.capture.lastImage)
            let bg = model.scene.palette.background * 255
            // A corner far from the seeded blobs is close to the background (dye fades with distance).
            let p = image.pixel(x: 1, y: image.height - 2)
            print("capture \(palette): corner \(p) background \(bg)")
            for c in 0..<3 { XCTAssertEqual(Float(p[c]), bg[c], accuracy: 3, "\(palette) corner channel \(c)") }
        }
    }
}
