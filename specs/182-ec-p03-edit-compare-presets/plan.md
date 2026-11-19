# Implementation Plan: Effects Composer — Phase 03 Chain editing, compare and presets

**Branch**: `182-ec-p03-edit-compare-presets` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

The compare view, a preset library after Visual Programming Lab's `GraphLibrary`, a `replace` edit that makes opening
a preset undoable, named accessibility actions for every node, and an audit of every drawn pass. Gaps G-EDIT,
G-COMPARE and G-PRESETS close, and the contract's later phases follow the manual's gates.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/presets.md](contracts/presets.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, Swift Testing, SwiftUI.
- **Dependencies:** unchanged products; `ExperienceStorage` (VisualCoreExperience), `FieldPass.runObserver`
  (VisualCoreRendering).
- **Storage:** `preset-<n>.json` and `presets.json` in the experience's storage.
- **Testing:** `EffectsComposerCoreTests`, `EffectsComposerExperienceTests` on sim-27.2; the app unit tests; the runner.
- **Constraints:** no VisualCore change; caps of clarification Q2; each test under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, II | PASS: no renderer change; `ExperienceStorage` reused; the library app-local after `GraphLibrary` |
| III | PASS: compare only changes which target is presented |
| IV | PASS: `replace` edit pure and tested |
| VIII | PASS: storage local; nothing deleted automatically |
| IX | PASS: damaged, newer and oversized files refused |
| Accessibility (A25) | PASS: named actions, no dragging |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/EffectsComposer/Core/ChainEditing.swift (replace edit)                          modify
Packages/ExperiencesCreative/EffectsComposer/CoreTests/HistoryTests.swift (replace and its undo)             modify
Packages/ExperiencesCreative/EffectsComposer/Experience/LookLibrary.swift                                  new
Packages/ExperiencesCreative/EffectsComposer/Experience/Adapter/ComposerCore.swift (view.compare)            modify
Packages/ExperiencesCreative/EffectsComposer/Experience/{PreviewRenderer,ComposerPresenter,ECControls}.swift modify  compare, library actions, accessibility actions
Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/{CompareTests,LookLibraryTests,AliasingTests,AccessibilityActionTests}.swift new
docs/apps/effects-composer/visualcore-contract.json (G-EDIT, G-COMPARE, G-PRESETS closed; phases moved)  modify
```

- **Lifecycle:** the library is made with the experience's storage at the factory; it touches no graphics.
- **Migration:** preset and index version 1; the chain file's own migrations apply to the embedded chain.
- **Rollback:** revert the commits.

## Parallel work

- **Agent L:** LookLibrary and LookLibraryTests.
- **Agent V:** replace edit, compare, accessibility actions, the audit and their tests (after L's library exists for the
  presenter actions).
- **Lead:** the contract, runs and commits.
