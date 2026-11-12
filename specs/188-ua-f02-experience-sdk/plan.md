# Implementation Plan: UA-F02 — ExperienceKit: the experience contract

**Branch**: `188-ua-f02-experience-sdk` (spec directory only; work stays on `main`) | **Date**: 2026-11-12 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/188-ua-f02-experience-sdk/spec.md`; the UA-F02 `/speckit-plan`
prompt of Auto-Creator.md section 20, verbatim in the invocation. The clarification decisions of the
specification are binding.

## Summary

Every experience of the unified app is written in two parts. A pure, `Sendable` core holds the domain state and
is prepared from a seed, advanced in fixed steps, driven by validated actions, captured in a versioned snapshot
and reduced to a SHA-256 digest. A main-actor presenter draws the core through the existing scene contract and
offers native controls. The framework adds what is common: the lifecycle reducer, the engine that enforces it,
the snapshot envelope, diagnostics, the conformance helper, the scenario hooks for automation builds, and a shell
that joins core and presenter behind one type-erased protocol for the session host of UA-F03. A sample experience
with seven deliberate faults proves the contract on the host and on both simulator runtimes.

## Technical Context

**Language/Version**: Swift 6 (toolchain 6.4.2, language mode 6, strict concurrency, typed throws); Python 3
standard library for one tool.

**Primary Dependencies**: Foundation and the existing pure modules VisualCoreMath, VisualCoreSimulation and
VisualCorePersistence for the pure part; SwiftUI, Observation and the existing VisualCoreRendering and
VisualCoreDiagnostics for the main-actor part. No third-party package.

**Storage**: none written by this feature. The snapshot envelope (format 1) is a `Codable` value that the
existing `DocumentStore` can store; where and when it is stored is UA-F05.

**Testing**: Swift Testing in `Packages/VisualCore/Tests` on the host and on both simulator runtimes; XCTest in
`Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests` on both simulator runtimes (a real render
host, frames read back); `unittest` in `scripts/test_scripts.py` for the tool. No app UI tests: this feature has
no screen.

**Target Platform**: iOS and iPadOS 26.0; the pure package also macOS 15.0 for host tests.

**Project Type**: library modules in two existing Swift packages, plus one repository tool.

**Performance Goals**: the conformance run of the sample takes less than 10 seconds on the development Mac; a
cancelled preparation ends within 1 second. Host and simulator measurements only; no device claim.

**Constraints**: the pure module imports only Foundation-level modules and pure VisualCore modules (rule R2);
everything that touches the graphics context runs on the main actor; code that reads a snapshot or an action
never traps; all inputs are bounded (research R12); hooks for automation compile only under `DEBUG` or
`VISUALCORE_AUTOMATION`.

**Scale/Scope**: 10 new source files in VisualCoreExperience, 1 moved file, 1 new module with 4 source files, 2
sample files, 2 new or extended test targets, 1 new tool; about 60 new public declarations.

## Constitution Check

*GATE: passed before Phase 0 research and re-checked after Phase 1 design (same result).*

| Principle | Result |
|---|---|
| I. Proven Renderer Only | pass: drawing goes through `RenderScene` on `RenderHost`; no renderer, context or scheduler is added |
| II. App-Neutral Public API | pass: the contract is generic framework code; `///` documentation, API baseline update, tests and the reference regression are tasks; no ProjectM type |
| II-a. Preserve the Reference | pass: submodule untouched; regression rerun in two chunks |
| III. GPU Lifecycle and Thread Ownership | pass: the shell, presenter and scene are `@MainActor`; GPU objects are created in `setup`, released in `teardown`, rebuilt after a context recreation; deactivation ends with a count of live and leaked objects; the experience lifecycle sits above the render lifecycle and does not replace it |
| IV. Host-Testable Domain Logic, Test-First | pass: lifecycle, digest, snapshot, actions, engine and conformance are pure and tested on the host; tests are written before the code they prove |
| V. Implementation Before Devices | pass: no device action; simulators only |
| VI. Evidence Over Assertion | pass: every evidence command goes through `migration_ledger.py run-check`; digests are compared with committed values; the absence of automation symbols is measured, and measured to be detectable |
| VII. Native, Accessible UI | pass: no screen here; the contract requires native controls, a state description and identifiers with the catalog's accessibility prefix |
| VIII. Public Apple APIs, Privacy | pass: Foundation, SwiftUI, Observation; no network; nothing stored |
| IX. Bounded Untrusted Input | pass: snapshot size, value counts, ranges, finiteness, versioned format, typed errors, no trap on data |
| X. Licensing and Provenance | pass: no new dependency or asset; SHA-256 is the repository's own implementation, moved |
| XI. One App and Stable Experience Identity | pass: no app target; every name derives from `ExperienceID`; experiences depend only on the framework |
| XII. One Purchase and No Advertising | pass: no store, advertising, analytics or tracking code |
| XIII. Code-Driven Visuals | pass: the sample draws by code; outcomes are decided by CPU state, never by pixels |
| Development Workflow | pass: work on `main`, ids in the FR-U02 namespace, one commit per task, push after the scan, every Spec Kit skill invoked for its step |

