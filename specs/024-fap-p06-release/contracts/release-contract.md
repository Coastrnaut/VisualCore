# Contract: TemporaryFolder, release artifacts and the Acknowledgements screen

## VisualCorePersistence

```swift
public struct TemporaryFolder: Sendable, Equatable {
    public init(name: String, base: URL = FileManager.default.temporaryDirectory)
    public let url: URL
    public func makeFileURL(prefix: String, extension ext: String) throws -> URL
    public var fileCount: Int { get }
    @discardableResult public func removeAll() -> Int
}
```

**Tests** (at least 6):
- names are sanitized;
- `makeFileURL` creates the folder and gives unique names;
- `removeAll` counts and removes;
- `removeAll` on a missing folder returns 0;
- files outside the folder are untouched;
- `fileCount`.

## App

- The home screen gains a link "Acknowledgements" (`fap.home.acknowledgements`), which opens
  `AcknowledgementsView(identifierPrefix: "fap.acknowledgements")`.
- Launch cleanup runs `TemporaryFolder(name: "Captures").removeAll()` in `FluidArtPlaygroundApp.init`.
- Info.plist:
  - `CFBundleShortVersionString` 1.0.0 and `CFBundleVersion` 1;
  - `ITSAppUsesNonExemptEncryption` false;
  - `NSPhotoLibraryAddUsageDescription` (the only usage key);
  - `CFBundleIconName` AppIcon (from the asset catalog).
- `PrivacyInfo.xcprivacy`:
  - `NSPrivacyTracking` false;
  - `NSPrivacyTrackingDomains` [];
  - `NSPrivacyCollectedDataTypes` [];
  - `NSPrivacyAccessedAPITypes`: exactly the scan's categories, with reasons.

## Release step

`release_check.py --only app-release-fluid-art-playground` builds Release for generic iOS (unsigned), then runs
`check_release_symbols.py`, `check_privacy_manifest.py` and `check_app_release.py` with `release.json`. All must
pass.
