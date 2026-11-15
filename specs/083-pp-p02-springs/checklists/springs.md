# Springs Requirements Quality Checklist: Physics Playground — Phase 02

**Purpose**: Unit tests for the requirements of A11-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK009).

## Completeness

- [x] CHK001 Are both Phase 02 gates (gravity, springs and drag; resting stack bounded) required with measurable outcomes? [Spec §Canonical overrides, SC-A11-201, 202] — yes.
- [x] CHK002 Are the spring law, its anchors, the stable stiffness and damping bounds and the zero-length case defined? [Clarifications Q1, Edge Cases] — yes.
- [x] CHK003 Are the force and stiffness levels given as numbers with defaults? [Clarifications Q4] — yes.
- [x] CHK004 Is the starting scene's new content (hanging box, joined circles) specified with positions and sizes? [Clarifications Q5, FR-A11-212] — yes.

## Architecture ownership

- [x] CHK005 Is the split between generic VisualCore code (springs, broad phase, warm starting) and app-local code (levels, scene, cache, drawing) explicit? [FR-A11-201–204, 210–212] — yes.
- [x] CHK006 Is the solver change additive, with the Phase 01 behaviour unchanged when nothing is stored? [FR-A11-203, Clarifications Q3] — yes.
- [x] CHK007 Is broad-phase correctness defined as equality with brute force, with a fixed pair order? [FR-A11-202, Clarifications Q2] — yes.
- [x] CHK008 Is the reference regression scheduled for the VisualCore change? [FR-A11-204] — yes (X-A11).

## iOS lifecycle and persistence

- [x] CHK009 Is the state after reset defined for the new levels and the contact cache? [Spec §Edge Cases] — failed at first (reset said nothing about levels); an Edge Cases bullet now restores the starting scene with the default levels, time scale 1, running and an empty cache.
- [x] CHK010 Are schema 2, the 1 → 2 migration defaults and exact save/restore (including the warm-start cache) required? [FR-A11-210, Clarifications Q3, Q4; SC-A11-206] — yes.

## Privacy and release constraints

- [x] CHK011 Are no permission, no network and no claim of engineering accuracy restated? [Spec §Negative Requirements] — yes.

## Accessibility

- [x] CHK012 Do the new controls carry VoiceOver labels and values, and does the spoken description cover springs, stiffness, gravity and drag? [FR-A11-220, 221] — yes.

## Testability and measurability

- [x] CHK013 Are the equilibrium (2 %), stack drift (2 cm) and sink (1 cm), energy (2 %, 0.1 %/s, 10 %) and level (1 %) tolerances stated? [SC-A11-201–205] — yes.
- [x] CHK014 Is the long-run stack requirement turned into a short measured run plus an arithmetic bound? [SC-A11-202] — yes.
- [x] CHK015 Are the new manifest fixtures named? [FR-A11-222, research D5] — yes (11–18).

## Performance

- [x] CHK016 Are per-tick bounds (≤ 48 bodies, ≤ 16 springs, broad-phase pairs, 10 iterations) and test durations (< 10 s) stated without unmeasured claims? [Plan §Technical Context, SC-A11-207] — yes.

## Notes

- 16 items evaluated on 2026-11-15; CHK009 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
