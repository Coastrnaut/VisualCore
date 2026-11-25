# Requirements Quality Checklist: R02-G17-04 gameplay spatial interaction

**Purpose**: Unit tests for the interaction requirements (gesture semantics, picking, the orbital-handle drag and the
time dial, camera, finished and cancelled states, accessibility parity, determinism, future device evidence)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 454's checklist. CHK013
failed at first reading: the panel's phase − and + (R02-G17-03) each send a phase change, which costs an action, so
stepping a planet to a far orbit position could exceed the budget and "every witness won through the panel" was not
guaranteed; clarification Q5 and FR-R02G1704-008 now make phase − and + move a previewed pending offset and add "Set
phase", which commits it as one action, and the item passes.

## Gesture semantics

- [x] CHK001 Is it stated what a tap on a body, on the time dial and on empty space each does, in every stage?
  [Clarity, Spec §FR-R02G1704-002, 003; Clarifications Q2]
- [x] CHK002 Is the orbital-handle drag defined (16 points to start on a movable body while playing, the pending offset
  as the nearest projected orbit position at the shown tick with ties to the lower offset, the ghost and predicted
  timeline as preview, one `orbit.phase` on release when it differs, nothing otherwise)? [Completeness, Spec
  §FR-R02G1704-001, 004; Clarifications Q3]
- [x] CHK003 Is a drag from a fixed body defined (nothing sent, explained in words)? [Edge Case, Spec §User Story 1;
  Clarifications Q3]
- [x] CHK004 Are the tap, drag and double-tap thresholds given in points and seconds and the same as feature 454's?
  [Consistency, Spec §Edge Cases; Assumptions]

## Picking

- [x] CHK005 Is picking analytic and reproducible (projected disc radius r · s grown by 8 points, front-most by paint
  order, the dial box)? [Measurability, Spec §FR-R02G1704-005; Clarifications Q1]
- [x] CHK006 Is a body hidden behind a nearer body addressed (the front-most is picked, as drawn)? [Edge Case, Spec
  §Edge Cases]

## Time dial and phase preview

- [x] CHK007 Is the dial's tick rule stated (the nearest projected tick on the strip, lower on ties — corrected at
  implementation from a linear fraction that missed by one under perspective; every change a `clock.show`)? [Clarity,
  Spec §Clarifications Q4]
- [x] CHK008 Is it stated that the preview and the shown tick are presentation only (never in the digest)?
  [Consistency, Spec §FR-R02G1704-004; SC-R02G1704-003]

## Camera

- [x] CHK009 Are the orbit bounds, gesture scales, re-basing, reset and refit (5 % margin at aspects 0.4 … 2.5, eye
  outside the box) stated in numbers? [Clarity, Spec §FR-R02G1704-006; Clarifications Q4]
- [x] CHK010 Is the fit stated to hold for a ghost at every orbit position (positions inside the widened R02-G17-03
  box)? [Coverage, Spec §SC-R02G1704-004; Plan §Constraints]

## Finished, cancelled and refused states

- [x] CHK011 Are finished plays, cancelled touches, second fingers and kernel refusals defined (no kernel action, or
  sent and decided by the kernel, with words)? [Coverage, Spec §FR-R02G1704-007; Edge Cases]
- [x] CHK012 Is it stated that taps and the dial still choose and show on a finished play? [Clarity, Spec
  §Clarifications Q2]

## Accessibility parity and determinism

- [x] CHK013 Is a complete gesture-free path required and achievable within every budget (the panel with "Set phase"
  and "Reset view"; all 100 witnesses won through the panel)? [Measurability, Spec §FR-R02G1704-008; SC-R02G1704-005;
  Clarifications Q5]
- [x] CHK014 Is it stated that only event timestamps are read and every action goes through a declared control?
  [Consistency, Spec §FR-R02G1704-009; Plan §Constitution Check]

## Future device evidence

- [x] CHK015 Are touch feel and latency deferred to after ImplementationLock-100 and marked `{device}`? [Consistency,
  Spec §SC-R02G1704-007]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
