# Requirements Quality Checklist: R02-G13-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 424 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the three design controls (drag links between stars, tap a node to nudge, orbit to inspect) and the
  listen each tied to a stated gesture and outcome? [Clarity, Spec §US1–US5; Clarifications Q2, Q3, Q4]
- [x] CHK002 Is it stated which gestures send a kernel action (link, unlink, nudge, listen) and which change
  presentation state only (choose, choosePair, preview, orbit, reset)? [Consistency, Spec §FR-R02G1304-001 … 006; Key
  Entities]
- [x] CHK003 Is the cost of each gesture stated (a star tap spends one action; a link tap inspects for free), with the
  reason the backward nudge stays on the panel? [Clarity, Spec §US2, US4; Assumptions; Research R2]

## Deterministic invariants

- [x] CHK004 Are picking order and targets numeric (coherence bars and hold pips, then the nearest star centre, then the
  nearest link spline of 16 segments, each within 22 points of the touch in view points, ties stated)? [Measurability,
  Spec §Clarifications Q1]
- [x] CHK005 Are tap, drag and double-tap thresholds numeric and told apart by event timestamps, including a press
  lifted at 0.5 s or later? [Clarity, Spec §Clarifications Q1, Q2]
- [x] CHK006 Is every link-drag outcome defined (unlinked pair, pair the player linked, fixed pair, no target, the start
  star, a drag on a stage other than playing, a drag from a link, a gauge or empty space)? [Completeness, Spec
  §Clarifications Q3; Edge Cases]
- [x] CHK007 Are orbit bounds, the refit and the reset stated, with orbit kept out of the digest and the snapshot?
  [Consistency, Spec §FR-R02G1304-006; Clarifications Q4]

## Empty and error states

- [x] CHK008 Are second fingers, cancels, 10 … 16-point touches and finished plays defined to send no kernel action,
  and is a star tap on a finished play stated? [Coverage, Spec §Edge Cases; SC-R02G1304-002]
- [x] CHK009 Are kernel refusals (degree limit, link limit, budget, stage) for every gesture passed through with their
  reason code, logged and shown? [Edge Case, Spec §Edge Cases; FR-R02G1304-008] — corrected 2026-11-23: only link
  limits were named; nudge and listen refusals and the logging were missing.
- [x] CHK010 Are taps on the moves gauge and on guides defined (empty space)? [Edge Case, Spec §Clarifications Q1]

## Accessibility (colour independence)

- [x] CHK011 Does every gesture have a panel alternative, with all 100 levels winnable through the panel alone?
  [Coverage, Spec §US6; FR-R02G1304-007; SC-R02G1304-005]

## Source licence and code-only graphics

- [x] CHK012 Are all interaction and drawing (including the drag filament) original code with no third-party assets or
  copied designs? [Consistency, Spec §Assumptions; Plan §Constitution]

## iPad/iPhone layout

- [x] CHK013 Are aspects 0.4 … 2.5 covered at every orbit with a 5 % margin? [Coverage, Spec §FR-R02G1304-006;
  SC-R02G1304-004]

## Simulator proof

- [x] CHK014 Are host and simulator test scopes stated (500 seeded gestures with an independent pick; pointer entry on
  the simulator; panel win over 100 levels)? [Measurability, Spec §Clarifications Q5; SC-R02G1304-001, 005]

## Future D1/D2/D3 evidence

- [x] CHK015 Is touch feel and latency tagged {device} and deferred to after ImplementationLock-100? [Completeness, Spec
  §SC-R02G1304-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK009 failed at first reading; the spec was corrected before the item was judged.
