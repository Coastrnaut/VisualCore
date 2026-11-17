# Feature Specification: Ambient Clock — Phase 01 Clock and time-zone correctness and accessibility

**Feature Branch**: `131-ac-p01-clock-a11y` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A18-P01 (legacy ledger) · ID namespace FR-A18-1##, SC-A18-1##, T-A18-1##

**Input**: User description: archived manual `apps/18-ambient-clock.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: accurate locale-aware time and date using the system calendar and time zone;
  - regression fixture: daylight-saving transitions and 12/24-hour formatting are tested with fixed calendar
    fixtures;
  - graphics context ownership stays solely in the audited VisualCore host (this phase draws nothing).
- **Gaps built here** (`docs/apps/ambient-clock/visualcore-contract.json`):
  - G-CLOCK: an injectable clock source with time-change events, assessed for VisualCore (two consumers: A14's "Now"
    and A18);
  - G-FORMAT: the clock preferences, the formatter and the next-tick schedule (app-local);
  - G-TIMEA11Y: the spoken time and its announcement policy (app-local).
- **Smallest vertical slice:** the clock's model is pure data tested without a GPU. The theme, the drawn overlay and
  the registration come in A18-P02, so nothing appears in the app now.
- Follow `specs/124-ia-p01-content-schema`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The clock shows the right time (Priority: P1) 🎯

A person glancing at the clock sees the correct hours and minutes (and seconds if chosen) for their locale, their
calendar and their time zone, in the 12- or 24-hour form their device uses unless they chose otherwise.

**Why this priority**: the manual's MVP and its risk 2: a wrong time breaks trust.

**Independent Test**: format fixed instants with fixed locales and zones; compare with the expected text.

**Acceptance Scenarios**:

1. **Given** a fixed instant, a locale and a time zone, **When** the time is formatted, **Then** the text shows the
   local hours and minutes in that locale's digits and order, with seconds only when chosen.
2. **Given** the 12/24-hour setting "system", **When** the locale's own convention is 12-hour (en_US) or 24-hour
   (de_DE), **Then** the text follows it; **Given** "12-hour" or "24-hour", **Then** the choice wins.
3. **Given** a date line chosen, **Then** the date is shown in the locale's long form for the same calendar day as the
   time.

---

### User Story 2 - The time stays right when the world changes (Priority: P1)

A person who travels, changes the time zone, crosses a daylight-saving change, changes the language or region, or
leaves the clock in the background sees the correct time at once on the next update.

**Why this priority**: version 0.1 feature 06 and the manual's regression fixture.

**Independent Test**: drive the model with a fixed clock through a spring-forward, a fall-back, a time-zone change, a
locale change, midnight and a foreground return.

**Acceptance Scenarios**:

1. **Given** a fixed zone with daylight saving, **When** the instant crosses the spring-forward or fall-back
   boundary, **Then** the shown hour jumps or repeats exactly as the calendar says, and the next update is scheduled
   on the next real second or minute boundary.
2. **Given** a time-zone, locale or calendar change, a significant time change (midnight, clock set) or a return to
   the foreground, **When** the event arrives, **Then** the time is read again and the text and next update are
   recomputed once.
3. **Given** the clock source in tests, **Then** it returns the injected instant; **Given** the default source,
   **Then** it reads the system clock and never adds an offset.

---

### User Story 3 - The time is heard correctly (Priority: P2)

A VoiceOver user hears the full time (hours, minutes, AM/PM or the 24-hour form, and the date when shown), and the
clock does not talk over them every minute.

**Why this priority**: accessibility is part of the phase title.

**Independent Test**: read the spoken string for each test locale; count announcements over a run of minute changes.

**Acceptance Scenarios**:

1. **Given** a formatted time, **Then** its spoken string names the hours, the minutes and the period or 24-hour
   form, and the date when the date line is shown.
2. **Given** a run of minute changes, **Then** no announcement is made by itself; the spoken string is always the
   current one, and an explicit request announces it at most as often as the planner allows.

### Edge Cases

- **Spring forward** (a local hour that does not exist): never shown; the clock moves from the last minute before to
  the first minute after.
- **Fall back** (a local hour shown twice): shown twice, in order; nothing goes backwards in the schedule.
- **A locale with other digits** (for example Arabic): its digits are used.
- **A fixed time zone or locale id that the system does not know:** refused when the preferences are read; the
  system's own is used instead.
- **Clock set backwards or forwards by the person:** a significant time change re-reads the time; the schedule never
  waits on the old deadline.
- **Midnight:** the date line changes in the same update as the time.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A18-101**: The clock's time MUST be read only from one injectable clock source. Its default MUST read the
  system clock; tests and replays MUST inject fixed instants. Nothing in production may offset or simulate time.
- **FR-A18-102**: The source MUST report each of these time changes as one event: return to the foreground, a
  significant time change, a time-zone change, a locale change and a calendar day change.
- **FR-A18-103**: Clock preferences MUST hold the 12/24-hour choice (system, 12-hour, 24-hour), seconds on or off,
  the date line on or off, and the time-zone and locale policy (system, or a fixed identifier). They MUST be
  versioned, round-trip unchanged, and refuse damaged, newer or unknown values with a named reason.
- **FR-A18-104**: The formatter MUST produce the time text, the date text and the spoken text for an instant, the
  preferences and the calendar, locale and time zone, following each locale's conventions.
- **FR-A18-105**: The schedule MUST give the next update deadline: the next whole second when seconds are shown,
  otherwise the next whole minute, in the clock's time zone, correct across daylight-saving changes.
- **FR-A18-106**: The clock state MUST change only through actions (time set, time changed, preferences set), so the
  same actions give the same state and digest.
- **FR-A18-107**: The clock MUST NOT announce minute changes by itself; an announcement on request MUST go through
  the rate-limited planner.
- **FR-A18-108**: If the clock source lands in VisualCore, it MUST carry `///` documentation, an API baseline update,
  tests and the seven-step reference regression in two chunks.
