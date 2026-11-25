# Requirements Quality Checklist: R02-G16-03 procedural materials and hero renderer

**Purpose**: Unit tests for the renderer requirements (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 443's checklist. CHK010
failed at first reading (a departure, arrival or deadline failure names no corridor, and the failed leg is not among the
play's flown legs, so "the failing corridor" was undefined); clarification Q4 now recomputes the failing leg through the
chart from the last record's action, and the item passes.

## Player impact

- [x] CHK001 Is it stated what a player sees (the turning firmament, pearl stars with notched rings, corridors with
  undrawn symbol strokes dashed, striped hazard tubes, meteor-gold trails, the sapphire ship, the beacon and chosen
  rings, the cartouche and the gauges) and how each drawn element maps to a kernel value (positions at the beat, flown
  legs, drawn strokes, hazards' intervals, actions left, beat and deadline)? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the drawn stars sit at the kernel's positions for the beat; tier,
  time, firmament turn and failures never change state, digest or verdict)? [Completeness, Spec §FR-R02G1603-003;
  SC-R02G1603-002]
- [x] CHK003 Is every placement (the mapping w(v) = (v − m) · s with s = 1.5 / (e + 1), star radius, ribbon widths,
  ring radii, ship length, cartouche, bars, track, pips, camera eye, target and box) given in numbers? [Clarity, Spec
  §Clarifications Q1, Q2]
- [x] CHK004 Does the camera box include everything a level can show (the chart within ±0.75 of the box centre by the
  scale rule plus at most 0.14 for the ship or rings, the cartouche at x −0.75 … −0.25 and y −1.45 … −0.95, the gauges
  at x 0 … 0.9 and y −1.05 … −1.35)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to sphere detail, trail ghosts and glow, with stars, corridors, hazards, trails, ship,
  rings, cartouche, gauges and positions identical at every tier? [Consistency, Spec §FR-R02G1603-004; Clarifications
  Q2]
- [x] CHK006 Is it stated which destination and wait are chosen (the other end of the lowest-index corridor from the
  start with wait 0 at opening, the panel's choice after, outside the digest), so frame checks are reproducible?
  [Clarity, Spec §Clarifications Q1, Q5]
- [x] CHK007 Is the drawing order and depth use stated (depth testing off; back to front by camera distance with a tie
  rule by kind then index; glow additive and last)? [Consistency, Spec §Clarifications Q1]
- [x] CHK008 Are the moving parts stated as presentation only (the firmament's turn of 0.02 rad/s and the ship's 0.5 s
  glide), with frame checks at time 0? [Clarity, Spec §Clarifications Q1, Q3]

## Empty and error states

- [x] CHK009 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK010 Is a failure shown distinctly for every failure kind (the failing leg in the broken colour, the star,
  hazard, stray stroke, beat track or actions bars marked, the reason named)? [Edge Case, Spec §Edge Cases;
  Clarifications Q4]
- [x] CHK011 Are adapter refusals defined for out-of-range and out-of-stage actions, a star the level lacks, the ship's
  own star, a wait outside 0 … 8, and restore refusals? [Coverage, Spec §Clarifications Q5]
- [x] CHK012 Are points near elements drawn after them excluded from the frame checks by a stated rule, and is the
  speckled backdrop checked robustly (median of a 9 × 9 patch)? [Measurability, Spec §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK013 Do stars (notches), the ship (arrow), the beacon and the choice (rings), strokes (solid or dashed),
  hazards (stripes) and the gauges each have a non-colour cue? [Coverage, Spec §Edge Cases; research R5]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G1603-001; Assumptions]
- [x] CHK015 Is the triangle budget of the largest scene (12 stars at level-0, 24 corridors, 8 hazards, 7 trails with
  ghosts) bounded so code-only geometry is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK016 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof and future device evidence

- [x] CHK017 Are the frame-check thresholds (star luminance 0.25, ship blue over red 0.08, trail red over blue 0.08,
  actions bar 0.1, backdrop 0.06) and the 5 levels × 3 tiers stated? [Measurability, Spec §Clarifications Q3;
  SC-R02G1603-001]
- [x] CHK018 Are device frame-time measurements deferred to after ImplementationLock-100 and marked `{device}`?
  [Consistency, Spec §SC-R02G1603-006]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
