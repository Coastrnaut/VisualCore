# Quickstart: validate Phase 4

```bash
swift test --package-path Packages/VisualCore --filter VisualCoreEffectsGraphTests
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test
```
Expected: all pass; invalid-graph fixtures rejected; each pass has a pixel test. API: `contracts/effects-api.md`.
Device performance per effect: campaign II (`{device}`).
