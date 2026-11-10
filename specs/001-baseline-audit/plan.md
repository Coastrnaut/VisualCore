# Implementation Plan: Phase 0 — Repository Integration and Baseline Audit

**Branch**: `001-baseline-audit` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-baseline-audit/spec.md`

## Summary

Audit first, change nothing. Deterministic Python scripts extend the existing F00 tooling to
inventory the read-only `External/projectm-ios` reference and trace its renderer with
path-and-symbol citations. They also build and smoke-test the unmodified reference on simulators
using its own scripts, recording every step through `desktop_runbook.py run-check`. Outputs are four
architecture documents and a baseline report.

## Technical Context

**Language/Version**: Python 3.15.2 (stdlib only) for audit scripts; reference is Swift 6 / C / C++
**Primary Dependencies**: git, nm, plutil, xcodebuild 27.2 (27B52), xcodegen 2.46.0, cmake 4.4.5,
the reference's `scripts/build_projectm_xcframework.py`
**Storage**: JSON + Markdown under `docs/architecture/` and `docs/verification/`; logs in `.autonomy/logs/`
**Testing**: `python3 scripts/test_scripts.py` (unit tests for new script functions);
`desktop_runbook.py run-check` for every baseline command
**Target Platform**: macOS 27.2 host; iOS 27.2 and 26.5 simulators
**Project Type**: audit/tooling (no production code)
**Performance Goals**: N/A (no measurements claimed; simulator never performance evidence)
**Constraints**: reference checkout read-only (clean tree before/after); writes only to its
gitignored `Build/` and generated `.xcodeproj`; no device action; explicit timeouts
**Scale/Scope**: 8 reference packages, 3 apps, 2 XcodeGen specs, ~10 scripts, 1 CI workflow

## Constitution Check

| Principle | Status |
|---|---|
| I Proven renderer | Audit only documents the ANGLE → Metal path; no new renderer — PASS |
| II App-neutral / read-only submodule | Clean-tree check before and after every step — PASS |
| III Lifecycle | Trace documents the reference lifecycle; gaps become follow-ups — PASS |
| IV Host-testable | Script logic unit-tested on host — PASS |
| V Devices later | No device install/launch/test; inventory read-only — PASS |
| VI Evidence | Every step via `run-check`; unknowns labelled — PASS |
| VII–X | Not affected beyond license inventory (X) — PASS |

Post-design re-check: PASS (no violations; Complexity Tracking empty).

## Project Structure

### Documentation (this feature)

```text
specs/001-baseline-audit/
├── plan.md  research.md  data-model.md  quickstart.md
├── contracts/audit-outputs.md
├── checklists/requirements.md
└── tasks.md                     # /speckit-tasks
```

### Source Code (repository root)

```text
scripts/
├── audit_projectm_reference.py   # existing (F00): pins, frameworks, licenses, bridge hashes
├── inventory_reference.py        # NEW: packages/targets/scripts/tests/CI/deps inventory + trace citation checker
├── check_reference_clean.py      # NEW: exit 1 if reference tracked files changed
├── run_reference_baseline.py     # NEW: ordered baseline command list (engine build, xcodegen, builds, tests) — prints or executes one step
└── test_scripts.py               # extended
docs/architecture/
├── repository-audit.md                  # inventory (FR-F003)
├── current-rendering-pipeline.md        # cited trace (FR-F004/FR-F005/FR-F006)
├── reusable-component-inventory.md      # classification (FR-F007)
├── visualcore-gap-analysis.md           # gaps (FR-F007)
└── reference-inventory.json             # machine output of inventory_reference.py
docs/verification/
└── projectm-baseline.md                 # baseline report (FR-F008)
```

**Structure Decision**: tooling + documentation only; the reference is never edited.

## Complexity Tracking

None.
