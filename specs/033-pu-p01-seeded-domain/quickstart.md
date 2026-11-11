# Quickstart: validate Phase 01

1. VisualCore simulation additions (C1–C7):
   `swift test --package-path Packages/VisualCore` → all pass, including `EmitterShapeTests`,
   `FixedStepRunnerTests`, and unchanged `ParticleSystemTests`/baseline checks.
2. App domain: `swift test --package-path Apps/ParticleUniverse/ParticleUniverseCore` → scene validation, family
   presets and `ReplayFixtureTests` (bit-exact against `Fixtures/replay-v1.json`).
3. A01 unchanged: `swift test --package-path Apps/GenerativeArtStudio/Core` passes.
4. App UI: `xcodegen generate --spec project.yml`, then the ParticleUniverse scheme test on iOS 27.2 and 26.5
   simulators (plan's command), then `python3 scripts/check_test_enumeration.py --sources Apps/ParticleUniverse/Tests
   --log <log>`. Expected: launch smoke, sandbox family/counts/pause-step tests and accessibility audits pass.
5. Contracts and API: `python3 scripts/check_public_api.py` (after `--update`), `check_app_contract.py --app
   particle-universe --render` shows G-SIMSTEP and G-EMITTERS closed; fast checks pass.
6. Regression: the two `release_check.py` reference chunks → 3/3 and 4/4; A01 and A02 build-for-testing from clean
   derived data.
