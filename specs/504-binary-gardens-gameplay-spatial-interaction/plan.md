# Implementation Plan: R02-G21-04 — Binary Gardens: gameplay spatial interaction

**Branch**: `504-binary-gardens-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/504-binary-gardens-gameplay-spatial-interaction/spec.md`

## Summary

Add Binary Gardens' gestures on the pattern of Mushroom Weather's (feature 494, itself modelled on feature 484): a
constrained view orbit and an orbiting camera (`BinaryGardensViewOrbit`, `camera(aspect:orbit:)`, the system and glow
meshes built for the drawn eye: billboards facing it, bodies sorted back to front from it, cube-sphere quads far-first
from it, the backdrop perpendicular to its view axis); the preview (the scene snapshot gains a preview: the change as a
kernel action — a star's ring, phase or luminosity, or the tilt — with either the previewed arrangement and the kernel's
own report of it, or the kernel's refusal; computed with the kernel's `BinaryGardensSky.changed` and
`BinaryGardensSky.report`, never a second law); the geometry draws the ghost star (a dashed outline of the star's disc,
in the broken colour when refused), the worlds and gauges from the previewed report with the committed report's cells as
ghost outlines behind them (the ghost bands), the stars, rings and pips at a previewed luminosity or tilt, and the
inspection marks (a marker ring round the inspected world, a bracket round its gauge row); an analytic picker
(`BinaryGardensPicker`: in the reverse of the scene's painter's order — the actions bars as empty space, the gauge rows
by the finger cast onto z = 0 inside a plate, the bodies front to back from the drawn eye (a star's luminosity pip row
within 12 points of its projected first-to-last pip segment, then its disc grown by 12 points; a world's disc grown by
12 points), the star rings within 12 points of their projected 48-gons (later rings first), the tilt dial within 12
points of its projected pip segment, the system disc cast onto z = 0 within 0.95, else empty; plus the ring, grid-phase,
pip, dial and tick targets and the projected orbit tangent); a host-tested gesture controller
(`BinaryGardensGestureController`: star drags whose mode — ring or phase — is decided once from the travel against the
projected tangent and the star's locks, previewing and committing one `star.ring` or `star.phase` on release; pip and
dial taps and sideways drags (32 points per step) committing one `star.luminosity` or `orbit.tilt`; world taps that
inspect; gauge presses that inspect and scrub `clock.show`; double taps on empty space that reset the view; two-finger
orbit; cancellation; no kernel action outside playing, with the reason in words); the presenter's pointer entry, the
scene's orbit-aware camera and meshes and the panel's direct choices (ring, luminosity, tilt, phase target with "Set
phase", "Inspect", "Reset view"); and tests: 500 seeded gestures against an independent pick, 200 previews against the
kernel, all 100 certified levels won through panel actions alone, and simulator wiring tests through the pointer entry.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-27, read-only)**: after R02-G21-03 T-001 … T-005 (commits `d132e45d0` … `38aca8c35`),
`Packages/ExperiencesRound02/Package.swift` has `BinaryGardensCore` (with VisualCoreSimulation, VisualCoreMath,
VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence) and `BinaryGardensCoreTests`;
the `BinaryGardensExperience` and `BinaryGardensExperienceTests` targets, the `project.yml` link and the registration
arrive with R02-G21-03 T-006 (drafted, not yet committed: `BinaryGardensPresenter` with `BinaryGardensMirror`,
`BinaryGardensSystemScene`, `BinaryGardensControls`, `BinaryGardensExperience`; the presenter has no `pointer`
override yet, the scene builds its meshes for `camera(aspect:)` only, the panel has a star picker and one-step − / +
rows). This feature starts after R02-G21-03 is recorded; no new target, product or scheme is needed.
`BinaryGardensSceneGeometry` (committed) has `camera(aspect:)` (eye (0, −2.0, 3.2), look-at (0, −0.35, 0), up +y,
box x −1.3 … 1.3, y −1.85 … 1.15, z −0.85 … 0.85, `fitMargin` 0.06 per side), `project(_:camera:)`, `starCentre`,
`worldCentre`, `starRadius(luminosityIndex:)`, `tiltPipCentre`, `gaugeY`, `cellX`, `cellCentre`, `bloomX`,
`actionsY`, `actionsBar`, `ringVertex`, `orbitVertex`, `luminosityPips`, `worldPips`, `paintOrder`, `systemMesh`,
`glowMesh`, `systemPart`, `glowPart` — all built for the fixed authored eye (`billboardBasis` and the body sort read the
static `eye`). `BinaryGardensSceneSnapshot` carries the ring radii, luminosity levels, T_max, phase step, worlds,
arrangement, star positions at ticks 1 … 48, shown tick, fit scale, failure, stage, actions left and budget, but not
the star speed ω nor the stars' lock flags (see research R10). The adapter declares nine controls (`star.ring`,
`star.phase`, `star.luminosity`, `orbit.tilt`, `light.run`, `play.undo`, `play.redo`, `level.next`, `clock.show`
[0 … 60], 1 … 48 shown). The kernel's change rule `BinaryGardensSky.changed(_:_:by:)` is internal to
`BinaryGardensCore` (the preview lives in the same module, so no kernel API changes) and `BinaryGardensSky.report` is
public. The invariant tests scan a fixed list of ten kernel files; the new files are presentation files and do not
join it.

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreScenes
(`PointerEvent`, `PointerPhase`, `Mesh`) and VisualCoreMath (`Vec2`, `Mat4`, `ScreenProjection`); the Binary Gardens
Core of R02-G21-01 … 03; VisualCoreExperienceHost (`ExperiencePresenter.pointer(_:viewSize:port:)`) and
VisualCoreRendering in the experience. No new package, target, Objective-C++ bridge or VisualCore API (no API baseline
change). **Storage**: none (snapshot schema 1 unchanged; orbit, preview, inspection and shown tick are not saved).
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`; simulator package
tests on sim-27.2 (`--only-testing BinaryGardensExperienceTests`); the app unit tests; the reference regression in two
chunks; the script tests alone. Seed 2_504. **Target platform**: iOS 26.5 and 27.x simulators now; devices only after
ImplementationLock-100. **Project type**: one experience module inside the one app.
**Performance goals**: a preview per drag move is one kernel `changed` (a 48-tick separation scan) plus one `report`
(48 ticks × at most 5 worlds × 2 stars, integers) — well under a millisecond, so it is recomputed on every target
change; the picker projects at most 2 stars, 5 worlds, 8 rings × 48 vertices, 7 dial pips and 4 pips per star per
touch-down. **Constraints**: presentation-only view orbit, shown tick, preview and inspection; tap distance 10 points
and duration 0.5 s, drag distance 16 points, double tap 0.35 s and 22 points, marker allowance 12 points, step travel
32 points, tangent floor 0.5 points, all by event timestamps; yaw ±60° (90° per view width), pitch −20° … +35° (60°
per view height); the orbit yaws about the vertical axis +z through the authored box centre (0, −0.35, 0), which is the
authored look-at point; the refit keeps the authored box (no extension: it already holds every ring at tilt 6, the dial,
the gauges and the bars) inside the view with `refitMargin` 0.06 per side, never moving the eye closer than the authored
distance |(0, −1.65, 3.2)| ≈ 3.60, so orbit 0 is the authored camera bit for bit; tests under 10 s.
**Scale/Scope**: 100 certified levels (2 … 8 rings, 1 … 4 luminosity levels, T_max 0 … 6, phase step 1 … 24, 1 … 5
worlds, budget 1 … 24).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — the ghost star, ghost bands and inspection marks are new materials of the existing system program on the OpenGL ES → ANGLE → Metal path. |
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| II-a Preserve the reference | PASS — the reference regression runs in two chunks (7 of 7). |
| III GPU lifecycle | PASS — meshes rebuilt on the render thread when the orbit, aspect, preview or inspection changes; release unchanged. |
| IV Host-testable | PASS — orbit, preview, picking and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VI Evidence over assertion | PASS — every task's check recorded with `run-check`; agent reports retested by the lead. |
| VII Native, accessible UI | PASS — every gesture has a panel equivalent; ghosts are dashed outlines, refusals named in words, inspection ringed and bracketed (not hue alone). |
| VIII Privacy | PASS — no telemetry; diagnostics stay in the presenter. |
| IX Bounded input | PASS — pointer events bounded by the view; non-finite points and sizes are empty space; orbit clamped; targets clamped to the level's rings, grid phases, levels, tilts and ticks; actions validated by the kernel. |
| X Provenance | PASS — original code only. |
| XI One app | PASS — the candidate experience only; no target or bundle. |
| XII One purchase, no ads | PASS — tier free; nothing changes. |
| XIII Code-driven visuals | PASS — generated geometry and shader code only. |

Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/504-binary-gardens-gameplay-spatial-interaction/
├── plan.md  research.md  data-model.md  quickstart.md  contracts/api.md   (this command)
└── tasks.md                                                                (/speckit-tasks)
```

