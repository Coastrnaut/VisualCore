---

description: "Task list for feature 020 — Fluid Art Playground Phase 02 core fluid advection and splat injection (ledger gate A02-P02)"
---

# Tasks: Fluid Art Playground — Phase 02 Core fluid advection and splat injection

**Input**: `/specs/020-fap-p02-advection-splats/` (spec with 5 clarifications, plan, research R1–R8, data model,
contracts, quickstart).

**Tests** are required:
- host suites;
- VisualCoreRendering package tests and the app unit and UI tests on iOS 27.2 and 26.5, each with the enumeration
  guard (run `xcodegen generate` after adding files);
- the ProjectM regression after the VisualCore change.

IDs are `T-A02-2##`, with one commit and push per task (`scripts/tick_task.py`). Commands run through `run-check
--stage A02-P02`. Review checkpoint at the end of each phase: `validate_docs`, `check_dependencies`,
`check_compliance` and `check_app_isolation --app Apps/FluidArtPlayground` pass. After Phase 2, the API baseline diff
contains additions only.

## Phase 1: Setup

- [X] T-A02-201 Add `VisualCoreScenes` to the `FluidArtPlaygroundCore` dependencies in — Verified 2026-11-11: FluidArtPlaygroundCore depends on VisualCoreScenes (for PointerVelocityTracker.Sample); the app target lists VisualCoreScenes in project.yml. run-check A02-P02/t201-core-build swift build pass; xcodegen generate exit 0; check_dependencies R1-R5 PASS
  `Apps/FluidArtPlayground/FluidArtPlaygroundCore/Package.swift` and to the app target in `project.yml`. Acceptance:
  `swift build` of the Core package, `xcodegen generate`, and `check_dependencies` (R1–R5) pass.

## Phase 2: Foundational — VisualCore pieces (blocks US1, US2, US4)

- [X] T-A02-202 [P] [US4] Write tests first, then implement `PointerVelocityTracker` in — Verified 2026-11-11: PointerVelocityTracker in VisualCoreScenes (resampling at spacing, EMA velocity with the raw first move, intervals < 1 ms keep the previous velocity, began/ended/cancelled semantics, 10 pointers, per-update cap including the newest location, counters) with /// docs; PointerVelocityTrackerTests 11 cases (SC-A02-204 needs >= 8). run-check A02-P02/t202-visualcore-host swift test: all pass (179 Swift Testing, 0 failures); API baseline updated (additions) then check_public_api PASS; README 'Touches as forces' and package-map row; check_dependencies PASS
  `Packages/VisualCore/Sources/VisualCoreScenes/PointerVelocityTracker.swift`, per the contract and research R4:
  - "spacing > 0 else 1; cap 1…256; 0 < α ≤ 1 else 0.5";
  - began: 1 sample with velocity 0;
  - moved: `n = min(ceil(dist/spacing), cap)`;
  - Δt < 1 ms keeps the previous velocity;
  - ended: a final sample; cancelled: nothing;
  - at most 10 pointers;
  - counters for ignored pointers, rejected samples and capped updates.

  Add `PointerVelocityTrackerTests` with ≥ 8 cases (SC-A02-204). Add `///` docs and a VisualCore README section;
  update the package-map row.
- [ ] T-A02-203 [P] Write tests first, then add `FieldGrid.sampleBilinear(cellX:cellY:channel:)` and
  `sampleBilinear(cellX:cellY:)` to `Packages/VisualCore/Sources/VisualCoreSimulation/FieldGrid.swift`:
  - "p = coord − 0.5, i0 = floor(p), t = p − i0, indices clamped to the edge, lerp a + (b − a)·t in x then y".

  Tests in `FieldGridTests` cover centers, midpoints, edges and outside coordinates. Update the README.
- [ ] T-A02-204 Add `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/field.glsl` (`vc_fieldTexel`,
  `vc_fieldBilinear`, the same formula as the CPU) and `ShaderBundle.visualCoreIncludes`. Add a defaulted `library:`
  parameter to `FieldPass.init`. Add `FieldBilinearTests` (GPU = CPU within 1e-5 at 64 coordinates, including outside
  ones, in RGBA16F). Run the package tests on iOS 27.2 and 26.5 with the enumeration guard, `check_public_api
  --update` (additions only), and the README, package-map and support-matrix updates.
- [ ] T-A02-205 Run the ProjectM regression in two chunks (3/3 + 4/4) after the VisualCore changes and append the
  results to `docs/apps/fluid-art-playground/regression-baseline.md` (FR-A02-210).

## Phase 3: User Story 1 — Swipe to inject dye and motion (P1) 🎯

- [ ] T-A02-206 [P] [US1] Tests first, then add the splat settings to `FluidConfiguration.swift`:
  - "brushRadius 0.04 in 0.005…0.25, non-finite → default";
  - "forceScale 1 in 0…4, non-finite → default";
  - "maxSplatsPerFrame 16 in 1…64".

  Extend `FluidConfigurationTests` (FR-A02-209).
- [ ] T-A02-207 [US1] Tests first, then add `Splat.swift` (Core):
  - validated init: nil for non-finite input; position clamped 0…1; radius 0.005…0.25; |force| ≤ 10,000 (scaled);
    color 0…1; `wasClamped`;
  - the CPU `apply(to:dye:precision:velocityEncoding:)` Gaussian `exp(−d²/r²)`, with d in cells (aspect-correct) and
    r = radius × min(W, H).

  `SplatTests` (FR-A02-203, FR-A02-205), including a corner splat at (0, 0) that stays finite and changes only
  in-grid cells (spec edge case; analyze C2).
