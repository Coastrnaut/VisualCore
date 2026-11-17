// WallpaperExportFile — feature 141 (A19-P04) T-A19-403 (FR-A19-401; clarification Q1; contracts/save.md "Share").
// A written export handed to the system's share sheet: a `Transferable` file whose `FileRepresentation` carries the
// content type of the plan's format (PNG `.png`, JPEG `.jpeg`, HEIC `.heic`; each representation is offered only
// for its own format) and sends the written file itself. The file is named "<Scene> <Device> <W>x<H>.<ext>", for
// example "Ink Flow iPhone 16 Pro 1206x2622.png", in the export folder, so the share sheet shows that name. The
// controls show the share link only while the written file exists (`item(for:)`). The person chooses where the
// picture goes from the share sheet; this file asks for no library access and makes no platform call.
import CoreTransferable
import Foundation
import LivingWallpapersCore
import UniformTypeIdentifiers

/// A written export offered to the share sheet with its format's content type (see the file header).
public struct WallpaperExportFile: Transferable, Equatable, Sendable {
    /// The written file.
    public let url: URL
    /// The file's format.
    public let format: ExportFormat

    /// A share item for the file at `url` in `format`.
    public init(url: URL, format: ExportFormat) {
        self.url = url
        self.format = format
    }

    /// The content type of `format`: `.png`, `.jpeg` or `.heic`.
    public static func contentType(_ format: ExportFormat) -> UTType {
        switch format {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        }
    }

    /// The content type of this file's format.
    public var contentType: UTType { Self.contentType(format) }

    /// The file name "<Scene> <Device> <W>x<H>.<ext>", for example "Ink Flow iPhone 16 Pro 1206x2622.png"; a `/` or
    /// `:` in a name becomes `-` so the name stays one path component.
    public static func fileName(scene: String, device: String, width: Int, height: Int,
                                format: ExportFormat) -> String {
        let name = "\(scene) \(device) \(width)x\(height).\(StillExport.fileExtension(format))"
        return name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    /// The file name of `plan` made from `project`: the scene's and the template's display names (their ids when
    /// the catalog has no such entry) with the plan's size and format.
    public static func fileName(project: WallpaperProject, plan: ExportPlan) -> String {
        let scene = SceneCatalog.scene(id: project.scene)?.name ?? project.scene
        let device = CanvasTemplates.template(id: project.template)?.device ?? project.template
        return fileName(scene: scene, device: device, width: plan.width, height: plan.height, format: plan.format)
    }

    /// The share item of a written `output`, or nil when there is no output or its file no longer exists.
    @MainActor
    static func item(for output: StillExport.Output?) -> WallpaperExportFile? {
        guard let output, FileManager.default.fileExists(atPath: output.url.path) else { return nil }
        return WallpaperExportFile(url: output.url, format: output.plan.format)
    }

    /// The written file, sent as itself with the content type of its format.
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { SentTransferredFile($0.url) }
            .exportingCondition { $0.format == .png }
        FileRepresentation(exportedContentType: .jpeg) { SentTransferredFile($0.url) }
            .exportingCondition { $0.format == .jpeg }
        FileRepresentation(exportedContentType: .heic) { SentTransferredFile($0.url) }
            .exportingCondition { $0.format == .heic }
    }
}