### Source code

```text
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSceneSnapshot.swift        edit  star speed, star freedoms, preview, inspected world, previewing/clearingPreview/inspecting (agent B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSceneGeometry.swift        edit  view orbit camera, camera-taking paint order, pips and meshes, drawn snapshot, ghost star, ghost bands, inspection marks (agent B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensShaders.swift              edit  ghostStar 38, ghostCell 39, inspectRing 40, inspectBracket 41 (agent B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensViewOrbit.swift            new   yaw and pitch, bounds, clamped (agent B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensPicker.swift               new   projection, pick, plane cast, ring, phase, pip, dial and tick targets, tangent, drag mode, step value (agent B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensGestureController.swift    new   arbitration, taps, star, pip and dial drags, inspection, scrubs, orbit (agent C)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/{BinaryGardensPickerTests (B), BinaryGardensPreviewTests (B), BinaryGardensGestureControllerTests (C), BinaryGardensPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/BinaryGardens/CoreTests/{BinaryGardensSceneGeometryTests, BinaryGardensSceneSnapshotTests, BinaryGardensShaderSourceTests}.swift  edit (B)
Packages/ExperiencesRound02/BinaryGardens/Experience/{BinaryGardensPresenter, BinaryGardensSystemScene, BinaryGardensControls}.swift  edit (lead)
Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensGestureWiringTests.swift   new   (agent E)
docs/architecture/binary-gardens.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md, README.md   edit (lead)
```

