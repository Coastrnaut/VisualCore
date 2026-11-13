// IconRenderTests — feature 024 T-A02-604 (FR-A02-603, SC-A02-602; clarification 2): the app icon is the app's own
// render — the deterministic test mode (gentle: default force, 3 pointers at 500 pt/s), seed 3, Glowing dye, 90 frames, offscreen 1024×1024, opaque sRGB. With
// FAP_WRITE_ICON=1 (TEST_RUNNER_FAP_WRITE_ICON for xcodebuild) the test writes the committed PNG; otherwise it
// compares the committed PNG with a fresh render (mean ≤ 1/255), so the icon's provenance stays provable.
import FluidArtPlaygroundCore
import ImageIO
import VisualCoreRendering
import VisualCoreTestSupport
import XCTest
@testable import FluidArtPlaygroundExperience

@MainActor
final class IconRenderTests: XCTestCase {
    // The standalone app's icon is kept as history with its dossier (feature 193, research R9).
    static let iconURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/apps/fluid-art-playground/history/icon-1024.png")

    private func render() throws -> StillImage {
        var base = FluidConfiguration()
        base.paletteID = "glow"
        // Default force and splat cap (not the stress settings), three slow strokes: the seeded blobs stay readable.
        let model = TestMode.makeModel(seed: 3, script: TestMode.Script(pointers: 3, strokeSamples: 40, speed: 500),
                                       base: base, aggressive: false, viewSize: CGSize(width: 390, height: 844))
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        for _ in 0..<90 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        model.scene.paused = true
        XCTAssertEqual(model.scene.stepCount, 90)
        return try host.renderOffscreen(width: 1024, height: 1024, time: 0)
    }

    func testIconIsTheAppsOwnRender() throws {
        let image = try render()
        XCTAssertTrue(stride(from: 3, to: image.rgba.count, by: 4).allSatisfy { image.rgba[$0] == 255 }, "opaque")
        if ProcessInfo.processInfo.environment["FAP_WRITE_ICON"] == "1" {
            try StillImageEncoder.pngData(image).write(to: Self.iconURL, options: .atomic)
            print("ICON written to \(Self.iconURL.path)")
        }
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(Self.iconURL as CFURL, nil), "committed icon present")
        let committed = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(committed.width, 1024)
        XCTAssertEqual(committed.height, 1024)
        XCTAssertTrue([.none, .noneSkipLast, .noneSkipFirst].contains(committed.alphaInfo), "no alpha in the icon")
        var rgba = [UInt8](repeating: 0, count: 1024 * 1024 * 4)
        rgba.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.draw(committed, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        }
        var live = image.rgba
        for i in stride(from: 3, to: live.count, by: 4) { live[i] = 255 }
        for i in stride(from: 3, to: rgba.count, by: 4) { rgba[i] = 255 }
        let d = ImageComparison.compare(rgba, live)
        print("ICON provenance check: mean=\(d.meanAbsolute) max=\(d.maxAbsolute)")
        XCTAssertLessThanOrEqual(d.meanAbsolute, 1, "the committed icon is this render")
        // Not a blank frame: the glow and dye light a real share of the icon.
        let lit = stride(from: 0, to: live.count, by: 4).filter { Int(live[$0]) + Int(live[$0 + 1]) + Int(live[$0 + 2]) > 60 }.count
        XCTAssertGreaterThan(Double(lit) / Double(1024 * 1024), 0.1)
    }
}
