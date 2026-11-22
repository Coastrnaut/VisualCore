# Tasks: R02-G09-06 — Nocturne Garden: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G09-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G09-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_386;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0906-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline = R02-G09-05 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G09-05's rendering runs (exit 0)
- [X] T-R02G0906-002 Edit `Packages/ExperiencesRound02/Package.swift` (`NocturneGardenCore` and its tests gain — Verified 2026-11-22: host (swift test --filter NocturneGarden) exit 0; Core and tests gain VisualCoreAudioDSP, Experience gains VisualCoreAudioDSP and VisualCoreAudio (iOS), experience tests VisualCoreAudioDSP
  VisualCoreAudioDSP; `NocturneGardenExperience` gains VisualCoreAudioDSP and VisualCoreAudio, iOS-conditioned, as
  Faceted Forge's targets have); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  NocturneGarden`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipe (P1, P2) 🎯

- [X] T-R02G0906-003 [P] [US1] [US3] Create — Verified 2026-11-22: host-2 (NocturneGardenFeedbackPlanTests 8 + invariant) exit 0, rerun by the lead; texts of clarification Q1 exact, outcome-only for an ending move, refusal words raw and prefixed, hint(text:) state
  `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenFeedbackPlan.swift` (texts and kinds of clarification
  Q1 word for word, including the revealed hint as `state` (`hint(text:)`); haptics of Q2; `after(old:new:)`, `refused(code:)`,
  `refusalText(code:)`, `summaryText(core:)` of Q5) with
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenFeedbackPlanTests.swift` (scripted sequences of
  plants, moves, resizes, removes, sun changes, undos, redos, refusals of every code, wins in campaign and practice,
  leak and budget failures and level changes compare texts, kinds and haptics exactly; a move that ends the play plans
  only the outcome; picker changes and previews plan nothing); agent A; `--name host-2`
- [X] T-R02G0906-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenLights.swift` — Verified 2026-11-22: host-3 (NocturneGardenLightsTests, NocturneGardenSoundRecipeTests, invariant) exit 0, rerun by the lead; lights and recipe exempted from the kernel scan as presentation; two slow-type-check literals split by the lead
  ("glow 0.7 playing / 1 won / 0.35 failed; leak 1 while the failure is a leak, else 0", eased linearly over 0.15 s,
  0.45 s under Reduce Flashing, no reversal mid-fade under Reduce Flashing; `maxHalfRangeCrossingsPerSecond`) and
  `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSoundRecipe.swift` ("root 110 Hz × (1, 9/8, 5/4, 4/3)
  for sun 1 … 4; one partial per planted bloom, up to four, at the root × (5/4, 3/2, 2, 5/2); octave when won; halved
  gains when failed; the longest accepted loop with whole cycles") with
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenLightsTests.swift` (a scripted win and
  adversarial flicker sampled every 1/60 s: at most 3 half-range crossings per second and every complete one-way fade
  over half the range ≥ 0.4 s under Reduce Flashing) and
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenSoundRecipeTests.swift` (pure; equal inputs
  equal, different inputs different; whole cycles; within the recipe's limits); agent B; `--name host-3`

## Phase 3: Wiring — geometry, presenter, scene, sound and panel

- [X] T-R02G0906-005 [US1] [US2] [US3] Edit — Verified 2026-11-22: host-4 (swift test --filter NocturneGarden, incl. the leak-cross lights geometry test) exit 0; sim-27 exit=65 (the leak frame was drawn before the crosses faded in; the render test now draws 1 s later and checks the leak level), sim-27-2 exit=0 (53 simulator tests incl. NocturneGardenAccessibilityTests 8, iOS 27.2); bloom picker value now capitalises only its first letter; refusals shown in words (two tests updated); agent C's tests retested by the lead
  `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneGeometry.swift` (optional `lights:` on
  gardenPart/gardenMesh: the leak crosses' shade from the lights; without lights the output is unchanged, with tests in
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenSceneGeometryTests.swift`), create
  `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenSound.swift` (the ambient loop over
  `AmbientLoopPlayer`, playing exactly while wanted, on screen and active), edit
  `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenPresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log, lights stepped per frame, the glow gain times the glow level),
  `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenGardenScene.swift` (the eased levels; rebuild
  only while a fade runs) and `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenControls.swift`
  (labels and values on every control, the adjustable kind, column, row, size, bloom and sun pickers, the summary
  element, Sound toggle off by default, Dynamic Type layout, 520-point width on iPad); agent C writes
  `Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/NocturneGardenAccessibilityTests.swift` (labels and
  values; the adjustable pickers; level 1 won through accessibility operations with every step announced; recorded
  announcements and haptics equal the plan; Reduce Motion frames identical; the loop's state table); `--name sim-27 --
  python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing NocturneGardenExperienceTests`

## Phase 4: Regression, documentation and close

- [X] T-R02G0906-006 Docs: `docs/architecture/nocturne-garden.md` (polish and accessibility), — Verified 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; architecture polish and accessibility section, package README feature 386, testing doc lesson (fades in frame tests); validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0906-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: rendering-27, rendering-26, experiences, host-full, app-unit exit=0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0906-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: reference-1 exit=0
- [X] T-R02G0906-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-22: reference-2 exit=0
- [X] T-R02G0906-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-22: script-tests exit=0 (run alone)
- [ ] T-R02G0906-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G0906-006)
- [ ] T-R02G0906-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Shared files (Package.swift, geometry, presenter, scene, controls, docs) stay
with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 → 003, 005; FR-004 → 004, 005;
FR-006 → 004, 005; FR-007 → 006 … 010.
