---

description: "Task list for feature 019 — Fluid Art Playground Phase 01 ping-pong feedback validation (ledger gate A02-P01)"
---

# Tasks: Fluid Art Playground — Phase 01 Ping-pong feedback validation

**Input**: `/specs/019-fap-p01-pingpong/` (spec with 5 clarifications, plan, research R1–R9, data-model, contracts,
quickstart).

**Tests** are required: host suites, VisualCoreRendering package tests and app unit and UI tests on iOS 27.2 and 26.5,
each followed by the enumeration guard, plus the ProjectM regression after the VisualCore change. IDs are
`T-A02-1##`, with one commit and push per task (`scripts/tick_task.py`). Every command runs through
`desktop_runbook.py run-check --stage A02-P01`.

**Review checkpoints**: at the end of each phase, `validate_docs.py`, `check_dependencies.py` and
`check_compliance.py` pass. After Phase 3, the API baseline diff is reviewed: additions only.

## Phase 1: Setup

- [X] T-A02-101 Create the GPU-free package `Apps/FluidArtPlayground/FluidArtPlaygroundCore`, which depends only on VisualCore's — Verified 2026-11-11: GPU-free package Apps/FluidArtPlayground/FluidArtPlaygroundCore (renamed from Core: SwiftPM package identity collided with Apps/GenerativeArtStudio/Core, research R10) depends only on VisualCoreSimulation; project.yml registers it, the app links FluidArtPlaygroundCore, VisualCoreSimulation, VisualCoreRendering and VisualCoreUI, new FluidArtPlaygroundTests unit target in the scheme. run-check A02-P01/t101-core-test-2 swift test 1/1 pass; t101-app-build-2 TEST BUILD SUCCEEDED (generic iOS Simulator) with the dependency audit PASS (no ProjectM); check_dependencies R1-R5 PASS
  `VisualCoreSimulation`:
  - `Package.swift`: swift-tools 6.0, iOS 26 / macOS 15;
  - `Sources/FluidArtPlaygroundCore/Module.swift` with the module doc;
  - an empty test target.

  Register it under `packages:` in `project.yml`, add the app dependencies on `FluidArtPlaygroundCore`,
  `VisualCoreRendering` and `VisualCoreUI`, and add a `FluidArtPlaygroundTests` unit-test target to the scheme.
  Acceptance: `swift build --package-path Apps/FluidArtPlayground/FluidArtPlaygroundCore`, `xcodegen generate` and a generic simulator
  build with the dependency audit all pass.

## Phase 2: Foundational — generic CPU pieces in VisualCore (G-CPUFIELD; blocks US1 and US2)

- [X] T-A02-102 [P] Write host tests first, then implement in `Packages/VisualCore/Sources/VisualCoreSimulation/`: — Verified 2026-11-11: VisualCoreSimulation FieldGrid/StoragePrecision (portable half rounding cross-checked against Float16 on 5,000 values; unorm8 stall case), SignedRangeEncoding, TimeStepPolicy with /// docs; tests FieldGridTests 8, SignedRangeEncodingTests 2, TimeStepPolicyTests 3. run-check A02-P01/t102-visualcore-host swift test: all suites pass (13 new XCTest + 168 Swift Testing, 0 failures); check_public_api --update (28 additions, 0 removed; baseline 923 lines) then PASS; check_documented_api PASS; check_compliance PASS; check_dependencies PASS; README and package-map updated
  - `FieldGrid.swift`: `FieldGrid` and `StoragePrecision`. The float16 rounding is `Float(Float16(x))`; unorm8 is
    `round(clamp(x,0,1)*255)/255`; the tolerances are 1e-6, 1e-3 and 1.5/255; channels are 1…4.
  - `SignedRangeEncoding.swift`: `encode = clamp(v/range*0.5+0.5, 0, 1)`; range > 0 and finite.
  - `TimeStepPolicy.swift`: 1/240…1/30; NaN, infinite or ≤ 0 → min; counts clamped and invalid deltas.

  Tests in `Packages/VisualCore/Tests/VisualCoreSimulationTests/` are `FieldGridTests`, `SignedRangeEncodingTests`
  and `TimeStepPolicyTests`, which include the unorm8 stall case. Add `///` docs to all public API, update the
  VisualCore README section and the API baseline (`check_public_api.py --update`, additions only). Acceptance:
  `swift test --package-path Packages/VisualCore` passes.

## Phase 3: User Story 2 — Reusable ping-pong and field passes in VisualCore (P1)

