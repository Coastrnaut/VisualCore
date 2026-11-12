# Implementation Plan: UA-F06 — Quality profiles and performance observability

**Branch**: `192-ua-f06-quality-performance` (spec directory only; work stays on `main`) | **Date**: 2026-11-12 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/192-ua-f06-quality-performance/spec.md`; the UA-F06 `/speckit-plan`
prompt of Auto-Creator.md section 20, verbatim in the invocation. The clarification decisions are binding.

## Summary

An experience declares a quality profile: named levels with four numeric budgets. A pure governor decides the
level in force from the device conditions (the existing quality policy) or a pin; the session applies it before
the first frame and keeps deciding while the experience runs. The session also measures an open stage by stage
(preparation, shader set-up, first presented frame), counts shader compilations that happen too late, meters the
interval between presented frames with constant memory, and reads the memory footprint and the graphics bytes.
All of it forms one versioned performance record, which UA-F09 will embed in its evidence record. A ten-minute
endurance scenario of the sample experience proves, with a growth rule, that nothing keeps growing. The budgets
of section 12.5 become a document of proposals with a check.

## Technical Context

**Language/Version**: Swift 6 (toolchain 6.4.2, strict concurrency); Python 3 standard library for two tools.

**Primary Dependencies**: Foundation; the existing modules VisualCoreDiagnostics, VisualCoreExperience,
VisualCoreRendering, VisualCoreExperienceHost; SwiftUI in the app. No third-party package.

**Storage**: none new. The performance record is a value; the app's stored override is unchanged (schema 1).

**Testing**: Swift Testing on the host for the pure types; package tests on the iOS 27.2 and iOS 26.5 simulators
for the session, the present observer and the endurance run; the app's XCTest and XCUITest chunks; `unittest`
for the tools.

**Target Platform**: iOS and iPadOS 26.0.

**Project Type**: additions to two framework packages, small changes to the app, two tools, one document.

**Performance Goals**: none claimed. The feature makes performance measurable; budgets stay proposals until the
device campaign.

**Constraints**: pure types stay Foundation-only; no direct GL in experience or app sources; public Apple
interfaces only and none that needs a declared privacy reason; the record never leaves the device; test access
absent from release builds; every command under ten minutes.

**Scale/Scope**: 5 new pure source files and 5 test files in VisualCoreDiagnostics; changes to 4 files of
VisualCoreExperience and 4 of the rendering package plus 2 new ones; 3 new test files on the simulator; 4 app
files; 2 tools; 1 document; about 45 new public declarations.

## Constitution Check

*GATE: passed before Phase 0 research and re-checked after Phase 1 design (same result).*

| Principle | Result |
|---|---|
| I. Proven Renderer Only | pass: one observer after the existing present call; no new backend, no fork |
| II. App-Neutral Public API | pass: profile, governor, meter, rule and record are generic; documentation, baseline, tests and reference regression are tasks |
| II-a. Preserve the Reference | pass: submodule untouched; the seven-step regression in two chunks is a task |
| III. GPU Lifecycle and Thread Ownership | pass: decisions, observers and measurements run on the main thread that owns the host; nothing touches GL outside the registry |
| IV. Host-Testable Domain Logic, Test-First | pass: every rule is a pure value with host tests written before the code |
| V. Implementation Before Devices | pass: simulators only; one `{device}` task for after the lock |
| VI. Evidence Over Assertion | pass: evidence through `run-check`; absent measurements stay absent; no simulator number is presented as performance |
| VII. Native, Accessible UI | pass: one rewritten settings note; no new control |
| VIII. Public Apple APIs, Privacy | pass: `task_info` and `ProcessInfo` are public; no required-reason interface; nothing is transmitted |
| IX. Bounded Untrusted Input | pass: profile and record are validated and bounded (8 levels, 64 KiB, strict keys); the meter has constant memory |
| X. Licensing and Provenance | pass: no new dependency |
| XI. One App and Stable Experience Identity | pass: no new target; the record names the experience id |
| XII. One Purchase and No Advertising | pass: no store, advertising or tracking code |
| XIII. Code-Driven Visuals | pass: no art |
| Development Workflow | pass: `main`, FR-U06 namespace, one commit per task, Spec Kit skills in order |

No violation; Complexity Tracking stays empty.

## Project Structure

### Source Code (repository root)

```text
Packages/VisualCore/
├── Package.swift                                          modify  VisualCoreExperience depends on VisualCoreDiagnostics; tests
├── Sources/VisualCoreDiagnostics/
│   ├── QualityProfile.swift                               new     QualityLevel, QualityBudget, QualityProfileError, QualityProfile, QualityDeclaration
│   ├── QualityGovernor.swift                              new
│   ├── PacingMeter.swift                                  new     PacingMeter, PacingSummary
│   ├── GrowthRule.swift                                   new     ResourceSample, GrowthVerdict, GrowthRule
│   ├── PerformanceRecord.swift                            new     PerformanceRecord, PerformanceRecordError, LaunchTiming
│   └── QualityPolicy.swift, DeviceConditions.swift, …     existing (unchanged)
├── Sources/VisualCoreExperience/
│   ├── ExperienceCore.swift                               modify  qualityProfile with its default
│   ├── ExperienceConformance.swift                        modify  check profileMatchesTiers
│   └── SessionLifecycle.swift                             modify  SessionStageTimings: setup, firstPresent, programsCompiled
├── Sources/VisualCoreTestSupport/SampleExperienceCore.swift   modify  a declared profile of three levels
└── Tests/VisualCoreDiagnosticsTests/
    ├── QualityProfileTests.swift, QualityGovernorTests.swift, PacingMeterTests.swift,
    │   GrowthRuleTests.swift, PerformanceRecordTests.swift                         new
    └── (VisualCoreExperienceTests: conformance and timings tests)                   modify

