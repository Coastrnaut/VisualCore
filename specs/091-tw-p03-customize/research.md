# Research: A12-P03 (feature 091)

Facts verified on 2026-11-15 (clarification session): `ExperimentStore` pattern over `ExperienceStorage` (atomic
`write`), slot closures in the presenter, `ExperienceSession.renderStill`, `StillImageEncoder`, `MeshShapes`,
`MeshRenderer(mesh:colors:registry:)`, `Ray3`, `MigrationChain`.

## D1 — Props (G-PROPS)
- **Decision**: four props built from `MeshShapes` and `MeshGenerators.uvSphere`, merged into one mesh per kind with a
  per-vertex colour stream from a prop palette; picking box = mesh bounds; transforms (x, y, z, rotation, scale 1).
- **Alternatives**: imported models (forbidden); one draw per part (more draws).

## D2 — Editing rules
- **Decision**: the clarified actions and refusal codes; placement validation as a pure function
  `WorldEditing.validate(placement:world:)` used by place and move; the selection is part of the state (so replay and
  digest cover it); preset or seed changes clear props.

## D3 — Light (G-LIGHT)
- **Decision**: `WorldLight` (azimuth wrapped, elevation and ambient clamped) → unit direction; applied to every
  renderer per frame.

## D4 — Document and slots (G-WORLDDOC)
- **Decision**: `WorldState` schema 2; `WorldDocument` (`schema`, `name`, `state`) encoded as sorted-key JSON (≤ 64 KB);
  `WorldStore` with `save/read/clear/summaries` on `world-<slot>.json` and `world-<slot>.png`, refusals `damaged`,
  `newer-version`, `too-large`; opening restores a snapshot of the document's state through `ExperienceShell.restore` (engine actions carry
  only numbers, so a whole state is never an action; Physics Playground opens slots the same way).
- **Rationale**: mirrors `ExperimentStore` (proven in A11-P04) and keeps every edit replayable.

## D5 — Thumbnails
- **Decision**: `renderStill(width: 160, height: 120)` → `StillImageEncoder` PNG → `world-<slot>.png` after the
  document; missing context → no picture; size cap 64 KB (refuse larger, keep the document).

## As built (2026-11-15, recorded at convergence T-A12-310)

- **D2 ground height:** a placed or moved prop rests on the drawn terrain: `WorldEditing.groundHeight` interpolates
  inside the mesh triangle under the point (each cell split along its (i, j)–(i + 1, j + 1) diagonal), so a prop sits
  on the visible surface (`WorldEditingTests` check within 1 mm against the mesh vertices). `GroundPick` keeps the
  bilinear sampler of A12-P02; a tapped point therefore differs from the drawn surface by at most the cell's bilinear
  error, and placement snaps it to the drawn surface.
- **D2 editing details:** placing selects the new prop; re-choosing the preset already shown keeps the props, while
  `world.seed` and a real preset change clear props and selection; an out-of-range or non-finite move or turn step is
  refused with `a12.invalid-choice` after `a12.no-selection` is checked.
- **D3 light range:** the engine accepts `light.azimuth` only within its declared 0…360°, so the azimuth stepper wraps
  its value before sending; `WorldLight.setAzimuth` wraps any finite value for direct core calls.
- **D4 documents:** the saved file's own schema must be exactly 2 (a file schema 1 is refused as `damaged`), while a
  schema-1 state inside a schema-2 document migrates like a snapshot. The interrupted-write test makes the experience's
  folder read-only (the storage's internal failure hook is not public) and checks that the previous JSON and PNG stay
  byte-identical (`WorldStoreTests`).
