// StillExport — feature 184 (A25-P05) T-A25-504 (FR-A25-501, FR-A25-502, FR-A25-508; clarification Q2; data-model.md
// "ExportRefusal", "EffectsExportFile"; contracts/export.md). Writing the finished look as a still picture:
//
//   - ``StillExport/validate(width:height:format:maxTextureSize:available:)`` refuses a request before anything is
//     drawn: a format the system cannot write is ``ExportRefusal/formatUnavailable`` (checked first); a non-positive
//     side, a longer edge above `ExportGeometry(maxEdge: min(maxTextureSize, 2048)).effectiveMaxEdge` or more pixels
//     than its `maxPixels` is ``ExportRefusal/tooLarge``.
//   - ``StillExport/write(_:format:in:)`` encodes the read-back picture with `StillImageEncoder.data` at
//     ``StillExport/quality`` (0.9; opaque, tagged sRGB) on a detached task, off the main actor, creates the folder
//     and writes the file atomically as "Look <W>x<H>.<ext>" (``StillExport/fileName(width:height:format:)``). An
//     encoder failure is ``ExportRefusal/formatUnavailable``; a failed write is ``ExportRefusal/interrupted`` and leaves
//     no file.
//   - ``EffectsExportFile`` hands the written file to `ShareLink`: a `Transferable` whose `FileRepresentation` carries
//     the format's content type (`.png`, `.jpeg`, `.heic`) and sends the file itself, as Living Wallpapers does.
//
// The folder is `tmp/EffectsComposer` (``StillExport/folder(in:)``); the presenter removes it before a new export and
// when the experience closes (``StillExport/removeFolder(_:)``). No photo-library access and no platform prompt.
import CoreTransferable
import EffectsComposerCore
import Foundation
import UniformTypeIdentifiers
import VisualCoreRendering
import VisualCoreScenes

/// Why an export was not written; each case has a stable ``code`` and the sentence the status shows.
public enum ExportRefusal: Error, Equatable, Sendable {
    /// The system cannot write the chosen format, or encoding it failed.
    case formatUnavailable
    /// The picture is larger than the export limit of this device (or has a non-positive side).
    case tooLarge
    /// There is not enough graphics memory for the export target.
    case memory
    /// The export was interrupted (a context loss, an incomplete read-back or a failed write); nothing was kept.
    case interrupted

    /// The stable code: `a25.export-format-unavailable`, `a25.export-too-large`, `a25.export-memory` or
    /// `a25.export-interrupted`.
    public var code: String {
        switch self {
        case .formatUnavailable: return "a25.export-format-unavailable"
        case .tooLarge: return "a25.export-too-large"
        case .memory: return "a25.export-memory"
        case .interrupted: return "a25.export-interrupted"
        }
    }

    /// The sentence shown to the person.
    public var message: String {
        switch self {
        case .formatUnavailable: return "This format cannot be written here."
        case .tooLarge: return "This picture is too large to export."
        case .memory: return "There is not enough memory to export this picture."
        case .interrupted: return "The export was interrupted. Try again."
        }
    }
}

/// Validating, encoding and writing an exported still (clarification Q2; see the file header).
public enum StillExport {
    /// The lossy compression quality of JPEG and HEIC (PNG ignores it).
    public static let quality = 0.9
    /// The largest longer edge exported, before the device's `maxTextureSize` lowers it.
    public static let maximumEdge = 2_048
    /// The name of the export folder inside the base folder.
    public static let folderName = "EffectsComposer"

    /// The export geometry of a device: `ExportGeometry(maxEdge: min(maxTextureSize, 2048))`.
    public static func geometry(maxTextureSize: Int) -> ExportGeometry {
        ExportGeometry(maxEdge: min(maxTextureSize, maximumEdge))
    }

    /// The refusal for exporting a `width × height` picture as `format` on a device with `maxTextureSize`, or nil when
    /// it may be exported. The format is checked first (`available`, by default `StillImageEncoder.isAvailable`), then
    /// the size against ``geometry(maxTextureSize:)``. Pure; nothing is drawn.
    public static func validate(width: Int, height: Int, format: StillImageFormat, maxTextureSize: Int,
                                available: (StillImageFormat) -> Bool = StillImageEncoder.isAvailable)
        -> ExportRefusal? {
        guard available(format) else { return .formatUnavailable }
        let limits = geometry(maxTextureSize: maxTextureSize)
        guard width > 0, height > 0,
              max(width, height) <= limits.effectiveMaxEdge,
              width * height <= limits.maxPixels // both edges are at most 8,192 here, so no overflow
        else { return .tooLarge }
        return nil
    }

