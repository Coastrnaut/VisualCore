# Requirements Quality Checklist: R02-G14-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 431 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 421's checklist; every item
passed at first reading.

## Player impact

- [x] CHK001 Are the player's goal (every meshing pair aligned, every required key frame's target covered within the
  stray allowance, no forbidden cell ever shadowed) and the player's levers (turn the handle, re-seat a gear, step the
  lamp, run) stated plainly? [Clarity, Spec §US1; Clarifications Q2, Q4]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (2 … 5 gears, 6 … 20 teeth, whole-tooth phases,
  depth 1 … 3, slot offsets within ±8, wall 8 … 24 × 6 … 16, lamp heights 2 … 5, 2 … 6 key frames, 0 … 12 forbidden
  cells, allowance 0 … 4, budget 1 … 40)? [Clarity, Spec §Clarifications Q1, Q3, Q4, Q5]
- [x] CHK003 Are the handle turn (directions alternating with distance from the driver), the re-seat, the mesh alignment
  (phaseₚ + phase_c) mod gcd = a with gcd ≥ 2 and its cyclic error, and the cast (slot tables, shift by height · depth,
  cells outside dropped) defined? [Measurability, Spec §FR-R02G1401-002, 003; Clarifications Q2, Q3]
- [x] CHK004 Is the truth metric (alignment errors and per-key-frame covered, missing, stray and forbidden counts)
  required after every action and excluded from deciding on its own? [Measurability, Spec §FR-R02G1401-014;
  Clarifications Q5]
- [x] CHK005 Is the order of a run's decisions (jam in pair order, then key frames in order with forbidden before missing
  before stray) and of the budget after an action fixed? [Consistency, Spec §FR-R02G1401-005; Clarifications Q4, Q5]
- [x] CHK006 Is it stated which pair, key frame, cell or count a failing run names (the first misaligned pair by child
  index; the key frame and lowest-numbered forbidden cell; the key frame and the missing or stray count)? [Clarity,
  Spec §Clarifications Q4]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (phases, lamp height, actions spent; from failed back to playing; a won level is final) stated? [Completeness, Spec
  §FR-R02G1401-007; Clarifications Q5]

## Empty and error states

- [x] CHK008 Are refusals named for an unknown gear, re-seating the driver, a step other than ±1, a lamp step out of
  range, wrong stage and staleness, and are the failures (jammed, forbidden, missing, stray, budget) named? [Coverage,
  Spec §Edge Cases; Clarifications Q4, Q5]
- [x] CHK009 Are malformed levels excluded (values out of range, a gear without a lower-index parent, a pair with
  divisor 1, a blade pattern all solid or all open, an empty slot list, key-frame turns not increasing, no required key
  frame, forbidden cells inside a target)? [Edge Case, Spec §Clarifications Q1, Q3, Q4; data-model]
- [x] CHK010 Are the boundaries stated (stray cells at the allowance match, one more does not; aligned holds, one tooth
  off jams; a forbidden cell at a key frame that is not required still fails; a run on the last action can win)? [Edge
  Case, Spec §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Is it required that every gear, blade and measure is available in words and numbers? [Coverage, Spec
  §FR-R02G1401-013]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes, the independent recomputation and the boundary cases (allowance, alignment, first and
  last key frame, one action either side of the budget) stated? [Measurability, Spec §SC-R02G1401-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
