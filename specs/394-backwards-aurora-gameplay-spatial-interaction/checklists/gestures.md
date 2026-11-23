# Requirements Quality Checklist: R02-G10-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 394 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the three design controls (tap segment ends, swipe the interval to reverse, timeline freeze preview)
  each tied to a stated gesture and outcome? [Clarity, Spec §US1–US3; Clarifications Q2, Q3]
- [x] CHK002 Is it stated which gestures send a kernel action (only the swipe) and which change presentation state only?
  [Consistency, Spec §FR-R02G1004-001 … 003; Key Entities]

## Deterministic invariants

- [x] CHK003 Are picking order and targets numeric (ends within 22 points, band extent, sample columns ± u/2, |y|
  limits)? [Measurability, Spec §Clarifications Q1]
- [x] CHK004 Are tap, drag, hold, swipe and double-tap thresholds numeric and based on event timestamps? [Clarity, Spec
  §Clarifications Q1–Q4]
- [x] CHK005 Is the freeze preview defined as the kernel's own reversal (not a graphics estimate), and its end state
  defined (lifting sends nothing; a frozen press never becomes a swipe)? [Completeness, Spec §Clarifications Q3] —
  corrected 2026-11-22: what happens when a frozen finger moves was undefined.
- [x] CHK006 Are orbit bounds, the refit and the reset stated, with orbit kept out of the digest and the snapshot?
  [Consistency, Spec §FR-R02G1004-005; Clarifications Q4]

## Empty and error states

- [x] CHK007 Are second fingers, cancels, 10 … 16-point touches and finished plays defined to send nothing? [Coverage,
  Spec §Edge Cases; SC-R02G1004-002]
- [x] CHK008 Are kernel refusals of a swiped section (palindrome, length) passed through with their reason and logged?
  [Edge Case, Spec §Edge Cases; Clarifications Q4]
- [x] CHK009 Is the crossing of ends excluded (start < end always)? [Edge Case, Spec §Edge Cases; Clarifications Q2]

## Accessibility (colour independence)

- [x] CHK010 Does every gesture have a panel alternative, with all 100 levels winnable through the panel alone?
  [Coverage, Spec §US5; FR-R02G1004-006; SC-R02G1004-005]

## Source licence and code-only graphics

- [x] CHK011 Is the preview drawn as generated geometry and are all designs original? [Consistency, Spec §Assumptions;
  Plan §Constitution XIII]

## iPad/iPhone layout

- [x] CHK012 Are aspects 0.4 … 2.5 covered at every orbit? [Coverage, Spec §FR-R02G1004-005; SC-R02G1004-004]

## Simulator proof

- [x] CHK013 Are host and simulator test scopes stated (500 seeded gestures with an independent pick; pointer entry on
  the simulator)? [Measurability, Spec §Clarifications Q5; SC-R02G1004-001]

## Future D1/D2/D3 evidence

- [x] CHK014 Is touch feel and latency tagged {device} and deferred to after ImplementationLock-100? [Completeness, Spec
  §SC-R02G1004-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK005 failed at first reading; the spec was corrected before the items were judged.
