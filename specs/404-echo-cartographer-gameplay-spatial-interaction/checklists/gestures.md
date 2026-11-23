# Requirements Quality Checklist: R02-G11-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 404 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the three design controls (tap to emit a pulse, drag markers to triangulate, rotate the 3D camera)
  each tied to a stated gesture and outcome? [Clarity, Spec §US1, US2, US4; Clarifications Q2–Q4]
- [x] CHK002 Is it stated which gestures send a kernel action (pulse, claim, mark) and which change presentation state
  only (cursor, orbit, reset)? [Consistency, Spec §FR-R02G1104-001 … 005; Key Entities]
- [x] CHK003 Is a claim given a deliberate gesture distinct from the pulse tap, with the reason stated? [Clarity, Spec
  §US3; Research R3]

## Deterministic invariants

- [x] CHK004 Are picking order and targets numeric (floor plane y = 0, markers within 22 points first, ties to the lower
  cell index, then the containing cell)? [Measurability, Spec §Clarifications Q1]
- [x] CHK005 Are tap, drag, hold and double-tap thresholds numeric and told apart by event timestamps? [Clarity, Spec
  §Clarifications Q1–Q3] — corrected 2026-11-23: the boundary between a tap and a held press (before 0.5 s, at 0.5 s
  or later) and its time base were not stated.
- [x] CHK006 Is every drag outcome defined (marker moved, marker placed, released on its own cell, a marked cell or
  empty space, ninth marker), including a drag or held press starting on empty space or on a marker? [Completeness,
  Spec §Clarifications Q3; Edge Cases] — corrected 2026-11-23: drags and held presses starting on empty space and a
  press held on a marker were undefined.
- [x] CHK007 Are orbit bounds, the refit and the reset stated, with orbit kept out of the digest and the snapshot?
  [Consistency, Spec §FR-R02G1104-005; Clarifications Q4]

## Empty and error states

- [x] CHK008 Are second fingers, cancels, 10 … 16-point touches and finished plays defined to send nothing, and is the
  cursor's behaviour on a finished play stated? [Coverage, Spec §Edge Cases; SC-R02G1104-002] — corrected 2026-11-23:
  whether a tap moves the cursor on a finished play was implicit.
- [x] CHK009 Are kernel refusals (pulse without energy or from a cell not known open, ninth marker, claim) passed
  through with their reason code, logged and shown? [Edge Case, Spec §Edge Cases; FR-R02G1104-007]
- [x] CHK010 Is a held press that moves after arming defined to cancel? [Edge Case, Spec §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Does every gesture have a panel alternative, with all 100 levels winnable through the panel alone?
  [Coverage, Spec §US5; FR-R02G1104-006; SC-R02G1104-005]

## Source licence and code-only graphics

- [x] CHK012 Are all interaction and drawing original code with no third-party assets or copied designs? [Consistency,
  Spec §Assumptions; Plan §Constitution]

## iPad/iPhone layout

- [x] CHK013 Are aspects 0.4 … 2.5 covered at every orbit with a 5 % margin? [Coverage, Spec §FR-R02G1104-005;
  SC-R02G1104-004]

## Simulator proof

- [x] CHK014 Are host and simulator test scopes stated (500 seeded gestures with an independent pick; pointer entry on
  the simulator; panel win over 100 levels)? [Measurability, Spec §Clarifications Q5; SC-R02G1104-001, 005]

## Future D1/D2/D3 evidence

- [x] CHK015 Is touch feel and latency tagged {device} and deferred to after ImplementationLock-100? [Completeness, Spec
  §SC-R02G1104-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK005, CHK006 and CHK008 failed at first reading; the spec was corrected before the items were judged.
