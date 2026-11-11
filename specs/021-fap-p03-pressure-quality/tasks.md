---

description: "Task list for feature 021 — Fluid Art Playground Phase 03 pressure projection and quality control (ledger gate A02-P03)"
---

# Tasks: Fluid Art Playground — Phase 03 Pressure projection and quality control

**Input**: `/specs/021-fap-p03-pressure-quality/` (spec with 5 clarifications, plan, research R1–R8, data model,
contract, quickstart).

**Tests** are required: host suites; app unit and UI tests on iOS 27.2 and 26.5 with the enumeration guard
(`xcodegen generate` after adding files); the ProjectM regression after the VisualCore change; an A01 build check.
IDs are `T-A02-3##`, with one commit and push per task (`scripts/tick_task.py`). Commands run through `run-check
--stage A02-P03`. Review checkpoint after each phase: `validate_docs`, `check_dependencies`, `check_compliance` and
`check_app_isolation`.

## Phase 1: Setup and foundational

- [X] T-A02-301 [P] [US4] Tests first, then add `QualityPolicy` in — Verified 2026-11-11: QualityPolicy in VisualCoreDiagnostics (tierCount >= 1, lowPowerCeiling clamped default 1, decisionInterval 2 s and calmPeriod 10 s with fallbacks; serious/critical or Low Power above the ceiling step down one tier per interval; calm (nominal/fair, no Low Power) for calmPeriod steps up one tier; floor; non-finite now keeps the tier; reset; counters) with /// docs, README 'Quality tiers', package-map and support-matrix rows. QualityPolicyTests 9 (SC-A02-304 needs >= 8). run-check A02-P03/t301-visualcore-host swift test: all pass (188 Swift Testing, 0 failures); API baseline updated (additions) then PASS; check_dependencies PASS
  `Packages/VisualCore/Sources/VisualCoreDiagnostics/QualityPolicy.swift`:
  - "tierCount ≥ 1; lowPowerCeiling 0…tierCount−1 default 1; decisionInterval > 0 default 2 s; calmPeriod > 0 default
    10 s";
  - step down on serious or critical, or on Low Power above the ceiling;
  - step up one tier after the calm period;
  - at most one change per interval;
  - a non-finite `now` keeps the tier;
  - `reset()` and counters.

  `QualityPolicyTests` cover ≥ 8 cases (SC-A02-304). Add `///` docs, a README section, the package-map row and the API
  baseline.
- [X] T-A02-302 Run the ProjectM regression (3/3 + 4/4) after the VisualCore change and append the results to — Verified 2026-11-11: run-check A02-P03/t302-reference-a 3/3 and t302-reference-b 4/4 (ANGLERendering 14/14, ProjectMReference 17/17 on iOS 27.2 and 26.5) = 7/7 after QualityPolicy; appended to regression-baseline.md (FR-A02-307)
  `regression-baseline.md` (FR-A02-307).
- [X] T-A02-303 [P] Tests first: add `BoundaryMode` ("walls default, open") and `boundaryMode` to — Verified 2026-11-11: BoundaryMode (walls default, open) and FluidConfiguration.boundaryMode; FluidConfigurationTests check the default and the Codable round trip with .open; the app target gains VisualCoreDiagnostics in project.yml (Core gets no new dependency, analyze I1). run-check A02-P03/t303-core-test swift test pass; xcodegen exit 0; check_dependencies PASS (FR-A02-305)
  `FluidConfiguration`. Add `VisualCoreDiagnostics` to the app dependencies in `project.yml` only; Core needs no new
  dependency (analyze I1).
  Extend `FluidConfigurationTests` (FR-A02-305).

## Phase 2: User Stories 1 and 2 — projection and boundaries, CPU reference (P1)

- [X] T-A02-304 [US1] [US2] Tests first, then add `FluidSolver.swift` (Core), following clarifications 1–5: — Verified 2026-11-11: FluidSolver CPU reference (Core): divergence 0.5*((uR-uL)+(vT-vB)), stateless Jacobi pressure (pL+pR+pB+pT-d)*0.25 from 0, gradient subtraction with the walls rule, implicit viscosity (8 iterations, nu = viscosity x 50), project and the full step in clarification-5 order; walls/open neighbor rules; FluidEncodings (velocity R, divergence 2R, pressure 4R; unorm8 zero exact); AccessLog of reads. FluidSolverTests 9: ramp divergence (open and walls), Jacobi point source symmetry, projection monotonic with >= 40% reduction at 20 iterations (measured 3529 -> 2874/2441/1921/1431 for 5/10/20/40, spec clarification 6 and SC-A02-302 set from data: the 50% guess was not achievable with this standard scheme), uniform field unchanged under open edges, zero normal velocity at walls and outward flow kept when open, 0 out-of-grid reads in both modes on 8x8 with a corner splat and viscosity (SC-A02-303), viscosity 0 skipped and spreading at 1, step at rest equals Phase 02 Advection.step, encoded rest field exact. run-check A02-P03/t304-core-test-2 swift test 42/42 pass (first attempt t304-core-test failed on the 50% threshold)
  - `divergence`, `jacobiPressure` (starting at 0), `subtractGradient` (walls rule), `diffuse` (8 iterations,
    ν = viscosity × 50);
  - the full `step` in the order of clarification 5;
  - 8-bit encodings for velocity, divergence (2×) and pressure (4×);
  - an access log of neighbor indices.

  `FluidSolverTests` cover:
  - divergence of known fields;
  - Jacobi on a point source;
  - a divergence reduction ≥ 50% at 20 iterations, never increasing over 5/10/20/40 (SC-A02-302);
  - a divergence-free field unchanged under open edges;
  - zero velocity through the walls after projection;
  - zero out-of-grid reads in both modes on 8×8 (SC-A02-303);
  - viscosity 0 skipped;
  - `step` with no splats and zero velocity equals Phase 02's `Advection.step` result.

