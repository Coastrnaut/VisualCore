# Research: A16-P00 (feature 116)

## Facts (verified in code, 2026-11-16)

- Products used by later phases: `VisualCoreMath`, `VisualCoreSimulation` (`FieldGrid`, `StoragePrecision` — CPU
  references for GPU field passes, feature 019), `VisualCoreScenes` (gesture recognizers, `GestureArbiter`),
  `VisualCoreRendering` (`RenderTarget`, `PingPongTarget` with `swap()`, `FloatRenderSupport.detect(in:)` and
  `storageFormat`, `FieldPass` with `FieldUniform` and `FieldPassError`, `ResourceRegistry`, `StillCapture`),
  `VisualCorePersistence` (`DocumentStore`, `MigrationChain`), `VisualCoreExperience` (experience storage, quality
  tiers, scenario manifests) and `VisualCoreExperienceHost` (session, shell, canvas overlay).
- `PingPongTarget` and `FieldPass` are used app-locally by Fluid Art Playground; still images are shared through
  `ShareLink` in Generative Art Studio.
- No cellular-automaton, Gray-Scott or wave-equation rules and no histogram reducer exist in any framework product.

## Decisions

- **D1 Scope:** audit only (clarification 1); the one app is the shell.
- **D2 Matrix scope:** five brainstorm capabilities (GPU simulation with framebuffer feedback, numerical
  visualization, parameter controls, data visualization, animation and capture) and six version 0.1 features (three
  families, parameter schema and seeds, pause/reset/step/speed with histogram or legend, CPU reference, GPU ping-pong
  with boundary rules, presets and still capture), plus cross-cutting rows (context loss and resize, quality tiers,
  accessibility, persistence with migration, bounded resources, truthful labels).
- **D3 Availability rule:** clarification 2.
- **D4 Gap owners:** simulation rules and their CPU references → app-local (A16-P01); GPU parity of the automata
  (A16-P02); reaction-diffusion and wave GPU passes with the float probe (A16-P03); the experiment interface, presets,
  histogram or legend and capture (A16-P04); numerical validation (A16-P05); release (A16-P06). Generic pieces (a
  reduction pass for histograms) are assessed for VisualCore ownership in their phase.
- **D5 Precision and boundaries:** clarification 5.
- **Alternatives considered:** building a new ping-pong or float-probe type for the experience (rejected: both exist
  in `VisualCoreRendering`); running reaction-diffusion on 8-bit targets (rejected: silent loss of precision).
