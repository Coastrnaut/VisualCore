# Implementation Plan: Visual Programming Lab — Phase 05 Resource-budget and usability testing

**Branch**: `170-vpl-p05-budget-usability` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

This phase proves the bounds and the usability and closes G-DEVICE as a plan:
- **Experience tests:** `StressCycleTests` (50 mixed cycles, level after the warm-up equals the level after the last),
  `PassCountTests` (2 passes for Gradient into Output with and without unused nodes; 6 for the journey),
  `RecoveryTests` (10 rebuilds in each of five states).
- **Interface tests:** `VPLSupport`, `VPLCanvasUITests`, `VPLRecoveryUITests` in a new serial chunk `e3`.
- **Device plan:** `docs/apps/visual-programming-lab/device-campaign.md`.
- **Fixes** found by the tests are made in the experience's own files.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/tests.md](contracts/tests.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI, XCTest (interface tests), Swift Testing (package tests).
- **Dependencies:** unchanged; only seams verified in this phase's clarification.
- **Testing:** both A23 package test targets on sim-27.2; the app build-for-testing, unit tests and the `e3` interface
  chunk on the iOS 27.2 phone; the runner on iOS 27.
- **Constraints:** unit tests under 10 s, interface tests under 60 s; no audit run; no device claim.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: no new drawing path |
| III | PASS: rebuilds run through the host's `recreateContext` |
| V | PASS: device rows pending; nothing run on a device |
| VI | PASS: simulator results never stand in for device rows |
| IX | PASS: list-form usability tested; audits wait for devices |
| A23 (2.19.0) | PASS: bounded resources proved by levels; no claims |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/{StressCycleTests,PassCountTests,RecoveryTests}.swift   new
Packages/ExperiencesCreative/VisualProgrammingLab/Experience/*.swift                                   modify only if a test finds a defect
Apps/VisualCore/Tests/UI/VisualProgrammingLab/{VPLSupport,VPLCanvasUITests,VPLRecoveryUITests}.swift    new
scripts/release_check.py (UI_CHUNKS "e3", SERIAL_CHUNKS); scripts/test_scripts.py if it lists chunks   modify (lead)
docs/apps/visual-programming-lab/device-campaign.md; README.md; visualcore-contract.json (G-DEVICE closed as the plan)  new / modify
```

- **Dependency direction:** unchanged.
- **Lifecycle:** unchanged; rebuilds through the host.
- **Migration:** none. **Rollback:** revert the commits.

## Parallel work

- **Agent S:** the three package test files (and any fix they need in the experience).
- **Agent U:** the three interface test files.
- **Agent V:** the device plan.
- **Lead:** release_check chunk, the contract, runs, commits.
