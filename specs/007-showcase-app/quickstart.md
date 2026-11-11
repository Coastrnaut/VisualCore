# Quickstart: Phase 6 validation

1. `xcodegen generate` (repository root) → `VisualCore.xcodeproj` with the `Showcase` scheme.
2. Build: `xcodebuild build -project VisualCore.xcodeproj -scheme Showcase -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`.
3. Audit: `python3 scripts/audit_showcase_dependencies.py --app <DerivedData>/Showcase.app` → exit 0, 0 findings; `python3 scripts/test_scripts.py` → contaminated fixtures fail as expected.
4. Smoke: `xcodebuild test -scheme Showcase -destination 'platform=iOS Simulator,id=<27.2 or 26.5 sim>' -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO` → all scenes render, touch, toggle, context loss, background pass.
5. Regression: VisualCoreRendering sim tests (texture upload), R1–R5, compliance, docs, reference ANGLERendering.
Contract: [showcase-contract.md](contracts/showcase-contract.md).
