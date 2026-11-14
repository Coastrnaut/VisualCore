# Implementation Plan: Oscilloscope Studio — Phase 04 Cursors, freeze and presets

**Branch**: `064-os-p04-cursors-presets` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-SCOPEINTERACT (app-local) and add scope presets. Core: `ScopeState` schema 3 (frozen, cursors shown, cursor A,
B, level and frequency positions; migration from schema 2), `ScopeReadout` (precision rules of FR-A08-404),
`ScopePreset` (format 1, `scope-<uuid>.json`, three built-ins), `ScopeZoom` (pinch scale → timebase steps). Experience:
actions `freeze.set`, `cursors.show`, `cursor.a`, `cursor.b`, `cursor.level`, `cursor.frequency`, `preset.apply`;
presenter holds the frozen window, draws cursor lines, reads out, feeds pointers to `PinchRecognizer` and drags the
nearest cursor; `ScopePresetStore` mirrors `JourneyPresetStore`; controls gain Freeze, cursor sliders and a preset list
with save, rename and delete; manifest fixtures for freeze with cursors, zoom steps and a preset applied. No VisualCore
change. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A08-P03, plus `VisualCorePersistence` (`ExperienceStorage`) and
`VisualCoreScenes` (`PinchRecognizer`, `PointerEvent`) already linked. **Storage**: snapshot `ScopeState` schema 3;
preset files `scope-<uuid>.json` in the experience's storage (settings only). **Testing**: ExperiencesCreative on
sim-27.2 (`ScopeReadoutTests`, `ScopePresetTests`, `ScopeZoomTests`, state migration tests; adapter, presets store,
session, render, manifest); app build and unit; runner iOS 27; package check; contract; script tests. **Performance**:
freeze copies at most 2 × 4,096 floats once; readouts are O(1). **Constraints**: tests < 10 s; iOS 27 only; reference
regression at X-A08; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (drawing through the host) · II PASS (reuses `PinchRecognizer`, `ExperienceStorage`, the A07 store pattern) ·
II-a PASS (no VisualCore change) · III PASS (frozen window released on source change; restored frozen state re-freezes)
· IV PASS (readout, zoom, presets host-free) · V PASS (schema 3 with migration; preset format 1 with newer and damaged
files kept) · VI PASS (render tests) · VII PASS (every control labelled; readouts spoken; drag has slider
alternatives) · VIII PASS (presets hold settings only; no audio) · IX PASS (names ≤ 40 characters, bounded cursor
ranges, NaN refused) · X–XIII PASS. A08 rules: truthful units (FR-A08-404) — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/OscilloscopeStudio/Core/{ScopeState,ScopeSettings}.swift (schema 3)          modify
Packages/ExperiencesCreative/OscilloscopeStudio/Core/{ScopeReadout,ScopePreset,ScopeZoom}.swift            new
Packages/ExperiencesCreative/OscilloscopeStudio/CoreTests/{ScopeStateTests,ScopeReadoutTests,ScopePresetTests,ScopeZoomTests}.swift
Packages/ExperiencesCreative/OscilloscopeStudio/Experience/{Adapter/ScopeCore,Adapter/ScopeManifest,ScopePresenter,
  ScopeControls,ScopePresetStore}.swift; ExperienceTests/{ScopeCoreTests,ScopePresetStoreTests,ScopeSessionTests,
  ScopeRenderTests,ScopeManifestTests}.swift; scenario-manifest.json                                         modify/new
Apps/VisualCore/App/ExperienceRegistry.swift (schema-2 example added)                                      modify
docs/apps/oscilloscope-studio/visualcore-contract.json (G-SCOPEINTERACT closed; M13, M14, M21 evidence)    modify
```

**Dependency direction** and **rollback** as before. **Lifecycle**: the presenter keeps the frozen window until
unfreeze, a source change or teardown; the preset store reloads on setup and after each change. **Migration**: schema
2 → 3 adds the freeze and cursor defaults; the registry stores schema-1 and schema-2 examples.

## Parallel work

Agent A: core (state schema 3, readout, preset, zoom) + tests. Agent B: preset store + tests (after A's `ScopePreset`).
Agent C: adapter, presenter, controls, experience tests and manifest after A and B. Lead: registry examples, contract,
runs, commits.
