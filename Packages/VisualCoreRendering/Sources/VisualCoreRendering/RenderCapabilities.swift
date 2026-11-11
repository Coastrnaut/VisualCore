// RenderCapabilities.swift — what the ANGLE context reports (feature 003; FR-F210).
import CVisualCoreEGL
import CVisualCoreGL

/// What the current ANGLE ES context reports, captured once per context generation.
public struct RenderCapabilities: Sendable, Equatable, Codable {
    /// GL_VERSION string.
    public var glVersion = ""
    /// GL_SHADING_LANGUAGE_VERSION string.
    public var glslVersion = ""
    /// GL_RENDERER string.
    public var renderer = ""
    /// GL_VENDOR string.
    public var vendor = ""
    /// EGL_VENDOR string of the display.
    public var eglVendor = ""
    /// Extension names reported via glGetStringi.
    public var extensions: [String] = []
    /// GL_MAX_TEXTURE_SIZE in pixels.
    public var maxTextureSize = 0
    /// GL_MAX_VIEWPORT_DIMS in pixels.
    public var maxViewport = Size(width: 0, height: 0)
    /// GL_MAX_RENDERBUFFER_SIZE in pixels (feature 015 T-A01-402).
    public var maxRenderbufferSize = 0

    /// A width and height in pixels.
    public struct Size: Sendable, Equatable, Codable {
        /// Width in pixels.
        public var width: Int
        /// Height in pixels.
        public var height: Int
    }

    /// True when the extension list includes `GL_EXT_color_buffer_half_float` or `GL_EXT_color_buffer_float`,
    /// the extensions that make RGBA16F color-renderable (feature 019; see FloatRenderSupport for the probe).
    public var reportsColorBufferHalfFloat: Bool { extensions.contains(where: FloatRenderSupport.isFloatColorExtension) }

    /// Extension names of the current context.
    static func currentExtensions() -> [String] {
        var count: GLint = 0
        vcglGetIntegerv(GLenum(GL_NUM_EXTENSIONS), &count)
        return (0..<max(0, Int(count))).compactMap { i in
            vcglGetStringi(GLenum(GL_EXTENSIONS), GLuint(i)).map { String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)) }
        }
    }

    /// Creates an empty report (no context queried).
    public init() {}

    /// Queries the current context. Call with a context current.
    static func query(display: EGLDisplay) -> RenderCapabilities {
        func string(_ name: Int32) -> String {
            guard let p = vcglGetString(GLenum(name)) else { return "" }
            return String(cString: UnsafeRawPointer(p).assumingMemoryBound(to: CChar.self))
        }
        var caps = RenderCapabilities()
        caps.glVersion = string(GL_VERSION)
        caps.glslVersion = string(GL_SHADING_LANGUAGE_VERSION)
        caps.renderer = string(GL_RENDERER)
        caps.vendor = string(GL_VENDOR)
        if let v = eglQueryString(display, EGL_VENDOR) { caps.eglVendor = String(cString: v) }
        caps.extensions = currentExtensions()
        var maxTexture: GLint = 0
        vcglGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &maxTexture)
        caps.maxTextureSize = Int(maxTexture)
        var dims: [GLint] = [0, 0]
        vcglGetIntegerv(GLenum(GL_MAX_VIEWPORT_DIMS), &dims)
        caps.maxViewport = Size(width: Int(dims[0]), height: Int(dims[1]))
        var maxRenderbuffer: GLint = 0
        vcglGetIntegerv(GLenum(GL_MAX_RENDERBUFFER_SIZE), &maxRenderbuffer)
        caps.maxRenderbufferSize = Int(maxRenderbuffer)
        return caps
    }
}