**Goal**: G-PINGPONG, G-FLOATRT and G-FIELDPASS. **Independent test**: the VisualCoreRendering package tests on both
runtimes, then the ProjectM regression 7/7.

- [X] T-A02-103 [US2] Add `RenderTarget.upload(rgbaFloats:)` and `readFloatPixels()` in — Verified 2026-11-11: RenderTarget.upload(rgbaFloats:) (rgba16f GL_FLOAT, rgba8 unorm8-quantized) and readFloatPixels(); RenderCapabilities.reportsColorBufferHalfFloat and currentExtensions(); FloatRenderSupport (extension + 4x4 RGBA16F probe, released, cached per generation, storageFormat(forceFallback:)); tests FieldTestSupport, FloatTransferTests 3, FloatRenderSupportTests 4. run-check A02-P01/t103-rendering-27-2: VisualCoreRendering package TEST SUCCEEDED on iOS 27.2, 0 failures; enumeration guard 7/7 new tests passed, none skipped; detect reports extension=true probe=true, matching the raw probe (the first attempt t103-rendering-27 failed to compile: main-actor isolation, fixed)
  `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GPUObjects.swift`:
  - rgba16f uses `GL_RGBA`/`GL_FLOAT`;
  - rgba8 is quantized on the CPU and read back normalized;
  - r8, a count mismatch, or a stale or released target → false / `[]`.

  Add `RenderCapabilities.reportsColorBufferHalfFloat`. Add `FloatRenderSupport.swift` (extension check plus a 4×4
  RGBA16F probe that is released, cached per generation, with `storageFormat(forceFallback:)`). Tests:
  `FloatTransferTests.swift` (round trip in both formats; the unorm8 quantization step) and
  `FloatRenderSupportTests.swift` (detect agrees with an independent probe; the forced fallback gives `.rgba8`; the
  ledger is unchanged after detect).
- [X] T-A02-104 [US2] Add `PingPongTarget.swift`: — Verified 2026-11-11: PingPongTarget (read/write, swap, swapCount, bytes, isValid, idempotent release, a failed second allocation releases the first); PingPongTargetTests 4 (swap alternates and read !== write; ledger count and bytes +2 / restored after release; budget-limited second allocation leaks nothing; context recreation invalidates and stale bind is counted). run-check A02-P01/t104-rendering-27-2: VisualCoreRendering package TEST SUCCEEDED on iOS 27.2; enumeration guard 15/15 new tests passed (first attempt t104-rendering-27 failed to compile: missing VisualCoreDiagnostics import in the test, fixed)
  - `read`/`write`, `swap()`, `swapCount`, `bytes` (2·w·h·bpp), `isValid`;
  - `release()` is idempotent;
  - a failed second allocation releases the first.

  Tests in `PingPongTargetTests.swift`: swap alternates and `read !== write`; the ledger bytes; release restores the
  ledger; after `recreateContext` the pair is invalid and stale use is counted.
- [X] T-A02-105 [US2] Add `FieldPass.swift` with `FieldUniform`, `FieldPassError` and `FieldPass.Output`. — Verified 2026-11-11: FieldPass (FieldUniform, FieldPassError incl. uniformTypeMismatch, Output .target/.framebuffer; validation before any draw; blend/scissor restored; pair step swaps only on success; source committed with 080889f); FieldPassTests 4: the two-input additive pass on 4x4 matches the CPU within one storage step (rgba16f on this runtime); inputIsOutput when pair.read is the output, missing/unknown input, unknown uniform, type mismatch, compile error, no swap on failure; the pair step writes the other target and swaps once; stale after context recreation. run-check A02-P01/t104-rendering-27-2 TEST SUCCEEDED on iOS 27.2, enumeration guard 15/15; contract doc aligned (v_uv, uniformTypeMismatch, shared programs)
  - `run(output:inputs:uniforms:)` validates before drawing: every listed input is supplied and no other; no input
    is the output (`inputIsOutput`); uniform names exist (`unknownUniform`); handles are current (`stale`). The
    viewport is the output size, with blend disabled and restored.
  - `run(pair:input:...)` swaps only on success.

  Tests in `FieldPassTests.swift`:
  - an additive two-input pass on 4×4 matches the CPU within 1e-3 (rgba16f);
  - `inputIsOutput` when `pair.read` is the output;
  - missing or unknown input and uniform errors;
  - `stale` after a context recreation;
  - a pair run swaps exactly once.
