# Feature Specification: R02-G07-04 — Amethyst Escape: gameplay spatial interaction

**Feature Branch**: `364-amethyst-escape-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G07-04 (migration ledger, game feature of experience R02-G07) · ID namespace FR-R02G0704-###,
SC-R02G0704-###, T-R02G0704-###

**Input**: User description: the archived R02-G07-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Amethyst Escape (the design's controls: "drag
each shell bezel, tap advance pearl, double tap isolate layer"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/364-amethyst-escape-gameplay-spatial-interaction`; FR-R02G0704-###,
  SC-R02G0704-###, T-R02G0704-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g07.amethyst-escape` (a registered candidate since
  R02-G07-03) inside the one app; the source's `Apps/AmethystEscape` and `Packages/GameModules` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 80" is a
  milestone figure; the 100 certified levels of R02-G07-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G07-01 … 03.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
354's answers. Facts checked in code (read-only, 2026-11-22): Chrono Constellator's feature 354 solved the same problem
with a host-tested `ChronoConstellatorGestureController` taking `PointerEvent`s (id, phase began/moved/ended/cancelled,
location in view points with the origin top-left, timestamp) with the view size and the drawn snapshot and orbit, an
analytic picker and a clamped `ChronoConstellatorOrbit`; Amethyst Escape's camera
(`AmethystEscapeSceneGeometry.camera(_:aspect:)`) looks from +z pitched 50° down; shell k is the annulus r_k … r_k + w
with its top at h_k (inner shells taller), own sector s sits at world sector (s + offset) mod S with angles from +x
towards +z (clockwise from above, the kernel's +1); the pearl is a sphere of radius 0.3·w; the adapter accepts
`shell.rotate [shell, ±1]`, `pearl.advance`, `play.undo`, `play.redo` and `level.next`, actions only while playing.

- Q: How does a drag become a turn? → A: a one-finger touch is picked at touch-down; if the pick is a shell (not the
  pearl) and the play is in stage `playing`, the gesture is a shell drag. The angle of a touch is atan2(z, x) of the
  point where the touch ray meets the plane y = h_k of the picked shell; the swept angle is the unwrapped sum of the angle
  changes between moves; the candidate turn is n = round(swept / (2π/S)) reduced to the shortest equivalent in
  −⌊S/2⌋ … ⌊S/2⌋ (a positive angle runs from +x towards +z, so n > 0 is the kernel's +1). When the finger lifts after
  having moved at least 16 points, |n| `shell.rotate [k, sign(n)]` are sent in order if n ≠ 0; otherwise nothing. A touch
  that moves less than 10 points is a tap. Impact: FR-R02G0704-001, 004; SC-R02G0704-001.
- Q: What is the pearl's touch target and how are taps used? → A: a touch hits the pearl when its ray meets the pearl
  sphere or its point lies within 22 points of the pearl centre's projection; the pearl wins over shells at touch-down.
  A tap (less than 10 points of travel, lifted within 0.5 s) on the pearl while playing sends one `pearl.advance`; a tap on
  a shell picks that shell in the panel (presentation only, no action); a tap on empty space sends nothing. Shells are
  picked by intersecting the ray with each shell's top plane y = h_k from the innermost (tallest) outward and taking the
  first hit inside r_k … r_k + w; if none, the shell whose projected top-ring midline lies within 22 points. Impact:
  FR-R02G0704-002, 004; SC-R02G0704-001.
- Q: What does isolating a layer do? → A: a double tap (two taps whose `.ended` timestamps are at most 0.35 s apart and
  22 points apart) on a shell toggles its isolation: while isolated, every other shell's wedges, fins and marks are drawn
  at shade 0.25 (darker, still opaque where they were) so the isolated shell and the pearl stand out; double-tapping the
  isolated shell clears it, double-tapping another shell isolates that one instead; "Show all layers" clears; `level.next` clears. A double tap on
  empty space resets the view. Isolation is presentation only: never in the digest, the snapshot or the kernel. Impact:
  FR-R02G0704-003; SC-R02G0704-003.
- Q: What can the camera do? → A: two-finger orbit of yaw (±40° about the y axis, 90° per view width) and pitch (30° …
  75° down from the horizon, authored 50°, 60° per view height); a second finger cancels a drag or press (nothing sent);
  a third re-bases the midpoint; a double tap on empty space or "Reset view" returns to the authored view; the distance
  refits so the bounding sphere of radius 1.1 stays inside the view with a 5 % margin at every orbit and aspect 0.4 …
  2.5. Presentation only: not saved, so the snapshot schema stays 1. Impact: FR-R02G0704-005; SC-R02G0704-004.
- Q: How are drags previewed and everything tested? → A: during a shell drag the scene draws the snapshot with that
  shell's offset (and the pearl, when it rests in that shell) turned by the candidate n sectors, and the description
  reads "Shell k would turn n sectors clockwise" (or anticlockwise, or "would not turn"). The Core gesture controller
  takes pointer events with the view size and the drawn snapshot and orbit and returns the actions plus the preview; host
  tests feed 500 seeded drags and taps on certified levels at several sizes and orbits and compare with an independent
  pick and angle computed in the test; simulator tests send the same touches through the experience's pointer entry; a
  host test wins all 100 certified levels through panel actions (shell picker, turn − and +, advance). Refused actions
  are logged with their reason code. Impact: FR-R02G0704-006 … 008; SC-R02G0704-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn a shell by dragging its bezel (Priority: P1) 🎯

A player puts a finger on a shell of the crystal and drags it round the centre; the shell follows as a preview, snapping
to whole sectors, and when the finger lifts the shell is turned by that many sectors. While dragging, the turn is shown
and named ("shell 2 two sectors clockwise"); nothing changes in the game until release.

**Why this priority**: turning shells is the game's main move.

**Independent Test**: scripted drags on shells of certified levels produce exactly the turns an independent picking and
angle computation predicts, or none.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** a drag starts on shell k and sweeps an angle that rounds to n whole sectors
   (n ≠ 0), **Then** on release |n| one-sector turns of shell k in the sign of n are sent.
2. **Given** a drag that starts outside every shell, or sweeps less than half a sector, **When** it is released, **Then**
   no turn is sent.
3. **Given** a won or failed play, **When** a shell is dragged, **Then** nothing is sent and the description says the
   play is over (undo or next level).

### User Story 2 - Tap to advance the pearl (Priority: P1)

A player taps the pearl (or the pocket it rests in) and the pearl rolls one pocket outward or clockwise as the rules
say; a tap elsewhere advances nothing.

**Why this priority**: advancing the pearl is the game's other move.

**Independent Test**: scripted taps on and off the pearl send exactly one advance or none.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player taps within the pearl's touch target, **Then** exactly one
   advance is sent.
2. **Given** a tap elsewhere on the crystal, **When** it lifts, **Then** no advance is sent and the tapped shell is picked
   in the panel.

### User Story 3 - Isolate a layer (Priority: P2)

A player double-taps a shell to isolate it: the other shells fade so the chosen one and the pearl stand out; double-tapping
it again, or tapping "Show all layers", brings them back. Isolation is presentation only.

**Independent Test**: double taps toggle the isolated shell as predicted; the digest never changes.

### User Story 4 - Look around and come back (Priority: P2)

A player orbits the crystal with two fingers within bounds and returns to the authored view; the view never changes the
game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot drag precisely can do everything through the labelled panel (shell picker, turn − and +, advance,
undo, redo, next level, "Show all layers", "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified solutions are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap (see US2); two taps on empty space within 0.35 s reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing is sent.
- **A finished play (won, failed or showing the result):** drags and pearl taps send nothing; selection, isolation and
  orbit still work.
- **A second finger during a drag:** cancels it (nothing sent) and orbits.
- **A cancelled touch:** sends nothing.
- **A drag that sweeps more than half a turn:** the turn is the shortest equivalent (at most ⌊S/2⌋ sectors either way).
- **A turn that would exceed the move budget:** the turns are sent one by one; the kernel refuses those after the play
  ends (budget or wedge), the refusal is shown, and nothing else changes.
- **The pearl hidden behind a taller inner shell:** picking prefers the pearl at touch-down within its touch target.
- **Isolation of a shell during play:** turns and advances still work; isolation survives turns and ends on next level.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0704-001**: While playing, a drag that starts on shell k, moves at least 16 points and sweeps an angle that
  rounds to n whole sectors (n ≠ 0, reduced to the shortest equivalent) MUST send exactly |n| `shell.rotate [k, sign(n)]`
  on release; any other drag MUST send no turn; a touch under 10 points is a tap.
- **FR-R02G0704-002**: A tap within the pearl's touch target while playing MUST send exactly one `pearl.advance`; a tap
  elsewhere MUST send nothing and pick the tapped shell in the panel.
- **FR-R02G0704-003**: A double tap (two taps within 0.35 s and 22 points) on a shell MUST toggle that shell's isolation;
  on empty space it MUST reset the view; isolation and the view are presentation only.
- **FR-R02G0704-004**: Picking MUST be analytic and deterministic: the touch ray through the drawn camera against the
  pearl (a sphere) and the shells' top surfaces (annuli at their heights), with a 22-point minimum touch target; the
  pearl wins at touch-down, then the tallest shell hit.
- **FR-R02G0704-005**: Two-finger orbit MUST stay within yaw ±40° and pitch 30° … 75° (authored 0°, 50°), keep the scene
  inside the view with a 5 % margin at every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a
  double tap on empty space or "Reset view" returns to the authored view.
- **FR-R02G0704-006**: While dragging, the previewed turn MUST be drawn and described; nothing changes in the kernel until
  release.
- **FR-R02G0704-007**: The panel MUST keep every action available without gestures and gain "Show all layers" and "Reset
  view"; every certified solution MUST be replayable through panel actions.
- **FR-R02G0704-008**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code (observability).

### Key Entities

- **Gesture controller**: state (idle, shell drag, pearl press, orbiting, cancelled), picked shell, start angle, last
  points, last tap time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Isolation**: the isolated shell or none (presentation only).
- **Gesture action**: turn(shell, sectors), advance, isolate(shell or none) or resetView, the first two mapped onto the
  declared controls.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0704-001**: For 500 seeded scripted drags and taps on certified levels at several sizes and orbits, the
  actions sent equal an independent computation of the touched pearl, shell and swept sectors.
- **SC-R02G0704-002**: Second fingers, cancels and gestures on a finished play send no action in every scripted case.
- **SC-R02G0704-003**: Isolation and orbit never change the digest in every scripted case.
- **SC-R02G0704-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin.
- **SC-R02G0704-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G0704-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G0704-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G07-05; announcements, haptics and full accessibility in
  R02-G07-06; persistence in R02-G07-07. The snapshot schema stays 1 here (no schema migration in this feature; orbit
  and isolation are not saved).
- All gestures map onto the adapter's declared controls; no new kernel action is added.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Gesture-to-world actions (drag each shell bezel, tap advance pearl, double tap isolate layer) | FR-R02G0704-001 … 004 |
| Undo without ambiguity | FR-R02G0704-007 |
| Camera behaviour (constrained orbit, reset, no singularities) | FR-R02G0704-005 |
| Accessible alternative to every gesture | FR-R02G0704-007 |
| Deterministic tests, observability | FR-R02G0704-008; SC-R02G0704-001 … 005 |

## Negative Requirements / Excluded scope

- No free camera navigation, no gestures that change the rules, no hints, sounds or haptics, no device run before
  ImplementationLock-100, no availability before X-R02-G07.
