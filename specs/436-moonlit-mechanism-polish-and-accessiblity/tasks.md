# Tasks: R02-G14-06 — Moonlit Mechanism: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G14-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G14-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_436;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 426's tasks, with its convergence lesson (the won look
faded in the unlit fallback too) and this feature's checklist correction (fades ease by the frame clock, not the
presentation time Reduce Motion holds at 0) taken into the first pass.

## Phase 1: Setup

- [X] T-R02G1406-001 Baselines after R02-G14-05 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree (.autonomy/migration/checks/R02-G14-06.baseline-*.json); rendering baseline = R02-G14-05 rendering-27/26
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G14-05's
  rendering runs (exit 0)
- [X] T-R02G1406-002 Edit `Packages/ExperiencesRound02/Package.swift` (`MoonlitMechanismCore` and its tests gain — Verified 2026-11-24: 2026-11-24: MoonlitMechanismCore and its tests gain VisualCoreAudioDSP; the experience and its tests gain VisualCoreAudioDSP and VisualCoreAudio (iOS); host exit 0 (.autonomy/migration/checks/R02-G14-06.host.json)
  VisualCoreAudioDSP; `MoonlitMechanismExperience` and its tests gain VisualCoreAudioDSP and VisualCoreAudio,
  iOS-conditioned, as Acoustic Constellator's targets have); `--name host -- swift test --package-path
  Packages/ExperiencesRound02 --filter MoonlitMechanismCoreTests`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipes (P1, P2) 🎯

- [X] T-R02G1406-003 [P] [US1] [US3] Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismFeedbackPlan.swift` — Verified 2026-11-24: 2026-11-24: agent A feedback plan (texts of Q1 word for word, haptics of Q2, a gear drag planned once, refusal words with the prefix read, summary of Q5); 11 tests on real cores; lead retest host-2 exit 0 (.autonomy/migration/checks/R02-G14-06.host-2.json)
  (texts and kinds of clarification Q1 word for word, the engine's `action.rule.` prefix read as the bare code, a
  revealed hint as `state` (`hint(text:)`); haptics of Q2 — a run and a budget-ending action plan only the outcome; a
  gear drag's turns planned once from the core before the first turn to the core after the last ("Turned the handle
  forward n teeth."); `after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `summaryText(core:gear:)` of Q5) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismFeedbackPlanTests.swift` (scripted sequences
  of turns, re-seats, lamp steps, undos, redos, refusals of every code (bare and prefixed), wins in campaign and practice,
  failures by each run outcome and by the budget, and level and mode changes compare texts, kinds and haptics exactly;
  choosing a gear and showing a key frame plan nothing); agent A; `--name host-2`
- [X] T-R02G1406-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismLights.swift` — Verified 2026-11-24: 2026-11-24: agent B lights (fades 0.15/0.45 s by the frame clock, crossing measure) and sound recipes (gear audition detuned by mesh error, ambient by covered quarters); 17 tests incl. seven flicker patterns; lead retest host-3 exit 0 (.autonomy/migration/checks/R02-G14-06.host-3.json)
  ("glow 0.7 playing / 1 won / 0.35 failed; won 1 once won, else 0", eased linearly over 0.15 s, 0.45 s under Reduce
  Flashing, no reversal mid-fade under Reduce Flashing, stepped by the frame clock's elapsed time;
  `maxHalfRangeCrossingsPerSecond`) and `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSoundRecipe.swift`
  (`MoonlitMechanismAudition` "a gear's tone 220 Hz × 2^((T − 12) / 12), clamped to two octaves; the chosen gear and its
  parent at gain 0.04 each, the second detuned upward by e × 1.5 Hz for the mesh error e; the driver alone; 0.6 s linear
  decay"; the ambient recipe "root 110 Hz × (1, 9/8, 5/4, 4/3) for more than 3/4, 1/2, 1/4 of the actions left, or less;
  one partial per covered quarter of the required target cells, up to four, at the root × (5/4, 3/2, 2, 5/2); the root
  alone when none is covered; octave when won; halved gains when failed; the longest accepted loop with whole cycles")
  with `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismLightsTests.swift` (a scripted win and
  adversarial flicker — a turn undone and redone every frame, retry, level changes — sampled every 1/60 s: at most 3
  half-range crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing) and
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismSoundRecipeTests.swift` (pure; equal inputs
  equal, different inputs different; whole cycles; within the recipe's limits; an aligned mesh gives no detune); agent B;
  `--name host-3`

## Phase 3: Wiring — geometry fallback, presenter, scene, sound and panel

- [X] T-R02G1406-005 [US1] [US2] [US3] Give `MoonlitMechanismSceneGeometry.clockworkPart` and `glowPart` — Verified 2026-11-24: 2026-11-24: fallback won level in clockworkPart (host-4 exit 0, .autonomy/migration/checks/R02-G14-06.host-4.json); MoonlitMechanismSound; presenter feedback route and log (a gear drag held and routed once), lights stepped by the frame clock, gear audition, refusal words from the plan; scene glow gain x glow level, u_won = won level, fallback rebuilt per tenth; panel labels and values on all 28 controls, adjustable gear and key frame, summary, Sound toggle, accessibility-size rows, 520-pt width; render test draws the won frame after the fade, wiring and teaching refusal expectations follow the plan's words; agent C's 10 accessibility tests (one compile fix by the lead); 51 simulator tests; sim-27 exit 0 (.autonomy/migration/checks/R02-G14-06.sim-27.json)
  (`Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSceneGeometry.swift`) a won level 0 … 1 that scales
  the paper's fallback lift (default: the snapshot's won state, so existing callers are unchanged), tested in
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismSceneGeometryTests.swift` (the lift scales
  monotonically, positions never change); create `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismSound.swift`
  (the ambient loop over `AmbientLoopPlayer` and the audition, playing exactly while wanted, on screen and active); edit
  `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismPresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log, a gear drag's turns routed once; lights stepped per frame by the frame clock;
  choosing a gear plays its audition when the sound is on; the refusal words from the feedback plan),
  `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismClockworkScene.swift` (the glow gain times the
  glow level, `u_won` the won level; in the fallback path `lights.won` passed to the parts, the fallback rebuilt when the
  level moves by a tenth or more) and `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismControls.swift`
  (a label and a value in words on every control — gear and key frame adjustable with their words, Turn the progress,
  Re-seat the chosen gear, Lamp the height, Run the progress, Undo and Redo the actions made, Next level the next open
  level, Reset view "authored" or "orbited", Dismiss the instruction, Retry the level and mode, Play level the picked
  level, Campaign / Daily / Practice "selected" or "not selected", Hint the level shown, Sound "on" or "off" — the
  summary element, Sound toggle off by default, Dynamic Type layout, 520-point width on iPad); agent C writes
  `Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismAccessibilityTests.swift` (labels and
  non-empty values; the adjustable gear and key frame; level 1 won through accessibility operations with every step
  announced; recorded announcements and haptics equal the plan; Reduce Motion and Reduce Flashing frames identical; the
  sound state table; a won level in fallback mode under Reduce Flashing brightens over at least 0.4 s), given the
  presenter's exact texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MoonlitMechanismExperienceTests`

