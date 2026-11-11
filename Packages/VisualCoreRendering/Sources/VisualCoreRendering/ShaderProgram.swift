// ShaderProgram.swift — a linked GLSL ES 3.00 program with its active-uniform table
// (feature 004 T-F311; FR-F304, FR-F305, FR-F307). Created only through ResourceRegistry.program.
import CVisualCoreGL
import VisualCoreShaderSource

/// Shader failures from source expansion, compilation or linking.
public enum ShaderError: Error, Equatable, Sendable {
    /// Rejected before any GPU work (size, depth, cycle, unknown include, version).
    case source(ShaderSourceError)
    case compile([ShaderDiagnostic])
    case link([ShaderDiagnostic])
}

/// A linked GLSL ES 3.00 program with its active-uniform table, created only by ResourceRegistry.program; stale after a context recreation.
@MainActor
public final class ShaderProgram {
    /// An active uniform as reported by glGetActiveUniform.
    public struct Uniform: Sendable, Equatable {
        /// Uniform location.
        public let location: GLint
        /// GL type enum (for example GL_FLOAT_VEC4).
        public let type: GLenum
        /// Array size (1 for non-arrays).
        public let size: GLint
    }

    /// GL program name.
    public let name: GLuint
    /// Context generation that created the program.
    public let generation: Int
    /// Lowercase SHA-256 hex of the expanded vertex and fragment sources; the registry cache key.
    public let cacheKey: String
    /// Active uniforms by name.
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

    // MARK: Validated uniforms (FR-F307). Call after use(); mismatches are warned once and not applied.

    /// Sets a float uniform; call after `use()`; a missing or mistyped uniform is warned once and not applied.
    public func set(_ name: String, _ v: Float) { apply(name, [GL_FLOAT]) { vcglUniform1f($0, v) } }
    /// Sets a vec2 uniform; call after `use()`; mismatches are warned once and not applied.
    public func set(_ name: String, _ v: SIMD2<Float>) { apply(name, [GL_FLOAT_VEC2]) { vcglUniform2f($0, v.x, v.y) } }
    /// Sets a vec3 uniform; call after `use()`; mismatches are warned once and not applied.
    public func set(_ name: String, _ v: SIMD3<Float>) { apply(name, [GL_FLOAT_VEC3]) { vcglUniform3f($0, v.x, v.y, v.z) } }
    /// Sets a vec4 uniform; call after `use()`; mismatches are warned once and not applied.
    public func set(_ name: String, _ v: SIMD4<Float>) { apply(name, [GL_FLOAT_VEC4]) { vcglUniform4f($0, v.x, v.y, v.z, v.w) } }
    /// Integers and sampler units.
    public func set(_ name: String, _ v: Int32) {
        apply(name, [GL_INT, GL_BOOL, GL_SAMPLER_2D, GL_SAMPLER_3D, GL_SAMPLER_CUBE]) { vcglUniform1i($0, v) }
    }
    /// A column-major 4×4 matrix (16 floats).
    public func set(_ name: String, matrix4 m: [Float]) {
        guard m.count == 16 else { _ = registry?.warn("\(cacheKey.prefix(8)):\(name) matrix needs 16 floats"); return }
        apply(name, [GL_FLOAT_MAT4]) { location in m.withUnsafeBufferPointer { vcglUniformMatrix4fv(location, 1, GLboolean(GL_FALSE), $0.baseAddress) } }
    }

    private func apply(_ name: String, _ accepted: [Int32], _ write: (GLint) -> Void) {
        guard !released, let registry, registry.accept(generation: generation) else { return }
        guard let uniform = uniforms[name] else {
            _ = registry.warn("\(cacheKey.prefix(8)):\(name) is not an active uniform")
            return
        }
        guard accepted.contains(where: { GLenum($0) == uniform.type }) else {
            _ = registry.warn("\(cacheKey.prefix(8)):\(name) type mismatch (declared 0x\(String(uniform.type, radix: 16)))")
            return
        }
        write(uniform.location)
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
