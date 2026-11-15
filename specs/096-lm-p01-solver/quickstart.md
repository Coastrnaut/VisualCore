# Quickstart: A13-P01 evidence (legacy ledger)

```bash
swift test --package-path Packages/VisualCore --filter Ray2Tests
python3 scripts/check_public_api.py
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LightMazeCoreTests LightMazeExperienceTests
xcodegen generate --spec project.yml && python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a13.light-maze --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app light-maze --render
python3 scripts/test_scripts.py
```

Expected: host suite passes; API baseline current; core and experience suites pass with 20 levels proven and 3 beam
fixtures; the app builds and its unit tests pass; the runner's nine scenarios pass; 13 experiences (A13 a candidate);
contract PASS with G-RAYCAST2D and G-BOARD closed; script tests OK.