**Structure decision**: everything stays in the existing `BinaryGardensCore` and `BinaryGardensExperience` targets
(files are picked up by path; `Package.swift` and `project.yml` are not edited; `xcodegen generate` is not needed
because no app file is added). **Dependency graph**: snapshot, geometry, shaders, view orbit and picker (B, one agent
because they share the vertex contract and the drawn-eye pip positions) → gesture controller (C, against B's contract)
→ presenter, scene and panel wiring (lead) → wiring tests (E); the panel win test (D) needs only the adapter and the
stored witnesses (`docs/games/binary-gardens/levels/NNN.witness.json`). **CI checks**: the package host tests (the
round-two host chunk `round02-host-2` carries BinaryGardens), the simulator package tests, app-unit, the reference
regression and the script tests. **Migration**: none (snapshot schema 1; orbit, preview, inspection and shown tick are
not saved; opening, next level, reset and restore return them to their defaults). **Rollback**: revert the feature's
commits; the panel remains a complete control path and the 503 renderer is unchanged at the authored orbit without a
preview or inspection.

## Parallel work

Agents B, C and D draft in isolated copies (C against the picker and preview contract, D against the adapter); the lead
wires the presenter, scene and panel after B and C report; E writes the simulator wiring tests from the wired presenter
with its exact status and explanation texts. Agents build only in their copies; the lead runs every repository build and
test, retests each agent result and records checks after every agent has reported.

## Complexity Tracking

None: no constitution violation to justify.
