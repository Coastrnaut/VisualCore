# Feature Specification: R02-G10-04 — Backwards Aurora: gameplay spatial interaction

**Feature Branch**: `394-backwards-aurora-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G10-04 (migration ledger, game feature of experience R02-G10) · ID namespace FR-R02G1004-###,
SC-R02G1004-###, T-R02G1004-###

**Input**: User description: the archived R02-G10-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Backwards Aurora (the design's controls: "tap
segment ends, swipe the interval to reverse, timeline freeze preview"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/394-backwards-aurora-gameplay-spatial-interaction`; FR-R02G1004-###,
  SC-R02G1004-###, T-R02G1004-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g10.backwards-aurora` (a registered candidate since
  R02-G10-03) inside the one app; the source's `Apps/BackwardsAurora` and `Packages/GameModules` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 76" is a
  milestone figure; the 100 certified levels of R02-G10-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G10-01 … 03.
- **Model:** feature 384 (Nocturne Garden's gameplay spatial interaction) for the gesture controller, picker, preview,
  orbit and panel.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Mark a section by tapping its ends (Priority: P1) 🎯

A player taps a sample of the aurora to mark one end of the section to reverse and taps another to mark the other end;
the chosen section's band follows. Tapping again moves the nearer end.

**Why this priority**: choosing what to reverse is the game's first step.

**Independent Test**: scripted taps on sample points of certified levels move the section's ends exactly as an
independent pick predicts; no kernel action is sent.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player taps a sample left of the section, **Then** the section's start
   moves to it; right of the section, the end moves to it; inside, the nearer end moves.
2. **Given** a tap off the timeline, **When** it lifts, **Then** nothing changes.

### User Story 2 - Swipe the section to reverse it, with a frozen preview (Priority: P1)

A player swipes along the chosen section; the section is reversed in time. While the player presses and holds on the
section, the timeline freezes and shows the wave as it would be after the reversal (the would-be samples, bends and any
tear), without changing anything.

**Why this priority**: reversing is the game's one move.

**Independent Test**: scripted swipes on the chosen section send exactly one reversal of it; held presses show a
preview whose samples equal the kernel's reversal and send nothing.

**Acceptance Scenarios**:

1. **Given** a chosen section while playing, **When** the player swipes along it, **Then** one reversal of exactly that
   section is sent.
2. **Given** a chosen section, **When** the player presses and holds on it, **Then** the would-be wave is previewed and
   nothing is sent when the finger lifts.

### User Story 3 - Drag an end to resize the section (Priority: P1)

A player drags either end of the chosen section along the timeline to another sample.

**Independent Test**: scripted drags of an end move it to the sample an independent pick predicts; no kernel action is
sent.

### User Story 4 - Look around and come back (Priority: P2)

A player orbits the aurora with two fingers within bounds and returns to the authored view; the view never changes the
game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot swipe precisely can do everything through the labelled panel (start and end steppers, reverse,
undo, redo, next level, "Reset view"), including winning every certified level in its smallest reversal count.

**Independent Test**: all 100 certified solutions are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap; two taps on empty space within 0.35 s and 22 points reset the view.
- **A touch that moves a little:** neither a tap nor a drag nor a swipe; nothing changes.
- **A finished play (won, failed or showing the result):** gestures send nothing and the description says the play is
  over (undo or next level); marking ends, previews and orbit still work.
- **A swipe over a section the kernel refuses (a palindrome, a length outside the level's sections):** the reversal is
  sent and the kernel refuses it with its reason, shown to the player.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing.
- **Ends that would cross:** an end dragged past the other stops one sample before it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1004-001**: A tap on a sample MUST move the nearer qualifying end of the chosen section (presentation state)
  as stated; a tap elsewhere MUST change nothing; no tap sends a kernel action.
- **FR-R02G1004-002**: A swipe along the chosen section while playing MUST send exactly one reversal of that section;
  a press held on the section MUST preview the exact would-be wave (the kernel's reversal) and send nothing.
- **FR-R02G1004-003**: A drag that starts on an end of the section MUST move that end to the sample under the finger,
  never past the other end.
- **FR-R02G1004-004**: Picking MUST be analytic and deterministic: the touch ray through the drawn camera against the
  timeline plane, with a minimum touch target; ends win over samples and the band.
- **FR-R02G1004-005**: Two-finger orbit MUST stay within stated bounds, keep the scene inside the view with a 5 % margin
  at every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a double tap on empty space or
  "Reset view" returns to the authored view.
- **FR-R02G1004-006**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified solution MUST be replayable through panel actions.
- **FR-R02G1004-007**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code (observability).

### Key Entities

- **Gesture controller**: state (idle, sample press, end drag, band press, swipe, freeze preview, orbiting,
  cancelled), the touched end or sample, the start and last points, the press time, the last tap time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Freeze preview**: the would-be samples, bends and tear of reversing the chosen section (presentation only).
- **Gesture action**: setStart, setEnd, reverse, resetView; only reverse maps onto a declared kernel control.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1004-001**: For 500 seeded scripted taps, end drags, swipes and held presses on certified levels at several
  sizes and orbits, the actions and section changes equal an independent computation.
- **SC-R02G1004-002**: Second fingers, cancels and gestures on a finished play send no action in every scripted case.
- **SC-R02G1004-003**: Previews and orbit never change the digest in every scripted case; every freeze preview equals
  the kernel's reversal of the chosen section.
- **SC-R02G1004-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin.
- **SC-R02G1004-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1004-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1004-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G10-05; announcements, haptics and full accessibility in
  R02-G10-06; persistence in R02-G10-07. The snapshot schema stays 1 here (orbit, section and previews are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Gesture-to-world actions (tap segment ends, swipe the interval to reverse) | FR-R02G1004-001 … 004 |
| Timeline freeze preview | FR-R02G1004-002; SC-R02G1004-003 |
| Undo without ambiguity | FR-R02G1004-006 |
| Camera behaviour (constrained orbit, reset, no singularities) | FR-R02G1004-005 |
| Accessible alternative to every gesture | FR-R02G1004-006 |
| Deterministic tests, observability | FR-R02G1004-007; SC-R02G1004-001 … 005 |

## Negative Requirements / Excluded scope

- No free camera navigation, no gestures that change the rules, no hints, sounds or haptics, no device run before
  ImplementationLock-100, no availability before X-R02-G10.
