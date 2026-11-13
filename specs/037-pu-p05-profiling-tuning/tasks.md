# Tasks: Particle Universe — Phase 05 Profiling and low-end device tuning

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/monitor.md](contracts/monitor.md), [quickstart.md](quickstart.md). PU = `Packages/ExperiencesCreative/ParticleUniverse`.

Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A04-P05 --name <check> -- <command>`. Commit after
each task. Tests before code. Owner-only items: none. One {device} task. No VisualCore change.

## Phase 1: Setup

- [X] T-A04-501 Baseline: ExperiencesCreative on sim-27.2 passes before the change (check `baseline-experiences`). — Verified 2026-11-13: ExperiencesCreative on sim-27.2 passed before the change (A04-P05/baseline-experiences)

## Phase 2: User Story 1 — Coming back never fast-forwards (P1)

- [X] T-A04-502 [P] [US1] Write `PU/ExperienceTests/ParticleResumeBoundTests.swift`: through `ExperienceSession` — Verified 2026-11-13: ParticleResumeBoundTests 4 tests through ExperienceSession: background then active, a 600 s engine frame took 8 steps, then 2 steps per 1/60 s frame; host clamp 600 s to 0.1 s; replay digest 3 of 3; paused gap 0 simulation steps; pass on sim-26.5 and 27.2 (A04-P05/experiences-ios26, ios27)
  (pattern of `ParticleSessionTests`): playing scene, background, active, one 600 s frame takes at most 8 steps
  (`maxStepsPerFrame`), then 1/60 s frames take the normal count; a replay of the same history gives the same digest
  3 of 3 times; a paused scene takes 0 steps for the gap.
- [X] T-A04-503 [US1] Acceptance on sim-27.2 (check `resume-ios27`) (SC-A04-501). — Verified 2026-11-13: ParticleResumeBoundTests pass on sim-27.2 within the package run (A04-P05/experiences-ios27) (SC-A04-501)

## Phase 3: User Story 2 — Slow frames lower drawn detail (P1)

- [X] T-A04-504 [P] [US2] Tests first in `PU/CoreTests/FrameBudgetMonitorTests.swift`: "25% of the last 120 drawn frames — Verified 2026-11-13: FrameBudgetMonitorTests 14 tests (31 of 120 slow steps down, 30 does not; 570 of 600 fast steps up, 569 does not; one tier per window; bounds; single slow frame; restart; invalid times ignored; deterministic 5,000-frame sequence) pass
  over 1.2× the budget" steps down one tier; "95% of the last 600 under 0.8× the budget" steps up one tier; at most one
  tier per window; never below 0 or above `maxTier`; a single slow frame changes nothing; `restart()` clears the windows;
  non-finite and non-positive times are ignored; deterministic for a given sequence.
- [X] T-A04-505 [US2] Write `PU/Core/FrameBudgetMonitor.swift` per contracts/monitor.md. — Verified 2026-11-13: PU/Core/FrameBudgetMonitor.swift per contracts/monitor.md (full windows, ring of flags, restart after a change); tests pass on both runtimes
- [X] T-A04-506 [US2] Wire `PU/Experience/ParticlePresenter.swift`: record `frame.delta` while the core plays, restart while — Verified 2026-11-13: ParticlePresenter records frame.delta while playing, restarts when paused and on setup/teardown, draws at max(host tier, monitor tier); ParticleDetailTests 3 tests (digest unchanged with detail changes, ceiling wins, paused frames do not count) pass
  paused; draw at `max(tier, monitor.tier)`; add a test in `PU/ExperienceTests/ParticleResumeBoundTests.swift` (or a new
  `ParticleDetailTests.swift`) showing the simulation digest is the same with and without detail changes, that the drawn
  tier is `max(host tier, monitor tier)` (host tier 2 with a monitor at 0 draws at 2; FR-A04-511), and that frames drawn
  while paused do not move the monitor (FR-A04-512).
- [X] T-A04-507 [US2] Acceptance on sim-27.2 (check `detail-ios27`) (SC-A04-502, 503). — Verified 2026-11-13: monitor and detail tests pass on sim-27.2 and 26.5 (A04-P05/experiences-ios27, ios26) (SC-A04-502, 503)

## Phase 4: User Story 3 — Profile recorded (P2)

- [X] T-A04-508 [P] [US3] Write `PU/ExperienceTests/ParticleProfileTests.swift`: open, play about 120 frames, close; print — Verified 2026-11-13: ParticleProfileTests prints one PROFILE line with source simulator and the session's PerformanceRecord fields, parsed back as JSON; pass
  one `PROFILE:` JSON line with `"source":"simulator"` and the session's `lastPerformanceRecord`.
- [X] T-A04-509 [US3] Add a "Particle Universe" row to `docs/performance/budgets.md` (device values pending the device — Verified 2026-11-13: docs/performance/budgets.md row for Particle Universe frame-time detail (device values pending the campaign); check_performance_docs PASS (A04-P05/performance-docs)
  campaign); `python3 scripts/check_performance_docs.py` passes (check `performance-docs`).
- [X] T-A04-510 [US3] Acceptance: the profile line appears in the recorded log on sim-27.2 (check `profile-ios27`) (SC-A04-504). — Verified 2026-11-13: PROFILE: {..."source":"simulator"...} line present in the recorded log .autonomy/logs/A04-P05.experiences-ios27.log (A04-P05/experiences-ios27) (SC-A04-504)

## Phase 5: User Story 4 — MVP and host gates (P3)

- [X] T-A04-511 [US4] PU interface chunks on the iOS 27.2 phone: `app-build-for-testing-ios27 app-ui-ios27-j2`, — Verified 2026-11-13: PU chunks on the iOS 27.2 phone: j2 223 s, j3 342 s, j4 PASS (A04-P05/ui-pu-j2, ui-pu-j3, ui-pu-j4); audit_showcase_dependencies --target VisualCore PASS (A04-P05/projectm-audit) (SC-A04-505)
  `app-ui-ios27-j3`, `app-ui-ios27-j4` (checks `ui-pu-j2`, `ui-pu-j3`, `ui-pu-j4`); dependency audit
  `python3 scripts/audit_showcase_dependencies.py --target VisualCore --sources Apps/VisualCore` (check `projectm-audit`)
  (SC-A04-505).

## Phase 6: Polish

- [X] T-A04-512 ExperiencesCreative on sim-26.5 (check `experiences-ios26`) and on sim-27.2 (check `experiences-ios27`); — Verified 2026-11-13: ExperiencesCreative PASS on sim-27.2 and sim-26.5 (A04-P05/experiences-ios27, ios26); new unit tests run in well under 10 s (SC-A04-506)
  new unit tests under 10 s (SC-A04-506).
- [X] T-A04-513 `python3 scripts/test_scripts.py` (check `script-tests`); `git diff --stat` over `Packages/VisualCore` and — Verified 2026-11-13: test_scripts PASS after making two state-dependent assertions follow the ledger (A04-P05/script-tests-r3); git diff --stat 1a428487..HEAD over Packages/VisualCore and Packages/VisualCoreRendering is empty
  `Packages/VisualCoreRendering` for the phase's commits is empty (FR-A04-540).
- [ ] T-A04-514 {device} In the device campaign: frame pacing, detail steps under load, thermal behaviour and memory of
  Particle Universe on D1, D2, D3; fill the budgets row.
- [X] T-A04-515 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A04-P05 — Verified 2026-11-13: 2026-11-13 converge rounds 1-3: round 1 appended T-A04-516, round 2 T-A04-517/518 (all ticked with checks t516-package-full-ios27, t518-package-ios26), round 3 appended nothing
  with `python3 Tools/python/desktop_runbook.py seal --stage A04-P05` and `record`.

## Dependencies

501 → {502, 504–505, 508} → 506 → 503, 507, 510 → 509, 511–513 → 515.

## Parallel execution

Agent A: 504–506. Agent B: 502, 508. Lead: 501, 503, 507, 509–515.

## Phase 7: Convergence

Appended by `/speckit-converge` (T-A04-515, round 1, 2026-11-13).

- [X] T-A04-516 Take the monitor's budget from the frame interval the host reports in `Packages/ExperiencesCreative/ParticleUniverse/Experience/ParticlePresenter.swift` (`targetTimestamp − time` when finite and positive, else 1/60 s; rebuild the monitor at the same tier when the interval changes by more than 10%), with a test in `ParticleDetailTests.swift`, per FR-A04-510 and the clarification on the frame budget (partial) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P05.t516-package-full-ios27.json (ExperiencesCreative package on sim-27.2: all bundles pass, incl. aMonitorStartsAtAGivenTierWithinItsBounds, theIntervalIsTheSmallestStepBetweenConsecutiveTargets, stepsAcrossGapsOutOfRangeOrNotFiniteAreIgnored, testTheBudgetFollowsTheHostsFrameInterval); interval from consecutive target timestamps, research D7

## Phase 8: Convergence

Appended by `/speckit-converge` (T-A04-515, round 2, 2026-11-13).

- [X] T-A04-517 Bring `specs/037-pu-p05-profiling-tuning/contracts/monitor.md` and `data-model.md` up to date with `FrameBudgetMonitor(budget:maxTier:tier:)` and `FrameIntervalEstimate` (research D7) per plan: contracts (partial) — Verified 2026-11-13: 2026-11-13 contracts/monitor.md and data-model.md match the public declarations in ParticleUniverse/Core/FrameBudgetMonitor.swift (grep of init/observe/reset/record/restart)
- [X] T-A04-518 Re-run the ExperiencesCreative package on sim-26.5 after T-A04-516 through `desktop_runbook.py run-check --stage A04-P05` per T-A04-512 (partial) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P05.t518-package-ios26.json (ExperiencesCreative package on sim-26.5, TEST SUCCEEDED, incl. the T-A04-516 tests)
