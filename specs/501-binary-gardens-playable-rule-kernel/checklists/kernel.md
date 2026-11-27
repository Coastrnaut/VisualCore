# Requirements Quality Checklist: R02-G21-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 501 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 491's checklist; every item
but CHK006, CHK008 and CHK009 passed at first reading.

## Player impact

- [x] CHK001 Are the player's goal (every garden world keeps a stable comfortable window across the full cycle, never
  stays lethally dim or bright longer than the tolerance, and blooms inside its integrated-flux band) and the player's
  levers (moving each star to a ring, shifting its phase, setting its luminosity, tilting the orbit plane, then
  committing the light window) stated plainly? [Clarity, Spec §US1; Clarifications Q3, Q4, Q5; Assumptions]

## Deterministic invariants

- [x] CHK002 Is every rule decided on integers with stated bounds (two stars, 1 … 5 worlds, 2 … 8 ring radii of
  1 … 40 units, star speed 1 … 3 steps per tick, 1 … 4 luminosity levels of 1 … 64, phases 0 … 47, tilt 0 … T_max with
  T_max 0 … 6, separation 0 … 16, clamp radius 1 … 8, world radius 1 … 60, world speed −4 … 4, flux bounds up to
  200 000 milliflux, tolerance 0 … 12, window 1 … 48, bloom bounds up to 9 600 000, budget 1 … 24, difficulty 1 … 5)?
  [Clarity, Spec §Clarifications Q1 … Q5]
- [x] CHK003 Is the exact geometry defined so two readers compute the same positions (48 phase steps of 7.5°, the
  literal quarter-wave cosine table at scale 1024 with its symmetry rules and S[k] = C[(k + 36) mod 48], the
  non-negative phase law (θ + ω·t) mod 48 and (ψ + ν·t) mod 48, world and star coordinates at scale 2²⁰ with the tilt,
  squared distances at scale 2⁴⁰ within 64 bits, and the exact return of every body after 48 ticks)? [Measurability,
  Spec §FR-R02G2101-003; Clarifications Q1, Q3]
- [x] CHK004 Is the milliflux law defined exactly (scale 1000, ⌊1000·Lᵢ·2⁴⁰ / max(D, r_min²·2⁴⁰)⌋ with one truncating
  division per star, the sum over the two stars, the clamp removing every division by zero, at most 64 000 milliflux
  per star) and is it stated why every device gets the same light? [Clarity, Spec §FR-R02G2101-003; Clarifications Q2;
  Canonical overrides]
- [x] CHK005 Are the five bands of a tick defined as a total function of the flux with ordered bounds
  (0 ≤ λ_lo < c_lo ≤ c_hi < λ_hi ≤ 200 000) and stated membership of each bound? [Clarity, Spec §FR-R02G2101-004;
  Clarifications Q4; Edge Cases]
- [x] CHK006 Is the lethal walk defined completely (ticks 1 … 48 + E, a tick beyond 48 equal to tick t − 48, a run
  across the cycle boundary counted whole) and is it stated which tick a `frozen` or `scorched` failure names beyond
  tick 48 (the walk tick 49 … 48 + E, not the cycle tick)? [Completeness, Spec §FR-R02G2101-005; Clarifications Q4;
  Plan research R7] — failed at first reading: the walk-tick numbering beyond tick 48 was only in research R7, the data model
  and the contract; FR-005 and the edge cases now name the walk tick.
- [x] CHK007 Is a mixed lethal run (lethal low then lethal high with no other tick between) defined as one run, and is
  it stated which reason it fails with (the band of the tick at which the run exceeds the tolerance)? [Clarity, Spec
  §Clarifications Q4; Plan research R7]
- [x] CHK008 Is the judge's order fixed (the lethal walk first, worlds in ascending order at each tick; only without a
  lethal failure, worlds in ascending order and, within one world, `unstable` before `wilted` or `bleached`; otherwise
  won) and is it stated what each failure names? [Consistency, Spec §FR-R02G2101-005; Clarifications Q4; Plan research
  R9] — failed at first reading: the order within one world (window before bloom band) was only in research R9;
  FR-005 now states it.
- [x] CHK009 Are the report's measures defined so two readers report the same values (the cyclic comfortable window
  read with tick 48 followed by tick 1, capped at 48, with its start tick and the choice among equal longest windows;
  the longest lethal run; the integral and its exact mean; the minimum star separation and the tick reported for it)?
  [Measurability, Spec §FR-R02G2101-014; Clarifications Q4, Q5; Plan research R8] — failed at first reading: the window's start tick for equal longest runs, the cyclic lethal run and the
  separation's earliest tick were undefined in the spec; FR-014, research R10 and the data model now define them.
