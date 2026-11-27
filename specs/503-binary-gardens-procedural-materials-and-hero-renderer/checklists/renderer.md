# Requirements Quality Checklist: R02-G21-03 procedural materials and hero renderer

**Purpose**: Unit tests for the renderer requirements (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 493's checklist. Seven
items failed at first reading: CHK002 (the caps were "reaching latitude ±30°" and "at ±60°", which reads either as caps
ending at those latitudes or as caps covering every latitude beyond them; research R6 decided the latter, the spec did
not say it), CHK008 (the shown tick was given at opening only; what ring, phase, luminosity, tilt, run, undo, redo,
`level.next`, reset and restore do to it was left to research R12), CHK009 (with depth testing off and no face culling,
a cube-sphere's own faces need an order; research R4 emits them far-first, the spec did not), CHK010 (the plan narrows
`BinaryGardensInvariantTests` to a fixed list of kernel files, but FR-R02G2103-009 required existing tests to pass
unchanged except the next-candidate test, so the spec forbade the change the plan makes), CHK012 (unstable marked "the
world's window bracket", which does not exist when no tick is comfortable; research R11 draws and marks the
required-length tick alone), CHK013 (`clock.show` refused "a tick outside 1 … 48" with `r02-g21.tick`, but with no
declared range wider than 1 … 48 the engine's standard refusal pre-empts the adapter's code; research R12 declares
0 … 60 and refuses 0 and 49 … 60) and CHK020 (the world-centre check of 0.15 over the backdrop was not shown achievable
for a world on its night side or with a small share; research R5 keeps an ambient floor of 0.35, the spec did not
state it). The spec now carries the fixes and they pass.

## Player impact

- [x] CHK001 Is it stated what a player sees (the starfield backdrop, the tilt dial, the star rings and world orbits,
  the trails, the two star discs with cores, coronas and luminosity pips, the cube-sphere worlds with their pips, the
  gauge rows with tick cells, guide lines, window bracket, tick marker and bloom meter, and the actions bars) and how
  each drawn element maps to a kernel value (positions, shares and band at the shown tick, flux per tick, longest window
  and its start, integral, tilt, luminosity, actions left)? [Clarity, Spec §US1; Clarifications Q1]
- [x] CHK002 Is the shader-only seasonal banding defined unambiguously, every cap and belt as a latitude range of the
  sphere normal (lethal low caps |φ| ≥ 30°, dim caps |φ| ≥ 60°, bright belt |φ| ≤ 15°, lethal high belt |φ| ≤ 40°)?
  [Clarity, Spec §Clarifications Q1; research R6] — fails: "reaching latitude ±30°" and "at ±60°" do not say which side
  of the latitude the cap covers. Fixed in the spec on 2026-11-27.

## Deterministic invariants

- [x] CHK003 Is renderer purity stated (snapshot only; positions, shares, bands, windows and integrals at the kernel's
  values; tier, time, shown tick and failures never change state, digest or verdict)? [Completeness, Spec
  §FR-R02G2103-003; SC-R02G2103-002]
- [x] CHK004 Is every drawn position, share, band, flux, window and integral required to be the kernel's integer value
  at the shown tick, with nothing interpolated between ticks and every body on a vertex of its 48-gon orbit through the
  kernel's table points? [Consistency, Spec §FR-R02G2103-003; Clarifications Q1; research R2, R3]
- [x] CHK005 Does the camera box include everything a level can show (bodies within the fitted disc of radius 0.95, a
  star at the largest tilt at most 0.68 above or below the plane plus its disc, the tilt dial from (−1.15, 1.08), the
  gauge plate to x = 1.22, five gauge rows down to y = −1.6 and the actions bars down to y = −1.73)? [Consistency, Spec
  §Clarifications Q1; Edge Cases; research R10]
- [x] CHK006 Is every placement (the fit scale k = 0.95 / R, orbit vertices, world and star radii, tilt dial pips,
  gauge rows, plate, cells and cell heights, guide lines, window bracket, tick marker, bloom meter, bars, camera eye,
  target and box) given in numbers? [Clarity, Spec §Clarifications Q1]
- [x] CHK007 Are tiers limited to cube-sphere tessellation, corona rays, trails, motes and glow, with the backdrop,
  starfield, tilt dial, rings, orbits, body positions and sizes, banding, pips, gauges, bars and colours identical at
  every tier? [Consistency, Spec §FR-R02G2103-004; Clarifications Q2]
- [x] CHK008 Is it stated which tick is shown (48 at opening, the panel's choice after, kept across ring, phase,
  luminosity, tilt, run, undo and redo, back to 48 at an opening, `level.next`, reset and restore, outside the digest,
  never advanced by time), so frame checks and scenarios are reproducible? [Clarity, Spec §Clarifications Q1, Q5;
  research R12] — fails: only the opening value and "never advanced by time" are stated. Fixed in the spec on 2026-11-27.
- [x] CHK009 Is the drawing order and depth use stated (painter's order with depth testing off and no face culling;
  a fixed order by kind; bodies back to front by eye distance with ties worlds first, then index; a cube-sphere's faces
  far-first from the fixed eye; glow additive and last)? [Consistency, Spec §Clarifications Q1; research R4] — fails:
  nothing orders a world's own faces, so without depth or culling its far side could cover its near side. Fixed in the spec on 2026-11-27.
- [x] CHK010 Is it stated that the kernel's invariant scans (no clock, floating point or run-time trigonometry; allowed
  imports) read a fixed list of the kernel's files, so the presentation sources (shaders with `sin(`/`cos(`, adapter
  with `clock.show`) neither trip nor weaken them, and does FR-R02G2103-009 permit that one test change? [Consistency,
  Spec §FR-R02G2103-009; Plan §Technical Context; research R13] — fails: the spec names no file list, and
  FR-R02G2103-009 allows only the next-candidate test to change. Fixed in the spec on 2026-11-27.

