# Requirements Quality Checklist: R02-G17-03 procedural materials and hero renderer

**Purpose**: Unit tests for the renderer requirements (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 453's checklist. CHK004
failed at first reading: the scale rule boxed only the orbit positions, but a catalog body's radius (up to 4 lattice
units against semi-axes from 3) could put its disc outside the camera box; clarification Q1 now widens the box by each
body's radius in x and y, so every disc lies within ±0.75 of the box centre, and the item passes.

## Player impact

- [x] CHK001 Is it stated what a player sees (the ink-navy sky, ivory planets on notched orbital rings, the crescents
  cut by nearer discs, corona-gold halos, the chosen ring, the timeline with window brackets, event marks and playhead,
  the actions bars) and how each drawn element maps to a kernel value (positions at the shown tick, eclipses under way
  and their classes, the target, the predicted intervals and matched count, actions left)? [Clarity, Spec §US1;
  Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the drawn planets sit at the kernel's positions for the shown
  tick; tier, time, shown tick and failures never change state, digest or verdict)? [Completeness, Spec
  §FR-R02G1703-003; SC-R02G1703-002]
- [x] CHK003 Is the crescent required to equal the overlap the kernel judges (a mask from the kernel's x, y and radius
  scaled by s, drawn only for eclipses the kernel reports under way), rather than a visual overlap under perspective?
  [Consistency, Spec §Clarifications Q1; research R2]
- [x] CHK004 Does the camera box include everything a level can show (every disc within ±0.75 of the box centre by the
  widened scale rule plus at most 0.05 for halos and the chosen ring, the timeline at x −0.9 … 0.9 and y −1.05 …
  −1.15, the bars at y −1.35)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Is every placement (the mapping, ring width, body radius r · s, chosen ring, timeline strip, brackets,
  marks, playhead, bars, camera eye, target and box) given in numbers? [Clarity, Spec §Clarifications Q1]
- [x] CHK006 Are tiers limited to sphere detail and glow, with rings, crescents, halos, timeline, gauges and positions
  identical at every tier (the crescent mask drawn at every tier)? [Consistency, Spec §FR-R02G1703-004;
  Clarifications Q2]
- [x] CHK007 Is it stated which body and tick are shown (the lowest-numbered movable body and tick 0 at opening, the
  panel's choice after, outside the digest, never advanced by time), so frame checks are reproducible? [Clarity, Spec
  §Clarifications Q1, Q5]
- [x] CHK008 Is the drawing order and depth use stated (depth testing off; back to front by camera distance with a tie
  rule by kind then index; glow additive and last)? [Consistency, Spec §Clarifications Q1]

## Empty and error states

- [x] CHK009 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK010 Is a failure shown distinctly for every failure kind (an unwanted or out-of-window event marked at its
  tick, a horizon failure at the strip's end with the next target outlined, the two bodies outlined, the reason
  named)? [Edge Case, Spec §Edge Cases; Clarifications Q4]
- [x] CHK011 Are adapter refusals defined for out-of-range and out-of-stage actions, a body the level lacks, a tick
  outside the horizon, and restore refusals? [Coverage, Spec §Clarifications Q5]
- [x] CHK012 Are points near elements drawn after them excluded from the frame checks by a stated rule, and is the
  speckled backdrop checked robustly (median of a 9 × 9 patch)? [Measurability, Spec §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK013 Do bodies (notches, fixed frames), the choice (dashed ring), events (diamond or cross), windows (brackets)
  and the actions (bars) each have a non-colour cue? [Coverage, Spec §Edge Cases; research R5]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G1703-001; Assumptions]
- [x] CHK015 Is the triangle budget of the largest scene (6 bodies at level-0, 6 rings, up to 15 halos, the timeline
  and 19 bars) bounded so code-only geometry is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK016 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof and future device evidence

- [x] CHK017 Are the frame-check thresholds (body luminance 0.25, actions bar red over blue 0.08, timeline strip 0.1,
  backdrop 0.06) and the 5 levels × 3 tiers stated? [Measurability, Spec §Clarifications Q3; SC-R02G1703-001]
- [x] CHK018 Are device frame-time measurements deferred to after ImplementationLock-100 and marked `{device}`?
  [Consistency, Spec §SC-R02G1703-006]

## Registration and scenarios

- [x] CHK019 Are the candidate's registration contents (capabilities of at most 40 characters, tier names, palette,
  scenario manifest path, no permissions, summary of at most 300 characters, content facts of 100 levels and the pinned
  digest) and the 80 acceptance scenarios R2-G17-QA-001 … 080 specified, with availability withheld until X-R02-G17?
  [Completeness, Spec §Clarifications Q5; Assumptions; FR-R02G1703-008]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
