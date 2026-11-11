// StillImage.swift — offscreen still export: the image type, its errors and the opaque sRGB PNG encoder
// (feature 015 T-A01-402; FR-A01-403, FR-A01-408; research R3, R4). RenderHost.renderOffscreen produces StillImages.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// An RGBA8 image in display orientation (row 0 is the top), produced by `RenderHost.renderOffscreen`.
public struct StillImage: Sendable, Equatable {
    /// Width in pixels.
    public let width: Int
    /// Height in pixels.
    public let height: Int
    /// RGBA bytes, 4 per pixel, rows top-down.
    public let rgba: [UInt8]

    /// Wraps top-down RGBA bytes; nil unless `rgba.count == width × height × 4` and both edges are positive.
    public init?(width: Int, height: Int, topDownRGBA rgba: [UInt8]) {
        guard width > 0, height > 0, rgba.count == width * height * 4 else { return nil }
        self.width = width
        self.height = height
        self.rgba = rgba
    }

    /// Flips GL readback rows (bottom-up) into display orientation; nil on a size mismatch.
    public init?(width: Int, height: Int, bottomUpRGBA: [UInt8]) {
        guard width > 0, height > 0, bottomUpRGBA.count == width * height * 4 else { return nil }
        let row = width * 4
        var flipped = [UInt8](repeating: 0, count: bottomUpRGBA.count)
        bottomUpRGBA.withUnsafeBufferPointer { src in
            flipped.withUnsafeMutableBufferPointer { dst in
                for y in 0..<height {
                    let from = (height - 1 - y) * row
                    dst.baseAddress!.advanced(by: y * row).update(from: src.baseAddress!.advanced(by: from), count: row)
                }
            }
        }
        self.init(width: width, height: height, topDownRGBA: flipped)
    }

    /// The pixel at column `x`, row `y` (top-down) as RGBA.
    public func pixel(x: Int, y: Int) -> SIMD4<UInt8> {
        let i = (y * width + x) * 4
        return SIMD4(rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3])
    }
}

/// Failures of an offscreen render or its encoding. A failed export never changes the live scene.
public enum OffscreenRenderError: Error, Equatable, Sendable {
    /// The host has no usable context or scene (destroyed, scene failed or not set up).
    case unavailable(String)
    /// The size is outside 1…max per edge or above the pixel cap; refused before any GPU work.
    case invalidSize(width: Int, height: Int, max: Int)
    /// The render target could not be created (over budget, invalid size or incomplete framebuffer).
    case resource(String)
    /// The scene threw while rendering offscreen.
    case scene(String)
    /// Reading the pixels back failed.
    case readback
    /// PNG encoding failed.
    case encoding
}

/// Encodes still images as opaque PNGs tagged with the sRGB color profile.
public enum StillImageEncoder {
    /// PNG data for `image`: alpha is dropped (stored as opaque), color space sRGB.
    public static func pngData(_ image: StillImage) throws(OffscreenRenderError) -> Data {
        var opaque = image.rgba
        for i in stride(from: 3, to: opaque.count, by: 4) { opaque[i] = 255 }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(opaque) as CFData),
              let cgImage = CGImage(width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: image.width * 4, space: space,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw .encoding }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, UTType.png.identifier as CFString, 1, nil)
        else { throw .encoding }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw .encoding }
        return output as Data
    }
}
