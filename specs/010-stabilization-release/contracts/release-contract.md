# Contract: release tooling and automation (Phase 9)

```text
python3 scripts/check_public_api.py [--update]          # exit 0 ok, 1 undocumented/changed (names listed), 2 usage
python3 scripts/check_licenses.py                       # exit 0 all dependencies inventoried, 1 unknown license
python3 scripts/release_check.py [--quick] [--json out] # runs every step; exit 0 only if all pass
python3 scripts/run_automation_sim.py --mode smoke|launch|lifecycle --sim <udid> --out <json>
swift run -c release --package-path Packages/VisualCore VisualCoreBaselines [--json]
```

```swift
// VisualCoreAutomation (only #if DEBUG || VISUALCORE_AUTOMATION)
@MainActor public final class AutomationRunner {
  public static let environmentKey = "VISUALCORE_AUTORUN", framesKey = "VISUALCORE_AUTORUN_FRAMES"
  public init(host: RenderHost, bundleID: String, terminate: @escaping (Int32) -> Void = { exit($0) })
  public static func requestedMode(environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
  @discardableResult public func run(mode: String, frames: Int = 120) -> AutomationReport   // writes JSON, then terminate
}
public struct AutomationReport: Codable { … see data-model … }
```
Release builds: `nm -U` of the Showcase Release binary contains no `AutomationRunner`/`VisualCoreAutomation` symbols.
