# Feature Specification: R02-F17 — Fluid-heightfield transport and conservation

**Feature Branch**: `217-fluid-heightfield-transport-and-conservation` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Clarified

**Ledger gate**: R02-F17 (migration ledger, shared round feature) · ID namespace FR-R02F17-###, SC-R02F17-###, T-R02F17-###

**Input**: User description: the archived R02-F17 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"conservative flows; explicit bounded steps; dye mass; erosion; stable clamps", with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/217-fluid-heightfield-transport-and-conservation`; FR-R02F17-###, SC-R02F17-###,
  T-R02F17-###.
- **Section 13 disposition: extend.** The framework has `FieldGrid` (a grid of float channels with storage rounding) and
  the GPU field passes (`FieldPass`, `PingPongTarget`) that draw and evolve such grids; Fluid Art Playground has its own
  incompressible, artistic `FluidSolver`. Nothing models water standing on terrain, dye carried by that water or terrain
  worn away by it, and nothing proves that water, dye or rock is conserved. This feature adds that model beside the
  existing grid, which stays unchanged, and hands its heights to the existing grid and passes for drawing; Fluid Art
  Playground is untouched.
- **Who the users are:** the player of Colorfall Canyons or Erosion Painter, who pours water and coloured dye on a
  landscape and watches it run, pool, mix and carve valleys, and who must never see water or colour appear from nothing,
  vanish, or explode; the engineer, who needs every step bounded, exactly conserving and identical on every device.
- **Prerequisites:** R02-F03 (numerical foundations) and R02-F05 (budgets) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** none in this slice; the consumers measure frame cost on D1–D3 in the
  device campaign. **Owner-only items:** none.

## Clarifications

### Session 2026-11-19

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-19): `FieldGrid` (VisualCoreSimulation) holds `Float` channels with a public `values`
array and `StoragePrecision` rounding; `FieldPass` and `PingPongTarget` are in VisualCoreRendering; Fluid Art
Playground's `FluidSolver` is its own; no erosion or sediment code exists; the names `Heightfield`,
`HeightfieldParameters`, `HeightfieldLedger`, `HeightfieldError` and `HeightfieldEdges` are free.

- Q: Where does the model live and how are amounts represented? → A: in VisualCoreSimulation beside `FieldGrid`, pure and
  host-tested; drawing hands a `FieldGrid` to the existing passes (VisualCoreRendering unchanged). Every amount (terrain,
  water, sediment, each of 0 … 4 dye channels) is an `Int64` count of quanta, 1 quantum = 1/65,536 height unit (cell
  size 1), 0 … 2⁴⁰ per cell; all transfers move whole quanta between cells, so every total is conserved exactly and
  identically on every device. Grids are 4 … 1,024 on a side, at most 262,144 cells. Rationale: floating-point sums
  cannot conserve exactly; integers can. Impact: FR-R02F17-001, 002, 004, 005; SC-R02F17-001.
- Q: What is the flow law? → A: the virtual-pipe shallow-water model (O'Brien and Hodgins 1995; Mei, Decaudin and Hu
  2007): each cell keeps four outflow fluxes (`Double`, per edge); per sub-step Δt each becomes
  max(0, damping · f + Δt · A · g · Δs / l) with Δs the drop of surface (terrain + water, in height units) to that
  neighbour, 0 towards a wall; the wanted outflow f · Δt is turned into quanta (floor) and, if the cell's wanted total
  exceeds its water, every direction is scaled by water / total (floor); all cells send from their water at the start of
  the sub-step, then all receive. Open edges send to the outside and count it as drained. Defaults g = 9.81, A = 1,
  l = 1, damping 0.995 (implementation 2026-11-19: with 0.98 a bowl was still 0.30 units uneven after 4,000 sub-steps
  because heavy damping slows levelling; 0.995 levels it to 0.003 — the requirement, not the default, is fixed).
  Impact: FR-R02F17-002; SC-R02F17-002.
- Q: How are steps bounded and values clamped? → A: a frame time Δ (finite, ≥ 0; 0 is a no-op; negative or not finite is
  refused) is split into n = ⌈Δ / h⌉ sub-steps of Δ / n, where h = min(maxSubstep (default 1/120 s),
  0.25 · l / √(g · max(depth, 1e-6))) is the stability limit for the deepest water; n is at most 64, and past it 64
  sub-steps of h run, the rest of Δ is dropped and the step report says so. Fluxes are clamped to 0 … 1,000,000 and stay
  finite; amounts never leave 0 … 2⁴⁰ (an add beyond is refused). Impact: FR-R02F17-003; SC-R02F17-003.
- Q: How are dye and sediment carried, and how does erosion work? → A: dye and sediment leave a cell in the same
  proportion as its water, floor(amount · sent / water) per direction (full-width integer arithmetic), the rounding
  remainder staying in the cell — unless the cell sends all its water, when the remainder goes along its largest
  outflow, so a dry cell never keeps dye or sediment (found in implementation, 2026-11-19). Erosion (off unless enabled) per sub-step compares the sediment with a capacity
  C = K_c · |v| · max(slope, 0.01) · depth, |v| from the cell's net flux over its depth: below C, rock moves to sediment
  at K_s · (C − sediment) · Δt, above it sediment settles back at K_d · (sediment − C) · Δt, each turned into whole
  quanta and limited by what is present, so rock never goes below the floor 0. Defaults K_c 0.05, K_s 0.3, K_d 0.3.
  Impact: FR-R02F17-004, 005; SC-R02F17-001, 004.
- Q: What is stored, and what are the failure codes? → A: `Heightfield` is `Codable` JSON schema 1 with sorted keys (size,
  edges, parameters, every quantity, fluxes and the ledger); it reopens and continues bit-identically; schema 1 is the
  first stored form (a later one adds a `MigrationChain` step in the consumer); a newer schema is refused. Reason codes
  (`HeightfieldError`): `r2-f17.grid-size`, `r2-f17.cell-range`, `r2-f17.amount-limit`, `r2-f17.invalid-time`,
  `r2-f17.invalid-parameter`, `r2-f17.dye-channel`, `r2-f17.newer-schema`, `r2-f17.malformed`; a step report (sub-steps
  run, time dropped, clamps) is returned, not thrown; the experience adds its id, seed and tick. Impact: FR-R02F17-007,
  009; SC-R02F17-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Water flows and settles without gaining or losing a drop (Priority: P1) 🎯

The engineer places terrain and water on a grid and steps it. Water runs downhill, pools in hollows and settles flat;
the total water, plus what left through open edges and what was added or removed on purpose, never changes.

**Why this priority**: both consumers are built on it.

**Independent Test**: on seeded terrains, the water ledger balances exactly after every step; a closed basin settles to
a flat surface; no cell ever holds negative water.

**Acceptance Scenarios**:

1. **Given** a closed grid, **When** stepped many times, **Then** total water is exactly unchanged.
2. **Given** open edges, **When** water reaches them, **Then** what leaves is counted and the ledger still balances.
3. **Given** a hollow, **When** left to settle, **Then** the water surface becomes flat within a stated tolerance.

### User Story 2 - Steps stay bounded and stable (Priority: P1)

Whatever time the frame asks for, the step is split into stable sub-steps within a stated limit, values are clamped to
stated ranges, and nothing becomes infinite or undefined.

**Independent Test**: extreme inputs (tall columns of water, steep cliffs, long frame times) stay finite and bounded, with
a reported clamp when the limit is reached.

### User Story 3 - Dye is carried by the water (Priority: P2)

Coloured dye placed in the water moves with it and mixes; the total amount of each dye is exactly conserved.

**Independent Test**: on seeded runs, every dye's total is exactly unchanged (apart from what drains), and dye goes only
where water flows.

### User Story 4 - Water carves the terrain (Priority: P2)

Fast water picks up rock as sediment, carries it and drops it where it slows; rock plus sediment is exactly conserved.

**Independent Test**: on seeded runs, terrain plus suspended sediment is exactly unchanged; a slope erodes at its top and
deposits at its foot.

### User Story 5 - Save and reopen a landscape (Priority: P2)

The full state is saved with a schema version and reopened later to continue identically; newer and damaged forms are
refused.

**Independent Test**: a saved state round-trips byte for byte and continues to the same result as an unsaved run.

### Edge Cases

- **A cell with no water:** sends nothing and receives normally.
- **More outflow asked than water present:** outflow is scaled down so the cell reaches zero, never below.
- **A frame time of zero, negative or not finite:** refused or a no-op, with a named reason.
- **A sub-step limit reached:** the remaining time is dropped and the clamp is reported.
- **Erosion that would cut below the floor:** limited at the floor.
- **Grids too small or too large:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F17-001**: A heightfield MUST hold terrain, water, sediment and dye per cell on a rectangular grid with walled or
  open edges.
- **FR-R02F17-002**: Stepping MUST move water between neighbouring cells by a conservative flow law so that total water
  plus drained minus added is exactly constant, and no cell holds negative water.
- **FR-R02F17-003**: A frame step MUST split its time into stable sub-steps within a stated limit, clamp values to stated
  ranges and report when a clamp applied.
- **FR-R02F17-004**: Dye MUST move with the water and each dye's total MUST be exactly conserved apart from what drains.
- **FR-R02F17-005**: Erosion MUST exchange terrain and sediment and carry sediment with the water so that terrain plus
  sediment is exactly conserved apart from what drains, never cutting below the floor.
- **FR-R02F17-006**: Terrain, water and dye MUST change only by flow, erosion or explicit ledgered add and remove
  operations; sediment changes only by erosion and flow.
- **FR-R02F17-007**: The state MUST have a versioned stored form that continues identically; newer and damaged forms MUST
  be refused.
- **FR-R02F17-008**: The heights MUST be handed to the existing field grid for drawing without changing it.
- **FR-R02F17-009**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F17-010**: Existing experiences and their tests MUST be unchanged; every new public name carries documentation;
  the API baseline and the reference regression are updated.

### Key Entities

- **Heightfield**: grid size, edge kind, per-cell terrain, water, sediment, dye, and per-edge flow.
- **Flow parameters**: gravity, pipe area, damping, sub-step limit, erosion rates.
- **Ledger**: added, removed and drained totals per quantity.
- **Stored state**: versioned form of all of the above.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F17-001**: On 50 seeded terrains stepped 500 times each, the water, dye and rock ledgers balance exactly after
  every step, and no cell holds a negative amount.
- **SC-R02F17-002**: A 16 × 16 closed bowl filled in one quarter settles so that its highest and lowest wet water
  surfaces differ by at most 0.05 height units within 2,000 sub-steps (sizes chosen so the test stays short; owner rule
  of 2026-11-13).
- **SC-R02F17-003**: In 100 seeded extreme cases (water columns up to the per-cell limit, cliffs of the full terrain
  range, frame times up to 10 s), every amount stays within 0 … 2⁴⁰, every flux finite within its clamp, the ledger
  balances, and a frame step longer than 64 stable sub-steps reports the dropped time.
- **SC-R02F17-004**: On a 16 × 8 slope with erosion enabled and water poured at its top for 1,000 sub-steps, the upper
  third's terrain decreases, the lower third's terrain increases, and terrain plus sediment balances exactly.
- **SC-R02F17-005**: A saved state round-trips byte for byte and continues to the bit-identical result; newer and damaged
  forms are refused; two runs from one state are identical.
- **SC-R02F17-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- The model is a game-grade shallow-water approximation, not a physical simulation; conservation is exact, motion is
  plausible.
- The consumer games do not exist yet; this slice ships the library and its proofs.
- No user interface: brushes, colours, layout and accessibility belong to the consuming experiences.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Conservative flows | FR-R02F17-001, 002, 006 |
| Explicit bounded steps | FR-R02F17-003 |
| Dye mass | FR-R02F17-004 |
| Erosion | FR-R02F17-005 |
| Stable clamps | FR-R02F17-003 |
| Schema migration | FR-R02F17-007 |
| Field handoff | FR-R02F17-008 |
| Observability | FR-R02F17-009 |
| No Stage One breakage | FR-R02F17-010 |

## Negative Requirements / Excluded scope

- No new module, no change to `FieldGrid`, the field passes or Fluid Art Playground, no three-dimensional fluid, no
  physical accuracy claim, no device run before ImplementationLock-100, no analytics.
