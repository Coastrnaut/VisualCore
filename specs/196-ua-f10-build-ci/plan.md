# Implementation Plan: UA-F10 — Build, project and CI consolidation

**Branch**: `196-ua-f10-build-ci` (spec directory; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Make every push prove that the one app compiles, and make the project's structure checkable. CI gets an app-build
job that compiles the app (Debug with its test bundles, and Release) for the simulator against link-only stand-in
ANGLE frameworks generated in CI (clarification 1). A tracked target list makes "one shippable app" checkable
(clarification 2). A package validator compares the experience packages with the catalog and the registrations.
`check_dependencies.py` gains rules for experiences. The release check gets unified-app steps that each fit in ten
minutes and run no accessibility audit. A measurement tool records build times and app size at milestones. No
framework (VisualCore) source changes; no public API changes.

## Technical Context

**Language/Version**: Python 3 (standard library only) for tools; YAML for GitHub Actions; C for the CI-generated
stand-ins; Swift 6.4.2 / Xcode 27.2 (build 27B52), XcodeGen 2.46.0 (`Configs/toolchain.json`).
**Primary Dependencies**: none new. GitHub-hosted `macos-latest` runners; `xcodebuild`, `xcodegen`, `clang`,
`lipo`, `xcodebuild -create-xcframework`.
**Storage**: tracked JSON files `Configs/app-targets.json` (schema 1) and `docs/performance/build-measurements.json`
(schema 1).
**Testing**: `scripts/test_scripts.py` (host, every new tool with planted defects); release-check steps; one real CI
run of a clean commit and one of a planted Release-only break on a scratch commit that is reverted.
**Target Platform**: macOS host and CI; the app targets iOS 26.0+ simulators.
**Project Type**: build tooling for the existing iOS app.
**Performance Goals**: every unified-app release-check step limited below 600 s; the CI app-build job under 30 min.
**Constraints**: nothing signed in CI; no ANGLE build or binary publication; public repository; tests short.
**Scale/Scope**: 4 experiences now, 100 at launch; 4 experience packages.

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Proven renderer only | The stand-ins are link-only, generated in the CI workspace, abort if called and are never run, committed or shipped; a marker symbol makes any leak detectable (`check_release_symbols.py --forbid`). The app still uses only the ANGLE path. | pass |
| II. App-neutral public API | No framework API change. | pass |
| III. GPU lifecycle and threads | Not touched. | n/a |
| IV. Host-testable logic, test first | Each tool gets script tests with planted defects before it is wired into CI. | pass |
| V. Implementation before devices | No device action. | pass |
| VI. Evidence over assertion | Each check is recorded with `run-check`; CI is confirmed by a real run, never assumed. | pass |
| VII. Native, accessible UI | Not touched; audits deferred by owner ruling, tests kept. | pass |
| VIII. Public APIs, privacy | No app code change; privacy manifest checked on the Release build. | pass |
| IX. Bounded untrusted input | The tools refuse damaged or newer-schema JSON with a message. | pass |
| X. Licensing and provenance | The stand-ins are generated from the tracked headers (MIT/Khronos-derived declarations already in the repo); nothing third-party is added. | pass |
| XI. One app, stable identity | Enforced by the target list check. | pass |
| XII. One purchase, no advertising | Not touched; compliance check stays in CI. | pass |
| XIII. Code-driven visuals | Not touched. | pass |

Re-checked after design: unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/196-ua-f10-build-ci/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/tools.md
├── checklists/requirements.md
└── tasks.md            (/speckit-tasks)
```

### Source Code (repository root)

```text
.github/workflows/ci.yml                 modify   + job app-build (stand-ins, xcodegen, Debug build-for-testing, Release build)
                                                  + steps: project check, package validation in job checks
scripts/make_ci_angle_standins.py        new      generates libEGL/libGLESv2 stand-in xcframeworks from CVisualCoreEGL.h
scripts/check_app_targets.py             new      project.yml vs Configs/app-targets.json vs the ledger
scripts/check_experience_packages.py     new      experience packages vs catalog vs registrations
scripts/measure_build.py                 new      clean/incremental build seconds and app bytes → build-measurements.json
scripts/check_dependencies.py            modify   + rules R6 (experience imports another experience), R7 (experience
                                                    target depends on another experience), R8 (experience imports ProjectM)
scripts/release_check.py                 modify   + unified-app steps (unit, interface chunks, verification subsets,
                                                    Release build, symbols with the stand-in marker, privacy, measurement)
scripts/test_scripts.py                  modify   tests of every new or changed tool
Configs/app-targets.json                 new      schema 1: the three application targets
docs/performance/build-measurements.json new      schema 1: records
docs/performance/budgets.md              modify   the row "clean build, incremental build and app size" points to the tool
Auto-Creator.md (sections 16, 24.1)      modify   as built, edited in place
```

Dependency direction is unchanged: `Apps/VisualCore → Experiences* → VisualCoreRendering → VisualCore`.

## Commands

- Tools: `python3 scripts/check_app_targets.py`, `python3 scripts/check_experience_packages.py`,
  `python3 scripts/check_dependencies.py`, `python3 scripts/measure_build.py [--check]`,
  `python3 scripts/make_ci_angle_standins.py --out <dir>` (CI only; refuses to write inside a path that holds real
  frameworks).
- Tests: `python3 scripts/test_scripts.py`; release-check steps `--only <step>`; package tests with
  `xcodebuild_package.py`; app tests with `xcodebuild_app.py`.
- CI: confirmed with `gh run list` between steps, never waited on.

## Rollback

Each tool and the CI job land as separate commits; `git revert` of the CI commit restores the previous workflow.
Tracked JSON files are new and can be removed by revert. No ledger or framework change.

## Complexity Tracking

None.
