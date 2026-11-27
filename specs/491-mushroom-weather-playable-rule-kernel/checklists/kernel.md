# Requirements Quality Checklist: R02-G20-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 491 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 481's checklist; every item
but CHK010 passed at first reading.

## Player impact

- [x] CHK001 Are the player's goal (every colony ends in its humidity band for the last K cycles, no sensitive colony
  dries out, no cell turns to mold) and the player's levers (placing, moving and removing spore pods, opening and
  closing vents, shifting the moonlight, then running the weather) stated plainly? [Clarity, Spec §US1; Clarifications
  Q3, Q4, Q5]

## Deterministic invariants

- [x] CHK002 Is every rule decided on integers with stated bounds (6 … 12 rows by 6 … 14 columns, humidity 0 … 10000,
  mold bound 1000 … 10000, diffusion 1 … 12 over 64, rates 0 … 200, moonlight 0 … 3, release 1 … 40 and 80, growth
  threshold 100 … 200000, run 20 … 200 cycles, required cycles 5 … T, pods 1 … 6, vents 0 … 6, colonies 1 … 6, budget
  1 … 12)? [Clarity, Spec §Clarifications Q1 … Q5]
- [x] CHK003 Is the cycle law defined so two readers compute the same field (three synchronous steps, the pairwise flow
  with truncation toward zero, the evaporation formula and its cap, release by grown state, the order of the steps)?
  [Measurability, Spec §FR-R02G2001-003; Clarifications Q2]
- [x] CHK004 Is the ledger defined so it balances exactly for every cycle, and is it stated why diffusion can neither
  create water nor drive a cell negative? [Clarity, Spec §FR-R02G2001-014; Clarifications Q2]
- [x] CHK005 Is the truth metric (ledger by cycle, colony runs, growth cycles, first failure, predicted outcome)
  required after every action and excluded from deciding on its own? [Measurability, Spec §FR-R02G2001-014;
  Clarifications Q5]
- [x] CHK006 Is the judge's order fixed (per cycle: `dried` by lowest sensitive colony, then `mold` by first cell in
  row-major order; after the run: `unstable`, else won) and is it stated what each failure names? [Consistency, Spec
  §Clarifications Q4]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (the arrangement and actions spent; from failed back to playing before the run; a won level is final) stated?
  [Completeness, Spec §FR-R02G2001-007; Clarifications Q5]

## Empty and error states

- [x] CHK008 Are refusals named for an action out of range, unchanged or on a forbidden cell, a removal of an empty
  slot, no action left, wrong stage and staleness, and are the failures (dried, mold, unstable) named? [Coverage, Spec
  §Edge Cases; Clarifications Q4, Q5]
- [x] CHK009 Are a colony on a band edge, a cell at the mold bound, a colony at its survival floor, a growth integral at
  its threshold, equal neighbours and evaporation larger than a cell holds addressed? [Edge Case, Spec §Edge Cases;
  Clarifications Q2 … Q4]
- [x] CHK010 Are malformed levels excluded (values out of range, required cycles above the run length, a colony, vent or
  starting pod off the floor, two colonies or pods on one cell, a pod on a colony, no colony, a sensitive colony below
  its floor at the start, a cell above the mold bound at the start, a starting arrangement that wins)? [Edge Case, Spec
  §FR-R02G2001-001; data-model] — failed at first reading: the starting floor and mold checks, shared cells and K ≤ T
  were only in the clarifications and data model; FR-001 now refuses them.
- [x] CHK011 Are the boundaries stated (a band edge is inside; the mold bound itself is not mold; the survival floor
  itself is alive; a spent budget still allows the run)? [Edge Case, Spec §Edge Cases; SC-R02G2001-004]
- [x] CHK012 Is it stated why the run costs no action and why the predicted outcome is reported before it (the
  arrangement determines everything; the run is the commitment)? [Consistency, Plan research R8]

## Accessibility (colour independence)

- [x] CHK013 Is it required that every cell, colony, pod, vent and measure is available in words and numbers?
  [Coverage, Spec §FR-R02G2001-013; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK015 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK016 Are host-test sizes, the independent recomputation (a second implementation of the cycle law) and the
  boundary cases (band edges, mold bound, survival floor, growth threshold, a final run one cycle short) stated?
  [Measurability, Spec §SC-R02G2001-001 … 004; Plan]

## Future D1/D2/D3 evidence

- [x] CHK017 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
