# Feature Specification: Aurora — Phase 02 Scene selection and controls

**Feature Branch**: `153-au-p02-scene-controls` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A21-P02 (legacy ledger) · ID namespace FR-A21-2##, SC-A21-2##, T-A21-2##

**Input**: User description: archived manual `apps/21-aurora.md` §9 Phase 02 `/speckit-specify` prompt (verbatim in
the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: colour, motion and intensity controls with sensible bounds;
  - regression fixture: a scene transition cannot exceed the person's luminance cap;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-CONTROLS, G-CAP and G-CHROME of `docs/apps/aurora/visualcore-contract.json`.
- **The experience arrives:** Aurora is drawn in the one app for the first time and registered as a candidate; it is
  not yet available to a person (that is X-A21).
- **No VisualCore or ProjectM change.** Follow `specs/146-zg-p02-sand-renderer`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose a sky and tune it (Priority: P1) 🎯

A person picks one of the three skies and tunes it: its colours, how fast and how wildly it moves, how many ribbons,
stars and clouds it shows, and how bright it may get. Every control stays within sensible bounds, and the sky changes
smoothly.

**Why this priority**: the manual's version 0.1 feature 02 and its second journey.

**Independent Test**: select each preset; move each control to and past its ends; read the state.

**Acceptance Scenarios**:

1. **Given** the experience, **When** a preset is chosen, **Then** the sky shows that preset's scene.
2. **Given** any control, **When** it is set beyond its range, **Then** the value is refused or held at its bound and
   the sky is unchanged otherwise.

---

### User Story 2 - The sky never gets brighter than the person allows (Priority: P1)

A person sets a brightness limit. Whatever preset, control or change between skies is shown, no part of the picture
is brighter than that limit, including in the middle of a change.

**Why this priority**: the manual's regression fixture and risk 2 (bright imagery may discomfort people).

**Independent Test**: draw every preset and the midpoint of every change between presets at several limits; measure.

**Acceptance Scenarios**:

1. **Given** a limit, **When** any preset is drawn, **Then** no pixel is brighter than the limit.
2. **Given** a change from one preset to another, **When** it is drawn at its start, middle and end, **Then** no pixel
   is brighter than the limit.

---

### User Story 3 - Controls step aside and come back (Priority: P2)

The sky fills the screen. A person hides the controls and brings them back with a tap anywhere on the sky, or with an
accessibility action.

**Why this priority**: the manual's version 0.1 feature 06.

**Independent Test**: hide the controls; tap; use the accessibility action.

**Acceptance Scenarios**:

1. **Given** the controls hidden, **When** the person taps the sky, **Then** the controls return.
2. **Given** VoiceOver, **When** the controls are hidden, **Then** an action to show them is offered.

### Edge Cases

- **A preset change while another change is running:** the new change starts from the current blend; nothing jumps.
- **A limit below the darkest preset's brightest pixel:** the whole picture is dimmed, never clipped to white.
- **Reduce Motion:** changes between presets happen without the blend (an immediate change), and the sky is still.
- **A context loss or resize:** the sky is rebuilt from the state with the same picture.
- **Hidden controls and an incoming accessibility focus:** the action to show them is always reachable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A21-201**: The experience MUST let a person choose a preset and set colour, motion and intensity values, each
  as a native control with a spoken label and bounds.
- **FR-A21-202**: Every value outside its range MUST be refused or held at its bound, and a refused value MUST leave
  the state unchanged.
- **FR-A21-203**: A brightness limit MUST cap every pixel of every drawn frame, including during a change between
  presets.
- **FR-A21-204**: A change between presets MUST blend smoothly over a bounded time without exceeding the limit, and
  MUST be immediate under Reduce Motion.
- **FR-A21-205**: The controls MUST hide and return with a tap on the sky or an accessibility action.
- **FR-A21-206**: Aurora MUST be registered as a candidate of the one app with its scenarios, quality levels and
  capabilities; it MUST NOT become available to a person in this phase.
- **FR-A21-207**: The experience MUST issue no GL call outside the scene protocol, and the sky MUST be rebuilt from
  the state after a context loss or a resize.

### Key Entities

- **Sky state**: the scene, the brightness limit, the change in progress (from, to, progress), controls hidden.
- **Brightness limit**: a luminance ceiling applied after compositing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A21-201**: 100% of out-of-range values are refused or held, with the state otherwise unchanged.
- **SC-A21-202**: In 100% of sampled frames (every preset, the start, middle and end of every change, several limits)
  no pixel exceeds the limit.
- **SC-A21-203**: Hidden controls return by tap and by the accessibility action in 100% of trials.
- **SC-A21-204**: Each unit test runs under 10 seconds; the experience passes the runner on the iOS 27 simulator.

## Assumptions

- Saved preferences come in A21-P03; this phase keeps the state in the session snapshot only.
- The interface journeys run in the app's interface tests in A21-P05.

## Traceability

| Source | Requirement |
|---|---|
| MVP: colour, motion and intensity controls with bounds | FR-A21-201, 202 |
| Regression fixture: a transition cannot exceed the luminance cap | FR-A21-203, 204, SC-A21-202 |
| Version 0.1 feature 06: hide and restore controls | FR-A21-205 |
| Manual risk 2 (bright imagery) | FR-A21-203 |
| Contract G-CONTROLS, G-CAP, G-CHROME | FR-A21-201–207 |

## Negative Requirements

- No GL call outside the scene protocol; no availability to a person before X-A21; no image or recording; no claim
  of a real aurora; no VisualCore change.
