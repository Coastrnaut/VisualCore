# Still Renderer Requirements Quality Checklist: Living Wallpapers — Phase 02

**Purpose**: Unit tests for the requirements of A19-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are both VisualCore additions specified as additive with their exact public shape and the unchanged existing behaviour? [Spec §FR-A19-201, 202, Q1, Q2] — yes.
- [x] CHK002 Are the four scenes, their uniforms and the two levels specified, with determinism? [Spec §FR-A19-203, Q3] — yes.
- [x] CHK003 Is the crop frame specified with its margin, aspect tolerance and containment? [Q4, data-model, SC-A19-203] — yes.
- [x] CHK004 Are the export steps, the cancel points, the failure reasons and the cleanup named? [Spec §FR-A19-205, Q5, data-model] — yes.
- [x] CHK005 Are the controls, the five fixtures and the snapshot schema named? [Q5, FR-A19-206] — yes.

## Architecture ownership

- [x] CHK006 Are the experience's quality tiers declared to match the presenter's levels and the registration? [Gap; lesson of 2026-11-16] — failed (not stated); data-model.md now declares `qualityTiers` level-0 and level-1 matching both.
- [x] CHK007 Is the split between VisualCore (encoder, timed still) and app-local (scenes, frame, export) justified? [research D1, D3, plan Constitution II] — yes.
- [x] CHK008 Is the source-compatibility of the additions addressed (no new error case, existing init kept)? [research D2, D3] — yes.

## iOS lifecycle

- [x] CHK009 Are context loss, Reduce Motion and the main-actor export timing addressed? [Spec §Edge Cases, Q2, research D6] — yes.

## Privacy and platform

- [x] CHK010 Is it stated that files stay in a temporary folder this phase and no permission is asked? [Spec §Negative Requirements, plan VIII] — yes.
- [x] CHK011 Are GL calls, wallpaper calls and the refused words excluded from the experience, with the existing scan applied? [FR-A19-207, contracts/experience.md] — yes.

## Testability and performance

- [x] CHK012 Is the no-orphan fixture measurable (live counts per kind and file count, equal before and after each case)? [SC-A19-202, Q5] — yes.
- [x] CHK013 Is the HEIC availability on the test runtime handled without a silent skip? [Q1] — yes (the test records availability and asserts it true on iOS 27.2).
- [x] CHK014 Are the reference regression's timing and the test time limits consistent with the faster-gates ruling? [SC-A19-205, overrides] — yes (corrected during plan: the regression runs at X-A19).

## Notes

- `/speckit-implement` reads these markers and does not change them.
