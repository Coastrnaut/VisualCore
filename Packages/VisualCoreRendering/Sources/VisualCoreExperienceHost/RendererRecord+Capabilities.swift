// RendererRecord+Capabilities.swift — the renderer's report as the pure evidence record (feature 202, R02-F02
// T-R02F02-010; FR-R02F02-006, clarification 1). The pure package cannot depend on the rendering package (rule R2), so
// the mapping lives here, where both are visible.
import VisualCoreExperience
import VisualCoreRendering

extension RendererRecord {
    /// The values of `capabilities` that the evidence keeps, with the names of the limits below their OpenGL ES 3.0
    /// minimum as `floor_findings` (empty when none).
    public init(_ capabilities: RenderCapabilities) {
        self.init(glVersion: capabilities.glVersion, glslVersion: capabilities.glslVersion,
                  renderer: capabilities.renderer, vendor: capabilities.vendor, eglVersion: capabilities.eglVersion,
                  maxTextureSize: capabilities.maxTextureSize, maxSamples: capabilities.maxSamples,
                  maxDrawBuffers: capabilities.maxDrawBuffers, maxColorAttachments: capabilities.maxColorAttachments,
                  missingEntryPoints: capabilities.missingEntryPoints, generation: capabilities.generation,
                  floorFindings: capabilities.floorFindings().map { "\($0.name) \($0.reported) < \($0.minimum)" })
    }
}
