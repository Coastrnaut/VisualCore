# Tasks: R02-G21-06 — Binary Gardens: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G21-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_506;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 496's tasks, with its lessons taken into the first
pass (the won look faded in the unlit fallback by blending the not-won and won colours; fades ease by the frame clock;
refusal sentences in the R02-G21-04 and R02-G21-05 tests updated with the panel's new refusal words; the presenter
never drops a selection change because the core is unchanged — the selected star lives in the presenter) and
round02-host in five chunks (1, 2, 3c, 3e, 3f). Prerequisites: R02-G21-04 and R02-G21-05 recorded.

## Phase 1: Setup

- [X] T-R02G2106-001 Baselines on the committed tree after R02-G21-05 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 (after R02-G21-05 was recorded)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters); the rendering
  baseline is R02-G21-05's rendering runs (exit 0)
- [X] T-R02G2106-002 Edit `Packages/ExperiencesRound02/Package.swift` (`BinaryGardensCore` and its tests gain — Verified 2026-11-27: host exit 0 (swift test --filter BinaryGardensCoreTests) with VisualCoreAudioDSP on Core and tests, VisualCoreAudioDSP and VisualCoreAudio (iOS) on Experience and tests
  VisualCoreAudioDSP (the tests also VisualCoreExperience); `BinaryGardensExperience` and its tests gain
  VisualCoreAudioDSP and VisualCoreAudio, iOS-conditioned, as Mushroom Weather's targets have); `--name host -- swift
  test --package-path Packages/ExperiencesRound02 --filter BinaryGardensCoreTests`

## Phase 2: Stories 1, 2 and 3 — feedback plan, lights, bloom levels and sound recipes (P1, P2) 🎯

- [X] T-R02G2106-003 [P] [US1] [US3] Create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensFeedbackPlan.swift` — Verified 2026-11-27: host-2 exit 0 (swift test --filter BinaryGardens: 275 tests in 26 suites; FeedbackPlan 13 pass)
  (text, kind, haptic and trigger; the texts and kinds of clarification Q1 word for word — "Star n moved to ring r (ρ
  units).", "Star n shifted to phase p.", "Star n's luminosity set to L.", "Tilt set to t of T steps.", "Undone.",
  "Redone.", each followed by the worlds keeping their light, whether running now would win or fail and the actions left;
  "a world keeps its light" as its longest lethal run within the tolerance, its comfortable window at least the required
  window and its total light inside its bloom band, judged on the arrangement's report; wins and failures `outcome` (the
  failure text R02-G21-05's `BinaryGardensFailureExplanation`), level and mode changes `level`, refusals `rejection` with
  a sentence per code (locked, date, action, budget, stage, stale, level, generation, not-whole, tick) and a default, the
  engine's `action.rule.` prefix read as the bare code; a revealed hint as `state` (`hint(text:)`); haptics of Q2 —
  selection for an accepted arrangement action, undo or redo, success for a win, warning for a failure, error for a
  refusal, nothing for selection, previews, the shown tick, the view or level changes; the run plans only its outcome;
  `after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `summaryText(...)` of Q5, `keepsLight`,
  `worldsKeepingLight`, `modeName`; the trigger is "the control, the bare refusal code, "hint" or "level"") with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensFeedbackPlanTests.swift` (scripted sequences of
  ring, phase, luminosity and tilt actions, undos, redos, refusals of every code (bare and prefixed), won runs in
  campaign, daily and practice, failed runs by every failure kind (frozen, scorched, unstable, wilted, bleached), and
  level and mode changes compare texts, kinds, haptics and triggers exactly; showing a tick plans nothing; equal inputs
  give equal plans); agent B; `--name host-2 -- swift test --package-path Packages/ExperiencesRound02 --filter
  BinaryGardens`
- [X] T-R02G2106-004 [P] [US2] [US3] [US4] Create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensLights.swift` — Verified 2026-11-27: host-2 exit 0 covers it (same command on the tree with T-004 installed; Lights 9, SoundRecipe 6, geometry +2 pass)
  ("glow 0.7 playing / 1 won / 0.35 failed (only once the run failed); won 1 once won, else 0; bloom 1 when the world is
  comfortable at the drawn shown tick or the level is won, else 0", eased linearly over 0.15 s, 0.45 s under Reduce
  Flashing, a started fade finishing before turning back under Reduce Flashing, stepped by the frame clock's elapsed
  time; the first frame settles; a level with another world count carries blooms by index and starts new worlds at 0;
  `maxHalfRangeCrossingsPerSecond`) and `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSoundRecipe.swift`
  (`BinaryGardensPartial`, `BinaryGardensAudition` "tone 220 Hz × 2^(n / 12), n = 2 × (7 − ring index clamped to
  0 … 7); with the tone × 3/2 when the star can change, with a partial 3 Hz above the tone when it cannot; gain 0.04
  each; 0.6 s linear decay"; the ambient recipe "root 110 Hz × (1, 9/8, 5/4, 4/3) by the actions-left share; one partial
  per quarter of the worlds keeping their light (≤ 4, at root × 5/4, 3/2, 2, 5/2); a brightness partial at root × 3 with
  the base amplitude × (i₁ + i₂) / (2 × (m − 1)); the octave (merged) and two swells per loop when won, halved
  amplitudes and gain when failed; ≤ 6 partials, gain ≤ 0.3, 4 … 16 s, a whole number of cycles per partial"); edit
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSceneGeometry.swift` (`glowPart` and `glowMesh` take
  optional bloom levels as each world's shell factor; nil gives today's mesh bit for bit; the presenter rebuilds when a
  bloom level crosses a 1/32 step) with `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensLightsTests.swift`
  (a scripted win and adversarial flicker — a ring change undone and redone every frame, a failed run undone and redone
  every frame, the shown tick stepped back and forth every frame, level changes — sampled every 1/60 s: at most 3
  half-range crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing),
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSoundRecipeTests.swift` (pure; equal inputs equal,
  different inputs different; whole cycles; every reachable recipe within the shared player's limits; a star that can
  change gives a consonant fifth, one that cannot a 3 Hz beat) and additions to
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSceneGeometryTests.swift` (nil bloom levels equal
  today's mesh; fractional levels set the shell factor); agent C; `--name host-3 -- swift test --package-path
  Packages/ExperiencesRound02 --filter BinaryGardens`

## Phase 3: Wiring — presenter, scene, sound and panel

- [X] T-R02G2106-005 [US1] [US2] [US3] [US4] Create `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensSound.swift` — Verified 2026-11-27: sim-27-2 exit 0 (sim-27.2, BinaryGardensExperienceTests: 69 tests in 7 suites; 13 accessibility tests; first attempt sim-27 exit 65 on three test assumptions fixed: a not-whole value sent to a valueless control, the won-look pixel check replaced by the drawn won level, star 2 selected on level 1)
  (the ambient loop over `AmbientLoopPlayer` and the audition over `SoundEffectPlayer`, playing exactly while the Sound
  toggle is on, the controls are on screen and the scene is active); edit
  `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensPresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log kept beside the tier log and R02-G21-04's refusal log; lights stepped per
  frame by the frame clock from the drawn snapshot (preview applied); changing the selected star plays its audition when
  the sound is on, never previews; the refusal words from the feedback plan; a tier change or memory warning resets
  nothing), `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensSystemScene.swift` (the glow gain times
  the glow level, each world's shell factor its bloom level, the won uniform the won level, the time held at 0 under
  Reduce Motion or Reduce Flashing; in the fallback path the not-won and won colours blended by `lights.won`, rebuilt
  when the level moves by a tenth or more) and `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensControls.swift`
  (a label and a value in words on every control of clarification Q5 — the star, ring, phase, luminosity, tilt and
  shown tick adjustable with ", locked" for a locked control, ring, phase, luminosity and tilt one action per step, star
  and tick presentation only; Run, Undo, Redo, Next level, Reset view, Inspect, Hint, Dismiss tutorial, the level
  picker, Campaign / Daily / Practice and Sound "on" or "off" with values; the summary element; the Sound toggle off by
  default; button rows wrapping into a column at accessibility sizes; at most 520 points wide on iPad); edit
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensRenderTests.swift`
  (`aWonLevelBloomsEveryWorld` draws one settling frame before its checked frame) and update in place the refusal lines
  of the R02-G21-04 and R02-G21-05 tests that assert the former refusal words (FR-R02G2106-009); agent D writes
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensAccessibilityTests.swift` (labels and
  non-empty values; the adjustables; level 1 won through accessibility operations with every step announced; recorded
  announcements and haptics equal the plan; Reduce Motion and Reduce Flashing frames still between actions; the sound
  state table; a won level in fallback mode under Reduce Flashing brightens over at least 0.4 s; the same scripted
  session at level-0, level-1, level-2 and the fallback gives equal feedback logs), given the presenter's exact texts;
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BinaryGardensExperienceTests`

## Phase 4: Regression, documentation and close

- [X] T-R02G2106-006 Docs: `docs/architecture/binary-gardens.md` (polish and accessibility), — Verified 2026-11-27: round02-host-1, -2, -3c, -3e, -3f exit 0; docs: architecture polish section, package README, automatedtesting
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the five round-two filters)
- [X] T-R02G2106-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-27: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G2106-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-27: reference-1 exit 0
- [X] T-R02G2106-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-27: reference-2 exit 0
- [ ] T-R02G2106-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2106-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G2106-006)
- [ ] T-R02G2106-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent B), 004 (agent C)} → 005 (lead; agent D writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Agents B and C may start in isolated copies before 001 (their files are new
or C's geometry edit is confined to its copy; C needs VisualCoreAudioDSP in its copy's Core target). Shared files
(Package.swift, presenter, scene, controls, render tests, docs) stay with the lead. MVP: Stories 1 and 2. Requirement
coverage: FR-001/005 → 005; FR-002/003 → 003, 005; FR-004 → 004, 005; FR-006 → 004, 005; FR-007 → 004, 005; FR-008 →
003, 005; FR-009 → 005 … 010.
