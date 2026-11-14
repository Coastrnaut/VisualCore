# Implementation Plan: Oscilloscope Studio — Phase 03 Spectrum and XY modes

**Branch**: `063-os-p03-spectrum` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-SPECTRUMLABELS (app-local). In the core: `ScopeDisplay.spectrum`, `SpectrumView` (log-frequency column mapping
of bins, strongest bin per column, level axis 0…−100 dBFS, decade and level marks) and `SpectrumReadout` (peak frequency
and level with its validity: no signal, clipping, filling). In the experience: the presenter reads the newest 4,096
frames of the left (or only) channel, analyses them with `SpectrumAnalyzer(size: 4096)`, draws the marks as grid lines
and the curve as one polyline, and states the readout in the status text and the description; the controls' View
picker gains Spectrum; the manifest gains the spectrum and mono-XY fixtures. No VisualCore change. Research:
[research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A08-P02 (no new product). **Storage**: experience snapshot (`ScopeState`
schema 2, `display` value range 0…2). **Testing**: ExperiencesCreative on sim-27.2 (`SpectrumViewTests`,
`SpectrumReadoutTests`, state tests; adapter, manifest, session, render); app build and unit; runner iOS 27; experience
package check; contract check; script tests. **Performance**: one 4,096-point transform per drawn frame (the analyser's
workspace is allocated once by the presenter); no wall-clock assert. **Constraints**: tests < 10 s; iOS 27 only;
reference regression at X-A08; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (draws through the host's renderer) · II PASS (reuses `SpectrumAnalyzer`, `Primitive.polyline`; labels and
readout are experience domain) · II-a PASS (no VisualCore change) · III PASS (lifecycle unchanged) · IV PASS (view and
readout host-free, tested with synthetic sines) · V PASS (schema 2 unchanged in shape) · VI PASS (render tests) · VII
PASS (readout spoken and shown in text; no colour-only cue) · VIII PASS (no new data or permission; "dBFS, relative to
full scale") · IX PASS (fixed 4,096 frame, ≤ 4,096 columns) · X–XIII PASS. A08 rules: truthful units (no SPL or volts),
bounded resources — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/OscilloscopeStudio/Core/ScopeSettings.swift (ScopeDisplay.spectrum)        modify
Packages/ExperiencesCreative/OscilloscopeStudio/Core/{SpectrumView,SpectrumReadout}.swift              new
Packages/ExperiencesCreative/OscilloscopeStudio/CoreTests/{SpectrumViewTests,SpectrumReadoutTests,ScopeStateTests}.swift new/modify
Packages/ExperiencesCreative/OscilloscopeStudio/Experience/{Adapter/ScopeCore,Adapter/ScopeManifest,ScopePresenter,
  ScopeControls}.swift, ExperienceTests/{ScopeCoreTests,ScopeManifestTests,ScopeSessionTests,ScopeRenderTests}.swift modify
Packages/ExperiencesCreative/OscilloscopeStudio/scenario-manifest.json                                  regenerate
docs/apps/oscilloscope-studio/visualcore-contract.json (G-SPECTRUMLABELS closed)                        modify
```

**Dependency direction**, **lifecycle** and **rollback** as A08-P02; the presenter owns one `SpectrumAnalyzer` created
on first use. **Migration**: none (the display field's range widens; A08-P02 snapshots restore unchanged).

## Parallel work

Agent A: core `SpectrumView`, `SpectrumReadout`, `ScopeDisplay.spectrum` + tests. Agent B: presenter, controls,
adapter, manifest and experience tests after A. Lead: contract, manifest regeneration, runs, commits.
