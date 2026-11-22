# Requirements Quality Checklist: R02-G06-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 352 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a player gains (every level solvable within its budget, none solved without the player)?
  [Clarity, Spec §US1]
- [x] CHK002 Is difficulty defined by decisions (edits needed, collisions to avoid) rather than reflexes? [Clarity, Spec
  §US3; Clarifications Q3]

## Deterministic invariants

- [x] CHK003 Is every draw of the generator, its order and its ranges stated, so a seed builds the same level everywhere?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK004 Is the solver's lower-bound argument stated (each edit acts on one star; a star off target at T needs one),
  with the window order, the blocked test and the work measure? [Clarity, Spec §Clarifications Q2]
- [x] CHK005 Is it required that every reported win is replayed through the kernel, with the win tick taken from the
  replay? [Completeness, Spec §FR-R02G0602-002; Clarifications Q2]
- [x] CHK006 Are the band ranges consistent with non-falling band means and the progression rule? [Consistency, Spec
  §Clarifications Q1, Q3]
- [x] CHK007 Is the content count consistent across sources (100 canonical, 78 a milestone)? [Consistency, Spec
  §Canonical overrides]

## Empty and error states

- [x] CHK008 Are the failure modes named (no candidate within 512, every window blocked, damaged, newer, edited or
  non-replaying witness)? [Coverage, Spec §Edge Cases; Clarifications Q2, Q5]
- [x] CHK009 Are the counterexamples defined for every smallest count, including 1? [Edge Case, Spec §Edge Cases]

## Source licence and code-only graphics

- [x] CHK010 Is the manifest's provenance stated and are generated levels original? [Consistency, Spec §Assumptions]
- [x] CHK011 Is it stated that nothing is drawn in this feature? [Completeness, Spec §Excluded scope]

## iPad/iPhone layout

- [x] CHK012 Is it stated that layout belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK013 Are the host-test size limits and the brute-force cross-check sample stated? [Measurability, Spec
  §SC-R02G0602-002, 006]

## Future D1/D2/D3 evidence

- [x] CHK014 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
