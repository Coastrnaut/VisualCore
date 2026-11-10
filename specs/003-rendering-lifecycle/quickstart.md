# Quickstart: validate Phase 2

```bash
swift test --package-path Packages/VisualCore                       # lifecycle + pacing (host)
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering \
  --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering \
  --scheme VisualCoreRendering-Package --destination sim-26.5 --action test
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering \
  --scheme VisualCoreRendering-Package --destination generic-ios
python3 scripts/run_reference_baseline.py --step test-anglerendering-ios27   # regression
python3 scripts/run_reference_baseline.py --step test-anglerendering-ios26
python3 scripts/check_dependencies.py && python3 scripts/check_compliance.py
```

Expected: all exit 0; `xcrun xcresulttool get test-results summary` reports `Passed` for each test
bundle. See `contracts/render-host-api.md` for the API under test.
