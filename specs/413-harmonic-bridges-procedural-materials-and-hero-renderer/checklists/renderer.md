# Requirements Quality Checklist: R02-G12-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 413 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23, following feature 403's checklist; failures
were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a player sees (copper island prisms, the start ring and goal star, swinging strings,
  cyan membranes under bridges, sample marks, reached-island glow, step pips, moves gauge) and how each drawn element
  maps to a kernel value (islands, strings and pegs, the report's swings, bridges and reached sets, steps, actions
  left)? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the drawn wave never replaces the kernel's exact swing; tier, time
  and failures never change state, digest or verdict)? [Completeness, Spec §FR-R02G1203-003; SC-R02G1203-002]
- [x] CHK003 Is every placement (island mapping, prism, ring, star, string and membrane widths and heights, marks, pips,
  gauge row and bars, wave shells, ground, camera box) given in numbers? [Clarity, Spec §Clarifications Q1, Q2] —
  corrected 2026-11-23: the pips' extent and size and the wave shells' size were added.
- [x] CHK004 Does the camera box include everything a level can show (islands within ±0.9 by ±0.54, prisms to 0.1 and
  marks to 0.11 high, the pips at z = 0.8 and the gauge at z = 0.95)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to wave shells, string motion and glow, with islands, strings, membranes and positions
  identical at every tier? [Consistency, Spec §FR-R02G1203-004; Clarifications Q2]
- [x] CHK006 Is it stated which step is drawn (cycling every 1.2 s while playing, step 0 at time 0, held under Reduce
  Motion) so frame checks are reproducible? [Clarity, Spec §Clarifications Q1, Q4]
- [x] CHK007 Is the drawing order and depth use stated (depth testing off; flat layers first, then membranes, strings
  and marks, then islands back to front with culling, then pips and gauge; glow additive and last)? [Consistency, Spec
  §Clarifications Q1]

## Empty and error states

- [x] CHK008 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK009 Are adapter refusals defined for out-of-range and out-of-stage actions, and restore refusals? [Coverage,
  Spec §Clarifications Q5]
- [x] CHK010 Is a failure shown distinctly (the broken step's pip and the broken string outlined, the reason named)?
  [Edge Case, Spec §Edge Cases; Clarifications Q4]
- [x] CHK011 Are points near other elements excluded from the frame checks by a stated rule? [Measurability, Spec
  §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK012 Do islands, start, goal, bridges, strings, swings, steps and the gauge each have a non-colour cue? [Coverage,
  Spec §Edge Cases; research R5]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G1203-001; Assumptions]
- [x] CHK014 Is the triangle budget of the largest scene (8 islands, 12 strings at level-0) bounded so code-only geometry
  is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK015 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK016 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec
  §Clarifications Q3; SC-R02G1203-001]

## Future D1/D2/D3 evidence

- [x] CHK017 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100?
  [Completeness, Spec §SC-R02G1203-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK003 failed at first reading; the spec was corrected before the item was judged.
