# Tasks: R02-G12-06 — Harmonic Bridges: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G12-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G12-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_416;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 406's tasks.

## Phase 1: Setup

- [X] T-R02G1206-001 Baselines after R02-G12-05 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline is R02-G12-05's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G12-05's
  rendering runs (exit 0)
- [X] T-R02G1206-002 Edit `Packages/ExperiencesRound02/Package.swift` (`HarmonicBridgesCore` and its tests gain — Verified 2026-11-23: Verified 2026-11-23: host exit 0 (HarmonicBridgesCoreTests); HarmonicBridgesExperience and its tests gain VisualCoreAudioDSP and VisualCoreAudio (iOS) as Echo Cartographer's have; the Core already depended on VisualCoreAudioDSP since R02-G12-01
  VisualCoreAudioDSP; `HarmonicBridgesExperience` gains VisualCoreAudioDSP and VisualCoreAudio, iOS-conditioned, as Echo
  Cartographer's targets have); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  HarmonicBridgesCoreTests`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipes (P1, P2) 🎯

- [X] T-R02G1206-003 [P] [US1] [US3] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesFeedbackPlan.swift` — Verified 2026-11-23: Verified 2026-11-23: host-2 exit 0 (HarmonicBridgesFeedbackPlanTests 8 through the real adapter: tunings, undo, redo, 3- and 2-star campaign wins, a practice win without stars, the daily win of 2026-11-23, every refusal code bare and prefixed, a broken test and a budget-ending tuning planning only the outcome, level and mode changes with and without the tutorial, choosing/previewing plans nothing, hint and summary texts); agent A retested by the lead (its choices of mode names, singular words and the summary's level words accepted)
  (texts and kinds of clarification Q1 word for word, the engine's `action.rule.` prefix read as the bare code, including
  the revealed hint as `state` (`hint(text:)`); haptics of Q2 — a test and a budget-ending tuning plan only the outcome;
  `after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `summaryText(core:string:peg:)` of Q5) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesFeedbackPlanTests.swift` (scripted sequences of
  tunings, undos, redos, refusals of every code (bare and prefixed), wins in campaign and practice, failures by a broken
  test and by the budget, and level and mode changes compare texts, kinds and haptics exactly; choosing and previewing
  plan nothing); agent A; `--name host-2`
- [ ] T-R02G1206-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesLights.swift`
  ("glow 0.7 playing / 1 won / 0.35 failed; won 1 once won, else 0", eased linearly over 0.15 s, 0.45 s under Reduce
  Flashing, no reversal mid-fade under Reduce Flashing; `maxHalfRangeCrossingsPerSecond`) and
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSoundRecipe.swift` (`HarmonicBridgesAudition`
  "fundamental 110 Hz × 2^((peg − 1) / 12); one partial per resonant mode n with tone strength w at the fundamental × n,
  gain 0.04 × w; the fundamental alone at gain 0.02 without modes; 0.6 s linear decay"; the ambient recipe "root 110 Hz ×
  (1, 9/8, 5/4, 4/3) for more than 3/4, 1/2, 1/4 of the actions left, or less; one partial per step reached, up to four,
  at the root × (5/4, 3/2, 2, 5/2); octave when won; halved gains when failed; the longest accepted loop with whole
  cycles") with `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesLightsTests.swift` (a scripted win
  and adversarial flicker — a tuning undone and redone every frame, retry, level changes — sampled every 1/60 s: at most
  3 half-range crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing)
  and `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesSoundRecipeTests.swift` (pure; equal inputs
  equal, different inputs different; whole cycles; within the recipe's limits; the muted pluck); agent B; `--name host-3`

## Phase 3: Wiring — shader, presenter, scene, sound and panel

- [ ] T-R02G1206-005 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesShaders.swift`
  (`u_wonLight` scales the won lift; `wonLightUniform`) with its source test in
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesShaderSourceTests.swift`, create
  `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesSound.swift` (the ambient loop over
  `AmbientLoopPlayer` and the audition, playing exactly while wanted, on screen and active), edit
  `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesPresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log; lights stepped per frame; a pluck plays its audition when the sound is on;
  the refusal words from the feedback plan), `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesBridgeScene.swift`
  (the glow gain times the glow level, `u_wonLight` the won level, the resting step with motion 0 and no wave shells
  under Reduce Motion or Reduce Flashing) and `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesControls.swift`
  (a label and a value in words on every control — string and peg with the string in words, Tune the chosen string and
  peg, Test the steps reached, Undo and Redo the actions made, Next level the next open level, Reset view "authored" or
  "orbited", Dismiss the instruction, Retry the level and mode, Play level the picked level, Campaign / Daily / Practice
  "selected" or "not selected", Hint the level shown, Sound "on" or "off" — the adjustable string and peg, the summary
  element, Sound toggle off by default, Dynamic Type layout, 520-point width on iPad); agent C writes
  `Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesAccessibilityTests.swift` (labels and
  non-empty values; the adjustable string and peg; level 1 won through accessibility operations with every step
  announced; recorded announcements and haptics equal the plan; Reduce Motion and Reduce Flashing frames identical; no
  wave shell under Reduce Flashing; the sound state table); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
  --only-testing HarmonicBridgesExperienceTests`

## Phase 4: Regression, documentation and close

- [ ] T-R02G1206-006 Docs: `docs/architecture/harmonic-bridges.md` (polish and accessibility),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1206-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1206-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1206-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1206-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1206-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G1206-006)
- [ ] T-R02G1206-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Agents A and B may start in isolated copies before 001 (their files are new;
A needs R02-G12-05's adapter for level and mode changes). Shared files (Package.swift, shaders, presenter, scene,
controls, docs) stay with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 → 003,
005; FR-004 → 004, 005; FR-006 → 004, 005; FR-007 → 006 … 010.
