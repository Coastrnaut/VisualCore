# Implementation Plan: Fractal Explorer — Phase 00 boundary audit

**Branch**: `025-fe-p00-boundary-audit` | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md) | **Gate**: A03-P00

## Summary

An audit phase plus an empty app shell. It produces:

- the repository inventory and the 10-row integration matrix in the shared contract format (JSON, with a rendered
  Markdown view);
- the gap register, which assigns each reusable gap to a VisualCore module (Principle II) and keeps the fractal
  formulas app-domain with a CPU reference (A03 rule);
- the stop/go decision;
- the recorded ProjectM regression baseline;
- a compilable SwiftUI shell `FractalExplorer` with a launch smoke test.

It reuses the A01-P00 tooling unchanged: `check_app_contract.py`, the `app-contracts` release-check step, and the
dependency-audit build phase. There are no VisualCore or ProjectM source changes and no new scripts.

## Technical Context

**Language/Version**: Swift 6.4.2 (shell), Python 3 (existing checker)

**Primary Dependencies**: none new. The shell links no VisualCore product yet; the domain package and rendering arrive in
Phases 01–02.

**Storage**: N/A

**Testing**:
- `check_app_contract.py --app fractal-explorer`;
- XCUITest launch smoke on iOS 27.2 and 26.5, enumeration-guarded;
- the reference regression steps;
- a diff check for `Packages/` and `External/`.

**Target Platform**: iOS/iPadOS 26.0+

**Performance Goals**: none (spec clarification 5)

**Constraints**:
- no VisualCore or ProjectM edits;
- no networking or permissions;
- unsigned simulator builds.

**Scale/Scope**: 1 contract JSON, 2 docs, 1 app target, 1 UI test target, 1 scheme.

## Constitution Check

| Principle | Status |
|---|---|
| I Proven renderer | PASS (no rendering code) |
| II Maximize reuse | PASS: shared checker reused; the register assigns reusable work (complex-plane viewport, precision query and advisor, render-cost estimate) to VisualCore |
| II-a Preserve reference | PASS: baseline regression run, no reference edits |
| III GPU lifecycle | N/A this phase |
| IV Host-testable | PASS: the contract check runs on the host |
| V Implementation before devices | PASS: simulator only |
| VI Evidence | PASS: run-check for every command |
| VII Accessible UI | PASS: the shell title has an accessibility label and identifier |
| VIII Public APIs and privacy | PASS: no permissions, no networking |
| IX Bounded input | PASS: the contract JSON is schema-validated by the checker |
| X Licensing | PASS: no assets added |
| A03 app rules | PASS: consumer only, escape-time formulas planned app-domain with a CPU reference, precision clamped and shown, offline, one phase at a time |

## Project Structure

### Documentation (this feature)

```text
specs/025-fe-p00-boundary-audit/{spec,plan,research,data-model,quickstart,tasks}.md, contracts/app-contract.md
```

### Source code (repository root)

```text
docs/apps/fractal-explorer/visualcore-contract.json   # inventory, matrix, gap register, traceability, negatives, decision
docs/apps/fractal-explorer/visualcore-contract.md     # rendered view (check_app_contract.py --render)
docs/apps/fractal-explorer/regression-baseline.md     # phase-start commit + ProjectM regression baseline for A03
Apps/FractalExplorer/App/FractalExplorerApp.swift   # @main SwiftUI shell, titled home
Apps/FractalExplorer/Generated/{Info,UITests-Info}.plist
Apps/FractalExplorer/Tests/UI/LaunchSmokeUITests.swift # launch + title + accessibility label
project.yml                                               # + targets FractalExplorer, FractalExplorerUITests; dependency audit phase
```

**Dependency direction**: `Apps/FractalExplorer` → (later) VisualCore products only. Nothing depends on the app.
There is no ProjectM edge, which `check_dependencies.py` R1 and the post-build audit enforce.

**Lifecycle contract (shell)**: `FractalExplorerApp` → `WindowGroup` → `HomeView` (static). There is no render
host in Phase 00.

**Data schemas**: the shared contract JSON (schema 1), see [data-model.md](data-model.md).

**Build commands**:
- `xcodegen generate --spec project.yml`
- `xcodebuild test -project VisualCore.xcodeproj -scheme FractalExplorer -destination "platform=iOS Simulator,id=<27.2|26.5 udid>" -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO`
- `python3 scripts/check_app_contract.py --app fractal-explorer [--render]`
- `python3 scripts/check_test_enumeration.py --sources Apps/FractalExplorer/Tests/UI --log <log>`

**Migration and rollback**: additive. Rollback removes the two `project.yml` targets, `Apps/FractalExplorer/` and
`docs/apps/fractal-explorer/`. No shared code changes.

## Complexity Tracking

None.