No violation; Complexity Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/188-ua-f02-experience-sdk/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── experience-core-api.md
│   └── experience-host-api.md
├── checklists/
└── tasks.md            (created by /speckit-tasks)
```

### Source Code (repository root)

```text
Packages/VisualCore/
├── Package.swift                                        modify: dependencies of VisualCoreExperience, VisualCoreShaderSource,
│                                                                VisualCoreTestSupport and of three test targets
├── Sources/VisualCoreMath/StableHash.swift              move (from VisualCoreShaderSource/SHA256.swift), made public
├── Sources/VisualCoreShaderSource/SHA256.swift          modify: keeps ShaderCacheKey, which now calls StableHash
├── Sources/VisualCoreExperience/
│   ├── Module.swift                                     modify: version 1.1.0-rc.1, header
│   ├── ExperienceError.swift                            new
│   ├── ExperienceLifecycle.swift                        new
│   ├── StateDigest.swift                                new
│   ├── ExperienceAction.swift                           new
│   ├── ExperienceSnapshot.swift                         new
│   ├── ExperienceCore.swift                             new
│   ├── ExperienceEngine.swift                           new
│   ├── ExperienceDiagnostics.swift                      new
│   ├── ExperienceConformance.swift                      new
│   └── ExperienceScenario.swift                         new (DEBUG || VISUALCORE_AUTOMATION)
├── Sources/VisualCoreTestSupport/
│   ├── SampleExperienceCore.swift                       new
│   └── SampleExperience.swift                           new (id, plan, committed digests, version-1 snapshot)
└── Tests/
    ├── VisualCoreMathTests/StableHashTests.swift        new (the vectors of the moved implementation)
    ├── VisualCoreShaderSourceTests/SHA256Tests.swift    existing (must stay green unchanged)
    └── VisualCoreExperienceTests/
        ├── ExperienceErrorTests.swift                   new
        ├── LifecycleTests.swift                         new
        ├── StateDigestTests.swift                       new
        ├── ExperienceActionTests.swift                  new
        ├── ExperienceSnapshotTests.swift                new
        ├── ExperienceEngineTests.swift                  new (preparation, lifecycle calls, fixed steps)
        ├── ExperienceEngineStateTests.swift             new (snapshot, restore, reset)
        ├── ExperienceEngineInputTests.swift             new (actions, replay)
        ├── ExperienceEngineQualityTests.swift           new (tier, shedding, leak rule, all operation cells)
        ├── ExperienceDiagnosticsTests.swift             new
        ├── ExperienceConformanceTests.swift             new
        ├── ExperienceScenarioTests.swift                new
        └── SampleExperienceTests.swift                  new (committed digests, migration, replay)

Packages/VisualCoreRendering/
├── Package.swift                                        modify: target, product and test target of the new module
├── Sources/VisualCoreExperienceHost/
│   ├── Module.swift                                     new
│   ├── ExperiencePresenter.swift                        new (ExperiencePresenter, Experience)
│   ├── ExperienceActionPort.swift                       new
│   └── ExperienceShell.swift                            new (shell and its scene)
└── Tests/VisualCoreExperienceHostTests/
    ├── ModuleTests.swift                                new
    ├── SamplePresenter.swift                            new
    ├── ShellRenderingTests.swift                        new
    ├── ShellLifecycleTests.swift                        new
    └── ShellPortTests.swift                             new

