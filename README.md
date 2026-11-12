# VisualCore

VisualCore is a reusable rendering framework for iOS and iPadOS apps. It draws with OpenGL ES 3.0 through EGL and
the repository owner's fork of ANGLE on its Metal backend. This repository contains the framework as two Swift
packages, a developer Showcase app, three test harnesses and four standalone creative apps built on the framework.

On 2026-11-11 the project was redirected from a plan of many separate apps and games to a single app, also named
VisualCore, in which the creative apps and the games are planned to become "experiences"
([ADR-0009](docs/decisions/ADR-0009-unified-app.md)). That app does not exist yet. This README states only what is
true in the repository today and labels everything else as planned.

## Status

State on 2026-11-11. Progress is recorded in two ledgers, not in prose; the commands below the table print the
live state. A phase is "sealed" when it has passed its host and simulator checks and its evidence file is recorded
in `.autonomy/evidence/`. Sealed does not mean device-verified.

| Component | State today | Evidence |
|---|---|---|
| Framework packages (version 1.0.0-rc.1) | simulator-verified: host tests and iOS Simulator tests | `.autonomy/evidence/F00.json` … `F09.json`; [release notes](docs/release/release-notes-1.0.0-rc.1.md) |
| Audio modules `VisualCoreAudioDSP` and `VisualCoreAudio` | placeholders; not implemented | [known limitations](docs/release/known-limitations.md) |
| Showcase app and the three harnesses | simulator-verified; development targets, not products | `.autonomy/evidence/F05.json` … `F08.json`; [Showcase/README.md](Showcase/README.md) |
| A01 Generative Art Studio | standalone app; all seven phases sealed; simulator-verified | `.autonomy/evidence/A01-P00.json` … `A01-P06.json` |
| A02 Fluid Art Playground | standalone app; all seven phases sealed; simulator-verified | `.autonomy/evidence/A02-P00.json` … `A02-P06.json` |
| A03 Fractal Explorer | standalone app; all seven phases sealed; simulator-verified | `.autonomy/evidence/A03-P00.json` … `A03-P06.json` |
| A04 Particle Universe | partial: four of seven phases sealed | `.autonomy/evidence/A04-P00.json` … `A04-P03.json` |
| A05–A25 | not started | no source; no gate passed in the legacy ledger |
| Games of Rounds 2–12 | planned; none exists in source | all 275 are `not-started` in the [catalog](docs/catalog/experience-catalog.json) |
| Unified VisualCore app | planned; the app target does not exist | [project.yml](project.yml) defines no such target |
| Physical-device testing | none has been run | every device gate is pending in both ledgers; [support matrix](docs/release/support-matrix.md) |
| App Store | no submission, no purchase code, nothing for sale | ADR-0009, open owner decisions OD-01, OD-02 and OD-06; no StoreKit code in source |

The legacy ledger records 35 of its 263 gates as passed: F00–F09 (framework) and A01-P00 … A04-P03 (app phases).
The evidence for all of them comes from the macOS host and the iOS Simulator.

```bash
python3 Tools/python/desktop_runbook.py status
python3 scripts/migration_ledger.py status
```

The first prints the legacy gates (framework and original-app phases), the second the unified-app gates.

## What the app will be

Planned. Nothing in this section exists in source yet. The decisions are recorded in
[ADR-0009](docs/decisions/ADR-0009-unified-app.md).

One App Store app named VisualCore, with one app target. Each creative app and each game becomes a registered
experience opened from one launcher. The first release is planned to contain exactly 100 experiences:

| Tier | Experiences | Count |
|---|---|---|
| Free forever | the 25 original creative apps (A01–A25) and the 25 Round 2 games (R02-G01 … R02-G25) | 50 |
| Premium | the games of Rounds 3 and 4 (R03-G01 … R04-G25) | 50 |

- **Price:** free download, plus one non-consumable in-app purchase of USD 1.99 that unlocks every premium
  experience, including premium experiences added later.
- **No advertising of any kind.** No tracking, no subscriptions and no account.
- **Order of work:** all 100 experiences are to be implemented and verified on the iOS Simulator before any
  physical-device campaign begins (gate `ImplementationLock-100`).
- **Catalog:** [docs/catalog/experience-catalog.json](docs/catalog/experience-catalog.json) lists all 300 planned
  experiences: the 100 above and a backlog of 200 from Rounds 5–12. It is a plan, not evidence of implementation.
- **Plan and gates:** [docs/migration/migration-plan.md](docs/migration/migration-plan.md) and the gate ledger
  `.autonomy/migration/ledger.json` (1,233 gates). `python3 scripts/migration_ledger.py status` shows which gates
  have passed; this file does not track that.