- [x] CHK010 Is the truth metric (per world the flux by tick with each star's share, bands, lethal runs, window,
  integral and mean, bloom result; the minimum separation, first failure and predicted outcome) required after every
  action and excluded from deciding on its own (only the run ends the level)? [Measurability, Spec §FR-R02G2101-005,
  006, 014; Clarifications Q5]
- [x] CHK011 Are the actions defined (ring, phase, luminosity, tilt; each must change the value, act on an adjustable
  control and keep the minimum separation at every tick 0 … 47; each spends one action of a 1 … 24 budget; run spends
  nothing and ends the level; inspecting changes nothing)? [Completeness, Spec §FR-R02G2101-002, 006; Clarifications
  Q3, Q5; Edge Cases]
- [x] CHK012 Are fingerprints, records and replay defined so a trace reproduces every state, is what undo covers (the
  arrangement and actions spent; from failed back to playing with the arrangement before the run; a won level is final)
  stated, and is the puzzle contract (position, moves, goal test) defined? [Completeness, Spec §FR-R02G2101-007, 010;
  Clarifications Q5; Edge Cases]
- [x] CHK013 Is the stored form defined (JSON schema 1 with sorted keys, every level field, fingerprint = SHA-256 of a
  canonical text, a later schema migrating schema 1 forward) with the refusals of a damaged or edited form
  (`malformed`), a newer form (`newer-schema`) and an invalid level (`level`)? [Completeness, Spec §FR-R02G2101-009;
  Clarifications Q5]

## Empty and error states

- [x] CHK014 Are refusals named for an action out of range, on a locked control, unchanged or breaking the separation,
  no action left, wrong stage, staleness and a broken or foreign record chain, and are the failures (frozen, scorched,
  unstable, wilted, bleached) named? [Coverage, Spec §Edge Cases; FR-R02G2101-006, 011; Clarifications Q4, Q5]
- [x] CHK015 Are a star and a world at the same point or inside the clamp radius, flux on each of the four bounds, a
  lethal run exactly at the tolerance, tolerance 0, a run straddling the cycle end, a window exactly W or the whole
  cycle, an integral on a bloom bound and a separation exactly σ addressed? [Edge Case, Spec §Edge Cases; Clarifications
  Q2 … Q4]
- [x] CHK016 Are malformed levels excluded (values out of range or out of order, ring radii or luminosity levels not
  strictly increasing, flux or bloom bounds out of order, no world or more than five, nothing adjustable, starting stars
  breaking the separation at a tick of the cycle, a starting arrangement that wins)? [Edge Case, Spec
  §FR-R02G2101-001; Edge Cases; data-model]
- [x] CHK017 Are the boundaries stated (a lethal bound itself is not lethal; a comfortable bound is comfortable; a run
  of exactly E survives; a window of exactly W holds; an integral on a bloom bound is inside; exactly σ is allowed; a
  spent budget still allows the run)? [Edge Case, Spec §Edge Cases; SC-R02G2101-004]
- [x] CHK018 Is it stated why the run costs no action and why the predicted outcome is reported before it (the
  arrangement determines everything; the run is the commitment of the light window)? [Consistency, Spec
  §Clarifications Q5; Plan research R11]

## Accessibility (colour independence)

- [x] CHK019 Is it required that every star, ring, world, band and measure is available in words and numbers?
  [Coverage, Spec §FR-R02G2101-013; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK020 Is it stated that the design is the project's own, the code original, no star catalogue or third-party
  data used, and the cosine table derived from its own definition? [Consistency, Spec §Assumptions; Clarifications Q1;
  Plan Constitution Check X]
- [x] CHK021 Is it stated that nothing is drawn in this feature and that the signature shader's numerical gravitation
  is presentation, not judged state? [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK022 Is it stated that drawing, layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK023 Are host-test sizes, the independent recomputation (a second implementation of the geometry, milliflux,
  bands, walk, window and judge) and the boundary cases (each flux bound, the clamp radius, the tolerance also across the
  cycle boundary, a window one tick short, each bloom bound, the separation) stated? [Measurability, Spec
  §SC-R02G2101-001 … 006; Plan]

## Future D1/D2/D3 evidence

- [x] CHK024 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
