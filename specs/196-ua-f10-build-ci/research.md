# Research: UA-F10

## 1. Read-only audit (2026-11-13)

- `project.yml`: application targets `Showcase`, `ParticleUniverse`, `VisualCore` (bundle `dev.visualcore.VisualCore`);
  test targets `ShowcaseTests`, `ShowcaseUITests`, `ParticleUniverseUITests`, `VisualCoreTests`, `VisualCoreUITests`;
  packages `VisualCore`, `VisualCoreRendering`, `ExperiencesCreative`; Debug and Release use `Configs/Signing.xcconfig`,
  which includes the gitignored local file when it exists.
- `Packages/VisualCoreRendering/Package.swift`: binary targets `libEGL` and `libGLESv2` at
  `../../External/projectm-ios/Build/ANGLEFrameworks/*.xcframework` (built locally, 18 MB, not in Git). The C target
  `CVisualCoreEGL` declares 15 EGL functions in `include/CVisualCoreEGL.h` (lines 71–87, two of them over two lines, from `eglGetPlatformDisplay`
  to `eglGetProcAddress`); GL is loaded at run time through `eglGetProcAddress` (`VCGLLoadFromEGL.c`), so only EGL
  symbols are linked. The local libEGL exports 115 symbols.
- `.github/workflows/ci.yml`: jobs `checks`, `host-tests`, `simulator-build` on `macos-latest`, each 30 min, one
  concurrency group per ref with cancel-in-progress. No app build.
- `scripts/check_dependencies.py`: rules R1–R5; no experience rule.
- `scripts/release_check.py`: `visualcore-app-build` (Debug simulator build), `app-visual-core-ios27/26` (whole
  scheme in one run, can exceed ten minutes), `experiences-creative-sim-ios27/26`, `release-symbols` (Showcase).
- `scripts/xcodebuild_app.py`: chunks, `--max-seconds`, method-level guard, `--action build-for-testing` /
  `test-without-building`, busy-simulator refusal (UA-F07).
- `scripts/check_release_symbols.py --app <app> --forbid <texts…>` exists (used by UA-F07 `release-symbols-r2`).
- `scripts/check_privacy_manifest.py --app <app>` exists.
- Catalog: `docs/catalog/experience-catalog.json` has 300 experiences with `code` (A01…, R02-G01…), `name`,
  `collection` (`original`, `round-02`, …). `Catalog/registrations.json` (schema 1) holds the registered
  experiences (A01–A04 today).
- `docs/performance/budgets.md` line 23 proposes the build-time and size record.
- GitHub: the repository is public; `macos-latest` jobs can wait in a queue for minutes (observed 2026-11-13).

## 2. Decisions

- **R1 CI stand-ins** (clarification 1). Decision: `make_ci_angle_standins.py` parses the prototypes of
  `CVisualCoreEGL.h`, writes a C file with each function calling `abort()`, plus `const char vc_ci_angle_standin[]`,
  compiles it for `arm64` and `x86_64` simulator slices, links a dynamic `libEGL.framework` and an empty
  `libGLESv2.framework`, and wraps each with `xcodebuild -create-xcframework` (simulator slice only; CI builds only
  for the simulator). In CI the read-only submodule is never initialized; the stand-ins are written into its empty
  folder (analysis D1). Alternatives: building ANGLE (hours, 12 GB), publishing frameworks (public repo), self-hosted
  runner (owner action). The tool refuses an output folder that already holds a framework without the marker.
- **R2 Target list** (clarification 2). `Configs/app-targets.json` lists each application target. A reason may name
  a ledger gate (`until_gate`); when that gate is pass, the check fails until the target is removed.
- **R3 Package validation.** Code prefix to package: `A` → `ExperiencesCreative`, `R02` → `ExperiencesRound02`,
  `R03` → `ExperiencesRound03`, `R04` → `ExperiencesRound04`. The directory and target prefix is the catalog name in
  upper camel case without spaces (`Generative Art Studio` → `GenerativeArtStudio`). Implemented means registered in
  `Catalog/registrations.json`. Targets are read from `Package.swift` text (`.target(name:` and `.testTarget(name:`),
  without running SwiftPM, so the check works on Linux and is fast.