The name "VisualCore" has not been checked for App Store availability, and the bundle identifier is a placeholder.

## How it renders

```text
RenderScene (OpenGL ES 3.0 calls) -> EGL -> ANGLE (libEGL, libGLESv2) -> Metal -> GPU
```

A scene implements `RenderScene` and issues OpenGL ES 3.0 calls. `RenderHost` owns the EGL context and a window
surface on the view's `CAMetalLayer`, runs frames from a `CADisplayLink` on the main thread and presents them with
`eglSwapBuffers`. EGL and OpenGL ES come from prebuilt `libEGL` and `libGLESv2` frameworks of the ANGLE fork (Metal
backend); they are built with the scripts of the pinned submodule `External/projectm-ios` and are not committed.
This is the only renderer: there is no direct Metal renderer, and `scripts/check_compliance.py` rejects one.

Visuals are code by decision (ADR-0009, D-09): GLSL shaders, procedural meshes, signed-distance fields, particles
and deterministic animation. Under that rule no hand-made models, purchased art packs, generated images or external
image services are required, and a seeded random generator with a fixed-step clock (`VisualCoreSimulation`) makes a
simulation repeatable in automated tests. More: [architecture](docs/architecture/visualcore-architecture.md) and
the [reference pipeline](docs/architecture/current-rendering-pipeline.md) that `RenderHost` re-implements.

## Repository map

| Path | Contents |
|---|---|
| `Packages/VisualCore/` | pure Swift modules without GPU or UIKit code; tested on the macOS host |
| `Packages/VisualCoreRendering/` | iOS modules over ANGLE: render host, resources, shaders, effects, UI, automation |
| `Showcase/` | developer Showcase app; not an App Store product |
| `Apps/` | four standalone creative apps: `GenerativeArtStudio/` (A01), `FluidArtPlayground/` (A02), `FractalExplorer/` (A03), `ParticleUniverse/` (A04) |
| `Apps/VisualCore/` | **planned**: the single app target; does not exist yet |
| `Packages/Experiences*/` | **planned**: one package per collection of experiences (`ExperiencesCreative`, `ExperiencesRound02`, `ExperiencesRound03`, `ExperiencesRound04`; ADR-0009, D-06); none exists yet |
| `Harnesses/` | non-shipping test hosts: `InteractiveDemo/`, `SecondConsumer/` (Lumen Garden, a small sample game), `ProjectMReference/` |
| `External/projectm-ios/` | pinned, read-only Git submodule: reference app, reference regression and source of the ANGLE build |
| `Catalog/` | runtime catalog of the planned app, generated by `scripts/build_catalog.py`: `experiences.json` (the 100 launch experiences; none is available yet), `categories.json`, `registrations.json`, `path-map.json` and the golden list of all 300 experience ids |
| `Configs/` | pinned tool versions (`toolchain.json`), the signing include (`Signing.xcconfig`) and the hashes of this Mac's simulator identifiers for the pre-push scan |
| `Tools/python/` | `desktop_runbook.py`, the legacy ledger tool |
| `scripts/` | deterministic Python checks and tools: release check, validators, ledgers, planning index |
| `specs/` | 35 feature dossiers, `001` to `035`, produced with Spec Kit |
| `docs/` | architecture, API baseline, decisions, catalog, migration, release notes, legal notices, planning archive |
| `.autonomy/` | evidence ledgers: `state.json`, `evidence/` and `checks/` (legacy), `migration/ledger.json` (unified app) |
| `.specify/`, `.claude/skills/` | Spec Kit configuration and constitution; the committed Spec Kit skills |
| `.github/workflows/` | `ci.yml` (checks, host tests, simulator build), `push-scan.yml` (scan of every pushed range) |

`project.yml` is the XcodeGen specification for the Showcase and the four apps. Xcode projects and build output are
generated locally and are not committed.

Framework modules, from the manifests [Packages/VisualCore/Package.swift](Packages/VisualCore/Package.swift) and
[Packages/VisualCoreRendering/Package.swift](Packages/VisualCoreRendering/Package.swift):

- `Packages/VisualCore`: `VisualCoreMath`, `VisualCoreSimulation`, `VisualCoreScenes`, `VisualCoreShaderSource`,
  `VisualCoreEffectsGraph`, `VisualCoreDiagnostics`, `VisualCorePersistence`, `VisualCoreParameters`,
  `VisualCoreAudioDSP` (placeholder), `VisualCoreTestSupport` (for tests) and the executable `VisualCoreBaselines`.
