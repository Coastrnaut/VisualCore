// StillExportTests — feature 184 (A25-P05) T-A25-504 (FR-A25-501, FR-A25-502, FR-A25-508; clarification Q2;
// contracts/export.md). `StillExport` without a renderer: a generated 40 × 24 gradient written as PNG, JPEG and HEIC
// (HEIC where the system can write it, else refused as `a25.export-format-unavailable`) decodes with ImageIO at its
// size, tagged sRGB, with the content type of its format; the PNG equals the input at every pixel; `validate` refuses
// an unavailable format before the size, a size above min(maxTextureSize, 2048) and a non-positive side, and accepts
// 2,048 × 1,024 on a 16,384 device; the refusal codes and messages and the file name are the contract's. Each test
// writes into its own folder under the temporary folder (named by the test and a counter, no UUID) and removes it.
// Short tests: no sleep, no clock. The renderer tests of T-A25-505 go in a separate suite in this file.
//
// Feature 184 (A25-P05) T-A25-505 (FR-A25-501 – FR-A25-503, FR-A25-508; contracts/export.md; analyze C1–C3): the suite
// `PresenterExport` exports through the presenter and the renderer in the one app's session host, each test with its
// own export base folder (`ComposerPresenter.exportBase`). An export is started (`startExport(format:)`), drawn in the
// next frame (`ComposerTest.draw`) and awaited. The regression fixture: the 96 × 64 gradient of `PictureSourceTests`
// imported through the normal path, chain grade (exposure +0.4), blur, vignette; the PNG decoded with ImageIO equals
// the preview's result read-back within 1/255 at every pixel, JPEG and HEIC (where the system writes it) within a mean
// of 3/255. Refusals (an unavailable format, a size above the texture limit seam) draw nothing (render and export
// counts unchanged) and write nothing; a second export removes the first file; a second call while one runs is ignored
// (one file); an all-disabled chain exports the source exactly; an export while an import is held back (the decoder
// seam waits on an `AsyncStream`) uses the shown picture; a full pool refuses as `a25.export-memory` and the preview
// keeps rendering; closing the experience removes the export folder.
import CoreGraphics
import EffectsComposerCore
import Foundation
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers
import VisualCoreExperience
import VisualCoreExperienceHost
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

/// Opening Effects Composer with a test export folder and running exports through the presenter.
@MainActor
enum ComposerExport {
    /// Opens Effects Composer in `session` with its export base in a fresh folder named after `test` (removed by
    /// ``close(_:_:)``), `configure` run before the first `setup`.
    static func open(_ session: ExperienceSession, test: String, size: CGSize = CGSize(width: 64, height: 48),
                     configure: @escaping (ComposerPresenter) -> Void = { _ in }) async throws
        -> ExperienceShell<ComposerPresenter> {
        let base = StillExportFixtures.freshFolder(test)
        return try await ComposerTest.open(session, size: size) { presenter in
            presenter.exportBase = base
            configure(presenter)
        }
    }

    /// Closes `session` and removes `shell`'s export base folder.
    static func close(_ session: ExperienceSession, _ shell: ExperienceShell<ComposerPresenter>?) {
        session.close()
        if let shell { StillExport.removeFolder(shell.presenter.exportBase) }
    }

    /// Starts an export as `format`, draws the next frame (where the export is drawn) and waits for the write.
    /// Returns whether the export was started (false when refused before drawing or ignored).
    @discardableResult
    static func run(_ shell: ExperienceShell<ComposerPresenter>, _ session: ExperienceSession,
                    _ format: StillImageFormat) async throws -> Bool {
        let task = shell.presenter.startExport(format: format)
        try ComposerTest.draw(session)
        await task?.value
        return task != nil
    }

    /// The names of the files in `shell`'s export folder, sorted; empty when the folder does not exist.
    static func files(_ shell: ExperienceShell<ComposerPresenter>) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: shell.presenter.exportFolder.path)) ?? []).sorted()
    }

    /// The written export of `shell` decoded with ImageIO into 8-bit sRGB RGBA, rows top-down.
    static func decoded(_ shell: ExperienceShell<ComposerPresenter>) throws -> RGBAImage {
        let file = try #require(shell.presenter.exportFile)
        let decoded = try #require(StillExportFixtures.decode(file.url))
        let pixels = try #require(StillExportFixtures.pixels(decoded.image))
        return RGBAImage(width: decoded.image.width, height: decoded.image.height, bytes: pixels)
    }

    /// The mean absolute difference of the colour channels of `a` and `b`, in code values.
    static func meanDifference(_ a: RGBAImage, _ b: RGBAImage) -> Double {
        var sum = 0, count = 0
        for i in 0..<a.bytes.count where i % 4 != 3 {
            sum += abs(Int(a.bytes[i]) - Int(b.bytes[i]))
            count += 1
        }
        return count == 0 ? 0 : Double(sum) / Double(count)
    }

    /// Imports the 96 × 64 gradient through the normal path and adds grade (exposure +0.4), blur and vignette.
    static func regressionFixture(_ shell: ExperienceShell<ComposerPresenter>,
                                  _ session: ExperienceSession) async throws -> RGBAImage {
        let data = PictureSourceTests.gradient()
        let picture = try PictureSourceTests.decoded(data)
        await shell.presenter.importPicture(data: data)
        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.set", [0, 0, 0.6])
        ComposerTest.accept(shell, "chain.add", [1, 1])
        ComposerTest.accept(shell, "chain.add", [3, 2])
        try ComposerTest.draw(session)
        return picture
    }
}

