# Research: UA-F03 — Experience host and session lifecycle

Date: 2026-11-12. Read-only audit of the sources the brief names, then the decisions of the plan. Every API named
in plan.md, data-model.md and the contract was read in the source at commit `faad563` or later.

## 1. Audit

| Surface | Where | What was verified |
|---|---|---|
| `Experience`, `ExperienceShell`, `ExperienceActionPort` | `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/` (UA-F02) | `prepare(seed:timeLimit:) async throws(ExperienceError)`, `cancelPreparation()`, `activate()`, `suspend()`, `resume()`, `snapshot()`, `restore(_:)`, `shedCaches()`, `beginDeactivation()`, `finishDeactivation()` (reads the registry, throws `.gpuLeak`), `state`, `scene`, `controls`, `accessibilitySummary`, `diagnostics`. Setup and draw errors move the shell to failed with the codes `experience.setup-failed` and `experience.draw-failed`. The shell never creates a render host. |
| `RenderHost` | `…/VisualCoreRendering/RenderHost.swift` | `init(scene:maxFramesPerSecond:budget:) throws`; `view`; `state`; `resources`; `lastError`; `pause()` and `resume()` (an app-requested pause that survives background and foreground); `recreateContext()`; `renderOneFrame(present:)`; `readPixels()`; `destroy()`; `addErrorObserver(_:)` and `addObserver(_:)` for lifecycle events. The host observes background, foreground and memory warnings itself: it drains and suspends in the background and trims its pools on a memory warning. |
| `ResourceRegistry`, `ResourceLedger`, `ResourceBudget` | rendering and diagnostics modules | `stats` (`liveCount`, `liveBytes`, `totalBytes`, `peakBytes`, `leaked`); `ResourceBudget(total:perKind:)`, default total 256 MiB. An allocation beyond the budget throws, so live bytes never exceed the budget: the "still over budget" rule needs its own limit (clarification 4). |
| `FrameScheduler` | `…/VisualCoreRendering/FrameScheduler.swift` | Owned by the render host; paused through the host. The session does not touch it. |
| `QualityPolicy`, `DeviceConditions` | diagnostics module | Tier choice from thermal state and Low Power Mode; `DeviceConditions.current()`. Used by UA-F06; this feature passes the tier through unchanged. |
| `RenderSurface` | `…/VisualCoreUI/RenderSurface.swift` | SwiftUI wrapper of a caller-owned host with an accessibility label and hint. |
| `check_app_isolation.py` | `scripts/` | `--app <folder>` (must exist, else exit 2), scans Swift sources outside `Tests` and `Generated` for imports of the two graphics shims and for `egl…(` calls, and for networking names; prints `PASS|FAIL: <app> — <n> app Swift files, <m> isolation problems`. It does not look for direct `gl…(` or `vcgl…(` calls. |
| Localization in the rendering package | `Packages/VisualCoreRendering/Package.swift` | No default localization and no string resources yet. |
| `Apps/VisualCore` | repository | Does not exist yet (UA-F04 creates it). |

## 2. Names of the brief, confirmed or corrected

| Name | Result |
|---|---|
| `ExperienceSession`, `ExperienceHostView` | new, in `VisualCoreExperienceHost` |
| "the session's ResourceRegistry" | the registry of the render host the session created (`host.resources`) |
| `python3 scripts/check_app_isolation.py --app Apps/VisualCore` | the folder does not exist before UA-F04; the tool is changed so that a folder without sources, or one that does not exist yet, is reported in plain words as "nothing checked" with exit 0, and `--require-sources` turns that into an error for gates that must find sources |
| "extended to experience modules" | new option `--experiences <folder>…` with the wider pattern set (also direct `gl…(` and `vcgl…(` calls) |

## 3. Decisions

### R1. Pure session lifecycle in VisualCoreExperience
- **Decision**: `SessionLifecycle` (state table, counters), `SessionCloseStep.order`, `MemoryPressureRule`,
  `SessionFailure`, `SessionStageTimings`, `SessionDiagnostics`, `SessionOpenResult` and `ScenePhaseInput` are
  value types in the pure module; the main-actor session records every step it takes through them.
