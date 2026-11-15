# Feature Specification: Light Maze — Phase 01 Grid/ray reflection solver and fixtures

**Feature Branch**: `096-lm-p01-solver` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A13-P01 (legacy ledger) · ID namespace FR-A13-1##, SC-A13-1##, T-A13-1##

**Input**: User description: archived manual `apps/13-light-maze.md` §9 Phase 01 `/speckit-specify` prompt (verbatim
in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — at least 20 handcrafted levels with emitter, wall, mirror, target and
  optional prism tiles; regression fixture — the incidence angle equals the reflection angle within tolerance;
  graphics context ownership stays solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/light-maze/visualcore-contract.json`): G-RAYCAST2D (a generic 2D ray cast
  against line segments with reflection about a segment's normal, in VisualCore's math module) and G-BOARD (the tile
  board, the optical rules, the bounce cap and cycle detection, in the experience). Beam rendering and snapped gestures
  stay for A13-P02 (G-BEAMS, G-SNAP); level select, progression, undo and saved progress for A13-P03 (G-LEVELS); hints
  and feedback for A13-P04; the solvability checker for A13-P05.
- **Experience:** created in `Packages/ExperiencesCreative/LightMaze`, registered as a candidate with its scenario
  manifest; the slice draws a real board with its beam that a person can change with native controls — no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; the reference
  regression for the VisualCore change runs at X-A13 (owner ruling 2026-11-14); every Spec Kit step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn a mirror and light the target (Priority: P1) 🎯

A person opens Light Maze and sees a small board: an emitter sending a beam, walls, a mirror and a target. Turning the
mirror with a native control redirects the beam; when it reaches the target the board says it is lit.

**Why this priority**: the manual's first journey ("rotate a mirror to redirect a beam into a target sensor") and the
smallest slice that proves the rules reach the screen through the one host.

**Independent Test**: open the experience on the simulator; a non-blank frame shows the board and the beam; turning
the mirror changes the beam path and the lit state.

**Acceptance Scenarios**:

1. **Given** the first level, **When** the experience opens, **Then** the board and the beam are drawn, and the spoken
   description names the level, the tiles and where the beam ends.
2. **Given** the first level, **When** the mirror is turned to its correct orientation, **Then** the beam reaches the
   target and the level reads as solved; turning it back makes it unsolved.

---

### User Story 2 - The beam follows exact, bounded rules (Priority: P1)

The engineer and the owner can trust the beam: it reflects with the angle of incidence equal to the angle of
reflection, it never gets stuck on the surface it just left, it never runs forever, and the same board always gives
the same path.

**Why this priority**: the manual's regression fixture and algorithm decisions 1–2; every later phase depends on it.

**Independent Test**: cast rays against segments at many angles; trace boards with loops and long paths; compare with
committed fixtures.

**Acceptance Scenarios**:

1. **Given** a ray meeting a segment at any angle, **When** it reflects, **Then** the incidence and reflection angles
   are equal within a stated tolerance and the reflected direction has unit length.
2. **Given** a ray starting on the surface it just left, **When** it is cast again, **Then** it does not hit that same
   surface at distance zero.
3. **Given** mirrors that would make the beam loop, **When** traced, **Then** the trace ends at the bounce cap or on the
   first repeated state, and reports why.
4. **Given** each level and its stored state, **When** traced twice, **Then** the beam segments are identical and equal
   the committed fixtures.

---

### User Story 3 - Twenty handcrafted levels (Priority: P1)

A person can step through at least 20 small handcrafted levels that use walls, mirrors, targets and, in later ones, a
prism that splits the beam; each level has at least one recorded solution that the rules prove.

**Why this priority**: the phase's MVP requirement.

**Independent Test**: load every bundled level; apply its recorded solution; the tracer reports all targets lit.

**Acceptance Scenarios**:

1. **Given** the bundled levels, **When** loaded, **Then** there are at least 20, each valid (one emitter, at least
   one target, every tile inside the board).
2. **Given** each level's recorded solution, **When** applied, **Then** every target is lit; **Given** the level's
   starting state, **Then** it is not already solved.

---

### User Story 4 - Every bundled level records its origin (Priority: P2)

The owner can see that every bundled level is original content with an author and a license, in a generated document
that a test keeps equal to the catalog.

**Independent Test**: run the license audit; read the generated document.

**Acceptance Scenarios**:

1. **Given** the level catalog, **When** audited, **Then** every level has author and license and 0 problems are
   reported; a record without a license or with an unsupported one is refused with a reason.

### Edge Cases

- **A ray parallel to a segment or meeting it exactly at an end point:** handled by a stated rule (parallel misses;
  end points count as hits on the segment), never a crash or a non-finite result.
- **Non-finite input** (origin, direction, segment points): refused, never a hit.
- **A beam leaving the board:** ends at the board's edge with the reason "left the board".
- **A beam hitting a wall or the back of a target:** ends there with its reason.
- **Prism splitting into paths that cross or loop:** every branch is bounded by the same cap; the total segment count is
  capped.
- **A level file that is damaged, newer or breaks the rules** (two emitters, tiles outside, out-of-range rotation):
  refused with a reason; the previous level stays.
- **Context loss or backgrounding:** the drawing is rebuilt from the board state; nothing animates in this slice.
- **Damaged or newer saved state:** refused; the first level opens.

## Requirements *(mandatory)*

### Functional Requirements

**Generic 2D ray casting in VisualCore (G-RAYCAST2D, story 2)**

- **FR-A13-101**: VisualCore's math module MUST offer a 2D ray and a cast against line segments returning the nearest
  hit (distance, point, segment index and the segment's normal facing the ray), with stated rules for parallel rays,
  end points and non-finite input.
- **FR-A13-102**: VisualCore MUST offer the reflection of a direction about a normal, preserving length, so that the
  incidence angle equals the reflection angle within a stated tolerance.
- **FR-A13-103**: A cast MUST be able to exclude the segment just left (and use a stated minimum distance) so a
  reflected ray never hits its own surface at distance zero.
- **FR-A13-104**: The new generic code MUST be documented, covered by host tests and recorded in the API baseline and the
  VisualCore README; existing APIs MUST NOT change.

**The puzzle core (G-BOARD, stories 1–3)**

- **FR-A13-110**: The experience MUST define a board (width, height in cells) with tiles: emitter (with direction),
  wall, mirror (with orientation), target (lit from any side) and prism (splits the beam), each in one cell.
- **FR-A13-111**: The tracer MUST compute the beam from the board using the generic ray cast, with a bounce cap, a total
  segment cap and cycle detection, and report each segment, the lit targets and why each branch ended.
- **FR-A13-112**: A level (tiles, starting orientations, schema version) MUST be validated; invalid levels MUST be
  refused with a reason and change nothing.
- **FR-A13-113**: At least 20 handcrafted levels MUST be bundled, each with at least one recorded solution proven by
  the tracer and a starting state that is not solved; committed beam fixtures MUST pin several levels' paths.
- **FR-A13-114**: Content records (levels) MUST carry author and license; an audit MUST refuse missing or unsupported
  licenses with reasons and a generated document MUST match the catalog.

**The experience (story 1)**

- **FR-A13-120**: The experience MUST draw the current board and its beam through the one host's drawing path, from the
  tracer's exact segments, and rebuild its GPU objects after context loss; drawing MUST NOT change the board.
- **FR-A13-121**: Native controls MUST choose the previous or next level, select a mirror or prism and turn it, and
  reset the level, each with a VoiceOver label and value; the canvas MUST have a spoken description (level, tiles,
  beam end, solved state).
- **FR-A13-122**: The experience MUST be registered as a candidate with a scenario manifest (standard scenarios and
  fixtures), saved and restored through its state schema 1, with damaged or newer payloads refused.

### Key Entities

- **Ray and hit (2D)**: origin, unit direction; nearest hit distance, point, segment index, normal.
- **Board**: width, height, tiles.
- **Tile**: kind (emitter, wall, mirror, target, prism), cell, orientation.
- **Beam**: segments (start, end, bounce index, branch), lit targets, end reasons.
- **Level**: id, name, board, starting orientations, recorded solution, author, license, schema version.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A13-101**: Over a sweep of incidence angles, 100 % of reflections keep incidence equal to reflection within the
  stated tolerance and keep unit length.
- **SC-A13-102**: 0 self-hits at distance zero across the reflection tests; every looping board ends within the cap.
- **SC-A13-103**: At least 20 levels load; 100 % have a recorded solution that lights every target and a starting state
  that is not solved; the committed beam fixtures reproduce exactly.
- **SC-A13-104**: The license audit reports 0 problems for the bundled levels and the generated document matches.
- **SC-A13-105**: The board draws a non-blank frame on the iOS 27 simulator; turning a mirror changes the drawn beam.
- **SC-A13-106**: The runner's nine standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- VisualCore's vectors, primitives with transforms, the primitive renderer, the experience host and storage are reused
  (A13-P00 contract).
- Beam glow, snapped drag and rotate gestures, level select with progression and undo are later phases; this slice
  draws plain lines and uses native controls.
- Snapshot schema 1 holds the level index and the current orientations; saved progress is A13-P03.

## Traceability

| Source | Requirement |
|---|---|
| Phase 01 MVP: at least 20 handcrafted levels with emitter, wall, mirror, target and prism | FR-A13-110, 112, 113, US3 |
| Regression fixture: incidence equals reflection within tolerance | FR-A13-101–103, US2 |
| EGL/context ownership in the VisualCore host | FR-A13-120 |
| Brainstorm: geometry and transformations, render targets, shaders, touch controls | FR-A13-101, 120, 121 |
| Manual algorithm decisions 1–2 (CPU ray/segment intersection; epsilon, last-hit tracking, bounce cap, cycle detection) | FR-A13-101–103, 111 |
| Contract gaps G-RAYCAST2D, G-BOARD | FR-A13-101–104, 110–114 |

## Negative Requirements

- No sprites, textures or artwork; no network; no second renderer or EGL path; no shader deciding the solved state; no
  refraction physics; no level editor or sharing; no glow, gestures, progression or saved progress beyond the slice in
  this phase.
