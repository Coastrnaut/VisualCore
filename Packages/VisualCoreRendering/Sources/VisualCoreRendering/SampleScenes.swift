// SampleScenes.swift — minimal independent scenes proving the host renders (feature 003 T-F210; FR-F212).
// The general shader service arrives in F03 (feature 004); this file compiles one tiny ES 3.00 program
// directly through the generated GL table.
import CVisualCoreGL

/// Clears the window to one color.
@MainActor
public final class ClearColorScene: RenderScene {
    public var red: Float, green: Float, blue: Float

    public init(red: Float = 0, green: Float = 0, blue: Float = 0) {
        self.red = red; self.green = green; self.blue = blue
    }

    public func setup(_ context: RenderContext) throws {}
    public func resize(_ context: RenderContext) {}
    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(red, green, blue, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
    public func teardown(_ context: RenderContext) {}
}

/// A full-screen triangle shaded red (left) to blue (right).
@MainActor
public final class GradientQuadScene: RenderScene {
    private var program: GLuint = 0

    public init() {}

    static let vertexSource = """
    #version 300 es
    out vec2 uv;
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
        uv = p;
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """
    static let fragmentSource = """
    #version 300 es
    precision mediump float;
    in vec2 uv;
    out vec4 color;
    void main() { color = vec4(mix(vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), clamp(uv.x, 0.0, 1.0)), 1.0); }
    """

    public func setup(_ context: RenderContext) throws {
        program = try MinimalProgram.link(vertex: Self.vertexSource, fragment: Self.fragmentSource)
    }

    public func resize(_ context: RenderContext) {}

    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(0, 0, 0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        vcglUseProgram(program)
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    }

    public func teardown(_ context: RenderContext) {
        if program != 0 { vcglDeleteProgram(program) }
        program = 0
    }
}

/// Compiles and links one program; throws the info log on failure (F03 replaces this with the shader service).
enum MinimalProgram {
    struct Failure: Error, CustomStringConvertible { let description: String }

    static func link(vertex: String, fragment: String) throws -> GLuint {
        let vs = try compile(GLenum(GL_VERTEX_SHADER), vertex)
        let fs = try compile(GLenum(GL_FRAGMENT_SHADER), fragment)
        defer { vcglDeleteShader(vs); vcglDeleteShader(fs) }
        let program = vcglCreateProgram()
        vcglAttachShader(program, vs)
        vcglAttachShader(program, fs)
        vcglLinkProgram(program)
        var ok: GLint = 0
        vcglGetProgramiv(program, GLenum(GL_LINK_STATUS), &ok)
        guard ok == GL_TRUE else {
            let log = infoLog { vcglGetProgramInfoLog(program, $0, $1, $2) }
            vcglDeleteProgram(program)
            throw Failure(description: "link: " + log)
        }
        return program
    }

    private static func compile(_ type: GLenum, _ source: String) throws -> GLuint {
        let shader = vcglCreateShader(type)
        source.withCString { cstr in
            var pointer: UnsafePointer<GLchar>? = cstr
            vcglShaderSource(shader, 1, &pointer, nil)
        }
        vcglCompileShader(shader)
        var ok: GLint = 0
        vcglGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &ok)
        guard ok == GL_TRUE else {
            let log = infoLog { vcglGetShaderInfoLog(shader, $0, $1, $2) }
            vcglDeleteShader(shader)
            throw Failure(description: "compile: " + log)
        }
        return shader
    }

    private static func infoLog(_ get: (GLsizei, UnsafeMutablePointer<GLsizei>, UnsafeMutablePointer<GLchar>) -> Void) -> String {
        var buffer = [GLchar](repeating: 0, count: 2048)
        var length: GLsizei = 0
        buffer.withUnsafeMutableBufferPointer { get(GLsizei($0.count), &length, $0.baseAddress!) }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
