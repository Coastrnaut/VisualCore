# Implementation Plan: UA-F04 — The VisualCore app shell

**Branch**: `190-ua-f04-app-shell` (spec directory only; work stays on `main`) | **Date**: 2026-11-12 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/190-ua-f04-app-shell/spec.md`; the UA-F04 `/speckit-plan` prompt of
Auto-Creator.md section 20, verbatim in the invocation. The clarification decisions are binding.

## Summary

`Apps/VisualCore/` becomes the one shippable app target. Its SwiftUI shell renders a pure shell model (launcher
sections, startup decision, preferences, reset plan) that lives next to the catalog in the pure package, opens
experiences through the session of UA-F03, and offers settings and an about screen built from the existing
VisualCoreUI views. No experience is registered yet, so the shipping launcher truthfully shows its empty
statement; interface tests use a debug-only fixture catalog and debug experience. A small tool runs the app's
tests on a phone and a tablet simulator of each runtime, chosen by runtime and kind.

## Technical Context

**Language/Version**: Swift 6 (toolchain 6.4.2, strict concurrency); XcodeGen for the project; Python 3 standard
library for one tool.

**Primary Dependencies**: SwiftUI, Observation, Foundation; the framework products VisualCoreExperience,
VisualCoreSimulation, VisualCoreExperienceHost, VisualCoreUI, VisualCoreRendering. No third-party package.

**Storage**: one preferences value in the app's `UserDefaults` (schema 1); experience data folders under
Application Support (created by UA-F05; removed here by a reset).

**Testing**: Swift Testing on the host for the shell model; XCTest unit tests in the app's test bundle; XCUITest
interface tests with accessibility audits on a phone and a tablet of iOS 27.2 and iOS 26.5; `unittest` for the
tool.

**Target Platform**: iOS and iPadOS 26.0.

**Project Type**: mobile app target in the existing XcodeGen project, plus additions to one pure module and one
tool.

**Performance Goals**: the launcher creates no rendering context; first run reaches a running experience in at
most two taps. No device claim.

**Constraints**: no network, no advertising, no account, no URL scheme, no usage description; debug support
absent from release builds; no direct GL in app sources; texts in string resources; no raster art.

**Scale/Scope**: 1 pure source file, about 12 app source files, 2 debug-only files, 3 resource files, 2 unit test
files, 4 interface test files, 1 new tool, changes to `project.yml`.

## Constitution Check

*GATE: passed before Phase 0 research and re-checked after Phase 1 design (same result).*

| Principle | Result |
|---|---|
| I. Proven Renderer Only | pass: the app draws nothing itself; the debug experience uses a public scene; the isolation check covers the app |
| II. App-Neutral Public API | pass: the shell model is generic; documentation, baseline, tests and reference regression are tasks |
| II-a. Preserve the Reference | pass: submodule untouched; the dependency audit runs on the built app |
| III. GPU Lifecycle and Thread Ownership | pass: the session owns the render host; the launcher creates no context |
| IV. Host-Testable Domain Logic, Test-First | pass: launcher, startup, preferences and reset decisions are pure and host-tested |
| V. Implementation Before Devices | pass: simulators only; one `{device}` task for after the lock |
| VI. Evidence Over Assertion | pass: evidence through `run-check`; the enumeration guard after every app test run; the empty real catalog is stated, not hidden |
| VII. Native, Accessible UI | pass: native navigation and controls, identifiers, tier as text, accessibility audits, largest text size |
| VIII. Public Apple APIs, Privacy | pass: no network, no usage description, a privacy manifest for the preferences storage |
| IX. Bounded Untrusted Input | pass: tolerant, bounded preference decoding; the catalog loader's typed errors shown as a message |
| X. Licensing and Provenance | pass: licences bundled by the existing script; no asset added |
| XI. One App and Stable Experience Identity | pass: this is the one shippable target; ids come from the catalog |
| XII. One Purchase and No Advertising | pass: no store code; premium tiles cannot be opened before UA-F08 |
| XIII. Code-Driven Visuals | pass: tiles are drawn by the interface from two colours and a seed; no icon raster |
| Development Workflow | pass: `main`, FR-U04 namespace, one commit per task, every Spec Kit skill invoked for its step |

No violation; Complexity Tracking stays empty.

## Project Structure

### Source Code (repository root)

```text
Packages/VisualCore/
├── Sources/VisualCoreExperience/ShellModel.swift                 new
└── Tests/VisualCoreExperienceTests/ShellModelTests.swift         new

