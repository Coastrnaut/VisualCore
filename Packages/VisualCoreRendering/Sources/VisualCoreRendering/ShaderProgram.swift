// ShaderProgram.swift — a linked GLSL ES 3.00 program with its active-uniform table
// (feature 004 T-F311; FR-F304, FR-F305, FR-F307). Created only through ResourceRegistry.program.
import CVisualCoreGL
import VisualCoreShaderSource

public enum ShaderError: Error, Equatable, Sendable {
    /// Rejected before any GPU work (size, depth, cycle, unknown include, version).
    case source(ShaderSourceError)
    case compile([ShaderDiagnostic])
    case link([ShaderDiagnostic])
}

@MainActor
public final class ShaderProgram {
    public struct Uniform: Sendable, Equatable {
        public let location: GLint
        public let type: GLenum
        public let size: GLint
    }

    public let name: GLuint
    public let generation: Int
    public let cacheKey: String
    public let uniforms: [String: Uniform]
    weak var registry: ResourceRegistry?
    var released = false

    /// The raw info log of the most recent compile/link failure (tests pin its format).
    public internal(set) static var lastFailureLog = ""

    init(name: GLuint, generation: Int, cacheKey: String, registry: ResourceRegistry) {
        self.name = name
        self.generation = generation
        self.cacheKey = cacheKey
        self.registry = registry
        uniforms = Self.activeUniforms(name)
    }

    /// Binds the program. Ignored (and counted as stale) after a context recreation.
    public func use() {
        guard let registry, registry.accept(generation: generation), !released else { return }
        vcglUseProgram(name)
    }

    private static func activeUniforms(_ program: GLuint) -> [String: Uniform] {
        var count: GLint = 0
        vcglGetProgramiv(program, GLenum(GL_ACTIVE_UNIFORMS), &count)
        var table: [String: Uniform] = [:]
        var buffer = [GLchar](repeating: 0, count: 256)
        for i in 0..<max(0, count) {
            var length: GLsizei = 0, size: GLint = 0, type: GLenum = 0
            vcglGetActiveUniform(program, GLuint(i), GLsizei(buffer.count), &length, &size, &type, &buffer)
            var uniformName = String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if uniformName.hasSuffix("[0]") { uniformName.removeLast(3) }
            let location = uniformName.withCString { vcglGetUniformLocation(program, $0) }
            table[uniformName] = Uniform(location: location, type: type, size: size)
        }
        return table
    }

    // MARK: Compilation (used by ResourceRegistry)

    static func compileShader(_ type: GLenum, _ source: ExpandedShader, stage: ShaderStage) -> (GLuint, [ShaderDiagnostic]) {
        let shader = vcglCreateShader(type)
        source.text.withCString { cstr in
            var pointer: UnsafePointer<GLchar>? = cstr
            vcglShaderSource(shader, 1, &pointer, nil)
        }
        vcglCompileShader(shader)
        var ok: GLint = 0
        vcglGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &ok)
        if ok == GL_TRUE { return (shader, []) }
        let log = infoLog { vcglGetShaderInfoLog(shader, $0, $1, $2) }
        lastFailureLog = log
        var diagnostics = InfoLogParser.parse(log, stage: stage, map: source)
        if diagnostics.isEmpty {
            diagnostics = [ShaderDiagnostic(file: "unknown", line: 0, stage: stage, severity: .error, message: "compile failed")]
        }
        return (shader, diagnostics)
    }

    static func linkLog(_ program: GLuint) -> [ShaderDiagnostic] {
        var ok: GLint = 0
        vcglGetProgramiv(program, GLenum(GL_LINK_STATUS), &ok)
        if ok == GL_TRUE { return [] }
        let log = infoLog { vcglGetProgramInfoLog(program, $0, $1, $2) }
        lastFailureLog = log
        let parsed = InfoLogParser.parse(log, stage: .link, map: nil)
        return parsed.isEmpty ? [ShaderDiagnostic(file: "unknown", line: 0, stage: .link, severity: .error, message: "link failed")] : parsed
    }

    private static func infoLog(_ get: (GLsizei, UnsafeMutablePointer<GLsizei>, UnsafeMutablePointer<GLchar>) -> Void) -> String {
        var buffer = [GLchar](repeating: 0, count: 4096)
        var length: GLsizei = 0
        buffer.withUnsafeMutableBufferPointer { get(GLsizei($0.count), &length, $0.baseAddress!) }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
