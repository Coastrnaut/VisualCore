# Requirements Quality Checklist: R02-G01-01 rule kernel

**Purpose**: Unit tests for the requirements of feature 301 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are "won" and "failed" stated in terms a player can trust (exact, the same every time, with an explanation of
  the furthest-off gate)? [Clarity, Spec §FR-R02G0101-003; Clarifications Q2]
- [x] CHK002 Is the move allowance's interaction with undo defined so exploration is not punished? [Clarity, Spec
  §Clarifications Q3]

## Deterministic invariants

- [x] CHK003 Are phase units, steps, gates, speeds, periods and tolerance defined numerically? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK004 Is the boundary of the tolerance (inclusive) and the tie order of the worst mismatch defined? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK005 Are the fingerprint's exact inputs listed? [Clarity, Spec §Clarifications Q4]
- [x] CHK006 Are the source's invariants all placed, here or in a named later feature? [Traceability, Spec §Traceability]
  — corrected: INV-06, INV-10 and INV-12 are assigned to later features and the gate; INV-11 is superseded.

## Empty and error states

- [x] CHK007 Are out-of-range, no-change, over-allowance, wrong-stage and stale moves, an already-winning start and
  damaged, newer stored levels each given an outcome and a code? [Coverage, Spec §Edge Cases; Clarifications Q3–Q5]

## Source licence and code-only graphics

- [x] CHK008 Is the kernel free of third-party content and of any drawing? [Consistency, Spec §Assumptions; plan
  Constitution Check X, XIII]

## iPad/iPhone layout and accessibility

- [x] CHK009 Is it stated which features own layout, VoiceOver and the accessible steppers, and that they use the same
  moves? [Completeness, Spec §Assumptions] — corrected: R02-G01-04 and -06.

## Simulator proof

- [x] CHK010 Are the host tests of the new package and the simulator regression of existing packages required?
  [Consistency, plan Testing; Spec §SC-R02G0101-006]

## Future D1/D2/D3 evidence

- [x] CHK011 Is it stated that this feature has no device-only item, and why? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
