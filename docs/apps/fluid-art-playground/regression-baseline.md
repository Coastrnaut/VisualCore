# Fluid Art Playground — ProjectM regression baseline (A02-P00)

**Phase-start commit:** `06091bb` ("speckit-checklist: feature 018 checklist reviewed 20/20"), the last commit before
this phase's tasks. FR-A02-007 checks `git diff --stat 06091bb..HEAD -- Packages External`, which must stay empty for
Phase 00.

**Reference pin:** `External/projectm-ios` at `d93edd1` (ADR-0005); nested ANGLE `29d1823`, projectM `c88894e`.

## Results (T-A02-003, 2026-11-11)

Ledger checks `A02-P00/t003-reference-a` and `t003-reference-b`, which run:

```bash
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 \
  projectm-reference-ios27 projectm-reference-ios26
```

| Step | Result | Detail |
|---|---|---|
| reference-engine-xcframework | pass | projectM engine xcframework from the pinned reference |
| reference-build-projectm-ios-sim | pass | projectM-iOS app, generic iOS Simulator (BUILD SUCCEEDED) |
| reference-test-anglerendering-ios27 | pass | ANGLERendering 14/14 tests, iOS 27.2 simulator |
| reference-test-anglerendering-ios26 | pass | ANGLERendering 14/14 tests, iOS 26.5 simulator |
| reference-clean | pass | reference working tree and pins unchanged (`d93edd1`) |
| projectm-reference-ios27 | pass | ProjectMReference harness 17/17 tests, iOS 27.2 |
| projectm-reference-ios26 | pass | ProjectMReference harness 17/17 tests, iOS 26.5 |

**7/7 steps pass**, the same table as A01's baseline. These are simulator results, not device evidence. Any later
A02 phase that changes VisualCore reruns this set and compares against this table (constitution II-a, A02 rules).

## A02-P01 rerun after the VisualCore change (2026-11-11)

Feature 019 added `PingPongTarget`, `FieldPass`, `FloatRenderSupport` and the float upload/readback to
VisualCoreRendering, and `FieldGrid`, `StoragePrecision`, `SignedRangeEncoding` and `TimeStepPolicy` to
VisualCoreSimulation. The API baseline diff contains additions only. Same two chunks, run under stage A02-P01:

| Chunk | run-check | Result |
|---|---|---|
| reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean | `A02-P01/t107-reference-a` | 3/3 pass (reference pin `d93edd1` unchanged) |
| reference-test-anglerendering-ios27/ios26, projectm-reference-ios27/ios26 | `A02-P01/t107-reference-b` | 4/4 pass (ANGLERendering 14/14 and ProjectMReference 17/17 on both runtimes) |

**7/7 steps pass**, unchanged from the phase-start table. These are simulator results, not device evidence.

### Rerun after `StoragePrecision.float16TowardZero` (2026-11-11, T-A02-111)

`A02-P01/t111-reference-a` 3/3 and `t111-reference-b` 4/4: **7/7 pass**, unchanged.

### Rerun after `ResourceRegistry.maxTextureSize` became public (2026-11-11, T-A02-116)

`A02-P01/t116-reference-a` 3/3 and `t116-reference-b` 4/4: **7/7 pass**, unchanged.

## A02-P02 rerun after the VisualCore change (2026-11-11)

Feature 020 added `PointerVelocityTracker` (VisualCoreScenes), `FieldGrid.sampleBilinear` (VisualCoreSimulation),
`vc/field.glsl`, `ShaderBundle.visualCoreIncludes` and the `FieldPass` `library:` parameter (VisualCoreRendering).
The API baseline diff contains additions, plus one source-compatible signature change.

| Chunk | run-check | Result |
|---|---|---|
| reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean | `A02-P02/t205-reference-a` | 3/3 pass (pin `d93edd1` unchanged) |
| reference-test-anglerendering-ios27/ios26, projectm-reference-ios27/ios26 | `A02-P02/t205-reference-b` | 4/4 pass (ANGLERendering 14/14 and ProjectMReference 17/17 on both runtimes) |

**7/7 steps pass**, unchanged.

### Rerun after `SignedRangeEncoding.center` and `contentSwipeBackDisabled` (2026-11-11, T-A02-215)

`A02-P02/t215-reference-a` 3/3 and `t215-reference-b` 4/4: **7/7 pass**, unchanged. A01 Generative Art Studio also
builds against the changed packages (`t215-gas-build-2`, after clearing its stale DerivedData).

## A02-P03 rerun after `QualityPolicy` (2026-11-11)

`A02-P03/t302-reference-a` 3/3 (pin `d93edd1` unchanged) and `t302-reference-b` 4/4 (ANGLERendering 14/14 and
ProjectMReference 17/17 on iOS 27.2 and 26.5): **7/7 pass**, unchanged.

## A02-P04 rerun after `FieldPass.runObserver` (2026-11-11)

`A02-P04/t401-reference-a` 3/3 (pin `d93edd1` unchanged) and `t401-reference-b` 4/4: **7/7 pass**, unchanged.

## A02-P05 rerun after `SyntheticGestureScript` and the automation seed/check hooks (2026-11-11)

`A02-P05/t502-reference-a` 3/3 (pin `d93edd1` unchanged) and `t502-reference-b` 4/4: **7/7 pass**, unchanged. A01
(`t502-a01-build`) and Showcase (`t502-showcase-build`) build against the changed `AutomationView`.
