# Requirements Quality Checklist: R02-G12-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 411 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23, following feature 401's checklist; failures
were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the player's goal (the start joined to the goal by bridges in every step of the crossing window) and
  the player's levers (turn an unlocked string's peg, pluck to hear, test the crossing) stated plainly? [Clarity, Spec
  §US1; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (2 … 8 islands, 1 … 12 strings, length 1 … 6,
  peg 1 … 12, 1 … 4 steps of 1 … 3 tones, frequency 1 … 72, strength 1 … 3, threshold 1 … 12, budget 1 … 60)?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Are resonance (n = F · L / p, a whole number in 1 … 5), the swing table (4 sin²(nπk/6) ∈ {0, 1, 3, 4}) and
  the averaged swing E(k) at the five samples defined exactly, and is a bridge defined by every sample reaching the
  threshold? [Measurability, Spec §FR-R02G1201-002, 003; Clarifications Q2]
- [x] CHK004 Is the truth metric (every swing, bridge and reachable set per step) required after every action and
  excluded from deciding on its own? [Measurability, Spec §FR-R02G1201-014; Clarifications Q4]
- [x] CHK005 Is the order of a test, a failure and the budget after an action fixed? [Consistency, Spec
  §FR-R02G1201-005; Clarifications Q4]
- [x] CHK006 Is it stated which step and which string a failing test names (the first step whose path is missing; the
  lowest-index non-bridge string across the start's reach, none when no string crosses)? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (pegs and actions spent; from failed back to playing; a won level is final) stated? [Completeness, Spec
  §FR-R02G1201-007; Clarifications Q4, Q5]

## Empty and error states

- [x] CHK008 Are refusals named for an unknown string, a peg out of range, a locked string, a tuning to the current
  peg, wrong stage and staleness, and are the failures (broken step and string; spent budget) named? [Coverage, Spec
  §Edge Cases; Clarifications Q3, Q4, Q5]
- [x] CHK009 Are malformed levels excluded (values out of range, start equal to goal, a string joining an island to
  itself, a repeated pair, a repeated tone in a step)? [Edge Case, Spec §Clarifications Q5; data-model]
- [x] CHK010 Are the boundaries stated (a swing at the threshold is a bridge, one quarter below at any sample is not; a
  test on the last action can win; a mode above 5 does not resonate)? [Edge Case, Spec §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Is it required that every string, island, bridge and measure is available in words and numbers? [Coverage,
  Spec §FR-R02G1201-013]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes, the independent recomputation and the boundary cases (threshold, one action either
  side of the budget) stated? [Measurability, Spec §SC-R02G1201-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]
