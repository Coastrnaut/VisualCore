# Tasks: R02-G01-06 — Aurora Loom: polish and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-06 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_306;
tests stay short (< 10 s each). {device} items (hearing, feeling, VoiceOver on hardware) are D1–D3 observations after
ImplementationLock-100 and are not tasks here. No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0106-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-20: 2026-11-20 R02-G01-06.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G02-02's rendering runs (exit 0)
- [X] T-R02G0106-002 Add the `VisualCoreAudioDSP` product to `AuroraLoomCore` in `Packages/ExperiencesRound02/Package.swift` — Verified 2026-11-20: 2026-11-20 host exit 0 (whole round-two package with VisualCoreAudioDSP added)
  (no other change); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — VoiceOver play (P1) 🎯

- [X] T-R02G0106-003 [P] [US1] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomFeedbackPlan.swift` (announcement "text and kind" and haptic — Verified 2026-11-20: 2026-11-20 host-2 exit 0 (feedback plan, 5 tests, exact texts)
  per clarifications Q1, Q2; "outcome replaces the move's selection"; `refused(code:)` → rejection + error) with
  `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomFeedbackPlanTests.swift` (exact texts for move, undo, redo, win, failure, level, mode,
  refusal; no plan for an unchanged core); `--name host-2`

## Phase 3: Story 2 — comfort settings (P1)

- [X] T-R02G0106-004 [P] [US2] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomLights.swift` ("12 crossing levels 0…1, win glow 0…1; 0.15 s, — Verified 2026-11-20: 2026-11-20 host-3 exit 0 (lights, 6 tests: ≤ 3 crossings/s and ≥ 0.4 s fades under Reduce Flashing incl. adversarial flicker)
  0.45 s under Reduce Flashing"; `maxHalfRangeCrossingsPerSecond`) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomLightsTests.swift`
  (a scripted win sampled at 60 Hz stays ≤ 3 half-range crossings per second under Reduce Flashing; every half-range
  change takes ≥ 0.4 s; targets reached); `--name host-3`

## Phase 4: Story 3 — sound and haptics (P2)

- [X] T-R02G0106-005 [P] [US3] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSoundRecipe.swift` (pure recipe from steps and stage; won adds a — Verified 2026-11-20: 2026-11-20 host-4 exit 0 (sound recipe, 6 tests, 12,288 valid recipes)
  fifth; failed is quieter) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomSoundRecipeTests.swift` (purity; differs per wave step and
  stage; partials within the recipe type's limits); `--name host-4`

## Phase 5: Wiring (presenter, panel, scene, sound)

- [X] T-R02G0106-006 Edit `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift` (injectable `feedback` route; `adjust(ribbon:control:by:port:)` used by the steppers and their accessibility actions; plans routed through the — Verified 2026-11-20: 2026-11-20 sim-27 exit 0 (round-two simulator suite incl. AuroraLoomAccessibilityTests: recorded announcements and haptics, level 1 won through adjust alone, panel at accessibility5 on 320 pt and iPad, sound state table, Reduce Flashing fades, Reduce Motion)
  port after `describe` and on refusals; feedback log; eased lights stepped each frame), `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomControls.swift`
  (ScrollView, Dynamic Type text styles, labels and values for every control, Sound toggle, iPad width ≤ 520 points,
  refusals through the presenter), `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomRibbonScene.swift` (gate and win brightness from the
  presenter's lights) and create `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomSound.swift` (A21 rule; rebuild at level open, play end, toggle
  on); with `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomAccessibilityTests.swift` (agent C: recorded announcements and haptics through
  the port for scripted sequences with \`RecordingHapticSink\` and \`RecordingAnnouncementSink\`; labels and values; level
  1 completed through the presenter's adjust operation alone (SC-R02G0106-001); panel at the largest text size; sound
  state table including a \`play()\` that fails; Reduce Motion frames identical); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 6: Regression, documentation and close

- [X] T-R02G0106-007 Docs: `docs/architecture/aurora-loom.md` (polish and accessibility), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-20: 2026-11-20 round02-host exit 0; docs/architecture/aurora-loom.md polish section, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md
  `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0106-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-20: 2026-11-20 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0106-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-20: 2026-11-20 reference-1 exit 0
- [ ] T-R02G0106-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0106-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0106-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 and 005 (agent B)} → 006 (lead; agent C writes the simulator tests) → 007 … 012.
Shared files (Package.swift, presenter, controls, scene, sound, docs) stay with the lead. MVP: Story 1.
