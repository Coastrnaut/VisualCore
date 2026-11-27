# Requirements Quality Checklist: R02-G20-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 492 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 482's checklist; every item
but CHK007 passed at first reading (CHK007 was checked value by value against R02-G20-01's ranges and the extension:
rows 6 … 9 of 6 … 12, columns 6 … 10 of 6 … 14, starting humidity 0 … 200 of 0 … M, D 4 … 12 of 1 … 12, rates 20 … 60
and vent rates 0 … 30 / 120 … 200 of 0 … 200, release 10 … 30 of 1 … 40, grown release up to 80 of r … 80, threshold
800 … 4000 of 100 … 200000, M 1000 … 2000 of 1000 … 10000, T 30 … 40 of 20 … 200, K 6 … 10 of 5 … T, vents 1 … 3 of
0 … 6, slots 2 … 4 of 1 … 6, colonies 2 … 5 of 1 … 6, sites 4 … 6 of 2 … 8, budgets 8 … 19 of the widened 1 … 24).

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be won within its budget, and the stored
  actions are a fewest)? [Clarity, Spec §US1; FR-R02G2002-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (more colonies, narrower bands, more sites, vents and actions
  working together), never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (floor, blocked cells, humidity, D, rates, pod rules,
  colonies, near cells, vents, moonlight, M, T, K, sites, the winning choice by partial shuffles, margins, sensitivity,
  bands from the winning run), with the seed derivation per candidate, the filters and the candidate bound?
  [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the minimality proof defined (every arrangement at a smaller distance judged and none winning), with the
  reason the distance is exact, the search order and the work bound stated? [Measurability, Spec §FR-R02G2002-002;
  Clarifications Q2; research R2]
- [x] CHK005 Is the band loss's role bounded (it orders only the last depth, never which depth is minimal; the plan is
  replayed through the kernel's play; the independent check searches without the loss order)? [Consistency, Spec
  §Clarifications Q2, Q5; research R3]
- [x] CHK006 Is the witness file's content (state digests, fingerprints, terminal report with the ledger totals and the
  colony survival intervals, counterexample with the nearest miss), byte-for-byte check and opt-in regeneration
  defined? [Completeness, Spec §FR-R02G2002-004; Clarifications Q4]
- [x] CHK007 Do the generated values stay inside R02-G20-01's level ranges as extended, and is every kernel change
  additive, with the existing tests it moves named? [Consistency, Spec §Clarifications Q1, Q5; SC-R02G2002-006] —
  failed at first reading: SC-006 said existing tests pass "unchanged", but feature 491's two out-of-range budget cases
  (13) become valid with the widened range; SC-006 now names them moving to 25.
- [x] CHK008 Is the catalog digest's input (fingerprints in manifest order), the progression rule on the witness length
  and the neighbour rule stated, with band plan lengths that keep the band means from falling? [Consistency, Spec
  §FR-R02G2002-005, 007; Clarifications Q1, Q3, Q5]
- [x] CHK009 Is the tie rule for several minimal arrangements stated (the first winning one in the search order), and is
  the witness order (pods in slot and site order, then vents, then the moonlight) stated? [Consistency, Spec §Edge Cases;
  Clarifications Q2; research R6]
- [x] CHK010 Is it stated that the acceptance ranges were measured by a prototype on the real kernel and the real
  manifest before being written down, with the figures and the rejected profiles? [Assumption, Spec §Clarifications
  preamble]

## Empty and error states

- [x] CHK011 Are refusals named for a manifest entry that yields no candidate, for damaged, newer, edited or
  non-replaying witness files, and for a placement off the level's sites? [Coverage, Spec §Edge Cases; Clarifications
  Q1, Q4, Q5]
- [x] CHK012 Are candidates with too few near cells, whose winning run fails, that the level rules refuse, that are
  reducible, that repeat the previous floor and colonies or whose minimal plan is not the band's plan length excluded
  with a deterministic next step? [Edge Case, Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions]

## iPad/iPhone layout

- [x] CHK014 Is it stated that presentation belongs to later features (R02-G20-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK015 Are host-test sizes stated (all 100 levels, the independent search on two levels per band, groups of 5
  under 10 s measured locally)? [Measurability, Spec §SC-R02G2002-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK016 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
- The items were first drafted before `/speckit-checklist` was invoked (a slip of the skill-first rule); the invocation
  then reviewed every item against the spec's clarifications, research and SC-R02G2002-006 and kept all sixteen.
