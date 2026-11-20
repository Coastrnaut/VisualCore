# Feature Specification: R02-F21 — Diffusion, nutrient and viability field solver

**Feature Branch**: `221-diffusion-nutrient-and-viability-field-solver` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

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

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): `FieldGrid` (Float channels, row-major from the bottom row), `Heightfield` (Int64
quanta, 65,536 per unit, cell and grid totals ≤ 2⁴⁰, exact ledger), `RouteGraph` (≤ 1,048,576 nodes, undirected edges)
and `GridGraph` (cell index y · width + x) are in VisualCoreSimulation; no diffusion solver exists; the names
`NutrientField`, `NutrientError`, `NutrientSource`, `NutrientLedger`, `NutrientStepReport`, `ViabilityBand` and
`GrowthNetwork` are free (`GrowthRule`/`GrowthVerdict` in VisualCoreDiagnostics are unrelated).

- Q: What does the field store, and how big may it be? → A: `NutrientField` in VisualCoreSimulation, a walled grid of
  2 … 512 cells per side (at most 262,144 cells) with 1 … 4 channels of `Int64` quanta (65,536 per unit, as the
  heightfield); a cell and a channel's grid total hold at most 2⁴⁰ quanta. Walls are closed: nothing leaves except
  through sinks, decay and growth. Rationale: integer quanta make conservation exact and identical on every device.
  Impact: FR-R02F21-001, 002, 008; SC-R02F21-001.
- Q: How is diffusion kept stable and exact for any frame time? → A: a frame time t (finite, ≥ 0) above 0.25 s is cut to
  0.25 s and the rest reported as dropped; t is split into n = max(1, ⌈8 · t · Dmax⌉) equal sub-steps (Dmax the largest
  channel rate D, finite 0 … 1,000 cells²/s), at most 256, so r = D · t / n ≤ 1/8. In each sub-step every edge between
  4-neighbours carries ⌊r · (a − b)⌋ quanta from the fuller cell a to the emptier b, all computed from the sub-step's
  start. A cell sends at most 4 r ≤ ½ of its excess, so amounts never go negative, the largest value never rises and the
  smallest never falls, and every quantum moved is counted on both sides. If 256 sub-steps are not enough, the time is
  cut further and the rest reported as dropped. Impact: FR-R02F21-001, 006; SC-R02F21-001, 002.
- Q: How do sources, sinks and decay work? → A: up to 256 `NutrientSource`s, each a cell, a channel, a kind (source or
  sink) and a rate in units per second (finite, 0 < rate ≤ 1,000); each keeps a fractional carry so that over time it
  moves exactly ⌊rate · unit · elapsed⌋ quanta. A source never passes the cell or grid limit (the rest is reported as
  capped); a sink takes at most what the cell holds (the shortfall is reported). Decay per channel λ (finite, 0 … 100 per
  second) fades ⌊a · (1 − e^(−λ h))⌋ quanta per cell per sub-step. Order per sub-step: sources, sinks, diffusion, decay.
  The `NutrientLedger` keeps per channel added, removed, faded and eaten; every channel's total equals
  added − removed − faded − eaten exactly (`isBalanced`). Impact: FR-R02F21-002, 003; SC-R02F21-001, 003.
- Q: How are viability and growth defined? → A: a `ViabilityBand` per channel (low ≤ high, ramp ≥ 0, in units) gives 1
  inside [low, high], falling linearly to 0 at low − ramp and high + ramp (a hard step when ramp is 0); a cell's viability
  is the minimum over the channels that have a band (1 without bands). `GrowthNetwork` grows once per frame after the
  sub-steps: candidates are the 4-neighbours of network cells outside the network whose viability is at least the
  threshold (0 < threshold ≤ 1) and whose food channel holds at least the cost; they are ranked by food amount
  (most first), then cell index, and up to the per-frame limit (1 … 1,024) are taken in that order while the network
  stays within its size limit (1 … 65,536 cells); each new cell links to its lowest-index network neighbour and eats the
  cost from its own cell (counted as eaten). Growth runs once per `step(by:)` call with t > 0. Seeds are placed by the caller and count toward the limit; a seed is
  refused without a network, outside the grid, on a network cell or at the limit (`.growth(name)` or `.cellRange`). `graph()` gives
  a `RouteGraph` over all grid cells with an undirected edge of cost 1 per link, for the existing route solvers.
  Impact: FR-R02F21-004, 005; SC-R02F21-004, 005.
- Q: What does a step report, how is the field stored and how are errors named? → A: `step(by:)` returns a
  `NutrientStepReport` (sub-steps, simulated and dropped time, per-channel added, removed, faded and eaten in that frame,
  capped and short amounts, cells grown). `NutrientField` is `Codable` JSON schema 1 with sorted keys (size, channels,
  rates, decay, amounts, sources with carries, bands, network, ledger); `decode` re-checks every rule and that the ledger
  matches the totals; a newer schema is refused. `fieldGrid(channel:)` and `viabilityGrid()` hand `FieldGrid`s (units as
  Float) to the existing passes. Reason codes (`NutrientError`): `r2-f21.grid-size`, `r2-f21.channel`,
  `r2-f21.cell-range`, `r2-f21.amount-limit`, `r2-f21.parameter`, `r2-f21.time`, `r2-f21.source-limit`,
  `r2-f21.growth`, `r2-f21.newer-schema`, `r2-f21.malformed`. Impact: FR-R02F21-006, 007, 008; SC-R02F21-006.

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
2. **Given** one concentrated spot, **When** it diffuses, **Then** its peak never rises and its spread (the amount-weighted
   mean squared distance from the spot) rises at the rate 4 · D per unit time while it is away from the walls.

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
- **A very long frame time:** split into at most 256 stable sub-steps of a frame cut to 0.25 s; time beyond is reported
  as dropped, not run.
- **A source on a full cell or a total near its limit:** capped at the limit, the rest reported as capped, never
  overflowing.
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
- **SC-R02F21-002**: A single spot's peak never rises and its spread (amount-weighted mean squared distance from the
  spot, in cells², on a 64 × 64 grid over 60 frames while the spot stays away from the walls) rises every frame and its
  growth matches 4 · D · elapsed within 1 %; a long frame gives the same
  totals as the same time in short frames.
- **SC-R02F21-003**: With constant sources, sinks and decay, a field settles: its total changes by less than 0.1 % over
  the last tenth of a seeded run (a 16 × 16 grid with decay 1 per second over 600 frames of 1/60 s).
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
