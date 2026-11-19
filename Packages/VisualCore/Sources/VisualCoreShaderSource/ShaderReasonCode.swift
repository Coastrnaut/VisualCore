// ShaderReasonCode.swift — stable reason codes and failure reports for shader refusals (feature 206 T-R02F06-002;
// clarification Q4, FR-R02F06-008). Contract:
// specs/206-shader-domain-specific-parameters-and-gl-es-safe-compilation/contracts/api.md.
//
// Report lines: `ShaderFailureReport.diagnostics` reuses the pure `ShaderDiagnostic` that already lives in this
// module (InfoLogParser.swift). It carries file, line, stage, severity and message, has no GL dependency, and is the
// same type `ShaderProgram` produces in VisualCoreRendering, so no second line type is needed.

/// The stable reason code of every shader refusal (clarification Q4); tests and logs assert codes by name.
public enum ShaderReasonCode: String, Sendable, CaseIterable, Codable {
    /// An `#include` chain returns to a file already on the stack.
    case includeCycle = "shader.include-cycle"
    /// `#include` nesting deeper than 8.
    case includeDepth = "shader.include-depth"
    /// Expanded text larger than 64 KiB of UTF-8.
    case tooLarge = "shader.too-large"
    /// An included (or requested) source is not registered.
    case unknownInclude = "shader.unknown-include"
    /// A `#version` other than `300 es`, or a version directive after the first line.
    case unsupportedVersion = "shader.unsupported-version"
    /// A define name that is not a GLSL identifier.
    case defineName = "shader.define-name"
    /// A define name with the reserved prefix `GL_` or `__`.
    case defineReserved = "shader.define-reserved"
    /// A define value with a line break or longer than 256 characters.
    case defineValue = "shader.define-value"
    /// More than 32 defines.
    case tooManyDefines = "shader.too-many-defines"
    /// A variant set the bounds refuse (switches, values or combinations).
    case tooManyVariants = "shader.too-many-variants"
    /// A stage failed to compile.
    case compile = "shader.compile"
    /// The program failed to link.
    case link = "shader.link"
    /// An active uniform that the declared layout does not name.
    case uniformUndeclared = "shader.uniform-undeclared"
    /// An active uniform whose type differs from the declared one.
    case uniformType = "shader.uniform-type"
    /// A parameter value that is NaN or infinite.
    case parameterNotFinite = "shader.parameter-not-finite"
}

/// One refused shader, reported with its reason code, diagnostics and the caller's context (clarification Q4).
public struct ShaderFailureReport: Equatable, Sendable, Codable {
    /// The feature that defines the codes: always `R2-F06`.
    public let feature: String
    /// The reason code.
    public let code: ShaderReasonCode
    /// Compiler, linker or expander messages mapped to source file and line; empty when none apply.
    public let diagnostics: [ShaderDiagnostic]
    /// The calling experience's id, when known.
    public let experience: String?
    /// The run's seed, when known.
    public let seed: UInt64?
    /// The simulation tick at the failure, when known.
    public let tick: Int?
    /// The capability (quality) tier in effect, when known.
    public let tier: Int?

    /// The feature identifier every report carries.
    public static let featureID = "R2-F06"

    /// Creates a report for `code`; `feature` is always `R2-F06`.
    public init(code: ShaderReasonCode, diagnostics: [ShaderDiagnostic] = [], experience: String? = nil,
                seed: UInt64? = nil, tick: Int? = nil, tier: Int? = nil) {
        self.feature = Self.featureID
        self.code = code
        self.diagnostics = diagnostics
        self.experience = experience
        self.seed = seed
        self.tick = tick
        self.tier = tier
    }
}

extension ShaderSourceError {
    /// The stable reason code; an unknown top-level source is reported as `shader.unknown-include`, the code for a
    /// source name that the library does not hold.
    public var reasonCode: ShaderReasonCode {
        switch self {
        case .tooLarge: .tooLarge
        case .tooDeep: .includeDepth
        case .cycle: .includeCycle
        case .unknownInclude, .unknownSource: .unknownInclude
        case .unsupportedVersion: .unsupportedVersion
        }
    }
}

extension DefineError {
    /// The stable reason code.
    public var reasonCode: ShaderReasonCode {
        switch self {
        case .invalidName: .defineName
        case .reservedName: .defineReserved
        case .invalidValue: .defineValue
        case .tooMany: .tooManyDefines
        }
    }
}

extension VariantError {
    /// The stable reason code: a refused define keeps its define code; every other variant refusal is
    /// `shader.too-many-variants`, the single code clarification Q4 gives variant sets.
    public var reasonCode: ShaderReasonCode {
        switch self {
        case .define(let error): error.reasonCode
        case .noValues, .tooManyValues, .duplicateValue, .duplicateSwitch, .tooManySwitches, .tooManyCombinations:
            .tooManyVariants
        }
    }
}
