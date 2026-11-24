# Tasks: R02-G15-06 — Voxel Origami: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G15-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G15-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_446;
tests stay short (< 10 s each). No {owner} tasks. Model: feature 436's tasks, with its lessons taken into the first
pass (the won look faded in the unlit fallback too; fades ease by the frame clock, not the presentation time Reduce
Motion holds at 0) and round02-host in three chunks (the second chunk reached 450 s at R02-G15-05).

## Phase 1: Setup

- [X] T-R02G1506-001 Baselines after R02-G15-05 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing exit 0; baseline-round02 in three chunks exit 0 (57 s VoxelOrigami, 48 s Moonlit/Acoustic/Harmonic, 339 s the rest)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02` (split into `baseline-round02-1 … 3` by the
  three filters of T-006 if it nears 450 s); the rendering baseline is R02-G15-05's rendering runs (exit 0)
- [X] T-R02G1506-002 Edit `Packages/ExperiencesRound02/Package.swift` (`VoxelOrigamiCore` and its tests gain — Verified 2026-11-24: 2026-11-24: VoxelOrigamiCore and tests gain VisualCoreAudioDSP; VoxelOrigamiExperience and tests gain VisualCoreAudioDSP and VisualCoreAudio (iOS); host exit 0
  VisualCoreAudioDSP; `VoxelOrigamiExperience` and its tests gain VisualCoreAudioDSP and VisualCoreAudio,
  iOS-conditioned, as Moonlit Mechanism's targets have); `--name host -- swift test --package-path
  Packages/ExperiencesRound02 --filter VoxelOrigamiCoreTests`

## Phase 2: Stories 1 and 3 — feedback plan, lights and sound recipes (P1, P2) 🎯

- [X] T-R02G1506-003 [P] [US1] [US3] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiFeedbackPlan.swift` — Verified 2026-11-24: 2026-11-24: agent A VoxelOrigamiFeedbackPlan (Q1 texts word for word, prefix read, outcome-only for level-ending turns, summaryText); 8 tests on real cores (turns, undo, redo, every refusal code, campaign/practice/daily wins, collision, sweep, budget, level and mode changes); lead retest host-2 exit 0
  (texts and kinds of clarification Q1 word for word, the engine's `action.rule.` prefix read as the bare code, a
  revealed hint as `state` (`hint(text:)`); haptics of Q2 — a turn that ends the level plans only the outcome;
  `after(old:new:)`, `refused(code:)`, `refusalText(code:)`, `summaryText(core:hinge:)` of Q5) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiFeedbackPlanTests.swift` (scripted sequences of turns,
  undos, redos, refusals of every code (bare and prefixed), wins in campaign and practice, failures by collision, sweep
  and budget, and level and mode changes compare texts, kinds and haptics exactly; choosing a hinge plans nothing);
  agent A; `--name host-2`
- [X] T-R02G1506-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiLights.swift` — Verified 2026-11-24: 2026-11-24: agent B VoxelOrigamiLights (0.15/0.45 s, frame clock, no mid-fade reversal under Reduce Flashing) and VoxelOrigamiSoundRecipe (hinge tones, chord or 3 Hz beat, ambient by actions share and cubes-in-place quarters, whole-cycle loops); 20 tests incl. adversarial flicker within 3 crossings/s and ≥ 0.4 s fades; lead retest host-3 exit 0
  ("glow 0.7 playing / 1 won / 0.35 failed; won 1 once won, else 0", eased linearly over 0.15 s, 0.45 s under Reduce
  Flashing, no reversal mid-fade under Reduce Flashing, stepped by the frame clock's elapsed time;
  `maxHalfRangeCrossingsPerSecond`) and `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiSoundRecipe.swift`
  (`VoxelOrigamiAudition` "hinge h's tone 220 Hz × 2^((h − 1) / 12); a turnable hinge with its fifth (× 3/2), a hinge
  that swings nothing with a partial 3 Hz above, gain 0.04 each; 0.6 s linear decay"; the ambient recipe "root 110 Hz ×
  (1, 9/8, 5/4, 4/3) for more than 3/4, 1/2, 1/4 of the actions left, or less; one partial per quarter of the cubes in
  place, up to four, at the root × (5/4, 3/2, 2, 5/2); the root alone when fewer than a quarter; octave when won; halved
  gains when failed; the longest accepted loop with whole cycles") with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiLightsTests.swift` (a scripted win and adversarial
  flicker — a turn undone and redone every frame, retry, level changes — sampled every 1/60 s: at most 3 half-range
  crossings per second and every complete one-way fade over half the range ≥ 0.4 s under Reduce Flashing) and
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiSoundRecipeTests.swift` (pure; equal inputs equal,
  different inputs different; whole cycles; within the recipe's limits; a turnable hinge gives a consonant chord, an idle
  one a 3 Hz beat); agent B; `--name host-3`

## Phase 3: Wiring — presenter, scene, sound and panel

- [X] T-R02G1506-005 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiSound.swift` — Verified 2026-11-24: 2026-11-24: VoxelOrigamiSound (loop and audition, A21 rule), presenter feedback route with log, lights stepped by the frame clock, hinge audition on choice, refusal sentences; scene glow gain × glow level, u_won and fallback won level in tenths; panel labels and values, adjustable hinge, summary element, Sound toggle, Dynamic Type rows, 520-pt width; refusal-word assertions in the wiring and teaching tests updated; agent C 10 accessibility tests; 46 simulator tests; sim-27 exit 0
  (the ambient loop over `AmbientLoopPlayer` and the audition, playing exactly while wanted, on screen and active); edit
  `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiPresenter.swift` (feedback through
  `ExperienceFeedback` with a feedback log; lights stepped per frame by the frame clock; choosing a hinge plays its
  audition when the sound is on; the refusal words from the feedback plan),
  `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiVoxelScene.swift` (the glow gain times the glow level,
  `u_won` the won level; in the fallback path `lights.won` passed to the parts' `wonLevel`, the fallback rebuilt when the
  level moves by a tenth or more) and `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiControls.swift`
  (a label and a value in words on every control — the hinge adjustable with its words, Turn the hinge, Undo and Redo
  the actions made, Next level the next open level, Reset view "authored" or "orbited", Dismiss the instruction, Retry
  the level and mode, Play level the picked level, Campaign / Daily / Practice "selected" or "not selected", Hint the
  level shown, Sound "on" or "off" — the summary element, Sound toggle off by default, Dynamic Type layout, 520-point
  width on iPad); agent C writes `Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiAccessibilityTests.swift`
  (labels and non-empty values; the adjustable hinge; level 1 won through accessibility operations with every step
  announced; recorded announcements and haptics equal the plan; Reduce Motion and Reduce Flashing frames identical; the
  sound state table; a won level in fallback mode under Reduce Flashing brightens over at least 0.4 s), given the
  presenter's exact texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing VoxelOrigamiExperienceTests`

