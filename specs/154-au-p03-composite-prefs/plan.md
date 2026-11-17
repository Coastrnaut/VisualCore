# Implementation Plan: Aurora — Phase 03 Multi-layer compositing and presets

**Branch**: `154-au-p03-composite-prefs` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-COMPOSITE and G-PREFS:
- **Composite:** preset changes run through `CrossfadeScene` with two moving, capped skies over 2.0 s, restarting from
  the current mix on a new choice, immediate under Reduce Motion.
- **Preferences:** schema 1 `a21.preferences` kept as the experience value `prefs.v1`, restored on open, reported and
  defaulted when damaged or newer; the sound choice (on/off, volume) lives here, outside the drawing lifecycle.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/experience.md](contracts/experience.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI. **Dependencies:** unchanged (`CrossfadeScene` is in VisualCoreRendering, already a
  dependency).
- **Testing:** `AuroraCoreTests` and `AuroraExperienceTests` on sim-27.2; the runner on iOS 27.
- **Constraints:** no GL call outside the scene protocol; no sound played; no VisualCore change. No NEEDS
  CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: `CrossfadeScene` and both skies draw on the host's context |
| II | PASS: reuses `CrossfadeScene` and `ExperienceStorage`; nothing copied |
| IV | PASS: the preferences model and its codes are pure and tested |
| A21 | PASS: every mixed frame under the limit; sound off by default and never played; Reduce Motion immediate |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Aurora/Core/SkyPreferences.swift                    new     schema 1, codes, defaults
Packages/ExperiencesCreative/Aurora/CoreTests/PreferencesTests.swift              new
Packages/ExperiencesCreative/Aurora/Experience/{AuroraPresenter,AuroraControls,AuroraExperience}.swift   modify
Packages/ExperiencesCreative/Aurora/Experience/SkyTransition.swift               new     CrossfadeScene driver
Packages/ExperiencesCreative/Aurora/ExperienceTests/{TransitionTests,PreferencesStoreTests,SoundChoiceTests}.swift new
docs/apps/aurora/visualcore-contract.json (G-COMPOSITE, G-PREFS closed)          modify
```

- **Lifecycle:** the crossfade owns both skies while set up; a context loss re-uploads its still picture; preferences
  are read before the first frame and written after each accepted change.
- **Migration:** schema 1 only. **Rollback:** revert the commits.

## Parallel work

- **Agent C:** the transition, the presenter changes and their tests.
- **Agent P:** the preferences model, store, sound control and their tests (after C has the presenter hooks, or
  through a separate `PreferencesStore` type the presenter calls).
- **Lead:** the contract, runs and commits.
