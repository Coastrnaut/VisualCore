# Implementation Plan: Ambient Clock — Phase 01 Clock and time-zone correctness and accessibility

**Branch**: `131-ac-p01-clock-a11y` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds three gaps:
- **G-CLOCK (VisualCore):**
  - `VisualCoreExperience` gets `ClockSource`, `SystemClock`, `FixedClock`, `TimeChangeKind` and
    `TimeChangeMonitor` (Foundation names);
  - `VisualCoreExperienceHost` adds the two UIKit names (`TimeChangeMonitor.applicationNames`).
- **G-FORMAT (app-local core `AmbientClockCore`):**
  - `ClockPreferences` (schema 1) with its typed refusals;
  - `ClockFormatter` for the time, date and spoken text;
  - `ClockSchedule` for the next deadline;
  - `AmbientClockState` with the actions `time.set`, `time.changed`, `prefs.set` and `time.speak`.
- **G-TIMEA11Y:**
  - the spoken string;
  - no automatic announcement, and requested announcements through `AnnouncementPlanner(minimumInterval: 0.5)`.

No experience target, registration or interface comes in this phase (clarification Q2). Research:
[research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/clock.md](contracts/clock.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6.
- **Dependencies:**
  - Foundation's `Calendar`, `Locale`, `TimeZone`, `DateFormatter`, `NotificationCenter`, `JSONEncoder` and
    `JSONDecoder`;
  - `VisualCoreExperience` (the clock source) and `VisualCoreSimulation` (`AnnouncementPlanner`);
  - UIKit only in the host addition.
- **Storage:** preferences of at most 4,096 bytes (written to the experience storage from A18-P03; only the codec
  here).
- **Testing:**
  - `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests` on the host;
  - `VisualCoreExperienceHostTests` on sim-27.2;
  - `AmbientClockCoreTests` through the ExperiencesCreative package scheme on sim-27.2.
- **Constraints:** tests under 10 s; no wall-clock assert; no GPU.
- **Reference regression:** it waits for X-A18 (owner ruling of 2026-11-14; precedent A17-P03). No NEEDS
  CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: no rendering in this phase |
| II Reuse | PASS: `AnnouncementPlanner`; the clock source is the shared piece G-CLOCK, not a copy of Solar System Explorer's |
| II-a VisualCore change | PASS: additive, with `///` docs, tests, the API baseline and a README row; the reference regression at X-A18 |
| IV Pure core | PASS: the core imports Foundation, VisualCoreExperience and VisualCoreSimulation; it reads no clock |
| V Persistence | PASS: schema 1, typed refusals, a size cap, refusal of newer versions |
| VI Tests | PASS: DST, 12/24-hour, locale, zone and time-change fixtures |
| VIII Privacy | PASS: no permission, no network, no location |
| X–XIII | PASS: documented API |

The A18 rules pass. Time comes only from the system through one injected source, and there is no simulated clock in
production. No network or weather. No brightness or keep-awake in this phase. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreExperience/ClockSource.swift                         new (ClockSource, SystemClock, FixedClock)
Packages/VisualCore/Sources/VisualCoreExperience/TimeChangeMonitor.swift                   new (TimeChangeKind, TimeChangeMonitor)
Packages/VisualCore/Tests/VisualCoreExperienceTests/{ClockSourceTests,TimeChangeMonitorTests}.swift  new
Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/TimeChangeMonitor+Application.swift    new
Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/TimeChangeApplicationTests.swift   new
Packages/VisualCore/README.md, docs/api/visualcore-public-api.txt                          modify
Packages/ExperiencesCreative/Package.swift                                                 modify (2 targets)
Packages/ExperiencesCreative/AmbientClock/Core/{ClockPreferences,ClockFormatter,ClockSchedule,AmbientClockState}.swift  new
Packages/ExperiencesCreative/AmbientClock/CoreTests/{PreferencesTests,FormatterTests,ScheduleTests,
  DaylightSavingTests,StateTests,SpokenTimeTests}.swift                                    new
docs/apps/ambient-clock/visualcore-contract.json (G-CLOCK, G-FORMAT, G-TIMEA11Y closed)    modify
scripts/test_scripts.py (the clock files of VisualCoreExperience, research D9)                modify
```

- **Dependency direction:** the core → VisualCoreExperience and VisualCoreSimulation; the host addition →
  VisualCoreExperience and UIKit.
- **Lifecycle:** the monitor observes from `start()` until `stop()` or deinit. The source is read only when an action
  is built (by the A18-P02 presenter), never inside the core.
- **Migration:** none; schema 1 is the first.
- **Rollback:** revert the commits. The VisualCore additions are additive, and no other experience uses them yet.

## Parallel work

- **Agent V:** the VisualCore source and test files and the host addition.
- **Agent C:** the four core source files.
- **Agent T:** the six core test files, written against the contract.
- **Lead:** `Package.swift`, the README row, the API baseline, the contract, the runs and the commits.
