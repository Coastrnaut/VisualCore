# Implementation Plan: Light Maze — Phase 02 Rendering and tap interactions

**Branch**: `097-lm-p02-interaction` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-SNAP and G-BEAMS in the experience, with no VisualCore change: a pure `MazeGestures` value type over
VisualCore's `GestureArbiter` (tap, drag, rotate) resolving canvas points to cells through the presenter's board camera
and sending only `tile.select` and `tile.turn`; the presenter's beam drawn with a halo and a core line, lit targets with
rings and the selected tile with an outline; spoken beam changes rate-limited to one per second; committed loop
fixtures in the core. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/interaction.md](contracts/interaction.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreScenes` (`TapRecognizer`, `DragRecognizer`, `RotateRecognizer`,
`GestureArbiter`, `GestureDeclaration`, `GestureOutcome`, `SceneNode`, `Primitive`), `VisualCoreMath` (`Camera2D`,
`Vec2`), `VisualCoreRendering` (`PrimitiveRenderer`), `VisualCoreUI` (`AnnouncementSink`), `VisualCoreExperienceHost`
(gesture alternatives check). **Storage**: unchanged (state schema 1). **Testing**: ExperiencesCreative on sim-27.2
(`LightMazeCoreTests`, `LightMazeExperienceTests`); app build and unit; runner iOS 27; packages; contract; script tests.
**Performance**: at most one scene rebuild per state change; the glow adds one primitive per segment (≤ 256).
**Constraints**: tests < 10 s; iOS 27 only; reference regression and iOS 26 at X-A13; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (drawing stays in the host's primitive renderer) · II PASS (VisualCore gestures and arbiter reused; nothing new
upstream) · II-a N/A (no VisualCore change) · III PASS (gestures only send actions) · IV PASS (gestures and loops
tested without GPU) · V PASS (no schema change) · VI PASS (render tests) · VII PASS (every gesture action has a native
control; shapes beside colour; spoken changes rate-limited) · VIII PASS · IX PASS (glow and segment caps) · X–XIII PASS.
A13 rules: the beam from the CPU tracer only, no shader deciding the solved state, nothing flashes — PASS. Post-design:
PASS.

## Project Structure

```text
Packages/ExperiencesCreative/LightMaze/Experience/MazeGestures.swift                                       new
Packages/ExperiencesCreative/LightMaze/Experience/{MazePresenter,LightMazeExperience}.swift                modify
Packages/ExperiencesCreative/LightMaze/ExperienceTests/{MazeGestureTests,MazeGlowTests}.swift              new
Packages/ExperiencesCreative/LightMaze/ExperienceTests/{MazeRenderTests,MazeSessionTests}.swift            modify
Packages/ExperiencesCreative/LightMaze/CoreTests/LoopFixtureTests.swift                                    new
docs/apps/light-maze/visualcore-contract.json (G-SNAP and G-BEAMS closed by A13-P02; rows M04, M07, M10, M12)  modify
```

**Dependency direction**: unchanged. **Lifecycle**: `MazeGestures` holds only touch state, reset on suspension and
teardown; the presenter maps view points to board units with the inverse of its camera of the last frame; gestures send
through the caller's port; the scene tree is rebuilt only when the state digest changes; announcements are sent on the
presenter's frame clock. **Migration**: none. **Rollback**: revert the commits.

## Parallel work

Agent A: `LoopFixtureTests.swift` (core). Agent B: `MazeGestures.swift` and `MazeGestureTests.swift`. Lead: presenter
glow and announcements, wiring, render tests, contract, runs, commits.