Apps/VisualCore/
├── App/
│   ├── VisualCoreApp.swift            new (app type, scene)
│   ├── AppModel.swift                 new (catalog, registry check, preferences, session, diagnostics)
│   ├── ExperienceRegistry.swift       new (explicit list; empty until UA-F07)
│   ├── PreferencesStore.swift         new
│   ├── ExperienceDataStore.swift      new
│   ├── RootView.swift                 new (split navigation, routes)
│   ├── LauncherView.swift             new (sections, search, states)
│   ├── TileView.swift                 new
│   ├── ExperienceRouteView.swift      new
│   ├── WelcomeView.swift              new
│   ├── SettingsView.swift             new
│   ├── AboutView.swift                new
│   ├── AppStrings.swift               new
│   └── DebugSupport/
│       ├── DebugLaunch.swift          new (DEBUG only: launch arguments, fixture catalog)
│       └── DebugExperience.swift      new (DEBUG only: core and presenter)
├── Resources/
│   ├── Localizable.xcstrings          new
│   └── PrivacyInfo.xcprivacy          new
├── Tests/Unit/
│   ├── AppModelTests.swift            new
│   └── StoreTests.swift               new
└── Tests/UI/
    ├── LauncherUITests.swift          new
    ├── RoutesUITests.swift            new
    ├── FirstRunUITests.swift          new
    └── SettingsUITests.swift          new

project.yml                            modify: targets VisualCore, VisualCoreTests, VisualCoreUITests; scheme VisualCore
scripts/xcodebuild_app.py              new
scripts/check_release_symbols.py       modify: option --forbid for the release-contents check
scripts/release_check.py               modify: the unsigned simulator build of the app as a step
scripts/test_scripts.py                modify
docs/api/visualcore-public-api.txt     modify (generated)
README.md, docs/getting-started.md, Auto-Creator.md (sections 11.1, 11.7, 16), docs/migration/path-map.json   modify in place
```

Existing and unchanged: the Showcase, the four standalone apps, the harnesses, VisualCoreUI, the session, the
catalog files.

**Structure Decision**: the app folder follows the layout of the existing apps (`App`, `Resources`, `Tests`,
generated plists); shared decisions go to the pure package, as Principle IV requires.

## Module and dependency direction

```text
VisualCoreExperience (pure, + shell model) ◄── VisualCoreApp (Apps/VisualCore) ──► VisualCoreExperienceHost, VisualCoreUI
VisualCoreTests, VisualCoreUITests ──► VisualCore (app)
```

The app depends on framework products only; nothing depends on the app.

## Public API

[contracts/shell-api.md](contracts/shell-api.md).

## Lifecycle and thread-ownership contracts

- The app model, the session and all views run on the main actor. Catalog loading and preference decoding are
  pure and run before the first view appears.
- One `ExperienceSession` for the app. The experience route opens through it and closes on back; the root view
  forwards the scene phase (through `ExperienceHostView`).
- Preferences are written after every change of route, search text or setting; a reset closes the open
  experience first.
- Debug launch arguments are read once at start and only in debug builds.

## Data schemas

[data-model.md](data-model.md). Preferences schema 1 has no predecessor; a later schema adds a tolerant reader.

## Tests of each layer

| Layer | Tests | Command |
|---|---|---|
| Host, pure | `ShellModelTests` | `swift test --package-path Packages/VisualCore --filter ShellModelTests` |
| Host, tool | `AppTestRunnerTests` in `scripts/test_scripts.py` | `python3 scripts/test_scripts.py` |
| App unit tests | `AppModelTests`, `StoreTests` in the simulator | part of the scheme's test action |
| App UI tests | four files with accessibility audits, on a phone and a tablet of both runtimes | `python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime <r> --kind <k>` |
| Package tests on simulators | the pure package on both runtimes | `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-<r> --action test` |
| Framework obligations | API baseline, documented API, dependencies, reference regression | quickstart.md |

## Build and test commands

[quickstart.md](quickstart.md); each evidence command through `run-check --gate UA-F04`.

## Migration and rollback

- Nothing existing changes behavior. Rollback: `git revert` of the feature's commits removes the app folder, the
  project entries, the shell model and the tool.

## Complexity Tracking

No constitution violation to justify.
