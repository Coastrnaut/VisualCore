# Feature Specification: R02-F20 — Bounded swarm and steering simulation

**Feature Branch**: `220-bounded-swarm-and-steering-simulation` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

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

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): `SteeringAgent` (position, velocity, group; `Sendable`, `Equatable`, not `Codable`),
`SteeringBounds`, `SteeringParameters` (neighbour radius and limit, weights, margin, `maxForce`), `Steering.force` and
`NeighbourSearch.neighbours(of:in:radius:limit:)` (within radius, nearest first, ties by index, non-finite agents
excluded) are in VisualCoreSimulation and used by Digital Aquarium; `FieldGrid` holds `Float` channels; the names
`Swarm`, `SwarmParameters`, `SwarmError`, `NeighbourGrid`, `MagneticField`, `MagneticPole` and `DensityRaster` are free.

- Q: Where does the swarm live, and how big may it be? → A: in VisualCoreSimulation beside `Steering`, reusing
  `SteeringAgent`, `SteeringBounds`, `SteeringParameters` and `Steering.force` unchanged; charges are kept in a parallel
  array of the swarm so `SteeringAgent` does not change. At most 65,536 agents; grids and rasters at most 1,048,576
  cells. Rationale: Section 13 extension; Digital Aquarium keeps compiling. Impact: FR-R02F20-001, 002, 007.
- Q: How does the grid guarantee the same neighbours? → A: `NeighbourGrid` buckets finite agents by ⌊position / cell⌋
  (cell size = the query radius unless given, keyed by integer cell, so no bounds are needed); a query scans the cells
  within ⌈radius / cell⌉ of the agent's cell, measures with the same `distance(to:)`, keeps d ≤ radius, sorts nearest
  first with ties by index and takes the limit — the same rule as `NeighbourSearch`, so the lists are equal. Impact:
  FR-R02F20-001; SC-R02F20-001.
- Q: How is a step integrated and bounded? → A: per step h (finite, 0 < h ≤ 0.1) all forces are computed from the
  start-of-step swarm (steering through the grid, plus poles); the velocity becomes v + a · h, is then turned by the
  uniform field's exact rotation angle −q · B · h (so a uniform field never changes speed), and is capped at the speed
  limit (finite, > 0); the position becomes p + v · h; walled edges reflect the position back inside and flip that
  velocity component, wrapping edges take the position modulo the bounds. Agents with non-finite values are left as they
  are and take no part. Impact: FR-R02F20-002, 003; SC-R02F20-002, 003.
- Q: What are the magnetic field and the poles exactly? → A: a uniform field B (finite, |B| ≤ 100) acts as above; a pole at
  c of strength s (finite, |s| ≤ 1,000) and softening ε (finite, ε ≥ 1e-6) pulls a charge q (finite, |q| ≤ 100) with
  F = s · q · (c − p) / (|c − p|² + ε²)^{3/2} (positive s q attracts), whose length never exceeds
  |s · q| · 2 / (3√3 · ε²); at most 64 poles. Impact: FR-R02F20-003; SC-R02F20-003 (a lone charge with steering weights 0
  in a uniform field keeps its speed within 1e-9 relative over 1,000 steps and returns to its start within 1e-9 of the
  circle's radius after 2π / (|q B| h) steps when that is a whole number).
- Q: How is density rastered, and what is stored? → A: `DensityRaster` (width × height 1 … 1,024 each, at most 1,048,576
  cells, over a rectangle) keeps `Double` cells; each finite agent inside the rectangle spreads weight 1 bilinearly over
  the four cells around it (cell centres at (i + ½, j + ½)), weights past the grid's edge folded onto the edge cells, so the
  total equals the in-area count; `fieldGrid()` hands a one-channel `FieldGrid` to the existing passes. `Swarm` is
  `Codable` JSON schema 1 with sorted keys (agents, charges, bounds, edges, parameters, speed limit, field); a newer schema
  is refused. Reason codes (`SwarmError`): `r2-f20.agent-limit`, `r2-f20.bounds`, `r2-f20.step`, `r2-f20.parameter`,
  `r2-f20.field`, `r2-f20.raster-size`, `r2-f20.newer-schema`, `r2-f20.malformed`. Impact: FR-R02F20-004, 005, 006;
  SC-R02F20-004, 005.

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
2. **Given** agents at non-finite positions or far outside the swarm's bounds, **When** neighbours are found,
   **Then** the result still equals the exhaustive search (the grid has no bounds of its own).

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
  to its start within 1e-9 of its circle's radius after one whole-step period; pole forces never exceed
  |s · q| · 2 / (3√3 · ε²) over 1,000 seeded positions, including on the pole.
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
