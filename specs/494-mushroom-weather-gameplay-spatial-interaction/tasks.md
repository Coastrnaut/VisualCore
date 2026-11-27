# Tasks: R02-G20-04 — Mushroom Weather: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G20-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G20-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_494;
tests stay short (< 10 s each). No {owner} tasks. Agents model their files on Microscopic Aurora's (feature 484).

## Phase 1: Setup

- [X] T-R02G2004-001 Baselines on the committed tree after R02-G20-03 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: 2026-11-27 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 after R02-G20-03 (.autonomy/migration/checks/R02-G20-04.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G20-03's
  rendering runs (exit 0)

## Phase 2: Foundational — view orbit, camera, preview, scrubber and picking

- [X] T-R02G2004-002 [P] Add the preview ("nil when no preview": the kind — pod slot with target site or removal, or a — Verified 2026-11-27: 2026-11-27 host-2 exit 0: 165 tests in 18 suites incl. picker (500 seeded points over 3 orbits against an independent pick, drop, moon and cycle rule), orbit camera in view at the corners and 7 aspects, preview equal to the kernel run, ghost pod and scrubber materials (.autonomy/migration/checks/R02-G20-04.host-2.json)
  moonlight level — the previewed arrangement and the previewed run — fields, colony runs, growth and failure — computed
  with the kernel's `MushroomWeatherForest.run`; "presentation only; never in the digest") and
  `previewing(_:level:)` to `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSceneSnapshot.swift`; add
  `MushroomWeatherViewOrbit` ("yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only", `clamped()`),
  `camera(aspect:orbit:)` (yaw about the vertical axis through the authored box centre, pitch about the authored view;
  refit so the box x −1.3 … 1.3, y −1.5 … 1.2, z −0.5 … 0.3 (feature 493's box extended to the moon's depth) stays
  inside the view with at least a 5 % margin at aspects 0.4 … 2.5, the eye distance being the larger of the authored
  distance and the fitting one; the eye outside the box; `camera(aspect:)` equals the authored orbit, bit-identical), the scrubber ("a
  track at y −0.9 from x −0.9 to 0.9 with a mark at the shown cycle", `scrubberY`, `scrubberPoint(_:)`), `podCentre`,
  `ventCentre`, the preview (the previewed run drawn in place of the committed one, the dragged pod as a ghost at its
  target, the moon at the previewed brightness) and camera-taking forest and glow meshes and parts (the existing
  signatures use the authored camera) to `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSceneGeometry.swift`;
  add the `ghostPod` and `scrubber` materials to `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherShaders.swift`;
  create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherPicker.swift` (FR-R02G2004-001 … 005, 007;
  SC-R02G2004-001, 004; `MushroomWeatherPick` pod(slot), site(index), vent(index), moon, scrubber, floor, empty;
  `viewPoint` projects a world point through the drawn camera into view points with the origin top-left, nil behind
  the eye; `pick`: vents (projected frame half-diagonal + 12 points), then pods (projected radius + 12, later slots
  first), then sites (projected ring radius + 12), then the moon (projected radius + 12), then the scrubber within 14
  points of its projected track, else the floor inside the projected floor rectangle, else empty; empty for unusable
  input; `floorPoint`: the view point cast onto the plane z = 0; `dropTarget`: the site whose projected centre is
  nearest the finger within 24 points (lower index on ties), nil when it is the pod's own or another pod's site,
  removal outside the projected floor rectangle, nil otherwise; `moonLevel(start:travel:)`: clamp(start + round(−dy /
  40), 0, 3); `scrubCycle`: round(fraction × cycles run) along the track, clamped) with
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherPickerTests.swift` (an independent pick, drop,
  moon and cycle rule written in the test on 500 seeded points over certified levels and 3 orbits; the allowances at
  their edges; overlapping targets; unusable input) and in
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherSceneGeometryTests.swift` (every element, the
  scrubber and a preview inside the view at the orbit corners and 7 aspects; the previewed run equals the kernel's run;
  no preview identical to R02-G20-03's geometry) and
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherShaderSourceTests.swift` (the new materials);
  agent B; `--name host-2`

## Phase 3: Stories 1 … 4 — pods, vents, moonlight and the scrubber (P1) 🎯

- [X] T-R02G2004-003 [US1] [US2] [US3] [US4] Create — Verified 2026-11-27: 2026-11-27 host-3 exit 0: 172 tests in 19 suites incl. 7 gesture-controller tests (500 seeded scripts at 3 sizes and 3 orbits on playing, won and failed plays against an independent expectation through the adapter; thresholds at their edges; second fingers, cancels and finished plays send no kernel action; orbit and preview change no digest) (.autonomy/migration/checks/R02-G20-04.host-3.json)
  `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherGestureController.swift` (FR-R02G2004-001 … 006,
  008, 009; SC-R02G2004-001 … 003; `MushroomWeatherGestureAction` place(slot, cell), move(slot, cell), remove(slot),
  setVent(index, open), setMoonlight(level), showCycle(cycle), preview(kind), clearPreview, selectSlot(slot),
  resetView, explain(reason); states idle, sitePress, podPress, podDrag, ventPress, moonPress, moonDrag,
  scrubberPress, scrubDrag, floorPress, emptyPress, orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on an
  empty site while playing: `place` in the first free slot, or `explain` with every slot used; on a pod: `selectSlot`
  and `explain` that pods are dragged; on a vent while playing: `setVent` with the other state; on the moon: `explain`
  that the moon is dragged up or down; on the scrubber: `showCycle` in any stage; on the floor or empty space: nothing,
  two such taps off the floor within 0.35 s and 22 points: `resetView`; a press lifted at 0.5 s or later without
  moving: nothing; a scrub drag from the scrubber: `showCycle` on every change from touch-down, any stage; a pod drag
  (≥ 16 points) while playing: `preview` when the drop target changes, `clearPreview` when it becomes no change, and on
  release one `move` or `remove` when the target is a change, else `clearPreview`; a moon drag (≥ 16 points) while
  playing: `preview` of the level under the finger when it changes, and on release one `setMoonlight` when the level
  differs from the current one, else `clearPreview`; outside playing: `explain` once and nothing else; 10 … 16 points:
  nothing; a second finger cancels (clearing a preview) and orbits (yaw 90° per width, pitch 60° per height, clamped;
  a third re-bases); cancelled phases send nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherGestureControllerTests.swift` (500 seeded
  scripted taps, pod drags, vent taps, moon drags and scrubs against an independent expectation over certified levels
  at playing, won and failed plays and 3 orbits, every kernel action applied through the adapter; second fingers,
  cancels and finished plays send no kernel action; orbit and the preview change no digest); agent C; `--name host-3`

## Phase 4: Story 6 — every move without gestures (P1)

- [X] T-R02G2004-004 [P] [US6] Create `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherPanelWinTests.swift`: — Verified 2026-11-27: 2026-11-27 host-4 exit 0: 174 tests in 20 suites incl. panel-win (all 100 certified levels won through one panel action per witness action, in 20 groups of 5, digests and fingerprints equal step by step; panel undo and redo restore digests) (.autonomy/migration/checks/R02-G20-04.host-4.json)
  all 100 certified levels won through panel actions only (FR-R02G2004-010; SC-R02G2004-005; each witness action as
  the panel's one-action placement, vent toggle or moonlight − and +, then Run; never more actions than the budget),
  split so each test is under 10 s, plus panel Undo then Redo restoring the digests; agent D; `--name host-4`

## Phase 5: Story 5 and wiring — orbit, reset, presenter, panel

- [X] T-R02G2004-005 [US5] Wire `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherPresenter.swift` — Verified 2026-11-27: 2026-11-27 sim-27 exit 0 on sim-27.2: 37 tests in 5 suites incl. 11 gesture wiring tests (site tap places, pod drag moves and removes with the drawn preview, vent tap toggles, moon drag sets the moonlight, scrub shows a cycle, orbit and reset change no digest, a refused change is shown and logged, a won play sends nothing and explains) (.autonomy/migration/checks/R02-G20-04.sim-27.json)
  (FR-R02G2004-001 … 011; `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn snapshot;
  placements, moves and removals sent through `pod.place` and `pod.remove`, vents through `vent.set`, the moonlight
  through `moon.set`, cycles through `clock.show`; the preview kept as presentation state and drawn; explain texts for
  a pod tap, a moon tap, a full slot set and a finished play ("The play is over: undo or go to the next level"); a
  refused action shown in the mirror message and logged with its code, with or without the engine's `action.rule.`
  prefix; `resetView()`), `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherForestScene.swift`
  (the orbit's camera and meshes, rebuilt when the orbit or the preview changes) and
  `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherControls.swift` ("Reset view"; a tapped pod
  selects its slot); agent E writes
  `Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherGestureWiringTests.swift` (touches
  through the pointer entry place on a site, move a pod by a drag, remove it off the floor, toggle a vent, set the
  moonlight by a moon drag, scrub the cycle; orbit and reset change no digest; a refused change is shown; a drag on a
  won play sends nothing and says the play is over), given the presenter's exact status and description texts;
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MushroomWeatherExperienceTests`

## Phase 6: Regression, documentation and close

- [X] T-R02G2004-006 Docs: `docs/architecture/mushroom-weather.md` (gestures, the scrubber and the preview), — Verified 2026-11-27: 2026-11-27 docs (architecture gestures and preview, package README, automatedtesting) and round02-host-1, -2, -3c, -3e, -3f exit 0 (.autonomy/migration/checks/R02-G20-04.round02-host-*.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G2004-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G2004-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2004-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2004-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2004-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G2004-007)
- [ ] T-R02G2004-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's contract) → 005 (lead; agent E writes the wiring tests) →
006 … 010, 012. 011 stays open until device testing. Agents may draft in isolated copies before 001 (new files only).
MVP: Story 1. Requirement coverage: FR-001 → 003, 005; FR-002 → 002, 003, 005; FR-003 → 002, 003, 005; FR-004 → 002,
003, 005; FR-005 → 002, 003, 005; FR-006 → 002; FR-007 → 002, 003; FR-008 → 002, 003, 005; FR-009 → 003, 005; FR-010
→ 004, 005; FR-011 → 003, 005 … 010.
