// IconRenderTests — feature 017 T-A01-604 (FR-A01-604): the app icon is the app's own render of the Gradient Noise
// "Dusk" preset at t = 12 s, 1024×1024, opaque sRGB. With GAS_WRITE_ICON=1 the test (re)writes the committed PNG;
// otherwise it checks the committed PNG against a fresh render (mean ≤ 1/255), so the icon's provenance stays provable.
import ImageIO
import XCTest
import GenerativeArtStudioCore
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreTestSupport
@testable import GenerativeArtStudioExperience

@MainActor
final class IconRenderTests: XCTestCase {
    // The standalone app's icon is kept as history with its dossier (feature 193, research R9): the one app has one
    // generated icon, and this test still proves the standalone icon's provenance.
    static let iconURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/apps/generative-art-studio/history/icon-1024.png")
    static let time = 12.0

    private func render() throws -> StillImage {
        let family = FamilyCatalog.family(.gradientNoise)
        XCTAssertEqual(family.defaultPreset.title, "Dusk")
        let m = SceneModel(family: family, reduceMotion: false, editor: CompositionEditor(family: family))
        defer { m.close() }
        let host = try XCTUnwrap(m.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        host.view.layoutIfNeeded()
        m.clocked.clock.pause()
        m.scrub(to: Self.time)
        XCTAssertTrue(host.renderOneFrame(present: false))
        return try ExportRunner.render(m, size: ExportSize(width: 1024, height: 1024))
    }

    func testIconIsTheAppsOwnRender() throws {
        let image = try render()
        XCTAssertTrue(stride(from: 3, to: image.rgba.count, by: 4).allSatisfy { image.rgba[$0] == 255 }, "opaque")
        if ProcessInfo.processInfo.environment["GAS_WRITE_ICON"] == "1" {
            try StillImageEncoder.pngData(image).write(to: Self.iconURL, options: .atomic)
            print("ICON written to \(Self.iconURL.path)")
        }
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(Self.iconURL as CFURL, nil), "committed icon present")
        let committed = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(committed.width, 1024); XCTAssertEqual(committed.height, 1024)
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
    }
}
