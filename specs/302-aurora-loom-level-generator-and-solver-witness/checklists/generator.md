# Requirements Quality Checklist: R02-G01-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 302 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated that every shipped level is solvable within its move allowance and does not start won?
  [Completeness, Spec §US1; §SC-R02G0102-001]
- [x] CHK002 Is "harder" defined in measurable terms (more moves, finer tolerance) rather than smaller gestures?
  [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Are the seed derivation per candidate, the candidate limit and the band parameters defined numerically?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK004 Is the solver's work budget stated as numbers? [Clarity, Spec §FR-R02G0102-002] — corrected: 32 sweeps per
  ribbon and 256 grid settings per ribbon are now in the requirement.
- [x] CHK005 Are the witness's tie rules (which shortest solution, which move order) fixed? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK006 Is "exhaustive check" defined independently of the solver? [Measurability, Spec §SC-R02G0102-002] —
  corrected: every setting of each ribbon judged by the full win test.
- [x] CHK007 Are the catalog digest's inputs and order stated? [Clarity, Spec §Clarifications Q5]

## Empty and error states

- [x] CHK008 Are a seed with no acceptable candidate, a damaged, newer or edited witness and a witness that no longer
  replays each given an outcome and a code? [Coverage, Spec §Edge Cases; Clarifications Q4, Q5]

## Source licence and code-only graphics

- [x] CHK009 Is the provenance of the manifest data stated and is the feature free of drawing? [Consistency, Spec
  §Assumptions] — corrected: the manifest is the project's own archived design; nothing is drawn.

## iPad/iPhone layout and accessibility

- [x] CHK010 Is it stated which features own layout, accessibility and hints? [Completeness, Spec §Assumptions] —
  corrected: R02-G01-04, -05 and -06.

## Simulator proof

- [x] CHK011 Are the host tests and the simulator regression of existing packages required? [Consistency, plan Testing;
  Spec §SC-R02G0102-006]

## Future D1/D2/D3 evidence

- [x] CHK012 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
