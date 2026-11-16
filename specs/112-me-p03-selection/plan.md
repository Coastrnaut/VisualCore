# Implementation Plan: Molecular Explorer — Phase 03 Selection and display styles

**Branch**: `112-me-p03-selection` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Build G-PICK and G-PANEL and the gestures and panning moved from A15-P02, with no VisualCore change: in the core a pure
atom picker (line of sight against drawn spheres, nearest wins), a label layout without overlaps, bond styles from
order and provenance, the camera's pan steps and state schema 3 (pan, selected atom) with a migration from schema 2; in
the experience the canvas gestures over VisualCore's arbiter, the new actions and controls (pan, atom previous / next /
clear), the drawing of bond styles, the canvas overlay with labels and the selection ring, the metadata panel, the
selected atom in the canvas description and announcements, and two new manifest fixtures. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/selection.md](contracts/selection.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified in the clarification session): `VisualCoreMath` (`Ray3`,
`Ray3.intersect(sphereCenter:radius:)`, `Ray3.nearest`, `OrbitCamera.ray(ndc:aspect:)`), `VisualCoreScenes`
(`GestureArbiter`, `DragRecognizer`, `PinchRecognizer`, `TapRecognizer`, `PointerEvent`), `VisualCoreRendering`
(`MeshRenderer`, `DepthMeshPass`), `VisualCoreExperienceHost` (`pointer(_:viewSize:port:)`, `makeCanvasOverlay`).
**Storage**: the session state (schema 3). **Testing**: core and experience tests in ExperiencesCreative on sim-27.2
(synthetic pointer events); app build and unit; runner iOS 27; packages; contract; documented API; script tests.
**Performance**: picking tests at most 24 spheres per tap; labels at most 24 boxes; bond styles at most 3 sticks per
bond half (caffeine 2 × (21 + 4 × 2) = 58 sticks); within the 1,500-item budget. **Constraints**: tests < 10 s; iOS 27
only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one renderer) · II PASS (gestures, rays, camera, overlay slot reused; no upstream change) · II-a N/A · III PASS
· IV PASS (picker, labels, bond styles, pan and state tested without GPU; gestures as pure values with synthetic events)
· V PASS (schema 3 with a migration from 2) · VI PASS · VII PASS (every gesture has a control; bond order and
provenance not by colour alone; panel and description speak the selection; one announcement per action) · VIII PASS ·
IX PASS (limits on pan, label boxes, items) · X PASS · XI–XIII PASS. A15 rules: inferred bonds marked, truthful,
bounded, GPU-free rules — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/MolecularExplorer/Core/{AtomPicker,LabelLayout,BondStyle}.swift                    new
Packages/ExperiencesCreative/MolecularExplorer/Core/{CameraSettings (pan),MoleculeState (schema 3),
  MoleculeScene (styled sticks)}.swift                                                                          modify
Packages/ExperiencesCreative/MolecularExplorer/CoreTests/{AtomPickerTests,LabelLayoutTests,BondStyleTests,
  MoleculeStateSchema3Tests}.swift; existing core tests updated                                                 new/modify
Packages/ExperiencesCreative/MolecularExplorer/Experience/{MoleculeGestures,MoleculeOverlay}.swift               new
Packages/ExperiencesCreative/MolecularExplorer/Experience/{Adapter/MoleculeCore.swift, Adapter/MoleculeManifest.swift,
  MoleculePresenter.swift, MoleculeControls.swift}                                                              modify
Packages/ExperiencesCreative/MolecularExplorer/ExperienceTests/{MoleculeGestureTests,MoleculePickingTests,
  MoleculePanelTests}.swift; existing experience tests updated                                                  new/modify
scenario-manifest.json (regenerated); docs/apps/molecular-explorer/visualcore-contract.json (G-PICK, G-PANEL closed) modify
```

**Dependency direction**: Experience → Core → VisualCoreMath and Foundation; the experience → scenes, rendering, host,
UI; nothing in VisualCore depends on the experience.

**Lifecycle**: gestures are a value owned by the presenter, fed by `pointer(_:viewSize:port:)`, sending actions through
the port; `reset()` on suspension and teardown. Picking reads the last drawn camera and scene (the frame the person
sees). The overlay reads the presenter's mirror only, reports its size, never takes touches. Renderers as before (two,
made and released together). **Migration**: schema 2 → 3 (no selection, no pan) through the adapter's chain.
**Rollback**: revert the commits.

## Parallel work

Agent A: core files and core tests (contracts/selection.md). Agent B: experience changes and tests after A. Lead:
manifest, contract, runs, commits.
