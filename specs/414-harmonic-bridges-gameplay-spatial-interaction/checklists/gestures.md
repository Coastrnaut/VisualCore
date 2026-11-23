# Requirements Quality Checklist: R02-G12-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 414 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the three design controls (pluck to audition, drag the tuning peg, tap freeze to test) each tied to a
  stated gesture and outcome? [Clarity, Spec §US1–US3; Clarifications Q2, Q3]
- [x] CHK002 Is it stated which gestures send a kernel action (tune, test) and which change presentation state only
  (choose, preview, orbit, reset)? [Consistency, Spec §FR-R02G1204-001 … 005; Key Entities]
- [x] CHK003 Is plucking stated to cost no action, with the reason given? [Clarity, Spec §US1; Research R2]

## Deterministic invariants

- [x] CHK004 Are picking order and targets numeric (pips, then the goal's top centre, then the nearest string segment,
  each within 22 points of the touch in view points, ties to the lower index)? [Measurability, Spec §Clarifications Q1]
- [x] CHK005 Are tap, drag and double-tap thresholds numeric and told apart by event timestamps, including a press
  lifted at 0.5 s or later? [Clarity, Spec §Clarifications Q1, Q2]
- [x] CHK006 Is the peg preview numeric (24 points per peg, rounding rule, clamp 1 … 12) and is every drag outcome
  defined (changed peg, unchanged peg, locked string, finished play, drag from a pip, the goal or empty space)?
  [Completeness, Spec §Clarifications Q3; Edge Cases] — corrected 2026-11-23: the preview of a drag from a locked string
  or on a stage other than playing was undefined.
- [x] CHK007 Are orbit bounds, the refit and the reset stated, with orbit kept out of the digest and the snapshot?
  [Consistency, Spec §FR-R02G1204-005; Clarifications Q4]

## Empty and error states

- [x] CHK008 Are second fingers, cancels, 10 … 16-point touches and finished plays defined to send no kernel action,
  and is plucking on a finished play stated? [Coverage, Spec §Edge Cases; SC-R02G1204-002]
- [x] CHK009 Are kernel refusals (a locked or missing string, a tuning to the current peg, the budget, the stage) passed
  through with their reason code, logged and shown? [Edge Case, Spec §Edge Cases; FR-R02G1204-007]
- [x] CHK010 Is a tap on an island other than the goal defined (empty space)? [Edge Case, Spec §Clarifications Q1]

## Accessibility (colour independence)

- [x] CHK011 Does every gesture have a panel alternative, with all 100 levels winnable through the panel alone?
  [Coverage, Spec §US5; FR-R02G1204-006; SC-R02G1204-005]

## Source licence and code-only graphics

- [x] CHK012 Are all interaction and drawing original code with no third-party assets or copied designs? [Consistency,
  Spec §Assumptions; Plan §Constitution]

## iPad/iPhone layout

- [x] CHK013 Are aspects 0.4 … 2.5 covered at every orbit with a 5 % margin? [Coverage, Spec §FR-R02G1204-005;
  SC-R02G1204-004]

## Simulator proof

- [x] CHK014 Are host and simulator test scopes stated (500 seeded gestures with an independent pick; pointer entry on
  the simulator; panel win over 100 levels)? [Measurability, Spec §Clarifications Q5; SC-R02G1204-001, 005]

## Future D1/D2/D3 evidence

- [x] CHK015 Is touch feel and latency tagged {device} and deferred to after ImplementationLock-100? [Completeness, Spec
  §SC-R02G1204-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK006 failed at first reading; the spec was corrected before the item was judged.
