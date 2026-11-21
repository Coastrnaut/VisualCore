# Tasks: R02-G02-06 — Lissajous Labyrinth: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G02-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G02-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_316;
tests stay short (< 10 s each). {device} items (hearing, feeling, VoiceOver on hardware) are D1–D3 observations after
ImplementationLock-100.

## Phase 1: Setup

- [ ] T-R02G0206-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing`; add the
  `VisualCoreAudioDSP` product to the `LissajousLabyrinthCore` target in `Packages/ExperiencesRound02/Package.swift`
  (and to its test target); `--name package -- swift build --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — VoiceOver play (P1) 🎯

- [ ] T-R02G0206-002 [P] [US1] [US3] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthFeedbackPlan.swift` ("after(old:new:)" texts and
  kinds of clarification Q1: "<Dial> <value>. v of n checkpoints in order. Actions s of a." with " The path touches
  obstacle k." while touching; "Undone: " / "Redone: "; win "The path is safe. Level won in s actions, k of 3 stars." (no
  stars in practice); failure = the feature-315 explanation; level or mode change "Level n, band b, <mode>." plus the
  tutorial instruction; haptics of Q2 with outcome over selection; "refused(code:)" words for r02-g02.locked,
  r02-g02.date, r02-g02.move, r02-g02.allowance, r02-g02.stage, otherwise "That change was refused.") with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthFeedbackPlanTests.swift` (scripted sequences of actions, undo, redo, refusals, wins,
  failures, level and mode changes: exact texts, kinds and haptics; no plan for an unchanged core); `--name host`

## Phase 3: Story 2 — comfort settings (P1)

- [ ] T-R02G0206-003 [P] [US2] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthLights.swift` ("checkpoint targets dim 0, next 0.5,
  visited 1; obstacle 0 or 1 touched; glow 1 when won; linear 0.15 s, or 0.45 s under Reduce Flashing where a started fade
  completes before turning back"; settle; step; maxHalfRangeCrossingsPerSecond) with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthLightsTests.swift` (a scripted win and adversarial flicker at 60 Hz: at most 3
  half-range crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing;
  normal mode reaches targets in 0.15 s; settle jumps); `--name host-2`

## Phase 4: Story 3 — sound and haptics (P2)

- [ ] T-R02G0206-004 [P] [US3] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSoundRecipe.swift` ("110 Hz × a, 110 Hz × b, a fifth
  above the lower; gains 0.6 … 1.0 of a base by phase; won adds an octave; failed halves the gains; 8 s") with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthSoundRecipeTests.swift` (equal for equal dials and stage; differs for a frequency or
  stage change; every recipe valid for `AmbientLoopRecipe`'s bounds over all legal dials); `--name host-3`

## Phase 5: Wiring (presenter, panel, scene, sound)

- [ ] T-R02G0206-005 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthSound.swift` (wanted, on screen, active;
  injected player for tests; recipe offered at level openings, play ends and when turned on) and edit
  `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthPresenter.swift` (route `LissajousLabyrinthFeedbackPlan` after each described change
  and for refusals through `feedback`, a feedback log, the eased lights stepped per frame into the scene, the sound),
  `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthThreadScene.swift` (checkpoint, obstacle and glow levels from the presenter's lights),
  `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthControls.swift` (labels and values of every control, Sound toggle, wrapping rows at
  accessibility sizes, 520-point width on iPad) and create `Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthAccessibilityTests.swift`
  (agent C: recorded announcements and haptics through the presenter; level 1 won with the steppers and Apply; a gesture
  preview is not announced, its released action is; the sound state table, including a player that fails to start (the
  choice stays on, the game is unaffected); labels and values; lights fade under Reduce Flashing in drawn frames; Reduce Motion stills identical);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0206-006 Docs: `docs/architecture/lissajous-labyrinth.md` (polish and accessibility),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g02.lissajous-labyrinth`
- [ ] T-R02G0206-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0206-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0206-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0206-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0206-011 {device} After ImplementationLock-100, on D1, D2 and D3: hear the ambient sound, feel the haptics,
  play level 1 with VoiceOver and the largest text size (SC-R02G0206-001 … 004 on hardware). Not run before the lock.
- [ ] T-R02G0206-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 and 004 (agent B)} → 005 (lead; agent C writes the simulator tests) → 006 … 010, 012. 011 is a
{device} task outside this campaign. Shared files (package manifest, presenter, panel, scene, docs) stay with the lead.
MVP: Story 1.
