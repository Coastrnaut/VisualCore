# Customization and Persistence Requirements Quality Checklist: Tiny Worlds — Phase 03

**Purpose**: Unit tests for the requirements of A12-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK009).

## Completeness

- [x] CHK001 Are both manual phase gates (seeded terrain as the base; props persist at exact transforms) mapped to requirements? [Spec §Traceability, FR-A12-320, 323] — yes.
- [x] CHK002 Are the four props, their size and vertex limits and their license specified? [Clarifications Q1, FR-A12-301] — yes.
- [x] CHK003 Are all editing actions with ranges and refusal codes listed? [Clarifications Q2, contracts/actions.md] — yes.

## Architecture ownership

- [x] CHK004 Is it stated that this phase changes no VisualCore code and which existing products it reuses? [plan Technical Context, Constitution Check] — yes.
- [x] CHK005 Is the split between engine actions (edits, open) and presenter slot actions (save, open, clear) stated? [Clarifications Q4, contracts/actions.md] — yes.

## Placement and light rules

- [x] CHK006 Are the placement rules quantified (bounds, sea level per preset, spacing, cap)? [Clarifications Q2] — yes.
- [x] CHK007 Is the behaviour of props when the terrain changes defined? [Edge Cases, Clarifications Q2] — yes (cleared, spoken).
- [x] CHK008 Are the light ranges, defaults and direction formula defined? [Clarifications Q3, FR-A12-310] — yes.

## Data and recovery

- [x] CHK009 Does the world document list every part of the state that must persist? [FR-A12-320, data-model] — failed at first (the selection, part of the state in the data model, was missing from FR-A12-320); corrected.
- [x] CHK010 Are damaged, truncated, oversized and newer files and interrupted writes defined? [US3 AC2–3, Clarifications Q4, SC-A12-303–304] — yes.
- [x] CHK011 Is the migration from schema 1 defined? [Clarifications Q4, Edge Cases] — yes.
- [x] CHK012 Is "exact transform" made measurable? [SC-A12-302, Clarifications Q4] — yes (bit-identical).

## Interface, accessibility and lifecycle

- [x] CHK013 Does every editing action have a control alternative and spoken refusals? [FR-A12-303, SC-A12-305, US1 AC2] — yes.
- [x] CHK014 Is the thumbnail fallback without a context defined? [Edge Cases, Clarifications Q5] — yes.

## Privacy and performance

- [x] CHK015 Are files local only, size-capped and free of personal data, with no permission? [Clarifications Q4–Q5, Negative Requirements] — yes.
- [x] CHK016 Are geometry and file caps quantified without measured performance claims? [plan Technical Context] — yes.

## Notes

- 16 items evaluated on 2026-11-15; CHK009 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
