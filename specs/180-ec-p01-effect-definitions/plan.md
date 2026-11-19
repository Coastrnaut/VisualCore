# Implementation Plan: Effects Composer — Phase 01 Effect definitions and render contracts

**Branch**: `180-ec-p01-effect-definitions` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

A pure, pending core for Effects Composer: the five built-in effects with their parameters, formulas, CPU references
and fragment programs (as strings), the effect chain with its caps, edits and exact undo and redo, the versioned chain
file, and a test image made in code. The programs are compiled and drawn only by the core tests inside a running
render host, which compare chosen pixels with the CPU references and prove that effect order matters and that undo
restores the picture byte for byte. Gaps G-MODEL and G-EFFECTS close.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/core.md](contracts/core.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 (strict concurrency), Swift Testing; GLSL ES 3.00 fragment programs held as strings.
- **Dependencies:** VisualCoreExperience (`DigestBuilder`, `StateDigest`) and VisualCorePersistence (`MigrationChain`)
  for the core; the core tests also VisualCoreRendering (`RenderHost`, `RenderScene`, `FieldPass`,
  `ResourceRegistry`, `RenderTarget.upload(rgbaFloats:)`, `readPixels`, `stats`).
- **Storage:** none in this phase (the chain file is encoded and decoded in memory; presets are A25-P04).
- **Testing:** `EffectsComposerCoreTests` on sim-27.2.
- **Performance:** each unit test under 10 s; the test image is 64 × 64 and the largest blur reads 289 texels per pixel.
- **Constraints:** no graphics call, no clock, no UIKit or SwiftUI in the core; no VisualCore change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: no renderer change; programs drawn through `FieldPass` in the host's context |
| II | PASS: reused `DigestBuilder`, `MigrationChain`, `RenderHost`, `FieldPass`, `ResourceRegistry`; effects app-local by decision (A25-P00 clarification Q1) |
| II-a | PASS: no VisualCore change, so no regression rerun |
| III | PASS: the core holds no GL state |
| IV | PASS: pure and tested |
| V | PASS: no device step |
| VI | PASS: CPU references with stated tolerances; no accuracy claim |
| VII–X | PASS |
| XI | PASS: a pending core in the one app's package; no target, no registration |
| XII, XIII | PASS: no asset; the test image is made in code |

A25 rules (constitution 2.21.0): domain truth pure; bounded chain and parameters; refusal of non-finite and newer
files; drawing never changes the chain; a pass never samples its output (`FieldPass` refuses it). PASS. Post-design:
PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                         modify  EffectsComposerCore, EffectsComposerCoreTests
Packages/ExperiencesCreative/EffectsComposer/Core/EffectDefinition.swift     new  EffectID, ParameterSpec, EffectDefinition, EffectLibrary (the five), fingerprint
Packages/ExperiencesCreative/EffectsComposer/Core/EffectReference.swift      new  RGBAImage (bytes, size), the CPU reference of each effect
Packages/ExperiencesCreative/EffectsComposer/Core/EffectPrograms.swift       new  the fragment program of each effect, its uniforms (packed vec4)
Packages/ExperiencesCreative/EffectsComposer/Core/EffectChain.swift          new  EffectNode, EffectChain, ChainLimits, validation, fingerprint
Packages/ExperiencesCreative/EffectsComposer/Core/ChainEditing.swift         new  ChainEdit, EditHistory (undo, redo, depth 64)
Packages/ExperiencesCreative/EffectsComposer/Core/ChainDocument.swift        new  encode, decode, ChainRefusal, migration hook
Packages/ExperiencesCreative/EffectsComposer/Core/TestImage.swift            new  the 64 × 64 picture made in code
Packages/ExperiencesCreative/EffectsComposer/CoreTests/{DefinitionTests,ChainTests,HistoryTests,ChainDocumentTests,ReferenceTests,
  ProgramRenderTests,OrderTests,HostCountTests,RenderSupport}.swift            new
docs/apps/effects-composer/visualcore-contract.json (G-MODEL, G-EFFECTS closed)    modify
docs/apps/effects-composer/README.md (the core's sources)                         modify
```

- **Dependency direction:** core tests → core → VisualCore pure products; the core tests also → VisualCoreRendering.
- **Lifecycle:** the core has none; the experience (A25-P02) compiles the programs in its scene's `setup`.
- **Migration:** chain file version 1; `MigrationChain(currentVersion: 1)` is the hook. **Rollback:** revert the commits.
- **Build commands:** see [quickstart.md](quickstart.md).

## Parallel work

- **Agent M:** EffectDefinition, EffectChain, ChainEditing, ChainDocument and their tests (Definition, Chain, History,
  ChainDocument), against [contracts/core.md](contracts/core.md).
- **Agent R:** EffectReference, EffectPrograms, TestImage and their tests (Reference, ProgramRender, Order,
  HostCount, RenderSupport), against the same contract, after M's EffectDefinition.
- **Lead:** Package.swift, the contract, the README, runs and commits.
