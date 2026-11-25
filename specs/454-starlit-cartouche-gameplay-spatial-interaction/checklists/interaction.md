# Requirements Quality Checklist: R02-G16-04 gameplay spatial interaction

**Purpose**: Unit tests for the interaction requirements (gesture semantics, picking, the time slider and launch
preview, camera, finished and cancelled states, accessibility parity, determinism, future device evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 444's checklist. Every item
passed at first reading; CHK010 was read twice because the ship glides along its newest trail while the stars move to
the launch beat, and the reading holds: the adapter resets the wait to 0 after every leg, so the glide always ends where
the launch preview places the ship.

## Gesture semantics

- [x] CHK001 Is it stated what a tap on a star, on the ship's star, on the slider and on empty space each does, in every
  stage? [Clarity, Spec §FR-R02G1604-001, 002; Clarifications Q2]
- [x] CHK002 Is the double tap defined (same star, 0.35 s, 22 points, only while playing) and what it sends (one
  `route.fly` with the chosen wait)? [Completeness, Spec §FR-R02G1604-001; Clarifications Q2]
- [x] CHK003 Is the ship drag defined (16 points to start, pending destination previewed, release over a star sends one
  `route.fly`, any other release sends nothing)? [Completeness, Spec §FR-R02G1604-004; Clarifications Q4]
- [x] CHK004 Are the tap, drag and double-tap thresholds given in points and seconds and the same as feature 444's?
  [Consistency, Spec §Edge Cases; Assumptions]

## Picking

- [x] CHK005 Is picking analytic and reproducible (projected ring radius 0.098 grown by 8 points, front-most by paint
  order, the ship's star as the ship, the slider box)? [Measurability, Spec §FR-R02G1604-005; Clarifications Q1]
- [x] CHK006 Is a star hidden behind a nearer star addressed (the front-most is picked, as drawn)? [Edge Case, Spec §Edge
  Cases]

## Time slider and launch preview

- [x] CHK007 Is the slider's wait rule stated (nearest pip along the line through pips 0 and 8, clamped 0 … 8, every
  change a `route.choose`)? [Clarity, Spec §Clarifications Q3]
- [x] CHK008 Is the launch preview defined (launch beat L = beat + wait, stars and the ship at L, the preview ribbon to
  the destination at L + travel, its width and colour, only while playing and when a corridor joins them)?
  [Completeness, Spec §FR-R02G1604-003; Clarifications Q3]
- [x] CHK009 Is it stated that the preview is presentation only (never in the digest) and that at wait 0 the picture is
  R02-G16-03's? [Consistency, Spec §FR-R02G1604-003; SC-R02G1604-003]
- [x] CHK010 Is the relation between trails, the ship's glide and the preview stated without contradiction (trails stay
  where flown; the wait resets to 0 after a leg)? [Consistency, Spec §Clarifications Q3; R02-G16-03 Q1, Q5]

## Camera

- [x] CHK011 Are the orbit bounds, gesture scales, re-basing, reset and refit (5 % margin at aspects 0.4 … 2.5, eye
  outside the box) stated in numbers? [Clarity, Spec §FR-R02G1604-006; Clarifications Q4]
- [x] CHK012 Is the fit stated to hold at every launch beat (stars stay on their orbits, inside the R02-G16-03 box)?
  [Coverage, Spec §SC-R02G1604-004; Plan §Constraints]

## Finished, cancelled and refused states

- [x] CHK013 Are finished plays, cancelled touches, second fingers and kernel refusals or failures defined (no kernel
  action, or sent and decided by the kernel, with words)? [Coverage, Spec §FR-R02G1604-007; Edge Cases]

## Accessibility parity and determinism

- [x] CHK014 Is a complete gesture-free path required (the panel with "Reset view") and measured (all 100 witnesses won
  through the panel)? [Measurability, Spec §FR-R02G1604-008; SC-R02G1604-005]
- [x] CHK015 Is it stated that only event timestamps are read and every action goes through a declared control?
  [Consistency, Spec §FR-R02G1604-009; Plan §Constitution Check]

## Future device evidence

- [x] CHK016 Are touch feel and latency deferred to after ImplementationLock-100 and marked `{device}`? [Consistency,
  Spec §SC-R02G1604-007]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
