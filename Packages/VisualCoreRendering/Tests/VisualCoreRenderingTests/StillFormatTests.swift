// StillFormatTests — feature 139 (A19-P02) T-A19-203 (G-ENCODE; research D1, D2; contracts/still.md). The still
// encoder writes PNG, JPEG and HEIC as opaque sRGB images that read back at their size, colour space and type; PNG
// through the new entry point is byte-identical to `pngData`. Small images, no GPU work.
import CoreGraphics
import ImageIO
import XCTest
@testable import VisualCoreRendering

final class StillFormatTests: XCTestCase {
    private static let width = 64
    private static let height = 48

    /// A flat image of one colour with alpha 0.5 (the encoder must force it opaque).
    private func flat(_ r: UInt8, _ g: UInt8, _ b: UInt8) throws -> StillImage {
        var rgba = [UInt8](repeating: 0, count: Self.width * Self.height * 4)
        for i in stride(from: 0, to: rgba.count, by: 4) {
            rgba[i] = r
            rgba[i + 1] = g
            rgba[i + 2] = b
            rgba[i + 3] = 128
        }
        return try XCTUnwrap(StillImage(width: Self.width, height: Self.height, topDownRGBA: rgba))
    }

    /// A deterministic noise pattern (a linear congruential generator), hard to compress.
    private func noisy() throws -> StillImage {
        var state: UInt32 = 0x1234_5678
        var rgba = [UInt8](repeating: 255, count: Self.width * Self.height * 4)
        for i in 0..<rgba.count where i % 4 != 3 {
            state = state &* 1_664_525 &+ 1_013_904_223
            rgba[i] = UInt8(truncatingIfNeeded: state >> 24)
        }
        return try XCTUnwrap(StillImage(width: Self.width, height: Self.height, topDownRGBA: rgba))
    }

    /// The decoded image of `data` redrawn into an sRGB RGBA buffer, top-down.
    private func redraw(_ image: CGImage) throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        out.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return out
    }

    func testPNGThroughTheFormatEntryPointIsByteIdenticalToPNGData() throws {
        for image in [try flat(40, 120, 200), try noisy()] {
            let viaFormat = try StillImageEncoder.data(image, format: .png)
            let viaPNG = try StillImageEncoder.pngData(image)
            XCTAssertEqual(viaFormat, viaPNG)
            // The quality argument does not apply to PNG.
            XCTAssertEqual(try StillImageEncoder.data(image, format: .png, quality: 0.1), viaPNG)
        }
    }

    func testTypeIdentifiersAreTheUniformTypes() {
        XCTAssertEqual(StillImageFormat.png.typeIdentifier, "public.png")
        XCTAssertEqual(StillImageFormat.jpeg.typeIdentifier, "public.jpeg")
        XCTAssertEqual(StillImageFormat.heic.typeIdentifier, "public.heic")
        XCTAssertEqual(StillImageFormat.allCases, [.png, .jpeg, .heic])
    }

    func testEveryAvailableFormatReadsBackAtItsSizeSpaceAndType() throws {
        let image = try flat(40, 120, 200)
        XCTAssertTrue(StillImageEncoder.isAvailable(.png))
        XCTAssertTrue(StillImageEncoder.isAvailable(.jpeg))
        for format in StillImageFormat.allCases where StillImageEncoder.isAvailable(format) {
            let data = try StillImageEncoder.data(image, format: format)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil), "\(format)")
            XCTAssertEqual(CGImageSourceGetType(source) as String?, format.typeIdentifier, "\(format)")
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil), "\(format)")
            XCTAssertEqual(decoded.width, Self.width, "\(format)")
            XCTAssertEqual(decoded.height, Self.height, "\(format)")
            XCTAssertEqual(decoded.colorSpace?.name, CGColorSpace.sRGB, "\(format)")
        }
    }

    func testAFlatColourDecodesExactlyForPNGAndWithinEightForLossyFormats() throws {
        let image = try flat(40, 120, 200)
        for format in StillImageFormat.allCases where StillImageEncoder.isAvailable(format) {
            let data = try StillImageEncoder.data(image, format: format)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let pixels = try redraw(decoded)
            let tolerance = format == .png ? 0 : 8
            var worst = 0
            for i in stride(from: 0, to: pixels.count, by: 4) {
                worst = max(worst, abs(Int(pixels[i]) - 40), abs(Int(pixels[i + 1]) - 120),
                            abs(Int(pixels[i + 2]) - 200))
                XCTAssertEqual(pixels[i + 3], 255)
            }
            XCTAssertLessThanOrEqual(worst, tolerance, "\(format): worst channel difference \(worst)")
        }
    }

    func testLowerJPEGQualityGivesSmallerData() throws {
        let image = try noisy()
        let low = try StillImageEncoder.data(image, format: .jpeg, quality: 0.3)
        let high = try StillImageEncoder.data(image, format: .jpeg, quality: 1.0)
        XCTAssertLessThan(low.count, high.count)
        // Out-of-range qualities are clamped, not refused.
        XCTAssertEqual(try StillImageEncoder.data(image, format: .jpeg, quality: 7), high)
        XCTAssertFalse(try StillImageEncoder.data(image, format: .jpeg, quality: -1).isEmpty)
    }

    func testHEICIsAvailableOnTheSimulator() {
        #if targetEnvironment(simulator)
        let runtime = ProcessInfo.processInfo.environment["SIMULATOR_RUNTIME_VERSION"]
            ?? ProcessInfo.processInfo.operatingSystemVersionString
        XCTAssertTrue(StillImageEncoder.isAvailable(.heic),
                      "HEIC encoding is not listed by ImageIO on the iOS \(runtime) simulator")
        #endif
    }
}
