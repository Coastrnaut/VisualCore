# Quickstart: validate Phase 02

1. VisualCore simulation and diagnostics (contract C1–C7): `swift test --package-path Packages/VisualCore` → all pass,
   including `ParticleForceFieldTests`, `LiveLimitTests`, `ParticleBudgetTests` and the unchanged particle and
   baseline tests.
2. Layer scene (C8): `scripts/xcodebuild_package.py` for `Packages/VisualCoreRendering` on `sim-27.2` and `sim-26.5`
   (plan commands) → `ParticleLayerSceneTests` pass with the rest of the rendering suite.
3. App domain: `swift test --package-path Apps/ParticleUniverse/ParticleUniverseCore` → placed force, scene force
   validation, quality, and the bit-exact `replay-v1.json` test.
4. A01 unchanged: `swift test --package-path Apps/GenerativeArtStudio/Core` passes (checksums).
5. App UI ([contracts/app-ui.md](contracts/app-ui.md)): ParticleUniverse scheme tests on iOS 27.2 and 26.5, then
   `check_test_enumeration.py`. Expected: force placement, drag, controls, strength, effective limit under
   `-uitestThermal serious`, renderer "GPU", and the accessibility audits pass.
6. Contracts and API: `check_public_api.py` (after `--update`); `check_app_contract.py --app particle-universe` shows
   G-FIELDS and G-PQUALITY closed; fast checks pass.
7. Regression: the two `release_check.py` reference chunks → 3/3 and 4/4; A01 and A02 build-for-testing from clean
   derived data.
