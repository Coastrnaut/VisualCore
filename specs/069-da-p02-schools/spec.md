# Feature Specification: Digital Aquarium — Phase 02 Fish movement and visual prototype

**Feature Branch**: `069-da-p02-schools` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A09-P02 (legacy ledger) · ID namespace FR-A09-2##, SC-A09-2##, T-A09-2##

**Input**: User description: archived manual `apps/09-digital-aquarium.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — bounded 2D/2.5D school behaviours and swim animation; regression fixture —
  save/load preserves species, decor transforms and lighting; graphics-context ownership stays solely in the
  VisualCore host.
- **Gaps built here** (contract `docs/apps/digital-aquarium/visualcore-contract.json`): G-STEERING upstream in
  `VisualCoreSimulation` (bounded steering forces — separation, alignment, cohesion and boundary avoidance — with a
  bounded neighbour search; docs, public-API baseline, host tests; reference regression at X-A09) and G-FISHSWIM
  app-local (swim animation of the procedural fish). Decor with transforms (position, rotation, scale) enters the
  habitat document so the fixture proves they persist.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## Clarifications

### Session 2026-11-14

Facts checked in code: `VisualCoreSimulation` has no steering or neighbour type (only particles, field grids, clocks
and seeded random); `VisualCoreMath.Vec2` offers `+ - * /`, `dot`, `cross`, `length`, `normalized`, `distance(to:)`
and `isFinite`; `DecorPlacement` holds only `kindId` and `position`, the bundled catalog has no decor kinds and the
Phase 01 starter documents carry no decor; `FishAgent` holds no turn value.

- Q: Where does the steering live and how does it name its types? → A: A new file in `VisualCoreSimulation` with
  value types `SteeringAgent` (position, velocity, group), `SteeringBounds` (rectangle), `SteeringParameters` (weights,
  radii, boundary margin, maximum force) and the functions `NeighbourSearch.neighbours(of:in:radius:limit:)` and
  `Steering.force(for:agents:neighbours:parameters:bounds:)`; nothing from the aquarium enters VisualCore.
- Q: How does the neighbour search stay bounded and deterministic? → A: A linear scan over the agents (at most the
  caller's count; the aquarium has ≤ 24) that keeps the `limit` nearest agents within `radius`, ordered by distance
  and then by index; the agent itself is never returned; a limit ≤ 0 or a non-finite radius returns nothing. No grid
  in this phase (24 fish do not need one).
- Q: Which forces act between fish of different species? → A: Separation acts between all agents; alignment and
  cohesion only between agents of the same `group` (the species). A lone fish of a species gets only separation and
  boundary forces, plus the Phase 01 seeded wander turn, which stays at a reduced weight so fish never freeze.
- Q: What does schema 2 add to the document and how is schema 1 migrated? → A: `DecorPlacement` gains `rotation`
  (radians, −π…π) and `scale` (0.5…2.0); `FishAgent` gains `turn` (smoothed heading change in radians per second,
  used only for drawing the bend); the catalog gains decor kinds (rock and shell shapes, colour, size, author,
  license) and each starter habitat a list of starter decor spots. A schema-1 state decodes with rotation 0, scale 1
  and turn 0, and when its decor list is empty the habitat's starter decor is added; schema 2 is then written.
  Validation refuses unknown decor kinds (with a catalog), positions outside the tank and scales outside 0.5…2.0.
- Q: What are the drawn swim-animation amounts? → A: The tail swing is 0.15 body lengths and the body wave 0.06 body
  lengths at full motion, driven by the state's animation phase (which advances with speed / body length, so faster
  fish beat more often); the bend toward the turn is `turn` × 0.12 s, capped at ±0.35 rad; Reduce Motion halves the
  swing, the wave and the bend in drawing only. Heading agreement (SC-A09-202) is measured as the length of the mean
  unit heading of each species with at least two fish, averaged over those species.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fish that swim together (Priority: P1) 🎯

A person watching the aquarium sees fish of the same species gather into loose schools that turn together, keep a
little distance from each other and never crowd into a single point, while still staying inside the water.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: over a simulated run, fish of one species end up closer to each other than at the start, never
closer than a minimum spacing on average, heading in similar directions, and always inside the swim bounds.

**Acceptance Scenarios**:

1. **Given** a habitat with two species, **When** the simulation runs for 30 simulated seconds, **Then** the average
   distance between same-species fish is smaller than at the start and smaller than the average distance between fish
   of different species.
2. **Given** a school, **When** it swims, **Then** same-species neighbours head in similar directions (their average
   heading agreement is clearly higher than for random headings).
3. **Given** any run, **When** positions are checked at every step, **Then** no fish leaves the swim bounds and no fish
   exceeds its species' maximum speed (the Phase 01 fixture still holds).
4. **Given** two fish about to overlap, **When** the next steps run, **Then** they move apart until at least the
   separation distance.

---

### User Story 2 - Fish that look alive (Priority: P1)

The fish swim with a visible body wave: the tail beats faster when a fish swims faster, the body bends slightly into
turns, and fish facing left and right look correct.

**Why this priority**: the manual's "swim animation" half of the MVP.

**Independent Test**: the drawn fish outline changes over time with a period tied to speed, bends toward the turn
direction, and is mirrored by heading; the frame differs between two moments of the same swim.

**Acceptance Scenarios**:

1. **Given** a fish at cruise speed and the same fish at maximum speed, **When** the animation advances, **Then** the
   faster fish beats its tail more often.
2. **Given** a fish turning left, **When** it is drawn, **Then** its body curves toward the left.
3. **Given** Reduce Motion, **When** fish swim, **Then** the body wave and tail swing are halved while the paths stay
   the same.

---

### User Story 3 - The aquarium is saved as it was (Priority: P2)

A person's aquarium — the species, the decor pieces with their positions, rotations and sizes, and the lighting —
comes back exactly as it was after leaving and returning, and an aquarium saved before this phase still opens.

**Why this priority**: the manual's Phase 02 regression fixture.

**Independent Test**: save and restore round trips keep species, decor transforms and lighting; a Phase 01 saved state
restores with the starter decor.

**Acceptance Scenarios**:

1. **Given** an aquarium with decor at bright lighting, **When** it is saved and restored, **Then** species, every decor
   transform and the lighting are identical.
2. **Given** a saved state from Phase 01 (no decor transforms), **When** it is restored, **Then** it opens with its
   fish, plants and lighting kept and the habitat's starter decor added.

### Edge Cases

- **A lone fish of a species:** it wanders as in Phase 01 (no neighbours, no school forces).
- **Neighbours beyond the search radius:** ignored; the neighbour search never visits more than a bounded number of fish.
- **Fish exactly on top of each other:** separation pushes them apart in a deterministic direction.
- **Many fish (the 24-fish cap):** the per-step work stays bounded by the neighbour limit.
- **Decor outside the tank or with a non-positive scale:** refused at validation.
- **Paused:** no movement and no animation change in the state.

## Requirements *(mandatory)*

### Functional Requirements

**VisualCore (G-STEERING)**

- **FR-A09-201**: VisualCore MUST offer bounded steering forces (separation, alignment, cohesion and boundary
  avoidance) for agents in a plane, each weighted and capped, with the combined force capped by a maximum.
- **FR-A09-202**: VisualCore MUST offer a bounded neighbour search that returns, for an agent, at most a given number of
  neighbours within a radius, nearest first with ties broken by index, never the agent itself, deterministically
  (same input, same order).
- **FR-A09-203**: The steering and the search MUST be deterministic, host-tested, documented and recorded in the public
  API baseline; existing simulation types stay unchanged.

**Experience**

- **FR-A09-210**: Same-species fish MUST school using the VisualCore steering with the species' tuning; fish of another
  species are separated from but not aligned with or drawn toward; a reduced seeded wander turn remains; the Phase 01
  bounds and speed guarantees MUST still hold, and no fish drops below half its cruise speed; every fish's force is
  computed from the state at the start of the step, so the result does not depend on the fish order; each fish's
  smoothed `turn` is kept in the state for drawing.
- **FR-A09-211**: Fish MUST be drawn with a swim animation: a body wave (0.06 body lengths) whose frequency grows with
  speed, a tail swing (0.15 body lengths) and a bend toward the turn (`turn` × 0.12 s, at most ±0.35 rad); Reduce
  Motion halves the drawn wave, swing and bend and never changes the state.
- **FR-A09-212**: The habitat document MUST hold decor pieces with position, rotation (−π…π) and scale (0.5…2.0)
  (schema 2); the catalog MUST hold licensed decor kinds and starter decor per habitat; a schema-1 state MUST migrate
  (rotation 0, scale 1, turn 0, starter decor added when it has none); decor is drawn procedurally (rocks and
  shells); unknown kinds, positions outside the tank and scales outside 0.5…2.0 are refused. The saved experience
  state moves to snapshot schema 2 and restores a schema-1 snapshot through the same migration; a snapshot that still
  fails validation after migration is refused as in Phase 01.
- **FR-A09-213**: The scenario manifest MUST add fixtures for schooling and for save/load of species, decor transforms
  and lighting.

### Key Entities

- **Steering parameters**: separation, alignment and cohesion weights and radii, boundary margin, maximum force.
- **Neighbour query**: radius, maximum count.
- **Decor piece**: kind, position, rotation (−π…π), scale (0.5…2.0); catalog decor kinds (rock or shell shape, colour,
  size) with author and license; starter decor spots per habitat.
- **Fish (schema 2)**: the Phase 01 fields plus `turn`, the smoothed heading change used for drawing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A09-201**: After 30 simulated seconds, the mean same-species distance is at most 60 % of its starting value and
  smaller than the mean cross-species distance, for at least 18 of 20 seeds.
- **SC-A09-202**: The heading agreement — the length of each species' mean unit heading, averaged over species with
  at least two fish — is at least 0.7 (1 = all parallel) after 30 simulated seconds, for at least 18 of 20 seeds.
- **SC-A09-203**: 0 positions outside the bounds and 0 speeds above maximum over 10,000 steps × 20 seeds.
- **SC-A09-204**: Save/restore keeps species, decor transforms and lighting identical in 100 % of round trips; a
  schema-1 state migrates.
- **SC-A09-205**: The neighbour search never returns more than its limit; the steering and search host tests and the
  aquarium tests each finish in under 10 seconds.

## Assumptions

- Feeding and decoration placement gestures come in A09-P03; caustics, bubbles and depth layers in A09-P04.

## Out of Scope

- Feeding, placement gestures, particles, caustics, ambient mode; 3D movement (the depth is a drawing order only).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 02 (bounded 2D/2.5D school behaviours and swim animation) | FR-A09-201, 202, 210, 211; stories 1–2 |
| Manual algorithm decision 1 (bounded steering forces with a small neighbour search) | FR-A09-201, 202 |
| Manual algorithm decision 2 (orientation and fin animation follow velocity with smoothed heading) | FR-A09-211 |
| Catalog fixture "Save/load preserves species, decor transforms and lighting" | FR-A09-212, 213; story 3 |
| Manual risk 3 (erratic motion — capped forces and smoothing) | FR-A09-201 |
| Contract gaps G-STEERING, G-FISHSWIM | FR-A09-201–203, 211 |

## Negative Requirements

- No second renderer or context; no artwork; no network; no claims of realistic animal behaviour.
