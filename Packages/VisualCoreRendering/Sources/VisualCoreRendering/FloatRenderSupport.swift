// FloatRenderSupport.swift — can this context render into half-float targets? (feature 019 T-A02-103; gap
// G-FLOATRT; spec clarification 4; research R3). ES 3.0 does not guarantee float color buffers: the extensions do,
// and a small probe confirms the extension really works. Simulations (fluid, reaction–diffusion, accumulation
// buffers) use `storageFormat` to pick RGBA16F, or the documented RGBA8 fallback.
import CVisualCoreGL

/// Half-float render-target support of one context generation.
public struct FloatRenderSupport: Sendable, Equatable {
    /// The context lists `GL_EXT_color_buffer_half_float` or `GL_EXT_color_buffer_float`.
    public let extensionReported: Bool
    /// A 4×4 RGBA16F render target was framebuffer-complete and read back the cleared values as finite floats.
    public let probeComplete: Bool
    /// Both the extension and the probe succeeded.
    public var supported: Bool { extensionReported && probeComplete }

    /// A support value from explicit results (tests, diagnostics).
    public init(extensionReported: Bool, probeComplete: Bool) {
        self.extensionReported = extensionReported
        self.probeComplete = probeComplete
    }

    /// The format a field should use: `.rgba16f` when supported and not forced to fall back, otherwise `.rgba8`.
    public func storageFormat(forceFallback: Bool = false) -> TextureFormat {
        supported && !forceFallback ? .rgba16f : .rgba8
    }

    /// Detects support in the current context (call with it current, on the main thread). The result is cached
    /// per context generation; the probe target is released before returning, so live resources are unchanged.
    @MainActor
    public static func detect(in registry: ResourceRegistry) -> FloatRenderSupport {
        if let cached = registry.floatSupportCache, cached.generation == registry.generation { return cached.value }
        let value = FloatRenderSupport(extensionReported: RenderCapabilities.currentExtensions().contains(where: Self.isFloatColorExtension),
                                       probeComplete: probe(registry))
        registry.floatSupportCache = (registry.generation, value)
        return value
    }

    static func isFloatColorExtension(_ name: String) -> Bool {
        name == "GL_EXT_color_buffer_half_float" || name == "GL_EXT_color_buffer_float"
    }

    @MainActor
    private static func probe(_ registry: ResourceRegistry) -> Bool {
        var previous: GLint = 0
        vcglGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &previous)
        var clear: [GLfloat] = [0, 0, 0, 0]
        vcglGetFloatv(GLenum(GL_COLOR_CLEAR_VALUE), &clear)
        defer {
            vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), GLuint(previous))
            vcglClearColor(clear[0], clear[1], clear[2], clear[3])
        }
        guard let target = try? registry.makeRenderTarget(width: 4, height: 4, format: .rgba16f, label: "vc.float-probe") else {
            _ = vcglGetError()
            return false
        }
        defer { registry.release(target) }
        target.bind()
        let scissor = vcglIsEnabled(GLenum(GL_SCISSOR_TEST)) == GLboolean(GL_TRUE)
        vcglDisable(GLenum(GL_SCISSOR_TEST))
        vcglClearColor(-0.5, 2, 0.25, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        if scissor { vcglEnable(GLenum(GL_SCISSOR_TEST)) }
        let pixels = target.readFloatPixels()
        guard pixels.count == 64 else { return false }
        return pixels.allSatisfy(\.isFinite) && abs(pixels[0] + 0.5) < 1e-3 && abs(pixels[1] - 2) < 1e-3
    }
}
