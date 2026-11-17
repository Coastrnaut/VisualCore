# Implementation Plan: Shader Studio — Phase 01 GLSL/diagnostic contract and editor shell

**Branch**: `159-ss-p01-glsl-diagnostics` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase adds Shader Studio's pending core and closes G-MODEL, G-VALIDATE, G-LINES and G-TEMPLATES:
- **Model:** `ShaderProject` (schema 1) with its uniforms, limits and refusals.
- **Validation:** `ShaderValidator` checks a source against `ShaderLimits` before any compile.
- **Lines:** `ShaderAssembly` builds the three template files, and `DiagnosticMapper` turns compiler diagnostics into
  the person's lines.
- **Editor model:** `EditorDocument` (`GLSLTokenizer`) holds numbered lines, tokens and diagnostics by line.
- **Templates:** `ShaderTemplates` holds three starters.
- **Proof:** the core tests compile real sources off screen.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/core.md](contracts/core.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 and GLSL ES 3.00 (as text).
- **Dependencies:**
  - the core: `VisualCoreShaderSource` (`ShaderDiagnostic`, `ShaderLibrary` limits), `VisualCoreParameters`
    (`ParameterDefinition`) and `VisualCorePersistence` (none needed if the envelope is app-local; see research D3);
  - the core tests: also `VisualCoreRendering` (`RenderHost`, `ResourceRegistry.program`, `ShaderBundle`,
    `FullScreenShaderScene.vertexSource`).
- **Testing:** `ShaderStudioCoreTests` on sim-27.2 through `scripts/xcodebuild_package.py`; each test under 10 s.
- **Constraints:**
  - the core is pure: no GL, clock, network, UIKit or SwiftUI;
  - no VisualCore change and no registration.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: the tests compile and draw on the host's own context; the core issues no GL call |
| II | PASS: reuses `ShaderLibrary`, `ShaderDiagnostic`, `ResourceRegistry.program`, `ShaderBundle`, `ParameterDefinition`; nothing copied into VisualCore |
| IV | PASS: project, validator, assembly, mapper, tokenizer and templates are pure and tested |
| VI | PASS: off-screen compiles prove the line mapping; no device claim |
| XIII | PASS: templates written here; recorded in `docs/apps/shader-studio/licenses.md` |
| A22 (2.18.1) | PASS: caps before compile; compiles only in the tests' host context; testable without the GPU except the compile proofs; no sandbox claim |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                  modify  ShaderStudioCore, ShaderStudioCoreTests
Packages/ExperiencesCreative/ShaderStudio/Core/ShaderProject.swift          new     project, uniforms, limits, refusals, codec
Packages/ExperiencesCreative/ShaderStudio/Core/ShaderValidator.swift        new     pre-compile checks
Packages/ExperiencesCreative/ShaderStudio/Core/ShaderAssembly.swift         new     prelude, person file, entry; names
Packages/ExperiencesCreative/ShaderStudio/Core/DiagnosticMapper.swift       new     diagnostics → person's lines / outside
Packages/ExperiencesCreative/ShaderStudio/Core/GLSLTokenizer.swift          new     token kinds, line split
Packages/ExperiencesCreative/ShaderStudio/Core/EditorDocument.swift         new     numbered lines with tokens and diagnostics
Packages/ExperiencesCreative/ShaderStudio/Core/ShaderTemplates.swift        new     gradient, noise-flow, rings
Packages/ExperiencesCreative/ShaderStudio/CoreTests/{ProjectTests,ValidatorTests,AssemblyTests,TokenizerTests,
  EditorDocumentTests,TemplateCompileTests,LineMappingCompileTests}.swift   new
docs/apps/shader-studio/licenses.md                                         new
docs/apps/shader-studio/visualcore-contract.json (G-MODEL, G-VALIDATE, G-LINES, G-TEMPLATES closed)   modify
```

- **Dependency direction:** core tests → core → VisualCore pure products; the core tests also → VisualCoreRendering.
- **Lifecycle:** the core has none. The A22-P02 presenter owns compiling in the host's context (queued requests).
- **Migration:** schema 1 only. **Rollback:** revert the commits.

## Parallel work

- **Agent M:** project, validator, their tests.
- **Agent T:** tokenizer, editor document, their tests.
- **Agent L:** assembly, mapper, templates, the two compile test files.
- **Lead:** Package.swift, licenses.md, the contract, runs and commits.
