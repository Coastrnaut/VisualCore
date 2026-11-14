# Research: A05-P04

## D1 — Restoring through actions
- **Decision**: one atomic action `composition.open` carrying the document's values; the core validates them all and
  applies all or nothing.
- **Rationale**: controls change state only through actions; a sequence of existing actions could stop half-way (one
  refused step) and would pass through intermediate presets; one action keeps the digest equality exact.
- **Alternatives**: Particle Universe's action sequence (`openActions()`) — rejected for partial-open risk; restoring an
  engine snapshot from controls — not possible through the port.

## D2 — Library pattern
- **Decision**: copy the `ParticleLibrary` structure (entries by name, unique names with numeric suffix, unreadable and
  newer counted, never deleted, atomic writes, last error message).
- **Rationale**: proven in A04 with its tests; consistent behaviour across experiences.

## D3 — Export path
- **Decision**: `experienceStillRenderer(width:height:)` → `StillImageEncoder.pngData` → in-memory `Transferable` for
  `ShareLink`, long edge 2048 capped by the device, canvas aspect.
- **Rationale**: the Fluid Art pattern; the host renders on its own context; no file means nothing to clean up.

## D4 — Export determinism
- **Decision**: compare decoded pixels (two still renders of an unchanged composition), not PNG bytes.
- **Rationale**: ImageIO does not document byte-stable output; the pixels are what the person sees.

## D5 — GPU stability measurement
- **Decision**: `RenderHost.resources.stats` (ledger snapshot: live counts per kind, leaked) after each full cycle of
  preset changes with a frame drawn after each change; equal after cycles 1–3; zero leaked.
