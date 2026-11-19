# Implementation Plan: R02-F06 — Shader domain-specific parameters and GL ES safe compilation

**Branch**: `206-shader-domain-specific-parameters-and-gl-es-safe-compilation` (spec directory only; work on `main`) |
**Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

Extend the one shader pipeline: safe expansion (include once, byte size guard, validated defines), declared variant
sets compiled in advance, a device-chosen default float precision, complete diagnostics with stable reason codes, and
declared uniform layouts and parameter bindings checked against the compiled program. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreShaderSource, VisualCoreRendering,
VisualCoreParameters (new dependency of VisualCoreRendering, pure). **Storage**: none. **Testing**: `swift test
--package-path Packages/VisualCore` (pure parts); VisualCoreRendering on sim-27.2 and sim-26.5 (GL parts);
ExperiencesCreative on sim-27.2 (no Stage One breakage); reference regression in two chunks.
**Target platform**: iOS 26+, simulator ANGLE path; device drivers in the device campaign.
**Performance goals**: bounded by arithmetic, not a clock (no wall-clock asserts on CI): each file is read once per
expansion, at most 64 KiB of text, 32 defines and 64 variant combinations; each test < 10 s (analyze A1).
**Constraints**: additive public API; `program(...)` signature kept; every existing shader compiles unchanged.
**Scale/scope**: 5 new source files, 1 modified source file in each package, 7 new test files.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no new draw path or context. |
| II App-neutral API | PASS — generic shader tooling; `///` on every public symbol; API baseline updated. |
| II-a Preserve the reference | PASS — reference regression in two chunks. |
| III GPU lifecycle and threads | PASS — GL work on the main thread inside host callbacks; bindings hold no GPU object across teardown. |
| IV Host-testable | PASS — expansion, defines, variants, precision and layouts are pure and host-tested. |
| V Implementation before devices | PASS — device drivers checked in the campaign. |
| VI Evidence | PASS — run-checks; planted-mistake fixtures. |
| VIII Public APIs only · IX Bounded input · X Licensing | PASS — GL ES 3.0 entry points already loaded; limits on defines, variants, logs; original code. |
| XI One app · XII No ads · XIII Code-only visuals | PASS. |

Post-design re-check: PASS (VisualCoreRendering → VisualCoreParameters is pure → pure; no cycle).

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreShaderSource/
  ShaderLibrary.swift         modify  include once; byte size guard; expand(_:defines: DefineSet, precision:) overload
  DefineSet.swift             new     DefineSet, DefineError (name, reserved, value, count)
  ShaderVariantSet.swift      new     ShaderVariantSet, VariantSwitch, VariantCombination (key), VariantError
  PrecisionPolicy.swift       new     PrecisionPolicy (high/medium), insertion rule, PrecisionFinding
  UniformLayout.swift         new     UniformType, UniformDeclaration, UniformLayout, UniformLayoutReport
  ShaderReasonCode.swift      new     ShaderReasonCode (stable codes), ShaderFailureReport
Packages/VisualCore/Package.swift (no change: ShaderSource stays dependency-free)
Packages/VisualCore/Tests/VisualCoreShaderSourceTests/
  IncludeOnceTests.swift, DefineSetTests.swift, VariantSetTests.swift, PrecisionPolicyTests.swift,
  UniformLayoutTests.swift                                                             new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/
  ShaderProgram.swift         modify  log length up to 64 KiB; warnings; link file labels; reflection type names
  ResourceRegistry.swift      modify  program(…defines: DefineSet, precision:) overload; prewarm(_:vertex:fragment:library:)
  ShaderBindings.swift        new     ShaderProgram.check(_ layout:), ParameterUniformBinding, PrewarmReport
Packages/VisualCoreRendering/Package.swift                     modify  VisualCoreRendering depends on VisualCoreParameters
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/
  SafeCompileTests.swift, ShaderBindingTests.swift                                     new
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md,
docs/architecture/shaders.md (new or extended)                                         modify (lead)
```

**Errors**: typed `DefineError`, `VariantError`, `ShaderError` (existing, gains `reasonCode`); layout and binding
checks report, they never crash. **Migration**: none (no stored data). **Rollback**: revert the feature's commits.

## Tests by layer

Host: VisualCoreShaderSourceTests (new and existing `ShaderLibraryTests`). Simulators 27.2 and 26.5: the whole
VisualCoreRendering scheme (existing shader, cache and validation tests plus the two new files). Regression:
ExperiencesCreative on 27.2 and VisualCoreEffects shader validation; reference regression in two chunks.

## Parallel work

Agent S: DefineSet, ShaderVariantSet, ShaderReasonCode and their tests. Agent P: ShaderLibrary include-once and size
guard, PrecisionPolicy, UniformLayout and their tests. Agent G (after S and P): ShaderProgram, ResourceRegistry,
ShaderBindings, Package.swift of VisualCoreRendering and the two GL test files. Lead: README, API baseline, docs, runs,
commits.
