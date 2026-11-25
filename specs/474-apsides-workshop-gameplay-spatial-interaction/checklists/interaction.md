# Requirements Quality Checklist: R02-G18-04 gameplay spatial interaction

**Purpose**: Unit tests for the interaction requirements (gesture semantics, picking, the knob, size and crank drags,
camera, finished and cancelled states, accessibility parity, determinism, future device evidence)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 464's checklist. CHK003
failed at first reading: the knob's direction is the point's angle around the star, which is undefined for a finger
exactly over the star; clarification Q3 now keeps the current direction there, and the item passes. CHK013 passed from
the start because clarification Q5 already gave the panel a pending orbit with "Set periapsis" and "Set size" (the
lesson of feature 464's CHK013).

## Gesture semantics

- [x] CHK001 Is it stated what a tap on the orbiter, the orbit loop, a handle and empty space each does, in every stage?
  [Clarity, Spec §FR-R02G1804-003; Clarifications Q2]
- [x] CHK002 Are the knob and size drags defined (16 points to start on the handle while playing, the finger cast onto
  the sky plane, the step formulas with their clamps, the ghost and gauges as preview, one tuning on release when the
  pending orbit is valid and differs, nothing otherwise)? [Completeness, Spec §FR-R02G1804-001, 002, 004;
  Clarifications Q3]
- [x] CHK003 Are degenerate drag points defined (a finger exactly at the star; a pending orbit that is invalid, with its
  reason in words)? [Edge Case, Spec §Clarifications Q3]
- [x] CHK004 Are the tap, drag and double-tap thresholds given in points and seconds and the same as feature 464's?
  [Consistency, Spec §Edge Cases; Assumptions]

## Picking

- [x] CHK005 Is picking analytic and reproducible (the orbiter's projected disc grown by 8 points, the markers grown by
  12 points, the loop band of 10 points, the one drawn last first)? [Measurability, Spec §FR-R02G1804-005;
  Clarifications Q1]
- [x] CHK006 Are overlapping handles addressed (the one drawn last is picked, as drawn)? [Edge Case, Spec §Edge Cases]

## Time crank and tuning preview

- [x] CHK007 Is the crank's tick rule stated (the nearest projected tick, lower on ties; every change a `clock.show`)?
  [Clarity, Spec §Clarifications Q4]
- [x] CHK008 Is it stated that the preview and the shown tick are presentation only (never in the digest)?
  [Consistency, Spec §FR-R02G1804-004; SC-R02G1804-003]

## Camera

- [x] CHK009 Are the orbit bounds, gesture scales, re-basing, reset and refit (5 % margin at aspects 0.4 … 2.5, eye
  outside the box) stated in numbers? [Clarity, Spec §FR-R02G1804-006; Clarifications Q4]
- [x] CHK010 Is the fit stated to hold for every previewed orbit (valid orbits stay inside the sky bound, so inside the
  R02-G18-03 box)? [Coverage, Spec §SC-R02G1804-004; Plan §Constraints]

## Finished, cancelled and refused states

- [x] CHK011 Are finished plays, cancelled touches, second fingers and kernel refusals defined (no kernel action, or
  sent and decided by the kernel, with words)? [Coverage, Spec §FR-R02G1804-007; Edge Cases]
- [x] CHK012 Is it stated that the time crank still shows ticks on a finished play? [Clarity, Spec §Clarifications Q2]

## Accessibility parity and determinism

- [x] CHK013 Is a complete gesture-free path required and achievable within every budget (the panel's pending orbit
  with "Set periapsis", "Set size" and "Reset view"; all 100 witnesses won through the panel)? [Measurability, Spec
  §FR-R02G1804-008; SC-R02G1804-005; Clarifications Q5]
- [x] CHK014 Is it stated that only event timestamps are read and every action goes through a declared control?
  [Consistency, Spec §FR-R02G1804-009; Plan §Constitution Check]

## Future device evidence

- [x] CHK015 Are touch feel and latency deferred to after ImplementationLock-100 and marked `{device}`? [Consistency,
  Spec §SC-R02G1804-007]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
