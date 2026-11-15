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
  `newer-version`, `too-large`; opening sends `world.open` with the document's state JSON as the replay record.
- **Rationale**: mirrors `ExperimentStore` (proven in A11-P04) and keeps every edit replayable.

## D5 — Thumbnails
- **Decision**: `renderStill(width: 160, height: 120)` → `StillImageEncoder` PNG → `world-<slot>.png` after the
  document; missing context → no picture; size cap 64 KB (refuse larger, keep the document).
