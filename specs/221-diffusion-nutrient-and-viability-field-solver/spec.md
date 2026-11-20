# Feature Specification: R02-F21 — Diffusion, nutrient and viability field solver

**Feature Branch**: `221-diffusion-nutrient-and-viability-field-solver` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

**Ledger gate**: R02-F21 (migration ledger, shared round feature) · ID namespace FR-R02F21-###, SC-R02F21-###, T-R02F21-###

**Input**: User description: the archived R02-F21 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"explicit stable diffusion; local sources/sinks; bounded graph growth; conservation reports", with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/221-diffusion-nutrient-and-viability-field-solver`; FR-R02F21-###, SC-R02F21-###,
  T-R02F21-###.
- **Section 13 disposition: new (with reuse).** The framework has `FieldGrid` (Float channels for GPU field passes and
  their CPU references), the integer-quanta conservation pattern of the heightfield transport (R02-F17) and the route
  graphs and solvers of R02-F16 (`RouteGraph`, `GridGraph`, `RouteSearch`). It has no diffusion solver with sources,
  sinks and an exact conservation account, no viability measure and no bounded growth of a network over a field. This
  feature adds them beside the existing types, which stay unchanged; the grown network is handed to the existing route
  solvers as a `RouteGraph`, and fields are handed to the existing passes as a `FieldGrid`.
- **Who the users are:** the player of Mushroom Weather, Binary Gardens or Mycelium Architect, who watches nutrients
  spread from springs, fade where they are eaten, and a network of threads creep toward the rich ground — the same way
  every time a scene is replayed, and never exploding or flickering; the engineer, who needs every step bounded and
  stable, every quantity accounted for exactly, and the same result on every device.
- **Prerequisites:** R02-F03 (numerical foundations) and R02-F16 (route graphs) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** the frame cost of a large field with growth on D1–D3, recorded in the
  device campaign. **Owner-only items:** none.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Diffuse without blowing up (Priority: P1) 🎯

The engineer lets several nutrient channels spread over a grid with any frame time; the solver stays stable (never
negative, never oscillating, never growing), the spread looks smooth, and the total of each channel is kept exactly.

**Why this priority**: every consumer depends on it.

**Independent Test**: on seeded grids with any frame time, totals stay exactly equal to their account, no cell goes
negative, and a peak only flattens.

**Acceptance Scenarios**:

1. **Given** a seeded field, **When** it diffuses with frame times from tiny to very long, **Then** each channel's total
   is unchanged to the quantum and no cell becomes negative.
2. **Given** one concentrated spot, **When** it diffuses, **Then** its peak only falls and its spread grows the way
   diffusion should.

### User Story 2 - Sources, sinks and decay (Priority: P1)

The engineer places springs that add nutrient, drains that remove it and a fading rate per channel; the field settles
toward a steady state and every amount added, removed or faded is reported.

**Independent Test**: after a seeded run with sources, sinks and decay, the field total equals added minus removed minus
faded, exactly.

### User Story 3 - Viability (Priority: P2)

The engineer asks where life can thrive: each cell gets a viability between 0 and 1 from how well its channels sit
inside chosen bands, ready to draw or to steer growth.

**Independent Test**: a cell inside every band is fully viable, outside any band not viable, and in between it ramps.

### User Story 4 - Bounded network growth (Priority: P2)

From seed cells a network grows step by step into viable neighbouring cells, eating nutrient as it goes, never past its
size limit, the same way every time; the grown network can be handed to the existing route solvers.

**Independent Test**: two seeded runs grow the same network; it never exceeds its limit, only grows into viable cells
next to itself, and every eaten amount appears in the account.

### User Story 5 - Save and reopen (Priority: P2)

A field with its sources, sinks, network and account is saved with a schema version and reopened to continue
identically; newer and damaged forms are refused.

**Independent Test**: a saved field round-trips byte for byte and continues bit-identically.

### Edge Cases

- **An empty or all-zero field:** steps without error and stays zero.
- **A very long frame time:** split into stable sub-steps up to a cap; time beyond the cap is reported as dropped, not run.
- **A source on a full cell or a total near its limit:** refused or capped and reported, never overflowing.
- **A sink asking more than a cell holds:** removes only what is there, and the report says so.
- **Growth with nowhere viable to go:** stops quietly; the report shows zero growth.
- **Too large a grid, too many sources or channels, or invalid rates:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F21-001**: A diffusion solver MUST spread up to several channels over a grid stably for any frame time, never
  producing negative amounts or growth of a peak.
- **FR-R02F21-002**: Each channel's total MUST be kept exactly, with every amount added by sources, removed by sinks,
  faded by decay and eaten by growth counted in a conservation account.
- **FR-R02F21-003**: Sources, sinks and per-channel decay MUST act locally and boundedly at their cells.
- **FR-R02F21-004**: A viability measure MUST give each cell a value between 0 and 1 from per-channel bands.
- **FR-R02F21-005**: A network MUST grow deterministically from seeds into viable neighbouring cells within a size limit
  and per-step limit, eating nutrient, and MUST be available to the existing route solvers.
- **FR-R02F21-006**: Each step MUST produce a report (sub-steps, dropped time, account changes, growth) for observability.
- **FR-R02F21-007**: The field MUST have a versioned stored form that continues identically; newer and damaged forms MUST
  be refused.
- **FR-R02F21-008**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F21-009**: Existing types (`FieldGrid`, the heightfield, the route graphs and solvers) and their tests MUST be
  unchanged; every new public name carries documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Nutrient field**: grid size, channels, amounts per cell and channel, diffusion and decay rates.
- **Source / sink**: cell, channel, rate.
- **Viability bands**: per channel, the low and high limits and the ramp.
- **Growth network**: grown cells, links between them, size and per-step limits, appetite.
- **Conservation account and step report**: per channel added, removed, faded, eaten; sub-steps; dropped time; growth.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F21-001**: For 20 seeded fields over 300 frames of seeded lengths, every channel's total equals its account
  after every frame, exactly, and no cell is ever negative.
- **SC-R02F21-002**: A single spot's peak never rises and its spread grows monotonically; a long frame gives the same
  totals as the same time in short frames.
- **SC-R02F21-003**: With constant sources, sinks and decay, a field settles: its total changes by less than 0.1 % over
  the last tenth of a seeded run.
- **SC-R02F21-004**: Viability is 1 inside every band, 0 outside any band and strictly between in a ramp, for 1,000
  seeded cells.
- **SC-R02F21-005**: Two seeded growth runs are identical; the network never exceeds its limits, every new cell is
  viable and next to the network, and the grown network routes through the existing solver.
- **SC-R02F21-006**: Fields round-trip byte for byte and continue bit-identically for 200 frames; newer and damaged forms
  are refused.
- **SC-R02F21-007**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- The field is two-dimensional on a square grid; consumers draw it through `FieldGrid` and the existing passes.
- The consumer games do not exist yet; this slice ships the library and its proofs.
- No user interface: controls, colours, layout and accessibility belong to the consuming experiences.
- The solver runs on the CPU; a GPU variant is out of scope.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Explicit stable diffusion | FR-R02F21-001 |
| Local sources/sinks | FR-R02F21-003 |
| Bounded graph growth | FR-R02F21-005 |
| Conservation reports | FR-R02F21-002, 006 |
| Viability | FR-R02F21-004 |
| Schema migration | FR-R02F21-007 |
| Observability | FR-R02F21-006, 008 |
| No Stage One breakage | FR-R02F21-009 |

## Negative Requirements / Excluded scope

- No new module, no change to `FieldGrid`, the heightfield or the route solvers, no GPU solver, no 3D field, no
  biological accuracy claim, no device run before ImplementationLock-100, no analytics.