- [X] T-A02-106 [US2] Run the VisualCoreRendering package tests on iOS 27.2 and then on 26.5 (separate run-checks), — Verified 2026-11-11: run-check A02-P01/t106-rendering-26: VisualCoreRendering package TEST SUCCEEDED on iOS 26.5, enumeration guard 129/129 (half-float extension=true probe=true); iOS 27.2 full run t104-rendering-27-2 enumeration guard 129/129; check_public_api --update (27 additions, 0 removed, baseline 950 lines) then PASS; check_documented_api --sources Packages/VisualCoreRendering/Sources PASS (a pre-existing gap for FramePacing.Thermal, failing before this feature too, was fixed with a Frame pacing section in the VisualCore README); VisualCoreRendering README section 'Ping-pong fields, field passes and half-float targets', package-map and support-matrix rows updated; check_dependencies, check_compliance and validate_docs PASS
  with the enumeration guard for the 4 new classes. Run `check_public_api.py --update` (additions only) and
  `check_documented_api.py --sources Packages/VisualCoreRendering/Sources`. Update the README section for the new
  types and the package-map / support-matrix entries.
- [X] T-A02-107 [US2] Run the ProjectM reference regression in two run-check chunks (3/3 + 4/4) after the VisualCore — Verified 2026-11-11: run-check A02-P01/t107-reference-a 3/3 (engine xcframework, projectM-iOS simulator build, reference clean at d93edd1) and t107-reference-b 4/4 (ANGLERendering 14/14 and ProjectMReference 17/17 on iOS 27.2 and 26.5) = 7/7 after the VisualCore change; appended to docs/apps/fluid-art-playground/regression-baseline.md (US2 AC3, SC-A02-105)
  change. Append the results to `docs/apps/fluid-art-playground/regression-baseline.md` (US2 AC3, SC-A02-105).

## Phase 4: User Story 1 — Bounded velocity and dye fields evolve correctly (P1) 🎯 MVP

**Goal**: FR-A02-101…104, 108 and 110. **Independent test**: the host Core tests, then the GPU dissipation fixture on
both runtimes and both storages.

- [X] T-A02-108 [P] [US1] Tests first, then the implementation of `FluidConfiguration.swift` in — Verified 2026-11-11: FluidConfiguration (version 1; grid 16...512 then <= maxEdge; dissipations 0...10 with non-finite -> default; viscosity 0...1; pressure iterations 1...80; velocityRange 0.5...64; seed) with ConfigurationIssue and idempotent validated(maxEdge:); FluidConfigurationTests 5, including 14 out-of-range cases (>= 8, with NaN/infinity), device cap, issue text and Codable round trip. run-check A02-P01/t108-core-test swift test 6/6 pass (SC-A02-103 part 1)
  `Apps/FluidArtPlayground/FluidArtPlaygroundCore/Sources/FluidArtPlaygroundCore/`:
  - fields and bounds verbatim from data-model.md:
    - "gridWidth/gridHeight 16…512, then ≤ maxEdge";
    - "dyeDissipation/velocityDissipation 0…10, NaN → default";
    - "viscosity 0…1";
    - "pressureIterations 1…80";
    - "velocityRange 0.5…64";
    - "version must be 1";
  - `ConfigurationIssue`, and `validated(maxEdge:)`, which is idempotent.

  `FluidConfigurationTests` cover ≥ 8 out-of-range cases, including NaN and infinity (SC-A02-103).
- [X] T-A02-109 [P] [US1] Add `Dissipation.swift` (`factor = 1/(1+d·dt)`, and `step` over a `FieldGrid` with — Verified 2026-11-11: Dissipation (factor 1/(1+d*dt); CPU step with StoragePrecision rounding and optional SignedRangeEncoding per channel), DyeSeed (uniform, deterministic 8-blob pattern from SeededRandom with RGB in 0...1 and alpha 1, zeroVelocity), FluidCanvasDescription. Tests: DissipationTests 6 (d=0 identity in every precision, float32 closed form after 60 steps, 1,000 steps at d=10 finite and >= 0 in every precision, unorm8 stall, encoded velocity decays and zero stays zero), DyeSeedTests 2, FluidCanvasDescriptionTests 1. run-check A02-P01/t109-core-test swift test 15/15 pass; check_dependencies PASS
  `StoragePrecision`), `DyeSeed.swift` (`uniform`, a deterministic `pattern(seed:)` from `SeededRandom` with values
  in [0, 1], and `zeroVelocity`) and `FluidCanvasDescription.swift`. Tests: `DissipationTests` (d = 0 identity; the
  closed form after N float32 steps; 1,000 steps at d = 10 stay finite and ≥ 0; unorm8 stalls as predicted),
  `DyeSeedTests` (determinism, range), `FluidCanvasDescriptionTests`. Acceptance: `swift test --package-path
  Apps/FluidArtPlayground/FluidArtPlaygroundCore` passes.
