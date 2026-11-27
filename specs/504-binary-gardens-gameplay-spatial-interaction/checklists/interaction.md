# Requirements Quality Checklist: R02-G21-04 gameplay spatial interaction

**Purpose**: Unit tests for the interaction requirements (gesture semantics, picking, star, pip and dial drags, gauge
scrubbing, previews, camera, finished and cancelled states, accessibility parity, determinism, future device evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 494's checklist, after the
items were generated in this skill invocation. At first reading CHK008, CHK009, CHK011, CHK013, CHK015 and CHK017
failed: the spec differs from the committed R02-G21-03 code where the plan's audit (Research §Spec assumptions checked
against the R02-G21-03 code, R5, R9, R10, R11) found it.

## Gesture semantics

- [x] CHK001 Is it stated what a tap on a world, a star, a ring, a luminosity pip row, the tilt dial, a gauge row, the
  system disc and empty space each does, in every stage? [Clarity, Spec §FR-R02G2104-001, 005, 006, 007, 011;
  Clarifications Q2]
- [x] CHK002 Are star drags defined (16 points to start on a star while playing, the mode decided once from the travel
  against the projected tangent and overridden by the locks, the ring and grid-phase targets, one `star.ring` or
  `star.phase` on release when it is a change, nothing otherwise)? [Completeness, Spec §FR-R02G2104-002, 003, 004;
  Clarifications Q3]
- [x] CHK003 Are degenerate cases defined (equal along and across components, a tangent below 0.5 points, ties between
  rings, grid phases and pips, a release on the current value, both locks, T_max = 0, a single luminosity level, g > 1)?
  [Edge Case, Spec §Clarifications Q2, Q3; Edge Cases]
- [x] CHK004 Is the luminosity and tilt drag mapping stated in numbers (start + round(dx / 32), right raises, halves
  away from zero, clamped 0 … levels − 1 or 0 … T_max, sent only when the value differs)? [Clarity, Spec
  §FR-R02G2104-005, 006; Clarifications Q4]
- [x] CHK005 Are the tap, drag and double-tap thresholds given in points and seconds and the same as feature 494's, with
  the step travel and tangent floor as this game's own constants? [Consistency, Spec §FR-R02G2104-012; Clarifications
  Q1, Q5]

## Picking

- [x] CHK006 Is picking analytic and reproducible (pip rows and the dial by projected segment within 12 points, bodies
  by projected radius grown by 12 points, rings by projected 48-gon, gauge rows and the system disc by the cast onto
  z = 0, the one drawn last first)? [Measurability, Spec §FR-R02G2104-009; Clarifications Q1]
- [x] CHK007 Are overlapping targets addressed (a star in front of a world, a pip row over a ring, a pip row before its
  own disc)? [Edge Case, Spec §Edge Cases; Clarifications Q1]
- [x] CHK008 Is it stated that, with an orbit, the luminosity pips, the body sort and every part facing the eye are
  computed from the drawn (orbited) eye, so that picking matches what is drawn? [Consistency, Spec §Clarifications Q1,
  Q4; Plan §Technical Context; Research R9] — Failed at first reading: the spec says the pips are "as the scene geometry gives them" and
  the bodies follow "the scene's back-to-front sort", but the R02-G21-03 geometry builds both for the static authored
  eye (`billboardBasis`, `paintOrder`); Q4 only says meshes are rebuilt when the orbit changes. Fixed in the spec on 2026-11-27.
- [x] CHK009 Is the gauge-row pick region consistent with the drawn plates (0.09 tall at a 0.1 pitch, never overlapping,
  the 0.01 gap between plates empty space)? [Consistency, Spec §Clarifications Q1; Research R11] — Failed at first reading: the spec's
  "the rows' centre lines deciding between neighbours" implies plates that overlap; the drawn plates (y ± 0.045 at a
  0.1 pitch) are disjoint and the gap is not mentioned. Fixed in the spec on 2026-11-27.

## Scrubbing and preview

- [x] CHK010 Is the scrub rule stated (tick = clamp(⌊(x + 0.9) / (1.8 / 48)⌋ + 1, 1, 48) for the cast x, read at
  touch-down, every changed tick a `clock.show`, the bloom meter reading 48, a tap sending the tick only when x ≤ 0.95,
  in any stage)? [Clarity, Spec §FR-R02G2104-007; Clarifications Q2, Q4]
- [x] CHK011 Is the `clock.show` control's declared range stated as the adapter declares it (0 … 60, with 0 and 49 … 60
  refused `r02-g21.tick`), and that gestures send only 1 … 48? [Consistency, Spec §Clarifications (facts); Research
  §Spec assumptions] — Failed at first reading: the spec gives `clock.show [tick]` as "ticks 1 … 48", which is the shown range, not the
  declared range of the R02-G21-03 adapter. Fixed in the spec on 2026-11-27.
