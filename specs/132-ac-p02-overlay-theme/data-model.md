# Data model: A18-P02 (feature 132)

## AmbientCore (ExperienceCore)

- **Fields:**
  - `instant: Double` (seconds since 1970; 0 until the first `time.set`);
  - `hourCycle: Int` (0 system, 1 h12, 2 h24);
  - `showSeconds: Bool` (false) and `showDate: Bool` (true);
  - `motion: Bool` (true) and `speed: Double` (0.25–2; default 1);
  - `revision: Int`, which grows by one per `time.changed`;
  - `qualityTier` (presentation only).
- **Controls:**
  - `time.set` [0…4.1e9];
  - `time.changed` [0…4], in `TimeChangeKind.allCases` order;
  - `clock.format` [0…2, 0…1, 0…1];
  - `theme.motion` [0…1] and `theme.speed` [0.25…2].
- **Quality:** `qualityTiers == 2`; `qualityProfile` has `level-0` (iterationShare 1, resolutionShare 1) and
  `level-1` (iterationShare 0.6, resolutionShare 0.5). Octaves are 5 and 3.
- **Snapshot:** schema 1 holds `hourCycle`, `showSeconds`, `showDate`, `motion` and `speed`; the instant and the
  revision are not stored.
- **Outcome:** `showing-time`, and `motion-off` when motion is off.

## Presenter

- `AmbientPresenter(clock: ClockSource = SystemClock(), environment: @Sendable () -> (Locale, TimeZone) = system,
  center: NotificationCenter = .default, reduceMotion: Bool)`.
- `display: AmbientClockState` follows the core's instants and format, with the environment read on each `time.set`
  and `time.changed`.
- `tick(port:) -> Date`: sends `time.set` with `clock.now` and returns the next deadline.
- `timeChanged(_ kind:, port:)`: sends `time.changed`.
- `describe(core)` is the spoken string, and `probes` holds the centre as `dark`.
- `NoiseGradientTheme`: the fragment source, the palette (four linear colours), the uniforms (`u_resolution`,
  `u_time`, `u_octaves`, `u_palette`) and `textColor` (white), with `minimumContrast()`.
- `ClockOverlay`: a SwiftUI view with the time and date text, sized per research D5, running the tick task.
