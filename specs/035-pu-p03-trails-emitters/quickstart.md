# Quickstart: validate Phase 03

1. `swift test --package-path Packages/VisualCore` → `TrailDecayTests` and every existing suite pass (C1, C2).
2. VisualCoreRendering package tests on `sim-27.2` and `sim-26.5` → `ParticleBlendTests`, `TrailLayerTests` and the
   unchanged `ParticleRendererTests`/`ParticleLayerSceneTests` pass with the enumeration guard (C3–C7).
3. `swift test --package-path Apps/ParticleUniverse/ParticleUniverseCore` → emitter slots, overrides and the
   bit-exact replay fixture.
4. `swift test --package-path Apps/GenerativeArtStudio/Core` → A01 unchanged.
5. ParticleUniverse UI tests on iOS 27.2 and 26.5 ([contracts/app-ui.md](contracts/app-ui.md)) with the
   enumeration guard, including the accessibility audits.
6. `check_public_api.py`, `check_app_contract.py --app particle-universe` (G-BLENDTRAIL closed), the release-check fast
   steps.
7. Reference regression 3/3 + 4/4; A01 and A02 clean build-for-testing.
