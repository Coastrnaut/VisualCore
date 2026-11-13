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

    // Feature 202 (R02-F02, FR-R02F02-001/002): further limits and precisions. Each is optional: nil when the query
    // left a GL error or when the report was written before this feature (FR-R02F02-007).
    /// GL_MAX_SAMPLES: the most samples a multisampled renderbuffer may have (reported only; the window is not
    /// multisampled, ADR-0002).
    public var maxSamples: Int?
    /// GL_MAX_DRAW_BUFFERS.
    public var maxDrawBuffers: Int?
    /// GL_MAX_COLOR_ATTACHMENTS.
    public var maxColorAttachments: Int?
    /// GL_MAX_VERTEX_ATTRIBS.
    public var maxVertexAttribs: Int?
    /// GL_MAX_VERTEX_UNIFORM_VECTORS.
    public var maxVertexUniformVectors: Int?
    /// GL_MAX_FRAGMENT_UNIFORM_VECTORS.
    public var maxFragmentUniformVectors: Int?
    /// GL_MAX_TEXTURE_IMAGE_UNITS.
    public var maxTextureImageUnits: Int?
    /// GL_MAX_VARYING_VECTORS.
    public var maxVaryingVectors: Int?
    /// Vertex-shader `highp` float precision.
    public var vertexHighp: ShaderPrecision?
    /// Vertex-shader `mediump` float precision.
    public var vertexMediump: ShaderPrecision?
    /// Fragment-shader `highp` integer precision.
    public var fragmentHighInt: ShaderPrecision?
    /// EGL_VERSION string of the display.
    public var eglVersion: String?
    /// EGL_EXTENSIONS of the display, split at spaces.
    public var eglExtensions: [String]?
    /// GL entry points the EGL loader could not resolve for this context (0 when complete).
    public var missingEntryPoints: Int?
    /// The context generation this report describes (`RenderHost.generation` when it was taken).
    public var generation: Int?

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
        precision(shader: GL_FRAGMENT_SHADER, type)
    }

    /// The precision of `type` in `shader` (GL_VERTEX_SHADER, GL_FRAGMENT_SHADER) in the current context.
    static func precision(shader: Int32, _ type: Int32) -> ShaderPrecision {
        var range: [GLint] = [0, 0]
        var precision: GLint = 0
        vcglGetShaderPrecisionFormat(GLenum(shader), GLenum(type), &range, &precision)
        return ShaderPrecision(rangeMin: Int(range[0]), rangeMax: Int(range[1]), precisionBits: Int(precision))
    }

    /// A limit from `read`, which returns the value and whether the query failed; nil on failure (FR-R02F02-002).
    static func limit(_ read: (Int32) -> (value: Int, failed: Bool), _ name: Int32 = 0) -> Int? {
        let result = read(name)
        return result.failed ? nil : result.value
    }

    /// Reads one integer limit of the current context: clears earlier errors, queries, and reports a failure when the
    /// query left a GL error.
    static func glLimit(_ name: Int32) -> (value: Int, failed: Bool) {
        while vcglGetError() != GLenum(GL_NO_ERROR) {}
        var value: GLint = 0
        vcglGetIntegerv(GLenum(name), &value)
        return (Int(value), vcglGetError() != GLenum(GL_NO_ERROR))
    }

    /// Each limit the floor check reads with its OpenGL ES 3.0 minimum and its value, in report order; a size of 0
    /// (not queried) counts as absent.
    func floorValues() -> [(name: String, minimum: Int, value: Int?)] {
        [("maxTextureSize", 2048, maxTextureSize > 0 ? maxTextureSize : nil),
         ("maxRenderbufferSize", 2048, maxRenderbufferSize > 0 ? maxRenderbufferSize : nil),
         ("maxSamples", 4, maxSamples), ("maxDrawBuffers", 4, maxDrawBuffers),
         ("maxColorAttachments", 4, maxColorAttachments), ("maxVertexAttribs", 16, maxVertexAttribs),
         ("maxVertexUniformVectors", 256, maxVertexUniformVectors),
         ("maxFragmentUniformVectors", 224, maxFragmentUniformVectors),
         ("maxTextureImageUnits", 16, maxTextureImageUnits), ("maxVaryingVectors", 15, maxVaryingVectors)]
    }

    /// Every reported limit below its OpenGL ES 3.0 minimum, in report order; absent values are not findings.
    /// Findings are recorded, not hidden and not raised (simulator values are not device values).
    public func floorFindings() -> [FloorFinding] {
        floorValues().compactMap { floor in
            guard let reported = floor.value, reported < floor.minimum else { return nil }
            return FloorFinding(name: floor.name, minimum: floor.minimum, reported: reported)
        }
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
        caps.maxSamples = limit(glLimit, GL_MAX_SAMPLES)
        caps.maxDrawBuffers = limit(glLimit, GL_MAX_DRAW_BUFFERS)
        caps.maxColorAttachments = limit(glLimit, GL_MAX_COLOR_ATTACHMENTS)
        caps.maxVertexAttribs = limit(glLimit, GL_MAX_VERTEX_ATTRIBS)
        caps.maxVertexUniformVectors = limit(glLimit, GL_MAX_VERTEX_UNIFORM_VECTORS)
        caps.maxFragmentUniformVectors = limit(glLimit, GL_MAX_FRAGMENT_UNIFORM_VECTORS)
        caps.maxTextureImageUnits = limit(glLimit, GL_MAX_TEXTURE_IMAGE_UNITS)
        caps.maxVaryingVectors = limit(glLimit, GL_MAX_VARYING_VECTORS)
        caps.vertexHighp = precision(shader: GL_VERTEX_SHADER, GL_HIGH_FLOAT)
        caps.vertexMediump = precision(shader: GL_VERTEX_SHADER, GL_MEDIUM_FLOAT)
        caps.fragmentHighInt = precision(shader: GL_FRAGMENT_SHADER, GL_HIGH_INT)
        if let v = eglQueryString(display, EGL_VERSION) { caps.eglVersion = String(cString: v) }
        if let e = eglQueryString(display, EGL_EXTENSIONS) {
            caps.eglExtensions = String(cString: e).split(separator: " ").map(String.init)
        }
        return caps
    }
}

/// One limit below its OpenGL ES 3.0 minimum (feature 202, FR-R02F02-005).
public struct FloorFinding: Sendable, Equatable, Codable {
    /// The report property, such as `maxDrawBuffers`.
    public var name: String
    /// The OpenGL ES 3.0 minimum.
    public var minimum: Int
    /// The value the renderer reported.
    public var reported: Int

    /// Creates a finding.
    public init(name: String, minimum: Int, reported: Int) {
        self.name = name; self.minimum = minimum; self.reported = reported
    }
}
