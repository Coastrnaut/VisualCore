# Implementation Plan: Generative Art Studio — Phase 00 boundary audit

**Branch**: `011-gas-p00-boundary-audit` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md) | **Gate**: A01-P00

## Summary

This is an audit phase plus an empty app shell. It produces:

- the repository inventory and the 10-row integration matrix (machine-readable JSON plus a generated Markdown view);
- an app-neutral contract checker that verifies every cited file and symbol, reusable by all 25 apps;
- a gap register that assigns each reusable gap to a VisualCore module (Principle II, "Maximize reuse");
- the stop/go decision;
- the recorded ProjectM regression baseline;
- a compilable SwiftUI shell `GenerativeArtStudio` with a launch smoke test.

No VisualCore or ProjectM source changes.

## Technical Context

**Language/Version**: Swift 6.4.2 (app shell), Python 3 (checker) · **Primary Dependencies**: none new. The shell
links no VisualCore product yet; rendering arrives in Phase 02. · **Storage**: N/A (documents in Phase 03) ·
**Testing**: `scripts/test_scripts.py` (checker logic plus a fixture), XCUITest launch smoke on iOS 27.2 and 26.5,
reference regression steps · **Target Platform**: iOS/iPadOS 26.0+ · **Project Type**: iOS app in a monorepo ·
**Performance Goals**: none in this phase (spec clarification 5) · **Constraints**: no VisualCore or ProjectM edits,
no networking, no permissions, unsigned simulator builds · **Scale/Scope**: 1 script, 1 JSON contract, 2 docs, 1 app
target, 1 UI test target.

## Constitution Check

| Principle | Status |
|---|---|
| I Proven renderer | PASS (no rendering code) |
| II App-neutral API; Maximize reuse | PASS: the checker is app-neutral, and the gap register assigns reusable work to VisualCore |
| II-a Preserve reference | PASS: baseline regression run, no reference edits |
| III GPU lifecycle | N/A this phase |
| IV Host-testable | PASS: checker tests on the host |
| V Implementation before devices | PASS: simulator only |
| VI Evidence | PASS: run-check for every command |
| VII Accessible UI | PASS: the shell title has an accessibility label and identifier |
| VIII Public APIs and privacy | PASS: no permissions, no networking |
| IX Bounded input | PASS: the checker treats contract JSON as untrusted (schema-validated) |
| X Licensing | PASS: no assets added |
| A01 app rules | PASS: consumer only, offline, one phase at a time |

## Project Structure

### Documentation (this feature)

```text
specs/011-gas-p00-boundary-audit/{spec,plan,research,data-model,quickstart,tasks}.md, contracts/app-contract.md
```

### Source code (repository root)

```text
docs/apps/generative-art-studio/visualcore-contract.json   # inventory, matrix, gap register, decision (data)
docs/apps/generative-art-studio/visualcore-contract.md     # generated view (--render) + narrative + traceability
docs/apps/generative-art-studio/regression-baseline.md     # ProjectM regression baseline for A01
scripts/check_app_contract.py                               # app-neutral: --app <slug> [--render]
scripts/fixtures/app_contract/{good,bad}/…                  # checker test fixtures
scripts/test_scripts.py                                     # + AppContractTests
Apps/GenerativeArtStudio/App/GenerativeArtStudioApp.swift   # @main SwiftUI shell, titled home
Apps/GenerativeArtStudio/Tests/UI/LaunchSmokeUITests.swift  # launch + title + accessibility label
project.yml                                                 # + targets GenerativeArtStudio, GenerativeArtStudioUITests, scheme
scripts/audit_showcase_dependencies.py                      # reused unchanged (--spec/--target/--sources/--app)
scripts/check_dependencies.py, check_documented_api.py      # reused; Apps/** already in their scope
```

**Dependency direction**: `Apps/GenerativeArtStudio` → (later) VisualCore products only. Nothing depends on the app.
There is no ProjectM edge, which `check_dependencies.py` (R1) and the post-build audit enforce.

**Lifecycle contract (shell)**: `GenerativeArtStudioApp` → `WindowGroup` → `HomeView` (static). No render host is
created in Phase 00, so there is no GPU lifecycle to manage yet. Phase 02 hosts `RenderHost.view` through a
VisualCore SwiftUI surface (gap G-UI).

**Data schemas**: the contract JSON (schema 1) in [data-model.md](data-model.md). No app documents exist yet (Phase 03).

**Build commands**:
- `xcodegen generate --spec project.yml`
- `xcodebuild build -project VisualCore.xcodeproj -scheme GenerativeArtStudio -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO`
- `xcodebuild test … -destination "platform=iOS Simulator,id=<27.2|26.5 udid>" -test-timeouts-enabled YES -default-test-execution-time-allowance 180`
- `python3 scripts/check_app_contract.py --app generative-art-studio`

**Migration and rollback**: everything is additive. Rollback means removing the two `project.yml` targets, the
scheme, `Apps/GenerativeArtStudio/` and `docs/apps/generative-art-studio/`. No shared code changes, so no consumer is
affected.

## Complexity Tracking

None.
