# Data model: A18-P04 (feature 134)

## VisualCoreExperienceHost

- `ExperiencePresenter.maxFramesPerSecond: Int { get }`, defaulting to 60 in a protocol extension.
- `Experience.maxFramesPerSecond` (default 60), which `ExperienceShell` forwards from its presenter. It is needed
  because the session holds the experience, not the presenter.
- `ExperienceSession` builds `RenderHost(scene:maxFramesPerSecond:budget:)` with it.

## AmbientClockCore

- **`NightPolicy`:**
  - fields: `mode` (off, on, scheduled), `start` and `end` (0…1439), `dim` (0.3…1);
  - `isNight(localMinute:)`;
  - `tint` = (1, 0.75, 0.55), and `textColor` #FFB27A;
  - `contrastProblems(palettes:)` is empty when the night text reaches 4.5 : 1 against every colour × dim × tint at
    the darkest allowed dim and at 1.
- **`ScreenCare`:**
  - `drift(at:reduceMotion:) -> (x, y)` in points: 8 × (sin 2πt/600, sin 2πt/840), or (0, 0) under reduced motion;
  - `dimFactor(now:lastAction:)` is 1 before 600 s and 0.6 after.

## Experience

- **`AmbientCore` schema 3** adds:
  - `nightMode` (0…2), `nightStart` and `nightEnd` (0…1439), `nightDim` (0.3…1);
  - `reduceMotion` (Bool) and `keepAwake` (Bool).

  Controls: `night.mode` [0…2], `night.window` [0…1439, 0…1439], `night.dim` [0.3…1], `motion.reduce` [0…1] and
  `screen.keepAwake` [0…1]. Migration 2 → 3 fills the defaults (0, 1,320, 420, 0.5, false, false). Outcome
  `night-on` when night mode is on (1).
- **`KeepAwake`:** `protocol IdleTimerPort { var keepsScreenAwake: Bool { get set } }`, with
  `ApplicationIdleTimer` (UIKit). It is the only implementation that touches `UIApplication.shared.isIdleTimerDisabled`,
  so only `KeepAwake.swift` names it. `KeepAwakeController.update(setting:visible:)` writes only when the value changes.
- **Presenter:**
  - `maxFramesPerSecond == 30`;
  - the visibility observers (`didBecomeActive`, `willResignActive`, `didEnterBackground`) on the injected centre;
  - `lastActionInstant`;
  - per-frame night and drift values as six float uniforms (`u_nightDim`, `u_nightTintR/G/B`, `u_driftX`,
    `u_driftY`) joined by `#define u_night` and `#define u_drift`, because `FullScreenShaderScene` binds floats only;
    the tint is applied to the sRGB-encoded output;
  - the shown drift rounded to 0.5 point (`shownDrift`);
  - `noteAction()`, which counts control and favourite actions but not `time.set` or `time.changed`;
  - the overlay offset and opacity.
