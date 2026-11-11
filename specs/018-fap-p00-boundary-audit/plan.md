# Implementation Plan: Fluid Art Playground — Phase 00 boundary audit

**Branch**: `018-fap-p00-boundary-audit` | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md) | **Gate**: A02-P00

## Summary

An audit phase plus an empty app shell. It produces:

- the repository inventory and the 10-row integration matrix in the shared contract format (JSON, with a rendered
  Markdown view);
- the gap register, which assigns each reusable gap to a VisualCore module (Principle II) and keeps the fluid
  equations app-domain with a CPU reference (A02 rule);
- the stop/go decision;
- the recorded ProjectM regression baseline;
- a compilable SwiftUI shell `FluidArtPlayground` with a launch smoke test.

It reuses the A01-P00 tooling unchanged: `check_app_contract.py`, the `app-contracts` release-check step, and the
dependency-audit build phase. There are no VisualCore or ProjectM source changes and no new scripts.

## Technical Context

**Language/Version**: Swift 6.4.2 (shell), Python 3 (existing checker)

**Primary Dependencies**: none new. The shell links no VisualCore product yet; the solver and rendering arrive in
Phases 01–02.

**Storage**: N/A

**Testing**:
- `check_app_contract.py --app fluid-art-playground`;
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
| II Maximize reuse | PASS: shared checker reused; the register assigns reusable work (ping-pong fields, float-target query, quality policy, splat input) to VisualCore |
| II-a Preserve reference | PASS: baseline regression run, no reference edits |
| III GPU lifecycle | N/A this phase |
| IV Host-testable | PASS: the contract check runs on the host |
| V Implementation before devices | PASS: simulator only |
| VI Evidence | PASS: run-check for every command |
| VII Accessible UI | PASS: the shell title has an accessibility label and identifier |
| VIII Public APIs and privacy | PASS: no permissions, no networking |
| IX Bounded input | PASS: the contract JSON is schema-validated by the checker |
| X Licensing | PASS: no assets added |
| A02 app rules | PASS: consumer only, solver planned app-domain with a CPU reference, offline, one phase at a time |

## Project Structure

### Documentation (this feature)

```text
specs/018-fap-p00-boundary-audit/{spec,plan,research,data-model,quickstart,tasks}.md, contracts/app-contract.md
```

### Source code (repository root)

```text
docs/apps/fluid-art-playground/visualcore-contract.json   # inventory, matrix, gap register, traceability, negatives, decision
docs/apps/fluid-art-playground/visualcore-contract.md     # rendered view (check_app_contract.py --render)
docs/apps/fluid-art-playground/regression-baseline.md     # phase-start commit + ProjectM regression baseline for A02
Apps/FluidArtPlayground/App/FluidArtPlaygroundApp.swift   # @main SwiftUI shell, titled home
Apps/FluidArtPlayground/Generated/{Info,UITests-Info}.plist
Apps/FluidArtPlayground/Tests/UI/LaunchSmokeUITests.swift # launch + title + accessibility label
project.yml                                               # + targets FluidArtPlayground, FluidArtPlaygroundUITests; dependency audit phase
```

**Dependency direction**: `Apps/FluidArtPlayground` → (later) VisualCore products only. Nothing depends on the app.
There is no ProjectM edge, which `check_dependencies.py` R1 and the post-build audit enforce.

**Lifecycle contract (shell)**: `FluidArtPlaygroundApp` → `WindowGroup` → `HomeView` (static). There is no render
host in Phase 00.

**Data schemas**: the shared contract JSON (schema 1), see [data-model.md](data-model.md).

**Build commands**:
- `xcodegen generate --spec project.yml`
- `xcodebuild test -project VisualCore.xcodeproj -scheme FluidArtPlayground -destination "platform=iOS Simulator,id=<27.2|26.5 udid>" -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO`
- `python3 scripts/check_app_contract.py --app fluid-art-playground [--render]`
- `python3 scripts/check_test_enumeration.py --sources Apps/FluidArtPlayground/Tests/UI --log <log>`

**Migration and rollback**: additive. Rollback removes the two `project.yml` targets, `Apps/FluidArtPlayground/` and
`docs/apps/fluid-art-playground/`. No shared code changes.

## Complexity Tracking

None.
