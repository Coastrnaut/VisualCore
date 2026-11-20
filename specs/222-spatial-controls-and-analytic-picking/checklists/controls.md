# Requirements Quality Checklist: R02-F22 spatial controls

**Purpose**: Unit tests for the requirements of feature 222 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the promise (the touch lands on the meant handle, drags never jump, one undo per drag, an equal path
  without dragging) stated as measurable rules? [Measurability, Spec §SC-R02F22-002…005]

## Deterministic invariants

- [x] CHK002 Are the screen-to-NDC mapping, the clip depths and the plane formula with its tolerance stated exactly?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the picking order (screen distance, depth, index) and the minimum radius stated without open ties?
  [Clarity, Spec §Clarifications Q2]
- [x] CHK004 Are the drag formula and both grazing thresholds given numerically? [Clarity, Spec §Clarifications Q3]
- [x] CHK005 Are coalescing, redo clearing and the depth bound defined for the history? [Completeness, Spec
  §Clarifications Q4]
- [x] CHK006 Is exact reversibility of assistive steps tied to an integer index, and its limit behaviour defined?
  [Clarity, Spec §Clarifications Q5]

## Empty and error states

- [x] CHK007 Are outside-viewport touches, degenerate cameras, no candidates, ties, edge-on planes, empty undo and redo,
  and oversize inputs each given an outcome, and is every refusal named? [Coverage, Spec §Edge Cases; Clarifications]

## Source licence and code-only graphics

- [x] CHK008 Are the methods named as textbook ones, with handle drawing left to code in the experiences? [Consistency,
  research R1–R6; Spec §Assumptions]

## iPad/iPhone layout and accessibility

- [x] CHK009 Is the unit of screen input and its use on both device families stated? [Completeness, Spec §Assumptions]
  — corrected: points with the origin at the top left, the same on iPhone and iPad in either orientation.
- [x] CHK010 Is the non-touch path for choosing a handle assigned to an owner? [Gap, Spec §Assumptions] — corrected: the
  consuming experience exposes handles as accessibility elements; this slice supplies the steps and history.

## Simulator proof

- [x] CHK011 Is the regression on the simulators required, Effects Composer included? [Consistency, plan Testing; Spec
  §SC-R02F22-007]

## Future D1/D2/D3 evidence

- [x] CHK012 Are the device-only items (touch accuracy, VoiceOver use) named and deferred to after
  ImplementationLock-100? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
