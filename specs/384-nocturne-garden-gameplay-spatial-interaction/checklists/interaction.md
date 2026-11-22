# Requirements Quality Checklist: R02-G09-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 384 (player impact, deterministic invariants, empty and error
states, accessibility, source licence, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what each gesture does (tap a cell to plant, drag a bloom to move or off the bed to remove,
  pinch to resize, drag the lantern to change the sun, two fingers to orbit, double tap to reset)? [Clarity, Spec
  §US1–US4; Clarifications Q2, Q3]
- [x] CHK002 Is the "silhouette preview as exact diagnostic" defined as the kernel's own cells, match and leak of the
  would-be arrangement, for moves and for removals? [Completeness, Spec §FR-R02G0904-002; Clarifications Q2] —
  corrected 2026-11-22: the removal preview (the arrangement without the bloom) was added.

## Deterministic invariants

- [x] CHK003 Are the pick order and the touch target size stated (lantern, blooms, bed; 22 points)? [Clarity, Spec
  §FR-R02G0904-004; Clarifications Q1]
- [x] CHK004 Are the tap, drag and double-tap thresholds and the time source (event timestamps only) stated in numbers?
  [Measurability, Spec §Clarifications Q1, Q3]
- [x] CHK005 Are the sun step (48 points), the pinch size rule (nearest allowed size to size·scale) and the grab offset
  of a drag stated? [Clarity, Spec §Clarifications Q2, Q3]
- [x] CHK006 Is it stated that orbit, picks and previews never enter the digest, snapshot or kernel? [Consistency, Spec
  §FR-R02G0904-005; SC-R02G0904-003]

## Empty and error states

- [x] CHK007 Are finished plays, cancelled touches, second fingers and no-op drags defined to send nothing? [Coverage,
  Spec §Edge Cases; Clarifications Q3, Q4]
- [x] CHK008 Is a kernel refusal (no supply, anchor outside the bed) defined as logged and shown with its reason code?
  [Coverage, Spec §Clarifications Q4]

## Accessibility (no gesture required)

- [x] CHK009 Does the panel keep every action available and is winning every level through it required? [Completeness,
  Spec §US5; FR-R02G0904-006; SC-R02G0904-005]

## Source licence and code-only graphics

- [x] CHK010 Is the preview outline stated as generated geometry with no image asset? [Consistency, Plan §Summary]

## iPad/iPhone layout

- [x] CHK011 Are the orbit bounds and the 5 % framing margin stated for aspects 0.4 … 2.5? [Coverage, Spec
  §FR-R02G0904-005; Clarifications Q3]

## Simulator proof

- [x] CHK012 Are host sizes (500 seeded sequences, all 100 levels through the panel) and the simulator wiring stated?
  [Measurability, Spec §SC-R02G0904-001 … 005; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK013 Is touch feel and latency tagged `{device}` and deferred to after ImplementationLock-100? [Completeness,
  Spec §SC-R02G0904-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK002 failed at first reading; the spec's drag clarification was corrected before the items were judged.
