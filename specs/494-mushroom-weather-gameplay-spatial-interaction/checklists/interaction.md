# Requirements Quality Checklist: R02-G20-04 gameplay spatial interaction

**Purpose**: Unit tests for the interaction requirements (gesture semantics, picking, pod and moon drags, the scrubber,
previews, camera, finished and cancelled states, accessibility parity, determinism, future device evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 484's checklist, after the
items were generated in this skill invocation.

## Gesture semantics

- [x] CHK001 Is it stated what a tap on an empty site, a pod, a vent, the moon, the scrubber, the floor and empty space
  each does, in every stage? [Clarity, Spec §FR-R02G2004-001, 003, 005; Clarifications Q2]
- [x] CHK002 Are pod drags defined (16 points to start on a pod while playing, the nearest site within 24 points or
  removal outside the floor rectangle, the previewed run, one move or removal on release when it is a change, nothing
  otherwise)? [Completeness, Spec §FR-R02G2004-002; Clarifications Q3]
- [x] CHK003 Are degenerate drop points defined (the pod's own site, a site another pod holds, ties between sites, a
  point on the floor near no site, a tap on an empty site with every slot used)? [Edge Case, Spec §Clarifications Q2,
  Q3; Edge Cases]
- [x] CHK004 Is the moon drag's mapping stated in numbers (start + round(−dy / 40), up raises, clamped 0 … 3, sent only
  when the level differs)? [Clarity, Spec §FR-R02G2004-004; Clarifications Q3]
- [x] CHK005 Are the tap, drag and double-tap thresholds given in points and seconds and the same as feature 484's?
  [Consistency, Spec §Edge Cases; Clarifications Q1]

## Picking

- [x] CHK006 Is picking analytic and reproducible (pods, sites, vents and the moon by projected size grown by 12 points,
  the scrubber band of 14 points, the floor as the projected floor rectangle, the one drawn last first)?
  [Measurability, Spec §FR-R02G2004-007; Clarifications Q1]
- [x] CHK007 Are overlapping targets addressed (a pod over its site, a vent over a cell, the moon behind the forest)?
  [Edge Case, Spec §Edge Cases; Clarifications Q1]

## Scrubber and preview

- [x] CHK008 Is the scrubber's geometry and cycle rule stated (a track at y −0.9 from x −0.9 to 0.9; round(fraction ×
  cycles run); every change a `clock.show`, in any stage)? [Clarity, Spec §Clarifications Q1, Q2, Q4]
- [x] CHK009 Is the preview defined as the kernel's own run of the previewed arrangement, presentation only and never in
  the digest, with what the scene draws for it? [Consistency, Spec §FR-R02G2004-006; SC-R02G2004-003; Clarifications
  Q3]

## Camera

- [x] CHK010 Are the orbit bounds, gesture scales, re-basing, reset and refit (5 % margin at aspects 0.4 … 2.5, eye
  outside the box) stated in numbers? [Clarity, Spec §FR-R02G2004-008; Clarifications Q4]
- [x] CHK011 Is the fit stated to hold with the scrubber added (the track at y −0.9 inside feature 493's box y −1.5 …
  1.2)? [Coverage, Spec §SC-R02G2004-004; Plan §Technical Context]

## Finished, cancelled and refused states

- [x] CHK012 Are finished plays, cancelled touches, second fingers and kernel refusals defined (no kernel action, or sent
  and decided by the kernel, with words)? [Coverage, Spec §FR-R02G2004-009; Edge Cases]
- [x] CHK013 Is it stated that the scrubber and orbit still work on a finished play? [Clarity, Spec §Clarifications Q2;
  Edge Cases]

## Accessibility parity and determinism

- [x] CHK014 Is a complete gesture-free path required and achievable within every budget (the panel's one-action
  placement, vent toggles, moonlight − and +, "Reset view"; all 100 witnesses won through the panel)? [Measurability,
  Spec §FR-R02G2004-010; SC-R02G2004-005; Clarifications Q5]
- [x] CHK015 Is it stated that only event timestamps are read and every action goes through a declared control?
  [Consistency, Spec §FR-R02G2004-011; Plan §Constitution Check]

## Future device evidence

- [x] CHK016 Are touch feel and latency deferred to after ImplementationLock-100 and marked `{device}`? [Consistency,
  Spec §SC-R02G2004-007]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
