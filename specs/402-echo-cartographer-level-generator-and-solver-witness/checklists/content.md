# Requirements Quality Checklist: R02-G11-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 402 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 chambers can be solved by reasoning: pulses within the
  energy single out every beacon, no guess needed)? [Clarity, Spec §US1; FR-R02G1102-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (larger chambers, more beacons, tighter tolerance, more pulses
  needed), never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (width, height, walls in index order, entry, region size,
  beacon count, beacons), with the seed derivation per candidate, the filters and the candidate bound? [Completeness,
  Spec §Clarifications Q1]
- [x] CHK004 Is the uniqueness proof defined (a placement fits when every pulse's sorted echoes are reproduced; exactly
  one fits after the witness; the enumeration, its pruning and cap) and the plan's choice rule and work bound stated?
  [Measurability, Spec §FR-R02G1102-002; Clarifications Q2]
- [x] CHK005 Is the witness file's content (echo digests, placements after each pulse, fingerprints, counterexample),
  byte-for-byte check and opt-in regeneration defined? [Completeness, Spec §FR-R02G1102-004; Clarifications Q4]
- [x] CHK006 Is the catalog digest's input (fingerprints in manifest order) and the progression rule on the witness pulse
  count stated, with band ranges that keep it? [Consistency, Spec §FR-R02G1102-005; Clarifications Q3, Q5]
- [x] CHK007 Do the generated values stay inside R02-G11-01's level ranges (sizes 6 … 14 within 5 … 16, beacons 1 … 4,
  tolerance 0 … 1 within 0 … 2, miss cost 1 … 3, energy 8 … 19 within 1 … 60, at most energy − 1 pulses), so the kernel
  is unchanged except for two new refusals? [Consistency, Spec §Clarifications Q1; FR-R02G1102-006]
- [x] CHK008 Is the tie rule for several pulse plans stated in this game's terms (fewest fitting placements, then lowest
  cell index)? [Consistency, Spec §Edge Cases; Clarifications Q2]
- [x] CHK009 Is it stated that the acceptance ranges were measured by a prototype before being written down?
  [Assumption, Spec §Clarifications preamble]

## Empty and error states

- [x] CHK010 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK011 Are too-small regions, unsingled-out beacons, out-of-range plans and over-work candidates excluded with a
  deterministic next step? [Edge Case, Spec §Edge Cases; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that presentation belongs to later features (R02-G11-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes stated (all 100 levels, the independent brute force on two levels per band, groups of
  5 under 10 s measured locally)? [Measurability, Spec §SC-R02G1102-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]
