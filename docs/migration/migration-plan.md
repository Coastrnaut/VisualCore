# Migration plan: from four standalone apps to one VisualCore app

**Status:** plan, written 2026-11-11 at milestone M0. Nothing in this document has been executed except the
consolidation itself. The decisions are in [ADR-0009](../decisions/ADR-0009-unified-app.md); the design is in
[`Auto-Creator.md`](../../Auto-Creator.md) (sections 16 to 18); the gates are in `.autonomy/migration/ledger.json`.
The starting point is recorded in [`pre-fable-baseline.md`](pre-fable-baseline.md).

## 1. What migrates and what does not

| Item | Today | After the migration |
|---|---|---|
| Framework packages `Packages/VisualCore`, `Packages/VisualCoreRendering` | exist, sealed by F00–F09 | retained; five modules are added, none is renamed or removed |
| Standalone apps A01–A04 | four app targets with their own Core packages | experiences in `Packages/ExperiencesCreative`, shown by the one app; the targets are retired |
| A05–A25 | not started | built directly as experiences; no standalone target is ever created |
| Games of Rounds 2–4 | not started | experiences in `Packages/ExperiencesRound02` … `04` |
| `Showcase`, harnesses, `External/projectm-ios` | exist | retained unchanged, non-shipping |
| Legacy ledger, dossiers `specs/001`–`035`, ADR-0001 … 0008, evidence | exist | retained unchanged as records |
| Planning documents | archived under `docs/archive/planning/` | retained unchanged |

**Packages retained:** `VisualCore` and `VisualCoreRendering` (extended), `GardenKit` inside the SecondConsumer
harness. **Packages dissolved:** the four per-app Core packages, whose targets move into the collection package
with their names (`GenerativeArtStudioCore`, …) and tests unchanged. **Packages added:** four experience
packages and, inside the framework packages, the modules `VisualCoreExperience`, `VisualCoreGeometry`,
`VisualCorePuzzle`, `VisualCoreExperienceHost`, `VisualCoreStore`.

## 2. Path map

The machine-readable form is [`path-map.json`](path-map.json) (63 directory-level entries). Every
"from" path is tracked and exists today; generated, untracked output such as `Apps/<Name>/Generated` is not listed. "To" paths are proposals that the named feature confirms; a move happens with `git mv`
only after parity is proven (section 4), and each executed move is recorded file by file in `Catalog/path-map.json`.

### 2.1 The four existing apps

**A01 Generative Art Studio**

| From (exists today) | To | Action | By | Note |
|---|---|---|---|---|
| `Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore` | `Packages/ExperiencesCreative/GenerativeArtStudio/Core` | move | UA-F07 | Pure domain target GenerativeArtStudioCore; tests must pass unchanged before and after the move. |
| `Apps/GenerativeArtStudio/Core/Tests/GenerativeArtStudioCoreTests` | `Packages/ExperiencesCreative/GenerativeArtStudio/CoreTests` | move | UA-F07 | Host tests and fixtures of the Core target; fixtures stay bit-identical. |
| `Apps/GenerativeArtStudio/Core/Package.swift` | `Packages/ExperiencesCreative/Package.swift` | merge | UA-F07 | The per-app package manifest is replaced by targets in the collection package. |
| `Apps/GenerativeArtStudio/App` | `Packages/ExperiencesCreative/GenerativeArtStudio/Experience` | move | UA-F07 | SwiftUI and scene sources become target GenerativeArtStudioExperience; the @main type GenerativeArtStudioApp.swift is replaced by the experience factory and is retired. |
| `Apps/GenerativeArtStudio/Shaders` | `Packages/ExperiencesCreative/GenerativeArtStudio/Shaders` | move | UA-F07 | GLSL sources become resources of the Experience target. |
| `Apps/GenerativeArtStudio/Tests/Unit` | `Packages/ExperiencesCreative/GenerativeArtStudio/ExperienceTests` | move | UA-F07 | Unit tests that need UIKit or the render host. |
| `Apps/GenerativeArtStudio/Tests/UI` | `Apps/VisualCore/Tests/UI/GenerativeArtStudio` | move | UA-F07 | UI tests are ported to the unified app; a mapping table and the enumeration guard prove none is lost. |
| `Apps/GenerativeArtStudio/Resources/PrivacyInfo.xcprivacy` | `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` | merge | UA-F11 | One privacy manifest for the app, audited against the built product. |
| `Apps/GenerativeArtStudio/Resources/Assets.xcassets` | — | retire | UA-F07 | Icon and accent of the standalone app; the unified app has one generated icon. |

