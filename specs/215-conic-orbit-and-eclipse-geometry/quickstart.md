# Quickstart: R02-F15

1. `swift test --package-path Packages/VisualCore --filter "KeplerSolverTests|ConicOrbitTests|ConicOrbitCodingTests|PhaseStepperTests|DiskOverlapTests|EclipseGeometryTests"`
   — expect all pass: residuals ≤ 1e-10 for 1,000 seeded cases per kind; elliptic positions equal `KeplerOrbit` to a
   relative 1e-9; 100,000 steps equal a direct jump; overlap equals the integration oracle to 1e-6; every class fixture.
2. `swift test --package-path Packages/VisualCore` — expect every existing test, `KeplerOrbitTests` included, unchanged
   and passing.
3. `python3 scripts/check_public_api.py` after `--update` — expect the new declarations only.
4. Regression: ExperiencesCreative (sim-27.2), VisualCoreRendering (sim-27.2, sim-26.5), the reference regression in two
   chunks and `python3 scripts/test_scripts.py`.
