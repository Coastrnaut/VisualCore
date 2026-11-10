# Implementation Plan: Phase 1 — Architecture Constitution and Integration Contracts

**Branch**: `002-architecture-contracts` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-architecture-contracts/spec.md`

## Summary

Turn the Phase 0 audit into enforceable contracts: package map and dependency rules, lifecycle and
threading, resources/shaders/errors/logging, test boundaries, the ProjectM adapter, submodule policy
and regression triggers. Correct ADR-0002/ADR-0003 to match, and add `scripts/check_dependencies.py`
to enforce the rules. Per the archived Phase 1 implement prompt: documentation, ADRs and only the
package scaffolding the plan approves (package manifests and empty module directories). No renderer
code migrates in this phase.

## Technical Context

**Language/Version**: Swift 6.4.2 (Swift 6 mode, strict concurrency), C11, Python 3.15 (scripts)
**Primary Dependencies**: prebuilt ANGLE `libEGL`/`libGLESv2` XCFrameworks (pin 29d1823) as SwiftPM
binary targets; Apple Foundation/UIKit/SwiftUI/QuartzCore/AVFAudio
**Storage**: N/A (contracts)
**Testing**: `python3 scripts/test_scripts.py` (checker unit tests); `swift package describe` on scaffolded manifests
**Target Platform**: iOS/iPadOS 26.0+ (simulators 27.2/26.5); macOS host for pure modules
**Project Type**: SwiftPM packages + XcodeGen app targets (reference pattern: `project.yml`, separate harness `.yml`)
**Performance Goals**: N/A in this phase
**Constraints**: no ProjectM outside the harness; read-only submodule; audit-backed boundaries only
**Scale/Scope**: 2 packages, 16 products, 4 contract documents, 1 checker

## Constitution Check

| Principle | Status |
|---|---|
| I renderer | Contracts keep the audited ANGLE sequence (render-lifecycle.md reconciliation) — PASS |
| II/II-a app-neutral, reference preserved | R1–R5 + regression triggers — PASS |
| III lifecycle | State machine, generations, threading — PASS |
| IV host-testable | Pure package split — PASS |
| V devices later | Test boundaries reserve device evidence for campaign II — PASS |
| VI evidence | Checker + run-check — PASS |
| VII–X | Logging privacy, bounded shaders, licensing of LGPL harness — PASS |

Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/002-architecture-contracts/
├── plan.md research.md data-model.md quickstart.md tasks.md
└── contracts/ package-map.md render-lifecycle.md resources-shaders-errors.md tests-adapter-submodule-regression.md
```

### Source Code (repository root)

```text
docs/decisions/ADR-0002-render-host-seam.md     # corrected to reference contracts
docs/decisions/ADR-0003-package-boundaries.md   # corrected to reference package-map.md
docs/architecture/visualcore-architecture.md    # updated links (was pointing at the retired dossier)
scripts/check_dependencies.py                   # R1–R5 enforcement (NEW)
Packages/VisualCore/Package.swift               # scaffold: 9 products, empty modules with README
Packages/VisualCoreRendering/Package.swift      # scaffold: 7 products incl. ANGLE binary targets
```

**Structure Decision**: two packages per the clarified decision; scaffolding only.

## Complexity Tracking

None.