**A02 Fluid Art Playground**

| From (exists today) | To | Action | By | Note |
|---|---|---|---|---|
| `Apps/FluidArtPlayground/FluidArtPlaygroundCore/Sources/FluidArtPlaygroundCore` | `Packages/ExperiencesCreative/FluidArtPlayground/Core` | move | UA-F07 | Pure domain target FluidArtPlaygroundCore; tests must pass unchanged before and after the move. |
| `Apps/FluidArtPlayground/FluidArtPlaygroundCore/Tests/FluidArtPlaygroundCoreTests` | `Packages/ExperiencesCreative/FluidArtPlayground/CoreTests` | move | UA-F07 | Host tests and fixtures of the Core target; fixtures stay bit-identical. |
| `Apps/FluidArtPlayground/FluidArtPlaygroundCore/Package.swift` | `Packages/ExperiencesCreative/Package.swift` | merge | UA-F07 | The per-app package manifest is replaced by targets in the collection package. |
| `Apps/FluidArtPlayground/App` | `Packages/ExperiencesCreative/FluidArtPlayground/Experience` | move | UA-F07 | SwiftUI and scene sources become target FluidArtPlaygroundExperience; the @main type FluidArtPlaygroundApp.swift is replaced by the experience factory and is retired. |
| `Apps/FluidArtPlayground/Tests/Unit` | `Packages/ExperiencesCreative/FluidArtPlayground/ExperienceTests` | move | UA-F07 | Unit tests that need UIKit or the render host. |
| `Apps/FluidArtPlayground/Tests/UI` | `Apps/VisualCore/Tests/UI/FluidArtPlayground` | move | UA-F07 | UI tests are ported to the unified app; a mapping table and the enumeration guard prove none is lost. |
| `Apps/FluidArtPlayground/Resources/PrivacyInfo.xcprivacy` | `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` | merge | UA-F11 | One privacy manifest for the app, audited against the built product. |
| `Apps/FluidArtPlayground/Resources/Assets.xcassets` | — | retire | UA-F07 | Icon and accent of the standalone app; the unified app has one generated icon. |

**A03 Fractal Explorer**

| From (exists today) | To | Action | By | Note |
|---|---|---|---|---|
| `Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore` | `Packages/ExperiencesCreative/FractalExplorer/Core` | move | UA-F07 | Pure domain target FractalExplorerCore; tests must pass unchanged before and after the move. |
| `Apps/FractalExplorer/FractalExplorerCore/Tests/FractalExplorerCoreTests` | `Packages/ExperiencesCreative/FractalExplorer/CoreTests` | move | UA-F07 | Host tests and fixtures of the Core target; fixtures stay bit-identical. |
| `Apps/FractalExplorer/FractalExplorerCore/Package.swift` | `Packages/ExperiencesCreative/Package.swift` | merge | UA-F07 | The per-app package manifest is replaced by targets in the collection package. |
| `Apps/FractalExplorer/App` | `Packages/ExperiencesCreative/FractalExplorer/Experience` | move | UA-F07 | SwiftUI and scene sources become target FractalExplorerExperience; the @main type FractalExplorerApp.swift is replaced by the experience factory and is retired. |
| `Apps/FractalExplorer/Tests/Unit` | `Packages/ExperiencesCreative/FractalExplorer/ExperienceTests` | move | UA-F07 | Unit tests that need UIKit or the render host. |
| `Apps/FractalExplorer/Tests/Fixtures` | `Packages/ExperiencesCreative/FractalExplorer/ExperienceTests/Fixtures` | move | UA-F07 | Test fixtures; stay bit-identical. |
| `Apps/FractalExplorer/Tests/UI` | `Apps/VisualCore/Tests/UI/FractalExplorer` | move | UA-F07 | UI tests are ported to the unified app; a mapping table and the enumeration guard prove none is lost. |
| `Apps/FractalExplorer/Resources/PrivacyInfo.xcprivacy` | `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` | merge | UA-F11 | One privacy manifest for the app, audited against the built product. |
| `Apps/FractalExplorer/Resources/Assets.xcassets` | — | retire | UA-F07 | Icon and accent of the standalone app; the unified app has one generated icon. |

**A04 Particle Universe**

