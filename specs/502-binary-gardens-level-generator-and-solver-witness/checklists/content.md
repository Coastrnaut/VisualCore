# Requirements Quality Checklist: R02-G21-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 502 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 492's checklist; every item
but CHK004, CHK010 and CHK012 passed at first reading, and those three stay open until the spec text is fixed (CHK007
was checked value by value against R02-G21-01's ranges: rings 3 … 5 of 2 … 8, radii 2 … 16 of 1 … 40, ω 1 … 3 of
1 … 3, luminosity levels 2 … 4 of 1 … 4 with values 4 … 32 of 1 … 64, T_max 0 … 3 of 0 … 6, σ 0 … 6 of 0 … 16, clamp
2 … 4 of 1 … 8, worlds 1 … 3 of 1 … 5, world radius up to 60 of 1 … 60, world speed ±1 … ±3 of −4 … 4, W 1 … 48 of
1 … 48, λ_hi at most 166 400 of the 200 000 ceiling, B_hi at most 7 065 600 of 9 600 000, tolerance 1 … 8 of 0 … 12,
budgets 8 … 19 of 1 … 24 unwidened; Q2's search sizes 11, 69, 583, 1,416 and 4,048 were recomputed).

## Player impact

- [x] CHK001 Is the player promise stated (every one of the 100 levels can be won within its budget, and the stored
  actions are a fewest)? [Clarity, Spec §US1; FR-R02G2102-001, 002]
- [x] CHK002 Is difficulty defined as more to work out (more worlds, narrower bands, tighter windows, more controls
  working together), never faster reactions, with measurable band values? [Clarity, Spec §US3; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK003 Is the candidate drawing order fully specified (adjustable controls with the emphasised one first, ω, rings
  and radii, luminosity levels, phase step, T_max, σ, clamp radius, the winning arrangement with bounded redraws, worlds,
  margins, E, the changed controls and their starting values), with the seed derivation per candidate, the bounds from
  the winning run, the filters and the candidate bound? [Completeness, Spec §Clarifications Q1; research R12, R15]
- [x] CHK004 Is the minimality proof defined (every arrangement at a smaller depth judged and none winning), with the
  reason the depth is the exact action distance (legal moves only, separation detours), the search order, the
  reachability rule stated the same way in the requirement and the clarification, and the work bound? [Consistency,
  Spec §FR-R02G2102-002; Clarifications Q2; research R3, R10] — failed at first reading: FR-R02G2102-002 skips
  arrangements "already reached at a smaller depth", while Q2 and research R3 skip those reached "at any depth"
  (earlier in the same depth included); the narrower wording would re-judge duplicates within a depth and change the
  counts the proof stores. Fixed in the spec on 2026-11-27.
- [x] CHK005 Is the light loss's role bounded (it orders only the expansion of a depth, never which depth is minimal;
  the plan is replayed through the kernel's play; the independent check searches with no visited set and no loss
  order)? [Consistency, Spec §Clarifications Q2, Q5; research R3, R14]
- [x] CHK006 Is the witness file's content (state digests, fingerprints, terminal report with each world's integral,
  exact mean, lethal run, window and bloom and the minimum separation, counterexample with the nearest miss and its
  first failure), byte-for-byte check and opt-in regeneration defined? [Completeness, Spec §FR-R02G2102-004;
  Clarifications Q4]
- [x] CHK007 Do the generated values stay inside R02-G21-01's level ranges, and is the kernel change (the phase step)
  additive, with a level without it encoding, fingerprinting and playing as in feature 501 and the existing tests
  unchanged? [Consistency, Spec §Clarifications Q1, Q5; FR-R02G2102-009; SC-R02G2102-006, 007]
- [x] CHK008 Is the catalog digest's input (fingerprints in manifest order), the progression rule on the witness length
  and the neighbour rule stated, with band plan lengths that keep the band means from falling? [Consistency, Spec
  §FR-R02G2102-005, 007; Clarifications Q1, Q3, Q5]
- [x] CHK009 Is the tie rule for several minimal arrangements stated (the first winning one in the fixed search order),
  and is the witness order (the winning arrangement's parent chain of moves, then `run`) stated? [Consistency, Spec
  §Edge Cases; Clarifications Q2; research R6]
- [x] CHK010 Is it stated where and when the band profiles are measured on the real kernel and the real manifest
  (before any test depends on them), with the figures to record, the adjustment ladder and the write-back rule, and do
  the spec, plan and research agree? [Assumption, Spec §Clarifications preamble; plan Summary, step 3; research R4] —
  fails at first reading: the preamble still says "no Binary Gardens code exists yet" (research reads the committed
  kernel of R02-G21-01 up to T-006) and that "the plan stage runs a prototype", while plan.md and research R4 moved the
  measurement to the first implementation task (T-R02G2102-003/004) and write changes back into Q1, research.md and
  data-model.md in the same commit. Fixed in the spec on 2026-11-27.

## Empty and error states

- [x] CHK011 Are refusals named for a manifest entry that yields no candidate, for damaged, newer, edited or
  non-replaying witness files, for a level whose phase step or starting phase is off the grid, and for a phase action
  off the level's grid? [Coverage, Spec §Edge Cases; Clarifications Q1, Q4, Q5]
- [x] CHK012 Are candidates whose winning arrangement or start cannot keep the separation, with a world whose c_lo is
  0, that the level rules refuse (a start that already wins included), that are reducible, that repeat the previous
  ring radii and worlds, whose minimal plan is not p or that do not win through the play excluded with a deterministic
  next step, and is every skip one that can occur or marked as a guard? [Edge Case, Spec §Edge Cases; Clarifications
  Q1, Q2; research R12] — failed at first reading: Q1 and the edge cases present the "λ_hi exceeds 200 000" skip as a
  real case, but a world receives at most 2 · 64 000 milliflux per tick, so λ_hi is at most 166 400 and the skip can
  never fire; plan.md and research R12 call it a guard tested as a bound, the spec does not. Fixed in the spec on 2026-11-27.

## Source licence and code-only graphics

- [x] CHK013 Is it stated that the manifest comes from the project's own archived design, no star catalogue or
  third-party content is used and nothing is drawn here? [Consistency, Spec §Assumptions]

## iPad/iPhone layout

- [x] CHK014 Is it stated that presentation belongs to later features (R02-G21-03 … 07)? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK015 Are host-test sizes stated (all 100 levels, the independent search on the two levels with the smallest
  move space per band, the content and novelty boundary tests with seeded neighbouring inputs, groups of 5 under 10 s
  measured locally)? [Measurability, Spec §SC-R02G2102-001 … 007; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK016 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
- CHK004, CHK010 and CHK012 are ticked only after the spec text is corrected and re-read against plan.md, research.md
  R3, R4 and R12, data-model.md and contracts/api.md.