- **R4 Dependency rules.** An experience module is a target of a `Packages/Experiences*` package; its owning experience
  is the target name minus `Core`, `CoreTests`, `Experience`, `ExperienceTests`. R6 import of another experience's
  module, R7 a target dependency on another experience's target in `Package.swift`, R8 an import of a ProjectM module
  (the existing `REFERENCE_MODULES`).
- **R5 Release-check steps.** `app-unit-ios27` (VisualCoreTests), `app-build-for-testing-ios27`, `app-ui-ios27-<chunk>`
  for the chunk table of UA-F07 minus the audit classes, `verify-<id>-ios27/26` per registered experience,
  `app-release-build`, `app-release-symbols` (forbids the debug texts and `vc_ci_angle_standin`),
  `app-privacy-manifest`, `measure-build`. Each step gets `--max-seconds` 540 or a step timeout of 590 s.
  Parallel clones: `xcodebuild_app.py --parallel N` adds `-parallel-testing-enabled YES
  -parallel-testing-worker-count N` (owner ruling); default 1.
- **R6 Measurement.** Clean build = `xcodebuild clean build` of the app in Debug for the generic simulator in a
  dedicated DerivedData; incremental = touch one file of `GenerativeArtStudioCore` and build again; size = bytes of
  the Release app bundle. Records append only; a commit already measured is skipped.

## 3. Absorbed sources

| Source requirement | Disposition | Reason |
|---|---|---|
| R02-F30 25 app schemes | superseded | one app (ADR-0009) |
| R02-F30 package tests | adopted | release-check steps |
| R02-F30 simulator test plans | adapted | chunks of `xcodebuild_app.py` |
| R02-F30 exact tool pins | adopted | `Configs/toolchain.json` |
| R02-F30 isolate signing | adopted | CI unsigned; local signing file gitignored |
| R03-F10/R04-F10 25-target CI | superseded | one app target |
| R03-F10/R04-F10 no vendor-fork rebuild | adopted | CI stand-ins, no ANGLE build |
| R03-F10/R04-F10 no signing corruption | adopted | target list check, CI unsigned |
| R03-F10/R04-F10 no duplicated framework files | adopted | one embedded copy of ANGLE, checked in the Release app |

## 4. Corrections during implementation

(none yet)
- 2026-11-13: the EGL header declares 15 functions, not 16 (two prototypes span two lines; counted by the stand-in
  tool and `nm -gU` of the generated libEGL). Tool tests live in `scripts/tests/test_<tool>.py`, collected by
  `scripts/test_scripts.py`, so parallel agents never write the same file (owner ruling of 2026-11-13).
  `check_app_targets.py` joins the reviewed readers of the migration ledger in the governance test.
- 2026-11-13, T-U10-004/005 (corrects analysis D1): the app's "Bundle licenses (UA-F04)" build phase copies the ANGLE
  license texts, which are tracked files of the reference submodule. The first local proof without the submodule
  compiled and linked every Swift and C target against the stand-ins and failed only in that phase. The CI job
  therefore checks the submodule out shallow and non-recursive, as the `checks` job already does. It writes the
  stand-ins into the submodule's gitignored `Build/` folder, where the real frameworks are built locally, and ends with
  `check_reference_clean.py`, which proves that no tracked file of the submodule changed. Locally the proof uses a copy
  of the tracked files under `Build/standin-check/` with the license texts taken by `git archive` from the
  submodule. Debug build-for-testing passes (`standin-local-build-r2`), and so does Release (`standin-local-release`).
- 2026-11-13, owner request "use caching in ci to speed things up": `actions/cache@v4` for the SwiftPM `.build`
  folders of the host tests, the DerivedData of the pure-package simulator build and of the app build (Debug and
  Release), the XcodeGen install and the generated ANGLE stand-ins. Each key holds the Xcode build and a hash of the
  sources it depends on, with a restore key of the same toolchain so a partial match gives an incremental build. The
  real ANGLE and ProjectM builds are not cached in CI: they are never built there (a 12 GB tree and hours of build), and
  publishing the locally built frameworks from a public repository is ruled out (clarification 1).
