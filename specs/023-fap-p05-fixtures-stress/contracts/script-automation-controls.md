# Contract: synthetic gesture script, automation hooks and playground controls

## VisualCoreScenes

```swift
public struct SyntheticGestureScript: Sendable, Equatable {
    public init(seed: UInt64, pointerCount: Int = 1, strokeSamples: Int = 30, speed: Double = 600,
                viewSize: Vec2, frameInterval: Double = 1.0 / 60)
    public let seed: UInt64, pointerCount: Int, strokeSamples: Int, speed: Double, viewSize: Vec2, frameInterval: Double
    public func events(forFrame frame: Int) -> [PointerEvent]
}
```

**Tests** (at least 8):
- identical inputs give identical events;
- different seeds give different events;
- 100 seeds × 600 frames stay in bounds;
- each pointer follows began → moved… → ended;
- timestamps strictly increase per pointer;
- the pointer count is clamped to 1…10;
- a non-finite view size or speed falls back;
- seed 0 equals seed 1;
- a negative frame gives no events.

## VisualCoreAutomation (DEBUG || VISUALCORE_AUTOMATION)

```swift
extension AutomationRunner {
    public nonisolated static let seedKey: String   // "VISUALCORE_AUTORUN_SEED"
    public nonisolated static func requestedSeed(environment: [String: String] = ProcessInfo.processInfo.environment) -> UInt64
    public var postRunCheck: (@MainActor () -> String?)?   // nil result = pass
}
AutomationView.init(..., postRunCheck: (@MainActor (RenderScene) -> String?)? = nil, ...)
```

- The check runs after smoke, launch and lifecycle, before the report is written. A failure keeps the frame data.
- Not run for `renderer-unavailable` or unknown modes.

**Tests**:
- seed parsing (missing, 0, invalid, max);
- the check passes and leaves the result "pass";
- the check fails, giving result "fail" and the message;
- the check is not called for an unknown mode.

## App UI

- **Toolbar on the playground**:
  - `fap.pause` is "Pause" or "Resume";
  - `fap.step` is "Step", disabled while running, with a hint;
  - `fap.reset` is "Reset canvas".
- **Adjust → Solver section**: a picker `fap.adjust.detail` with Low, Medium and High, and the value "Medium,
  128 by 128 cells".
- **Announcements**: Paused, Resumed, Stepped one frame, Reset to the starting picture.

## Launch environment (automation builds only)

| Key | Meaning |
|---|---|
| `VISUALCORE_AUTORUN` | smoke, launch or lifecycle |
| `VISUALCORE_AUTORUN_FRAMES` | 1…10,000 (default 120) |
| `VISUALCORE_AUTORUN_SEED` | UInt64, default 1 |

Fluid test-mode script: 4 pointers, 30 samples per stroke, 1,200 points/s. The force scale and splat cap are the
configuration maximums (aggressive by design).
