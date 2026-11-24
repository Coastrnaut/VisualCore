# Requirements Quality Checklist: R02-G14-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 434 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is each move of the game (turn, lamp step, re-seat, show a key frame, run) tied to a stated gesture and
  outcome? [Clarity, Spec §US1–US4; Clarifications Q2, Q3, Q4]
- [x] CHK002 Is it stated which gestures send a kernel action (turn, lamp step, re-seat, run) and which change
  presentation only (choose a gear, pending texts, show a key frame, orbit, reset)? [Consistency, Spec
  §FR-R02G1404-001 … 006; Key Entities]
- [x] CHK003 Is the cost of each gesture stated (one action per tooth and per rung, one per re-seat and run, a card tap
  free), with the cap at the actions left? [Clarity, Spec §US1, US2; Clarifications Q2]

## Deterministic invariants

- [x] CHK004 Are picking order and targets numeric (lamp and ladder within 22 points, then a card rectangle or centre
  within 22 points, then the front-most gear outline circle 3.75 s + 8 points; ties stated)? [Measurability, Spec
  §Clarifications Q1]
- [x] CHK005 Are tap, drag and double-tap thresholds numeric and told apart by event timestamps, including a press
  lifted at 0.5 s or later? [Clarity, Spec §Clarifications Q1; Edge Cases]
- [x] CHK006 Is the turn count of a gear drag defined exactly (clockwise swept angle ÷ one tooth, rounded; step sign from
  the gear's direction; the centre dead zone; the cap)? [Measurability, Spec §FR-R02G1404-001; Clarifications Q2]
- [x] CHK007 Is the lamp drag defined in screen distance (24 points per rung), with the reason a projected rung is not
  used? [Clarity, Spec §Clarifications Q3; Research R3]
- [x] CHK008 Are orbit bounds, the refit and the reset stated, with orbit kept out of the digest and the snapshot?
  [Consistency, Spec §FR-R02G1404-006; Clarifications Q5]

## Empty and error states

- [x] CHK009 Are second fingers, cancels, 10 … 16-point touches and finished plays defined to send no kernel action,
  with what gear and card taps still do on a finished play? [Coverage, Spec §Edge Cases; SC-R02G1404-002]
- [x] CHK010 Is every drag outcome on a stage other than playing, and every cancelled drag, defined? [Completeness, Spec
  §Clarifications Q2, Q3] — corrected 2026-11-24: the lamp drag off the playing stage, a ladder tap and the clearing
  of the pending texts on a cancel were not stated.
- [x] CHK011 Are kernel refusals (budget, lamp range, stage, the driver) passed through with their reason code, logged
  and shown, and is the driver's double tap defined? [Edge Case, Spec §Edge Cases; FR-R02G1404-003, 008]
- [x] CHK012 Are taps on the wall, the alignment pips and the moves bars defined (empty space)? [Edge Case, Spec
  §Clarifications Q1]

## Accessibility (colour independence)

- [x] CHK013 Does every gesture have a panel alternative, with all 100 levels winnable through the panel alone?
  [Coverage, Spec §US6; FR-R02G1404-007; SC-R02G1404-005]

## Source licence and code-only graphics

- [x] CHK014 Are all interaction and drawing original code with no third-party assets or copied designs? [Consistency,
  Spec §Assumptions; Plan §Constitution]

## iPad/iPhone layout

- [x] CHK015 Are aspects 0.4 … 2.5 covered at every orbit with a 5 % margin? [Coverage, Spec §FR-R02G1404-006;
  SC-R02G1404-004]

## Simulator proof

- [x] CHK016 Are host and simulator test scopes stated (500 seeded gestures with an independent pick; pointer entry on
  the simulator; panel win over 100 levels)? [Measurability, Spec §Clarifications Q5; SC-R02G1404-001, 005]

## Future D1/D2/D3 evidence

- [x] CHK017 Is touch feel and latency tagged {device} and deferred to after ImplementationLock-100? [Completeness, Spec
  §SC-R02G1404-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK010 failed at first reading; the spec was corrected before the item was judged.
