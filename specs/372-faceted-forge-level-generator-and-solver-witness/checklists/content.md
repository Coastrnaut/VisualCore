# Requirements Quality Checklist: R02-G08-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 372 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be cut into its target within its budget
  without a sliver)? [Clarity, Spec §US1; FR-R02G0802-001]
- [x] CHK002 Is difficulty defined as more cuts and more varied directions, never faster reactions, with measurable band
  ranges? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (crystal by band, cut count, piece, direction, depth), with
  the seed derivation per candidate, the filters and the candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the proof of the smallest cut count defined (the piece-count lower bound, a sequence that meets it, the
  search order and pruning) and its work counted and bounded? [Measurability, Spec §FR-R02G0802-002; Clarifications Q2]
- [x] CHK005 Is the witness file's content, byte-for-byte check and opt-in regeneration defined? [Completeness, Spec
  §FR-R02G0802-004; Clarifications Q4]
- [x] CHK006 Is the catalog digest's input (fingerprints in manifest order) and the progression rule stated?
  [Consistency, Spec §FR-R02G0802-005; Clarifications Q3, Q5]
- [x] CHK007 Is the widening of the kernel's ranges stated as additive, with every earlier level still valid?
  [Consistency, Spec §Clarifications Q1; FR-R02G0802-006]

## Empty and error states

- [x] CHK008 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK009 Are unsuitable, over-budget and over-work candidates excluded with a deterministic next step? [Edge Case,
  Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK010 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK011 Is it stated that presentation belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK012 Are host-test sizes stated (all 100 levels, at least two independent checks per band, groups of 5 under
  10 s measured locally)? [Measurability, Spec §SC-R02G0802-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK013 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
