// ShaderBindings.swift — prewarm reports and parameter-to-uniform bindings (feature 206 T-R02F06-007;
// FR-R02F06-003, FR-R02F06-007, FR-R02F06-008, research R8). Contract:
// specs/206-shader-domain-specific-parameters-and-gl-es-safe-compilation/contracts/api.md.
//
// Lifecycle: a binding holds its program only; after a context rebuild the caller builds a new program and a new
// binding from it (bindings hold no GPU object across teardown, as presenters do; clarification Q6).
import CVisualCoreGL
import VisualCoreParameters
import VisualCoreShaderSource

/// The outcome of `ResourceRegistry.prewarm(_:vertex:fragment:library:precision:vertexName:fragmentName:)`: one entry
/// per variant combination, in combination order; valid for the registry's current context generation only.
public struct PrewarmReport: Equatable, Sendable {
    /// What happened to one combination.
    public enum Outcome: Equatable, Sendable {
        /// Compiled and linked now, and placed in the program cache.
        case compiled
        /// Already in the program cache (counted as a cache hit).
        case cached
        /// Refused or failed, with its diagnostics mapped to source file and line.
        case failed([ShaderDiagnostic])
    }

    /// One combination's result.
    public struct Entry: Equatable, Sendable {
        /// The combination key (`name=value` pairs joined by `;`).
        public let key: String
        /// What happened.
        public let outcome: Outcome
        /// The reason code of a failure (`shader.compile`, `shader.link` or a source code); nil otherwise.
        public let reasonCode: ShaderReasonCode?

        /// Creates an entry.
        public init(key: String, outcome: Outcome, reasonCode: ShaderReasonCode? = nil) {
            self.key = key; self.outcome = outcome; self.reasonCode = reasonCode
        }
    }

    /// The entries, in combination order.
    public let entries: [Entry]

    /// Creates a report from its entries.
    public init(entries: [Entry]) { self.entries = entries }

    /// Combinations compiled now.
    public var compiledCount: Int { entries.filter { $0.outcome == .compiled }.count }
    /// Combinations served from the cache.
    public var cachedCount: Int { entries.filter { $0.outcome == .cached }.count }
    /// Combinations that failed.
    public var failedCount: Int { entries.filter { if case .failed = $0.outcome { true } else { false } }.count }
    /// True when no combination failed.
    public var allSucceeded: Bool { failedCount == 0 }
}

/// Why `ParameterUniformBinding.apply(_:)` refused a set of values.
public enum ParameterBindingError: Error, Equatable, Sendable {
    /// The named parameter's value is NaN or infinite; nothing was set.
    case notFinite(String)

    /// The stable reason code (`shader.parameter-not-finite`).
    public var reasonCode: ShaderReasonCode {
        switch self {
        case .notFinite: .parameterNotFinite
        }
    }
}

/// A parameter schema matched to a program's active float uniforms `u_<name>` (feature 206, FR-R02F06-007).
@MainActor
public struct ParameterUniformBinding {
    /// The schema whose values are applied.
    public let schema: ParameterSchema
    /// The program the uniforms belong to.
    public let program: ShaderProgram
    /// Bound parameters: parameter name → uniform location of `u_<name>`.
    public let bound: [String: GLint]
    /// Parameters without an active `float` uniform `u_<name>` (removed by the compiler, absent or of another type),
    /// sorted; each is reported once as a registry warning when the binding is made.
    public let unused: [String]

    /// The uniform name of a parameter: `u_<name>`.
    public static func uniformName(_ parameter: String) -> String { "u_\(parameter)" }

    /// Matches every parameter of `schema` to the active `float` uniform `u_<name>` of `program`.
    public init(schema: ParameterSchema, program: ShaderProgram) {
        self.schema = schema
        self.program = program
        var bound: [String: GLint] = [:]
        var unused: [String] = []
        for definition in schema.definitions {
            if let uniform = program.uniforms[Self.uniformName(definition.name)],
               uniform.type == GLenum(GL_FLOAT), uniform.size == 1 {
                bound[definition.name] = uniform.location
            } else {
                unused.append(definition.name)
            }
        }
        self.bound = bound
        self.unused = unused.sorted()
        for name in self.unused {
            program.registry?.warn("\(program.cacheKey.prefix(8)):parameter \(name) has no float uniform \(Self.uniformName(name))")
        }
    }

    /// Sets every bound uniform to its parameter's value clamped to the schema range (a missing value takes the
    /// default). Call after `program.use()`, like `ShaderProgram`'s setters. Any non-finite value is refused with
    /// `shader.parameter-not-finite` before anything is set.
    public func apply(_ values: ResolvedParameters) throws(ParameterBindingError) {
        for definition in schema.definitions {
            if let value = values.values[definition.name], !value.isFinite { throw .notFinite(definition.name) }
        }
        for definition in schema.definitions where bound[definition.name] != nil {
            let value = definition.clamped(values.values[definition.name] ?? definition.defaultValue)
            program.set(Self.uniformName(definition.name), Float(value))
        }
    }
}

extension ShaderError {
    /// The diagnostics of a compile or link failure; a source refusal becomes one error diagnostic at its file and
    /// line when known, attributed to `sourceStage`.
    func diagnostics(sourceStage: ShaderStage) -> [ShaderDiagnostic] {
        switch self {
        case .compile(let d), .link(let d): return d
        case .source(let error):
            let (file, line): (String, Int)
            switch error {
            case .unknownInclude(_, let f, let l), .unsupportedVersion(let f, let l): (file, line) = (f, l)
            default: (file, line) = ("unknown", 0)
            }
            return [ShaderDiagnostic(file: file, line: line, stage: sourceStage, severity: .error,
                                     message: "\(error.reasonCode.rawValue): \(error)")]
        }
    }
}
