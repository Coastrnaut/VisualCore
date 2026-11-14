# Feature Specification: Audio Odyssey — Phase 01 Journey/camera comfort contract

**Feature Branch**: `054-ao-p01-journey-comfort` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A07-P01 (legacy ledger) · ID namespace FR-A07-1##, SC-A07-1##, T-A07-1##

**Input**: User description: archived manual `apps/07-audio-odyssey.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — three distinct procedural environments with a controlled camera rail;
  regression fixture — procedural chunks have watertight joins and bounded generation time; graphics-context ownership
  stays solely in the VisualCore host.
- **Gaps built here in VisualCore** (docs, public-API baseline, tests; reference regression at X-A07 per the owner ruling
  of 2026-11-14), from `docs/apps/audio-odyssey/visualcore-contract.json`: G-CAMERARAIL (a smooth closed rail with
  eased speed and comfort caps) and G-ORIGINREBASE (far positions mapped to precise local ones). G-RAILDRAW (fog, free
  view matrices) and G-SEGMENTSTREAM (streaming pool) stay for A07-P02; this slice draws a fixed short window.
- **Experience:** created in `Packages/ExperiencesCreative/AudioOdyssey`, registered as a candidate with its scenario
  manifest; the slice flies a real rail through real generated segments (no placeholder). Audio input arrives in A07-P03.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fly through a world on a calm rail (Priority: P1) 🎯

A person opens Audio Odyssey and is already gliding along a smooth path through a tunnel. They can pick one of three
worlds — tunnel, landscape, star corridor — and each looks clearly different; the flight continues without a jump.

**Why this priority**: the phase MVP and journey 2 of the brainstorm ("pick tunnel, landscape or star-corridor journey
and start flight").

**Independent Test**: open the experience; frames show the tunnel moving forward; select each world; each world's
geometry differs and the camera position after the switch continues from where it was.

**Acceptance Scenarios**:

1. **Given** a first launch, **When** the experience opens, **Then** the tunnel world is shown and the camera advances
   along the rail at the default speed, with no prompt of any kind.
2. **Given** a running flight, **When** the person picks the landscape or star corridor, **Then** the new world appears
   at the same rail position and the speed is unchanged.
3. **Given** the same world, seed and elapsed flight, **When** the journey is replayed, **Then** the camera poses and the
   generated geometry are identical.

---

### User Story 2 - Comfortable motion the person controls (Priority: P1)

A person changes the flight speed (slow, medium, fast) and the speed eases to the new value instead of jumping; they
can pause and resume; with Reduce Motion on, the flight is slower and the camera does not sway or tilt.

**Why this priority**: the constitution's comfort rule and journey 3 ("adjust speed, pause, switch to low-motion").

**Independent Test**: drive speed changes, pause and resume, and Reduce Motion in host tests; speed, acceleration and
turning never exceed the comfort limits; with Reduce Motion, sway and roll are zero and speed is lower.

**Acceptance Scenarios**:

1. **Given** slow speed, **When** fast is chosen, **Then** speed rises over time without exceeding the acceleration limit
   and reaches fast within the time the limit allows.
2. **Given** a running flight, **When** paused, **Then** the camera stops (eased) and the journey state is kept; resume
   continues from the same position.
3. **Given** Reduce Motion, **When** flying at any chosen speed, **Then** the speed is at most the reduced-motion cap and
   camera sway and roll stay zero.

---

### User Story 3 - Seamless worlds, built in time (Priority: P2)

The worlds are built from consecutive pieces; where two pieces meet, their edges line up exactly so no seam or crack
shows, and each piece is made quickly enough not to disturb the flight.

**Why this priority**: the phase's regression fixture.

**Independent Test**: generate consecutive pieces for every world and several seeds; the end edge of each piece equals
the start edge of the next; generation of a piece stays within its vertex budget and time budget.

**Acceptance Scenarios**:

1. **Given** pieces i and i+1 of any world and seed, **When** compared, **Then** the shared edge positions match within
   1e-9 of the rail scale.
2. **Given** any piece, **When** generated, **Then** its vertex count is within the piece budget and its median
   generation time on the host is under 2 ms.

### Edge Cases

- A very long flight: positions far along the rail are rebased so that what is drawn near the camera stays precise.
- The rail wraps (closed loop): distance beyond the rail length continues seamlessly from the start.
- Invalid numbers (NaN, infinite, negative speeds or time steps) are rejected or clamped; the journey never stores them.
- Leaving the experience pauses the flight; returning resumes from the saved state.
- Switching worlds rapidly ends with exactly the last chosen world shown.
- A zero or huge time step (app was suspended): the advance is capped so the camera never leaps.

## Requirements *(mandatory)*

### Functional Requirements

**Rail and comfort (stories 1, 2; VisualCore)**
- **FR-A07-101**: VisualCore MUST offer a closed camera rail through control points with position, direction and a
  stable orientation frame at any travelled distance, parameterised by distance so equal distances are equal lengths.
- **FR-A07-102**: VisualCore MUST offer comfort limits (maximum speed, acceleration, turn rate, sway and roll) and a
  flight that eases speed toward a target within those limits; a reduced-motion form lowers speed and sets sway and
  roll to zero.
- **FR-A07-103**: VisualCore MUST offer origin rebasing: far positions map to local positions near the camera whose
  precision does not degrade with distance, and the rebasing offset is part of the deterministic state.
- **FR-A07-104**: The same rail, limits, start state and time steps MUST give identical poses; time steps are capped.

**Worlds (stories 1, 3; experience)**
- **FR-A07-110**: Audio Odyssey MUST offer three worlds — tunnel, landscape, star corridor — each generated from the rail
  and a seed as consecutive pieces with watertight joins and a per-piece vertex budget.
- **FR-A07-111**: Piece generation MUST be deterministic (same world, seed, index → same piece).

**Experience (stories 1, 2)**
- **FR-A07-120**: Audio Odyssey MUST be an experience of the one app in `Packages/ExperiencesCreative/AudioOdyssey`,
  registered as a candidate with the nine standard scenarios and one scenario per regression fixture that this phase
  proves (watertight joins; comfort limits).
- **FR-A07-121**: The experience MUST draw the current world around the rail camera through the host (no context of its
  own), with controls for world, speed and pause; the journey state (world, distance, speed choice, seed, paused) is
  part of its digest and snapshot.
- **FR-A07-122**: Every control has an accessible label and identifier; the canvas describes world, speed and pause in
  words; Reduce Motion is honoured as in FR-A07-102.

**Common**
- **FR-A07-130**: No networking, accounts or analytics; no hard camera cuts; no VR or open-world navigation; no claims
  about comfort, relaxation or motion-sickness prevention.

### Key Entities

- **Camera rail**: control points, total length, pose at distance (position, direction, frame).
- **Comfort limits**: maximum speed, acceleration, turn rate, sway, roll; reduced-motion form.
- **Flight**: distance, speed, target speed, paused.
- **Origin rebase**: origin offset, threshold.
- **World**: tunnel, landscape or star corridor; piece index; piece budget.
- **Journey state**: world, distance, speed choice, seed, paused (schema 1).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A07-101**: Over 10 seeded rails, distance steps of equal length give positions whose spacing differs by under 1%
  and orientation frames never flip (consecutive frames turn by under the turn-rate limit).
- **SC-A07-102**: In 200 seeded speed-change sequences, speed and acceleration never exceed the limits; with reduced
  motion, sway and roll are exactly zero and speed never exceeds the reduced cap.
- **SC-A07-103**: After rebasing, positions 10^7 units along the rail match the reference within 1e-3 units near the
  camera, while unrebased single-precision positions do not.
- **SC-A07-104**: For every world and 5 seeds, the shared edges of consecutive pieces match within 1e-9 of the rail
  scale; each piece is within its vertex budget; median piece generation time is under 2 ms on the host.
- **SC-A07-105**: The nine scenarios and the two fixture scenarios pass on iOS 27; a rendered frame of each world differs
  from the others; the public-API baseline lists the new types, documented; every new test finishes in under 10 seconds.

## Assumptions

- The rail is a closed loop so a flight never ends; distance wraps modulo the rail length (rebasing still applies to
  the unwrapped distance for the "long flight" edge case).
- With roll held at zero the camera keeps the horizon level, so this slice can draw through the existing orbit-camera
  drawing path; free view matrices and fog come with G-RAILDRAW in A07-P02.
- A fixed short window of pieces around the camera is enough for this slice; the bounded streaming pool is A07-P02.

## Out of Scope

- Audio input and audio-driven geometry (A07-P03); presets (A07-P04); fog and particles beyond the star corridor's
  points (A07-P02).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 01 (three procedural environments with a controlled camera rail) | FR-A07-101, 110, 121 |
| v0.1 feature 03 (manual flight speed, camera easing, reduced motion) | FR-A07-102, 122 |
| v0.1 feature 06 (stable pause/resume) | FR-A07-121, story 2 |
| Manual §9 Phase 01 fixture (watertight joins, bounded generation time) | FR-A07-110, SC-A07-104 |
| Catalog fixtures (comfort limits; long-duration precision) | FR-A07-102, 103; SC-A07-102, 103 |
| Journeys 2 and 3 | User stories 1, 2 |
| Contract gaps G-CAMERARAIL, G-ORIGINREBASE | FR-A07-101–104 |

## Negative Requirements

- No audio-driven camera jolts or hard cuts; no VR, headset or free navigation; no comfort or health claims.
- No second renderer or context; no ProjectM code; no networking.
