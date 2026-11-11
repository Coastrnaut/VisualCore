# Quickstart: validate feature 029

```bash
swift test --package-path Packages/VisualCore
swift test --package-path Apps/FractalExplorer/FractalExplorerCore
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name <name>
xcodegen generate --spec project.yml
xcodebuild test -project VisualCore.xcodeproj -scheme FractalExplorer -destination "platform=iOS Simulator,id=<udid>" \
  -derivedDataPath Build/DerivedData/FractalExplorer -resultBundlePath .autonomy/xcresults/<name>.xcresult \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 300 CODE_SIGNING_ALLOWED=NO
python3 scripts/check_test_enumeration.py --sources Apps/FractalExplorer/Tests --log <log>
```

Expected: cost reads "Render cost: 1× the default view (light)" at cap 200; a capture at 4096 px (or the device /
precision limit) is offered for sharing; a tour plays its three stops and Stop keeps the view; the spacing fixture
passes. See [the contract](contracts/capture-tour-cost.md).
