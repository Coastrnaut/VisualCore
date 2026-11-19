// ShaderProgram.swift — a linked GLSL ES 3.00 program with its active-uniform table
// (feature 004 T-F311; FR-F304, FR-F305, FR-F307). Created only through ResourceRegistry.program.
// Feature 206 T-R02F06-007 (FR-R02F06-005…008, research R6, R7): info logs sized by GL_INFO_LOG_LENGTH (capped at
// 65,536 bytes), compile warnings kept on success, link diagnostics labelled `<vertexName>+<fragmentName>`,
// `ShaderError.reasonCode`, reflected `UniformType`s and `check(_:)` against a declared `UniformLayout`.
import CVisualCoreGL
import VisualCoreShaderSource

/// Shader failures from source expansion, compilation or linking.
public enum ShaderError: Error, Equatable, Sendable {
    /// Rejected before any GPU work (size, depth, cycle, unknown include, version).
    case source(ShaderSourceError)
    case compile([ShaderDiagnostic])
    case link([ShaderDiagnostic])
}

extension ShaderError {
    /// The stable reason code (feature 206, clarification Q4): a source error keeps its own mapping, a compile failure
    /// is `shader.compile` and a link failure `shader.link`.
    public var reasonCode: ShaderReasonCode {
        switch self {
        case .source(let error): error.reasonCode
        case .compile: .compile
        case .link: .link
        }
    }
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
        /// The GL type as a `UniformType` (feature 206, research R7); unmapped codes are `.other(code)`.
        public var uniformType: UniformType { ShaderProgram.uniformType(glType: type) }
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

    /// Compiler and linker warnings reported while this program was built successfully, mapped to source file and
    /// line like errors (feature 206, FR-R02F06-005); empty when the driver reports none.
    public private(set) var warnings: [ShaderDiagnostic]

    /// The raw info log of the most recent compile/link failure (tests pin its format).
    public internal(set) static var lastFailureLog = ""

    /// Largest info log read from the driver, in bytes (feature 206, research R6); longer logs are truncated.
    public static let maxInfoLogBytes = 65_536

    init(name: GLuint, generation: Int, cacheKey: String, registry: ResourceRegistry, warnings: [ShaderDiagnostic] = []) {
        self.name = name
        self.generation = generation
        self.cacheKey = cacheKey
        self.registry = registry
        self.warnings = warnings
        uniforms = Self.activeUniforms(name)
    }

    // MARK: Uniform layout (feature 206, FR-R02F06-006)

    /// Active uniforms by name with their `UniformType` (array names without `[0]`).
    public var activeUniformTypes: [String: UniformType] { uniforms.mapValues(\.uniformType) }

    /// Checks the active uniforms against a declared layout: undeclared and mistyped uniforms are errors, declared
    /// uniforms the compiler removed are reported as unused.
    public func check(_ layout: UniformLayout) -> UniformLayoutReport { layout.check(active: activeUniformTypes) }

