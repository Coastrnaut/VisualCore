# Feature Specification: Audio Odyssey — Phase 04 Multi-world presets and UI

**Feature Branch**: `057-ao-p04-presets-ui` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A07-P04 (legacy ledger) · ID namespace FR-A07-4##, SC-A07-4##, T-A07-4##

**Input**: User description: archived manual `apps/07-audio-odyssey.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — microphone, app-owned file and demo input modes (built in A07-P02; this
  phase completes their interface: a clear source picker with status, file name and permission recovery); regression
  fixture — the demo signal produces a stable and measurable scene response; context ownership stays solely in the
  VisualCore host.
- **No VisualCore change expected:** presets are stored through the experience's existing storage as A06 does.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Journeys I can come back to (Priority: P1) 🎯

A person picks one of three built-in journeys (for example "Deep tunnel", "Rolling hills", "Night stars"), or saves the
current world with its mappings, speed, easing and calm setting under a name, and later applies it again; they can
rename or delete their own journeys, never the built-ins.

**Why this priority**: the phase deliverable ("multi-world presets") and v0.1 feature 05 ("save environment + mapping
presets").

**Independent Test**: save, apply, rename and delete presets in a fresh storage; applying restores exactly the saved
world, mappings, speed, easing and calm motion; built-ins cannot be changed.

**Acceptance Scenarios**:

1. **Given** a built-in journey, **When** applied, **Then** the world, mappings, speed, easing and calm motion become the
   preset's, and the flight continues without a jump (speed eases to the new target).
2. **Given** the current setup, **When** saved as "My trip", **Then** it appears in the list, sorted by name, and
   survives leaving and reopening the experience.
3. **Given** a name already taken (ignoring case), **When** saved or renamed, **Then** the next free suffix is added
   ("My trip 2"); nothing is overwritten.
4. **Given** a built-in, **When** rename or delete is attempted, **Then** it is refused with a plain message.

---

### User Story 2 - Choosing the sound is clear (Priority: P1)

A person sees which source is playing (demo, microphone, or the file's name), switches with one tap, and when the
microphone is refused, sees why and how to allow it, while the demo keeps the journey alive.

**Why this priority**: the phase MVP gate (input modes).

**Independent Test**: for each source and permission state, the source section shows the right status, name and
recovery message; switching keeps the flight.

**Acceptance Scenarios**:

1. **Given** a file being played, **When** the source section is shown, **Then** it names the file and offers the other
   sources.
2. **Given** permission denied or restricted, **When** the microphone is chosen, **Then** a message explains how to
   allow access in Settings and the demo keeps playing.

---

### User Story 3 - The demo response is measurable and stable (Priority: P2)

The built-in demo signal makes each world respond measurably and the same way every time (the phase fixture).

**Independent Test**: play the demo with a fixed seed for a fixed number of frames twice; the response traces match
within tolerance, and the response rises measurably above rest.

**Acceptance Scenarios**:

1. **Given** the same seed and steps, **When** the demo plays twice, **Then** the primary and light traces match within
   1e-6.
2. **Given** the demo, **When** it plays for 2 seconds, **Then** the primary response rises at least 25% of its range
   above rest at some point in every world.

### Edge Cases

- A damaged or newer-format preset file: counted and left untouched; the list still opens.
- Storage full: saving fails with a plain message; nothing changes.
- An empty or whitespace name: becomes "Untitled"; names longer than 60 characters are cut.
- Applying a preset while paused: the setup changes, the journey stays paused.
- A preset saved under an older state version: it still applies with defaults for missing fields.

## Requirements *(mandatory)*

### Functional Requirements

**Presets (story 1)**
- **FR-A07-401**: The experience MUST offer three read-only built-in journeys and user journeys stored as one small
  file each in its own storage, listed built-ins first, then user journeys sorted by name ignoring case.
- **FR-A07-402**: A journey MUST hold world, mappings for every world, speed target, easing and calm motion; applying
  one sets them without moving the camera abruptly.
- **FR-A07-403**: Save, rename and delete MUST keep names unique ignoring case (next free suffix), clean names (trim,
  at most 60 characters, empty → "Untitled") and refuse changes to built-ins; failures leave every file as it was and
  show a plain message.
- **FR-A07-404**: Unreadable and newer-format files MUST be counted, never deleted or rewritten.

**Sources (story 2)**
- **FR-A07-410**: The controls MUST show the active source, the file's name when a file plays, and a recovery message
  with the way to Settings when the microphone is denied or restricted.

**Fixture (story 3)**
- **FR-A07-420**: The demo signal MUST produce a deterministic response trace for a given seed and step count in every
  world, rising measurably above rest.

**Layout**
- **FR-A07-430**: The controls MUST be grouped as Journey (world, pause, new journey), Sound (source, mapping), Comfort
  (speed, easing, calm motion) and Journeys (presets), each control labelled for VoiceOver.

**Common**
- **FR-A07-440**: No networking, accounts or sharing; presets never contain audio; no claims about sound measurement
  or health.

### Key Entities

- **Journey preset**: id, name (≤ 60 characters), saved time, world, mappings (3), speed target, easing, calm motion,
  built-in flag (not stored); file format version.
- **Preset store**: entries (built-ins + user), unreadable count, newer count, last message.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A07-401**: Save → apply round trips restore all six preset fields exactly in 100% of seeded cases; built-ins are
  refused for rename and delete.
- **SC-A07-402**: Names are unique ignoring case after any sequence of saves and renames (200 seeded operations).
- **SC-A07-403**: Damaged and newer files are counted and left byte-identical.
- **SC-A07-404**: Two demo runs with the same seed and steps give response traces equal within 1e-6; the primary rises
  ≥ 25% of its range above rest within 2 seconds in each world.
- **SC-A07-405**: Source status, file name and recovery message are correct for every source and permission state.
- **SC-A07-406**: The scenarios pass on iOS 27; every new test finishes in under 10 seconds.

## Assumptions

- The preset file format follows A06's (`{…, "format": 1, "id": …}`, sorted keys, id in the file name) adapted to
  journeys; the A06 store logic is the model, not shared code (it lives in another experience).

## Out of Scope

- Sharing or exporting presets; long-session performance and accessibility verification (A07-P05).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 05 (save environment + mapping presets) | FR-A07-401–404; SC-A07-401–403 |
| v0.1 feature 04 (microphone, file, demo input modes) | FR-A07-410; SC-A07-405 |
| Manual §9 Phase 04 fixture (demo waveform → stable measurable response) | FR-A07-420; SC-A07-404 |
| Later idea "curated audio journeys and scene packs" (built-ins only, no packs) | FR-A07-401 |

## Negative Requirements

- No sharing, accounts or downloads of journeys; no audio inside presets; no networking.
