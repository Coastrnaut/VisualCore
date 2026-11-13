# Implementation Plan: UA-F07 — Adoption of the existing apps A01 to A04 as experiences

**Branch**: `193-ua-f07-legacy-adoption` (spec directory only; work stays on `main`) | **Date**: 2026-11-13 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/193-ua-f07-legacy-adoption/spec.md`; the UA-F07 `/speckit-plan`
prompt of Auto-Creator.md section 20, verbatim in the invocation. The clarification decisions are binding.

## Summary

The four existing apps become experiences of the one app through thin adapters. Each adapter is a core that wraps
the app's domain types in the experience contract, and a presenter that wraps its existing scene. They are compiled
first as one framework per experience from the app's own folder, so the sources stay in place and keep their
history. A host change gives canvas touches to the presenter as actions.

Each experience is a candidate until the verification runner passes on both runtimes. Its interface tests are
ported with a mapping table and a guard. Then its sources move along the path map, its standalone target is
retired, and its X gate is recorded. The order is A01, A02, A03; A04 is adopted and verified, but X-A04 stays
pending.

## Technical Context

**Language/Version**: Swift 6 (toolchain 6.4.2, strict concurrency); Python 3 standard library for two tools.

**Primary Dependencies**: the four Core packages; VisualCore modules (Experience, Scenes, Simulation, Math,
Persistence, Parameters, Diagnostics); VisualCoreRendering (Rendering, ExperienceHost, Effects, UI). No new
third-party package.

**Storage**: A01's library and A03's bookmarks go through `ExperienceStorage`; saved states (UA-F05).

**Testing**: Core host tests (unchanged); conformance and session tests per adapter on the host and both
simulators; ported interface tests in the app; the UA-F09 runner; script tests.

**Target Platform**: iOS and iPadOS 26.0; simulators iOS 27.2 and 26.5.

**Performance Goals**: none claimed; A04's replay time is measured on simulators as a development signal.

**Constraints**: Core packages and fixtures unchanged; one app target; experiences independent; adapters list
every behaviour difference.

**Scale/Scope**: four adapters (about 4 × 400 lines), one host change, four framework targets, 56 ported
interface tests, two tools changed or new, and four moves of about 33 path-map entries.

## Constitution Check

*GATE: passed before Phase 0 research and re-checked after Phase 1 design.*

| Principle | Result |
|---|---|
| I. Proven Renderer Only | pass: the apps' scenes run on the existing render host; no renderer change |
| II. App-Neutral Public API | pass: the pointer hook is generic; docs, baseline and the reference regression are tasks |
| II-a. Preserve the Reference | pass: submodule untouched; the two-chunk regression is a task |
| III. GPU Lifecycle and Thread Ownership | pass: the presenters own GPU objects through the session; no stepping in render callbacks (A04 fix) |
| IV. Host-Testable Domain Logic, Test-First | pass: cores are pure and host-tested with the conformance helper before the presenters |
| V. Implementation Before Devices | pass: simulators only; A04's long-replay measurement on devices is left to the campaign |
| VI. Evidence Over Assertion | pass: the runner, the test map guard and the fixture hashes |
| VII. Native, Accessible UI | pass: native controls; ported audits at two text sizes |
| VIII. Public Apple APIs, Privacy | pass: no new API class; storage only through the handle |
| IX. Bounded Untrusted Input | pass: manifests, replays and stored documents are bounded |
| X. Licensing and Provenance | pass: the apps' acknowledgements merge into the one app's (UA-F11 owns the final list) |
| XI. One App and Stable Experience Identity | pass: frameworks, not app targets; catalog ids |
| XII. One Purchase and No Advertising | pass: all four are free; no store code |
| XIII. Code-Driven Visuals | pass: shaders and scenes are code; the app icons are retired, not shipped |
| Development Workflow | pass: `main`, FR-U07 namespace, one commit per task, Spec Kit skills in order |

The conflicts of rules E-04 and E-13 with A02 and A04 are resolved by clarifications 1 and 2 and ADR-0011, not by
exceptions to the constitution.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/
  ExperiencePresenter.swift, ExperienceShell.swift, ExperienceSession.swift          modify   pointer path
Packages/VisualCoreRendering/Package.swift                                            modify   ExperienceHost → VisualCoreScenes (if missing)
Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/{GenerativeArtCore,GenerativeArtPresenter,GenerativeArtControls,GenerativeArtManifest}.swift   new
Apps/FluidArtPlayground/FluidArtPlaygroundAdapter/{FluidArtCore,FluidArtPresenter,FluidArtControls,FluidArtManifest}.swift                       new
Apps/FractalExplorer/Adapter/{FractalCore,FractalPresenter,FractalControls,FractalManifest}.swift                               new
Apps/ParticleUniverse/Adapter/{ParticleCore,ParticlePresenter,ParticleControls,ParticleManifest}.swift                         new
Apps/*/Adapter/Tests/<Name>AdapterTests.swift (conformance, replay, digests)                                                   new
project.yml                                                   modify   four Experience frameworks, adapter test bundles, VisualCore links them
Apps/VisualCore/App/ExperienceRegistry.swift                  modify   candidates
Apps/VisualCore/App/DebugSupport/DebugLaunch.swift            modify   -vcCandidates
Apps/VisualCore/Tests/UI/{GenerativeArtStudio,FluidArtPlayground,FractalExplorer,ParticleUniverse}/   new  ported tests
specs/193-ua-f07-legacy-adoption/test-map.csv                 new
scripts/check_test_map.py                                     new
scripts/check_app_contract.py, scripts/release_check.py       modify   path map, experience packages
scripts/xcodebuild_app.py (chunk helpers), scripts/test_scripts.py   modify
docs/decisions/ADR-0011-fluid-picture-presentation.md        new
docs/apps/<slug>/README.md (four)                             new      "store listing superseded"
Packages/ExperiencesCreative/                                 new (move)   Package.swift and the four experiences after parity
Catalog/path-map.json, docs/migration/path-map.json           modify
Auto-Creator.md (sections 17, 16)                             modify   as built
```

