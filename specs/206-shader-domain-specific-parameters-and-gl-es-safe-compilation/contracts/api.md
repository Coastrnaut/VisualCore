# Contract: public API (R02-F06)

VisualCoreShaderSource (pure):
- `public struct DefineSet: Equatable, Sendable { public init(_ defines: [String: String]) throws(DefineError); public var defines: [String: String] { get }; public static let maxDefines = 32; public static let maxValueLength = 256 }`
- `public enum DefineError: Error, Equatable { case invalidName(String), reservedName(String), invalidValue(String), tooMany(Int) }`
- `public struct VariantSwitch: Equatable, Sendable { public init(name: String, values: [String]) throws(VariantError) }`
- `public struct ShaderVariantSet: Equatable, Sendable { public init(_ switches: [VariantSwitch]) throws(VariantError); public var combinations: [VariantCombination] { get }; public static let maxSwitches = 6, maxValuesPerSwitch = 8, maxCombinations = 64 }`
- `public struct VariantCombination: Equatable, Sendable { public let key: String; public let defines: DefineSet }`
- `public enum VariantError: Error, Equatable { case noValues(String), tooManyValues(String), duplicateValue(String, String), duplicateSwitch(String), tooManySwitches(Int), tooManyCombinations(Int), define(DefineError) }`
- `public enum PrecisionPolicy: String, Sendable { case high, medium; public init(fragmentHighpSupported: Bool) }`
- `ShaderLibrary.expand(_ name: String, defines: DefineSet, precision: PrecisionPolicy?, stage: ShaderStageKind) throws(ShaderSourceError) -> ExpandedShader` (existing overloads unchanged); `ExpandedShader.precisionFindings: [PrecisionFinding]`
- `public enum UniformType`, `public struct UniformDeclaration`, `public struct UniformLayout`, `public struct UniformLayoutReport` (data-model.md)
- `public enum ShaderReasonCode: String, Sendable, CaseIterable` (the fifteen codes); `public struct ShaderFailureReport: Equatable, Sendable`

VisualCoreRendering:
- `ShaderProgram.warnings: [ShaderDiagnostic]`; `ShaderProgram.check(_ layout: UniformLayout) -> UniformLayoutReport`
- `ShaderError.reasonCode: ShaderReasonCode`
- `ResourceRegistry.program(vertex:fragment:defines: DefineSet, precision: PrecisionPolicy?, library:vertexName:fragmentName:) throws -> ShaderProgram`
- `ResourceRegistry.prewarm(_ set: ShaderVariantSet, vertex:fragment:library:precision:) -> PrewarmReport`
- `public struct ParameterUniformBinding { public init(schema: ParameterSchema, program: ShaderProgram); public let unused: [String]; public func apply(_ values: ResolvedParameters) throws(ParameterBindingError) }`
