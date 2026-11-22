# Tasks: R02-G06-06 — Chrono Constellator: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G06-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G06-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_356;
tests stay short (< 10 s each). No {owner} tasks; one {device} task; no GLSL change.

## Phase 1: Setup

- [X] T-R02G0606-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing`; add the — Verified 2026-11-21: 2026-11-21: baseline-round02, baseline-host, baseline-timing exit 0; VisualCoreAudioDSP added to ChronoConstellatorCore and tests, VisualCoreAudio to the experience; package (swift build) exit 0
  `VisualCoreAudioDSP` product to the `ChronoConstellatorCore` target and its test target and `VisualCoreAudio` (iOS) to
  `ChronoConstellatorExperience` in `Packages/ExperiencesRound02/Package.swift`; `--name package -- swift build
  --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — VoiceOver play (P1) 🎯

- [X] T-R02G0606-002 [P] [US1] [US3] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorFeedbackPlan.swift` ("after(old:new:)" texts and — Verified 2026-11-21: 2026-11-21: host (ChronoConstellatorFeedbackPlanTests, 7 tests: exact texts, kinds and haptics for edits, steps, rewinds, undo/redo, every refusal code, wins with stars, failures, level and mode changes; summary) exit 0, lead retest
  kinds of clarification Q1: phase "Star k (shape) starts at row r, column c. n edits left."; hold "Star k holds from tick
  s for l ticks." and release "Star k's hold from tick s removed." with the same suffix; step "Tick t of T. m of N stars
  on target."; rewind "Rewound to tick 0."; "Undone. " / "Redone. " + "Tick t of T. n edits left."; "picked(star:)"
  "Star k (shape) picked." (state, no haptic); win "Every star is on its target. Level won with e edits, k of 3 stars."
  (no stars in practice); failure = the feature-355 explanation; level or mode change "Level n, band b, <mode>." plus the
  tutorial instruction; haptics of Q2 with outcome over selection; "refused(code:)" and "refusalText(code:)" words for
  r02-g06.locked, date, action, budget, stage, not-whole, otherwise "That change was refused."; "summaryText(core:)" for
  the summary element of Q5) with `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorFeedbackPlanTests.swift` (agent A: scripted sequences
  of phase changes, holds, releases, steps, rewinds, undo, redo, refusals, wins, failures, level and mode changes: exact
  texts, kinds and haptics; no plan for an unchanged core); `--name host`

## Phase 3: Story 2 — comfort settings (P1)

- [X] T-R02G0606-003 [P] [US2] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorLights.swift` ("rings: 1 lit, 0.5 unlit; nodes: 1 on — Verified 2026-11-21: 2026-11-21: host-2 (ChronoConstellatorLightsTests: settle, 0.15/0.45 s fades, scripted win and adversarial flicker at 60 Hz <= 3 half-range crossings/s and fades >= 0.4 s under Reduce Flashing, collision mark) exit 0, lead retest
  target, 0.7 off; glow 1 when won; collision 1 when failed by collision; linear 0.15 s, or 0.45 s under Reduce Flashing
  where a started fade completes before turning back"; settle; step; isSettled; maxHalfRangeCrossingsPerSecond) with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorLightsTests.swift` (agent B: a scripted win and adversarial flicker (a phase changed
  and undone every frame; steps of 1 tick; a rewind; a retry) at 60 Hz: at most 3 half-range crossings per second and
  every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing; normal mode reaches targets in 0.15 s;
  settle jumps); `--name host-2`
- [X] T-R02G0606-004 [US2] Edit `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSceneGeometry.swift` (fieldPart, fieldMesh, starPart and — Verified 2026-11-21: 2026-11-21: host-geometry (SceneGeometryTests incl. theLightsDriveRingsNodesAndTheCollisionMark + LightsTests) exit 0; no lights = unchanged meshes; lights gained collisionCell so the mark fades out after a rewind
  starMesh take optional lights: ring shade, node brightness and collision-mark shade from the lights; no lights =
  feature 353's meshes exactly) with tests in `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorSceneGeometryTests.swift`; `--name
  host-geometry`

## Phase 4: Story 3 — sound and haptics (P2)

- [X] T-R02G0606-005 [P] [US3] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSoundRecipe.swift` ("root 110 Hz; one partial per star — Verified 2026-11-21: 2026-11-21: host-3 (ChronoConstellatorSoundRecipeTests: equal/distinct recipes for 32 patterns x 7 stages, valid bounds, 100 certified levels start and solution) exit 0, lead retest
  on target at 110 × (3/2, 5/4, 2, 5/3, 9/8)[star], base gain; the root alone with no star on target; won adds an octave,
  failed halves the gains, 12 s") with `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorSoundRecipeTests.swift` (agent B: equal for equal
  stars on target and stage; differs when they differ; every recipe valid for `AmbientLoopRecipe`'s bounds over every
  certified level's start and solution states in every stage); `--name host-3`

## Phase 5: Wiring (presenter, panel, scene, sound)

- [X] T-R02G0606-006 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorSound.swift` (wanted, on screen, active; — Verified 2026-11-22: 2026-11-22: sim-27 (ChronoConstellatorExperienceTests, 45 tests in 7 suites on iOS 27.2 incl. 8 accessibility tests: recorded feedback, level 1 won with panel operations, preview not announced, sound state table, labels and summary, Reduce Flashing ring fade, Reduce Motion stills) exit 0
  injected player for tests; recipe offered at level openings, changes of the stars on target or stage and when turned
  on) and edit `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorPresenter.swift` (route `ChronoConstellatorFeedbackPlan` after each
  described change, star pick and refusal through `feedback`, a feedback log, the eased lights stepped per frame into the
  scene, the sound, `sceneActive(_:)`), `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorSkyScene.swift` (rings, nodes and marks from the
  presenter's lights; win glow scales the glow gain, clamped by `u_glowLimit`; field and star geometry rebuilt while a
  fade runs), `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorControls.swift` (labels and values of every control, summary element,
  refusals in words, Sound toggle, wrapping rows at accessibility sizes, 520-point width on iPad, the scene phase reported
  to `sceneActive`) and create `Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorAccessibilityTests.swift` (agent C: recorded
  announcements and haptics through the presenter; level 1 won with the star picker, phase − and + and Run; a drag
  preview is not announced, its released change is; the sound state table, including a player that fails to start;
  labels and values; lights fade under Reduce Flashing in drawn frames; Reduce Motion stills identical); `--name sim-27
  -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing ChronoConstellatorExperienceTests`

## Phase 6: Regression, documentation and close

- [X] T-R02G0606-007 Docs: `docs/architecture/chrono-constellator.md` (polish and accessibility), — Verified 2026-11-22: 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; architecture polish and accessibility, package README, testing lesson
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0606-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: 2026-11-22: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0606-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: 2026-11-22: reference-1 exit 0
- [ ] T-R02G0606-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0606-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0606-012 {device} After ImplementationLock-100, on D1, D2 and D3: hear the ambient sound, feel the haptics,
  play level 1 with VoiceOver and the largest text size (SC-R02G0606-001 … 004 on hardware). Not run before the lock.
- [ ] T-R02G0606-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 and 005 (agent B)} → 004 (lead) → 006 (lead; agent C writes the simulator tests) → 007 … 011,
013. 012 is a {device} task outside this campaign. Shared files (package manifest, geometry, presenter, panel, scene,
docs) stay with the lead. MVP: Story 1.
