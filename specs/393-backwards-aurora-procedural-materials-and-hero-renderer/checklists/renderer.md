# Requirements Quality Checklist: R02-G10-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 393 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a player sees (cyan ribbon, lilac ghost trail, checkpoint ticks and rings, kink and tear
  crosses, section band, reversal gauge) and how each drawn element maps to a kernel value (samples, target,
  checkpoints and matches, bends above L, the torn seam, reversals spent and budget)? [Clarity, Spec §US1;
  Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the ribbon drawn is the kernel's samples; tier, time and failures
  never change state, digest or verdict)? [Completeness, Spec §FR-R02G1003-003; SC-R02G1003-002]
- [x] CHK003 Is every placement (x and y of a sample, ribbon height, ghost depth, ticks and rings, crosses, band, gauge
  row, ground depth, trailing layer offsets, camera box) given in numbers? [Clarity, Spec §Clarifications Q1]
- [x] CHK004 Does the camera box include everything a level can show (heights ± 0.6 plus the ribbon, trailing layers
  up to + 0.08, rings, ticks to ± 0.7 and the gauge at −0.85)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to trailing layers, pulses and glow, with samples and positions identical at every tier?
  [Consistency, Spec §FR-R02G1003-004; Clarifications Q2]
- [x] CHK006 Is the drawn path defined from the kernel's samples (a polyline, never a smoothed curve), so frame checks
  can name exact samples? [Clarity, Spec §US2; research R2]
- [x] CHK007 Is the drawing order (layering with depth testing off) stated so the ghost is never hidden by a trailing
  layer? [Consistency, Spec §Clarifications Q1] — corrected 2026-11-22: the order ground, band, trailing layers, ghost,
  ticks, ribbon, rings, crosses, gauge was added.

## Empty and error states

- [x] CHK008 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK009 Are adapter refusals defined for out-of-range and out-of-stage actions, and restore refusals? [Coverage,
  Spec §Clarifications Q5]
- [x] CHK010 Is a tear shown distinctly (a larger cross at the seam, the reversal and seam named)? [Edge Case, Spec
  §Edge Cases; Clarifications Q4]
- [x] CHK011 Are points near markers excluded from the frame checks by a stated rule, for the ghost as well as the
  ribbon? [Measurability, Spec §Clarifications Q3] — corrected 2026-11-22: the 6-pixel rule now covers target points.

## Accessibility (colour independence)

- [x] CHK012 Do checkpoints, matches, sharp bends, the tear, the section and the gauge each have a non-colour cue?
  [Coverage, Spec §Edge Cases; research R4]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G1003-001; Assumptions]
- [x] CHK014 Is the triangle budget of the largest scene (32 samples at level-0) bounded so code-only geometry is
  feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK015 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK016 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec
  §Clarifications Q3; SC-R02G1003-001]

## Future D1/D2/D3 evidence

- [x] CHK017 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100?
  [Completeness, Spec §SC-R02G1003-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK007 and CHK011 failed at first reading; the spec was corrected before the items were judged.
