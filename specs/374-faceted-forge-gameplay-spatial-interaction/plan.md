# Implementation Plan: R02-G08-04 — Faceted Forge: gameplay spatial interaction

**Branch**: `374-faceted-forge-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Give Faceted Forge its gestures, following Amethyst Escape's R02-G07-04 in the same package: in the host-tested Core an
orbit (`FacetedForgeOrbit`, `camera(_:aspect:orbit:)`), an analytic picker (`FacetedForgePicker`: the touch ray against
the opened preview rim and polygon and the opened pieces' faces, the 22-point minimum target, the rim tilt and the
depth steps along the projected normal) and the gesture controller (`FacetedForgeGestureController`: idle, rim drag,
depth drag, plane press, piece press, orbiting, cancelled; a new preview choice from taps and drags, one `piece.cut` per
tap on the plane, view reset on a double tap on empty space); in the experience the presenter's pointer entry, the
candidate preview while dragging, and "Reset view" in the panel; host tests with an independent pick, tilt and step, a
host test that wins all 100 levels through panel actions, and simulator wiring tests. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-22)**: `Packages/ExperiencesRound02/Package.swift` already has `FacetedForgeCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience), `FacetedForgeExperience` (iOS rendering dependencies) and
their test targets (R02-G08-03); `project.yml` links both products into the one app; no new target or scheme is needed.
**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`) and
VisualCoreMath (`Vec2`, `Mat4`) as Amethyst Escape's gesture controller uses them; the Faceted Forge Core of R02-G08-01
… 03; VisualCoreExperienceHost (pointer events) in the experience. No new package, target, GLSL, Objective-C++ or
VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_374.
**Constraints**: presentation-only orbit and preview choice; tap distance 10 points, drag distance 16 points, minimum
target 22 points, tap duration 0.5 s and double tap 0.35 s by event timestamps; 24 points per depth step; tests under
10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; cuts are sent through the kernel's declared control. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; choices clamped; cuts validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — the preview reuses the generated meshes and existing programs. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSceneGeometry.swift          edit  orbit, camera(_:aspect:orbit:) (agent B)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgePicker.swift                  new   touch ray, rim, plane, pieces, tilt, depth steps (agent B)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeGestureController.swift       new   arbitration, taps, rim and depth drags, commit, double taps, orbit (agent C)
Packages/ExperiencesRound02/FacetedForge/CoreTests/{FacetedForgePickerTests (B), FacetedForgeGestureControllerTests (C), FacetedForgePanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeSceneGeometryTests.swift edit  orbit framing (agent B)
Packages/ExperiencesRound02/FacetedForge/Experience/{FacetedForgePresenter, FacetedForgeCrystalScene, FacetedForgeControls}.swift  edit (lead)
Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeGestureWiringTests.swift   new   (agent E)
docs/architecture/faceted-forge.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: orbit and picker → gesture controller → presenter wiring → wiring tests; the panel win test needs
only the adapter and the preview choice. **CI checks**: the package host tests, the simulator package tests, app-unit,
the reference regression and the script tests, as for R02-G08-03. **Migration**: none (snapshot schema 1; orbit and the
preview choice are not saved). **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agent B (orbit, picker) and agent D (panel win test) in parallel, then agent C (gesture controller) on B's picker; the
lead wires the presenter, scene and controls; agent E writes the simulator wiring tests. The lead retests every result.
