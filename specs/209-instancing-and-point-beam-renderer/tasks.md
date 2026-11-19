# Tasks: R02-F09 — Instancing and point/beam renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F09 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks; large instance counts on D1–D3 are a {device} campaign item.

## Phase 1: Setup

- [X] T-R02F09-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F09.{baseline-host,baseline-rendering}.json (exit 0)
  `--name baseline-rendering --` the VisualCoreRendering scheme on sim-27.2

## Phase 2: Foundational (pure)

- [X] T-R02F09-002 [P] Create `Packages/VisualCore/Sources/VisualCoreScenes/InstanceOrder.swift` (`backToFront(depths:)`: — Verified 2026-11-19: migration_ledger run-check R02-F09/host exit=0 (swift test, InstanceOrderTests + BeamProfileTests)
  ascending view-space z, ties by index, non-finite refused with `MeshError.invalidInput`) and
  `Packages/VisualCore/Sources/VisualCoreScenes/BeamProfile.swift` (`falloff(r)` = exp(−4 r²) for r ≤ 1 else 0,
  `distanceToSegment`, `coverage`), with `Packages/VisualCore/Tests/VisualCoreScenesTests/InstanceOrderTests.swift`
  (scrambled orders, ties keep order, empty, non-finite) and `BeamProfileTests.swift` (falloff values and continuity,
  distance to segment interior/ends/degenerate, coverage of a zero-length beam is a round disc); `--name host`

## Phase 3: Stories 1–3 — the renderers (P1) 🎯

- [X] T-R02F09-003 [US1] [US3] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/InstancingError.swift` — Verified 2026-11-19: lead retest: R02-F09/rendering-27 exit=0, 219 tests 0 failures incl. InstancedMeshRendererTests (500 instances = 500 MeshRenderer draws, max 0/255)
  and `InstancedMeshRenderer.swift` (`MeshInstance`; per-instance matrix at locations 3–6 and colour at 7, divisor 1,
  reset after the draw; one `vcglDrawElementsInstanced`; shader of `MeshRenderer` with the instance matrix; fog;
  translucent: sorted with `InstanceOrder`, premultiplied blending, depth write off; limit 16,384; reused buffer;
  internal `drawCallCount`) with
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/InstancedMeshRendererTests.swift` (500 instances equal
  500 `MeshRenderer` draws within 1/255 with depth on; one draw call; above the limit refused with nothing drawn;
  non-finite refused; scrambled translucent orders equal the sorted picture; equal depths keep order; 100 frames keep
  live counts constant; context rebuild gives the same picture)
- [X] T-R02F09-004 [US2] [US3] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/BeamRenderer.swift` — Verified 2026-11-19: lead retest: R02-F09/rendering-27 exit=0 incl. BeamRendererTests (4,096 px vs BeamProfile.coverage, max 0.54/255, tolerance 2/255)
  (`Beam`, `BeamBlend`; strip per clarification Q2 with the end-on fallback; Gaussian falloff; premultiplied sorted by
  midpoint depth or additive unsorted; depth test on, write off, culling off, state restored; limit 65,536; reused
  buffer; internal `drawCallCount`) with `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/BeamRendererTests.swift`
  (cross-section and point match `BeamProfile` within 2/255 at sampled pixels; full width at an oblique angle; end-on
  beam is a round point; zero width and non-finite refused; scrambled translucent beams equal sorted; additive order
  free; one draw call; context rebuild same picture)
- [X] T-R02F09-005 Simulator runs: `--name rendering-27` and `--name rendering-26` — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F09.rendering-27.json and R02-F09.rendering-26.json (exit 0, 219 tests, 0 failures each)

## Phase 4: Regression, documentation and close

- [X] T-R02F09-006 No Stage One breakage: `--name experiences --` ExperiencesCreative on sim-27.2 — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F09.experiences-2.json (exit 0) after renaming Beam to BeamInstance (research R6; first attempt R02-F09.experiences exit 65, LightMazeCore.Beam ambiguous); rendering re-run R02-F09.rendering-27-2.json exit 0
- [X] T-R02F09-007 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-19: 2026-11-19 R02-F09.public-api.json and R02-F09.documented-api.json (exit 0; 3228 declarations, 0 undocumented); READMEs and section 13.4 note rendered; validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; section in
  `Packages/VisualCoreRendering/README.md`; section 13.4 row R02-F09 "As built" (also correcting the ParticleSystem
  home to VisualCoreSimulation) in `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [X] T-R02F09-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F09.reference-1.json (exit 0)
- [X] T-R02F09-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F09.reference-2.json (exit 0)
- [X] T-R02F09-010 Script tests (`--name script-tests`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F09.script-tests.json (exit 0)
- [ ] T-R02F09-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  R02-F09; README.md and `docs/automatedtesting.md`

## Dependencies

001 → 002 → {003, 004} → 005 → 006 → 007 → 008 → 009 → 010 → 011.

## Parallel examples

- **Agent P:** 002. **Agent G:** 003 then 004 (one builder). **Lead:** 001, 005–011.

## Phase 5: Convergence

- [X] T-R02F09-012 Add `testOneHundredFramesKeepLiveCountsConstant` to — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F09.rendering-27-3.json (exit 0, 220 tests, BeamRendererTests.testOneHundredFramesKeepLiveCountsConstant passed)
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/BeamRendererTests.swift` (100 frames alternating 500 and
  300 beams: `liveCount`, `liveBytes` and `compileCount` constant, 100 draw calls, no GL error, 0 leaks after destroy);
  rerun `--name rendering-27-3` per SC-R02F09-004 (partial)
