# Requirements Quality Checklist: R02-G11-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 401 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the player's goal (every beacon located within the tolerance before the energy runs out) and the
  player's levers (pulse from a known open cell, claim a cell, mark candidates) stated plainly? [Clarity, Spec §US1;
  Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (W, H 5 … 16, 1 … 4 beacons, tolerance 0 … 2,
  energy 1 … 60, miss cost 1 … 3, at most 8 markers)? [Clarity, Spec §Clarifications Q1, Q3]
- [x] CHK003 Are a ray's revealed cells and travel distance and a beacon's echo (breadth-first path length, sorted and
  unlabelled) defined exactly, with the delay in whole ticks? [Measurability, Spec §FR-R02G1101-002, 003;
  Clarifications Q2]
- [x] CHK004 Is the truth metric (each located beacon's localization error and their total) required after every action
  and excluded from deciding? [Measurability, Spec §FR-R02G1101-014; Clarifications Q4]
- [x] CHK005 Is the order of win and energy after an action fixed? [Consistency, Spec §FR-R02G1101-005;
  Clarifications Q4]
- [x] CHK006 Is it stated which beacon a claim locates when several are within the tolerance (nearest, then lowest row,
  then lowest column)? [Clarity, Spec §Clarifications Q3]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (energy and revealed cells; from failed back to playing; a won level is final) stated? [Completeness, Spec
  §FR-R02G1101-007; Clarifications Q4, Q5]

## Empty and error states

- [x] CHK008 Are refusals named for a cell outside the chamber, a pulse from a cell not known open, a claim on a known
  wall, a ninth marker, a claim near only located beacons, wrong stage and staleness, and is the energy failure named
  with its action? [Coverage, Spec §Edge Cases; Clarifications Q3, Q4, Q5]
- [x] CHK009 Are malformed levels excluded (sizes or values out of range, a beacon on a wall, on the entry or
  unreachable, duplicate cells)? [Edge Case, Spec §Clarifications Q5; data-model]
- [x] CHK010 Are the boundaries stated (a claim at the tolerance counts, one cell further misses; a win with any energy
  left wins; a pulse that spends the last energy fails)? [Edge Case, Spec §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Is it required that every cell, echo, marker and measure is available in words and numbers? [Coverage, Spec
  §FR-R02G1101-013]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes, the independent recomputation and the boundary cases (tolerance, one action either
  side of the energy budget) stated? [Measurability, Spec §SC-R02G1101-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]
