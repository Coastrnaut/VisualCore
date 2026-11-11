# Data model: A01-P05

## VisualCore

| Entity | Module | Fields | Rules |
|---|---|---|---|
| `AccessibilityChoice` | VisualCoreSimulation | `system`, `on`, `off` (String raw values) | Codable; unknown raw → `system`; `title` "System"/"On"/"Off" |
| `SystemAccessibility` | VisualCoreSimulation | `reduceMotion: Bool`, `dimFlashingLights: Bool` | Sendable, Equatable |
| `AccessibilityPreferences` | VisualCoreSimulation | `reduceMotion: AccessibilityChoice`, `reduceFlashing: AccessibilityChoice` (default `.system`) | `resolve(_ system:) -> EffectiveAccessibility` |
| `EffectiveAccessibility` | VisualCoreSimulation | `reduceMotion`, `reduceFlashing` (Bool) | `playbackRate` = reduceMotion ? `SceneClock.reducedMotionFactor` : 1 |
| `SystemAccessibilityObserver` | VisualCoreUI | `current: SystemAccessibility` | `init(source:)`; `refresh()`; refreshes on the reduce-motion and dim-flashing-lights notifications |
| `EffectScene.bypassEffects` | VisualCoreEffects | Bool, default false | true → content renders directly; graph and limiter state untouched |

## App

| Entity | Fields | Rules |
|---|---|---|
| `CanvasDescription` (Core) | `family`, `preset` (title or nil → "custom"), `palette` (name or "custom palette"), `seed`, `isPlaying` | `text` = "<Family>, <preset> preset, <palette> palette, seed <n>, <playing/paused>." |
| Stored choices | `gas.a11y.reduceMotion`, `gas.a11y.reduceFlashing` → `AccessibilityChoice.rawValue` | absent or unknown → System |