- [X] T-A02-110 [US1] Add `Apps/FluidArtPlayground/App/FluidShaders.swift`, with an original-work license header: — Verified 2026-11-11: FluidShaders (dissipate with RGBA8 signed-velocity decode/scale/re-encode, display; MIT original-work header) and FluidFieldsScene: storage from FloatRenderSupport (forceFallback), velocity and dye PingPongTargets at the validated grid, one shared dissipate FieldPass plus a display pass, seed upload (velocity RG encoded with SignedRangeEncoding on RGBA8, analyze U1), TimeStepPolicy-clamped dt with the fixedDelta seam, stepCount/rebuildCount/lastError, readDye/readVelocity, teardown releases everything. run-check A02-P01/t110-app-build TEST BUILD SUCCEEDED (generic iOS Simulator) with the dependency audit PASS; behavior is verified by T-A02-111 and T-A02-113
  - a dissipate fragment, `uField`, `uFactor`, and `uEncoded`/`uRange` for RGBA8 signed velocity;
  - a display fragment, `uDye`, with a dark background.

  Add `FluidFieldsScene.swift` per contracts/app-fields.md:
  - storage selection;
  - two `PingPongTarget`s;
  - seed upload (velocity goes through `SignedRangeEncoding(range: velocityRange)` when the storage is RGBA8, so zero
    is stored as 0.5; analyze U1);
  - the per-frame clamped `Δt` (`TimeStepPolicy`);
  - dissipation on both pairs, then display to the framebuffer;
  - `stepCount`, `rebuildCount`, the `fixedDelta` test seam, and `readDye()`/`readVelocity()`;
  - `teardown` releases everything.
- [X] T-A02-111 [US1] Add `Apps/FluidArtPlayground/Tests/Unit/DissipationFixtureTests.swift`: for d ∈ {0, 1, 5}, — Verified 2026-11-11: DissipationFixtureTests 4 (d in {0,1,5}, 60 steps at 1/60 on 16x16, uniform 0.8/0.8/0.8/1, half-float and forced RGBA8; zero velocity stays 0; one swap per pair per step; GPU seed equals the CPU seed rounded to storage (C2); the guard refuses inputIsOutput and the scene keeps rendering). Found: half-float color writes truncate on the simulators (GLES implementation-defined), so StoragePrecision.float16TowardZero was added to VisualCore (FieldGridTests +1, host t111-visualcore-host pass) and the fixture accepts the closer half reference (spec clarification 6, research R2 revision). run-check A02-P01/t111-app-27-3 (iOS 27.2) and t111-app-26 (iOS 26.5): TEST SUCCEEDED, enumeration guard 6/6 each; half-float matched float16TowardZero with max diff 0.0, RGBA8 max diff 0.0 for all d (SC-A02-101, SC-A02-102). An earlier attempt t111-app-27 ran without the new class (project not regenerated; caught by the guard) and t111-app-27-2 failed on the nearest-only reference. API baseline PASS; ProjectM regression rerun t111-reference-a 3/3 + t111-reference-b 4/4; check_documented_api for the app PASS (FramePacing.Range now documented)
  60 steps at Δt = 1/60, a 16×16 grid with uniform (0.8, 0.8, 0.8, 1), in half-float (when supported) and forced
  RGBA8, `max|GPU − CPU(precision)| ≤ tolerance`. Zero velocity stays at 0 in both storages. Every simulation pass
  writes to a target other than its input (`swapCount` == 2 per step; a guard test expects `inputIsOutput`). After 0
  steps, the GPU readback of `DyeSeed.pattern(seed:)` equals the CPU seed rounded to the storage precision, within
  tolerance (FR-A02-110; analyze C2).
  Acceptance: SC-A02-101 and SC-A02-102 on iOS 27.2 and 26.5 (one run-check each), with the enumeration guard.

## Phase 5: User Story 3 — See the fields on screen (P2)

**Goal**: FR-A02-106 and 107. **Independent test**: the lifecycle unit tests and the UI test on both runtimes.

