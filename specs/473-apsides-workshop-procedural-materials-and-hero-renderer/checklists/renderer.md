# Requirements Quality Checklist: R02-G18-03 procedural materials and hero renderer

**Purpose**: Unit tests for the renderer requirements (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 463's checklist. CHK017
failed at first reading: the frame checks rendered at the shown tick 0, where the orbiter sits at the periapsis, which
can be 3 lattice units (0.042 world) from the star, so the star's check point lay within 6 pixels of the orbiter drawn
after it and could have been excluded silently; clarification Q3 now renders at the shown tick T/2 (the apoapsis, at
least 8 lattice units out), and the item passes.

## Player impact

- [x] CHK001 Is it stated what a player sees (the midnight sky, the compass of eight sectors with notched rim and target
  brackets, the swept-area wedges, the ghost loop, the glacial orbit loop, the apsis diamond and square, hatched
  planets, the star, the orbiter, the gauges and the actions bars) and how each drawn element maps to a kernel value
  (positions, shares, apsis readings, planets, targets with readings and met flags, actions left)? [Clarity, Spec §US1;
  Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the orbit loop passes through the kernel's positions; tier, time,
  shown tick and failures never change state, digest or verdict)? [Completeness, Spec §FR-R02G1803-003;
  SC-R02G1803-002]
- [x] CHK003 Is the orbit drawn required to pass through every judged position, with any refinement between ticks
  stated to be presentation only and the judged chords stated to stay the kernel's? [Consistency, Spec
  §Clarifications Q1; research R2]
- [x] CHK004 Does the camera box include everything a level can show (the rim and brackets within radius 0.98, planet
  centres within ±0.9 plus radius and hazard ring under 0.06, gauge rows down to y −1.43, the bars at y −1.55, inside x
  −1.0 … 1.0 and y −1.65 … 1.0)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Is every placement (the scale, the ribbon widths and depths, spokes, rim, notches, brackets, markers,
  planet and star radii, orbiter, gauge rows, bars, camera eye, target and box) given in numbers? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK006 Are tiers limited to sphere detail, orbit refinement and glow, with wedges, compass, ghost loop, markers,
  gauges, colours and positions identical at every tier? [Consistency, Spec §FR-R02G1803-004; Clarifications Q2]
- [x] CHK007 Is it stated which tick is shown (0 at opening, the panel's choice after, outside the digest, never
  advanced by time), so frame checks are reproducible? [Clarity, Spec §Clarifications Q1, Q5]
- [x] CHK008 Is the drawing order and depth use stated (depth testing off; a fixed order by kind; glow additive and
  last)? [Consistency, Spec §Clarifications Q1; research R3]

## Empty and error states

- [x] CHK009 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK010 Is a failure shown distinctly for every failure kind (a contact: the struck planet's ring and the segment;
  an order, share or apsis failure: that target's gauge; the reason named)? [Edge Case, Spec §Edge Cases;
  Clarifications Q4]
- [x] CHK011 Are adapter refusals defined for out-of-range and out-of-stage actions, a tick outside the period, and
  restore refusals? [Coverage, Spec §Clarifications Q5]
- [x] CHK012 Are points near elements drawn after them excluded from the frame checks by a stated rule, and is the
  speckled backdrop checked robustly (median of a 9 × 9 patch)? [Measurability, Spec §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK013 Do sectors (rim notches), target sectors (brackets), apsides (diamond and square), planets (hatched rings),
  gauges (filled or hollow marks) and actions (bars) each have a non-colour cue? [Coverage, Spec §Edge Cases; research
  R5]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G1803-001; Assumptions]
- [x] CHK015 Is the triangle budget of the largest scene (96 ticks of wedges and ribbon, up to 5 spheres at level-0, 6
  gauges and 19 bars) bounded so code-only geometry is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK016 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof and future device evidence

- [x] CHK017 Are the frame-check thresholds (star and orbiter luminance 0.25, actions bar red over blue 0.08, gauge track
  0.1, backdrop 0.06), the shown tick of the check frames and the 5 levels × 3 tiers stated? [Measurability, Spec
  §Clarifications Q3; SC-R02G1803-001]
- [x] CHK018 Are device frame-time measurements deferred to after ImplementationLock-100 and marked `{device}`?
  [Consistency, Spec §SC-R02G1803-006]

## Registration and scenarios

- [x] CHK019 Are the candidate's registration contents (capabilities of at most 40 characters, tier names, palette,
  scenario manifest path, no permissions, summary of at most 300 characters, content facts of 100 levels and the pinned
  digest) and the 80 acceptance scenarios R2-G18-QA-001 … 080 specified, with availability withheld until X-R02-G18?
  [Completeness, Spec §Clarifications Q5; Assumptions; FR-R02G1803-008]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
