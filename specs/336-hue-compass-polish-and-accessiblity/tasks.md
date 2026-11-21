# Tasks: R02-G04-06 — Hue Compass: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_336;
tests stay short (< 10 s each). {device} items (hearing, feeling, VoiceOver on hardware) are D1–D3 observations after
ImplementationLock-100.

## Phase 1: Setup

- [X] T-R02G0406-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing`; add the — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0; VisualCoreAudioDSP added to HueCompassCore, its tests and the experience (with VisualCoreAudio); package build exit 0
  `VisualCoreAudioDSP` product to the `HueCompassCore` target in `Packages/ExperiencesRound02/Package.swift` (and to its
  test target); `--name package -- swift build --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — VoiceOver play (P1) 🎯

- [X] T-R02G0406-002 [P] [US1] [US3] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassFeedbackPlan.swift` ("after(old:new:)" texts and kinds of — Verified 2026-11-21: 2026-11-21 host exit 0: HueCompassFeedbackPlanTests 6/6 (turns, probes, undo, redo, band picks, campaign and practice wins, probe and selection failures, level and mode changes, every refusal code, summary with and without clues)
  clarification Q1: turn "Bearing b of 96, band h. Units s of a."; probe "Probe at bearing b: hue gap g bands, fog depth
  d. Units s of a." ("band" for g = 1); "Undone: " / "Redone: "; "picked(band:)" "Band h picked." (state, no haptic); win
  "The bearing and band match. Level won with s units, k of 3 stars." (no stars in practice); failure = the feature-335
  explanation; level or mode change "Level n, band b, <mode>." plus the tutorial instruction; haptics of Q2 with outcome
  over selection (a selection, or a probe spending the last unit, plans only the outcome); "refused(code:)" and
  "refusalText(code:)" words for r02-g04.locked, r02-g04.date, r02-g04.action, r02-g04.allowance, r02-g04.stage,
  r02-g04.not-whole, otherwise "That change was refused."; "summaryText(core:)" for the summary element of Q5 with "No
  clues yet.") with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassFeedbackPlanTests.swift` (scripted sequences of turns, probes, undo, redo,
  refusals, wins, failures, level and mode changes: exact texts, kinds and haptics; no plan for an unchanged core);
  `--name host`

## Phase 3: Story 2 — comfort settings (P1)

- [X] T-R02G0406-003 [P] [US2] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassLights.swift` ("probe marks keyed by bearing, 1 present, 0 — Verified 2026-11-21: 2026-11-21 host-2 exit 0: HueCompassLightsTests 10/10 (scripted win and flicker under Reduce Flashing: at most 3 half-range crossings per second, fades >= 0.4 s; normal 0.15 s; vanished marks keep their bearing; a moved mark goes out then in)
  absent; selection mark and target ring remember their last bearing; glow 1 when won; linear 0.15 s, or 0.45 s under
  Reduce Flashing where a started fade completes before turning back; a probe level at 0 with target 0 is dropped";
  settle; step; isSettled; maxHalfRangeCrossingsPerSecond) with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassLightsTests.swift` (a scripted
  win and adversarial flicker (a turn and its undo every frame; a retry and replay) at 60 Hz: at most 3 half-range
  crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing; normal mode
  reaches targets in 0.15 s; settle jumps; a vanished mark keeps its bearing while fading); `--name host-2`
