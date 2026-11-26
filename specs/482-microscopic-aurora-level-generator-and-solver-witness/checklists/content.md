# Requirements Quality Checklist: R02-G19-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 482 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 472's checklist; every item
but CHK007 passed at first reading (CHK007 was checked value by value against R02-G19-01's ranges and the extension:
enclosure 11 of 6 … 11, swims 120 … 160 of 120 … 480, swarms 4 … 8 of 4 … 16, ρ 2 … 4, σ 1 … ρ, κ 6 … 8, weights,
a_max 4 … 12 and v_max 12 … 24 inside their ranges, stencils 6 … 60 of 4 … 120, thresholds 1 … 3 of 1 … 64, coverage
600 … 1000 of 500 … 1000, coherence 2 … N, sites 3 … 6 of 2 … 8, budgets 8 … 19 of the widened 1 … 24).

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be won within its budget, and the stored
  placements are a fewest)? [Clarity, Spec §US1; FR-R02G1902-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (larger patterns, stricter coverage, more sites and more wells
  working together), never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (swim length, swarm rules, swarm size, centre and drift, each
  swimmer, the sites redrawn until distinct, the winning wells by partial shuffle, the threshold, the stencil and its
  breadth-first trim, the coverage and coherence draws), with the seed derivation per candidate, the filters and the
  candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the minimality proof defined (every set of fewer wells on distinct sites judged and none winning), with
  the reason a setting is reachable exactly when it is such a set, the search order and the work bound stated?
  [Measurability, Spec §FR-R02G1902-002; Clarifications Q2; research R2]
- [x] CHK005 Is the shape loss's role bounded (it orders only the last depth, never which depth is minimal; the plan is
  replayed through the kernel's play; the independent check judges without the loss order)? [Consistency, Spec
  §Clarifications Q2, Q5; research R3]
- [x] CHK006 Is the witness file's content (state digests, fingerprints, terminal report with the density distribution
  and pattern connectivity, counterexample with the nearest miss), byte-for-byte check and opt-in regeneration defined?
  [Completeness, Spec §FR-R02G1902-004; Clarifications Q4]
- [x] CHK007 Do the generated values stay inside R02-G19-01's level ranges as extended, and is every kernel change
  additive, with the one existing test it moves named? [Consistency, Spec §Clarifications Q1; SC-R02G1902-006] —
  failed at first reading: SC-006 said existing tests pass "unchanged", but feature 481's out-of-range budget case (13)
  becomes valid with the widened range; SC-006 now names that case moving to 25.
- [x] CHK008 Is the catalog digest's input (fingerprints in manifest order), the progression rule on the witness length
  and the neighbour rule stated, with band plan lengths that keep the band means from falling? [Consistency, Spec
  §FR-R02G1902-005, 007; Clarifications Q1, Q3, Q5]
- [x] CHK009 Is the tie rule for several minimal settings stated (the first winning set in the search order), and is the
  witness order (slots in site order, distinct sites) stated? [Consistency, Spec §Edge Cases; Clarifications Q2; research
  R5]
- [x] CHK010 Is it stated that the acceptance ranges were measured by a prototype on the real kernel and the real
  manifest before being written down, with the figures and the rejected profile? [Assumption, Spec §Clarifications
  preamble]

## Empty and error states

- [x] CHK011 Are refusals named for a manifest entry that yields no candidate, for damaged, newer, edited or
  non-replaying witness files, and for a placement off the level's sites? [Coverage, Spec §Edge Cases; Clarifications
  Q1, Q4, Q5]
- [x] CHK012 Are candidates whose winning swim escapes or breaks apart, whose lit group is too small, that the level
  rules refuse, that repeat the previous stencil or whose minimal plan is not the band's plan length excluded with a
  deterministic next step? [Edge Case, Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions]

## iPad/iPhone layout

- [x] CHK014 Is it stated that presentation belongs to later features (R02-G19-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK015 Are host-test sizes stated (all 100 levels, the independent enumeration on two levels per band, groups of
  5 under 10 s measured locally)? [Measurability, Spec §SC-R02G1902-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK016 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
