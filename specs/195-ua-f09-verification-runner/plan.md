# Implementation Plan: UA-F09 — Experience verification runner and evidence schema

**Branch**: `195-ua-f09-verification-runner` (spec directory only; work stays on `main`) | **Date**: 2026-11-12 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/195-ua-f09-verification-runner/spec.md`; the UA-F09 `/speckit-plan`
prompt of Auto-Creator.md section 20, verbatim in the invocation. The clarification decisions are binding.

## Summary

An experience reports an outcome derived from its state. Each experience carries a scenario manifest: the nine
standard scenarios as seeded domain actions with expectations. A runner plays one scenario through a real
session, then reads digests, the outcome, the rendered frame with its probes, timings and resources. The app
runs one scenario when its launch environment asks for it, writes a schema 1 record and exits; the Release
build contains none of this.

`scripts/verify_experiences.py` drives host tests, the build, the simulators, the result-bundle checks, the
record validation and the audits, with time limits and resumable state. The sample experience is proven through
package tests on both runtimes, and the app path through the debug experience.

## Technical Context

**Language/Version**: Swift 6 (toolchain 6.4.2, strict concurrency); Python 3 standard library.

**Primary Dependencies**: Foundation; the modules VisualCoreExperience, VisualCoreExperienceHost,
VisualCoreRendering and VisualCoreDiagnostics; SwiftUI in the app; `xcrun simctl`, `xcrun xcresulttool` and
`xcodebuild` from Xcode 27.2. No third-party package.

**Storage**: records in the app container's `Documents/visualcore-evidence/<run>/`, copied to
`.autonomy/verify/<run>/` (untracked); summaries in `docs/verification/<id>/` (tracked); run state in
`.autonomy/verify/state.json`.

**Testing**: Swift Testing on the host (manifest, validator, evaluator, frame checks, outcome); package tests on
the iOS 27.2 and 26.5 simulators (runner with the sample); app unit tests (scenario launch parsing, registry
with the debug experience, record writing); `unittest` for the scripts.

**Target Platform**: iOS and iPadOS 26.0; simulators iOS 27.2 and 26.5.

**Project Type**: additions to two framework modules, an app entry used only in builds made for testing, and
two new scripts.

**Performance Goals**: none claimed. Endurance on a simulator is a development signal.

**Constraints**: no runner code in the shipping build; no URL scheme; every wait bounded; no identifier in
tracked files; every command under ten minutes.

**Scale/Scope**:
- 8 new pure source files and 5 test files.
- 2 host files changed, 1 new host file and 1 new host test file with a sample manifest.
- 3 new app files and 2 changed.
- 2 new scripts with about 60 script tests.
- About 40 new public declarations.

## Constitution Check

*GATE: passed before Phase 0 research and re-checked after Phase 1 design (same result).*

| Principle | Result |
|---|---|
| I. Proven Renderer Only | pass: frames read from the existing render host; no renderer change |
| II. App-Neutral Public API | pass: outcome, manifest, runner and probes are generic; docs, baseline, tests and the reference regression are tasks |
| II-a. Preserve the Reference | pass: submodule untouched; the two-chunk regression is a task |
| III. GPU Lifecycle and Thread Ownership | pass: the runner is main-actor and drives the session; pixels are read only between frames on the main thread |
| IV. Host-Testable Domain Logic, Test-First | pass: manifest, validator, evaluator, frame checks and outcome are pure and tested first |
| V. Implementation Before Devices | pass: simulators only; the record format stays usable on devices without being run there |
| VI. Evidence Over Assertion | pass: a pass needs observed steps, digests and frames; result bundles are checked independently; failures are kept |
| VII. Native, Accessible UI | pass: the runner has no UI of its own; the scenario host view shows the session's own views |
| VIII. Public Apple APIs, Privacy | pass: `simctl`, `xcresulttool` and `xcodebuild` on the host; nothing leaves the machine; no identifier tracked |
| IX. Bounded Untrusted Input | pass: manifests, records and environment values are size-limited and validated |
| X. Licensing and Provenance | pass: no new dependency; the raster audit enforces generated art only |
| XI. One App and Stable Experience Identity | pass: one target; records keyed by experience id |
| XII. One Purchase and No Advertising | pass: no store code; the entitlement audit is named and left to UA-F08 |
| XIII. Code-Driven Visuals | pass: the raster audit makes the rule executable |
| Development Workflow | pass: `main`, FR-U09 namespace, one commit per task, Spec Kit skills in order |

No violation; Complexity Tracking stays empty.

## Project Structure

### Source Code (repository root)

```text
Packages/VisualCore/
├── Sources/VisualCoreExperience/
│   ├── ExperienceOutcome.swift              new      ExperienceOutcome (release); ExperienceCore.outcome default
│   ├── ExperienceCore.swift                 modify   outcome requirement
│   ├── ExperienceEngine.swift               modify   outcome
│   ├── ExperienceDiagnostics.swift          modify   outcome field
│   ├── ScenarioManifest.swift               new      manifest, errors, ContentRequirement   (#if)
│   ├── ScenarioManifestValidator.swift      new                                             (#if)
│   ├── ScenarioObservation.swift            new      observation, evaluator                 (#if)
│   ├── FrameChecks.swift                    new      checks, FrameProbe (release)
│   ├── ScenarioRequest.swift                new      environment keys and parsing            (#if)
│   └── EvidenceRecord.swift                 new      the app's part of schema 1             (#if)
├── Sources/VisualCoreTestSupport/SampleExperienceCore.swift   modify  outcome target-reached
└── Tests/VisualCoreExperienceTests/
    ├── OutcomeTests.swift, ScenarioManifestTests.swift, ScenarioEvaluatorTests.swift,
    │   FrameChecksTests.swift, ScenarioRequestTests.swift                                   new

Packages/VisualCoreRendering/
├── Sources/VisualCoreExperienceHost/
│   ├── ExperiencePresenter.swift            modify   probes(_:) default; Experience.frameProbes
│   ├── ExperienceShell.swift                modify   frameProbes
│   └── ScenarioRunner.swift                 new                                             (#if)
└── Tests/VisualCoreExperienceHostTests/
    ├── ScenarioRunnerTests.swift            new      nine scenarios of the sample, faults, attachments
    └── Fixtures/sample-manifest.json        new

Apps/VisualCore/
├── App/VisualCoreApp.swift                  modify   scenario request before the model
├── App/Automation/ScenarioLaunch.swift      new      request → registry → runner → record → exit   (#if)
├── App/Automation/ScenarioHostView.swift    new                                             (#if)
├── App/DebugSupport/DebugExperience.swift   modify   outcome, probes, manifest
├── App/DebugSupport/DebugInventory.swift    modify   the evidence folder rule
└── Tests/Unit/ScenarioLaunchTests.swift     new

scripts/verify_experiences.py                new
scripts/check_evidence.py                    new
scripts/xcodebuild_app.py                    modify   --result-name
scripts/check_release_symbols.py, scripts/check_experience_symbols.py    modify  names
scripts/release_check.py                     modify   steps evidence-self-test, verify-audits
scripts/test_scripts.py                      modify
Catalog/generated-art.json                   new      empty list of permitted generated raster files
docs/verification/README.md                  new      record layout
docs/api/visualcore-public-api.txt           modify
Auto-Creator.md (sections 6, 11.4, 16, 22)   modify   as built
```

## Module and dependency direction

The direction is unchanged. `VisualCoreExperience` (pure) holds the manifest, evaluator, checks, request and
record. `VisualCoreExperienceHost` holds the runner, which uses the session, render host and memory reading it
already depends on. The app holds the entry. `VisualCoreAutomation` is not used by the one app; its key name
`VISUALCORE_AUTORUN` is shared, with the value `scenario` reserved for the unified runner.

## Lifecycle and thread-ownership contracts

- The runner, the session and the render host live on the main actor. Pixels are read only after
  `renderOneFrame` returns.
- The app checks the request in `VisualCoreApp.init`, before `AppModel` exists. It never builds the launcher in
  a scenario run, so the run does not read or write the person's preferences.
- The process exits only after the record is written with `Data.write(options: .atomic)` and the file handle is
  synced.
- Save-restore in the app is two processes: the save phase writes `state.json` through `SavedStateStore` into the
  experience's normal folder. The restore phase loads it. The driver removes the experience's folder before the
  save phase and after the restore phase.

## Data schemas

Manifest schema 1 and evidence schema 1 (data-model.md). A newer number is refused with a typed error, and there
is no migration yet. The diagnostics coding gains an optional field; older encodings read.

## Tests of each layer

| Layer | Tests |
|---|---|
| Host (`swift test`) | outcome, manifest load and validation, evaluator, frame checks, request parsing |
| Package tests, iOS 27.2 and 26.5 | `ScenarioRunnerTests` (nine scenarios, two faults, attachments); existing session tests |
| App unit tests | `ScenarioLaunchTests`: parsing, registry with the debug experience, record writing without exit (the exit is injected) |
| App interface tests | the existing chunks; the inventory test with the new evidence rule |
| Scripts | validator, audits, driver planning, xcresult reading on fixtures, state and resume |

## Build and test commands

See [quickstart.md](quickstart.md).

## Migration and rollback

Additive. `git revert` of the feature's commits in reverse order removes the runner, the outcome and the scripts.
Experiences that implement `outcome` keep compiling against the default.

## Complexity Tracking

No violation to justify.
