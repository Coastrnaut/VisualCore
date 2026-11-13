# Tasks: R02-F26 — Games input, accessibility and haptics contract

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md)

Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-F26 --name <check> -- <command>`. Commit after each
task. Owner-only items: none.

## Phase 1: Setup

- [X] T-R02F26-001 Record the audit and decisions (research.md sections 1–2); baseline: `swift test --package-path — Verified 2026-11-13: research.md sections 1-2 (audit re-verified); baseline after X-A01..A03 availability: app unit and chunks a, b, d, e, f pass (baseline-app-r2, baseline-app-ui-d, baseline-app-ui-ef); pure host tests pass (host-visualcore-r2)
  Packages/VisualCore` passes before the change (check `baseline-host`).

## Phase 2: User Story 1 — Touches mean one thing at a time (P1)

- [X] T-R02F26-002 [P] [US1] Tests first in `Packages/VisualCore/Tests/VisualCoreScenesTests/GestureArbiterTests.swift`: — Verified 2026-11-13: GestureArbiterTests.swift: 9 tests (8 sequences each identical over 3 runs, third finger ignored, priority tie by declaration order, cancelAll) pass in swift test Packages/VisualCore (host-visualcore-r2)
  8 recorded sequences (tap, tap that becomes a drag, drag then a second finger to pinch, pinch released to one finger,
  long press, rotate versus pinch by priority, cancelled touch, non-finite position) give fixed outcome lists,
  identical over 3 runs; more pointers than declared are rejected.
- [X] T-R02F26-003 [US1] Write `Packages/VisualCore/Sources/VisualCoreScenes/GestureArbiter.swift` (research R1; — Verified 2026-11-13: GestureArbiter.swift: GestureDeclaration, GestureKind, GestureOutcome, GestureArbiter (handle, tick, cancelAll) over the existing recognizers, one owner at a time, cancelled touch cancels, non-finite and extra pointers ignored; /// on each
  data-model `GestureDeclaration { id, kind, priority, pointers: 1...2 }`, `GestureOutcome { gesture, phase, values }`)
  over the existing recognizers; `///` on each public declaration.
- [X] T-R02F26-004 [US1] Acceptance: host tests (check `host-arbiter`) (SC-R02F26-001). — Verified 2026-11-13: swift test Packages/VisualCore: 390 + 98 + 55 + 15 tests pass, arbiter tests included (host-visualcore-r2) (SC-R02F26-001)

## Phase 3: User Story 2 — Every gesture has a button (P1)

- [X] T-R02F26-005 [P] [US2] Tests first: `GestureAlternatives.missing(gesture:native:)` returns the sorted gesture — Verified 2026-11-13: GestureAlternativesTests.swift (covered sets leave nothing; missing actions named in order) pass (host-visualcore-r2)
  actions without a native action, empty when covered (`Packages/VisualCore/Tests/VisualCoreExperienceTests/GestureAlternativesTests.swift`).
- [X] T-R02F26-006 [US2] Write `Packages/VisualCore/Sources/VisualCoreExperience/GestureAlternatives.swift`; add — Verified 2026-11-13: GestureAlternatives.missing(gesture:native:) in VisualCoreExperience; ExperiencePresenter.gestureActions and nativeActions with empty defaults; rendering package 15/15 per runtime still pass (rendering-ios27/26) and ExperiencesCreative 274 test cases pass (experiences-ios27)
  `gestureActions` and `nativeActions` (default empty sets) to `ExperiencePresenter` in
  `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperiencePresenter.swift`.
- [X] T-R02F26-007 [US2] Declare the sets in the app's debug experience presenter — Verified 2026-11-13: DebugPresenter declares nativeActions [tap]; GestureAlternativesAppTests: the debug experience has nothing missing and a planted zoom gap is named; app unit 78/78 (app-settings-r2); A01-A04 unchanged (analysis D1) (SC-R02F26-002)
  (`Apps/VisualCore/App/DebugSupport/DebugExperience.swift`) and add a unit test that the check finds nothing missing
  for it and that a planted gap fails (SC-R02F26-002). A01–A04 stay unchanged (analysis D1); app unit tests (check
  `app-unit-alternatives`).

## Phase 4: User Stories 3 and 4 — Announcements and colour (P2)

- [X] T-R02F26-008 [P] [US3] [US4] Tests first in `Packages/VisualCore/Tests/VisualCoreSimulationTests/AccessibilityPlansTests.swift`: — Verified 2026-11-13: AccessibilityPlansTests.swift: 14 tests (5 announcement sequences, 5 haptic sequences, 3 state-sign cases, transitionDuration incl. Reduce Motion, negative, NaN, infinity) pass (host-visualcore-r2)
  5 announcement sequences (rate limit 0.5 s, merge to newest, off → none), state-sign check (missing sign, duplicate
  sign, valid palette), and `transitionDuration(_:reduceMotion:)` (0 under Reduce Motion, unchanged otherwise;
  FR-R02F26-050).
