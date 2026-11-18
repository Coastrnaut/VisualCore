# Implementation Plan: Shader Studio — Phase 04 Resource limits and error UX

**Branch**: `162-ss-p04-limits-error-ux` (spec directory only; work on `main`) | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-WATCHDOG and G-LIBRARY and adds error guidance:
- **Guidance:** a pure `Guidance` gives one sentence per refusal code and per common compiler error. It is shown
  under the status and with each diagnostic.
- **Watchdog:** a pure `FrameWatchdog` watches drawn-frame intervals (limit 0.25 s, window 8). A stopped preview
  draws a flat dark frame. Reset (`preview.reset`) swaps back the previous live shader the watchdog had not stopped,
  or queues the template's starter.
- **Library:** `ProjectLibrary` saves, lists, opens, renames and removes named projects in the experience's
  `ExperienceStorage`, after Digital Zen Garden's `GardenLibrary`.
- **Fixture:** a `#version` line and a uniform used without a declaration show their own guidance.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/limits.md](contracts/limits.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI.
- **Dependencies:** unchanged. The experience uses:
  - `ExperienceStorage` (`write`, `read`, `exists`, `list`, `remove`; quota 16 MiB and 64 files);
  - `FrameInfo.delta`;
  - the A22-P01 `ShaderProject` envelope;
  - the A22-P02/P03 pipeline, editor and inspector.

  All are public and tested.
- **Testing:**
  - core and experience tests on sim-27.2;
  - guidance patterns proved by compiling real broken shaders on ANGLE (`CompileSupport`, compile only);
  - the app build and unit tests;
  - interface chunk `d3`, now `SSEditorUITests` and `SSLibraryUITests`, each test under 60 s;
  - the runner.
- **Constraints:** no GL call outside VisualCore types; no compile from a control; no clock in the core (the
  watchdog is fed intervals).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: drawing stays in the host's context through `FullScreenShaderScene` and `FieldPass`; the stopped frame is a scene clear |
| II | PASS: reuses `ExperienceStorage`, the `ShaderProject` envelope and the library pattern; nothing copied from another experience's module |
| IV | PASS: `Guidance` and `FrameWatchdog` are pure core types with tests |
| VI | PASS: files are versioned; damaged and newer files are refused and never deleted |
| IX | PASS: spoken labels, Dynamic Type, keyboard reachable; guidance is text, not colour |
| A22 (2.18.1) | PASS: caps before compile, queued compiles, a watchdog and reset, no sandbox claim |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/ShaderStudio/Core/{Guidance,FrameWatchdog}.swift                 new  pure
Packages/ExperiencesCreative/ShaderStudio/CoreTests/{GuidanceTests,GuidanceCompileTests,FrameWatchdogTests}.swift new
Packages/ExperiencesCreative/ShaderStudio/Experience/Adapter/{StudioCore,StudioManifest}.swift  modify  preview.reset, resets, fixtures
Packages/ExperiencesCreative/ShaderStudio/Experience/{PreviewPipeline,StudioPresenter,StudioControls,StudioEditor}.swift modify
Packages/ExperiencesCreative/ShaderStudio/Experience/{ProjectLibrary,StudioLibraryView}.swift   new
Packages/ExperiencesCreative/ShaderStudio/Experience/ShaderStudioExperience.swift              modify  pass storage
Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/{GuidanceDisplayTests,WatchdogTests,LibraryTests}.swift new
Packages/ExperiencesCreative/ShaderStudio/scenario-manifest.json                               regenerate
Apps/VisualCore/Tests/UI/ShaderStudio/SSLibraryUITests.swift; scripts/release_check.py (d3)    new/modify
docs/apps/shader-studio/visualcore-contract.json                                               modify
```

- **Dependency direction:** unchanged (app → experience → core → VisualCore). The core does not import storage.
- **Lifecycle:**
  - The watchdog is reset in setup, resize, Run and Reset (it skips the next interval).
  - The fallback scene is torn down with the pipeline and rebuilt from its source after a context loss.
  - The library reads storage on open and writes atomically on each change.
- **Migration:** snapshot schema 1, with an optional `resets` field (default 0). The library files are new
  (version 1).
- **Rollback:** revert the commits. Library files stay in the experience's storage and are ignored by older builds.

## Parallel work

- **Agent X:** core `Guidance`, `FrameWatchdog` and their tests.
- **Agent L:** `ProjectLibrary` and `LibraryTests`. These are new files.
- **Agent E:** adapter, pipeline, presenter, controls and editor wiring, guidance display, watchdog and the library
  view, after X and L.
- **Agent U:** `SSLibraryUITests`.
- **Lead:** release_check.py, contract, runs and commits.
