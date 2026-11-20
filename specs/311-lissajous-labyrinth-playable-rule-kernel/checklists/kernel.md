# Requirements Quality Checklist: R02-G02-01 rule kernel

**Purpose**: Unit tests for the requirements of feature 311 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are "won" and "failed" stated in terms a player can trust (exact, the same every time, with the first contact
  or missing checkpoint named)? [Clarity, Spec §FR-R02G0201-003; Clarifications Q2]
- [x] CHK002 Is the allowance's interaction with undo defined so exploration is not punished? [Clarity, Spec
  §Clarifications Q3]

## Deterministic invariants

- [x] CHK003 Are angles, the sine table, amplitudes, frequencies, phases, the lap length and the tick defined numerically?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK004 Are the boundaries (checkpoint inclusive, obstacle exclusive), the closing segment and the verdict's tie
  order defined? [Clarity, Spec §Edge Cases; Clarifications Q2]
- [x] CHK005 Are the fingerprint's exact inputs listed? [Clarity, Spec §Clarifications Q4]
- [x] CHK006 Are the source's invariants all placed, here or in a named later feature? [Traceability, Spec §Traceability;
  FR-R02G0201-010]

## Empty and error states

- [x] CHK007 Are out-of-range, no-change, not-coprime, over-allowance, wrong-stage and stale actions, an already-won start
  and damaged, edited and newer stored levels each given an outcome and a code? [Coverage, Spec §Edge Cases;
  Clarifications Q3–Q5]

## Source licence and code-only graphics

- [x] CHK008 Is the kernel free of third-party content and of any drawing, and is the sine table's origin stated?
  [Consistency, Spec §Assumptions] — corrected: the table is computed by the project.

## iPad/iPhone layout and accessibility

- [x] CHK009 Is it stated which features own layout, VoiceOver and the accessible dial steppers, and that they use the
  same actions? [Completeness, Spec §Assumptions] — corrected: R02-G02-04 and -06.

## Simulator proof

- [x] CHK010 Are the host tests of the new target and the simulator regression of existing packages required?
  [Consistency, plan Testing; Spec §SC-R02G0201-006]

## Future D1/D2/D3 evidence

- [x] CHK011 Is it stated that this feature has no device-only item, and why? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
