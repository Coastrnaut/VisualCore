# Generative Art Studio — ProjectM regression baseline (A01-P00)

**Phase-start commit:** `8172b76` ("Seal F09…"), the last commit before feature 011. FR-A01-007 checks
`git diff --stat 8172b76..HEAD -- Packages External`, which must stay empty for Phase 00.

**Reference pin:** `External/projectm-ios` at `d93edd1` (ADR-0005); nested ANGLE `29d1823`, projectM `c88894e`.

## Results (T-A01-006, 2026-11-10)

Command, run under ledger check `A01-P00/t006-reference-regression`:

```bash
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim \
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 reference-clean \
  projectm-reference-ios27 projectm-reference-ios26
```

| Step | Result | Detail |
|---|---|---|
| reference-engine-xcframework | pass | projectM engine xcframework built from the pinned reference |
| reference-build-projectm-ios-sim | pass | projectM-iOS app, generic iOS Simulator |
| reference-test-anglerendering-ios27 | pass | ANGLERendering 14/14 tests, iOS 27.2 simulator |
| reference-test-anglerendering-ios26 | pass | ANGLERendering 14/14 tests, iOS 26.5 simulator |
| reference-clean | pass | reference working tree and pins unchanged (`d93edd1`) |
| projectm-reference-ios27 | pass | ProjectMReference harness 17/17 tests, iOS 27.2 |
| projectm-reference-ios26 | pass | ProjectMReference harness 17/17 tests, iOS 26.5 |

**7/7 steps pass.** These are simulator results, not device evidence. Any later A01 phase that changes VisualCore
reruns this set and compares against this table (constitution II-a).
