# Experience Requirements Quality Checklist: Digital Zen Garden — Phase 02

**Purpose**: Unit tests for the requirements of A20-P02 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK012).

## Completeness

- [x] CHK001 Are the actions, their value counts and ranges specified for strokes, rake, tone, undo and redo? [Spec §Q2, Q3, data-model] — yes.
- [x] CHK002 Is the drawn field's size and the reason for it specified? [Spec §Q1, research D2] — yes (480 × 360, fine-rake period about 5.8 cells).
- [x] CHK003 Is the brush preview defined with its shape, scale and lifetime? [Spec §FR-A20-204, Q4] — yes.
- [x] CHK004 Are the native alternatives to raking defined so every gesture action has one? [Spec §Q3] — yes (four patterns).

## Clarity and measurability

- [x] CHK005 Is "matches the reference" quantified for both storage formats? [Spec §Q1, SC-A20-202] — yes (1/1024, 1/255).
- [x] CHK006 Is "no gaps" quantified? [Spec §SC-A20-201, contract] — yes (0.004 + 1e-9).

## Consistency

- [x] CHK007 Is the change from the P00 GPU stamp decision recorded with its reason, consistently with the contract update? [Spec §Q1, research D1] — yes.
- [x] CHK008 Is the snapshot content consistent with the core's document and the undo history's lifetime? [Spec §Q5] — yes.

## Edge cases

- [x] CHK009 Are touches outside the tray, a second finger, the point cap and the stroke cap covered? [Spec §Edge Cases, Q2] — yes.
- [x] CHK010 Is the 8-bit fallback covered? [Spec §Edge Cases, Q1] — yes.

## Lifecycle

- [x] CHK011 Are resize, rotation, context loss, restore and pointer cancellation covered? [Spec §FR-A20-203, plan lifecycle] — yes.
- [x] CHK012 Is drawing when nothing changes specified (the manual's frame idling)? [Spec §FR-A20-207] — failed (no requirement); FR-A20-207 now requires a reused still frame and a 30 fps cap.

## Architecture, privacy and release

- [x] CHK013 Is GL kept in the host's scenes and out of the core, with no network or clock? [Spec §FR-A20-206] — yes.
- [x] CHK014 Is the registration a candidate only, with no permission? [Spec §Q5] — yes.
- [x] CHK015 Is VisualCore unchanged, with the reuse named? [Plan §Constitution Check II] — yes.

## Testability and performance

- [x] CHK016 Is the replay cost bounded by arithmetic rather than a device number? [Plan §Technical Context] — yes.
- [x] CHK017 Are test time limits stated? [Spec §SC-A20-204] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