    /// The file extension of `format`, its content type's preferred one: `png`, `jpeg` or `heic`.
    public static func fileExtension(_ format: StillImageFormat) -> String {
        switch format {
        case .png: return "png"
        case .jpeg: return "jpeg"
        case .heic: return "heic"
        }
    }

    /// The file name "Look <W>x<H>.<ext>", for example "Look 96x64.png".
    public static func fileName(width: Int, height: Int, format: StillImageFormat) -> String {
        "Look \(width)x\(height).\(fileExtension(format))"
    }

    /// The export folder inside `base` (by default the temporary folder): `base/EffectsComposer`.
    public static func folder(in base: URL = FileManager.default.temporaryDirectory) -> URL {
        base.appendingPathComponent(folderName, isDirectory: true)
    }

    /// `picture` encoded as `format` at ``quality`` and written atomically into `folder` (created when missing) as
    /// ``fileName(width:height:format:)``. The encode and the write run on a detached task, off the main actor.
    /// Throws ``ExportRefusal/formatUnavailable`` when encoding fails and ``ExportRefusal/interrupted`` when the file
    /// cannot be written; a failed write leaves no file.
    public static func write(_ picture: RGBAImage, format: StillImageFormat,
                             in folder: URL) async throws(ExportRefusal) -> EffectsExportFile {
        let result = await Task.detached(priority: .userInitiated) {
            encodeAndWrite(picture, format: format, in: folder)
        }.value
        switch result {
        case .success(let file): return file
        case .failure(let refusal): throw refusal
        }
    }

    /// The synchronous body of ``write(_:format:in:)``.
    private static func encodeAndWrite(_ picture: RGBAImage, format: StillImageFormat,
                                       in folder: URL) -> Result<EffectsExportFile, ExportRefusal> {
        guard let still = StillImage(width: picture.width, height: picture.height, topDownRGBA: picture.bytes)
        else { return .failure(.formatUnavailable) }
        let data: Data
        do {
            data = try StillImageEncoder.data(still, format: format, quality: quality)
        } catch {
            return .failure(.formatUnavailable)
        }
        let url = folder.appendingPathComponent(fileName(width: picture.width, height: picture.height,
                                                         format: format), isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: url)
            return .failure(.interrupted)
        }
        return .success(EffectsExportFile(url: url, format: format, width: picture.width, height: picture.height))
    }

    /// Removes `folder` and everything in it; a missing folder or a failed removal is ignored.
    public static func removeFolder(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }
}

/// A written export offered to the share sheet with its format's content type (see the file header).
public struct EffectsExportFile: Transferable, Equatable, Sendable {
    /// The written file.
    public let url: URL
    /// The file's format.
    public let format: StillImageFormat
    /// The picture's width in pixels.
    public let width: Int
    /// The picture's height in pixels.
    public let height: Int

    /// A share item for the `width × height` picture written at `url` in `format`.
    public init(url: URL, format: StillImageFormat, width: Int, height: Int) {
        self.url = url
        self.format = format
        self.width = width
        self.height = height
    }

    /// The content type of `format`: `.png`, `.jpeg` or `.heic`.
    public static func contentType(_ format: StillImageFormat) -> UTType {
        switch format {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        }
    }

    /// The content type of this file's format.
    public var contentType: UTType { Self.contentType(format) }

    /// The written file, sent as itself with the content type of its format; each representation is offered only
    /// for its own format.
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { SentTransferredFile($0.url) }
            .exportingCondition { $0.format == .png }
        FileRepresentation(exportedContentType: .jpeg) { SentTransferredFile($0.url) }
            .exportingCondition { $0.format == .jpeg }
        FileRepresentation(exportedContentType: .heic) { SentTransferredFile($0.url) }
            .exportingCondition { $0.format == .heic }
    }
}
