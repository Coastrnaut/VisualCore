# Feature Specification: R02-F20 — Bounded swarm and steering simulation

**Feature Branch**: `220-bounded-swarm-and-steering-simulation` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

**Ledger gate**: R02-F20 (migration ledger, shared round feature) · ID namespace FR-R02F20-###, SC-R02F20-###, T-R02F20-###

**Input**: User description: the archived R02-F20 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"deterministic boids; neighborhood grid; magnetic fields; density raster", with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/220-bounded-swarm-and-steering-simulation`; FR-R02F20-###, SC-R02F20-###,
  T-R02F20-###.
- **Section 13 disposition: extend.** The framework has deterministic, bounded flocking forces (`SteeringAgent`,
  `SteeringBounds`, `SteeringParameters`, `Steering.force`, feature 069) and a brute-force nearest-neighbour search
  (`NeighbourSearch`), plus the fixed-step runner and seeded randomness. It has no neighbourhood grid that scales to
  thousands of agents, no swarm stepper that integrates the forces in bounded fixed steps, no magnetic fields acting on
  agents and no density picture of the swarm. This feature adds those on top of the existing types, which stay
  unchanged and keep their tests; the grid is proved to return exactly the neighbours of `NeighbourSearch`; Digital
  Aquarium is untouched.
- **Who the users are:** the player of Microscopic Aurora or Mushroom Weather, who watches thousands of drifting particles
  school, swirl around magnetic poles and gather into glowing clouds, the same way every time a scene is replayed; the
  engineer, who needs every step bounded, finite and identical on every device, and fast enough for thousands of agents.
- **Prerequisites:** R02-F03 (numerical foundations) and R02-F09 (instancing) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** the frame cost of a large swarm on D1–D3, recorded in the device
  campaign. **Owner-only items:** none.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find neighbours fast and exactly (Priority: P1) 🎯

The engineer asks for each agent's nearest neighbours within a radius among thousands of agents and gets exactly the
same answer as the existing exhaustive search, in a fraction of the work.

**Why this priority**: every swarm step depends on it.

**Independent Test**: on seeded swarms, every agent's neighbour list from the grid equals the existing search's list,
order included.

**Acceptance Scenarios**:

1. **Given** a seeded swarm, **When** neighbours are found through the grid, **Then** they equal the exhaustive search for
   every agent.
2. **Given** agents at non-finite positions or outside the grid's bounds, **When** neighbours are found, **Then** the
   result still equals the exhaustive search.

### User Story 2 - Step a bounded swarm deterministically (Priority: P1)

The engineer steps a swarm with the existing steering forces, a speed limit and walls or wrap-around edges; the same start
gives the same swarm after any number of steps, and nothing ever leaves its bounds or becomes infinite.

**Independent Test**: two runs from one seeded start are identical after many steps; every agent stays inside the
bounds with a speed within the limit.

### User Story 3 - Magnetic fields (Priority: P2)

The engineer adds magnetic poles and a uniform field; charged agents curve around them, attracted or repelled, with the
pull bounded so that no agent is flung away.

**Independent Test**: a charged agent in a uniform field circles at its speed (the field turns but does not speed it
up); an agent near an attracting pole moves toward it; forces stay bounded near a pole.

### User Story 4 - A density picture of the swarm (Priority: P2)

The engineer turns the swarm into a density grid where every agent spreads its weight over the nearest cells; the total
equals the number of agents inside the area, ready for the existing field passes to draw as glow.

**Independent Test**: the density total equals the in-area agent count within a small tolerance; an agent at a cell
centre lands in that cell only.

### User Story 5 - Save and reopen a swarm (Priority: P2)

A swarm's agents and settings are saved with a schema version and reopened to continue identically; newer and damaged
forms are refused.

**Independent Test**: a saved swarm round-trips byte for byte and continues bit-identically.

### Edge Cases

- **An empty swarm:** steps and rasters to nothing, without error.
- **Agents stacked at one point:** the existing coincident-agent rule separates them, results stay finite.
- **An agent exactly on a pole:** the field force is bounded, never infinite.
- **Agents with non-finite values:** they are left in place and excluded, never spreading non-finite values.
- **Too many agents or too large a grid:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F20-001**: A neighbourhood grid MUST return, for every agent, exactly the neighbours the existing search returns
  (same radius, limit and order).
- **FR-R02F20-002**: A swarm stepper MUST integrate the existing steering forces in fixed steps with a speed limit and
  walled or wrapping bounds, deterministically.
- **FR-R02F20-003**: Magnetic fields (uniform field and point poles) MUST act on charged agents with bounded forces.
- **FR-R02F20-004**: A density raster MUST spread each in-area agent's weight over the nearest cells so the total equals
  the in-area agent count, as a field grid for the existing passes.
- **FR-R02F20-005**: Swarms MUST have a versioned stored form that continues identically; newer and damaged forms MUST be
  refused.
- **FR-R02F20-006**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F20-007**: The existing steering types, Digital Aquarium and their tests MUST be unchanged; every new public
  name carries documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Neighbourhood grid**: cell size, bounds, buckets of agents.
- **Swarm**: agents (position, velocity, group, charge), bounds, edge mode, steering settings, speed limit, step.
- **Magnetic field**: uniform strength, poles (position, strength, softening).
- **Density raster**: grid size and bounds, cell values.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F20-001**: For 50 seeded swarms of up to 2,000 agents, the grid's neighbour list equals the existing search's
  for every agent.
- **SC-R02F20-002**: Two runs of 20 seeded swarms over 500 steps are bit-identical; every agent stays inside the bounds
  with speed at most the limit after every step.
- **SC-R02F20-003**: A charged agent in a uniform field keeps its speed within 1e-9 relative over 1,000 steps and returns
  near its start after one period; pole forces never exceed their stated bound.
- **SC-R02F20-004**: The density total equals the in-area agent count within 1e-9 relative for 50 seeded swarms; a
  cell-centre agent lands in one cell.
- **SC-R02F20-005**: Swarms round-trip byte for byte and continue bit-identically for 200 steps; newer and damaged forms are
  refused.
- **SC-R02F20-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- The swarm is two-dimensional (the existing steering is); consumers lift it into 3D for drawing.
- The consumer games do not exist yet; this slice ships the library and its proofs.
- No user interface: controls, colours, layout and accessibility belong to the consuming experiences.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic boids | FR-R02F20-002 |
| Neighbourhood grid | FR-R02F20-001 |
| Magnetic fields | FR-R02F20-003 |
| Density raster | FR-R02F20-004 |
| Schema migration | FR-R02F20-005 |
| Observability | FR-R02F20-006 |
| No Stage One breakage | FR-R02F20-007 |

## Negative Requirements / Excluded scope

- No new module, no change to `Steering`, `NeighbourSearch` or Digital Aquarium, no GPU simulation, no 3D steering, no
  physical electromagnetism claim, no device run before ImplementationLock-100, no analytics.