- [ ] T-A02-208 [US1] Tests first, then add `SplatQueue.swift` (Core):
  - `add(samples, viewSize:)`: y flipped and normalized; force = velocity × cells-per-point × forceScale; color by
    pointer order modulo 6;
  - `addSplash()` (research R6);
  - the even capped `drain(max:)` (research R5), with `dropped` counted.

  `SplatQueueTests` cover spacing (SC-A02-201), per-pointer direction (US1 AC2), the cap including the newest
  (US1 AC3), splash determinism, and cancel (FR-A02-204).
- [ ] T-A02-209 [US1] Add a splat fragment to `FluidShaders.swift` (`#include "vc/field.glsl"`; uniforms
  `uPoint`/`uRadius`/`uValue`/`uEncoded`/`uRange`/`uVelocity`; encoded 8-bit velocity is decoded, added and clamped).
  Add `FluidFieldsScene.enqueue(_:)` and drain-then-apply in `render`. Add
  `Apps/FluidArtPlayground/Tests/Unit/SplatFixtureTests.swift`: one splat on 8×8 and 16×16, both storages, GPU vs
  `Splat.apply` within one storage step (US1 AC4). Also test that splats enqueued before `recreateContext` are applied
  after the rebuild (spec edge case; analyze C3).

## Phase 4: User Story 2 — Dye and motion are carried by the flow (P1)

- [ ] T-A02-210 [P] [US2] Tests first, then add `Advection.swift` (Core): the semi-Lagrangian step in the order of
  clarification 5, with the dissipation factor, `FieldGrid.sampleBilinear`, precision rounding, and 8-bit velocity
  decode/encode. `AdvectionTests`: zero velocity is the identity; a uniform half-cell shift; a uniform field stays
  uniform; edges are clamped.
- [ ] T-A02-211 [US2] Add an advect fragment (`vc_fieldBilinear`, `gl_FragCoord`) and replace the Phase 01 dissipate
  passes in the scene with: advect velocity by itself, then advect dye by the advected velocity. Add
  `Apps/FluidArtPlayground/Tests/Unit/AdvectionFixtureTests.swift`:
  - zero velocity, d = 0, 120 steps on 8×8 and 16×16 (FR-A02-207, SC-A02-202);
  - uniform 30 cells/s for 4 steps (SC-A02-203);
  - both storages (half: the closer of the nearest and toward-zero references).

  Keep the Phase 01 fixtures green.
- [ ] T-A02-212 [US2] Run the app tests on iOS 27.2 and then 26.5, with the enumeration guard after each.

## Phase 5: User Story 3 — A control alternative to swiping (P1)

- [ ] T-A02-213 [US3] In `PlaygroundView.swift`:
  - wire `host.pointerHandler` → `PointerVelocityTracker` (spacing = brushRadius × shorter view edge / 2) →
    `SplatQueue` → `scene.enqueue` each frame;
  - add an "Add splash" button (`fap.splash`, ≥ 44 pt, hint) that calls `addSplash()` and posts the "Splash added"
    announcement;
  - the canvas label reports the splashes added.

  Update `PlaygroundUITests`: tap splash → the label contains "1 splash added"; a drag keeps the app responsive.
  Add a unit test that feeds `PointerEvent`s through the model's pointer handler and asserts queued, then applied,
  splats (FR-A02-208; analyze C1). Create `Apps/FluidArtPlayground/Tests/UI/AccessibilityAuditUITests.swift` (A01
  pattern) auditing home and playground at the default size and at XXXL. Document the exclusions (canvas artwork
  contrast) in the spec Clarifications (SC-A02-205; analyze U1).

## Phase 6: Polish

- [ ] T-A02-214 Update `docs/apps/fluid-art-playground/visualcore-contract.json`:
  - G-POINTERVEL closed in A02-P02;
  - G-SOLVER notes record advection and splats as done, with the pressure solve left for Phase 03;
  - M04 and M05 rows updated with the new evidence.

  Render it and run `check_app_contract --render`.
- [ ] T-A02-215 Run the release fast steps, the documented-API and isolation checks and the host domain tests through
  `release_check.py --only …` (SC-A02-206), and add any new lessons to `docs/testing/simulator-test-lessons.md`.

## Analyze remediation (2026-11-11)

Applied under the owner's delegated approval (CLAUDE.md §2):
- C1: a pointer-to-splat unit test was added to T-A02-213.
- C2: a corner splat test was added to T-A02-207.
- C3: a pending-splats-survive-context-loss test was added to T-A02-209.
- U1: the A02 accessibility audit UI test was added to T-A02-213.
- I1: Core's VisualCoreScenes dependency is justified (a pure module, needed for the tracker `Sample`).

No CRITICAL findings; coverage is 100%.

## Dependencies

- T-A02-201 comes first.
- T-A02-202 and T-A02-203 can run in parallel. T-A02-204 needs T-A02-203. T-A02-205 comes after T-A02-204.
- US1: T-A02-206 → T-A02-207 → T-A02-208 → T-A02-209 (T-A02-209 needs T-A02-204).
- US2: T-A02-210 (in parallel with US1 Core work) → T-A02-211 (needs T-A02-209's scene changes) → T-A02-212.
- US3: T-A02-213 needs T-A02-202 and T-A02-208.
- Polish comes last.

## Parallel examples

- T-A02-202 (Scenes), T-A02-203 (Simulation) and T-A02-206 (app Core) touch different files.
- T-A02-210 can be written while T-A02-209 runs on the GPU.

## Implementation strategy

MVP = Phase 1–2 + US1 + US2 (splats and advection matching the CPU). Then US3 (touch and splash), then the contract
and checks. Seal only after converge appends nothing.
