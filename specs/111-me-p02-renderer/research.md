# Research: A15-P02 (feature 111)

## D1 — Display modes
- **Decision**: ball-and-stick atoms 0.30 × van der Waals radius with 0.12 Å sticks; space-filling 1.00 × van der Waals
  radius without sticks (clarification Q1); legend "Display radii, not measured sizes".
- **Alternatives**: covalent radii for balls (rejected: hydrogen too small to see at default zoom).

## D2 — Camera
- **Decision**: turn 15° wrapping, tilt 10° within ±80°, zoom 0.85 per step within ±4 of the framed distance; default
  30°/20°/0 (clarification Q2); refusal `a15.camera-limit`.

## D3 — Drawing and instancing
- **Decision**: one unit sphere and one unit stick mesh, per-item model matrices and colours through `DepthMeshPass`
  (clarification Q5); instanced lit meshes for VisualCoreRendering assessed: at most 74 items, not needed; recorded in
  the contract (G-RENDER).

## D4 — State and migration
- **Decision**: schema 2 (molecule, mode, turn, tilt, zoom); schema 1 migrates to the defaults (clarification Q3).

## D5 — Scope cut
- **Decision**: gestures and panning move to A15-P03 with picking (they share the touch handling); bond-order styling to
  A15-P03 with the panel (contract G-PANEL).
