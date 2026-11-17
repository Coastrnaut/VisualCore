# Feature Specification: Ambient Clock — Phase 04 Power and visibility controls

**Feature Branch**: `134-ac-p04-power-visibility` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A18-P04 (legacy ledger) · ID namespace FR-A18-4##, SC-A18-4##, T-A18-4##

**Input**: User description: archived manual `apps/18-ambient-clock.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):**
  - MVP: the theme editor with saveable favourites (built in A18-P03) keeps working with every power setting;
  - regression fixture: returning to the app never shows the old time while the drawing refreshes;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here** (`docs/apps/ambient-clock/visualcore-contract.json`):
  - G-NIGHT: night mode;
  - G-MOTION: the motion-reduction option;
  - G-FRAMERATE: a frame-rate cap an experience can declare, assessed for VisualCoreExperienceHost;
  - G-SCREENCARE: pixel drift and idle dimming;
  - G-AWAKE: opt-in keep-awake.
- Follow `specs/133-ac-p03-themes-favourites`.

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `RenderHost(scene:maxFramesPerSecond:budget:)` defaults to 60, and `ExperienceSession.swift:287` builds it without a
  cap.
- `FramePacing(thermal:lowPower:requestedMaxFPS:)` keeps a floor of `FramePacing.minimumFPS` (30) and lowers the rate
  for heat and Low Power Mode.
- No source in the repository sets `isIdleTimerDisabled` or writes `UIScreen.brightness`.
- The presenter receives no scene phase; `UIApplication` notifications reach it through the injected centre (A18-P02).
- The snapshot is schema 2 (A18-P03).

- Q: How does an experience declare its frame cap? → A: An additive requirement of `ExperiencePresenter` in
  VisualCoreExperienceHost: `var maxFramesPerSecond: Int { get }`, defaulting to 60 in a protocol extension.
  `ExperienceSession` passes it to `RenderHost(scene:maxFramesPerSecond:budget:)` when it builds the host.
  `FramePacing` still applies its floor of 30 and its heat and Low Power Mode reductions. Every other experience
  keeps 60.

  Ambient Clock declares 30 at all times. Its text changes once a second at most and its themes move slowly, so night
  mode needs no lower cap (30 is the floor).
- Q: What is night mode exactly? → A: The core holds:
  - `nightMode` (0 off, 1 on, 2 scheduled) with `nightStart` and `nightEnd` in minutes of the day (defaults 1,320 and
    420, that is 22:00 and 07:00);
  - `nightDim` (0.3–1, default 0.5).

  At night the shader multiplies its colour by `nightDim` and by a warm tint (1, 0.75, 0.55). The time text becomes
  warm amber, #FFB27A, which must reach at least 4.5 : 1 against every dimmed and tinted palette colour (checked over
  all 48 colours). Scheduled mode reads the local time from the presenter's display environment: start ≤ end means
  [start, end), start > end wraps midnight, and start = end is never night.
- Q: How do screen care's drift and dimming work? → A: Drift:
  - offset = 8 points × (sin(2π·t/600), sin(2π·t/840)), with t the instant in seconds;
  - so at most 8 points, and at most 2π·8/600 × 60 ≈ 5 points per minute.

  The spec's "1 point per minute" is corrected to "at most 6 points per minute". Under reduced motion the offset is
  zero. It moves the overlay and the scene by the same points.

  Idle dimming: after 600 s without an action, a dim factor of 0.6 multiplies the scene and the text opacity. Any sent
  action restores it, with the last-action instant taken from the clock source.
- Q: How is keep-awake made testable and confined? → A: Through an `IdleTimerPort` protocol with one production type,
  `ApplicationIdleTimer`, in `Experience/KeepAwake.swift`. It is the only file that names `isIdleTimerDisabled`.
  - The presenter sets it on when the `keepAwake` setting is on and the clock is visible (setup or
    `didBecomeActive`).
  - It sets it off on `willResignActive`, `didEnterBackground`, teardown and setting off.
  - Tests inject a recording port.

  A source-scan test over the experience's folder finds `isIdleTimerDisabled` in exactly `KeepAwake.swift`, and
  `brightness =` in no file.
- Q: What changes in the saved state, and what is the resume fixture? → A: Snapshot schema 3 adds `nightMode`,
  `nightStart`, `nightEnd`, `nightDim`, `reduceMotion` (the in-app option) and `keepAwake`. The defaults are off, 1,320,
  420, 0.5, off and off. Migration 2 → 3 fills the defaults, and the schema-1 and schema-2 examples are registered.

  New controls: `night.mode` [0…2], `night.window` [0…1439, 0…1439], `night.dim` [0.3…1], `motion.reduce` [0…1] and
  `screen.keepAwake` [0…1].

  The resume fixture: the display shows the old minute; the clock advances 30 minutes; posting `willEnterForeground`
  makes the display show the new time before any `draw`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A clock that is kind at night (Priority: P1) 🎯

A person sets night mode on, off or on a schedule (for example 22:00–07:00). At night the clock is dimmer and warmer
and stays readable, and the device's own screen brightness is never changed.

**Why this priority**: version 0.1 feature 05 and the manual's thermal and burn-in risk.

**Independent Test**: evaluate the schedule at fixed times; compute the contrast of the night text against the dimmed
palettes; draw a night frame.

**Acceptance Scenarios**:

1. **Given** a schedule of 22:00–07:00, **When** the local time is 21:59, 22:00, 06:59 and 07:00, **Then** night mode is
   off, on, on and off.
2. **Given** night mode on, **Then** the drawing is dimmer than by day and the time text reaches at least 4.5 : 1
   against every dimmed palette colour.
3. **Given** any setting, **Then** the device's screen brightness is never written.

---

### User Story 2 - Calm motion and a light load (Priority: P1)

A person can reduce motion in the clock itself (as well as through the system setting), and the clock never draws more
often than it needs.

**Why this priority**: the motion-reduction option of feature 05 and the manual's thermal risk.

**Independent Test**: turn the option on; read the frame cap of the clock's session.

**Acceptance Scenarios**:

1. **Given** the clock's own reduce-motion option or the system setting on, **Then** frames at different times are
   identical and theme changes cut.
2. **Given** the clock open, **Then** its frame cap is 30 per second, never below the platform floor; every other
   experience keeps its cap of 60.

---

### User Story 3 - Screen care and keeping the screen on (Priority: P2)

A person leaving the clock on a stand sees the picture and text drift very slowly and dim after a while without use;
they can choose to keep the screen on while the clock is open.

**Why this priority**: the manual's burn-in risk and keep-awake policy.

**Independent Test**: evaluate the drift and dimming at fixed instants; drive an injected idle-timer port through
visibility changes; scan the sources.

**Acceptance Scenarios**:

1. **Given** any instant, **Then** the drift offset stays within 8 points, moves at most 6 points per minute and is the
   same for the same instant.
2. **Given** 10 minutes without an action, **Then** the clock dims; any action restores it.
3. **Given** keep-awake on and the clock visible, **Then** the idle timer is disabled; on background, close or teardown
   it is released; with keep-awake off it is never disabled.
4. **Given** the experience's sources, **Then** the idle-timer setting appears in exactly one file.

### Edge Cases

- **A schedule that crosses midnight** (22:00–07:00) and one that does not (13:00–14:00): both evaluated correctly; an
  empty schedule (start equals end) is never night.
- **Returning from the background** with an old time on screen: the time text is replaced before the next frame.
- **Reduce Motion on with drift:** the drift is held still.
- **Low Power Mode or heat:** the platform may lower the frame rate further; the clock's cap never raises it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A18-401**: Night mode MUST be off, on or scheduled (start and end in minutes of the day), MUST dim and warm the
  drawing in the scene, and MUST keep the time text at least 4.5 : 1 against every dimmed palette colour.
- **FR-A18-402**: The device's screen brightness MUST never be written.
- **FR-A18-403**: The clock's own reduce-motion option and the system setting MUST each still the picture and cut theme
  changes.
- **FR-A18-404**: An experience MUST be able to declare a frame cap, never below the platform floor; the default for
  every other experience MUST stay unchanged; Ambient Clock declares 30.
- **FR-A18-405**: The picture and text MUST drift within 8 points, at most 6 points per minute, deterministically from
  the instant; under reduced motion the drift is still.
- **FR-A18-406**: After 10 minutes without an action the clock MUST dim; any action MUST restore it.
- **FR-A18-407**: Keep-awake MUST be off by default and, when on, disable the idle timer only while the clock is
  visible, releasing it on background, close and teardown, in exactly one named source file.
- **FR-A18-408**: On returning to the foreground the time text MUST show the current time before the next frame.
- **FR-A18-409**: The saved state MUST migrate from the A18-P03 schema; the frame-cap change in VisualCore MUST carry
  `///` documentation, an API baseline update and tests, and the reference regression at X-A18.

