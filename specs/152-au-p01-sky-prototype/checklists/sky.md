# Sky Requirements Quality Checklist: Aurora — Phase 01

**Purpose**: Unit tests for the requirements of A21-P01 (completeness, privacy, ownership, lifecycle, testability,
performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) judged the requirement's quality
satisfied, not that work is done. Two items failed and were corrected before this record (CHK006, CHK008).

## Completeness

- [x] CHK001 Are every scene field, its bound and its unit stated? [Spec §FR-A21-101, Clarifications Q1] — yes.
- [x] CHK002 Are the three presets named with their character, version and attribution? [Spec §FR-A21-102, Q1] — yes.
- [x] CHK003 Is every refusal code listed with the condition that raises it? [Spec §FR-A21-103, data-model] — yes.
- [x] CHK004 Are the layers, their order and the composite rule specified? [Spec §FR-A21-104, Q2] — yes.

## Clarity and measurability

- [x] CHK005 Are the comparison tolerance and the brightness range quantified? [Spec §SC-A21-102, Q3] — yes (2/255 mean, 8/255 largest; luminance ≤ 0.75 per pixel, ≥ 0.02 mean).
- [x] CHK006 Is "bounded twinkle" quantified? [Gap, data-model] — failed; data-model now bounds it to ±30 % and star size to 1.5 pixels.
- [x] CHK007 Is the time step bound and the loop period stated, with what Reduce Motion does to them? [Spec §FR-A21-106, Q4] — yes.

## Lifecycle and ownership

- [x] CHK008 Is the drawing required to recover after a context loss and a resize, as the contract's G-SKY test says? [Spec §FR-A21-104, contract G-SKY] — failed; FR-A21-104 and the core contract now require a matching picture after both.
- [x] CHK009 Is it stated that the core issues no GL call and that the presenter of A21-P02 owns the GPU life? [Spec §FR-A21-107, plan lifecycle] — yes.
- [x] CHK010 Is reuse of `SceneClock`, `FullScreenShaderScene` and `vc/` required rather than copies? [Plan Constitution Check II, research D2] — yes.

## Privacy, release and constraints

- [x] CHK011 Are images, recordings, claims of a real aurora and registration excluded? [Spec §Negative Requirements] — yes.
- [x] CHK012 Is the license record of presets, palettes and shader required? [Plan Constitution Check XIII] — yes.
- [x] CHK013 Is every test bounded in time? [Spec §SC-A21-104] — yes (under 10 s each).
- [x] CHK014 Are speed zero, NaN values and counts above caps covered? [Spec §Edge Cases] — yes.
