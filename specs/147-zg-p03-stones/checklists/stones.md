# Stones Requirements Quality Checklist: Digital Zen Garden — Phase 03

**Purpose**: Unit tests for the requirements of A20-P03 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK010).

## Completeness

- [x] CHK001 Are every stone action, its values and its ranges specified? [Spec §Q2, data-model] — yes (six actions; corrected by analyze: selection by id).
- [x] CHK002 Are the shapes of all five kinds defined by numbers (exponents, heights, wobble)? [Spec §Q1, data-model] — yes.
- [x] CHK003 Are the selection rule, its display and its spoken label specified? [Spec §FR-A20-303, Q4] — yes.
- [x] CHK004 Are native alternatives defined for every stone gesture? [Spec §Q3] — yes.

## Clarity and measurability

- [x] CHK005 Is "topmost" defined (highest depth whose shape contains the point)? [Spec §Q2, data-model] — yes.
- [x] CHK006 Is the orientation fixture quantified (two view sizes, one-cell tolerance)? [Spec §Q5, SC-A20-303] — yes.
- [x] CHK007 Is the shadow made checkable (darker sand under a stone's shadow than without it)? [Contract] — yes.

## Consistency

- [x] CHK008 Is the change from meshes (P00 contract) to a rasterized layer recorded with its reason? [Spec §Q1, research D1] — yes.
- [x] CHK009 Do the history commands of A20-P01 and the new actions agree (one command per lift or rotation end)? [Spec §Q2, Q3] — yes.

## Edge cases

- [x] CHK010 Are a cancelled stone drag and a cancelled rotation covered? [Spec §Edge Cases] — failed (not covered); the edge cases now say nothing is sent and the stone stays.
- [x] CHK011 Are the stone cap, the tray edge, removing the selected stone and undo of a removal covered? [Spec §Edge Cases] — yes.

## Lifecycle, architecture and privacy

- [x] CHK012 Are rebuilds after undo, redo, restore, resize and context loss required for the stone layer? [Spec §FR-A20-306] — yes.
- [x] CHK013 Is the selection kept out of the saved document and the digest? [Spec §Q4, facts] — yes.
- [x] CHK014 Is VisualCore unchanged, with the reuse named, and no permission or network? [Plan §Constitution Check, Negative Requirements] — yes.

## Testability and performance

- [x] CHK015 Is the rasterization cost bounded by arithmetic? [Plan §Technical Context] — yes.
- [x] CHK016 Are test time limits stated? [Spec §SC-A20-304] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
