# Requirements Quality Checklist: R02-G03-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 324 (handle picking, drag-to-direction mapping and snap,
arbitration, orbit limits and framing, selection and preview, panel completeness, testability, device items)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Picking and dragging

- [x] CHK001 Is the touch radius stated and the rule for overlapping handles defined? [Clarity, Spec §FR-R02G0304-001;
  Edge Cases]
- [x] CHK002 Is the drag-to-direction mapping defined precisely, including ties and the snap distance with a floor in
  points? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is it stated how many actions one gesture may send? [Completeness, Spec §FR-R02G0304-002; Q1]

## Arbitration and stages

- [x] CHK004 Are second finger, cancel, tap and empty-space cases each defined with their outcome? [Coverage, Spec
  §Clarifications Q2; Edge Cases]
- [x] CHK005 Is behaviour outside the playing stage defined for drags and taps? [Edge Case, Spec §Edge Cases; Q2]
- [x] CHK006 Is a refused move's presentation defined? [Exception Flow, Spec §User Story 1 AS3; Q2]

## Camera

- [x] CHK007 Are orbit limits, rates, reset and refit stated numerically? [Measurability, Spec §Clarifications Q3]
- [x] CHK008 Is the orbit stated as presentation only (not digest, snapshot or save)? [Consistency, Spec §FR-R02G0304-004]

## Selection, preview and panel

- [x] CHK009 Are the selection's drawing, description and the drag preview defined? [Completeness, Spec §Clarifications
  Q4]
- [x] CHK010 Is panel completeness stated as a measurable requirement over all levels, with the reason no pending values
  are needed? [Measurability, Spec §SC-R02G0304-004; Q4]

## Testability and device

- [x] CHK011 Is the screenless test approach defined (controller inputs and independent expectations)? [Measurability,
  Spec §Clarifications Q5]
- [x] CHK012 Are gesture feel and latency deferred as {device} items? [Scope, Spec §SC-R02G0304-007]

## Notes

- `/speckit-implement` reads these markers and does not change them.
