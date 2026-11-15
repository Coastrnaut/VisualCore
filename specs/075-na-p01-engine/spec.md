# Feature Specification: Neon Arcade — Phase 01 Fixed-step engine and collision fixtures

**Feature Branch**: `075-na-p01-engine` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A10-P01 (legacy ledger) · ID namespace FR-A10-1##, SC-A10-1##, T-A10-1##

**Input**: User description: archived manual `apps/10-neon-arcade.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — one complete game first: Neon Dodge with a player lane, falling hazards
  and collectible orbs; regression fixture — a recorded input replay produces identical score and collision ticks;
  graphics-context ownership stays solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/neon-arcade/visualcore-contract.json`): G-COLLISION2D (generic 2D
  overlap and swept tests in VisualCore's simulation module; the high-speed fixture that proves the swept case for the
  game is A10-P03's, the generic swept test itself is proved here) and the Phase 01 part of G-GAMERULES (the
  app-local game run, spawning, scoring, lives, input replay and content license records). Lanes with the full wave
  director, difficulty and the complete mechanics stay for A10-P02.
- **Experience:** created in `Packages/ExperiencesCreative/NeonArcade`, registered as a candidate with its scenario
  manifest; the slice draws a real, playable game (player, hazards, orbs, score and lives, all in code) — no
  placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; the reference
  regression for this VisualCore change runs at X-A10 (owner ruling 2026-11-14, "faster gates"); every Spec Kit
  step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code: an
`ExperienceCore` declares `stepDuration` (default 1/120 s), `update(step:)`, `apply(_:)`, `reset()`, snapshot payload
and restore with a `MigrationChain`, `qualityTiers` (default 1); an `ExperienceAction` carries `control`, `values` and
the `step` it applies at, so a recorded action list is an input record; the engine's `suspend()`/`resume()` stop and
restart stepping and its fixed-step run serves replays (`ExperienceEngine.swift`); `SeededRandom` saves and restores
its state; `Primitive` offers rect, circle, line, polygon and polyline shapes drawn in one batch; `Vec2` lives in
`VisualCoreMath`; no 2D shape-against-shape or swept test exists in any framework product (contract G-COLLISION2D).

- Q: Which coordinates, speeds and step does the game use? → A: Game units, portrait field 9 × 16 (x 0…9, y 0…16, y
  up); the fixed step is 1/60 s; the player is a circle of hit radius 0.4 on the line y = 1.5, x kept inside 0.5…8.5,
  maximum speed 9 units/s; a steering value −1…1 sets the target velocity (value × maximum speed) and holds until the
  next steering input. Drawing scales the field uniformly and letterboxes it.
- Q: What exactly does the shared collision code offer, and how does it treat touching and fast objects? → A: In
  `VisualCoreSimulation`: a circle (centre, radius), a capsule (segment end points, radius), overlap tests
  circle–circle and circle–capsule (touching counts, tolerance 1e-9), and a swept circle–circle test over one step
  (both circles move linearly; it returns the earliest fraction 0…1 at which they touch, or none; a pair already
  touching at the start returns 0); non-finite or negative-radius input gives none. The game uses the swept test for
  every circle object against the player; capsule hazards fall at most 5 units/s (0.083 units per step, below the
  smallest summed radius 0.6), so the end-of-step overlap test cannot miss them — an invariant the tests check.
- Q: How are objects spawned, and what are the values and limits? → A: The first object spawns at step 30 (0.5 s),
  then one every 40 steps; the seeded generator picks hazard (70 %) or orb (30 %), x uniform in 0.5…8.5, start y 16.5,
  fall speed 3…5 units/s; hazards are circles (radius 0.35…0.6) or horizontal capsules (half-length 0.6…1.0, radius
  0.2); orbs are circles of radius 0.25 worth 10 points. At most 24 objects; a spawn beyond the cap is skipped. Lives
  start at 3; a hit grants 90 steps (1.5 s) of invulnerability; the score is capped at 9,999,999. Lanes, waves and
  difficulty replace this simple schedule in A10-P02.
