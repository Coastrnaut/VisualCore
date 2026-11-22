# Requirements Quality Checklist: R02-G09-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 382 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 gardens can be matched within its move budget without
  leaking beyond the allowance)? [Clarity, Spec §US1; FR-R02G0902-001]
- [x] CHK002 Is difficulty defined as a finer fit (larger beds, more blooms, all sizes and elevations, tighter match,
  smaller leak allowance, a decoy), never faster reactions, with measurable band values? [Clarity, Spec §US3;
  Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (bed, sizes, elevations, construction sun, bloom count,
  blooms, forbidden ring, match, allowance, supply, opening sun), with the seed derivation per candidate, the filters and
  the candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the proof of the smallest move count defined (the lower bound L from needed cells and single-plant
  cover, a sequence of exactly L moves, the search order and pruning) and its work counted and bounded? [Measurability,
  Spec §FR-R02G0902-002; Clarifications Q2]
- [x] CHK005 Is the witness file's content (per-action mask digests, fingerprints, bound argument, near miss),
  byte-for-byte check and opt-in regeneration defined? [Completeness, Spec §FR-R02G0902-004; Clarifications Q4]
- [x] CHK006 Is the catalog digest's input (fingerprints in manifest order) and the progression rule stated?
  [Consistency, Spec §FR-R02G0902-005; Clarifications Q3, Q5]
- [x] CHK007 Is it stated that the generated levels stay inside R02-G09-01's level ranges, so the kernel is unchanged
  except for two new refusals? [Consistency, Spec §Clarifications; FR-R02G0902-006]
- [x] CHK008 Is the tie rule for several winning sequences stated in the plant order of this game (not another game's
  wording)? [Consistency, Spec §Edge Cases] — corrected: "fixed cut order" → "fixed plant order".

## Empty and error states

- [x] CHK009 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK010 Are unsuitable, over-budget and over-work candidates excluded with a deterministic next step? [Edge Case,
  Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK011 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK012 Is it stated that presentation belongs to later features (R02-G09-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK013 Are host-test sizes stated (all 100 levels, an independent brute-force bound on two levels per band, groups
  of 5 under 10 s measured locally)? [Measurability, Spec §SC-R02G0902-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK014 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides; Excluded
  scope]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