scripts/check_experience_symbols.py                      new
scripts/test_scripts.py                                  modify: tests of the new tool
docs/api/visualcore-public-api.txt                       modify (generated by check_public_api.py --update)
Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md, docs/getting-started.md   modify
Auto-Creator.md (sections 11.3 and 16), docs/migration/path-map.json                            modify in place
```

Existing and unchanged in behavior and API: `RenderScene`, `RenderHost`, `ResourceRegistry`, `RenderSurface`,
`RenderLifecycle`, `FixedStepClock`, `FixedStepRunner`, `PlaybackState`, `DocumentStore`, `MigrationChain`,
`QualityPolicy`, the module VisualCoreAutomation, `ShaderCacheKey`, and everything of UA-F01.

**Structure Decision**: the pure part extends the module of UA-F01, as ADR-0009 D-06 and Auto-Creator.md section
11.3 state; the main-actor part is a new target of the rendering package, next to VisualCoreUI and
VisualCoreAutomation.

## Module and dependency direction

```text
VisualCoreMath ◄── VisualCoreShaderSource                       (new edge: StableHash)
VisualCoreMath, VisualCoreSimulation, VisualCorePersistence ◄── VisualCoreExperience
VisualCoreExperience, VisualCorePersistence, VisualCoreMath, VisualCoreSimulation ◄── VisualCoreTestSupport   (tests only, rule R5)
VisualCoreRendering, VisualCoreDiagnostics, VisualCoreExperience ◄── VisualCoreExperienceHost
VisualCoreExperienceHost, VisualCoreTestSupport, CVisualCoreGL ◄── VisualCoreExperienceHostTests
later: session host (UA-F03), experiences ──► VisualCoreExperienceHost, VisualCoreExperience
```

Acyclic. The pure package gains no dependency on the rendering package. No module depends on an experience.

## Public API

[contracts/experience-core-api.md](contracts/experience-core-api.md) and
[contracts/experience-host-api.md](contracts/experience-host-api.md). Errors are typed and carry stable codes.

## Lifecycle and thread-ownership contracts

- The experience lifecycle (data-model.md sections 1 and 2) is a value inside the engine; the engine is a value
  inside the shell. The render host keeps its own lifecycle below it.
- Main actor: shell, presenter, port, scene, every GPU call. The render host asserts the owning thread; the shell
  adds no second thread to the graphics context.
- Off the main actor: `Core.prepare(seed:)` in a detached task. Its result is a `Sendable` value handed back to
  the main actor; a result whose ticket is stale is discarded.
- Cancellation: the caller's task or `cancelPreparation()` cancels the detached task; the lifecycle goes to
  inactive at once and the late result is discarded.
- Frames: the scene asks the engine for steps only in active; resume discards accumulated time; a frame draws the
  core value it was given.
- Deactivation: `beginDeactivation` stops every callback except `teardown`; the host owner destroys the host;
  `finishDeactivation` reads the counts. A leak is a typed failure, never a silent pass.
- Failure: an error of preparation, setup or drawing moves the lifecycle to failed and stays readable in the
  diagnostics; preparing again and deactivating stay legal.

## Data schemas

[data-model.md](data-model.md): the digest encoding (section 3), the snapshot envelope, format 1, with its
validation order and the migration path through `MigrationChain` (section 4), and the diagnostics value
(section 5). There is no earlier envelope format, so nothing is migrated at the envelope level; a later change
takes format 2 and a reader for both. Each experience versions its payload itself; the sample has version 2 with
one migration step, to prove the path.

## Tests of each layer

| Layer | Tests | Command |
|---|---|---|
| Host, pure | `VisualCoreExperienceTests` (lifecycle table, digest vectors, actions, snapshot fixtures and migration, engine, diagnostics, conformance with seven faults, scenario, committed digests), `VisualCoreMathTests` (hash vectors), `VisualCoreShaderSourceTests` (unchanged) | `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests`; the whole package with `swift test --package-path Packages/VisualCore` |
| Host, tool | `ExperienceSymbolsTests` in `scripts/test_scripts.py` | `python3 scripts/test_scripts.py` |
| Package tests on simulators, pure | the same Swift tests on iOS 27.2 and iOS 26.5 (the committed digests must match there too) | `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-27.2 --action test` and `--destination sim-26.5` |
| Package tests on simulators, main actor | `VisualCoreExperienceHostTests` with a real render host: drawing, context recreation, tier, shedding, deactivation counts, failure paths, cancellation, port, scenario | the two commands of the brief (`--scheme VisualCoreRendering-Package`, `--result-name ua-f02-ios27` and `ua-f02-ios26`) |
| Release symbols | 0 automation symbols without the flag, at least 1 with it, for both modules | `python3 scripts/check_experience_symbols.py --module pure|host [--with-flag]` |
| App UI tests | none: no screen in this feature | not applicable |
| Framework obligations | API baseline, documented API of the consumers, dependency rules, reference regression in two chunks, consumers rebuilt for testing | see quickstart.md |

## Build and test commands

All in [quickstart.md](quickstart.md). Each evidence command is recorded with
`python3 scripts/migration_ledger.py run-check --gate UA-F02 --name <check-name> -- <command>`; simulator, symbol
and reference commands get `--timeout 600`. One heavy build runs at a time, in the foreground.

## Migration and rollback

- No stored data exists in this format yet, so nothing is migrated.
- The only change to existing code is the move of SHA-256: `ShaderCacheKey` keeps its API and results, proven by
  the unchanged `SHA256Tests`.
- Rollback: `git revert` of the feature's commits removes the new files and restores the two package manifests,
  the moved file and the API baseline. No shipped target depends on the new modules yet, so a revert cannot break
  a consumer.

## Complexity Tracking

No constitution violation to justify.
