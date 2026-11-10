# Quickstart: validate Phase 3

```bash
swift test --package-path Packages/VisualCore
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test
python3 scripts/check_dependencies.py && python3 scripts/check_compliance.py
```
Expected: all exit 0; xcresult summaries Passed. API: `contracts/resources-shaders-api.md`.
