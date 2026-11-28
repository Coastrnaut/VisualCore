# Implementation Plan: R02-G22-04 — Mycelium Architect: gameplay spatial interaction

**Branch**: `514-mycelium-architect-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-27 | **Spec**: [spec.md](spec.md)

## Summary

Add Mycelium Architect's gestures on the pattern of feature 504: an analytic picker over the drawn camera (gauge,
sprouts, root, cells), a gesture controller (taps that place, clear or inspect; site presses that preview ghost growth;
seed and unseed drags from the root; gauge scrubs; second-finger orbit; double-tap reset) with feature 504's constants,
a bounded view orbit with a re-fitted camera, previews computed by the kernel's own change rule and growth, ghost veins
and an inspection ring in the scene, the tool and panel additions, and the presenter wiring. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Dependencies**: as feature 513 (no new products). **Core**: `MyceliumArchitectPicker`,
`MyceliumArchitectGestureController` and `MyceliumArchitectViewOrbit` in `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/` (outside the
kernel scans); the snapshot gains the tool, the preview (action, previewed report and verdict, or refusal), the
inspected cell and the orbit as presentation state, never in the digest; the geometry draws ghost veins (dashed) and an
inspection ring; the camera takes the orbit. **Experience**: the presenter routes pointer events through the controller,
applies kernel actions through the adapter and presentation actions locally; the panel gains Nutrient and Blocker
buttons (never a segmented picker, the R02-G21-09 lesson), "place at cursor", "Inspect: none" and "Reset view".
**Testing**: host scripted pointer sequences (picker against an independent projection on 500 seeded cases, controller
state machine, orbit fit at every aspect, previews equal the kernel's on 200 cases, all 100 witnesses won through panel
actions); simulator wiring tests through the experience's pointer entry. **Performance**: picking is O(cells) per touch
(at most 256 on catalog boards); a preview is one kernel growth run. **Constraints**: additive; snapshot schema stays 1;
only event timestamps are read; constants equal feature 504's.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven Renderer Only | PASS — ghosts and rings use the existing programs. |
| II App-Neutral Public API | PASS — all in the experience package. |
| II-a Preserve the Reference and Prove It | PASS — reference regression in two chunks. |
| III GPU Lifecycle | PASS — unchanged. |
| IV Host-Testable Domain Logic, Test-First | PASS — picker, controller and orbit are pure and host-tested. |
| V Implementation Before Devices | PASS — touch feel is a `{device}` task. |
| VI Evidence Over Assertion | PASS — run-check records. |
| VII Native, Accessible UI | PASS — panel parity; no hue-only cues. |
| VIII Public Apple APIs, Privacy | PASS — no telemetry. |
| IX Bounded Untrusted Input | PASS — non-finite input is empty space. |
| X Licensing and Provenance | PASS — original code. |
| XI One App | PASS — the candidate only. |
| XII One Purchase, No Advertising | PASS — free. |
| XIII Code-Driven Visuals | PASS — ghosts are generated geometry. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectPicker.swift               new  (agent A)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectGestureController.swift    new  (agent B)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectViewOrbit.swift            new  (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectSceneSnapshot.swift        edit tool, preview, inspection, orbit (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectSceneGeometry.swift        edit ghost veins, inspection ring, orbit camera (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectExperienceCore.swift       edit preview helper via the kernel's change rule (lead)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPickerTests.swift                  new  (agent A)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectGestureControllerTests.swift       new  (agent B)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPanelWinTests.swift                new  all 100 witnesses through panel actions (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Experience/MyceliumArchitectPresenter.swift, MyceliumArchitectBoardScene.swift, MyceliumArchitectControls.swift  edit (agent C)
Packages/ExperiencesRound02/MyceliumArchitect/ExperienceTests/MyceliumArchitectGestureWiringTests.swift     new  simulator (agent C)
docs/architecture/mycelium-architect.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md            edit (lead)
```

**Migration**: none. **Rollback**: revert the feature's commits.

## Implementation order

1. Baselines after R02-G22-03 is recorded. 2. Orbit, snapshot and geometry additions, preview helper (lead), host tests.
3. Picker (agent A) and controller (agent B) in parallel. 4. Panel-win tests (lead). 5. Presenter, scene and panel wiring
with simulator wiring tests (agent C). 6. Docs, chunks, chain, reference, script tests. 7. Converge.

## Complexity Tracking

None.
