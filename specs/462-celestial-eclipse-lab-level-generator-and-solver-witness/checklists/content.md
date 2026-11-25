# Requirements Quality Checklist: R02-G17-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 462 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 452's checklist; every item
passed at first reading (CHK007 was checked value by value against R02-G17-01's ranges: coordinates at most 8 + 10 = 18,
depth layers −12 … 8 with a tilt of ±1 keeping a gap of at least 2 between neighbouring layers).

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be won within its budget, and the stored
  phase changes are a fewest)? [Clarity, Spec §US1; FR-R02G1702-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (more bodies, longer target sequences, more orbits to phase
  together), never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (body count, depth ranks by a stated shuffle, period,
  centre, semi-axes, direction, tilt, the integer orbit table and its rounding, radius, fixed body, horizon, winning
  phases, target count and windows, bodies moved away), with the seed derivation per candidate, the filters and the
  candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the minimality proof defined (every setting with fewer phase changes judged and none winning), with the
  reason a setting is a phase vector (a later change of a body overrides an earlier one), the search order and the work
  bound stated? [Measurability, Spec §FR-R02G1702-002; Clarifications Q2; research R1]
- [x] CHK005 Is the agreement between the pair-interval table and the kernel's judge required (the plan replayed through
  the kernel's play, whose timeline must agree; the independent check uses the whole-sky timeline)? [Consistency, Spec
  §Clarifications Q2, Q5]
- [x] CHK006 Is the witness file's content (state digests, fingerprints, terminal timeline with visibility classes,
  counterexample), byte-for-byte check and opt-in regeneration defined? [Completeness, Spec §FR-R02G1702-004;
  Clarifications Q4]
- [x] CHK007 Do the generated values stay inside R02-G17-01's level ranges (3 … 6 bodies, periods 4 … 8 of 4 … 24,
  coordinates within −32 … 32, radius 1 … 4 of 1 … 8, horizon 24 … 48 of 8 … 96, targets 1 … 4 of 1 … 6, budgets 8 …
  19 of 1 … 24, every pair depth-ordered), so that no kernel bound changes? [Consistency, Spec §Clarifications Q1]
- [x] CHK008 Is the catalog digest's input (fingerprints in manifest order), the progression rule on the witness length
  and the neighbour rule stated, with band ranges that keep the band means from falling? [Consistency, Spec
  §FR-R02G1702-005, 007; Clarifications Q1, Q3, Q5]
- [x] CHK009 Is the tie rule for several minimal settings stated in this game's terms (the first winning setting in the
  fixed subset and phase order)? [Consistency, Spec §Edge Cases; Clarifications Q2]
- [x] CHK010 Is it stated that the acceptance ranges were measured by a prototype on the real kernel and the real
  manifest before being written down, with the figures? [Assumption, Spec §Clarifications preamble]

## Empty and error states

- [x] CHK011 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q4, Q5]
- [x] CHK012 Are candidates the level rules refuse, whose starting phases already win, with too few events, repeating
  the previous target sequence, with out-of-range plans and over the work bound excluded with a deterministic next
  step? [Edge Case, Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions]

## iPad/iPhone layout

- [x] CHK014 Is it stated that presentation belongs to later features (R02-G17-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK015 Are host-test sizes stated (all 100 levels, the independent enumeration on two levels per band, groups of
  10 under 10 s measured locally)? [Measurability, Spec §SC-R02G1702-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK016 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
