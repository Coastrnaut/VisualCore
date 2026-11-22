# Tasks: R02-G08-06 — Faceted Forge: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G08-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G08-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_376;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0806-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline = R02-G08-05 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G08-05's rendering runs (exit 0)
- [ ] T-R02G0806-002 Edit `Packages/ExperiencesRound02/Package.swift` (`FacetedForgeCore` and its tests gain
  VisualCoreAudioDSP; `FacetedForgeExperience` gains VisualCoreAudioDSP and VisualCoreAudio, iOS-conditioned, as
  Amethyst Escape's targets have); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  FacetedForge`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipe (P1, P2) 🎯

- [ ] T-R02G0806-003 [P] [US1] [US3] Create
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeFeedbackPlan.swift` (texts and kinds of clarification Q1
  word for word, haptics of Q2, `after(old:new:)`, `refused`, `refusalText`, `summaryText(core:choice:)` of Q5) with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeFeedbackPlanTests.swift` (scripted sequences of cuts,
  undos, redos, refusals of every code, wins in campaign and practice, sliver and budget failures and level changes
  compare texts, kinds and haptics exactly; a cut that ends the play plans only the outcome; preview choices plan
  nothing); agent A; `--name host-2`
- [ ] T-R02G0806-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeLights.swift`
  ("glow 0.7 playing / 1 won / 0.35 failed; sliver 0 / 1 while the failure is a sliver", eased linearly over 0.15 s,
  0.45 s under Reduce Flashing, no reversal mid-fade under Reduce Flashing; `maxHalfRangeCrossingsPerSecond`) and
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSoundRecipe.swift` ("root 110 Hz; one partial per piece
  beyond the first, up to four, at 110 × (5/4, 3/2, 2, 5/2); octave when won; halved gains when failed; 12-second loop")
  with `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeLightsTests.swift` (a scripted win and
  adversarial flicker sampled every 1/60 s: at most 3 half-range crossings per second and every complete one-way fade
  over half the range ≥ 0.4 s under Reduce Flashing) and
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeSoundRecipeTests.swift` (pure; equal inputs equal,
  different inputs different; within the recipe's limits); agent B; `--name host-3`

## Phase 3: Wiring — geometry, presenter, scene, sound and panel

- [ ] T-R02G0806-005 [US1] [US2] [US3] Edit
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSceneGeometry.swift` (optional `lights:` on
  crystalPart/crystalMesh: the sliver cross's shade from the lights; without lights the output is unchanged, with tests
  in `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeSceneGeometryTests.swift`), create
  `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeSound.swift` (the ambient loop over
  `AmbientLoopPlayer`, playing exactly while wanted, on screen and active), edit
  `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgePresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log, lights stepped per frame, the glow gain times the glow level),
  `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeCrystalScene.swift` (the eased levels; rebuild only
  while a fade runs) and `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeControls.swift` (labels and
  values on every control, the adjustable pickers "Piece to cut", "Direction of the cut", "Depth of the cut", the
  summary element, Sound toggle, Dynamic Type layout, 520-point width on iPad); agent C writes
  `Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeAccessibilityTests.swift` (labels and values;
  the adjustable pickers; level 1 won through accessibility operations with every step announced; recorded announcements
  and haptics equal the plan; Reduce Motion frames identical; the loop's state table); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing FacetedForgeExperienceTests`

## Phase 4: Regression, documentation and close

- [ ] T-R02G0806-006 Docs: `docs/architecture/faceted-forge.md` (polish and accessibility),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0806-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0806-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0806-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0806-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0806-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G0806-006)
- [ ] T-R02G0806-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Shared files (Package.swift, geometry, presenter, scene, controls, docs) stay
with the lead. MVP: Stories 1 and 2.