### Key Entities

- **Night policy**: mode (off, on, scheduled), start and end minutes, dim level.
- **Screen care**: drift offset, idle interval, dim factor.
- **Keep-awake**: setting, visibility, idle-timer state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A18-401**: The schedule fixtures switch at exactly their boundaries; 100 % of night palettes reach 4.5 : 1.
- **SC-A18-402**: A source scan finds no screen-brightness write and the idle-timer setting in exactly one file.
- **SC-A18-403**: The clock's session caps at 30 frames per second; another experience stays at 60.
- **SC-A18-404**: Drift stays within bound and rate over a simulated day of fixed instants (sampled, not run in real
  time).
- **SC-A18-405**: Every test runs in under 10 seconds; the nine standard scenarios pass on iOS 27.

## Assumptions

- Device measurements of brightness, heat and battery are A18-P05 {device} tasks.
- The privacy page that states the keep-awake behaviour (A18-P00 clarification 4) is written in A18-P06 with the
  release documents; this phase fixes the behaviour and the one named file it will cite.

## Traceability

| Source | Requirement |
|---|---|
| Phase 04 deliverable: power and visibility controls | FR-A18-401–408 |
| MVP: the theme editor with favourites keeps working | FR-A18-409 (migration), Phase 03 |
| Regression fixture: resume never shows the old time | FR-A18-408 |
| Feature 05: night mode and motion reduction | FR-A18-401, 403 |
| Manual risk 1: thermal load and burn-in | FR-A18-404–406 |
| Contract G-NIGHT, G-MOTION, G-FRAMERATE, G-SCREENCARE, G-AWAKE | FR-A18-401–409 |

## Negative Requirements

- No write of the screen brightness; no keep-awake by default; no idle-timer use outside one file; no background
  rendering; no screen-on guarantee claimed.
