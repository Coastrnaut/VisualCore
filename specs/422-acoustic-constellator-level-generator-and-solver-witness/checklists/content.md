# Requirements Quality Checklist: R02-G13-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 422 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23, following feature 412's checklist.

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be won within its budget, and the stored
  plan is a smallest one)? [Clarity, Spec §US1; FR-R02G1302-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (more stars, more missing links, a cycle, longer windows, finer
  phase work), never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (stars, symbol tree and cycle, base and star rates, starting
  phases, missing pairs, coupling, snap limit, hold, window, derived limits and threshold), with the seed derivation per
  candidate, the filters and the candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the minimality proof defined (missing symbol pairs always included, extra sets in increasing size,
  every smaller set tried and losing), with the option order and work bound stated, and is the reason the pruning is
  complete (opposite nudges cancel, unlinking is never useful) given? [Measurability, Spec §FR-R02G1302-002;
  Clarifications Q2]
- [x] CHK005 Is the witness file's content (state digests, fingerprints, counterexample), byte-for-byte check and
  opt-in regeneration defined? [Completeness, Spec §FR-R02G1302-004; Clarifications Q4]
- [x] CHK006 Is the catalog digest's input (fingerprints in manifest order) and the progression rule on the witness
  action count stated, with band ranges that keep it? [Consistency, Spec §FR-R02G1302-005; Clarifications Q3, Q5]
- [x] CHK007 Do the generated values stay inside R02-G13-01's level ranges (stars 3 … 8, symbol pairs at most 8 of 10,
  fixed links ≤ 6 for the largest band: symbol up to 8 pairs minus 3 missing = 5, K 2 … 8 within 1 … 8, σ 3 … 5 within
  2 … 5, H 4 … 8, W ≤ 48, θ = ⌊3n²/5⌋ within 1 … n², budget 8 … 19 within 1 … 40, at most budget − 1 actions), so the
  kernel is unchanged except for two new refusals? [Consistency, Spec §Clarifications Q1; FR-R02G1302-006]
- [x] CHK008 Is the tie rule for several minimal plans stated in this game's terms (first multiset in option order)?
  [Consistency, Spec §Edge Cases; Clarifications Q2]
- [x] CHK009 Is it stated that the acceptance ranges were measured by a prototype before being written down?
  [Assumption, Spec §Clarifications preamble]

## Empty and error states

- [x] CHK010 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK011 Are candidates already won or needing no action (never: at least one pair is always missing),
  out-of-range plans and over-work candidates excluded with a deterministic next step? [Edge Case, Spec §Edge Cases;
  Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that presentation belongs to later features (R02-G13-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes stated (all 100 levels, the independent brute force on two levels per band, groups of
  5 under 10 s measured locally)? [Measurability, Spec §SC-R02G1302-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
- CHK014 passes on what is written; whether a brute force over every play action at size 5 fits the test budget is
  left to `/speckit-analyze`.
