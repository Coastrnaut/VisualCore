// StillCapture.swift — capture the host's current picture as a PNG file in an app-owned temporary folder (feature 029
// T-A03-404; gap G-CAPTURE; FR-A03-403; research R4). Generalized from A02's CaptureModel (feature 022): the render
// runs on the host's own context through `renderOffscreen` (no second context), `StillImageEncoder` makes the PNG, and
// only the latest file exists. Callers freeze any animation around `capture` and offer the file through the system
// share sheet; nothing here writes to Photos.
import Foundation
import Observation
import VisualCorePersistence
import VisualCoreScenes

/// The latest still capture of a render host, kept as one PNG in a temporary folder.
@MainActor
@Observable
public final class StillCapture {
    /// Where a capture stands.
    public enum State: Equatable, Sendable {
        /// Nothing captured (or the file was removed).
        case idle
        /// The PNG at this URL.
        case done(URL)
        /// The capture failed; the message is for the person.
        case failed(String)
    }

    /// The app-owned folder of capture files (callers empty it at launch).
    public let folder: TemporaryFolder
    /// The current state.
    public private(set) var state = State.idle
    /// The last captured image (tests, previews).
    public private(set) var lastImage: StillImage?

    /// A capture keeping its file in `folder`.
    public init(folder: TemporaryFolder) { self.folder = folder }

    /// The temporary folder `tmp/<name>` for captures.
    public nonisolated static func folder(named name: String) -> TemporaryFolder { TemporaryFolder(name: name) }

    /// Renders `host`'s scene at `size`, encodes a PNG named `<prefix>-….png` and replaces the previous file. On
    /// failure the state carries a message and no file is left.
    @discardableResult
    public func capture(host: RenderHost, size: ExportSize, prefix: String) -> State {
        do {
            let image = try host.renderOffscreen(width: size.width, height: size.height, time: 0)
            let png = try StillImageEncoder.pngData(image)
            removeFile()
            let url = try folder.makeFileURL(prefix: prefix, extension: "png")
            try png.write(to: url, options: .atomic)
            lastImage = image
            state = .done(url)
        } catch let error as OffscreenRenderError {
            removeFile()
            state = .failed(Self.message(for: error))
        } catch {
            removeFile()
            state = .failed("The picture could not be saved: \(error.localizedDescription)")
        }
        return state
    }

    /// The person-facing message for a render error.
    public nonisolated static func message(for error: OffscreenRenderError) -> String {
        switch error {
        case .invalidSize: "This picture size is too large for this device."
        default: "The picture could not be captured. Please try again."
        }
    }

    /// Deletes the captured file, if any, and returns to idle.
    public func removeFile() {
        if case .done(let url) = state { try? FileManager.default.removeItem(at: url) }
        state = .idle
    }
}
