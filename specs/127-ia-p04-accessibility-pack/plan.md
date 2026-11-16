# Implementation Plan: Interactive Anatomy — Phase 04 Accessibility and offline content

**Branch**: `127-ia-p04-accessibility-pack` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-LABELS, G-A11Y and G-PACK, plus the camera gestures.

- **VisualCore** (additive, in `VisualCoreMath`):
  - `AnchoredLabelLayout`: candidates, projection, culling, priority order, overlap skipping and a budget;
  - with docs, tests, the README row and the API baseline.
- **Core:**
  - `AnatomyLayerSign` (three signs that pass `stateSignProblems`);
  - `AnatomyLabels` (candidates for the layout);
  - `AnatomyContentPack` (envelope `a17.content-pack` at schema 2, migration from the bare region, cap, digest);
  - `AnatomyProvenance` and its check;
  - the network-free source check;
  - the bundled resource moves to `knee-right.pack.json`.
- **Experience:**
  - `AnatomyGestures` (drag, pinch and tap through `GestureArbiter`);
  - the canvas overlay with the labels;
  - announcements through `AnnouncementPlanner` with an injectable sink;
  - list rows with signs; the limit sentence.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/accessibility-pack.md](contracts/accessibility-pack.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6.
- **New core dependency:** `VisualCoreSimulation` (pure: `StateSign`, `stateSignProblems`, `AnnouncementPlanner`).
- **VisualCoreMath:** `OrbitCamera.project`, `StableHash`, `Vec2`, `Vec3`.
- **Experience:** `GestureArbiter` and its recognizers (`VisualCoreScenes`), `makeCanvasOverlay`
  (`VisualCoreExperienceHost`).
- **Storage:** none new; the pack is a bundle resource.
- **Testing:**
  - `VisualCoreMathTests` (host `swift test --package-path Packages/VisualCore --filter AnchoredLabelLayoutTests`);
  - core and experience tests on sim-27.2;
  - public and documented API, app build and unit, runner, packages, catalog, scripts.
- **Constraints:** tests under 10 s. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: labels are an overlay of the host; no GL |
| II | PASS: the third consumer promotes the generic layout to VisualCoreMath; A14 and A15 are left unchanged by rule |
| II-a | PASS: additive, documented, tested, API baseline, README row; the reference regression at X-A17 |
| III | PASS |
| IV | PASS: layout, signs, pack and provenance are tested without a GPU |
| V | PASS: pack schema 2 with a migration from 1; typed refusals |
| VI | PASS |
| VII | PASS: signs not by colour alone; announcements; list rows spoken with layer words |
| VIII | PASS: a bundled pack; the no-network check |
| IX | PASS: label budget 16; pack cap 256 KB |
| X–XIII | PASS |

A17 rules: provenance and the not-reviewed label in the pack: PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/AnchoredLabelLayout.swift                                  new
Packages/VisualCore/Tests/VisualCoreMathTests/AnchoredLabelLayoutTests.swift                          new
Packages/VisualCore/README.md (the VisualCoreMath table); docs/api/visualcore-public-api.txt          modify
Packages/ExperiencesCreative/Package.swift (core + VisualCoreSimulation)                              modify
Packages/ExperiencesCreative/InteractiveAnatomy/Core/Content/knee-right.pack.json (replaces knee-right.json) new
Packages/ExperiencesCreative/InteractiveAnatomy/Core/{AnatomyLayerSign,AnatomyLabels,AnatomyContentPack,
  AnatomyProvenance}.swift; AnatomyContent.swift (bundled pack)                                       new/modify
Packages/ExperiencesCreative/InteractiveAnatomy/CoreTests/{LayerSignTests,LabelCandidateTests,ContentPackTests,
  ProvenanceTests,NoNetworkTests}.swift                                                                new
Packages/ExperiencesCreative/InteractiveAnatomy/Experience/{AnatomyGestures,AnatomyOverlay}.swift new;
  AnatomyPresenter, AnatomyControls, Adapter/AnatomyCore modify
Packages/ExperiencesCreative/InteractiveAnatomy/ExperienceTests/{AnatomyGestureTests,AnatomyLabelTests,
  AnatomyAnnouncementTests}.swift                                                                     new
docs/apps/interactive-anatomy/{content-sources.md (pack path), visualcore-contract.json}             modify
```

**Dependency direction:** the experience → the core → VisualCoreMath, VisualCoreScenes, VisualCoreExperience,
VisualCorePersistence and VisualCoreSimulation. VisualCoreMath gains no dependency.

**Lifecycle:**
- The presenter lays out the labels after each drawn frame from the last camera, aspect and canvas size, and the
  overlay reads them. A camera change relays them out.
- Announcements are submitted on selection change and flushed on later frames.
- The pack is decoded once and cached, like the bundled region today.

**Migration:** pack 1 (a bare region) → 2 (the envelope). **Rollback:** revert the commits; restoring the bare
resource returns the A17-P03 loading.

## Parallel work

- **Agent V:** `AnchoredLabelLayout` and its tests.
- **Agent C:** the core files, the pack resource and the core tests.
- **Agent E, after V and C:** the experience changes and tests.
- **Lead:** Package.swift, the API baseline, the README, contract, runs, commits.
