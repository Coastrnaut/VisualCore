# Contract: shell model (module VisualCoreExperience) and app tools (UA-F04)

```swift
public enum ShellRoute: Sendable, Equatable, Codable { case catalog, experience(ExperienceID), settings, about
    public init?(text: String); public var text: String }

public enum AccessibilityChoice: String, Sendable, Codable, CaseIterable { case system, on, off }

public struct ShellPreferences: Sendable, Equatable, Codable {
    public static let schema = 1, maxBytes = 65_536, maxSearchLength = 100, storageKey = "vc.shell.preferences"
    public var welcomeSeen: Bool, lastRoute: ShellRoute, searchText: String, qualityOverride: Int?
    public var reduceMotion: AccessibilityChoice, reduceFlashing: AccessibilityChoice
    public init()
    public static func decode(_ data: Data?) -> (preferences: ShellPreferences, note: String?)   // never throws
    public func encoded() -> Data
}

public struct LauncherTile: Sendable, Equatable, Identifiable { id, title, summary, tierText, isPremium, colors, seed, accessibilityIdentifier }
public struct LauncherSection: Sendable, Equatable, Identifiable { category id and title, tiles }
public enum LauncherState: Sendable, Equatable { case error(code: String), empty, noMatch, sections([LauncherSection]) }
public enum LauncherModel {
    public static func state(manifest: Result<CatalogManifest, CatalogError>, categories: CategoryList?,
                             registered: Set<ExperienceID>, searchText: String) -> LauncherState
    public static func shown(manifest: CatalogManifest, registered: Set<ExperienceID>) -> [ExperienceDescriptor]
}

public struct ShellStartup: Sendable, Equatable { public let showWelcome: Bool; public let route: ShellRoute
    public let firstFree: ExperienceID?
    public static func decide(preferences: ShellPreferences, shown: [ExperienceDescriptor]) -> ShellStartup }

public enum ResetPlan: Sendable, Equatable { case experience(ExperienceID), all
    public func namespaces(known: [ExperienceID]) -> [String]; public var removesPreferences: Bool }
```

Exact field types follow the existing `ExperienceDescriptor` of UA-F01; data-model.md gives the rules.

## Tool: `scripts/xcodebuild_app.py`

```text
python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone|tablet
        [--project VisualCore.xcodeproj] [--only-testing <id> …] [--sources Apps/VisualCore/Tests] [--log-name <name>]
```

Resolves the first available simulator of that runtime and kind (iPhone or iPad), runs
`xcodebuild test -project … -scheme … -destination "platform=iOS Simulator,id=<resolved>"
-test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO`, writes the log to
`.autonomy/logs/app-tests/<name>.log`, then runs `check_test_enumeration.py --sources … --log …`. Exit 0 only when
both pass; 2 for bad input or no such simulator. It accepts no device destination.
