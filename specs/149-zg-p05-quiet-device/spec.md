# Feature Specification: Digital Zen Garden — Phase 05 Responsiveness and idle-power QA

**Feature Branch**: `149-zg-p05-quiet-device` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A20-P05 (legacy ledger) · ID namespace FR-A20-5##, SC-A20-5##, T-A20-5##

**Input**: User description: archived manual `apps/20-digital-zen-garden.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):**
  - MVP: save and load named gardens with a lightweight stroke history (built in A20-P04; proven here in the app's
    interface);
  - regression fixture: the reduced-motion state disables incidental animations;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-QUIET (the low-stimulation mode with sound and animation off by default, Reduce Motion and
  Reduce Flashing) and G-DEVICE of `docs/apps/digital-zen-garden/visualcore-contract.json`, the latter as a
  device-campaign plan whose rows are {device} and stay pending until the campaign after ImplementationLock-100.
- **Experience A20 inside the one app; still a candidate.** Follow `specs/142-lw-p05-device-tests`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `SoundEffectPlayer` (VisualCoreAudio) uses the ambient session, which the silent switch mutes. Its `isEnabled`
  defaults to `true`, so the experience must set it off. Its effects are procedural one-shot tones from
  VisualCoreAudioDSP, with no sound file.
- `ExperienceFeedback.haptic` plays only while the person's Settings switch is on.
- `ExperienceStorage.setValue(_:for:)` and `value(for:)` keep small per-experience values (at most 64 values of 4,096
  bytes).
- The sand scene already reuses a still frame when nothing changes (A20-P02) and caps frames at 30 per second. The
  interface chunks of `scripts/release_check.py` end at `a3`, a serial chunk; the next is `b3`.

- Q: What are the calm settings, and where are they kept? → A:
  - **Switches:** `calm.sound`, `calm.drift` and `calm.haptics`, each [0…1] and off by default. They are core state
    and not in the digest, so the garden is unchanged by them.
  - **Storage:** the switches are kept as experience values under `calm.v1`, restored when the experience opens,
    with damaged values ignored.
  - **Reduce Motion and Reduce Flashing:** read from the launch, as today. Reduce Motion forces the drift off at
    draw time without changing the switch.
- Q: What is the drift, and how is "no change" proved? → A:
  - **Drift:** a slow sideways drift of the sand grain only (the grain's noise offset moves at 0.01 tray widths per
    second). The relief, stones and shadows never move, and nothing flashes.
  - **Off:** the cached still frame is reused, so no frame is redrawn without input.
  - **Proof:** two renders at different frame times are identical with the drift off, or with Reduce Motion on, and
    differ with the drift on.
  - **Reduce Flashing:** it changes nothing, because nothing flashes.
- Q: What do sound and haptics do when on? → A:
  - **Sound:** a soft procedural one-shot tone, quiet and low, when a stroke is committed, a stone is placed, and a
    stone is removed. It plays through `SoundEffectPlayer`, with `isEnabled` following `calm.sound`.
  - **Haptics:** a light selection haptic on stone selection and a light impact on placement, through the port's
    haptic route, only when `calm.haptics` is on and the person's switch allows it.
  - **State:** neither changes the state.
- Q: Which interface tests run, and in which chunk? → A: A new serial chunk `b3` with `ZGGardenUITests` and
  `ZGLibraryUITests`, launched with the candidates argument, as `LWSupport` is:
  - `ZGGardenUITests`: rake the rows pattern; undo empties the description's stroke count. In the stone tool, place a
    river pebble, remove it, then undo restores it.
  - `ZGLibraryUITests`: rake a pattern, save as "Evening", reset the garden through undo, then open "Evening"; the
    description shows one stroke again.
  - **Limits:** each test under 60 s.
- Q: Which campaign rows does the plan hold? → A: Rows ZG-D1 to ZG-D8 in
  `docs/apps/digital-zen-garden/device-campaign.md`:
  - ZG-D1: touch-to-groove latency;
  - ZG-D2: coalesced touches, and whether fast drags need them;
  - ZG-D3: idle drawing (frames drawn while untouched);
  - ZG-D4: heat during ten minutes of raking;
  - ZG-D5: battery during a long session;
  - ZG-D6: precision on the smallest phone and the need for a brush zoom (manual risk 2);
  - ZG-D7: the quiet defaults and the silent switch on a real device;
  - ZG-D8: the accessibility audits at the default and the largest text size.

  Each row has its devices (D1, D2, D3), procedure, threshold and "pending device campaign". No number is claimed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Quiet by default (Priority: P1) 🎯

A new garden is silent and still: no sound, no drifting sand and no extra haptics until the person turns them on. A
person who wants a little life can turn on a gentle sand drift and soft rake sounds; Reduce Motion keeps the drift off
whatever the setting says.

**Why this priority**: the manual's version 0.1 feature 06 and its regression fixture.

**Independent Test**: open a fresh garden; nothing changes between frames; turn the drift on; frames change; turn
Reduce Motion on; frames stop changing.

**Acceptance Scenarios**:

1. **Given** a fresh start, **Then** sound, drift and haptics are off, and two frames with no input are identical.
2. **Given** the drift on and Reduce Motion on, **Then** two frames with no input are identical.

---

### User Story 2 - The garden works in the app (Priority: P1)

In the one app, a person rakes a pattern, places and removes a stone, undoes, saves the garden under a name and opens
it again.

**Why this priority**: the MVP proven at the interface.

**Independent Test**: the interface chunk on the iOS 27 phone simulator.

**Acceptance Scenarios**:

1. **Given** a fresh start, **When** a pattern is raked and the garden saved as "Evening", **Then** the library lists
   "Evening" and opening it shows the same garden.
2. **Given** a placed stone, **When** it is removed and the removal undone, **Then** the stone is back.

---

### User Story 3 - The device campaign knows what to measure (Priority: P2)

The owner's device campaign has rows for what the simulator cannot give: touch latency and coalesced touches, drawing
when idle, heat and battery during long raking, precision on a small screen, the quiet defaults on a real device, and
the accessibility audits.

**Why this priority**: G-DEVICE; responsiveness and idle power are device facts.

**Independent Test**: read the plan; every row has a device, a procedure, a threshold and "pending".

**Acceptance Scenarios**:

1. **Given** the plan, **Then** each row names what is recorded, how, the pass condition and that it waits for the
   campaign; no row claims a number.

### Edge Cases

- **Reduce Motion turned on while the drift runs:** the drift stops at once and the picture stays.
- **Reduce Flashing:** nothing in the garden flashes in either state.
- **Sound on with the device's silent switch on:** the sound stays silent (the ambient session respects it).
- **The person's haptics switch off:** no haptic plays even with the experience's haptics on.
- **The app moves to the background while a tone plays or the drift runs:** the tone stops and drawing stops;
  both resume only with the experience.
- **A row that needs the owner** (a device in hand, an audit): recorded as an owner action in the campaign.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A20-501**: Sound, sand drift and haptics MUST be off by default and each MUST be a native switch with a spoken
  label; turning them on MUST not change the garden.
- **FR-A20-502**: With the drift off, or with Reduce Motion on, the picture MUST not change between frames without
  input; with the drift on and Reduce Motion off it MUST change.
- **FR-A20-503**: Nothing in the experience MUST flash; Reduce Flashing MUST leave the picture the same.
- **FR-A20-504**: Interface tests MUST cover raking a pattern, placing and removing a stone with undo, and saving and
  opening a named garden, in the one app on the iOS 27 phone.
- **FR-A20-505**: A device-campaign plan MUST list rows for touch latency and coalesced touches, idle drawing, heat
  and battery, small-screen precision, the quiet defaults and the accessibility audits, each pending.
- **FR-A20-506**: No measured device number MUST be claimed before the campaign.

### Key Entities

- **Calm settings**: sound, drift and haptics switches (state, not the garden).
- **Campaign row**: id, what, device class, procedure, threshold, status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A20-501**: Two frames without input are identical in 100% of quiet-default and Reduce Motion samples.
- **SC-A20-502**: The interface chunk passes on the iOS 27 phone, each test under 60 seconds.
- **SC-A20-503**: 100% of campaign rows have device class, procedure, threshold and "pending"; 0 numbers claimed.
- **SC-A20-504**: Unit tests stay under 10 seconds each.

## Assumptions

- The campaign runs after ImplementationLock-100 with the owner's devices (D1, D2, D3); D3 stays on iPadOS 26.5.

## Traceability

| Source | Requirement |
|---|---|
| MVP: save/load named gardens | FR-A20-504 |
| Regression fixture: reduced motion disables incidental animation | FR-A20-502, SC-A20-501 |
| Version 0.1 feature 06: low-stimulation mode, sound and animation off by default | FR-A20-501–503 |
| Phase 05 deliverable: responsiveness and idle-power QA | FR-A20-505, 506 |
| Manual risks 2 and 3 (touch precision, bright effects) | FR-A20-501, 505 |
| Contract G-QUIET, G-DEVICE | FR-A20-501–506 |

## Negative Requirements

- No device install or run before ImplementationLock-100; no simulator number presented as a device result; no
  flashing; no sound file; no network.
