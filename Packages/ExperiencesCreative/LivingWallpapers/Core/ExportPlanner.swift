// ExportPlanner — feature 138 (A19-P01) T-A19-107 (FR-A19-104; clarification Q3). Turns a project into an exact pixel
// size and colour profile before anything is allocated: a template that fits is planned at exactly its size (odd
// edges kept); one that does not is refused with the ExportGeometry size offered at its aspect (even edges).
import Foundation
import VisualCoreScenes

/// The file format of an export: PNG, JPEG or HEIC.
public enum ExportFormat: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// An opaque PNG tagged sRGB.
    case png
    /// A JPEG still (feature 139, A19-P02).
    case jpeg
    /// A HEIC still (feature 139, A19-P02).
    case heic
}

/// A planned export: the format, the exact pixel size, the colour profile and whether the size is a fallback.
public struct ExportPlan: Equatable, Hashable, Sendable {
    /// The file format.
    public let format: ExportFormat
    /// The width in pixels.
    public let width: Int
    /// The height in pixels.
    public let height: Int
    /// The colour profile the file is tagged with.
    public let profile: ColorProfile
    /// True when the size is the offered fallback rather than the template's exact size.
    public let fallback: Bool

    /// Creates a plan.
    public init(format: ExportFormat, width: Int, height: Int, profile: ColorProfile = .sRGB, fallback: Bool) {
        self.format = format
        self.width = width
        self.height = height
        self.profile = profile
        self.fallback = fallback
    }

    /// The planned size.
    public var size: ExportSize { ExportSize(width: width, height: height) }
}

/// Why an export could not be planned at the template's exact size.
public enum ExportRefusal: Error, Equatable, Sendable {
    /// The device reported no usable edge limit (maxEdge ≤ 0).
    case noLimit
    /// The template's size does not fit the limits; `offered` is the ExportGeometry size at the template's aspect.
    case doesNotFit(template: String, offered: ExportSize)
    /// The project names a template that ``CanvasTemplates`` does not have; the value is the id.
    case unknownTemplate(String)

    /// The stable code: `no-limit`, `does-not-fit` or `unknown-template`.
    public var code: String {
        switch self {
        case .noLimit: return "no-limit"
        case .doesNotFit: return "does-not-fit"
        case .unknownTemplate: return "unknown-template"
        }
    }

    /// One sentence describing the refusal.
    public var sentence: String {
        switch self {
        case .noLimit:
            return "This device reported no usable image size limit, so nothing can be exported."
        case let .doesNotFit(template, offered):
            return "The template \"\(template)\" is larger than this device can export; "
                + "\(offered.width)×\(offered.height) is offered instead."
        case .unknownTemplate(let id):
            return "The canvas template \"\(id)\" is unknown."
        }
    }

    /// The fallback plan at the offered size (marked as a fallback), or nil when nothing is offered.
    public func offeredPlan(format: ExportFormat) -> ExportPlan? {
        guard case let .doesNotFit(_, offered) = self else { return nil }
        return ExportPlan(format: format, width: offered.width, height: offered.height, fallback: true)
    }
}

/// Plans exports from a project and the device's limits. Pure arithmetic; nothing is allocated.
public enum ExportPlanner {
    /// Plans the export of `project`.
    ///
    /// - Returns `.failure(.noLimit)` when `maxEdge ≤ 0`.
    /// - Returns the template's exact oriented size when both edges are ≤ `maxEdge`, the long edge is
    ///   ≤ ``ExportGeometry/hardMaxEdge`` and the pixel count is ≤ `maxPixels`.
    /// - Otherwise returns `.failure(.doesNotFit(template:offered:))`, offering
    ///   `ExportGeometry(maxEdge:maxPixels:).size(longEdge:aspect:)` at the template's own aspect.
    public static func plan(project: WallpaperProject, maxEdge: Int,
                            maxPixels: Int = ExportGeometry.defaultMaxPixels) -> Result<ExportPlan, ExportRefusal> {
        guard maxEdge > 0 else { return .failure(.noLimit) }
        guard let template = CanvasTemplates.template(id: project.template) else {
            return .failure(.unknownTemplate(project.template))
        }
        let size = template.size(for: project.orientation)
        let long = size.longEdge
        if size.width <= maxEdge, size.height <= maxEdge, long <= ExportGeometry.hardMaxEdge,
           size.pixelCount <= maxPixels {
            return .success(ExportPlan(format: project.format, width: size.width, height: size.height, fallback: false))
        }
        guard let aspect = ExportAspect(id: template.id, title: template.device, width: size.width, height: size.height)
        else { return .failure(.unknownTemplate(template.id)) }
        let offered = ExportGeometry(maxEdge: maxEdge, maxPixels: maxPixels).size(longEdge: long, aspect: aspect)
        return .failure(.doesNotFit(template: template.id, offered: offered))
    }
}
