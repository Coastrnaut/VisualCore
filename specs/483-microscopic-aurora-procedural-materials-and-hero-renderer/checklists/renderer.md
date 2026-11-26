# Requirements Quality Checklist: R02-G19-03 procedural materials and hero renderer

**Purpose**: Unit tests for the renderer requirements (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 473's checklist. Two items
failed at first reading: CHK004 (the fronds outside the rim had no stated reach, so the camera box could not be shown
to contain them; clarification Q1 now bounds them at 0.07 beyond the rim, inside x ±1.0) and CHK017 (swimmers drawn
after one another could exclude every swimmer's check point in a bunched swarm, silently; clarification Q3 now states
the index order and that at least one swimmer is checked in every frame). Both now pass.

## Player impact

- [x] CHK001 Is it stated what a player sees (the still water, the dish field and rim, the fronds, the stencil
  outlines, the lit and stray cells, the site rings, the well spirals with sense arrows, the ribbons, the capsule
  swimmers, the coverage and coherence gauges and the actions bars) and how each drawn element maps to a kernel value
  (positions, density, lit cells, stencil, sites, wells, coverage, coherence, actions left)? [Clarity, Spec §US1;
  Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; swimmers and ribbons at the kernel's positions; tier, time, shown
  tick and failures never change state, digest or verdict)? [Completeness, Spec §FR-R02G1903-003; SC-R02G1903-002]
- [x] CHK003 Is every drawn swimmer and ribbon point required to be a kernel position, with nothing interpolated between
  ticks? [Consistency, Spec §Clarifications Q1; research R2]
- [x] CHK004 Does the camera box include everything a level can show (the rim at radius 0.9 and fronds at most 0.07
  beyond it, the gauge rows at y −1.08 and −1.15, the bars at y −1.25, inside x −1.0 … 1.0 and y −1.35 … 1.0)?
  [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Is every placement (the scale, the field and rim, outline and fill sizes, ring and spiral radii, ribbon
  width, capsule size, gauge rows, bars, camera eye, target and box) given in numbers? [Clarity, Spec §Clarifications
  Q1]
- [x] CHK006 Are tiers limited to capsule detail, ribbon length, fronds and glow, with the backdrop, field, rim, cells,
  sites, wells, gauges, colours and positions identical at every tier? [Consistency, Spec §FR-R02G1903-004;
  Clarifications Q2]
- [x] CHK007 Is it stated which tick is shown (0 at opening, the panel's choice after, outside the digest, never advanced
  by time), so frame checks are reproducible? [Clarity, Spec §Clarifications Q1, Q5]
- [x] CHK008 Is the drawing order and depth use stated (depth testing off; a fixed order by kind; glow additive and
  last)? [Consistency, Spec §Clarifications Q1; research R3]

## Empty and error states

- [x] CHK009 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK010 Is a failure shown distinctly for every failure kind (exit: the escaping swimmer and the rim mark;
  coherence: the swimmers outside the largest group; coverage: the unlit stencil outlines; connectedness: the named
  cell; the reason named)? [Edge Case, Spec §Edge Cases; Clarifications Q4]
- [x] CHK011 Are adapter refusals defined for out-of-range and out-of-stage actions, a tick outside the swim, and
  restore refusals? [Coverage, Spec §Clarifications Q5]
- [x] CHK012 Are points near elements drawn after them excluded from the frame checks by a stated rule that cannot
  empty a check, and is the backdrop checked robustly (median of a 9 × 9 corner patch)? [Measurability, Spec
  §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK013 Do stencil cells (outlines), lit cells (fills), sites (rings), wells (spiral turns and arrow), gauges
  (filled or hollow marks with requirement ticks) and actions (bars) each have a non-colour cue? [Coverage, Spec §Edge
  Cases; research R6]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that all geometry and shading are original code with no image assets, and that the fronds are
  decoration only? [Consistency, Spec §FR-R02G1903-001; Assumptions; research R5]
- [x] CHK015 Is the triangle budget of the largest scene (8 swimmers × 64 ribbon points, up to 576 cells, 6 sites, 3
  spirals, 8 capsules of 12 segments, fronds, 2 gauges and 19 bars) bounded so code-only geometry is feasible?
  [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK016 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof and future device evidence

- [x] CHK017 Are the frame-check thresholds (swimmer luminance 0.25, rim 0.1, actions bar blue over green 0.08, coverage
  track 0.1, backdrop 0.06), the shown tick of the check frames, the swimmer order and the 5 levels × 3 tiers stated?
  [Measurability, Spec §Clarifications Q3; SC-R02G1903-001]
- [x] CHK018 Are device frame-time measurements deferred to after ImplementationLock-100 and marked `{device}`?
  [Consistency, Spec §SC-R02G1903-006]

## Registration and scenarios

- [x] CHK019 Are the candidate's registration contents (capabilities of at most 40 characters, tier names, palette,
  scenario manifest path, no permissions, summary of at most 300 characters, content facts of 100 levels and the pinned
  digest) and the 80 acceptance scenarios R2-G19-QA-001 … 080 specified, with availability withheld until X-R02-G19?
  [Completeness, Spec §Clarifications Q5; Assumptions; FR-R02G1903-008]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
