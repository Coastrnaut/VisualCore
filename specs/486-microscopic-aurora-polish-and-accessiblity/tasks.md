# Tasks: R02-G19-06 — Microscopic Aurora: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G19-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G19-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_486;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 476's tasks, with its lessons taken into the first
pass (the won look faded in the unlit fallback by blending the not-won and won colours, since the fallback's won input
is a flag; fades ease by the frame clock; refusal sentences in the teaching and gesture tests updated with the panel's
new refusal words; the presenter never drops a selection change because the core is unchanged — the selection lives in
the mirror) and round02-host in five chunks (1, 2, 3c, 3e, 3f; Microscopic Aurora in 3e).

## Phase 1: Setup

- [X] T-R02G1906-001 Baselines on the committed tree after R02-G19-05 is recorded: `--name baseline-host`, `--name — Verified 2026-11-26: baselines exit 0 on the committed tree after the R02-G19-05 record (host, timing, round02-1, -2, -3c, -3e, -3f); rendering baseline is R02-G19-05's rendering runs
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters); the rendering
  baseline is R02-G19-05's rendering runs (exit 0)
- [X] T-R02G1906-002 Edit `Packages/ExperiencesRound02/Package.swift` (`MicroscopicAuroraCore` and its tests gain — Verified 2026-11-26: Package.swift: MicroscopicAuroraCore and its tests gain VisualCoreAudioDSP; the experience and its tests gain VisualCoreAudioDSP and VisualCoreAudio (iOS); host exit 0 (MicroscopicAuroraCoreTests)
  VisualCoreAudioDSP (the tests also VisualCoreExperience); `MicroscopicAuroraExperience` and its tests gain
  VisualCoreAudioDSP and VisualCoreAudio, iOS-conditioned, as Apsides Workshop's targets have); `--name host -- swift
  test --package-path Packages/ExperiencesRound02 --filter MicroscopicAuroraCoreTests`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipes (P1, P2) 🎯

- [X] T-R02G1906-003 [P] [US1] [US3] Create — Verified 2026-11-26: host-2 exit 0: feedback plan texts, kinds and haptics exact for placements, removals, undo, redo, every refusal code bare and prefixed, wins in campaign, practice and daily, failures of all four kinds, level and mode changes; clock.show plans nothing (7 tests)
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraFeedbackPlan.swift` (texts and kinds of
  clarification Q1 word for word, the engine's `action.rule.` prefix read as the bare code, a revealed hint as `state`
  (`hint(text:)`); haptics of Q2 — the play plans only its outcome; `after(old:new:)`, `refused(code:)`,
  `refusalText(code:)`, `summaryText(core:selected:slot:)` of Q5) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraFeedbackPlanTests.swift` (scripted sequences
  of placements and removals, undos, redos, refusals of every code (bare and prefixed), won plays in campaign and
  practice, failed plays by every failure kind (exit, coherence, coverage, connectedness), and level and mode changes
  compare texts, kinds and haptics exactly; showing a tick plans nothing); agent A; `--name host-2`
- [X] T-R02G1906-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraLights.swift` — Verified 2026-11-26: host-3 exit 0: lights fade 0.15/0.45 s, at most 3 half-range crossings per second and fades >= 0.4 s under Reduce Flashing over a scripted win and adversarial flicker; audition and ambient recipes pure, whole-cycle loops, consonant interval vs 3 Hz beat (20 tests)
  ("glow 0.7 playing / 1 won / 0.35 failed; won 1 once won, else 0", eased linearly over 0.15 s, 0.45 s under Reduce
  Flashing, no reversal mid-fade under Reduce Flashing, stepped by the frame clock's elapsed time;
  `maxHalfRangeCrossingsPerSecond`) and
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSoundRecipe.swift` (`MicroscopicAuroraAudition`
  "tone 220 Hz × 2^(n / 12), n = 3 × (strength − 1); a well that can be placed with × 3/2 (clockwise) or × 4/3
  (counterclockwise), one that cannot with a partial 3 Hz above, gain 0.04 each; 0.6 s linear decay"; the ambient
  recipe "root 110 Hz × (1, 9/8, 5/4, 4/3) for more than 3/4, 1/2, 1/4 of the actions left, or less; one partial per
  quarter of the needed stencil cells lit, up to four, at the root × (5/4, 3/2, 2, 5/2); the root alone when fewer than a
  quarter; octave when won; halved gains when failed; the longest accepted loop with whole cycles") with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraLightsTests.swift` (a scripted win and
  adversarial flicker — a placement undone and redone every frame, retry, level changes — sampled every 1/60 s: at most
  3 half-range crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing)
  and `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraSoundRecipeTests.swift` (pure; equal
  inputs equal, different inputs different; whole cycles; within the recipe's limits; a placeable well gives a consonant
  interval, one that cannot be placed a 3 Hz beat); agent B; `--name host-3`