- Q: Which actions and saved state does the experience have, and how is a replay recorded? → A: Actions `run.steer
  [−1…1]`, `run.pause [0…1]` and `run.restart`; the drag gesture turns the finger's horizontal offset from the player
  into a steering value (offset ÷ 1.5 units, clamped) and sends `run.steer`; left/right controls send −1/+1 while held
  and 0 on release. A replay is the seed plus the list of applied `run.steer` actions with their steps; the game keeps
  the last 256 collision events (step, object id, kind) and their total count, and the digest covers both. Snapshot
  schema 1 holds the game run and the generator state; one quality level (`level-0`).
- Q: Where is the content catalog, and how are shapes drawn? → A: In the experience's core as Swift data
  (`ArcadeCatalog.bundled`) with a JSON encoding and a validating decoder used by tests and the audit: the player
  (shape `chevron`), hazards (`spike-ball` circle, `bar` capsule) and the orb (`glow-orb` circle), each with colours,
  size limits and value, author "VisualCore project" and license "MIT" (the only allowed license); refusal reasons
  `missing-license`, `unsupported-license`, `unknown-shape`, `invalid-number`. Every object is drawn with its
  collision shape at the rule size (the player: a ring at the hit radius with a chevron inside); the license document
  is generated as `docs/apps/neon-arcade/content-licenses.md` and checked against the catalog by a test.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A game to play (Priority: P1) 🎯

A person opens Neon Arcade and plays Neon Dodge at once: a glowing player shape near the bottom of the field moves
left and right as they steer, hazards fall from the top and must be avoided, orbs fall too and add to the score when
collected; the run ends when the lives are gone, and a new run can start.

**Why this priority**: the manual's MVP (version 0.1 feature 01) and journey 1.

**Independent Test**: opening the experience shows a non-blank field with the player, at least one falling object
within the first seconds, a score and the lives; steering moves the player; touching a hazard costs a life;
collecting an orb raises the score.

**Acceptance Scenarios**:

1. **Given** a new run, **When** the experience opens, **Then** the player stands in its band, the score is 0, the
   lives are full, and hazards and orbs begin to fall within 2 seconds of game time.
2. **Given** a steering input to the left or right, **When** the next steps run, **Then** the player moves that way at
   no more than its maximum speed and never leaves the field.
3. **Given** a hazard that touches the player, **When** the collision is resolved, **Then** one life is lost, the hazard
   is removed and the player cannot be hit again for a short invulnerability time.
4. **Given** an orb that touches the player, **When** the collision is resolved, **Then** the score rises by the orb's
   value and the orb is removed.
5. **Given** the last life is lost, **When** the step ends, **Then** the run is over, nothing moves, and a restart begins
   a new run with the same rules.

---

### User Story 2 - The same inputs give the same game (Priority: P1)

A recorded game — its seed and the person's steering inputs with the steps at which they happened — replays to exactly
the same score, lives and collision steps, whatever the frame rate of the screen.

**Why this priority**: the manual's Phase 01 regression fixture and algorithm decisions 1 and 4 (fixed step
independent of the frame rate; serialized inputs for test replays; drawing never decides a hit).

**Independent Test**: replaying a recorded run twice, and once at a different frame pacing, gives identical score,
lives and the identical list of (step, object, kind) collision events.

**Acceptance Scenarios**:

1. **Given** a seed and a recorded input list, **When** the run is replayed twice, **Then** the score, the lives and
   the collision events with their steps are identical.
2. **Given** the same seed and inputs, **When** the steps are driven by frames of 1/30 s and of 1/60 s (and 1/120 s),
   **Then** the outcome after the same number of game steps is identical.
3. **Given** a run, **When** it is drawn or not drawn, or drawn at another quality level, **Then** the game state is
   unchanged.

---

### User Story 3 - Collisions that cannot be missed (Priority: P1)

Hits are decided by the same simple shapes the person sees, and a fast object can never pass through the player
between two steps.

**Why this priority**: manual algorithm decisions 2 and 3 (swept tests against tunnelling; collision geometry separate
from effects); gap G-COLLISION2D.

**Independent Test**: generic overlap tests (circle with circle, circle with capsule) and a swept test (a moving circle
against a circle over one step) give the right answer for touching, separated, inside and grazing cases, and a
circle moving much farther than its own size in one step is still reported as hitting a circle in its path.

**Acceptance Scenarios**:

1. **Given** two circles whose distance equals the sum of their radii, **When** they are tested, **Then** they overlap
   (touching counts); one unit farther apart, they do not.
