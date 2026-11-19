# Implementation Plan: R02-F07 — Linear-colour HDR-look emissive pass and mobile-safe bloom

**Branch**: `207-linear-color-hdr-look-emissive-pass-and-mobile-safe-bloom` (spec directory only; work on `main`) |
**Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

One new pass type `emissive` in the existing effect graph (linear-light prefilter, downsampled separable blur,
exposure, tone mapping, sRGB encode), a premultiplied composite mode and blend preset, a linear-light option of the
flash limiter, and a pure CPU reference. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 via `FieldPass`-style full-screen programs of VisualCoreEffects.
**Primary dependencies**: VisualCoreEffectsGraph (pure schemas, reference), VisualCoreEffects (passes), VisualCoreRendering
(targets, pool, `FloatRenderSupport`), VisualCoreShaderSource (`RenderState`). No new package dependency.
**Testing**: `swift test --package-path Packages/VisualCore` (schemas, reference); VisualCoreRendering scheme on
sim-27.2 and sim-26.5 (VisualCoreEffectsTests pixel tests); ExperiencesCreative on sim-27.2 (Fluid Art Playground and
Generative Art Studio use bloom and the limiter); reference regression in two chunks.
**Performance goals**: bounded by arithmetic (no wall-clock asserts): three draws per frame, two blur targets of a
quarter (half quality) or a sixteenth (quarter quality) of the output's pixels; each test < 10 s.
**Constraints**: additive; existing pass outputs byte-identical on their fixtures.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — passes of the existing effect renderer; no new context. |
| II App-neutral API · II-a reference | PASS — generic effect; `///`; API baseline; reference regression in two chunks. |
| III GPU lifecycle | PASS — targets from the pool, returned each frame; programs rebuilt after a context rebuild like every pass. |
| IV Host-testable | PASS — formulas in the pure reference; schema validation on the host. |
| VII Accessibility | PASS — reduce-flashing keeps bounding the glow (FR-R02F07-005). |
| IX Bounded input | PASS — every parameter ranged and validated. XIII Code-only visuals | PASS. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreEffectsGraph/
  PassSchemas.swift          modify  "emissive" schema; composite mode 0…2; flashLimit "linear"; bytes estimate
  EmissiveReference.swift    new     sRGB transfer (unclamped decode), luminance, prefilter, tone maps, composite, premultiplied over
Packages/VisualCore/Sources/VisualCoreShaderSource/RenderState.swift   modify  premultipliedBlended preset
Packages/VisualCore/Tests/VisualCoreEffectsGraphTests/EmissiveReferenceTests.swift, EmissiveSchemaTests.swift   new
Packages/VisualCoreRendering/Sources/VisualCoreEffects/
  EffectShaders.swift        modify  emissive prefilter, blur, composite programs; composite mode 2; limiter linear luma
  EffectPasses.swift         modify  EmissivePass (pool targets, precision fallback warning); composite mode 2; limiter linear
  EffectRenderer.swift       modify  "emissive" case
  EffectScene.swift          modify  limiter `linear` = 1 when the graph has an emissive pass
Packages/VisualCoreRendering/Tests/VisualCoreEffectsTests/EmissivePassTests.swift   new
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md,
docs/architecture/shaders.md (emissive section), docs/catalog/shared-feature-map.json (as built)   modify (lead)
```

**Migration**: none (graph JSON gains a pass type; old graphs unchanged). **Rollback**: revert the commits.

## Parallel work

Agent R: EmissiveReference, schemas, RenderState preset and host tests. Agent G (after R): shaders, passes, renderer,
scene and EmissivePassTests. Lead: docs, API baseline, runs, commits.