- [x] CHK012 Is the preview defined as the kernel's own change rule and report of the changed arrangement, presentation
  only and never in the digest, with what the scene draws for it (ghost star, previewed worlds and gauges, ghost bands)?
  [Consistency, Spec §FR-R02G2104-008; SC-R02G2104-006; Clarifications Q3]
- [x] CHK013 Is it stated that the drawn snapshot the controller reads carries the level's star speed ω and each star's
  ring, phase and luminosity freedoms, which the tangent, the phase targets and the lock overrides need at touch-down?
  [Completeness, Spec §Clarifications Q3, Q5; Key Entities; Research R10] — Failed at first reading: the spec uses ω and the locks in Q3
  and says the controller takes "the drawn snapshot", but only says the snapshot "gains a preview"; the R02-G21-03
  snapshot carries neither ω nor the lock flags, which the plan adds. Fixed in the spec on 2026-11-27.
- [x] CHK014 Is a refused star-drag preview defined (the ghost star in the broken colour at the target, the committed
  report kept, the refusal named in words, the action still sent once on release and its reason code shown)?
  [Coverage, Spec §FR-R02G2104-008; User Story 1 scenario 3; Edge Cases; Clarifications Q3]
- [x] CHK015 Is a refused luminosity or tilt preview defined (where the broken ghost stands, and the order in which the
  kernel's refusals are given)? [Completeness, Spec §Clarifications Q3, Q4; Research R4, R5] — Failed at first reading: Q4 says only that
  these drags preview "like a star drag"; for a luminosity or tilt change there is no target position, so where the
  broken ghost is drawn (at the star with its previewed radius; at both stars at the previewed tilt) and the refusal
  order (the change rule's refusal, then no action left) are found only in the research. Fixed in the spec on 2026-11-27.

## Camera

- [x] CHK016 Are the orbit bounds, gesture scales, re-basing and reset stated in numbers (yaw ±60° about the vertical
  axis through the authored box centre at 90° per view width, pitch −20° … +35° at 60° per view height, a third finger
  re-bases, double tap or "Reset view" returns to orbit (0, 0))? [Clarity, Spec §FR-R02G2104-010, 012; Clarifications
  Q4]
- [x] CHK017 Is the fit margin stated as the code fits it (`fitMargin` 0.06 per side, the refit at every orbit and
  aspect 0.4 … 2.5 using the same value so orbit 0 is the authored camera bit for bit)? [Consistency, Spec
  §Clarifications (facts), Q4; FR-R02G2104-010; SC-R02G2104-004; Research §Spec assumptions, R9] — Failed at first reading: the spec
  states a 5 % margin in four places; the R02-G21-03 code fits with 0.06 per side and the plan's refit uses 0.06 too. Fixed in the spec on 2026-11-27.
- [x] CHK018 Is the fit stated to hold with one box and no camera zoom, and the eye to stay outside the box? [Coverage,
  Spec §Clarifications Q4; Assumptions; Plan §Technical Context; Research R9]

## Finished, cancelled and refused states

- [x] CHK019 Are finished plays, plays not running, cancelled touches, second fingers and kernel refusals defined (no
  kernel action, or sent once and decided by the kernel, with words)? [Coverage, Spec §FR-R02G2104-011; Edge Cases]
- [x] CHK020 Is it stated that scrubbing, inspecting and orbit still work on a finished play? [Clarity, Spec §Edge
  Cases; Clarifications Q2]

## Accessibility parity and determinism

- [x] CHK021 Is a complete gesture-free path required and achievable within every budget (direct ring, luminosity and
  tilt choices, a phase target with "Set phase", "Inspect", "Reset view"; all 100 witnesses won through the panel)?
  [Measurability, Spec §FR-R02G2104-013; SC-R02G2104-005; Clarifications Q5]
- [x] CHK022 Is it stated that only event timestamps are read and every action goes through a declared control?
  [Consistency, Spec §FR-R02G2104-012; Key Entities; Plan §Constitution Check]
- [x] CHK023 Is it stated that no preview, ghost or inspection is carried by hue alone (dashed ghosts, refusals in
  words, the inspected world ringed and its row bracketed)? [Coverage, Spec §FR-R02G2104-015]

## Future device evidence

- [x] CHK024 Are touch feel and latency deferred to after ImplementationLock-100 and marked `{device}`? [Consistency,
  Spec §SC-R02G2104-008]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
