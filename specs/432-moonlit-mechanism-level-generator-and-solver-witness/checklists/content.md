# Requirements Quality Checklist: R02-G14-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 432 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 422's checklist.

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be won within its budget, and the stored
  plan is a shortest one)? [Clarity, Spec §US1; FR-R02G1402-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (more gears, lamp heights and key frames, longer scrambles),
  never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (wall, gear count, lamp heights, parents and tooth counts
  with the divisor redraw, solution set-up, blades, depths, centres, slot tables, alignment values, key frames and
  required flags, forbidden cells, allowance, scramble), with the seed derivation per candidate, the filters and the
  candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the minimality proof defined (plan vectors by increasing L1 norm, every vector of a smaller norm tried
  and losing), with the vector order and work bound stated, and is the reason the vector search covers every plan
  (actions commute, a monotone lamp path stays in range) and the reason the alignment pruning loses no win (a turn never
  changes an alignment, a jammed machine never wins) given? [Measurability, Spec §FR-R02G1402-002; Clarifications Q2]
- [x] CHK005 Is the witness file's content (state digests, fingerprints, counterexample), byte-for-byte check and
  opt-in regeneration defined? [Completeness, Spec §FR-R02G1402-004; Clarifications Q4]
- [x] CHK006 Is the catalog digest's input (fingerprints in manifest order) and the progression rule on the witness
  action count stated, with band ranges that keep it? [Consistency, Spec §FR-R02G1402-005; Clarifications Q3, Q5]
- [x] CHK007 Do the generated values stay inside R02-G14-01's level ranges (2 … 5 gears, teeth from 6 … 20 with
  divisors ≥ 2, depth 1 … 3, slot rays within ±3 of ±8, wall 12 … 16 × 9 … 12 within 8 … 24 × 6 … 16, lamp heights
  2 … 5, 2 … 5 key frames within 2 … 6, 2 … 6 forbidden cells within 0 … 12, allowance 0, budget 8 … 19 within 1 … 40,
  at most budget − 1 actions), so the kernel is unchanged except for two new refusals? [Consistency, Spec
  §Clarifications Q1; FR-R02G1402-006]
- [x] CHK008 Is the tie rule for several minimal plans stated in this game's terms (the first vector in the fixed
  order)? [Consistency, Spec §Edge Cases; Clarifications Q2]
- [x] CHK009 Is it stated that the acceptance ranges were measured by a prototype on the real kernel before being
  written down? [Assumption, Spec §Clarifications preamble]

## Empty and error states

- [x] CHK010 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK011 Are candidates already won at their start, with an empty key-frame cast, with out-of-range plans and over
  the work bound excluded with a deterministic next step? [Edge Case, Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that presentation belongs to later features (R02-G14-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes stated (all 100 levels, the independent breadth-first search on two levels per band,
  groups of 20 under 10 s measured locally)? [Measurability, Spec §SC-R02G1402-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
