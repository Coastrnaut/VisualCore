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

    /// Fragment-shader `highp` float precision (feature 027 T-A03-202; G-PRECISION); nil when not queried. Optional so
    /// earlier stored reports still decode.
    public var fragmentHighp: ShaderPrecision?
    /// Fragment-shader `mediump` float precision; nil when not queried.
    public var fragmentMediump: ShaderPrecision?

    /// A float format's range and precision as reported by `glGetShaderPrecisionFormat`: the representable magnitude
    /// is about 2^rangeMin…2^rangeMax and the relative precision 2^−precisionBits (precisionBits is the mantissa
    /// length; 23 for IEEE single precision). All zero means the format is unsupported.
    public struct ShaderPrecision: Sendable, Equatable, Codable {
        /// log2 of the smallest representable magnitude (absolute value of the reported minimum).
        public var rangeMin: Int
        /// log2 of the largest representable magnitude.
        public var rangeMax: Int
        /// Mantissa bits.
        public var precisionBits: Int
        /// True when the format is supported (any non-zero field).
        public var isSupported: Bool { rangeMin != 0 || rangeMax != 0 || precisionBits != 0 }
        /// Creates a report.
        public init(rangeMin: Int, rangeMax: Int, precisionBits: Int) {
            self.rangeMin = rangeMin; self.rangeMax = rangeMax; self.precisionBits = precisionBits
        }
    }

    /// The mantissa bits a fragment shader can rely on: `highp` if supported, else `mediump`, else `fallback`
    /// (10, the GLSL ES minimum for `mediump`).
    public func fragmentMantissaBits(fallback: Int = 10) -> Int {
        if let h = fragmentHighp, h.isSupported, h.precisionBits > 0 { return h.precisionBits }
        if let m = fragmentMediump, m.isSupported, m.precisionBits > 0 { return m.precisionBits }
        return fallback
    }

    /// The fragment precision of `type` (GL_HIGH_FLOAT, GL_MEDIUM_FLOAT) in the current context.
    static func fragmentPrecision(_ type: Int32) -> ShaderPrecision {
        var range: [GLint] = [0, 0]
        var precision: GLint = 0
        vcglGetShaderPrecisionFormat(GLenum(GL_FRAGMENT_SHADER), GLenum(type), &range, &precision)
        return ShaderPrecision(rangeMin: Int(range[0]), rangeMax: Int(range[1]), precisionBits: Int(precision))
    }

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
        caps.fragmentHighp = fragmentPrecision(GL_HIGH_FLOAT)
        caps.fragmentMediump = fragmentPrecision(GL_MEDIUM_FLOAT)
        return caps
    }
}
