# Tasks: R02-G16-06 — Starlit Cartouche: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G16-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G16-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_456;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 446's tasks, with its lessons taken into the first
pass (the won look faded in the unlit fallback too; fades ease by the frame clock, not the presentation time Reduce
Motion holds at 0) and round02-host in three chunks (the second chunk reached 450 s at R02-G16-05).

## Phase 1: Setup

- [X] T-R02G1606-001 Baselines after R02-G16-05 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: baseline-host, baseline-timing, baseline-round02-1..3 exit 0 (.autonomy/migration/checks/R02-G16-06.baseline-*.json)
  baseline-round02-1 … 3` (the three round-two filters of feature 446); the rendering baseline is R02-G16-05's rendering
  runs (exit 0)
- [X] T-R02G1606-002 Edit `Packages/ExperiencesRound02/Package.swift` (`StarlitCartoucheCore` and its tests gain — Verified 2026-11-24: host exit 0 (.autonomy/migration/checks/R02-G16-06.host.json); Core and tests gain VisualCoreAudioDSP, experience and tests gain VisualCoreAudioDSP and VisualCoreAudio (iOS)
  VisualCoreAudioDSP; `StarlitCartoucheExperience` and its tests gain VisualCoreAudioDSP and VisualCoreAudio,
  iOS-conditioned, as Voxel Origami's targets have); `--name host -- swift test --package-path
  Packages/ExperiencesRound02 --filter StarlitCartoucheCoreTests`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipes (P1, P2) 🎯

- [X] T-R02G1606-003 [P] [US1] [US3] Create — Verified 2026-11-24: host-2 exit 0 (.autonomy/migration/checks/R02-G16-06.host-2.json); feedback plan with Q1 texts, Q2 haptics, refusals bare and prefixed, summary text; 7 tests incl. every leg failure kind and a budget-out
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheFeedbackPlan.swift` (texts and kinds of
  clarification Q1 word for word, the engine's `action.rule.` prefix read as the bare code, a revealed hint as `state`
  (`hint(text:)`); haptics of Q2 — a leg that ends the level plans only the outcome; `after(old:new:)`,
  `refused(code:)`, `refusalText(code:)`, `summaryText(core:destination:wait:)` of Q5) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheFeedbackPlanTests.swift` (scripted sequences
  of legs, undos, redos, refusals of every code (bare and prefixed), wins in campaign and practice, failures by every
  leg failure kind and the budget, and level and mode changes compare texts, kinds and haptics exactly; choosing a
  destination or wait plans nothing); agent A; `--name host-2`
- [X] T-R02G1606-004 [P] [US2] [US3] Create — Verified 2026-11-24: host-3 exit 0 (.autonomy/migration/checks/R02-G16-06.host-3.json); lights with fades and the flicker measure, audition and ambient recipes; 20 tests
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheLights.swift` ("glow 0.7 playing / 1 won / 0.35
  failed; won 1 once won, else 0", eased linearly over 0.15 s, 0.45 s under Reduce Flashing, no reversal mid-fade under
  Reduce Flashing, stepped by the frame clock's elapsed time; `maxHalfRangeCrossingsPerSecond`) and
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSoundRecipe.swift` (`StarlitCartoucheAudition`
  "star j's tone 220 Hz × 2^(j / 12); a reachable star (a corridor joins it to the ship's star) with its fifth (× 3/2),
  an unreachable one with a partial 3 Hz above, gain 0.04 each; 0.6 s linear decay"; the ambient recipe "root 110 Hz ×
  (1, 9/8, 5/4, 4/3) for more than 3/4, 1/2, 1/4 of the actions left, or less; one partial per quarter of the symbol
  drawn, up to four, at the root × (5/4, 3/2, 2, 5/2); the root alone when fewer than a quarter; octave when won; halved
  gains when failed; the longest accepted loop with whole cycles") with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheLightsTests.swift` (a scripted win and
  adversarial flicker — a leg undone and redone every frame, retry, level changes — sampled every 1/60 s: at most 3
  half-range crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing) and
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheSoundRecipeTests.swift` (pure; equal inputs
  equal, different inputs different; whole cycles; within the recipe's limits; a reachable star gives a consonant chord,
  an unreachable one a 3 Hz beat); agent B; `--name host-3`

## Phase 3: Wiring — presenter, scene, sound and panel

- [X] T-R02G1606-005 [US1] [US2] [US3] Create — Verified 2026-11-24: sim-27 exit 0, 52 simulator tests incl. 11 accessibility tests (.autonomy/migration/checks/R02-G16-06.sim-27.json; sim-27a failed only on two old refusal sentences in the teaching tests, sim-27b exit 0 after updating them); sound, feedback route and log, eased lights in the scene, panel accessibility
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheSound.swift` (the ambient loop over
  `AmbientLoopPlayer` and the audition, playing exactly while wanted, on screen and active); edit
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartouchePresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log; lights stepped per frame by the frame clock; choosing a destination plays
  its audition when the sound is on; the refusal words from the feedback plan),
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheChartScene.swift` (the glow gain times the
  glow level, `u_won` the won level; in the fallback path `lights.won` passed to the parts' `wonLevel`, the fallback
  rebuilt when the level moves by a tenth or more) and
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheControls.swift` (a label and a value in words
  on every control — the destination and the wait adjustable with their words, Fly the chosen leg, Undo and Redo the
  actions made, Next level the next open level, Reset view "authored" or "orbited", Dismiss the instruction, Retry the
  level and mode, Play level the picked level, Campaign / Daily / Practice "selected" or "not selected", Hint the level
  shown, Sound "on" or "off" — the summary element, Sound toggle off by default, Dynamic Type layout, 520-point width on
  iPad); agent C writes
  `Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheAccessibilityTests.swift` (labels and
  non-empty values; the adjustable destination and wait; level 1 won through accessibility operations with every step
  announced; recorded announcements and haptics equal the plan; Reduce Motion and Reduce Flashing frames identical; the
  sound state table; a won level in fallback mode under Reduce Flashing brightens over at least 0.4 s), given the
  presenter's exact texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  StarlitCartoucheExperienceTests`

## Phase 4: Regression, documentation and close

- [X] T-R02G1606-006 Docs: `docs/architecture/starlit-cartouche.md` (polish and accessibility), — Verified 2026-11-24: round02-host-1..3 exit 0 (.autonomy/migration/checks/R02-G16-06.round02-host-*.json; chunk 3 344 s); architecture, package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1 … 3` (the three round-two
  filters of feature 446)
- [X] T-R02G1606-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24 rendering-27, rendering-26, experiences, host-full exit 0; app-unit exit 1 compiled half-done 457 edits in the working tree, app-unit-2 on the committed tree exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G1606-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-24: 2026-11-24 reference-1 exit 0
- [X] T-R02G1606-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-24: 2026-11-24 reference-2 exit 0
- [ ] T-R02G1606-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1606-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G1606-006)
- [ ] T-R02G1606-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Agents A and B may start in isolated copies before 001 (their files are new; B
needs VisualCoreAudioDSP in its copy's Core target). Shared files (Package.swift, presenter, scene, controls, docs) stay
with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 → 003, 005; FR-004 → 004, 005;
FR-006 → 004, 005; FR-007 → 006 … 010.
