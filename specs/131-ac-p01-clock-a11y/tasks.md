# Tasks: Ambient Clock — Phase 01 Clock and time-zone correctness and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/clock.md](contracts/clock.md), [quickstart.md](quickstart.md). Gate A18-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A18-P01 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); run checks, read each exit, then tick in a separate step. iOS 27 only. No test may
raise a system prompt; no wall-clock assert. Precedent: `specs/124-ia-p01-content-schema/tasks.md` (core only) and
`specs/126-ia-p03-layers-search/tasks.md` (VisualCore change).

## Phase 1: Setup

- [ ] T-A18-101 Baseline: cite the A18-P00 evidence on an unchanged `Packages` tree (`.autonomy/checks/A18-P00.{app-build,no-change}.json`) instead of a rerun (owner ruling of 2026-11-14)

## Phase 2: Foundational — the VisualCore clock source (G-CLOCK)

- [ ] T-A18-102 Create `Packages/VisualCore/Sources/VisualCoreExperience/{ClockSource,TimeChangeMonitor}.swift` per data-model.md ("`ClockSource` with `now`; `SystemClock` is `Date()` with no offset; `FixedClock` with `set` and `advance(by:)`; `TimeChangeKind` foreground, significantTime, timeZone, locale, calendarDay; `TimeChangeMonitor(center:names:handler:)` with `start`, `stop`, `isRunning` and `foundationNames`"), every public symbol with `///`, and `Packages/VisualCore/Tests/VisualCoreExperienceTests/{ClockSourceTests,TimeChangeMonitorTests}.swift` (fixed clock returns and advances; the system clock is within one second of `Date()` read before and after; each Foundation name posted on a private `NotificationCenter` gives one handler call with its kind; none after `stop`; an unnamed notification ignored; `start` twice observes once); the VisualCoreExperience row in `Packages/VisualCore/README.md` and the API baseline (`check_public_api.py --update`, then `check_public_api.py`) (FR-A18-101, 102, 108)
- [ ] T-A18-103 Create `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/TimeChangeMonitor+Application.swift` (`TimeChangeMonitor.applicationNames`: `foundationNames` plus `UIApplication.significantTimeChangeNotification` → significantTime and `UIApplication.willEnterForegroundNotification` → foreground), documented, with `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/TimeChangeApplicationTests.swift` (the five kinds are each mapped once; posting each application name on a private center gives one event); the README paragraph and API baseline (FR-A18-102, 108)

## Phase 3: The core targets

- [ ] T-A18-104 Add the targets `AmbientClockCore` (path `AmbientClock/Core`, dependencies `VisualCoreExperience` and `VisualCoreSimulation`) and `AmbientClockCoreTests` (path `AmbientClock/CoreTests`) to `Packages/ExperiencesCreative/Package.swift` (the lead writes this file); no experience target, product or registration (FR-A18-109; clarification Q2)

## Phase 4: Story 1 — the right time (P1) 🎯 MVP

