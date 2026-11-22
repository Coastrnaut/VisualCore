# Tasks: R02-G08-04 — Faceted Forge: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G08-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G08-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_374;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0804-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline = R02-G08-03 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G08-03's rendering runs (exit 0)

## Phase 2: Foundational — orbit and picking

- [X] T-R02G0804-002 [P] Add `FacetedForgeOrbit` ("yaw ±40°, pitch 10° … 60°, authored (0, 30°)") and — Verified 2026-11-22: 2026-11-22: host-2 (FacetedForgePickerTests, FacetedForgeSceneGeometryTests, invariant tests, 37 tests) exit 0, rerun by the lead; framing sphere 1.65; meshes emitted back to front for the orbit's eye; tilt snaps n·c to 1e-6 before rounding
  `camera(_:aspect:orbit:)` (distance refit to the framing sphere of radius 1.65 with a 5 % margin, the cut-mark row
  included; `camera(_:aspect:)` equals the authored orbit, bit-identical) to
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSceneGeometry.swift`; create
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgePicker.swift` (touch ray through the drawn camera; the
  opened preview rim within 22 points of its projected outline first, then the preview polygon (ray hit or inside its
  projection), then the nearest opened face polygon of a piece, then a projected opened piece centre within 22 points,
  ties to the lower index; `tilt`: normalize(n0 + (dx·R − dy·U) · 2 / min(width, height)), the direction of largest
  |dot| (ties to the lower index), the depth nearest round(n·c) among the crossing depths, c the preview centre in
  kernel coordinates (the middle crossing depth without a preview); `depthSteps`: round(s / 24) with s the drag along
  the projected normal) with `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgePickerTests.swift` (an
  independent pick, tilt and step written in the test on 500 seeded points over certified levels, sizes and orbits;
  minimum target) and orbit framing in
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeSceneGeometryTests.swift`; agent B; `--name host-2`

## Phase 3: Stories 1 to 3 — choose, tilt, slide, commit (P1) 🎯

- [X] T-R02G0804-003 [US1] [US2] [US3] Create — Verified 2026-11-22: 2026-11-22: host-3 (all FacetedForge host tests, 157, incl. 8 gesture controller tests with 500 seeded scripts) exit 0, rerun by the lead; the default plane now faces the authored camera (direction z), added to the spec's edge cases
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeGestureController.swift` (states idle, rimDrag, depthDrag,
  planePress, piecePress, orbiting, cancelled; a tap (< 10 points, ≤ 0.5 s) on a piece outside the preview: `choose`
  that piece at the middle crossing depth of the current direction; a rim drag (≥ 16 points): the candidate tilt while
  moving, `choose` it on release; a depth drag: candidate steps while moving, `choose` on release; a tap on the preview
  while playing: `cut(piece, direction, depth)` unless within 0.35 s of the previous commit; on a finished play no cut;
  a double tap (≤ 0.35 s, ≤ 22 points) on empty space: `resetView`; 10 … 16 points: nothing; a second finger cancels
  (the candidate dropped) and orbits (yaw 90° per width, pitch 60° per height, clamped), a third re-bases; cancelled
  phases send nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeGestureControllerTests.swift` (500 seeded scripted
  taps and drags against an independent expectation over 3 sizes and 3 orbits; second fingers, cancels and finished
  plays send no cut; 10 … 16 points change nothing; a double tap on the plane cuts once; choices and orbit change no
  digest); agent C; `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [X] T-R02G0804-004 [P] [US5] Create — Verified 2026-11-22: 2026-11-22: host-4 (FacetedForgePanelWinTests: 100 levels won through panel actions in 10 cases, undo/redo digests) exit 0, rerun by the lead
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgePanelWinTests.swift`: all 100 certified levels won
  through panel actions only (the piece picker, direction picker and depth − and + move a `FacetedForgePreviewChoice` to
  each certified cut's piece, direction and depth, then Cut sends `piece.cut`), split so each test is under 10 s, plus
  panel Undo then Redo after a cut restoring the digests before and after it; agent D; `--name host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter

- [X] T-R02G0804-005 [US4] Wire `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgePresenter.swift` — Verified 2026-11-22: 2026-11-22: sim-27 (FacetedForgeExperienceTests, 38 tests incl. 7 gesture wiring tests, iOS 27.2) exit 0
  (`pointer(_:viewSize:port:)` routing through the gesture controller, `choose` setting the mirror's choice, `cut` sent
  through the port, `resetView()`, the descriptions "The cut plane would tilt to direction …" / "would move to depth …"
  and, for a commit on a finished play, "The play is over: undo or go to the next level"; a gesture's refused action
  shown in the mirror message like the panel's and logged with its code; fingers counted so only a one-finger touch can
  commit), `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeCrystalScene.swift` (the orbit's camera; the
  candidate choice drawn while dragging; the fallback follows) and
  `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeControls.swift` ("Reset view"); agent E writes
  `Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeGestureWiringTests.swift` (touches through the
  pointer entry change the choice and send the expected cut; orbit and reset change no digest; a refused gesture action
  is shown); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing FacetedForgeExperienceTests`

## Phase 6: Regression, documentation and close

- [X] T-R02G0804-006 Docs: `docs/architecture/faceted-forge.md` (gestures), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-22: 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; architecture, package README and testing doc updated
  `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0804-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: 2026-11-22: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0804-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: 2026-11-22: reference-1 exit 0
- [X] T-R02G0804-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-22: 2026-11-22: reference-2 exit 0
- [X] T-R02G0804-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-22: 2026-11-22: script-tests (run alone) exit 0
- [ ] T-R02G0804-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G0804-007)
- [ ] T-R02G0804-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's picker) → 005 (lead; agent E writes the wiring tests) →
006 … 010, 012. 011 stays open until device testing. Shared files (presenter, scene, controls, docs) stay with the
lead. MVP: Stories 1, 2, 3 and 5.

## Phase 7: Convergence

- [X] T-R02G0804-013 Say when the plane misses the chosen piece per the Spec's edge case "A direction whose plane crosses — Verified 2026-11-22: 2026-11-22: sim-27-2 (39 tests incl. aPlaneThatMissesThePieceIsNamed) exit 0; it overlapped the chain's rendering-26 for 12 s on another simulator (rule breach noted, rendering-26 read separately)
  the chosen piece at no integer depth" (partial): in `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgePresenter.swift`
  the mirror's depth label reads "the plane misses this piece" and the description says "The cut plane misses piece N in
  direction …" when no depth of the chosen direction crosses the chosen piece; cover it in
  `Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeGestureWiringTests.swift`; `--name sim-27-2`