- [X] T-A02-112 [US3] Add `Apps/FluidArtPlayground/App/PlaygroundView.swift`: — Verified 2026-11-11: PlaygroundView with PlaygroundModel (owns one RenderHost(scene: FluidFieldsScene), destroyed on disappear; RenderSurface with identifier fap.canvas, label from FluidCanvasDescription, hint 'Fluid canvas...'; title 'Playground'; failure text if the host cannot start); home gains a 44-pt NavigationLink fap.home.open. Contract app-fields.md aligned with the A01 label-plus-hint pattern. run-check A02-P01/t112-app-build TEST BUILD SUCCEEDED with the dependency audit PASS; UI behavior verified in T-A02-113
  - `RenderHost(scene: FluidFieldsScene)` in `RenderSurface`, with the label "Fluid canvas" and a value from
    `FluidCanvasDescription`, identifier `fap.canvas`;
  - the title "Playground";
  - pause and resume with the scene phase.

  In `FluidArtPlaygroundApp.swift`, the home link `fap.home.open` opens it.
- [X] T-A02-113 [US3] Add `Apps/FluidArtPlayground/Tests/Unit/FieldsLifecycleTests.swift`: — Verified 2026-11-11: FieldsLifecycleTests 4 (context loss in both storages: rebuildCount 1, stepCount reset, live counts and bytes per category equal to the first setup, leaked 0, no stale use, >= 1% lit pixels after the rebuild; dt clamp 10 s -> 1/30 with exactly one step, NaN -> 1/240; the canvas is lit and mean dye strictly decreases over 30 steps; paused does not step) and PlaygroundUITests 1 (home fap.home.open -> fap.canvas whose label starts 'Dye pattern' and names the 128 by 128 grid, 'Playground' nav bar, no failure text, back returns home). run-check A02-P01/t113-app-27 (iOS 27.2) and t113-app-26 (iOS 26.5): TEST SUCCEEDED, enumeration guard 11/11 each (SC-A02-104)
  - after `recreateContext`, `rebuildCount` is 1, the stats' live counts per category equal those after the first
    setup, the scene uses no stale handle, and the readback is non-blank;
  - the Δt clamp: `fixedDelta` 10 s → one step of 1/30, and NaN → 1/240;
  - the readback has ≥ 1% non-black pixels, and the mean dye strictly decreases over 30 steps when d > 0.

  Add `Apps/FluidArtPlayground/Tests/UI/PlaygroundUITests.swift`: home → canvas exists with the label and a
  non-empty value, and the header is present. Acceptance: the app scheme passes on iOS 27.2 and 26.5 with the
  enumeration guard (SC-A02-104).

## Phase 6: Polish and cross-cutting

- [X] T-A02-114 Update `docs/apps/fluid-art-playground/visualcore-contract.json`: — Verified 2026-11-11: visualcore-contract.json gate A02-P01: M01, M03 and M10 are available with new evidence (PingPongTarget, FieldPass, FieldUniform, FloatRenderSupport, RenderCapabilities.reportsColorBufferHalfFloat, RenderTarget.readFloatPixels, FieldGrid, StoragePrecision, TimeStepPolicy, SignedRangeEncoding) and example consumer FluidFieldsScene; G-PINGPONG, G-FLOATRT and G-FIELDPASS closed in A02-P01; G-CPUFIELD added and closed. check_app_contract --app fluid-art-playground --render PASS: 10 rows, 40 citations, 7 gaps, decision go; .md re-rendered (FR-A02-109)
  - G-PINGPONG, G-FLOATRT and G-FIELDPASS are closed (phase 1, with test evidence);
  - G-CPUFIELD is added and closed;
  - M01, M03 and M10 are `available`, citing the new symbols.

  Re-render the `.md` and run `check_app_contract.py --app fluid-art-playground --render` (FR-A02-109).
