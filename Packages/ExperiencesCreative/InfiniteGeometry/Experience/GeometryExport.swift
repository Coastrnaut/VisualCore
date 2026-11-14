// GeometryExport — feature 043 (A05-P04) T-A05-404 (FR-A05-410–413). The still export of Infinite Geometry: the
// current composition rendered off screen through the host's still renderer (the session's own context, no second
// renderer) at the canvas's aspect with a long edge of at most 2048 pixels, encoded as a PNG held in memory for the
// system's share interface. No file is written, no metadata is added and the core is never changed by an export.
import CoreGraphics
import CoreTransferable
import Foundation
import UniformTypeIdentifiers
import VisualCoreExperienceHost
import VisualCoreRendering

/// A PNG made by the export, offered to the system's share interface without a file of the app's own.
struct GeometryCapture: Transferable {
    /// The PNG data.
    let data: Data
    /// The width of the picture in pixels.
    let width: Int
    /// The height of the picture in pixels.
    let height: Int

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}

/// The export size and the PNG export of the current composition.
enum GeometryExport {
    /// The long edge of an export in pixels.
    static let longEdge = 2048

    /// The export size for a canvas of `canvas` pixels: the canvas's aspect with a long edge of
    /// `min(longEdge, maxEdge)` pixels and at least one pixel on each side. Nil for a canvas with a zero, negative or
    /// non-finite side, or a `maxEdge` below 1.
    static func size(canvas: CGSize, maxEdge: Int) -> (width: Int, height: Int)? {
        let width = Double(canvas.width), height = Double(canvas.height)
        guard width.isFinite, height.isFinite, width > 0, height > 0, maxEdge >= 1 else { return nil }
        let long = Double(min(longEdge, maxEdge))
        let scale = long / max(width, height)
        return (max(1, Int((width * scale).rounded())), max(1, Int((height * scale).rounded())))
    }

    /// Renders the current picture through `still` at `size(canvas:maxEdge:)` and encodes it as a PNG. Throws
    /// `OffscreenRenderError.invalidSize` for a canvas without a size, and the renderer's or the encoder's error when
    /// the picture cannot be made (for example a size the device cannot render); nothing is changed then.
    @MainActor
    static func png(still: ExperienceStillRenderer, canvas: CGSize, maxEdge: Int) throws -> GeometryCapture {
        guard let size = size(canvas: canvas, maxEdge: maxEdge) else {
            throw OffscreenRenderError.invalidSize(width: 0, height: 0, max: max(0, min(longEdge, maxEdge)))
        }
        let image = try still(width: size.width, height: size.height)
        return GeometryCapture(data: try StillImageEncoder.pngData(image), width: image.width, height: image.height)
    }
}
