# Feature Specification: Solar System Explorer — Phase 04 Time controls and guided tours

**Feature Branch**: `106-sse-p04-time-tours` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A14-P04 (legacy ledger) · ID namespace FR-A14-4##, SC-A14-4##, T-A14-4##

**Input**: User description: archived manual `apps/14-solar-system-explorer.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — play, pause and speed up simulated motion with an explicit UTC date, and
  captioned guided tours over the bodies; regression fixture — the same commands give the same instants, the date
  never leaves the model's range, and a tour is bounded and skippable; graphics context ownership stays solely in the
  VisualCore host.
- **Gaps built here** (contract `docs/apps/solar-system-explorer/visualcore-contract.json`): G-TIME (rows M05, M08,
  M15, M22) — the simulated clock, rates, range clamp, UTC label and reset to the present, app-local; G-TOURS (rows
  M10, M11, M23) — captioned tours, fact cards with units and citations, the saved view document and the on-canvas
  labels, app-local, plus one generic addition to the VisualCore host: an optional, non-interactive overlay drawn over
  the canvas, which the labels and captions use (documented, tested, recorded in the API baseline; the reference
  regression runs at X-A14).
- **Experience:** the 3D view of A14-P03 gains time controls, two guided tours, a saved view and labels on the canvas.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A14; every Spec Kit step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch the planets move (Priority: P1) 🎯

A person presses play and watches the planets move along their orbits; they choose a faster rate, pause, and always
see the date and time in UTC; at the end of the model's range motion stops with a reason; "Now" jumps to today.

**Why this priority**: the phase's MVP ("play, pause and speed up simulated motion with an explicit date").

**Independent Test**: play at each rate for a known number of steps; read the date; run into the range end.

**Acceptance Scenarios**:

1. **Given** play at a rate, **When** a known number of steps pass, **Then** the date has advanced by rate × elapsed
   simulated seconds and the planets have moved accordingly.
2. **Given** motion reaching the end of the range, **Then** it stops exactly at the end, pauses, and says why.
3. **Given** "Now", **Then** the date becomes the current instant (from the device clock), clamped to the range.
4. **Given** the app in the background, **Then** no simulated time passes.

---

### User Story 2 - Follow a guided tour (Priority: P1)

A person starts a tour; the camera visits a short sequence of bodies, holding at each while a caption describes it;
they can pause, skip to the next stop or stop the tour; with Reduce Motion the camera cuts between stops.

**Why this priority**: the manual's guided tours with captions.

**Independent Test**: start each tour; step through stops; pause, skip, stop.

**Acceptance Scenarios**:

1. **Given** a tour, **When** started, **Then** it visits its stops in order, each held for a stated time with a
   caption, and ends by itself.
2. **Given** a running tour, **When** paused, skipped or stopped, **Then** it holds, moves to the next stop, or ends.
3. **Given** any caption, **Then** every number in it comes from the sourced catalog with its unit.

---

### User Story 3 - Labels and a saved view (Priority: P2)

A person sees body names on the canvas next to the bodies (never overlapping the controls, hidden for bodies behind
the camera) and can save the current view and restore it later.

**Why this priority**: the manual's labels and saved view state.

**Independent Test**: project labels for several views; save a view, change everything, restore it.

**Acceptance Scenarios**:

1. **Given** a view, **When** drawn, **Then** each visible body's label sits at its projected position and labels do
   not overlap one another.
2. **Given** a saved view, **When** restored, **Then** the body, date, rate, camera and scale mode return; a damaged,
   newer or oversized saved file is refused with a reason.

### Edge Cases

- **Playing into either end of the range:** stops exactly at the end, never beyond.
- **A date step while playing:** applies immediately; play continues.
- **A tour while time is playing:** the tour controls the camera; time keeps its own play state.
- **Bodies behind the camera or off the canvas:** no label.
- **Rapid announcements:** the spoken date while playing is rate-limited.

## Requirements *(mandatory)*

### Functional Requirements

**Time (story 1)**

- **FR-A14-401**: The state MUST hold play/pause and a rate from a fixed list of simulated days per second; each host
  step while playing advances the date by rate × step duration.
- **FR-A14-402**: Motion MUST stop exactly at either end of the range, pausing with a stated reason.
- **FR-A14-403**: "Now" MUST set the date to the current instant from an injected clock, clamped to the range; the
  date is shown and spoken as a UTC date and time; spoken updates while playing are rate-limited.

**Tours (story 2)**

- **FR-A14-410**: At least two bundled tours MUST exist, each with a bounded number of stops; each stop names a body,
  a hold time and a caption built from catalog values with units and sources.
- **FR-A14-411**: Tours MUST be startable, pausable, skippable and stoppable through actions; the camera flies between
  stops (Reduce Motion cuts); a tour ends by itself after its last stop.

**Labels and saved view (story 3)**

- **FR-A14-420**: The VisualCore host MUST offer an optional, non-interactive overlay drawn over the canvas; the
  experience places body labels at projected positions there, without overlaps, hidden behind the camera.
- **FR-A14-421**: A saved view document (body, date, rate, camera, scale mode) MUST round-trip through the
  experience's storage; damaged, newer and oversized documents are refused with a reason.

**Integration**

- **FR-A14-430**: The scenario manifest MUST be updated (state schema 4 with migration from 3) and pass the runner on
  iOS 27; the contract closes G-TIME and G-TOURS; the VisualCore addition is documented, tested and in the API baseline.

### Key Entities

- **Clock state**: playing, rate index, last stop reason.
- **Tour**: id, title, stops (body, hold, caption).
- **Tour state**: tour, stop, progress in the stop, paused.
- **Saved view**: schema, body, date, rate, yaw, pitch, zoom, scale mode.
- **Label**: body, projected point, visibility.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A14-401**: For every rate, N steps advance the date by exactly rate × N × step duration (within 1e-9 days);
  the same command stream gives the same digest.
- **SC-A14-402**: 100 % of runs into either range end stop exactly at the end with a reason.
- **SC-A14-403**: Every tour has at most 6 stops and lasts at most 40 s; every caption's numbers match the catalog.
- **SC-A14-404**: Labels never overlap one another and none is shown for a body behind the camera, for the tested views.
- **SC-A14-405**: The saved view round-trips exactly; 100 % of damaged, newer and oversized documents are refused.
- **SC-A14-406**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The catalog, orbit model, scale modes and focus flight of A14-P01 to A14-P03 exist; VisualCore's experience storage,
  orbit camera projection and announcement sink exist.
- The host steps the core only while the experience is active, so backgrounding cannot fast-forward time.

## Traceability

| Source | Requirement |
|---|---|
| Phase 04 MVP: play, pause, speed and UTC date | FR-A14-401–403 |
| Phase 04 MVP: guided tours with captions | FR-A14-410, 411 |
| v0.1 feature 3 and 5: time controls, guided tours | FR-A14-401–411 |
| Labels and overlays, saved view state | FR-A14-420, 421 |
| Contract gaps G-TIME (M05, M08, M15, M22), G-TOURS (M10, M11, M23) | FR-A14-401–430 |

## Negative Requirements

- No network, no live sky positions, no audio narration, no flashing; no time beyond the model's range; no labels that
  take touches or cover the controls.