| From (exists today) | To | Action | By | Note |
|---|---|---|---|---|
| `Apps/ParticleUniverse/ParticleUniverseCore/Sources/ParticleUniverseCore` | `Packages/ExperiencesCreative/ParticleUniverse/Core` | move | UA-F07 | Pure domain target ParticleUniverseCore; tests must pass unchanged before and after the move. |
| `Apps/ParticleUniverse/ParticleUniverseCore/Tests/ParticleUniverseCoreTests` | `Packages/ExperiencesCreative/ParticleUniverse/CoreTests` | move | UA-F07 | Host tests and fixtures of the Core target; fixtures stay bit-identical. |
| `Apps/ParticleUniverse/ParticleUniverseCore/Package.swift` | `Packages/ExperiencesCreative/Package.swift` | merge | UA-F07 | The per-app package manifest is replaced by targets in the collection package. |
| `Apps/ParticleUniverse/App` | `Packages/ExperiencesCreative/ParticleUniverse/Experience` | move | UA-F07 | SwiftUI and scene sources become target ParticleUniverseExperience; the @main type ParticleUniverseApp.swift is replaced by the experience factory and is retired. |
| `Apps/ParticleUniverse/Tests/UI` | `Apps/VisualCore/Tests/UI/ParticleUniverse` | move | UA-F07 | UI tests are ported to the unified app; a mapping table and the enumeration guard prove none is lost. |

### 2.2 Retained and modified

| From (exists today) | To | Action | By | Note |
|---|---|---|---|---|
| `Packages/VisualCore` | `Packages/VisualCore` | modify | UA-F01, UA-F02, R02-F05, R02-F23 | Adds the pure modules VisualCoreExperience, VisualCoreGeometry and VisualCorePuzzle; existing modules keep their names and API. |
| `Packages/VisualCoreRendering` | `Packages/VisualCoreRendering` | modify | UA-F02, UA-F03, UA-F08 | Adds VisualCoreExperienceHost and VisualCoreStore; existing modules keep their names and API. |
| `project.yml` | `project.yml` | modify | UA-F04, UA-F07, UA-F10 | Gains the application target VisualCore; loses each standalone app target after its experience is verified. |
| `Showcase` | `Showcase` | keep | - | Non-shipping framework showcase. |
| `Harnesses/InteractiveDemo` | `Harnesses/InteractiveDemo` | keep | - | Non-shipping harness. |
| `Harnesses/SecondConsumer` | `Harnesses/SecondConsumer` | keep | - | Non-shipping harness (Lumen Garden) with GardenKit. |
| `Harnesses/ProjectMReference` | `Harnesses/ProjectMReference` | keep | - | The only target that touches the ProjectM reference (rule R1). |
| `External/projectm-ios` | `External/projectm-ios` | keep | - | Pinned read-only submodule (ADR-0005). |
| `Configs` | `Configs` | keep | - | toolchain.json and Signing.xcconfig; Signing.local.xcconfig is owner-created and never committed. |
| `Tools/python/desktop_runbook.py` | `Tools/python/desktop_runbook.py` | keep | - | Legacy ledger tool; reads the archived specification. |
| `scripts` | `scripts` | modify | UA-F00, UA-F01, UA-F09, UA-F13 | Adds build_catalog.py, verify_experiences.py, run_device_campaign.py; existing checks are extended, not replaced. |
| `specs` | `specs` | modify | every feature | 001-035 are records and are never rewritten; new dossiers follow the numbering of ADR-0009 D-11. |
| `.autonomy/state.json` | `.autonomy/state.json` | keep | - | Legacy ledger; never reset. |
| `.autonomy/evidence` | `.autonomy/evidence` | keep | - | Sealed legacy evidence. |
| `.autonomy/checks` | `.autonomy/checks` | keep | - | Legacy attestations. |
| `.autonomy/migration` | `.autonomy/migration` | modify | every gate | Migration ledger, its evidence and attestations. |
| `.specify` | `.specify` | modify | CONSTITUTION-2 | Constitution amended to 2.0.0; templates and scripts unchanged. |
| `.github/workflows/ci.yml` | `.github/workflows/ci.yml` | modify | UA-F00, UA-F10 | Adds the steering validators and the unified app's simulator build. |
| `docs/archive/planning` | `docs/archive/planning` | keep | - | Byte-identical originals; never edited. |
| `docs/apps` | `docs/apps` | keep | - | Regression baselines and release dossiers of the standalone apps: history; store listings are superseded. |
| `docs/release` | `docs/release` | keep | - | Framework 1.0.0-rc.1 records; the unified app's release material is added by UA-F14. |

### 2.3 New