/// Exports through the presenter and the renderer (T-A25-505; see the file header).
@MainActor
@Suite("PresenterExport", .serialized)
struct PresenterExportTests {
    @Test("the PNG export equals the preview within 1/255; JPEG and HEIC within a mean of 3/255")
    func regressionFixture() async throws {
        let session = ExperienceSession()
        var shell: ExperienceShell<ComposerPresenter>?
        defer { ComposerExport.close(session, shell) }
        let opened = try await ComposerExport.open(session, test: "regression")
        shell = opened
        let picture = try await ComposerExport.regressionFixture(opened, session)
        let preview = try #require(opened.presenter.lastResult)
        #expect(preview.width == 96 && preview.height == 64)
        #expect(preview != picture, "the chain changes the picture")

        try await ComposerExport.run(opened, session, .png)
        #expect(opened.presenter.mirror.status == ComposerPresenter.exportedWord)
        #expect(opened.presenter.mirror.exportFile == opened.presenter.exportFile)
        #expect(opened.presenter.renderer.exportCount == 1)
        let png = try ComposerExport.decoded(opened)
        #expect(png.width == 96 && png.height == 64)
        let d = png.maxChannelDifference(ComposerTest.opaque(preview))
        #expect(d <= 1, "PNG against the preview: \(d)/255")

        for format in [StillImageFormat.jpeg, .heic] {
            guard StillImageEncoder.isAvailable(format) else {
                print("PresenterExport: \(format) skipped: the system cannot write it here")
                continue
            }
            try await ComposerExport.run(opened, session, format)
            #expect(opened.presenter.mirror.status == ComposerPresenter.exportedWord, "\(format)")
            let lossy = try ComposerExport.decoded(opened)
            let mean = ComposerExport.meanDifference(lossy, preview)
            #expect(mean <= 3, "\(format) mean \(mean)/255")
            print("PresenterExport regression: PNG max \(d)/255, \(format) mean \(mean)/255")
        }
    }

    @Test("an unavailable format and a too-large size are refused before drawing and write nothing")
    func refusalsBeforeDrawing() async throws {
        let session = ExperienceSession()
        var shell: ExperienceShell<ComposerPresenter>?
        defer { ComposerExport.close(session, shell) }
        let opened = try await ComposerExport.open(session, test: "refusals")
        shell = opened
        _ = try await ComposerExport.regressionFixture(opened, session)
        let renders = opened.presenter.renderer.renderCount

        opened.presenter.formatAvailable = { _ in false }
        #expect(try await ComposerExport.run(opened, session, .png) == false)
        #expect(opened.presenter.mirror.status == ExportRefusal.formatUnavailable.message)

        opened.presenter.formatAvailable = StillImageEncoder.isAvailable
        opened.presenter.exportTextureLimit = 64
        #expect(try await ComposerExport.run(opened, session, .png) == false)
        #expect(opened.presenter.mirror.status == ExportRefusal.tooLarge.message)

        #expect(opened.presenter.renderer.renderCount == renders, "nothing was drawn")
        #expect(opened.presenter.renderer.exportCount == 0)
        #expect(opened.presenter.exportFile == nil)
        #expect(!FileManager.default.fileExists(atPath: opened.presenter.exportFolder.path))
    }

    @Test("a second export removes the first file; a call while exporting is ignored")
    func oneFileAtATime() async throws {
        let session = ExperienceSession()
        var shell: ExperienceShell<ComposerPresenter>?
        defer { ComposerExport.close(session, shell) }
        let opened = try await ComposerExport.open(session, test: "one-file")
        shell = opened
        _ = try await ComposerExport.regressionFixture(opened, session)

        try await ComposerExport.run(opened, session, .png)
        #expect(ComposerExport.files(opened) == ["Look 96x64.png"])
        try await ComposerExport.run(opened, session, .jpeg)
        #expect(ComposerExport.files(opened) == ["Look 96x64.jpeg"], "the earlier file was removed")

        let first = opened.presenter.startExport(format: .png)
        #expect(first != nil)
        #expect(opened.presenter.mirror.status == ComposerPresenter.exportingWord)
        #expect(opened.presenter.mirror.isExporting)
        #expect(opened.presenter.startExport(format: .jpeg) == nil, "ignored while exporting")
        try ComposerTest.draw(session)
        await first?.value
        #expect(ComposerExport.files(opened) == ["Look 96x64.png"])
        #expect(opened.presenter.renderer.exportCount == 3)
        #expect(!opened.presenter.mirror.isExporting)
    }

