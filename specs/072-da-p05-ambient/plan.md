# Implementation Plan: Digital Aquarium — Phase 05 Ambient device testing and release content

**Branch**: `072-da-p05-ambient` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-AMBIENT and the manual's Phase 05 gates in the experience, with no VisualCore change. Core: `AquariumBudget`
(particle and caustics budgets per quality level and ambient, the smaller wins), an `ambient` speed factor in
`AquariumSimulation.advance` (cruise × 0.6; speed floor scales), `AquariumConfiguration` (the saved configuration,
format 1, its validation and the action list that rebuilds it), and `AmbientDimmer` (idle clock 60 s, fade 2 s to
0.6, restore on touch). Experience: actions `ambient.mode [0…1]` and `decor.turn [index, rotation, scale]`, snapshot
schema 4 (`ambient`), `qualityTiers` 3 with registration levels 0…2, `AquariumLibrary` (files `aquarium-<uuid>.json`
in the experience's storage, at most 12, unreadable and newer counted), the presenter applying the budget, the dimmer's
colour scale and Low Power Mode / Reduce Motion as ambient drawing, controls for ambient and the library, manifest
fixtures 12 and 13, the device-campaign document. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A09-P04; `ExperienceStorage` (write/read/list/remove, quota),
`ExperienceActionPort.send`, the host's `draw(_:tier:context:frame:)` tier and `ResourceRegistry.stats` (all verified
in the clarification session). **Storage**: snapshot schema 4 (`ambient`, missing → off; chain 3 → 4); configuration
files format 1 in the experience's storage. **Testing**: ExperiencesCreative on sim-27.2; app build and unit (registry
quality tiers); runner iOS 27; script tests. **Performance**: budgets only lower work. **Constraints**: tests < 10 s;
iOS 27 only; device measurements planned, not run.

## Constitution Check

I PASS (no context; colour scaling inside the existing drawing) · II PASS (ambient policy, budgets, library are
experience domain over shared storage, governor and port) · II-a PASS (no VisualCore change) · III PASS (dimmer and
library live in the presenter, reset on teardown; suspension unchanged) · IV PASS (pure core budget, configuration,
dimmer) · V PASS (schema 4 with chain step; configuration format 1 with newer files counted) · VI PASS (render tests
per level and dimming) · VII PASS (labelled controls for ambient and library; announcements unchanged) · VIII PASS
(files stay on the device; no new permission or network; no system brightness call) · IX PASS (12-file limit, quota,
damaged files skipped) · X–XIII PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/DigitalAquarium/Core/AquariumBudget.swift                                   new
Packages/ExperiencesCreative/DigitalAquarium/Core/AmbientDimmer.swift                                    new
Packages/ExperiencesCreative/DigitalAquarium/Core/AquariumConfiguration.swift                            new
Packages/ExperiencesCreative/DigitalAquarium/Core/AquariumSimulation.swift (speed factor)                 modify
Packages/ExperiencesCreative/DigitalAquarium/Core/WaterEffects.swift (per-vent and mote limits as inputs) modify
Packages/ExperiencesCreative/DigitalAquarium/CoreTests/{AquariumBudgetTests,AmbientDimmerTests,
  AquariumConfigurationTests,LongRunTests}.swift                                                          new
Packages/ExperiencesCreative/DigitalAquarium/Experience/Adapter/AquariumCore.swift (ambient, decor.turn,
  schema 4, qualityTiers 3)                                                                                modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/AquariumLibrary.swift                             new
Packages/ExperiencesCreative/DigitalAquarium/Experience/{AquariumPresenter,AquariumControls,CausticsScene,
  DigitalAquariumExperience}.swift (budget, dimmer, low power, library, controls)                          modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/Adapter/AquariumManifest.swift (fixtures 12, 13)  modify
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/{AquariumCoreTests,AquariumRenderTests,
  AquariumSessionTests,AquariumManifestTests}.swift, AquariumLibraryTests.swift (new)                      modify/new
Packages/ExperiencesCreative/DigitalAquarium/scenario-manifest.json                                       regenerate
Catalog/registrations.json (a09 quality_tiers level-0…2)                                                  modify
Apps/VisualCore/App/ExperienceRegistry.swift (schema-3 example)                                           modify
docs/apps/digital-aquarium/device-campaign.md                                                             new
docs/apps/digital-aquarium/visualcore-contract.{json,md} (G-AMBIENT closed; M14–M16 notes)              modify
```

**Dependency direction**: experience → DigitalAquariumCore → VisualCoreMath, VisualCoreSimulation; experience →
VisualCoreExperience (storage), VisualCoreRendering, VisualCoreUI; nothing in VisualCore depends on the aquarium.

**Lifecycle**: the library loads on presenter setup when storage exists and refreshes after each save or delete; the
dimmer's clock advances with drawn frames (so a suspension stops it) and resets on teardown and on every touch.
**Migration**: snapshot 3 → 4 adds `ambient` false; stored `schemaThreeExample()` for the registry. Configuration
format 1; a greater format is counted as newer. **Rollback**: revert the commits; saved configuration files are
ignored by older builds (no release exists).

## Build and evidence

See [quickstart.md](quickstart.md); each command runs through
`python3 Tools/python/desktop_runbook.py run-check --stage A09-P05 --timeout 600 --name <check> -- <command>`.

## Parallel work

Agent A: `AquariumBudget`, `AmbientDimmer`, `WaterEffects` limits, ambient speed in `AquariumSimulation`,
`LongRunTests` and their tests. Agent B: `AquariumConfiguration` + tests and `AquariumLibrary` + tests. Lead:
`AquariumCore` (actions, schema 4, tiers), registry and registrations, manifest fixtures. Agent C (after A, B and the
lead): presenter, controls, caustics octave switch, render and session tests. Lead: device-campaign document, contract,
runs, commits.
