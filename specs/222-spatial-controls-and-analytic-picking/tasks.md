# Tasks: R02-F22 — Spatial controls and analytic picking

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F22 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F22 --name <check> -- <command>` (never a scratchpad path).
Commit after every task with its check record (no trailers). No {owner} tasks; one {device} task. Fixture seed 2_022
through a fileprivate SplitMix generator; tests stay short.

## Phase 1: Setup

- [X] T-R02F22-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and the isolated — Verified 2026-11-20: 2026-11-20 baseline-host exit 0, baseline-timing exit 0 (.autonomy/migration/checks/R02-F22.baseline-*.json); rendering baseline R02-F21 rendering-27/26 exit 0
  timing run; the rendering baseline is R02-F21's rendering runs (exit 0)

## Phase 2: Foundational — Story 1, a touch becomes a world point (P1) 🎯

- [X] T-R02F22-002 [US1] Create `Packages/VisualCore/Sources/VisualCoreMath/Plane3.swift` (Plane3 "finite; normal not zero", normalised; signedDistance; — Verified 2026-11-20: 2026-11-20 host-r2 exit 0: ScreenProjectionTests 4/4 (959 seeded points, worst distance / camera distance 8.0e-14; plane hits on the plane); the first attempts host and host-rerun failed only to build while agent files were mid-edit (.autonomy/migration/checks/R02-F22.host*.json)
  `Ray3.intersect(plane:)` per clarification Q1), `Packages/VisualCore/Sources/VisualCoreMath/ScreenProjection.swift` (ray(through:viewport:inverseViewProjection:)
  "viewport finite > 0; point inside 0 … w, 0 … h"; project(_:viewProjection:viewport:)) and
  `Packages/VisualCore/Sources/VisualCoreScenes/SpatialControlError.swift` with `Packages/VisualCore/Tests/VisualCoreMathTests/ScreenProjectionTests.swift` (1,000 seeded OrbitCamera views and world
  points: the ray through the projection passes within 1e-9 of the point relative to the scene size; plane hits on the
  plane within 1e-12; parallel and behind rays miss; outside-viewport, non-finite and degenerate inputs give nil; agreement
  with `OrbitCamera.ray(ndc:aspect:)`); `--name host`

## Phase 3: Story 2 — depth-aware picking (P1)

- [X] T-R02F22-003 [P] [US2] Create `Packages/VisualCore/Sources/VisualCoreScenes/SpatialHandles.swift` (HandleKind; SpatialHandle "position finite; hitRadius — Verified 2026-11-20: 2026-11-20 host-2-r2 exit 0: HandlePickerTests 11/11 (200 seeded sets equal the brute-force rule; ties, behind-camera, radius raising, refusals); host-2 failed only to build (.autonomy/migration/checks/R02-F22.host-2*.json)
  finite ≥ 0"; HandlePicker "≤ 1,024 handles; touch radius raised to ≥ 22 points") with `Packages/VisualCore/Tests/VisualCoreScenesTests/HandlePickerTests.swift`
  (200 seeded handle sets equal a brute-force rule, ties by depth then index; handles behind the camera skipped; no
  candidate gives nil; radius raising; a non-finite touch; refusals (.handleLimit, .viewport) and codes); `--name host-2`

## Phase 4: Story 3 — drags (P2)

- [X] T-R02F22-004 [P] [US3] Create `Packages/VisualCore/Sources/VisualCoreScenes/HandleDrag.swift` (DragConstraint; HandleDrag "grazing: plane abs(d · n) < 0.1, — Verified 2026-11-20: 2026-11-20 host-3-r2 exit 0: HandleDragTests 10/10 (400 seeded drags return exactly; grazing holds; bounds; quarter and half turns within 1e-12); host-3 failed only to build (.autonomy/migration/checks/R02-F22.host-3*.json)
  axis abs(d · a) > 0.995"; optional bounds) with `Packages/VisualCore/Tests/VisualCoreScenesTests/HandleDragTests.swift` (seeded drags returning to the start ray
  give the start exactly; plane and axis drags follow the hit; grazing rays hold the last position; a grazing start is
  refused; bounds clamp; rotation angle about the axis for seeded quarter and half turns); `--name host-3`

## Phase 5: Story 4 — undo and redo (P2)

- [X] T-R02F22-005 [P] [US4] Create `Packages/VisualCore/Sources/VisualCoreScenes/ControlHistory.swift` ("depth 1 … 1,000 (default 100); JSON schema 1") with — Verified 2026-11-20: 2026-11-20 host-4-r2 exit 0: ControlHistoryTests 15/15 (50 seeded sequences undo/redo exactly; a 500-event drag is one step; depth bound; round trip; refusals); host-4 failed only to build (.autonomy/migration/checks/R02-F22.host-4*.json)
  `Packages/VisualCore/Tests/VisualCoreScenesTests/ControlHistoryTests.swift` (seeded edit sequences undone fully give the exact start and redone the exact end;
  a 500-event drag is one step; redo cleared by a new edit; depth bound with dropped count; empty undo and redo give nil;
  round trip byte for byte; newer and damaged forms refused); `--name host-4`

## Phase 6: Story 5 — assistive controls (P2)

- [X] T-R02F22-006 [P] [US5] Create `Packages/VisualCore/Sources/VisualCoreScenes/AssistiveStep.swift` ("step finite > 0; range finite, min ≤ max ≤ min + 1e9 · step; — Verified 2026-11-20: 2026-11-20 host-5-r2 exit 0: AssistiveStepTests 8/8 (100 seeded cases return bitwise; limits; descriptions; steps recorded in ControlHistory); host-5 failed to build on the lead's own test (mutating call inside #require), fixed (.autonomy/migration/checks/R02-F22.host-5*.json)
  start inside") with `Packages/VisualCore/Tests/VisualCoreScenesTests/AssistiveStepTests.swift` (100 seeded cases: n up then n down within range return exactly;
  limits do nothing and return nil; descriptions non-empty, locale-independent, decimals from the step; pairs usable in
  `ControlHistory`); `--name host-5`

## Phase 7: Regression, documentation and close

- [ ] T-R02F22-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences` and
  `--name host-full`
- [X] T-R02F22-008 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-20: 2026-11-20 public-api exit 0 (4,006 declarations), documented-api exit 0, docs/architecture/spatial-controls.md, README section, map F22 as built, render_autocreator + validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/spatial-controls.md`;
  section in `Packages/VisualCore/README.md`; section 13.4 row R02-F22 "As built" in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [ ] T-R02F22-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F22-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F22-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02F22-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F22-013 {device} Measure touch accuracy on handles and drive the assistive steps with VoiceOver on D1–D3 and
  record it in the device campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → 002 → {003, 004, 005, 006} in parallel → 007 → … → 012. Agents: A (003), B (004), C (005), D (006). Shared files
(002, docs) stay with the lead. MVP: Stories 1 and 2.
