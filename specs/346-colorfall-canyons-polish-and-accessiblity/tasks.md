# Tasks: R02-G05-06 — Colorfall Canyons: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_346;
tests stay short (< 10 s each). No GLSL change. {device} items (hearing, feeling, VoiceOver on hardware) are D1–D3
observations after ImplementationLock-100.

## Phase 1: Setup

- [X] T-R02G0506-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing`; add the — Verified 2026-11-21: 2026-11-21 baseline-host, baseline-timing, baseline-round02 exit 0; VisualCoreAudioDSP added to ColorfallCanyonsCore and tests, VisualCoreAudio to the experience; package build exit 0 (.autonomy/migration/checks/R02-G05-06.*.json)
  `VisualCoreAudioDSP` product to the `ColorfallCanyonsCore` target in `Packages/ExperiencesRound02/Package.swift` (and to
  its test target); `--name package -- swift build --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — VoiceOver play (P1) 🎯

- [X] T-R02G0506-002 [P] [US1] [US3] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsFeedbackPlan.swift` ("after(old:new:)" texts — Verified 2026-11-21: 2026-11-21 host exit 0: 10 tests (exact announcement texts, kinds and haptics for carves, valves, steps, undo, redo, refusals of every code, campaign and practice wins, time failure, level and mode changes, tutorial, cell picks, summary) (.autonomy/migration/checks/R02-G05-06.host.json); lead retest
  and kinds of clarification Q1: carve "Carved row r, column c. n actions left."; valve "<Colour> valve open." / "closed."
  with the same suffix; step "Tick t of T. f of m basins filled."; "Undone. " / "Redone. " + "Tick t of T. n actions
  left."; "picked(cell:columns:)" "Row r, column c picked." (state, no haptic); win "Every basin is filled. Level won
  with s actions, k of 3 stars." (no stars in practice); failure = the feature-345 explanation; level or mode change
  "Level n, band b, <mode>." plus the tutorial instruction; haptics of Q2 with outcome over selection (a step that wins
  or fails plans only the outcome); "refused(code:)" and "refusalText(code:)" words for r02-g05.locked, r02-g05.date,
  r02-g05.action, r02-g05.budget, r02-g05.stage, r02-g05.not-whole, otherwise "That change was refused.";
  "summaryText(core:)" for the summary element of Q5) with
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsFeedbackPlanTests.swift` (agent A: scripted sequences of carves, valves,
  steps, undo, redo, refusals, wins, failures, level and mode changes: exact texts, kinds and haptics; no plan for an
  unchanged core); `--name host`

## Phase 3: Story 2 — comfort settings (P1)

- [X] T-R02G0506-003 [P] [US2] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsLights.swift` ("sheets keyed by cell: target — Verified 2026-11-21: 2026-11-21 host-2 exit 0: 7 lights tests (scripted win and adversarial flicker at 60 Hz under Reduce Flashing: <= 3 half-range crossings per second, one-way fades >= 0.4 s; normal 0.15 s; settle; emptied sheet keeps weights) (.autonomy/migration/checks/R02-G05-06.host-2.json); fade rule: each fade takes its full duration (research R3); lead retest
  0.35 + 0.65 · min(volume, 24) / 24, 0 when empty, with the last colour weights; emitters 1 flowing, 0.3 not; glow 1
  when won; linear 0.15 s, or 0.45 s under Reduce Flashing where a started fade completes before turning back; a sheet
  at 0 with target 0 is dropped"; settle; step; isSettled; maxHalfRangeCrossingsPerSecond) with
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsLightsTests.swift` (agent B: a scripted win and adversarial flicker (a valve
  toggled and undone every frame; steps of 1 tick; a retry) at 60 Hz: at most 3 half-range crossings per second and
  every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing; normal mode reaches targets in 0.15 s;
  settle jumps; an emptied sheet keeps its weights while fading); `--name host-2`
