# Editor Requirements Quality Checklist: Shader Studio — Phase 03

**Purpose**: Unit tests for the requirements of A22-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-18 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are the editor's parts (gutter, colours, marks, list, jump) specified? [Spec §FR-A22-301, Q1] — yes.
- [x] CHK002 Is the oversized proof (codes, counts, pixels) specified? [Spec §FR-A22-302, Q2] — yes.
- [x] CHK003 Are the inspector's fields, clamping and reset specified? [Spec §FR-A22-303, Q3] — yes.
- [x] CHK004 Are the three textures, their sizes and binding specified? [Spec §FR-A22-304, Q4, data-model] — yes.
- [x] CHK005 Is the snapshot's compatibility with A22-P02 specified? [Spec §Q5, FR-A22-305] — yes.
- [x] CHK006 Are interface tests required? [Spec §FR-A22-307] — corrected: FR-A22-307 now requires the editor and inspector journeys in the app.

## Clarity and measurability

- [x] CHK007 Is "before GPU work" measurable? [Spec §SC-A22-301] — yes (zero compiles, byte-identical preview).
- [x] CHK008 Are time limits stated? [Spec §SC-A22-304] — yes (10 s, 60 s).
- [x] CHK009 Is "three different pictures" measurable? [Spec §SC-A22-304] — yes (pairwise differing read-backs).

## Accessibility and lifecycle

- [x] CHK010 Is colour forbidden as the only cue? [Spec §Q1] — yes (weights differ).
- [x] CHK011 Are large text and a hardware keyboard addressed? [Spec §FR-A22-306, Edge Cases] — yes.
- [x] CHK012 Is the texture lifecycle (setup, rebuild, teardown) specified? [Spec §Q4, Plan §Lifecycle] — yes.

## Edge cases and consistency

- [x] CHK013 Are empty editors, outside-source diagnostics, long lines and unchosen inputs covered? [Spec §Edge Cases] — yes.
- [x] CHK014 Do spec and data model agree on the template range 0…3 and texture defaults [0, 1]? [Spec §Q4–Q5, data-model] — yes.

## Architecture, privacy and release

- [x] CHK015 Are GL calls outside VisualCore types and compiles from controls excluded? [Spec §Negative Requirements] — yes.
- [x] CHK016 Is no image file bundled (textures made in code)? [Spec §Negative Requirements, Q4] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
