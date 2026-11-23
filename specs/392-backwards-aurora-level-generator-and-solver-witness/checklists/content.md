# Requirements Quality Checklist: R02-G10-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 392 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 auroras can be folded back within its reversal budget
  without tearing)? [Clarity, Spec §US1; FR-R02G1002-001]
- [x] CHK002 Is difficulty defined as more to read and a tighter fit (longer waves, more reversals and checkpoints, a
  smaller breaking margin), never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications
  Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (length, target, bend limit, reversal count, section lengths
  and placement, checkpoints, breaking limit), with the seed derivation per candidate, the filters and the candidate
  bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the proof of the smallest reversal count defined (bad bends fall by at most 4 per reversal, the bound
  ⌈β / 4⌉, openings with β = 4k, the search order and pruning) and its work counted and bounded? [Measurability, Spec
  §FR-R02G1002-002; Clarifications Q2]
- [x] CHK005 Is the witness file's content (per-reversal sample digests, fingerprints, bound argument, near miss),
  byte-for-byte check and opt-in regeneration defined? [Completeness, Spec §FR-R02G1002-004; Clarifications Q4]
- [x] CHK006 Is the catalog digest's input (fingerprints in manifest order) and the progression rule stated?
  [Consistency, Spec §FR-R02G1002-005; Clarifications Q3, Q5]
- [x] CHK007 Do the generated values stay inside R02-G10-01's level ranges (N 14 … 32 within 12 … 32, checkpoints 2 … 6
  within 2 … 8, B ≥ L, k ≤ 7 below every budget of 8 … 19), so the kernel is unchanged except for two new refusals?
  [Consistency, Spec §Clarifications Q1; FR-R02G1002-006]
- [x] CHK008 Is the tie rule for several winning sequences stated in this game's terms (the solver's fixed order of
  sections)? [Consistency, Spec §Edge Cases; Clarifications Q2]

## Empty and error states

- [x] CHK009 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK010 Are unsuitable, over-budget and over-work candidates excluded with a deterministic next step? [Edge Case,
  Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK011 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK012 Is it stated that presentation belongs to later features (R02-G10-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK013 Are host-test sizes stated (all 100 levels, independent checks on two levels per band with an exhaustive
  search on two band-1 levels, groups of 5 under 10 s measured locally)? [Measurability, Spec §SC-R02G1002-001 … 006;
  Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK014 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides; Excluded
  scope]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