- [X] T-R02G0506-004 [US2] Edit `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSceneGeometry.swift` (fluidPart, fluidMesh, — Verified 2026-11-21: 2026-11-21 host-geometry exit 0: 17 scene geometry tests incl. settled lights equal to feature 343's streams and an emptied sheet fading with its remembered weights (.autonomy/migration/checks/R02-G05-06.host-geometry.json)
  featurePart and featureMesh take optional lights: sheet brightness and emitter brightness from the lights, fading
  sheets drawn with their remembered weights, a waterfall following the cell it falls from; no lights = feature 343's meshes exactly) with tests in
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsSceneGeometryTests.swift`; `--name host-geometry`

## Phase 4: Story 3 — sound and haptics (P2)

- [X] T-R02G0506-005 [P] [US3] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSoundRecipe.swift` ("root 98 Hz; cyan 98 × 3/2, — Verified 2026-11-21: 2026-11-21 host-3 exit 0: 6 sound recipe tests (equal for equal basins and stage, differs by fill and stage, root alone without fluid, 1,400 valid recipes over all 100 witness start and solution states in 7 stages) (.autonomy/migration/checks/R02-G05-06.host-3.json); lead retest
  coral 98 × 5/4, yellow 98 × 2 for each colour present in a basin, gain base × (0.3 + 0.7 · share); the root alone with
  no basin fluid; won adds an octave, failed halves the gains, 10 s") with
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsSoundRecipeTests.swift` (agent B: equal for equal basins and stage; differs
  for a fill or stage change; every recipe valid for `AmbientLoopRecipe`'s bounds over every certified level's start and
  solution states in every stage); `--name host-3`

## Phase 5: Wiring (presenter, panel, scene, sound)

- [X] T-R02G0506-006 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsSound.swift` (wanted, on screen, — Verified 2026-11-21: 2026-11-21 sim-27-2 exit 0: ColorfallCanyonsExperienceTests 43 tests in 7 suites on sim-27.2 incl. 8 accessibility tests (recorded announcements and haptics, level 1 won with panel operations, drag highlight not announced, sound state table, lights fading under Reduce Flashing, Reduce Motion stills, summary) (.autonomy/migration/checks/R02-G05-06.sim-27-2.json; the first attempt sim-27 exit 65: a test-target import and the old refusal wording, both fixed); lead run
  active; injected player for tests; recipe offered at level openings, changes of the basins or stage and when turned on)
  and edit `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsPresenter.swift` (route
  `ColorfallCanyonsFeedbackPlan` after each described change, cell pick and refusal through `feedback`, a feedback log,
  the eased lights stepped per frame into the scene, the sound, `sceneActive(_:)`),
  `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsCanyonScene.swift` (sheets and emitters from the presenter's lights; win glow
  scales the glow gain, clamped by `u_glowLimit`; fluid and feature geometry rebuilt while a fade runs),
  `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsControls.swift` (labels and values of every control, summary element,
  refusals in words, Sound toggle, wrapping rows at accessibility sizes, 520-point width on iPad, the scene phase reported
  to `sceneActive`) and create `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsAccessibilityTests.swift` (agent C:
  recorded announcements and haptics through the presenter; level 1 won with the cell picker, Carve, valves and Run; a
  drag highlight is not announced, its released carve is; the sound state table, including a player that fails to
  start; labels and values; lights fade under Reduce Flashing in drawn frames; Reduce Motion stills identical);
  `--name sim-27`

## Phase 6: Regression, documentation and close

- [X] T-R02G0506-007 Docs: `docs/architecture/colorfall-canyons.md` (polish and accessibility), — Verified 2026-11-21: 2026-11-21 docs updated (architecture polish and accessibility, package README, testing lesson); round02-host exit 0 (.autonomy/migration/checks/R02-G05-06.round02-host.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0506-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G05-06.*.json)
  `--name host-full`, `--name app-unit`
- [X] T-R02G0506-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0 (.autonomy/migration/checks/R02-G05-06.reference-1.json)
- [X] T-R02G0506-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0 (.autonomy/migration/checks/R02-G05-06.reference-2.json)
- [ ] T-R02G0506-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0506-012 {device} After ImplementationLock-100, on D1, D2 and D3: hear the ambient sound, feel the haptics,
  play level 1 with VoiceOver and the largest text size (SC-R02G0506-001 … 004 on hardware). Not run before the lock.
- [ ] T-R02G0506-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 and 005 (agent B)} → 004 (lead) → 006 (lead; agent C writes the simulator tests) → 007 … 011,
013. 012 is a {device} task outside this campaign. Shared files (package manifest, geometry, presenter, panel, scene,
docs) stay with the lead. MVP: Story 1.

## Phase 7: Convergence

- [ ] T-R02G0506-014 Add `labelsValuesAndActionCoverage` to `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsAccessibilityTests.swift`: the label and value strings built outside the view body (`ColorfallCanyonsControls.progressValue`, `readableWidth` 520, `modeName`), the valve states ("open, n units left", "closed", "dry") and the cell picker's value ("row r, column c") from the mirror, `nativeActions` covering every action id with `gestureActions` a subset, the sound off by default, and the summary following a carve, per FR-R02G0506-001 and SC-R02G0506-001 (partial)