## Phase 3: Wiring — presenter, scene, sound and panel

- [X] T-R02G1906-005 [US1] [US2] [US3] Create — Verified 2026-11-26: sound player (ambient loop and audition, wanted x on screen x active), presenter feedback route with log, lights by the frame clock, selection auditions, refusal words from the feedback plan; scene eased glow, u_won and fallback colour blend; panel labels and values, adjustable slot, site and strength, summary, Sound toggle, Dynamic Type rows, 520-point width; MicroscopicAuroraAccessibilityTests (12) and refusal sentences in the teaching and wiring tests; won render test settles the fade; sim-27 exit 0 (58 tests)
  `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraSound.swift` (the ambient loop over
  `AmbientLoopPlayer` and the audition, playing exactly while wanted, on screen and active); edit
  `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraPresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log; lights stepped per frame by the frame clock; changing the panel's selection
  (slot, site, strength, sense) plays its audition when the sound is on, never drag previews; the refusal words from the
  feedback plan), `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraDishScene.swift` (the glow
  gain times the glow level, `u_won` the won level; in the fallback path the not-won and won parts' colours blended by
  `lights.won`, the fallback rebuilt when the level moves by a tenth or more) and
  `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraControls.swift` (a label and a value in
  words on every control — the slot, site and strength adjustable with their words, the sense toggle "clockwise" or
  "counterclockwise", Place the selected well, Remove the slot's well, the shown tick, Play, Undo and Redo the actions
  made, Next level the next open level, Freeze "frozen" or "not frozen", Reset view "authored" or "orbited", Dismiss
  the instruction, Play level the picked level, Campaign / Daily / Practice "selected" or "not selected", Hint the level
  shown, Sound "on" or "off" — the summary element, Sound toggle off by default, Dynamic Type layout, 520-point width on
  iPad); agent C writes `Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraAccessibilityTests.swift`
  (labels and non-empty values; the adjustable slot, site and strength; level 1 won through accessibility operations
  with every step announced; recorded announcements and haptics equal the plan; Reduce Motion and Reduce Flashing frames
  identical; the sound state table; a won level in fallback mode under Reduce Flashing brightens over at least 0.4 s),
  given the presenter's exact texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  MicroscopicAuroraExperienceTests`

## Phase 4: Regression, documentation and close

- [X] T-R02G1906-006 Docs: `docs/architecture/microscopic-aurora.md` (polish and accessibility), — Verified 2026-11-26: docs updated (architecture polish and accessibility, round-two README, automatedtesting); round02-host-1, -2, -3c, -3e, -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the five round-two filters)
- [ ] T-R02G1906-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1906-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1906-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1906-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1906-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G1906-006)
- [ ] T-R02G1906-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Agents A and B may start in isolated copies before 001 (their files are new; B
needs VisualCoreAudioDSP in its copy's Core target). Shared files (Package.swift, presenter, scene, controls, docs) stay
with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 → 003, 005; FR-004 → 004, 005;
FR-006 → 004, 005; FR-007 → 006 … 010.
