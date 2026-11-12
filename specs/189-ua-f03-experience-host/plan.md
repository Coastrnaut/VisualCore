# Implementation Plan: UA-F03 — Experience host and session lifecycle

**Branch**: `189-ua-f03-experience-host` (spec directory only; work stays on `main`) | **Date**: 2026-11-12 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/189-ua-f03-experience-host/spec.md`; the UA-F03 `/speckit-plan`
prompt of Auto-Creator.md section 20, verbatim in the invocation. The clarification decisions are binding.

## Summary

One main-actor object, `ExperienceSession`, opens and closes experiences for the whole app. It builds the
experience from a factory, prepares it, creates the render host with the experience's budget, activates it, and
on every exit destroys the host and proves that no GPU object is live or leaked. It turns failures into a state
the interface can show, cancels preparations, follows scene phases, reacts to memory warnings and recreated
contexts, and hands snapshots to a sink. Its decisions (state table, close order, pressure rule) are pure values
tested on the Mac host. `ExperienceHostView` shows the session. The isolation tool learns about experience
modules.

## Technical Context

**Language/Version**: Swift 6 (toolchain 6.4.2, language mode 6, strict concurrency); Python 3 standard library
for the tool.

**Primary Dependencies**: SwiftUI, Observation, UIKit (memory-warning notification); the existing modules
VisualCoreRendering, VisualCoreUI (`RenderSurface`), VisualCoreDiagnostics and VisualCoreExperience. No
third-party package.

**Storage**: none. Snapshots go to a sink supplied by the opener (UA-F05).

**Testing**: Swift Testing on the host for the pure part; XCTest on both simulator runtimes for the session and
the host view (a real render host; the sample experience of UA-F02); `unittest` for the tool. App UI tests: none
in this feature, because the app target is created by UA-F04, whose UI tests drive the host view's controls.

**Target Platform**: iOS and iPadOS 26.0; the pure package also macOS 15.0.

**Project Type**: library modules in two existing Swift packages, plus a change to one repository tool.

**Performance Goals**: a close during preparation ends within 1 second; 50 open and close cycles keep live bytes
constant. Simulator measurements only.

**Constraints**: main actor for everything that touches the render host; exactly one render host alive; no file
access and no network; texts in the module's string catalog; inputs bounded.

**Scale/Scope**: 1 new pure source file, 4 new main-actor source files and one resource file, 5 new test files,
1 changed tool, about 40 new public declarations.

## Constitution Check

*GATE: passed before Phase 0 research and re-checked after Phase 1 design (same result).*

| Principle | Result |
|---|---|
| I. Proven Renderer Only | pass: the session uses `RenderHost` as it is; the isolation tool now also covers experience modules |
| II. App-Neutral Public API | pass: generic framework code; documentation, baseline, tests and reference regression are tasks |
| II-a. Preserve the Reference | pass: submodule untouched; regression rerun in two chunks |
| III. GPU Lifecycle and Thread Ownership | pass: main actor; one host; fixed close order ending with a count of live and leaked objects; context recreation covered |
| IV. Host-Testable Domain Logic, Test-First | pass: state table, close order and pressure rule are pure and host-tested; tests before code |
| V. Implementation Before Devices | pass: simulators only; long-session memory and thermal behavior is a `{device}` task |
| VI. Evidence Over Assertion | pass: every evidence command through `run-check`; counts are read from the registry, not assumed |
| VII. Native, Accessible UI | pass: native controls with labels and stable identifiers, canvas label from the state description, layout checked at the largest text size |
| VIII. Public Apple APIs, Privacy | pass: SwiftUI, Observation, UIKit notification; no network, nothing stored |
| IX. Bounded Untrusted Input | pass: a refused snapshot never stops an open; time limit on preparation |
| X. Licensing and Provenance | pass: no new dependency or asset |
| XI. One App and Stable Experience Identity | pass: one session for the app; identifiers derive from the experience id |
| XII. One Purchase and No Advertising | pass: no store, advertising, analytics or tracking code |
| XIII. Code-Driven Visuals | pass: nothing drawn by the session itself beyond native views |
| Development Workflow | pass: `main`, FR-U03 namespace, one commit per task, push after the scan, every Spec Kit skill invoked for its step |

No violation; Complexity Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/189-ua-f03-experience-host/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/session-api.md
├── checklists/
└── tasks.md            (created by /speckit-tasks)
```

### Source Code (repository root)

