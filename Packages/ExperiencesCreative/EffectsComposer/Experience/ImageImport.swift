// ImageImport — feature 183 (A25-P04) T-A25-404 (clarification Q2; data-model.md "ImportedPicture", "ImportRefusal";
// contracts/import.md). Decoding a picture the person picked into the bytes the preview uploads:
//
//   - Data above ``ImageImport/maxDataBytes`` (50 MiB) is refused as ``ImportRefusal/imageTooLarge`` before any
//     decoding.
//   - ImageIO reads the data (`CGImageSourceCreateWithData`); data it cannot read, or reads only in part, is
//     ``ImportRefusal/imageDamaged``.
//   - The picture is made with `CGImageSourceCreateThumbnailAtIndex`, the EXIF orientation applied
//     (`kCGImageSourceCreateThumbnailWithTransform`) and the longer edge at most `limit`. A picture already within the
//     limit keeps its size: the requested edge is the smaller of `limit` and the picture's own longer edge, so nothing is
//     enlarged.
//   - A result under ``ImageImport/minimumEdge`` (8) pixels on a side is ``ImportRefusal/imageTooSmall``.
//   - The picture is drawn into an 8-bit sRGB `CGContext` with premultiplied-last alpha (converting any embedded
//     profile, Display P3 for example, to sRGB) and un-premultiplied into straight RGBA bytes, rows top-down (the
//     context's memory is top-down; nothing is flipped).
//
// Pure CPU and free of actor isolation, so the presenter can run it on a background task.
import CoreGraphics
import EffectsComposerCore
import Foundation
import ImageIO

/// A decoded picture: RGBA8 with straight alpha, rows top-down, in sRGB; each side 8…`limit` pixels.
/// It is the core's ``RGBAImage``, the shape the test picture already has.
public typealias ImportedPicture = RGBAImage

/// Why a picked picture was not used; each case has a stable ``code`` and the sentence the status shows.
public enum ImportRefusal: Error, Equatable, Sendable {
    /// ImageIO could not read the data (not a picture, damaged or cut short).
    case imageDamaged
    /// The data is larger than ``ImageImport/maxDataBytes``.
    case imageTooLarge
    /// The picture is under ``ImageImport/minimumEdge`` pixels on a side.
    case imageTooSmall

    /// The stable code: `a25.image-damaged`, `a25.image-too-large` or `a25.image-too-small`.
    public var code: String {
        switch self {
        case .imageDamaged: return "a25.image-damaged"
        case .imageTooLarge: return "a25.image-too-large"
        case .imageTooSmall: return "a25.image-too-small"
        }
    }

    /// The sentence shown to the person.
    public var message: String {
        switch self {
        case .imageDamaged: return "This picture cannot be read."
        case .imageTooLarge: return "This picture is too large."
        case .imageTooSmall: return "This picture is too small."
        }
    }
}

/// Decoding picked picture data into an ``ImportedPicture`` (clarification Q2).
public enum ImageImport {
    /// The largest data accepted, 50 MiB; larger data is refused before decoding.
    public static let maxDataBytes = 50 * 1024 * 1024
    /// The smallest side accepted, in pixels.
    public static let minimumEdge = 8
    /// The largest longer edge, in pixels (the preview pool's cap of A25-P02).
    public static let maximumEdge = 2_048

    /// The longer-edge limit for a device: the smaller of its `maxTextureSize` and ``maximumEdge``.
    public static func limit(maxTextureSize: Int) -> Int { min(maxTextureSize, maximumEdge) }

    /// Decodes `data` into a picture whose longer edge is at most `limit` (never enlarged), with the EXIF orientation
    /// applied, in sRGB, straight alpha, rows top-down; or the reason it was refused.
    public static func decode(_ data: Data, limit: Int) -> Result<ImportedPicture, ImportRefusal> {
        guard data.count <= maxDataBytes else { return .failure(.imageTooLarge) }
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
        else { return .failure(.imageDamaged) }

        // The picture's own longer edge, so a small picture is not enlarged.
        var ownEdge = limit
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
           let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue {
            ownEdge = max(width, height)
        }
        let edge = max(1, min(limit, ownEdge))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: edge,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return .failure(.imageDamaged)
        }
        let width = image.width
        let height = image.height
        guard width >= minimumEdge, height >= minimumEdge else { return .failure(.imageTooSmall) }
        guard let bytes = straightSRGBBytes(of: image) else { return .failure(.imageDamaged) }
        return .success(ImportedPicture(width: width, height: height, bytes: bytes))
    }

    /// Draws `image` into an 8-bit sRGB premultiplied-last context and returns straight RGBA bytes, rows top-down;
    /// nil when the context cannot be made.
    static func straightSRGBBytes(of image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let rowBytes = width * 4
        var bytes = [UInt8](repeating: 0, count: rowBytes * height)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: rowBytes, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        unpremultiply(&bytes)
        return bytes
    }

    /// Converts premultiplied RGBA bytes to straight alpha in place (rounded; colour 0 where alpha is 0).
    static func unpremultiply(_ bytes: inout [UInt8]) {
        var i = 0
        while i < bytes.count {
            let alpha = Int(bytes[i + 3])
            if alpha == 0 {
                bytes[i] = 0; bytes[i + 1] = 0; bytes[i + 2] = 0
            } else if alpha < 255 {
                for c in 0..<3 {
                    bytes[i + c] = UInt8(min(255, (Int(bytes[i + c]) * 255 + alpha / 2) / alpha))
                }
            }
            i += 4
        }
    }
}
