// CaptureModel.swift — still capture of the current picture (feature 022 T-A02-405; FR-A02-405, FR-A02-406;
// spec 022 clarification 3). Everything GPU-side is VisualCore's A01 export path: RenderHost.renderOffscreen on the
// host's own context (no second context), ExportGeometry for the size and StillImageEncoder for the PNG. The scene is
// paused for the render so a capture never advances the simulation. Only the latest PNG exists, in the temporary
// directory, and it is deleted when the playground closes. Saving to Photos happens only through the system share
// sheet (NSPhotoLibraryAddUsageDescription).
import Foundation
import Observation
import VisualCoreRendering
import VisualCoreScenes

@MainActor
@Observable
final class CaptureModel {
    enum State: Equatable {
        case idle
        case done(URL)
        case failed(String)
    }

    /// Long edge of a capture in pixels (capped by the device).
    static let longEdge = 2048

    private(set) var state = State.idle
    /// The last captured image (for tests and the preview).
    private(set) var lastImage: StillImage?

    /// Renders the host's current scene (including the glow) at the capture size in the canvas aspect.
    /// `sizeOverride` is a test seam for the failure path.
    func capture(host: RenderHost, scene: FluidFieldsScene, viewSize: CGSize, sizeOverride: ExportSize? = nil) {
        let wasPaused = scene.paused
        scene.paused = true
        defer { scene.paused = wasPaused }
        guard let aspect = ExportAspect(id: "canvas", title: "Canvas", width: max(1, Int(viewSize.width.rounded())),
                                        height: max(1, Int(viewSize.height.rounded()))) else {
            state = .failed("The canvas has no size yet. Try again in a moment.")
            return
        }
        let size = sizeOverride ?? ExportGeometry(maxEdge: host.maxRenderSize).size(longEdge: Self.longEdge, aspect: aspect)
        do {
            let image = try host.renderOffscreen(width: size.width, height: size.height, time: 0)
            let png = try StillImageEncoder.pngData(image)
            removeFile()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("FluidArt-\(UUID().uuidString).png")
            try png.write(to: url, options: .atomic)
            lastImage = image
            state = .done(url)
        } catch let error as OffscreenRenderError {
            state = .failed(Self.message(for: error))
        } catch {
            state = .failed("The picture could not be saved: \(error.localizedDescription)")
        }
    }

    static func message(for error: OffscreenRenderError) -> String {
        switch error {
        case .invalidSize: "This picture size is too large for this device."
        default: "The picture could not be captured. Please try again."
        }
    }

    /// Deletes the captured file, if any.
    func removeFile() {
        if case .done(let url) = state { try? FileManager.default.removeItem(at: url) }
        state = .idle
    }
}
