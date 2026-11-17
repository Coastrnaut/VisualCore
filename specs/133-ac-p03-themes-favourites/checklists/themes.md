# Themes Requirements Quality Checklist: Ambient Clock — Phase 03

**Purpose**: Unit tests for the requirements of A18-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK005).

## Completeness

- [x] CHK001 Are all four themes named with their per-level budgets? [Clarification Q2, data-model] — yes.
- [x] CHK002 Are the preset fields, ranges, schema and refusals specified? [Clarification Q3, data-model] — yes.
- [x] CHK003 Are the favourites cap, name rules, storage place and apply behaviour specified? [Clarification Q4] — yes.

## Architecture ownership

- [x] CHK004 Is the crossfade's placement in VisualCoreRendering justified by two consumers, with existing scenes unchanged and the VisualCore obligations listed? [Clarification Q1, Spec §FR-A18-307, plan] — yes.

## Measurability

- [x] CHK005 Is the crossfade's midpoint tolerance stated in numbers in the spec? [Spec §US2, SC-A18-303] — failed (the spec said "a small tolerance"); US2 and SC-A18-303 now say within 2 of 255 per channel, as contracts/crossfade.md.
- [x] CHK006 Is the contrast rule measurable for every theme and palette combination? [Spec §FR-A18-302, SC-A18-301] — yes (12 palettes, 48 colours).

## iOS lifecycle

- [x] CHK007 Are context loss and resize during a crossfade, a change during a crossfade, and a failed theme compile addressed? [Spec §Edge Cases, Clarification Q5] — yes.
- [x] CHK008 Is Reduce Motion's effect on the crossfade stated (a cut)? [Spec §FR-A18-303] — yes.

## Persistence and migration

- [x] CHK009 Is the snapshot migration from schema 1 specified with its default values and its registered examples? [Spec §FR-A18-306, research D5] — yes.
- [x] CHK010 Are damaged, newer, oversized and over-cap cases each named with a reason? [Spec §US3, contracts/themes.md] — yes.

## Privacy and release constraints

- [x] CHK011 Are imported themes, network, free colour choice and generated images excluded? [Spec §Negative Requirements] — yes.
- [x] CHK012 Is a license entry required for the shaders? [plan: licenses.md] — yes.

## Testability

- [x] CHK013 Is every success criterion tied to a runnable check under 10 seconds? [SC-A18-301–305, quickstart] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
