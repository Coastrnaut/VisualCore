// RendererRecord — feature 202 (R02-F02) T-R02F02-009 (FR-R02F02-006, FR-R02F02-007; clarification 1;
// specs/202-visualcore-public-api-compatibility-and-renderer-capability-probing/data-model.md). The renderer's report
// as an evidence record carries it in `environment.renderer`: a pure value type, so the pure package needs no
// dependency on the rendering package. Every field is optional, keys are snake_case and unknown keys are ignored, so
// a record written by an older or newer app still decodes.
import Foundation

/// What the renderer reported for a run, as written to `environment.renderer` of an evidence record.
public struct RendererRecord: Sendable, Equatable, Codable {
    /// The GL version string.
    public var glVersion: String?
    /// The GLSL version string.
    public var glslVersion: String?
    /// The renderer string.
    public var renderer: String?
    /// The vendor string.
    public var vendor: String?
    /// The EGL version or vendor string.
    public var eglVersion: String?
    /// The maximum texture size in texels.
    public var maxTextureSize: Int?
    /// The maximum number of samples per pixel.
    public var maxSamples: Int?
    /// The maximum number of draw buffers.
    public var maxDrawBuffers: Int?
    /// The maximum number of colour attachments.
    public var maxColorAttachments: Int?
    /// The number of GL entry points that could not be resolved.
    public var missingEntryPoints: Int?
    /// The context generation the report belongs to.
    public var generation: Int?
    /// The capability floor findings, one text per value below its minimum; empty when the floor holds.
    public var floorFindings: [String]?

    enum CodingKeys: String, CodingKey {
        case glVersion = "gl_version"
        case glslVersion = "glsl_version"
        case renderer, vendor
        case eglVersion = "egl_version"
        case maxTextureSize = "max_texture_size"
        case maxSamples = "max_samples"
        case maxDrawBuffers = "max_draw_buffers"
        case maxColorAttachments = "max_color_attachments"
        case missingEntryPoints = "missing_entry_points"
        case generation
        case floorFindings = "floor_findings"
    }

    /// Creates a record; every field defaults to absent.
    public init(glVersion: String? = nil, glslVersion: String? = nil, renderer: String? = nil, vendor: String? = nil,
                eglVersion: String? = nil, maxTextureSize: Int? = nil, maxSamples: Int? = nil,
                maxDrawBuffers: Int? = nil, maxColorAttachments: Int? = nil, missingEntryPoints: Int? = nil,
                generation: Int? = nil, floorFindings: [String]? = nil) {
        self.glVersion = glVersion
        self.glslVersion = glslVersion
        self.renderer = renderer
        self.vendor = vendor
        self.eglVersion = eglVersion
        self.maxTextureSize = maxTextureSize
        self.maxSamples = maxSamples
        self.maxDrawBuffers = maxDrawBuffers
        self.maxColorAttachments = maxColorAttachments
        self.missingEntryPoints = missingEntryPoints
        self.generation = generation
        self.floorFindings = floorFindings
    }
}
