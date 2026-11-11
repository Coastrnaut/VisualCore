# Contract: Phase 06 tools and API

```text
python3 scripts/check_privacy_manifest.py --app <X.app> [--json <out>]
  exit 0: detected == declared categories; NSPrivacyTracking false; no tracking domains; no collected data types
  exit 1: lists "UNDECLARED <category> (symbols…)", "UNUSED <category>", "VIOLATION <text>"
  exit 2: missing app, executable or manifest

python3 scripts/check_app_release.py --app <X.app> --config docs/apps/<slug>/release.json
  checks: bundle id, CFBundleShortVersionString/CFBundleVersion, ITSAppUsesNonExemptEncryption present,
          NS*UsageDescription keys ⊆ allowed (and every allowed key present), PrivacyInfo.xcprivacy in the bundle,
          compiled app icon (CFBundleIcons or CFBundleIconName + Assets.car), required docs exist,
          every checklist row has a known status and non-empty evidence/steps
  exit 0 all pass; 1 any failure (one line per item); 2 bad input
```

```swift
// VisualCoreAutomation (compiled only under DEBUG || VISUALCORE_AUTOMATION)
public struct AutomationView: UIViewRepresentable {
  public init(mode: String, bundleID: String, makeScene: @escaping @MainActor () -> RenderScene,
              configure: (@MainActor (RenderScene, CGFloat) -> Void)? = nil)
}
```
