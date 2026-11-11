# Implementation Plan: Particle Universe — Phase 00 boundary audit

**Branch**: `032-pu-p00-boundary-audit` | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md) | **Gate**: A04-P00

## Summary

An audit phase plus an empty app shell. It produces the repository inventory and the 10-row integration matrix in the
shared contract format (JSON with a rendered Markdown view); the gap register, which assigns each reusable gap to a
VisualCore module (Principle II); the stop/go decision; the recorded ProjectM regression baseline; and a compilable
SwiftUI shell `ParticleUniverse` with a launch smoke test. It reuses the A01-P00 tooling unchanged
(`check_app_contract.py`, the `app-contracts` release-check step, the dependency-audit build phase). No VisualCore or
ProjectM source changes and no new scripts.

## Technical Context

**Language/Version**: Swift 6.4.2 (shell), Python 3 (existing checker).

**Primary Dependencies**: none new; the shell links VisualCoreUI only for `AccessibleColors` (as A03's shell).

**Storage**: N/A.

**Testing**: `check_app_contract.py --app particle-universe`; XCUITest launch smoke on iOS 27.2 and 26.5 under the
enumeration guard; the 7 reference regression steps; a diff check for `Packages/` and `External/`.

**Target Platform**: iOS/iPadOS 26.0+.

**Performance Goals**: none.

**Constraints**: no VisualCore or ProjectM edits; no networking or permissions; unsigned simulator builds.

**Scale/Scope**: 1 contract JSON, 2 docs, 1 app target, 1 UI test target, 1 scheme.

## Constitution Check

| Principle | Status |
|---|---|
| I Proven renderer | PASS (no rendering code) |
| II Maximize reuse | PASS: the register assigns emitter families, fields, additive blending, trail decay and particle quality tiers to VisualCore modules |
| II-a Preserve reference | PASS: baseline regression, no reference edits |
| III GPU lifecycle | N/A this phase |
| IV Host-testable | PASS: the contract check runs on the host |
| V/VI Evidence | PASS: simulator and run-check only |
| VII Accessible UI | PASS: the title has a label and identifier |
| VIII Privacy | PASS: no permissions, no networking |
| IX Bounded input | PASS: the contract JSON is schema-checked |
| X Licensing | PASS: no assets |
| A04 app rules | PASS: consumer only, CPU simulation in VisualCore, offline, one phase at a time |

## Project Structure

```text
docs/apps/particle-universe/visualcore-contract.json   # inventory, matrix, gaps, traceability, negatives, decision
docs/apps/particle-universe/visualcore-contract.md     # rendered (check_app_contract.py --render)
docs/apps/particle-universe/regression-baseline.md     # phase-start commit + ProjectM baseline
Apps/ParticleUniverse/App/ParticleUniverseApp.swift   # @main shell, titled home (pu.home.title)
Apps/ParticleUniverse/Generated/{Info,UITests-Info}.plist
Apps/ParticleUniverse/Tests/UI/LaunchSmokeUITests.swift
project.yml   # + targets ParticleUniverse, ParticleUniverseUITests, scheme; dependency audit phase
```

**Dependency direction**: `Apps/ParticleUniverse` → VisualCore products only; nothing depends on the app; no ProjectM
edge (R1 and the post-build audit).

**Lifecycle contract (shell)**: `ParticleUniverseApp` → `WindowGroup` → `HomeView` (static); no render host.

**Data schemas**: the shared contract JSON (schema 1), see [data-model.md](data-model.md).

**Build commands**: `xcodegen generate --spec project.yml`; `xcodebuild test -project VisualCore.xcodeproj -scheme
ParticleUniverse -destination "platform=iOS Simulator,id=<udid>" … CODE_SIGNING_ALLOWED=NO`;
`python3 scripts/check_app_contract.py --app particle-universe [--render]`.

**Migration and rollback**: additive; rollback removes the two targets, `Apps/ParticleUniverse/` and
`docs/apps/particle-universe/`.

## Complexity Tracking

None.
