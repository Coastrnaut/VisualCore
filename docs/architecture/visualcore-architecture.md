# VisualCore architecture

Controlling documents: [constitution](../../.specify/memory/constitution.md) v1.1.0,
[ADR-0001](../decisions/ADR-0001-ledger-and-repository-state.md) (ledger),
[ADR-0002](../decisions/ADR-0002-render-host-seam.md) (render host seam),
[ADR-0003](../decisions/ADR-0003-package-boundaries.md) (package boundaries),
[ADR-0004](../decisions/ADR-0004-spec-kit-per-gate-and-f00-f01-rework.md) (one Spec Kit feature per gate).

* Phase 0 audit (feature [001](../../specs/001-baseline-audit/)): [repository audit](repository-audit.md),
  [rendering pipeline trace](current-rendering-pipeline.md),
  [reusable components](reusable-component-inventory.md), [gap analysis](visualcore-gap-analysis.md),
  [baseline](../verification/projectm-baseline.md).
* Phase 1 contracts (feature [002](../../specs/002-architecture-contracts/)):
  [package map + rules R1–R5](../../specs/002-architecture-contracts/contracts/package-map.md),
  [render lifecycle](../../specs/002-architecture-contracts/contracts/render-lifecycle.md),
  [resources, shaders, errors, logging](../../specs/002-architecture-contracts/contracts/resources-shaders-errors.md),
  [tests, adapter, submodule, regression](../../specs/002-architecture-contracts/contracts/tests-adapter-submodule-regression.md).

```text
25 apps / Showcase / SecondConsumer           Harnesses/ProjectMReference (own .yml)
        |  SwiftUI + domain                         |  reference ProjectMBridge (LGPL engine)
        v                                           v
  VisualCoreUI, VisualCoreEffects, VisualCoreAudio, VisualCoreAutomation   (iOS)
        v
  VisualCoreRendering: RenderHost (EGL lifecycle), resources, programs     (iOS)
        v                                  \
  CVisualCoreEGL / CVisualCoreGL            Packages/VisualCore pure modules (host + iOS):
        v                                    Math, Simulation, Scenes, ShaderSource,
  libEGL / libGLESv2 (owner ANGLE fork,      EffectsGraph, Diagnostics, AudioDSP,
  Metal backend, pin 29d1823)                Persistence, TestSupport (tests only)
        v
  Metal → GPU
```

## Regression (from the contracts)

Rendering-package changes require: VisualCoreRendering simulator tests on iOS 27.2 + 26.5, the
reference baseline renderer tests (`scripts/run_reference_baseline.py --step test-anglerendering-ios27/26`)
and, from F07, the `ProjectMReference` harness. Every commit runs `validate_docs.py`,
`check_compliance.py`, `check_dependencies.py` and `test_scripts.py`.

## F01 rework addendum (2026-11-10, ADR-0004): ownership-ambiguity review (SC-F105)

| Reference package | Owner | VisualCore counterpart |
|---|---|---|
| ANGLERendering | ProjectM-iOS (read-only) | `VisualCoreRendering.RenderHost` (re-implemented EGL sequence, no engine types) |
| Rendering | ProjectM-iOS | ideas only: `VisualCoreDiagnostics` (frame meter, quality caps), `VisualCoreEffects` (flash limiter) |
| ProjectMBridge | ProjectM-iOS | none (harness only) |
| PresetLibrary | ProjectM-iOS | none |
| AudioCore | ProjectM-iOS | `VisualCoreAudioDSP` (re-implemented ring/DSP) |
| CaptureKit / CaptureUI | ProjectM-iOS | none (System/App Capture is not a suite feature) |
| Diagnostics | ProjectM-iOS | ideas only: `VisualCoreDiagnostics` reports |

No component is owned by both. Result: zero ownership ambiguities (archived Phase 1 exit gate).
