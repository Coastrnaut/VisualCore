# Implementation Plan: Shader Studio — Phase 05 Stress-test shader failures and device recovery

**Branch**: `163-ss-p05-stress-recovery` (spec directory only; work on `main`) | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

## Summary

This phase proves no build-up and recovery, binds the core's bounds to the live project and closes G-DEVICE:
- **Stress:** experience tests run short fixed cycles (successful, failing, refused and stopped runs, template
  changes) and compare the registry's resource level after the first and the last cycle. Any leak they find is fixed
  in the experience.
- **Recovery:** 10 context rebuilds in each of 5 states give the same picture and resource level, and `leaked` stays
  0.
- **Bounds:** a new core action `document.shape [uniforms, inputs]` is sent by the presenter. The snapshot field
  `shape` is optional.
- **Relaunch:** `SSRecoveryUITests` proves that a saved project survives a relaunch.
- **Device plan:** `docs/apps/shader-studio/device-campaign.md`, with rows SS-D1 to SS-D6 per device, all pending.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/recovery.md](contracts/recovery.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6.
- **Dependencies:** unchanged. The experience uses:
  - `ResourceRegistry.stats` (`liveCount`, `liveBytes`, `totalBytes`, `leaked`);
  - `ExperienceSession.recreateContext()`;
  - `ExperienceStorage`;
  - the A22-P02 to P04 pipeline, editor, inspector, watchdog and library.

  All are public and tested.
- **Testing:**
  - core and experience tests on sim-27.2, each under 10 s;
  - the app build and unit tests;
  - interface chunk `d3` adds `SSRecoveryUITests`, each test under 60 s;
  - the runner.
- **Constraints:** no GL call outside VisualCore types; no compile from a control; no soak.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: rebuilds go through the host's `recreateContext`; resources are released in teardown and counted by the registry |
| II | PASS: no VisualCore API change |
| IV | PASS: `document.shape` is a pure core action with tests |
| V | PASS: no device run; the plan's rows stay pending until `ImplementationLock-100` |
| VI | PASS: simulator results are not device evidence; the plan says so |
| VII, VIII | PASS: no new UI beyond tests; no network |
| IX | PASS: shape bounds clamp the core's actions; snapshots stay bounded |
| A22 (2.18.1) | PASS: caps, the queue, the watchdog and no sandbox claim are unchanged |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/ShaderStudio/Experience/Adapter/{StudioCore,StudioManifest}.swift   modify  document.shape, shape, fixture
Packages/ExperiencesCreative/ShaderStudio/Experience/{StudioPresenter,PreviewPipeline}.swift     modify  send the shape; fix any leak found
Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/{StressCycleTests,RecoveryTests,ShapeTests}.swift new
Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/{StudioCoreTests,StudioManifestTests,LibraryTests}.swift modify
Packages/ExperiencesCreative/ShaderStudio/scenario-manifest.json                                regenerate
Apps/VisualCore/Tests/UI/ShaderStudio/SSRecoveryUITests.swift; scripts/release_check.py (d3)     new/modify
docs/apps/shader-studio/device-campaign.md                                                      new
docs/apps/shader-studio/visualcore-contract.json                                                modify
```

- **Dependency direction:** unchanged (app → experience → core → VisualCore).
- **Lifecycle:**
  - The shape is sent when the document's counts change: an edit, an open, a template choice or a restore. Sending
    it is an action through the engine, never a compile.
  - A rebuild tears down the live, fallback and stopped scenes and the texture targets, and sets them up again.
- **Migration:** snapshot schema 1 with an optional `shape`, defaulting to the template's counts.
- **Rollback:** revert the commits.

## Parallel work

- **Agent S:** `StressCycleTests` and `RecoveryTests`, new files; it reports any leak.
- **Agent E:** `document.shape` (core adapter, presenter), `ShapeTests` and the manifest. After S, it fixes any leak
  S found.
- **Agent U:** `SSRecoveryUITests`.
- **Agent D:** `device-campaign.md`.
- **Lead:** release_check.py, contract, runs and commits.
