# Particle Universe — ProjectM regression baseline (A04-P00)

**Phase-start commit:** `d425f7d` ("speckit-constitution: 1.5.0 adds the A04 Particle Universe section (feature 032,
ADR-0008)"), the last commit before any A04 file. FR-A04-007 checks `git diff --stat d425f7d..HEAD -- Packages
External`, which must stay empty for Phase 00.

**Reference pin:** `External/projectm-ios` at `d93edd1` (ADR-0005); nested ANGLE `29d1823`, projectM `c88894e`.

## Results (T-A04-003, 2026-11-11)

Ledger checks `A04-P00/t003-reference-a` and `t003-reference-b` run:

```bash
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 \
  projectm-reference-ios27 projectm-reference-ios26
```

| Step | Result | Detail |
|---|---|---|
| reference-engine-xcframework | pass | projectM engine xcframework from the pinned reference |
| reference-build-projectm-ios-sim | pass | projectM-iOS app, generic iOS Simulator (BUILD SUCCEEDED) |
| reference-clean | pass | reference checkout and nested submodules unmodified (`d93edd1`) |
| reference-test-anglerendering-ios27 | pass | ANGLERendering 14/14 tests, iOS 27.2 simulator |
| reference-test-anglerendering-ios26 | pass | ANGLERendering 14/14 tests, iOS 26.5 simulator |
| projectm-reference-ios27 | pass | ProjectMReference harness 17/17 tests, iOS 27.2 simulator |
| projectm-reference-ios26 | pass | ProjectMReference harness 17/17 tests, iOS 26.5 simulator |

**7/7 pass.** These are simulator results: a regression baseline, not device evidence. Any VisualCore change made for
Particle Universe (gaps G-EMITTERS, G-FIELDS, G-PQUALITY, G-BLENDTRAIL) reruns these steps (constitution A04).

## A04-P01 rerun after `EmitterShape`, `EmitterBurst`, `Emitter.radial`/`clamped()` and `FixedStepRunner` (2026-11-11)

`A04-P01/t113-reference-a` 3/3 (pin `d93edd1` unchanged) and `t113-reference-b-2` 4/4: **7/7 pass**.

The first chunk-B attempt, `t113-reference-b`, failed one step: `projectm-reference-ios27`
`BaselineComparisonTests.testSquarePresetMatchesTheReferenceSequence`. Its within-8 score was 0.9705 against a required
value of max(0.95, floor − 0.01). That run's engine noise floor was unusually high (0.9835), which set the requirement
at 0.9735.

The criterion is relative to the engine's own run-to-run noise: recorded floors span 96.9–99.1% (SC-F702 amendment,
feature 008). The ProjectM path does not use the particle simulation that changed here. The unchanged rerun passed
(within-8 0.9738, floor 0.9778, required ≥ 0.9678). The failed attempt stays in the ledger; the criterion was not
changed.

Further checks:
- A01 (`t113-build-GenerativeArtStudio`) and A02 (`t113-build-FluidArtPlayground`) build for testing from clean
  derived data.
- VisualCoreRendering package tests pass on iOS 27.2 and 26.5 (`t113-rendering-27`, `t113-rendering-26`; enumeration
  149/149 each).
- The VisualCore host suite passes, including the baselines (`t104-visualcore-2`, `t105-visualcore`).
- A01's `ParticleReplay` is unchanged (`t104-a01-core`).

## A04-P01 rerun after `PlaybackState` (T-A04-115, 2026-11-11)

Results after adding `PlaybackState` to VisualCoreSimulation:
- `A04-P01/t115-reference-a`: 4/4 (with public-api; pin `d93edd1` unchanged).
- `t115-reference-b`: 4/4.
- The ProjectM regression is **7/7 pass** on the first attempt.
- A01 (`t115-build-GenerativeArtStudio`) and A02 (`t115-build-FluidArtPlayground`) build for testing from clean
  derived data.
- The VisualCore host suite passes (`t115-visualcore`).

## A04-P02 rerun after G-FIELDS, G-PQUALITY and `ParticleLayerScene` (T-A04-216, 2026-11-11, Mac Studio)

Results after adding the force fields and `liveLimit` (VisualCoreSimulation), `ParticleBudget` and
`DeviceConditions` (VisualCoreDiagnostics) and `ParticleLayerScene` (VisualCoreRendering):
- `A04-P02/t216-reference-a`: 3/3 (pin `d93edd1` unchanged, reference clean).
- `t216-reference-b`: 4/4.
- The ProjectM regression is **7/7 pass** on the first attempt.
- A01 (`t216-build-GenerativeArtStudio`) and A02 (`t216-build-FluidArtPlayground`) build for testing from clean
  derived data.
- VisualCoreRendering package tests pass on iOS 27.2 and 26.5 (`t212-rendering-ios27`, `t212-rendering-ios26`,
  enumeration 153/153 each). The VisualCore host suite passes (`t205-visualcore`), and A01's `ParticleReplay` and
  `replay-v1.json` are unchanged (`t205-a01-core`, `t205-pu-core`).

## A04-P03 rerun after G-BLENDTRAIL (T-A04-314, 2026-11-11)

Results after adding `TrailDecay` and `ParticleSystem.liveCount(source:)` (VisualCoreSimulation) and
`ParticleBlend`, `TrailLayer` and the `ParticleLayerScene` trail options (VisualCoreRendering):
- `A04-P03/t314-reference-a`: 3/3 (pin `d93edd1` unchanged, reference clean).
- `t314-reference-b`: 4/4.
- The ProjectM regression is **7/7 pass** on the first attempt.
- A01 (`t314-build-GenerativeArtStudio`) and A02 (`t314-build-FluidArtPlayground`) build for testing from clean
  derived data.
- VisualCoreRendering package tests pass on iOS 27.2 and 26.5 after the last VisualCore change
  (`t305-rendering-ios27-2`, `t305-rendering-ios26`, enumeration 166/166 each). The VisualCore host suite passes
  (`t306-visualcore`); A01's `ParticleReplay` and `replay-v1.json` are unchanged (`t306-a01-core`, `t306-pu-core`).