2. **Given** a circle and a capsule (a segment with a radius), **When** the circle touches the capsule's side or one of
   its rounded ends, **Then** they overlap; otherwise not.
3. **Given** a circle moving from one side of another circle to the other in one step, faster than both sizes
   together, **When** the swept test runs, **Then** it reports a hit and the first fraction of the step at which they
   touch, between 0 and 1.
4. **Given** non-finite positions or radii, **When** any test runs, **Then** it reports no hit (never a crash).

---

### User Story 4 - The game is saved and paused safely (Priority: P2)

A run survives leaving and returning: score, lives, the falling objects and the player come back as they were, the
game never fast-forwards while it was away, and damaged saved data never breaks the experience.

**Why this priority**: catalog fixture "background/resume freezes simulation rather than catching up" (manual §11
fixture 2); the base for local scores in A10-P04.

**Acceptance Scenarios**:

1. **Given** a running game, **When** its state is saved and restored, **Then** the run (seed state, step, score,
   lives, player, objects) is identical.
2. **Given** the experience is suspended for any wall-clock time, **When** it resumes, **Then** the game continues from
   the same step (no catch-up).
3. **Given** a damaged or newer saved state, **When** it is restored, **Then** it is refused and a new run opens.
4. **Given** the person pauses, **When** steps would run, **Then** nothing moves until they resume.

### Edge Cases

- **Two hits in the same step** (a hazard and an orb, or two hazards): resolved in a fixed order (objects by their
  spawn order); during invulnerability later hazards in that step cost nothing.
- **A hazard touches the player during invulnerability:** it passes without effect (no life lost, no event, not
  removed); orbs are still collected. A restart resets steering to 0, the score to 0 and the lives to 3.
- **An object spawned overlapping the player:** it can be collected or hit only from the next step on; spawning is
  never inside the player's band.
- **Steering held against a wall:** the player stops at the field edge; no tunnelling through the wall.
- **Too many objects:** falling objects are capped; a spawn beyond the cap is skipped, not queued.
- **Very small screens or iPad landscape:** the field keeps its game coordinates; drawing scales and letterboxes, the
  game does not change.
- **Reduce Motion:** the game itself is unchanged (it is the content); the glow pulse and background drift are halved.
- **Non-finite numbers in input or saved state:** refused; an input with a non-finite value is ignored.
- **Score overflow:** the score is capped at a maximum; reaching it is not an error.

## Requirements *(mandatory)*

### Functional Requirements

**Generic collision (G-COLLISION2D, VisualCore)**

- **FR-A10-101**: The shared simulation module MUST offer generic 2D tests: circle–circle overlap, circle–capsule
  overlap and a swept circle–circle test that returns whether and at which fraction of the step two moving circles
  first touch; touching counts as overlap; non-finite inputs give "no hit".
- **FR-A10-102**: The tests MUST be pure and deterministic, documented, part of the published interface record, and
  proved by tests including a tunnelling case (travel per step at least four times the summed radii).
- **FR-A10-103**: Because the shared module changes, its documentation and published interface record MUST be updated
  in this phase and the seven-step reference regression MUST be scheduled for X-A10 (two chunks).

**Game run (G-GAMERULES, Phase 01 part, app-local)**

- **FR-A10-110**: A game run MUST be a versioned, validated record of: seed state, step count, score, lives, paused
  and over flags, the player (position, velocity, hit radius, invulnerability steps) and the falling objects (kind
  hazard or orb, position, velocity, shape, value), advanced only at a fixed step.
- **FR-A10-111**: Each step MUST apply that step's steering input, move the player within the field at no more than its
  maximum speed, spawn objects from the seeded generator on a schedule, move them, and resolve collisions with the
  swept test (hazard: lose a life and start invulnerability; orb: add its value); objects that leave the field are
  removed; when the lives reach 0 the run is over.
- **FR-A10-112**: Inputs MUST be recordable as (step, steering value) entries and replayable; the same seed and inputs
  MUST give the same score, lives and collision events (step, object id, kind), independent of frame pacing and of
  drawing.
- **FR-A10-113**: The shapes, colours and values of the player, hazards and orbs MUST come from a content catalog whose
  every item records author and license; loading MUST refuse a missing or unsupported license, an unknown shape or a
  non-finite number, naming the reason; a content license document MUST list every item.

**Experience**