## Phase 3: User Stories 1 and 2 — GPU passes (P1)

- [X] T-A02-305 [US1] [US2] Add divergence, pressure, gradient and diffuse fragments to `FluidShaders.swift` — Verified 2026-11-11: FluidShaders gain solverCommon (dec/enc with uCenter and per-field ranges, inside(), velAt with the walls reflection, scalarAt), divergence, fill, pressure, gradient (walls rule), diffuse and copy fragments using texelFetch with explicit edge branches; FluidFieldsScene adds divergence/pressure/scratch pairs (created and released with the rest), the clarification-5 pipeline (advect velocity, viscosity, divergence, zero-fill + N Jacobi, gradient, then advect dye), only active uniforms per pass, activePressureIterations/qualityIterations and update(configuration:) (no rebuild). Phase 01/02 fixtures moved to the full-step reference (solverReference with FluidSolver.step; uniform motion with open edges; velocity swaps 2 per step). run-check A02-P03/t305-app-27 TEST SUCCEEDED, enumeration guard 26/26: half-float exact (0.0) through projection; 8-bit within the per-stored-pass tolerance (max dye 12/255, velocity 4/255 on the splat frame); isolation PASS
  (`texelFetch` with explicit edge branches; `uWalls`; encodings). Add pressure, divergence and scratch pairs to the
  scene, created and released with the others. Implement the pipeline of clarification 5 with
  `update(configuration:)` (edge mode, viscosity, dissipation and iterations take effect the next frame without a
  rebuild). Update the Phase 02 fixtures' references to `FluidSolver.step`, with open edges for uniform motion.
- [ ] T-A02-306 [US1] [US2] Add `Apps/FluidArtPlayground/Tests/Unit/ProjectionFixtureTests.swift` and
  `BoundaryFixtureTests.swift`, on 8×8 and 16×16 grids in both storages:
  - a splat-driven divergent field projected with 20 iterations, GPU = CPU (SC-A02-301);
  - walls versus open near the edges (US2 AC1–AC2);
  - a uniform field under open edges unchanged (US1 AC3);
  - viscosity 0.5, GPU = CPU (FR-A02-304; analyze C1);
  - a live configuration change taking effect without a rebuild.

  Out-of-grid reads are proven by the CPU access log, plus clamped `texelFetch` and exact edge comparisons on the GPU
  (plan R4; analyze C2).

  Run the app tests on iOS 27.2 and 26.5 with the guard.

## Phase 4: User Story 3 — Adjust panel (P1)

- [ ] T-A02-307 [US3] Add `Apps/FluidArtPlayground/App/AdjustPanel.swift`, per the contract identifiers:
  - sliders for viscosity (0–1), dye fade (0–10 per s), motion fade (0–10 per s) and quality (1–80 iterations);
  - an edge picker;
  - a tier label;
  - Reset.

  Each control's accessibility value includes its unit. In `PlaygroundView.swift`, add the `fap.adjust` button and
  sheet; `PlaygroundModel.configuration` updates are forwarded to `scene.update`. Add `AdjustUITests`: change each
  control, check the value shown, reset (SC-A02-305). Extend the audit test with the Adjust sheet.

## Phase 5: User Story 4 — automatic quality (P2)

- [ ] T-A02-308 [US4] Tests first: add `FluidQuality.swift` (Core): tiers Full, Reduced and Minimal, with
  "Reduced = max(1, it/2); Minimal = max(1, it/4) and max(1, cap/2)". Wire `QualityPolicy` into `PlaygroundModel`:
  `ProcessInfo.thermalState` and `isLowPowerModeEnabled` are read every frame through an injectable provider. The
  tier's iterations and splat cap reach the scene and the queue drain. The tier label is shown. Add
  `QualityWiringTests` with injected states: serious → Reduced iterations next frame; the queue is not cleared; the
  label updates (FR-A02-308).

## Phase 6: Polish

- [ ] T-A02-309 Update `visualcore-contract.json`:
  - G-QUALITY closed in A02-P03, with the owner changed to VisualCore:VisualCoreDiagnostics (justification R1);
  - G-SOLVER closed in A02-P03;
  - M07 available;
  - M04 available or with updated evidence.

  Run `check_app_contract --render` (FR-A02-309).
- [ ] T-A02-310 Run the release fast steps, plus host, documented-API and isolation checks; rerun the ProjectM
  regression if VisualCore changed after T-A02-302; build A01; add lessons (SC-A02-306).

## Analyze remediation (2026-11-11)

Applied under the owner's delegated approval (CLAUDE.md §2):
- C1: the viscosity fixture was added to T-A02-306.
- I1: the speculative Core → VisualCoreDiagnostics dependency was removed (app only).
- C2: the out-of-bounds proof method is recorded.

No CRITICAL findings; coverage is 100%.

## Dependencies

- T-A02-301, then T-A02-302. T-A02-303 can run in parallel with T-A02-301.
- T-A02-304 needs T-A02-303.
- T-A02-305 needs T-A02-304, then T-A02-306.
- T-A02-307 needs T-A02-305.
- T-A02-308 needs T-A02-301 and T-A02-305.
- Polish comes last.

## Implementation strategy

MVP = Phases 1–3 (projection and boundaries matching the CPU). Then the Adjust panel, then automatic quality, then
the contract and checks. Seal only after converge appends nothing.
