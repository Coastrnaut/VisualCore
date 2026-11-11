# Quickstart: validate feature 030

```bash
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name <name>
swift test --package-path Apps/FractalExplorer/FractalExplorerCore
xcodebuild test -project VisualCore.xcodeproj -scheme FractalExplorer -destination "platform=iOS Simulator,id=<udid>" ...
xcodebuild build -project VisualCore.xcodeproj -scheme FractalExplorer -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath Build/DerivedData/FractalExplorer-auto CODE_SIGNING_ALLOWED=NO
python3 scripts/run_automation_sim.py --app <Debug .app> --runtime 27.2 --mode precision --out .autonomy/logs/<dir>
python3 scripts/run_automation_sim.py --app <Debug .app> --runtime 27.2 --mode tour --out .autonomy/logs/<dir>
python3 scripts/check_release_symbols.py --app <Release .app>
```

Expected: reports with `result: pass` and the measurements in [the contract](contracts/automation-modes.md) —
rehearsal data only, never device evidence.