    @Test("an all-disabled chain exports the source exactly")
    func allDisabledExportsTheSource() async throws {
        let session = ExperienceSession()
        var shell: ExperienceShell<ComposerPresenter>?
        defer { ComposerExport.close(session, shell) }
        let opened = try await ComposerExport.open(session, test: "disabled")
        shell = opened
        let picture = try await ComposerExport.regressionFixture(opened, session)
        for i in 0..<3 { ComposerTest.accept(opened, "chain.enable", [Double(i), 0]) }
        try await ComposerExport.run(opened, session, .png)
        #expect(try ComposerExport.decoded(opened) == picture)
    }

    @Test("an export while a picture is being read uses the shown picture")
    func exportWhileImporting() async throws {
        let session = ExperienceSession()
        var shell: ExperienceShell<ComposerPresenter>?
        defer { ComposerExport.close(session, shell) }
        let opened = try await ComposerExport.open(session, test: "importing")
        shell = opened
        let shown = PictureSourceTests.gradient(shift: 0)
        let pending = PictureSourceTests.gradient(shift: 100)
        let shownPicture = try PictureSourceTests.decoded(shown)
        await opened.presenter.importPicture(data: shown)
        try ComposerTest.draw(session)
        let (gate, open) = AsyncStream<Void>.makeStream()
        opened.presenter.decoder = { data, limit in
            if data == pending {
                for await _ in gate { break }
            }
            return ImageImport.decode(data, limit: limit)
        }
        let reading = opened.presenter.startImport(data: pending)
        #expect(opened.presenter.mirror.status == ComposerPresenter.readingWord)
        try await ComposerExport.run(opened, session, .png)
        #expect(try ComposerExport.decoded(opened) == shownPicture)
        open.yield()
        open.finish()
        await reading.value
        #expect(opened.presenter.mirror.status == ComposerPresenter.yourPictureWord)
    }

    @Test("a full pool refuses as a25.export-memory and the preview keeps working")
    func fullPoolRefusesAsMemory() async throws {
        let session = ExperienceSession()
        var shell: ExperienceShell<ComposerPresenter>?
        defer { ComposerExport.close(session, shell) }
        let opened = try await ComposerExport.open(session, test: "memory")
        shell = opened
        let picture = try await ComposerExport.regressionFixture(opened, session)
        let pool = try #require(opened.presenter.renderer.pool)
        var held: [RenderTarget] = []
        while pool.held < PreviewPool.maxTargets { held.append(try pool.acquire(width: 8, height: 8)) }
        #expect(try await ComposerExport.run(opened, session, .png))
        #expect(opened.presenter.mirror.status == ExportRefusal.memory.message)
        #expect(ExportRefusal.memory.code == "a25.export-memory")
        #expect(opened.presenter.exportFile == nil)
        #expect(ComposerExport.files(opened).isEmpty)
        #expect(pool.held == PreviewPool.maxTargets, "the refused export took nothing")
        for target in held { pool.release(target) }

        ComposerTest.accept(opened, "chain.set", [0, 0, 0.7])
        try ComposerTest.draw(session)
        let chain = try ComposerTest.core(opened).chain
        let result = try #require(opened.presenter.lastResult)
        #expect(result.maxChannelDifference(EffectReference.apply(chain, to: picture)) <= ComposerTest.tolerance(chain))
        try await ComposerExport.run(opened, session, .png)
        #expect(opened.presenter.mirror.status == ComposerPresenter.exportedWord)
    }

    @Test("closing the experience removes the export folder")
    func closingRemovesTheFolder() async throws {
        let session = ExperienceSession()
        let opened = try await ComposerExport.open(session, test: "close")
        defer { StillExport.removeFolder(opened.presenter.exportBase) }
        try await ComposerExport.run(opened, session, .png)
        let file = try #require(opened.presenter.exportFile)
        #expect(file.width == 256 && file.height == 256, "the test picture exports at its size")
        #expect(FileManager.default.fileExists(atPath: file.url.path))
        session.close()
        #expect(!FileManager.default.fileExists(atPath: opened.presenter.exportFolder.path))
        #expect(opened.presenter.exportFile == nil)
        #expect(opened.presenter.mirror.exportFile == nil)
    }
}
