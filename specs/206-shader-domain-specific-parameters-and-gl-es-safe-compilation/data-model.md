# Data Model: R02-F06

- **DefineSet**: ordered map name → value; invariants of FR-R02F06-002; `lines` sorted by name.
- **VariantSwitch**: `name` (a valid define name), `values: [String]` (1–8, each a valid define value, unique).
- **ShaderVariantSet**: `switches` (≤ 6, unique names, sorted); `combinations` (≤ 64) in lexicographic order; each
  `VariantCombination` has `defines: DefineSet` and `key` = `name=value` pairs joined by `;`.
- **ShaderStageKind**: `.vertex`, `.fragment` (VisualCoreShaderSource; only fragment shaders get a default precision).
- **PrecisionPolicy**: `.high` or `.medium`; `PrecisionPolicy(fragmentHighpSupported:)`; `PrecisionFinding(file, line,
  message)`.
- **UniformType**: float, vec2, vec3, vec4, int, ivec2, ivec3, ivec4, bool, mat3, mat4, sampler2D, sampler3D,
  samplerCube, other(UInt32).
- **UniformLayout**: `[UniformDeclaration(name, type)]`, unique names. **UniformLayoutReport**: `undeclared: [String]`,
  `mistyped: [(name, declared, actual)]`, `unused: [String]`; `isValid` = no undeclared and no mistyped.
- **ShaderReasonCode**: the fifteen codes of clarification Q4. **ShaderFailureReport**: `feature = "R2-F06"`, `code`,
  `diagnostics`, optional `experience`, `seed`, `tick`, `tier`.
- **PrewarmReport**: `[(key, outcome: compiled | cached | failed([ShaderDiagnostic]))]` in combination order, valid for
  the registry's current context generation; after a context rebuild the caller prewarms again (the cache is empty).
- **ParameterUniformBinding**: schema, program, `bound: [name: location]`, `unused: [String]`.

As built (T-R02F06-015): see [contracts/api.md](contracts/api.md) "As built" for the additions
(`DefineSet` helpers, `UniformLayoutError`, `PrewarmReport` counts and entry reason codes) and the reason-code mapping
of `VariantError` and `ShaderSourceError.unknownSource`.
