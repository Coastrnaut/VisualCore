# Feature Specification: Audio Odyssey — Phase 02 Streaming procedural tunnel

**Feature Branch**: `055-ao-p02-streaming-tunnel` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A07-P02 (legacy ledger) · ID namespace FR-A07-2##, SC-A07-2##, T-A07-2##

**Input**: User description: archived manual `apps/07-audio-odyssey.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — audio features mapped to scene geometry and lighting rather than hard
  cuts; regression fixture — camera speed and acceleration respect comfort limits; graphics-context ownership stays
  solely in the VisualCore host.
- **Gaps built here in VisualCore** (docs, public-API baseline, tests; reference regression at X-A07 per the owner ruling
  of 2026-11-14), from `docs/apps/audio-odyssey/visualcore-contract.json`: G-SEGMENTSTREAM (a streaming window of pieces
  around a moving distance, kept in a bounded pool) and G-RAILDRAW (depth-tested mesh drawing through any view and
  projection, with linear depth fog).
- **Audio:** reuses the sources (demo first; microphone with permission and files the person picks, as in A06) and the
  analysis and mapping that A06 built; the envelope mapping editor is A07-P03.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The tunnel breathes with the music (Priority: P1) 🎯

A person flies through the tunnel while sound plays (the built-in demo first, with no permission asked). The tunnel's
ripples swell and its light brightens with the sound, smoothly, never with jumps or flashes; when the sound stops the
tunnel settles back.

**Why this priority**: the phase MVP and the brainstorm's core promise ("environments that respond to sound").

**Independent Test**: feed the demo signal, a tone and silence; the tunnel's ripple amount and brightness follow the
sound level within bounds, change by at most a bounded amount per frame, and return to rest in silence.

**Acceptance Scenarios**:

1. **Given** the demo signal, **When** flying, **Then** ripple and brightness rise above their rest values within a
   second and stay inside their bounds.
2. **Given** a sudden loud onset, **When** it arrives, **Then** ripple and brightness rise over several frames (no
   single-frame jump larger than the step limit) and the camera's motion is unchanged.
3. **Given** silence, **When** it lasts two seconds, **Then** ripple and brightness are back within 5% of rest.

---

### User Story 2 - Endless, steady flight (Priority: P1)

A person flies for a long time; the world keeps appearing ahead and disappearing behind without stalls, without
growing memory use and without visible gaps, and far things fade into the distance instead of popping in.

**Why this priority**: the phase's "streaming" deliverable and the comfort fixture.

**Independent Test**: advance the window over many pieces; the number of live pieces never exceeds the pool capacity,
pieces behind the camera are returned and reused, and the drawn frame shows distance fog.

**Acceptance Scenarios**:

1. **Given** a flight over 200 pieces, **When** the window advances, **Then** at most the pool's capacity of pieces is
   ever alive and the number built per step is bounded.
2. **Given** any speed change, **When** flying, **Then** speed and acceleration stay within the comfort limits (the
   phase fixture).
3. **Given** the far end of the window, **When** a frame is drawn, **Then** geometry there blends into the fog colour.

---

### User Story 3 - Choose the sound (Priority: P2)

A person switches between the demo, the microphone (asked for permission once; refused permission keeps the demo) and
a file they pick; the tunnel follows the chosen sound and the flight never stops or restarts.

**Why this priority**: the v0.1 input-modes feature; the catalog fixture "source switching does not reset the context".

**Independent Test**: with simulated permission states, switch sources; the host context and flight state are
unchanged by switching; denied permission falls back to the demo with a message.

**Acceptance Scenarios**:

1. **Given** permission denied, **When** the microphone is chosen, **Then** no request is shown, the demo keeps playing
   and a message says how to allow access.
2. **Given** a running flight, **When** the source changes, **Then** distance and speed continue and the drawing context
   is the same before and after.

### Edge Cases

- Silence or a missing source: the tunnel rests; nothing flashes.
- Very loud input: mapped values are clamped to their bounds.
- Very fast speed changes or a long pause: pieces are built only for the window; nothing is built for skipped distance.
- Reduce Flashing: brightness changes are capped further; Reduce Motion: the ripple amplitude is halved.
- Leaving the experience stops the audio source and releases the microphone; returning restarts the chosen source.

## Requirements *(mandatory)*

### Functional Requirements

**Streaming and drawing (story 2; VisualCore)**
- **FR-A07-201**: VisualCore MUST offer a streaming window that, for a moving distance, keeps the pieces from a number
  behind to a number ahead, returns pieces behind to a bounded pool, reuses them, and reports which pieces to build.
- **FR-A07-202**: VisualCore's depth-tested mesh drawing MUST accept any view and projection (not only an orbit camera),
  with an optional linear depth fog (start, end, colour); existing callers are unchanged.

**Audio response (story 1; experience over existing VisualCore audio)**
- **FR-A07-210**: The tunnel's ripple amount and brightness MUST follow smoothed audio features within fixed bounds,
  with a per-frame step limit; audio never moves the camera.
- **FR-A07-211**: Reduce Flashing caps brightness change further; Reduce Motion halves the ripple amplitude.

**Sources (story 3)**
- **FR-A07-220**: The experience MUST offer demo, microphone (permission-gated, requested only when not determined) and
  file sources through the existing VisualCore audio interface; switching keeps the flight and the host context.
- **FR-A07-221**: No audio is recorded or leaves the device; the microphone is released when leaving.

**Experience**
- **FR-A07-230**: The tunnel is drawn through the streaming window and the new drawing path with fog; the other two
  worlds keep working; the source and the mapped response are part of the canvas description.
- **FR-A07-231**: The manifest keeps the nine standard scenarios and five fixture scenarios, with fixture 2 (comfort)
  and fixture 3 (source switching) exercising real behaviour.

**Common**
- **FR-A07-240**: No networking; no hard cuts or audio-driven camera motion; no claims about sound measurement or health.

### Key Entities

- **Streaming window**: behind, ahead, pool capacity; live pieces; pieces to build and to return per step.
- **Fog**: start distance, end distance, colour.
- **Audio response**: ripple amount, brightness; rest values, bounds, step limit.
- **Source choice**: demo, microphone, file (display name only).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A07-201**: Over a 200-piece flight the live piece count never exceeds the pool capacity, at most 2 pieces are
  built per step, and pieces are reused after the first window (no growth).
- **SC-A07-202**: A frame drawn with fog has the fog colour (within 2%) at the far end and the unfogged colour near the
  camera; the orbit-camera drawing gives identical pixels to before the change.
- **SC-A07-203**: Under the demo signal ripple and brightness leave rest within 1 s and stay within bounds; no
  frame-to-frame change exceeds the step limit; after 2 s of silence both are within 5% of rest.
- **SC-A07-204**: In 200 seeded speed sequences speed and acceleration never exceed the comfort limits (fixture 2).
- **SC-A07-205**: Source switches keep distance, speed and the host context; denied permission falls back to the demo
  (100% of simulated states).
- **SC-A07-206**: The scenarios pass on iOS 27; the API baseline lists the new types, documented; every new test finishes
  in under 10 seconds.

## Assumptions

- The analysis, smoothing and mapping of A06 (`FeatureExtractor`, `FeatureSmoother`, `AudioMapper`) suit the response;
  only the experience's mapping table (feature → ripple, brightness) is new.
- The landscape and star corridor keep the fixed window of A07-P01 until they adopt streaming in a later phase if
  needed; the tunnel proves the slice.

## Out of Scope

- The envelope mapping editor and presets (A07-P03, A07-P04); particles beyond the star corridor.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 02 (audio mapped to geometry/lighting, not hard cuts) | FR-A07-210, 211; SC-A07-203 |
| v0.1 feature 04 (microphone, app-owned file, demo inputs) | FR-A07-220, 221 |
| Manual §9 Phase 02 fixture (comfort limits) | SC-A07-204 |
| Catalog fixture 3 (source switching keeps the context) | FR-A07-220; SC-A07-205 |
| Manual §6 algorithm 1 (bounded streaming corridor, retire behind) and render stage 4 (fog) | FR-A07-201, 202 |
| Contract gaps G-SEGMENTSTREAM, G-RAILDRAW | FR-A07-201, 202 |

## Negative Requirements

- No system-wide capture of other apps' audio; no recording or upload; no audio-driven camera jolts.
- No second renderer or context; no networking; no claims about sound measurement, relaxation or health.
