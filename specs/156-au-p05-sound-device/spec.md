# Feature Specification: Aurora — Phase 05 Long-run thermal and comfort validation

**Feature Branch**: `156-au-p05-sound-device` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A21-P05 (legacy ledger) · ID namespace FR-A21-5##, SC-A21-5##, T-A21-5##

**Input**: User description: archived manual `apps/21-aurora.md` §9 Phase 05 `/speckit-specify` prompt (verbatim in
the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):**
  - MVP: the optional ambient loop, made in code and recorded in the licence inventory, with its own sound control;
  - regression fixture: Low Power Mode lowers the frame cadence without a visible time jump;
  - verification matrix rows (manual §11): the sound setting stays independent of the drawing's life (fixture 3) and
    the low-power cadence (fixture 5).
- **Gaps built here:** G-SOUND (the experience's loop and its own volume through the shared ambient loop player,
  independent of the drawing's life) and G-DEVICE (a device-campaign plan whose rows are {device} and stay pending
  until the campaign after ImplementationLock-100) of `docs/apps/aurora/visualcore-contract.json`.
- **Interface:** the app's interface journeys run in a new serial chunk.
- **Experience A21 inside the one app; still a candidate.** Follow `specs/149-zg-p05-quiet-device`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A quiet loop, only when asked (Priority: P1) 🎯

A person watching the sky can turn on a soft ambient sound and set how loud it is. The sound is off on a first
start. It keeps going while the sky changes presets, rebuilds its drawing or pauses for a moment, and it stops when
the person turns it off, leaves Aurora or the app goes to the background. Coming back to Aurora with the sound on
starts it again.

**Why this priority**: the manual's version 0.1 feature 05, its MVP for this phase and verification fixture 3.

**Independent Test**: with a test double for the audio output, turn the sound on, change presets, rebuild the drawing,
pause and resume the drawing; the loop plays throughout; turn it off and it stops; the sky's state is unchanged.

**Acceptance Scenarios**:

1. **Given** a first start, **Then** the sound is off and nothing plays.
2. **Given** the sound on, **When** the volume is set to 40 %, **Then** the loop plays at 0.4 of full volume.
3. **Given** the sound on and the loop playing, **When** the drawing is torn down and built again or paused and
   resumed, **Then** the loop keeps playing and the sound choice is unchanged.
4. **Given** the sound on, **When** the person leaves Aurora or the app moves to the background, **Then** the loop
   stops; **When** Aurora is shown again in the foreground, **Then** it plays again.
5. **Given** any sound choice, **Then** the sky's state, its digest and its scenario manifest are the same as with the
   sound off.

---

### User Story 2 - Low Power Mode keeps the sky smooth (Priority: P1)

With Low Power Mode on, the sky draws fewer frames per second, yet its motion carries on at the same pace: no frame
shows the sky jumping ahead or back.

**Why this priority**: the phase's regression fixture (manual fixture 5) and the battery risk (manual risk 1).

**Independent Test**: advance the sky at the low-power cadence and at the full cadence for the same span; both reach
the same sky time, every step is one frame's worth of motion, and the pictures at the shared instants match.

**Acceptance Scenarios**:

1. **Given** Low Power Mode, **Then** the frame cap is 30 frames per second.
2. **Given** two seconds of sky at 30 and at 60 frames per second, **Then** both end at the same sky time and the
   pictures drawn at the shared instants are identical.
3. **Given** the low-power cadence, **Then** no step between two frames moves the sky by more than one frame's span
   at the chosen speed.

---

### User Story 3 - Aurora works in the app (Priority: P1)

In the one app, a person opens Aurora, picks another preset, turns on the still view and the reduced-flash mode,
turns the sound on and sets its volume, and hides and restores the controls.

**Why this priority**: the experience's journeys proven at the interface.

**Independent Test**: the new interface chunk on the iOS 27 phone simulator.

**Acceptance Scenarios**:

1. **Given** Aurora open, **When** the person picks "Violet veil", **Then** the controls name that preset.
2. **Given** Aurora open, **When** the sound is turned on and the volume set, **Then** the controls read the new
   choice, and on a new start the choice is restored.
3. **Given** Aurora open, **When** the controls are hidden and the sky tapped, **Then** the controls are back.

---

### User Story 4 - The device campaign knows what to measure (Priority: P2)

The owner's device campaign has rows for what the simulator cannot give: thermal trend and frame rate during a long
session, battery, the low-power cadence on a real device, brightness and comfort on the screen, the loop on a real
speaker with the silent switch, and the accessibility audits.

**Why this priority**: G-DEVICE; thermal behaviour and comfort are device facts.

**Independent Test**: read the plan; every row has devices, a procedure, a pass condition and "pending".

**Acceptance Scenarios**:

1. **Given** the plan, **Then** each row names what is recorded, how, the pass condition and that it waits for the
   campaign; no row claims a number.