- **FR-A10-120**: The experience MUST draw the field, the player, hazards and orbs procedurally through the host's
  renderer only, with the collision shapes drawn at the sizes the rules use, and show the score and the lives; a spoken
  description MUST name the score, the lives and whether the run is playing, paused or over.
- **FR-A10-121**: The person MUST be able to steer (drag on the field, and left/right controls as an alternative),
  pause and resume, and restart; the state MUST be saved and restored by the host, and suspension MUST NOT advance the
  game.
- **FR-A10-122**: Every control MUST have a VoiceOver label and value; with Reduce Motion on, the glow pulse and
  background drift MUST be halved while the game is unchanged.
- **FR-A10-123**: The experience MUST be registered as a candidate with a scenario manifest holding the nine standard
  scenarios and fixtures for input replay, frame-pacing independence, swept collision, save/restore, no catch-up on
  resume, catalog refusal and bounded object counts.

### Key Entities

- **Game run**: version, seed state, step, score, lives, paused, over, player, falling objects, next object id.
- **Player**: position, velocity, hit radius, invulnerability steps.
- **Falling object**: id, kind (hazard or orb), position, velocity, shape and radius, value.
- **Input record**: seed and a list of (step, steering value).
- **Collision event**: step, object id, kind.
- **Content item**: id, shape, colours, size, value, author, license.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A10-101**: A new run shows the player, score 0 and full lives, and the first falling object appears within 2
  seconds of game time; steering moves the player and 0 player positions leave the field over 10,000 steps from 20
  seeds.
- **SC-A10-102**: Replaying a recorded run gives identical score, lives and collision events in 100 % of repeats and at
  frame times of 1/30, 1/60 and 1/120 s.
- **SC-A10-103**: The generic collision tests answer 100 % of the fixed cases correctly (touching, separated, inside,
  grazing, capsule ends, non-finite) and the swept test catches 100 % of tunnelling cases with travel of 4 to 50 times
  the summed radii.
- **SC-A10-104**: 100 % of bundled content items carry author and license; 100 % of malformed catalog fixtures are
  refused with a named reason.
- **SC-A10-105**: Save/restore round trips are identical; a resume after any suspension continues from the same step.
- **SC-A10-106**: The nine standard scenarios and the fixtures pass on iOS 27; the VisualCore host tests and the
  public-interface check pass; each package test finishes in under 10 seconds.

## Assumptions

- The game field uses fixed game units in portrait orientation; the exact size, speeds, spawn schedule and values are
  set in clarification and plan, and tuned in A10-P05.
- The fixed step, seeded generator, control stream for recorded inputs, batched shape drawing, gestures, storage and
  quality tiers are reused from VisualCore (contract rows M01–M04, M07, M13, M14).
- Lanes, waves and difficulty (A10-P02), glow, particles, sound and haptics (A10-P03), local high scores and the full
  accessibility pass (A10-P04) and balance (A10-P05) come later.

## Out of Scope

- Lanes and wave patterns, difficulty ramps, high scores, particles and bloom, sound, haptics, title and game-over
  screens beyond the in-field state, settings for sensitivity.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 01 (Neon Dodge with player lane, falling hazards and orbs) | FR-A10-110, 111, 120, 121; story 1 |
| v0.1 feature 02 (deterministic fixed-step loop, authoritative collision) | FR-A10-101, 102, 111, 112; stories 2, 3 |
| Phase 01 regression fixture "recorded input replay produces identical score and collision ticks" | FR-A10-112; story 2 |
| Manual algorithm decisions 1–4 (fixed step, swept collision, separate geometry, serialized inputs) | FR-A10-101, 111, 112, 120 |
| Manual §11 fixture 2 "background/resume freezes simulation" | FR-A10-121; story 4 |
| Manual §11 fixture 3 "swept collision catches high-speed hazards" (generic part) | FR-A10-101, 102; story 3 |
| Contract gaps G-COLLISION2D, G-GAMERULES (Phase 01 part) | FR-A10-101–103, 110–113 |
| Constitution A10 licenses rule | FR-A10-113 |

## Negative Requirements

- No artwork, sprites, textures or recordings; no network; no permission; no online leaderboards; no loot boxes or
  purchasable currency; no claims of skill, reflex, cognitive or health benefits; no second renderer or context; no
  ProjectM code; drawing never changes the game state.
