// SimulationCapture — feature 120 (A16-P04) T-A16-409 (FR-A16-440; SC-A16-404; Clarification Q5). A picture of the
// field: a 1024 × 1024 render through a closure (the host's still renderer in the app, a fake in tests), encoded as
// an sRGB PNG by `StillImageEncoder.pngData` into the temporary folder `a16-captures`. The folder holds at most one
// capture: a new capture replaces the previous file, and a failure removes it, shows the failure sentence and leaves
// no file. Nothing is written to Photos. `SimulationCaptureFile` hands the PNG to a ShareLink.
import CoreTransferable
import Foundation
import Observation
import UniformTypeIdentifiers
import VisualCorePersistence
import VisualCoreRendering

/// The capture of the field into one temporary PNG file.
@MainActor
@Observable
final class SimulationCapture {
    /// The edge of a capture in pixels.
    static let size = 1024
    /// The name of the temporary folder of captures.
    static let folderName = "a16-captures"
    /// The prefix of a capture file name (`a16-capture-<UUID>.png`).
    static let prefix = "a16-capture"
    /// The sentence shown after a failed capture.
    static let failureSentence = "The picture could not be captured. Please try again."

    /// The temporary folder that holds the capture.
    let folder: TemporaryFolder
    /// The current capture file; nil before the first capture, after a failure and after `clearFolder()`.
    private(set) var url: URL?
    /// The failure sentence after a failed capture; nil after a success.
    private(set) var message: String?

    /// A capture into `folder` (default: the temporary folder `a16-captures`).
    init(folder: TemporaryFolder = TemporaryFolder(name: SimulationCapture.folderName)) {
        self.folder = folder
    }

    /// Renders `size` × `size` pixels with `render(width, height)`, encodes a PNG and writes it atomically as a new
    /// file, removing the previous one. Any error (render, encoding, a wrong image size or the file system) removes
    /// the previous file too, sets `url` to nil and `message` to `failureSentence`.
    func capture(_ render: (Int, Int) throws -> StillImage) {
        let previous = url
        do {
            let image = try render(Self.size, Self.size)
            guard image.width == Self.size, image.height == Self.size else {
                throw OffscreenRenderError.invalidSize(width: image.width, height: image.height, max: Self.size)
            }
            let png = try StillImageEncoder.pngData(image)
            let target = try folder.makeFileURL(prefix: Self.prefix, extension: "png")
            try png.write(to: target, options: .atomic)
            if let previous { try? FileManager.default.removeItem(at: previous) }
            url = target
            message = nil
        } catch {
            if let previous { try? FileManager.default.removeItem(at: previous) }
            url = nil
            message = Self.failureSentence
        }
    }

    /// Empties the folder (the experience does this when it opens) and forgets the capture.
    func clearFolder() {
        folder.removeAll()
        url = nil
    }
}

/// A capture file offered to the share sheet as a PNG.
struct SimulationCaptureFile: Transferable {
    /// The PNG file.
    let url: URL

    /// The PNG file exported as itself.
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { SentTransferredFile($0.url) }
    }
}
