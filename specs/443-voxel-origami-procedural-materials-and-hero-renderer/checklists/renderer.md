# Requirements Quality Checklist: R02-G15-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 443 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 433's checklist. CHK007
failed at first reading (two elements at the same distance from the eye had no stated order, so a frame check could
depend on the sort); clarification Q1 now breaks ties by kind, then index, and the item passes.

## Player impact

- [x] CHK001 Is it stated what a player sees (frosted-ivory chamfered cubes with glyphs and dots, hinge bars with the
  chosen hinge striped hot pink, the turquoise target outline at the best alignment, covered pips and moves bars) and how
  each drawn element maps to a kernel value (cells, orientations, quarter turns, the covered alignment, the shape report,
  actions left)? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the drawn cubes sit in the kernel's cells; tier, time and failures
  never change state, digest or verdict)? [Completeness, Spec §FR-R02G1503-003; SC-R02G1503-002]
- [x] CHK003 Is every placement (the mapping w(c) = (c − m) · s with s = 1.5 / (e + 1), cube side, target edge, hinge
  bar size, pips, bars, camera eye, target and box) given in numbers? [Clarity, Spec §Clarifications Q1, Q2]
- [x] CHK004 Does the camera box include everything a level can show (the chain and target within ±0.75 of the box
  centre by the scale rule, pips at y −1.05, bars at −1.2 … −1.22)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to bevel steps, edge thickness and glow, with cubes, glyphs, dots, hinge marks, target
  outline, gauges and positions identical at every tier? [Consistency, Spec §FR-R02G1503-004; Clarifications Q2]
- [x] CHK006 Is it stated which hinge is chosen (the first that can turn at opening, the panel's choice after, outside
  the digest) and where the target is drawn (the covered count's best alignment), so frame checks are reproducible?
  [Clarity, Spec §Clarifications Q1, Q5]
- [x] CHK007 Is the drawing order and depth use stated (depth testing off; back to front by camera distance with a tie
  rule; glow additive and last)? [Consistency, Spec §Clarifications Q1]

## Empty and error states

- [x] CHK008 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK009 Are adapter refusals defined for out-of-range and out-of-stage actions, a hinge the level lacks, and restore
  refusals? [Coverage, Spec §Clarifications Q5]
- [x] CHK010 Is a failure shown distinctly (the moving cube and the cube in its way outlined, the meeting cell marked,
  the reason named)? [Edge Case, Spec §Edge Cases; Clarifications Q4]
- [x] CHK011 Are points near elements drawn after them excluded from the frame checks by a stated rule? [Measurability,
  Spec §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK012 Do cubes (dots, inner glyph solid or hollow), the chosen hinge (stripes), the target (wireframe) and the two
  gauges each have a non-colour cue? [Coverage, Spec §Edge Cases; research R5]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G1503-001; Assumptions]
- [x] CHK014 Is the triangle budget of the largest scene (12 chamfered cubes at level-0, 12 target wireframes) bounded so
  code-only geometry is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK015 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK016 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec
  §Clarifications Q3; SC-R02G1503-001]

## Future D1/D2/D3 evidence

- [x] CHK017 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100?
  [Completeness, Spec §SC-R02G1503-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
