# Implementation Plan: Audio Odyssey — Phase 04 Multi-world presets and UI

**Branch**: `057-ao-p04-presets-ui` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Experience-only slice. Core gains `JourneyPreset` (fields, format-1 file coding with sorted keys, name cleaning and
uniqueness, three built-ins, `actionValues` for `preset.apply`) and `DemoResponseTrace` (deterministic envelope →
response trace for a seed and step count, host-testable). The experience gains `JourneyPresetStore` over
`ExperienceStorage` (list, save, rename, delete; unreadable/newer counted), the `preset.apply` action, a grouped control
layout (Journey, Sound with a segmented source picker and status, Comfort, Journeys with list/save/rename/delete) and
the fixture tests. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: unchanged. **Storage**: one file per user preset
`journey-<lowercased uuid>.json` (format 1) in the experience's storage; snapshot schema stays 3 (presets are files, the
selected preset id is display state). **Testing**: ExperiencesCreative on sim-27.2 (Core: preset coding, names,
built-ins, trace; experience: store with an in-memory or temporary storage, apply through the core, source picker
states, demo trace through the presenter); app build and unit; runner iOS 27; script tests; public API unchanged.
**Constraints**: tests < 10 s; fixed steps, no wall clock; iOS 27 only.

## Constitution Check

I PASS · II PASS (no generic machinery; preset rules per experience as A06) · II-a PASS · III PASS (store reloaded on
activate; source lifecycle unchanged) · IV PASS (preset coding and trace pure) · V PASS (preset files versioned; newer
refused, never rewritten) · VI PASS · VII PASS (grouped, labelled controls; spoken status) · VIII PASS (no audio in
presets; storage local only) · IX PASS (quota errors surfaced; name ≤ 60) · X PASS · XI–XIII PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/AudioOdyssey/Core/{JourneyPreset,DemoResponseTrace}.swift                          new
Packages/ExperiencesCreative/AudioOdyssey/CoreTests/{JourneyPresetTests,DemoResponseTraceTests}.swift            new
Packages/ExperiencesCreative/AudioOdyssey/Experience/JourneyPresetStore.swift                                    new
Packages/ExperiencesCreative/AudioOdyssey/Experience/{Adapter/OdysseyCore,Adapter/OdysseyManifest,OdysseyPresenter,
  OdysseyControls,AudioOdysseyExperience}.swift                                                                  modify
Packages/ExperiencesCreative/AudioOdyssey/ExperienceTests/{JourneyPresetStoreTests,OdysseyPresetApplyTests,
  OdysseySourcePickerTests,OdysseyDemoTraceTests}.swift                                                          new
Packages/ExperiencesCreative/AudioOdyssey/scenario-manifest.json                                                  regenerate
```

**Dependency direction**: unchanged. **Lifecycle**: the store is created by the factory with the experience's storage
and reloaded in the presenter's `setup()`, which runs on every open and on context recovery (the presenter protocol
has no activate hook; convergence T-A07-413). **Migration**: none (snapshot schema 3 unchanged; preset format 1 new). **Rollback**: revert.

## Parallel work

Agent A: Core JourneyPreset + DemoResponseTrace + tests. Agent B (after A): store, action, presenter, controls,
manifest, experience tests. Lead: runs, ticks, commits.
