# VisualCore architecture (F01)

Controlling documents: [constitution](../../.specify/memory/constitution.md) v1.0.0,
[ADR-0001](../decisions/ADR-0001-ledger-and-repository-state.md) (ledger),
[ADR-0002](../decisions/ADR-0002-render-host-seam.md) (render host seam),
[ADR-0003](../decisions/ADR-0003-package-boundaries.md) (package boundaries), feature dossier
[specs/001-visualcore-foundation](../../specs/001-visualcore-foundation/) (spec, plan, contracts, tasks).

```text
25 apps / Showcase / SecondConsumer           Harnesses/ProjectMReference (own .yml)
        |  SwiftUI + domain                         |  ProjectMBridge (reference, LGPL engine)
        v                                           v
  VisualCoreUI, VisualCoreEffects, VisualCoreAudio, VisualCoreAutomation   (iOS)
        v
  VisualCoreRendering: RenderHost (EGL lifecycle), GL table, resources, programs   (iOS)
        v                                  \
  CVisualCoreEGL / CVisualCoreGL            Packages/VisualCore pure modules (host + iOS):
        v                                    Math, Simulation, Scenes, ShaderSource,
  libEGL / libGLESv2 (owner ANGLE fork,      EffectsGraph, Diagnostics, AudioDSP,
  Metal backend, pin 29d1823)                Persistence, TestSupport (tests only)
        v
  Metal → GPU
```

Source-to-requirement mapping: `docs/verification/source-hashes.json` maps each of the 33
archived sources (hash-verified) and each of the 25 manuals to its ledger gates `ANN-P00..P06` and
spec directory `specs/0MM-app-<slug>` (MM = NN + 1). ID namespaces per ADR-0001.
