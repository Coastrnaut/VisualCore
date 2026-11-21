# Tasks: R02-G03-06 — Wave Knot Keeper: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_326;
tests stay short (< 10 s each). {device} items (hearing, feeling, VoiceOver on hardware) are D1–D3 observations after
ImplementationLock-100.

## Phase 1: Setup

- [X] T-R02G0306-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing`; add the — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0; VisualCoreAudioDSP added to WaveKnotKeeperCore and its tests; package build exit 0
  `VisualCoreAudioDSP` product to the `WaveKnotKeeperCore` target in `Packages/ExperiencesRound02/Package.swift` (and to
  its test target); `--name package -- swift build --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — VoiceOver play (P1) 🎯

- [X] T-R02G0306-002 [P] [US1] [US3] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperFeedbackPlan.swift` ("after(old:new:)" texts and kinds — Verified 2026-11-21: 2026-11-21 host exit 0: WaveKnotKeeperFeedbackPlanTests 6/6 (moves, selections, undo, redo, degenerate texts, campaign and practice wins, failure, level and mode changes, every refusal code; singular counts)
  of clarification Q1: "Point n moved <direction>. c crossings, writhe w; target C, W. Moves s of a." (degenerate: "Two
  strands overlap in the view." for the counts); "Undone: " / "Redone: "; "Point n selected."; win "The knot matches.
  Level won in s moves, k of 3 stars." (no stars in practice); failure = the feature-325 explanation; level or mode change
  "Level n, band b, <mode>." plus the tutorial instruction; haptics of Q2 with outcome over selection; "refused(code:)" and
  "refusalText(code:)" words for r02-g03.locked, r02-g03.date, r02-g03.move, r02-g03.allowance, r02-g03.stage, otherwise
  "That change was refused.") with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperFeedbackPlanTests.swift` (scripted sequences of moves,
  selections, undo, redo, refusals, wins, failures, level and mode changes: exact texts, kinds and haptics; no plan for an
  unchanged core); `--name host`

## Phase 3: Story 2 — comfort settings (P1)

- [X] T-R02G0306-003 [P] [US2] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperLights.swift` ("crossing marks keyed by their two segments, — Verified 2026-11-21: 2026-11-21 host-2 exit 0: WaveKnotKeeperLightsTests 10/10 (scripted win and move/undo flicker under Reduce Flashing: at most 3 half-range crossings per second, fades >= 0.4 s; normal 0.15 s; vanished marks keep segment and fraction)
  1 present, 0 absent, remembering the over segment and the fraction along it; match 1 while the summary equals the
  target; glow 1 when won; linear 0.15 s, or 0.45 s under Reduce Flashing where a started fade completes before turning
  back; a level at 0 with target 0 is dropped"; settle; step; isSettled; maxHalfRangeCrossingsPerSecond) with
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperLightsTests.swift` (a scripted win and adversarial flicker (a move and its undo every frame)
  at 60 Hz: at most 3 half-range crossings per second and every complete one-way fade over half the range ≥ 0.4 s under
  Reduce Flashing; normal mode reaches targets in 0.15 s; settle jumps; a vanished mark keeps its segment and fraction
  while fading); `--name host-2`
- [X] T-R02G0306-004 [US2] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSceneGeometry.swift` (ropeMesh and glowMesh take optional lights: — Verified 2026-11-21: 2026-11-21 host-geometry exit 0: WaveKnotKeeperSceneGeometryTests 15/15 (settled lights draw feature 323's meshes exactly; a half-lit crossing halves its weights; a vanished crossing fades where it was)
  present marks' weights scaled by their levels, fading marks drawn at their remembered fraction of the over segment; no
  lights = feature 323's weights exactly) with tests in `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperSceneGeometryTests.swift`;
  `--name host-geometry -- swift test --package-path Packages/ExperiencesRound02 --filter WaveKnotKeeperSceneGeometryTests`

## Phase 4: Story 3 — sound and haptics (P2)

- [X] T-R02G0306-005 [P] [US3] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSoundRecipe.swift` ("root 110 Hz × (1 + target crossings), — Verified 2026-11-21: 2026-11-21 host-3 exit 0: WaveKnotKeeperSoundRecipeTests 5/5 (equal and differing recipes, exact partials, valid for all 100 levels in every stage)
  partial 110 Hz × (1 + crossings), a fifth above the root, gains 0.6 … 1.0 of a base by |writhe − target writhe|, won adds
  an octave, failed halves the gains, 8 s") with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperSoundRecipeTests.swift` (equal for equal
  summary, target and stage; differs for a crossings or stage change; every recipe valid for `AmbientLoopRecipe`'s bounds
  over every certified level's start and solution summaries); `--name host-3`

## Phase 5: Wiring (presenter, panel, scene, sound)

- [ ] T-R02G0306-006 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperSound.swift` (wanted, on screen, active;
  injected player for tests; recipe offered at level openings, summary changes, play ends and when turned on) and edit
  `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperPresenter.swift` (route `WaveKnotKeeperFeedbackPlan` after each described change and for
  refusals through `feedback`, a feedback log, the eased lights stepped per frame into the scene, the sound),
  `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperRopeScene.swift` (crossing weights, match and glow from the presenter's lights; geometry
  rebuilt while a crossing fade runs), `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperControls.swift` (labels and values of every control,
  refusals in words, Sound toggle, wrapping rows at accessibility sizes, 520-point width on iPad) and create
  `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperAccessibilityTests.swift` (agent C: recorded announcements and haptics through the
  presenter; level 1 won with the point picker and the direction buttons; a drag preview is not announced, its released
  move is; the sound state table, including a player that fails to start; labels and values; lights fade under Reduce
  Flashing in drawn frames; Reduce Motion stills identical); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0306-007 Docs: `docs/architecture/wave-knot-keeper.md` (polish and accessibility),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g03.wave-knot-keeper`
- [ ] T-R02G0306-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0306-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0306-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0306-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0306-012 {device} After ImplementationLock-100, on D1, D2 and D3: hear the ambient sound, feel the haptics,
  play level 1 with VoiceOver and the largest text size (SC-R02G0306-001 … 004 on hardware). Not run before the lock.
- [ ] T-R02G0306-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 and 005 (agent B)} → 004 (lead) → 006 (lead; agent C writes the simulator tests) → 007 … 011,
013. 012 is a {device} task outside this campaign. Shared files (package manifest, geometry, presenter, panel, scene,
docs) stay with the lead. MVP: Story 1.
