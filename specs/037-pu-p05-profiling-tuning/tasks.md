# Tasks: Particle Universe — Phase 05 Profiling and low-end device tuning

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/monitor.md](contracts/monitor.md), [quickstart.md](quickstart.md). PU = `Packages/ExperiencesCreative/ParticleUniverse`.

Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A04-P05 --name <check> -- <command>`. Commit after
each task. Tests before code. Owner-only items: none. One {device} task. No VisualCore change.

## Phase 1: Setup

- [ ] T-A04-501 Baseline: ExperiencesCreative on sim-27.2 passes before the change (check `baseline-experiences`).

## Phase 2: User Story 1 — Coming back never fast-forwards (P1)

- [ ] T-A04-502 [P] [US1] Write `PU/ExperienceTests/ParticleResumeBoundTests.swift`: through `ExperienceSession`
  (pattern of `ParticleSessionTests`): playing scene, background, active, one 600 s frame takes at most 8 steps
  (`maxStepsPerFrame`), then 1/60 s frames take the normal count; a replay of the same history gives the same digest
  3 of 3 times; a paused scene takes 0 steps for the gap.
- [ ] T-A04-503 [US1] Acceptance on sim-27.2 (check `resume-ios27`) (SC-A04-501).

## Phase 3: User Story 2 — Slow frames lower drawn detail (P1)

- [ ] T-A04-504 [P] [US2] Tests first in `PU/CoreTests/FrameBudgetMonitorTests.swift`: "25% of the last 120 drawn frames
  over 1.2× the budget" steps down one tier; "95% of the last 600 under 0.8× the budget" steps up one tier; at most one
  tier per window; never below 0 or above `maxTier`; a single slow frame changes nothing; `restart()` clears the windows;
  non-finite and non-positive times are ignored; deterministic for a given sequence.
- [ ] T-A04-505 [US2] Write `PU/Core/FrameBudgetMonitor.swift` per contracts/monitor.md.
- [ ] T-A04-506 [US2] Wire `PU/Experience/ParticlePresenter.swift`: record `frame.delta` while the core plays, restart while
  paused; draw at `max(tier, monitor.tier)`; add a test in `PU/ExperienceTests/ParticleResumeBoundTests.swift` (or a new
  `ParticleDetailTests.swift`) showing the simulation digest is the same with and without detail changes.
- [ ] T-A04-507 [US2] Acceptance on sim-27.2 (check `detail-ios27`) (SC-A04-502, 503).

## Phase 4: User Story 3 — Profile recorded (P2)

- [ ] T-A04-508 [P] [US3] Write `PU/ExperienceTests/ParticleProfileTests.swift`: open, play about 120 frames, close; print
  one `PROFILE:` JSON line with `"source":"simulator"` and the session's `lastPerformanceRecord`.
- [ ] T-A04-509 [US3] Add a "Particle Universe" row to `docs/performance/budgets.md` (device values pending the device
  campaign); `python3 scripts/check_performance_docs.py` passes (check `performance-docs`).
- [ ] T-A04-510 [US3] Acceptance: the profile line appears in the recorded log on sim-27.2 (check `profile-ios27`) (SC-A04-504).

## Phase 5: User Story 4 — MVP and host gates (P3)

- [ ] T-A04-511 [US4] PU interface chunks on the iOS 27.2 phone: `app-build-for-testing-ios27 app-ui-ios27-j2`,
  `app-ui-ios27-j3`, `app-ui-ios27-j4` (checks `ui-pu-j2`, `ui-pu-j3`, `ui-pu-j4`); dependency audit
  `python3 scripts/audit_showcase_dependencies.py --target VisualCore --sources Apps/VisualCore` (check `projectm-audit`)
  (SC-A04-505).

## Phase 6: Polish

- [ ] T-A04-512 ExperiencesCreative on sim-26.5 (check `experiences-ios26`) and on sim-27.2 (check `experiences-ios27`);
  new unit tests under 10 s (SC-A04-506).
- [ ] T-A04-513 `python3 scripts/test_scripts.py` (check `script-tests`); `git diff --stat` over `Packages/VisualCore` and
  `Packages/VisualCoreRendering` for the phase's commits is empty (FR-A04-540).
- [ ] T-A04-514 {device} In the device campaign: frame pacing, detail steps under load, thermal behaviour and memory of
  Particle Universe on D1, D2, D3; fill the budgets row.
- [ ] T-A04-515 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A04-P05
  with `python3 Tools/python/desktop_runbook.py seal --stage A04-P05` and `record`.

## Dependencies

501 → {502, 504–505, 508} → 506 → 503, 507, 510 → 509, 511–513 → 515.

## Parallel execution

Agent A: 504–506. Agent B: 502, 508. Lead: 501, 503, 507, 509–515.
