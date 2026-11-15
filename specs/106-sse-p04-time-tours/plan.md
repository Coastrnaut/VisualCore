# Implementation Plan: Solar System Explorer — Phase 04 Time controls and guided tours

**Branch**: `106-sse-p04-time-tours` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Build G-TIME and G-TOURS. VisualCore gains one generic, additive host slot: `ExperiencePresenter.makeCanvasOverlay(_:)`
and `Experience.canvasOverlay` (both default `nil`), drawn by `ExperienceHostView` over the render surface without hit
testing (host tests, README section, API baseline; reference regression at X-A14). The experience core gains the
step-driven clock (play, four rates, range clamp with a reason, `date.set` for "Now"), two catalog-built tours, the
saved view document and state schema 4; the experience gains time and tour controls, a "Now" button with an injected
clock, rate-limited spoken dates, a saved view through `ExperienceStorage`, and an overlay with non-overlapping body
labels and the tour caption. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contracts:
[contracts/canvas-overlay.md](contracts/canvas-overlay.md), [contracts/time-tours.md](contracts/time-tours.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified during clarification): `VisualCoreExperienceHost`
(`ExperiencePresenter`, `Experience`, `ExperienceShell`, `ExperienceHostView` with the canvas and the controls in a
`VStack`; suspension runs no step and does not catch up), `VisualCoreExperience` (`ExperienceStorage.write/read/exists/
remove`, `StorageError`), `VisualCoreMath` (`OrbitCamera.project(_:aspect:)`), `VisualCoreUI` (`AnnouncementSink`,
`RecordingAnnouncementSink`). **Storage**: `view.json` (≤ 4,096 bytes) in the experience's storage. **Testing**: host
tests (`VisualCoreRendering` package, `VisualCoreExperienceHostTests` on sim-27.2); ExperiencesCreative SSE tests on
sim-27.2; app build and unit; runner iOS 27; packages; contract; documented and public API checks; script tests.
**Performance**: labels: nine projections and ≤ 9 boxes per frame; no new meshes. **Constraints**: tests < 10 s, no
wall-clock asserts (the announcement limiter takes an injected clock); iOS 27 only; reference regression and iOS 26 at
X-A14. No NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one app) · II PASS (storage, camera, announcements, host reused) · II-a PASS (additive generic host slot with
defaults, documented, tested, baseline updated; nothing existing changes behaviour; reference regression at X-A14) ·
III PASS (no assets; labels are system text in native views) · IV PASS (clock, tours, saved view, label layout tested
without GPU) · V PASS (state schema 4 with migration from 3; saved view schema 1 with refusals) · VI PASS · VII PASS
(captions and dates spoken, rate-limited; Reduce Motion cuts tour flights; labels never take touches) · VIII PASS (no
network; the saved view stays in app storage) · IX PASS (bounded tours, file size limit) · X PASS · XI–XIII PASS. A14
rules: captions from sourced values; truthful UTC date; deterministic core ("Now" enters as an action) — PASS.
Post-design: PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/{ExperiencePresenter,ExperienceShell,
  ExperienceHostView}.swift                                                                                  modify
Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/CanvasOverlayTests.swift                    new
Packages/VisualCoreRendering/README.md (canvas overlay paragraph), docs/api/visualcore-public-api.txt         modify
Packages/ExperiencesCreative/SolarSystemExplorer/Core/{SimClock,Tours,SavedView}.swift                       new
Packages/ExperiencesCreative/SolarSystemExplorer/Core/{SolarState,SimulatedDate}.swift                       modify
Packages/ExperiencesCreative/SolarSystemExplorer/CoreTests/{SimClockTests,ToursTests,SavedViewTests,
  SolarStateSchema4Tests}.swift; existing state tests adjusted                                               new/modify
Packages/ExperiencesCreative/SolarSystemExplorer/Experience/{LabelLayout,ViewStore,AnnouncementLimiter,
  SolarOverlay}.swift                                                                                        new
Packages/ExperiencesCreative/SolarSystemExplorer/Experience/{Adapter/SolarCore,Adapter/SolarManifest,
  SolarPresenter,SolarControls,SolarSystemExplorerExperience}.swift                                          modify
Packages/ExperiencesCreative/SolarSystemExplorer/ExperienceTests/{LabelLayoutTests,ViewStoreTests,
  AnnouncementLimiterTests,SolarTimeTourSessionTests}.swift; existing tests adjusted                         new/modify
Packages/ExperiencesCreative/SolarSystemExplorer/scenario-manifest.json (regenerated, schema 4)              modify
docs/apps/solar-system-explorer/{visualcore-contract.json (G-TIME, G-TOURS closed), visualcore-contract.md,
  README}                                                                                                    modify
```

**Dependency direction**: unchanged (Core → VisualCoreMath, Foundation; Experience → Core, host, UI, rendering,
scenes); the host slot depends only on SwiftUI.

**Lifecycle**: `update(step:)` advances the clock and the tour (deterministic; no step while suspended). The presenter
reads the state; on selection changes it flies (A14-P03); it saves and restores the view through `ViewStore` on the
user's buttons; it posts announcements through `AnnouncementLimiter` (injected wall clock); the overlay view reads the
presenter's mirror (labels from `LabelLayout` with the drawn camera, the caption). **Migration**: state 3 → 4 adds
paused, rate 0, no tour; saved view schema 1 new. **Rollback**: revert the commits; the host slot is additive.

## Parallel work

Agent A: host slot, its tests and README paragraph (lead runs the host tests and the baseline update). Agent B: core
`SimClock`, `Tours`, `SavedView` and tests. Lead: `SolarState` schema 4, `SolarCore`, manifest. Agent C (after A, B and
the lead): label layout, view store, limiter, overlay, presenter and controls, and their tests.

## Evidence

`python3 Tools/python/desktop_runbook.py run-check --stage A14-P04 --timeout 600 --name <n> -- <cmd>`: `host-overlay`
(xcodebuild_package VisualCoreRendering, CanvasOverlayTests and ExperienceHostViewTests), `visualcore-api`,
`visualcore-docs`, `sse-core-ios27`, `sse-ios27`, `app-unit`, `verify-27`, `experience-packages`, `script-tests`,
`contract`.
