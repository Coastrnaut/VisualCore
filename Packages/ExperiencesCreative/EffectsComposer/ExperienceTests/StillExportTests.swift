// StillExportTests — feature 184 (A25-P05) T-A25-504 (FR-A25-501, FR-A25-502, FR-A25-508; clarification Q2;
// contracts/export.md). `StillExport` without a renderer: a generated 40 × 24 gradient written as PNG, JPEG and HEIC
// (HEIC where the system can write it, else refused as `a25.export-format-unavailable`) decodes with ImageIO at its
// size, tagged sRGB, with the content type of its format; the PNG equals the input at every pixel; `validate` refuses
// an unavailable format before the size, a size above min(maxTextureSize, 2048) and a non-positive side, and accepts
// 2,048 × 1,024 on a 16,384 device; the refusal codes and messages and the file name are the contract's. Each test
// writes into its own folder under the temporary folder (named by the test and a counter, no UUID) and removes it.
// Short tests: no sleep, no clock. The renderer tests of T-A25-505 go in a separate suite in this file.
import CoreGraphics
import EffectsComposerCore
import Foundation
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers
@testable import EffectsComposerExperience
import VisualCoreRendering

/// Fixtures shared by the export suites: the gradient picture, fresh folders and the ImageIO decode.
enum StillExportFixtures {
    /// The folder counter, so two folders of one test never collide.
    private static let counter = Mutex(0)

    /// A fresh, empty folder under the temporary folder named "EffectsComposerTests-<test>-<n>".
    static func freshFolder(_ test: String) -> URL {
        let n = counter.withLock { value in
            value += 1
            return value
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EffectsComposerTests-\(test)-\(n)", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        return url
    }

    /// An opaque `width × height` gradient: red rises with the column, green with the row, blue is their mix.
    static func gradient(width: Int = 40, height: Int = 24) -> RGBAImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                bytes[i] = UInt8(255 * x / max(width - 1, 1))
                bytes[i + 1] = UInt8(255 * y / max(height - 1, 1))
                bytes[i + 2] = UInt8((Int(bytes[i]) + Int(bytes[i + 1])) / 2)
            }
        }
        return RGBAImage(width: width, height: height, bytes: bytes)
    }

    /// The file at `url` decoded with ImageIO: its type identifier and image.
    static func decode(_ url: URL) -> (type: String?, image: CGImage)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return (CGImageSourceGetType(source) as String?, image)
    }

    /// `image` redrawn into an 8-bit sRGB RGBA context, rows top-down.
    static func pixels(_ image: CGImage) -> [UInt8]? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? bytes : nil
    }
}

