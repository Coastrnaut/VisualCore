# Requirements Quality Checklist: R02-G20-03 procedural materials and hero renderer

**Purpose**: Unit tests for the renderer requirements (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 483's checklist. One item
failed at first reading: CHK004 (the camera box was given in x and y only, but under the tilted camera the stalks, caps
and vents stand above the floor; clarification Q1 now adds z 0 … 0.3, the tallest element being a vent at 0.9 s ≤
0.24). It now passes.

## Player impact

- [x] CHK001 Is it stated what a player sees (the midnight backdrop and moon, the floor, logs and stones, fronds, the
  mist, site rings, stalks and caps with band rings, pods and droplets, vents, the colony gauges and the actions bars)
  and how each drawn element maps to a kernel value (humidity at the shown cycle, bands and runs, pods and growth,
  sites, vents, moonlight, actions left)? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the mist, caps and gauges at the kernel's values; tier, time,
  shown cycle and failures never change state, digest or verdict)? [Completeness, Spec §FR-R02G2003-003; SC-R02G2003-002]
- [x] CHK003 Is every drawn humidity value required to be the kernel's integer value at the shown cycle, with nothing
  interpolated between cycles? [Consistency, Spec §Clarifications Q1; research R2]
- [x] CHK004 Does the camera box include everything a level can show (the floor within x ±0.9 and y ±0.8, the moon to
  x 1.27 and y 1.17, fronds at most 0.3 s beyond the floor, the gauge rows down to y −1.35, the bars down to y −1.49,
  and heights up to 0.3)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Is every placement (the fit scale, cell squares, logs and stones, mist sizes, ring radii, stalk and cap
  sizes, pod sizes, vent frames, gauge rows, bars, moon, camera eye, target and box) given in numbers? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK006 Are tiers limited to lathe detail, droplets, fronds, motes and glow, with the backdrop, moon, floor, mist,
  sites, vents, gauges, colours and positions identical at every tier? [Consistency, Spec §FR-R02G2003-004;
  Clarifications Q2]
- [x] CHK007 Is it stated which cycle is shown (0 at opening, the panel's choice after, outside the digest, never
  advanced by time), so frame checks are reproducible? [Clarity, Spec §Clarifications Q1, Q5]
- [x] CHK008 Is the drawing order and depth use stated (depth-tested solids; a fixed order by kind for the flats; glow
  additive and last)? [Consistency, Spec §Clarifications Q1; research R3]

## Empty and error states

- [x] CHK009 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK010 Is a failure shown distinctly for every failure kind (dried: the wilted cap and broken band ring; mold: the
  broken patch on the named cell; unstable: the named colony's broken gauge marker and run bar; the reason named)?
  [Edge Case, Spec §Edge Cases; Clarifications Q4]
- [x] CHK011 Are adapter refusals defined for out-of-range and out-of-stage actions, a cycle outside the run, and
  restore refusals? [Coverage, Spec §Clarifications Q5]
- [x] CHK012 Are points near elements drawn after them excluded from the frame checks by a stated rule that cannot empty
  a check (at least one cap checked in every frame), and is the backdrop checked robustly (median of a 9 × 9 corner
  patch)? [Measurability, Spec §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK013 Do colonies (band rings, solid or dashed), the mist (size as well as shade), vents (open or flat slats),
  blocked cells (log or stone shapes), pods (orb, second ring once grown), gauges (bracket, marker, run bar), the moon
  (phase ticks) and actions (bars) each have a non-colour cue? [Coverage, Spec §Edge Cases; research R6]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that all geometry and shading are original code with no image assets, and that fronds,
  droplets and motes are decoration only? [Consistency, Spec §FR-R02G2003-001; Assumptions; research R5]
- [x] CHK015 Is the triangle budget of the largest scene (168 cells, 6 colonies, 6 pods, 3 vents, droplets, motes,
  fronds, 6 gauge rows and 24 bars) bounded so code-only geometry is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK016 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof and future device evidence

- [x] CHK017 Are the frame-check thresholds (cap luminance over moss 0.2, moon 0.1, actions bar red over blue 0.08,
  gauge track 0.1, backdrop 0.06), the shown cycle of the check frames and the 5 levels × 3 tiers stated?
  [Measurability, Spec §Clarifications Q3; SC-R02G2003-001]
- [x] CHK018 Are device frame-time measurements deferred to after ImplementationLock-100 and marked `{device}`?
  [Consistency, Spec §SC-R02G2003-006]

## Registration and scenarios

- [x] CHK019 Are the candidate's registration contents (capabilities of at most 40 characters, tier names, palette,
  scenario manifest path, no permissions, summary of at most 300 characters, content facts of 100 levels and the pinned
  digest) and the 80 acceptance scenarios R2-G20-QA-001 … 080 specified, with availability withheld until X-R02-G20?
  [Completeness, Spec §Clarifications Q5; Assumptions; FR-R02G2003-008]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
