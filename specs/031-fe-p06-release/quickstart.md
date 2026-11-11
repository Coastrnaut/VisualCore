# Quickstart: validate feature 031

```bash
xcodegen generate --spec project.yml
xcodebuild test -project VisualCore.xcodeproj -scheme FractalExplorer -destination "platform=iOS Simulator,id=<udid>" ...
python3 scripts/release_check.py --only app-release-fractal-explorer
python3 scripts/check_app_isolation.py --app Apps/FractalExplorer --built-app Build/DerivedData/release-FractalExplorer-Release/Build/Products/Release-iphoneos/FractalExplorer.app --allow-usage NSPhotoLibraryAddUsageDescription
```

Expected: all pass; see [the contract](contracts/release.md).
