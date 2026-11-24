# Requirements Quality Checklist: R02-G16-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 452 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 442's checklist; every item
passed at first reading.

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be won within its budget, and the stored
  route is a shortest one)? [Clarity, Spec §US1; FR-R02G1602-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (more stars, longer symbols, more timing to plan), never faster
  reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (star count, glyph points with their redraw, orbits, range,
  start, route with its draw bound, decoys, hazards with their drop rule, deadline, windows by emphasis), with the seed
  derivation per candidate, the filters and the candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the minimality proof defined (every state reachable in fewer legs reached and none winning), with the
  state (star, beat, strokes), the expansion order, state merging and work bound stated, and is the reason time must be
  part of the state given? [Measurability, Spec §FR-R02G1602-002; Clarifications Q2; research R1]
- [x] CHK005 Is the witness file's content (state digests, fingerprints, counterexample), byte-for-byte check and
  opt-in regeneration defined? [Completeness, Spec §FR-R02G1602-004; Clarifications Q4]
- [x] CHK006 Is the catalog digest's input (fingerprints in manifest order) and the progression rule on the witness leg
  count stated, with band ranges that keep it? [Consistency, Spec §FR-R02G1602-005; Clarifications Q3, Q5]
- [x] CHK007 Do the generated values stay inside R02-G16-01's level ranges (5 … 10 stars, coordinates −5 … 5, range
  6 … 8, at most 24 corridors and 8 hazards, windows by beat 64, deadline at most 64, symbols of at most 7 strokes), with
  the one stated change (budgets 1 … 24 for the manifest's 8 … 19)? [Consistency, Spec §Clarifications Q1;
  FR-R02G1602-007]
- [x] CHK008 Is the tie rule for several minimal routes stated in this game's terms (the first winning leg in the fixed
  expansion order)? [Consistency, Spec §Edge Cases; Clarifications Q2]
- [x] CHK009 Is it stated that the acceptance ranges were measured by a prototype on the real kernel before being
  written down, with the counts per band? [Assumption, Spec §Clarifications preamble]

## Empty and error states

- [x] CHK010 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK011 Are candidates the level rules refuse, with no flyable route, with out-of-range plans and over the work
  bound excluded with a deterministic next step? [Edge Case, Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that presentation belongs to later features (R02-G16-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes stated (all 100 levels, the independent depth-first enumeration on two levels per
  band, groups of 10 under 10 s measured locally)? [Measurability, Spec §SC-R02G1602-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
