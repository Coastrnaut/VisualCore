# Contract: Showcase (Phase 6)

## UI / accessibility contract (used by the smoke test)

| Identifier | Element | Value |
|---|---|---|
| `showcase.scene.<id>` | scene list row | label = title, hint = summary |
| `showcase.canvas` | render surface | label = scene accessibility description, hint = interaction hint, direct interaction |
| `showcase.diagnostics` | static text | `frames=… fps=… state=… gen=… live=… bytes=… peak=… warnings=… leaked=… error=…` |
| `showcase.status` | static text | scene status string |
| `showcase.contextLoss` | button | "Simulate context loss" |
| `showcase.effectToggle` | toggle (post-processing) | "Post-processing" on/off |
| `showcase.diagnosticsToggle` | toolbar button | "Show diagnostics" / "Hide diagnostics" |

Launch arguments: `-uitestReduceMotion YES|NO`, `-showcaseInjectShaderError YES` (debug builds only).

## Audit CLI

```text
python3 scripts/audit_showcase_dependencies.py [--spec project.yml] [--sources Showcase] [--app <path/to/Showcase.app>]
        [--packages Packages/VisualCore Packages/VisualCoreRendering] [--json <report>]
exit 0 = no findings; exit 1 = findings (each printed as "<layer>: <item>"); exit 2 = usage/input error
```

## Framework addition

```swift
extension Texture { @MainActor public func upload(rgba: [UInt8]) -> Bool }   // rgba8 only; size must match
```
