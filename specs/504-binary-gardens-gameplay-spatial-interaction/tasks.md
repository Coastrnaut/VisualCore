# Tasks: R02-G21-04 — Binary Gardens: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G21-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_504;
tests stay short (< 10 s each). No {owner} tasks. Agents model their files on Mushroom Weather's (feature 494, itself
modelled on feature 484).

## Phase 1: Setup

- [ ] T-R02G2104-001 Baselines on the committed tree after R02-G21-03 is recorded: `--name baseline-host`, `--name
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the quickstart step 1 commands); the
  rendering baseline is R02-G21-03's rendering runs (exit 0)

## Phase 2: Foundational — view orbit, camera, preview, inspection and picking

- [ ] T-R02G2104-002 [P] Add the stored `starSpeed` (ω; default 1 when unchecked), `freedoms`
  (`BinaryGardensStarFreedom` ring, phase, luminosity copied from the level's `ringAdjustable`, `phaseAdjustable`,
  `luminosityAdjustable`; default all adjustable when unchecked), `preview` and `inspectedWorld` (both nil from every
  initialiser; "presentation only; never in the digest"), `starStep(_:tick:)` ((θ + ω·tick) mod 48),
  `previewing(_:level:)`, `clearingPreview()` and `inspecting(_:)` (out of range → nil) to
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSceneSnapshot.swift`, with `BinaryGardensPreview`
  (`change` a `.ring`, `.phase`, `.luminosity` or `.tilt` action; `Outcome` accepted(arrangement, report) or
  refused(`BinaryGardensError`); `report`, `wins`; `of(_:arrangement:actionsLeft:level:)`: the kernel's
  `BinaryGardensSky.changed`, then `.budget` when no action is left, then `BinaryGardensSky.report`; nil for `.run` or
  an unchanged value; never a second law); create
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensViewOrbit.swift` (`BinaryGardensViewOrbit` "yaw ±60°
  about +z through (0, −0.35, 0), pitch −20° … +35°; authored (0, 0); presentation only", `yawLimit`, `yawRange`,
  `pitchRange`, `clamped()` (a non-finite angle clamps to 0), `isWithinBounds`, `corners`); add to
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSceneGeometry.swift` `refitMargin` 0.06,
  `camera(aspect:orbit:)` (refit so the authored box x −1.3 … 1.3, y −1.85 … 1.15, z −0.85 … 0.85 stays inside the
  view with 0.06 per side at aspects 0.4 … 2.5, never closer than the authored distance ≈ 3.60; `camera(aspect:)`
  equals `camera(aspect:orbit: .authored)` bit for bit), the geometry overloads for the drawn eye
  (`paintOrder(_:eye:)`, `luminosityPips(_:_:eye:)`, `worldPips(_:_:eye:)`, `coronaRays(_:_:tier:eye:)`, the
  backdrop centre: billboards facing it, bodies sorted back to
  front from it, cube-sphere quads far-first from it, the backdrop perpendicular to its view axis; the existing
  signatures use the authored eye), `starRadius(_:_:)` made public, `drawnSnapshot(_:)` (the preview applied; itself
  without a preview), `ghostStars(_:)` (the ghost star at the target, refused flag), the ghost bands (the committed
  report's cells as outline strips, `ghostCellWidth` 0.003, behind the previewed worlds and gauges), the inspection
  marks (`inspectRingRadius` 0.115 round the inspected world; `bracketWidth` 0.006, `bracketHalf` 0.05, `bracketLeft`
  −0.962, `bracketRight` 1.232 round its gauge row) and the camera-taking `systemMesh`, `glowMesh`, `systemPart` and
  `glowPart`; add the materials `ghostStar` = 38 (quad, dashed ring by a new angular dash coverage rule, the
  star's colour chosen by `a_normal.z` = star; broken when refused), `ghostCell` = 39 (outline strips, square coverage,
  a valued material added to `isValued` whose value band index / 4 selects BG_LETHAL_LOW … BG_LETHAL_HIGH in the vertex
  shader, `baseColour` and `colour(of:won:)`), `inspectRing` = 40 (quad, joins the ring coverage, marker colour) and
  `inspectBracket` = 41 (strip, square coverage, marker colour), `maxMaterial` = `inspectBracket.rawValue` = 41, to
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensShaders.swift`; create
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensPicker.swift` (FR-R02G2104-004, 007, 009, 010, 012;
  SC-R02G2104-001, 004; `BinaryGardensPick` gauge(world), pips(star), star(star), world(world), ring(index), dial,
  disc, empty; `BinaryGardensStarDragMode` ring, phase; `markerAllowance` 12, `stepTravel` 32, `tangentFloor` 0.5;
  `camera(size:orbit:)`; `viewPoint` projects a world point through the drawn camera into view points with the origin
  top-left, nil behind the eye; `projectedExtent`; `pick` in the reverse of the painter's order: the actions bars as
  empty space, the gauge rows by the finger cast onto z = 0 inside a plate, the bodies front to back from the drawn eye
  (a star's luminosity pip row within 12 points of its projected first-to-last pip segment, then its disc grown by 12
  points; a world's disc grown by 12 points), the star rings within 12 points of their projected 48-gons (later rings
  first), the tilt dial within 12 points of its projected pip segment, the system disc cast onto z = 0 within 0.95,
  else empty; empty for unusable input; `planePoint`; `tangent` (ring vertex step + 1 minus step − 1, projected);
  `dragMode` (along > across → phase, else ring; |tangent| < 0.5 → ring; locks override; nil when both locked);
  `ringTarget`, `phaseTarget` (grid phases at the shown tick), `nearestPip`, `nearestTiltPip` (lower index on ties);
  `stepValue(start:travel:upper:)` clamp(start + round(dx / 32), 0, upper); `gaugeX`, `gaugeTick` (1 … 48, x clamped
  to the cells)) with `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPickerTests.swift` (an
  independent pick written in the test on 500 seeded points over certified levels, 3 sizes and 3 orbits, including 1
  and 5 worlds, 2 and 8 rings, tilt 0 and 6 and a single luminosity level; the allowances at their edges; overlapping
  targets (a star in front of a world, a pip row over a ring); unusable input; the ring, phase, pip, dial and tick
  targets and the tangent rule), `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPreviewTests.swift`
  (200 previews equal to the kernel's `changed` and `report`, or its refusal, in the play's refusal order; unchanged
  and `.run` give no preview), and in
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSceneSnapshotTests.swift` (star speed, freedoms,
  `starStep`, previewing, clearing and inspecting; none of it in the digest; schema 1),
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSceneGeometryTests.swift` (every element, ghost
  and mark inside the view at the orbit corners and 7 aspects 0.4 … 2.5; no preview, no inspection and the authored
  orbit identical to R02-G21-03's geometry; the drawn snapshot equals the kernel's previewed report) and
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensShaderSourceTests.swift` (the materials 38 … 41);
  agent B; `--name host-2 -- swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`

## Phase 3: Stories 1 … 5 — ring and phase drags, luminosity, tilt, inspection and the scrub (P1) 🎯

- [ ] T-R02G2104-003 [US1] [US2] [US3] [US4] [US5] Create
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensGestureController.swift` (FR-R02G2104-001 … 008, 010,
  011, 012; SC-R02G2104-001 … 003; `BinaryGardensGestureAction` setRing(star, index), setPhase(star, step),
  setLuminosity(star, index), setTilt(step), showTick(tick), inspectWorld(world?), selectStar(star), preview(change),
  clearPreview, resetView, explain(reason); states idle, starPress, ringDrag, phaseDrag, pipsPress, luminosityDrag,
  dialPress, tiltDrag, gaugePress, scrubDrag, worldPress, ringPress, discPress, emptyPress, orbiting, cancelled;
  `tapDistance` 10, `dragDistance` 16, `tapDuration` 0.5 s, `doubleTapWindow` 0.35 s, `doubleTapDistance` 22,
  `yawPerViewWidth` π / 2, `pitchPerViewHeight` π / 3; the reasons `finishedReason` "The play is over: undo or go to
  the next level", `notRunningReason`, `starReason`, `ringReason`, `fixedReason`, `luminosityLockedReason`,
  `singleLevelReason` with the contract's exact texts; a tap (< 10 points, lifted before 0.5 s) on a star:
  `selectStar` and `explain` that stars are dragged; on a world: `inspectWorld` (a second tap on the inspected world clears it) in any stage; on a gauge row:
  `inspectWorld` of its world (no toggle) and, when the cast x ≤ 0.95 and the press did not scrub, `showTick` of the
  column under the finger, in any stage; on the luminosity pips while playing: `setLuminosity` of the nearest pip
  when it differs, `explain` when locked or a single level; on the tilt dial while playing: `setTilt` of the nearest
  pip when it differs; on a ring: `explain` the ring reason; on the disc: nothing (and it breaks a double tap); on empty space: nothing, two such taps within 0.35 s and 22
  points: `resetView`; a press lifted at 0.5 s or later without moving: nothing; a star drag (≥ 16
  points) while playing: its mode decided once by `dragMode`, then `preview` of `star.ring` or `star.phase` when the
  target changes, `clearPreview` when it returns to the committed value, and on release one `setRing` or `setPhase`
  when the target differs, else `clearPreview`; both locked: `explain` the fixed reason; a pip or dial drag sideways
  while playing: `preview` of `stepValue` when it changes and on release one `setLuminosity` or `setTilt` when it
  differs, else `clearPreview`; a gauge press: the tick read at touch-down (nothing sent), then `showTick` on every later change of the tick (cast x
  clamped to the cells), any stage; outside
  playing: `explain` once and no kernel action; 10 … 16 points: nothing; a second finger cancels (clearing a preview)
  and orbits (yaw 90° per width, pitch 60° per height, clamped; a third re-bases); cancelled phases send nothing; only
  event timestamps read; `camera(viewSize:)`, `cancel()`, `resetView()`) with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensGestureControllerTests.swift` (500 seeded scripted
  taps, star drags in both modes, luminosity and tilt drags, world taps and scrubs on playing, won, failed and paused
  plays at 3 sizes and 3 orbits against an independent expectation, every kernel action applied through the adapter;
  thresholds at their edges; locks and a single luminosity level explained; second fingers, cancels and finished
  plays send no kernel action; orbit, preview, inspection and scrubbing change no digest); agent C; `--name host-3 --
  swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`

## Phase 4: Story 7 — every move without gestures (P1)

- [ ] T-R02G2104-004 [P] [US7] Create `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPanelWinTests.swift`:
  all 100 certified levels won through panel actions only (FR-R02G2104-013; SC-R02G2104-005; each witness action of
  `docs/games/binary-gardens/levels/NNN.witness.json` as the selected star and its direct ring, phase, luminosity or
  tilt choice — one `star.ring`, `star.phase`, `star.luminosity` or `orbit.tilt` — then Run; never more actions than
  the budget; digests and fingerprints equal to the witness step by step), in groups so each test is under 10 s, plus
  panel Undo then Redo restoring the digests; agent D; `--name host-4 -- swift test --package-path
  Packages/ExperiencesRound02 --filter BinaryGardens`

## Phase 5: Story 6 and wiring — orbit, reset, presenter, scene, panel

- [ ] T-R02G2104-005 [US6] Wire `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensPresenter.swift`
  (FR-R02G2104-001 … 016; `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn snapshot
  (the core's snapshot with the `BinaryGardensMirror`'s preview and inspection applied); ring, phase, luminosity and
  tilt changes sent through `star.ring [star, index]`, `star.phase [star, step]`, `star.luminosity [star, index]` and
  `orbit.tilt [step]` (each dropping the preview), ticks through `clock.show [tick]`; `preview`, `inspectedWorld`,
  `phaseTarget` and the selected star kept in the mirror; explain texts in the mirror message; a refused action shown
  in words through `BinaryGardensMirror.refusalText(code:)` and its bare code kept in `refusalLog` (at most 64), with
  or without the engine's `action.rule.` prefix; `resetView()`, `cancelPointers()`, `orbit`, `gestureState`,
  `gestureActions` = `["star.ring", "star.phase", "star.luminosity", "orbit.tilt", "clock.show"]`, `nativeActions` =
  every declared control; the inspected world's kernel words at the shown tick in `describe(_:)`; an opening,
  `level.next`, reset or restore clears the preview, the inspection and the orbit),
  `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensSystemScene.swift` (`orbit`, and the orbit, aspect, preview and inspection in its `GeometryKey`; meshes from the camera-taking builders at `camera(aspect:orbit:)`,
  rebuilt when any of them changes) and `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensControls.swift`
  (every row kept; Ring picker 1 … n, Luminosity picker 1 … L, Phase target stepper by g with "Set phase", Tilt picker
  0 … T_max when T_max > 0, "Inspect" none or world 1 … W with the inspected world's words below it, "Reset view"; each
  ring, luminosity, tilt and Set phase choice sends one action; Inspect and Reset view are presentation only; the panel
  is built by `makeControls` with a send closure through the presenter's `send` (refusals shown and logged in
  `refusalLog`) and a `resetView` closure, as in feature 494); agent E writes
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensGestureWiringTests.swift` (through the
  pointer entry: a radial star drag moves it to a ring with the drawn preview, a tangential drag shifts its phase, a
  pip tap and a pip drag set the luminosity, a dial tap and drag set the tilt, a world tap inspects (marks drawn, words
  given) and a second tap clears, a gauge scrub shows ticks, two fingers orbit and a double tap resets (no digest
  change), a refused change (separation or no action left) is previewed as refused, sent once, shown and logged with
  its code, a drag on a won play sends nothing and says the play is over; reusing
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensTestSupport.swift`), given the presenter's
  exact status and description texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  BinaryGardensExperienceTests`

## Phase 6: Regression, documentation and close

- [ ] T-R02G2104-006 Docs: `docs/architecture/binary-gardens.md` (gestures, the preview, the ghost star and bands, the
  inspection marks and the orbit), `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name
  round02-host-1`, `-2`, `-3c`, `-3e`, `-3f` (the baseline commands of quickstart step 1)
- [ ] T-R02G2104-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit` (the quickstart step 5 commands)
- [ ] T-R02G2104-008 Reference regression chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only
  reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [ ] T-R02G2104-009 Reference regression chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27
  projectm-reference-ios26`)
- [ ] T-R02G2104-010 Script tests, run alone (`--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-R02G2104-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G2104-008)
- [ ] T-R02G2104-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's contract) → 005 (lead; agent E writes the wiring tests) →
006 … 010, 012. 011 stays open until device testing. Agents may draft in isolated copies before 001 (new files only).
MVP: Story 1. Requirement coverage: FR-001 → 002, 003, 005; FR-002 → 002, 003, 005; FR-003 → 002, 003, 005; FR-004 →
002, 003, 005; FR-005 → 002, 003, 005; FR-006 → 002, 003, 005; FR-007 → 002, 003, 005; FR-008 → 002, 003, 005; FR-009 →
002; FR-010 → 002, 003, 005; FR-011 → 003, 005; FR-012 → 002, 003; FR-013 → 004, 005; FR-014 → 003, 005 … 010; FR-015
→ 002, 005; FR-016 → 002, 005.