    /// Maps a GL uniform type enum to `UniformType` (research R7); anything else is `.other(code)`.
    public nonisolated static func uniformType(glType: GLenum) -> UniformType {
        switch Int32(bitPattern: glType) {
        case GL_FLOAT: .float
        case GL_FLOAT_VEC2: .vec2
        case GL_FLOAT_VEC3: .vec3
        case GL_FLOAT_VEC4: .vec4
        case GL_INT: .int
        case GL_INT_VEC2: .ivec2
        case GL_INT_VEC3: .ivec3
        case GL_INT_VEC4: .ivec4
        case GL_BOOL: .bool
        case GL_FLOAT_MAT3: .mat3
        case GL_FLOAT_MAT4: .mat4
        case GL_SAMPLER_2D: .sampler2D
        case GL_SAMPLER_3D: .sampler3D
        case GL_SAMPLER_CUBE: .samplerCube
        default: .other(UInt32(glType))
        }
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
    /// Sets the first `min(values.count, declared size)` elements of a `vec3` array uniform (for example `u_palette[8]`);
    /// call after `use()`; mismatches are warned once and not applied.
    public func set(_ name: String, vec3Array values: [SIMD3<Float>]) {
        let count = min(values.count, Int(uniforms[name]?.size ?? 0))
        guard count > 0 else { apply(name, [GL_FLOAT_VEC3]) { _ in }; return }
        let flat = values.prefix(count).flatMap { [$0.x, $0.y, $0.z] }
        apply(name, [GL_FLOAT_VEC3]) { location in flat.withUnsafeBufferPointer { vcglUniform3fv(location, GLsizei(count), $0.baseAddress) } }
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

    /// Compiles one stage. Returns the shader, its errors (empty on success) and, on success, the warnings of its
    /// info log (feature 206: the log is read after a successful compile too; every line of it counts as a warning).
    static func compileShader(_ type: GLenum, _ source: ExpandedShader, stage: ShaderStage)
        -> (shader: GLuint, errors: [ShaderDiagnostic], warnings: [ShaderDiagnostic]) {
        let shader = vcglCreateShader(type)
        source.text.withCString { cstr in
            var pointer: UnsafePointer<GLchar>? = cstr
            vcglShaderSource(shader, 1, &pointer, nil)
        }
        vcglCompileShader(shader)
        var ok: GLint = 0
        vcglGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &ok)
        var length: GLint = 0
        vcglGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &length)
        let log = infoLog(length: length) { vcglGetShaderInfoLog(shader, $0, $1, $2) }
        if ok == GL_TRUE {
            return (shader, [], asWarnings(InfoLogParser.parse(log, stage: stage, map: source)))
        }
        lastFailureLog = log
        var diagnostics = InfoLogParser.parse(log, stage: stage, map: source)
        if diagnostics.isEmpty {
            diagnostics = [ShaderDiagnostic(file: "unknown", line: 0, stage: stage, severity: .error, message: "compile failed")]
        }
        return (shader, diagnostics, [])
    }

    /// The link result: errors (empty when linked) and, when linked, warnings; diagnostics without a mapped file are
    /// labelled `label` (`<vertexName>+<fragmentName>`, feature 206).
    static func linkLog(_ program: GLuint, label: String = "unknown") -> (errors: [ShaderDiagnostic], warnings: [ShaderDiagnostic]) {
        var ok: GLint = 0
        vcglGetProgramiv(program, GLenum(GL_LINK_STATUS), &ok)
        var length: GLint = 0
        vcglGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &length)
        let log = infoLog(length: length) { vcglGetProgramInfoLog(program, $0, $1, $2) }
        let parsed = InfoLogParser.parse(log, stage: .link, map: nil).map { relabel($0, label) }
        if ok == GL_TRUE { return ([], asWarnings(parsed)) }
        lastFailureLog = log
        let errors = parsed.isEmpty
            ? [ShaderDiagnostic(file: label, line: 0, stage: .link, severity: .error, message: "link failed")] : parsed
        return (errors, [])
    }

    private static func relabel(_ d: ShaderDiagnostic, _ label: String) -> ShaderDiagnostic {
        d.file == "unknown" ? ShaderDiagnostic(file: label, line: d.line, stage: d.stage, severity: d.severity, message: d.message) : d
    }

    /// Lines of a successful compile or link log: a line the parser could not structure is kept as one warning.
    private static func asWarnings(_ diagnostics: [ShaderDiagnostic]) -> [ShaderDiagnostic] {
        diagnostics.map {
            $0.severity == .warning ? $0
                : ShaderDiagnostic(file: $0.file, line: $0.line, stage: $0.stage, severity: .warning, message: $0.message)
        }
    }

    /// Reads an info log of `length` bytes (GL_INFO_LOG_LENGTH, including the terminator), capped at `maxInfoLogBytes`.
    private static func infoLog(length: GLint,
                                _ get: (GLsizei, UnsafeMutablePointer<GLsizei>, UnsafeMutablePointer<GLchar>) -> Void) -> String {
        guard length > 1 else { return "" }
        var buffer = [GLchar](repeating: 0, count: min(Int(length), maxInfoLogBytes))
        var written: GLsizei = 0
        buffer.withUnsafeMutableBufferPointer { get(GLsizei($0.count), &written, $0.baseAddress!) }
        return String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
