# VisualCore

[![CI](https://github.com/Coastrnaut/VisualCore/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Coastrnaut/VisualCore/actions/workflows/ci.yml)
[![Push scan](https://github.com/Coastrnaut/VisualCore/actions/workflows/push-scan.yml/badge.svg?branch=main)](https://github.com/Coastrnaut/VisualCore/actions/workflows/push-scan.yml)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20iPadOS%2026%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.4-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**One iOS and iPadOS app of code-drawn visual experiences, built on a reusable OpenGL ES → ANGLE → Metal rendering
framework.**

VisualCore is two things in one repository:

- **The VisualCore framework** — Swift packages that draw with OpenGL ES 3.0 through EGL and the owner's fork of ANGLE
  on its Metal backend, plus pure-Swift modules for math, simulation, scenes, audio analysis, persistence and the
  experience contract.
- **The VisualCore app** — a single App Store app (one target, one bundle identifier) in which every creative app and
  every game is a registered *experience* opened from one launcher
  ([ADR-0009](docs/decisions/ADR-0009-unified-app.md)).

This README states only what is true in the repository today and labels everything else as planned. It is updated
with every gate that changes what it says (see [Keeping this README current](#keeping-this-readme-current)).

## Contents

- [Status](#status)
- [Features](#features)
- [The app and its experiences](#the-app-and-its-experiences)
- [How it renders](#how-it-renders)
- [Getting started](#getting-started)
- [Testing and continuous integration](#testing-and-continuous-integration)
- [Repository structure](#repository-structure)
- [Framework modules](#framework-modules)
- [Development workflow](#development-workflow)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Keeping this README current](#keeping-this-readme-current)
- [License](#license)

## Status

State on **2026-11-14**. Progress lives in two ledgers, never in prose; the commands below print the live state. A
gate is "pass" when its host and simulator checks passed and its evidence is recorded. **Pass is never device
evidence**: no physical-device test of the unified app has been run.

| Component | State today | Evidence |
|---|---|---|
| Framework packages (version 1.0.0-rc.1) | simulator-verified: host tests and iOS Simulator tests | `.autonomy/evidence/F00.json` … `F09.json`; [release notes](docs/release/release-notes-1.0.0-rc.1.md) |
| Unified VisualCore app (`Apps/VisualCore`) | exists: launcher, routes, settings, about, onboarding, session host, persistence, quality profiles, verification runner (UA-F00 … UA-F07, UA-F09 … UA-F11 pass) | `python3 scripts/migration_ledger.py status` |
| Audio modules `VisualCoreAudioDSP` and `VisualCoreAudio` | implemented: FFT, bands, RMS, onsets, test signals, min/max decimation; demo, file, microphone, test-signal and two-channel sources with interruption and route handling | A06–A08 phases; [known limitations](docs/release/known-limitations.md) |
| A01 Generative Art Studio | experience in the app; X-A01 pass | `.autonomy/migration/checks/X-A01.*.json` |
| A02 Fluid Art Playground | experience in the app; X-A02 pass | `.autonomy/migration/checks/X-A02.*.json` |
| A03 Fractal Explorer | experience in the app; X-A03 pass | `.autonomy/migration/checks/X-A03.*.json` |
| A04 Particle Universe | experience in the app; X-A04 pass | `.autonomy/migration/checks/X-A04.*.json` |
| A05 Infinite Geometry | experience in the app; X-A05 pass | `.autonomy/migration/checks/X-A05.*.json` |
| A06 VisualCore Music Lab | experience in the app; X-A06 pass | `.autonomy/migration/checks/X-A06.*.json` |
| A07 Audio Odyssey | experience in the app; X-A07 pass | `.autonomy/migration/checks/X-A07.*.json` |
| A08 Oscilloscope Studio | experience in the app; X-A08 pass | `.autonomy/migration/checks/X-A08.*.json` |
| A09–A25 | not started | next legacy gate A09-P00 |
| Shared round features (R02-F02 … F05, F26) | pass | `python3 scripts/migration_ledger.py status` |
| Games of Rounds 2–12 | planned; none exists in source | [catalog](docs/catalog/experience-catalog.json) |
| Physical-device testing | none run; waits for `ImplementationLock-100` | [support matrix](docs/release/support-matrix.md) |
| App Store | no submission and nothing for sale; signing, App Store Connect and agreements are owner actions | [build and archive](docs/release/build-and-archive.md) |

Ledger totals today: the legacy ledger records **66 of 263** gates as passed (F00–F09 and the app phases
A01-P00 … A08-P06); the unified-app ledger has 1,233 gates, with 8 experience gates (X-A01 … X-A08), 11 unified-app features,
5 shared round features and both governance milestones passed.

```bash
python3 Tools/python/desktop_runbook.py status   # legacy gates: framework and app phases
python3 scripts/migration_ledger.py status        # unified-app gates and the next action
```

## Features

- **One renderer.** OpenGL ES 3.0 through EGL on ANGLE's Metal backend; `scripts/check_compliance.py` rejects any
  second renderer.
- **Visuals are code.** GLSL shaders, procedural meshes, signed-distance fields, particles and deterministic
  animation — no purchased, generated or hand-made art.
- **Deterministic simulation.** A seeded random generator and a fixed-step clock (`VisualCoreSimulation`) make every
  scene repeatable in automated tests; each experience proves this with a scenario manifest and state digests.
- **Experience contract.** Every experience implements one contract (core state, actions, snapshots with migrations,
  quality tiers, accessibility description) and is opened, suspended, restored and torn down by one host.
- **Audio without recording.** Live analysis of microphone, file and test-signal input in memory only; nothing is
  recorded, stored or sent.
- **Private by design.** No network requests, no accounts, no tracking and no advertising of any kind.
- **Accessible.** Every control has a label, value and identifier; each canvas has a spoken description; Reduce Motion
  and Reduce Flashing are honoured.

## The app and its experiences

Planned scope, decided in [ADR-0009](docs/decisions/ADR-0009-unified-app.md). The first release contains exactly
**100 experiences**:

| Tier | Experiences | Count |
|---|---|---|
| Free forever | the 25 original creative apps (A01–A25) and the 25 Round 2 games (R02-G01 … R02-G25) | 50 |
| Premium | the games of Rounds 3 and 4 (R03-G01 … R04-G25) | 50 |

- **Price:** free download plus one non-consumable in-app purchase of USD 1.99 (StoreKit 2) that unlocks every
  premium experience, present and future. No subscriptions, consumables or external payment paths.
- **No advertising of any kind.** No ad or tracking SDKs, no ad identifiers, no required account.
- **Order of work:** all 100 experiences are implemented and verified on the iOS Simulator before any
  physical-device campaign begins (gate `ImplementationLock-100`), then devices D1 → D2 → D3.
- **Catalog:** [docs/catalog/experience-catalog.json](docs/catalog/experience-catalog.json) lists all 300 planned
  experiences: the 100 above and a backlog of 200 from Rounds 5–12. It is a plan, not evidence of implementation.
- **Plan and gates:** [docs/migration/migration-plan.md](docs/migration/migration-plan.md) and the gate ledger
  `.autonomy/migration/ledger.json`.

The name "VisualCore" has not been checked for App Store availability, and the bundle identifier is a placeholder.

## How it renders

```text
RenderScene (OpenGL ES 3.0 calls) -> EGL -> ANGLE (libEGL, libGLESv2) -> Metal -> GPU
```

A scene implements `RenderScene` and issues OpenGL ES 3.0 calls. `RenderHost` owns the EGL context and a window
surface on the view's `CAMetalLayer`, runs frames from a `CADisplayLink` on the main thread and presents them with
`eglSwapBuffers`. EGL and OpenGL ES come from prebuilt `libEGL` and `libGLESv2` frameworks of the ANGLE fork (Metal
backend); they are built with the scripts of the pinned submodule `External/projectm-ios` and are not committed.
Experiences draw only through the host's context (`VisualCoreExperienceHost`); none owns a context of its own.

More: [architecture](docs/architecture/visualcore-architecture.md) and the
[reference pipeline](docs/architecture/current-rendering-pipeline.md) that `RenderHost` re-implements.

## Getting started

### Requirements

Toolchain as recorded in [Configs/toolchain.json](Configs/toolchain.json) (never silently upgraded):

| Tool | Version |
|---|---|
| Xcode | 27.2 (build 27B52), iOS SDK 27.2 |
| Swift | 6.4.2 |
| XcodeGen | 2.46.0 |
| CMake | 4.4.5 |
| Python | 3.10 or later |
| Simulator runtimes | iOS 26.5 and iOS 27.2 |

### Setup

```bash
git clone https://github.com/Coastrnaut/VisualCore.git
cd VisualCore
git submodule update --init External/projectm-ios
python3 scripts/verify_environment.py
```

Fetch only the reference submodule (do not use `--recursive` at the top level), then compare the installed tools with
`Configs/toolchain.json`. Rendering tests, the app, the Showcase and the harnesses also need the ANGLE frameworks
built from the submodule and Xcode projects generated with XcodeGen; [setup.md](setup.md) is the full guide.

### Build and run the app

```bash
xcodegen generate --spec project.yml
python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone --action build-for-testing
```

`project.yml` is the XcodeGen specification of the VisualCore app, its unit and interface tests, and the Showcase.
Xcode projects and build output are generated locally and are not committed. Debug builds show experiences that are
still candidates (none today) with the launch argument `-vcCandidates`.

## Testing and continuous integration

```bash
swift test --package-path Packages/VisualCore                                   # pure modules on the macOS host
python3 scripts/release_check.py --list                                          # every release check and its command
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/verify_experiences.py --runtime 27                              # scenario manifests of every experience
python3 scripts/release_check.py --only docs app-contracts compliance dependencies public-api licenses script-tests
```

- App tests build once (`build-for-testing`) and run in `test-without-building` chunks under a time limit
  (`scripts/xcodebuild_app.py --max-seconds`, default 540 s); interface tests are grouped in chunks (`UI_CHUNKS` in
  `scripts/release_check.py`), each test under 60 seconds; package tests run in under 10 seconds each.
- Simulators are chosen by runtime (`sim-27.2`, `sim-26.5`), never by a copied identifier.
- System accessibility audits run only in the device campaign (`VC_RUN_AUDITS=1`).
- Simulator results are development evidence, not device evidence.

**CI** ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs on pushes to `main` and on pull requests, on macOS
runners: the ledger, documentation, steering-document, planning-archive, planning-index, migration-ledger,
compliance, dependency, public-API, documented-API, license and script checks; `swift test` for
`Packages/VisualCore` and the harness package `GardenKit`; and an iOS Simulator build of the pure package. It runs no
rendering tests, because those need the locally built ANGLE frameworks. A second workflow
([.github/workflows/push-scan.yml](.github/workflows/push-scan.yml)) repeats the pre-push scan (device identifiers,
team ids, secrets) over the commits of every push and pull request; it is never cancelled by a newer push.

## Repository structure

| Path | Contents |
|---|---|
| `Apps/VisualCore/` | the single shippable app: launcher, routes, settings, about, onboarding, the experience registry (`App/ExperienceRegistry.swift`), unit tests (`Tests/Unit`) and interface tests per experience (`Tests/UI/<Experience>`) |
| `Apps/GenerativeArtStudio/`, `Apps/FluidArtPlayground/`, `Apps/FractalExplorer/` | resources kept from the former standalone apps; their sources now live in `Packages/ExperiencesCreative` |
| `Packages/VisualCore/` | pure Swift modules without GPU or UIKit code; tested on the macOS host |
| `Packages/VisualCoreRendering/` | iOS modules over ANGLE: render host, experience host, resources, shaders, effects, UI, audio, automation |
| `Packages/ExperiencesCreative/` | the creative experiences, one folder each with `Core`, `CoreTests`, `Experience`, `ExperienceTests` and a `scenario-manifest.json`: `GenerativeArtStudio`, `FluidArtPlayground`, `FractalExplorer`, `ParticleUniverse`, `InfiniteGeometry`, `VisualCoreMusicLab`, `AudioOdyssey`, `OscilloscopeStudio` |
| `Packages/ExperiencesRound02` … `Round04` | **planned** packages for the games (ADR-0009, D-06); none exists yet |
| `Showcase/` | developer Showcase app; not an App Store product |
| `Harnesses/` | non-shipping test hosts: `InteractiveDemo/`, `SecondConsumer/` (Lumen Garden, a small sample game), `ProjectMReference/` |
| `External/projectm-ios/` | pinned, read-only Git submodule: reference app, reference regression and source of the ANGLE build |
| `Catalog/` | runtime catalog generated by `scripts/build_catalog.py`: `experiences.json` (the 100 launch experiences), `categories.json`, `registrations.json`, `path-map.json` and the golden list of all 300 experience ids |
| `Configs/` | pinned tool versions (`toolchain.json`), the signing include (`Signing.xcconfig`), the copy-claim denylist, the permission vocabulary and the hashes of this Mac's simulator identifiers for the pre-push scan |
| `Tools/python/` | `desktop_runbook.py`, the legacy ledger tool |
| `scripts/` | deterministic Python checks and tools: release check, build and test runners, validators, ledgers, planning index, copy and release-document checks |
| `specs/` | 82 feature dossiers produced with Spec Kit (spec, plan, research, data model, contracts, checklists, tasks) |
| `docs/` | architecture, API baseline, decisions, catalog, migration, per-experience documents (`docs/apps/<slug>/`), release notes and limitations, legal notices, planning archive |
| `.autonomy/` | evidence ledgers: `state.json`, `evidence/` and `checks/` (legacy), `migration/` (unified app) |
| `.specify/`, `.claude/skills/` | Spec Kit configuration and constitution; the committed Spec Kit skills |
| `.github/workflows/` | `ci.yml` (checks, host tests, simulator build), `push-scan.yml` (scan of every pushed range) |

## Framework modules

From [Packages/VisualCore/Package.swift](Packages/VisualCore/Package.swift) and
[Packages/VisualCoreRendering/Package.swift](Packages/VisualCoreRendering/Package.swift):

- **`Packages/VisualCore`** (pure Swift): `VisualCoreMath`, `VisualCoreSimulation`, `VisualCoreScenes`,
  `VisualCoreShaderSource`, `VisualCoreEffectsGraph`, `VisualCoreDiagnostics`, `VisualCorePersistence`,
  `VisualCoreParameters`, `VisualCoreAudioDSP`, `VisualCoreExperience` (the experience contract, catalog identity,
  storage), `VisualCoreTestSupport` (for tests) and the executable `VisualCoreBaselines`.
- **`Packages/VisualCoreRendering`** (iOS): `CVisualCoreEGL`, `CVisualCoreGL`, `VisualCoreRendering`,
  `VisualCoreEffects`, `VisualCoreUI`, `VisualCoreAutomation`, `VisualCoreAudio` and `VisualCoreExperienceHost`.

Every public declaration is listed in the [public API baseline](docs/api/visualcore-public-api.txt) and documented
with `///`; `scripts/check_public_api.py` fails on any undocumented or unrecorded change.

## Development workflow

- The project is developed with **Claude Code in the Claude Desktop app** and **GitHub Spec Kit**. Every phase of every
  experience runs the full Spec Kit loop — specify, clarify, plan, checklist, tasks, analyze, implement and converge
  (repeated until nothing is appended) — before its gate is sealed and recorded.
- [CLAUDE.md](CLAUDE.md) is the bootstrap every session reads first; the continuation prompt is the last section of
  [Auto-Creator.md](Auto-Creator.md).
- Work happens on `main`; every task, skill and gate is committed and pushed after `python3 scripts/prepush_scan.py`
  passes. History is never rewritten.
- Shared, pure logic belongs in `Packages/VisualCore`; GPU and UIKit code in `Packages/VisualCoreRendering`; each
  experience's own logic in its folder under `Packages/ExperiencesCreative`.

## Documentation

| Document | Purpose |
|---|---|
| [Auto-Creator.md](Auto-Creator.md) | forward-looking design and steering document for the unified app |
| [setup.md](setup.md) | machine and contributor setup |
| [CLAUDE.md](CLAUDE.md) | bootstrap for Claude sessions: reading order, live-state commands, fixed rules |
| [docs/decisions/ADR-0009-unified-app.md](docs/decisions/ADR-0009-unified-app.md) | decision record for the single app; ADR-0001 to ADR-0008 and ADR-0010 (constitution 2.0.0) are in `docs/decisions/` |
| [docs/migration/migration-plan.md](docs/migration/migration-plan.md) | migration plan: path map, milestones, rollback |
| [docs/migration/pre-fable-baseline.md](docs/migration/pre-fable-baseline.md) | state of the repository before the consolidation |
| `docs/apps/<slug>/` | per experience: README, VisualCore contract, regression baseline and, after its release phase, privacy and credits, store-text input, release checklist and device-campaign plan |
| [docs/release/known-limitations.md](docs/release/known-limitations.md) | what is unmeasured or device-only, per experience |
| [docs/release/build-and-archive.md](docs/release/build-and-archive.md) | build and archive steps, with the owner-only steps |
| [docs/archive/planning/README.md](docs/archive/planning/README.md) | index of the original planning documents, archived unchanged |
| [docs/index.md](docs/index.md) | framework documentation index |
| [docs/getting-started.md](docs/getting-started.md) | using the framework: modules, a first scene, samples |
| [docs/api/visualcore-public-api.txt](docs/api/visualcore-public-api.txt) | public API baseline: every public declaration of both packages |

The former root README, the full specification of the earlier 25-app plan, is archived unchanged at
[docs/archive/planning/root/README-2026-11-10-full-specification.md](docs/archive/planning/root/README-2026-11-10-full-specification.md).

## Contributing

Issues and pull requests are welcome. Before opening a pull request:

1. Read [setup.md](setup.md) and run `python3 scripts/verify_environment.py`.
2. Follow the rules in [CLAUDE.md](CLAUDE.md) §3 (one app, visuals as code, no advertising, no network, public Apple
   APIs only, `External/projectm-ios` read-only).
3. Run the fast checks: `python3 scripts/release_check.py --only docs app-contracts compliance dependencies public-api
   licenses script-tests` and `swift test --package-path Packages/VisualCore`.
4. Use LF line endings and never commit `Configs/Signing.local.xcconfig`, `.autonomy/private`, logs or result bundles.

## Keeping this README current

This README is a living document. It is updated in the same commit as any change it describes — at the latest when a
gate is recorded that changes the Status table (an experience's X gate, a unified-app feature, a milestone), when a
package, module, top-level folder, workflow or tool version is added or removed, or when a documented command
changes. The status date at the top of [Status](#status) names the day of the last update; the ledgers remain the
source of truth.

## License

MIT License. The full text and the copyright notice are in [LICENSE](LICENSE).

Third-party components and their licenses are listed in
[docs/legal/THIRD_PARTY_NOTICES.md](docs/legal/THIRD_PARTY_NOTICES.md) and, in machine-readable form, in
[docs/legal/third-party.json](docs/legal/third-party.json). The notices list libprojectM (LGPL-2.1) as harness-only:
it is used by `Harnesses/ProjectMReference`, a tester tool that is not distributed; see
[docs/legal/lgpl-analysis.md](docs/legal/lgpl-analysis.md).