## Module and dependency direction

Each experience framework (later each package target pair `<Name>Core`, `<Name>Experience`) depends on its Core
and on VisualCore and VisualCoreRendering products. The app depends on the four. No experience depends on another.
VisualCoreExperienceHost gains VisualCoreScenes (pure) for `PointerEvent`.

## Lifecycle and thread-ownership contracts

- Cores step only in `update(step:)`; presenters draw from the core. A04's stepping moves out of the render
  callback, and A03's tours and palette move off `systemUptime`.
- The session owns the render host. A presenter's GPU objects follow setup and teardown. A02's fields are rebuilt
  at every setup (a context loss included).
- Pointer events arrive on the main actor through the host's handler and become actions in the same turn.

## Data schemas

Every adapter core has schema version 1 (the first stored state of each experience in the one app). The Core
packages' own document schemas are unchanged: A01's library documents and A03's bookmarks keep their migrations
and fixtures.

## Tests of each layer

| Layer | Tests |
|---|---|
| Host | Core packages unchanged; adapter core tests (conformance helper, digests, replay, normalization) |
| Package tests, iOS 27.2 and 26.5 | session host tests with the pointer path; adapter session tests in the framework test bundles |
| App | registry candidates; ported interface tests (56 methods, map guard); existing chunks |
| Runner | `verify_experiences.py` for A01–A04 on both runtimes |
| Tools | `check_test_map.py`, the contract checker's path-map resolution, the release-check steps |

## Build and test commands

See [quickstart.md](quickstart.md).

## Migration and rollback

Each experience is a separate group of commits: adapter, ported tests, move, retirement, X gate. `git revert` of a
group in reverse order restores the earlier state. The standalone target exists until its own retirement, so the
app stays buildable at every step.

## Complexity Tracking

No violation to justify. Four framework targets exist only until the move into `Packages/ExperiencesCreative`.
