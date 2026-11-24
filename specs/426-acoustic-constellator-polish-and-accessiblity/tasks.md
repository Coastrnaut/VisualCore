# Tasks: R02-G13-06 — Acoustic Constellator: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G13-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G13-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_426;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 416's tasks, with its convergence lesson (the won look
faded in the unlit fallback too) taken into the first pass.

## Phase 1: Setup

- [X] T-R02G1306-001 Baselines after R02-G13-05 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on d89682515 (.autonomy/migration/checks/R02-G13-06.baseline-*.json); rendering baseline = R02-G13-05 rendering-27/26
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G13-05's
  rendering runs (exit 0)
- [ ] T-R02G1306-002 Edit `Packages/ExperiencesRound02/Package.swift` (`AcousticConstellatorCore` already has
  VisualCoreAudioDSP; `AcousticConstellatorExperience` and its tests gain VisualCoreAudioDSP and VisualCoreAudio,
  iOS-conditioned, as Harmonic Bridges' targets have); `--name host -- swift test --package-path
  Packages/ExperiencesRound02 --filter AcousticConstellatorCoreTests`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipes (P1, P2) 🎯

- [ ] T-R02G1306-003 [P] [US1] [US3] Create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorFeedbackPlan.swift` (texts and kinds of
  clarification Q1 word for word, the engine's `action.rule.` prefix read as the bare code, including the revealed hint
  as `state` (`hint(text:)`); haptics of Q2 — a listen and a budget-ending action plan only the outcome;
  `after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `summaryText(core:star:partner:)` of Q5) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorFeedbackPlanTests.swift` (scripted
  sequences of links, unlinks, nudges, undos, redos, refusals of every code (bare and prefixed), wins in campaign and
  practice, failures by each listen outcome and by the budget, and level and mode changes compare texts, kinds and
  haptics exactly; choosing and the drag preview plan nothing); agent A; `--name host-2`
- [ ] T-R02G1306-004 [P] [US2] [US3] Create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorLights.swift` ("glow 0.7 playing / 1 won /
  0.35 failed; won 1 once won, else 0", eased linearly over 0.15 s, 0.45 s under Reduce Flashing, no reversal mid-fade
  under Reduce Flashing; `maxHalfRangeCrossingsPerSecond`) and
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSoundRecipe.swift`
  (`AcousticConstellatorAudition` "two tones 220 Hz × 2^(rate / 12), gain 0.04 each, the second detuned upward by
  g × 1.5 Hz for the phase gap g at the shown tick; 0.6 s linear decay"; the ambient recipe "root 110 Hz × (1, 9/8, 5/4,
  4/3) for more than 3/4, 1/2, 1/4 of the actions left, or less; one partial per lit quarter of the coherence gauge at the
  last tick of the current listen report, up to four, at the root × (5/4, 3/2, 2, 5/2); the root alone when none is lit;
  octave when won; halved gains when failed; the longest accepted loop with whole cycles") with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorLightsTests.swift` (a scripted win and
  adversarial flicker — a link undone and redone every frame, retry, level changes — sampled every 1/60 s: at most 3
  half-range crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing) and
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorSoundRecipeTests.swift` (pure; equal
  inputs equal, different inputs different; whole cycles; within the recipe's limits; a gap of 0 gives no detune); agent
  B; `--name host-3`

## Phase 3: Wiring — shader, geometry fallback, presenter, scene, sound and panel

- [ ] T-R02G1306-005 [US1] [US2] [US3] Edit
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorShaders.swift` (`u_wonLight` scales the won
  look: the `wonLink` material's lift and the `.wonGlow` strips; `wonLightUniform`) with its source test in
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorShaderSourceTests.swift`; give
  `AcousticConstellatorSceneGeometry.constellationPart` and `glowPart`
  (`Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSceneGeometry.swift`) a won level 0 … 1
  that scales the lift of their fallback colours (default: the snapshot's won state, so existing callers are unchanged),
  tested in `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorSceneGeometryTests.swift`
  (the lift scales monotonically, positions never change); create
  `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorSound.swift` (the ambient loop over
  `AmbientLoopPlayer` and the audition, playing exactly while wanted, on screen and active); edit
  `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorPresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log; lights stepped per frame; a link inspection plays its audition when the sound
  is on; the refusal words from the feedback plan),
  `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorConstellationScene.swift` (the glow
  gain times the glow level, `u_wonLight` the won level, tick 0 with pulse 0 and no wave shells under Reduce Motion or
  Reduce Flashing; in the fallback path `lights.won` passed to the parts, the fallback rebuilt when the level moves by a
  tenth or more) and `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorControls.swift` (a
  label and a value in words on every control — star and partner with the stars in words, Link and Unlink the chosen
  pair, Nudge the chosen star, Listen the missing pairs, Undo and Redo the actions made, Next level the next open level,
  Reset view "authored" or "orbited", Dismiss the instruction, Retry the level and mode, Play level the picked level,
  Campaign / Daily / Practice "selected" or "not selected", Hint the level shown, Sound "on" or "off" — the adjustable
  star and partner, the summary element, Sound toggle off by default, Dynamic Type layout, 520-point width on iPad);
  agent C writes `Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorAccessibilityTests.swift`
  (labels and non-empty values; the adjustable star and partner; level 1 won through accessibility operations with
  every step announced; recorded announcements and haptics equal the plan; Reduce Motion and Reduce Flashing frames
  identical; no wave shell under Reduce Flashing; the sound state table; a won level in fallback mode under Reduce
  Flashing brightens over at least 0.4 s), given the presenter's exact texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing AcousticConstellatorExperienceTests`

## Phase 4: Regression, documentation and close

- [ ] T-R02G1306-006 Docs: `docs/architecture/acoustic-constellator.md` (polish and accessibility),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1306-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1306-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1306-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1306-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1306-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G1306-006)
- [ ] T-R02G1306-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Agents A and B may start in isolated copies before 001 (their files are new;
A needs R02-G13-05's adapter for level and mode changes). Shared files (Package.swift, shaders, geometry, presenter,
scene, controls, docs) stay with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 →
003, 005; FR-004 → 004, 005; FR-006 → 004, 005; FR-007 → 006 … 010.
