# Implementation Plan: R02-G07-04 — Amethyst Escape: gameplay spatial interaction

**Branch**: `364-amethyst-escape-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Give Amethyst Escape its gestures, following Chrono Constellator's R02-G06-04 in the same package: in the host-tested
Core an orbit (`AmethystEscapeOrbit`, `camera(_:aspect:orbit:)`), an analytic picker (`AmethystEscapePicker`: the touch
ray against the pearl sphere and the shells' top planes, the 22-point minimum target, the drag angle on a shell's plane),
a preview snapshot (`previewing(shell:sectors:)`), shell isolation in the geometry and the gesture controller
(`AmethystEscapeGestureController`: idle, shell drag, pearl press, orbiting, cancelled; |n| one-sector turns per shell
drag, an advance per pearl tap, shell selection on a tap, isolation and view reset on double taps); in the experience
the presenter's pointer entry, the drag preview, isolation and "Show all layers" and "Reset view" in the panel; host
tests with an independent pick and angle, a host test that wins all 100 levels through panel actions, and simulator
wiring tests. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-22)**: `Packages/ExperiencesRound02/Package.swift` already has `AmethystEscapeCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience), `AmethystEscapeExperience` (iOS rendering dependencies) and
their test targets (R02-G07-03); `project.yml` links both products into the one app; no new target or scheme is needed.
**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`,
`PointerTracker`) and VisualCoreMath (`Vec2`, `Mat4`) as Chrono Constellator's gesture controller uses them; the Amethyst
Escape Core of R02-G07-01 … 03; VisualCoreExperienceHost (pointer events) in the experience. No new package, target,
GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_364.
**Constraints**: presentation-only orbit and isolation; tap distance 10 points, drag distance 16 points, minimum target
22 points, tap duration 0.5 s and double tap 0.35 s by event timestamps; at most ⌊S/2⌋ turns per drag; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; turns are whole sectors sent through the kernel. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — the preview and isolation reuse the generated meshes and existing programs. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSceneGeometry.swift            edit  orbit, camera(_:aspect:orbit:), isolation shade (agent B)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSceneSnapshot.swift            edit  previewing(shell:sectors:) (lead)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapePicker.swift                    new   touch ray, pearl sphere, shell planes, angle, minimum target (agent B)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeGestureController.swift         new   arbitration, shell drag, pearl tap, double taps, orbit, reset (agent C)
Packages/ExperiencesRound02/AmethystEscape/CoreTests/{AmethystEscapePickerTests (B), AmethystEscapeGestureControllerTests (C), AmethystEscapePanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeSceneGeometryTests.swift   edit  orbit framing, isolation (agent B)
Packages/ExperiencesRound02/AmethystEscape/Experience/{AmethystEscapePresenter, AmethystEscapeCrystalScene, AmethystEscapeControls}.swift  edit (lead)
Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeGestureWiringTests.swift   new   (agent E)
docs/architecture/amethyst-escape.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: snapshot preview, orbit and picker → gesture controller → presenter wiring → wiring tests; the
panel win test needs only the adapter. **CI checks**: the package host tests, the simulator package tests, app-unit,
the reference regression and the script tests, as for R02-G07-03. **Migration**: none (snapshot schema 1; orbit and
isolation are not saved). **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

The lead adds the snapshot preview first; agent B (orbit, picker, isolation) and agent D (panel win test) in parallel,
then agent C (gesture controller) on B's picker; the lead wires the presenter, scene and controls; agent E writes the
simulator wiring tests. The lead retests every result.
