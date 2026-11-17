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

1. **Given** any instant, **Then** the drift offset stays within 8 points, moves at most 1 point per minute and is the
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
- **FR-A18-405**: The picture and text MUST drift within 8 points, at most 1 point per minute, deterministically from
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
