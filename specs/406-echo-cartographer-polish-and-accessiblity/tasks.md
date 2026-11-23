# Tasks: R02-G11-06 — Echo Cartographer: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G11-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G11-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_406;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 396's tasks, including its convergence lesson (every
native control carries a value in words from the start).

## Phase 1: Setup

- [X] T-R02G1106-001 Baselines after R02-G11-05 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree; rendering baseline is R02-G11-05's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G11-05's
  rendering runs (exit 0)
- [X] T-R02G1106-002 Edit `Packages/ExperiencesRound02/Package.swift` (`EchoCartographerCore` and its tests gain — Verified 2026-11-23: host (EchoCartographer core tests with the new VisualCoreAudioDSP dependency) exit 0
  VisualCoreAudioDSP; `EchoCartographerExperience` gains VisualCoreAudioDSP and VisualCoreAudio, iOS-conditioned, as
  Backwards Aurora's targets have); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  EchoCartographerCoreTests`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipe (P1, P2) 🎯

- [X] T-R02G1106-003 [P] [US1] [US3] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerFeedbackPlan.swift` (texts and kinds of — Verified 2026-11-23: host-2 (186 EchoCartographer core tests incl. EchoCartographerFeedbackPlanTests 8: scripted pulses, located and missed claims, markers placed and removed, undos, redos, every refusal code, campaign and practice wins, failures by pulse and by missed claim (outcome only), level and mode changes, tutorial dismiss (none), hints and summary texts compared exactly) exit 0, lead retest
  clarification Q1 word for word — a missed claim's m is the energy the miss actually took (energy before minus
  after, never more than was left) — including the revealed hint as `state` (`hint(text:)`); haptics of Q2;
  `after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `summaryText(core:cursor:)` of Q5) with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerFeedbackPlanTests.swift` (scripted sequences of pulses, located and missed claims,
  markers placed and removed, undos, redos, refusals of every code, wins in campaign and practice, failures by a pulse
  and by a missed claim, and level and mode changes compare texts, kinds and haptics exactly; an action that ends the
  play plans only the outcome; cursor moves plan nothing); agent A; `--name host-2`
- [ ] T-R02G1106-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerLights.swift` ("glow 0.7 playing / 1 won / 0.35
  failed; won 1 once won, else 0", eased linearly over 0.15 s, 0.45 s under Reduce Flashing, no reversal mid-fade under
  Reduce Flashing; `maxHalfRangeCrossingsPerSecond`) and `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSoundRecipe.swift` ("root 110 Hz ×
  (1, 9/8, 5/4, 4/3) for more than 3/4, 1/2, 1/4 of the energy left, or less; one partial per located beacon, up to
  four, at the root × (5/4, 3/2, 2, 5/2); octave when won; halved gains when failed; the longest accepted loop with whole
  cycles") with `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerLightsTests.swift` (a scripted win and adversarial flicker — a pulse undone
  and redone every frame, retry, level changes — sampled every 1/60 s: at most 3 half-range crossings per second and
  every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing) and
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerSoundRecipeTests.swift` (pure; equal inputs equal, different inputs different; whole
  cycles; within the recipe's limits); agent B; `--name host-3`

## Phase 3: Wiring — shader, presenter, scene, sound and panel

- [ ] T-R02G1106-005 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerShaders.swift` (`u_wonLight` scales the won lift;
  `wonLightUniform`) with its source test in `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerShaderSourceTests.swift`, add the new Core
  files that use Doubles to `presentationSources` in `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerInvariantTests.swift` (lights, sound
  recipe, feedback plan if it does), create `Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerSound.swift` (the ambient loop over
  `AmbientLoopPlayer`, playing exactly while wanted, on screen and active), edit
  `Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerPresenter.swift` (feedback through `ExperienceFeedback` with a feedback log, lights
  stepped per frame), `Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerChamberScene.swift` (the glow gain times the glow level,
  `u_wonLight` the won level, `u_reduceMotion` 1 under Reduce Motion or Reduce Flashing) and
  `Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerControls.swift` (a label and a value in words on every control — column and row with the
  cell in words, Pulse, Claim and Mark the chosen cell, Undo and Redo the actions made, Next level the next open level,
  Reset view "authored" or "orbited", Dismiss the instruction, Retry the level and mode, Play level the picked level,
  Campaign / Daily / Practice "selected" or "not selected", Hint the level shown, Sound "on" or "off" — the adjustable
  column and row, the summary element, Sound toggle off by default, Dynamic Type layout, 520-point width on iPad);
  agent C writes `Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/EchoCartographerAccessibilityTests.swift` (labels and non-empty values; the
  adjustable column and row; level 1 won through accessibility operations with every step announced; recorded
  announcements and haptics equal the plan; Reduce Motion frames identical; no ring or flare under Reduce Flashing; the
  loop's state table); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing EchoCartographerExperienceTests`

## Phase 4: Regression, documentation and close

- [ ] T-R02G1106-006 Docs: `docs/architecture/echo-cartographer.md` (polish and accessibility),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1106-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1106-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1106-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1106-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1106-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G1106-006)
- [ ] T-R02G1106-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Agents A and B may start in isolated copies before 001 (their files are new).
Shared files (Package.swift, shaders, invariant test, presenter, scene, controls, docs) stay with the lead. MVP: Stories
1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 → 003, 005; FR-004 → 004, 005; FR-006 → 004, 005; FR-007 →
006 … 010.
