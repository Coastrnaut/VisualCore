# Tasks: R02-F18 — Procedural terrain mesh and skydome

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F18 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F18 --name <check> -- <command>`. Commit after every task with
its check record (no trailers). No {owner} tasks; one {device} task. Fixture seed 2_018; tests stay short.

## Phase 1: Setup

- [X] T-R02F18-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and the isolated — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F18.baseline-host.json and R02-F18.baseline-timing.json (exit 0); rendering baseline = R02-F17.rendering-27.json and rendering-26.json (exit 0)
  timing run; the rendering baseline is R02-F17's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02F18-002 Create `Packages/VisualCore/Sources/VisualCoreScenes/TerrainError.swift`, `Packages/VisualCore/Sources/VisualCoreScenes/TerrainSettings.swift` ("P 1 … 64; C power of two 4 … 128; s finite — Verified 2026-11-19: lead retest 2026-11-19: R02-F18.host.json (exit 0, full suite); TerrainSettingsTests 4 passed (every terrain and sky refusal with its code; both stored forms round-trip byte for byte; newer, damaged and out-of-range forms refused)
  > 0; L 1 … log₂C; D finite > 0; budget 1 … 4,194,304 (default 262,144); JSON schema 1") and `Packages/VisualCore/Sources/VisualCoreScenes/SkyParameters.swift`
  (SkyError; SkyParameters "sunRadius 0.001 … 0.2 rad; glowStrength 0 … 4; glowExponent 1 … 4,096; all finite; JSON schema
  1", defaults of data-model.md) with `Packages/VisualCore/Tests/VisualCoreScenesTests/TerrainSettingsTests.swift` (every refusal and reason code; both round-trip byte
  for byte; schema 2 and damaged JSON refused); `--name host`

## Phase 3: Story 1 — terrain levels of detail (P1) 🎯

- [X] T-R02F18-003 [P] [US1] Create `Packages/VisualCore/Sources/VisualCoreScenes/TerrainLOD.swift` (TerrainPiece; `select` per clarifications Q1–Q2; `mesh(for:height:)` — Verified 2026-11-19: lead retest 2026-11-19: R02-F18.host.json (exit 0, full suite); TerrainLODTests 9 passed (200 seeded viewpoints: one-level neighbours, budget kept, identical twice, no inversion with the default budget and none unexplained by the one-level rule under tight budgets after the budget rule became quarter-octave distance shrinking; 50 selections at cell size 0.1 crack-free bit for bit after coordinates moved to the global grid index; HeightField heights; edge cases)
  from `HeightField` sampling with stitched coarser-facing edges) with `Packages/VisualCore/Tests/VisualCoreScenesTests/TerrainLODTests.swift` (200 seeded viewpoints:
  neighbours within one level, detail never rising with distance, budget kept, selections identical; 50 seeded selections:
  every shared edge matches bit for bit; one-piece terrain; far viewpoint; budget refusal; heights equal a `HeightField`
  of the same function); `--name host-2`

## Phase 4: Story 2 — erosion masks (P2)

- [X] T-R02F18-004 [P] [US2] Create `Packages/VisualCore/Sources/VisualCoreScenes/ErosionMask.swift` (clarification Q3) with `Packages/VisualCore/Tests/VisualCoreScenesTests/ErosionMaskTests.swift` (flat, tilted — Verified 2026-11-19: lead retest 2026-11-19: R02-F18.host.json (exit 0, full suite); ErosionMaskTests 6 passed (flat, tilted plane, V-valley and pit fixtures with their stated values; 20 seeded terrains bit-identical; every value in 0 … 1)
  plane, V-valley and pit fixtures with their stated values; 20 seeded terrains bit-identical across runs; every value in
  0 … 1); `--name host-3`

## Phase 5: Story 3 — procedural sky (P1)

- [X] T-R02F18-005 [P] [US3] Create `Packages/VisualCore/Sources/VisualCoreScenes/SkyModel.swift` (clarification Q4) with `Packages/VisualCore/Tests/VisualCoreScenesTests/SkyModelTests.swift` (zenith, horizon and — Verified 2026-11-19: lead retest 2026-11-19: R02-F18.host.json (exit 0; SkyModelTests 8 passed) and R02-F18.rendering-27.json (exit 0, full VisualCoreRendering suite on iOS 27.2: SkyShaderTests worst 1/255 over a 64 × 64 grid for 9 sun positions, SkyRendererTests 5 passed (worst 1/255, sky only at far depth, GL state restored, no leak), ShaderBundleTests compiles vc/sky.glsl alone)
  ground colours at their directions; no disc below −r; night darker than day; finite for the sun below, at and above the
  horizon; direction refusals), `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/sky.glsl` (`vc_sky`) with `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SkyShaderTests.swift` (a full grid of
  directions for at least 8 sun positions within 2 of 255 of `SkyModel`; no leak) and `Packages/VisualCoreRendering/Sources/VisualCoreRendering/SkyRenderer.swift` with
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SkyRendererTests.swift` (a known camera: drawn pixels equal `SkyModel` within 2 of 255; drawn only where depth is
  far; state restored; no GPU object after release); add `vc/sky.glsl` to `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ShaderBundleTests.swift` (lead);
  `--name host-4`, `--name rendering-27`

## Phase 6: Story 4 — settings (P2)

Covered by T-R02F18-002 (both settings types round-trip; newer and damaged refused).

## Phase 7: Regression, documentation and close

- [X] T-R02F18-006 No Stage One breakage: `--name rendering-26` and `--name experiences` — Verified 2026-11-20: 2026-11-20 R02-F18.rendering-26.json and experiences.json (exit 0 each, TEST SUCCEEDED; the sky shader and renderer tests also pass on iOS 26.5)
- [X] T-R02F18-007 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-20: 2026-11-20 R02-F18.public-api.json and R02-F18.documented-api.json (exit 0; 3760 baseline lines incl. SkyRenderer, 0 undocumented); docs/architecture/terrain-and-sky.md; sections in both package READMEs; section 13.4 row rendered; validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/terrain-and-sky.md`;
  sections in `Packages/VisualCore/README.md` and `Packages/VisualCoreRendering/README.md`; section 13.4 row R02-F18
  "As built" in `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [X] T-R02F18-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-20: 2026-11-20 .autonomy/migration/checks/R02-F18.reference-1.json (exit 0)
- [X] T-R02F18-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-20: 2026-11-20 .autonomy/migration/checks/R02-F18.reference-2.json (exit 0)
- [ ] T-R02F18-010 Script tests (`--name script-tests`)
- [ ] T-R02F18-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F18-012 {device} Measure the frame cost of a full terrain selection and the sky on D1–D3 and record it in the
  device campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → 002 → {003, 004, 005} in parallel → 006 → … → 011. Agents: A (003), B (004), C (005 except the bundle list).
Shared files (002, the bundle list, docs) stay with the lead. MVP: Stories 1 and 3.
