# Requirements Quality Checklist: R02-G13-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 421 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23, following feature 411's checklist; every item
passed at first reading.

## Player impact

- [x] CHK001 Are the player's goal (every symbol link present and the stars coherent for the hold within the window)
  and the player's levers (link, unlink, nudge a phase, listen) stated plainly? [Clarity, Spec §US1; Clarifications Q1,
  Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (3 … 8 stars, rates and phases 0 … 11, 0 … 6
  fixed links, 2 … 10 symbol pairs, K 1 … 8, degree limit 2 … 4, link limit up to 16, snap limit 2 … 5, threshold
  1 … n², hold 2 … 12, window up to 48, budget 1 … 40)? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Are the tick (12-step clock, coupling table t(0 … 6) = 0, 1, 2, 2, 2, 1, 0, step ⌊K · P / 4⌋ clamped to
  −1 … 1, simultaneous update), the snap (gap above σ) and the exact order parameter A + B√3 with its exact comparison
  defined? [Measurability, Spec §FR-R02G1301-002, 003; Clarifications Q2, Q4]
- [x] CHK004 Is the truth metric (a listen report of the current state and the graph-isomorphism label with its match)
  required after every action and excluded from deciding on its own? [Measurability, Spec §FR-R02G1301-014;
  Clarifications Q4]
- [x] CHK005 Is the order of a listen's decisions (missing pairs, then per tick: move, snap, disconnection, coherence,
  hold) and of the budget after an action fixed? [Consistency, Spec §FR-R02G1301-005; Clarifications Q4]
- [x] CHK006 Is it stated which pair, tick and link a failing listen names (the lowest-index missing pair; the tick and
  lowest-index link snapped in it; the longest coherent run)? [Clarity, Spec §Clarifications Q4]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (links, starting phases, actions spent; from failed back to playing; a won level is final) stated? [Completeness,
  Spec §FR-R02G1301-007; Clarifications Q4, Q5]

## Empty and error states

- [x] CHK008 Are refusals named for an unknown star, a self link, an existing link, a degree or link limit, a missing or
  fixed link removed, a nudge other than ±1, wrong stage and staleness, and are the failures (missing, disconnected,
  incoherent, budget) named? [Coverage, Spec §Edge Cases; Clarifications Q3, Q4, Q5]
- [x] CHK009 Are malformed levels excluded (values out of range, a self or repeated pair, a disconnected symbol, fixed
  links over a limit)? [Edge Case, Spec §Clarifications Q5; data-model]
- [x] CHK010 Are the boundaries stated (coherence at θ counts, one below does not; a gap of σ holds, σ + 1 snaps; the
  hold on the last tick wins; a listen on the last action can win)? [Edge Case, Spec §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Is it required that every star, link and measure is available in words and numbers? [Coverage, Spec
  §FR-R02G1301-013]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes, the independent recomputation and the boundary cases (threshold, snap limit, hold,
  one action either side of the budget) stated? [Measurability, Spec §SC-R02G1301-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]
