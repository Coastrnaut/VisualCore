# Requirements Quality Checklist: R02-G13-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 423 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23, following feature 413's checklist; every item
passed at first reading.

## Player impact

- [x] CHK001 Is it stated what a player sees (star-white stars with phase hands, silver links turning teal, plum guides,
  broken links, the coherence, hold and moves gauges) and how each drawn element maps to a kernel value (stars, rates
  and phases, the links, the symbol, the listen report's phases, snaps and coherence, actions left)? [Clarity, Spec
  §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the drawn pulse never replaces the kernel's phases; tier, time and
  failures never change state, digest or verdict)? [Completeness, Spec §FR-R02G1303-003; SC-R02G1303-002]
- [x] CHK003 Is every placement (star mapping, ellipsoid radii and segments, hand length and width, link width and rise,
  guide dashes, broken gap, gauge rows and bars, hold pips, wave shells, sky, camera box) given in numbers? [Clarity,
  Spec §Clarifications Q1, Q2]
- [x] CHK004 Does the camera box include everything a level can show (stars within ±0.77 by ±0.55 at heights
  0.15 ± 0.02 plus hands 0.04 above, the coherence gauge at z = 0.85, the hold pips at z = 1.0 and the moves gauge at
  z = 1.15)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to wave shells, star pulse and glow, with stars, hands, links, guides, gauges and
  positions identical at every tier? [Consistency, Spec §FR-R02G1303-004; Clarifications Q2]
- [x] CHK006 Is it stated which tick is drawn (one tick per 0.25 s, the last held 1 s, looping; tick 0 at time 0 and
  under Reduce Motion) so frame checks are reproducible? [Clarity, Spec §Clarifications Q1, Q4]
- [x] CHK007 Is the drawing order and depth use stated (depth testing off; the sky and flat gauges first, then guides,
  links and hands, then stars back to front with culling; glow additive and last)? [Consistency, Spec §Clarifications Q1]

## Empty and error states

- [x] CHK008 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK009 Are adapter refusals defined for out-of-range and out-of-stage actions, and restore refusals? [Coverage,
  Spec §Clarifications Q5]
- [x] CHK010 Is a failure shown distinctly (the missing pair's guide or the snapped link outlined, the reason named)?
  [Edge Case, Spec §Edge Cases; Clarifications Q4]
- [x] CHK011 Are points near other elements excluded from the frame checks by a stated rule? [Measurability, Spec
  §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK012 Do stars, links, guides, snapped links and the three gauges each have a non-colour cue? [Coverage, Spec
  §Edge Cases; research R5]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G1303-001; Assumptions]
- [x] CHK014 Is the triangle budget of the largest scene (8 stars, 16 links at level-0) bounded so code-only geometry is
  feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK015 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK016 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec
  §Clarifications Q3; SC-R02G1303-001]

## Future D1/D2/D3 evidence

- [x] CHK017 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100?
  [Completeness, Spec §SC-R02G1303-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