/// Validation, file names and writing of clarification Q2.
@Suite("StillExport")
struct StillExportTests {
    @Test("each format writes a file of the picture's size tagged sRGB")
    func eachFormatWritesADecodableSRGBFile() async throws {
        let picture = StillExportFixtures.gradient()
        for format in StillImageFormat.allCases {
            let folder = StillExportFixtures.freshFolder("formats")
            defer { StillExport.removeFolder(folder) }
            guard StillImageEncoder.isAvailable(format) else {
                await #expect(throws: ExportRefusal.formatUnavailable) {
                    _ = try await StillExport.write(picture, format: format, in: folder)
                }
                continue
            }
            let file = try await StillExport.write(picture, format: format, in: folder)
            #expect(file.url == folder.appendingPathComponent("Look 40x24.\(StillExport.fileExtension(format))"))
            #expect(file.format == format)
            #expect(file.width == 40 && file.height == 24)
            #expect(file.contentType.identifier == format.typeIdentifier)
            let decoded = try #require(StillExportFixtures.decode(file.url), "\(format)")
            #expect(decoded.type == format.typeIdentifier, "\(format)")
            #expect(decoded.image.width == 40 && decoded.image.height == 24, "\(format)")
            #expect(decoded.image.colorSpace?.name == CGColorSpace.sRGB, "\(format)")
        }
    }

    @Test("the PNG equals the picture at every pixel")
    func pngIsLossless() async throws {
        let picture = StillExportFixtures.gradient()
        let folder = StillExportFixtures.freshFolder("png")
        defer { StillExport.removeFolder(folder) }
        let file = try await StillExport.write(picture, format: .png, in: folder)
        let decoded = try #require(StillExportFixtures.decode(file.url))
        let pixels = try #require(StillExportFixtures.pixels(decoded.image))
        #expect(pixels == picture.bytes)
    }

    @Test("a second write of the same size replaces the file, and removing the folder removes it")
    func writeReplacesAndFolderRemoves() async throws {
        let folder = StillExportFixtures.freshFolder("replace")
        defer { StillExport.removeFolder(folder) }
        _ = try await StillExport.write(StillExportFixtures.gradient(), format: .png, in: folder)
        let file = try await StillExport.write(StillExportFixtures.gradient(), format: .png, in: folder)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(names == ["Look 40x24.png"])
        StillExport.removeFolder(folder)
        #expect(!FileManager.default.fileExists(atPath: file.url.path))
        StillExport.removeFolder(folder) // a missing folder is ignored
    }

    @Test("a folder that cannot be created is an interrupted export")
    func unwritableFolderIsInterrupted() async throws {
        let base = StillExportFixtures.freshFolder("blocked")
        defer { StillExport.removeFolder(base) }
        // A plain file where the folder should be, so the folder cannot be created.
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let blocker = base.appendingPathComponent("EffectsComposer")
        try Data([1]).write(to: blocker)
        await #expect(throws: ExportRefusal.interrupted) {
            _ = try await StillExport.write(StillExportFixtures.gradient(), format: .png, in: blocker)
        }
    }

    @Test("an unavailable format is refused before the size")
    func unavailableFormatIsRefusedFirst() {
        for format in StillImageFormat.allCases {
            #expect(StillExport.validate(width: 40, height: 24, format: format, maxTextureSize: 16_384,
                                         available: { _ in false }) == .formatUnavailable)
            #expect(StillExport.validate(width: 0, height: 0, format: format, maxTextureSize: 16_384,
                                         available: { _ in false }) == .formatUnavailable)
        }
    }

    @Test("sizes above min(maxTextureSize, 2048) and non-positive sides are too large")
    func sizeLimits() {
        let always: (StillImageFormat) -> Bool = { _ in true }
        #expect(StillExport.validate(width: 2_048, height: 1_024, format: .png, maxTextureSize: 16_384,
                                     available: always) == nil)
        #expect(StillExport.validate(width: 2_048, height: 2_048, format: .jpeg, maxTextureSize: 4_096,
                                     available: always) == nil)
        #expect(StillExport.validate(width: 2_049, height: 1_024, format: .png, maxTextureSize: 16_384,
                                     available: always) == .tooLarge)
        #expect(StillExport.validate(width: 1_024, height: 2_050, format: .png, maxTextureSize: 16_384,
                                     available: always) == .tooLarge)
        #expect(StillExport.validate(width: 1_024, height: 1_024, format: .png, maxTextureSize: 1_024,
                                     available: always) == nil)
        #expect(StillExport.validate(width: 1_026, height: 512, format: .png, maxTextureSize: 1_024,
                                     available: always) == .tooLarge)
        #expect(StillExport.validate(width: 0, height: 24, format: .png, maxTextureSize: 16_384,
                                     available: always) == .tooLarge)
        #expect(StillExport.validate(width: 40, height: -1, format: .png, maxTextureSize: 16_384,
                                     available: always) == .tooLarge)
        #expect(StillExport.geometry(maxTextureSize: 16_384).effectiveMaxEdge == 2_048)
    }

    @Test("PNG and JPEG validate with the system's encoder")
    func defaultAvailability() {
        #expect(StillExport.validate(width: 40, height: 24, format: .png, maxTextureSize: 16_384) == nil)
        #expect(StillExport.validate(width: 40, height: 24, format: .jpeg, maxTextureSize: 16_384) == nil)
    }

    @Test("refusal codes and messages are the contract's")
    func codesAndMessages() {
        #expect(ExportRefusal.formatUnavailable.code == "a25.export-format-unavailable")
        #expect(ExportRefusal.formatUnavailable.message == "This format cannot be written here.")
        #expect(ExportRefusal.tooLarge.code == "a25.export-too-large")
        #expect(ExportRefusal.tooLarge.message == "This picture is too large to export.")
        #expect(ExportRefusal.memory.code == "a25.export-memory")
        #expect(ExportRefusal.memory.message == "There is not enough memory to export this picture.")
        #expect(ExportRefusal.interrupted.code == "a25.export-interrupted")
        #expect(ExportRefusal.interrupted.message == "The export was interrupted. Try again.")
    }

    @Test("the file name is Look <W>x<H> with the content type's preferred extension")
    func fileNames() {
        #expect(StillExport.fileName(width: 96, height: 64, format: .png) == "Look 96x64.png")
        #expect(StillExport.fileName(width: 2_048, height: 1_365, format: .jpeg) == "Look 2048x1365.jpeg")
        #expect(StillExport.fileName(width: 8, height: 8, format: .heic) == "Look 8x8.heic")
        for format in StillImageFormat.allCases {
            #expect(EffectsExportFile.contentType(format).preferredFilenameExtension
                    == StillExport.fileExtension(format))
            #expect(EffectsExportFile.contentType(format).identifier == format.typeIdentifier)
        }
        let base = URL(fileURLWithPath: "/base", isDirectory: true)
        #expect(StillExport.folder(in: base).path == "/base/EffectsComposer")
        #expect(StillExport.quality == 0.9)
    }
}
