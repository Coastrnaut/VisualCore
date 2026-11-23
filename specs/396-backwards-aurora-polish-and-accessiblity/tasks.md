# Tasks: R02-G10-06 — Backwards Aurora: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G10-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G10-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_396;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 386's tasks, including its convergence lesson (every
native control carries a value in words from the start).

## Phase 1: Setup

- [X] T-R02G1006-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit=0 on the committed tree; rendering baseline is R02-G10-05's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G10-05's rendering runs (exit 0)
- [X] T-R02G1006-002 Edit `Packages/ExperiencesRound02/Package.swift` (`BackwardsAuroraCore` and its tests gain — Verified 2026-11-23: host exit=0 (Backwards Aurora host tests with VisualCoreAudioDSP in the Core and VisualCoreAudioDSP/VisualCoreAudio in the experience)
  VisualCoreAudioDSP; `BackwardsAuroraExperience` gains VisualCoreAudioDSP and VisualCoreAudio, iOS-conditioned, as
  Nocturne Garden's targets have); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  BackwardsAurora`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipe (P1, P2) 🎯

- [X] T-R02G1006-003 [P] [US1] [US3] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraFeedbackPlan.swift` (texts and kinds of — Verified 2026-11-23: host-2 exit=0 (BackwardsAuroraFeedbackPlanTests 8: reversal, undo and redo with measures, 3-star and 2-star campaign wins, a practice win without stars, every refusal code in words, a tear and a budget failure plan only the outcome, level and mode changes with the tutorial, section ends and previews plan nothing, summary and hint texts; invariant scan passes; agent A's files retested by the lead in a combined copy, 198 Core tests)
  clarification Q1 word for word, including the revealed hint as `state` (`hint(text:)`); haptics of Q2;
  `after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `summaryText(core:sectionStart:sectionEnd:)` of Q5) with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraFeedbackPlanTests.swift` (scripted sequences of reversals, undos, redos, refusals of every
  code, wins in campaign and practice, tear and budget failures and level and mode changes compare texts, kinds and
  haptics exactly; a reversal that ends the play plans only the outcome; section-end changes and previews plan nothing);
  agent A; `--name host-2`
- [X] T-R02G1006-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraLights.swift` ("glow 0.7 playing / 1 won / 0.35 — Verified 2026-11-23: host-3 exit=0 (BackwardsAuroraLightsTests 10: scripted win, 45 adversarial flicker runs of tears, undos, retries, level changes and previews sampled at 1/60 s within 3 half-range crossings per second and at least 0.4 s per half-range fade under Reduce Flashing, normal settling, targets per stage; BackwardsAuroraSoundRecipeTests 6: root steps at their boundaries, pure and distinct over 60 inputs, whole cycles, octave when won, halved when failed, real plays of level 97; the lead added the lights and recipe to the invariant scan's presentation sources; agent B's files retested by the lead)
  failed; won 1 once won, else 0; tear 1 while the failure is a tear, else 0; preview 1 while a preview shows, else 0",
  eased linearly over 0.15 s, 0.45 s under Reduce Flashing, no reversal mid-fade under Reduce Flashing;
  `maxHalfRangeCrossingsPerSecond`) and `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSoundRecipe.swift` ("root 110 Hz × (1, 9/8, 5/4, 4/3)
  for a worst bend at most 1×, 2×, 4× the limit or more; one partial per matched checkpoint, up to four, at the root ×
  (5/4, 3/2, 2, 5/2); octave when won; halved gains when failed; the longest accepted loop with whole cycles") with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraLightsTests.swift` (a scripted win and adversarial flicker — a tear undone and repeated
  every frame, retry, level changes, previews held and released — sampled every 1/60 s: at most 3 half-range crossings
  per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing) and
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraSoundRecipeTests.swift` (pure; equal inputs equal, different inputs different; whole
  cycles; within the recipe's limits); agent B; `--name host-3`

## Phase 3: Wiring — geometry, presenter, scene, sound and panel

- [X] T-R02G1006-005 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneGeometry.swift` (optional `fadingTear:` on the mesh — Verified 2026-11-23: sim-27 exit=0 (48 simulator tests incl. BackwardsAuroraAccessibilityTests 9: values in words on every control, the summary follows the section, level 1 won with the panel's operations and every step announced as planned, recorded announcements and haptics equal the plan through reversal, undo, redo, refusals and a tear, a revealed hint announced, Reduce Motion stills identical, the tear light fades in and out over at least 0.4 s under Reduce Flashing, the sound state table and toggle); u_tearLight and u_previewLight scale the tear and preview alphas, fadingTear keeps the cross on the last seam (geometry and shader tests); render and teaching tests updated for the fade and refusal words; agent C's tests retested by the lead)
  builders: the tear cross kept on the last torn seam while its light fades out; without it the output is unchanged)
  and `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraShaders.swift` (`u_tearLight` and `u_previewLight` scale the tear cross's and
  the preview ribbon's alphas), with tests in `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraSceneGeometryTests.swift`), add the new Core files that use
  Doubles to `presentationSources` in `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraInvariantTests.swift` (lights, sound recipe), create
  `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraSound.swift` (the ambient loop over `AmbientLoopPlayer`, playing exactly while wanted,
  on screen and active), edit `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraPresenter.swift` (feedback through `ExperienceFeedback` with
  a feedback log, lights stepped per frame, the last preview kept while its light fades out),
  `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraAuroraScene.swift` (the glow gain times the glow level, `u_won` times the won level;
  rebuild only while a fade runs) and `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraControls.swift` (a label and a value in words on
  every control — start and end with the sample's height, Reverse the section, Undo and Redo the reversals made, Next
  level the next open level, Reset view "authored" or "orbited", Dismiss the instruction, Retry the level and mode, Play
  level the picked level, Campaign / Daily / Practice "selected" or "not selected", Hint the level shown, Sound "on" or
  "off" — the adjustable start and end, the summary element, Sound toggle off by default, Dynamic Type layout, 520-point
  width on iPad); agent C writes `Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/BackwardsAuroraAccessibilityTests.swift` (labels and non-empty
  values; the adjustable ends; level 1 won through accessibility operations with every step announced; recorded
  announcements and haptics equal the plan; Reduce Motion frames identical; the loop's state table); `--name sim-27 --
  python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing BackwardsAuroraExperienceTests`

## Phase 4: Regression, documentation and close

- [X] T-R02G1006-006 Docs: `docs/architecture/backwards-aurora.md` (polish and accessibility), — Verified 2026-11-23: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; docs/architecture/backwards-aurora.md polish and accessibility, ExperiencesRound02 README feature 396, docs/automatedtesting.md entry; validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1006-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: rendering-27, rendering-26, experiences, host-full, app-unit exit=0
  `--name host-full`, `--name app-unit`
- [X] T-R02G1006-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-23: reference-1 exit=0
- [ ] T-R02G1006-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1006-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1006-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G1006-006)
- [ ] T-R02G1006-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Shared files (Package.swift, geometry, invariant test, presenter, scene,
controls, docs) stay with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 → 003,
005; FR-004 → 004, 005; FR-006 → 004, 005; FR-007 → 006 … 010.
