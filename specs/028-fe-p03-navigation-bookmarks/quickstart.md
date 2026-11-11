# Quickstart: validate feature 028

```bash
swift test --package-path Packages/VisualCore --filter "PlaneFramingTests|NamedLibraryTests"
swift test --package-path Apps/FractalExplorer/FractalExplorerCore
xcodegen generate --spec project.yml
xcodebuild test -project VisualCore.xcodeproj -scheme FractalExplorer \
  -destination "platform=iOS Simulator,id=<iOS 27.2 or 26.5 udid>" -derivedDataPath Build/DerivedData/FractalExplorer \
  -resultBundlePath .autonomy/xcresults/<name>.xcresult -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 300 CODE_SIGNING_ALLOWED=NO
python3 scripts/check_test_enumeration.py --sources Apps/FractalExplorer/Tests --log <log>
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
```

Expected: all tests pass; a saved bookmark reopens with the same center and span at any size; Go to −0.743643887,
0.131825904, 1000 reads "zoom 1000×"; the regression is 7/7. See [the contract](contracts/framing-library-bookmarks.md).
