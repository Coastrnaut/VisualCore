# Research: R02-F26

## 1. Audit (2026-11-13; agent note Build/agent-notes/R02-F26-audit.md, names re-verified by the lead)

- `GestureRecognizer` protocol (`state`, `handle(_:tracker:)`, `tick(now:)`, `reset()`), `GestureState`
  (`isTerminal`, `isActive`), Tap/DoubleTap/LongPress/Drag/Pinch/Rotate recognizers — VisualCoreScenes/GestureRecognizers.swift.
- `PointerEvent(id:phase:location:timestamp:)`, `PointerTracker` — VisualCoreScenes/PointerTracker.swift.
- `ExperiencePresenter` requirements: `setup`, `resize`, `draw`, `teardown`, `shedCaches`, `describe`, `makeControls`,
  `pointer(_:viewSize:port:)` (default no-op).
- `ShellPreferences`: `welcomeSeen`, `lastRoute`, `searchText`, `qualityOverride`, `reduceMotion`, `reduceFlashing`;
  schema 1; missing fields decode as defaults.
- `ExperienceLaunch` (app): `storage`, `reduceMotion`, `reduceFlashing`.
- No haptics code anywhere; no announcement code; two `AccessibilityChoice` types (none added).

## 2. Decisions

- **R1 Arbiter**: `GestureArbiter` holds declared recognizers with priority and pointer count; the first to leave
  `possible` with the highest priority among those able owns the touch; the others reset; a cancelled pointer phase
  cancels the owner. Output: `[GestureOutcome]` (gesture id, phase, values). Pure, `Sendable`.
- **R2 Planners**: `AnnouncementPlanner` (rate limit 0.5 s, merges to the newest, off → nothing) and `HapticPlanner`
  (kinds selection, success, warning, error, impactLight/Medium/Heavy; rate limit 0.05 s; off → nothing), both pure
  with an explicit clock.
- **R3 Colour**: `StateSign { id, colorHex, sign }` and `stateSignProblems([StateSign]) -> [String]`.
- **R4 Alternatives**: presenter `gestureActions: Set<String>` and `nativeActions: Set<String>` (default empty);
  `GestureAlternatives.missing(gesture:native:) -> [String]` sorted.
- **R5 Players**: `HapticSink` and `AnnouncementSink` protocols; `SystemHapticSink` (UIKit generators, prepared once),
  `SystemAnnouncementSink` (`UIAccessibility.post(.announcement)`), main actor.
- **R6 Hand-off**: `ShellPreferences.haptics: Bool?`; `ExperienceLaunch.haptics: Bool`; the session holds the players
  and offers `feedback(_ event:)` / `announce(_ text:kind:)` to the presenter through the action port.

## 3. Corrections during implementation

(none yet)
