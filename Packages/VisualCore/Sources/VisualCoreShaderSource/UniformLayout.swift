// UniformLayout.swift — declared uniform layouts checked against a program's active uniforms (feature 206
// T-R02F06-005; FR-R02F06-006, clarification Q1, research R7). Contract:
// specs/206-shader-domain-specific-parameters-and-gl-es-safe-compilation/contracts/api.md.
//
// Pure: the active uniforms come from the caller (VisualCoreRendering reflects them with `glGetActiveUniform`).

/// The type of a uniform, as GLSL ES 3.00 names it; `other` carries an unmapped GL type code.
public enum UniformType: Equatable, Hashable, Sendable {
    /// `float`.
    case float
    /// `vec2`.
    case vec2
    /// `vec3`.
    case vec3
    /// `vec4`.
    case vec4
    /// `int`.
    case int
    /// `ivec2`.
    case ivec2
    /// `ivec3`.
    case ivec3
    /// `ivec4`.
    case ivec4
    /// `bool`.
    case bool
    /// `mat3`.
    case mat3
    /// `mat4`.
    case mat4
    /// `sampler2D`.
    case sampler2D
    /// `sampler3D`.
    case sampler3D
    /// `samplerCube`.
    case samplerCube
    /// Any other GL type, by its GL enum value; it must not be declared in a layout.
    case other(UInt32)

    /// The GLSL type name; `other` reads `other(0x….)` with the GL code in hexadecimal.
    public var glslName: String {
        switch self {
        case .float: "float"
        case .vec2: "vec2"
        case .vec3: "vec3"
        case .vec4: "vec4"
        case .int: "int"
        case .ivec2: "ivec2"
        case .ivec3: "ivec3"
        case .ivec4: "ivec4"
        case .bool: "bool"
        case .mat3: "mat3"
        case .mat4: "mat4"
        case .sampler2D: "sampler2D"
        case .sampler3D: "sampler3D"
        case .samplerCube: "samplerCube"
        case .other(let code): "other(0x\(String(code, radix: 16, uppercase: true)))"
        }
    }
}

/// One declared uniform: its name and type.
public struct UniformDeclaration: Equatable, Hashable, Sendable {
    /// The uniform name as written in GLSL (for example `u_time`).
    public let name: String
    /// The declared type.
    public let type: UniformType
    /// Creates a declaration.
    public init(name: String, type: UniformType) { self.name = name; self.type = type }
}

/// Why a uniform layout was refused.
public enum UniformLayoutError: Error, Equatable, Sendable {
    /// Two declarations share the name.
    case duplicateName(String)
    /// A declaration uses `UniformType.other`, which cannot be declared.
    case undeclarableType(String)
}

/// An active uniform whose type differs from its declaration.
public struct UniformMismatch: Equatable, Sendable {
    /// The uniform name.
    public let name: String
    /// The declared type.
    public let declared: UniformType
    /// The type the program reports.
    public let actual: UniformType
    /// Creates a mismatch record.
    public init(name: String, declared: UniformType, actual: UniformType) {
        self.name = name; self.declared = declared; self.actual = actual
    }
}

/// The outcome of checking a layout against active uniforms; every list is sorted by name.
public struct UniformLayoutReport: Equatable, Sendable {
    /// Active uniforms the layout does not declare (errors, `shader.uniform-undeclared`).
    public let undeclared: [String]
    /// Active uniforms with a different type (errors, `shader.uniform-type`).
    public let mistyped: [UniformMismatch]
    /// Declared uniforms the compiler removed (not errors).
    public let unused: [String]
    /// Creates a report; the lists are stored as given.
    public init(undeclared: [String], mistyped: [UniformMismatch], unused: [String]) {
        self.undeclared = undeclared; self.mistyped = mistyped; self.unused = unused
    }
    /// True when no active uniform is undeclared or mistyped; unused declarations do not invalidate.
    public var isValid: Bool { undeclared.isEmpty && mistyped.isEmpty }
    /// The reason code of the first error (undeclared before mistyped), or nil when valid.
    public var reasonCode: ShaderReasonCode? {
        if !undeclared.isEmpty { return .uniformUndeclared }
        if !mistyped.isEmpty { return .uniformType }
        return nil
    }
}

/// A declared set of uniforms with unique names.
public struct UniformLayout: Equatable, Sendable {
    /// The declarations, sorted by name.
    public let declarations: [UniformDeclaration]

    /// Validates unique names and declarable types.
    public init(_ declarations: [UniformDeclaration]) throws(UniformLayoutError) {
        var names = Set<String>()
        for item in declarations {
            guard names.insert(item.name).inserted else { throw .duplicateName(item.name) }
            if case .other = item.type { throw .undeclarableType(item.name) }
        }
        self.declarations = declarations.sorted { $0.name < $1.name }
    }

    /// The declared type of `name`, or nil.
    public func type(of name: String) -> UniformType? { declarations.first { $0.name == name }?.type }

    /// Compares the active uniforms (name → type) with the declarations; deterministic, sorted lists.
    public func check(active: [String: UniformType]) -> UniformLayoutReport {
        var declared: [String: UniformType] = [:]
        for item in declarations { declared[item.name] = item.type }
        var undeclared: [String] = []
        var mistyped: [UniformMismatch] = []
        for name in active.keys.sorted() {
            let actual = active[name]!
            guard let expected = declared[name] else { undeclared.append(name); continue }
            if expected != actual { mistyped.append(UniformMismatch(name: name, declared: expected, actual: actual)) }
        }
        let unused = declarations.map(\.name).filter { active[$0] == nil }
        return UniformLayoutReport(undeclared: undeclared, mistyped: mistyped, unused: unused)
    }
}
