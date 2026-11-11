# Quickstart: validate Fractal Explorer Phase 02

Run each command through `run-check --stage A03-P02`, one runtime per call.

1. **Host**: `swift test --package-path Packages/VisualCore` (PrecisionAdvisorTests).
2. **VisualCoreRendering package**: run the tests on 27.2 and 26.5. The capabilities precision test logs the
   simulator's reported values as context only.
3. **App**: run on 27.2 and 26.5 with the guard. The GPU agreement, gestures, precision clamp, palette, UI tests and
   audit must all pass.
4. **Regression and checks**: run the ProjectM regression (expect 3/3 and 4/4), the A01 and A02 builds, and the fast
   checks.
