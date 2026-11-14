# Research: A08-P02 (feature 062)

## 0. Verified facts (2026-11-14)

- `Primitive` has four cases; only `SceneGraph.swift` (`bounded`, `contains`) and `PrimitiveRenderer.triangles`
  switch over it in the repository; `.line` gives six vertices (one quad); `PrimitiveRenderer` uploads one triangle
  batch per draw and reports `lastTriangleCount`; `PrimitiveRendererTests` run on the simulator.
- The A08-P01 presenter draws `sampleCount − 1` `.line` nodes per channel (`lastSegmentCounts`) in pixel units.
- `ScopeState` is schema 1 with a `MigrationChain(currentVersion: 1)` in `ScopeCore`; A07's registry stores schema
  examples (`OdysseyCore.schemaOneExample()`) for the migration check.

## 1. Decisions

- **D1 Polyline as a new primitive case (clarification 1):** reuses the batch, transform and colour path; quads per
  segment equal the old per-segment drawing pixel for pixel. Alternatives rejected: a separate strip renderer (second
  drawing path) or more polygon points (filled, ≤ 256).
- **D2 Column rule (clarification 2):** column = ⌊i × N / count⌋, min/max per column, identity when count ≤ N; the
  zig-zag (min, max per column) keeps every peak with ≤ 2 N points.
- **D3 XY (clarification 4):** one polyline through (l·g, r·g) clamped to ±1 in a centred square; mono windows never
  plot XY.
- **D4 Schema 2 (clarification 5):** `display` field; migration adds `waveform`; `display.select` is accepted by the
  core in any state, the presenter shows the waveform with the "XY needs two channels" mark for mono windows (keeps
  snapshots deterministic and independent of the live source).
- **D5 Flat-line fixture (convergence T-A08-218):** no action selects silence, so the flat line is proved by
  `ScopeSessionTests.testAFlatLineNeverTriggersAndNormalModeWaits` with an injected silent source (auto "no trigger",
  normal "waiting"); the manifest carries the missing crossing (fixture 3 normal, fixture 6 auto) and XY (fixture 7),
  and `testAMissingCrossingNeverTriggersAndNormalModeKeepsTheLastTrace` proves the missing crossing in both modes.
  **Hairlines (T-A08-217):** a polyline is never drawn thinner than one pixel on screen.