| From (exists today) | To | Action | By | Note |
|---|---|---|---|---|
| — | `Apps/VisualCore` | new | UA-F04 | The only shippable target: App/, Resources/, Tests/Unit, Tests/UI. |
| — | `Catalog` | new | UA-F01 | Runtime manifest experiences.json, categories.json and path-map.json. |
| — | `Packages/ExperiencesCreative` | new | UA-F07 | A01-A25, one directory per experience with Core, Experience, Shaders and tests. |
| — | `Packages/ExperiencesRound02` | new | UA-F10 | R02-G01 … R02-G25. |
| — | `Packages/ExperiencesRound03` | new | UA-F10 | R03-G01 … R03-G25. |
| — | `Packages/ExperiencesRound04` | new | UA-F10 | R04-G01 … R04-G25. |
| — | `scripts/build_catalog.py` | new | UA-F01 | Derives the runtime manifest from the planning catalog. |
| — | `scripts/verify_experiences.py` | new | UA-F09 | Verification runner and lock driver. |
| — | `scripts/run_device_campaign.py` | new | UA-F13 | Noninteractive device campaign. |
| — | `docs/verification/implementation-lock-100.json` | new | UA-F12 | Lock manifest. |
| — | `docs/decisions/ADR-0010-constitution-2-0-0.md` | new | CONSTITUTION-2 | Records the constitution amendment. |

### 2.4 Layout of an experience

```
Packages/ExperiencesCreative/
├── Package.swift                      targets generated or validated from the catalog
└── GenerativeArtStudio/
    ├── Core/                          target GenerativeArtStudioCore (pure, host-testable)
    ├── CoreTests/                     its tests and fixtures
    ├── Experience/                    target GenerativeArtStudioExperience (SwiftUI, scenes, adapter)
    ├── Shaders/                       GLSL resources of the Experience target
    └── ExperienceTests/               tests that need UIKit or the render host
Apps/VisualCore/Tests/UI/GenerativeArtStudio/   UI tests of the experience in the app
```

Games use the same layout in their round's package. Module granularity (two targets per experience, one package
per collection) is a starting point; a change needs a measurement of build time and size and an ADR.

## 3. Milestone graph

```
M0 Consolidation ──► M1 Governance ──► M2 Walking skeleton ──► M3 Adoption (A01–A04)
                                                                    │
                    ┌───────────────────────────────────────────────┘
                    ▼
        M4 Creative library (A04-P04 … A25-P06, X-A04 … X-A25)
                    │                         ┐
                    ▼                         │ free library
        M5 Round 2 (24 shared features, 25 games)
                    │                         ┘
                    ▼
              LOCK-FREE-50 ──► M6 Purchase (UA-F08) ──► M7 Premium library (Rounds 3, 4)
                                                              │
                                                              ▼
                                                      LOCK-PREMIUM-50
                                                              │
                                                              ▼
                                      M8 UA-F13 ──► ImplementationLock-100
                                                              │
                                                              ▼
                               M9 Devices: D1 ──► D2 ──► D3 ──► DEVICE-RECONCILE-100
                                                              │
                                                              ▼
                                M10 Release preparation (owner-gated) ──► M11 Rounds 5–12
```

| Milestone | Gates (migration ledger unless noted) | Evidence of exit |
|---|---|---|
| M0 | `M0-CONSOLIDATION` | validators pass; archive and baseline verified |
| M1 | `CONSTITUTION-2`, `UA-F00` | constitution 2.0.0, ADR-0010, tooling tests |
| M2 | `UA-F01` … `UA-F06`, `UA-F09` … `UA-F12` | the app builds; one experience passes the nine scenarios on both runtimes |
| M3 | `UA-F07`, `X-A01`, `X-A02`, `X-A03` | parity of fixtures and UI tests; standalone targets retired |
| M4 | legacy `A04-P04` … `A25-P06`; `X-A04` … `X-A25` | each creative experience verified in the app |
| M5 | `R02-F02` … (24 gates), 250 game features, `X-R02-G01` … `G25`, `LOCK-FREE-50` | independent rerun of the 50 free experiences |
| M6 | `UA-F08` | StoreKit tests; Release binary free of fixture and ad symbols |
| M7 | Round 3 and 4 shared and game features, `X-R03-G01` … `X-R04-G25`, `LOCK-PREMIUM-50` | independent rerun of the 50 premium experiences |
| M8 | `UA-F13`, `ImplementationLock-100` | lock manifest for one commit |
| M9 | 300 device rows, three campaign gates, `DEVICE-RECONCILE-100` | signed runs on D1, D2, D3 |
| M10 | `UA-F14`, `RELEASE-PREP` | release candidate artifacts; owner checklist |
| M11+ | `add-round --round N` | per-round lock and device rows |

## 4. Procedure for adopting one existing app

