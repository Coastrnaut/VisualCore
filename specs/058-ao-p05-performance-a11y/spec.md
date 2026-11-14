# Feature Specification: Audio Odyssey — Phase 05 Long-session performance and accessibility verification

**Feature Branch**: `058-ao-p05-performance-a11y` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A07-P05 (legacy ledger) · ID namespace FR-A07-5##, SC-A07-5##, T-A07-5##

**Input**: User description: archived manual `apps/07-audio-odyssey.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — saved environment and mapping presets (built in A07-P04; this phase
  proves they persist across sessions together with the journey); regression fixture — long-duration travel avoids
  coordinate precision collapse; context ownership stays solely in the VisualCore host.
- **Gaps built here**, from `docs/apps/audio-odyssey/visualcore-contract.json`: G-JOURNEYBUDGET (VisualCore: a streaming
  budget that maps quality levels to window size, draw distance and element share within the mesh budget) and
  G-JOURNEYA11Y (experience: spoken journey description and announcements through the shared announcement sink).
- **Owner rulings:** short tests (a long session is measured briefly and bounded by arithmetic; no soak runs);
  accessibility audits and device measurements in the device campaign; iOS 27 at phase gates; reference regression at
  X-A07; every Spec Kit step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`QualityLevel` (VisualCoreDiagnostics) carries resolution, element and iteration shares; the host passes the chosen
level index to the presenter (`draw(_:tier:context:frame:)`, as A06 uses it with `forceTierForTesting`);
`ResourceRegistry.stats` gives a ledger snapshot; `AnnouncementSink` (VisualCoreUI) announces text; A06 has an
`AnnouncementGate` (2 s, changed text only) in its own Core; `MeshBudget` and `SegmentWindow` are in VisualCoreScenes.

- Q: What does the streaming budget look like? → A: `StreamingBudget` in VisualCoreScenes: `levels: [StreamingLevel]`
  with `behind`, `ahead`, `drawDistance` and `elementShare`; `init?(levels:pieceLength:)` refuses an empty list,
  rising values or a draw distance beyond `ahead × pieceLength`; `vertexTotal(level:perPieceVertices:)` and
  `fits(level:perPieceVertices:budget: MeshBudget)`. Audio Odyssey's three levels: ahead 8/6/4, behind 2/2/1,
  draw distance 64/48/32 units (= ahead × piece length 8; fog end, fog start at 40% of it; corrected during implementation because longer distances exceed the window), element share 1.0/0.6/0.35 (star count per piece).
- Q: How is the precision fixture measured at 10^9? → A: In Core and VisualCoreMath tests: `CameraRail.pose(at:)` at
  10^9 + x equals `pose(at: (10^9 + x) mod length)` within 1e-6; pieces with index ≈ 1.25 × 10^8 join within 1e-6; the
  presenter, restored at distance 10^9 through a snapshot, draws its first frame with the rebased camera within 1e-3 of
  the reference pose (Float). The rail wraps, so world positions are bounded; the unwrapped distance stays Double.
- Q: How is the long session measured without a soak? → A: 3,600 frames (60 s at 60 fps) of simulated flight at
  7 units/s on the simulator: live renderers ≤ capacity every frame, ≤ 2 built per frame, and the registry's ledger
  snapshot after frame 3,600 equals the snapshot after the first full window; longer sessions are bounded by
  arithmetic because the per-frame work and the pool are constant.
- Q: Where does the announcement gate live, and what is announced? → A: A07's own `JourneyAnnouncer` (Core, pure):
  announcements for world, source, preset applied, pause and resume, at most one per 1.5 s, changed text only, latest
  pending text announced when the interval passes; the presenter sends through the injected `AnnouncementSink` only
  while VoiceOver runs (injectable `voiceOverRunning`, as A06). The gate is duplicated by design: it is a few lines and
  each experience's wording and events differ (Principle II covers generic machinery; promoting it is noted for a
  later shared-UI feature).
- Q: How is persistence across sessions proven? → A: An experience test saves a preset through the store, takes the
  session snapshot, closes the session, opens a new session with the same storage and the snapshot, and compares the
  preset list and the restored journey (world, distance, speed target, mappings, source).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A long flight that stays smooth and precise (Priority: P1) 🎯

A person flies for a long time; the world keeps streaming without growing memory or work, and even after a very long
distance the geometry near the camera stays exact: no jitter, cracks or drifting joins.

**Why this priority**: the phase fixture and the risk named in the manual ("long-duration travel avoids coordinate
precision collapse").

**Independent Test**: simulate a short flight and a jump to a very long distance; pieces still join exactly, poses
match the rail, and the pool and resource totals stay constant over the measured run.

**Acceptance Scenarios**:

1. **Given** a journey at distance 10^9 units, **When** pieces are built and drawn, **Then** consecutive pieces still
   join within 1e-6 and the camera pose matches the rail pose at the wrapped distance within 1e-6.
2. **Given** 60 seconds of simulated flight at full speed, **When** measured, **Then** live pieces never exceed the
   pool capacity and the GPU resource totals at the end equal those after the first full window.

---

### User Story 2 - Quality adapts, the journey does not (Priority: P1)

When the device is hot or in Low Power Mode, the experience draws less (shorter view, fewer stars) but the journey —
world, position, speed, mappings — is exactly the same.

**Why this priority**: v0.1 feature 06 ("thermal quality downgrade") and the constitution's bounded-resources rule.

**Independent Test**: force each quality level; the window, draw distance and element share follow the level's
budget, the journey digest is unchanged, and every level stays within the mesh budget.

**Acceptance Scenarios**:

1. **Given** levels 0, 1 and 2, **When** forced in turn, **Then** the pieces ahead, the draw distance and the star
   count fall from level to level and never rise.
2. **Given** a level change mid-flight, **When** it happens, **Then** the journey state and digest are unchanged.

---

### User Story 3 - Hear and see the journey without looking (Priority: P2)

A VoiceOver user hears what is happening: the world, the speed, the sound source and pause state are described in
words, and changes (new world, source, preset, pause) are announced once, not repeatedly.

**Why this priority**: the constitution's accessibility rule; gap G-JOURNEYA11Y.

**Independent Test**: drive state changes with VoiceOver simulated as running; each change produces exactly one
announcement with the right words; nothing is announced while VoiceOver is off.

**Acceptance Scenarios**:

1. **Given** VoiceOver on, **When** the world changes, **Then** one announcement names the new world.
2. **Given** a rapid sequence of changes, **When** they happen within the throttle interval, **Then** at most one
   announcement per interval is made and the last state is announced.

---

### User Story 4 - My journeys and setup are still there tomorrow (Priority: P2)

A person saves a journey, leaves, and comes back: the saved journeys and the journey they were on (world, distance,
speed, mappings, source) are restored.

**Why this priority**: the phase MVP gate.

**Independent Test**: save a preset and a session snapshot, close the experience, reopen it with the same storage;
both are restored exactly.

**Acceptance Scenarios**:

1. **Given** a saved preset and a running journey, **When** the experience is closed and reopened, **Then** the preset
   list and the restored journey match what was there.

### Edge Cases

- A quality level change while pieces are being built: the window shrinks or grows by the build limit per frame;
  nothing is built beyond the new window.
- VoiceOver toggled during a flight: announcements start or stop at once.
- Reduce Flashing with a high level: light changes stay capped regardless of quality.
- A restored journey far along the rail: rebasing takes effect on the first frame.

## Requirements *(mandatory)*

### Functional Requirements

**Budget (story 2; VisualCore)**
- **FR-A07-501**: VisualCore MUST offer a streaming budget that, for each quality level, gives the pieces behind and
  ahead, the draw distance and the element share, non-increasing from level to level, with a check that a level's
  total vertices stay within a mesh budget.
- **FR-A07-502**: The experience MUST register three quality levels and apply the host's level each frame (window,
  fog distance, star count); the journey state is independent of the level.

**Long session and precision (story 1)**
- **FR-A07-510**: At any distance up to 10^9 units, pieces MUST join exactly and the camera MUST follow the rail; the
  drawn positions near the camera MUST stay precise.
- **FR-A07-511**: A measured flight MUST show a constant live-piece count and constant resource totals after the first
  window; longer sessions are bounded by arithmetic from the measurement.

**Accessibility (story 3; experience)**
- **FR-A07-520**: The canvas MUST describe world, speed, source, response strength and pause in words, and announce
  changes of world, source, preset and pause once each through the shared announcement sink, throttled, only while
  VoiceOver runs.

**Persistence (story 4)**
- **FR-A07-530**: Saved journeys and the session state MUST be restored after closing and reopening.

**Common**
- **FR-A07-540**: No performance claims without device measurement; no networking; audits deferred to the device
  campaign.

### Key Entities

- **Streaming budget**: levels → behind, ahead, draw distance, element share; vertex check against a mesh budget.
- **Announcement**: text, time; throttle interval.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A07-501**: For levels 0/1/2 the pieces ahead, draw distance and star count are non-increasing; each level's
  vertex total is within the mesh budget; the journey digest is unchanged by level changes.
- **SC-A07-502**: At distance 10^9 the joins match within 1e-6 and the pose matches the wrapped rail pose within 1e-6.
- **SC-A07-503**: Over 3,600 simulated frames at full speed the live-piece count never exceeds capacity and the resource
  totals at the end equal those after the first window; the per-frame build count stays ≤ 2.
- **SC-A07-504**: Each state change produces exactly one announcement while VoiceOver runs and none otherwise; rapid
  changes within the throttle produce at most one per interval.
- **SC-A07-505**: Closing and reopening restores presets and the journey exactly.
- **SC-A07-506**: The scenarios pass on iOS 27; the API baseline lists the new types, documented; every new test finishes
  in under 10 seconds.

## Assumptions

- The host chooses the quality level (as for every experience); tests force it.
- The rail is a closed loop, so world positions stay bounded; the precision risk is the unwrapped distance and piece
  index, which the fixture covers.

## Out of Scope

- Device frame-time and energy measurements (device campaign); release documents (A07-P06).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 06 (stable pause/resume, thermal quality downgrade) | FR-A07-501, 502; SC-A07-501 |
| v0.1 feature 05 (save presets) — MVP gate of Phase 05 | FR-A07-530; SC-A07-505 |
| Manual §9 Phase 05 fixture (long-duration travel precision) | FR-A07-510, 511; SC-A07-502, 503 |
| Manual §12 profiling (segment generation, long-session energy) | FR-A07-511, 540 |
| Contract gaps G-JOURNEYBUDGET, G-JOURNEYA11Y | FR-A07-501, 520 |

## Negative Requirements

- No soak or endurance runs; no claims of frame rate, battery life or comfort; no networking.
