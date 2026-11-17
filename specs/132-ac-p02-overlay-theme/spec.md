# Feature Specification: Ambient Clock — Phase 02 Native clock overlay and one shader theme

**Feature Branch**: `132-ac-p02-overlay-theme` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A18-P02 (legacy ledger) · ID namespace FR-A18-2##, SC-A18-2##, T-A18-2##

**Input**: User description: archived manual `apps/18-ambient-clock.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP (the first of the four themes; the other three come in A18-P03): one procedural theme with quality and motion
    controls;
  - regression fixture: a time-zone change invalidates the displayed time correctly;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here** (`docs/apps/ambient-clock/visualcore-contract.json`):
  - G-OVERLAY: the native clock overlay, its layout, the contrast rule, the first theme (noise gradient), and the
    presenter that reads the clock source and the time-change monitor and labels the canvas;
  - G-BUDGETS: the frame and work budgets per quality level.
- **Experience A18 inside the one app:** registered as a candidate experience, not a standalone app. Visuals are code:
  the theme is a fragment shader over VisualCore's GLSL library; the text uses system fonts.
- Follow `specs/125-ia-p02-scene-selection` and `specs/131-ac-p01-clock-a11y`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A readable clock over a calm background (Priority: P1) 🎯

A person opens Ambient Clock and sees the current time (and the date) in large system text, readable against a slowly
moving noise gradient. The text stays correct even if the drawing stops.

**Why this priority**: the manual's MVP and its rule that the time must stay correct even if rendering is unavailable.

**Independent Test**: open the experience with a fixed clock; read the overlay text and the canvas label; draw frames
at both quality levels.

**Acceptance Scenarios**:

1. **Given** a fixed instant, **When** the experience opens, **Then** the overlay shows that instant's time and date
   and the canvas is labelled with the spoken time.
2. **Given** the theme's palette, **Then** the text colour reaches a contrast of at least 4.5 : 1 against every
   palette colour.
3. **Given** each quality level, **When** a frame is drawn, **Then** it is not blank and its work stays within the
   level's budget.

---

### User Story 2 - The time follows the world (Priority: P1)

A person who changes the time zone, or returns to the clock from the background, sees the right time at once.

**Why this priority**: the manual's regression fixture and version 0.1 feature 06.

**Independent Test**: drive the presenter with a fixed clock and a private notification centre; post a time-zone
change.

**Acceptance Scenarios**:

1. **Given** the clock showing New York time, **When** the system zone becomes Kolkata and the time-zone notification
   arrives, **Then** the overlay shows Kolkata time for the same instant in the same update.
2. **Given** the scheduled deadline passes, **When** the clock ticks, **Then** the overlay shows the new minute (or
   second) and schedules the next deadline.
3. **Given** a return to the foreground, **Then** the time is read again at once.

---

### User Story 3 - Calm motion that respects the person (Priority: P2)

A person can stop the motion of the background or slow it, and with Reduce Motion on the background is still.

**Why this priority**: the manual's motion control and accessibility.

**Independent Test**: set motion off and on; turn Reduce Motion on; draw frames at two times.

**Acceptance Scenarios**:

1. **Given** motion off or Reduce Motion on, **When** two frames are drawn at different times, **Then** they are
   identical.
2. **Given** motion on at a speed, **Then** frames at different times differ, and the speed stays within its range.

### Edge Cases

- **Rendering unavailable** (a failed draw or a lost context): the overlay keeps the correct time; the host rebuilds
  the drawing.
- **Very large text** (the largest accessibility size): the time scales down to fit the canvas without truncation.
- **Seconds shown:** the overlay updates every second; otherwise every minute.
- **A burst of time-change notifications:** each re-reads once; nothing is announced by itself.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A18-201**: The experience MUST be registered as a candidate in the one app with two quality levels and no
  permission.
- **FR-A18-202**: The background MUST be one procedural noise-gradient theme drawn in code over VisualCore's GLSL
  library, with a palette, a speed and motion on or off.
- **FR-A18-203**: The time and date MUST be drawn by the native overlay with system fonts, sized to the canvas and
  Dynamic Type, never by the shader.
- **FR-A18-204**: The text colour MUST reach a contrast of at least 4.5 : 1 against every colour of the theme's palette.
- **FR-A18-205**: The canvas MUST be labelled with the spoken time; the clock MUST NOT announce minute changes by
  itself.
- **FR-A18-206**: The presenter MUST read the time only from the injected clock source. It MUST send the time at each
  scheduled deadline and on every time-change event (time zone, locale, day, significant time change, foreground),
  and MUST rebuild the displayed text from the system's locale and zone at that moment.
- **FR-A18-207**: With motion off or Reduce Motion on, the background MUST be still; motion MUST never affect the
  shown time.
- **FR-A18-208**: Each quality level MUST have stated budgets (shader iterations, frame-rate cap, draws); a level over
  budget MUST be refused.
- **FR-A18-209**: The experience's state MUST round-trip through its snapshot; the instant is not stored.
- **FR-A18-210**: The nine standard verification scenarios MUST pass, with fixtures for a time-zone change and motion
  off.

### Key Entities

- **Clock experience state**: instant, hour cycle, seconds, date line, motion, speed, time-change revision.
- **Theme**: id, palette, speed range, quality levels.
- **Overlay layout**: time and date sizes for a canvas size and text size.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A18-201**: The overlay text equals the formatter's output for the fixed instant in 100 % of the fixtures.
- **SC-A18-202**: The time-zone fixture shows Kolkata time within one update of the notification.
- **SC-A18-203**: The text colour's contrast is at least 4.5 : 1 against all palette colours.
- **SC-A18-204**: Still frames are identical; moving frames differ; frames at both levels are not blank.
- **SC-A18-205**: Every test runs in under 10 seconds; the experience passes the nine standard scenarios on iOS 27.

## Assumptions

- The three further themes, the theme editor and favourites come in A18-P03; night mode, screen care and keep-awake
  in A18-P04.
- Fixed time-zone and locale preferences have no control yet (the editor is A18-P03); the system's are used.

## Traceability

| Source | Requirement |
|---|---|
| Phase 02 deliverable: native clock overlay and one shader theme | FR-A18-202, 203 |
| MVP: themes with quality and motion controls (the first theme) | FR-A18-202, 207, 208 |
| Regression fixture: a time-zone change invalidates the display | FR-A18-206, SC-A18-202 |
| Brainstorm: shader backgrounds, animation, typography integration | FR-A18-202–205 |
| Manual rule: the time stays correct when rendering is unavailable | FR-A18-203, Edge Cases |
| Contract G-OVERLAY, G-BUDGETS | FR-A18-201–210 |

## Negative Requirements

- No text drawn by the shader; no simulated clock; no network, location or weather; no permission; no keep-awake or
  brightness change in this phase; no purchased, generated or photographic image.