- **FR-A18-109**: The model MUST be testable without a GPU; the experience is not registered in this phase and no
  interface appears.

### Key Entities

- **Clock source**: the current instant and the stream of time-change events.
- **Clock preferences**: hour cycle, seconds, date line, time-zone policy, locale policy, schema version.
- **Clock display**: time text, date text, spoken text.
- **Clock state**: the current instant, the display, the next update deadline, the preferences.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A18-101**: 100 % of the formatting fixtures (four locales, 12/24-hour, seconds on and off, date on and off)
  give the expected text.
- **SC-A18-102**: The spring-forward and fall-back fixtures show no non-existent hour, the repeated hour twice, and a
  next deadline that is always later than the current instant and on a boundary.
- **SC-A18-103**: Each of the five time-change kinds produces exactly one recomputation in a test.
- **SC-A18-104**: Preferences round-trip unchanged; every damaged, newer or unknown input is refused with its reason.
- **SC-A18-105**: Every test runs in under 10 seconds; the app's registry and catalog are unchanged; if VisualCore
  changes, the reference regression passes 7 of 7 steps.

## Assumptions

- The theme, the drawn text and the registration arrive in A18-P02 over this model; the night mode, screen care and
  keep-awake in A18-P04.
- Locales and zones in fixtures are the system's own data; fixtures pin the identifiers, not the system's current
  settings.

## Traceability

| Source | Requirement |
|---|---|
| Phase 01 deliverable: clock and time-zone correctness and accessibility | FR-A18-101–107 |
| MVP: accurate locale-aware time with the system calendar and zone (feature 01) | FR-A18-103, 104, SC-A18-101 |
| Regression fixture: DST and 12/24-hour fixtures | FR-A18-105, SC-A18-101, 102 |
| Feature 03: 12/24-hour typography, optional seconds (the text model) | FR-A18-103, 104 |
| Feature 06: foreground, time-zone and DST updates | FR-A18-102, 105, SC-A18-103 |
| Brainstorm: typography integration (the text and spoken form) | FR-A18-104, 107 |
| Manual risk 2: time correctness, no simulated clock | FR-A18-101 |
| Contract G-CLOCK, G-FORMAT, G-TIMEA11Y | FR-A18-101–108 |

## Negative Requirements

- No simulated or offset clock in production; no network, location or weather; no permission; no interface,
  registration or drawing in this phase; no claim beyond the system clock's accuracy.
