# Orbit Requirements Quality Checklist: Solar System Explorer — Phase 02

**Purpose**: Unit tests for the requirements of A14-P02 (API verification, data provenance, algorithm tolerances, state
migration, accessibility of the controls, evidence commands)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK013).

## API verification

- [x] CHK001 Is the new VisualCore type's full public surface (initialiser, refusals, solver, position, period) specified? [FR-A14-201, 202, Clarifications Q1, contracts/kepler-orbit.md] — yes.
- [x] CHK002 Is the reference frame of the returned position defined (x reference direction, z north) and its mapping into the scene stated? [Clarifications Q1, Q4, research D4] — yes.
- [x] CHK003 Are only VisualCore APIs verified in code referenced (`Vec3` in Double, `OrbitCamera` limits, `tube` signature)? [Plan Technical Context] — yes.
- [x] CHK004 Are documentation, API baseline and the deferral of the reference regression to X-A14 required? [FR-A14-203, Constitution II-a] — yes.

## Data provenance

- [x] CHK005 Are every element's source, epoch, units and license stated, with the basis for `public-domain`? [FR-A14-210, Clarifications Q2] — yes.
- [x] CHK006 Is the derivation of ω, M₀ and n from the published elements and the catalog defined? [research D2] — yes.
- [x] CHK007 Is the model's validity range and its fixed-epoch approximation stated? [Assumptions, Clarifications Q3] — yes.

## Algorithm tolerances

- [x] CHK008 Are the iteration bound, the stop tolerance and the starting values quantified? [Clarifications Q1, research D1] — yes.
- [x] CHK009 Are fixture tolerances quantified for longitude, distances, period return and residual? [Clarifications Q3, research D5] — yes.
- [x] CHK010 Are high and near-zero eccentricity and angle normalisation addressed? [Spec §Edge Cases] — yes.
- [x] CHK011 Is non-finite input behaviour defined for elements and time? [FR-A14-202, contracts/kepler-orbit.md] — yes.

## State migration

- [x] CHK012 Are schema 2's fields, the migration from schema 1 and the refusal of newer documents specified? [Clarifications Q5, data model] — yes.
- [x] CHK013 Are the camera ranges and the behaviour at their ends consistent across spec, data model and contract? [FR-A14-221, data model, contracts/orbit-view.md] — failed (the clarification said the zoom distance is clamped while the contract refused steps beyond 4…80, and pitch values were "multiples of 5"); the spec, data model, research and contract now state zoom steps −1…12 refused beyond, pitch 5 + 10k, and why focus never crosses the near plane.
- [x] CHK014 Are date range ends and refusal codes defined (`a14.invalid-step`, `a14.out-of-range`)? [FR-A14-211, Clarifications Q3] — yes.

## Accessibility of the controls

- [x] CHK015 Do all new controls require a label and a value, and is the not-to-scale notice part of the spoken description? [FR-A14-221, contracts/orbit-view.md] — yes.

## Evidence commands

- [x] CHK016 Is every success criterion mapped to a command runnable without a device, with the evidence stage named? [SC-A14-201–205, plan Evidence, quickstart] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
