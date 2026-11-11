# Quickstart: Phase 7 validation

1. Before: `python3 scripts/check_reference_clean.py`; reference baseline at `d93edd1` (ADR-0005 evidence, or rerun `run_reference_baseline.py` steps).
2. `xcodegen generate --spec Harnesses/ProjectMReference/ProjectMReference.yml`; `xcodebuild test -project Harnesses/ProjectMReference/ProjectMReference.xcodeproj -scheme ProjectMReference -destination 'platform=iOS Simulator,id=<27.2/26.5 sim>' CODE_SIGNING_ALLOWED=NO` → engine renders, A/B within tolerance, lifecycle stress clean, effects over engine.
3. VisualCoreRendering sim tests (GLState) on both runtimes; `check_dependencies.py` (R1: only the harness imports ProjectMBridge); Showcase audit still clean.
4. After: reference ANGLERendering tests on both runtimes, `check_reference_clean.py`; migration-log rows 2a and 2 filled.
Contract: [projectm-adapter.md](contracts/projectm-adapter.md).
