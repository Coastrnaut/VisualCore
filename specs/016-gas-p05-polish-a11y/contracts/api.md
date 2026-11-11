# Contract: Phase 05 API and UI

```swift
// VisualCoreSimulation (pure)
public enum AccessibilityChoice: String, Sendable, Codable, CaseIterable, Identifiable { case system, on, off
  public var id: String; public var title: String; public init(storedValue: String?) }   // unknown/nil → .system
public struct SystemAccessibility: Sendable, Equatable { public var reduceMotion: Bool; public var dimFlashingLights: Bool
  public init(reduceMotion: Bool = false, dimFlashingLights: Bool = false) }
public struct EffectiveAccessibility: Sendable, Equatable { public let reduceMotion: Bool; public let reduceFlashing: Bool
  public var playbackRate: Double }
public struct AccessibilityPreferences: Sendable, Equatable, Codable {
  public var reduceMotion: AccessibilityChoice; public var reduceFlashing: AccessibilityChoice
  public init(reduceMotion: AccessibilityChoice = .system, reduceFlashing: AccessibilityChoice = .system)
  public func resolve(_ system: SystemAccessibility) -> EffectiveAccessibility
}

// VisualCoreUI
@MainActor @Observable public final class SystemAccessibilityObserver {
  public private(set) var current: SystemAccessibility
  public init(source: @escaping @MainActor () -> SystemAccessibility = SystemAccessibilityObserver.systemValues)
  public static func systemValues() -> SystemAccessibility     // UIAccessibility + MADimFlashingLightsEnabled
  public func refresh()
}

// VisualCoreEffects
extension EffectScene { public var bypassEffects: Bool }   // default false
```

App UI identifiers:
- `gas.settings.open` (gallery toolbar), `gas.settings`;
- pickers `gas.settings.reduceMotion` and `gas.settings.reduceFlashing` (values "System", "On", "Off");
- `gas.settings.footer` ("Off overrides the system setting."), `gas.settings.about`, `gas.settings.done`;
- the canvas `gas.scene.canvas`, whose label is the `CanvasDescription` text.
