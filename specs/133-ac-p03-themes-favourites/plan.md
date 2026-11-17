# Implementation Plan: Ambient Clock — Phase 03 Theme customization and persistence

**Branch**: `133-ac-p03-themes-favourites` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-TRANSITION, G-THEMES and G-FAVOURITES:
- **G-TRANSITION (VisualCoreRendering):** the additive `CrossfadeScene`, which mixes two scenes drawn into render
  targets by a progress value.
- **G-THEMES:**
  - three new fragments (particle drift, wave field, SDF shapes) beside the noise gradient, each with three curated
    palettes, all passing the 4.5 : 1 rule for white text;
  - a `ThemeCatalog` describing themes, palettes and budgets per level.
- **G-FAVOURITES:**
  - `ThemePreset` (kind `a18.theme-preset`, schema 1);
  - favourites in a `NamedLibrary<ThemePreset>` in the experience's storage, capped at 12;
  - snapshot schema 2 (theme and palette) with a migration from schema 1 and registered examples;
  - the controls `theme.select` and `theme.palette`;
  - the editor with save and apply.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contracts:
[contracts/crossfade.md](contracts/crossfade.md) and [contracts/themes.md](contracts/themes.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 and GLSL ES 3.00.
- **Dependencies:** VisualCoreRendering (`RenderTarget`, `ResourceRegistry`, `ShaderProgram`, `RenderContext`),
  VisualCorePersistence (`NamedLibrary`, `MigrationChain`), VisualCoreSimulation (`transitionDuration`),
  VisualCoreUI (`AccessibleColors`), and the A18 targets.
- **Testing:**
  - `VisualCoreRenderingTests` (`CrossfadeSceneTests`) on sim-27.2;
  - `AmbientClockCoreTests` and `AmbientClockExperienceTests` on sim-27.2;
  - the public and documented API, the runner, the app build and the unit tests.
- **Constraints:** tests under 10 s; no wall-clock assert (the crossfade progress is set by the caller); the
  reference regression at X-A18. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: render targets through the host's registry; no second renderer; context ownership stays in the host |
| II-a VisualCore change | PASS: additive `CrossfadeScene` with `///` docs, tests, the API baseline and a README row; existing scenes unchanged; the reference regression at X-A18 |
| IV Pure core | PASS: `ThemePreset` and `ThemeCatalog` validation are pure and GPU-free |
| V Persistence | PASS: the preset schema, the favourites library, and snapshot schema 2 with a migration and examples |
| VI Tests | PASS: crossfade, contrast, theme render, preset, favourites and migration tests |
| VIII Privacy | PASS: storage local to the experience; no network |
| IX Accessibility | PASS: a cut under Reduce Motion; contrast guaranteed by curated palettes |

The A18 rules pass (visuals are code). Post-design: PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreRendering/CrossfadeScene.swift                    new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/CrossfadeSceneTests.swift            new
Packages/VisualCoreRendering/README.md (scene table), docs/api/visualcore-public-api.txt     modify
Packages/ExperiencesCreative/AmbientClock/Core/{ThemePreset,ThemeCatalog}.swift                  new
Packages/ExperiencesCreative/AmbientClock/CoreTests/{ThemePresetTests,ThemeCatalogTests}.swift   new
Packages/ExperiencesCreative/AmbientClock/Experience/{ParticleDriftTheme,WaveFieldTheme,SDFShapesTheme,ThemeShaders,
  AmbientFavourites,AmbientSchemaExamples}.swift                                                 new
Packages/ExperiencesCreative/AmbientClock/Experience/{Adapter/AmbientCore,Adapter/AmbientManifest,AmbientPresenter,
  AmbientControls,NoiseGradientTheme}.swift                                                      modify
Packages/ExperiencesCreative/AmbientClock/ExperienceTests/{ThemeRenderTests,CrossfadeUseTests,FavouritesTests,
  SnapshotMigrationTests}.swift                                                                  new
Packages/ExperiencesCreative/AmbientClock/scenario-manifest.json                                 regenerated
Apps/VisualCore/App/ExperienceRegistry.swift (examples)                                          modify
docs/apps/ambient-clock/visualcore-contract.json (G-THEMES, G-TRANSITION, G-FAVOURITES closed)   modify
docs/apps/ambient-clock/licenses.md (the four shaders, original code)                            new
```

- **Dependency direction:** the experience → the core and VisualCore. `CrossfadeScene` depends only on
  VisualCoreRendering.
- **Lifecycle:**
  - The presenter owns four theme scenes, made lazily when a theme is first shown, and one `CrossfadeScene`.
  - A theme change starts a crossfade (1.2 s with smoothstep, or 0 under Reduce Motion). The presenter sets
    `progress` from the frame time, and once it reaches 1 it draws the incoming scene alone.
  - Setup after a context loss rebuilds the scenes and the targets.
  - Teardown releases them all.
- **Migration:** snapshot schema 1 → 2 (theme 0, palette 0).
- **Rollback:** revert the commits. `CrossfadeScene` is additive and has no other user yet.

## Parallel work

- **Agent V:** the VisualCore crossfade and its tests.
- **Agent C:** the core preset and catalog with their tests.
- **Agent E:** the themes, presenter, favourites, controls and schema examples.
- **Agent T:** the experience tests.
- **Lead:** README, API baseline, registry, manifest, contract, licenses, runs and commits.