## Empty and error states

- [x] CHK011 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK012 Is a failure shown distinctly for every failure kind (frozen or scorched: the named world's broken ring
  and its gauge cell at column ((tick − 1) mod 48) + 1; unstable: the window bracket, or the required-length tick alone
  when the window is 0; wilted or bleached: the bloom meter marker; the reason named)? [Edge Case, Spec §Edge Cases;
  Clarifications Q4; research R11] — fails: with window 0 there is no bracket to mark. Fixed in the spec on 2026-11-27.
- [x] CHK013 Are adapter refusals defined for out-of-range and out-of-stage actions, non-whole numbers, a shown tick
  outside 1 … 48 (declared range 0 … 60, so 0 and 49 … 60 reach the adapter and are refused with `r02-g21.tick`), and
  restore refusals? [Coverage, Spec §Clarifications Q5; research R12] — fails: no declared ranges are stated, so a
  declaration of 1 … 48 would make the engine refuse first and `r02-g21.tick` unreachable. Fixed in the spec on 2026-11-27.
- [x] CHK014 Are points near elements drawn after them excluded from the frame checks by a stated rule that cannot empty
  a check (at least one world and one star checked in every frame), and is the backdrop checked robustly (median of a
  9 × 9 corner patch the sparse starfield cannot move)? [Measurability, Spec §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK015 Do the stars (position, ring, pips; luminosity by disc size and filled pips), the worlds' bands (caps,
  belt, flowers), gauge cells (height and crossed, hollow or solid shape), the window (solid or dashed bracket), the
  bloom (bracket with marker), world ↔ gauge row (pips), tilt (dial and drawn plane) and actions (bars) each have a
  non-colour cue? [Coverage, Spec §Edge Cases; research R9]

## Source licence and code-only graphics

- [x] CHK016 Is it stated that all geometry and shading are original code with no image assets, and that trails,
  coronas, motes and glow carry no rule meaning? [Consistency, Spec §FR-R02G2103-001, 004; Assumptions; research R8]
- [x] CHK017 Is the triangle budget of the largest scene (5 worlds of 6 · 8² quads, 2 stars with 12 rays, 8 rings of
  48 dashes, 5 orbits, trails of 8 ticks × 7 bodies, motes, 5 gauge rows of 48 cells, 24 bars, 7 tilt pips) bounded so
  code-only geometry is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK018 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof and future device evidence

- [x] CHK019 Are the frame-check thresholds (world centre over backdrop 0.15, star centre 0.4, actions bar red over
  blue 0.08, gauge plate margin 0.05, backdrop 0.06), the shown tick of the check frames (24) and the 5 levels × 3 tiers
  stated? [Measurability, Spec §Clarifications Q3; SC-R02G2103-001]
- [x] CHK020 Is the world-centre threshold achievable for every world whatever its band and shares at the shown tick
  (an ambient floor of 0.35 of the surface colour; the centre seen from the fixed eye lying outside both belts)?
  [Measurability, Spec §Clarifications Q1, Q3; research R5] — fails: a world lit faintly or from behind has no stated
  minimum brightness, so the 0.15 bound could fail on a correct render. Fixed in the spec on 2026-11-27.
- [x] CHK021 Are device frame-time measurements deferred to after ImplementationLock-100 and marked `{device}`?
  [Consistency, Spec §SC-R02G2103-006]

## Registration and scenarios

- [x] CHK022 Are the candidate's registration contents (capabilities of at most 40 characters, tier names, palette,
  scenario manifest path, no permissions, summary of at most 300 characters, content facts of 100 levels and the pinned
  digest) and the 80 acceptance scenarios R2-G21-QA-001 … 080 specified, with availability withheld until X-R02-G21?
  [Completeness, Spec §Clarifications Q5; Assumptions; FR-R02G2103-008]

## Notes

- `/speckit-implement` reads these markers; it does not change them.
