// RenderCapabilities.swift — what the ANGLE context reports (feature 003; FR-F210).
import CVisualCoreEGL
import CVisualCoreGL

public struct RenderCapabilities: Sendable, Equatable, Codable {
    public var glVersion = ""
    public var glslVersion = ""
    public var renderer = ""
    public var vendor = ""
    public var eglVendor = ""
    public var extensions: [String] = []
    public var maxTextureSize = 0
    public var maxViewport = Size(width: 0, height: 0)

    public struct Size: Sendable, Equatable, Codable {
        public var width: Int
        public var height: Int
    }

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
        var count: GLint = 0
        vcglGetIntegerv(GLenum(GL_NUM_EXTENSIONS), &count)
        for i in 0..<max(0, Int(count)) {
            if let p = vcglGetStringi(GLenum(GL_EXTENSIONS), GLuint(i)) {
                caps.extensions.append(String(cString: UnsafeRawPointer(p).assumingMemoryBound(to: CChar.self)))
            }
        }
        var maxTexture: GLint = 0
        vcglGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &maxTexture)
        caps.maxTextureSize = Int(maxTexture)
        var dims: [GLint] = [0, 0]
        vcglGetIntegerv(GLenum(GL_MAX_VIEWPORT_DIMS), &dims)
        caps.maxViewport = Size(width: Int(dims[0]), height: Int(dims[1]))
        return caps
    }
}