- [X] T-A02-115 Run all checks: `check_documented_api.py --sources Apps/FluidArtPlayground`, `check_dependencies.py`, — Verified 2026-11-11: run-check A02-P01/t115-release-fast-2: 13/13 (docs, app-contracts, compliance, dependencies, public-api, licenses, script-tests 67 OK, documented-api, isolation and host domain-package tests for fluid-art-playground and generative-art-studio). New shared tooling: scripts/check_app_isolation.py (no CVisualCoreEGL/CVisualCoreGL import or egl* call, offline unless allowed, no undeclared usage descriptions) with AppIsolationTests 3, and release_check per-app steps documented-api-*, isolation-*, host-*-core and app-*-ios27/26 (ReleaseCheckTests +1). t115-isolation PASS on Apps/FluidArtPlayground with the built app: 0 problems, no NS*UsageDescription; the dependency audit (no ProjectM) passed in every app build (FR-A02-106, FR-A02-109; analyze C1; SC-A02-105). Lessons added to docs/testing/simulator-test-lessons.md
  `check_compliance.py`, `check_licenses.py`, `validate_docs.py`, `test_scripts.py`, and the release fast steps.
  Confirm that the app has no networking, no usage descriptions and no ProjectM linkage (dependency audit). A source
  check finds no `CVisualCoreEGL` import and no `egl` call under `Apps/FluidArtPlayground` (FR-A02-106; analyze C1)
  (SC-A02-105).

## Analyze remediation (2026-11-11)

Applied under the owner's delegated approval (CLAUDE.md §2):
- C1: the no-EGL source check was added to T-A02-115.
- C2: the GPU seed equality check was added to T-A02-111.
- U1: the RGBA8 velocity encoding on upload was added to T-A02-110.
- I1: the plan's Core file count and tree were fixed.
- N1: Reduce Motion is out of scope until user-driven motion arrives in Phase 02. Phase 01 shows only a slow fade.

No CRITICAL findings; coverage is 100%.

## Dependencies

- Setup (T-A02-101) comes first, then Foundational (T-A02-102).
- US2 (T-A02-103…107) provides the GPU machinery.
- US1: its Core tasks T-A02-108 and T-A02-109 can run in parallel with US2 once T-A02-102 is done. The GPU tasks
  T-A02-110 and T-A02-111 need US2.
- US3 (T-A02-112 and T-A02-113) needs T-A02-110.
- Polish comes last.

## Parallel examples

- T-A02-108 and T-A02-109 (Core, different files) run in parallel with T-A02-103…105 (VisualCoreRendering).
- Inside US2, the tests of T-A02-103, 104 and 105 are separate files, but the package build is shared, so they are
  run in sequence.

## Implementation strategy

MVP = Setup + Foundational + US2 + US1: a GPU dissipation fixture that matches the CPU. Then US3 (the visible canvas
and lifecycle), then the contract and checks. The gate is sealed only after converge appends nothing.

## Phase 7: Convergence

- [X] T-A02-116 Cap the grid by the real device limit. Expose the registry's maximum texture size read-only in VisualCoreRendering (`ResourceRegistry.maxTextureSize`, `public internal(set)`, with docs and the API baseline), validate the configuration in `FluidFieldsScene.setup` with `min(maxEdge, resources.maxTextureSize)`, and add a unit test where a small cap clamps the grid and is reported. Then rerun the package tests, the app tests and the ProjectM regression, per FR-A02-101 (partial) — Verified 2026-11-11: ResourceRegistry.maxTextureSize is now public internal(set) with docs (API baseline updated, check_public_api PASS; README note); FluidFieldsScene.setup validates with effectiveMaxEdge = min(maxEdge, resources.maxTextureSize); GridCapTests: the device cap equals min(512, maxTextureSize), and an explicit 64 cap clamps 512x300 to 64x64, reports both edges and sizes the GPU fields at 64. run-check A02-P01/t116-rendering-27 and t116-rendering-26 TEST SUCCEEDED, guard 129/129 each (FloatRenderSupportTests asserts maxTextureSize == capabilities); t116-app-27 and t116-app-26 TEST SUCCEEDED, guard 13/13 each; ProjectM regression t116-reference-a 3/3 + t116-reference-b 4/4 (FR-A02-101). The same app runs also cover T-A02-117
- [X] T-A02-117 Make `FluidFieldsScene.setup` throw (and release everything) when a seed `upload(rgbaFloats:)` returns false, with a unit test of the failure path, per FR-A02-107 / plan lifecycle step 1 (partial) — Verified 2026-11-11: FluidFieldsScene.setup throws FluidSceneError.seedUploadFailed(velocity|dye) when a seed upload returns false and releases both pairs and passes (catch -> releaseAll); uploadSeed test seam. SeedUploadFailureTests: no fields remain, 0 live framebuffers, and the host reports a .scene error naming seedUploadFailed. Code committed with c2ada3e; verified in run-check A02-P01/t116-app-27 and t116-app-26 (TEST SUCCEEDED, enumeration guard 13/13 each, SeedUploadFailureTests passed on both) (FR-A02-107)
