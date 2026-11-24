# Requirements Quality Checklist: R02-G15-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 444 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is each move of the game (choose a hinge, turn it by a drag or a double tap) tied to a stated gesture and
  outcome? [Clarity, Spec §US1, US2; Clarifications Q2, Q3]
- [x] CHK002 Is it stated which gestures send a kernel action (a turn) and which change presentation only (choose a
  hinge, the pending text, orbit, reset)? [Consistency, Spec §FR-R02G1504-001 … 004; Key Entities]
- [x] CHK003 Is the cost of each gesture stated (one action per turn, one turn per drag, a tap free)? [Clarity, Spec
  §US1, US2; Clarifications Q2]

## Deterministic invariants

- [x] CHK004 Are the picking target and order numeric (the convex outline of the eight projected corners of a 0.9 s cube
  grown by 8 points; the front-most, drawn last, first; ties by the paint order)? [Measurability, Spec
  §Clarifications Q1; FR-R02G1504-003]
- [x] CHK005 Are tap, drag and double-tap thresholds numeric and told apart by event timestamps, including a press
  lifted at 0.5 s or later and a 10 … 16-point touch? [Clarity, Spec §Clarifications Q1; Edge Cases]
- [x] CHK006 Is the step of a cube drag defined exactly (the predicted on-screen motion of the tracked cube, the swinging cube
  farthest from the hinge line,
  for +1 and −1, the larger projection of the finger's travel, the 24-point threshold, one turn per drag, the pending
  text following the finger)? [Measurability, Spec §FR-R02G1504-001; Clarifications Q2; Edge Cases]
- [x] CHK007 Is it stated why the touched cube's own motion is not used (cube h lies on its hinge line and never moves)?
  [Clarity, Spec §Clarifications preamble and Q2; Research R2]
- [x] CHK008 Are orbit bounds, the refit, the eye outside the box and the reset stated, with orbit kept out of the digest
  and the snapshot's game state? [Consistency, Spec §FR-R02G1504-004; Clarifications Q4]

## Empty and error states

- [x] CHK009 Are second fingers, cancels and finished plays defined to send no kernel action, with what taps still do on
  a finished play? [Coverage, Spec §Edge Cases; FR-R02G1504-005; SC-R02G1504-002]
- [x] CHK010 Is every drag outcome on the root, on an idle hinge, outside playing and on a cancel defined, including the
  pending text? [Completeness, Spec §Clarifications Q2; Edge Cases] — corrected 2026-11-24: clearing the pending turn
  on a cancelled drag was not stated.
- [x] CHK011 Are kernel refusals and failures (idle hinge, collision, sweep, budget, stage) passed through with their
  reason code, logged and shown? [Edge Case, Spec §Edge Cases; FR-R02G1504-007]
- [x] CHK012 Are taps on the target wireframe, hinge marks, gauges, backdrop and root defined? [Edge Case, Spec
  §Clarifications Q1, Q3]

## Accessibility (colour independence)

- [x] CHK013 Does every gesture have a panel alternative, with all 100 levels winnable through the panel alone?
  [Coverage, Spec §US4; FR-R02G1504-006; SC-R02G1504-005]

## Source licence and code-only graphics

- [x] CHK014 Are all interaction and drawing original code with no third-party assets or copied designs? [Consistency,
  Spec §Assumptions; Plan §Constitution]

## iPad/iPhone layout

- [x] CHK015 Are aspects 0.4 … 2.5 covered at every orbit with a 5 % margin, and are the meshes defined to face the
  drawn eye under orbit? [Coverage, Spec §FR-R02G1504-004; Clarifications Q4; SC-R02G1504-004]

## Simulator proof

- [x] CHK016 Are host and simulator test scopes stated (500 seeded gestures with an independent pick and prediction;
  pointer entry on the simulator; panel win over 100 levels)? [Measurability, Spec §Clarifications Q5;
  SC-R02G1504-001, 005]

## Future D1/D2/D3 evidence

- [x] CHK017 Is touch feel and latency tagged {device} and deferred to after ImplementationLock-100? [Completeness, Spec
  §SC-R02G1504-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK010 failed at first reading; the spec was corrected before the item was judged.
