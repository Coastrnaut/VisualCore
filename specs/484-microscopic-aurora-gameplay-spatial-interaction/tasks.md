# Tasks: R02-G19-04 — Microscopic Aurora: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G19-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G19-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_484;
tests stay short (< 10 s each). No {owner} tasks. Agents model their files on Apsides Workshop's as recorded at
R02-G18-04 (`git show <R02-G18-04 record commit>:<path>`).

## Phase 1: Setup

- [X] T-R02G1904-001 Baselines on the committed tree after R02-G19-03 is recorded: `--name baseline-host`, `--name — Verified 2026-11-26: baselines exit 0 on the committed tree after R02-G19-03 (host, timing, round02-1, -2, -3c, -3e, -3f)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G19-03's
  rendering runs (exit 0)

## Phase 2: Foundational — view orbit, camera, preview, scrubber and picking

- [X] T-R02G1904-002 [P] Add the preview ("nil when no preview": slot, target site or removal, previewed wells and the — Verified 2026-11-26: host-2 exit 0: picker (500 seeded points, 3 orbits), view orbit, camera(aspect:orbit:) inside the view at orbit corners x 7 aspects, preview equals the kernel swim, frozen, scrubber, materials 20/21; purity, invariant, scenarios and adapter suites unchanged
  previewed swim — positions, density, lit cells, coverage, coherence, failure — computed with the kernel's
  `MicroscopicAuroraDish.swim`; "presentation only; never in the digest"), `frozen` ("presentation only"),
  `previewing(slot:target:level:)` and `freezing(_:)` to
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSceneSnapshot.swift`; add
  `MicroscopicAuroraViewOrbit` ("yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only", `clamped()`),
  `camera(aspect:orbit:)` (yaw about the vertical axis through the authored box centre, pitch about the authored view;
  refit so the box x −1.0 … 1.0, y −1.35 … 1.0 stays inside the view with at least a 5 % margin at aspects 0.4 … 2.5;
  the eye outside the box; `camera(aspect:)` equals the authored orbit, bit-identical), the scrubber ("a track at
  y −1.31 from x −0.9 to 0.9 with a mark at the shown tick", `scrubberY`, `scrubberPoint(_:)`), `wellCentre`, the
  preview (unfrozen: the previewed swim drawn in place of the committed one and the dragged well as a ghost at its
  target, material 20 `ghostWell`; frozen: the committed swim and the previewed gauge readings), and camera-taking
  `dishMesh`, `glowMesh`, `dishPart`, `glowPart` (the existing signatures use the authored camera) to
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSceneGeometry.swift`; add materials 20
  `ghostWell` and 21 `scrubber` to `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraShaders.swift`;
  create `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraPicker.swift` (FR-R02G1904-001 … 003,
  006; SC-R02G1904-001, 004; `MicroscopicAuroraPick` well(slot), site(index), scrubber, field, empty; `viewPoint`
  projects a world point through the drawn camera into view points with the origin top-left, nil behind the eye;
  `pick`: a well within its projected spiral radius grown by 12 points (later slots first), else a site within its
  projected ring radius grown by 12 points, else the scrubber within 14 points of its projected track, else the field
  inside the projected enclosure, else empty; empty for unusable input; `dishPoint`: the view point cast onto the plane
  z = 0 in dish units; `dropTarget`: the site nearest the finger within 24 points (lower index on ties), nil when it is
  the well's own or another well's site, removal outside the projected enclosure, nil otherwise; `scrubTick`:
  round(fraction × ticks swum) along the track, clamped) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraPickerTests.swift` (an independent pick,
  drop and tick rule written in the test on 500 seeded points over certified levels and 3 orbits; the allowances at
  their edges; overlapping targets; unusable input) and in
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraSceneGeometryTests.swift` (every element,
  the scrubber and a preview inside the view at the orbit corners and 7 aspects; the previewed swim equals the kernel's
  swim; frozen draws the committed swim; no preview identical to R02-G19-03's geometry) and
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraShaderSourceTests.swift` (the new
  materials); agent B; `--name host-2`

## Phase 3: Stories 1, 2 and 3 — wells, scrubber and freeze (P1) 🎯

- [X] T-R02G1904-003 [US1] [US2] [US3] Create — Verified 2026-11-26: host-3 exit 0 against the real picker: 500 seeded scripts match the independent expectation (levels 1, 41, 90; playing, won, failed; 3 sizes, 3 orbits); thresholds, well drags, scrubs, orbit, cancels send no kernel action
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraGestureController.swift` (FR-R02G1904-001 …
  005, 007, 008; SC-R02G1904-001 … 003; `MicroscopicAuroraGestureAction` place(slot, well), move(slot, well),
  remove(slot), showTick(tick), preview(slot, target), clearPreview, toggleFreeze, selectSlot(slot), resetView,
  explain(reason); states idle, sitePress, wellPress, wellDrag, scrubberPress, scrubDrag, fieldPress, emptyPress,
  orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on an empty site while playing: `place` in the first
  free slot with the controller's strength and sense, or `explain` with every slot used; on a well: `selectSlot` and
  `explain` that wells are dragged; on the scrubber: `showTick` in any stage; on the field: `toggleFreeze` in any stage;
  on empty space: nothing, two such taps within 0.35 s and 22 points: `resetView`; a press lifted at 0.5 s or later
  without moving: nothing; a scrub drag from the scrubber: `showTick` on every change from touch-down, any stage; a well
  drag (≥ 16 points) while playing: `preview` when the drop target changes, `clearPreview` when it becomes no change,
  and on release one `move` (same strength and sense) or `remove` when the target is a change, else `clearPreview`;
  outside playing: `explain` once and nothing else; 10 … 16 points: nothing; a second finger cancels (clearing a
  preview) and orbits (yaw 90° per width, pitch 60° per height, clamped; a third re-bases); cancelled phases send
  nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraGestureControllerTests.swift` (500 seeded
  scripted taps, well drags and scrubs against an independent expectation over certified levels at playing, won and
  failed plays and 3 orbits, every kernel action applied through the adapter; second fingers, cancels and finished
  plays send no kernel action; orbit, the freeze and the preview change no digest); agent C; `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [X] T-R02G1904-004 [P] [US5] Create — Verified 2026-11-26: host-4 exit 0: all 100 certified levels won through panel actions within budget (20 groups of 5) and panel undo/redo restores digests
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraPanelWinTests.swift`: all 100 certified
  levels won through panel actions only (FR-R02G1904-009; SC-R02G1904-005; each witness placement as the panel's slot,
  site, strength and sense sending one `well.place`, then Play; never more actions than the budget), split so each test
  is under 10 s, plus panel Undo then Redo restoring the digests; agent D; `--name host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter, panel

- [X] T-R02G1904-005 [US4] Wire `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraPresenter.swift` — Verified 2026-11-26: sim-27 exit 0 on sim-27.2: presenter pointer entry places, moves and removes wells, scrubs, toggles the freeze; orbit and reset change no digest; refusals shown and logged; finished play sends nothing (MicroscopicAuroraExperienceTests)
  (FR-R02G1904-001 … 010; `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn snapshot
  and the panel's strength and sense; placements, moves and removals sent through `well.place` and `well.remove`, ticks
  through `clock.show`; the preview and the freeze kept as presentation state and drawn; explain texts for a well tap, a
  full slot set and a finished play ("The play is over: undo or go to the next level"); a refused action shown in the
  mirror message and logged with its code, reading codes with or without the engine's `action.rule.` prefix;
  `resetView()`, `toggleFreeze()`), `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraDishScene.swift`
  (the orbit's camera and meshes, rebuilt when the orbit, the preview or the freeze changes) and
  `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraControls.swift` ("Freeze" and "Reset view";
  a tapped well selects its slot); agent E writes
  `Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraGestureWiringTests.swift` (touches
  through the pointer entry place on a site, move a well by a drag, remove it off the dish, scrub the tick, toggle the
  freeze; orbit and reset change no digest; a refused change is shown; a drag on a won play sends nothing and says the
  play is over), given the presenter's exact status and description texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing MicroscopicAuroraExperienceTests`

## Phase 6: Regression, documentation and close

- [X] T-R02G1904-006 Docs: `docs/architecture/microscopic-aurora.md` (gestures, the scrubber, the freeze and the — Verified 2026-11-26: docs updated (architecture, round-two README, automatedtesting); round02-host-1, -2, -3c, -3e, -3f exit 0
  preview), `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`,
  `-3c`, `-3e`, `-3f`
- [X] T-R02G1904-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-26: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G1904-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-26: reference-1 exit 0
- [X] T-R02G1904-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-26: reference-2 exit 0 (7 of 7 with chunk 1)
- [ ] T-R02G1904-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1904-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1904-007)
- [ ] T-R02G1904-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's contract) → 005 (lead; agent E writes the wiring tests) →
006 … 010, 012. 011 stays open until device testing. Agents may draft in isolated copies before 001 (new files only).
MVP: Story 1. Requirement coverage: FR-001 → 003, 005; FR-002 → 002, 003, 005; FR-003 → 002, 003; FR-004 → 002, 003;
FR-005 → 003, 005; FR-006 → 002; FR-007 → 002, 003, 005; FR-008 → 003, 005; FR-009 → 004, 005; FR-010 → 005 … 010.
