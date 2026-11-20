# Requirements Quality Checklist: R02-G02-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 312 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated that every shipped level is solvable within its move allowance and does not start won?
  [Completeness, Spec §US1; §SC-R02G0202-001]
- [x] CHK002 Is "harder" defined in measurable terms (more dial changes, fewer winning settings) rather than finer
  gestures? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Are the seed derivation per candidate, the candidate limit and the band parameters (checkpoints, radii,
  obstacles, shortest ranges) defined numerically? [Clarity, Spec §Clarifications Q1]
- [x] CHK004 Is the solver's work budget stated as numbers? [Clarity, Spec §FR-R02G0202-002] — corrected: at most 14,080
  exact verdicts and a search over at most 14,080 states.
- [x] CHK005 Are the witness's tie rules (which winning setting, which action order) fixed? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK006 Is the independent check of the solver defined without the solver's own prefilter? [Measurability, Spec
  §SC-R02G0202-002]
- [x] CHK007 Are the catalog digest's inputs and order stated? [Clarity, Spec §Clarifications Q5]
- [x] CHK008 Is the requirement that intermediate states stay legal (coprime) part of the shortest-path definition?
  [Consistency, Spec §FR-R02G0202-002; Edge Cases]

## Empty and error states

- [x] CHK009 Are a seed with no acceptable candidate, a damaged, newer or edited witness and a witness that no longer
  replays each given an outcome and a code? [Coverage, Spec §Edge Cases; Clarifications Q4, Q5]
- [x] CHK010 Are both counterexamples defined for every possible winning setting, including frequencies equal to 1?
  [Edge Case, Spec §Clarifications Q4]

## Source licence and code-only graphics

- [x] CHK011 Is the provenance of the manifest data stated and is the feature free of drawing? [Consistency, Spec
  §Assumptions]

## iPad/iPhone layout and accessibility

- [x] CHK012 Is it stated which features own layout, accessibility and hints? [Completeness, Spec §Assumptions] —
  corrected: R02-G02-04, -05 and -06 are named.

## Simulator proof

- [x] CHK013 Are the host tests and the simulator regression of existing packages required, with the per-test time
  bound? [Consistency, plan Testing; Spec §SC-R02G0202-006]

## Future D1/D2/D3 evidence

- [x] CHK014 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
