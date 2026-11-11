// IconRenderTests — feature 031 T-A03-603 (FR-A03-602; US2 AC1; spec 031 clarification 1), after A02's: the app icon
// is the app's own render — the Seahorse Valley tour's second stop in the Sunset palette, cap 500, animation off,
// 1024 × 1024, opaque. With FE_WRITE_ICON=1 (TEST_RUNNER_FE_WRITE_ICON for xcodebuild) the test writes the committed
// PNG; otherwise it compares the committed PNG with a fresh render (mean ≤ 1/255), so the icon's provenance stays
// provable.
import FractalExplorerCore
import ImageIO
import VisualCoreMath
import VisualCoreRendering
import VisualCoreSimulation
import VisualCoreTestSupport
import XCTest
@testable import FractalExplorer

@MainActor
final class IconRenderTests: XCTestCase {
    static let iconURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

    private func render() throws -> StillImage {
        let size = Vec2(512, 512)
        let model = ExplorerModel(size: size, system: SystemAccessibility(reduceMotion: true),
                                  bookmarksDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("fe-icon"))
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: size.x, height: size.y)
        host.view.layoutIfNeeded()
        model.animate = false
        model.paletteID = "sunset"
        model.state.iterationCap = 500
        let stop = try XCTUnwrap(FractalTours.tour("seahorse")).stops[1]
        model.state.viewport = stop.framing.viewport(size: size)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNil(model.scene.errorMessage)
        return try host.renderOffscreen(width: 1024, height: 1024, time: 0)
    }

    func testIconIsTheAppsOwnRender() throws {
        let image = try render()
        XCTAssertTrue(stride(from: 3, to: image.rgba.count, by: 4).allSatisfy { image.rgba[$0] == 255 }, "opaque")
        if ProcessInfo.processInfo.environment["FE_WRITE_ICON"] == "1" {
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
        // Not a blank frame: both the black set and the coloured bands cover a real share.
        let black = stride(from: 0, to: live.count, by: 4).filter { Int(live[$0]) + Int(live[$0 + 1]) + Int(live[$0 + 2]) <= 3 }.count
        let share = Double(black) / Double(1024 * 1024)
        XCTAssertGreaterThan(share, 0.02)
        XCTAssertLessThan(share, 0.9)
    }
}
