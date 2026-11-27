# Tasks: R02-G20-06 — Mushroom Weather: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G20-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G20-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_496;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 486's tasks, with its lessons taken into the first
pass (the won look faded in the unlit fallback by blending the not-won and won colours; fades ease by the frame clock;
refusal sentences in the teaching and gesture tests updated with the panel's new refusal words; the presenter never
drops a selection change because the core is unchanged — the selection lives in the mirror) and round02-host in five
chunks (1, 2, 3c, 3e, 3f; Mushroom Weather in 3f).

## Phase 1: Setup

- [X] T-R02G2006-001 Baselines on the committed tree after R02-G20-05 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit=0 (.autonomy/migration/checks/R02-G20-06.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters); the rendering
  baseline is R02-G20-05's rendering runs (exit 0)
- [X] T-R02G2006-002 Edit `Packages/ExperiencesRound02/Package.swift` (`MushroomWeatherCore` and its tests gain — Verified 2026-11-27: host exit=0 (.autonomy/migration/checks/R02-G20-06.host.json)
  VisualCoreAudioDSP (the tests also VisualCoreExperience); `MushroomWeatherExperience` and its tests gain
  VisualCoreAudioDSP and VisualCoreAudio, iOS-conditioned, as Microscopic Aurora's targets have); `--name host -- swift
  test --package-path Packages/ExperiencesRound02 --filter MushroomWeatherCoreTests`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipes (P1, P2) 🎯

- [X] T-R02G2006-003 [P] [US1] [US3] Create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherFeedbackPlan.swift` — Verified 2026-11-27: host-2 exit=0, MushroomWeatherFeedbackPlanTests passed (.autonomy/migration/checks/R02-G20-06.host-2.json)
  (texts and kinds of clarification Q1 word for word, "colonies staying in band" as the colonies whose final in-band run
  of the predicted run reaches the required cycles, the engine's `action.rule.` prefix read as the bare code, a revealed
  hint as `state` (`hint(text:)`); haptics of Q2 — the run plans only its outcome; `after(old:new:)`, `refused(code:)`,
  `refusalText(code:)`, `summaryText(core:slot:site:)` of Q5) with
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherFeedbackPlanTests.swift` (scripted sequences of
  pod placements, moves and removals, vent and moonlight changes, undos, redos, refusals of every code (bare and
  prefixed), won runs in campaign and practice, failed runs by every failure kind (dried, mold, unstable), and level and
  mode changes compare texts, kinds and haptics exactly; showing a cycle plans nothing); agent A; `--name host-2`
- [X] T-R02G2006-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherLights.swift` — Verified 2026-11-27: host-3 exit=0, MushroomWeatherLightsTests and MushroomWeatherSoundRecipeTests passed (.autonomy/migration/checks/R02-G20-06.host-3.json)
  ("glow 0.7 playing / 1 won / 0.35 failed; won 1 once won, else 0", eased linearly over 0.15 s, 0.45 s under Reduce
  Flashing, no reversal mid-fade under Reduce Flashing, stepped by the frame clock's elapsed time;
  `maxHalfRangeCrossingsPerSecond`) and `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSoundRecipe.swift`
  (`MushroomWeatherAudition` "tone 220 Hz × 2^(n / 12), n = 2 × site index; a site that can take a pod with × 3/2, one
  that cannot with a partial 3 Hz above, gain 0.04 each; 0.6 s linear decay"; the ambient recipe "root 110 Hz × (1, 9/8,
  5/4, 4/3) for more than 3/4, 1/2, 1/4 of the actions left, or less; one partial per quarter of the colonies staying in
  band, up to four, at the root × (5/4, 3/2, 2, 5/2); the root alone when fewer than a quarter; a partial at the root × 3
  with the base gain × moonlight / 3 when the moonlight is above 0; octave when won; halved gains when failed; the
  longest accepted loop with whole cycles") with
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherLightsTests.swift` (a scripted win and
  adversarial flicker — a pod placement undone and redone every frame, retry, level changes — sampled every 1/60 s: at
  most 3 half-range crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce
  Flashing) and `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherSoundRecipeTests.swift` (pure;
  equal inputs equal, different inputs different; whole cycles; within the recipe's limits; a site that can take a pod
  gives a consonant interval, one that cannot a 3 Hz beat); agent B; `--name host-3`

## Phase 3: Wiring — presenter, scene, sound and panel

- [X] T-R02G2006-005 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherSound.swift` — Verified 2026-11-27: sim-27 exit=0, 59 tests in 7 suites incl. MushroomWeatherAccessibilityTests (12) (.autonomy/migration/checks/R02-G20-06.sim-27.json)
  (the ambient loop over `AmbientLoopPlayer` and the audition, playing exactly while wanted, on screen and active); edit
  `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherPresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log; lights stepped per frame by the frame clock; changing the panel's selection
  (slot, site) plays its audition when the sound is on, never drag previews; the refusal words from the feedback plan),
  `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherForestScene.swift` (the glow gain times the glow
  level, the won uniform the won level, motion 0 under Reduce Motion or Reduce Flashing; in the fallback path the not-won
  and won parts' colours blended by `lights.won`, the fallback rebuilt when the level moves by a tenth or more) and
  `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherControls.swift` (a label and a value in words
  on every control — the slot, site and moonlight adjustable with their words, each vent toggle "open" or "closed",
  Place the selected site, Remove the slot's pod, the shown cycle, Run, Undo and Redo the actions made, Next level the
  next open level, Reset view "authored" or "orbited", Dismiss the instruction, Play level the picked level, Campaign /
  Daily / Practice "selected" or "not selected", Hint the level shown, Sound "on" or "off" — the summary element, Sound
  toggle off by default, Dynamic Type layout, 520-point width on iPad); agent C writes
  `Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherAccessibilityTests.swift` (labels and
  non-empty values; the adjustable slot, site and moonlight; level 1 won through accessibility operations with every
  step announced; recorded announcements and haptics equal the plan; Reduce Motion and Reduce Flashing frames identical;
  the sound state table; a won level in fallback mode under Reduce Flashing brightens over at least 0.4 s), given the
  presenter's exact texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MushroomWeatherExperienceTests`

## Phase 4: Regression, documentation and close

- [X] T-R02G2006-006 Docs: `docs/architecture/mushroom-weather.md` (polish and accessibility), — Verified 2026-11-27: docs (architecture polish and accessibility, package README, automatedtesting) and round02-host-1, -2, -3c, -3e, -3f exit=0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the five round-two filters)
- [X] T-R02G2006-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-27: rendering-27, rendering-26, experiences, host-full and app-unit exit=0 (.autonomy/migration/checks/R02-G20-06.{rendering-27,rendering-26,experiences,host-full,app-unit}.json)
  `--name host-full`, `--name app-unit`
- [X] T-R02G2006-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-27: reference-1 exit=0 (.autonomy/migration/checks/R02-G20-06.reference-1.json)
- [X] T-R02G2006-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-27: reference-2 exit=0 (.autonomy/migration/checks/R02-G20-06.reference-2.json)
- [X] T-R02G2006-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-27: script-tests exit=0 (.autonomy/migration/checks/R02-G20-06.script-tests.json)
- [ ] T-R02G2006-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G2006-006)
- [ ] T-R02G2006-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Agents A and B may start in isolated copies before 001 (their files are new; B
needs VisualCoreAudioDSP in its copy's Core target). Shared files (Package.swift, presenter, scene, controls, docs) stay
with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 → 003, 005; FR-004 → 004, 005;
FR-006 → 004, 005; FR-007 → 006 … 010.
