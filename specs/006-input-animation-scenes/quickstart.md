# Quickstart: Phase 5 validation

1. Host: `swift test --package-path Packages/VisualCore` → Math, Simulation, Scenes suites pass (coordinates round trip, gestures incl. cancel/fail, clock at 60/120 Hz and stalls, golden RNG, timelines, scene transforms/hit tests, particles, meshes).
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test` (and `sim-26.5`) → primitive, particle, mesh and touch-adapter tests pass.
3. Demo: `xcodegen --spec Harnesses/InteractiveDemo/InteractiveDemo.yml`, then `xcodebuild test` on an iOS 27.2 and 26.5 simulator with `CODE_SIGNING_ALLOWED=NO` → drag raises particles, pinch raises zoom, background/foreground does not burst.
4. Regression: generic-iOS build, `check_dependencies.py`, `check_compliance.py`, `validate_docs.py`, reference ANGLERendering tests; `nm` of the demo shows zero ProjectM symbols.
Contracts: [interaction-api.md](contracts/interaction-api.md); entities: [data-model.md](data-model.md).
