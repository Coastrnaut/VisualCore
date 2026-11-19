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

## As built (T-R02F06-015, 2026-11-19)

The API above shipped with these additions and choices, all documented with `///` and listed in
`docs/api/visualcore-public-api.txt`:
- `DefineSet.empty`, `names`, `lines` and `static validate(name:value:) throws(DefineError)` (also used by
  `VariantSwitch`).
- `UniformLayoutError` (`duplicateName`, `undeclarableType` for `.other`); `UniformLayoutReport.reasonCode`
  (undeclared before mistyped).
- `ResourceRegistry.prewarm(_:vertex:fragment:library:precision:vertexName:fragmentName:)`: the two names are
  defaulted and label failure diagnostics; `PrewarmReport.Entry` carries `reasonCode` and the report counts
  `compiledCount`, `cachedCount`, `failedCount` and `allSucceeded`.
- `ShaderProgram.maxInfoLogBytes = 65_536`; `ParameterUniformBinding.uniformName(_:)` (`u_<name>`).
- Reason-code mapping: every `VariantError` except `.define(e)` maps to `shader.too-many-variants`, the only variant
  code of clarification Q4 (`.define(e)` keeps `e`'s code); `ShaderSourceError.unknownSource` maps to
  `shader.unknown-include`.
- The existing `program(...)` now labels link diagnostics `<vertexName>+<fragmentName>` (formerly `unknown`), as
  FR-R02F06-005 asks for every link; its signature and every other behaviour are unchanged.