- [X] T-R02F26-009 [US3] [US4] Write `Packages/VisualCore/Sources/VisualCoreSimulation/AccessibilityPlans.swift` — Verified 2026-11-13: AccessibilityPlans.swift: Announcement, AnnouncementPlanner (0.5 s, merge to newest, off drops), StateSign, stateSignProblems, transitionDuration; texts are passed in by callers
  (`Announcement`, `AnnouncementPlanner`, `StateSign`, `stateSignProblems`, `transitionDuration`) — texts are passed in by the caller from a
  string catalog (FR-R02F26-021).
- [ ] T-R02F26-010 [US3] Write `AnnouncementSink`, `SystemAnnouncementSink` (`UIAccessibility.post(notification:
  .announcement, argument:)`) in `Packages/VisualCoreRendering/Sources/VisualCoreUI/AccessibilityPlayers.swift`, with a
  fake-sink test in the rendering tests.
- [ ] T-R02F26-011 [US3] [US4] Acceptance: host tests and rendering tests on both runtimes (checks `host-plans`,
  `rendering-ios27`, `rendering-ios26`) (SC-R02F26-003, SC-R02F26-004).

## Phase 5: User Story 5 — Haptics, when wanted (P3)

- [ ] T-R02F26-012 [P] [US5] Tests first: haptic planner (5 sequences, 0.05 s rate limit, off → none) in
  `AccessibilityPlansTests.swift`; `ShellPreferences` JSON without `haptics` decodes with haptics on, and round trips
  with false (`Packages/VisualCore/Tests/VisualCoreExperienceTests/ShellPreferencesHapticsTests.swift`).
- [ ] T-R02F26-013 [US5] Write `HapticEvent`, `HapticPlanner` in `AccessibilityPlans.swift`; `ShellPreferences.haptics:
  Bool?` (absent = on, key `haptics`, schema 1) in `ShellModel.swift`; `HapticSink`, `SystemHapticSink` (UIKit
  generators) in `AccessibilityPlayers.swift` with a fake-sink test.
- [ ] T-R02F26-014 [US5] Wire: `ExperienceLaunch.haptics` from the preferences (`Apps/VisualCore/App/ExperienceRegistry.swift`,
  `AppModel.swift`); a haptics switch with identifier `vc.settings.haptics` and a VoiceOver label in `SettingsView.swift`;
  the session owns one player and one announcer and offers them to the experience
  (`Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperienceSession.swift`); a session test that a
  planned feedback reaches the fake sink and the state digest is unchanged.
- [ ] T-R02F26-015 [US5] Acceptance: app unit tests and the settings interface chunk with a new test that the switch
  survives a relaunch (`Apps/VisualCore/Tests/UI/SettingsUITests.swift`; `release_check.py --only
  app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-b`, check `app-settings`) (SC-R02F26-005, SC-R02F26-006).

## Phase 6: Polish

- [ ] T-R02F26-016 `check_public_api.py --update` (only added lines, 0 undocumented; check `public-api`),
  `check_documented_api.py --sources Apps/VisualCore` (check `documented-api`), README sections in VisualCore and
  VisualCoreRendering.
- [ ] T-R02F26-017 Reference regression `reference-a` and `reference-b` after the change (SC-R02F26-007).
- [ ] T-R02F26-018 Release build, symbols and privacy (`release_check.py --only app-release-build app-release-symbols
  app-privacy-manifest`, check `release-app`).
- [ ] T-R02F26-019 Auto-Creator.md section 13 row R02-F26 as built via `docs/catalog/shared-feature-map.json` and
  `render_autocreator.py`; `validate_autocreator.py` (check `steering`); `validate_docs.py`, `migration_baseline.py
  verify`, script tests; CI of a commit with all changes finished with success.
- [ ] T-R02F26-020 {device} In the device campaign: haptic feedback fires and feels distinct per kind on D1, D2, D3;
  manual VoiceOver pass over one game (recorded, non-gating); the system accessibility audits of the settings switch.
- [ ] T-R02F26-021 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record R02-F26.

## Dependencies and parallel work

US1, US2 and US3/US4 are independent; US5 depends on the planners file of Phase 4 (same file) and on the session.
Parallel agents: arbiter + tests (G1), planners + tests (G2), UI players + tests (G3); the lead owns
`ExperiencePresenter.swift`, `ExperienceSession.swift`, `ShellModel.swift` and the app.
MVP: US1 and US2.

## Analysis

- **Run 1 (2026-11-13)**:
  - D1 HIGH: changing the A01–A04 presenters would have made the evidence of UA-F07 stale. Fixed: the check is
    proven on the debug experience, and A01–A04 adopt the sets later.
  - E1 MEDIUM: Reduce Motion transitions had no task. Fixed in T-R02F26-008/009.
  - E2 LOW: the canvas label already mirrors the state. Accepted.
  - 15 of 15 requirements and 7 of 7 criteria are covered, with no critical or high finding left.
