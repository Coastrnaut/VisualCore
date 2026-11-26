# Requirements Quality Checklist: R02-G19-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 481 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 471's checklist; every item
but CHK010 passed at first reading.

## Player impact

- [x] CHK001 Are the player's goal (the lit trails cover enough of the stencil as one pattern, no swimmer escapes, the
  swarm stays coherent) and the player's levers (placing, changing and removing up to three wells, then playing the
  swim) stated plainly? [Clarity, Spec §US1; Clarifications Q3, Q4, Q5]

## Deterministic invariants

- [x] CHK002 Is every rule decided on integers with stated bounds (24 × 24 cells of 256 units, enclosure radius 6 … 11,
  swimmers 4 … 16, swim 120 … 480 ticks, radii and weights, a_max 2 … 16, v_max 8 … 48, stencil 4 … 120, threshold
  1 … 64, coverage 500 … 1000, strengths 1 … 4, budget 1 … 12)? [Clarity, Spec §Clarifications Q1 … Q5]
- [x] CHK003 Is the tick law defined so two readers compute the same swim (synchronous step, neighbour and separation
  radii as squared distances, the coincident-swimmer rule, the means and divisors, the curl formula, truncation toward
  zero, the clamps and their order, semi-implicit Euler)? [Measurability, Spec §FR-R02G1901-003; Clarifications Q2]
- [x] CHK004 Are trail density (ticks 1 … T), the lit threshold (inclusive), the coverage unit and its rounding, and
  connectedness (exactly one four-neighbour group) defined without ambiguity at their boundaries? [Clarity, Spec
  §FR-R02G1901-004; Clarifications Q3]
- [x] CHK005 Is the truth metric (density per cell, lit cells, coverage, groups, smallest coherence and its tick, first
  failure, predicted outcome) required after every action and excluded from deciding on its own? [Measurability, Spec
  §FR-R02G1901-014; Clarifications Q5]
- [x] CHK006 Is the judge's order fixed (per tick: `exit` by lowest swimmer, then `coherence`; after the swim:
  `coverage`, then `connectedness`) and is it stated what each failure names? [Consistency, Spec §Clarifications Q4]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (wells and actions spent; from failed back to playing before the play; a won level is final) stated? [Completeness,
  Spec §FR-R02G1901-007; Clarifications Q5]

## Empty and error states

- [x] CHK008 Are refusals named for a placement out of range, unchanged, on an occupied or outside cell, a removal of
  an empty slot, no action left, wrong stage and staleness, and are the failures (exit, coherence, coverage,
  connectedness) named? [Coverage, Spec §Edge Cases; Clarifications Q4, Q5]
- [x] CHK009 Are a swimmer on the rim (inside), coincident swimmers, a density exactly at the threshold, coverage
  exactly at the requirement and a swim with no well addressed? [Edge Case, Spec §Edge Cases; Clarifications Q1 … Q3]
- [x] CHK010 Are malformed levels excluded (values out of range, a separation radius above the neighbour radius, a
  swimmer outside, an incoherent start, a stencil cell outside or repeated, an empty stencil, a starting well outside or
  on a shared cell, starting wells that already win)? [Edge Case, Spec §FR-R02G1901-001; data-model] — failed at first
  reading: the incoherent start, the separation radius, repeated stencil cells and the starting wells' cells were only
  in the clarifications and data model; FR-001 now refuses them.
- [x] CHK011 Are the boundaries stated (the rim is inside; a density at the threshold is lit; coverage at the
  requirement is met; a spent budget still allows the play)? [Edge Case, Spec §Edge Cases; SC-R02G1901-004]
- [x] CHK012 Is it stated why the play costs no action and why the predicted outcome is reported before it (the wells
  determine everything; the play is the commitment)? [Consistency, Plan research R8]

## Accessibility (colour independence)

- [x] CHK013 Is it required that every well, cell, swimmer and measure is available in words and numbers? [Coverage,
  Spec §FR-R02G1901-013; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK015 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK016 Are host-test sizes, the independent recomputation (a second implementation of the tick law) and the
  boundary cases (rim, threshold, coverage, coherence) stated? [Measurability, Spec §SC-R02G1901-001 … 004; Plan]

## Future D1/D2/D3 evidence

- [x] CHK017 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
