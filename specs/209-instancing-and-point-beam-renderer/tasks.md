# Tasks: R02-F09 — Instancing and point/beam renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F09 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks; large instance counts on D1–D3 are a {device} campaign item.

## Phase 1: Setup

- [ ] T-R02F09-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and
  `--name baseline-rendering --` the VisualCoreRendering scheme on sim-27.2

## Phase 2: Foundational (pure)

- [ ] T-R02F09-002 [P] Create `Packages/VisualCore/Sources/VisualCoreScenes/InstanceOrder.swift` (`backToFront(depths:)`:
  ascending view-space z, ties by index, non-finite refused with `MeshError.invalidInput`) and
  `Packages/VisualCore/Sources/VisualCoreScenes/BeamProfile.swift` (`falloff(r)` = exp(−4 r²) for r ≤ 1 else 0,
  `distanceToSegment`, `coverage`), with `Packages/VisualCore/Tests/VisualCoreScenesTests/InstanceOrderTests.swift`
  (scrambled orders, ties keep order, empty, non-finite) and `BeamProfileTests.swift` (falloff values and continuity,
  distance to segment interior/ends/degenerate, coverage of a zero-length beam is a round disc); `--name host`

## Phase 3: Stories 1–3 — the renderers (P1) 🎯

- [ ] T-R02F09-003 [US1] [US3] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/InstancingError.swift`
  and `InstancedMeshRenderer.swift` (`MeshInstance`; per-instance matrix at locations 3–6 and colour at 7, divisor 1,
  reset after the draw; one `vcglDrawElementsInstanced`; shader of `MeshRenderer` with the instance matrix; fog;
  translucent: sorted with `InstanceOrder`, premultiplied blending, depth write off; limit 16,384; reused buffer;
  internal `drawCallCount`) with
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/InstancedMeshRendererTests.swift` (500 instances equal
  500 `MeshRenderer` draws within 1/255 with depth on; one draw call; above the limit refused with nothing drawn;
  non-finite refused; scrambled translucent orders equal the sorted picture; equal depths keep order; 100 frames keep
  live counts constant; context rebuild gives the same picture)
- [ ] T-R02F09-004 [US2] [US3] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/BeamRenderer.swift`
  (`Beam`, `BeamBlend`; strip per clarification Q2 with the end-on fallback; Gaussian falloff; premultiplied sorted by
  midpoint depth or additive unsorted; depth test on, write off, culling off, state restored; limit 65,536; reused
  buffer; internal `drawCallCount`) with `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/BeamRendererTests.swift`
  (cross-section and point match `BeamProfile` within 2/255 at sampled pixels; full width at an oblique angle; end-on
  beam is a round point; zero width and non-finite refused; scrambled translucent beams equal sorted; additive order
  free; one draw call; context rebuild same picture)
- [ ] T-R02F09-005 Simulator runs: `--name rendering-27` and `--name rendering-26`

## Phase 4: Regression, documentation and close

- [ ] T-R02F09-006 No Stage One breakage: `--name experiences --` ExperiencesCreative on sim-27.2
- [ ] T-R02F09-007 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; section in
  `Packages/VisualCoreRendering/README.md`; section 13.4 row R02-F09 "As built" (also correcting the ParticleSystem
  home to VisualCoreSimulation) in `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [ ] T-R02F09-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F09-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F09-010 Script tests (`--name script-tests`)
- [ ] T-R02F09-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  R02-F09; README.md and `docs/automatedtesting.md`

## Dependencies

001 → 002 → {003, 004} → 005 → 006 → 007 → 008 → 009 → 010 → 011.

## Parallel examples

- **Agent P:** 002. **Agent G:** 003 then 004 (one builder). **Lead:** 001, 005–011.