## Phase 4: Regression, documentation and close

- [X] T-R02G1506-006 Docs: `docs/architecture/voxel-origami.md` (polish and accessibility), — Verified 2026-11-24: 2026-11-24: architecture polish section, ExperiencesRound02 README, testing doc; round02-host in three chunks exit 0 (74 s, 57 s, 324 s)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1 -- … --filter
  VoxelOrigami`, `--name round02-host-2 -- … --filter 'MoonlitMechanism|AcousticConstellator|HarmonicBridges'`,
  `--name round02-host-3 -- … --skip 'VoxelOrigami|MoonlitMechanism|AcousticConstellator|HarmonicBridges'`
- [X] T-R02G1506-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G1506-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-24: 2026-11-24: reference-1 exit 0
- [X] T-R02G1506-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-24: 2026-11-24: reference-2 exit 0
- [ ] T-R02G1506-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1506-011 {device} After ImplementationLock-100: sound, haptics and VoiceOver on D1/D2/D3 (SC-R02G1506-006)
- [ ] T-R02G1506-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead; agent C writes the accessibility tests) → 006 … 010,
012. 011 stays open until device testing. Agents A and B may start in isolated copies before 001 (their files are new; B
needs VisualCoreAudioDSP in its copy's Core target). Shared files (Package.swift, presenter, scene, controls, docs) stay
with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/005 → 005; FR-002/003 → 003, 005; FR-004 → 004, 005;
FR-006 → 004, 005; FR-007 → 006 … 010.
