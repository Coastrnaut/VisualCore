# Implementation Plan: VisualCore Music Lab — Phase 05 Audio/render performance and accessibility

**Branch**: `051-ml-p05-performance-accessibility` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

VisualCore gains `AnalysisQuality` (G-AUDIOBUDGET) in `VisualCoreAudioDSP`: level 0/1/2 → window 1,024/512/256, bands
16/16/8, clamped, with a host timing test (asserted locally only). The experience gains `MetricText` and
`AnnouncementGate` (G-A11YMETRICS) in its Core, palettes (`MusicLabPalette`, three fixed palettes) in state schema 3 and
preset format 2, `palette.select`, an 8-value `preset.apply`, tier-driven analysis, metrics in the controls and the
description with rate-limited announcements through an injectable sink, and a transition-fixture test. G-SIGNALTEXTURE
is closed as adapted (row M18 available with primitive/mesh/mapper evidence). Research: [research.md](research.md);
model: [data-model.md](data-model.md); contract: [contracts/api.md](contracts/api.md); evidence:
[quickstart.md](quickstart.md).

## Technical Context

**Language**: Swift 6. **Verified APIs**: `FeatureExtractor(size:sampleRate:bandCount:)` and
`analyze(_:time:elapsed:into:)`, `BandLayout`, `AudioFeatures.bandDB`/`rmsDB`, `draw(_:tier:context:frame:)`,
`AnnouncementSink` and `SystemAnnouncementSink` (VisualCoreUI), `UIAccessibility.isVoiceOverRunning`, `MigrationChain`,
`MusicPreset` format 1 and `MusicLabPresetStore`, `ResumableAudioSource`, `ExperienceSession`/`renderOneFrame`,
`hostsAlive`. **Storage**: state schema 3, preset format 2. **Testing**: host `swift test` (quality, timing); Experiences
on sim-27.2 (metrics, gate, palettes, migration, presets v2, tier, transitions); app build/unit; runner iOS 27; public API;
script tests (catalog). **Constraints**: tests < 10 s; wall-clock asserted only without `CI`; iOS 27 only; reference
regression at X-A06.

## Constitution Check

I PASS (colours through the host renderers) · II PASS (quality configuration in VisualCore; metrics, palettes app-local)
· II-a PASS (G-AUDIOBUDGET built; G-A11YMETRICS app-local justified; G-SIGNALTEXTURE adapted with evidence) · III PASS
(extractor rebuilt on tier change; sink injected; transitions keep lifecycle consistent) · IV PASS (metric text, gate,
palettes host-tested) · V PASS (schema 3 and format 2 migrations; invalid refused) · VI PASS (palettes and transitions
rendered on the simulator) · VII PASS (text metrics without motion or colour; rate-limited announcements) · VIII–XIII
PASS · A06 PASS (metrics labelled approximate visual aids).

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreAudioDSP/AnalysisQuality.swift                                  new
Packages/VisualCore/Tests/VisualCoreAudioDSPTests/{AnalysisQualityTests,AnalysisTimingTests}.swift     new
Packages/ExperiencesCreative/VisualCoreMusicLab/Core/{MetricText,MusicLabPalette}.swift                new
Packages/ExperiencesCreative/VisualCoreMusicLab/Core/{MusicLabState,MusicPreset}.swift                 modify (palette; schema 3; format 2)
Packages/ExperiencesCreative/VisualCoreMusicLab/CoreTests/{MetricTextTests,MusicLabPaletteTests}.swift new; MusicLabStateTests, MusicPresetTests modify
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/Adapter/MusicLabCore.swift                  modify (palette.select, preset.apply 8 values, migration 2→3, digest)
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/{MusicLabPresenter,MusicLabScenes,MusicLabControls,MusicLabPresetStore,VisualCoreMusicLabExperience}.swift  modify
Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/{MusicLabMetricsTests,MusicLabTransitionTests}.swift  new; core/scene/preset tests modify
Packages/ExperiencesCreative/VisualCoreMusicLab/scenario-manifest.json, Catalog/registrations.json (quality_tiers)  regenerate / modify
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Auto-Creator.md §13, docs/apps/visualcore-music-lab/visualcore-contract.{json,md}  modify
```

**Dependency direction**: unchanged (experience → VisualCoreAudioDSP, VisualCoreUI for the sink protocol through the host
product it already uses; Core stays audio-free).

**Lifecycle**: per frame the presenter maps `tier` → level; on change it rebuilds the extractor and resets mappers; after
analysis it updates the metric text and asks the gate whether to announce. **Migration**: state 2 → 3 (palette 0);
preset format 1 → read as palette 0, written as format 2. **Rollback**: revert; format-2 presets are counted as newer by
an older build (kept, never rewritten).

## Parallel work

Agent A: AnalysisQuality + tests. Agent B: MetricText + AnnouncementGate + tests. Agent C: MusicLabPalette + tests.
Lead: state/preset/core changes, presenter, scenes, controls, experience tests, catalog, manifest, docs, runs, commits.
