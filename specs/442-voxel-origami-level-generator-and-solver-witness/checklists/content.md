# Requirements Quality Checklist: R02-G15-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 442 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 432's checklist.

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be won within its budget, and the stored
  plan is a shortest one)? [Clarity, Spec §US1; FR-R02G1502-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (more cubes, longer scrambles, more folds in the right order),
  never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (cube count, tree with its redraw bound, solution turns,
  orientations by emphasis, target rotation and shift, scramble with its draw bound), with the seed derivation per
  candidate, the filters and the candidate bound? [Completeness, Spec §Clarifications Q1]
- [x] CHK004 Is the minimality proof defined (every state reachable in fewer turns reached and none matching), with the
  expansion order, state merging and work bound stated, and is the reason a breadth-first search is exact given (turns
  do not commute, so plans are paths)? [Measurability, Spec §FR-R02G1502-002; Clarifications Q2; research R1]
- [x] CHK005 Is the witness file's content (state digests, fingerprints, counterexample), byte-for-byte check and
  opt-in regeneration defined? [Completeness, Spec §FR-R02G1502-004; Clarifications Q4]
- [x] CHK006 Is the catalog digest's input (fingerprints in manifest order) and the progression rule on the witness turn
  count stated, with band ranges that keep it? [Consistency, Spec §FR-R02G1502-005; Clarifications Q3, Q5]
- [x] CHK007 Do the generated values stay inside R02-G15-01's level ranges (5 … 10 cubes within 4 … 12, quarter turns
  0 … 3, the three orientation groups, budget 8 … 19 within 1 … 40, plans of at most 6 turns within every budget), so
  the kernel is unchanged except for two new refusals? [Consistency, Spec §Clarifications Q1; FR-R02G1502-006]
- [x] CHK008 Is the tie rule for several minimal plans stated in this game's terms (the first matching state in the
  fixed expansion order)? [Consistency, Spec §Edge Cases; Clarifications Q2]
- [x] CHK009 Is it stated that the acceptance ranges were measured by a prototype on the real kernel before being
  written down, per orientation group? [Assumption, Spec §Clarifications preamble]

## Empty and error states

- [x] CHK010 Are refusals named for a manifest entry that yields no candidate and for damaged, newer, edited or
  non-replaying witness files? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK011 Are candidates with a colliding rest or solution pose, already matching at their start, with out-of-range
  plans and over the work bound excluded with a deterministic next step? [Edge Case, Spec §Edge Cases; Clarifications
  Q1, Q2]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the manifest comes from the project's own archived design and nothing is drawn here?
  [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that presentation belongs to later features (R02-G15-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes stated (all 100 levels, the independent depth-first enumeration on two levels per
  band, groups of 10 under 10 s measured locally)? [Measurability, Spec §SC-R02G1502-001 … 006; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
- CHK009: the prototype measured each orientation group separately and drew the target unrotated; a target's rotation
  and shift do not change which poses match (the canonical form is invariant under them), so the measured rates carry
  over. The implement step re-measures on the real generator (every entry must certify within 256 candidates).
