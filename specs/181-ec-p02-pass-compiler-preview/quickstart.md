# Quickstart: A25-P02

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing EffectsComposerCoreTests EffectsComposerExperienceTests
xcodegen generate --spec project.yml
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a25.effects-composer --runtime 27
python3 scripts/check_app_contract.py --app effects-composer --render
```

Expected: all tests pass; the app builds and its unit tests pass with A25 a candidate; the runner passes; G-COMPILER,
G-POOL and G-DIAG are closed.