```text
Packages/VisualCore/
├── Sources/VisualCoreExperience/SessionLifecycle.swift            new (pure session values)
└── Tests/VisualCoreExperienceTests/SessionLifecycleTests.swift    new

Packages/VisualCoreRendering/
├── Package.swift                                                   modify: default localization, resources of the
│                                                                           host module, its dependency on VisualCoreUI
├── Sources/VisualCoreExperienceHost/
│   ├── ExperienceSession.swift                                     new
│   ├── ExperienceOpenRequest.swift                                 new
│   ├── ExperienceHostView.swift                                    new (host view and its state views)
│   ├── SessionStrings.swift                                        new
│   └── Resources/Localizable.xcstrings                             new
└── Tests/VisualCoreExperienceHostTests/
    ├── SessionOpenCloseTests.swift                                 new (open, one at a time, 50 cycles, leak)
    ├── SessionFailureTests.swift                                   new (failure kinds, timeout, retry, back, cancellation)
    ├── SessionPhaseMemoryTests.swift                               new (phases, memory warning, context recreation, sink)
    └── ExperienceHostViewTests.swift                               new (state views, layout at the largest text size)

scripts/check_app_isolation.py                                      modify
scripts/test_scripts.py                                             modify
docs/api/visualcore-public-api.txt                                  modify (generated)
Packages/VisualCoreRendering/README.md, docs/getting-started.md, Auto-Creator.md (sections 11.4, 16)   modify in place
docs/migration/path-map.json                                        modify (notes)
```

Existing and unchanged in behavior and API: `RenderHost`, `ResourceRegistry`, `FrameScheduler`, `RenderSurface`,
the experience contract of UA-F02 (additions only), `SamplePresenter` and the sample core.

**Structure Decision**: the session and its view join the module that UA-F02 created, as Auto-Creator.md
sections 11.4 and 13 state; the pure values join VisualCoreExperience.

## Module and dependency direction

```text
VisualCoreExperience (pure) ◄── VisualCoreExperienceHost ──► VisualCoreRendering, VisualCoreUI, VisualCoreDiagnostics
VisualCoreExperienceHostTests ──► VisualCoreExperienceHost, VisualCoreTestSupport, CVisualCoreGL
later: the app shell (UA-F04) ──► VisualCoreExperienceHost
```

Acyclic. `VisualCoreUI` does not depend on the host module.

## Public API

[contracts/session-api.md](contracts/session-api.md).

## Lifecycle and thread-ownership contracts

- The session, its view and every call into the experience and the render host run on the main actor. The core's
  preparation runs off the main actor inside the shell, as built by UA-F02.
- The session lifecycle (data-model.md section 1) sits above the experience lifecycle, which sits above the render
  host's lifecycle. Each layer keeps its own table; no layer skips one.
- Exactly one render host is alive: created after a successful preparation, destroyed in the close order, on
  failure, on memory closure and in `deinit`.
- Every suspension point of `open` is followed by a generation check; a stale open releases what it built.
- Observers: one memory-warning observer owned by the session and removed in `deinit`; one error observer per
  render host, gone with the host.

## Data schemas

[data-model.md](data-model.md). `SessionDiagnostics` is an evidence value with sorted keys; it has no stored
predecessor and is not read back by the app, so there is no migration.

## Tests of each layer

| Layer | Tests | Command |
|---|---|---|
| Host, pure | `SessionLifecycleTests` (49 state pairs, close order, pressure rule, diagnostics encoding) | `swift test --package-path Packages/VisualCore --filter SessionLifecycleTests` |
| Host, tool | `AppIsolationTests` additions in `scripts/test_scripts.py` | `python3 scripts/test_scripts.py` |
| Package tests on simulators | the four session test files with a real render host, on iOS 27.2 and iOS 26.5 | the two commands of the brief |
| App UI tests | none here; UA-F04 drives the host view in the app | not applicable |
| Framework obligations | API baseline, documented API, dependency rules, reference regression, consumers | quickstart.md |

## Build and test commands

All in [quickstart.md](quickstart.md); each evidence command through
`python3 scripts/migration_ledger.py run-check --gate UA-F03 --name <check-name> -- <command>`.

## Migration and rollback

- Nothing stored changes. `check_app_isolation.py` keeps its behavior for existing app folders.
- Rollback: `git revert` of the feature's commits. No shipped target uses the session yet.

## Complexity Tracking

No constitution violation to justify.
