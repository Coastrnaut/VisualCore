// GardenStill — feature 148 (A20-P04) T-A20-405 (FR-A20-405, FR-A20-406; clarification Q4; data-model.md
// "GardenStill"; contracts/library.md "Still"). A still picture of the garden for the system share sheet:
//
//   - the session's still renderer (`experienceStillRenderer`, the open experience drawn off screen on the session's
//     own render host; no second context and no GL call here) draws the tray at 1600 × 1200 pixels;
//   - `StillImageEncoder.pngData` encodes it as an opaque sRGB PNG;
//   - the PNG is written atomically as the one file "Zen Garden 1600x1200.png" in the temporary folder
//     `DigitalZenGarden-Still` (`TemporaryFolder`), so the share sheet shows that name. Each export first removes the
//     previous file, and a failure at any step leaves no file, so the folder holds at most one file.
//
// The file is handed to SwiftUI `ShareLink` as a `GardenStillFile` (a `Transferable` PNG file). "Save Image" in the
// share sheet uses the app's add-only Photos usage string (the registration declares `photo-library-add`); the
// experience itself makes no Photos library call and no network request.
import CoreTransferable
import Foundation
import UniformTypeIdentifiers
import VisualCorePersistence
import VisualCoreRendering

/// Why a still export failed; no file is left behind.
enum StillFailure: String, Error, Equatable, Sendable, CaseIterable {
    /// No still renderer is available (no experience is open).
    case noRenderer = "no-renderer"
    /// The renderer threw or drew a picture of another size.
    case render
    /// The picture could not be encoded as PNG.
    case encoding
    /// The file could not be written.
    case write

    /// One sentence for the person.
    var sentence: String {
        switch self {
        case .noRenderer: return "The picture cannot be drawn now."
        case .render: return "The picture could not be drawn."
        case .encoding: return "The picture could not be encoded."
        case .write: return "The picture could not be written."
        }
    }
}

/// The still export of the garden (see the file header).
@MainActor
final class GardenStill {
    /// The picture's width in pixels.
    static let width = 1600
    /// The picture's height in pixels.
    static let height = 1200
    /// The one file the export writes.
    static let fileName = "Zen Garden \(width)x\(height).png"
    /// The name of the temporary folder.
    static let folderName = "DigitalZenGarden-Still"

    /// The renderer of a still: width and height in pixels (main actor).
    typealias Render = @MainActor (Int, Int) throws(OffscreenRenderError) -> StillImage

    /// The folder the export writes into.
    let folder: TemporaryFolder
    /// The written file of the last export; nil before one and after a failure.
    private(set) var lastURL: URL?

    /// An exporter writing into `folder` (default `DigitalZenGarden-Still` in the temporary directory).
    init(folder: TemporaryFolder = TemporaryFolder(name: GardenStill.folderName)) {
        self.folder = folder
    }

    /// The file the export writes.
    var fileURL: URL { folder.url.appendingPathComponent(Self.fileName, isDirectory: false) }

    /// Removes the previous file, draws the garden with `render` at 1600 × 1200, encodes it as PNG and writes it;
    /// returns the file, or the failure (no file is left behind).
    func export(render: Render?) -> Result<URL, StillFailure> {
        discard()
        guard let render else { return .failure(.noRenderer) }
        let image: StillImage
        do {
            image = try render(Self.width, Self.height)
        } catch {
            return .failure(.render)
        }
        guard image.width == Self.width, image.height == Self.height else { return .failure(.render) }
        let data: Data
        do {
            data = try StillImageEncoder.pngData(image)
        } catch {
            return .failure(.encoding)
        }
        let url = fileURL
        do {
            try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: url)
            return .failure(.write)
        }
        lastURL = url
        return .success(url)
    }

    /// Removes the written file, if any.
    func discard() {
        lastURL = nil
        let url = fileURL
        if FileManager.default.fileExists(atPath: url.path) { try? FileManager.default.removeItem(at: url) }
    }
}

/// The written still handed to the share sheet: the PNG file itself.
struct GardenStillFile: Transferable, Equatable, Sendable {
    /// The written file.
    let url: URL

    /// The file, sent as itself with the PNG content type.
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { SentTransferredFile($0.url) }
    }
}
