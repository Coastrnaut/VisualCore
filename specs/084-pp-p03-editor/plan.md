# Implementation Plan: Physics Playground — Phase 03 Gesture editor and overlays

**Branch**: `084-pp-p03-editor` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-EDITOR and G-OVERLAYS in the experience, with no VisualCore change: the core gains editing operations (add,
select, grab with a critically damped pull, move, release, pin, delete, nudge), pinned bodies as static, overlay
settings and force measurement, and world schema 3 with the 2 → 3 migration; the adapter gains the eleven edit and
overlay actions; the presenter maps tap, double-tap, long-press and drag (through VisualCore's recognizers and arbiter)
to those actions, draws velocity and force arrows and the grab line, and the controls add the selection, pin, delete,
add, nudge, shape and overlay controls and the state panel. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Actions: [contracts/actions.md](contracts/actions.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: unchanged from A11-P02 (`VisualCoreScenes` recognizers `TapRecognizer`,
`DoubleTapRecognizer`, `LongPressRecognizer`, `DragRecognizer`, `GestureArbiter`, `PointerEvent`; `Primitive.line`,
`.polygon`; `Springs2D.stableStiffness`, `Springs2D.apply`). **Storage**: snapshot schema 3. **Testing**:
ExperiencesCreative on sim-27.2 (core and experience tests); app build and unit; runner iOS 27; experience packages;
contract; script tests. No VisualCore host or public-API run is needed (no VisualCore change; the API check runs in
the script tests' release steps unchanged). **Performance**: arrows ≤ 3 per body (≤ 144 + panel); gesture handling
per pointer event is constant work plus one hit test over ≤ 48 bodies. **Constraints**: tests < 10 s; iOS 27 only; no
NEEDS CLARIFICATION remains.

## Constitution Check

I PASS · II PASS (VisualCore recognizers, arbiter, springs and primitives reused; editing and overlays are app-local
as the contract assigns) · II-a N/A (no VisualCore change) · III PASS · IV PASS (edits and measurements tested
without GPU) · V PASS (schema 3, migration, stored schema-2 example) · VI PASS · VII PASS (every gesture has a native
control; panel and arrows described; Reduce Motion has nothing decorative to calm) · VIII PASS · IX PASS (body cap and
stage bounds enforced on add) · X PASS · XI–XIII PASS. A11 rules: truthful claims (panel labelled), authoritative
physics, accessibility alternatives — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/PhysicsPlayground/Core/{WorldEditing,ForceMeasurement}.swift                       new
Packages/ExperiencesCreative/PhysicsPlayground/Core/{PhysicsWorld,WorldSimulation,StartingScene}.swift          modify
Packages/ExperiencesCreative/PhysicsPlayground/CoreTests/{WorldEditingTests,PinFixtureTests,ForceMeasurementTests}.swift new; others updated
Packages/ExperiencesCreative/PhysicsPlayground/Experience/PlaygroundGestures.swift                               new
Packages/ExperiencesCreative/PhysicsPlayground/Experience/{Adapter/PlaygroundCore,Adapter/PlaygroundManifest,
  PlaygroundPresenter,PlaygroundControls}.swift                                                                 modify
Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/{PlaygroundGestureTests}.swift                    new; others updated
Packages/ExperiencesCreative/PhysicsPlayground/scenario-manifest.json                                            regenerate
Apps/VisualCore/App/ExperienceRegistry.swift (schema-2 example), Catalog/registrations.json (capabilities)         modify
docs/apps/physics-playground/visualcore-contract.json (G-EDITOR, G-OVERLAYS closed; M05, M08, M11 available)       modify
```

**Dependency direction**: unchanged. **Lifecycle**: gestures produce actions through the port only; the presenter
keeps transient gesture state (current recognizers, pointer positions) outside the world and resets it on suspend and
teardown; a cancelled gesture sends `edit.release`. **Migration**: 2 → 3 in `PlaygroundCore.migrations`;
`schemaTwoExample()` stored for the registry. **Rollback**: revert the commits.

## Parallel work

Agent A: core editing, pinning, force measurement, schema 3 and their tests. Agent B (after A): adapter actions,
gestures, presenter arrows, controls, panel, manifest fixtures and experience tests. Lead: registry example,
registration, contract, runs, commits.
