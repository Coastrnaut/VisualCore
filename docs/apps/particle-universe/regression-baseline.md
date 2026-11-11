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