- [X] T-R02G0406-004 [US2] Edit `Packages/ExperiencesRound02/HueCompass/Core/HueCompassSceneGeometry.swift` (markPart and markMesh take optional lights: — Verified 2026-11-21: 2026-11-21 host-geometry exit 0: HueCompassSceneGeometryTests (settled lights draw feature 333's marks exactly; a vanished mark shrinks where it was and is gone at 0)
  each mark's radius scaled by its level, fading marks drawn at their remembered bearing; no lights = feature 333's
  marks exactly) with tests in `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassSceneGeometryTests.swift`; `--name host-geometry -- swift test
  --package-path Packages/ExperiencesRound02 --filter HueCompassSceneGeometryTests`

## Phase 4: Story 3 — sound and haptics (P2)

- [X] T-R02G0406-005 [P] [US3] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassSoundRecipe.swift` ("root 110 Hz, a partial at 110 Hz × (1 + g / — Verified 2026-11-21: 2026-11-21 host-3 exit 0: HueCompassSoundRecipeTests 6/6 (equal and differing recipes, exact partials, valid for every certified level and clue in every stage)
  12) for the last hue gap g (unison with no clue), a fifth above the root, gains × (1 − 0.4 · min(d, 90) / 90) for fog
  depth d, won adds an octave, failed halves the gains, 8 s") with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassSoundRecipeTests.swift` (equal
  for equal clue and stage; differs for a hue-gap or stage change; every recipe valid for `AmbientLoopRecipe`'s bounds
  over every certified level's start and solution clues in every stage); `--name host-3`

## Phase 5: Wiring (presenter, panel, scene, sound)

- [X] T-R02G0406-006 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassSound.swift` (wanted, on screen, active; injected — Verified 2026-11-21: 2026-11-21 sim-27-2 exit 0 (Hue Compass experience tests incl. HueCompassAccessibilityTests: recorded announcements and haptics equal the plans; level 1 won with turn buttons, Probe, band stepper and Select; swipe previews not announced; sound state table and offers; drawn lights under Reduce Flashing; Reduce Motion stills identical; labels, values, layout at the largest text size) and sim-27-full exit 0 (whole round-two suite on sim-27.2); refusals in words (teaching tests updated); a still at a non-advancing time settles the lights (first sim-27 attempt failed on that, exit 65)
  player for tests; recipe offered at level openings, new clues, play ends and when turned on) and edit
  `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassPresenter.swift` (route `HueCompassFeedbackPlan` after each described change, band pick and
  refusal through `feedback`, a feedback log, the eased lights stepped per frame into the scene, the sound),
  `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassCompassScene.swift` (marks from the presenter's lights; win glow scales the glow-shell gain,
  clamped by `u_gainLimit`; mark geometry rebuilt while a fade runs), `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassControls.swift` (labels
  and values of every control, summary element, refusals in words, Sound toggle, wrapping rows at accessibility sizes,
  520-point width on iPad) and create `Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassAccessibilityTests.swift` (agent C: recorded
  announcements and haptics through the presenter; level 1 won with the turn buttons, Probe, the band stepper and
  Select; a swipe preview is not announced, its released turn is; the sound state table, including a player that fails
  to start; labels and values; lights fade under Reduce Flashing in drawn frames; Reduce Motion stills identical);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 6: Regression, documentation and close

- [X] T-R02G0406-007 Docs: `docs/architecture/hue-compass.md` (polish and accessibility), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; architecture (polish and accessibility), package README and testing doc (stills at a repeated time settle) updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0406-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit exit 0 on the final code (after T-014/T-015)
  `--name host-full`, `--name app-unit`
- [X] T-R02G0406-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0406-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [ ] T-R02G0406-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0406-012 {device} After ImplementationLock-100, on D1, D2 and D3: hear the ambient sound, feel the haptics,
  play level 1 with VoiceOver and the largest text size (SC-R02G0406-001 … 004 on hardware). Not run before the lock.
- [ ] T-R02G0406-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 and 005 (agent B)} → 004 (lead) → 006 (lead; agent C writes the simulator tests) → 007 … 011,
013. 012 is a {device} task outside this campaign. Shared files (package manifest, geometry, presenter, panel, scene,
docs) stay with the lead. MVP: Story 1.

## Phase 7: Convergence

- [X] T-R02G0406-014 Report the scene phase from `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassControls.swift` (`@Environment(\.scenePhase)`, `.onChange` → `presenter.sceneActive(phase == .active)`, as Aurora Loom's panel does) so the ambient loop stops while the app is inactive per FR-R02G0406-006 (partial) — Verified 2026-11-21: 2026-11-21 sim-27-3 exit 0 (Hue Compass experience tests on sim-27.2 with the panel reporting scenePhase to presenter.sceneActive; the sound state table covers the active input)
- [X] T-R02G0406-015 Announce the units left ("Units L of a." with L = allowance − spent) in the turn, probe and summary texts of `Packages/ExperiencesRound02/HueCompass/Core/HueCompassFeedbackPlan.swift` (the win keeps the units spent), updating `HueCompassFeedbackPlanTests`, `HueCompassAccessibilityTests` and `docs/architecture/hue-compass.md`, per FR-R02G0406-002 and US1/AC1 (partial) — Verified 2026-11-21: 2026-11-21 host-4 exit 0 (HueCompassFeedbackPlanTests: turn, probe and summary texts read the units left) and sim-27-3 exit 0 (HueCompassAccessibilityTests with the same texts)