- `Packages/VisualCoreRendering`: `CVisualCoreEGL`, `CVisualCoreGL`, `VisualCoreRendering`, `VisualCoreEffects`,
  `VisualCoreUI`, `VisualCoreAutomation` and `VisualCoreAudio` (placeholder).

## Build and test

Toolchain as recorded in [Configs/toolchain.json](Configs/toolchain.json): Xcode 27.2 (build 27B52), iOS SDK 27.2,
Swift 6.4.2, XcodeGen 2.46.0, CMake 4.4.5, Python 3.10 or later, and the simulator runtimes iOS 26.5 and iOS 27.2.
The commands below are the host tests and the fast checks from [setup.md](setup.md) and
[docs/getting-started.md](docs/getting-started.md).

```bash
git submodule update --init External/projectm-ios
python3 scripts/verify_environment.py
swift test --package-path Packages/VisualCore
python3 scripts/release_check.py --list
python3 scripts/release_check.py --only docs app-contracts compliance dependencies public-api licenses script-tests host-visualcore host-particle-universe-core
```

In order: fetch the reference submodule (do not use `--recursive` at the top level); compare the installed tools
with `Configs/toolchain.json`; run the host tests of the pure package; list every release check with its exact
command; run the fast checks.

Rendering tests, the Showcase, the harnesses and the apps also need the ANGLE frameworks built from the submodule,
Xcode projects generated with XcodeGen and an iOS simulator; [setup.md](setup.md) is the full guide. Simulator
results are development evidence, not device evidence.

CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs on pushes to `main` and on pull requests, on macOS
runners: the ledger, documentation, steering-document, planning-archive, planning-index, migration-ledger,
compliance, dependency, public-API, documented-API, license and script checks; `swift test` for
`Packages/VisualCore` and the harness package `GardenKit`; and an iOS Simulator build of the pure package. It runs
no rendering tests, because those need the locally built ANGLE frameworks. A second workflow
([.github/workflows/push-scan.yml](.github/workflows/push-scan.yml)) repeats the pre-push scan over the commits of
every push and pull request; it is never cancelled by a newer push.

## Documentation

| Document | Purpose |
|---|---|
| [Auto-Creator.md](Auto-Creator.md) | forward-looking design and steering document for the unified app |
| [setup.md](setup.md) | machine and contributor setup |
| [CLAUDE.md](CLAUDE.md) | bootstrap for Claude sessions: reading order, live-state commands, fixed rules |
| [docs/decisions/ADR-0009-unified-app.md](docs/decisions/ADR-0009-unified-app.md) | decision record for the single app; ADR-0001 to ADR-0008 and ADR-0010 (constitution 2.0.0) are in `docs/decisions/` |
| [docs/migration/migration-plan.md](docs/migration/migration-plan.md) | migration plan: path map, milestones, rollback |
| [docs/migration/pre-fable-baseline.md](docs/migration/pre-fable-baseline.md) | state of the repository before the consolidation |
| [docs/archive/planning/README.md](docs/archive/planning/README.md) | index of the original planning documents, archived unchanged |
| [docs/index.md](docs/index.md) | framework documentation index |
| [docs/getting-started.md](docs/getting-started.md) | using the framework: modules, a first scene, samples |
| [docs/api/visualcore-public-api.txt](docs/api/visualcore-public-api.txt) | public API baseline: every public declaration of both packages |

The former root README, the full specification of the earlier 25-app plan, is archived unchanged at
[docs/archive/planning/root/README-2026-11-10-full-specification.md](docs/archive/planning/root/README-2026-11-10-full-specification.md).

## Working with Claude

- The project is developed with Claude Code in the Claude Desktop app and with GitHub Spec Kit.
- [CLAUDE.md](CLAUDE.md) is the bootstrap that every session reads first.
- The continuation prompt for a new session is the last section of [Auto-Creator.md](Auto-Creator.md).

## License

MIT License. The full text and the copyright notice are in [LICENSE](LICENSE).

Third-party components and their licenses are listed in
[docs/legal/THIRD_PARTY_NOTICES.md](docs/legal/THIRD_PARTY_NOTICES.md) and, in machine-readable form, in
[docs/legal/third-party.json](docs/legal/third-party.json). The notices list libprojectM (LGPL-2.1) as harness-only:
it is used by `Harnesses/ProjectMReference`, a tester tool that is not distributed; see
[docs/legal/lgpl-analysis.md](docs/legal/lgpl-analysis.md).
