# Requirements Quality Checklist: R02-G14-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 433 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 423's checklist. CHK004
failed at first reading (a gear shifted with its shadow could leave the camera box, and the lamp at its top height sat
above it); the spec and research were corrected (gears stay at their centre cells, the lamp rises 0.03 per height) and
the item then passed.

## Player impact

- [x] CHK001 Is it stated what a player sees (translucent gold gears with blades, ink shadows on the paper wall, the
  target outline, forbidden marks, the lamp, key-frame cards, alignment pips and moves bars) and how each drawn element
  maps to a kernel value (gears, phases at the shown key frame, the lamp height, the cast, target and forbidden cells,
  the run report, actions left)? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the drawn shadows are the kernel's cast cells; tier, time and
  failures never change state, digest or verdict)? [Completeness, Spec §FR-R02G1403-003; SC-R02G1403-002]
- [x] CHK003 Is every placement (wall plane and cell size, shadow squares, outlines, marks, gear depth planes, rim
  radius, tooth height and count, notch, spokes, lamp and ladder, cards, pips, bars, backdrop, camera box) given in
  numbers? [Clarity, Spec §Clarifications Q1, Q2]
- [x] CHK004 Does the camera box include everything a level can show (wall rows within y 0.05 … 1.25, gear centres in
  rows 2 … H − 5 with rims of 3.4 cells, the lamp at most at y 1.44 plus its radius, cards at y −0.18, pips at −0.30,
  bars at −0.40)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to outline segments, the soft shadow edge and glow, with gears, shadow cells, targets,
  marks, gauges and positions identical at every tier? [Consistency, Spec §FR-R02G1403-004; Clarifications Q2]
- [x] CHK006 Is it stated which key frame is drawn (key frame 0 at opening, the panel's choice after, outside the
  digest) and at which phases the gears are drawn, so frame checks are reproducible? [Clarity, Spec §Clarifications Q1,
  Q5]
- [x] CHK007 Is the drawing order and depth use stated (depth testing off; backdrop, wall, shadows, outlines and marks
  first, then gears deepest first, then lamp and gauges; glow additive and last)? [Consistency, Spec §Clarifications Q1]

## Empty and error states

- [x] CHK008 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK009 Are adapter refusals defined for out-of-range and out-of-stage actions, a key frame the level lacks, and
  restore refusals? [Coverage, Spec §Clarifications Q5]
- [x] CHK010 Is a failure shown distinctly (the jammed pair's teeth, the forbidden cell or the failing key frame's card
  outlined, the reason named)? [Edge Case, Spec §Edge Cases; Clarifications Q4]
- [x] CHK011 Are points near other elements excluded from the frame checks by a stated rule? [Measurability, Spec
  §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK012 Do gears, shadow cells, targets, missing and stray cells, forbidden cells, the lamp and the three gauges
  each have a non-colour cue? [Coverage, Spec §Edge Cases; research R5]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G1403-001; Assumptions]
- [x] CHK014 Is the triangle budget of the largest scene (5 gears of 20 teeth at level-0, 384 wall cells) bounded so
  code-only geometry is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK015 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK016 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec
  §Clarifications Q3; SC-R02G1403-001]

## Future D1/D2/D3 evidence

- [x] CHK017 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100?
  [Completeness, Spec §SC-R02G1403-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
