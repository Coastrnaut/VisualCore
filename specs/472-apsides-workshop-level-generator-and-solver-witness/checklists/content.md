# Requirements Quality Checklist: R02-G18-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 472 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 462's checklist; every item
passed at first reading (CHK007 was checked value by value against R02-G18-01's ranges: periods 24 … 48 of 16 … 96 and
even, planets 0 … 3 of 0 … 6 with radius 1 … 3 of 1 … 8 and centres clipped to −64 … 64, targets 1 … 4 of 1 … 6, bands
inside 0 … 1000 and 0 … 1280 by clipping, budgets 8 … 19 of 1 … 24; sweep sectors are distinct and at most two apsis
targets are of different kinds, so no two targets are identical).

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be won within its budget, and the stored
  tunings are a fewest)? [Clarity, Spec §US1; FR-R02G1802-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (more targets satisfied together, tighter bands, more planets,
  both levers needed), never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (period, winning orbit redrawn until valid, target and
  apsis-target counts, sweep sectors and their half-widths, apsis targets and their half-widths, the order by event
  tick, the planet placement with its tries, the levers moved and the starting orbit), with the seed derivation per
  candidate, the filters and the candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the minimality proof defined (every orbit with fewer levers changed judged and none winning), with the
  reason an orbit is reachable exactly when it differs in at most that many levers, the search order and the work bound
  stated? [Measurability, Spec §FR-R02G1802-002; Clarifications Q2; research R1]
- [x] CHK005 Is the agreement between the apsis pruning and the kernel's judge required (pruning changes only the work;
  the plan replayed through the kernel's play, whose report must agree; the independent check uses the full report with
  no shortcut)? [Consistency, Spec §Clarifications Q2, Q5; research R2]
- [x] CHK006 Is the witness file's content (state digests, fingerprints, terminal report with shares, apsis readings,
  Kepler residual and deviations, counterexample), byte-for-byte check and opt-in regeneration defined? [Completeness,
  Spec §FR-R02G1802-004; Clarifications Q4]
- [x] CHK007 Do the generated values stay inside R02-G18-01's level ranges, so that no kernel bound changes?
  [Consistency, Spec §Clarifications Q1]
- [x] CHK008 Is the catalog digest's input (fingerprints in manifest order), the progression rule on the witness length
  and the neighbour rule stated, with band plan ranges that keep the band means from falling? [Consistency, Spec
  §FR-R02G1802-005, 007; Clarifications Q1, Q3, Q5]
- [x] CHK009 Is the tie rule for several minimal orbits stated in this game's terms (the first winning orbit in the
  fixed depth order), and is the order of a two-tuning witness that passes only valid orbits stated? [Consistency, Spec
  §Edge Cases; Clarifications Q2; research R5]
- [x] CHK010 Is it stated that the acceptance ranges were measured by a prototype on the real kernel and the real
  manifest before being written down, with the figures? [Assumption, Spec §Clarifications preamble]

## Empty and error states

- [x] CHK011 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q4, Q5]
- [x] CHK012 Are candidates whose planets cannot be placed, whose starting orbit is invalid, equal to the winning one or
  already winning, repeating the previous targets, with out-of-range plans and over the work bound excluded with a
  deterministic next step? [Edge Case, Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions]

## iPad/iPhone layout

- [x] CHK014 Is it stated that presentation belongs to later features (R02-G18-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK015 Are host-test sizes stated (all 100 levels, the independent enumeration on two levels per band, groups of
  10 under 10 s measured locally)? [Measurability, Spec §SC-R02G1802-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK016 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
