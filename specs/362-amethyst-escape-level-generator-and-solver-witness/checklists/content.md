# Requirements Quality Checklist: R02-G07-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 362 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be escaped within its budget, and none by
  advances alone)? [Clarity, Spec §US1; FR-R02G0702-001]
- [x] CHK002 Is difficulty defined as longer routes through more shells, never faster reactions, with measurable band
  ranges? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (profile, apertures, walls, wedges, start), with the seed
  derivation per candidate and the candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the proof of the smallest move count defined (breadth-first order, dead wedges, depth counts) and its work
  bounded by arithmetic? [Measurability, Spec §FR-R02G0702-002; Clarifications Q2]
- [x] CHK005 Is the witness file's content, byte-for-byte check and opt-in regeneration defined? [Completeness, Spec
  §FR-R02G0702-004; Clarifications Q4]
- [x] CHK006 Is the catalog digest's input (fingerprints in manifest order) and the progression rule stated?
  [Consistency, Spec §FR-R02G0702-005; Clarifications Q3, Q5]

## Empty and error states

- [x] CHK007 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK008 Are unsolvable, too easy, too hard and over-budget candidates excluded with a deterministic next step?
  [Edge Case, Spec §Edge Cases; Clarifications Q1]

## Source licence and code-only graphics

- [x] CHK009 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK010 Is it stated that presentation belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK011 Are host-test sizes stated (all 100 levels, at least two brute-force samples per band, per-band tests under
  10 s measured locally)? [Measurability, Spec §SC-R02G0702-001 … 006]

## Future D1/D2/D3 evidence

- [x] CHK012 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