Packages/VisualCoreRendering/
├── Sources/VisualCoreRendering/
│   ├── RenderHost.swift                                   modify  addPresentObserver, PresentedFrame
│   └── ProcessMemory.swift                                new
├── Sources/VisualCoreExperienceHost/
│   ├── ExperiencePresenter.swift                          modify  Experience.qualityProfile (default)
│   ├── ExperienceShell.swift                              modify  returns the core's profile
│   └── ExperienceSession.swift                            modify  governor, stage times, late compilations, pacing, record
└── Tests/VisualCoreExperienceHostTests/
    ├── SessionQualityTests.swift, SessionPerformanceTests.swift, EnduranceTests.swift   new
    └── SamplePresenter.swift                              modify  variants: late compilation, leak

Apps/VisualCore/
├── App/VisualCoreApp.swift, RootView.swift                modify  launch timing
├── App/AppModel.swift                                     modify  the pin goes to the session; own override code removed
├── App/SettingsView.swift, Resources/Localizable.xcstrings   modify  note; debug diagnostics show the record
└── Tests/Unit/AppModelTests.swift, Tests/UI/SettingsUITests.swift   modify

scripts/
├── xcodebuild_package.py                                  modify  --only-testing
├── check_performance_docs.py                              new
├── release_check.py                                       modify  step performance-docs
└── test_scripts.py                                        modify
docs/performance/budgets.md                                new
docs/performance/README.md                                 modify  link, notice
docs/api/visualcore-public-api.txt                         modify  baseline
Auto-Creator.md (sections 11.4, 12.4 to 12.6, 16)          modify  as built
```

## Module and dependency direction

`VisualCoreDiagnostics` (no dependency) ← `VisualCoreExperience` (new edge) ← `VisualCoreTestSupport`;
`VisualCoreRendering` and `VisualCoreExperienceHost` already depend on `VisualCoreDiagnostics`. The app depends
on the host module as before; the product `VisualCoreDiagnostics` is linked by the app again because the app
names `LaunchTiming`. No cycle; `scripts/check_dependencies.py` must stay green.

## Public API

See [contracts/performance-api.md](contracts/performance-api.md). Additions only; no existing declaration
changes its signature. Protocol requirements are added with defaults (`ExperienceCore.qualityProfile`,
`Experience.qualityProfile`), so existing conformers compile unchanged.

## Lifecycle and thread-ownership contracts

- The governor, the meter and the record are values owned by `ExperienceSession`, which is bound to the main
  actor; `RenderHost` calls present observers on the main thread after `eglSwapBuffers` succeeded.
- Open: prepare → apply the level in force → (restore) → create host (set-up timed, programs counted) → activate →
  first frame. Interactive begins when the session becomes running; the compile baseline is taken then.
- Running: each presented frame gives one interval to the meter; at most once per second the governor decides;
  a changed level is applied through `setQualityTier`.
- Suspend: no decision, no sample; resume: `governor.resume()`, `meter.skipNext()`.
- Context recreation: rebuild counted, compile baseline taken again.
- Close: the record is frozen into `lastPerformanceRecord` before the host is destroyed (peak bytes are read
  first); a failed or cancelled open leaves a record with the stages that ended.
- Memory warning: counted in `memory_events`; the level is not changed.

## Data schemas

`PerformanceRecord` version 1 (data-model section 5): new, no migration. `SessionStageTimings` gains three
optional fields; older encoded values decode with them absent. The shell preferences are unchanged (schema 1).

## Tests of each layer

| Layer | Tests |
|---|---|
| Host (`swift test`) | `QualityProfileTests`, `QualityGovernorTests`, `PacingMeterTests`, `GrowthRuleTests`, `PerformanceRecordTests`; conformance with the new check; timings coding |
| Package tests, iOS 27.2 and 26.5 simulators | the same pure tests; `SessionQualityTests`, `SessionPerformanceTests`, `EnduranceTests` |
| App unit tests | the pin reaches the session and the first frame; the record after an open; launch timing set once |
| App interface tests | the record is readable in the settings of a debug build after an experience ran |
| Tools | `--only-testing` of the package runner; `check_performance_docs.py` |

## Build and test commands

See [quickstart.md](quickstart.md). When the framework changes: `python3 scripts/check_public_api.py --update`,
`python3 scripts/check_documented_api.py`, and the seven-step ProjectM reference regression in two chunks.

## Migration and rollback

Additive. Rollback is `git revert` of the feature's commits in reverse order; the app then applies the override
after an open again (UA-F04 behaviour), and no stored data is affected because nothing new is stored.

## Complexity Tracking

No violation to justify.
