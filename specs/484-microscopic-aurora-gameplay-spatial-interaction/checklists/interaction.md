# Requirements Quality Checklist: R02-G19-04 gameplay spatial interaction

**Purpose**: Unit tests for the interaction requirements (gesture semantics, picking, well drags, the scrubber, the
freeze, camera, finished and cancelled states, accessibility parity, determinism, future device evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 474's checklist. CHK003
failed at first reading: a dragged well's target was "the nearest site within 24 points, other than a site another
well holds", so a finger resting on an occupied site could silently pick a free site farther away; clarification Q3 now
takes the nearest site (lower index on ties) and makes an occupied or own site no change, and the item passes. CHK013
passed from the start: the R02-G19-03 panel already places a well with one action, so every witness fits its budget.

## Gesture semantics

- [x] CHK001 Is it stated what a tap on an empty site, a well, the scrubber, the dish field and empty space each does,
  in every stage? [Clarity, Spec §FR-R02G1904-001, 003, 005; Clarifications Q2]
- [x] CHK002 Are well drags defined (16 points to start on a well while playing, the finger cast onto the dish plane,
  the target site or removal, the previewed swim, one placement or removal on release when it is a change, nothing
  otherwise)? [Completeness, Spec §FR-R02G1904-002, 004; Clarifications Q3]
- [x] CHK003 Are degenerate drop points defined (an occupied or own site, ties between sites, a point inside the dish
  near no site, a tap on an empty site with every slot used)? [Edge Case, Spec §Clarifications Q2, Q3; Edge Cases]
- [x] CHK004 Are the tap, drag and double-tap thresholds given in points and seconds and the same as feature 474's?
  [Consistency, Spec §Edge Cases; Assumptions]

## Picking

- [x] CHK005 Is picking analytic and reproducible (wells and sites by projected radius grown by 12 points, the scrubber
  band of 14 points, the field as the projected enclosure, the one drawn last first)? [Measurability, Spec
  §FR-R02G1904-006; Clarifications Q1]
- [x] CHK006 Are overlapping targets addressed (a well over its own site, sites near the rim: the one drawn last is
  picked)? [Edge Case, Spec §Edge Cases]

## Scrubber, freeze and preview

- [x] CHK007 Is the scrubber's tick rule stated (round(fraction × ticks swum) along the track; every change a
  `clock.show`)? [Clarity, Spec §Clarifications Q2, Q4]
- [x] CHK008 Is it stated that the preview, the freeze and the shown tick are presentation only (never in the digest),
  and what each freeze state draws? [Consistency, Spec §FR-R02G1904-004, 005; SC-R02G1904-003; Clarifications Q3]

## Camera

- [x] CHK009 Are the orbit bounds, gesture scales, re-basing, reset and refit (5 % margin at aspects 0.4 … 2.5, eye
  outside the box) stated in numbers? [Clarity, Spec §FR-R02G1904-007; Clarifications Q4]
- [x] CHK010 Is the fit stated to hold with the scrubber added (the track at y −1.31 inside the R02-G19-03 box y −1.35
  … 1.0)? [Coverage, Spec §SC-R02G1904-004; Plan §Constraints]

## Finished, cancelled and refused states

- [x] CHK011 Are finished plays, cancelled touches, second fingers and kernel refusals defined (no kernel action, or
  sent and decided by the kernel, with words)? [Coverage, Spec §FR-R02G1904-008; Edge Cases]
- [x] CHK012 Is it stated that the scrubber and the freeze still work on a finished play? [Clarity, Spec
  §Clarifications Q2]

## Accessibility parity and determinism

- [x] CHK013 Is a complete gesture-free path required and achievable within every budget (the panel's one-action
  placement, "Freeze" and "Reset view"; all 100 witnesses won through the panel)? [Measurability, Spec
  §FR-R02G1904-009; SC-R02G1904-005; Clarifications Q5]
- [x] CHK014 Is it stated that only event timestamps are read and every action goes through a declared control?
  [Consistency, Spec §FR-R02G1904-010; Plan §Constitution Check]

## Future device evidence

- [x] CHK015 Are touch feel and latency deferred to after ImplementationLock-100 and marked `{device}`? [Consistency,
  Spec §SC-R02G1904-007]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