### Edge Cases

- **Volume at 0 %** with the sound on: the loop plays silently and the control reads 0 %.
- **A damaged, newer or out-of-range stored sound choice:** the sound opens off at the default volume.
- **The audio output cannot start** (no route, the session refuses): the sound choice stays on, nothing plays, no
  crash, and the sky is unaffected.
- **An interruption** (a call, an alarm): the loop stops and does not restart by itself; it starts again when Aurora
  is shown again in the foreground with the sound on.
- **The silent switch on:** the loop stays silent (the ambient session follows it).
- **Low Power Mode turned on or off while the sky moves:** the cadence changes at the next frame with no time jump.
- **A long stall** (more than a tenth of a second between frames): the sky advances by at most a tenth of a second,
  never by the whole stall.
- **Reduce Motion or the still view under Low Power Mode:** the sky holds still, as at the full cadence.
- **A row that needs the owner** (a device in hand, an audit): recorded as an owner action in the campaign.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A21-501**: The sound MUST be off on a first start; turning it on MUST play the experience's ambient loop and
  turning it off MUST stop it.
- **FR-A21-502**: The volume control (0–100 %) MUST set the loop's volume at once, and the sound choice MUST be kept
  and restored with the preferences.
- **FR-A21-503**: Building, tearing down, rebuilding, pausing or resuming the drawing MUST neither start nor stop the
  loop nor change the sound choice; the sound choice MUST never change the sky's state, digest or scenario manifest.
- **FR-A21-504**: Leaving Aurora, an interruption or moving to the background MUST stop the loop; showing Aurora again
  in the foreground with the sound on MUST play it again; a failure to start the output MUST leave the sky unaffected.
- **FR-A21-505**: Under Low Power Mode the frame cap MUST be 30 frames per second, and the sky time MUST follow the
  frame time at every cadence, so that the same span reaches the same sky time and no step moves the sky by more than
  one frame's span (at most a tenth of a second).
- **FR-A21-506**: Interface tests MUST cover picking a preset, the still view and the reduced-flash mode, the sound
  and its volume (restored on a new start) and hiding and restoring the controls, in the one app on the iOS 27 phone.
- **FR-A21-507**: A device-campaign plan MUST list rows for the thermal trend and frame rate in a long session,
  battery, the low-power cadence, the brightness limit and comfort on screen, the loop on a real device with the
  silent switch, and the accessibility audits, each pending.
- **FR-A21-508**: No measured device number MUST be claimed before the campaign, and the licence inventory MUST record
  the loop as made in code.

### Key Entities

- **Sound choice**: on or off and a volume (0–1), part of the preferences, not of the sky's state.
- **Campaign row**: id, what, devices, procedure, pass condition, status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A21-501**: In 100 % of lifecycle samples (build, tear down, rebuild, pause, resume, preset change) the loop's
  playing state and the sound choice are unchanged.
- **SC-A21-502**: At the low-power and the full cadence the same span ends at the same sky time (to one part in a
  million) and the shared instants draw identical pictures.
- **SC-A21-503**: The interface chunk passes on the iOS 27 phone, each test under 60 seconds.
- **SC-A21-504**: 100 % of campaign rows have devices, a procedure, a pass condition and "pending"; 0 numbers claimed.
- **SC-A21-505**: Unit tests stay under 10 seconds each.

## Assumptions

- The ambient loop player and its synthesised recipe already exist in the shared audio module (A21-P04, G-LOOP); no
  VisualCore change is needed in this phase.
- The shared host already lowers the frame cap under Low Power Mode and limits the step between frames; this phase
  proves the sky follows it.
- The campaign runs after ImplementationLock-100 with the owner's devices (D1, D2, D3); D3 stays on iPadOS 26.5.

## Traceability

| Source | Requirement |
|---|---|
| MVP: optional licensed ambient loop with separate audio control (version 0.1 feature 05) | FR-A21-501, 502, 508 |
| Regression fixture: low-power cadence without visible time discontinuity (fixture 5) | FR-A21-505, SC-A21-502 |
| Fixture 3: sound setting independent of the visualization lifecycle | FR-A21-503, 504, SC-A21-501 |
| Phase 05 deliverable: long-run thermal and comfort validation; §12 long-session power, brightness, thermal trend | FR-A21-507, 508 |
| Manual risks 1, 2 and 3 (battery, bright flashing, soundtrack licensing) | FR-A21-505, 507, 508 |
| §11 app UI row: first-session flow | FR-A21-506 |
| Contract G-SOUND, G-DEVICE | FR-A21-501–508 |

## Negative Requirements

- No device install or run before ImplementationLock-100; no simulator number presented as a device result.
- No sound file or recording, no background audio, no microphone, no network.
- No VisualCore change, no long soak run, no flashing.