## Phase 4: Regression, documentation and close

- [X] T-R02G1406-006 Docs: `docs/architecture/moonlit-mechanism.md` (polish and accessibility), — Verified 2026-11-24: 2026-11-24: architecture polish and accessibility section, ExperiencesRound02 README, testing doc (three lessons); round02-host exit 0 in 378 s (.autonomy/migration/checks/R02-G14-06.round02-host.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1406-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24: rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G14-06.{rendering-27,rendering-26,experiences,host-full,app-unit}.json)
  `--name host-full`, `--name app-unit`
- [X] T-R02G1406-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-24: 2026-11-24: reference-1 exit 0 (.autonomy/migration/checks/R02-G14-06.reference-1.json)
- [X] T-R02G1406-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-24: 2026-11-24: reference-2 exit 0 (.autonomy/migration/checks/R02-G14-06.reference-2.json)
- [X] T-R02G1406-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-24: 2026-11-24: script-tests exit 0 (.autonomy/migration/checks/R02-G14-06.script-tests.json)
- [ ] T-R02G1406-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G1406-006)
- [ ] T-R02G1406-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Agents A and B may start in isolated copies before 001 (their files are new; B
needs VisualCoreAudioDSP in its copy's Core target). Shared files (Package.swift, geometry, presenter, scene, controls,
docs) stay with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 → 003, 005; FR-004 →
004, 005; FR-006 → 004, 005; FR-007 → 006 … 010.