- [ ] T-A18-105 [P] [US1] Create `Packages/ExperiencesCreative/AmbientClock/Core/{ClockPreferences,ClockFormatter}.swift` per data-model.md: `ClockPreferences` ("hourCycle ∈ {system, h12, h24} (default system); showSeconds (false); showDate (true); timeZone and locale each .system or .fixed(id)") with the envelope kind `a18.clock-preferences`, schema 1, `encoded()` with sorted keys and `decode(_:)` refusing `damaged`, `newer-version`, `unknown-time-zone`, `unknown-locale` and `too-large` ("above 4,096 bytes"), each with a sentence naming the value; `ClockEnvironment` (fixed policies win, otherwise the system's); `ClockFormatter.display(at:preferences:environment:)` with templates `jmm`/`hmm a`/`HHmm` plus `ss`, the date in `dateStyle .full`, the spoken string (time, then the date when shown) and `usesTwelveHourClock(locale:)`; cached formatters (FR-A18-103, 104; research D2)
- [ ] T-A18-106 [P] [US1] Write `Packages/ExperiencesCreative/AmbientClock/CoreTests/{PreferencesTests,FormatterTests}.swift` against contracts/clock.md: round trip exact; each refusal named; en_US, de_DE, ja_JP and ar_EG at fixed instants in `America/New_York` and `Asia/Kolkata`; system/h12/h24; seconds on and off; date on and off; ar_EG digits U+0660–U+0669; text compared after mapping U+202F and U+00A0 to a space (SC-A18-101, 104)

## Phase 5: Story 2 — right when the world changes (P1)

- [ ] T-A18-107 [P] [US2] Create `Packages/ExperiencesCreative/AmbientClock/Core/{ClockSchedule,AmbientClockState}.swift`: `ClockSchedule.nextDeadline(after:showSeconds:calendar:)` ("strictly later, on a whole second or minute in the clock's zone"); `AmbientClockState` with the actions `time.set`, `time.changed`, `prefs.set` and `time.speak`, `recomputations`, the planner `AnnouncementPlanner(minimumInterval: 0.5)`; no clock read inside the core (FR-A18-105–107)
- [ ] T-A18-108 [P] [US2] Write `Packages/ExperiencesCreative/AmbientClock/CoreTests/{ScheduleTests,DaylightSavingTests,StateTests}.swift`: deadlines on boundaries and strictly later; New York 2026-03-08 06:58–07:01 UTC never shows 02:xx; 2026-11-01 05:58–06:59 UTC shows 01:59 twice; Kolkata half-hour offset; midnight changes the date with the time; each of the five kinds adds one recomputation; equal actions give equal states (SC-A18-102, 103)

## Phase 6: Story 3 — heard correctly (P2)

- [ ] T-A18-109 [US3] Write `Packages/ExperiencesCreative/AmbientClock/CoreTests/SpokenTimeTests.swift`: the spoken string names the time (with the period for 12-hour) and the date when shown, for each locale; a run of minute `time.set` actions announces nothing; `time.speak` bursts within 0.5 s post at most one (FR-A18-107)

## Phase 7: Records and evidence

- [ ] T-A18-110 Contract `docs/apps/ambient-clock/visualcore-contract.json`: G-CLOCK (VisualCoreExperience and VisualCoreExperienceHost), G-FORMAT and G-TIMEA11Y closed by "A18-P01"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app ambient-clock --render`)
- [ ] T-A18-111 Tests: VisualCore host (`--name visualcore-experience -- swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests`), the host addition (`--name host-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreExperienceHostTests`), the core (`--name ac-core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AmbientClockCoreTests`), the public API (`--name public-api -- python3 scripts/check_public_api.py`) and the documented API (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/AmbientClock`) (SC-A18-101–105)
- [ ] T-A18-112 Packages, catalog, script tests and the app build (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name catalog -- python3 scripts/build_catalog.py --check`; `--name script-tests -- python3 scripts/test_scripts.py`; `--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`); the app and its registry are unchanged (SC-A18-105; FR-A18-109)
- [ ] T-A18-113 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A18-P01; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A18-101 → 102 → 103 → 104 → {105, 107} → {106, 108, 109} → 110 → 111 → 112 → 113. 106, 108 and 109 are written
against contracts/clock.md; 105 and 107 touch different files.

## Parallel examples

Agent V: T-A18-102 and 103 (VisualCore). Agent C: T-A18-105 and 107 (core sources). Agent T: T-A18-106, 108 and 109
(core tests). Lead: Package.swift (104), README rows, API baseline, contract, runs, commits.

## Implementation strategy

MVP: the clock source (102) and the formatter with its fixtures (105, 106). The schedule, DST and state (107, 108)
and the spoken time (109) close the phase. Review checkpoints after 102 (host tests pass) and at 111.
