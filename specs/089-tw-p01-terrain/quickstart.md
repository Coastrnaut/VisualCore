# Quickstart: A12-P01 evidence (legacy ledger)

```bash
swift test --package-path Packages/VisualCore --filter "GradientNoise2DTests|HeightFieldTests"
python3 scripts/check_public_api.py
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing TinyWorldsCoreTests TinyWorldsExperienceTests
xcodegen generate --spec project.yml && python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a12.tiny-worlds --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app tiny-worlds --render
python3 scripts/test_scripts.py
```

Expected: host suites pass; API baseline current; core and experience suites pass with 9 digest fixtures; the app builds
and its unit tests pass; the runner's nine scenarios pass; 12 experiences (A12 a candidate); contract PASS with
G-TERRAIN and G-CONTENTLICENSES closed; script tests OK.
