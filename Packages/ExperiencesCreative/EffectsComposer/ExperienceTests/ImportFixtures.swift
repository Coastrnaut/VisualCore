// ImportFixtures — feature 183 (A25-P04) T-A25-405 (clarification Q3; SC-A25-401 – SC-A25-403). The pictures the
// import tests decode, generated in code with ImageIO and never bundled:
//
//   - ``ImportFixtures/oriented(_:)``: a stored 64 × 48 PNG, blue with an 8 × 8 red block, written with an EXIF
//     orientation 1…8 (`kCGImagePropertyOrientation` in the image's properties; ImageIO keeps it in PNG). The block is
//     placed at the stored corner that the orientation shows at the displayed top left (the inverse of the EXIF
//     transform): 1 and 5 top left, 2 and 8 top right, 3 and 7 bottom right, 4 and 6 bottom left.
//   - ``ImportFixtures/flat(width:height:red:green:blue:alpha:space:)``: a flat colour in any colour space (the
//     profile is embedded), for the Display P3 red, the 4,000 × 1,000 and the 4 × 4 pictures and the partial alpha.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Pictures for the import tests, encoded as PNG data.
enum ImportFixtures {
    /// The stored size of the oriented picture.
    static let storedWidth = 64
    /// The stored height of the oriented picture.
    static let storedHeight = 48
    /// The side of the red marked block.
    static let block = 8

    /// The stored corner (column, row of the block's top-left pixel) that orientation `orientation` shows at the
    /// displayed top left.
    static func storedCorner(orientation: Int) -> (x: Int, y: Int) {
        let right = storedWidth - block
        let bottom = storedHeight - block
        switch orientation {
        case 2, 8: return (right, 0)
        case 3, 7: return (right, bottom)
        case 4, 6: return (0, bottom)
        default: return (0, 0)
        }
    }

    /// The 64 × 48 stored picture, blue with the red block at ``storedCorner(orientation:)``, as PNG data tagged with
    /// EXIF orientation `orientation`.
    static func oriented(_ orientation: Int) -> Data {
        let corner = storedCorner(orientation: orientation)
        var bytes = [UInt8](repeating: 0, count: storedWidth * storedHeight * 4)
        for y in 0..<storedHeight {
            for x in 0..<storedWidth {
                let i = (y * storedWidth + x) * 4
                let marked = x >= corner.x && x < corner.x + block && y >= corner.y && y < corner.y + block
                bytes[i] = marked ? 255 : 0
                bytes[i + 2] = marked ? 0 : 255
                bytes[i + 3] = 255
            }
        }
        let image = cgImage(width: storedWidth, height: storedHeight, bytes: bytes,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!)
        return png(image, properties: [kCGImagePropertyOrientation: orientation])
    }

    /// A flat picture of `width × height` pixels with the straight channels given (0…255) in colour space `space`,
    /// as PNG data with the profile embedded.
    static func flat(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255,
                     space: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!) -> Data {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        var i = 0
        while i < bytes.count {
            bytes[i] = red; bytes[i + 1] = green; bytes[i + 2] = blue; bytes[i + 3] = alpha
            i += 4
        }
        return png(cgImage(width: width, height: height, bytes: bytes, space: space), properties: [:])
    }

    /// A `CGImage` of straight RGBA bytes (rows top-down) in `space`.
    static func cgImage(width: Int, height: Int, bytes: [UInt8], space: CGColorSpace) -> CGImage {
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    /// `image` encoded as PNG with `properties`.
    static func png(_ image: CGImage, properties: [CFString: Any]) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        precondition(CGImageDestinationFinalize(destination), "ImportFixtures: PNG not written")
        return data as Data
    }

    /// The sRGB bytes (straight, 0…255) CoreGraphics gives one opaque pixel of `rgb` in `space`: the standard
    /// conversion the decoded picture is compared with.
    static func srgbReference(of rgb: (UInt8, UInt8, UInt8), in space: CGColorSpace) -> SIMD3<Int> {
        let image = cgImage(width: 1, height: 1, bytes: [rgb.0, rgb.1, rgb.2, 255], space: space)
        var out = [UInt8](repeating: 0, count: 4)
        out.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                    bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return SIMD3(Int(out[0]), Int(out[1]), Int(out[2]))
    }
}
