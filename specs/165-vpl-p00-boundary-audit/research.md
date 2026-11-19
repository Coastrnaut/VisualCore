# Research: A23-P00 (feature 165)

- **D1 What VisualCore offers (survey, spot-checked):**
  - **Pass graph:** `EffectGraphDescription` and `EffectGraphValidator` (VisualCoreEffectsGraph) validate a versioned
    pass DAG with a private Kahn order, cycle errors, a 32-pass limit and a memory quota; `EffectRenderer` and
    `EffectScene` (VisualCoreEffects) draw it. The pass set is closed and chain-only.
  - **Passes and targets:** `FieldPass` with named sampler inputs and typed uniforms; `PingPongTarget`; render targets
    with pools; `ResourceBudget` and `ResourceLedger`.
  - **GLSL:** `vc/` noise, palette, colour, hash, SDF and field functions; the blur shader is internal.
  - **Parameters, persistence, hashing:** `ParameterSchema`, `MigrationChain`, `NamedLibrary`, `ExperienceStorage`,
    `ExperienceSnapshot`, `DigestBuilder`, `StableHash`.
  - **Canvas math:** `PlaneViewport`, `Camera2D`, gesture recognizers, `SceneNode.hitTest`.
- **D2 What it lacks:** typed ports, a public DAG utility, generator, constant, time and scalar-mix passes, a node
  canvas, a compiled-subgraph cache and graph migration.
- **D3 Traceability:** the five brainstorm capabilities (render graph, compositing, parameter system, reusable effects,
  graph serialization) and the six version 0.1 features (typed graph; node library; touch canvas; cycle detection
  and feedback; preview compiler; versioned persistence) each map to matrix rows.
- **D4 Phase plan of the gaps (manual §9):**

  | Gap | Phase |
  |---|---|
  | The graph, node, port and edge models; the node registry; type checking, topological order and cycle rejection | A23-P01 |
  | The canvas with wires, zoom, pan, selection and the accessible list form; connection feedback | A23-P02 |
  | The compiled pass schedule, the node operators, the static texture budget, the preview and its rebuild | A23-P03 |
  | Save and open, examples, migration, diagnostics on nodes | A23-P04 |
  | Resource-budget and usability testing; the device plan | A23-P05 |
  | Release | A23-P06 |
- **D4a Numbers later:** the caps (nodes, edges, textures, sizes, blur radius) are set in A23-P01 and A23-P03 and
  measured on devices in the campaign.
- **D5 Rejected:** mapping nodes onto `EffectGraphDescription` was rejected because its pass set is closed and has no
  generators or scalar ports, so every phase would need a VisualCore change; a second consumer would justify an
  upstream pass registry. Promoting the private Kahn order was rejected for one user; the core's own order is short and
  tested.
