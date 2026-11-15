# Schools Requirements Quality Checklist: Digital Aquarium — Phase 02

**Purpose**: Unit tests for the requirements of A09-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); three items failed and were
corrected in the spec before this record (CHK006, CHK011, CHK013).

## Completeness

- [x] CHK001 Are both manual Phase 02 gates (bounded school behaviour with swim animation; save/load of species, decor transforms and lighting) required with acceptance scenarios? [Spec §US1–US3, FR-A09-210–213] — yes.
- [x] CHK002 Are all four steering forces and the combined cap named as requirements? [Spec §FR-A09-201] — yes.
- [x] CHK003 Are the decor transform fields defined with ranges? [Spec §FR-A09-212, Clarifications Q4] — yes (rotation −π…π, scale 0.5…2.0).
- [x] CHK004 Are the swim-animation amounts quantified? [Spec §FR-A09-211, Clarifications Q5] — yes.
- [x] CHK005 Are the decor kinds required to carry author and license like species and plants? [Spec §Key Entities, FR-A09-212] — yes.
- [x] CHK006 Is the migration of the saved experience state (not only the habitat document) specified? [Spec §FR-A09-212] — failed (only the document was named); corrected: snapshot schema 2 restores schema 1 through the same migration.

## Clarity and measurability

- [x] CHK007 Is "school" measurable? [Spec §SC-A09-201, 202] — yes (distance ratio ≤ 60 %, agreement ≥ 0.7, 18 of 20 seeds).
- [x] CHK008 Is "heading agreement" defined unambiguously? [Spec §SC-A09-202, Clarifications Q5] — yes.
- [x] CHK009 Is the neighbour ordering defined so determinism is checkable? [Spec §FR-A09-202] — yes (nearest first, ties by index, never self).
- [x] CHK010 Are the cross-species rules unambiguous? [Spec §FR-A09-210, Clarifications Q3] — yes (separation only).

## Consistency

- [x] CHK011 Is the result defined independently of the order of fish in the document? [Spec §FR-A09-210] — failed (not stated); corrected: forces from the start-of-step state.
- [x] CHK012 Is Reduce Motion consistent with Phase 01 (drawing only, state unchanged)? [Spec §US2-3, FR-A09-211] — yes.
- [x] CHK013 Is a minimum speed specified so steering cannot stall fish while Phase 01's "fish keep swimming" holds? [Spec §FR-A09-210] — failed; corrected: never below half the cruise speed.

## Edge cases and recovery

- [x] CHK014 Are lone fish, coincident fish, out-of-radius neighbours, the 24-fish cap and pause covered? [Spec §Edge Cases] — yes.
- [x] CHK015 Are invalid decor (unknown kind, outside tank, bad scale) refusals specified? [Spec §FR-A09-212] — yes.
- [x] CHK016 Is a schema-1 state with no decor handled? [Spec §US3-2, Clarifications Q4] — yes (starter decor added).

## Architecture ownership and lifecycle

- [x] CHK017 Is the boundary between VisualCore (generic steering) and the experience (species tuning, decor, animation) stated? [Spec §FR-A09-201–203, 210–212] — yes.
- [x] CHK018 Is graphics-context ownership kept in the host? [Spec §Canonical overrides, Negative Requirements] — yes.
- [x] CHK019 Are suspension and pause behaviours unchanged from Phase 01 and stated? [Spec §Edge Cases "Paused"; A09-P01 FR-A09-121] — yes.

## Privacy, performance and release

- [x] CHK020 Does the phase add no data collection, permission or network? [Spec §Negative Requirements] — yes.
- [x] CHK021 Is per-step work bounded by a stated limit? [Spec §Edge Cases, SC-A09-205] — yes.
- [x] CHK022 Are test durations bounded per the owner's ruling? [Spec §SC-A09-205] — yes (< 10 s).
- [x] CHK023 Is the VisualCore API change tied to the public-API baseline and the X-A09 reference regression? [Spec §FR-A09-203, Canonical overrides] — yes.
- [x] CHK024 Are realism claims excluded? [Spec §Negative Requirements] — yes.

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
