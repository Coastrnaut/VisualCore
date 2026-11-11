# Fractal Explorer — ProjectM regression baseline (A03-P00)

**Phase-start commit:** `343d251` ("speckit-constitution: A03 Fractal Explorer app-scoped rules (constitution 1.4.0),
ADR-0008"), the last commit before any A03 file. FR-A03-007 checks `git diff --stat 343d251..HEAD -- Packages
External`, which must stay empty for Phase 00.

**Reference pin:** `External/projectm-ios` at `d93edd1` (ADR-0005); nested ANGLE `29d1823`, projectM `c88894e`.

## Results (T-A03-003, 2026-11-11)

Ledger checks `A03-P00/t003-reference-a` and `t003-reference-b` run:

```bash
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 \
  projectm-reference-ios27 projectm-reference-ios26
```

| Step | Result | Detail |
|---|---|---|
| reference-engine-xcframework | pass | projectM engine xcframework from the pinned reference |
| reference-build-projectm-ios-sim | pass | projectM-iOS app, generic iOS Simulator (BUILD SUCCEEDED) |
| reference-clean | pass | reference working tree and pins unchanged (`d93edd1`) |
| reference-test-anglerendering-ios27 | pass | ANGLERendering 14/14 tests, iOS 27.2 simulator |
| reference-test-anglerendering-ios26 | pass | ANGLERendering 14/14 tests, iOS 26.5 simulator |
| projectm-reference-ios27 | pass | ProjectMReference harness 17/17 tests, iOS 27.2 simulator |
| projectm-reference-ios26 | pass | ProjectMReference harness 17/17 tests, iOS 26.5 simulator |

**7/7 pass.** These are simulator results: a regression baseline, not device evidence. Any VisualCore change made for
Fractal Explorer (gaps G-VIEWPORT, G-PRECISION, G-COST, G-TOUR) reruns these steps (constitution A03).

## A03-P01 rerun after `PlaneViewport` (2026-11-11)

`A03-P01/t101-reference-a` 3/3 (pin `d93edd1` unchanged) and `t101-reference-b` 4/4: **7/7 pass**, unchanged. A01
(`t101-build-GenerativeArtStudio`) and A02 (`t101-build-FluidArtPlayground`) build against the changed packages.

## A03-P02 rerun after `PrecisionAdvisor` and `RenderCapabilities` fragment precision (2026-11-11)

`A03-P02/t202-reference-a` 3/3 (pin `d93edd1` unchanged) and `t202-reference-b` 4/4: **7/7 pass**, unchanged. A01
(`t202-build-GenerativeArtStudio`) and A02 (`t202-build-FluidArtPlayground`) build against the changed packages. The
VisualCoreRendering package tests pass on both runtimes (`t202-rendering-27`, `t202-rendering-26`, enumeration
141/141). The simulator reports highp with 23 mantissa bits; that is context, not device evidence.

## A03-P03 rerun after `PlaneFraming` and `NamedLibrary` (2026-11-11)

`A03-P03/t303-reference-a` 3/3 (pin `d93edd1` unchanged) and `t303-reference-b` 4/4: **7/7 pass**, unchanged. A01
(`t303-build-GenerativeArtStudio`) and A02 (`t303-build-FluidArtPlayground`) build from clean derived data against the
changed packages. A01's own `CompositionLibrary` is unchanged; adopting `NamedLibrary` there is a follow-up.

## A03-P04 rerun after `RenderCostEstimate`, `FramingFlight`/`TourTimeline` and `StillCapture` (2026-11-11)

`A03-P04/t405-reference-a` 3/3 (pin `d93edd1` unchanged) and `t405-reference-b` 4/4: **7/7 pass**, unchanged, after
VisualCoreRendering gained the pure VisualCorePersistence dependency. A01 (`t405-build-GenerativeArtStudio`) and A02
(`t405-build-FluidArtPlayground`) build from clean derived data. A02's own `CaptureModel` is unchanged; adopting
`StillCapture` there is a follow-up.

## A03-P05 rerun after the VisualCoreAutomation app modes (2026-11-11)

`A03-P05/t502-reference-a` 3/3 (pin `d93edd1` unchanged) and `t502-reference-b` 4/4: **7/7 pass**, unchanged. A01
(`t502-build-GenerativeArtStudio`) and A02 (`t502-build-FluidArtPlayground`) build from clean derived data, and A02's
own automation tests pass unchanged (`t501-a02-automation`, 4/4).