- **Rationale**: clarification 5 and Principle IV; the order of a close becomes a tested list instead of a habit.
- **Alternatives**: all logic in the main-actor class (testable only on simulators).

### R2. The session owns the render host and builds the experience from a factory
- **Decision**: `ExperienceOpenRequest` carries `make: @MainActor () -> any Experience`. The session creates
  `RenderHost(scene: experience.scene, budget:)` after a successful preparation and destroys it on every exit.
- **Rationale**: clarification 1; FR-U03-012. Creating the host after preparation means a cancelled preparation
  never has a host (FR-U03-032).

### R3. Newest open wins, through a generation counter
- **Decision**: `open` is `async` and returns `SessionOpenResult`. Each open takes a new generation number,
  closes what is there, and checks the number after every suspension point; a stale open returns `.superseded`
  (or `.cancelled` when it was closed).
- **Rationale**: clarification 2; one integer decides, as in the engine's preparation ticket.

### R4. Failures reach the session through the experience's state and the host's error observer
- **Decision**: after preparation the session checks the result; for setup and drawing it registers
  `host.addErrorObserver`: a `.scene` error with the experience in failed, and `.unsupported` or a context that
  could not be recreated, call the session's `fail`. Failing destroys the host and keeps the failure for the view.
- **Rationale**: the render host already reports scene errors; no polling.

### R5. Phases and memory
- **Decision**: `setScenePhase(_:)` is the one entry for phases (the host view forwards SwiftUI's `scenePhase`);
  not active → `experience.suspend()`, snapshot to the sink, `host.pause()`; active → `host.resume()`,
  `experience.resume()`. The session adds one observer for
  `UIApplication.didReceiveMemoryWarningNotification` and offers `handleMemoryWarning()` for tests. The pressure
  limit defaults to half of the budget's total.
- **Rationale**: clarifications 3 and 4; the host's own observers stay as they are (FR-U03-044).

### R6. Host view and texts
- **Decision**: `ExperienceHostView` switches on the session's state: `RenderSurface` plus controls, a preparing
  view with Cancel, a failure view with Retry and Back, a message view with Back. Each state view is scrollable,
  and its buttons use one style with a minimum of 44 by 44 points. Texts live in a string catalog of the module
  (`Resources/Localizable.xcstrings`, default localization `en`) and are read through one `SessionStrings` type.
- **Rationale**: FR-U03-060 to FR-U03-063. If the string catalog does not build for a package target on this
  toolchain, the fallback is a `Localizable.strings` file in `en.lproj`; the deviation is recorded then.

### R7. Proving the layout without an app
- **Decision**: simulator tests host each state view in a window of 320 by 568 points at the largest
  accessibility text size and check that the laid-out content is reachable (inside the scroll content, width not
  above the screen) and that the button style's minimum is 44 points. The full interface test with VoiceOver
  identifiers runs in the app's UI tests of UA-F04, which this plan names as the place for it.
- **Rationale**: there is no app target before UA-F04; a package test can measure layout, not drive taps.

### R8. Isolation tool
- **Decision**: `--experiences` takes any number of folders and uses the patterns of `--app` plus direct GL
  calls; `--app` keeps its behavior for existing apps; a missing or empty folder prints
  `PASS: <path> — nothing checked (no Swift sources yet)`; `--require-sources` makes that exit 1.
- **Rationale**: section 2. The test presenter of this feature lives under `Tests`, which the tool skips by
  rule, so FR-U03-091 needs no exception; the output states the number of skipped test files.

### R9. Limits
| Limit | Value |
|---|---|
| Preparation time limit | 10 s by default |
| Memory-pressure limit | half of the budget's total by default; at least 1 byte |
| Open and close cycles in the acceptance test | 50 |
| Failure text | at most 500 characters (from `ExperienceFailure`) |

## 4. Not verified here
- Memory and thermal behavior of long sessions on devices: a `{device}` task, never claimed from simulators.
- Taps on the host view's controls by a UI test: UA-F04, in the app.
