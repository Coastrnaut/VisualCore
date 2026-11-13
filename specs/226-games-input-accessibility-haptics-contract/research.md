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
- 2026-11-13, baseline (T-R02F26-001): X-A01, X-A02 and X-A03 were recorded after UA-F07. As FR-U07-051 asks, their
  registrations moved from `ExperienceRegistry.candidates` to `all`, and `build_catalog.py` made the three available.
  Tests that assumed an empty catalog followed:
  - the agreement and level-name unit tests now expect the three;
  - the candidates test uses A04;
  - the real-catalog launcher test checks the three tiles;
  - the debug fixture marks every other entry unavailable;
  - the empty-launcher interface tests use the new debug argument `-vcNothingAvailable` (real catalog, nothing
    available).
  On the iOS 27.2 phone, the app unit tests and the interface chunks a, b, d, e and f pass (`baseline-app-r2`,
  `baseline-app-ui-d`, `baseline-app-ui-ef`).
- 2026-11-13, availability follow-up (found by the R02-F26 host run and the CI script tests): four pure tests read the
  real catalog and still expected nothing available. `RealCatalogTests` now expects the three integrated
  experiences, `ShellModelTests` checks that they are the ones shown and keeps the empty case with nothing
  registered, the startup test uses no registration, and `RegistryReportTests` matches with the three registered.
  The build-catalog script-test fixture copied the real ledger, where X-A01 to X-A03 are pass, with no
  registrations; it now resets the X gates to pending in its copy. Host tests 390 + 98 + 55 + 15 pass
  (`host-visualcore-r2`); script tests 383 OK.