1. Adapter in place: implement the experience over the existing scene and model types without moving a file.
2. Conformance and session-host tests pass; the Core package's tests pass unchanged; fixtures and checksums are
   bit-identical (A01 replay and baselines, A02 and A03 fixtures, A04 `replay-v1.json`).
3. UI tests ported, with a table of old and new names; `scripts/check_test_enumeration.py` proves none was lost.
4. Verification runner passes for the experience on the iOS 27.x and iOS 26.5 simulators.
5. `git mv` along the path map; steps 2 to 4 again.
6. The standalone target is removed from `project.yml`; the project is regenerated; the app and the remaining
   targets build.
7. The integration gate is recorded.

## 5. Rollback by phase

| Phase | If it goes wrong | Why this is safe |
|---|---|---|
| M0 | `git revert` the consolidation commits, or check out `main` | `main` is untouched; the baseline manifest and the outside `git bundle` reproduce the starting state exactly |
| M1 | revert the constitution commit | the amendment is one commit with its own ADR |
| M2 | revert the feature's commits | new modules and the new target do not change existing targets |
| M3, step 1–4 | remove the adapter | the standalone app is still intact and buildable |
| M3, step 5–6 | `git revert` the move and the target removal | moves are pure renames; history follows |
| M4–M7 | revert the experience's commits | experiences never depend on each other |
| After a lock | repair, re-verify, re-lock | every lock revision keeps its evidence |
| Devices | a failed row is recorded and rerun | failed attempts are never overwritten |

History is never rewritten and nothing is force-pushed. A rollback never touches the ledgers' recorded gates: a
gate whose code was reverted is verified again and recorded as a new revision, or blocked with the reason.

## 6. Risks

| # | Risk | Effect | Mitigation | Watched by |
|---|---|---|---|---|
| 1 | One binary with 100 experiences builds slowly and grows large | slow iteration, large download | two targets per experience so pure cores build and test on the host; build time and size recorded at every milestone; granularity changes by ADR | UA-F10 |
| 2 | GPU resources leak between experiences | memory growth, crashes after many launches | one session at a time; registry must report zero live and leaked objects on exit; 50-cycle test | UA-F03, scenario `teardown-reentry` |
| 3 | Shader compilation makes opening an experience slow | poor first impression | compile during preparation; time stages separately; warm caches | UA-F06 |
| 4 | Behavior of A01–A04 changes while moving | regression of sealed work | adapters first; bit-identical fixtures; UI test mapping; move only after parity | UA-F07 |
| 5 | Archived prompts still say "separate app", "$2.99", "after the device campaign" | wrong targets or early device work | canonical overrides printed with every prompt; ledger dependencies; device guard | section 21 of Auto-Creator.md, `guard-device` |
| 6 | Entitlement mistakes | premium content free, or buyers locked out | no stored flag; gating at routing and activation; `SKTestSession` for every state; Release symbol scan | UA-F08 |
| 7 | Simulator passes hide device problems | late failures on D3 | quality tiers from the start; device-only items tracked as tasks; repairs with re-lock | UA-F06, section 23 |
| 8 | Volume: 750 game features and 147 remaining app phases | fatigue, shortcuts, placeholders | one gate at a time from sealed evidence; no-placeholder audits; locks rerun independently | UA-F09, UA-F12 |
| 9 | Two games turn out to share a mechanic | weak library, review risk | distinctiveness matrix before the lock | UA-F11 |
| 10 | Constitution 1.5.0 contradicts the single app | checks reject valid work | amendment to 2.0.0 is the first gate | `CONSTITUTION-2` |
| 11 | The legacy tool and the new tool disagree about an original app | double or missing records | legacy ledger stays the only record of app phases; `X-A<nn>` requires its seven gates; `migration_ledger.py validate` checks the link | UA-F00 |
| 12 | Owner-only prerequisites are missing when devices start | campaign cannot begin | recorded as `BLOCKED_OWNER_ACTION` with exact steps; simulator work never depends on them | section 24.3 |
| 13 | Name or bundle identifier changes late | rework of identifiers | placeholders isolated in `project.yml` and the StoreKit configuration; experience ids do not contain the bundle identifier | OD-01, OD-02 |
| 14 | The supplemental candidates of Rounds 11 and 12 have provisional scores | wrong order of late backlog | re-score before those rounds start | section 10 |

## 7. What this plan does not do

It does not move any source file, change any target or run any test by itself. Each step happens inside a Spec Kit
feature with its own evidence. It does not authorize signing changes, device work before the lock, purchases or
submission.
